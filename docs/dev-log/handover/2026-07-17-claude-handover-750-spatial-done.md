# Handover — Claude → Claude: #750 spatial redraw SHIPPED; NEXT = capstone metric-repair

**Date:** 2026-07-17 · **Branch:** `claude/release-0.5.0` (pushed, in sync) · **From/To:** Claude → Claude

## 🎯 One-command resume (paste in your authenticated terminal at the repo root)
```
claude "Rehydrate from docs/dev-log/handover/2026-07-17-claude-handover-750-spatial-done.md + the
CLAUDE.md snapshot. #750 (spatial SPDE unconditional RE redraw) is DONE + pushed and the lane is clean.
NEXT ARC (Shinichi-chosen): the CAPSTONE METRIC-REPAIR — repair the coverage/power capstone harness
(CI-08/CI-10 metric rows, binary-harness mislabelling, ordinal-probit rows) that gates the whole
coverage/power campaign, CRAN, and the methods paper. Ultra-plan it first; spawn Rose before any claim."
```

## 🔴 Critical context (read first)
1. **#750 is COMPLETE and pushed.** The base per-trait spatial (SPDE) unconditional RE redraw is landed:
   `bootstrap_Sigma()` / `coverage_study()` / loading-signal-proportions-lv-effects CIs are now valid
   (non-collapsed) for base spatial fits. Redraw **proven distributionally exact** (recovery test +
   adversarial Opus review). Coverage DoD **MET in-regime** (n≥150, mean 0.946 = the shipped Sigma_unit
   certificate). `spatial_latent`/`spatial_dep`/`spde_*_slope` stay **fail-closed**. Full detail:
   `docs/dev-log/after-task/2026-07-17-spatial-spde-redraw-750.md`.
2. **The lane is CLEAN.** All 7 arc commits pushed (`dd80244a` … `051eb4e5`); `claude/release-0.5.0` in
   sync with origin. Local coverage `.rds`/shards gitignored (D-50). No merge needed — arcs accumulate
   on `release-0.5.0`; release→`main` is a 0.6-release decision, not per-arc.
3. **NOT yours (leave alone):** the untracked `docs/dev-log/*tier2a*` / `phylo-multinomial-harness` docs
   and the `check-log.md` edit are the **concurrent Tier-2 / Lane-C (multinomial)** lane. **Lane C files
   are OFF-LIMITS.**

## NEXT ARC — Capstone metric-repair (Shinichi-chosen 2026-07-17)
The single gate holding the whole coverage/power campaign, which in turn **gates CRAN + the methods
paper** (the 1.0 story). Issues **#349** (power capstone), **#346** (sim/coverage framework); **Design 66**
(capstone power study). The blocker (per the 2026-07-17 arc-survey): the **2026-06-23 scaling gate** —
(a) **CI-08 / CI-10** coverage register rows are incomplete/mis-computed, (b) a **binary-harness
mislabelling** bug, (c) **missing ordinal-probit rows**. Start by ultra-planning: sweep the M3 coverage
grid + Design 66 + the register (CI-08/CI-10), reproduce the mislabelling, then decompose. It is XL and
compute-heavy (n_sim=2000 ADEMP sweep → **Totoro/DRAC**, results LOCAL never GitHub artifacts, D-50).
**START HERE:** `docs/dev-log/handover/2026-07-17-claude-handover-coverage-shipped.md` "Remaining arcs"
map (full arc list) + Design 66 + `dev/m3-*` harness.

## What shipped this session
- **`87a11cf4`** — the `spde` redraw branch in `.simulate_eta_unconditional()` (reconstructs
  `Q_base = κ⁴M0 + 2κ²M1 + M2`, `perm=FALSE` sparse-Cholesky draw, `A_proj` projection) + whitelist in
  `.check_simulate_unconditional()` (adds `spde` + `spatial_indep`/`spatial_scalar`; latent/dep/slope
  fail-closed) + 3 tests (`test-spatial-redraw.R`, flipped `test-bootstrap-Sigma.R`).
- **`5379ab52` / `832a721d` / `9cd66027`** — coverage evidence: N=353 spatial pilot, non-spatial baseline
  control (proved the sub-0.94 at n=50 is a coverage_study small-n artifact, spatial-free), and the
  in-regime n=160 run (DoD met). Scripts `dev/spatial-coverage-750{,-parallel,-shard,-pool,-baseline-shard,-clean-shard}.R`.
- **`051eb4e5`** — gitignore the local coverage artifacts (D-50).
- Mission Control refreshed (vault `ea22550`).

## Files created / modified (this session's diff, `dd80244a..051eb4e5`)
`R/methods-gllvmTMB.R` · `tests/testthat/test-bootstrap-Sigma.R` · `tests/testthat/test-spatial-redraw.R`
(new) · `dev/spatial-coverage-750*.R` (new, ×6) · `.gitignore` ·
`docs/dev-log/after-task/2026-07-17-spatial-spde-redraw-750.md` (new) · this handover.

## Gotchas / lessons (paid for this session)
- **Agent-tool `isolation:worktree` bases off the DEFAULT branch (`main`), not your current branch.** The
  S1 build agent built against `main` (which lacked `be40d8ae`); I ported it onto `release-0.5.0`. Verify
  the worktree base for any isolated build on a non-default branch.
- **`Matrix::Cholesky` default `perm=TRUE` gives the WRONG covariance** (`P·Q⁻¹·Pᵀ`, relerr 0.61) — use
  `perm=FALSE` for a precision draw that must align with `A_proj`.
- **TMB `ADFun` pointers are fork-hostile** — `mclapply` crashes; use separate `Rscript` processes
  (`xargs -P` / a bash loop) reusing the cached `.so` (`load_all(compile=FALSE)`) for parallel coverage.
- **`coverage_study()` sub-0.94 at small n is a coverage_study property, not a defect** — profile CIs +
  MLE-as-truth under-cover at n<150 (baseline control proves it, spatial-free). Measure IN-REGIME (n≥150,
  well-identified fit) to reproduce ~nominal. It is NOT a BCa/bootstrap issue (coverage_study is profile,
  not percentile-bootstrap). The result object field is `cs$coverage` (not `cs$summary`).

## How to resume (rehydration recipe)
1. Open the capability widget / Mission Control (CLAUDE.md step 0).
2. Read: this doc → the #750 after-task → the coverage-shipped handover's "Remaining arcs" map.
3. `git log --oneline -8` + `git status -sb` — confirm HEAD `051eb4e5`, lane in sync, and that the only
   untracked items are the Lane-C/Tier-2 files (not yours).
4. **Ultra-plan the capstone metric-repair** (it's XL + compute-heavy). Spawn Rose before any coverage/
   power completion claim (D-43 default NOT-DONE). Compute on Totoro/DRAC; results LOCAL (D-50).

## Mission-control summary
| repo · branch · CI | what shipped this session | next by leverage |
|---|---|---|
| gllvmTMB · `claude/release-0.5.0` · pushed/in-sync | **#750 spatial SPDE unconditional RE redraw DONE** — redraw proven exact (recovery + Opus review), `bootstrap_Sigma`/`coverage_study` valid for spatial, coverage DoD met in-regime (n≥150, mean 0.946). 7 commits. Earlier: Sigma_unit coverage certificate `dd80244a`; pkgdown fix #754 + roadmap retired. Lane clean. | **1** Capstone metric-repair (#349/#346, Design 66 — gates CRAN+paper) ← chosen · **2** Article Wave 1 (#347) · **3** BCa bootstrap · **4** spatial_latent redraw (#750 follow-up) · held sign-offs (disp_group deferred, family-breadth, tweedie) |
