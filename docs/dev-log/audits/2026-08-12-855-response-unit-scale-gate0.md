# Gate 0 — #855 response-unit scale equivariance

**Date:** 2026-08-12
**Branch:** `codex/scale-equivariance-gate0` at `cb312689`
**Verdict:** **NO-GO for internal per-trait response scaling on the current parameterisation.**

## Question

Can the package divide each eligible Gaussian identity-link trait by its own
response scale internally, fit once, and back-transform its public results while
preserving the fitted model?

## Governing obstruction

No.  The current native likelihood has one pooled residual parameter,
`sigma_eps = exp(log_sigma_eps)`, for every Gaussian and lognormal row.  For
trait-specific scales `s_t`, the Gaussian transformation

```
y'_it = y_it / s_t
eta'_it = eta_it / s_t
sigma'_t = sigma_eps / s_t
```

requires a residual SD for every scaled trait.  One scalar cannot equal all
`sigma_eps / s_t` when the `s_t` differ.  Changing it would be a new residual
parameterisation, not an internal implementation detail.  The previous #856
attempt to vectorise this parameter was explicitly halted as based on a false
premise; its retained report is a do-not-reuse warning, not implementation
evidence.

The exact eligibility predicate makes the stop condition stronger: for all
observed rows, the family/link must be Gaussian/identity, all `s_t` must be
finite and positive, and the fitted parameterisation must admit
`eta*_it = eta_it / s_t` and `sigma*_t = sigma_eps / s_t`.  With one scalar
residual SD, that is possible only when every eligible trait has the same
scale.  A common global scale is therefore already a valid transformation; an
unequal trait-scale vector is not.

Consequently, the only exact current-model equivariance remains the common
scale transformation already guarded by `test-scale-equivariance.R`: `y -> k y`
for the measured ordinary single-tier Gaussian `latent()` regime.  This gate
does not broaden that claim.

## Source-verified consumer map

| Surface | Evidence | Gate 0 disposition |
| --- | --- | --- |
| Engine response and residual SD | `R/fit-multi.R` builds `tmb_data$y`; `src/gllvmTMB.cpp` evaluates Gaussian `dnorm(y, eta, sigma_eps)` and reports `eta` / `sigma_eps`. | **BLOCKED**: trait-specific scaling requires trait-specific residual semantics. |
| Fixed effects, loadings, Psi, Sigma | `predict()`, `summary()`, `tidy()`, `extract_Sigma()`, `extract_ordination()` expose response-unit quantities. | Would require trait-vector / outer-product back-transforms. Do not implement piecemeal. |
| Prediction and simulation | `R/methods-gllvmTMB.R`: `predict()` reads `report$eta`; `simulate()` draws from `eta` and `sigma_eps`; `bootstrap_Sigma()` reuses simulation. | **BLOCKED** until engine/public-scale contract is redesigned and tested. |
| Residuals and diagnostics | `R/predictive-diagnostics.R`, `R/diagnose.R`, and `R/extract-sigma.R` jointly read `tmb_data$y`, `report$eta`, and `report$sigma_eps`. | **BLOCKED**: a partial transform would silently corrupt residual and link-residual diagnostics. |
| Likelihood comparisons | `logLik.gllvmTMB_multi()` returns the objective-derived likelihood and rejects non-unit likelihood weights. | For unweighted ML, a common-scale Jacobian is `-n_obs log(k)`. Per-trait scaling would require an eligibility-aware correction; REML needs a separate derivation and is excluded. |
| Invariant outputs | latent scores, correlations, communalities, and variance proportions are algebraically invariant only after a successful fit. | Preserve existing behaviour; do not use invariance as evidence that an upstream transform is safe. |

## What a future architecture would have to prove

For `D = diag(s_t)`, a genuine trait-scale implementation would require
`Lambda* = D^-1 Lambda`, `Psi* = D^-1 Psi D^-1`, and
`Sigma* = D^-1 Sigma D^-1`; latent scores remain standardised.  Every additive
piece of `eta` must follow the same row scale.  That includes offsets, fixed
and shared coefficients, constrained loadings, random slopes, and common
variance structures.  Each is currently an additional closure condition, not
an automatic consequence of changing `tmb_data$y`.

For observed row `i`, the ML relation is
`nll_raw = nll_scaled + sum_i log(s_t(i))`; a weighted objective would instead
carry `sum_i w_i log(s_t(i))`, and masked rows contribute neither term.
`logLik()` rejects non-unit likelihood weights today, but a transform must
still preserve the stored criterion.  REML is excluded until its integration
measure has its own derivation and oracle.

## Explicit fences

- This concerns **response-unit scale equivariance**, not the package's
  `loading_scale = "standardized"` output convention.
- No claim is made for non-Gaussian families, mixed-family-within-trait data,
  REML, constrained/shared-coefficient models, offsets, all covariance tiers,
  or old fit objects.
- #851 remains closed: its scale-aware start is deliberately confined to the
  measured ordinary Gaussian B-tier path.
- #872 two-tier likelihood flatness and #897 ordinal degeneracy detection are
  unrelated and remain deferred.

## Next legal work

Do not open an implementation arc for #855 as stated.  The smallest viable
successor is a separately approved architecture decision: either retain the
pooled residual scale and address individual measured constants locally, or
design and validate a per-trait residual model as a new capability before
reconsidering response-unit scaling.  The latter needs its own mathematical
contract, simulation plan, pre-run estimate, and compute approval if it crosses
the 30-minute threshold.
