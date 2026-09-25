# Session Handoff: gllvmTMB Meuwissen-Luo F twin (new Cursor lane)

Meta: 2026-09-25 · from Cursor · TARGET = cursor · AUTHOR = cursor

You are Cursor, picking up a **new lane**. This chat does not exist for you.
Rehydrate from files and git only.

## Critical Context

1. **drmTMB TMB-speed arc is CLOSED** on `itchyshin/drmTMB` `origin/main` @ `b737b3bad`. Stack: #1422 Quaas A^{-1} (`b7dddda6`) → #1423 receipt → #1424/#1427 Meuwissen-Luo F (`ef7ef00cc`) → #1428 tip-identity receipt (`b737b3bad`). Unlazy G1-G5 all met. Do not reopen it.
2. **This lane is the gllvmTMB twin only.** `.gllvm_pedigree_precision` still does `Finb <- diag(A) - 1` after a dense tabular A (`R/pedigree-precision.R:163-165` on `origin/main` @ `1d7e68da1`). Quaas sparse A^{-1} stays. Port the **F walk only**.
3. **gllvmTMB is multi-lane.** Ownership map: `docs/dev-log/handover/2026-07-25-active-lane-split.md` plus `docs/dev-log/coordination-board.md`. Preflight reported ~12 live lanes (docs / MSPL / julia-bridge). This lane owns only the pedigree-precision slice below. Do not merge or edit Claude/Codex/MSPL PRs.

## Goals / mission

Finish Destination D's second twin: animal-pedigree construction on the R/TMB path is sparse end-to-end (F + A^{-1}), matching drmTMB #1424 without vendoring GPL source.

## Plans / roadmap (beyond this slice)

After identity gates land: optional large-n receipt (Totoro, D-50, no Actions artifacts). Not in scope: DRM.jl H^2 SIMD, #914 `profile=`, drmTMB heap-walk C++ rewrite, hsquared #366 coverage.

## What Was Accomplished (prior Cursor overnight; drmTMB)

- Sparse Quaas A^{-1} and Meuwissen-Luo F shipped on drmTMB; receipts green.
- Twin scout (read-only): dense F confirmed; issue draft written under scratch (not filed yet).
- Cite walls (drmTMB candidate, abs seconds, no multiplier): n=1500/3000/6000/10000 construct/fit 2.237/3.276, 7.494/11.966, 41.793/48.520, 137.965/151.254. Do not claim speedup vs the S4 leftover.

## Current Working State

- Working: drmTMB stack on main; scout draft ready; this handover branch.
- In progress: nothing implemented in gllvmTMB yet.
- Not working / blocked: Dropbox `gllvmTMB` checkout is dirty/behind; never implement there. Use a clean local-scratch worktree from `origin/main`.

## Key Decisions & Rationale

- New lane, yes. Leave the drmTMB speed chat and Dropbox dirty tree; start fresh here.
- Reimplement Meuwissen-Luo in R following HSquared.jl MIT walk (`src/pedigree.jl` @ `eee5f7aa…`). Cite drmTMB #1424 as twin. Do not copy drmTMB GPL source. Do not vendor Julia.
- Keep `.gllvm_pedigree_additive_relationship` as oracle / dense export only.
- Gates: F identity vs dense diag(A)-1; Ainv identity vs dense-F path and MCMCglmm at current 1e-10; help honesty; COPYRIGHTS provenance.
- No public speed multiplier. Absolute seconds only if a receipt is taken.
- `#914` profile= stays abandoned on drmTMB. Julia SI KEEP-OURS stays closed.

## Landing State

Paste-oriented ledger for this handoff (handoff_gate on Dropbox checkout shows many foreign unpushed branches; those stay PROTECTED and are outside this lane's debt).

| Artifact / branch | Committed | Pushed | PR | State |
|---|---|---|---|---|
| drmTMB `origin/main` `b737b3bad` (#1422-#1428 stack) | y | y | merged | LANDED (other repo) |
| Twin scout draft `~/local-scratch/tmb-1424-parallel/gllvmtmb-twin-issue-draft.md` | n (scratch) | n | none | CARRIED-OVER: paste into GitHub issue as step 1; not in this repo |
| This handover branch `cursor/meuwissen-twin-handover-20260925` | this commit | when pushed | open docs PR | LANDED when PR merges |
| gllvmTMB Meuwissen implementation | n | n | none | OWED (next session) |
| Foreign gllvmTMB open PRs (#1318, #1317, #1306, #1236, MSPL #1065/#1070/#1077/#981, …) | — | — | open | PROTECTED |
| Dropbox gllvmTMB untracked (`.worktrees/`, inbox, christin vignette, …) | n | n | — | PROTECTED; never stage |

FINDINGS-OF-RECORD: dense Finb leftover at `R/pedigree-precision.R:163-165`; twin draft ready in scratch. vault-note: none required (finding lives in this handover + scratch draft).

## Files Created / Modified (this handoff PR)

- `docs/dev-log/handover/2026-09-25-cursor-handover-meuwissen-twin.md` (this file)
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` (prepend this lane)
- `docs/dev-log/coordination-board.md` (Active lanes row)
- `AGENTS.md` (multi-lane rehydrate pointer; does not orphan siblings)

## Next Immediate Steps (OWED)

1. Run `~/shinichi-brain/tools/lane_preflight.sh` on the worktree. State: `PLATFORM: cursor | LANE: meuwissen-twin-F | OTHER LANES: docs/MSPL/julia-bridge PROTECTED`.
2. Classify this handoff vs live git: OWED / DONE / RETRACTED / PROTECTED. Execute **OWED only**.
3. Fresh worktree: `~/local-scratch/lanes/gllvmTMB-meuwissen-twin-20260925` from `origin/main`. Branch `cursor/meuwissen-twin-20260925`. Do not use Dropbox primary.
4. File the GitHub issue by pasting `~/local-scratch/tmb-1424-parallel/gllvmtmb-twin-issue-draft.md` (title + body). Record the issue number in the PR.
5. Implement: `.gllvm_pedigree_inbreeding_meuwissen_luo`; swap Finb in `.gllvm_pedigree_precision`; keep dense-F oracle path; extend `tests/testthat/test-pedigree-precision.R`; update `pedigree_to_Ainv_sparse` help; `inst/COPYRIGHTS` + header.
6. Verify: focused pedigree tests with `NOT_CRAN=true` and `devtools::load_all()` first; then broader testthat for pedigree files. No campaign on Actions (D-50).
7. PR closes the new issue. merge-when-green. After-task + check-log.d entry. Rose: no speed claim.

## Blockers / Open Questions

- None for starting. Optional Totoro n-ladder is post-identity and needs a separate compute GO.
- Do not resolve foreign-lane conflicts unilaterally (D-87).

## Gotchas & Failed Approaches

- drmTMB mid-n R heap walk can be **slower** than dense F in wall time even after dropping dense A allocation. Twin may need a later C++ pass; do not promise seconds wins in NEWS.
- Do not mirror Julia selected-inverse / `profile=` into TMB.
- `test_file()` without `load_all()` tests the installed package (gap-close lesson on this repo).
- Scratch twin draft said "do not file" until lane assigned; **lane is now assigned** so filing is OWED.

## How to Resume

Working directory: a **new** local-scratch worktree from `origin/main` (not Dropbox dirty `main`).

Toolchain:

```sh
export PATH="$HOME/.juliaup/bin:$PATH"
export NOT_CRAN=true
R_PROFILE_USER=/dev/null Rscript --no-init-file -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-pedigree-precision.R")'
```

Do not stage: Dropbox untracked inbox/worktrees, foreign MSPL/docs branches, `_julia_skip*` style artifacts.

Read order: `AGENTS.md` → this handover → `docs/dev-log/handover/2026-07-25-active-lane-split.md` → coordination-board Active lanes → twin draft in scratch → `R/pedigree-precision.R:160-214`.

Paste-ready prompt for a fresh Cursor agent in the gllvmTMB repo (or worktree):

```text
Read AGENTS.md and docs/dev-log/handover/2026-09-25-cursor-handover-meuwissen-twin.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
