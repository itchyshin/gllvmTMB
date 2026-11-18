# Arcs — cursor-mspl-phase4-nbinom1

| ID | Status | Arc | Notes |
|---|---|---|---|
| A0 | **DONE** | LOOP kit on isolated worktree | no root `LOOP/` |
| A1 | **DONE** | Copy sibling note + oracles (byte-identical) | no rewrite; no registry row |
| A2 | **DONE** | Re-run oracles; structured counts | superseded by R1 |
| A3 | **DONE** | Explicit-path commit + push + stacked PR on #971 | [#976](https://github.com/itchyshin/gllvmTMB/pull/976); no merge |
| R1 | **DONE** | Repair blocking NB1 exact-information review | PMF-summed exact Fisher; success probability fixed; **74/74 PASS** (14 blocks) |

## Structured counts (A2 log)

| ID | block | n |
|---|---|---|
| N1 | NB1 variance \(\mu(1+\varphi)\) vs Poisson / NB2 | 5 |
| N2 | exact PMF score/Fisher moments; differs from quasi weight | 9 |
| N3 | exact Jeffreys rejects quasi shared-\(\varphi\) identity | 7 |
| N4 | mean-boundary \(\to-\infty\) | 4 |
| N5 | near-zero \(\mu\) scaling | 3 |
| N6 | \(\varphi\to 0\) recovers Poisson, not \(-\infty\) | 4 |
| N7 | \(\varphi\to\infty\) \(\to-\infty\) | 3 |
| N8 | \(\theta=1/\varphi\) is not NB1 | 4 |
| N9 | exact exposure information is nonlinear | 8 |
| N10 | offset spelling | 3 |
| N11 | Hirose / \(V_{\mathrm{loading}}\) refused | 9 |
| N12 | size \(\mu/\varphi\); success \(1/(1+\varphi)\); \(\log(V-\mu)\) | 8 |
| N13 | no admitted / no planned registry row | 5 |
| — | no live `estimator="mspl"` | 2 |
| | **Total** | **74** |

## HARD STOP flags

- Rewrite science / registry row / prepare widen / `R/mspl.R` / `src/` / admit / merge
