# Audit: M3.3 failure-mode ledger

**Date**: 2026-05-19
**Branch**: `codex/m3-3-failure-mode-triage-2026-05-19`
**Production run reviewed**:
<https://github.com/itchyshin/gllvmTMB/actions/runs/26100827665>
**Roles**: Ada, Fisher, Curie, Gauss, Grace, Rose

## Verdict

The M3.3 failure is not one failure. It separates into at least four
diagnostic classes:

1. **Systematic upper-bound misses for `psi`.** Across all failed
   converged rows in the production artifacts, the true `psi` was above
   the profile upper bound. No converged miss was a lower-bound miss.
2. **Non-Gaussian `psi` collapse.** Binomial, nbinom2,
   ordinal-probit, and several mixed-family traits have median
   `est_psi / truth_psi` near zero, while many profile upper bounds are
   either infinite or still too small for the simulated truth.
3. **Count-family and mixed-family convergence/refit failure.** nbinom2
   had 101 failed replicate fits out of 600. Mixed-family had 105
   failed replicate fits out of 600, worsening with rank.
4. **A Gaussian d = 2 anomaly.** Gaussian d = 1 and d = 3 passed or
   narrowly passed the 94 % gate, but Gaussian d = 2 missed badly
   despite only one failed replicate fit. This points to a target/profile
   issue that is not count-family-specific.

M3.3 should not proceed directly to another full 15-cell production
rerun. Slice 2 should first audit the target scale: whether the
production grid should be validating per-trait `psi`, total diagonal
`Sigma_unit[tt]`, or both, and whether `tmbprofile_wrapper()` is
calibrated for the chosen non-Gaussian variance target.

## Production Failure Ledger

This table is reconstructed from the downloaded full grid artifacts.
`below` and `above` count uncovered converged trait rows where the true
`psi` was below the lower bound or above the upper bound.

| Cell | Coverage | Failed reps | Misses below | Misses above | Median `est_psi / truth_psi` | Initial class |
|---|---:|---:|---:|---:|---:|---|
| `binomial-d1` | 0.926 | 3 | 0 | 73 | 1.29e-09 | near-gate target/identifiability |
| `binomial-d2` | 0.896 | 4 | 0 | 102 | 9.10e-10 | target/identifiability |
| `binomial-d3` | 0.856 | 2 | 0 | 143 | 1.66e-09 | rank-amplified target/identifiability |
| `gaussian-d1` | 0.966 | 2 | 0 | 34 | 0.629 | passed |
| `gaussian-d2` | 0.870 | 1 | 0 | 129 | 0.592 | profile/target anomaly |
| `gaussian-d3` | 0.941 | 2 | 0 | 58 | 0.595 | passed but marginal |
| `mixed-d1` | 0.820 | 11 | 0 | 170 | 1.00e-05 | mixed target + nbinom2 component |
| `mixed-d2` | 0.685 | 38 | 0 | 252 | 1.39e-07 | mixed convergence + target |
| `mixed-d3` | 0.550 | 56 | 0 | 322 | 6.85e-09 | mixed convergence + target |
| `nbinom2-d1` | 0.495 | 30 | 0 | 429 | 4.83e-06 | severe count-family target/convergence |
| `nbinom2-d2` | 0.372 | 35 | 0 | 518 | 9.65e-07 | severe count-family target/convergence |
| `nbinom2-d3` | 0.229 | 36 | 0 | 632 | 1.80e-07 | severe count-family target/convergence |
| `ordinal_probit-d1` | 0.790 | 5 | 0 | 205 | 1.98e-08 | ordinal target/latent-scale identifiability |
| `ordinal_probit-d2` | 0.784 | 4 | 0 | 212 | 3.52e-09 | ordinal target/latent-scale identifiability |
| `ordinal_probit-d3` | 0.752 | 7 | 0 | 239 | 3.14e-09 | ordinal target/latent-scale identifiability |

## Trait-Level Patterns

The mixed-family cells show the expected family imprint. In the M3 DGP,
mixed traits 1 and 4 are Gaussian, traits 2 and 5 are binomial, and
trait 3 is nbinom2. The nbinom2-like trait 3 is the worst mixed-family
trait in every rank (`0.545`, `0.444`, `0.257` coverage), but the
Gaussian-like traits also deteriorate sharply at higher rank. This means
mixed-family failure is not only "the nbinom2 trait is bad"; higher-rank
joint fitting is also contributing.

The ordinal-probit cells have low failed-refit counts but broad
undercoverage across traits. That makes ordinal a target-scale or
latent-threshold identifiability problem first, not a convergence
problem.

## Comparator Probe

The user asked to compare against other software. Ada ran a small
glmmTMB probe on the same nbinom2 DGP seeds:

- target: single-trait total latent-scale random-intercept SD,
  `sqrt(truth_diag_sigma[t])`;
- model: `glmmTMB(value ~ 1 + (1 | unit), family = nbinom2())`;
- scope: nbinom2, d = 1, 20 reps x 5 traits.

Result:

| Comparator | Target | Fits converged | Profile bounds available | Coverage among available profiles | Coverage counting missing profiles as failures |
|---|---|---:|---:|---:|---:|
| `glmmTMB` 1.1.13 | total single-trait random-intercept SD | 99/100 | 70/100 | 0.914 | 0.640 |

Interpretation: glmmTMB also finds this n = 60 nbinom2 variance-profile
problem rough: many profile bounds fail to interpolate, and Hessian
warnings appear in some fits. But when glmmTMB returns a profile bound,
the completed intervals are not systematically too low in this small
probe. That differs from the production gllvmTMB `psi` grid, where the
completed intervals themselves often miss because the true `psi` is
above the upper bound.

The comparator does **not** validate the same target as M3.3. It checks
total single-trait random-intercept variance, while the current M3.3
grid checks the multivariate `psi` component. That target difference is
now a leading hypothesis, not a nuisance detail.

galamm 0.4.0 is installed locally, but it is not a direct nbinom2
comparator: its documented families are Gaussian, binomial, poisson, and
mixed combinations of those families. A single-trait binomial random
intercept probe also fails because there is one observation per unit
after subsetting to one trait (`number of levels of each grouping factor
must be < number of observations`). galamm may still be useful for a
multivariate binomial latent-factor comparator, but it is not the next
tool for the nbinom2 failure.

## Slice 2 Questions

Slice 2 should answer these before any full rerun:

1. Does M3.3 need to validate `truth_psi`, `truth_diag_sigma`, or both?
2. For non-Gaussian families, is per-trait `psi` separately identified
   enough at n = 60 to justify a 94 % profile-coverage gate?
3. Are the current `theta_diag_B` profile intervals on the same scale
   and target as the DGP truth column they are compared against?
4. Should the production grid keep `psi` as a component diagnostic but
   move the M3.3 promotion gate to a total diagonal variance target?
5. Which minimal rerun cells are needed after the target audit:
   `gaussian-d2`, one nbinom2 cell, one ordinal-probit cell, and one
   mixed-family cell remain the starting set.

## Commands

```sh
gh run download 26100827665 --repo itchyshin/gllvmTMB \
  --dir /tmp/gllvmtmb-m3-artifacts-26100827665-triage

Rscript --vanilla - <<'EOF'
root <- "/tmp/gllvmtmb-m3-artifacts-26100827665-triage"
gfiles <- list.files(root, pattern = "grid[.]rds$", recursive = TRUE, full.names = TRUE)
grid <- do.call(rbind, lapply(gfiles, function(f) readRDS(f)$grid))
conv <- !is.na(grid$covered_prof)
grid$miss_side <- NA_character_
grid$miss_side[conv & grid$covered_prof] <- "covered"
grid$miss_side[conv & !grid$covered_prof & grid$truth_psi < grid$ci_prof_lo] <- "truth_below_lower"
grid$miss_side[conv & !grid$covered_prof & grid$truth_psi > grid$ci_prof_hi] <- "truth_above_upper"
grid$miss_side[conv & !grid$covered_prof & is.na(grid$ci_prof_lo)] <- "lower_na"
grid$miss_side[conv & !grid$covered_prof & is.na(grid$ci_prof_hi)] <- "upper_na"
grid$miss_side[conv & !grid$covered_prof & is.na(grid$miss_side)] <- "other_miss"
EOF
```

Comparator probes were run with local `glmmTMB` 1.1.13 and `galamm`
0.4.0.
