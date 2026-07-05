# After Task: Sigma Profile Bootstrap Controls

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Fisher / Curie / Grace / Rose / Shannon`

## 1. Goal

Start the `gllvmTMB` completion arc with a small inference-safety repair:
when `confint(..., parm = "Sigma_unit", method = "profile")` must fall back to
bootstrap for nonlinear full-Sigma targets, preserve the caller's `nsim` and
`seed`. Also update the Ultra-Plan so Totoro and DRAC are part of an explicit
compute escalation ladder rather than implicit lab knowledge.

## 2. Implemented

- `.confint_sigma()` now passes `nsim` and `seed` into
  `.confint_sigma_profile()`.
- `.confint_sigma_profile()` now forwards those controls into the bootstrap
  fallback instead of hard-coding `nsim = 200L` and `seed = NULL`.
- `test-sigma-profile-bootstrap-controls.R` now has a mocked regression test
  proving the fallback receives the user-supplied replicate count and RNG seed.
- The completion Ultra-Plan now separates local checks, Totoro diagnostics, and
  DRAC claim-evidence runs, including worker caps, SLURM-array rules,
  provenance columns, and denominator-pooling guards.

## 3. Files Changed

Code:

- `R/z-confint-gllvmTMB.R`

Tests:

- `tests/testthat/test-sigma-profile-bootstrap-controls.R`

Planning and evidence:

- `docs/dev-log/while-away/2026-07-04-gllvmtmb-completion-ultra-plan.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-sigma-profile-bootstrap-controls.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep this as a narrow Phase 1 inference-safety repair.

Rationale: issue #606 is a real reproducibility bug, but fixing it does not
prove new interval calibration or move a validation-debt row.

Rejected alternative: run a broad bootstrap/profile campaign immediately.

Reason rejected: focused local correctness came first; Totoro/DRAC scaling is
now documented but not launched.

Confidence: high for the control-forwarding fix; modest for broader profile-CI
health because the full profile test file remains expensive.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); cat("parse-ok\n")'
```

Outcome: passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-sigma-profile-bootstrap-controls.R", reporter = "summary")'
```

Outcome: passed; printed `sigma-profile-bootstrap-controls: ....`.

```sh
GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "matrix-gamma-unit", reporter = "summary")'
```

Outcome: passed locally.

```sh
gh issue view 606 --json number,title,state,labels,url,body --jq '{number,title,state,url,labels:[.labels[].name],body:(.body|tostring|.[0:1200])}'
```

Outcome: confirmed open issue #606 describes this exact bug.

## 5. Tests of the Tests

The new test mocks `bootstrap_Sigma()` so the assertion is on the handoff
contract, not on stochastic bootstrap output. Against the old implementation it
would observe `n_boot = 200L` and `seed = NULL`, so it directly guards the
regression.

## 6. Consistency Audit

No public capability wording was changed. The Ultra-Plan now says no remote
compute is launched by the planning update, and the check-log records that no
validation-debt row moved.

## 7. Roadmap Tick

N/A. This is an issue-level safety repair and planning update, not a public
capability promotion.

## 7a. GitHub Issue Ledger

- #606 remains open locally addressed: <https://github.com/itchyshin/gllvmTMB/issues/606>.
- No issue was closed or commented in this slice.

## 8. What Did Not Go Smoothly

The full heavy `profile-ci` file run reached the older
`Profile on Sigma_unit (latent+unique tier) falls back to bootstrap` test and
was too slow for this quick repair cycle. The test session was interrupted and
replaced with a targeted mocked assertion. Also, this installed `testthat`
version does not support `test_file(..., filter = ...)`, so test-name filtering
was not available.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the slice narrow and did not bundle missing-data, structural grammar,
or non-Gaussian expansion.

Fisher treated this as an uncertainty-control repair, not as proof that profile
or bootstrap intervals are calibrated.

Curie required the regression to inspect `nsim` and `seed` directly rather than
infer it from random bootstrap output.

Grace kept remote compute idle and documented the local -> Totoro -> DRAC
escalation gates.

Rose blocked any new "covered" interval claim.

Shannon kept issue #606 as the ledger anchor and avoided closing GitHub state
from an uncommitted local repair.

## 10. Known Limitations And Next Actions

- Run a broader `profile-ci` slice once the expensive fallback test can be
  bounded or isolated.
- Continue Phase 1 inference-safety issues: status-shape bugs, pinned-profile
  status, baseline consistency, and bootstrap merge status.
- Then move to Phase 2 missing/mixed correctness: response masks under
  `missing = "include"` and mixed-family list matching by names.
- Use Totoro only for diagnostic canaries after focused local tests are green;
  use DRAC only for frozen-design claim evidence.
