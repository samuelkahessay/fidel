#!/usr/bin/env python3
import argparse
from html import escape
import hashlib
import json
import os
from pathlib import Path
import re
import time
from urllib import error, request

AUDITION_IDS = [1, 2, 12, 20, 46]
ACTIVE_VOICE = "am-ET-AmehaNeural"
FEMALE_VOICE = "am-ET-MekdesNeural"
LANGUAGE = "am-ET"
OUTPUT_FORMAT = "audio-24khz-48kbitrate-mono-mp3"
PROVIDER = "azure"
ASSET_SET = "all-phrases-v1"
FIDEL_ASSET_SET = "fidel-characters-v1"
VOCAB_ASSET_SET = "vocabulary-v1"
CONVERSATION_ASSET_SET = "conversation-lines-v1"
SKIPPED_PLACEHOLDER_IDS = {17, 19, 55}

# The Azure am-ET voices return empty audio for these archaic Ge'ez code
# points. In modern Amharic they are homophones of their common-series
# counterparts, so synthesis substitutes the equivalent glyph; the manifest
# keeps the original character as the asset text.
FIDEL_TTS_SUBSTITUTIONS = {
    "4-3": "ሲ",   # ሢ (U+1222, śi) sounds identical to ሲ
    "13-7": "ሆ",  # ኆ (U+1286, ḫo) sounds identical to ሆ
}

# Same archaic-glyph workaround for word / conversation text, keyed by contentId.
# Populate only if Azure returns empty audio for a specific entry (validate flags it).
VOCAB_TTS_SUBSTITUTIONS: dict[str, str] = {}
CONVERSATION_TTS_SUBSTITUTIONS: dict[str, str] = {}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def load_phrases(root: Path) -> list[dict]:
    return json.loads((root / "Fidel" / "Data" / "phrases.json").read_text(encoding="utf-8"))


def load_fidel_chart(root: Path) -> list[dict]:
    return json.loads((root / "Fidel" / "Data" / "fidel_chart.json").read_text(encoding="utf-8"))


def load_vocabulary(root: Path) -> list[dict]:
    return json.loads((root / "Fidel" / "Data" / "vocabulary.json").read_text(encoding="utf-8"))


def load_conversations(root: Path) -> list[dict]:
    return json.loads((root / "Fidel" / "Data" / "conversations.json").read_text(encoding="utf-8"))


def source_hash(text: str, voice: str) -> str:
    source = f"{LANGUAGE}|{PROVIDER}|{voice}|{OUTPUT_FORMAT}|{text}"
    return hashlib.sha256(source.encode("utf-8")).hexdigest()


def slugify(value: str) -> str:
    slug = value.lower().replace("&", "and")
    slug = re.sub(r"[^a-z0-9]+", "-", slug)
    slug = slug.strip("-")
    return slug or "phrase"


def audio_file_path(phrase: dict, voice: str) -> str:
    phrase_id = int(phrase["id"])
    return f"Audio/phrases/{PROVIDER}/{voice}/phrase-{phrase_id:03d}-{slugify(phrase['english'])}.mp3"


def asset_id(phrase_id: int, voice: str) -> str:
    return f"phrase-{phrase_id:03d}__{PROVIDER}__{voice}"


def manifest_row(phrase: dict, voice: str, asset_role: str) -> dict:
    phrase_id = int(phrase["id"])
    return {
        "id": asset_id(phrase_id, voice),
        "contentType": "phrase",
        "contentId": str(phrase_id),
        "language": LANGUAGE,
        "provider": PROVIDER,
        "voice": voice,
        "assetRole": asset_role,
        "assetSet": ASSET_SET,
        "format": "mp3",
        "file": audio_file_path(phrase, voice),
        "englishSlug": slugify(phrase["english"]),
        "text": phrase["amharic"],
        "sourceTextHash": source_hash(phrase["amharic"], voice),
    }


def rows_for_ids(root: Path, phrase_ids: list[int], voice: str, asset_role: str) -> list[dict]:
    phrases = {item["id"]: item for item in load_phrases(root)}
    missing_ids = [phrase_id for phrase_id in phrase_ids if phrase_id not in phrases]
    if missing_ids:
        raise SystemExit(f"Missing phrase IDs in phrases.json: {missing_ids}")
    return [manifest_row(phrases[phrase_id], voice, asset_role) for phrase_id in phrase_ids]


def is_placeholder_phrase(phrase: dict) -> bool:
    fields = (phrase["english"], phrase["amharic"], phrase["transliteration"])
    return int(phrase["id"]) in SKIPPED_PLACEHOLDER_IDS or any("[" in field or "]" in field for field in fields)


def full_phrase_rows(root: Path, voice: str, asset_role: str) -> list[dict]:
    phrases = load_phrases(root)
    placeholder_ids = {int(phrase["id"]) for phrase in phrases if is_placeholder_phrase(phrase)}
    if placeholder_ids != SKIPPED_PLACEHOLDER_IDS:
        raise SystemExit(
            f"Placeholder phrase IDs changed. Expected {sorted(SKIPPED_PLACEHOLDER_IDS)}, "
            f"found {sorted(placeholder_ids)}"
        )
    return [manifest_row(phrase, voice, asset_role) for phrase in phrases if int(phrase["id"]) not in placeholder_ids]


def fidel_character_id(char: dict) -> str:
    return f"{int(char['rowIndex'])}-{int(char['vowelOrder'])}"


def fidel_audio_file_path(char: dict, voice: str) -> str:
    row = int(char["rowIndex"])
    vowel = int(char["vowelOrder"])
    return f"Audio/fidel/{PROVIDER}/{voice}/fidel-{row:02d}-{vowel}-{slugify(char['romanization'])}.mp3"


def fidel_manifest_row(char: dict, voice: str) -> dict:
    row = int(char["rowIndex"])
    vowel = int(char["vowelOrder"])
    return {
        "id": f"fidel-{row:02d}-{vowel}__{PROVIDER}__{voice}",
        "contentType": "fidelCharacter",
        "contentId": fidel_character_id(char),
        "language": LANGUAGE,
        "provider": PROVIDER,
        "voice": voice,
        "assetRole": "active",
        "assetSet": FIDEL_ASSET_SET,
        "format": "mp3",
        "file": fidel_audio_file_path(char, voice),
        "englishSlug": slugify(char["romanization"]),
        "text": char["character"],
        "sourceTextHash": source_hash(char["character"], voice),
    }


def fidel_rows(root: Path) -> list[dict]:
    return [fidel_manifest_row(char, ACTIVE_VOICE) for char in load_fidel_chart(root)]


def vocabulary_content_id(word: dict) -> str:
    return f"{word['category']}-{word['amharic']}"


def vocabulary_audio_file_path(index: int, word: dict, voice: str) -> str:
    # English slugs collide (e.g. two "doctor"s), so the array index keeps file
    # names unique; the contentId stays unique via the Amharic spelling.
    return f"Audio/vocabulary/{PROVIDER}/{voice}/vocab-{index:03d}-{slugify(word['english'])}.mp3"


def vocabulary_manifest_row(index: int, word: dict, voice: str) -> dict:
    return {
        "id": f"vocab-{index:03d}__{PROVIDER}__{voice}",
        "contentType": "vocabulary",
        "contentId": vocabulary_content_id(word),
        "language": LANGUAGE,
        "provider": PROVIDER,
        "voice": voice,
        "assetRole": "active",
        "assetSet": VOCAB_ASSET_SET,
        "format": "mp3",
        "file": vocabulary_audio_file_path(index, word, voice),
        "englishSlug": slugify(word["english"]),
        "text": word["amharic"],
        "sourceTextHash": source_hash(word["amharic"], voice),
    }


def vocabulary_rows(root: Path) -> list[dict]:
    return [
        vocabulary_manifest_row(index, word, ACTIVE_VOICE)
        for index, word in enumerate(load_vocabulary(root))
    ]


def conversation_content_id(conversation_id: int, line_num: int) -> str:
    return f"{conversation_id}-{line_num}"


def conversation_audio_file_path(conversation_id: int, line_num: int, voice: str) -> str:
    return f"Audio/conversations/{PROVIDER}/{voice}/conv-{conversation_id:02d}-{line_num:02d}.mp3"


def conversation_manifest_row(conversation: dict, line: dict, voice: str) -> dict:
    conversation_id = int(conversation["id"])
    line_num = int(line["lineNum"])
    return {
        "id": f"conv-{conversation_id:02d}-{line_num:02d}__{PROVIDER}__{voice}",
        "contentType": "conversationLine",
        "contentId": conversation_content_id(conversation_id, line_num),
        "language": LANGUAGE,
        "provider": PROVIDER,
        "voice": voice,
        "assetRole": "active",
        "assetSet": CONVERSATION_ASSET_SET,
        "format": "mp3",
        "file": conversation_audio_file_path(conversation_id, line_num, voice),
        "englishSlug": slugify(line["english"]),
        "text": line["amharic"],
        "sourceTextHash": source_hash(line["amharic"], voice),
    }


def conversation_line_rows(root: Path) -> list[dict]:
    return [
        conversation_manifest_row(conversation, line, ACTIVE_VOICE)
        for conversation in load_conversations(root)
        for line in conversation["lines"]
    ]


def active_manifest_rows(root: Path) -> list[dict]:
    return full_phrase_rows(root, ACTIVE_VOICE, "active")


def female_rows(root: Path) -> list[dict]:
    return full_phrase_rows(root, FEMALE_VOICE, "alternate")


def audition_rows(root: Path, voice: str) -> list[dict]:
    return rows_for_ids(root, AUDITION_IDS, voice, "audition")


def catalog_rows(root: Path) -> list[dict]:
    active_rows = active_manifest_rows(root)
    female_catalog_rows = [
        row for row in female_rows(root)
        if (root / "Fidel" / row["file"]).exists()
    ]
    return active_rows + female_catalog_rows


def app_manifest_path(root: Path) -> Path:
    return root / "Fidel" / "Data" / "audio_manifest.json"


def catalog_path(root: Path) -> Path:
    return root / "Fidel" / "Data" / "audio_catalog.json"


def write_json(path: Path, rows: list[dict]) -> None:
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(rows)} rows to {path}")


def validate(root: Path, rows: list[dict], *, allow_duplicate_content: bool) -> list[str]:
    errors = []
    phrases = {str(item["id"]): item for item in load_phrases(root)}
    fidel_chars = {fidel_character_id(char): char for char in load_fidel_chart(root)}
    vocab_words = {vocabulary_content_id(word): (index, word) for index, word in enumerate(load_vocabulary(root))}
    conversation_lines = {
        conversation_content_id(int(conversation["id"]), int(line["lineNum"])): (conversation, line)
        for conversation in load_conversations(root)
        for line in conversation["lines"]
    }
    seen_ids = set()
    seen_content_keys = set()
    for row in rows:
        row_id = row["id"]
        content_key = (row["contentType"], row["contentId"])
        if row_id in seen_ids:
            errors.append(f"{row_id}: duplicate asset id")
        seen_ids.add(row_id)
        if not allow_duplicate_content and content_key in seen_content_keys:
            errors.append(f"{row_id}: duplicate active content key {content_key}")
        seen_content_keys.add(content_key)

        if row["contentType"] == "fidelCharacter":
            char = fidel_chars.get(row["contentId"])
            if char is None:
                errors.append(f"{row_id}: missing fidel character {row['contentId']}")
            elif char["character"] != row["text"]:
                errors.append(f"{row_id}: text mismatch")
            elif row["file"] != fidel_audio_file_path(char, row["voice"]):
                errors.append(f"{row_id}: expected file {fidel_audio_file_path(char, row['voice'])}")
            elif row.get("englishSlug") != slugify(char["romanization"]):
                errors.append(f"{row_id}: stale romanization slug")
            if not row["file"].startswith(f"Audio/fidel/{PROVIDER}/{row['voice']}/"):
                errors.append(f"{row_id}: file path is not voice-scoped")
        elif row["contentType"] == "vocabulary":
            entry = vocab_words.get(row["contentId"])
            if entry is None:
                errors.append(f"{row_id}: missing vocabulary {row['contentId']}")
            else:
                index, word = entry
                if word["amharic"] != row["text"]:
                    errors.append(f"{row_id}: text mismatch")
                elif row["file"] != vocabulary_audio_file_path(index, word, row["voice"]):
                    errors.append(f"{row_id}: expected file {vocabulary_audio_file_path(index, word, row['voice'])}")
                elif row.get("englishSlug") != slugify(word["english"]):
                    errors.append(f"{row_id}: stale english slug")
            if not row["file"].startswith(f"Audio/vocabulary/{PROVIDER}/{row['voice']}/"):
                errors.append(f"{row_id}: file path is not voice-scoped")
        elif row["contentType"] == "conversationLine":
            entry = conversation_lines.get(row["contentId"])
            if entry is None:
                errors.append(f"{row_id}: missing conversation line {row['contentId']}")
            else:
                conversation, line = entry
                expected_file = conversation_audio_file_path(int(conversation["id"]), int(line["lineNum"]), row["voice"])
                if line["amharic"] != row["text"]:
                    errors.append(f"{row_id}: text mismatch")
                elif row["file"] != expected_file:
                    errors.append(f"{row_id}: expected file {expected_file}")
                elif row.get("englishSlug") != slugify(line["english"]):
                    errors.append(f"{row_id}: stale english slug")
            if not row["file"].startswith(f"Audio/conversations/{PROVIDER}/{row['voice']}/"):
                errors.append(f"{row_id}: file path is not voice-scoped")
        else:
            if row["contentType"] == "phrase" and int(row["contentId"]) in SKIPPED_PLACEHOLDER_IDS:
                errors.append(f"{row_id}: placeholder phrase should not have generated audio")

            phrase = phrases.get(row["contentId"])
            if phrase is None:
                errors.append(f"{row_id}: missing phrase {row['contentId']}")
            elif phrase["amharic"] != row["text"]:
                errors.append(f"{row_id}: text mismatch")
            elif row["file"] != audio_file_path(phrase, row["voice"]):
                errors.append(f"{row_id}: expected file {audio_file_path(phrase, row['voice'])}")
            elif row.get("englishSlug") != slugify(phrase["english"]):
                errors.append(f"{row_id}: stale english slug")
            if not row["file"].startswith(f"Audio/phrases/{PROVIDER}/{row['voice']}/"):
                errors.append(f"{row_id}: file path is not voice-scoped")

        if row["language"] != LANGUAGE:
            errors.append(f"{row_id}: expected language {LANGUAGE}")
        if row["provider"] != PROVIDER:
            errors.append(f"{row_id}: expected provider {PROVIDER}")
        if row["format"] != "mp3":
            errors.append(f"{row_id}: expected mp3 format")
        if row["sourceTextHash"] != source_hash(row["text"], row["voice"]):
            errors.append(f"{row_id}: stale source hash")

        file_path = root / "Fidel" / row["file"]
        if not file_path.exists():
            errors.append(f"{row_id}: missing audio file {file_path}")
        elif file_path.stat().st_size == 0:
            errors.append(f"{row_id}: empty audio file {file_path}")
    return errors


def load_local_env(root: Path) -> None:
    env_path = root / ".env"
    if not env_path.exists():
        return

    allowed_keys = {"AZURE_SPEECH_KEY", "AZURE_SPEECH_REGION"}
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key not in allowed_keys or os.environ.get(key):
            continue
        os.environ[key] = value.strip().strip("\"'")


def synthesize(root: Path, rows: list[dict], force: bool) -> None:
    load_local_env(root)
    key = os.environ.get("AZURE_SPEECH_KEY")
    region = os.environ.get("AZURE_SPEECH_REGION")
    if not key or not region:
        raise SystemExit("Set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION in the shell or ignored .env before generating audio.")

    endpoint = f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1"
    for row in rows:
        output = root / "Fidel" / row["file"]
        output.parent.mkdir(parents=True, exist_ok=True)
        if output.exists() and not force:
            print(f"skipped existing {output.relative_to(root / 'Fidel')}")
            continue

        tts_text = row["text"]
        # Isolated character pronunciation is spoken noticeably slower than
        # phrases so learners can hear the syllable clearly. Single words sit
        # between the two; full conversation lines read at natural phrase pace.
        rate = "-8%"
        if row["contentType"] == "fidelCharacter":
            tts_text = FIDEL_TTS_SUBSTITUTIONS.get(row["contentId"], tts_text)
            rate = "-35%"
        elif row["contentType"] == "vocabulary":
            tts_text = VOCAB_TTS_SUBSTITUTIONS.get(row["contentId"], tts_text)
            rate = "-18%"
        elif row["contentType"] == "conversationLine":
            tts_text = CONVERSATION_TTS_SUBSTITUTIONS.get(row["contentId"], tts_text)
        text = escape(tts_text, quote=False)
        ssml = (
            f"<speak version='1.0' xml:lang='{LANGUAGE}'>"
            f"<voice xml:lang='{LANGUAGE}' name='{row['voice']}'>"
            f"<prosody rate='{rate}'>{text}</prosody>"
            "</voice></speak>"
        )
        req = request.Request(endpoint, data=ssml.encode("utf-8"), method="POST")
        req.add_header("Ocp-Apim-Subscription-Key", key)
        req.add_header("Content-Type", "application/ssml+xml")
        req.add_header("X-Microsoft-OutputFormat", OUTPUT_FORMAT)
        req.add_header("User-Agent", "FidelAudioGenerator")

        # Retry transient throttling/server errors with exponential backoff so a
        # long (600+ call) run isn't aborted by a single 429.
        attempt = 0
        while True:
            try:
                with request.urlopen(req, timeout=30) as response:
                    output.write_bytes(response.read())
                print(f"generated {output.relative_to(root / 'Fidel')}")
                break
            except error.HTTPError as exc:
                if exc.code in {429, 500, 503} and attempt < 5:
                    attempt += 1
                    wait = 2 ** attempt
                    print(f"retry {attempt}/5 for {row['id']} after HTTP {exc.code}; waiting {wait}s")
                    time.sleep(wait)
                    continue
                details = exc.read().decode("utf-8", errors="replace")
                raise SystemExit(f"Azure TTS failed for {row['id']}: HTTP {exc.code} {details}") from exc


def selected_rows(root: Path, scope: str, voice: str) -> list[dict]:
    if scope in {"active", "male"}:
        return active_manifest_rows(root)
    if scope == "female":
        return female_rows(root)
    if scope == "audition":
        return audition_rows(root, voice)
    if scope == "catalog":
        return catalog_rows(root)
    if scope == "fidel":
        return fidel_rows(root)
    if scope == "vocabulary":
        return vocabulary_rows(root)
    if scope == "conversation":
        return conversation_line_rows(root)
    raise SystemExit(f"Unknown scope: {scope}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate and validate Fidel pronunciation audio assets.")
    parser.add_argument("--scope", choices=["active", "male", "female", "audition", "catalog", "fidel", "vocabulary", "conversation"], default="active")
    parser.add_argument("--write-manifest", action="store_true", help="Write the app-facing active audio manifest.")
    parser.add_argument("--write-catalog", action="store_true", help="Write the full generated-audio catalog.")
    parser.add_argument("--generate", action="store_true", help="Generate MP3 files through Azure Speech.")
    parser.add_argument("--validate", action="store_true", help="Validate selected rows against source text and files.")
    parser.add_argument("--force", action="store_true", help="Regenerate MP3 files that already exist.")
    parser.add_argument("--voice", default=ACTIVE_VOICE, help=f"Azure voice name for audition scope. Default: {ACTIVE_VOICE}")
    args = parser.parse_args()

    root = repo_root()
    rows = selected_rows(root, args.scope, args.voice)

    if args.write_manifest:
        # The app manifest carries phrase audio plus per-character fidel audio,
        # per-word vocabulary audio, and per-line conversation audio. Only rows
        # whose mp3s exist are included, so a partial generation never breaks the
        # bundled-files test.
        generated_fidel_rows = [
            row for row in fidel_rows(root)
            if (root / "Fidel" / row["file"]).exists()
        ]
        generated_vocab_rows = [
            row for row in vocabulary_rows(root)
            if (root / "Fidel" / row["file"]).exists()
        ]
        generated_conversation_rows = [
            row for row in conversation_line_rows(root)
            if (root / "Fidel" / row["file"]).exists()
        ]
        write_json(
            app_manifest_path(root),
            active_manifest_rows(root)
            + generated_fidel_rows
            + generated_vocab_rows
            + generated_conversation_rows,
        )
    if args.write_catalog:
        write_json(catalog_path(root), catalog_rows(root))
    if args.generate:
        synthesize(root, rows, args.force)
    if args.validate:
        errors = validate(root, rows, allow_duplicate_content=args.scope == "catalog")
        if errors:
            raise SystemExit("\n".join(errors))
        print(f"validated {len(rows)} {args.scope} audio rows")


if __name__ == "__main__":
    main()
