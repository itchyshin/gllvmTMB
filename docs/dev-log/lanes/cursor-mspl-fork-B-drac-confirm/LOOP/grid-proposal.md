# Grid proposal pointer — DRAC confirm panel

**Locked detail lives in the research note:**

`docs/dev-log/research/2026-08-19-mspl-forkB-drac-confirm-grid-proposal.md`

Absorbed from T1 grid proposal §Optional confirm and §Why not 3 seeds × every cell
(`docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md`).

**800 fits:**

| Block | cell_id | seeds | n_rep | fits |
|---|---|---|---:|---:|
| L1 confirm | `T1-confirm-n80-T8` | 20260834 | 200 | 200 |
| n160 multi-seed | `T1-anchor-n160-T8` | 20260831, 20260835, 20260836 | 200 each | 600 |

Do **not** start until T1 receipt is on `main` ([#1173](https://github.com/itchyshin/gllvmTMB/pull/1173)).
