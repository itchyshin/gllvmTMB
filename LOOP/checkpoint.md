GOAL: see LOOP/GOAL.md.   STATE: Arc 1A implemented and locally verified; stacked PR is the remaining S6 outward step.

ARCS DONE (verified):
- S0 recon — estimator_id sites frozen (fit-multi assign 0/1/2; mspl.R list field; cpp DATA integer unread)
- S1 resolver — `R/estimator-provenance.R` exists
- S2 wire — adapter derives 0/1/2; `fit$estimator_provenance` attached
- S3 tests — `tests/testthat/test-estimator-provenance.R` + two expects in `test-mspl-api.R`
- S4 receipt — LOG `FAIL 0 / WARN 0 / SKIP 0 / PASS 75` and `PASS 223`; no numeric drift
- S5 written Gauss/Noether/Rose PASS in after-task (not Opus)
- V mechanical — no C++ / NEWS / register / foreign-lane paths
- R Melissa — `docs/dev-log/plan-actual/2026-08-14-mspl-arc-1a.md`

ARC IN PROGRESS: S6 after-task + check-log + stacked PR (do not merge)

NEXT: push `-u` and `gh pr create` against `main`; then STOP. Do not merge. Do not start Arc 1B or Arc 2.

OPEN GATES (need human): merge to main; NEWS/public claim; any C++ tape change; any new error for a currently accepted call (1B).

TRUTH LIVES IN: worktree `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` · branch `cursor/mspl-arc-1a-provenance` · after-task `docs/dev-log/after-task/2026-08-14-mspl-arc-1a-provenance-parity.md`

RESUME: You are cursor-mspl-arc-1a-provenance — running Arc 1A internal provenance parity. RESUME. READ FIRST: LOOP/GOAL.md -> LOOP/checkpoint.md -> LOOP/ultra-plan.md. WORKSPACE: `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap` only. CONTINUE FROM: S6 PR if not opened; otherwise STOP at merge gate. Do not re-implement S0–S5.
