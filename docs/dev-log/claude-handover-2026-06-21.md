# Claude session handover — 2026-06-21

**From:** Claude (Ada), autonomous "finish both packages" run.
**To:** the next Claude session.
**Repo is authoritative.** Rehydrate from `git`/`gh`, not from chat memory.

---

## 0. TL;DR

The 2026-06-20 `unique()`→Ψ migration (#505) had introduced two heavy-suite
regressions on merged `main`. Both are now **fixed and merged**. All planned
slices from the prior handover's next-5 are landed or cleanly handed off.
`gllvmTMB` `main` is green on the full local heavy suite (**9580 PASS / 0 FAIL**);
one **pre-existing flaky CI gate** remains (flagged, maintainer-gated).

---

## 1. Repos & key commits

- **gllvmTMB** `origin/main` = **`60fb621`** (after #508/#509/#510 merges).
- **GLLVM.jl** `origin/main` = **`c81be2f`** (GP-1 #112 merged).
- Working dir `/Users/z3437171/Dropbox/Github Local/gllvmTMB` is checked out on
  **`codex/r-bridge-grouped-dispersion`** (Codex's branch, dirty — do NOT commit
  to it or revert its changes). Use fresh worktrees off `origin/main` for new work.

---

## 2. Operating contract — HARD GUARDS (do not violate)

- **Engine / export / grammar / likelihood / family merges to shared `main` need
  EXPLICIT per-item maintainer "yes merge."** The auto-mode classifier enforces
  this (it blocked the #509 merge until the maintainer said "Approve — merge now").
  Low-risk (docs, dev-log, after-task, audits, design notes, test-only additions,
  individual article rewrites) you may self-merge when CI is green.
- **Never self-promote a validation-debt register row** (Design 35) or a COE-03/
  COE-04 coverage row — maintainer-gated.
- **Never `git add -A`** — stage by name.
- **Do not revert Codex/human changes.** Stop for maintainer discussion before
  deletions, API/grammar/likelihood/family changes, or broad article rewrites.
- **If a gate can't pass honestly, STOP and report blocked** — do not weaken tests
  to go green.
- **Division of labour:** Codex runs the live R/TMB + Julia toolchain (real fits,
  `R CMD check`, simulations, Julia builds); Claude plans, refactors, writes prose,
  runs pure-logic + (here) heavy R verification locally on the Mac.
- **Local checks over CI** (maintainer's standing rule): run `devtools::test()` /
  the heavy suite locally before pushing; CI is `pull_request`+`workflow_dispatch`,
  Linux-only for routine runs.
- Commit trailer: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Surface review touchpoints at every stopping point**: open-PR links, after-task
  paths, and 🔴 **Needs you:** blockers. The maintainer does not browse PRs.

## 2a. Heavy-test gate

Heavy recovery/coverage/profile tests are gated behind `GLLVMTMB_HEAVY_TESTS=1`
(see `tests/testthat/setup.R`). Routine PR CI leaves it unset (fast suite only).
To reproduce the full suite locally: `Sys.setenv(GLLVMTMB_HEAVY_TESTS="1",
NOT_CRAN="true")` then `devtools::load_all(".", compile=FALSE)` +
`testthat::test_dir("tests/testthat")`. `skip_on_cran()` needs `NOT_CRAN=true` or
those tests silently skip when run via `Rscript`.

---

## 3. ★ CANONICAL Ψ MODEL (the doctrine — internalise this before touching Psi)

`Σ = Λ Λᵀ + Ψ` (Greek **Psi/psi**; the 2026-05-14 reversal supersedes old `S`/`s`
and "two-U" wording). The diagonal trait companion **Ψ = specific(residual) part +
distribution(overdispersion) part**:

- **Gaussian & Poisson**: distribution part = 0 ⇒ Ψ is *only* the specific/residual
  term ⇒ **the ONLY families where `unique()` was ever needed.**
- **All other non-Gaussian** (NB1/NB2, Beta, Gamma, GP-1, lognormal, Tweedie,
  Student-t, …): specific part ≈ 0 and the overdispersion part is **already carried
  by the family's own dispersion** ⇒ an explicit Ψ/`unique()` is **REDUNDANT
  (double-counts).** "non-Gaussian is the key."
- **Binary/Bernoulli (single-trial)**: no free dispersion (like Poisson) BUT Ψ is
  **UNIDENTIFIED** (the link's implicit scale *is* the between-unit residual) ⇒ must
  **auto-skip** Ψ. This was the #509 bug.

Grammar consequence: `unique()`/`*_unique()` are soft-deprecated (loud fire-on-use
warning). `latent(..., residual=TRUE)` is the default (carries per-family Ψ);
`residual=FALSE` = old Λ-only.

---

## 4. What this session delivered

### Merged to gllvmTMB `main`
- **PR #509** (engine+extractor — the critical fix). Two independent root causes:
  1. `R/fit-multi.R` — **per-trait B-tier auto-Psi binary skip** (~line 3841+,
     `auto_psi_B` flag at ~line 719). Mirrors the W-tier OLRE skip: pins
     `theta_diag_B[t]` + maps `s_B` off for single-trial binary (`family_id==1L &&
     n_trials==1`); honours `diag_B_common`; **explicit `unique()`/`indep()`
     diagonals untouched** (gated on the `.auto_residual` marker). Multi-trial
     binomial (`cbind`, `n_trials>1`) is identified and left alone.
  2. `R/profile-derived.R` — **`profile_ci_correlation` boundary clamp** (~line
     746): clamp finite bounds so `lower ≤ estimate ≤ upper`. Fixes m1-4 where a
     rank-1 (`d=1`) latent block gives a degenerate ±1 latent correlation the
     ±0.999 profile grid couldn't bracket. Pre-existing, #505-EXPOSED, proven
     orthogonal to the binary fix (byte-identical m1-4 output with/without it).
  - After-task: `docs/dev-log/after-task/2026-06-20-psi-default-heavy-test-regressions.md`
- **PR #508** — articles `unique()`→`indep()` deprecation cascade (13 reader-path
  articles); kept source-specific `*_unique()`, `part="unique"`, the 4×5 grid.
- **PR #510** — coevolution **nbinom1 + Beta** two-kernel recovery gates (COE-04).
  `test-coevolution-two-kernel.R` 472/0. Seeds: nb1 = 5201/5202 (DGP disp 0.8,
  intercept 1.7, 14 reps), Beta = 6103/6104 (φ=15, intercept 0). After-task:
  `docs/dev-log/after-task/2026-06-20-coevolution-beta-nb1-gates.md`

### GLLVM.jl
- Closed **#104** (GP-1 family, merged via #112) and **#96** (mode-finder
  convexity/backtrack safeguard — verified live in `src/families/laplace.jl`,
  `_laplace_mode_should_backtrack` gates Poisson/Binomial/NB/Beta/**Gamma**/Exp).
- **Draft PR #113** — **Student-t #105** ported from archived `5a0f827` onto the
  current engine. Family math intact; `fit_studentt_gllvm` REWRITTEN to the current
  Optim scalar-aux pattern (the old `marginal_loglik_laplace_aux_value_grad` path
  was retired); `simulate(fit::StudentTFit)` added to `src/simulate_fit.jl`;
  `test_studentt.jl` updated (retired-API testset removed, DGP→inline t-draws).
  **NOT built/verified — Codex (Julia lane) must build + run the acceptance gates.**

### Issues updated
#361 (coevolution C0–C3 progress), #488 (bridge-gate audit: conservative, GP-1 the
one deliberate hold, no drift bug), #105 (Student-t handoff), #343 (flaky gate).

---

## 5. 🔴 Open items needing maintainer / Codex

1. **Codex: build + verify Student-t draft PR #113** (GLLVM.jl) per its checklist
   (density vs `Distributions`, marginal-FD ≤1e-6, Gaussian-limit, simulate→fit
   recovery, outlier robustness, `link_residual`). Worktree:
   `/private/tmp/gllvmjl-studentt`.
2. **Maintainer: flaky CI gate `test-multi-trial-binomial.R`** (#343). Borderline
   stochastic slope-recovery gate (`>=20/30`); platform(BLAS)-non-deterministic on
   ubuntu (passes locally 28/30). **NOT a #509 regression** (byte-identical main-vs-
   fix proof). A test-tolerance fix is sensitive — left for the maintainer. `main`
   CI may show this one test red until addressed.
3. **Maintainer decisions parked**: in-engine `rho` estimation (#507 recommends
   keep fixed-`rho`); COE-03/04 register-row promotion; the GP-1 R-bridge exposure
   slice (#488 — needs R↔Julia parity infrastructure).

---

## 6. Next slices (none is a safe solo-merge — get a steer first)

- Julia families: **#106** lognormal, **#107** zero-trunc Poisson/NB, **#108**
  ANOVA/LRT, **#109** check_fit diagnostics, **#110** structured Schur. (Codex's
  Julia lane to build/verify; archived drafts may exist — check `git log --all`.)
- **`cluster2`** 4th grouping tier (#342/#355/#356) — parser+engine, **grammar
  change ⇒ discussion-gated.**
- Mixed-family two-kernel coevolution recovery gate (last queued COE-04 family).
- **CI-08 / CI-10** coverage; power-study capstone (#349/#346).
- Article reorganization into the pkgdown surface (deferred bigger task the
  maintainer raised: arrange like drmTMB, bank not-yet-ready articles).

---

## 7. Where things live

- **Memory:** `~/.claude/memory/memory_summary.md` (read early) — has the ★ canonical
  Ψ model, the ★ 2026-06-21 session-resolution snapshot, repo rules, validation
  command set. `~/.claude/memory/MEMORY.md` = full task-group doctrine.
- **After-task reports:** `docs/dev-log/after-task/2026-06-20-*.md` (this arc).
- **Design docs:** Design 65 (coevolution kernel), Design 35 (validation-debt
  register), `docs/design/04-sister-package-scope.md` (what gllvmTMB does/doesn't).
- **Active worktrees:** `/private/tmp/gllvmjl-studentt` (#113, keep for Codex),
  `/private/tmp/gllvmjl-genpoisson` (GP-1, Codex may reuse). All merged gllvmTMB
  worktrees were cleaned up.
- **Family-id map** (`R/fit-multi.R`): 0=gaussian, 1=binomial, 2=poisson, 4=Gamma,
  5=nbinom2, 7=Beta, 12/13=delta_*, 14=ordinal_probit, 15=nbinom1.

---

## 8. First actions for the new session

1. Read `~/.claude/memory/memory_summary.md` (esp. the ★ Ψ model + the 2026-06-21
   snapshot) and `AGENTS.md` / `CLAUDE.md`.
2. `git fetch` both repos; confirm `gllvmTMB` `main`=`60fb621`, `GLLVM.jl`=`c81be2f`.
3. Check `gh pr list` / `gh issue list` for both repos for any maintainer replies on
   #113 (Codex), #343, #507.
4. Ask the maintainer which next slice (§6) to take — do not start a grammar/engine/
   family slice without explicit go-ahead.
