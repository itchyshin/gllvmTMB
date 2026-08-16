# Tweedie live MSPL hang vs the W_* two-sided rule

**Date:** 2026-08-16
**Lane:** `cursor/mspl-tweedie-hang`
**Status:** Fenced hang-fix landed. Not a covered claim. Not an
admit. No public door. No public `se=TRUE`.

## Cell

`#999` 8×3 ordinary `latent(d=1)` Tweedie-log, `y = recycle(0.5, 1, 2)`.
Public `estimator = "mspl"` hung (>5 min, 99% CPU) after the planned
door in #1014. Tweedie **ML** on the same cell returned in 1.274 s
(#1014) and 0.786 s on this sitting. `setTimeLimit` does not interrupt
TMB's compiled inner loop.

## Mechanism (two layers)

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
`W = diag(μ)`. Layer 1 is the wrong existence penalty.

Layer 2, measured after working `W_*` was on the tape: first
`nlminb` and each `fn()`/`gr()` were milliseconds. The process then
sat in the MSPL **BFGS rescue** (`optim(..., maxit = 5000)` from
`par_init`) written for spatial Bernoulli. That walk enters the
`dtweedie` series-cost region. A later bookkeeping abort
(Huber `mspl_dispersion_nll` omitted from the penalty-off sum)
fired in 4.5 s once the rescue was skipped.

## Repair (fenced)

1. Working logistic `W_* = μ_*(1-μ_*)` on `η = X_*β` (2023 `P^(f)`),
   plus Huber on `log φ` and `logit(p-1)`. Existence device, not
   true-model Jeffreys.
2. Skip the MSPL BFGS rescue when `family_id == 6`.
3. Include `mspl_dispersion_nll` in the penalty-off decomposition
   sum.

Registry stays `planned`. Prepare allow-list stays
`c(0L, 1L, 2L, 5L, 15L)`. Probe-only env
`GLLVMTMB_MSPL_TWEEDIE_PROBE=1` can reach the cell. Not a user door.

## Probe (2026-08-16, this branch)

`pkgload::load_all` of this tree. `GLLVMTMB_MSPL_TWEEDIE_PROBE=1`,
`se=FALSE`, `n_init=1`. Default `nlminb` (no `iter.max` cap).

```
PROBE_OK class=gllvmTMB_mspl/gllvmTMB_multi/gllvmTMB
registry=planned elapsed=1.549s optimizer=nlminb
```

Hang fuse `.mspl_se_tweedie_live_hangs` is now `FALSE`. CI still
cannot start a public live fit: prepare rejects family 6 unless the
probe env is set.

## What this is not

- Not an admit. Not NEWS covered. Not public `se=TRUE`.
- Not a Poisson `W = diag(μ)` replacement (separate slice).
- Not a proof of E1–E3 + `||∇P|| = o_p(1)` for Tweedie GLLVMs.
- Not a licence to open the public Tweedie door.

## Minimal reproduction (probe env only)

```r
Sys.setenv(GLLVMTMB_MSPL_TWEEDIE_PROBE = "1")
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
