# checkpoint — cursor-mspl-phase4-prep-goal

GOAL: see GOAL.md.   STATE: **GOAL deliverable met** — notes+oracles on stacked PRs; #971 verified. STOP at merge (human). Still no admit.

ARCS DONE (verified):
- A0 — LOOP kit committed `77b37a7a` on `cursor/mspl-phase4-prep-goal`; pointer only on closed point-continue GOAL.
- A1 — #971 MERGED `cb126576` by Shinichi. Independent verify: **29/29 PASS (168 expects)**; TSV **64/64** finite; `git diff -- src/ R/mspl.R` empty. Ubuntu CI still **pending** at verify time (`gh pr checks 971`; merge-commit run https://github.com/itchyshin/gllvmTMB/actions/runs/31896665218).
- A2 — #972 Poisson: **102/102 PASS**; `planned`/`phase4_prep`; no defect.
- A3 — #973 Tweedie: **62/62** (file `expect_` count 62; the “51” claim was wrong). Wording fix pushed `90a156cf`.
- A4 — #974 NB2: **72/72**; stays **excluded**.
- A5 — #975 beta: **65/65**; wording nits landed `daa76352`.
- A6 — #976 NB1: **68/68**; no `nbinom1` registry row.
- A7 — Rose fence: no NEWS covered for these families; no planned→admitted; prepare still `fam_ids %in% c(0L, 1L)` on all five tips.
- A8 — this checkpoint + after-task + Melissa.

ARC IN PROGRESS: none (merge is human).

NEXT: Shinichi retarget #972–#976 base to `main` (see rebase note), then merge after CI. Do **not** admit anyone.

OPEN GATES (need human): merge #972–#976 after CI; still no admit. #971 Ubuntu CI still pending on the merge commit.

TRUTH LIVES IN: `cursor/mspl-phase4-prep-goal` @ this kit · after-task `docs/dev-log/after-task/2026-08-15-mspl-phase4-prep-goal.md` · Melissa `docs/dev-log/plan-actual/2026-08-15-mspl-phase4-prep-goal.md` · PRs #971–#976.

## Rebase note (do not rebase from this lane)

Family PRs still target base `cursor/mspl-point-programme-continue`, not `main`. They are **1 behind `main`** — only merge commit `cb126576`. `git merge-tree` vs `origin/main` is **CLEAN** for all five. No content rebase needed. Do **not** force-push `main`. Human can retarget each PR base to `main` and merge; this lane did not retarget or merge.

RESUME:
```text
You are lane cursor/mspl-phase4-prep-goal — RESUME after human merge.
READ FIRST: docs/dev-log/lanes/cursor-mspl-phase4-prep-goal/LOOP/GOAL.md -> checkpoint.md -> ultra-plan.md.
WORKSPACE: /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
GOAL deliverable is landed. Do not merge #972–#976 from the agent. Do not admit. Do not rebase onto main unless Shinichi asks and the tree stays CLEAN (no force-push to main).
```
