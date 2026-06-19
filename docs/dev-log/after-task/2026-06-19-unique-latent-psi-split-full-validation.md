# After Task: Unique / Ordinary Latent Psi Split Full Validation

**Branch**: `codex/unique-latent-psi-split-20260619`
**Date**: `2026-06-19`
**Roles (engaged)**: `Ada / Boole / Rose / Grace`

## 1. Goal

Repair the remaining full-suite failures in the `unique()` /
ordinary-`latent()` Psi migration split and verify that the lane is locally
green before bridge admission, coevolution, article-placement, or release gates
depend on it.

## 2. Implemented

- The row-weight tests now opt into `latent(..., residual = FALSE)` because
  they test observation-weight dispatch, not the new ordinary `latent()` Psi
  decomposition.
- The mixed-family extractor test now expects ordinary `latent()` to expose a
  positive default Psi diagonal through `extract_Sigma(part = "unique")`
  instead of expecting the old no-Psi subset.
- A follow-up Rose/Rawls split-scope audit found stale convention-cascade text
  after the first validation pass. The repaired text now teaches ordinary
  `latent()` as the default shared-plus-diagonal-Psi decomposition in the README
  first-click examples, the canonical vision examples, and the communality help.
  The covariance/correlation article now says `no-residual latent fit` for the
  explicit `residual = FALSE` comparison instead of using the ambiguous
  `latent-only` shorthand.

## 3. Files Changed

Files touched in this closeout slice:

- `tests/testthat/test-lme4-style-weights.R`
- `tests/testthat/test-mixed-family-extractor.R`
- `README.md`
- `docs/design/00-vision.md`
- `R/extractors.R`
- `man/extract_communality.Rd`
- `vignettes/articles/covariance-correlation.Rmd`
- `docs/design/04-random-effects.md`

Inherited files in this split lane remain part of the broader API/convention
cascade. The follow-up audit specifically closed the stale README, canonical
vision, communality roxygen/Rd, and covariance/correlation article blockers
found after the first validation pass.

The final split-lane cascade also touched the ordinary-latent/Psi wording in
the extractor reference docs, generated Rd files, design notes, and rendered
article sources. The changed article/example files are:

- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/behavioural-syndromes.Rmd`
- `vignettes/articles/choose-your-model.Rmd`
- `vignettes/articles/convergence-start-values.Rmd`
- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/cross-package-validation.Rmd`
- `vignettes/articles/data-shape-flowchart.Rmd`
- `vignettes/articles/fit-diagnostics.Rmd`
- `vignettes/articles/functional-biogeography.Rmd`
- `vignettes/articles/joint-sdm.Rmd`
- `vignettes/articles/mixed-family-extractors.Rmd`
- `vignettes/articles/model-selection-latent-rank.Rmd`
- `vignettes/articles/morphometrics.Rmd`
- `vignettes/articles/phylogenetic-gllvm.Rmd`
- `vignettes/articles/pitfalls.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `vignettes/articles/psychometrics-irt.Rmd`
- `vignettes/articles/random-regression-reaction-norms.Rmd`
- `vignettes/articles/random-slopes-nongaussian.Rmd`
- `vignettes/articles/response-families.Rmd`
- `vignettes/articles/simulation-recovery-validated.Rmd`
- `vignettes/articles/simulation-verification.Rmd`
- `vignettes/articles/stacked-trait-gllvm.Rmd`

## 3a. Decisions and Rejected Alternatives

Decision: use `latent(..., residual = FALSE)` in the weight fixture.

Rationale: the test file is about lme4/glmmTMB-style row weights. Ordinary
`latent()` now carries a default diagonal Psi companion, which can absorb the
signal the old fixture used to detect weight effects on fixed-effect SEs and
Gaussian residual scale.

Rejected alternative: relax the SE and sigma expectations. That would keep the
test passing but weaken the row-weight contract.

Decision: update the mixed-family extractor expectation to positive finite Psi.

Rationale: ordinary `latent()` now owns the diagonal Psi term by default. A
zero-Psi expectation would test the old no-residual subset while fitting the new
ordinary model.

## 4. Checks Run

- `Rscript --vanilla -e 'devtools::test(filter = "lme4-style-weights|mixed-family-extractor", reporter = "summary")'`
  -> before edits reproduced four failures: two SE-shrink failures, one
  heteroscedastic sigma-recovery failure, and one stale zero-Psi mixed-family
  extractor expectation.
- `Rscript --vanilla -e 'devtools::test(filter = "lme4-style-weights|mixed-family-extractor", reporter = "summary")'`
  -> after edits completed with `DONE`, exit code 0.
- `Rscript --vanilla -e 'devtools::test(filter = "unique-family-deprecation|canonical-keywords|ordinary-latent-random-regression|brms-sugar|gllvmTMB-wide|keyword-grid|stage2-rr-diag|stage3-propto-equalto|stage33-non-gaussian|phase56-3-phylo-unique-parser|sigma-rename|extract-sigma|example-covariance-edge-cases|family-gamma|gllvmTMB-diagnose|joint-sdm-binary-long-wide|julia-bridge|lme4-style-weights|mixed-family-extractor", reporter = "summary")'`
  -> completed with `DONE`, exit code 0; expected INLA, heavy, and live-Julia
  skips remained.
- `Rscript --vanilla -e 'devtools::test(reporter = "summary")'`
  -> completed with `DONE`, exit code 0. The prior full-suite failures were
  gone; remaining warning output was from existing compatibility/deprecation and
  diagnostic paths.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" PATH="$HOME/.juliaup/bin:$PATH" Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed with `DONE`, exit code 0; JuliaCall activated the integration
  project and exited cleanly.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE, error_on = "never")'`
  -> `0 errors | 1 warning | 0 notes`.
- `rg -n "WARNING|Status:|fixed-enum|R_ext/Boolean|unknown warning group" /private/tmp/gllvmTMB-rcmdcheck/gllvmTMB.Rcheck/00check.log /private/tmp/gllvmTMB-rcmdcheck/gllvmTMB.Rcheck/00install.out`
  -> the lone warning was the known Apple clang / R header warning:
  `R_ext/Boolean.h:62:36: warning: unknown warning group '-Wfixed-enum-extension', ignored`.
- `git diff --check`
  -> clean after edits.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated documentation after the communality roxygen wording repair.
- `Rscript --vanilla -e 'devtools::test(filter = "extractors|extract-sigma|unique-family-deprecation|canonical-keywords|gllvmTMB-wide|ordinary-latent-random-regression", reporter = "summary")'`
  -> completed with `DONE`, exit code 0. Expected heavy/INLA skips remained;
  compatibility `unique()` fixtures emitted the intended lifecycle warnings.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/covariance-correlation", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> rendered `pkgdown-site/articles/covariance-correlation.html`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- Stale wording scan:
  ```sh
  rg -n 'compute them from a latent-only fit|no `unique\(\)`|no unique|latent\(\) but \*\*no\*\* `unique|refit with `\+ unique|Psi` \| `unique|latent\(1 \| individual, d = 1\) \+|latent\(0 \+ trait \| individual, d = 1\) \+' README.md docs/design/00-vision.md R/extractors.R man/extract_communality.Rd vignettes/articles/covariance-correlation.Rmd
  ```
  -> no matches, but this scan was incomplete: it did not catch multiline
  `latent(...) + unique(...)` examples in touched roxygen blocks.
- Cicero / Rose pre-publish audit:
  -> `FAIL`; the audit found stale `latent(...) + unique(...)` examples in
  `extract_communality()` and `extract_ordination()`, plus a `00-vision.md`
  headline that still named `latent() + unique()` as the core reduced-rank
  decomposition.
- Multiline stale-example scan added after Cicero's audit:
  ```sh
  rg -n -U "latent\\([^\\n]*\\)\\s*\\+\\s*\\n\\s*(#'\\s*)?unique\\(" R man README.md NEWS.md docs/design vignettes
  ```
  -> used as the follow-up guard for multiline roxygen/Rd/article examples.
- Follow-up repair:
  - `R/extractors.R`: `extract_communality()` and `extract_ordination()`
    examples now use ordinary `latent(...)` without explicit `+ unique(...)`;
    communality parameter text now says `link_residual = "none"` returns the
    fitted latent covariance scale.
  - `docs/design/00-vision.md`: the headline capability now names ordinary
    `latent()` as **Σ = ΛΛᵀ + Ψ** by default, with explicit `latent() +
    unique()` only as compatibility wording later in the document.
  - `man/extract_communality.Rd` and `man/extract_ordination.Rd`: regenerated
    by `devtools::document(quiet = TRUE)`.
- `git diff --check`
  -> clean after the convention-cascade follow-up.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (article in c("api-keyword-grid", "behavioural-syndromes", "choose-your-model", "convergence-start-values", "covariance-correlation", "cross-package-validation", "data-shape-flowchart", "fit-diagnostics", "functional-biogeography", "joint-sdm", "mixed-family-extractors", "model-selection-latent-rank", "morphometrics", "phylogenetic-gllvm", "pitfalls", "profile-likelihood-ci", "psychometrics-irt", "random-regression-reaction-norms", "random-slopes-nongaussian", "response-families", "simulation-recovery-validated", "simulation-verification", "stacked-trait-gllvm")) pkgdown::build_article(paste0("articles/", article), pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  -> all 23 touched article pages rendered to `pkgdown-site/articles/*.html`
  with exit code 0.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- Final multiline stale-example scan:
  ```sh
  rg -n -U "latent\\([^\\n]*\\)\\s*\\+\\s*\\n\\s*(#'\\s*)?unique\\(" R man README.md NEWS.md docs/design vignettes
  ```
  -> remaining hits are intentionally scoped: the non-Gaussian augmented
  random-regression boundary example in `random-regression-reaction-norms.Rmd`,
  the compatibility example in `R/brms-sugar.R`, and the generated
  compatibility example in `man/unique_keyword.Rd`.
- Final prose stale-wording scan:
  ```sh
  rg -n 'latent\(\) \+ unique|latent \+ unique|`latent\(\) \+ unique\(\)`|`latent \+ unique`|latent\(.*\) \+ unique|canonical .*latent.*unique|When in doubt, start with `latent\(\) \+ unique|no `unique\(\)` means zero Psi|zero-Psi|unique-only|unique\(\)-only|no-unique' README.md NEWS.md docs/design R vignettes/articles
  ```
  -> remaining hits are compatibility or historical validation rows/comments,
  after replacing the stale current-design phrase `unique-only diagonal
  extraction` in `docs/design/04-random-effects.md` with
  `diagonal-compatibility extraction`.
- Local rendered-image check:
  ```sh
  python3 - <<'PY'
  # Parsed the 23 rendered HTML files and checked local <img src> targets.
  PY
  ```
  -> checked 51 local image targets across 23 rendered articles; missing or
  empty targets: 0.
- `git diff --check`
  -> clean after the final design-wording repair and after-task update.

## 5. Tests of the Tests

The failure-before-fix evidence showed that the two repaired files were the
remaining full-suite blockers. The repaired focused run and the full
`devtools::test()` run both completed with exit code 0, so the changed
expectations are exercised in isolation and in the macro suite.

## 6. Consistency Audit

- `rg -n "zero-Psi|no-unique\\(\\) fit|structurally zero|latent\\(0 \\+ trait \\| site, d = 1\\)(,|\\))" tests/testthat/test-lme4-style-weights.R tests/testthat/test-mixed-family-extractor.R`
  -> no matches. The repaired test files no longer contain the stale zero-Psi/no
  residual-implicit wording or unqualified weight-test latent formula.
- The first follow-up stale wording scan listed in Section 4 returned no
  matches in the README first-click examples, canonical vision examples,
  communality roxygen/Rd, or covariance/correlation article phrase that
  previously triggered the split-scope audit failure, but Cicero / Rose found
  that this was too narrow because it missed multiline examples.
- The second follow-up adds the multiline scan and repairs the two stale
  roxygen examples and generated Rd pages named by Cicero.
- The broad article render sweep is the integration check for the convention
  cascade because this change touches formula examples and reader-facing syntax
  across articles. It rendered all 23 touched article pages successfully.
- Final stale scans leave only compatibility syntax, historical validation-row
  evidence, and the intentionally failing non-Gaussian augmented-`unique()`
  boundary example.

## 7. Roadmap Tick

N/A. This was a split-lane validation repair, not a roadmap row movement.

## 7a. GitHub Issue Ledger

No issue was closed or created. The relevant public issue/PR state remains
unchanged: draft PR #489 is still the broader bridge PR, and this split worktree
has not been pushed.

## 8. What Did Not Go Smoothly

The original full-suite failure was not a new engine break. It was stale test
intent after the ordinary `latent()` Psi default changed. The row-weight fixture
needed an explicit no-residual model to keep the row-weight signal identifiable.

The first split closeout under-scoped the convention-change cascade: it proved
the repaired tests and macro validation, but did not enumerate or scan the
README, canonical vision, communality help, and article wording that still
looked like the old `latent() + unique()` teaching path. The follow-up audit
closed those concrete blockers before this lane could be treated as locally
reviewable.

The first generated-HTML link parser was too broad for this split worktree: it
treated unbuilt reference, index, news, and untargeted article pages as missing
links even though this lane rendered only the touched articles and
`pkgdown::check_pkgdown()` validated the site structure. The corrected local
asset check was limited to rendered article image targets and passed.

## 9. Team Learning

Ada: keep this as the first split lane because downstream bridge/article work
should teach the stable covariance grammar.

Boole: tests that need the old reduced-rank subset must now say
`residual = FALSE` explicitly.

Rose: stale “no `unique()` means zero Psi” language is an overclaim after the
ordinary latent-Psi fold.

Grace: the local R, pkgdown, R CMD check, and live Julia-via-R evidence now pass
for this split lane; the R CMD check warning is external compiler-header noise.

## 10. Known Limitations And Next Actions

This does not remove `unique()` or escalate lifecycle policy. Source-specific
and kernel latent-Psi folds remain future slices unless separately tested.

Next action: keep the split discipline. Use this Psi/API lane evidence before
moving on to bridge admission, fixed-rho coevolution engine review, or public
article placement.
