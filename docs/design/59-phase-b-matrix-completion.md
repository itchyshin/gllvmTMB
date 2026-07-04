# Design 59 — Phase B-matrix: capability-matrix completion campaign

**Status**: In flight (2026-05-29)
**Goal**: walk every *feasible* `partial` cell of the family × structure
capability matrix to `covered`, honestly skipping infeasible cells.

## What this campaign does NOT redo (already owned)

- **Random-slope column** (`phylo_unique(1 + x | sp)`) × core families →
  Phase B-NG (branch `agent/phase-b-ng`, in flight).
- **Binary probit × {phylo_scalar, phylo_indep/dep, spatial pair/scalar/
  indep/dep}** → PR #309 (merged to main).
- **Lambda-entry + derived-quantity CIs** (Wald / Wald-asym / profile /
  bootstrap) → PRs #307 (merged) + #308 (open).

## Matrix gaps this campaign fills

| Group | Cells | Families |
|---|---|---|
| **A** unit-tier structural | ordinary `latent`, explicit-Psi compatibility, `indep`, `dep`, and scalar diagonal cells at the unit tier | poisson, nbinom2, gamma, beta, ordinal_probit, binomial-logit |
| **B** phylo × non-binary | `phylo_latent()` with explicit-Psi compatibility where needed, `phylo_scalar`, `phylo_indep` / `phylo_dep` | poisson, nbinom2, gamma, beta, ordinal_probit |
| **C** spatial × non-binary | `spatial_latent()` with explicit-Psi compatibility where needed, `spatial_scalar`, `spatial_indep` / `spatial_dep` | poisson, nbinom2, gamma, beta, ordinal_probit |
| **E** tail-family recovery | family recovery depth plus ordinary latent / explicit compatibility diagonal smoke | betabinomial, nbinom1, lognormal, student-t, tweedie, truncated, censored |

## Agent ownership (1 test file per agent, disjoint)

| Agent | File | Register rows it informs |
|---|---|---|
| A-pois | `test-matrix-poisson-unit.R` | FG-07/08/09 (poisson), RE-09 |
| A-nb2 | `test-matrix-nbinom2-unit.R` | FG-07/08/09 (nbinom2) |
| A-gam | `test-matrix-gamma-unit.R` | FG-07/08/09 (gamma), FAM-09 |
| A-beta | `test-matrix-beta-unit.R` | FG-07/08/09 (beta), FAM-10 |
| A-ord | `test-matrix-ordinal-unit.R` | FG-07/08/09 (ordinal), FAM-14 |
| A-logit | `test-matrix-binomial-logit-unit.R` | FG-07/08/09 (binomial-logit) |
| B-pois | `test-matrix-poisson-phylo.R` | PHY-04/05 (poisson) |
| B-nb2 | `test-matrix-nbinom2-phylo.R` | PHY-04/05 (nbinom2) |
| B-gam | `test-matrix-gamma-phylo.R` | PHY-04/05 (gamma) |
| B-beta | `test-matrix-beta-phylo.R` | PHY-04/05 (beta) |
| B-ord | `test-matrix-ordinal-phylo.R` | PHY-04/05 (ordinal) |
| C-pois | `test-matrix-poisson-spatial.R` | SPA-02/03/04 (poisson) |
| C-nb2 | `test-matrix-nbinom2-spatial.R` | SPA-02/03/04 (nbinom2) |
| C-gam | `test-matrix-gamma-spatial.R` | SPA-02/03/04 (gamma) |
| C-beta | `test-matrix-beta-spatial.R` | SPA-02/03/04 (beta) |
| C-ord | `test-matrix-ordinal-spatial.R` | SPA-02/03/04 (ordinal) |
| E-bb | `test-matrix-betabinomial.R` | FAM-05 |
| E-nb1 | `test-matrix-nbinom1.R` | FAM-07 |
| E-ln | `test-matrix-lognormal.R` | FAM-11 |
| E-st | `test-matrix-student.R` | FAM-12 |
| E-tw | `test-matrix-tweedie.R` | FAM-13 |
| E-tr | `test-matrix-truncated.R` | FAM-15 |

## Coordination protocol (collision-safe at scale)

1. **All agents work in worktree `/tmp/gll-matrix`** on branch
   `agent/phase-b-matrix`. `cd` there first.
2. **Each agent writes exactly ONE uniquely-named test file** and commits
   with `git add tests/testthat/<their-file>.R` ONLY — never `git add -A`,
   never a directory, never the register. This is the lesson from the
   B1/B3 collision (a broad `git add` swept a sibling's staged file).
3. **Agents do NOT edit `docs/design/35-validation-debt-register.md`.**
   They report, in their final message, each row ID and the status their
   evidence supports (`covered` / stays `partial` + reason). The
   orchestrator consolidates all register moves in ONE reviewable commit
   after the wave.
4. **`devtools::load_all()`, NOT `install()`** — avoids cross-agent
   library races. The worktree is pre-compiled once before dispatch.

## Honest-matrix discipline (hard)

- **No widening tolerances.** Per-family recovery tolerance comes from the
  Phase B0 scoping memo; fixed-residual-scale families (binomial, ordinal
  probit) tighter than mean-dependent (poisson, nbinom2, gamma, beta).
- **No fake-pass.** A cell that does not converge / is non-PD / has a
  degenerate profile is **skipped** with `skip("<reason>")` and reported
  as "stays partial", NOT forced green.
- **Time-box 15 min per fit.** If a single fit exceeds it, skip + report.
- **Engine/parser frozen**: no touches to `src/gllvmTMB.cpp`,
  `R/fit-multi.R`, `R/brms-sugar.R`, `R/parse-multi-formula.R`.

## Close-out

When a wave returns: orchestrator (a) runs the full new-test filter to
confirm green/skip (no fails), (b) writes the single register-update
commit moving only the rows with real passing evidence, (c) folds the
wave into PR #311 (Phase B-matrix). The matrix ends "covered where the
data identify it, honestly-partial where they do not" — the register is
the ledger, not a wish-list.
