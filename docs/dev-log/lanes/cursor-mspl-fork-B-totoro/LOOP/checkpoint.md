# Checkpoint — OVERWRITTEN every arc (a pointer to truth, not a log)

GOAL: see `LOOP/GOAL.md`.
STATE: **T1 RECORDED on Totoro. tstar NOT-FROZEN.**

- **ARCS DONE (verified):**
  - **K0** — kit under `docs/dev-log/lanes/cursor-mspl-fork-B-totoro/`.
  - **K1** — `dev/mspl-forkB-t1-smoke.R` reuses L1 ADEMP; adds four
    hold-outs + `far_tail`.
  - **K2** — Totoro 1-rep `T1-anchor-n40-T8` / 20260830 PASS
    (RDS 724 bytes, LOG 698 bytes, `Q_0` / fork B).
  - **K3** — 800-rep panel at 16 cores, 15.3 s, 800 unique-seed rows.
  - **K4** — receipt
    `docs/dev-log/research/2026-08-18-mspl-forkB-t1-receipt.md`.
    Anchor cov_eff 0.940 / 0.975; near-tail 0.710; far-tail 0.580.
- **NEXT:** human T\* freeze (blocked). Do not auto-start. Optional
  confirm `T1-confirm-n80-T8` / 20260834 is out of the primary 800.
- **OPEN GATES (need a human):**
  1. **T\* freeze** — blocked. Never auto-start.
  2. **Undraft #1077 · public `se=TRUE` / `vcov()` / `confint()` ·
     MSPL-04 off `blocked` · NEWS `covered`** — hard OUT.
- **WHERE TRUTH LIVES:**
  - worktree `~/local-scratch/lanes/gllvmTMB-mspl-fork-B-totoro`
  - branch `cursor/mspl-fork-B-totoro-20260818`
  - Totoro deploy `~/gllvmtmb-mspl-forkB-t1-20260818` @ `7187b7d`
  - receipt `docs/dev-log/research/2026-08-18-mspl-forkB-t1-receipt.md`
  - object `docs/dev-log/research/2026-08-18-mspl-forkB-t1-panel.rds`
  - official L1 inherit: #1128 cov_eff 0.880
  - official L2 inherit: #1162 Seed B/C 0.900 / near-tail 0.780
- **RESUME:** T1 is recorded. Do not re-walk the 800. Do not freeze T\*.
  Do not undraft #1077.
