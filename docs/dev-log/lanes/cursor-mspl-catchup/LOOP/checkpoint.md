GOAL: see GOAL.md. Shinichi 2026-08-15: implement Gaussian LA-MSPL (point).

STATE: Pick **C**. Local se=FALSE smoke PASS; gaussian ordinary q1/q2 flipped to
`admitted` / `oracle_local`. Hirose tape live on this branch. #964+#965 merged.
#966 uniqueness open (CI). **No SE/interval work.**

**PROTECTED:** `codex/lane-b-mspl-interval-feasibility` owns binary MSPL SE /
sandwich / profile / coverage. This lane: point estimates only (`se=FALSE`).
Binary admitted cells unchanged for point estimation; no binary SE claim.

ARCS DONE: #963–#965; Arc U uniqueness (pick C); G-impl smoke green + registry flip (this branch).
NEXT: push stacked implement PR; merge #966 then implement; update Mission Control MSPL column.
OPEN GATES: Totoro campaign; NEWS/covered claim; poisson/NB; **SE (PROTECTED)**; free-ε cell.
TRUTH LIVES IN: worktree `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` · `cursor/mspl-gaussian-heywood-atom` · LOOP `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/` · NOT repo-root `LOOP/`
RESUME: Point-only Gaussian MSPL. Never touch the Codex interval-feasibility lane.
