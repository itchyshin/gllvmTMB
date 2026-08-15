GOAL: see GOAL.md. Shinichi 2026-08-15: implement Gaussian LA-MSPL (point).

STATE: Pick **C**. #964+#965+#966 merged. Local se=FALSE smoke PASS; gaussian
ordinary q1/q2 `admitted` / `oracle_local`. Hirose tape on PR #967
(`cursor/mspl-gaussian-heywood-atom` @ `792e8f35`). **No SE/interval work.**

**PROTECTED:** `codex/lane-b-mspl-interval-feasibility` owns binary MSPL SE /
sandwich / profile / coverage. This lane: point estimates only (`se=FALSE`).
Binary admitted cells unchanged for point estimation; no binary SE claim.

ARCS DONE: #963–#966; Arc U uniqueness (pick C); G-impl smoke + registry flip (this PR).
NEXT: merge #967 when CI green. STOP before Totoro campaign / NEWS / covered claim / SE lane.
OPEN GATES: Totoro campaign; NEWS/covered claim; poisson/NB; **SE (PROTECTED)**; free-ε cell.
TRUTH LIVES IN: worktree `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` · `cursor/mspl-gaussian-heywood-atom` · LOOP `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/` · NOT repo-root `LOOP/`
RESUME: Point-only Gaussian MSPL. Never touch the Codex interval-feasibility lane.
