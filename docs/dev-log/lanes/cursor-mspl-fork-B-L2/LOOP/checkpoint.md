# Checkpoint — OVERWRITTEN every arc (a pointer to truth, not a log)

GOAL: see `LOOP/GOAL.md`.
STATE: **K5 landing.** Local L2 recorded. Totoro remains blocked.

- **ARCS DONE (verified):**
  - **R0 / K0** — kit on `origin/main` via [#1155](https://github.com/itchyshin/gllvmTMB/pull/1155).
  - **K1** — `dev/mspl-forkB-l2-smoke.R` reuses `dev/mspl-forkB-l1-ademp.R`; Seed A guarded.
  - **K2a / K2b** — 1-rep objects inspected: two-sided `Q_0` / fork B, finite, `lo < hi`.
    Verified by reading the rds rows, not the process exit code.
  - **K3** — 150 new rows (seeds 20260819/20 × 50 + near-tail 20260821 × 50); Seed A not walked.
    Object `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.rds`.
  - **K4** — official receipt with dual coverage + refusal + Wilson + MCSE;
    `calibrated: FALSE`; `public_confint: refused`; `coverage_claim: none`.
- **ARC IN PROGRESS:** none (K5/V1 in this PR).
- **NEXT:** Totoro / T\* — **blocked**. Do not auto-start.
- **OPEN GATES (need a human):**
  1. **Totoro / DRAC / T\*** — blocked. Never auto-start.
  2. **Undraft #1077 · public `se=TRUE` / `vcov()` / `confint()` · MSPL-04 off
     `blocked` · NEWS `covered`** — hard OUT, not questions.
- **WHERE TRUTH LIVES:**
  - this kit: `docs/dev-log/lanes/cursor-mspl-fork-B-L2/LOOP/`
  - worktree: `~/local-scratch/lanes/gllvmTMB-mspl-forkB-L2-goal`
  - branch: `cursor/mspl-forkB-L2-exec-20260818` from `origin/main` @ `2a2a0450`
  - official L2 receipt: `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md`
  - official L1 (inherited): [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) cov_eff 0.880
  - closed g0_unlock (do not edit): `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/`
  - repo-root `LOOP/`: closed Poisson \(W_*\) REPLACE — do not overwrite
- **RESUME:** L2 compute is done. Do not re-run the 50-rep panel. Do not start Totoro.
