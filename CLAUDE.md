# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

An R-based song management and publishing system. It takes raw song text files with chord annotations, transposes them to all 12 musical keys, and generates HTML and PDF output for web publishing and print.

## Running the Pipeline

There are no build tools — run R scripts directly:

```r
source("make-html.R")    # Generate HTML output → output_html/
source("make-pdfs.R")    # Generate PDF output → output_git/
```

PDF layout is controlled by sourcing one of the setup files before `make-pdfs.R`:
- `setup-withchords_normal-16x9.R` — with chords, 16:9 landscape
- `setup-withchords_normal-16x10.R` — with chords, 16:10 landscape
- `setup-nochords_normal-16x9.R` — lyrics only, 16:9 landscape

External dependencies: `knitr`, `pdflatex`, `gdown`, `docx2txt`, `lilypond` (provides the `lilypond` binary; also bundles `midi2ly`, though we use our own patched copy — see below), ImageMagick (`convert`).

## Architecture

**Data flow:**

```
songs/*.txt
  → functions/process_songs.R     (detect/tag chord lines)
  → cache/songsprocessed/
  → functions/transpose.R         (generate 12 transpositions)
  → cache/songsprocessedTransposed/
  → make-html.R / make-pdfs.R     → output_html/ / output_git/
```

**Key functions in `functions/`:**

| File | Role |
|------|------|
| `process_songs.R` | Tags which lines are chord lines vs. lyric lines |
| `transpose.R` | Rotates through 12 semitones using symbol substitution |
| `makeit_pdfs.R` | LaTeX compilation with layout options |
| `html_make_index.R` | Generates HTML index pages |
| `read_from_google_drive.R` | Downloads songs from Google Drive |
| `getnm.R`, `add.R`, `postfix.R` | File naming and song formatting helpers |
| `midi_to_score.R` | Finds score-image tags in `songs/*.txt` and renders the referenced `.mid` → cropped notation-image PNGs in `output_midiscores/` |

**HTML output** uses `templates/html/` — each song page embeds all 12 transpositions with CSS classes (`chordline no0`…`chordline no11`); `script.js` switches between them client-side.

**Short note scores:** drop a `.mid` file in `songs/midi/`, then reference it from a song's `.txt` with a markdown image tag: `![Tema](midi/song_tema.mid)` (path relative to `songs/`). An optional `[N]` suffix — e.g. `![Tema](midi/song_tema.mid)[2]` — splits the rendering into N score lines of roughly equal length (via LilyPond's `system-count`); omitting it renders one line. `render_scores()` (called from `make-html.R`) scans every `songs/*.txt` for these tags and, for each distinct `(file, N)` pair referenced, converts it into a cropped PNG in `output_midiscores/` (repo root, alongside `output_html/`/`output_pdf/`) via `functions/vendor/midi2ly` (`.mid`→`.ly`) → `lilypond` (`.ly`→`.png`) → `convert -trim` (autocrop), skipping renders that are already up to date. `makeit_html.R` turns the tag into an `<img class="score">`; `make-pdfs.R` drops the tag line entirely (scores are HTML-only). Despite the `output_` prefix, `output_midiscores/*.png` **are** committed to the repo (`.gitignore` carves out `!/output_midiscores` from the general `/output*` rule) — CI does **not** install lilypond, it just ships whatever's already committed there (copied into `output_html/midiscores/` during the HTML build), so always run `make-html.R` locally after adding/changing a `.mid` or its `[N]` tag and commit the resulting PNG alongside it. `functions/vendor/midi2ly` is a one-line-patched copy of the system script (upstream divides with `/` instead of `//`, which crashes under Python 3) — always invoke that vendored copy, not a system `midi2ly`.

**Publishing:** The whole project lives in the GitHub repo `pederbacher/songs`. On push, `.github/workflows/deploy.yml` reruns `make-html.R` headless (`SANGE_NO_SERVER_RESTART=1`, base R only — no pdflatex) and deploys `output_html/` to GitHub Pages via the Actions artifact. Pages **must** be set to *Build and deployment → Source: GitHub Actions* in repo settings. `output_html/` is generated in CI and need not be committed. (The legacy `output_git/` local-clone push flow in the `if(FALSE)` block of `make-html.R` is superseded.)

**Browser editing without the local server:** The editor in `templates/html/script.js` and `toc-script.js` is dual-mode. On `localhost` it uses the `server.py` endpoints. On the deployed Pages site it reads/commits the raw `.txt` straight to the repo via the GitHub Contents API, using a fine-grained PAT (`Contents: Read and write`, single repo) that the user pastes once — stored only in their browser's `localStorage` (`gh_token`). A commit triggers the deploy workflow, so the site rebuilds automatically (~1–2 min). The "Rebuild" button becomes "Build" and opens the Actions page. Repo coordinates are the `GH` const at the top of both JS files.

## Song File Format

Files are named `Artist___SongTitle.txt` (triple underscore). Chord lines contain only chord symbols (`C`, `Am`, `F#`, `Db`, etc.) and are automatically detected. Section markers like `[Verse 1]` and `[Chorus]` are supported.

## Collections

Collection files (`songs/collection-*.txt`) list song filenames for a specific set (e.g., `collection-roskilde_2026.txt`). The PDF scripts use these to build curated songbooks.

## PDF Layout Notes

From `read.me`: when mixing landscape and portrait pages, set `landscape=TRUE` on each `addsong()` call individually. Setting it globally only works if all pages share the same orientation.
