# Quarto Basics for New Authors

## What Is a `.qmd` File?

A Quarto Markdown (`.qmd`) file is a plain text document that combines three things:

1. **YAML header** — metadata at the top of the file, fenced by `---`, that controls the document title, author, date, and rendering options.
2. **Markdown** — prose written using standard Markdown syntax (headings, lists, bold, italic, links, tables).
3. **Code chunks** — executable code blocks delimited by triple backticks and a language label (e.g., ` ```{r} ` or ` ```{stata} `).

A minimal chapter looks like this:

```markdown
---
title: "My Chapter"
author: "Jane Doe"
date: today
---

## Introduction

This is prose. You can use **bold**, *italic*, and [links](https://quarto.org).

## Analysis

```{r}
#| label: fig-trend
#| fig-cap: "Trend over time"
library(ggplot2)
ggplot(mtcars, aes(wt, mpg)) + geom_point()
```
```

---

## Headings and Structure

Use `#` for top-level headings (avoid in chapters — the `title:` YAML field handles that), `##` for sections, and `###` for subsections. Quarto automatically numbers sections when `number-sections: true` is set in `_quarto.yml`.

---

## Lists and Tables

**Unordered list:**
```markdown
- Item one
- Item two
```

**Ordered list:**
```markdown
1. First step
2. Second step
```

**Table:**
```markdown
| Column A | Column B |
|----------|----------|
| Value 1  | Value 2  |
```

---

## Cross-References

Quarto supports automatic cross-references for figures, tables, and sections. Labels must start with the appropriate prefix:

- **Figures:** `#| label: fig-name` → reference with `@fig-name`
- **Tables:** `#| label: tbl-name` → reference with `@tbl-name`
- **Sections:** Add `{#sec-name}` after a heading → reference with `@sec-name`

Example:
```markdown
See @fig-trend for the trend and @tbl-summary for summary statistics.
```

---

## Citations

Add citations using `[@key]` syntax, where `key` matches an entry in `references.bib`:

```markdown
Self-reliance is defined in the literature [@unhcr2019; @worldbank2021].
```

To add a reference, open `references.bib` and add a BibTeX entry:

```bibtex
@report{unhcr2019,
  author = {{UNHCR}},
  title  = {Refugee Self-Reliance Initiative},
  year   = {2019}
}
```

---

## `quarto preview` vs `quarto render`

| Command | What it does |
|---|---|
| `quarto preview` | Opens a live browser preview; re-renders on save. Use during writing. |
| `quarto render` | Renders the full book to `docs/`. Use before committing. |

---

## How `freeze: auto` Works

The `_quarto.yml` file sets `freeze: auto`. This means:

- The first time you render, Quarto executes all code chunks and stores their outputs in the `_freeze/` folder.
- On subsequent renders, Quarto only re-executes a chunk if its source code has changed.
- The `_freeze/` folder **must be committed** to the repository so that the GitHub Actions CI runner — which does not have Stata installed — can render the book using your pre-computed outputs.

**Important:** If you modify a Stata chunk, always run `quarto render` locally before pushing, then commit both the `.qmd` file and the updated `_freeze/` folder together.
