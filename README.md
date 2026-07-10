# 50by35 Microdata Pipeline

This repository contains the Quarto book documenting the data pipeline used to **upload, harmonize, and review** microdata used to monitor the UNHCR **50by35 vision**: that 50 percent of refugees in protracted crises are self-reliant by 2035.

## Live Book

The rendered book is available at:
**https://GPID-WB.github.io/50by35-data/**

## Repository Structure

| Folder/File | Purpose |
|---|---|
| `chapters/` | Book chapters as `.qmd` files |
| `R/` | R scripts and functions |
| `Stata/` | Stata do-files |
| `data/raw/` | Raw data (not committed) |
| `data/processed/` | Processed/derived data (not committed) |
| `wiki/` | Contributor guides and documentation |
| `.github/workflows/` | CI/CD pipeline for GitHub Pages |

## Quick Start for Contributors

See the **[`wiki/contributing.md`](wiki/contributing.md)** file for full setup instructions, including how to install Quarto, R, Stata, and how to write and preview chapters.

## Prerequisites

- [Quarto](https://quarto.org/docs/get-started/) ≥ 1.4
- R ≥ 4.4 and the packages in `renv.lock` (install via `renv::restore()`)
- Stata (any recent version) — required only if you are authoring or modifying Stata chunks
- Git

## Local Preview

```bash
# Clone the repo
git clone https://github.com/GPID-WB/50by35-data.git
cd 50by35-data

# Install R packages
Rscript -e "renv::restore()"

# Preview the book (live reload)
quarto preview

# Full render
quarto render
```

The rendered book will appear in `docs/`.
