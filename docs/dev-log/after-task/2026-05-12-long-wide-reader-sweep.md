# After Task: Long/Wide Reader-Facing Sweep

## Goal

Complete the post-PR #33 long/wide cleanup by making the wide
data-frame path match the reader promise: `traits(...)` names response
columns on the LHS, so the RHS should use compact syntax rather than
forcing the long-form `0 + trait` grammar.

## Implemented

- Fixed `R/traits-keyword.R` so `traits(...)` expands compact wide RHS
  syntax before the recursive long-engine call:
  `1` -> `0 + trait`, `x` -> `(0 + trait):x`, and
  `latent(1 | unit)` / `unique(1 | unit)` -> the matching
  `0 + trait | unit` long covariance terms.
- Covered the rest of the formula surface in the same expander:
  `indep()`, `dep()`, bar-style `phylo_indep()` / `phylo_dep()`, and
  `spatial_*()` terms get the same `1 | group` ->
  `0 + trait | group` rewrite; species-axis phylogenetic keywords such
  as `phylo_latent(species, d = K)` pass through because they already
  name the species axis; ordinary `(1 | group)` random intercepts pass
  through unchanged.
- Restored `vignettes/articles/morphometrics.Rmd` to show the same
  model three ways: long, formula-wide `traits(...)`, and
  matrix-wide `gllvmTMB_wide()`.
- Restored the first-replicate wide equivalence check in the
  morphometrics recovery loop using the compact formula-wide syntax.
- Restored formula-wide `dep()` / `indep()` comparison fits, now using
  `dep(1 | individual)` and `indep(1 | individual)` as the wide RHS.
- Rewrote the behavioural-syndromes and functional-biogeography
  wide-input notes so they show the compact `traits(...) ~ 1 + ...`
  grammar instead of telling readers to write long-form RHS syntax.
- Updated the data-shape design note, README, `AGENTS.md`, `CLAUDE.md`,
  NEWS, roxygen, and generated Rd to describe `traits()` as the wide
  data-frame formula path rather than a hidden long-syntax shim.

## Mathematical Contract

No likelihood, family, NAMESPACE, or estimator change. This is a
parser-layer formula rewrite inside the existing `traits()` LHS path,
plus tests and documentation. Explicit long RHS syntax remains
accepted, so existing code that already wrote `0 + trait` stays valid.

## Files Changed

- `vignettes/articles/morphometrics.Rmd`
- `vignettes/articles/behavioural-syndromes.Rmd`
- `vignettes/articles/functional-biogeography.Rmd`
- `docs/design/02-data-shape-and-weights.md`
- `CLAUDE.md`
- `R/gllvmTMB.R`
- `R/gllvmTMB-wide.R`
- `R/traits-keyword.R`
- `tests/testthat/test-traits-keyword.R`
- `tests/testthat/test-weights-unified.R`
- `README.md`
- `NEWS.md`
- `AGENTS.md`
- `_pkgdown.yml`
- `man/gllvmTMB.Rd`
- `man/gllvmTMB_wide.Rd`
- `man/traits.Rd`
- `docs/dev-log/after-task/2026-05-12-long-wide-reader-sweep.md`

## Checks Run

- Pre-edit lane check: `gh pr list --state open` initially showed
  PR #35 (Shannon audit files) and PR #36 (housekeeping bundle,
  including `docs/dev-log/check-log.md`). No same-file collision was
  found for the source/test/docs touched here. A coordination comment
  was left on PR #36:
  `https://github.com/itchyshin/gllvmTMB/pull/36#issuecomment-4432401845`.
  On resume, PR #36 had merged, so this branch was fast-forwarded to
  `origin/main` before appending the deferred check-log entry.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE)'`:
  completed after the RHS rewrite patch.
- Direct rewrite probes confirmed that compact fixed effects,
  `latent()` / `unique()` / `indep()` / `dep()`, `phylo_*()`,
  `spatial_*()`, `spatial()`, and `(1 | group)` route to the intended
  long formula expressions.
- `air format R/traits-keyword.R tests/testthat/test-traits-keyword.R tests/testthat/test-weights-unified.R`:
  completed.
- `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword|weights-unified")'`:
  passed with `FAIL 0 | WARN 0 | SKIP 1 | PASS 65`. The skip is the
  pre-existing fixed-effect-only fallback skip.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`:
  completed and regenerated `man/gllvmTMB.Rd`, `man/gllvmTMB_wide.Rd`,
  and `man/traits.Rd`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/morphometrics", new_process = FALSE)'`:
  completed and wrote `articles/morphometrics.html`; the only message
  was the pre-existing `../logo.png` pkgdown warning. The default
  `new_process = TRUE` path was not the right local source check here
  because it picked up the installed package before this source patch.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`:
  passed with "No problems found."
- Rose pre-publish audit: PASS. Targeted scans found no contradiction
  between the touched README/vignettes/design/Rd wording and the
  current wide-data-frame formula contract.
- `git diff --check`: passed.
- Resumed verification after the final phylogenetic wording fix:
  `devtools::document(quiet = TRUE)` regenerated `man/traits.Rd`;
  `pkgdown::build_article("articles/morphometrics", new_process = FALSE)`
  completed with only the pre-existing `../logo.png` warning;
  `pkgdown::check_pkgdown()` passed with "No problems found";
  targeted Rose stale-wording scans found no remaining outdated
  `traits()` status / RHS-rewrite wording and no remaining over-broad
  phylogenetic pass-through wording.
- Recovery follow-up after Codex stream failure: a targeted parser
  review found that subtractive formula controls such as `-1` were
  being expanded to `-(0 + trait)`. The fix preserves `-1` literally
  while still expanding compact positive RHS terms. `air format
  R/traits-keyword.R tests/testthat/test-traits-keyword.R` completed,
  direct probes returned `-1 + (0 + trait):env_temp` and
  `0 + trait + (0 + trait):env_temp - 1`, and
  `Rscript --vanilla -e 'devtools::test(filter = "traits-keyword|weights-unified")'`
  passed with `FAIL 0 | WARN 0 | SKIP 1 | PASS 71`.
- Full-suite attempt during recovery: `Rscript --vanilla -e
  'devtools::test()'` was run without explicit multi-core settings and
  interrupted after about 14 minutes while still computing
  `phylo-q-decomposition` (`sigma2_Q recovered within 50% relative
  error`). Treat this as incomplete validation, not a pass. Future
  bootstrap- or recovery-heavy reruns should use explicit multi-core
  settings where supported.
- A targeted scan for bootstrap wording found the touched public prose
  still points readers toward Wald or profile intervals where
  appropriate; bootstrap is described as a slower deliberate
  cached check, not the default inferential recommendation.
- Claude review follow-up for PR #39: reverted the scope-expansion
  change that renamed the `extract_correlations()` default. Source,
  focused tests, and generated Rd are back to
  `method = c("fisher-z", "profile", "wald", "bootstrap")`; touched
  vignettes and NEWS again describe `fisher-z` as the default and
  `wald` as the alias. This keeps the compact `traits(...)` RHS pivot
  separate from the extractor-default decision.
- Post-review validation after the default revert:
  `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` completed;
  a direct probe returned default `method` label `fisher-z`;
  `Rscript --vanilla -e 'devtools::test(filter = "fisher-z-correlations|traits-keyword|weights-unified")'`
  passed with `FAIL 0 | WARN 1 | SKIP 1 | PASS 87`; the one warning
  is the restored legacy `tier = "B"` alias warning inside
  `test-fisher-z-correlations.R`, not a default-method failure;
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  passed with "No problems found"; `git diff --check` passed.
- Rose pre-publish terminology gate after the default revert: PASS.
  Source formals, generated Rd, NEWS, and touched vignettes agree that
  `extract_correlations()` defaults to `method = "fisher-z"`; `wald`
  remains an alias or a separate extractor method where explicitly
  requested.
- Post-fast-forward validation after PR #37/#38 landed on `origin/main`:
  `Rscript --vanilla -e 'devtools::test(filter = "fisher-z-correlations|traits-keyword|weights-unified")'`
  passed with `FAIL 0 | WARN 0 | SKIP 1 | PASS 87`;
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  passed with "No problems found"; `git diff --check` passed.

## Tests Of The Tests

`tests/testthat/test-traits-keyword.R` now has a parser-level guard
that checks the compact RHS expansion across ordinary fixed effects,
normal random intercepts, the none/phylo/spatial keyword grid, and the
old explicit long syntax. It also checks that `-1` stays an intercept
control rather than being rewritten as `-(0 + trait)`.
`tests/testthat/test-weights-unified.R` uses the compact wide formula
in the round-trip fit against the manually pivoted long formula.

## Consistency Audit

- The design note and public examples now agree that wide data frames
  use `gllvmTMB(traits(...) ~ compact_rhs, data = df_wide, ...)`.
- The morphometrics article again demonstrates long, formula-wide, and
  matrix-wide fits and checks log-likelihood equality where the model
  is expressible in all forms.

## What Did Not Go Smoothly

The first implementation only rewrote the LHS and therefore fitted the
wrong fixed-effect structure for compact wide formulas: `1` stayed a
single common intercept instead of becoming `0 + trait`, and predictor
terms stayed common slopes. A second pass caught a similar risk for
`phylo_*()` calls, `spatial_*()` calls, and ordinary `(1 | group)`
random intercepts, so the expander now distinguishes fixed effects,
covariance keywords, and random-intercept terms before dispatch.

## Team Learning

- **Ada** kept the patch bounded to the `traits()` rewrite layer: no
  TMB, likelihood, family, or NAMESPACE edits.
- **Pat** benefits from the actual easy wide syntax: a reader with a
  wide data frame writes `traits(...) ~ 1 + x + latent(1 | unit)`.
- **Boole** preserves back-compatibility: explicit long RHS formulas
  through `traits(...)` still pass through unchanged.
- **Rose** caught and classified remaining `traits()` hits so history
  and implementation notes were not confused with live recommendations.
- **Grace** verified the focused tests, generated Rd, morphometrics
  article render, pkgdown reference index, and whitespace check.
- **Shannon** found no open PR overlap before shared rule/design/dev-log
  files were edited; once PR #36 merged, this branch fast-forwarded to
  current `origin/main` and appended its own check-log entry.

## Known Limitations

- `gllvmTMB_wide()` remains the matrix wrapper for the standard
  matrix-first workflow; arbitrary formula-wide structures belong in
  `gllvmTMB(traits(...) ~ ..., data = df_wide, ...)`.
- The full package test suite was attempted during recovery but did
  not complete; focused parser/weight tests and the affected article
  render passed.

## Next Actions

Open the focused PR, watch CI to completion, then continue the
reader-path sequence one article at a time.

For the next maintainer-dispatched item #1 lane ("phylogenetic /
two-U doc-validation branch"), keep "two-U" as the legacy task label
only. Public math and user-facing prose should translate the unique
diagonal component to current `gllvmTMB` notation: `S` / `s`, e.g.
`Sigma = Lambda Lambda^T + S`, `S_phy`, and `S_non`, not legacy
`U`, `U_phy`, or `U_non`.
