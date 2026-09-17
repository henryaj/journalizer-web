# Local import pipeline

How to get a notebook of handwritten journal photos into the Obsidian vault without touching the web
UI. This is the procedure that imported 533 pages across three notebooks; it is written down because
most of the cost was discovering the failure modes, not doing the work.

Person- and journal-specific details — the OCR name glossary, per-entry date corrections, notebook
inventory — deliberately live in `Journal digitisation.md` **in the vault**, not here. This file is the
method only.

---

## The shape of it

```
photos ──▶ stage ──▶ journal:ocr ──▶ transcribe ──▶ verify ──▶ dry run ──▶ journal:write
           (clean)   (paid, cached)   (parallel)   (deterministic)          (ONCE)
```

Two rake tasks do the mechanical ends; everything between them is judgement.

```bash
bin/rails 'journal:ocr[/path/to/photos]'                  # LIMIT=30 to do a chunk
bin/rails 'journal:write[/path/to/photos,entries.json]'   # DRY_RUN=1 to preview
```

Run them locally with `bin/rails`, not `bundle exec rake` — `dotenv-rails` loads `.env`, which is where
`HANDWRITING_OCR_API_KEY`, `OBSIDIAN_VAULT_PATH` and `OBSIDIAN_JOURNAL_FOLDER` live. The task aborts
loudly if the vault path or its `journal/` and `attachments/` subdirectories are missing.

`journal:ocr` normalises each photo (3000px, Q90, flattened — handles HEIC), uploads to
HandwritingOCR, polls, and caches the text per page in `$TMPDIR/journal-import-<hash of dir>/`.
`journal:write` takes structured entries back and writes markdown + images into the vault.

Between them you produce `entries.json`: an array of
`{title, date, image_indices, text}`. That is the interesting part.

---

## 1. Stage into a clean directory

```bash
mkdir -p ~/journal-import-<name>
cp ~/Downloads/IMG_*.HEIC ~/journal-import-<name>/
```

**Always stage.** The glob in `journal:ocr` picks up `*.{jpg,jpeg,png,heic,webp,tif,tiff}`. Point it at
a directory where you have also written normalised `.jpg` output and it will OCR its own derivatives as
extra pages — real money, silently. This cost 3 wasted pages the first time.

AirDrop from iPhone lands in `~/Downloads`, not `~/Desktop`.

Check the filenames sort in page order. `IMG_1234.HEIC` is fine (fixed width). Anything like
`page9.jpg` / `page10.jpg` is not — the task zero-pads digit runs in its sort key to handle it, but
verify. Page indices are the contract between the OCR text, the entry `image_indices`, and the copied
attachments; get the order wrong and every photo attaches to the wrong entry.

Gaps in the numbering are usually iOS skipping numbers, not missing pages. Worth one glance at the
phone, not worth blocking on.

## 2. Look at one page before spending anything

Normalise a single page and *look* at it.

```ruby
UploadToOcrJob.normalize('/path/IMG_0001.HEIC', '/tmp/probe.jpg')
```

This is free and tells you the orientation, whether it is a single page or a two-page spread, and the
date on page one — enough to identify which notebook you are holding and what era it covers. Vision is
reliable for *orientation and navigation*. It is not reliable for transcription (see §7).

## 3. OCR

```bash
caffeinate -i bin/rails "journal:ocr[/Users/you/journal-import-<name>]"
```

Run it in the background; ~10–15s per page. Results cache per page, so:

- chunked runs (`LIMIT=30`) cost exactly the same as one big run
- a crash costs at most the page in flight
- re-running is free for pages already done

**`caffeinate -i` does not survive a laptop lid close.** It blocks idle sleep only. A lid close killed a
36-minute run with nothing recoverable.

Check afterwards: 1 `.txt` per page, none under ~20 bytes, none missing.

## 4. Map the structure before transcribing

Free, and it tells you what you are dealing with.

```bash
# printed page numbers — a reset means a notebook change mid-batch
for i in $(seq -f "%03g" 0 N); do
  n=$(grep -oE '^[0-9]{1,3}$' $CACHE/$i.txt | tr '\n' ',')
  [ -n "$n" ] && printf "%s:%s " "$((10#$i))" "$n"
done

# date headers — the era, and any obvious anomalies
grep -oiE '(Mon|Tues?|Wednes?|Thurs?|Fri|Satur?|Sun)[a-z]*,? ?[0-9]{1,2}' $CACHE/*.txt
```

Printed page numbers are the single best structural signal. They are monotonic within a notebook, so a
reset tells you two notebooks are in one batch, and contiguity proves an entry sits between its
neighbours regardless of what its header claims.

> `seq -w` pads to the width of the *largest* value — 2 digits for `seq -w 0 99`. Use `seq -f "%03g"`.
> This bit twice, and once silently produced an empty read inside a subagent.

## 5. Transcribe

For anything beyond ~40 pages, fan out. The shape that worked:

- **8-page windows.** Each agent gets 4 pages of lookbehind and 6 of lookahead as *context*, but
  **owns** a strict range.
- **Ownership by date header.** Emit an entry if and only if its date header falls in the owned range.
  If the window opens mid-entry, that entry belongs to the previous window — skip it. If an entry
  starting in range runs past the end, include the continuation and its page indices.
  This is what stops boundary entries being truncated by one window and duplicated by the next.
- **Checkpoint each window to disk**, and have the agent check for its own checkpoint before starting.
  Workflow-level resume only caches agents that *completed*; a hard kill mid-flight caches nothing.
- **Three stages, pipelined**: transcribe → faithfulness critic → repair, with repair running only on
  flagged windows. Roughly 2/3 of windows pass clean.

Point the critic explicitly at **omission**, and say so bluntly in the prompt — the failure mode of a
subagent on difficult personal material is quietly dropping the uncomfortable parts, and a critic
comparing text to source will otherwise call that faithful. Ask it to report seam gaps *outside* its own
remit too; that is how a page orphaned between a hand-transcribed prefix and the fan-out was caught.

Give every agent the glossary of known OCR misreads, **and** an explicit list of names that look like
variants but are distinct people. The second list matters more than the first.

## 6. Verify deterministically

Never let the model be the last word on anything a computer can check. Agents return the raw date
header and the weekday word verbatim; code decides whether they can be true.

1. **Weekday vs calendar.** Parse the claimed weekday, compare to the real one, and for mismatches
   offer nearby dates that *would* satisfy it — including ±1 month, because writing the old month for a
   week after a boundary is a common habit.
2. **Page coverage.** Every source page claimed by at least one entry.
3. **Duplicate dates**, distinguishing cross-window (suspect double-emission) from same-window (usually
   two genuine sittings).
4. **Chronology.** Backwards jumps when entries are sorted by page order.
5. **Seam.** Which proposed dates already exist in the vault, and from what source.

Test the verifier on synthetic input before trusting it. Both times a correction script was written, it
had a bug the verifier caught — most memorably matching entries *by date* while mutating dates, so
correction N found the entry correction N−1 had just renamed.

For dates that survive all of that unresolved, a panel of independent judges on **different lenses**
(weekday arithmetic / sequence and page numbers / narrative content) works well. Unanimity means
something; a 1–1–1 split means the evidence genuinely is not there, and the honest move is to file the
date as written and record the conflict in the entry.

## 7. Ask about proper nouns

**This is the one error class nothing in the pipeline can catch.** OCR renders a name consistently
wrong, the critic sees the same wrong name in source and transcription and passes it, and the calendar
check has no opinion. Of nine ambiguous names put to the journal's author, six were wrong — including
one person appearing under three different OCR spellings, and two cases where merging apparent variants
would have erased a real separate person.

How to surface them:

```
cluster every capitalised token across the corpus by edit distance   → near-variant pairs
list the singletons                                                  → highest OCR risk
cross-reference the agents' own uncertainty flags                    → what they already doubted
```

Most clusters are noise (`Park`/`Mark`, `Fight`/`Night`). The signal is real.

Two traps:

- **The same first name can mean two different people in one entry.** A global rename merged a fund
  manager with a house guest. Check per occurrence.
- **When in doubt, crop the image and look at the handwriting.** Twice, reading the actual page beat
  every inference available from the text — a name the OCR rendered as a plausible-but-wrong word
  turned out to be legible once enlarged. Free, and more reliable than reasoning about context.

## 8. Dry run, then write once

```bash
DRY_RUN=1 bin/rails 'journal:write[<dir>,entries.json]'
```

Check what will be suffixed. A `-2` means that date already exists; confirm the existing entry is a
different *medium* (voice, daily note) or a genuinely different sitting, not something being shadowed.

**`journal:write` is not idempotent.** Run it twice and every entry is written again under a `-2`
suffix. Nothing is overwritten — the collision logic holds — but you get a duplicate set.
Do not put it inside a command substitution to count lines. (Recovery, if it happens: a double-write
duplicate shares its `# title` with the file it shadows, whereas a legitimate `-2` has a base with a
different title and a different `source:`.)

## Vault conventions worth knowing

- Entries go in `journal/`, images in `attachments/`. `ObsidianExporter#copy_images` writes images to
  `journal/` instead; Obsidian resolves `![[...]]` by vault-wide search so this goes unnoticed, but it
  leaves the images somewhere the vault does not expect.
- The vault mixes `voice`, `daily-note` and `handwritten-ocr` entries **on the same dates**. A date
  collision is normally a different medium, not a duplicate — suffix, never overwrite.
- Voice entries are sometimes dictations of the *same* handwritten pages, so they are useful
  corroboration for a disputed date rather than independent evidence.
- Photos are landscape spreads, so one image often holds the end of one entry and the start of the
  next. Two entries legitimately sharing a page index is correct, not a bug.
- `ClaudePostProcessor` is told to "assume recent past if ambiguous" when a page states no year. That
  is what produced a run of entries misfiled a year early. Pass `year_hint`.

## Shell traps that cost time here

- `seq -w` pads to the largest value's width; use `seq -f "%03g"`.
- `-[0-9]+\.md$` matches the *day* component of every `YYYY-MM-DD.md` filename. Twice mistaken for a
  suffix pattern. Use `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]+\.md$`.
- `head` on a pipe can SIGPIPE a `tee` and silently truncate the file you were writing.
- zsh parses `$var[...]` as an array subscript — breaks `grep "$name[^.]*"`. Use Ruby.
- BSD `sed` has no `\b`. Use Ruby for word-boundary replacements.
- Wide `.{0,N}` context greps hit ugrep's complexity limit on UTF-8 text.
