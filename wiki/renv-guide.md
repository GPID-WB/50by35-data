# Managing R Packages: renv (Optional)

## What Is renv?

`renv` is an R package that records exactly which packages — and which versions — your
project uses, saving that information in a file called `renv.lock`. Anyone who clones
the repository and runs `renv::restore()` gets the exact same package versions you had
when you wrote the code.

**You do not need to use renv to contribute to this book.** The CI runner will install
a standard set of packages automatically if no `renv.lock` is present. This guide is
for teams that want stricter reproducibility.

---

## Why You Might Want It

- Your code breaks when a package updates and you want to pin versions.
- You want to guarantee that every collaborator (and the CI server) uses identical
  package versions.
- The project is long-lived and you want to protect it from future upstream changes.

## Why You Might Skip It

- You are the only author, or all authors keep their R installations current.
- The book leans heavily on `freeze: auto` (frozen Stata/R outputs), so the CI server
  rarely needs to re-execute code anyway.
- You find the extra workflow steps more confusing than helpful.

---

## One-Time Setup (if you decide to use renv)

Run this once from the project root in R:

```r
install.packages("renv")
renv::init()

# Install the packages your chapters need, then snapshot:
install.packages(c("tidyverse", "haven", "knitr", "gt", "ggplot2", "scales", "here"))
renv::snapshot()
```

Commit the resulting `renv.lock` file:

```bash
git add renv.lock
git commit -m "chore: add renv lockfile"
git push
```

From this point on, the CI runner will automatically detect `renv.lock` and use it.

---

## Day-to-Day Usage

**Restoring packages** (e.g., after cloning on a new machine):
```r
renv::restore()
```

**After installing a new package** you need in a chapter:
```r
install.packages("newpackage")
renv::snapshot()   # updates renv.lock — commit this file
```

**Checking for drift** between your installed packages and `renv.lock`:
```r
renv::status()
```

---

## Opting Out Later

If the project is already using `renv` and you want to stop:

### 1. Deactivate renv in the project
```r
renv::deactivate()
```
This removes the `renv/` auto-loader from `.Rprofile` but leaves `renv.lock` in place
as a historical record (harmless).

### 2. Remove renv files from the repository
```bash
# Remove the renv infrastructure folder and lockfile
git rm -r renv/
git rm renv.lock

# The .Rprofile may have been modified by renv — check it
# If it only contains renv content, remove it too:
git rm .Rprofile
```

### 3. Commit and push
```bash
git commit -m "chore: remove renv, revert to direct package installation"
git push
```

Once `renv.lock` is gone, the CI runner automatically falls back to installing packages
directly (see step 5b in the workflow file).

### 4. Reinstall packages normally
Other contributors can now just install packages with `install.packages()` as usual,
without any `renv::restore()` step.

---

## Summary

| | With renv | Without renv |
|---|---|---|
| Setup effort | A few extra commands | None |
| Reproducibility | Exact version pinning | Latest CRAN versions |
| CI behavior | Restores from `renv.lock` | Installs a standard set of packages |
| Recommended when | Long-lived project, multiple authors, version-sensitive code | Simple project, active development, few dependencies |
