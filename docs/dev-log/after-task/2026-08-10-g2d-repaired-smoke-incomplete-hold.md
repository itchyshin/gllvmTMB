# After Task: G2d repaired local-smoke incomplete-artifact HOLD

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
passed. The one authorised smoke then created its bound root receipt but
returned without a G2D completion verdict and without any fixture, fit,
profile, metric, restart, paired-map, event, manifest, or smoke receipt. The
independent artifact audit is therefore `G2D_SMOKE_ARTIFACT_AUDIT_HOLD`.

Mathematical contract: no DGP, estimand, likelihood, profile threshold,
formula grammar, public R API, response family, or public documentation
changed. G2c remains `G2C_SMOKE_ADMISSION_HOLD`.

## 4. Files Touched

- Internal closeout: this report,
  `docs/dev-log/plan-actual/2026-08-10-g2d-repaired-smoke-reconciliation.md`,
  and `docs/dev-log/check-log.md`.
- Retained ignored evidence: `dev/isdm-package-recovery/results/g2d-preflight-20260810-220000/`
  and `dev/isdm-package-recovery/results/g2d-smoke-20260810-220000/`.
- Untouched: `R/`, `src/`, `README.md`, `NEWS.md`, `ROADMAP.md`, vignettes,
  generated Rd, pkgdown, empirical data, Totoro, campaign fixtures, and Issue
  #953.

## 3a. Decisions and Rejected Alternatives

- **Decision**: close the authorised smoke as HOLD. **Rationale**: its root
  lacks every artifact required to establish that a fit began or completed.
  **Rejected alternative**: infer PASS from a returned shell process or the
  root receipt alone. **Confidence**: high.
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
# No printed G2D verdict. Only root-receipt.md/rds were retained.

Rscript --vanilla -e '<audit smoke artifact set and bound root receipt>'
# HOLD: G2D_SMOKE_ARTIFACT_AUDIT_HOLD; fit-start evidence absent.
```

No Totoro, campaign, empirical, count, comparator, spatial, source-admission,
public API/docs, or Issue #953 command ran.

## 6. Tests of the Tests

No code or test changed in this closure. The independent audit tested the
negative condition that must bar a PASS: absence of `fixtures/ordinary-01.rds`
and all required post-fit receipts despite a valid bound root receipt.

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

The no-fit preflight demonstrated that the root could be written and read, but
the smoke stopped after writing its root receipt. This is distinct from the
previous profile-map HOLD: it provides no retained evidence that the repaired
profile code was reached. A first draft of the external audit assumed flat
sentinel fields; inspection corrected it to the runner's nested receipt schema
without modifying the result root.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept the frozen-head, fresh-root, and one-attempt contract intact and
did not treat process return as model evidence. **Rose**'s audit standard makes
the missing receipt set a HOLD rather than a plausible PASS and keeps any new
diagnostic smoke approval separate.

## 10. Known Residuals

There is still no valid G2d local smoke, numerical recovery result, Totoro
admission, 30-fixture campaign, or Paper-2 numerical evidence. Diagnose the
incomplete root only under a new explicit authority; it may not be retried from
this approval. Any future request must preserve this root as negative evidence
and state whether it authorises diagnostic execution, a new smoke, or both.

## 12. Cross-Product Coverage

This HOLD does NOT cover a completed repaired smoke, fit or profile execution,
eligibility, numerical recovery, a 30-fixture campaign, Totoro, empirical data,
counts, comparators, spatial or source-admission work, detection, absolute
intensity, public API or documentation, Issue #953, or any Paper-2 numerical
claim.
