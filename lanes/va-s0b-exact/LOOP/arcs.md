# Arcs — va-s0b-exact

| id | status | arc | gate |
| --- | --- | --- | --- |
| B0 | done | Scaffold LOOP + protocol + scripts (generalise S0a) | — |
| B1 | done | Totoro Gate/runtime smoke (one poisson VA row) | compute |
| B2 | done | Full fresh plan+run+export (3 cells × 300 seeds × 2 q × 2 est = 3600) | compute |
| B3 | done | Absolute-first scientific ledger | — |
| B4 | done | After-task + check-log + plan-actual; STOP for S1 | **G0c open S1?** |

## Seed choice

**10301:10600** (n=300). Same band as S0a; disjoint from Arc-2 `1:500` and S0a
`10001:10300`. Enough for abs recovery; Gamma may still fail reliability (Arc-2
signal) — that is a result, not a reason to inflate seeds mid-run.

## Caps

Default β RMSE ≤ 0.35, Σ rel Frob ≤ 0.50 (flexible: propose alternate only if
default is misleading). Abs-availability ≥ 0.90.
