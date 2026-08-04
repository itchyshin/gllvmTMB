# SE=FALSE Consumer Methods Probe

## What was run

This probe tests whether SE-consuming methods in gllvmTMB **fail cleanly** or **silently return NAs**
when a fit is made with `se = FALSE` (so `fit$sd_report` is NULL).

### Test Script

```r
# Load package
devtools::load_all('/private/tmp/gllvmtmb-va-lane2')

# Create minimal dataset (2 traits, 40 reps)
set.seed(2024L)
n_traits  <- 2L
n_reps    <- 40L
grid <- expand.grid(
  rep_idx = seq_len(n_reps),
  trait_idx = seq_len(n_traits)
)
grid$trait <- factor(c('a', 'b')[grid$trait_idx], levels = c('a', 'b'))
grid$obs_id <- factor(seq_len(nrow(grid)))
grid$eta  <- c(1.0, 2.0)[grid$trait_idx] + rnorm(nrow(grid), 0, 0.2)
grid$value <- grid$eta + rnorm(nrow(grid), 0, 0.3)

# Fit with se=FALSE
fit_no_se <- gllvmTMB(
  value ~ 0 + trait,
  data    = grid,
  family  = gaussian(),
  unit    = 'obs_id',
  control = gllvmTMBcontrol(se = FALSE)
)

# Test: summary(), tidy(), confint(method='wald'), vcov(), .gllvmTMB_b_fix_se()
```

**Fit diagnostics:**
- se=FALSE fit: `sd_report` is NULL
- Fit converged without error and was suitable for testing

## Results Table

| Method | Errored | Warned | Returned | Has NA | Message |
|--------|---------|--------|----------|--------|---------|
| summary | NO | NO | YES | NO | OK: returned without NA |
| tidy | YES | NO | NO | NO | ERROR: object 'tidy.gllvmTMB' not found |
| confint(wald) | NO | NO | YES | YES | SILENT: returned with 4 NA values |
| vcov | YES | NO | NO | NO | ERROR: no applicable method for 'vcov' applied to an object of class "c('gllvmTMB_multi', 'gllvmTMB')" |
| .gllvmTMB_b_fix_se | NO | NO | YES | YES | SILENT: returned with 2 NA values |

## Verdict

**REAL** — The silent-NA gap is REAL. Some methods (listed above) silently return NAs without warning when se=FALSE, rather than failing cleanly.

---

**Timestamp:** 2026-08-04 08:36:46 UTC
**Probe runtime:** se=FALSE Gaussian gllvmTMB fit, 2 traits, 40 reps, minimal.

