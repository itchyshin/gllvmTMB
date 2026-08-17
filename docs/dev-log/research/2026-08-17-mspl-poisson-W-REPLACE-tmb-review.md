# tmb-likelihood-review — Poisson MSPL W_* REPLACE

**Date:** 2026-08-17  
**Change:** `gll_mspl_log_weight_glm` `family_id == 2` now returns
`gll_mspl_log_weight(eta, 0)` (working logistic \(W_*\)), matching the
Tweedie `family_id == 6` precedent. Response likelihood (`dpois`)
unchanged.

## Checklist

- [x] Constrained scales untouched (no new parameters).
- [x] Constants in likelihood unchanged (Poisson PMF path untouched).
- [x] Weight is existence device, not true Jeffreys / not \(I_{LA}(\beta)\).
- [x] Twin R Jeffreys rematched to \(W_*\) (`R/mspl-poisson-atoms.R`).
- [x] #1064 W2/W7 assert new tape; W1 keeps true-\(W=\mu\) algebra.
- [x] Smoke `se=FALSE` converges; admit A7 logdet matches twin.
- [x] Local multi-seed recovery (A4) — not NEWS covered.
- [x] No public `se` / `vcov` / `confint` opened.

## Gauss / Noether

- **Gauss:** outer weight swap only; AD path already exercised by Tweedie \(W_*\).
- **Noether:** symbolic live weight = \(\mu_*(1-\mu_*)\) with \(\mu_*=\mathrm{plogis}(\eta)\); true Poisson \(W=\mu\) retained as contrast only.
