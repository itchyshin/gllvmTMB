# checkpoint — cursor-mspl-gaussian

GOAL: see GOAL.md.   STATE: S0–S4 PASS; awaiting CI green for single #967 merge (Q1).

ARCS DONE (verified):
- S0 — #967 OPEN MERGEABLE; 3 ahead / 0 behind `origin/main` @ `813da14a`; MSPL-only file map; no foreign lanes.
- S1 — LOOP kit landed under `docs/dev-log/lanes/cursor-mspl-gaussian/LOOP/` (catch-up GOAL untouched).
- S2 — Hirose tape PASS (source read): `psi=exp(2*theta_diag_B)`; `c_N=sqrt(2/N)`; gaussian adds Hirose only; Jeffreys/`V_loading` Bernoulli-only; R fence pick C.
- S3 — `test-mspl-registry.R` + `test-mspl-gaussian-fit-smoke.R` → `S3_SUMMARY failed=0` (log, not exit code alone); Bernoulli admit row still present.
- S4 — Rose PASS: NEWS untouched in PR; no SE/sandwich/profile/interval paths; registry `oracle_local` + not-covered note; Codex Lane B untouched.

ARC IN PROGRESS: S5 — Melissa plan-actual drafted; merge when CI green (check not already merged).

NEXT: poll `gh pr checks 967` → merge once → fill merge SHA in plan-actual → Mission Control NOW → V/R freeze GOAL.

OPEN GATES (need human): none (Q1 already YES; waiting only on CI).

TRUTH LIVES IN: worktree `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` @ `813da14a` (+ pending LOOP/Melissa commit); PR https://github.com/itchyshin/gllvmTMB/pull/967

RESUME: You are cursor-mspl-gaussian. READ GOAL→checkpoint→ultra-plan. CONTINUE FROM S5: if #967 still OPEN and CI green and Rose PASS, merge once. If already merged, record SHA and close GOAL. HARD STOP campaign/SE/Poisson/NEWS covered/free-ε.
