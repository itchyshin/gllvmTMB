# After Task: G2i one-replicate recovery pre-run

## 1. Goal

Execute the approved S7 once: run one SHA-bound local known-truth recovery
pre-run for the private six-species G2i estimator, retain every result, and
use its measured time to propose (but not launch) a later Totoro campaign.

## 2. Implemented

Commit `0d0d5772cfa77d6d84af7731f3f8d01c8596305c` adds a private,
validate-before-fit runner and frozen decision record.  Exactly one run used
seed `86122L` in the ignored result root
`dev/isdm-package-recovery/results/g2i-recovery-prerun-20260811-001`.

The run retained the truth, fitted object, six five-offset profiles, recovery
summary, decision ledger, timing, manifest, terminal receipt, and a
self-excluding final provenance closure.  Its result is
`PRE_RUN_RECOVERY_HOLD`; no retry or campaign was started.

## 3a. Decisions and Rejected Alternatives

The DGP and fitted model remain the locked nonspatial relative-intensity
iJSDM,

\[
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},\qquad
Y^G_{cs}\sim\operatorname{Poisson}\{a^G_c\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},
\]

with three conditionally independent PA-cloglog observations conditional on
the same \(\eta_{cs}\), rank-one \(\Lambda\), diagonal \(\Psi\), and a
GBIF-only bias gate.  The G2i final-polish estimator is unchanged.

The frozen all-criteria rule rejected a superficially tempting relabel: four
recovery measures passed, but maximum diagonal-\(\Psi\) variance error was
`0.2156398`, above the predeclared `0.20` limit.  The correct result is a
HOLD, not a threshold change, extra local replicate, or campaign authority.

## 4. Files Touched

- `dev/isdm-package-recovery/run-g2i-recovery-prerun.R` -- private,
  SHA-bound validate/pre-run wrapper.
- `dev/isdm-package-recovery/2026-08-11-g2i-recovery-prerun-decision.md` --
  frozen recovery criteria.
- `tests/testthat/test-g2i-recovery-prerun.R` -- no-fit contract tests.
- This after-task report, the paired reconciliation record, and the
  check-log entry.

No public API, documentation, formula grammar, likelihood, pkgdown surface,
empirical data, spatial model, count-survey branch, source admission, Issue
#953, Totoro, or DRAC changed.

## 5. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse(file="dev/isdm-package-recovery/run-g2i-recovery-prerun.R")); devtools::test(filter="g2i-recovery-prerun", reporter="summary")'
# PASS: 17 targeted no-fit assertions.

Rscript --vanilla dev/isdm-package-recovery/run-g2i-recovery-prerun.R \
  --mode=validate --output=dev/isdm-package-recovery/results/g2i-validation-unused \
  --pkg=/private/tmp/gllvmtmb-isdm-g2i-polish-recovery
# PASS: validation exits before a fit.

Rscript --vanilla dev/isdm-package-recovery/run-g2i-recovery-prerun.R \
  --mode=prerun --output=dev/isdm-package-recovery/results/g2i-recovery-prerun-20260811-001 \
  --pkg=/private/tmp/gllvmtmb-isdm-g2i-polish-recovery \
  --campaign-sha=0d0d5772cfa77d6d84af7731f3f8d01c8596305c
# Exactly one pre-run: PRE_RUN_RECOVERY_HOLD.
```

The fit took `45.987` seconds and the profiles `382.373` seconds: `428.360`
seconds total (about `7.14` minutes).  Structural admission diagnostics were
valid: three restarts, six finite converged five-offset profiles, and a valid
GBIF-only gate.  The full frozen admission rule did not pass because final
gradient `0.002726537` exceeds `1e-3`.  Recovery values were beta `0.1597133`, bias
`0.1043863`, minimum map correlation `0.7324197`, shared-covariance relative
Frobenius error `0.2403427`, and maximum diagonal-Psi variance error
`0.2156398`.

## 6. Tests of the Tests

The test filter exercises SHA binding, validate-before-fit routing, frozen
fixture/decision hashes, unavailable output roots, source-gate shape, and
recovery-classification logic.  The retained final manifest and provenance
closure make independent hash recomputation possible without re-fitting.

## 7a. Issue Ledger

Issue #953 was not opened, changed, or discussed.  The only live scientific
issue is the predeclared diagonal-Psi recovery failure; it remains an internal
HOLD for separate diagnosis.

## 8. Consistency Audit

The result root binds the exact runner, fixture, contract, and decision
hashes to `0d0d5772`.  It contains no empirical inputs.  G2c remains
`G2C_SMOKE_ADMISSION_HOLD` and G2h remains `G2H_SMOKE_HOLD`; G2i does not
alter either status.  No reader-facing surface was edited.

## 9. What Did Not Go Smoothly

The parent terminal returned while the profile stage continued.  Process and
artifact monitoring established that it was the same single run, rather than
starting another.  Readback R commands also required a writable temporary
directory in the Codex worktree; the retained result itself was unaffected.

## 10. Known Residuals

One seed cannot establish recovery frequency.  More importantly, it did not
meet the frozen gradient or diagonal-Psi thresholds.  This is not evidence for recovery,
public promotion, Paper 2 efficacy, spatial structure, detection separation,
absolute intensity, count-survey outcomes, arbitrary sources, or
zero-inflation.

## 11. Team Learning

The one-run discipline worked: an almost-passing result is still recorded as
a HOLD, with sufficient artifacts to diagnose whether diagonal residual
variance, fixture information, or the criterion is responsible.  A campaign
must not substitute for that diagnosis.

## 12. Cross-Product Coverage

This covers one private synthetic six-species recovery pre-run only.  It
**does NOT cover** a multi-seed campaign, spatial fields, detection parameters,
count-survey outcomes, source-admission extensions, empirical inference,
public/package surfaces, or any other extension.

### Measured campaign proposal

If a separately approved diagnostic redesign preserves the frozen estimator
and asks for frequency rather than a replacement result, a 30-seed Totoro
array would use 30 cores (below the 150-core cap), about `3.57` core-hours at
the measured `428.360` seconds per replicate, and a conservative 15-minute
wall-time allocation including setup.  It is **not recommended or authorized
now** because this pre-run is a recovery HOLD.  First decide whether the
diagonal-Psi failure is an estimand/information problem or a threshold/DGP
design problem; only then request campaign approval with a frozen seed grid.
