# Checkpoint — OVERWRITTEN every arc (a pointer to truth, not a log)

GOAL: see `LOOP/GOAL.md`.
STATE: **K2–K5 verified. CI whitespace fix on #1162; merge when green. Totoro blocked.**

- **ARCS DONE (verified):**
  - **R0 / K0** — kit #1155.
  - **K1** — `dev/mspl-forkB-l2-smoke.R` reuses L1 harness; Seed A guarded.
  - **K2a / K2b** — 1-rep objects inspected (two-sided `Q_0` / fork B, `lo < hi`).
    Verified by reading the rds rows.
  - **K3** — 150 new rows. Object inspected:
    Seed B 20260819 cov_eff 0.900 (50/0/45);
    Seed C 20260820 cov_eff 0.900 (50/0/45);
    near-tail 20260821 cov_eff 0.780 (50/0/39);
    all `Q_0` / B; Seed A 20260818 **not walked**.
  - **K4** — official receipt
    `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md`:
    inherit 0.880; `calibrated: FALSE`; `public_confint: refused`;
    `coverage_claim: none`. Companion 0.935 not used.
  - **K5 / Rec / V1** — after-task + check-log + Melissa plan-vs-actual in
    commit `e346c6b8`. V1: #1077 draft; MSPL-04 `blocked`; root `LOOP/`
    and closed g0_unlock untouched.
- **ARC IN PROGRESS:** **ship** — [#1162](https://github.com/itchyshin/gllvmTMB/pull/1162)
  first CI failed on `git diff --check` trailing whitespace (markdown
  hard-breaks). This sitting stripped those spaces; merge when the new
  check is green (G0 preapprove, docs/receipt).
- **NEXT:** merge #1162 when CI green → overwrite this file **GOAL_MET**.
  **Do not start Totoro.**
- **OPEN GATES (need a human):**
  1. **Totoro / DRAC / T\*** — blocked. Never auto-start.
  2. **Undraft #1077 · public `se=TRUE` / `vcov()` / `confint()` · MSPL-04 off
     `blocked` · NEWS `covered`** — hard OUT.
- **WHERE TRUTH LIVES:**
  - branch `cursor/mspl-forkB-L2-exec-20260818` (this CI-fix commit)
  - PR: https://github.com/itchyshin/gllvmTMB/pull/1162
  - official L2: `docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md`
  - official L1 inherit: #1128 cov_eff 0.880
- **RESUME:** if #1162 still open, `gh pr checks 1162` then merge when green.
  If merged, mark GOAL_MET. Do not re-run the 50-rep panel. Do not start Totoro.
