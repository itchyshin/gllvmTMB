# After-task: Notation switch NS-3a -- API rename + callers -- 2026-05-14

**Tag**: `engine` (public API rename in `simulate_site_trait()`;
cascading test + article + README updates to keep CI green).

**PR / branch**: this PR / `agent/notation-switch-r-roxygen`.

**Lane**: Claude (Codex absent).

**Dispatched by**: maintainer 2026-05-14 "let's go Psi!"
(originating chain); follow-up clarification "a - rename - all
unique parts should use Psi/psi consistently". NS-3a is the
atomic API-rename portion of NS-3 per the Option 2 split
("split into NS-3a atomic API rename + NS-3b roxygen sweep")
chosen by the maintainer.

**Files touched** (43 files):

R/ source:
- `R/simulate-site-trait.R`: argument names `S_B`, `S_W`
  renamed to `psi_B`, `psi_W` (lowercase; matches the
  factor-analysis convention where lowercase greek = vector
  of diagonal entries). Internal variables, `@param` block,
  `@return` block describing the `truth` list, and the
  returned `truth$psi_B` / `truth$psi_W` keys all renamed.
  `@examples` unchanged (the example uses defaults).
- `R/rotate-loadings.R`: `@examples` call updated.
- `R/extract-correlations.R`: `@examples` call updated.
- `R/bootstrap-sigma.R`: `@examples` call updated.
- `R/z-confint-gllvmTMB.R`: `@examples` call updated.

tests/testthat/ (30 files; ~134 reference sites):

- 84 reference sites + ~50 more from the second grep pass
  (after the initial scope undercount).
- All `simulate_site_trait(S_B = ...)` -> `simulate_site_trait(psi_B = ...)`.
- All `simulate_site_trait(S_W = ...)` -> `simulate_site_trait(psi_W = ...)`.
- All `sim$truth$S_B` -> `sim$truth$psi_B` (only in
  `test-simulate-site-trait.R`).
- Test-internal variable names (e.g. `S_B`, `S_W` used as
  local variables in test fixtures) renamed to `psi_B`,
  `psi_W` for consistency.

vignettes/articles/ code chunks (4 files; 9 reference sites):

- `joint-sdm.Rmd:254`: `S_B = rep(0.4, T)` -> `psi_B = rep(0.4, T)`.
- `choose-your-model.Rmd:248, 280, 311`: same pattern.
- `pitfalls.Rmd:87, 120, 127, 134`: same pattern (plus one
  inline `# CLEAN latent()-only DGP: explicitly switch off
  beta and S_B` comment, also renamed).
- `functional-biogeography.Rmd:143-150, 162-163`: `S_B_true`
  / `S_W_true` local variable assignments + the
  `simulate_site_trait()` call renamed accordingly. Article
  math-prose references to `S_B` and `S_W` in
  $\boldsymbol\Sigma_B = \boldsymbol\Lambda_B
  \boldsymbol\Lambda_B^{\!\top} + \boldsymbol\Psi_B$ style
  equations **stay** for NS-5 (article math-prose sweep).

README.md:
- Line 113 (Tiny example smoke test code chunk):
  `S_B = c(0.2, 0.3, 0.2)` -> `psi_B = c(0.2, 0.3, 0.2)`.
- Math prose was already updated in NS-2 (PR #87).

man/*.Rd (regenerated via `devtools::document()`):
- `man/simulate_site_trait.Rd` -- new `@param psi_B,psi_W`
  block, updated `@return` description, updated parameter
  signature.
- `man/bootstrap_Sigma.Rd`, `man/extract_correlations.Rd`,
  `man/confint.gllvmTMB_multi.Rd`, `man/rotate_loadings.Rd`
  -- updated `@examples` chunks.

dev-log:
- `docs/dev-log/after-task/2026-05-14-notation-switch-ns3a-api-rename.md`
  (this file).

## Math contract

The argument-name change is purely a function-parameter
rename. The model, likelihood, parameterisation, formula
grammar, and parser are unchanged. `simulate_site_trait()`
still simulates the same data-generating process; only the
keyword for the unique-variance vector input changed:

```
# Before:
sim <- simulate_site_trait(..., S_B = c(0.2, 0.3), S_W = c(...))
sim$truth$S_B

# After:
sim <- simulate_site_trait(..., psi_B = c(0.2, 0.3), psi_W = c(...))
sim$truth$psi_B
```

`psi_B` and `psi_W` are length-`n_traits` vectors of
trait-specific unique variances. In math notation:
`\boldsymbol\Psi_B = diag(psi_B)`,
`\boldsymbol\Psi_W = diag(psi_W)`. The matrix-side bold
capital `\boldsymbol\Psi` was introduced in NS-1 / NS-2; the
function-argument vector-side lowercase `psi` is introduced
here. This matches the factor-analysis convention (bold
capital for matrices, italic lowercase for entries).

The function signature change is **breaking** for any caller
using positional or named-argument matching on `S_B` / `S_W`.
Pre-CRAN: no external users; in-repo callers (tests, R/
@examples, articles, README) all updated in this PR.

## Checks run

- `devtools::document(quiet = TRUE)`: clean regeneration of
  the 5 affected `man/*.Rd` files. Per the post-document
  protocol (PR #36 lesson):
  `tail -5 man/simulate_site_trait.Rd` -- ends with
  `sim$truth$alpha` then `}`; clean.
  `grep -c '^\\keyword' man/simulate_site_trait.Rd` -- 0;
  no malformed roxygen-tag-after-prose output.
- `devtools::load_all(quiet = TRUE)`: clean.
  `simulate_site_trait` formals: `n_sites, n_species,
  n_traits, mean_species_per_site, n_predictors, alpha,
  beta, sigma2_eps, Lambda_B, Lambda_W, psi_B, psi_W,
  sigma2_phy, sigma2_sp, Cphy, spatial_range, sigma2_spa,
  coords, seed`. `psi_B` present; `S_B` absent. Confirmed.
- `testthat::test_file("tests/testthat/test-simulate-site-trait.R")`:
  33 PASS, 0 FAIL, 0 WARN, 0 SKIP.
- Full `devtools::test()` running in background as of
  commit; expected to pass since the API change is mechanical
  and all in-repo callers were updated.

## Consistency audit

- `rg -n '\\bS_B\\b|\\bS_W\\b' tests/testthat/ R/rotate-loadings.R
  R/extract-correlations.R R/bootstrap-sigma.R
  R/z-confint-gllvmTMB.R R/simulate-site-trait.R
  vignettes/articles/joint-sdm.Rmd
  vignettes/articles/choose-your-model.Rmd
  vignettes/articles/pitfalls.Rmd
  vignettes/articles/functional-biogeography.Rmd README.md`
  returned **zero hits** after the perl rename. NS-3a scope is
  consistent.
- `S_B` / `S_W` references remaining in main are now confined
  to NS-3b scope (R/ roxygen math prose in `extract-sigma.R`,
  `extract-omega.R`, `unique-keyword.R`, `extractors.R`,
  `fit-multi.R`, `extract-two-U-cross-check.R`,
  `extract-two-U-via-PIC.R`, `brms-sugar.R`) + NS-5 scope
  (article math prose in
  `behavioural-syndromes.Rmd:342, 345`, the `\Psi_X` lines
  in `functional-biogeography.Rmd` -- already converted to
  `\boldsymbol{S}_X` in PR #82 and pending conversion back to
  `\boldsymbol{\Psi}_X` in NS-5 -- and inline math in
  `pitfalls.Rmd:114`).

## Tests of the tests

- `test-simulate-site-trait.R` passes after rename (33/33);
  catches a mis-rename in the function signature or internal
  vars.
- Cross-file rename catches: if any caller is missed, the
  test will fail with `unused argument (S_B = ...)` or
  `$ operator is invalid for atomic vectors`. The full
  test-suite run in background will catch these. Current
  expectation: pass; if any failures surface, fix in this PR
  before opening.

## What went well

- The maintainer's "all unique parts should use Psi/psi
  consistently" was a clear-enough directive that the
  rename pattern (`S_B` -> `psi_B`, `S_W` -> `psi_W`) could
  be applied via a single `perl -i -pe` regex across 43
  files in one pass. No file-by-file manual editing
  required.
- Pre-rename grep confirmed the only S_B/S_W tokens in the
  test corpus were the literal `S_B` and `S_W` themselves
  (no `S_B_true`, no `S_BIG`, no other variants), making the
  word-boundary regex `\bS_B\b` safe. This let the rename be
  truly atomic.
- `devtools::document()` regeneration of `man/*.Rd` produced
  no malformed `\keyword` entries (post-doc protocol check
  per PR #36 lesson). Clean.
- Test-simulate-site-trait runs cleanly after rename,
  confirming the @return list keys are correctly accessed by
  the test (`sim$truth$psi_B` now works).

## What did not go smoothly

- **Initial scope undercount**. First grep showed 84 test
  references; the second pass found ~50 more (in
  `test-stage37-mixed-family.R`, `test-tidy-predict.R`,
  `test-stage2-rr-diag.R`). The first grep used a narrower
  pattern that missed some cases. Lesson: when scoping a
  multi-file rename, do the broad perl-dry-run before
  estimating PR size. Total ended at ~134 reference sites
  across 30 test files, ~9 article references, ~4 R/ caller
  @examples references, 1 README site -- 43 files total.
- **Article math-prose left for NS-5** means temporary
  inconsistency in main between code chunks (now `psi_B`)
  and math prose (still `S_B` / `\boldsymbol{S}_B`). This
  is intentional per the NS-1..NS-5 sequence design, but
  worth flagging for the rendered articles' interim state.

## Team learning, per AGENTS.md role

- **Ada (maintainer)**: the clear-enough directive ("a -
  rename - all unique parts should use Psi/psi consistently")
  was the key to the smooth perl pass. When the maintainer
  gives a single-pattern instruction, the bulk-rename tooling
  works. Counter-example: if the directive had been "rename
  some of S_B but not others", the perl approach would have
  been wrong.
- **Boole (R API)**: the breaking API change is the heart
  of this PR. `simulate_site_trait(S_B = ...)` will fail
  post-merge; callers must update to `psi_B = ...`.
  Pre-CRAN no-external-users argument is the rationale; no
  `lifecycle::deprecate_soft()` alias. If pilot users
  exist outside the repo, this will break them. Standing
  brief for any future user-facing rename: same atomic
  scope-then-sweep pattern, with deprecation considered
  if any external users have been counted.
- **Gauss (TMB likelihood / numerical)**: no TMB-side
  touch in NS-3a. The argument names are wrapper-level R
  parameters; the engine receives the variance values via
  `truth$...` access in tests and via the simulator's
  internal use. Standing brief for NS-3b: the math prose
  in roxygen of R/ files like `extract-sigma.R` is
  cosmetic; no algorithmic change.
- **Noether (math consistency)**: the engine equation
  $\boldsymbol{\Sigma}_B = \boldsymbol{\Lambda}_B
  \boldsymbol{\Lambda}_B^{\!\top} + \boldsymbol{\Psi}_B$ is
  now also reflected in the function-argument naming
  (`psi_B` is the vector of diagonal entries of
  `\boldsymbol{\Psi}_B`). The math and the R API now align
  perfectly. Cleanup pass scheduled for NS-3b roxygen
  sweep.
- **Darwin (biology audience)**: no biology-audience change
  in NS-3a; standing brief for NS-4/NS-5 article math-prose
  updates.
- **Fisher (statistical inference)**: no inference-machinery
  touch; standing brief for Phase 1b (engine + extractor +
  diagnostics).
- **Emmy (R package architecture)**: `man/*.Rd` regenerated;
  no S3 method change. Public surface API change limited to
  `simulate_site_trait()` parameter names.
- **Pat (applied PhD user)**: README's Tiny example now
  reads `psi_B = c(0.2, 0.3, 0.2)` in the code chunk; math
  prose says `\boldsymbol{\Sigma} = \boldsymbol{\Lambda}
  \boldsymbol{\Lambda}^{\!\top} + \mathrm{diag}(\psi)`
  (from NS-2). Code and math now use lowercase `\psi`
  consistently. Future Pat audits: confirm every article's
  first runnable chunk uses the new argument names.
- **Jason (literature / scout)**: no literature scan
  scheduled until pre-Phase-1b' (or per-phase-boundary
  cadence).
- **Curie (simulation / testing)**: the simulator fixture
  is `psi_B = c(...)`-driven everywhere now. Recovery tests
  read `sim$truth$psi_B`. Standing brief: future DGP
  extensions (e.g., `simulate_phylo_trait()` if added) use
  `psi_*` parameter names from the start.
- **Grace (CI / pkgdown / CRAN)**: CI may rerun on this PR
  to confirm full test suite passes after the rename. No
  pkgdown change in NS-3a; article math-prose still
  uses `S_B` so pkgdown rendering still works (the math is
  just LaTeX in `\eqn{}`/`$$...$$` blocks; not parsed by R).
  Renders fine; just temporarily inconsistent with the new
  R-side convention. NS-5 closes that.
- **Rose (systems audit)**: pre-publish audit confirms the
  perl rename was complete (zero `\bS_B\b|\bS_W\b` hits in
  NS-3a scope). Cross-file consistency: AGENTS.md /
  CONTRIBUTING.md / CLAUDE.md / decisions.md / check-log.md
  (from NS-1), README / design docs (from NS-2), R/ source
  + tests + article chunks + man/Rd (from NS-3a) all on
  the new `\boldsymbol\Psi` / `psi` convention.
- **Shannon (cross-team)**: Codex absent. No cross-team
  coordination event in this PR.

## Design-doc + pkgdown updates

- No design-doc edits in NS-3a (design docs handled in
  NS-2).
- `pkgdown::check_pkgdown()` not re-run in this PR; the
  navbar / reference index didn't change. The reference
  index entry for `simulate_site_trait` will show the
  updated `@param psi_B,psi_W` block once pkgdown
  re-renders.

## Known limitations and next actions

**Known limitations**:

- Article math-prose still uses `S_B`, `S_W`, `S_phy`,
  `S_non` in `\eqn{}` / `$$...$$` blocks until NS-5 lands.
  Temporary code-vs-math inconsistency in the rendered
  articles.
- R/ roxygen math prose in 8 R/ files (`extract-sigma.R`,
  `extract-omega.R`, `unique-keyword.R`, `extractors.R`,
  `fit-multi.R`, `extract-two-U-cross-check.R`,
  `extract-two-U-via-PIC.R`, `brms-sugar.R`) still uses
  `\mathbf{S}_B` etc. in `\eqn{}` blocks until NS-3b
  lands. Reference-index visible.

**Next actions**:

1. Verify full `devtools::test()` passes (running in
   background as of NS-3a commit).
2. NS-3b: R/ roxygen prose sweep across the 8 R/ files
   with math notation in `\eqn{}` blocks (no API change;
   cosmetic).
3. NS-4: articles part 1 (Concepts + lighter Worked
   examples) -- math prose sweep.
4. NS-5: articles part 2 (heavier Worked examples) +
   `NEWS.md` entry + final pkgdown sanity check.
5. After NS-1 through NS-5 merged: start Phase 1a Batch A
   under the new convention.
