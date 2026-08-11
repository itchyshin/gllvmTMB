# After Task: G2d root-only smoke termination diagnostic

**Branch**: `codex/isdm-g2d-six-species`
**Starting commit**: `580d17dd`
**Diagnostic commit**: `d04cb53e47df8553ccd4ebc7e281130cc01fe0c3`
**Date**: `2026-08-11`
**Roles engaged**: Ada, Curie, Rose

## 1. Goal

Diagnose the retained root-only G2d S3 smoke without fitting; establish an
exact failure boundary, add a no-fit guard, retain its provenance, and state
whether a separately approved replacement smoke is justified.

## 2. Contract and implemented guard

No likelihood, DGP, estimand, parameterisation, family, formula grammar, or
public interface changed. `prepare_fixture()` now performs frozen-commit/root
checks, deterministic fixture construction, and fixture validation. The new
`smoke_boundary` mode invokes this shared path only. A smoke stage ledger now
records root, fixture, and pre/post-arm boundaries before final artifacts.

## 3. Files touched

- `dev/isdm-package-recovery/run-g2d-six-species-recovery.R`
- `tests/testthat/test-g2d-six-species-harness.R`
- this report, reconciliation, and `docs/dev-log/check-log.md`

No public/package documentation, API, Rd, README, NEWS, ROADMAP, vignette, or
pkgdown file changed. G2c remains `G2C_SMOKE_ADMISSION_HOLD`.

## 4. Checks

```sh
Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g2d-six-species-harness.R", reporter = "summary", stop_on_failure = TRUE)'
# PASS: boundary diagnostic and existing no-fit harness checks.

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R \
  --mode=smoke_boundary --scenario=ordinary --replicate=1 \
  --output=dev/isdm-package-recovery/results/g2d-tail-boundary-20260811-002 \
  --pkg=/private/tmp/gllvmtmb-isdm-g2d-six-species \
  --campaign-sha=d04cb53e47df8553ccd4ebc7e281130cc01fe0c3
# PASS: G2D_SMOKE_BOUNDARY_PASS (no fit).

Rscript --vanilla -e '<read root, stage ledger, boundary object, and manifest>'
# PASS: G2D_SMOKE_BOUNDARY_STAGE_READBACK_PASS.

git diff --check
# PASS.
```

No optimizer, profile, smoke, campaign, Totoro/DRAC, or empirical/public work
ran. A first diagnostic command used a shortened SHA and was rejected before a
root was created; the successful root uses the verified 40-character SHA.

## 5. Tests of the tests

The regression test launches `smoke_boundary` in a temporary private root,
asserts exact stage order, verifies all receipts, and asserts no smoke receipt.
It fails if preparation fits, stops recording a stage, or diverges from the
shared pre-fit path.

## 6. Consistency audit

```sh
rg -n 'smoke_boundary|prepare_fixture|smoke-stage-ledger|one_visit_fit_entered|three_visit_fit_entered' dev/isdm-package-recovery/run-g2d-six-species-recovery.R tests/testthat/test-g2d-six-species-harness.R
rg -n 'G2D_ROOT_ONLY_CAUSE_UNATTRIBUTED|RUNNER_OBSERVABILITY_DEFECT_REPAIRED|G2C_SMOKE_ADMISSION_HOLD|Totoro|Issue #953' dev/isdm-package-recovery docs/dev-log/after-task docs/dev-log/plan-actual
```

Verdict: only private diagnostic provenance is new; G2c and Totoro retain
their existing HOLD labels.

## 7. What did not go smoothly

The original smoke kept no process exit status or intermediate artifact. Its
specific cause is not recoverable from retained evidence. No retry was made.

## 8. Team learning

**Ada** kept diagnosis separate from replacement execution. **Curie** required
a shared no-fit preparation path rather than a look-alike fixture test.
**Rose** requires durable stages before an interrupted smoke is diagnosable.

## 9. Roadmap and issue ledger

**Roadmap tick**: N/A. **GitHub issue ledger**: no issue inspected, changed, or
created; Issue #953 remained out of scope.

## 10. Verdict and next action

`G2D_ROOT_ONLY_CAUSE_UNATTRIBUTED`: no retained evidence supports a specific
engine, optimizer, or external cause. `RUNNER_OBSERVABILITY_DEFECT_REPAIRED`:
future stage persistence is verified without fitting.

Do not rerun now. A fresh, separately approved replacement S3 smoke may be
considered only with the new ledger, captured exit status, a new root, and the
same one-attempt/no-Totoro boundaries.
