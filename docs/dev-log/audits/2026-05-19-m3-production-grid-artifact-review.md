# Audit: M3.3 production grid artifact review

**Date**: 2026-05-19
**Branch**: `codex/m3-production-artifact-review-2026-05-19`
**Run**: <https://github.com/itchyshin/gllvmTMB/actions/runs/26100827665>
**Inputs**: `n_reps = 200`, `init_strategy = "single_trait_warmup"`,
`retention_days = 14`
**Roles**: Ada, Curie, Fisher, Grace, Rose

## Verdict

The production workflow itself passed: all 15 family-by-dimension
matrix jobs completed and uploaded artifacts. The statistical gate
failed. Only 2/15 profile-psi coverage cells met the 94 % audit-1
threshold (`gaussian-d1` and `gaussian-d3`). The full grid contained
236 failed replicate fits out of 3000 attempted replicate fits.

This evidence keeps CI-08 and CI-10 in `partial` status. No production
RDS should be promoted to `inst/extdata/`, and no reader-facing
coverage claim should move to `covered` from this run.

The uploaded summary RDS files also exposed a summary-count bug:
`m3_summarise()` filtered out failed rows before counting failures,
so each per-cell artifact reported `n_failed = 0`. This audit therefore
recounted failed replicates from the full grid artifacts. The branch
patches `dev/m3-grid.R` so future summaries count failed replicates
before coverage filtering.

## Coverage Matrix

| Cell | Reps | Converged | Failed | Trait rows | Profile coverage | Gate | Mean rep runtime (s) |
|---|---:|---:|---:|---:|---:|---|---:|
| `binomial-d1` | 200 | 197 | 3 | 985 | 0.926 | FAIL | 0.287 |
| `binomial-d2` | 200 | 196 | 4 | 980 | 0.896 | FAIL | 0.461 |
| `binomial-d3` | 200 | 198 | 2 | 990 | 0.856 | FAIL | 0.690 |
| `gaussian-d1` | 200 | 198 | 2 | 990 | 0.966 | PASS | 0.314 |
| `gaussian-d2` | 200 | 199 | 1 | 995 | 0.870 | FAIL | 0.328 |
| `gaussian-d3` | 200 | 198 | 2 | 990 | 0.941 | PASS | 0.300 |
| `mixed-d1` | 200 | 189 | 11 | 945 | 0.820 | FAIL | 0.516 |
| `mixed-d2` | 200 | 162 | 38 | 810 | 0.685 | FAIL | 0.530 |
| `mixed-d3` | 200 | 144 | 56 | 720 | 0.550 | FAIL | 0.775 |
| `nbinom2-d1` | 200 | 170 | 30 | 850 | 0.495 | FAIL | 0.612 |
| `nbinom2-d2` | 200 | 165 | 35 | 825 | 0.372 | FAIL | 0.736 |
| `nbinom2-d3` | 200 | 164 | 36 | 820 | 0.229 | FAIL | 0.832 |
| `ordinal_probit-d1` | 200 | 195 | 5 | 975 | 0.790 | FAIL | 0.505 |
| `ordinal_probit-d2` | 200 | 196 | 4 | 980 | 0.784 | FAIL | 0.656 |
| `ordinal_probit-d3` | 200 | 193 | 7 | 965 | 0.752 | FAIL | 0.901 |

Family-level averages across the three dimensions:

| Family | Converged reps | Failed reps | Mean coverage |
|---|---:|---:|---:|
| `binomial` | 591 | 9 | 0.892 |
| `gaussian` | 595 | 5 | 0.926 |
| `mixed` | 495 | 105 | 0.685 |
| `nbinom2` | 499 | 101 | 0.366 |
| `ordinal_probit` | 584 | 16 | 0.775 |

## Interpretation

The profile-psi path is not ready to support the advertised M3
coverage claim. The failure is not just sampling noise around the
94 % gate: nbinom2 and mixed-family coverage fall far below the
threshold, and mixed-family convergence worsens with dimension.
Gaussian is also not uniformly safe because `gaussian-d2` missed the
gate despite low failed-refit count.

The next M3 lane should diagnose the profile target, transform,
and calibration assumptions before rerunning the full matrix. A
minimal rerun should start with `gaussian-d2`, one nbinom2 cell, one
ordinal-probit cell, and one mixed-family cell after the failure mode
is understood.

## Commands

```sh
gh workflow run m3-production-grid.yaml --ref main \
  -f n_reps=200 \
  -f init_strategy=single_trait_warmup \
  -f retention_days=14
gh run watch 26100827665 --exit-status --interval 60
gh run download 26100827665 --dir /tmp/gllvmtmb-m3-artifacts-26100827665
Rscript --vanilla -e 'source("dev/m3-grid.R"); root <- "/tmp/gllvmtmb-m3-artifacts-26100827665"; gfiles <- list.files(root, pattern = "grid[.]rds$", recursive = TRUE, full.names = TRUE); grids <- lapply(gfiles, function(f) readRDS(f)$grid); grid <- do.call(rbind, grids); s <- m3_summarise(grid); s <- s[order(s$family, s$d), ]; print(s, row.names = FALSE)'
```
