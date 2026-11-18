# After Task: G2d instrumented replacement local-smoke HOLD

**Branch**: `codex/isdm-g2d-six-species`
**Frozen commit**: `a8b3f80a5c9afcb2ec4f43172e0819dd92d5af0b`
**Date**: `2026-08-11`
**Roles engaged**: Ada, Curie, Rose

## 1. Goal

Run one instrumented replacement G2d ordinary local smoke after fresh no-fit
preflight, audit retained evidence, and decide whether Totoro is warranted.

## 2. Mathematical contract

No likelihood, DGP, estimand, grammar, parameterisation, public API, or reader
documentation changed. The smoke retained the locked six-species nonspatial
GBIF Poisson plus three PA-cloglog events, rank-one `Lambda`, free diagonal
`Psi`, relative intensity, and GBIF-only bias gate. The ledger is provenance
instrumentation only.

## 3. Files and scope

The runner/test ledger was committed at `d04cb53e`. This execution adds ignored
roots plus this report, reconciliation, and `check-log.md`. No public API/Rd,
README, NEWS, ROADMAP, vignette, pkgdown, empirical, spatial, detection,
structural-zero, survey-count, comparator, source-admission, Totoro/DRAC,
campaign, or Issue #953 action ran.

## 4. Checks

```sh
Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R \
  --mode=preflight --output=dev/isdm-package-recovery/results/g2d-replacement-preflight-20260811-001 \
  --pkg=/private/tmp/gllvmtmb-isdm-g2d-six-species \
  --campaign-sha=a8b3f80a5c9afcb2ec4f43172e0819dd92d5af0b
# PASS: G2D_PREFLIGHT_PASS (no fit).

Rscript --vanilla -e '<independent preflight receipt, sentinel, manifest read-back>'
# PASS: G2D_REPLACEMENT_PREFLIGHT_READBACK_PASS.

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R \
  --mode=smoke --scenario=ordinary --replicate=1 \
  --output=dev/isdm-package-recovery/results/g2d-replacement-smoke-20260811-001 \
  --pkg=/private/tmp/gllvmtmb-isdm-g2d-six-species \
  --campaign-sha=a8b3f80a5c9afcb2ec4f43172e0819dd92d5af0b
# exit status 0; G2D_SMOKE_HOLD.

Rscript --vanilla -e '<verify artifacts, stage order, root commit, and manifest>'
# PASS: G2D_REPLACEMENT_SMOKE_AUDIT_PASS.
```

Runtime was about three minutes, below the ten-minute ceiling. No retry ran.

## 5. Result

`G2D_SMOKE_HOLD`: all six three-visit profile ledgers are HOLD and the GBIF
bias maximum error is `0.371326`, above the frozen `0.30` target. The selected
objective is `1735.661`; maximum gradient is `7.396919e-04`; minimum map
correlation is `0.730678`; shared covariance relative Frobenius error is
`0.364813`; and maximum Psi-variance error is `0.198249`.

The prior root later finished as complete `G2D_SMOKE_HOLD`; this supersedes the
earlier termination explanation.

## 6. Tests of the tests

The stage-ledger regression test passed before this run. The production attempt
then retained every stage, terminal receipt, and manifest hash, so missing
in-flight progress and incomplete bundles are now detectable.

## 7. Consistency audit

```sh
rg -n 'G2D_SMOKE_(PASS|HOLD)|G2C_SMOKE_ADMISSION_HOLD|Totoro|Issue #953' dev/isdm-package-recovery docs/dev-log/after-task docs/dev-log/plan-actual
rg -n 'smoke-stage-ledger|one_visit_fit_entered|three_visit_fit_entered' dev/isdm-package-recovery/run-g2d-six-species-recovery.R tests/testthat/test-g2d-six-species-harness.R
```

Verdict: G2c remains held; instrumentation is private; Totoro needs a separate
approval after a valid PASS, which does not exist.

## 8. Team learning

**Ada** kept the ten-minute/no-retry contract. **Curie**'s ledger showed the
complete two-arm route and corrected the root-only interpretation. **Rose**
classifies a complete but ineligible smoke as negative admission evidence.

## 9. Roadmap and issue ledger

**Roadmap tick**: N/A. **GitHub issue ledger**: no issue changed or created;
Issue #953 remained out of scope.

## 10. Next action

No Totoro decision is warranted. G2d remains `G2D_SMOKE_HOLD`; G2c remains
`G2C_SMOKE_ADMISSION_HOLD`. Future work needs separately approved diagnosis of
profile/gamma recovery failure, not another smoke or campaign.
