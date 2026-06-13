# cran-comments

> **Draft scaffold (2026-06-13).** This file is a starting point for the first
> CRAN submission of `gllvmTMB`. The maintainer must run the check locally and
> fill the results section before submitting — see the TODO markers. `cran-comments.md`
> is listed in `.Rbuildignore`, so it is not part of the built package.

## Submission

This is a **new submission** — `gllvmTMB` is not yet on CRAN.

## Test environments

* local: macOS, R <version> (maintainer)
* GitHub Actions: <CI matrix actually run, e.g. ubuntu-latest / macos-latest /
  windows-latest, R release + devel>

## R CMD check results

<!--
TODO (maintainer): paste the actual `rcmdcheck::rcmdcheck(args = "--as-cran")`
tally below before submitting. Clear these first:

  1. Regenerate NAMESPACE/man so the `engine = "julia"` bridge exports register
     (issue #483) — otherwise `--as-cran` will NOTE undocumented/unregistered
     objects (gllvm_julia_setup, gllvm_julia_fit, and the S3 methods
     logLik.gllvmTMB_julia / print.gllvmTMB_julia).

  2. Decide release scope for the bridge. It currently lives on the `engine-julia`
     branch (5 commits ahead of `main`, which it is also behind on the recent
     unique-removal docs). Reconcile engine-julia <-> main and decide whether the
     first release ships `engine = "julia"` (mark gllvm_julia_setup / gllvm_julia_fit
     as experimental) or holds it on-branch.

  3. Confirm JuliaCall is Suggests-only and all `engine = "julia"` tests/examples
     skip cleanly when Julia is absent, so CRAN machines without Julia pass.
-->

0 errors | 0 warnings | <N> notes

* As a new submission, expect the standard *"New submission"* NOTE. Document any
  others here.

## Downstream dependencies

There are currently no downstream dependencies (new submission; `gllvmTMB` is not
yet on CRAN).
