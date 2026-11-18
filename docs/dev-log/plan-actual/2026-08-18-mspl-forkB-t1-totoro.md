# Plan vs actual — Totoro T1 (Design 125 fork B)

**Date:** 2026-08-18
**Lane:** `cursor/mspl-fork-B-totoro-20260818`

| Planned | Actual | Tag |
|---|---|---|
| Smoke-first one new cell on Totoro | `T1-anchor-n40-T8` / 20260830 PASS (RDS 724, LOG 698, `Q_0`/B) | as-planned |
| 4 × 200 = 800 at ≤16 cores | 800 rows, 16 workers, 15.3 s, no empty cell | as-planned |
| Do not freeze T\* | `tstar_status: NOT-FROZEN` | as-planned |
| Do not undraft #1077 / public se | held | as-planned |
| Local 1-rep × 4 before Totoro | skipped; user locked one-cell Totoro smoke then 800 | adaptive |
| Conservative wall 20–40 min incl. deploy | deploy already present; panel 15.3 s | adaptive |
