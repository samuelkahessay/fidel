# Audio Asset Library

Date: 2026-05-13

## Purpose

Fidel keeps pronunciation audio as generated, reviewable assets. The app-facing manifest chooses what ships in learner UI, while the catalog records every generated clip that exists for review or future use.

## Files

- `Fidel/Data/audio_manifest.json`: active app-facing audio rows. It must contain at most one row per `contentType` and `contentId`, because the app resolves audio by content key.
- `Fidel/Data/audio_catalog.json`: full generated-audio catalog. It can contain multiple voices for the same content item when clips are alternates or under review.
- `Fidel/Audio/phrases/azure/<voice>/phrase-<id>-<english-slug>.mp3`: generated phrase audio files, scoped by provider and voice.

## Naming

Use zero-padded phrase IDs, English slugs, and voice-scoped folders:

```text
Audio/phrases/azure/am-ET-AmehaNeural/phrase-001-hello.mp3
Audio/phrases/azure/am-ET-MekdesNeural/phrase-001-hello.mp3
```

Do not put provider or voice variants directly under `Audio/phrases/`; those filenames collide as soon as a second voice exists.

The active library is generated from `Fidel/Data/phrases.json` and skips placeholder phrase IDs `17`, `19`, and `55`. That leaves 171 clips per full voice set.

## Catalog Fields

Each row records:

- `id`: unique asset ID, including content ID, provider, and voice.
- `contentType` and `contentId`: source content lookup key.
- `language`, `provider`, `voice`, `format`: generation identity.
- `assetRole`: `active` for shipped app clips, `alternate` for generated clips that are cataloged but not used by default.
- `assetSet`: the product/content batch, currently `all-phrases-v1`.
- `file`: bundle-relative audio path.
- `englishSlug`: slug used in the filename for human browsing.
- `text`: Amharic source text used for synthesis.
- `sourceTextHash`: hash of language, provider, voice, output format, and text.

## Commands

Regenerate the active app manifest:

```bash
python3 tools/audio/azure_audio_manifest.py --write-manifest
```

Regenerate the full catalog:

```bash
python3 tools/audio/azure_audio_manifest.py --write-catalog
```

Validate active shipped clips:

```bash
python3 tools/audio/azure_audio_manifest.py --scope active --validate
```

Validate all generated catalog clips:

```bash
python3 tools/audio/azure_audio_manifest.py --scope catalog --validate
```

Generate the male Azure active set:

```bash
AZURE_SPEECH_KEY=... AZURE_SPEECH_REGION=canadacentral \
  python3 tools/audio/azure_audio_manifest.py --scope active --generate
```

Generate the female alternate catalog set after the male active set validates:

```bash
AZURE_SPEECH_KEY=... AZURE_SPEECH_REGION=canadacentral \
  python3 tools/audio/azure_audio_manifest.py --scope female --generate
```
