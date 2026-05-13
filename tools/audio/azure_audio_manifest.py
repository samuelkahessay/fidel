#!/usr/bin/env python3
import argparse
from html import escape
import hashlib
import json
import os
from pathlib import Path
from urllib import error, request

PILOT_IDS = [1, 2, 3, 4, 5, 8, 9, 10, 12, 13, 14, 16, 20, 21, 22, 26, 27, 28, 30, 32, 33, 46, 47, 49, 50]
DEFAULT_VOICE = "am-ET-MekdesNeural"
LANGUAGE = "am-ET"
OUTPUT_FORMAT = "audio-24khz-48kbitrate-mono-mp3"


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def load_phrases(root: Path) -> list[dict]:
    return json.loads((root / "Fidel" / "Data" / "phrases.json").read_text(encoding="utf-8"))


def source_hash(text: str, voice: str) -> str:
    source = f"{LANGUAGE}|{voice}|{OUTPUT_FORMAT}|{text}"
    return hashlib.sha256(source.encode("utf-8")).hexdigest()


def manifest_row(phrase: dict, voice: str) -> dict:
    phrase_id = str(phrase["id"])
    return {
        "id": f"phrase-{phrase_id}",
        "contentType": "phrase",
        "contentId": phrase_id,
        "language": LANGUAGE,
        "provider": "azure",
        "voice": voice,
        "format": "mp3",
        "file": f"Audio/phrases/phrase-{phrase_id}.mp3",
        "text": phrase["amharic"],
        "sourceTextHash": source_hash(phrase["amharic"], voice),
    }


def pilot_rows(root: Path, voice: str) -> list[dict]:
    phrases = {item["id"]: item for item in load_phrases(root)}
    missing_ids = [phrase_id for phrase_id in PILOT_IDS if phrase_id not in phrases]
    if missing_ids:
        raise SystemExit(f"Missing pilot phrase IDs in phrases.json: {missing_ids}")
    return [manifest_row(phrases[phrase_id], voice) for phrase_id in PILOT_IDS]


def manifest_path(root: Path) -> Path:
    return root / "Fidel" / "Data" / "audio_manifest.json"


def write_manifest(root: Path, rows: list[dict]) -> None:
    target = manifest_path(root)
    target.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(rows)} audio rows to {target}")


def validate(root: Path, rows: list[dict]) -> list[str]:
    errors = []
    phrases = {str(item["id"]): item for item in load_phrases(root)}
    seen_ids = set()
    for row in rows:
        row_id = row["id"]
        if row_id in seen_ids:
            errors.append(f"{row_id}: duplicate manifest row")
        seen_ids.add(row_id)

        phrase = phrases.get(row["contentId"])
        if phrase is None:
            errors.append(f"{row_id}: missing phrase {row['contentId']}")
        elif phrase["amharic"] != row["text"]:
            errors.append(f"{row_id}: text mismatch")

        if row["language"] != LANGUAGE:
            errors.append(f"{row_id}: expected language {LANGUAGE}")
        if row["provider"] != "azure":
            errors.append(f"{row_id}: expected provider azure")
        if row["format"] != "mp3":
            errors.append(f"{row_id}: expected mp3 format")

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
            print(f"skipped existing {output.name}")
            continue

        text = escape(row["text"], quote=False)
        ssml = (
            f"<speak version='1.0' xml:lang='{LANGUAGE}'>"
            f"<voice xml:lang='{LANGUAGE}' name='{row['voice']}'>"
            f"<prosody rate='-8%'>{text}</prosody>"
            "</voice></speak>"
        )
        req = request.Request(endpoint, data=ssml.encode("utf-8"), method="POST")
        req.add_header("Ocp-Apim-Subscription-Key", key)
        req.add_header("Content-Type", "application/ssml+xml")
        req.add_header("X-Microsoft-OutputFormat", OUTPUT_FORMAT)
        req.add_header("User-Agent", "FidelAudioGenerator")

        try:
            with request.urlopen(req, timeout=30) as response:
                output.write_bytes(response.read())
            print(f"generated {output.name}")
        except error.HTTPError as exc:
            details = exc.read().decode("utf-8", errors="replace")
            raise SystemExit(f"Azure TTS failed for {row['id']}: HTTP {exc.code} {details}") from exc


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate and validate Fidel pronunciation audio assets.")
    parser.add_argument("--write-manifest", action="store_true", help="Write the 25-row pilot audio manifest.")
    parser.add_argument("--generate", action="store_true", help="Generate MP3 files through Azure Speech.")
    parser.add_argument("--validate", action="store_true", help="Validate manifest rows against source text and files.")
    parser.add_argument("--force", action="store_true", help="Regenerate MP3 files that already exist.")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help=f"Azure voice name. Default: {DEFAULT_VOICE}")
    args = parser.parse_args()

    root = repo_root()
    rows = pilot_rows(root, args.voice)

    if args.write_manifest:
        write_manifest(root, rows)
    if args.generate:
        synthesize(root, rows, args.force)
    if args.validate:
        errors = validate(root, rows)
        if errors:
            raise SystemExit("\n".join(errors))
        print(f"validated {len(rows)} audio rows")


if __name__ == "__main__":
    main()
