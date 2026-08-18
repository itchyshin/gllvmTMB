# Checkpoint — OVERWRITTEN every arc (a pointer to truth, not a log)

GOAL: see `LOOP/GOAL.md`.
STATE: **K0 landing.** Ultra-plan + NEW kit written from `origin/main`. L2 compute has **not** started.

- **ARCS DONE (verified):**
  - **R0** — sweep receipt in `LOOP/ultra-plan.md`. Verified by reading closed
    `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/checkpoint.md` (GOAL_MET) and
    official L1 `docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.md`
    (cov_eff 0.880).
- **ARC IN PROGRESS:** **K0** — this kit + docs PR.
- **NEXT:** after K0 merges, a **fresh `/goal` chat** starts **K1** (thin L2 runner).
  Do **not** start K1 in the planning sitting.
- **OPEN GATES (need a human):**
  1. **Totoro / DRAC / T\*** — blocked. Never auto-start.
  2. **Undraft #1077 · public `se=TRUE` / `vcov()` / `confint()` · MSPL-04 off
     `blocked` · NEWS `covered`** — hard OUT, not questions.
- **WHERE TRUTH LIVES:**
  - this kit: `docs/dev-log/lanes/cursor-mspl-fork-B-L2/LOOP/`
  - worktree: `~/local-scratch/lanes/gllvmTMB-mspl-forkB-L2-goal`
  - branch: `cursor/mspl-forkB-L2-goal-20260818` from `origin/main` @ `b6c50d28`
  - closed g0_unlock (do not edit): `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/`
  - L0: [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) @ `d7f526d4`
  - official L1: [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) @ `715326af` — cov_eff 0.880
  - ADEMP L2 rule: `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` §P5
  - harness already holding the near-tail cell: `dev/mspl-forkB-l1-ademp.R` (`L1-neartail-n40-T4`, role `L2-hold`)
  - repo-root `LOOP/`: closed Poisson \(W_*\) REPLACE — do not overwrite
- **RESUME:** paste `LOOP/launch-prompt.md` into a fresh Cursor chat opened on
  the scratch worktree. Continue from **K1**. Do not reopen g0_unlock.
