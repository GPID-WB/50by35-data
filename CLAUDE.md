# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Quarto **book** (not a package or app) documenting the data pipeline used to harmonize,
upload, review, and publish microdata for monitoring the UNHCR **50by35 vision** (50% of
refugees in protracted crises self-reliant by 2035). The content itself — pipeline steps,
schema definitions, PRIMUS/Datalibweb usage — is the deliverable; there is no application
code to run, only documentation to render.

Rendered output is published via GitHub Pages from `docs/` on `main`.

## Commands

```bash
quarto preview      # live-reload local preview while editing chapters
quarto render        # full render to docs/ (required before committing Stata-chunk changes)
Rscript -e "renv::restore()"   # install pinned R packages, if renv.lock is present
```

There are no tests, linters, or build steps beyond Quarto rendering. There is no `renv.lock`
committed currently — CI installs a standard package set when it's absent (see
`wiki/renv-guide.md`).

## Architecture

### Book structure (`_quarto.yml`)

The book's chapter order and parts are declared in `_quarto.yml`, not inferred from the
filesystem. When adding/removing/reordering chapters, update the `book.chapters` list there
— adding a `.qmd` file under `chapters/` alone has no effect on the rendered book.

Current structure: `index.qmd` → Part "Pipeline" (`01-raw-upload.qmd`, `02-harmonization.qmd`,
`03-harmonized-upload.qmd`, `04-access.qmd`) → Part "Reference" (`05-schema.qmd`).

### The pipeline the book documents

Three real-world stages, each mapped to a chapter:

1. **Upload raw data** (`01-raw-upload.qmd`) — raw microdata uploaded via **PRIMUS**
   (process `FDPRaw-data`, processid 39) unless already on **Datalibweb**. Reviewed/approved
   by a separate approver role before it becomes available for harmonization.
2. **Harmonize data** (`02-harmonization.qmd`) — approved raw data is mapped to the 50by35
   schema (see `05-schema.qmd`).
3. **Upload harmonized data** (`03-harmonized-upload.qmd`) — harmonized data + harmonization
   scripts uploaded via PRIMUS (process `FDP-harmonized-data`, processid 40), validated
   against the schema, then reviewed/approved for publication to Datalibweb.
4. **Access data** (`04-access.qmd`) — approved data accessed from Datalibweb: collections
   `FDPRAW` (raw) and `FDP` (harmonized, module `WELF`), via the `datalibweb` Stata package
   or the `dlw` R package.

Chapters show parallel R and Stata examples in `::: {.panel-tabset}` blocks, since either
client can drive the same APIs. **When editing one language's example, check whether the
same procedure needs updating in the other tab and in the corresponding step of the other
upload chapter** — the raw-upload and harmonized-upload chapters share near-duplicate
review/approval code blocks that must stay in sync with their respective process names/IDs.
Working example scripts live in `Stata/` (harmonization + PRIMUS steps + validation) and
`R/` (PRIMUS steps + validation) — keep chapter code blocks consistent with those scripts.

### Schema (`05-schema.qmd`)

Defines the harmonized `.dta` file contract: one row per individual, mandatory vs. optional
variables, Stata storage types, allowed missingness, and value-label codes. This is the
authoritative reference other chapters point to — validation rules described in
`03-harmonized-upload.qmd` (missing mandatory vars, `welfare_self <= welfare`, `hhsize`
consistency with `pid` counts per `hhid`) must match what's documented here. The schema is
explicitly marked as a **working draft** pending sign-off from the 50by35 methodology team.

### Stata/R execution model

- `execute: freeze: auto` in `_quarto.yml` means code chunks are cached in `_freeze/` and only
  re-executed when source changes.
- CI (`.github/workflows/publish.yml`) has **no Stata license**, so any `.qmd` with a Stata
  chunk must be rendered locally (`quarto render`) and its `_freeze/` output committed
  alongside the source change, or the CI build fails on that chunk.
- Shared helper code lives in `R/utils.R` and `Stata/utils.do` — add cross-chapter helpers
  there rather than duplicating in individual chapters.

### Wiki vs. chapters

`wiki/` holds contributor-facing setup/process docs (Quarto basics, R/Stata configuration,
renv, contributing workflow) — it is not part of the rendered book (`_quarto.yml` doesn't
reference it) and is linked to from `index.qmd`/`README.md` as plain GitHub markdown. Keep
new contributor documentation there, not in `chapters/`. Cross-check links between wiki pages
when renaming or removing files — they reference each other by relative path and Quarto does
not validate those links at build time.