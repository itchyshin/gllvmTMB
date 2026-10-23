# Checkpoint — OVERWRITTEN every arc (a pointer to truth, not a log)

GOAL: see `LOOP/GOAL.md`.
STATE: **GOAL_MET. Local L2 recorded and merged. Totoro blocked.**

- **ARCS DONE (verified):**
  - **R0 / K0** — kit #1155.
  - **K1** — `dev/mspl-forkB-l2-smoke.R` reuses L1 harness; Seed A guarded.
  - **K2a / K2b** — 1-rep objects inspected (two-sided `Q_0` / fork B, `lo < hi`).
  - **K3** — 150 new rows. Object inspected:
    Seed B 20260819 cov_eff 0.900 (50/0/45);
    Seed C 20260820 cov_eff 0.900 (50/0/45);
    near-tail 20260821 cov_eff 0.780 (50/0/39);
    all `Q_0` / B; Seed A 20260818 **not walked**.
  - **K4** — official receipt
    `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md`:
    inherit 0.880; `calibrated: FALSE`; `public_confint: refused`;
    `coverage_claim: none`. Companion 0.935 not used.
  - **K5 / Rec / V1** — after-task + check-log + Melissa in `e346c6b8`.
    V1: #1077 draft; MSPL-04 `blocked`; root `LOOP/` and closed
    g0_unlock untouched.
  - **ship** — [#1162](https://github.com/itchyshin/gllvmTMB/pull/1162)
    squash-merged at `93ea79bd` after ubuntu-latest (release) green
    (16m6s). Receipt is on `origin/main`.
- **ARC IN PROGRESS:** none. Lane closed.
- **NEXT:** Totoro / T\* — **blocked**. Do not start. Needs a new G0.
- **OPEN GATES (need a human):**
  1. **Totoro / DRAC / T\*** — blocked. Never auto-start.
  2. **Undraft #1077 · public `se=TRUE` / `vcov()` / `confint()` · MSPL-04 off
     `blocked` · NEWS `covered`** — hard OUT.
- **WHERE TRUTH LIVES:**
  - `origin/main` @ merge `93ea79bd` ([#1162](https://github.com/itchyshin/gllvmTMB/pull/1162))
  - official L2: `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md`
  - official L1 inherit: #1128 cov_eff 0.880
  - this checkpoint: GOAL_MET
- **RESUME:** do not resume this kit. Local L2 is recorded. A Totoro /
  T\* sitting needs a new G0 and a new lane. Do not re-run the 50-rep
  panel. Do not undraft #1077.
