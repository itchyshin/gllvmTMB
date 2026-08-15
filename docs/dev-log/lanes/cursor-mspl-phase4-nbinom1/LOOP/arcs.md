# Arcs — cursor-mspl-phase4-nbinom1

| ID | Status | Arc | Notes |
|---|---|---|---|
| A0 | **DONE** | LOOP kit on isolated worktree | no root `LOOP/` |
| A1 | **DONE** | Copy sibling note + oracles (byte-identical) | no rewrite; no registry row |
| A2 | **DONE** | Re-run oracles; structured counts | **68/68 PASS** (14 blocks) |
| A3 | in progress | Explicit-path commit + push + stacked PR on #971 | no merge |

## Structured counts (A2 log)

| ID | block | n |
|---|---|---|
| N1 | NB1 variance \(\mu(1+\varphi)\) vs Poisson / NB2 | 5 |
| N2 | \(W=\mu/(1+\varphi)\) | 5 |
| N3 | shared-\(\varphi\) Jeffreys identity | 5 |
| N4 | mean-boundary \(\to-\infty\) | 4 |
| N5 | near-zero \(\mu\) scaling | 3 |
| N6 | \(\varphi\to 0\) recovers Poisson, not \(-\infty\) | 5 |
| N7 | \(\varphi\to\infty\) \(\to-\infty\) | 4 |
| N8 | \(\theta=1/\varphi\) is not NB1 | 4 |
| N9 | exposure doubling | 7 |
| N10 | offset spelling | 3 |
| N11 | Hirose / \(V_{\mathrm{loading}}\) refused | 9 |
| N12 | size \(\mu/\varphi\); \(\log(V-\mu)\) | 7 |
| N13 | no admitted / no planned registry row | 5 |
| — | no live `estimator="mspl"` | 2 |
| | **Total** | **68** |

## HARD STOP flags

- Rewrite science / registry row / prepare widen / `R/mspl.R` / `src/` / admit / merge
