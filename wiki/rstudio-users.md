# Using RStudio (Alternative to Positron)

This project recommends **Positron** as the IDE. If you are already comfortable with
RStudio and prefer to keep using it, everything will still work — the steps are nearly
identical. This document notes where things differ.

---

## Installation

Download RStudio Desktop (free) from https://posit.co/download/rstudio-desktop/ and
run the installer. You still need R installed separately from
https://cran.r-project.org/bin/windows/base/.

---

## Opening the Project

After cloning the repository, open RStudio and go to **File → Open Project**, then
select the `50by30-data` folder. If a `.Rproj` file exists in the folder, you can also
double-click it directly.

---

## Running Terminal Commands

In RStudio, the terminal is in the **bottom-left pane** under the **Terminal** tab
(next to the Console tab). All `git` and `quarto` commands in this guide work there
exactly as written.

---

## Installing R Packages

Open the **Console** tab (bottom-left) and run:

```r
install.packages(c("tidyverse", "haven", "knitr", "gt", "ggplot2", "scales", "here"))
```

---

## Everything Else

All other instructions in the wiki — writing chapters, running `quarto preview`,
committing with Git, the Stata freeze workflow — are identical whether you use
Positron or RStudio. Follow the main guides as written.

| Guide | Applies to RStudio? |
|---|---|
| `wiki/contributing.md` | Yes — substitute "Positron Terminal" with "RStudio Terminal" |
| `wiki/quarto-basics.md` | Yes — fully identical |
| `wiki/r-and-stata-usage.md` | Yes — fully identical |
| `wiki/tachyons-guide.md` | Yes — fully identical |
| `wiki/renv-guide.md` | Yes — fully identical |
