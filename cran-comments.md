# cran-comments

> **Draft (2026-07-09) — gllvmTMB 1.0.0.** First CRAN submission of `gllvmTMB`.
> A fresh local `--as-cran` run on this release branch is **clean: 0 errors,
> 0 warnings, 0 notes** (see "R CMD check results" below). The earlier PDF-manual
> Unicode warning, DOI notes, Julia bridge namespace note, unused-import note,
> NEWS heading note, and an undeclared test dependency have all been resolved.
> `cran-comments.md` is listed in `.Rbuildignore`, so it is not part of the built
> package.

## Submission

This is a **new submission** — `gllvmTMB` is not yet on CRAN.

## Test environments

* local: macOS (Apple), R 4.6.0 — `devtools::check(args = "--as-cran")`
* GitHub Actions (recommended before submit): ubuntu-latest / macos-latest /
  windows-latest, R release + devel

## R CMD check results

A fresh local `--as-cran` run on the 1.0.0 release branch reports
**0 errors | 0 warnings | 0 notes**:

```r
Rscript -e 'devtools::check(args = c("--as-cran", "--no-tests", "--no-build-vignettes"), error_on = "never")'
# Status: OK  (0 errors | 0 warnings | 0 notes)
```

(`--no-tests` / `--no-build-vignettes` keep the structural check fast; the test
suite and vignettes are exercised separately by the GitHub Actions
R-CMD-check matrix.) On CRAN's incoming feasibility checks a single "New
submission" NOTE is expected.

The items below were flagged by earlier checks and are now **all resolved**;
they are retained here as a record of what changed.

**Warnings**

1. *Install warning* — Apple-clang `unknown warning group '-Wfixed-enum-extension'`
   from `R_ext/Boolean.h`. Toolchain noise local to this macOS clang; not a package
   defect and not expected on CRAN's runners.
2. *PDF manual* — **FIXED.** The LaTeX-breaking Greek letters were ASCII-ised in
   the `.Rd` sources (commit `93640b7`). Verified: `R CMD Rd2pdf` builds the full
   reference manual with no `inputenc`/Unicode/LaTeX errors.

**Notes**

1. *CRAN incoming feasibility* — "New submission" (expected). The DOI sub-notes
   are **FIXED**: the bioRxiv DOI was corrected to the registered
   `10.64898/2025.12.20.695312` (the old `10.1101/...` prefix did not resolve);
   the Felsenstein (2005) reference was corrected — its title belongs to *Phil.
   Trans. R. Soc. B* **360**:1427–1434, `10.1098/rstb.2005.1669`, not the
   non-resolving `Genetics`/`10.1534/genetics.104.025262` that was cited; and the
   three `\doi{}`-form URLs in `diag_re.Rd` / `spde.Rd` were converted from
   `\url{https://doi.org/...}` to `\doi{}`. All five DOIs were confirmed to
   resolve via `doi.org`.
2. *NEWS.md* — **FIXED.** R could not extract version info because the top
   section header was `# gllvmTMB (development version)` (no version), which
   made the parser fall back to the dated `##` topic sub-headers. Naming the
   release section `# gllvmTMB 1.0.0` gives the parser a version and the
   sub-headers are read as subsections; `tools:::.build_news_db_from_package_NEWS_md()`
   now parses clean.
3. *Non-standard file* `gllvmTMB-manual.tex` — was a leftover artifact of the
   earlier failed PDF build; resolved now that the PDF manual builds.
4. *R code namespace note* — **FIXED.** The Julia bridge S3 methods now import
   `stats::coef`, `stats::fitted`, and `stats::setNames`; the current check has
   `checking R code for possible problems ... OK`.

**Submission readiness:** the local `--as-cran` structural check is clean
(0/0/0). Remaining before submit: a full GitHub Actions `R-CMD-check` matrix run
(3-OS, with tests and vignettes) and a final `--as-cran` including CRAN incoming
feasibility, where the only expected note is the standard "New submission".

## Downstream dependencies

There are currently no downstream dependencies (new submission; `gllvmTMB` is not
yet on CRAN).
