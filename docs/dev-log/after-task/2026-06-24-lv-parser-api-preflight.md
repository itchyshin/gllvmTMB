# After Task: Predictor-Informed Latent-Score Parser/API Preflight

**Branch**: `codex/lv-parser-api-preflight-20260624`
**Date**: `2026-06-24`
**Roles (engaged)**: `Ada / Boole / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Turn the fail-loud Design 73 `latent(..., lv = ~ x)` reservation into a
typed parser/API preflight for the ordinary Gaussian unit-tier surface,
without wiring the TMB likelihood, ADREPORT, extractors, recovery tests,
non-Gaussian support, structured-source support, or Julia bridge parity.

The slice should let the package validate the future user syntax,
construct the future unit-level `X_lv_B` design matrix, and still abort
before TMB construction so no release can silently treat score
predictors as fitted model terms.

## 2. Implemented

- Added `lv = NULL` to the exported `latent()` marker and regenerated
  `man/latent.Rd`.
- Rewrote ordinary `latent(..., lv = ~ x)` metadata to
  `extra$lv_formula` on the reduced-rank term only; the auto-added
  diagonal `Psi` companion does not receive `lv` metadata.
- Added `R/lv-predictor.R`, a parser/API preflight helper that:
  - allows only one `lv` term;
  - requires ordinary unit-tier Gaussian `latent()`;
  - requires the intercept-only latent block;
  - rejects `REML = TRUE`, non-Gaussian families, unsupported tiers,
    ordinary diagonal aliases, source-specific forms, spatial / animal /
    deprecated aliases, kernel forms, augmented random-regression forms,
    random terms, offsets, `mi()`, smooths, response/trait columns,
    missing columns, exact fixed-effect overlap, nonconstant-within-unit
    predictors, unused unit levels, and rank-deficient designs;
  - normalizes `lv = ~ x` to the no-intercept design equivalent to
    `lv = ~ 0 + x`;
  - builds `X_lv_B` with one row per unit.
- Replaced the coarse runtime guard in `fit_multi()` with this
  validation-and-abort preflight.
- Expanded `tests/testthat/test-lv-parser-guard.R` from a guard test to
  a parser/API preflight suite covering long and `traits(...)` wide
  surfaces, factors, intercept-only rejections, unused unit levels, and
  the unsupported-regime gates.
- Updated Design 73-linked documentation and validation rows while
  keeping `FG-18`, `RE-13`, `EXT-31`, and `LV-01` through `LV-07`
  blocked.
- Added a NEWS development note that explicitly says this is parser/API
  preflight only, not a fitted capability.

## 3a. Decisions and Rejected Alternatives

Decision: keep this as a parser/API preflight that still aborts before
TMB construction.

Rationale: this gives users and future implementers a real validation
contract without implying a likelihood exists. It also protects the next
TMB slice from inheriting ambiguous parser behavior.

Decision: store the user formula as `extra$lv_formula` rather than
leaving `extra$lv` on the reduced-rank term.

Rationale: `lv_formula` is explicit and avoids confusing the reserved
surface with a TMB-ready data field. The future TMB slice can consume the
preflight output deliberately.

Decision: reject `lv = ~ 1` and `lv = ~ 0`.

Rationale: R formula algebra would otherwise turn `~ 0 + 1` into an
intercept column. Design 73 is about predictor-informed latent-score
means, so an intercept-only score mean should not sneak through this
slice.

Rejected alternative: allow source-specific or kernel latent terms to
carry `lv` metadata and let the preflight reject later. The formula
rewriter used to risk dropping metadata on those surfaces, so the safer
API behavior is to reject the unsupported keyword immediately.

## 4. Files Touched

Implementation:

- `R/brms-sugar.R`
- `R/fit-multi.R`
- `R/lv-predictor.R`

Tests:

- `tests/testthat/test-lv-parser-guard.R`

User-facing generated documentation:

- `man/latent.Rd`

Status and design:

- `NEWS.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`

Dev-log:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-24-lv-parser-api-preflight.md`

## 5. Checks Run

- `git status --short --branch && git diff --stat`
  -> PASS after compaction recovery; worktree was dirty only with this
  slice.
- `sed -n '1,220p' docs/dev-log/recovery-checkpoints/2026-06-24-lv-predictor-main-lane-handoff.md`
  -> PASS; confirmed the Design 73 source contract and hard scope.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS before shared-file edits; no open PRs.
- `gh run list --repo itchyshin/gllvmTMB --branch main --limit 10 --json databaseId,workflowName,status,conclusion,headSha,createdAt,displayTitle,url`
  -> PASS; post-#556 R-CMD-check run `28133069989` succeeded on
  `6667a3203a6d46d202ec7ce37be1f4d0f2643898`; pkgdown run
  `28133663663` was still in progress and not used as validation
  evidence; Power pilot sweep runs remained separate and were not used.
- `git log --all --oneline --since='6 hours ago' --decorate`
  -> PASS; no collision detected before shared design/dev-log edits.
- `Rscript --vanilla -e 'devtools::test(filter = "^lv-parser-guard$")'`
  -> PASS; 38 pass, 0 fail, 0 warn, 0 skip.
- `Rscript --vanilla -e 'devtools::test(filter = "^(lv-parser-guard|latent-unique-rename|latent-rank-guard|brms-sugar|formula-grammar-smoke|canonical-keywords|traits-keyword|ordinary-latent-random-regression|kernel-latent-unique-fold|phylo-latent-unique-fold|animal-latent-unique-fold|stage2-rr-diag|mixed-response-sigma)$")'`
  -> PASS; 346 pass, 6 skip, 1 warning. Skips were INLA absent,
  one glmmTMB non-PD Hessian skip, and two heavy recovery/matrix skips.
  The warning was the existing `level = "B"` deprecation path in
  `extract_Omega()`.
- `Rscript --vanilla -e 'devtools::test()'`
  -> PASS before the final unsupported-keyword broadening; 3737 pass,
  747 skip, 10 warnings, 0 fail. Warnings were existing
  numerical/deprecation/Julia-bridge warnings, not new `lv` preflight
  failures. Current-tip coverage after the broadening was checked by
  the focused/expanded suites above and the `devtools::check()` run
  below.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS; regenerated `man/latent.Rd`. Unrelated roxygen2 churn in
  other generated Rd files was restored out of the diff.
- `tail -5 man/latent.Rd; printf 'keyword_count='; grep -c '^\\\\keyword' man/latent.Rd || true`
  -> PASS; tail shows the expected `\\seealso{}` close, and
  `keyword_count=0`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; no problems found.
- `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`
  -> PARTIAL / STOPPED. The render reached and wrote the main
  `articles/gllvmTMB.html` plus several earlier articles, then spent
  about 17 minutes in the later `lambda-constraint.Rmd` article and
  spawned `tools/run-structured-re-q4-location-slope-bootstrap-budget-probe.R`.
  Because that heavy probe is outside this `lv` parser/API slice, the
  article-only gate was interrupted; the orphaned probe process was
  terminated and generated vignette images were removed from the
  worktree.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> WARN; 0 errors, 1 warning, 0 notes. The warning was the local
  Apple clang / R header diagnostic:
  `/Library/Frameworks/R.framework/Resources/include/R_ext/Boolean.h:62:36:
  warning: unknown warning group '-Wfixed-enum-extension', ignored`.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = FALSE, error_on = "never", check_dir = "/private/tmp/gllvmtmb-lv-parser-api-preflight-check")'`
  -> WARN; reproduced the same 0-error / 1-warning / 0-note result and
  preserved logs in
  `/private/tmp/gllvmtmb-lv-parser-api-preflight-check/gllvmTMB.Rcheck`.
- `git diff --check`
  -> PASS.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-24-lv-parser-api-preflight.md`
  -> PASS; no output.

## 6. Tests of the Tests

The expanded `test-lv-parser-guard.R` now fails on the previous coarse
guard implementation because valid parser/API inputs never reach an
`X_lv_B` preflight object. It also fails on the older silent-ignore
behavior because `gllvmTMB(..., lv = ~ x)` would continue to fit instead
of aborting before TMB construction.

The `lv = ~ 1` probe found a real edge case during development:
`model.matrix(~ 0 + 1)` still produces an intercept column. The new
tests lock this down so intercept-only `lv` formulas cannot be mistaken
for predictor-informed score means.

The unused-unit-level test prevents an `NA` first-row lookup from
becoming a hidden row in the future unit-level score-mean design.

## 7a. Issue Ledger

No GitHub issue was closed. No validation row was promoted. This slice
adds evidence to blocked rows `FG-18`, `RE-13`, `LV-01`, and `LV-04`,
but it does not move them because no likelihood, extractor, ADREPORT, or
recovery evidence exists.

No DRAC job, GPU job, broad production simulation, Julia bridge change,
or webpage/published-site update was performed.

## 8. Consistency Audit

- `rg -n "latent\\([^\\n]*lv\\s*=|lv_formula|X_lv_B|predictor-informed|latent-score mean|B_lv|LV-0[1-7]|FG-18|RE-13|EXT-31" docs R tests/testthat NEWS.md man/latent.Rd`
  -> PASS; hits are the intended Design 73 parser/API surface, blocked
  rows, helper code, tests, NEWS, and linked status/design text.
- `rg -n "latent\\([^\\n]*lv\\s*=|lv\\s*=\\s*~|lv_formula|X_lv_B" README.md vignettes R tests docs NEWS.md man/latent.Rd`
  -> PASS; no `README.md` or `vignettes` `lv` examples exist to
  cascade in this slice. Hits are the intended R helper, tests,
  design/dev-log, NEWS, and `man/latent.Rd` surfaces.
- `rg -n "REML|AI-REML|Gaussian-only|non-Gaussian.*REML|REML.*non-Gaussian" docs/design/73-predictor-informed-latent-scores.md docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md R/lv-predictor.R R/fit-multi.R tests/testthat/test-lv-parser-guard.R NEWS.md`
  -> PASS; hits preserve the Gaussian-only REML boundary and keep
  `REML = TRUE` rejected for `lv`.
- `rg -n "Julia|GLLVM\\.jl|parity|engine = \"julia\"|engine = 'julia'" docs/design/73-predictor-informed-latent-scores.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md NEWS.md`
  -> PASS; hits keep the Julia bridge language row-backed and do not
  imply broad `lv` parity.
- `rg -n "No accepted parser|reserved-surface fail-loud guard only|accepted parser|implemented model|TMB construction|ADREPORT|extract_lv_effects|alpha_lv_B" docs/design/73-predictor-informed-latent-scores.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md NEWS.md R/lv-predictor.R R/fit-multi.R tests/testthat/test-lv-parser-guard.R`
  -> PASS after patching `RE-13`; remaining hits correctly say this
  aborts before TMB construction and has no ADREPORT/extractor path yet.

## 9. What Did Not Go Smoothly

Roxygen2 on this machine wanted to rewrite unrelated generated Rd
files (`add_utm_columns`, `extract_correlations`, `gllvmTMB-package`,
`make_mesh`, `phylo_latent`, and `reexports`). Those were restored out
of the diff so the PR only carries the intentional `latent()` help-page
change.

The full article-render gate is expensive because later articles launch
a structured-re bootstrap budget probe. The render did reach the main
public `gllvmTMB` article, but I stopped the full article build at
`lambda-constraint.Rmd` rather than letting an unrelated heavy probe
dominate this capability PR. This is recorded as partial verification,
not a pass.

The extra formula check found that `lv = ~ 1` was not rejected by the
initial helper because R turns `~ 0 + 1` into an intercept column. That
is now explicitly rejected and covered by tests.

The validation register row `RE-13` still said "No accepted parser"
after the first documentation pass. The stale-claim scan caught it and
the row now says parser/API preflight exists while TMB/extractor/recovery
remain absent.

A final code-read found that `phylo_unique(..., lv = ~ x)` could silently
drop the reserved metadata before the preflight saw it. The rewriter now
rejects the broader unsupported keyword family immediately, and the final
focused/expanded test counts include `unique()` and `phylo_unique()`
coverage for that edge.

## 10. Known Residuals

- `latent(..., lv = ~ x)` still does not fit a predictor-informed
  latent-score model.
- `FG-18`, `RE-13`, `EXT-31`, and `LV-01` through `LV-07` remain
  blocked.
- There is no TMB `alpha_lv_B`, no `B_lv` ADREPORT, no
  `extract_lv_effects()`, no score-mean ordination component, no
  Gaussian recovery, no non-Gaussian support, no tier-expanded support,
  no structured-source support, and no Julia bridge support.
- Local `devtools::check()` has one environment/toolchain warning from
  Apple clang ignoring an R header warning group; CI will still run the
  full 3-OS R-CMD-check on the PR.
- Full article rendering is partial only: it reached the main
  `gllvmTMB` article, then was stopped at an unrelated heavy
  `lambda-constraint.Rmd` bootstrap probe. `pkgdown::check_pkgdown()`
  passed, and no generated article/site files are retained in this PR.

## 11. Team Learning

Ada: this was the right middle slice between a bare guard and TMB work:
prove the parser/API contract, but keep the capability blocked.

Boole: the reserved syntax is now concrete enough for user-facing error
messages and future parser work. Unsupported keyword surfaces must reject
before metadata can disappear.

Curie: parser preflight tests should exercise the design matrix, not
only the final abort. The factor, intercept-only, rank-deficient, and
unused-level cases are small but important fixtures.

Fisher: no inference claim moved. Building `X_lv_B` is not evidence for
coverage, bias, power, or recovery.

Grace: local checks covered focused tests, neighboring parser tests,
the full suite, generated help, pkgdown index consistency, and diff
whitespace. No new dependency or compiled-code surface was added.

Rose: the stale-row scan did its job. `RE-13` now matches the actual
state instead of repeating the previous guard-only wording.

Shannon: the work stayed in the clean `/private/tmp` worktree, the
dirty Dropbox checkout was not used for package PR work, and no second
open PR existed before editing shared docs.
