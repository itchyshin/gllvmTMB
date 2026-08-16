# Tweedie live MSPL hang vs the W_* two-sided rule

**Date:** 2026-08-16
**Lane:** `cursor/mspl-tweedie-hang`
**Status:** AGENT-INFERRED diagnosis + fenced tape change. Not a covered
claim. Not an admit. No public door. No `se=TRUE`.

## Cell

`#999` 8×3 ordinary `latent(d=1)` Tweedie-log, `y = recycle(0.5, 1, 2)`.
Public `estimator = "mspl"` hung (>5 min, 99% CPU) after the planned
door in #1014. Tweedie **ML** on the same cell returned in 1.274 s (#1014) and 0.786 s on this sitting.
`setTimeLimit` does not interrupt TMB's compiled inner loop, so CI
used `skip_if`.

## Mechanism

True GLM weight (log link, `V(μ) = μ^p`, `1 < p < 2`):

`W = μ^{2-p} / φ`

Two-sided vanishing test (vault `2026-08-16-mspl-all-families-theory`
§4.3, AGENT-INFERRED): existence for `||β|| → ∞` needs `W → 0` at
**both** infinities of `η`.

| path | true W | Jeffreys `P = ½ log det(X'WX)` |
|---|---|---|
| `η → -∞` | `→ 0` | `→ -∞` (kills) |
| `η → +∞` | `→ +∞` (`2-p > 0`) | `→ +∞` (rewards) |
| `φ → 0` | `→ +∞` | `→ +∞` (rewards) |
| `φ → +∞` | `→ 0` | `→ -∞` (kills) |

`dW / dη = (2-p) W > 0`. Same one-sided bug as live Poisson
`W = diag(μ)`. The hang is the optimiser chasing the **rewarded**
`φ → 0` (and/or `η → +∞`) ridge into a region where `dtweedie`
series cost explodes. The likelihood itself is not the hang: ML
finishes.

This is **not** a missing public door. The C++ tape existed. The
atom was the wrong existence penalty.

## Repair (fenced)

Working logistic `W_* = μ_*(1-μ_*)` on the same `η = X_*β`
(2023 `P^(f)`). It vanishes at both infinities and does not see
`φ`. Huber / live `gll_mspl_pseudohuber` on `log φ` and
`logit(p-1)` kills the extra-parameter boundaries.

Working `W_*` is an existence device, not true-model Jeffreys.
Registry stays `planned`. Prepare allow-list stays
`c(0L, 1L, 2L, 5L, 15L)`. Probe-only env
`GLLVMTMB_MSPL_TWEEDIE_PROBE=1` can reach the cell for a
timeout-bounded hang check. Not a user door.

## Probe (2026-08-16, this branch)

Installed this tree to a temp lib. `GLLVMTMB_MSPL_TWEEDIE_PROBE=1`,
`se=FALSE`, `n_init=1`, `OMP=1`. OS timeout, not `setTimeLimit`.

- 90 s: no return (`PROBE_START_FIT` never reached in the first
  `load_all` attempt).
- 180 s against the installed temp lib: `PROBE_START_FIT` printed;
  **no return**. Killed at 180 s.

Working `W_*` + Huber is the right existence tape and is now in
C++. It did **not** unstick the known cell. A second mechanism
remains (Tweedie `dtweedie` × Laplace AD cost and/or a long
`nlminb` path). That is why the hang fuse stays `TRUE` and the
public door stays closed.

**BLOCKED** as a hang-fix for `#999`. Do not fake a door.

## What this is not

- Not an admit. Not NEWS covered. Not public `se=TRUE`.
- Not a Poisson `W = diag(μ)` replacement (separate slice).
- Not a proof of E1–E3 + `||∇P|| = o_p(1)` for Tweedie GLLVMs.
- Not a licence to lift `#999` live pins. The 180 s probe failed.

## Minimal reproduction (door closed on main)

```r
# After GLLVMTMB_MSPL_TWEEDIE_PROBE=1 and a local install of this
# branch. Use OS timeout, not setTimeLimit.
dat <- data.frame(
  site = factor(rep(1:8, each = 3)),
  trait = factor(rep(paste0("t", 1:3), 8)),
  y = rep(c(0.5, 1, 2), length.out = 24)
)
gllvmTMB(
  y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
  data = dat, family = tweedie(), estimator = "mspl",
  control = gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE,
                            warn_runaway = FALSE)
)
```
