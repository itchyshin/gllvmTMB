# After-task report - sister-package citation hygiene + `meta_V()` syntax (#223, #227)

**Date**: 2026-05-20
**Branch**: `codex/sister-package-citation-hygiene-2026-05-20`
**PR**: #226
**Issues**: #223, #227
**Maintainer lane**: citation/provenance hygiene plus one API-convention
fix discovered from the rendered `meta_V()` reference page.

## Active perspectives

- **Ada**: orchestrated the bounded lane and kept issue, board,
  check-log, and after-task artefacts aligned.
- **Jason**: checked sister-package and literature-map context.
- **Boole**: reviewed the formula-marker convention and the 4 x 5
  keyword grammar.
- **Pat**: checked the wide-format `traits(...)` reader path.
- **Fisher**: checked inference-claim boundaries and MET-01 / MET-03
  validation-debt wording.
- **Grace**: checked roxygen, pkgdown, focused tests, and article
  rendering.
- **Rose**: checked stale wording, unsupported capability drift, and
  convention-change cascade coverage.
- **Shannon**: checked coordination state before shared-file edits.

No spawned subagents were running for this lane.

## Scope

Completed edits:

- refreshed sister-package and simulation-reporting citation context;
- fixed live stale `3 x 5` wording;
- kept recent phylogenetic location-scale work framed as background,
  not an implemented `gllvmTMB` feature;
- changed the canonical known-V marker to `meta_V(V = V)` /
  `meta_V(V, type = "exact")`;
- kept `meta_V(value, V = V)` and `meta_known_V(V = V)` accepted by
  the parser for compatibility;
- reserved `type = "proportional"` as a planned, currently blocked
  mode that errors explicitly;
- fixed the wide `traits(...)` RHS expander so `meta_V()` is preserved
  as a covariance marker;
- downgraded unsupported known-V `glmmTMB::equalto()` comparator prose
  to MET-01 validation debt;
- appended exact commands and stale-wording scans to
  `docs/dev-log/check-log.md`.

## Definition-of-done check

1. **Implementation**: complete. R parser and wide-format expander code
   changed for `meta_V()`. No C++ likelihood or TMB parameterization was
   changed.
2. **Simulation recovery test**: not applicable. This was a
   formula-marker / parser convention change, not a new likelihood,
   family, keyword family, or estimator. Existing MET-01 remains
   `partial` until the direct `glmmTMB::equalto()` comparator lands.
3. **Documentation**: complete. Roxygen, generated Rd, README, NEWS,
   design docs, validation-debt rows, AGENTS/CLAUDE rules, Rose's
   pre-publish rule, and affected articles were updated.
4. **Runnable user-facing example**: complete for this scope. New public
   examples use `meta_V(V = V)`; old `value` placeholder examples were
   removed except where explicitly documented as compatibility history.
5. **Check-log entry**: complete; see
   `docs/dev-log/check-log.md` 2026-05-20 #223 and #227 entries.
6. **Review pass**: complete for this scope. Boole checked formula
   grammar; Pat checked wide-format behaviour; Fisher checked MET-01 /
   MET-03 claim boundaries; Grace checked documentation and focused
   tests; Rose checked stale wording and cascade coverage; Shannon
   checked coordination state before shared-file edits.

## Commands and evidence

- `git status --short --branch`
  -> branch and worktree checked before editing.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt`
  -> no open PRs at lane start.
- `git log --all --oneline --since="6 hours ago"`
  -> recent shared-file history reviewed before editing.
- Literature/source checks for #223 covered `gllvm` 2.0, EVA-GLLVM,
  `glmmTMB::rr()`, simulation-reporting guidance, and phylogenetic
  location-scale background; DOIs are recorded in the check-log.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/meta.Rd`, `man/meta_V.Rd`, and
  `man/meta_known_V.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "formula-grammar-smoke")'`
  -> passed: 27 tests, no warnings, no skips.
- `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword")'`
  -> passed: 49 tests, 1 pre-existing skip, no warnings.
- `Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords")'`
  -> passed: 48 tests, 3 skips for missing INLA, no warnings.
- `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMB-args")'`
  -> passed: 24 tests, 4 pre-existing no-covstruct skips, no warnings.
- `git diff --check`
  -> clean.
- #223 stale-syntax scans:
  - `rg -n '3 x 5|3 × 5|3x5' ...`
    -> one remaining historical NEWS hit only.
  - `rg -n 'gllvmTMB_wide\(Y, \.\.\.\) was removed|removed in 0\.2\.0|REMOVED in 0\.2\.0|profile-likelihood default|trio|meta_known_V\(value|phylo\(|gr\(|meta\(|diag\(U\)|U_phy|U_non|\\bf S|S_B|S_W' ...`
    -> 0 hits.
- #227 stale-syntax scans:
  - `rg -n 'meta_V\(value, V = V\)|meta_known_V\(value|scale = "proportional"|scale = "known"|meta_V\(value, w|meta_V\(scale' ...`
    -> only expected compatibility/history mentions remained.
  - `rg -n 'glmmTMB::equalto\(.*\).*LL match|LL match to 1e-3|log-likelihood match to 1e-3|test-stage3-propto-equalto\.R.*equalto|equalto.*covered' ...`
    -> no stale known-V equalto-coverage claims.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> passed: `No problems found.`
- `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`
  -> failed before reaching touched files because a new pkgdown process
  loaded an older installed `gllvmTMB` without the current
  `pedigree_to_A()` export.
- `pkgload::load_all()` + `pkgdown::build_article(..., new_process = FALSE)`
  -> current-checkout render passed for `animal-model` and all seven
  touched articles; only pre-existing missing-logo and Pandoc TeX
  warnings appeared.

## Files touched

Implementation and tests:

- `R/brms-sugar.R`
- `R/traits-keyword.R`
- `R/two-stage.R`
- `tests/testthat/test-formula-grammar-smoke.R`
- `tests/testthat/test-traits-keyword.R`
- `tests/testthat/test-block-V.R`
- `tests/testthat/test-canonical-keywords.R`

Generated documentation:

- `man/meta.Rd`
- `man/meta_V.Rd`
- `man/meta_known_V.Rd`

Public prose and examples:

- `README.md`
- `NEWS.md`
- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/choose-your-model.Rmd`
- `vignettes/articles/cross-package-validation.Rmd`
- `vignettes/articles/data-shape-flowchart.Rmd`
- `vignettes/articles/gllvm-vocabulary.Rmd`
- `vignettes/articles/pitfalls.Rmd`
- `vignettes/articles/stacked-trait-gllvm.Rmd`

Design / process docs:

- `AGENTS.md`
- `CLAUDE.md`
- `.agents/skills/rose-pre-publish-audit/SKILL.md`
- `docs/design/00-vision.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/04-random-effects.md`
- `docs/design/04-sister-package-scope.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/14-known-relatedness-keywords.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-20-sister-package-citation-hygiene.md`

## Outcome

The literature map now credits `gllvm` 2.0, EVA-GLLVM, and
`glmmTMB::rr()` explicitly; M3 simulation docs cite ADEMP and
transparent simulation-reporting guidance; recent phylogenetic
location-scale work is recorded as background rather than an
implemented `gllvmTMB` feature. The `meta_V()` public API now follows
the value-less known-V marker shape (`meta_V(V = V)`), works through
the wide `traits(...)` parser path, and reserves
`type = "proportional"` honestly as blocked future work rather than
implying it is already implemented.
