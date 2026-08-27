# Gaussian/lognormal scale consumer map

Date: 2026-08-27  
Source pin: `origin/main` at `870944744ff090fe8676e853ebc03957204571c0`  
Status: pre-implementation checklist

The joint Gaussian/lognormal repair keeps `log_sigma_eps` length one for every
existing pure-family or non-0+3 fit. It has two slots only when family IDs 0 and
3 coexist: Gaussian raw-scale SD first, lognormal log-scale SD second.

## Likelihood and construction

- `src/gllvmTMB.cpp:1018`: scalar parameter declaration becomes a vector.
- `src/gllvmTMB.cpp:2745-2805`: assert length from `family_id_vec`, exponentiate
  both slots, and select the matching slot in fid 0 and fid 3 densities.
- `R/fit-multi.R:3606-3607`: joint starts must be computed separately on raw
  Gaussian residuals and lognormal `log(y)` residuals.
- `R/fit-multi.R:4812-4815`: parameter list carries length one or two.
- `R/fit-multi.R:5856-5885`: map length follows parameter length; current
  per-row-diagonal suppression remains all-or-nothing for the first slice.
- `R/fit-multi.R:5338-5341`: Gaussian-only VGH warm-start copy stays restricted
  to the length-one route.

## One authoritative selector

Replace the scalar-only `.gllvmTMB_sigma_eps()` implementation in
`R/predictive-diagnostics.R` with a vector-safe reader plus
`.gllvmTMB_sigma_eps_for_family(fit, family_id)`. The fallback must select all
repeated `log_sigma_eps` names from `opt$par`; bracket lookup by name silently
returns only the first slot.

## Consumers that must dispatch by family

- `R/methods-gllvmTMB.R`: `.apply_linkinv_per_row()`,
  `.dlinkinv_per_row()`, `.draw_y_per_family()`, and response-scale prediction.
- `R/family-cdf-args.R`: Gaussian and lognormal CDF arguments and notes.
- `R/predictive-diagnostics.R`: exact-CDF/randomized-quantile residual branches.
- `R/output-methods.R`: `VP()` observation residual contribution. A trait that
  mixes fid 0 and fid 3 cannot select one trait-level slot and must fail loud or
  return an explicit unavailable value.
- `R/diagnose.R`: mapped/boundary reporting for both free slots.
- `R/profile-targets.R`: dual fits expose indexed `sigma_eps` targets; the
  existing unindexed pure-fit target remains unchanged.

`extract_Sigma(part = "shared", link_residual = "none")` does not change:
lognormal link residual remains zero and the scientific latent target is still
`Lambda Lambda^T`. Julia remains on its current scalar contract; a dual 0+3
predictor-informed route is native-Laplace-only until separately designed.

## Required proof

1. Pure Gaussian and pure lognormal likelihood/estimate parity.
2. Equal-scale joint objective parity with the old pooled density.
3. Unequal-scale joint recovery and finite gradient/Hessian.
4. Repeated-name fallback, response-link, simulation, CDF residual, `VP()`,
   diagnostics, and profile-index tests.
5. Existing per-row-diagonal suppression and all neighbouring pure-family
   tests remain green.

No live fit or production edit was made while compiling this map.
