# After Task: G2k private six-species calibration campaign on FIR

**Branch**: `codex/isdm-g2k-calibration-campaign`  
**Date**: 2026-08-11  
**Roles (engaged)**: Ada, Gauss, Noether, Curie, Fisher, Rose, Grace

## 1. Goal

Repair the invalid 128-valid/22-invalid-DGP campaign design, run a
deterministic all-attempt 150-fixture private recovery campaign for the locked
six-species nonspatial iJSDM, retain provenance, and determine whether it
supports a recovery-validated capability claim.

## 2. Implemented

The deterministic G2l screen retained the first 150 fixtures admissible under
the unchanged G2h source/design check.  A private FIR Slurm wrapper ran one
remote representative pre-run and then array `54323628`, capped at 50
single-threaded tasks.  It completed 150/150 tasks and retained 150 ledgers.

The campaign result is `G2K_CALIBRATION_HOLD`: 22/150 strict joint passes
(0.1467; binomial MCSE 0.0289), 106/150 substantive recovery-metric passes
(0.7067; MCSE 0.0372), and no missing/scheduler-failed attempt.  The frozen
specification defined no promotion-frequency cutoff, so these results do not
support a recovery-validated iJSDM capability claim.

The two local-only article staging sources remain drafts.  The repeated-visit
detection extension is now implementation-ready as a mathematical
specification, but remains unimplemented and gated on a future core PASS or
separately approved redesign.

## 3. Files Changed

- `dev/isdm-package-recovery/g2l-eligible-seeds.R` and
  `run-g2k-calibration.R`: deterministic screen, immutable receipt, and
  all-attempt coordinator.
- `dev/isdm-package-recovery/run-g2k-calibration-worker.sh` and
  `run-g2k-calibration-fir.sbatch`: private one-seed worker and FIR array
  wrapper; the latter maps array tasks past the CSV header.
- `R/fit-multi.R` and `tests/testthat/test-warm-nlminb-restart.R`: private
  same-objective covariance-Newton polish used by the frozen estimator.
- `tests/testthat/test-g2k-calibration.R`: no-fit seed-grid, private-library,
  profile-retry, and FIR-wrapper contracts.
- `dev/isdm-package-recovery/article-staging/gbif-joint-intensity.Rmd` and
  `article-staging/integrated-jsdm-repeated-survey.Rmd`: local-only drafts.
- `dev/isdm-package-recovery/2026-08-11-repeated-visit-detection-extension-specification.md`:
  private detection implementation specification.
- `dev/isdm-package-recovery/2026-08-11-g2k-calibration-reconciliation.md`:
  final evidence and HOLD verdict.
- This after-task report and retained ignored result roots.  No public
  `README.md`, `NEWS.md`, `ROADMAP.md`, `_pkgdown.yml`, vignette, generated Rd,
  or exported API changed.

## 3a. Decisions and Rejected Alternatives

The campaign used pre-screening, not post-hoc omission: invalid DGP fixtures
are recorded as rejected candidates before fitting, while all 150 admitted
fixtures remain in the denominator.  A 150-task duplicate on Nibi/Narval was
rejected because FIR had already begun the immutable all-attempt campaign.
No recovery criterion or model component was relaxed after provisional holds.

## 4. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter="g2k-calibration", reporter="summary")'
# PASS: targeted no-fit contract assertions.

Rscript --vanilla dev/isdm-package-recovery/run-g2k-calibration.R --mode=validate
# PASS: coordinator validation exits before fitting.

bash -n dev/isdm-package-recovery/run-g2k-calibration-fir.sbatch
# PASS.
```

The FIR pre-run at `g2r-fir-prerun-20260811-001` passed: valid profiles,
three restarts, gradient `0.0007778423`, and all frozen recovery measures.
FIR array `54323628` completed 150 tasks with exit code `0:0`; the frozen
coordinator summary records `n_requested=150`, `n_started=150`, `n_missing=0`,
`n_joint_pass=22`, and `n_recovery_metric_pass=106`.

## 5. Tests of the Tests

The G2k test is a boundary/failure-path contract: it checks an exact screened
grid, rejected-candidate manifest, no-fit validation, and the header-offset
that previously caused a scheduler task to feed `seed` to the numeric runner.
The resulting remote failure-before-fix was retained as a launcher-only root;
the corrected one-task pre-run passed before the array launch.

## 6. Consistency Audit

`rg "G2C_SMOKE_ADMISSION_HOLD|G2K_CALIBRATION_HOLD|PRE_RUN_RECOVERY_PASS" dev/isdm-package-recovery docs/dev-log` found the intended private decision records; G2c remains held.

`rg "integrated_jsdm\\(|iJSDM|repeated-visit" README.md NEWS.md ROADMAP.md _pkgdown.yml vignettes` found no public implementation claim.

`rg "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design` found no new reader-facing model call from this private lane.

## 7. Roadmap Tick

**Roadmap tick**: N/A — this is a private evidence lane and deliberately changes no public roadmap surface.

## 7a. GitHub Issue Ledger

Issue #953 was not changed, discussed, or updated.  `gh pr list --state open`
was attempted for the pre-edit lane check but unavailable because the GitHub
API connection failed; no issue action is required by this private lane.

## 8. What Did Not Go Smoothly

Totoro was saturated by a foreign campaign, so the approved work moved to FIR.
The first FIR launcher read the seed-grid header, and an earlier coordinator
invocation used the wrong working directory; both failed before fitting, were
retained, and were repaired with a no-fit wrapper contract.  FIR's normal
priority queue released the 150 attempts in four waves rather than all at
once.  None of these altered the DGP, source gate, estimator, or denominator.

## 9. Team Learning

**Ada:** preserving one immutable campaign root through scheduler delays
prevented accidental duplicate evidence.

**Gauss and Noether:** the same-objective polish and profile retry are
numerical routing changes, not likelihood/DGP changes; the raw gradient must
remain a real gate until a new diagnostic arc justifies otherwise.

**Curie:** the pre-screen makes source/DGP admissibility explicit rather than
silently conditioning a recovery rate on successful fixtures.

**Fisher:** 22/150 strict passes is a HOLD, even though 106/150 substantive
metric passes help localize the limitation to the numerical admission rule.

**Rose and Grace:** scheduler exit success is not scientific success; only the
retained 150-ledger coordinator summary closes the all-attempt evidence.

## 10. Known Limitations And Next Actions

This is one fixed six-species, nonspatial, synthetic, package-native relative
intensity DGP.  It does not validate empirical inference, detection
estimation, public API/docs, spatial fields, count outcomes, arbitrary data
sources, abundance, or generic zero inflation.  The next task is a bounded
method/identifiability diagnosis of why the raw-gradient gate rejects so many
otherwise metric-passing attempts; it must be separately planned and approved
before any estimator/DGP/threshold change or repeated-visit implementation.
