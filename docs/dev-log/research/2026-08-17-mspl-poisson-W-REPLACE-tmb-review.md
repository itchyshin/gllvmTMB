# tmb-likelihood-review — Poisson MSPL W_* REPLACE

**Date:** 2026-08-17  
**Change:** `gll_mspl_log_weight_glm` `family_id == 2` now returns
`gll_mspl_log_weight(eta, 0)` (working logistic \(W_*\)), matching the
Tweedie `family_id == 6` precedent. Response likelihood (`dpois`)
unchanged.  
**Docs:** `docs/design/03-likelihoods.md` § Opt-in LA-MSPL GLM-outer weights.  
**PR:** https://github.com/itchyshin/gllvmTMB/pull/1111

## tmb-likelihood-review checklist

- [x] Constrained scales untouched (no new parameters).
- [x] Constants in likelihood unchanged (Poisson PMF path untouched).
- [x] Weight is existence device, not true Jeffreys / not \(I_{LA}(\beta)\).
- [x] Twin R Jeffreys rematched to \(W_*\) (`R/mspl-poisson-atoms.R`).
- [x] #1064 W2/W7 assert new tape; W1 keeps true-\(W=\mu\) algebra.
- [x] Smoke `se=FALSE` converges; admit A7 logdet matches twin.
- [x] Local multi-seed recovery (A4) — not NEWS covered.
- [x] No public `se` / `vcov` / `confint` opened.
- [x] Gradients finite on Poisson MSPL smoke after TMB rebuild (A1 ship).
- [x] Boundary: live \(W_*\) two-sided; true \(W=\mu\) contrast only.

## Gauss (numerical / TMB)

- [x] `gll_mspl_log_weight(eta, 0)` is logit working weight (log \(p(1-p)\)).
- [x] R twin `plogis(eta)*(1-plogis(eta))` matches C++ atom (admit A7).
- [x] Tweedie `family_id == 6` remains the same working-logistic device.
- [x] Bernoulli `family_id == 1` path untouched.
- [x] Outer weight swap only; AD path already exercised by Tweedie \(W_*\).
- [x] No claim that soft Jeffreys \(P_J\) is true-model Jeffreys for Poisson.

## Noether (symbolic ↔ R ↔ C++ ↔ design)

- [x] Live \(W_*=\mu_*(1-\mu_*)\), \(\mu_*=\mathrm{plogis}(\eta)\) named in
  `03-likelihoods.md`, atoms header, cpp comment, admit notes.
- [x] True Poisson \(W=\mu\) / `return eta` retained as historical contrast only.
- [x] `.gllvmTMB_mspl_poisson_jeffreys(X, eta)` takes `eta` (not `mu`); callers updated.
- [x] W7 pins C++ no longer `return eta` for Poisson; W1 keeps true-\(W\) algebra.
- [x] Registry / admit notes say working logistic / G0 REPLACE / #1102.
- [x] `03-likelihoods.md` states **not** NEWS `covered` and no public SE.

## Hard OUT audit (must stay true through merge)

- [x] No `NEWS` / register **covered** for intervals or SE.
- [x] No public `se = TRUE` / `vcov` / `confint`.
- [x] `MSPL-04` remains `blocked`.
- [x] #1077 stays draft; no Totoro / Design 118 / Lane B absorb.

## Human skim still useful on #1111

Confirm the three surfaces agree before merge: cpp `family_id == 2` branch,
R twin, and the Poisson bullet in `03-likelihoods.md`. No further tape edit
needed from this note.
