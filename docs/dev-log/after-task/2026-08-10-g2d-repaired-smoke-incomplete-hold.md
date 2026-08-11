# After Task: G2d repaired local-smoke ineligible HOLD

**Branch**: `codex/isdm-g2d-six-species`  
**Frozen commit**: `45ff9943356b4038234885055bf412262421cc97`  
**Date**: `2026-08-10`  
**Roles (engaged)**: Ada, Rose

## 1. Goal

Run exactly one newly authorised repaired G2d ordinary seed-86101 local smoke
after a no-fit root preflight at the frozen commit, then determine whether its
retained artifacts justify a separate Totoro decision.

## 2. Implemented

The new no-fit preflight root passed and its independent receipt/sentinel audit
passed. The one authorised smoke retained its complete artifact bundle and
returned `G2D_SMOKE_HOLD`: the three-visit fit was ineligible, with maximum
absolute gradient `7.384789e-04`. The paired-state structural checks were all
true, but this does not substitute for numerical eligibility.

Mathematical contract: no DGP, estimand, likelihood, profile threshold,
formula grammar, public R API, response family, or public documentation
changed. G2c remains `G2C_SMOKE_ADMISSION_HOLD`.

## 4. Files Touched

- Internal closeout: this report,
  `docs/dev-log/plan-actual/2026-08-10-g2d-repaired-smoke-reconciliation.md`,
  and `docs/dev-log/check-log.md`.
- Retained ignored evidence: `dev/isdm-package-recovery/results/g2d-preflight-20260810-220000/`
  and `dev/isdm-package-recovery/results/g2d-smoke-20260810-220000/`, including
  root/fit/profile/metric/restart receipts, paired map, event ledger, fixture,
  manifest, and smoke receipt.
- Untouched: `R/`, `src/`, `README.md`, `NEWS.md`, `ROADMAP.md`, vignettes,
  generated Rd, pkgdown, empirical data, Totoro, campaign fixtures, and Issue
  #953.

## 3a. Decisions and Rejected Alternatives

- **Decision**: close the authorised smoke as HOLD. **Rationale**: the
  three-visit fit is explicitly ineligible despite a complete, hash-validated
  result bundle and intact paired-state checks. **Rejected alternative**:
  infer PASS from structural pairing or finite retained metrics alone.
  **Confidence**: high.
- **Decision**: do not retry. **Rationale**: the approval allowed exactly one
  fresh smoke. **Rejected alternative**: consume a second attempt to diagnose
  the incomplete root. **Confidence**: high.

## 5. Checks Run

```sh
Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R \
  --mode=preflight --output=dev/isdm-package-recovery/results/g2d-preflight-20260810-220000 \
  --pkg="$PWD" --campaign-sha=45ff9943356b4038234885055bf412262421cc97
# PASS: G2D_PREFLIGHT_PASS (no fit).

Rscript --vanilla -e '<read root receipt, sentinel, and manifest>'
# PASS: G2D_FROZEN_PREFLIGHT_AUDIT_PASS.

Rscript --vanilla dev/isdm-package-recovery/run-g2d-six-species-recovery.R \
  --mode=smoke --scenario=ordinary --replicate=1 \
  --output=dev/isdm-package-recovery/results/g2d-smoke-20260810-220000 \
  --pkg="$PWD" --campaign-sha=45ff9943356b4038234885055bf412262421cc97
# HOLD: G2D_SMOKE_HOLD; three_visit_status: ineligible;
# three_visit_max_abs_gradient: 7.384789e-04.

Rscript --vanilla -e '<audit complete smoke artifact set, hashes, provenance, and paired state>'
# PASS: G2D_FINAL_SMOKE_MANIFEST_AUDIT_PASS; G2D_SMOKE_HOLD_CONFIRMED.

Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-g2d-six-species-harness.R", reporter = "summary")'
# PASS: targeted no-fit harness regression test.
```

No Totoro, campaign, empirical, count, comparator, spatial, source-admission,
public API/docs, or Issue #953 command ran.

## 6. Tests of the Tests

No code or test changed in this closure. The independent audit tests the
acceptance boundary for a complete bundle (all required artifacts and hashes)
and the negative admission condition: `three_visit$eligibility$eligible` is
false even though the paired-state invariants are true.

## 8. Consistency Audit

```sh
rg -n 'G2D_SMOKE_(PASS|HOLD)|G2C_SMOKE_ADMISSION_HOLD|Totoro' \
  dev/isdm-package-recovery docs/dev-log/after-task docs/dev-log/plan-actual
```

Verdict: retained G2d records continue to reserve Totoro for a separately
authorised, inspected `G2D_SMOKE_PASS`; G2c is not relabelled.

### Roadmap Tick

N/A: private recovery admission evidence does not change a public roadmap row.

## 7a. Issue Ledger

No relevant open issue; no new issue created. Issue #953 was explicitly out of
scope and was not inspected or updated.

## 9. What Did Not Go Smoothly

The smoke command appeared to return before its artifact bundle was visible,
so the first inspection was premature and an initial closeout was committed
against an incomplete directory listing. Reinspection found the complete,
hash-validated bundle and the actual ineligible HOLD. This correction replaces
that premature interpretation; no result was deleted or rerun.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept the frozen-head, fresh-root, and one-attempt contract intact and
reopened a premature interpretation when the retained artifact state changed.
**Rose**'s audit standard makes the explicit ineligibility a HOLD rather than
a structural PASS and keeps any new diagnostic smoke approval separate.

## 10. Known Residuals

There is no admissible G2d smoke, numerical recovery result, Totoro admission,
30-fixture campaign, or Paper-2 numerical evidence. Diagnose this ineligible
smoke only under a new explicit authority; it may not be retried from this
approval. Any future request must preserve this root as negative evidence and
state whether it authorises diagnostic execution, a new smoke, or both.

## 12. Cross-Product Coverage

This HOLD does NOT cover an admissible repaired smoke, numerical recovery, a
30-fixture campaign, Totoro, empirical data,
counts, comparators, spatial or source-admission work, detection, absolute
intensity, public API or documentation, Issue #953, or any Paper-2 numerical
claim.
