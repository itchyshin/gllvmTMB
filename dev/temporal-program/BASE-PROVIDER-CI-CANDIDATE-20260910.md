# Base temporal provider: local CI candidate

## Candidate boundary

The review candidate is commit `f227e7801c49593209dc56d4a50a1964453d76aa`
on local branch `codex/temporal-base-review-20260910`, in the isolated worktree
`/private/tmp/gllvmTMB-temporal-base-review-20260910`.

It contains the native temporal provider and its unconditional-simulation
repair. It intentionally ends before every temporal source-pair and temporal
lifecycle helper commit. The larger programme branch is not an appropriate
single CI/release candidate: it contains later, independently scoped source
pairs and forecast/profile/bootstrap/selection routes with their own gates.

## Local verification

On 2026-09-10, on macOS arm64 with R 4.6.0, this clean worktree passed:

```sh
Rscript --vanilla dev/temporal-ar1/verify.R parser
Rscript --vanilla dev/temporal-ar1/verify.R oracle
Rscript --vanilla dev/temporal-ar1/verify.R methods
Rscript --vanilla dev/temporal-ar1/verify.R regression
```

The commands emitted, respectively, `TEMPORAL_PARSER_PASS`,
`TEMPORAL_ORACLE_PASS`, `TEMPORAL_METHODS_PASS`, and
`TEMPORAL_REGRESSION_PASS`. The regression gate also completed its pkgdown
check and rendered the temporal article. The worktree was clean before and
after the commands.

The same candidate completed a retained local source-package check:

```sh
R CMD build .
R CMD check --as-cran --no-manual gllvmTMB_0.7.1.tar.gz
```

On macOS arm64 / R 4.6.0, installation, compilation, examples,
documentation, vignette rebuilding, and the full test suite passed. The check
returned one CRAN incoming NOTE because `README.md` links to the temporal
article at the public pkgdown URL, which is intentionally still a 404 until a
future deployment. This local-only candidate has not been deployed; the NOTE
is retained rather than suppressed. The full log is retained locally at
`/private/tmp/temporal-base-check-20260910/check/gllvmTMB.Rcheck/00check.log`.

## What this does and does not authorize

This is a local review boundary and macOS evidence only. It does not supply
Linux or Windows verification, a pull request, merge, release, recovery or
interval-coverage claim. It does not include the temporal source-pair or
lifecycle routes.

The next publication action, if explicitly authorised, is to push this exact
branch unchanged for three-OS CI, inspect the CI receipts, and only then decide
whether a base-provider pull request is reviewable. No push, pull request,
merge, or release occurred while creating this candidate.
