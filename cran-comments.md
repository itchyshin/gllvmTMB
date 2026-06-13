# cran-comments

> **Draft (2026-06-13).** First CRAN submission of `gllvmTMB`. The two gating
> items from the earlier `--as-cran` run — the PDF-manual Unicode warning and the
> DOI notes — have both been **fixed on this branch** (see "R CMD check results"
> below); a final `--as-cran` re-run is recommended to confirm the clean tally
> before submission. `cran-comments.md` is listed in `.Rbuildignore`, so it is not
> part of the built package.

## Submission

This is a **new submission** — `gllvmTMB` is not yet on CRAN.

## Test environments

* local: macOS (Apple), R 4.5.2 — `rcmdcheck::rcmdcheck(args = "--as-cran")`
* GitHub Actions (recommended before submit): ubuntu-latest / macos-latest /
  windows-latest, R release + devel

## R CMD check results

The earlier `--as-cran` run (NAMESPACE/man regenerated so the `engine = "julia"`
bridge exports register) reported **0 errors | 2 warnings | 3 notes**. The two
gating items have since been fixed on this branch; the post-fix expectation is
**0 errors | 1 (environmental) warning | 1–2 notes**.

**Warnings**

1. *Install warning* — Apple-clang `unknown warning group '-Wfixed-enum-extension'`
   from `R_ext/Boolean.h`. Toolchain noise local to this macOS clang; not a package
   defect and not expected on CRAN's runners.
2. *PDF manual* — **FIXED.** The LaTeX-breaking Greek letters were ASCII-ised in
   the `.Rd` sources (commit `93640b7`). Verified: `R CMD Rd2pdf` builds the full
   145-page reference manual with no `inputenc`/Unicode/LaTeX errors.

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
   titles. Pre-existing; reorganise under version headers or accept the NOTE.
3. *Non-standard file* `gllvmTMB-manual.tex` — was a leftover artifact of the
   earlier failed PDF build; resolved now that the PDF manual builds.

**Submission readiness:** 0 errors; the Unicode warning and the DOI notes are
fixed. Remaining before submit: a final `--as-cran` re-run to confirm the clean
tally, and a decision on the pre-existing NEWS.md NOTE (reorganise vs accept).

## Downstream dependencies

There are currently no downstream dependencies (new submission; `gllvmTMB` is not
yet on CRAN).
