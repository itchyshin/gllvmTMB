# After Task: G2m prospective numerical-admission design

**Branch:** `codex/isdm-g2m-numerical-admission`
**Date:** 2026-08-12
**Roles (engaged):** Ada, Gauss, Noether, Fisher, Rose

## 1. Goal

Design an approval-ready prospective numerical-admission protocol after G2k
`NO_REPAIR`, without fitting or changing the six-species private iJSDM.

## 2. Implemented

The protocol distinguishes `NOT_REQUIRED` raw-pass cases, the existing
conditional boundary candidate, and `NO_CANDIDATE` non-boundary `b_fix` /
`theta_rr_B` cases. It freezes no-fit, compiled-unit, provenance, and local
pre-run gates for later approval.

### Mathematical contract

No public API, likelihood, formula grammar, DGP, seed grid, source gate,
parameter map, raw threshold, recovery criterion, Rd, vignette, or pkgdown
surface changed. The locked model is restated only for symbolic alignment.

## 3. Files Changed

Private protocol, method review, text-only validator, targeted test,
reconciliation, check-log entry, and this report were created or changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** conditional polish; `NO_CANDIDATE` for Case C.

**Rationale:** 15 G2k raw-pass/all-metric cases reject universal polish; 31/31
boundary candidates succeeded; the dominant non-boundary geometry has no
predeclared validated candidate. The covariance-Newton primitive is boundary-
gated and lacks covariance-alignment/conditioning safeguards.

**Rejected:** threshold relaxation, G2k reclassification, extending boundary
polish, new controls/retries, and any pre-run/campaign authorization.

## 4. Files Touched

- `dev/isdm-package-recovery/2026-08-12-g2m-numerical-admission-protocol.md`
- `dev/isdm-package-recovery/2026-08-12-g2m-numerical-admission-method-review.md`
- `dev/isdm-package-recovery/run-g2m-numerical-admission-validation.R`
- `tests/testthat/test-g2m-numerical-admission-protocol.R`
- `docs/dev-log/plan-actual/2026-08-12-g2m-numerical-admission-reconciliation.md`
- `docs/dev-log/check-log.md` and this report.

No public docs, README, NEWS, ROADMAP, vignette, roxygen, Rd, or API changed.

## 5. Checks Run

```sh
Rscript --vanilla dev/isdm-package-recovery/run-g2m-numerical-admission-validation.R --mode=validate
# PASS: text-only decision-table and predecessor/engine constraints.

Rscript --vanilla -e 'devtools::test(filter = "g2m-numerical-admission-protocol", reporter = "summary")'
# PASS: 6 assertions; no fit.
```

## 6. Tests of the Tests

The prophylactic boundary test catches loss of raw-pass `NOT_REQUIRED`,
non-boundary `NO_CANDIDATE`, or an accidental model-call token. The validator
checks all five cases, the G2k `NO_REPAIR` predecessor, and implementation
constraints.

## 7a. Issue Ledger

Issue #953 was not inspected, altered, or updated by scope. No relevant open
issue; no new issue created because this is a private design gate.

## 8. Consistency Audit

`rg "NOT_REQUIRED|NO_CANDIDATE|conditional repair evidence|candidate_method" dev/isdm-package-recovery` found the intended private decision states.

`rg "integrated_jsdm\\(|iJSDM|repeated-visit" README.md NEWS.md ROADMAP.md _pkgdown.yml vignettes` found no new public capability claim.

`rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design` found only pre-existing reader-facing calls.

## 9. What Did Not Go Smoothly

The brain CLI could not secure `~/.basic-memory` under sandboxing and project
routing had no manifest. Raw-vault fallback had no G2k hit, so committed G2k
records and live source were technical authority. Independent review caught the
covariance-Newton wording gap; the protocol was corrected before closure.

## 10. Known Residuals

No Case-C optimizer is designed, tested, or implemented. G2m does not resolve
Psi/map recovery failures or authorize a pre-run. The next task, if approved,
is prospective implementation and validation only.

## 11. Team Learning

**Ada:** “repair unnecessary” and “repair failed” are distinct admission
states.

**Gauss and Noether:** an algebraic same-objective step is not an admissible
candidate without covariance/order/conditioning and symmetry safeguards.

**Fisher:** `NO_CANDIDATE` is more honest than inferring repair success from a
favourable subset.

**Rose:** candidate method identity belongs in immutable provenance.

## 12. Cross-Product Coverage

This design covers only numerical admission for the locked six-species,
nonspatial iJSDM. It does NOT cover a new optimizer, spatial/detection work,
empirical data, count outcomes, sources, public API/docs, recovery claims, or
external compute.
