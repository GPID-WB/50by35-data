# R and Stata Usage Guide

Instructions are written for **Windows** users. macOS notes are included where steps differ.

---

## R Code Chunks

R code chunks are delimited with ` ```{r} ` and support Quarto chunk options prefixed with `#|`.

### Annotated example

````markdown
```{r}
#| label: fig-poverty-trend       # unique ID used for cross-referencing
#| fig-cap: "Poverty headcount rate over time"
#| echo: true                     # show source code in the output
#| warning: false                 # suppress warnings

library(tidyverse)

df |>
  ggplot(aes(x = year, y = poverty_rate)) +
  geom_line() +
  labs(x = "Year", y = "Poverty rate (%)")
```
````

### Key chunk options

| Option | Purpose |
|---|---|
| `label` | Unique identifier (required for cross-refs; use `fig-` or `tbl-` prefix) |
| `fig-cap` | Caption for figures |
| `echo` | Show (`true`) or hide (`false`) the source code |
| `eval` | Execute (`true`) or skip (`false`) the chunk |
| `warning` / `message` | Suppress R warnings or messages |
| `cache` | Cache chunk output (prefer `freeze: auto` at project level instead) |

---

## Stata Code Chunks

Quarto runs Stata chunks through knitr and the **`Statamarkdown`** R package
(install once with `install.packages("Statamarkdown")`). Stata must be installed
on your machine and `Statamarkdown` must be able to find it (see below). Load the
package in a setup chunk before the first `{stata}` chunk in each `.qmd`.

### Basic example

````markdown
```{r}
#| include: false
library(Statamarkdown)
```

```{stata}
#| label: tbl-summary
#| echo: true

* Summarize household income
summarize income [aw = weight]
tabulate region
```
````

---

## Configuring Stata on Windows (Primary Setup)

Quarto needs to know where your Stata executable is. There are two ways to do this.

### Option A — Add Stata to your Windows PATH (recommended)

This is a one-time system setting that makes Stata accessible from any terminal.

1. Find your Stata installation folder. Common locations:
   - `C:\Program Files\Stata18\`
   - `C:\Program Files\Stata17\`
   - `C:\Program Files (x86)\Stata16\`

2. Open **Start Menu** and search for **"Edit the system environment variables"**.

3. Click **Environment Variables…**

4. Under **System variables**, select **Path** and click **Edit…**

5. Click **New** and paste the full path to your Stata folder, e.g.:
   ```
   C:\Program Files\Stata18
   ```

6. Click **OK** on all dialogs to save.

7. **Restart** any open terminals or Positron for the change to take effect.

8. Verify it works by opening Command Prompt and running:
   ```
   stata /e display 1
   ```
   If Stata runs without an error, you're good.

   > **macOS:** the executable is named after your edition (`stata-mp`, `stata-se`,
   > or `stata-be`). Verify with:
   > ```bash
   > stata-mp -q -b -e "display 1"
   > ```

### Option B — Set the path inside R (per-project)

If you prefer not to modify system settings, set the path in R instead. Add this line
at the top of any `.qmd` file that contains Stata chunks, inside an R setup chunk:

````markdown
```{r}
#| include: false
Statamarkdown::stata_engine_path("C:/Program Files/Stata18/StataSE-64.exe")
```
````

Or set it once for the whole project in your `.Rprofile` file (in the project root):

```r
# .Rprofile
Statamarkdown::stata_engine_path("C:/Program Files/Stata18/StataSE-64.exe")
```

Adjust the filename to match your Stata edition:

| Stata edition | Executable name |
|---|---|
| Stata/MP | `StataMP-64.exe` |
| Stata/SE | `StataSE-64.exe` |
| Stata/IC | `Stata-64.exe` |
| Stata/BE | `StataBE-64.exe` |

> **macOS:** Add Stata to PATH in `~/.zshrc` (adjust `StataMP` to your edition),
> then restart open terminals:
> ```bash
> export PATH="/Applications/Stata/StataMP.app/Contents/MacOS:$PATH"
> ```
> On macOS `Statamarkdown` usually **auto-detects** Stata under `/Applications`
> (loading the package prints `Stata found at …`), so no path setting is needed.
> If detection fails, set it explicitly via
> `Statamarkdown::stata_engine_path("/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp")`.

---

## Installing `Statamarkdown`

The `Statamarkdown` R package is what executes ` ```{stata} ` chunks when Quarto
renders. Install it once in R:

```r
install.packages("Statamarkdown")
```

It finds Stata automatically in the default install locations (`C:/Program Files`
on Windows, `/Applications` on macOS); use `stata_engine_path()` (see Option B
above) only if auto-detection fails.

---

## The Freeze Workflow for Stata

Because Stata requires a paid license, the GitHub Actions CI server cannot execute
Stata code. The project uses `freeze: auto` to handle this: Stata outputs are computed
locally, saved to the `_freeze/` folder, and committed alongside the source files.

**Step-by-step:**

1. **Write or modify** a Stata chunk in a `.qmd` file.

2. **Render the full book locally** in the Positron Terminal (or Git Bash):
   ```bash
   quarto render
   ```

3. **Commit both** the `.qmd` file and the updated `_freeze/` folder:
   ```bash
   git add chapters/your-chapter.qmd _freeze/
   git commit -m "feat: add Stata summary table for indicator X"
   git push
   ```

4. GitHub Actions renders the book using the committed frozen outputs — no Stata
   license needed on the server.

> If you forget to commit `_freeze/`, the CI build will fail on Stata chunks.

---

## Reading Stata `.dta` Files into R

Use the `haven` package to read Stata data files directly into R:

```r
library(haven)

df <- read_dta("data/raw/household_survey.dta")

# haven preserves Stata value labels — convert to R factors
df <- df |>
  haven::as_factor()

head(df)
```

To write a processed dataset back to `.dta` format:

```r
write_dta(df_processed, "data/processed/household_clean.dta")
```

`haven` preserves variable labels, value labels, and Stata data types, making it the
recommended bridge between R and Stata workflows.
