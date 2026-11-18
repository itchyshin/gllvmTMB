# Arcs — cursor-mspl-phase4-student-ordinal

| ID | Status | Arc | Notes |
|---|---|---|---|
| A0 | **DONE** | LOOP kit on isolated worktree | no root `LOOP/` |
| A1 | **DONE** | RED oracle tests | helpers missing; `could not find function` |
| A2 | **DONE** | GREEN helpers + notes | student **51/51**; ordinal **45/45** |
| A3 | **DONE** | Explicit-path commit + push + DRAFT PR | [#1005](https://github.com/itchyshin/gllvmTMB/pull/1005); no merge |

## Structured counts (A2 log)

### Student-t (identity) — 13 blocks / 51

| ID | block | n |
|---|---|---|
| S1 | location weight vs Gaussian | 5 |
| S2 | \(\mu\)-inert \(P_J\) | 3 |
| S3 | \(\nu\to\infty\) / \(\nu\to 1^+\) | 5 |
| S4 | \(\sigma\to 0\) anti-coercive | 3 |
| S5 | \(\sigma\to\infty\) | 3 |
| S6 | TMB \(1+\exp\) vs stale \(2+\exp\) | 6 |
| S7 | variance vs \(I_\mu\) at \(1<\nu\le 2\) | 6 |
| S8 | `dt` loglik + score FD | 2 |
| S9 | Hirose refused | 3 |
| S10 | \(V_{\mathrm{loading}}\) inert | 5 |
| S11 | identity only | 3 |
| S12 | no admitted / no planned row | 5 |
| — | no live `estimator="mspl"` | 2 |
| | **Total** | **51** |

### ordinal_probit — 12 blocks / 45

| ID | block | n |
|---|---|---|
| O1 | \(\tau_1=0\); probs sum to 1 | 7 |
| O2 | exact \(I_\eta\) moments | 4 |
| O3 | \(\lvert\eta\rvert\to\infty\Rightarrow P_J\to-\infty\) | 6 |
| O4 | cut collision | 4 |
| O5 | cut infinity | 3 |
| O6 | residual sd pinned at 1 | 2 |
| O7 | \(K=2\) probit vs \(K\ge 3\) | 3 |
| O8 | Hirose refused | 2 |
| O9 | \(V_{\mathrm{loading}}\) inert | 4 |
| O10 | not stacked Bernoulli / softmax | 3 |
| O11 | no admitted / no planned row | 5 |
| — | no live `estimator="mspl"` | 2 |
| | **Total** | **45** |

## HARD STOP flags

- Registry row / prepare widen / `R/mspl.R` / `src/` / admit / NEWS covered / public `se=TRUE` / merge
