# Cross-family correlation intervals — quick-start (experimental; please find bugs)

**Branch:** `claude/cross-family-intervals-20260718` (worktree `../gllvmTMB-cross-family-intervals`).
**Status:** the interval *methods run and are tested*, but **coverage is NOT yet certified** — the
intervals are **recovery-oriented / exploratory**, not calibrated 95% intervals (that's future work).
The whole point of this pass is: **run it on real data and report anything that breaks or looks wrong.**

## What's new
`extract_cross_correlations()` — which reports the association between a `multinomial()` (nominal)
trait and each partner trait — now attaches **confidence intervals** via a `method =` argument. Two
summaries per (nominal, partner) pair:
- **`multiple_r`** — the reference-invariant multiple correlation between the partner and the whole
  K−1 contrast block (a single number in [0, 1]).
- **`contrast_r`** — the per-contrast vector (partner vs each category-vs-baseline contrast).

Also new under the hood: `simulate()` now draws a multinomial response (the parametric bootstrap
needs it), so `simulate(fit)` / `bootstrap_Sigma(fit, ...)` work for cross-family multinomial fits.

## Install
From the built tarball (path given at handoff):
```r
install.packages("gllvmTMB_<version>.tar.gz", repos = NULL, type = "source")
```
…or point R at the worktree with `devtools::load_all("path/to/gllvmTMB-cross-family-intervals")`.

## Data shape (long format)
One row per (unit × trait) observation:
| column | meaning |
|---|---|
| `unit` | grouping unit (factor) — the level the latent factor varies over |
| `trait` | trait name (factor): the multinomial trait + the other-family partner traits |
| `value` | response: an integer category code for the multinomial trait; numeric for the others |
| `family` | a per-row family indicator column mapping each trait to its family |

## Fit a cross-family model
```r
library(gllvmTMB)
fam <- list(g = gaussian(), b = binomial(), m = multinomial())
attr(fam, "family_var") <- "family"          # tells gllvmTMB which family each row is

fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 2),
                data = dat, family = fam, trait = "trait", unit = "unit")
```

## Get the intervals — three routes
```r
## point estimates only (current default behaviour)
extract_cross_correlations(fit, contrasts = TRUE)

## (1) WALD — fast Fisher-z, always returns, ANY partner family. Best first pass.
extract_cross_correlations(fit, contrasts = TRUE, method = "wald")

## (2) BOOTSTRAP — parametric bootstrap for multiple_r (slower; nsim refits).
extract_cross_correlations(fit, method = "bootstrap", nsim = 200, seed = 1)

## (3) PROFILE — profile likelihood for each contrast_r (gaussian/binomial partners only).
extract_cross_correlations(fit, contrasts = TRUE, method = "profile")
```

## Output columns
- `nominal`, `partner`, `multiple_r` (+ `contrast_r` list-column when `contrasts = TRUE`).
- `multiple_r_lower` / `multiple_r_upper` / `multiple_r_method` / `multiple_r_interval_status` (scalars).
- `contrast_r_lower` / `contrast_r_upper` / `contrast_r_method` / `contrast_r_interval_status` (list-columns).
- `interval_status` is a **humility flag**: `"heuristic_unvalidated"` (wald) or
  `"target_specific_uncalibrated"` (bootstrap/profile) — **both mean coverage is NOT certified.**

## Which method to reach for
| method | estimands | speed | partner families | notes |
|---|---|---|---|---|
| `wald` | multiple_r + contrast_r | fast (no refits) | any | most approximate; always returns |
| `bootstrap` | multiple_r | slow (nsim refits) | any | can drop a pair if refits fail |
| `profile` | contrast_r | medium (root-find) | gaussian, binomial | fails loud on other families / structured tiers |

Start with **`wald`** for a first look; use `bootstrap`/`profile` where you want the more principled route.

## What fails loud (by design — tell us if any of these fire unexpectedly)
- `method = "profile"` needs `contrasts = TRUE` (multiple_r has no single profile parameter).
- `method = "profile"` only at the `unit` / `unit_obs` tier, gaussian/binomial partners.
- No `multinomial()` trait in the fit → error (use `extract_correlations()` instead).

## Please report
Crashes, `NA` intervals, intervals that don't bracket the point estimate, absurd widths — **especially**
on partner families beyond gaussian/binomial, large K, small numbers of units, or near-boundary
correlations. That feedback is exactly what we need before any coverage certification.
