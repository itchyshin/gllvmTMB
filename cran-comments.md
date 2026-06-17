# cran-comments

> **Draft (2026-06-16).** First CRAN submission of `gllvmTMB`. The PDF-manual
> Unicode warning, DOI notes, and Julia bridge namespace note exposed by earlier
> checks have been **fixed on this branch** (see "R CMD check results" below).
> A final release-branch `--as-cran` rerun is still required before submission.
> `cran-comments.md` is listed in `.Rbuildignore`, so it is not part of the built
> package.

## Submission

This is a **new submission** — `gllvmTMB` is not yet on CRAN.

## Test environments

* local: macOS (Apple), R 4.5.2 — `devtools::check(args = "--no-manual")`
* GitHub Actions (recommended before submit): ubuntu-latest / macos-latest /
  windows-latest, R release + devel

## R CMD check results

The earlier `--as-cran` run (NAMESPACE/man regenerated so the `engine = "julia"`
bridge exports register) reported **0 errors | 2 warnings | 3 notes**. The
current draft branch check at PR #489 head `b0fe50a` reports
**0 errors | 1 warning | 1 note**:

```r
GLLVM_JL_PATH='' Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = FALSE, error_on = "never")'
```

GitHub Actions R-CMD-check on `ubuntu-latest` also passes at `b0fe50a`.

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
2. *NEWS.md* — R cannot extract version info from the topic-style `##` section
   titles. Pre-existing; reorganise under version headers or explicitly accept
   the NOTE in the final submission.
3. *Non-standard file* `gllvmTMB-manual.tex` — was a leftover artifact of the
   earlier failed PDF build; resolved now that the PDF manual builds.
4. *R code namespace note* — **FIXED.** The Julia bridge S3 methods now import
   `stats::coef`, `stats::fitted`, and `stats::setNames`; the current check has
   `checking R code for possible problems ... OK`.

**Submission readiness:** branch evidence is now 0 errors with only the known
local compiler warning and the NEWS heading NOTE. Remaining before submit: a
final release-branch `--as-cran` rerun, including CRAN incoming checks, and a
maintainer decision on the pre-existing NEWS.md NOTE (reorganise vs accept).

## Downstream dependencies

There are currently no downstream dependencies (new submission; `gllvmTMB` is not
yet on CRAN).
