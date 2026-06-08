# After Task: Behavioural Reaction-Norm Article

**Branch**: `codex/status-random-regression-article-2026-06-08`
**Date**: `2026-06-08`
**Roles (engaged)**: `Ada / Pat / Rose / Fisher / Florence / Grace / Curie`

## 1. Goal

Make the random-regression / reaction-norm article public-ready after the
Gaussian ordinary `latent + unique` random-slope engine landed. The article
needed a normal behavioural-syndrome example, not deprecated `phylo_slope()` /
`animal_slope()` syntax or structured dependence as a substitute.

## 2. Implemented

- Added a reproducible behavioural reaction-norm example object:
  `inst/extdata/examples/behavioural-reaction-norm-example.rds`.
- Added its generator:
  `data-raw/examples/make-behavioural-reaction-norm-example.R`.
- Added a fixture gate:
  `tests/testthat/test-example-behavioural-reaction-norm.R`.
- Rewrote `vignettes/articles/random-regression-reaction-norms.Rmd` as a
  Tier-1 public worked example with:
  - `individual` as the unit;
  - `session_id` as the repeated occasion / `unit_obs`;
  - long and wide `gllvmTMB()` paths;
  - `check_gllvmTMB()` diagnostics;
  - augmented covariance extraction through `level = "unit_slope"`;
  - fitted-vs-truth recovery figure;
  - repeatability curves across temperature;
  - explicit non-Gaussian augmented-`unique()` guard wording.
- Promoted the article into `_pkgdown.yml` Model guide navigation.
- Updated README, NEWS, ROADMAP, capability status, article gate matrix, and
  the example-object contract so the public surface no longer says this
  article is internal.

## 3. Files Changed

Example fixture:

- `data-raw/examples/make-behavioural-reaction-norm-example.R`
- `inst/extdata/examples/behavioural-reaction-norm-example.rds`
- `tests/testthat/test-example-behavioural-reaction-norm.R`

Public article and navigation:

- `vignettes/articles/random-regression-reaction-norms.Rmd`
- `_pkgdown.yml`

Status and prose cascade:

- `README.md`
- `NEWS.md`
- `ROADMAP.md`
- `docs/design/52-example-object-contract.md`
- `docs/design/61-capability-status.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-08-behavioural-reaction-norm-article.md`

## 3a. Decisions and Rejected Alternatives

Decision: use a Gaussian behavioural-syndrome fixture with `boldness`,
`exploration`, and `activity`, with `temperature` as the within-individual
reaction-norm covariate.

Rationale: this matches the animal personality / reaction-norm framing and
keeps the example focused on individual-level random slopes.

Rejected alternative: using `phylo_slope()`, `animal_slope()`, or structured
phylogenetic/spatial syntax. Those are legacy or different model classes and
would blur the ordinary individual-level RE-12 claim.

Decision: keep the occasion tier as `latent(1 | session_id, d = 1)` without
adding augmented session-level slopes.

Rationale: the scientific target is individual intercept/slope covariance; the
occasion tier supplies repeated-session structure without overloading the first
public article.

Decision: use article-local plotting data for `unit_slope` recovery.

Rationale: `extract_Sigma_table()` does not yet support `level = "unit_slope"`;
expanding that exported helper would be a separate API slice.

## 4. Checks Run

- `Rscript data-raw/examples/make-behavioural-reaction-norm-example.R`
  -> saved `inst/extdata/examples/behavioural-reaction-norm-example.rds`
  (`30499` bytes).
- `env NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-example-behavioural-reaction-norm.R")'`
  -> `FAIL 0`, `WARN 0`, `SKIP 0`, `PASS 40`.
- `env NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-ordinary-latent-random-regression.R")'`
  -> `FAIL 0`, `WARN 0`, `SKIP 0`, `PASS 60`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/random-regression-reaction-norms", quiet = FALSE, new_process = FALSE)'`
  -> rendered `pkgdown-site/articles/random-regression-reaction-norms.html`.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `env NOT_CRAN=true Rscript --vanilla -e 'devtools::test()'`
  -> `FAIL 0`, `WARN 0`, `SKIP 704`, `PASS 2652`, duration `334.7s`.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> `0 errors`, `1 warning`, `1 note`, exit status `1` because warnings fail
  the check. This matches the known local pattern: package-install warning and
  existing `NEWS.md` section-title parsing note.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

The new test is prophylactic and checks the article fixture against the public
example-object contract. It verifies object fields, long/wide repeated-measure
shapes, long/wide likelihood equivalence, optimizer and gradient health,
augmented covariance composition, recovery against known truth, and ggplot
build readiness.

It does not test non-Gaussian augmented `unique()` because that is deliberately
guarded outside this slice and already covered by
`tests/testthat/test-ordinary-latent-random-regression.R`.

## 6. Consistency Audit

- `rg -n -F 'x \\|' ...`
  -> no escaped-pipe article / rendered HTML hits.
- `rg -n -F ' \\|' ...`
  -> no escaped-pipe article / rendered HTML hits.
- `rg -n "kept internal|keep internal|public return still needs|public runnable example object still pending|public biological example/diagnostics/figures still pending|still needs a polished reader-facing|structured dependence as a stand-in|Polish the Gaussian worked example" ...`
  -> one unrelated hit for `mixed-family-extractors`, which still intentionally
  remains internal.
- `rg -n "fire|fire animal|phylo_slope\\(|animal_slope\\(" ...`
  -> no hits in the new article or rendered article HTML; expected legacy /
  reference hits remain elsewhere.
- Rose pre-publish audit:
  PASS after patching stale `docs/design/61-capability-status.md` wording.
- Figure-quality gate:
  PASS after changing repeatability y-axis to the full `0..1` scale.

## 7. Roadmap Tick

`ROADMAP.md` now marks `random-regression-reaction-norms` as promoted to the
public Model guide after #466, with the Gaussian article complete and
non-Gaussian augmented `unique()` remaining guarded.

## 7a. GitHub Issue Ledger

- PR #466 exists for this branch:
  `https://github.com/itchyshin/gllvmTMB/pull/466`.
- Relevant tracking issues remain #340 (capability status board) and #347
  (article completion / public learning path).
- No issue comments were posted from this local slice; the PR branch and
  after-task report carry the evidence.

## 8. What Did Not Go Smoothly

- The in-app browser controller was not exposed by `tool_search` in this
  session, so rendered-output verification used HTML scans and direct PNG
  inspection rather than in-app browser navigation.
- The first repeatability figure auto-zoomed its y-axis. Florence gate caught
  that; the article now fixes the y-axis to `0..1`.
- `devtools::check()` remains blocked by the known local warning / NEWS note
  pattern even though it reports `0 errors`.

## 9. Team Learning

Ada: Keep the article and capability boundary together. This slice is public
only because the Gaussian example object, test, article, and status docs moved
in lockstep.

Pat: The reader path now starts from individual/session behavioural data and
shows long plus wide calls before interpretation.

Rose: The stale-wording scan caught an internal-status sentence in
`docs/design/61-capability-status.md` after the obvious README/NEWS/ROADMAP
updates were already patched.

Fisher: The article frames recovery and repeatability as point-estimate
diagnostics, not calibrated uncertainty.

Florence: Repeatability is a bounded `0..1` quantity; the final figure uses
that full scale.

Grace: `pkgdown::check_pkgdown()` and article rendering passed; full tests
passed; package check still has the known local warning / NEWS note pattern.

Curie: The new fixture test guards long/wide likelihood equivalence and
truth recovery, so the article object is not just prose.

## 10. Known Limitations And Next Actions

- Non-Gaussian augmented `unique(1 + x | unit)` remains guarded.
- Non-Gaussian ordinary augmented `latent()` random slopes remain smoke-level
  evidence only.
- `extract_Sigma_table()` does not yet support `level = "unit_slope"`; the
  article uses `extract_Sigma()` plus article-local comparison rows.
- Delta / hurdle / two-stage families remain outside this slope-covariance
  lane.
- The next capability slice, if wanted, is a separate admission grid for
  non-Gaussian ordinary augmented `unique()` random slopes.
