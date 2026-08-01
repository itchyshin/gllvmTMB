# After-task: slope-per-family gap ledger (D-113 track 6 / Arc 0)

**Branch:** `claude/slope-per-family-20260801` @ `origin/main` tip  
**Date:** 2026-08-01  
**Worktree:** `/private/tmp/gllvmtmb-slope-per-family-20260801`  
**Roles:** Curie (ledger) · Ada (lane)

## Goal

Map every runtime `family_to_id` (0–15) against intercept evidence, `phylo_indep(1+x)` slope evidence, and membership in `.augmented_slope_family_contract()` on **main tip** before admitting betabinomial.

## Method

Read `R/fit-multi.R` (`.augmented_slope_family_contract`, `family_to_id`), slope test inventory under `tests/testthat/`, and register rows FAM-*/RE-02/PHY-11..18. No capability claims beyond this inventory.

## Ledger (main tip, pre-admission)

| id | Family | Intercept / matrix | `phylo_indep(1+x)` slope test | In slope contract? | Status for D-113 DoD |
| ---: | --- | --- | --- | --- | --- |
| 0 | gaussian | covered | `test-phylo-indep-slope-gaussian.R` | yes (route_specific) | met |
| 1 | binomial | covered | `test-binomial-slope-recovery.R` (logit/probit) | yes (logit+probit) | met |
| 2 | poisson | covered | `test-phylo-indep-slope-nongaussian.R` + matrix | yes | met |
| 3 | lognormal | covered | `test-family-slope-recovery.R` (C1) | yes (c1_partial) | met (C1) |
| 4 | Gamma | covered | nongaussian + `test-matrix-slope-gamma.R` | yes | met |
| 5 | nbinom2 | covered | nongaussian + matrix | yes | met |
| 6 | tweedie | covered (intercept) | **GATED** — fail-loud boundary in `test-matrix-slope-phylo-indep.R`; campaign deferred | **no** | open (deferred: multi-seed campaign) |
| 7 | Beta | covered | nongaussian + matrix | yes | met |
| 8 | betabinomial | covered (FAM-05 intercept) | `test-family-slope-recovery.R` (C1, large-N) — **ADMITTED 2026-08-01** | **yes** (c1_partial, logit) | met (C1); see admission after-task |
| 9 | student | covered | `test-family-slope-recovery.R` (C1) | yes (c1_partial) | met (C1) |
| 10 | truncated_poisson | partial | none | no | open (later) |
| 11 | truncated_nbinom2 | partial | none | no | open (later) |
| 12 | delta_lognormal | partial / fenced | none | no | open (later; delta fence) |
| 13 | delta_gamma | partial / fenced | none | no | open (later; delta fence) |
| 14 | ordinal_probit | covered | nongaussian + matrix | yes | met |
| 15 | nbinom1 | covered | route-specific (phylo_dep VALIDATION + contract); not in C1 file on tip | yes (route_specific) | met |

**Contract source of truth on tip:** single table `.augmented_slope_family_contract()` in `R/fit-multi.R` (not six duplicated integer vectors). Six guards call `.augmented_slope_family_allowed()`.

## Rung 1 target

Admit **betabinomial (8)** as `c1_partial` (logit / `link_0` only) after a multi-trial recovery cell lands in `test-family-slope-recovery.R`, mirroring binomial `cbind(succ, fail)` semantics and the C1 plausibility band used for lognormal/student.

## Explicitly not covered by this ledger

- Coverage / interval calibration (D-112).
- Tweedie slope campaign.
- Missing-data phases #336–#338.
- EVA / AGHQ / #750 / SEPARABLE.

## Checks

- `git rev-parse HEAD` on worktree = `origin/main` at scaffold time.
- `bash ~/shinichi-brain/tools/branch_drift_check.sh` → 0 ahead / 0 behind at branch birth.
