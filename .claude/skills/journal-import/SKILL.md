---
name: journal-import
description: Import handwritten journal photos into an Obsidian vault via the journal:ocr / journal:write rake tasks, bypassing the web UI. Use when given a folder of journal page photos to OCR, transcribe and write into the vault, or when asked about the local import pipeline.
---

Read `LOCAL-PIPELINE.md` at the repo root before doing anything. It is the procedure; this file is
only the spine and the rules that are expensive to rediscover.

```
photos → stage → journal:ocr → transcribe → verify → dry run → journal:write
```

`lib/tasks/import.rake` holds both tasks. Run with `bin/rails`, not `bundle exec rake` — `dotenv-rails`
loads `.env`, where `HANDWRITING_OCR_API_KEY` and `OBSIDIAN_VAULT_PATH` live.

## Rules that cost money or data if broken

- **Stage photos into a fresh, empty directory.** The OCR glob takes every image in the dir, so any
  crop or normalised derivative you leave there gets OCR'd as an extra page and billed.
- **OCR is paid per page.** Confirm the page count and the user's credit balance before running.
  Pages cache individually, so chunk freely with `LIMIT=` — it costs the same.
- **`journal:write` is not idempotent.** A second run rewrites every entry under a `-2` suffix. Run it
  exactly once, after `DRY_RUN=1`. Never inside `$( )`.
- **Never overwrite an existing entry.** The vault holds voice, daily-note and handwritten entries on
  the same dates; a collision is a different medium, not a duplicate. Suffix.
- **Do not transcribe from your own vision.** Handwriting OCR is the transcription source; your own
  reading of a page is for orientation and for settling a single ambiguous name, nothing more.

## Judgement

- **Dates:** agents report what the page says; Ruby decides what can be true (weekday vs calendar,
  page coverage, duplicates, chronology, vault seam). Never let a model be the last word on arithmetic.
- **Proper nouns are the one error class the pipeline cannot catch.** Cluster capitalised tokens by edit
  distance, list singletons, and ASK THE USER. Do not silently "correct" a name — and do not merge two
  spellings without confirmation; one of them may be a different person.
- Person-specific material — the OCR name glossary, the notebook inventory, per-entry date corrections
  — lives in `Journal digitisation.md` in the vault, not in this repo. Read it at the start of a run and
  append to it at the end. Keep it out of git.
