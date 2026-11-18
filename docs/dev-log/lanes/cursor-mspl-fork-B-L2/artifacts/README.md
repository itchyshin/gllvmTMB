# L2 smoke artifacts (local only)

K1 runner: `dev/mspl-forkB-l2-smoke.R` (reuses `dev/mspl-forkB-l1-ademp.R`).
Smoke-first driver: `dev/mspl-forkB-l2-k2-smoke-first.sh`.

**Not** the official K4 receipt
(`docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md` — write that
only after the 50-rep panel).

Verify by reading the `.md` / `.rds`, never the process exit code.

| Arc | Cell | seed_base | n_rep | Paths |
|---|---|---|---|---|
| K2a | `L1-neartail-n40-T4` | 20260821 | 1 | [md](../../../research/2026-08-18-mspl-forkB-l2-k2-L1-neartail-n40-T4-20260821-n1.md) · [rds](../../../research/2026-08-18-mspl-forkB-l2-k2-L1-neartail-n40-T4-20260821-n1.rds) |
| K2b | `L1-anchor-n80-T8` | 20260819 | 1 | [md](../../../research/2026-08-18-mspl-forkB-l2-k2-L1-anchor-n80-T8-20260819-n1.md) · [rds](../../../research/2026-08-18-mspl-forkB-l2-k2-L1-anchor-n80-T8-20260819-n1.rds) |

Both 1-rep walks: `smoke_ok = TRUE`, two-sided `Q_0` / fork B, `L2-RECORDED`,
`calibrated: FALSE`, `public_confint: refused`. Near-tail is ready for
`--n_rep=50` with the same flags. Official L1 seed `20260818` inherited.
