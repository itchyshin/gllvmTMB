# Design 58 — Phase B-INF: Binary inference maximally done

**Status**: In flight (2026-05-28)
**Closure criterion**: Lane 1 + Lane 2 land with focused tests green per agent.
Empirical 94% coverage (CI-08, CI-10) stays `partial` — separate Phase B-COV.

## Goal

Make the unified `confint(parm, method)` surface (Design 02 + Stages 1–3c of
the Profile-CI unified framework, PR #307) **programmatically complete on
binary probit fits across all random-effect keywords and all CI methods**.

Every documented `(parm, method)` combination on a binary fit:
- returns a finite CI when the data identify it,
- returns NA + an honest `ci_status` when they don't,
- never invents a number,
- has a focused test.

## Scope (in)

| Lane | What |
|---|---|
| 1 | Wald + Bootstrap paths for derived quantities currently profile-only: `communality`, `proportions`, `phylo_signal`; plus Bootstrap path for Lambda entries |
| 2 | Binary probit recovery + CI smoke for the partial random-effect keywords: `phylo_scalar`, `phylo_indep`/`phylo_dep`, `spatial_latent + spatial_unique` paired, `spatial_scalar`, `spatial_indep`/`spatial_dep` |

Validation-debt register rows walked to `covered` on close: **PHY-04, PHY-05,
SPA-02, SPA-03, SPA-04**.

## Scope (out, explicit)

- Empirical 94% coverage at scale (CI-08) — Phase B-COV, separate dispatch.
- Mixed-family CI (CI-10) — stays `partial`.
- Non-binary families (Gaussian, Poisson, NB, Gamma, beta, ordinal) — Phase B-NG.
- Article rewrites — Phase Articles.
- Gaussian `lambda_constraint` (LAM-02) — separate work.
- `phylo_slope` (PHY-06) — Phase 56 structural-slope lane.
- Engine / parser changes (`src/gllvmTMB.cpp`, `R/fit-multi.R`, `R/brms-sugar.R`,
  `R/parse-multi-formula.R`) — out of scope, hard-blocked per maintainer.

## Lane 1 — CI method completion (4 parallel agents)

| Agent | Target | Methods added | New R file (disjoint) | New test file |
|---|---|---|---|---|
| A1 | communality | Wald (delta on `(LL^T)_tt / Σ_tt` at one tier), Bootstrap (refit-based) | `R/communality-ci.R` | `tests/testthat/test-communality-ci.R` |
| A2 | proportions | Wald (delta on `Σ_c[tt] / Σ_total[tt]`), Bootstrap | `R/proportions-ci.R` | `tests/testthat/test-proportions-ci.R` |
| A3 | phylo_signal | Wald (delta on `σ²_phy / total`), Bootstrap | `R/phylo-signal-ci.R` | `tests/testthat/test-phylo-signal-ci.R` |
| A4 | Lambda entries | Bootstrap (Procrustes-aligned, reuses `bootstrap_Sigma` machinery) | `R/loading-ci-bootstrap.R` | `tests/testthat/test-loading-ci-bootstrap.R` |

**Coordination**: each Lane 1 agent writes its new R file + new test file only.
Agents do **not** edit `R/z-confint-gllvmTMB.R`. Orchestrator (Claude session)
adds all four routing branches in a single integration commit after the four
agents land.

## Lane 2 — Binary × RE-keyword full coverage (5 parallel agents)

| Agent | Register row | Scope | New test file (disjoint) |
|---|---|---|---|
| B1 | PHY-04 | `phylo_scalar(0+trait\|sp)` on binary probit: recovery on `σ²_phy_scalar` + correlation CI | `tests/testthat/test-phyloscalar-binary.R` |
| B2 | PHY-05 | `phylo_indep` and `phylo_dep` on binary probit: recovery + CI smoke | `tests/testthat/test-phylodepindep-binary.R` |
| B3 | SPA-02 | `spatial_latent + spatial_unique` paired on binary probit + SPDE mesh: recovery + CI | `tests/testthat/test-spatial-pair-binary.R` |
| B4 | SPA-03 | `spatial_scalar` on binary probit: recovery + CI | `tests/testthat/test-spatial-scalar-binary.R` |
| B5 | SPA-04 | `spatial_indep`/`spatial_dep` on binary probit: recovery + CI smoke | `tests/testthat/test-spatial-depindep-binary.R` |

**Coordination**: zero file overlap. Each agent also updates **one row** of
`docs/design/35-validation-debt-register.md` (their corresponding row from
`partial` → `covered`, with the new test path cited).

## Branch + PR strategy

- Lane 1 base branch: **`agent/phase-b-inf-lane1`** off `bdcbabc` (current PR #307 tip).
- Lane 2 base branch: **`agent/phase-b-inf-lane2`** off `bdcbabc`.
- Lanes land as separate PRs: **PR #308** (Lane 1) and **PR #309** (Lane 2).
- Both PRs rebase trivially when PR #307 merges to main (Phase B-INF touches
  different files except for the one shared dispatch file in Lane 1, which the
  orchestrator integrates).

## Hard constraints (verbatim from maintainer)

- No engine/parser touches.
- No tolerance widening.
- No fake-pass tests. If a tier's profile sweep diverges on a fixture, narrow
  the test rather than relax the assertion.
- Validation-debt rows move `partial → covered` only with passing evidence
  path; if the recovery genuinely fails, flag it honestly in the register and
  the PR description.
- Each PR ships with a NEWS.md release-note entry staged.

## Per-agent close-out checklist

- [ ] `devtools::document()`
- [ ] `devtools::test(filter = "<focused>")` green
- [ ] `devtools::check_man()` clean
- [ ] One register row walked (Lane 2) OR new R file documented (Lane 1)
- [ ] Commit to lane branch, no push (orchestrator pushes after merge)

## Estimate

~3–6 hours per agent wall-clock; up to 9 in parallel. Lane 1 close-out ~6–8 h,
Lane 2 close-out ~6–8 h, partially overlapping. Total ~10–12 h wall-clock,
mostly unattended.

## Out-of-band tracking

PR #307 (lambda-constraint capability + profile-CI framework + Stage 3c +
bound-agreement fix) is in 3-OS CI as of 2026-05-28. Phase B-INF starts before
PR #307 merges; both lanes branch off `bdcbabc` and will rebase when #307 lands.
