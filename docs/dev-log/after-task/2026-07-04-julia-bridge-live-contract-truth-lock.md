# After Task: Julia Bridge Live Contract Truth-Lock

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Hopper / Fisher / Grace / Rose / Shannon`

## 1. Goal

Clear the local checkout for cloud-work readiness while making the configured
live R-to-Julia bridge test file match the current admitted contract.

This was a truth-lock and cleanup checkpoint, not a push, PR, merge, API
widening, or parity-completion slice.

## 2. Implemented

- In `R/julia-bridge.R`, Gaussian and per-trait ordinal postfit alpha payloads
  now replace non-finite entries with the link-scale zero intercept convention
  before prediction. This makes Gaussian no-X bridge postfit prediction usable
  when GLLVM.jl reports placeholder `NaN` alpha values.
- Tightened `GJL-GATE-X-CI` wording so it says current fixed-effect-X CI
  routing is Gaussian complete-response only.
- In `tests/testthat/test-julia-bridge.R`, updated configured live tests to
  assert the current fail-loud contract for unsupported rows: NB1,
  response masks, non-Gaussian fixed X, mixed-family vectors,
  ordinal-probit, and broad TMB-vs-Julia Gaussian parity.
- Refreshed Mission Control `status.json` and `sweep.json` so the older
  10-failure caveat is superseded by green current-contract evidence.

## 3. Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-julia-bridge-live-contract-truth-lock.md`

## 3a. Decisions and Rejected Alternatives

Decision: update stale live tests to the narrowed bridge contract instead of
reviving unsupported success claims.

Rationale: the live GLLVM.jl bridge does not currently support NB1, masks,
non-Gaussian fixed X, mixed-family vectors, ordinal-probit, or broad
TMB-vs-Julia equality as admitted rows. Treating those as pass expectations
would overstate parity.

Rejected alternative: leave the configured live file red and commit only the
earlier 9-row drift cleanup. That would not solve the cloud-readiness problem.

Confidence: high for the truth-lock boundary; this is not a parity-completion
claim.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/julia-bridge.R")); cat("parse-ok\n")'
```

Outcome: parse succeeded.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Outcome: passed with 350 assertions, 0 failures, and 13 expected
live-GLLVM-path skips.

```sh
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R")'
```

Outcome: passed with 781 assertions, 0 failures, and 0 skips.

## 5. Tests of the Tests

The configured live file now fails if unsupported surfaces are silently
accepted, and it also fails if the Gaussian no-X postfit path regresses back
to non-finite prediction payloads.

## 6. Consistency Audit

Mission Control now says the configured live bridge test file is green for the
current narrowed contract. It also keeps the key blockers in place:
non-Gaussian X, masks, mixed-family vectors/CIs, source-specific `lv`,
`unique=` Julia parity, coverage calibration, and v1.0 parity completion remain
gated.

## 7. Roadmap Tick

No metric row was promoted. This checkpoint reduces local dirt and closes the
immediate configured-live-test failure set under the current contract.

## 7a. GitHub Issue Ledger

No issue was opened or closed.

## 8. What Did Not Go Smoothly

The first configured live rerun still had 6 failures after the broad cleanup.
Those were expectation-drift failures: Gamma grouped dispersion was per-trait
rather than single-group, and ordinal mask plus Wald CI hit the ordinal-CI gate
before the mask gate. After aligning the tests to the actual gate order and
payload shape, the configured live file passed.

## 9. Not Done

- No push, PR, or merge.
- No full `devtools::check()`.
- No large Totoro/DRAC compute.
- No source-specific `lv = ~ env` exposure.
- No Julia source-Psi parity.
- No broad R/Julia parity completion claim.
