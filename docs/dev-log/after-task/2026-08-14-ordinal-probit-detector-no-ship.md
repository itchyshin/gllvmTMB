# After Task: #897 ordinal-probit detector admission — no ship

**Branch**: `codex/897-ordinal-detector-admission`  
**Date**: 2026-08-14  
**Roles (engaged)**: Ada, Gauss, Rose, Curie, Fisher

## 1. Goal

Determine whether an ordinary native-Laplace ordinal-probit diagnostic could identify silently unreliable shared covariance without transferring binomial thresholds. The required outcome was either one bounded, validated `check_gllvmTMB()` warning or an evidence-backed fence.

## 2. Implemented

No package behaviour shipped. Private `dev/` machinery now pins and records the ordinary Gaussian-free ordinal-probit fixture, per-cell route/DGP/fit receipts, resumed cells, frozen development thresholds, and independent hold-out scoring. The decision is **no ship**: #897 remains open and fenced because the held-out campaign did not complete and the completed development denominators are too small and too ambiguous for a user-facing warning.

## 3. Files Changed

- `dev/897-ordinal-detector-admission.R`: immutable fixture, native-Laplace route checks, atomic cell receipts, and resumability.
- `dev/897-ordinal-detector-totoro-preflight.sh` and `dev/897-ordinal-detector-totoro-campaign.sh`: isolated Totoro execution, thread cap, install/run logs, and manifests.
- `dev/897-ordinal-detector-calibrate.R` and `dev/897-ordinal-detector-validate.R`: frozen development rule and no-retuning hold-out scorer.
- `docs/dev-log/release/2026-08-09-pre-0.7-issue-disposition-ledger.md`: #897 fence receipt.
- This after-task report. `README.md`, `NEWS.md`, `ROADMAP.md`, `docs/dev-log/known-limitations.md`, vignettes, roxygen, Rd, `_pkgdown.yml`, tests, and package source were inspected and deliberately unchanged: no user behaviour changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain the #897 fence and do not add a `check_gllvmTMB()` row. **Rationale:** the development sentinel had 7 degenerate and 15 healthy truth-labelled rows; its apparent 1.00/1.00 in-sample performance is not calibration. The independent run was stopped after exceeding its estimate, retaining only 42 of 80 cells. **Rejected:** porting binomial prevalence/loading thresholds, lowering the acceptance rule, completing the 40-hour full grid without a revised approval, or treating converged/PD fits as healthy covariance estimates. **Confidence:** high for no-ship; no conclusion about the underlying ordinal mechanism.

## 4. Checks Run

- Totoro four-cell pre-run, commit `fe618705`: 4/4 `OK`, all native ordinal-probit route checks true, elapsed 594.81 s serial, maximum RSS 2.92 GB; SHA-256 manifest verified at `~/gllvm_work/results/897-ordinal-detector/totoro-preflight-sha256.txt`.
- Totoro sentinel development, commit `b117b243`: 80 retained receipts in 6m04s. Statuses: 79 `OK`, 1 `INVALID_DGP`; truth labels: 7 degenerate, 15 healthy, 57 ambiguous, 1 unusable. The fixed rule (`relative_loading >= 2 OR saturation >= .02 OR cutpoint spacing <= .01 OR rare category <= .005`) scored 7/7 and 15/15 on development only.
- Totoro sentinel hold-out, commit `e4214fd9`: stopped at 42 retained receipts after a severe overrun; statuses: 40 `OK`, 2 `INVALID_DGP`; labels: 8 degenerate, 4 healthy, 28 ambiguous, 2 unusable. It is incomplete and not used to claim sensitivity/specificity.
- Local `Rscript --vanilla dev/897-ordinal-detector-admission.R --timing-smoke`: known positive remained `OK` with `rel_frob = 232.24` before the campaign harness was extended.
- `Rscript --vanilla -e 'parse(...)'` passed for both analysis scripts; `bash -n dev/897-ordinal-detector-totoro-campaign.sh` passed.

## 5. Tests of the Tests

The private known-positive timing smoke is a failure-before-fix fixture: it retains a converged, PD-Hessian fit with shared-covariance relative Frobenius error above 10. The high-`n` pre-run and sentinel cells are healthy/boundary controls. No package test was added because no package diagnostic was admitted.

## 6. Consistency Audit

- `rg -n "#897|ordinal.*diagn|ordinal.*probit" docs/dev-log/release docs/dev-log/known-limitations.md docs/design/35-validation-debt-register.md NEWS.md R/diagnose.R`: verdict — the only public-package detector remains binomial-only; the release ledger and limits fence are consistent with no ordinal detector.
- `rg "Sigma_B|Sigma_W|Lambda_B|Lambda_W|latent\\(|unique\\(|indep\\(|dep\\(" README.md ROADMAP.md docs vignettes R tests`: verdict — no scope claim was added; ordinary latent terminology remains unchanged.
- `rg "full.*rejected|only diagonal|planned.*implemented|deprecated.*0\\.1" README.md ROADMAP.md NEWS.md docs vignettes`: verdict — no stale release-promotion wording introduced by this no-ship record.

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row changed; #897 stays a release fence rather than a scheduled feature.

## 7a. GitHub Issue Ledger

Inspected [#897](https://github.com/itchyshin/gllvmTMB/issues/897). No comment, closure, or status promotion was made: the incomplete hold-out cannot support it. Nearby draft PRs #960, #958, #957, #956 and unrelated #955 were inspected for coordination only.

## 8. What Did Not Go Smoothly

The initial 3,840-cell campaign vastly exceeded its 20–90 minute estimate and was stopped after about 2.5 hours; its first harness wrote only an end-of-run aggregate, so partial results were not evidence. Atomic per-cell RDS receipts fixed that defect. The 80-cell hold-out also overran its <=15 minute estimate because concurrent high-`n` fits became much slower; 42 receipts were retained before it was stopped. One development and two hold-out DGPs had an empty intended category and correctly remained `INVALID_DGP` rather than being silently dropped.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** kept package source and public surfaces untouched when the evidence gate did not earn a diagnostic.

**Gauss:** required native-Laplace route checks (`family_id = 14`, rank-2 B tier, no diagonal Psi, `random = z_B`) before any covariance label could count.

**Rose:** kept the distinction between a development pattern and a held-out calibrated warning; no “resolved” wording is warranted.

**Curie:** exposed the need for failure-retaining, atomic per-cell receipts and a stop-on-overrun protocol.

**Fisher:** rejected pooled in-sample apparent accuracy as a sensitivity/specificity result; ambiguous and invalid cells remain in denominators.

## 10. Known Limitations And Next Actions

The package still has no calibrated ordinal-probit saturation/degeneracy detector. This work does not establish prevalence, mechanism, recovery, a general threshold, or user-warning value, and does not touch AGHQ, VA/EVA, structured tiers, slopes, two-tier/Psi models, likelihood/default controls, or intervals. Any future #897 work needs a newly approved, cost-calibrated and interrupted-safe design with enough independent healthy and degenerate rows per advertised regime; it must re-run a held-out acceptance gate before proposing package code.
