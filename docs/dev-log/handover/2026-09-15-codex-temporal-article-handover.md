# Codex Handover — Standalone temporal article refresh

Meta: 2026-09-15 · AUTHOR = Codex · TARGET = Codex · repository `itchyshin/gllvmTMB`

You are Codex, picking up the reader-facing temporal documentation lane in a fresh worktree. This repository is multi-lane. Read `AGENTS.md`, `docs/dev-log/handover/2026-07-25-active-lane-split.md`, this document, and `docs/dev-log/after-task/2026-09-14-temporal-standalone-scope.md` before editing. Classify every item as `DONE`, `OWED`, `RETRACTED`, or `PROTECTED`; do only `OWED` work.

## Mission Control

| Repo | Branch / baseline | Verified state | Plan by leverage |
| --- | --- | --- | --- |
| `itchyshin/gllvmTMB` | `codex/temporal-program-20260909` (resolve its pushed tip with `git rev-parse origin/codex/temporal-program-20260909`) | Standalone temporal AR1/OU provider passed retained local publication and closeout gates, plus the three-OS package check run `34922613507`. | 1. create an article-only worktree from this branch; 2. audit and improve the existing temporal article; 3. render and package-check its reader workflow; 4. submit the documentation branch for review. |

## Critical Context

The requested next work is a **fresh documentation lane**, not another likelihood or source-pair lane. An article already exists at `vignettes/articles/temporal-ar1.Rmd`; the task is to make that reader path coherent and complete rather than create a duplicate article.

The earned public scope is one **standalone temporal provider** alongside the stable-unit 5 × 3 grid:

```r
temporal_indep(0 + trait | series, time = occasion, structure = "ar1")
temporal_dep(0 + trait | series, time = elapsed, structure = "ou")
temporal_latent(0 + trait | series, time = occasion,
                d = 1, unique = TRUE, structure = "ar1")
```

AR1 uses ordered integer occasions and preserves integer gaps. OU uses numeric elapsed time and positive continuous decay. Long and `traits(...)` wide workflows must be shown through `gllvmTMB()`.

Temporal combinations with phylogenetic, animal, spatial, or kernel sources are deferred and rejected before TMB construction. They remain developer-only retained history under `dev/temporal-program/retained-source-pair-tests/`. Do not revive, explain as public options, or test those routes in this documentation lane.

## What Was Accomplished

- Implemented the standalone `temporal_indep()`, `temporal_dep()`, and rank-one `temporal_latent()` API for AR1 and OU, with private `(series, time)` identity and public labels preserved.
- Added extraction, labelled latent scores, simulation, update/refit and bounded lifecycle guards at the earned standalone scope.
- Removed the public temporal-source-pair surface and relocated its former package tests to retained developer history.
- Updated the grammar, help, README, NEWS, keyword-grid material, temporal article, and validation register for the standalone boundary.
- Retained an immutable three-OS receipt for GitHub Actions run `34922613507`; macOS, Ubuntu, and Windows all passed.
- Ran `TEMPORAL_PROGRAM_PUBLICATION_PASS` and `TEMPORAL_PROGRAM_CLOSEOUT_PASS` against `.unlazy/temporal-program/publication-ci-34922613507-7693bbe44.rds`.

## Current Working State

- **Working:** branch `codex/temporal-program-20260909` is pushed and includes this handover; resolve its tip before work; the standalone temporal implementation is locally implemented and verified.
- **In progress:** no implementation or compute work. The next owed work is reader-facing article refinement only.
- **Blocked / deferred:** all temporal source-pair combinations and any wider forecast, interval, profile, selection, bootstrap, recovery, or coverage claims beyond their existing bounded standalone contracts.

## Key Decisions and Rationale

1. **Standalone provider, not a sixth full grid row.** Temporal ordering and time-scale semantics are distinct from stable-unit covariance sources. Public teaching therefore presents the stable-unit 5 × 3 grid plus one temporal provider.
2. **AR1 and OU only.** AR1 is discrete-time persistence, including negative persistence and integer gaps. OU is continuous-time positive decay on user-supplied numeric elapsed time. Toeplitz, heteroscedastic, seasonal, ARMA, and temporal Matérn structures are future modelling decisions.
3. **Temporal is not `unit` or `unit_obs`.** `series` identifies an independent temporal sequence; `time` selects the temporal state. Existing `unit` and nested `unit_obs` components retain their ordinary meanings.
4. **Article claims must match evidence.** Say “locally implemented and verified” for the named standalone route. Do not say merged, released, cross-platform verified as a product-wide release claim, or generally recovered / covered.
5. **Do not edit the shared active-lane map.** It diverges across many active refs. This handover is intentionally self-contained and leaves `docs/dev-log/handover/2026-07-25-active-lane-split.md`, `AGENTS.md`, and `CLAUDE.md` protected.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `codex/temporal-program-20260909` (resolve pushed tip before work) | yes | yes | none | LANDED branch state for the documentation worktree |
| `.unlazy/temporal-program/publication-ci-34922613507-7693bbe44.rds` | ignored retained evidence | local only | none | PROTECTED; do not delete or fabricate |
| `graft/` | no | no | none | PROTECTED untracked repository index; never stage or remove |
| `docs/dev-log/handover/2026-07-25-active-lane-split.md` and other live lanes | mixed | mixed | mixed | PROTECTED; do not edit from this lane |

**FINDINGS-OF-RECORD: none.** This handover records a completed software-validation arc and the next article task; it creates no branch-only scientific finding.

## Files Created / Modified

The temporal programme changed the following paths relative to merge base `3e646cbf28c585251a369949c62ab86d9e112f85`. This exhaustive list is generated directly from Git history; the next lane should edit only the article-related subset after a fresh lane preflight.

```text
.github/workflows/R-CMD-check.yaml
.unlazy/temporal-ar1/GATES.md
AGENTS.md
CLAUDE.md
NAMESPACE
NEWS.md
R/aghq-report.R
R/bootstrap-lv-effects.R
R/bootstrap-sigma.R
R/brms-sugar.R
R/extract-repeatability.R
R/extractors.R
R/fit-multi.R
R/gllvmTMB.R
R/imports.R
R/julia-bridge.R
R/loading-ci-bootstrap.R
R/loading-ci.R
R/loading-profile.R
R/methods-gllvmTMB.R
R/ordination-uncertainty.R
R/output-methods.R
R/phylo-signal-ci.R
R/profile-derived.R
R/profile-targets.R
R/proportions-ci.R
R/select-lv.R
R/temporal-bootstrap.R
R/temporal-forecast.R
R/temporal-profile.R
R/temporal-selection.R
R/temporal.R
R/traits-keyword.R
R/z-confint-gllvmTMB.R
README.md
_pkgdown.yml
dev/gapclose/build-capability-status.R
dev/temporal-ar1/ACCEPTANCE-REVISION.md
dev/temporal-ar1/REVIEWS.md
dev/temporal-ar1/recovery-cell-summary.csv
dev/temporal-ar1/recovery-design-exploration.csv
dev/temporal-ar1/recovery-exploration-24-results.csv
dev/temporal-ar1/recovery-exploration-24-summary.csv
dev/temporal-ar1/recovery-exploration-24-unrep-phi0-multistart.csv
dev/temporal-ar1/recovery-optimizer-diagnosis.csv
dev/temporal-ar1/recovery-results-bfgs.csv
dev/temporal-ar1/recovery-results.csv
dev/temporal-ar1/recovery-uncertainty-summary.csv
dev/temporal-ar1/recovery.R
dev/temporal-ar1/run-recovery-exploration-24.R
dev/temporal-ar1/run-recovery.R
dev/temporal-ar1/verify.R
dev/temporal-program/ADDITIVE-SOURCE-CONTRACT.md
dev/temporal-program/ANIMAL-RECOVERY-DIAGNOSTIC.md
dev/temporal-program/BASE-PROVIDER-CI-CANDIDATE-20260910.md
dev/temporal-program/BOOTSTRAP-CONTRACT.md
dev/temporal-program/DIRECT-PROFILE-CONTRACT.md
dev/temporal-program/DOCUMENTATION-AUDIT-20260909.md
dev/temporal-program/FORECAST-CONTRACT.md
dev/temporal-program/KERNEL-IDENTIFICATION-REDESIGN.md
dev/temporal-program/LOCAL-PACKAGE-CHECK-20260909.md
dev/temporal-program/OU-SOURCE-MATHEMATICAL-REVIEW-20260912.md
dev/temporal-program/PHYLO-OPTIMIZER-QUALIFICATION.md
dev/temporal-program/PLAN.md
dev/temporal-program/PUBLICATION-READINESS.md
dev/temporal-program/RESUME.md
dev/temporal-program/SELECTION-CONTRACT.md
dev/temporal-program/SPATIAL-RECOVERY-DIAGNOSTIC.md
dev/temporal-program/TEMPORAL-DEP-ANIMAL-CONTRACT.md
dev/temporal-program/TEMPORAL-DEP-KERNEL-160-QUALIFICATION-CONTRACT.md
dev/temporal-program/TEMPORAL-DEP-KERNEL-160-QUALIFICATION-RESULTS-20260912.md
dev/temporal-program/TEMPORAL-DEP-KERNEL-CONTRACT.md
dev/temporal-program/TEMPORAL-DEP-KERNEL-CURVATURE-REVIEW-20260912.md
dev/temporal-program/TEMPORAL-DEP-KERNEL-INFORMATION-DIAGNOSTIC.md
dev/temporal-program/TEMPORAL-DEP-KERNEL-INFORMATION-RESULTS-20260911.md
dev/temporal-program/TEMPORAL-DEP-KERNEL-NUMERICAL-FOLLOWUP-CONTRACT.md
dev/temporal-program/TEMPORAL-DEP-PHYLO-CONTRACT.md
dev/temporal-program/TEMPORAL-DEP-SPATIAL-CONTRACT.md
dev/temporal-program/TEMPORAL-DEP-SPATIAL-CORRECTED-SCALE-CAMPAIGN.md
dev/temporal-program/TEMPORAL-KERNEL-FORECAST-CONTRACT.md
dev/temporal-program/TEMPORAL-LATENT-ANIMAL-CONTRACT.md
dev/temporal-program/TEMPORAL-LATENT-KERNEL-CONTRACT.md
dev/temporal-program/TEMPORAL-LATENT-PHYLO-CONTRACT.md
dev/temporal-program/TEMPORAL-LATENT-PHYLO-ENDPOINT-DIAGNOSTIC-CONTRACT.md
dev/temporal-program/TEMPORAL-LATENT-SPATIAL-CONTRACT.md
dev/temporal-program/TEMPORAL-OU-KERNEL-CONTRACT.md
dev/temporal-program/TEMPORAL-OU-KERNEL-RECOVERY-CONTRACT.md
dev/temporal-program/continuation/PHYLO-DAMPED-NEWTON-CANDIDATE.md
dev/temporal-program/continuation/PHYLO-THIRD-PASS.md
dev/temporal-program/diagnose-dep-kernel-curvature.R
dev/temporal-program/diagnose-dep-kernel-information.R
dev/temporal-program/diagnose-dep-kernel-retained-curvature.R
dev/temporal-program/diagnose-latent-phylo-endpoint.R
dev/temporal-program/make-publication-ci-receipt.R
dev/temporal-program/remote/collect-phylo-recovery.R
dev/temporal-program/remote/dep-kernel-160-qualification-totoro.sh
dev/temporal-program/remote/dep-kernel-information-totoro.sh
dev/temporal-program/remote/dep-spatial-corrected-scale-totoro.sh
dev/temporal-program/remote/phylo-damped-newton-common.R
dev/temporal-program/remote/phylo-damped-newton-drac.sh
dev/temporal-program/remote/phylo-damped-newton-task.R
dev/temporal-program/remote/phylo-damped-newton.R
dev/temporal-program/remote/phylo-optimizer-qualification.R
dev/temporal-program/remote/phylo-recovery-common.R
dev/temporal-program/remote/phylo-recovery-drac.sh
dev/temporal-program/remote/phylo-recovery-task.R
dev/temporal-program/remote/phylo-third-pass-common.R
dev/temporal-program/remote/phylo-third-pass.R
dev/temporal-program/remote/prepare-phylo-recovery-runtime.sh
dev/temporal-program/results/animal-recovery-160-20260909.csv
dev/temporal-program/results/animal-recovery-160-summary-20260909.csv
dev/temporal-program/results/animal-third-pass-diagnostic-20260909.csv
dev/temporal-program/results/continuation/phylo-damped-newton-local-probe-20260910/phi_0.6_seed_2609185.rds
dev/temporal-program/results/continuation/phylo-third-pass-local-six-20260910/control_phi06_seed2609181.rds
dev/temporal-program/results/continuation/phylo-third-pass-local-six-20260910/control_phi0_seed2609181.rds
dev/temporal-program/results/continuation/phylo-third-pass-local-six-20260910/control_phim04_seed2609181.rds
dev/temporal-program/results/continuation/phylo-third-pass-local-six-20260910/failure_phi06_seed2609183.rds
dev/temporal-program/results/continuation/phylo-third-pass-local-six-20260910/failure_phi06_seed2609185.rds
dev/temporal-program/results/continuation/phylo-third-pass-local-six-20260910/failure_phi0_seed2609188.rds
dev/temporal-program/results/continuation/phylo-third-pass-local-six-20260910/summary.csv
dev/temporal-program/results/corrected-scale-20260911/.gitkeep
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-01-phase.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-01.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-02-phase.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-02.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-03-phase.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-03.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-04-phase.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-04.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-05-phase.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-05.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-06-phase.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-06.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-07-phase.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-07.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-08-phase.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-08.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-09-phase.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-attempt-09.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-recovery.csv
dev/temporal-program/results/corrected-scale-20260911/dep-spatial-corrected-scale-summary.csv
dev/temporal-program/results/corrected-scale-20260911/totoro-finalize.log
dev/temporal-program/results/corrected-scale-20260911/totoro-logs/attempt-2.log
dev/temporal-program/results/corrected-scale-20260911/totoro-logs/attempt-3.log
dev/temporal-program/results/corrected-scale-20260911/totoro-logs/attempt-4.log
dev/temporal-program/results/corrected-scale-20260911/totoro-logs/attempt-5.log
dev/temporal-program/results/corrected-scale-20260911/totoro-logs/attempt-6.log
dev/temporal-program/results/corrected-scale-20260911/totoro-logs/attempt-7.log
dev/temporal-program/results/corrected-scale-20260911/totoro-logs/attempt-8.log
dev/temporal-program/results/corrected-scale-20260911/totoro-logs/attempt-9.log
dev/temporal-program/results/corrected-scale-20260911/totoro-logs/build.log
dev/temporal-program/results/dep-animal-recovery-20260911.csv
dev/temporal-program/results/dep-animal-recovery-attempt-01-20260911.csv
dev/temporal-program/results/dep-animal-recovery-attempt-02-20260911.csv
dev/temporal-program/results/dep-animal-recovery-attempt-03-20260911.csv
dev/temporal-program/results/dep-animal-recovery-attempt-04-20260911.csv
dev/temporal-program/results/dep-animal-recovery-attempt-05-20260911.csv
dev/temporal-program/results/dep-animal-recovery-attempt-06-20260911.csv
dev/temporal-program/results/dep-animal-recovery-attempt-07-20260911.csv
dev/temporal-program/results/dep-animal-recovery-attempt-08-20260911.csv
dev/temporal-program/results/dep-animal-recovery-attempt-09-20260911.csv
dev/temporal-program/results/dep-animal-recovery-summary-20260911.csv
dev/temporal-program/results/dep-kernel-recovery-20260911.csv
dev/temporal-program/results/dep-kernel-recovery-summary-20260911.csv
dev/temporal-program/results/dep-phylo-recovery-20260911.csv
dev/temporal-program/results/dep-phylo-recovery-summary-20260911.csv
dev/temporal-program/results/dep-spatial-recovery-attempt-01-20260911.csv
dev/temporal-program/results/dep-spatial-recovery-attempt-02-20260911.csv
dev/temporal-program/results/dep-spatial-recovery-attempt-03-20260911.csv
dev/temporal-program/results/dep-spatial-recovery-attempt-04-20260911.csv
dev/temporal-program/results/diagnostics/.gitkeep
dev/temporal-program/results/diagnostics/dep-kernel-information-20260911/dep-kernel-information-n160-seed2609221.rds
dev/temporal-program/results/diagnostics/dep-kernel-information-20260911/dep-kernel-information-n160-seed2609222.rds
dev/temporal-program/results/diagnostics/dep-kernel-information-20260911/dep-kernel-information-n160-seed2609223.rds
dev/temporal-program/results/diagnostics/dep-kernel-information-20260911/dep-kernel-information-n80-seed2609221.rds
dev/temporal-program/results/diagnostics/dep-kernel-information-20260911/dep-kernel-information-n80-seed2609222.rds
dev/temporal-program/results/diagnostics/dep-kernel-information-20260911/dep-kernel-information-n80-seed2609223.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-curvature-20260911/dep-kernel-retained-curvature-v1-2609221.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-curvature-20260911/dep-kernel-retained-curvature-v1-2609222.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-curvature-20260911/dep-kernel-retained-curvature-v1-2609223.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-curvature-final-20260911/dep-kernel-retained-curvature-v1-2609221.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-curvature-final-20260911/dep-kernel-retained-curvature-v1-2609222.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-curvature-final-20260911/dep-kernel-retained-curvature-v1-2609223.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-curvature-hardened-20260911/dep-kernel-retained-curvature-v1-2609221.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-curvature-hardened-20260911/dep-kernel-retained-curvature-v1-2609222.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-curvature-hardened-20260911/dep-kernel-retained-curvature-v1-2609223.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-oracle-20260911/dep-kernel-retained-oracle-v1-2609221.csv
dev/temporal-program/results/diagnostics/dep-kernel-retained-oracle-20260911/dep-kernel-retained-oracle-v1-2609221.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-oracle-20260911/dep-kernel-retained-oracle-v1-2609222.csv
dev/temporal-program/results/diagnostics/dep-kernel-retained-oracle-20260911/dep-kernel-retained-oracle-v1-2609222.rds
dev/temporal-program/results/diagnostics/dep-kernel-retained-oracle-20260911/dep-kernel-retained-oracle-v1-2609223.csv
dev/temporal-program/results/diagnostics/dep-kernel-retained-oracle-20260911/dep-kernel-retained-oracle-v1-2609223.rds
dev/temporal-program/results/diagnostics/dep-spatial-attempt-03-fit-only-20260911-phase.csv
dev/temporal-program/results/diagnostics/dep-spatial-attempt-03-fit-only-20260911.csv
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-01.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-02.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-03.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-04.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-05.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-06.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-07.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-08.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-09.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-10.rds
dev/temporal-program/results/diagnostics/latent-phylo-endpoint-20260912-coordinate-11.rds
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/RESULTS.md
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-1/attempt-01.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-1/frozen-plan.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-2/attempt-02.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-2/frozen-plan.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-3/attempt-03.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-3/frozen-plan.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-4/attempt-04.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-4/frozen-plan.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-5/attempt-05.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-5/frozen-plan.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-6/attempt-06.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-6/frozen-plan.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-7/attempt-07.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-7/frozen-plan.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-8/attempt-08.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-8/frozen-plan.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-9/attempt-09.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/attempt-9/frozen-plan.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/ou-kernel-recovery-20260912.csv
dev/temporal-program/results/failed/ou-kernel-recovery-20260912/ou-kernel-recovery-summary-20260912.csv
dev/temporal-program/results/failed/phylo-recovery-160-fir-59096255-20260910/phylo-recovery-160-20260909.csv
dev/temporal-program/results/failed/phylo-recovery-160-fir-59096255-20260910/phylo-recovery-160-summary-20260909.csv
dev/temporal-program/results/failed/phylo-recovery-initial-20260909.csv
dev/temporal-program/results/failed/phylo-recovery-initial-summary-20260909.csv
dev/temporal-program/results/kernel-recovery-20260909.csv
dev/temporal-program/results/kernel-recovery-summary-20260909.csv
dev/temporal-program/results/latent-animal-recovery-20260911.csv
dev/temporal-program/results/latent-animal-recovery-summary-20260911.csv
dev/temporal-program/results/latent-kernel-recovery-20260911.csv
dev/temporal-program/results/latent-kernel-recovery-current-20260914.csv
dev/temporal-program/results/latent-kernel-recovery-current-summary-20260914.csv
dev/temporal-program/results/latent-kernel-recovery-summary-20260911.csv
dev/temporal-program/results/latent-phylo-recovery-20260911.csv
dev/temporal-program/results/latent-phylo-recovery-summary-20260911.csv
dev/temporal-program/results/latent-spatial-recovery-20260911.csv
dev/temporal-program/results/latent-spatial-recovery-summary-20260911.csv
dev/temporal-program/results/phylo-recovery-160-20260909.csv
dev/temporal-program/results/phylo-recovery-160-tasks-20260909.csv
dev/temporal-program/results/publication-ci-34842749688-20260914.rds
dev/temporal-program/results/qualification-160-20260912/dep-kernel-160-phi-0.4-seed2609341.rds
dev/temporal-program/results/qualification-160-20260912/dep-kernel-160-phi-0.4-seed2609342.rds
dev/temporal-program/results/qualification-160-20260912/dep-kernel-160-phi-0.4-seed2609343.rds
dev/temporal-program/results/qualification-160-20260912/dep-kernel-160-phi0-seed2609341.rds
dev/temporal-program/results/qualification-160-20260912/dep-kernel-160-phi0-seed2609342.rds
dev/temporal-program/results/qualification-160-20260912/dep-kernel-160-phi0-seed2609343.rds
dev/temporal-program/results/qualification-160-20260912/dep-kernel-160-phi0.6-seed2609341.rds
dev/temporal-program/results/qualification-160-20260912/dep-kernel-160-phi0.6-seed2609342.rds
dev/temporal-program/results/qualification-160-20260912/dep-kernel-160-phi0.6-seed2609343.rds
dev/temporal-program/results/qualification-20260910/README.md
dev/temporal-program/results/qualification-20260910/fir-59103979-phi0-seed2609188-19756f2a-step1e-5.rds
dev/temporal-program/results/qualification-20260910/local-phi0-seed2609188-19756f2a-step1e-5.rds
dev/temporal-program/results/qualification-20260910/local-phi0-seed2609188-c9a185414-runsqrt-eps.rds
dev/temporal-program/results/qualification-20260910/local-phi0-seed2609188-uncommitted-step1e-5.rds
dev/temporal-program/results/spatial-recovery-20260909.csv
dev/temporal-program/results/spatial-recovery-80-summary-20260909.csv
dev/temporal-program/retained-source-pair-tests/README.md
dev/temporal-program/retained-source-pair-tests/fixtures/temporal-phylo-optimizer-qualification-controls.R
dev/temporal-program/retained-source-pair-tests/test-temporal-phylo-damped-newton.R
dev/temporal-program/retained-source-pair-tests/test-temporal-phylo-optimizer-qualification.R
dev/temporal-program/retained-source-pair-tests/test-temporal-phylo-third-pass.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-animal-replicated.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-bootstrap.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-animal.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-kernel-160-qualification.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-kernel-curvature.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-kernel-information.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-kernel-native-dense.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-kernel-retained-curvature.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-kernel-retained-oracle.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-kernel.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-phylo.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-spatial-runner.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-dep-spatial.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-forecast-kernel.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-kernel-replicated.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-latent-animal.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-latent-kernel.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-latent-phylo.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-latent-spatial.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-ou-kernel-recovery-runner.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-ou-kernel.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-phylo-replicated.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-profile.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-selection.R
dev/temporal-program/retained-source-pair-tests/test-temporal-program-spatial-replicated.R
dev/temporal-program/run-animal-recovery.R
dev/temporal-program/run-dep-animal-recovery.R
dev/temporal-program/run-dep-kernel-160-qualification.R
dev/temporal-program/run-dep-kernel-recovery.R
dev/temporal-program/run-dep-phylo-recovery.R
dev/temporal-program/run-dep-spatial-recovery.R
dev/temporal-program/run-kernel-recovery.R
dev/temporal-program/run-latent-animal-recovery.R
dev/temporal-program/run-latent-kernel-recovery.R
dev/temporal-program/run-latent-phylo-recovery.R
dev/temporal-program/run-latent-spatial-recovery.R
dev/temporal-program/run-ou-kernel-recovery.R
dev/temporal-program/run-phylo-recovery-initial.R
dev/temporal-program/run-phylo-recovery.R
dev/temporal-program/run-spatial-recovery.R
dev/temporal-program/verify-dep-kernel-native-dense.R
dev/temporal-program/verify-dep-kernel-retained-oracle.R
dev/temporal-program/verify.R
dev/temporal-sixth-source/CONTRACT.md
dev/temporal-sixth-source/run-recovery.R
dev/temporal-sixth-source/verify.R
docs/design/00-vision.md
docs/design/01-formula-grammar.md
docs/design/03-likelihoods.md
docs/design/04-random-effects.md
docs/design/06-extractors-contract.md
docs/design/35-validation-debt-register.md
docs/design/capability-status.md
docs/dev-log/after-task/2026-09-08-temporal-ar1-native-provider.md
docs/dev-log/after-task/2026-09-09-temporal-sixth-source.md
docs/dev-log/after-task/2026-09-10-temporal-phylo-drac-recovery.md
docs/dev-log/after-task/2026-09-14-temporal-standalone-scope.md
docs/dev-log/check-log.md
docs/dev-log/known-limitations.md
docs/dev-log/plans/temporal-ar1-20260908/ACCEPTANCE.md
docs/dev-log/plans/temporal-ar1-20260908/HANDOVER.md
docs/dev-log/plans/temporal-ar1-20260908/PLAN.md
docs/dev-log/recovery-checkpoints/2026-09-09-temporal-program-phylo-overrun.md
docs/dev-log/recovery-checkpoints/2026-09-09-temporal-sixth-source-checkpoint.md
docs/dev-log/recovery-checkpoints/2026-09-11-1600-codex-temporal-program-checkpoint.md
man/anova.gllvmTMB_multi.Rd
man/bootstrap_temporal.Rd
man/compare_temporal.Rd
man/extract_temporal.Rd
man/forecast_temporal.Rd
man/gllvmTMB.Rd
man/gllvmTMBcontrol.Rd
man/gllvm_julia_fit.Rd
man/profile_temporal.Rd
man/simulate.gllvmTMB_multi.Rd
man/temporal_latent.Rd
man/update.gllvmTMB_multi.Rd
src/gllvmTMB.cpp
tests/testthat/helper-temporal-program-repo-root.R
tests/testthat/test-temporal-ar1-methods.R
tests/testthat/test-temporal-ar1-oracles.R
tests/testthat/test-temporal-ar1-parser.R
tests/testthat/test-temporal-ar1-regressions.R
tests/testthat/test-temporal-ar1-verify-runner.R
tests/testthat/test-temporal-program-bootstrap.R
tests/testthat/test-temporal-program-composed-simulation.R
tests/testthat/test-temporal-program-forecast.R
tests/testthat/test-temporal-program-profile.R
tests/testthat/test-temporal-program-selection.R
tests/testthat/test-temporal-program-simulation.R
tests/testthat/test-temporal-sixth-source-api.R
tests/testthat/test-temporal-sixth-source-engine.R
tests/testthat/test-temporal-sixth-source-oracles.R
tests/testthat/test-temporal-sixth-source-regressions.R
vignettes/articles/api-keyword-grid.Rmd
vignettes/articles/temporal-ar1.Rmd
```

This handover itself adds `docs/dev-log/handover/2026-09-15-codex-temporal-article-handover.md`. It deliberately does not modify the shared `AGENTS.md`, `CLAUDE.md`, or active-lane split pointer because they are multi-lane coordination surfaces with live divergent edits.

## Verification Evidence

Completed implementation evidence:

```sh
Rscript --vanilla dev/temporal-program/verify.R self-test
# TEMPORAL_PROGRAM_SELF_TEST_PASS

Rscript --vanilla dev/temporal-program/verify.R lifecycle
# TEMPORAL_PROGRAM_LIFECYCLE_PASS

TEMPORAL_PROGRAM_CI_RECEIPT=.unlazy/temporal-program/publication-ci-34922613507-7693bbe44.rds \
  Rscript --vanilla dev/temporal-program/verify.R publication
# TEMPORAL_PROGRAM_PUBLICATION_PASS

TEMPORAL_PROGRAM_CI_RECEIPT=.unlazy/temporal-program/publication-ci-34922613507-7693bbe44.rds \
  Rscript --vanilla dev/temporal-program/verify.R closeout
# TEMPORAL_PROGRAM_CLOSEOUT_PASS
```

GitHub Actions run `34922613507` completed successfully on macOS, Ubuntu, and Windows for commit `7693bbe44`.

## Next Immediate Steps

1. Create a **fresh worktree and branch** from `origin/codex/temporal-program-20260909`; do not write in the completed implementation worktree.
2. Run `bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"` and claim only the article, its navigation entry if required, its associated roxygen/help, and a new temporal article test if needed. Respect any foreign ownership result.
3. Read `vignettes/articles/temporal-ar1.Rmd`, `vignettes/articles/api-keyword-grid.Rmd`, `README.md`, `NEWS.md`, `R/temporal.R`, `man/temporal_latent.Rd`, `man/extract_temporal.Rd`, `docs/design/01-formula-grammar.md`, and `docs/design/35-validation-debt-register.md` before deciding whether a wording or worked-example change is needed.
4. Write article acceptance gates before editing: long/wide AR1 example, long/wide OU example, a clear `series`/`time`/`unit`/`unit_obs` explanation, scope-boundary wording, rendered article, `pkgdown::check_pkgdown()`, and a focused test only where executable article code needs it.
5. Use the live R/TMB toolchain for `devtools::document()`, article rendering, and package checks. Codex owns those live checks; review prose and scope before opening a PR. Do not merge.

## Blockers / Open Questions

- No technical blocker exists for the article lane.
- Decide during the article audit whether the current article already satisfies the intended teaching goal. If it does, record that outcome and avoid a cosmetic duplicate.
- Do not treat a new documentation article as authority to broaden the model contract.

## Gotchas / Failed Approaches

- Do not call the user-facing feature a “6 × 3 grid” or imply all temporal source combinations exist.
- Do not explain `time = occasion` as an ordinary fixed effect. It supplies the temporal coordinate; fixed time effects, if substantively needed, are separate formula terms.
- Do not reclassify `unit_obs` as a replicate identifier. `replicate =` is explicit when replicated measurements are used.
- Do not stage `graft/`.
- Do not change the shared active-lane split merely to advertise this lane; preflight found live divergence across 18 refs.
- Do not reuse old source-pair tests as article validation. They are retained, developer-only history.

## How to Resume

From a fresh Codex worktree based on the verified branch, paste:

```text
Read AGENTS.md, docs/dev-log/handover/2026-07-25-active-lane-split.md, and docs/dev-log/handover/2026-09-15-codex-temporal-article-handover.md. Reconcile them with current git state, then create the reader-facing standalone temporal article refresh described in Next Immediate Steps. Preserve the 5 × 3 stable-unit grid plus one standalone AR1/OU temporal provider; do not revive temporal source-pair extensions.
```
