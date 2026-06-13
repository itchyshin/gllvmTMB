# cran-comments

> **Draft (2026-06-13).** First CRAN submission of `gllvmTMB`. The check results
> below are from an actual `--as-cran` run on this branch (with the bridge exports
> registered); the two gating items are flagged. `cran-comments.md` is listed in
> `.Rbuildignore`, so it is not part of the built package.

## Submission

This is a **new submission** — `gllvmTMB` is not yet on CRAN.

## Test environments

* local: macOS (Apple), R 4.5.2 — `rcmdcheck::rcmdcheck(args = "--as-cran")`
* GitHub Actions (recommended before submit): ubuntu-latest / macos-latest /
  windows-latest, R release + devel

## R CMD check results

Ran `--as-cran` on this branch (NAMESPACE/man regenerated so the `engine = "julia"`
bridge exports register): **0 errors | 2 warnings | 3 notes**.

**Warnings**

1. *Install warning* — Apple-clang `unknown warning group '-Wfixed-enum-extension'`
   from `R_ext/Boolean.h`. Toolchain noise local to this macOS clang; not a package
   defect and not expected on CRAN's runners.
2. *PDF manual* — **must fix before submission.** LaTeX cannot typeset the Greek
   letters (Σ, σ, ε, Λ) used in several `.Rd` files, so the PDF reference manual
   fails to build. 34 of 131 man pages carry non-ASCII characters; the
   LaTeX-breaking ones are the Greek symbols. Fix in the roxygen sources
   (e.g. `\eqn{\sigma}` / `\eqn{\Sigma}`, or ASCII names) and re-`document()`.

**Notes**

1. *CRAN incoming feasibility* — "New submission" (expected). Also flags 2 invalid
   DOIs (404: `10.1101/2025.12.20.695312`, `10.1534/genetics.104.025262` in
   `compare_dep_vs_two_psi.Rd` / `compare_indep_vs_two_psi.Rd`) and 3 URLs that
   should use `\doi{}` (`diag_re.Rd`, `spde.Rd`) — fix before submit.
2. *NEWS.md* — R cannot extract version info from the topic-style `##` section
   titles. Pre-existing; reorganise under version headers or accept the NOTE.
3. *Non-standard file* `gllvmTMB-manual.tex` — a leftover artifact of the failed
   PDF build; disappears once the Unicode issue (Warning 2) is fixed.

**Submission readiness:** 0 errors. The PDF-manual Unicode (Warning 2) and the
invalid DOIs (Note 1) are the gating items; the install warning is environmental.

## Downstream dependencies

There are currently no downstream dependencies (new submission; `gllvmTMB` is not
yet on CRAN).
