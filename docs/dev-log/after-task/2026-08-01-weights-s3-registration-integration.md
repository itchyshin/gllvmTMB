# After Task: Integrate the qualified `stats::weights` S3 registration

## 1. Goal

Replay the verified `weights.gllvmTMB_va` namespace repair from `c27f118a`
onto current `origin/main` (`0b898266`), preserve the complete live-validation
receipts, reconcile PR #882's append to `docs/dev-log/check-log.md`, and open a
focused pull request after package-level validation. The lane excludes spatial
convergence policy, tolerances, snapshots, AGHQ, scale-start work, and Poisson
VA-09.

## 2. Implemented

`R/va-methods.R` now declares `@exportS3Method stats::weights`, and the generated
`NAMESPACE` registers `S3method(stats::weights,gllvmTMB_va)`. This allows the
installed package namespace to load when only base is attached while preserving
the deliberate error returned by `stats::weights()` for a variational fit.

The historical live-validation after-task report and plan-vs-actual report were
replayed without rewriting them. The check-log conflict was resolved append-only:
PR #882's pkgdown entry remains first, followed by the live-validation entry and
this integration receipt.

### Mathematical Contract

No public method signature, return value, likelihood, formula grammar, family,
estimand, optimizer, tolerance, snapshot, generated Rd topic, vignette, or
pkgdown navigation changed. The patch changes only S3 registration metadata for
the existing `stats::weights()` generic and existing `gllvmTMB_va` method.

## 3a. Decisions and Rejected Alternatives

- **Decision**: replay the validated commit onto a fresh branch from current
  `origin/main`. **Rationale**: the primary checkout is dirty and owned by the
  profile lane, while PR #882 moved main after the diagnostic arc. **Rejected
  alternative**: rebase or edit the dirty primary checkout. **Confidence**: high.
- **Decision**: retain both check-log tails in chronological order. **Rationale**:
  both are true, non-overlapping receipts. **Rejected alternative**: choose one
  side of the conflict or rewrite the historical report. **Confidence**: high.
- **Decision**: report the `--as-cran` snapshot error without accepting it.
  **Rationale**: the same 21,896-byte SVG drift was already classified as
  observational and differs at two character positions/four coordinates by 0.01
  SVG units. **Rejected alternative**: update the snapshot or widen this lane into
  plotting policy. **Confidence**: high about scope; the render cause remains
  unknown.

## 4. Files Touched

- `R/va-methods.R` — qualify the existing S3 method's roxygen registration.
- `NAMESPACE` — roxygen-generated qualified registration.
- `docs/dev-log/after-task/2026-08-01-current-main-live-validation.md` — preserved
  evidence from the preceding diagnostic arc.
- `docs/dev-log/plan-actual/2026-08-01-current-main-live-validation.md` — preserved
  plan-vs-actual reconciliation.
- `docs/dev-log/check-log.md` — retain PR #882's append and add the live-validation
  and integration receipts.
- `docs/dev-log/after-task/2026-08-01-weights-s3-registration-integration.md` —
  this integration report.

No README, NEWS, ROADMAP, design, vignette, test, snapshot, generated Rd, C++,
AGHQ, spatial, or VA-09 file changed. `_pkgdown.yml` already contains the VA
methods topic through merged PR #882 and was not duplicated here.

## 5. Checks Run

```sh
TMPDIR=/private/tmp Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Passed. Roxygen regenerated no additional diff; `NAMESPACE` remains the only
generated artefact changed by the repair.

```sh
TMPDIR=/private/tmp R CMD INSTALL \
  --library=/private/tmp/gllvmtmb-weights-s3-lib.GfjkIr .
```

Passed, including load tests from temporary and final installation locations.

```sh
R_DEFAULT_PACKAGES=NULL \
R_LIBS=/private/tmp/gllvmtmb-weights-s3-lib.GfjkIr \
Rscript --vanilla -e \
'ns <- loadNamespace("gllvmTMB"); fit <- structure(list(), class = "gllvmTMB_va"); err <- tryCatch(stats::weights(fit), error = identity); stopifnot(inherits(err, "error"), grepl("not defined for a variational fit", conditionMessage(err), fixed = TRUE))'
```

Passed: base-only namespace loading and qualified `stats::weights()` dispatch.

```sh
TMPDIR=/private/tmp NOT_CRAN=true Rscript --vanilla -e \
'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-va-routing-oracle.R", reporter = "summary")'
```

Passed all 31 expectations.

```sh
TMPDIR=/private/tmp Rscript --vanilla -e 'pkgdown::check_pkgdown()'
```

Passed: `No problems found.`

```sh
env -u GLLVMTMB_HEAVY_TESTS TMPDIR=/private/tmp NOT_CRAN=true \
R CMD build /private/tmp/gllvmtmb-weights-s3-registration-20260801
```

Passed, including vignette creation; produced `gllvmTMB_0.6.0.tar.gz`.

```sh
env -u GLLVMTMB_HEAVY_TESTS TMPDIR=/private/tmp NOT_CRAN=true \
R CMD check --as-cran gllvmTMB_0.6.0.tar.gz
```

The first sandboxed attempt stopped during CRAN incoming feasibility because DNS
could not resolve CRAN or Bioconductor. The retained network-enabled rerun reached
the authoritative result: **1 ERROR, 0 WARNINGs, 1 NOTE**. The sole error was the
pre-existing dispatcher ellipse snapshot at
`test-plot-visual-snapshots.R:301`; the note was `New submission`. Testthat
reported `FAIL 1 / WARN 2 / SKIP 822 / PASS 8032`. Installation, namespace load
and unload, S3 registration and consistency, code checks, Rd, examples,
`--run-donttest`, vignettes, PDF and HTML manuals, and all other tests passed.
The complete log is retained at
`/private/tmp/gllvmtmb-weights-s3-ascran-network-20260801/gllvmTMB.Rcheck/00check.log`.

## 6. Tests of the Tests

No test file changed. Failure-before-fix evidence is preserved in
`2026-08-01-current-main-live-validation.md`: the unqualified baseline failed
base-only namespace loading with `object 'weights' not found`. The repaired
installed package now passes that exact boundary and the existing VA routing
oracle confirms that `stats::weights(fit)` reaches the intentional VA method
error rather than a default method.

The snapshot assertion remained effective: the full check failed on the same
two-character SVG difference. No tolerance or fixture was changed to manufacture
a pass.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row or progress bar changes.

## 7a. Issue Ledger

Targeted open-issue searches for `VA weights S3 namespace registration` and
`variational methods pkgdown` returned no relevant issue. No issue was commented,
closed, or created because this PR repairs packaging metadata without changing a
tracked capability.

## 8. Consistency Audit

```sh
rg -n -C 2 '@exportS3Method stats::weights|weights\.gllvmTMB_va|S3method\(stats::weights,gllvmTMB_va\)' R/va-methods.R NAMESPACE tests/testthat/test-va-routing-oracle.R
```

Verdict: source roxygen, generated namespace registration, method definition, and
the existing oracle agree on the `stats::weights` route.

```sh
rg -n 'S3method\(weights,gllvmTMB_va\)' NAMESPACE
```

Verdict: no unqualified stale registration remains.

```sh
rg -n 'gllvmTMB_va-methods' _pkgdown.yml R/va-methods.R R/gllvmTMB.R man/gllvmTMB_va-methods.Rd
```

Verdict: PR #882's reference index, roxygen topic, cross-reference, and generated
help remain aligned; this PR adds no navigation change.

```sh
git diff --name-only origin/main...HEAD | rg '(^src/|spatial|snapshot|aghq|scale-start|VA-09)'
```

Verdict: no excluded implementation, snapshot, or neighbouring-lane path changed.

Rendered-Rd spot-check: N/A. `devtools::document()` changed no Rd file.

Status inventory: N/A. This is namespace registration for an existing method;
README, NEWS, ROADMAP, known limitations, formula grammar, validation-debt status,
and public capability claims do not move.

## 9. What Did Not Go Smoothly

Cherry-picking the validated commit produced the expected conflict at the tail of
`docs/dev-log/check-log.md` because PR #882 had appended after the diagnostic
baseline. The resolution retained both sections rather than selecting a side.

The first `--as-cran` invocation was not an admissible package result because the
sandbox blocked CRAN/Bioconductor DNS. Rerunning the same tarball with network
access resolved that environment failure. The full rerun then confirmed the
known snapshot error, so this branch is not described as a clean local CRAN check.

## 10. Known Residuals

The branch has not passed a zero-error local `R CMD check --as-cran`: the existing
dispatcher ellipse snapshot remains the sole error.

Next, open the focused pull request and require its three-OS R-CMD-check matrix to
pass before marking it ready for review. Investigate the spatial execution-context
discrepancy and ellipse serialization drift in separate lanes.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept the landing to the already-qualified registration and rejected any
optimizer, tolerance, snapshot, AGHQ, or VA-09 expansion.

**Grace** required a real source tarball, network-enabled CRAN incoming checks,
manual and vignette checks, and a precise `1 ERROR, 0 WARNINGs, 1 NOTE` report
rather than reusing the ordinary check from the diagnostic baseline.

**Rose** required append-only reconciliation, preservation of historical reports,
and language that separates a verified S3 repair from the unresolved visual drift.

**Shannon** identified the dirty primary checkout and foreign PRs before editing;
the new worktree kept this lane disjoint from PRs #877 and #881. The pre-PR
audit returned **WARN** only because PR #877 is currently non-mergeable and this
PR will bring the open-PR count to the soft cap of three; no file collision or
active CI run blocks this push.

## 12. Cross-Product Coverage

This PR does NOT cover the snapshot's cause or acceptance policy, spatial
convergence behavior, profile algorithms, AGHQ/scale-start changes, Poisson VA-09
recovery, interval calibration, or any wider VA capability claim. It covers only
the existing `weights.gllvmTMB_va` method's namespace registration and dispatch.
