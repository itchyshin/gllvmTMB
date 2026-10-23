# Checkpoint — OVERWRITTEN every arc (a pointer to truth, not a log)

GOAL: see `LOOP/GOAL.md`.
STATE: **GOAL_MET.** L0 [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) `d7f526d4` and L1 [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) `715326af` are on `origin/main`. Melissa reconcile landed. **Do not start L2.**

- **ARCS DONE (verified):**
  - **A0** — kit under `docs/dev-log/lanes/cursor-mspl-fork-B/`. Verified: [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127) MERGED.
  - **A1 / A2** — G4c → fork B + D-159 / PARK→REPLACE. Verified: [#1129](https://github.com/itchyshin/gllvmTMB/pull/1129) MERGED; `docs/dev-log/decisions.md` 2026-08-18 G0 is on `main`.
  - **A3** — [#1100](https://github.com/itchyshin/gllvmTMB/pull/1100) CLOSED; [#1124](https://github.com/itchyshin/gllvmTMB/pull/1124) MERGED.
  - **A4 — L0** — `objective=` selector, `calibrated=FALSE`, public doors still refuse. Verified: [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) MERGED @ `d7f526d4`. [#1126](https://github.com/itchyshin/gllvmTMB/pull/1126) CLOSED (superseded).
  - **A5 — L1** — local ADEMP 50-rep on `L1-anchor-n80-T8`. Verified by reading `docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.md` on `main`: availability 1.000, refusal 0.000, \(\widehat{\mathrm{cov}}_{\mathrm{eff}}=0.880\), Wilson [0.7620, 0.9438], 50/0/44, all rows `tape=Q_0` / fork B, **L1-PASS**. Not calibrated. Not public `se`.
  - **A6** — kit PR [#1127](https://github.com/itchyshin/gllvmTMB/pull/1127) MERGED; Rose fence held (root `LOOP/` untouched; MSPL-04 `blocked`; #1077 draft).
  - **Reconcile** — this file + `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-g0-unlock.md`.
- **ARC IN PROGRESS:** none. Campaign is closed.
- **NEXT:** **L2** — OPEN GATE, needs an explicit Shinichi G0. Do **not** auto-start. Do not draft the ask in this kit unless he asks.
- **OPEN GATES (need a human):**
  1. **L2 and every Totoro / DRAC gate** — blocked, needs Shinichi G0. Never auto-start.
  2. **T\* thresholds · undraft #1077 · public `se=TRUE` / `vcov()` / `confint()` · MSPL-04 off `blocked` · NEWS `covered`** — hard OUT, not questions.
- **WHERE TRUTH LIVES:**
  - this kit: `docs/dev-log/lanes/cursor-mspl-fork-B/LOOP/` on `origin/main` (after this reconcile PR)
  - L0: [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) @ `d7f526d4`
  - L1 official receipt: `docs/dev-log/research/2026-08-18-mspl-forkB-l1-smoke.md` via [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) @ `715326af`
  - Melissa: `docs/dev-log/plan-actual/2026-08-18-mspl-forkB-g0-unlock.md`
  - the construction: `docs/design/125-mspl-profile-led-intervals.md`
  - the gates: `docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` §P5
  - repo-root `LOOP/`: the **closed** Poisson \(W_*\) REPLACE `GOAL_MET` record — do not read it as this lane's goal, do not overwrite it
- **RESUME:** this `/goal` is **GOAL_MET**. A fresh chat should **not** re-run A0–A5. The only legal next step is a **new** Shinichi G0 for L2 (or a hard OUT). If he signs L2, start a **new** kit — do not reopen this one.
