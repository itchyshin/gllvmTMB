# Pre-run test (arc 3), 2026-09-30, Totoro

Tasks: reps 1-3 of all 72 cells (216 datasets) plus 4 datasets (rep 4, n=150, p=16, d=2, one per family) with `--check-auto`. 72 workers, `R_LIBS=~/autod-recovery/lib` (gllvmTMB 0.8.0.9000 built from e68391469), OPENBLAS_NUM_THREADS=1.

Checks (215 of 220 datasets finished when read):
- `gllvmTMB(d = "auto")$select_lv$selected_d` == `select_lv()$selected_d` on 4 of 4 (2=2, 2=2, 1=1, 2=2).
- Recomputed `bic_sites` argmin over eligible rows == `select_lv()$selected_d` on all 215.
- 0 aborts, 0 task errors.

Seconds per dataset (median / max over 3 to 12 datasets per family x n x p):

| family | n | p=8 | p=16 |
|---|---|---|---|
| gaussian | 50 / 150 / 400 | 1.8 / 2.0 / 3.3 | 2.1 / 3.2 / 8.0 |
| binomial | 50 / 150 / 400 | 1.8 / 3.4 / 8.3 | 3.0 / 8.5 / 38.2 |
| poisson | 50 / 150 / 400 | 3.3 / 9.0 / 35.7 | 8.0 / 35.1 / 88.6 |
| nbinom2 | 50 / 150 / 400 | 6.5 / 36.8 / 263.8 (max 588) | 28.1 / 151.2 / 571.0 (max 646; 5 datasets still running at >12 min) |

Projection for the full 14,400: about 243 CPU-h from the finished datasets, of which NB 199 CPU-h; an underestimate, because the slowest NB n=400, p=16 datasets had not finished. On 140 workers that is roughly 2 to 2.5 h wall, too close to the 3 h line to commit blind.

Decision: split. Phase A = every cell except NB at n=400 (12,998 remaining tasks, about 92 CPU-h, estimate 45 to 60 min on 140 workers), launched 07:46 MDT. Phase B = NB at n=400 (1,200 tasks), re-estimated from finished stragglers before launch; if A + B exceed 3 h, stop for Shinichi, and the design's fallback (100 reps at n=400) is the proposal.
