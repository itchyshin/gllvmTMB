# Session Handoff: end of the frontier day -- to a fresh Claude session

Meta: 2026-08-15 (evening) · from Claude · target Claude · session close at
maintainer request. `handoff_gate.sh` timed out on the loaded Mac; landing
state verified directly instead: **worktree clean, branch
`codex/isdm-range-amplitude-orthogonal` fully pushed to origin at
`0a982687`** (~190 commits).

```text
🎯 GOAL (of the NEXT session -- the active baton)
Build the PUBLIC iSDM fitting interface + rewire the example article.
Authoritative brief: docs/dev-log/handover/2026-08-15-claude-handover-isdm-public-api.md
Everything else below is state, fences, and parked work -- not the task.
```

## What this session landed (all DONE, all pushed)

1. **Chart-lane audit arc** (morning): map audit, no-fit design, contract
   hardening (13->44 tests), 31-file test guard sweep, after-task + Melissa.
2. **The diagnosis**: 24 failed estimator routes traced to the frozen fixture
   sitting below its own recoverability frontier; both prior hypotheses
   (information deficit, coordinates) eliminated by measurement.
3. **Three measured axes** (~7,200 Totoro fits, 0 errors): effort
   (E*_pd = 1.85 [1.43, 3.17]; amplitude plateau), finer-patches (REFUTED,
   monotone harm), domain growth (monotone gain). The law: *spatial
   replication helps iff per-patch information is preserved -- cells buy what
   records cannot.* gamma under-coverage resolved (heals with cells).
4. **Artifacts**: P1-F1v2/F2/F3/F4 + summaries in
   `dev/isdm-package-recovery/frontier-campaign/artifacts/`; results notes;
   evidence-chapter draft 0 (`two-paper-staging/paper1-evidence-chapter.md`);
   scale-free runaway detector prototype + 13 tests; brain notes updated
   (memory/ "ISDM programme -- the destination is data integration...").
5. **Example article draft**: `vignettes/articles/integrated-two-source-example.Rmd`
   (renders, converges; single-seed gamma noisy and read honestly; do NOT
   keep tuning the seed), registered in `_pkgdown.yml`.

## Item classification for the next session

- **OWED**: the public API lane (the baton doc above) -- ratify name at first
  checkpoint, build wrapper/tests/docs, rewire article.
- **PROTECTED**: Kristen's storyboards + both staging articles
  (`article-staging/`, `two-paper-staging/` narratives); all sealed roots;
  the 5x3 keyword grid; A3 bundles + pre-run on Totoro.
- **CARRIED-OVER (parked by maintainer)**: A3 crossing campaign launch
  (~106 core-h; pre-run PASSED; resume = approve then
  `1d_run_crossing.R` job sweep per Amendment A3 in the campaign design doc).
- **CARRIED-OVER (unowned)**: detector R/-integration; two unguarded test
  files (`test-bfgs-smoke-contract.R`, `test-g2o-postmortem.R`); PR/merge
  decision for this ~190-commit branch; Paper 2 diagnosis arc.
- **RETRACTED today** (do not re-cite): "fixing tau causes the ridge";
  "loadings 21.6 are pathological"; "no reparameterisation can help"
  (as stated); the pilot's marginal-recovery optimism.

## Environment the next session needs

Worktree `/private/tmp/gllvmtmb-isdm-range-amplitude-chart` (or a fresh
worktree from origin -- the branch is pushed). Toolchain: local R 4.6 + TMB
1.9.21; `src/gllvmTMB.so` built in-tree. Totoro via the ControlMaster socket
(`~/.ssh/cm-snakagaw@totoro...`), staging in `~/frontier-prerun/` (raw rows
archived: `frontier-raw-rows-20260815.tar.gz`). **Go easy on this Mac's CPU
(maintainer, tonight): route anything heavy to Totoro; OPENBLAS single
thread.** Safe verification:
`Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-paper1-range-amplitude-orthogonal-contract.R", reporter="summary")'`.
Do not stage anything under `dev/isdm-package-recovery/results/` (gitignored)
or the untracked `vignettes/articles/figures/P1-F*.png` copies if present.

## How to resume

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-15-claude-handover-eod.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
