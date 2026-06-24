# After Task: Predictor-Informed Latent-Score Runtime Guard

**Branch**: `codex/lv-parser-guard-20260624`
**Date**: `2026-06-24`
**Roles (engaged)**: `Ada / Boole / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Prevent the reserved Design 73 surface `latent(..., lv = ~ x)` from
being silently accepted and ignored before the real parser, TMB,
extractor, and recovery slices exist. The goal was a guard PR, not the
capability implementation.

## 2. Implemented

- Added an early `fit_multi()` guard that aborts when any parsed
  covstruct carries `extra$lv`.
- Added `tests/testthat/test-lv-parser-guard.R`, covering parser
  metadata preservation plus runtime rejection for the default-Psi and
  loadings-only ordinary `latent()` forms.
- Updated the validation register and Design 73-linked status pages so
  `FG-18`, `RE-13`, and `LV-01` remain blocked while recording the
  fail-loud guard evidence.
- Updated the check-log with the exact commands, checks, and stale-scan
  boundaries.

## 3. Files Changed

Implementation:

- `R/fit-multi.R`

Tests:

- `tests/testthat/test-lv-parser-guard.R`

Design and status:

- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`

Dev-log:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-24-lv-parser-guard.md`

## 3a. Decisions and Rejected Alternatives

Decision: abort in `fit_multi()` rather than in the parser.

Rationale: the parser already preserves term-local metadata. Guarding in
the fitter prevents silent model fitting immediately while keeping the
future parser/API implementation free to decide the final storage name
and validation order.

Rejected alternative: remove or drop `lv` during formula rewriting. That
would hide the user's intent and make it harder to distinguish a reserved
surface from a typo.

Decision: leave validation rows blocked.

Rationale: the new evidence proves only that `lv` is not silently
ignored. It does not provide an accepted parser surface, likelihood path,
ADREPORT, extractor, or recovery evidence.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS before shared design/dev-log edits; no open PRs.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> PASS before shared design/dev-log edits; current main was
  `16d92b2 docs: specify predictor-informed latent scores (#555)`.
- `gh run list --repo itchyshin/gllvmTMB --branch main --limit 10 --json databaseId,workflowName,status,conclusion,headSha,createdAt,displayTitle,url`
  -> PASS before PR closeout; R-CMD-check run `28129990711`
  succeeded on `16d92b2`, pkgdown run `28130029193` was still in
  progress, and Power pilot sweep runs `28130468525` / `28125143612`
  were pending/in progress and not used as evidence.
- `gh run watch 28130029193 --repo itchyshin/gllvmTMB --exit-status`
  -> stopped manually after repeated in-progress `Build site` status;
  no failure observed.
- `gh run view 28130029193 --repo itchyshin/gllvmTMB --json status,conclusion,createdAt,updatedAt,url,jobs`
  -> PASS; run remained `in_progress` in `Build site`.
- `air format R/fit-multi.R tests/testthat/test-lv-parser-guard.R`
  -> PASS; no output, but it reformatted legacy `R/fit-multi.R`
  broadly. The formatter churn was restored to `HEAD`, and only the
  guard patch was reapplied.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-lv-parser-guard.R")'`
  -> PASS; 5 pass, 0 fail, 0 warn, 0 skip.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); for (f in c("tests/testthat/test-latent-unique-rename.R", "tests/testthat/test-brms-sugar.R", "tests/testthat/test-ordinary-latent-random-regression.R")) testthat::test_file(f)'`
  -> PASS; `test-latent-unique-rename.R` 6 pass;
  `test-brms-sugar.R` 5 pass with expected once-per-session
  deprecation messages; `test-ordinary-latent-random-regression.R`
  23 pass and 8 expected skips.
- `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); df <- expand.grid(unit = paste0("u", 1:3), trait = paste0("t", 1:2), KEEP.OUT.ATTRS = FALSE); df$value <- rnorm(nrow(df)); df$x <- rep(c(0,1,2), each = 2); tryCatch(gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ x), data = df, unit = "unit", trait = "trait", control = gllvmTMBcontrol(se = FALSE)), error = function(e) { message("ERROR: ", conditionMessage(e)); quit(status = 0) }); quit(status = 1)'`
  -> PASS; aborts with the Design 73 guard and names `FG-18`,
  `RE-13`, and `LV-01`.
- `git diff --check`
  -> PASS.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-24-lv-parser-guard.md`
  -> PASS.

## 5. Tests of the Tests

Failure-before-fix: the probe on `origin/main` fit successfully and
ignored `lv = ~ x`. The new `expect_error()` tests fail on that old
behavior because no error is raised.

Boundary: one test confirms parser metadata remains visible, while the
fit tests confirm the current runtime refuses to use it. This preserves
the future implementation path without advertising support.

Feature combination: the loadings-only `latent(unique = FALSE, lv = ~ x)`
test verifies the guard is tied to `lv` itself, not only to the default
auto-Psi companion.

## 6. Consistency Audit

- `rg -n "latent\\([^\\n]*lv\\s*=|predictor-informed|latent-score mean|B_lv|LV-0[1-7]|FG-18|RE-13|EXT-31" docs R tests/testthat vignettes README.md NEWS.md`
  -> PASS; hits are Design 73, blocked validation rows, the new guard,
  the new guard tests, and prior Design 73 dev-log artifacts.
- `rg -n "no parser|no accepted parser|fail-loud guard|silently ignore|not implemented yet|not live" docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md R/fit-multi.R tests/testthat/test-lv-parser-guard.R`
  -> PASS; current hits distinguish fail-loud guard evidence from
  accepted parser/TMB runtime support.
- `rg -n "REML|AI-REML|Gaussian-only|non-Gaussian.*REML|REML.*non-Gaussian" docs/design/73-predictor-informed-latent-scores.md docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md R/fit-multi.R tests/testthat/test-lv-parser-guard.R`
  -> PASS; hits preserve the Gaussian-only REML boundary and keep
  `REML = TRUE` rejected for the planned `lv` lane.
- `rg -n "Julia|GLLVM\\.jl|parity|engine = \"julia\"|engine = 'julia'" docs/design/73-predictor-informed-latent-scores.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md R/fit-multi.R tests/testthat/test-lv-parser-guard.R`
  -> PASS; hits remain row-backed Julia bridge boundaries and do not
  imply broad `lv` parity.

## 7. Roadmap Tick

N/A. This PR does not promote any row. It records guard evidence on
blocked rows `FG-18`, `RE-13`, and `LV-01`.

## 7a. GitHub Issue Ledger

No issue was closed. No new issue was created because the Design 73
validation rows are the durable ledger for this capability. The related
capability board remains issue #340.

## 8. What Did Not Go Smoothly

The surprise was that current main already preserved `lv = ~ x` in
parser metadata and then continued fitting. That made the narrow guard
more urgent than the larger implementation-map slice.

The stale-wording scan also found a few design/status sentences that
still said "no parser evidence" too broadly. Those were tightened to
say the current state is guard evidence only, with no accepted parser or
TMB model support.

`air format` also reformatted a large legacy R file. That was my own
local churn in the temp worktree, so it was restored before closeout to
keep the PR focused on the guard.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: the best next step was smaller than the original implementation
map. Stop the silent capability leak first, then resume the real parser
and TMB slices.

Boole: term-local `lv` can remain the reserved syntax, but unsupported
term-local arguments must fail loudly when the parser preserves them.

Curie: a negative regression test is useful evidence here. It protects
future implementation work by requiring the guard to be deliberately
moved, not accidentally bypassed.

Fisher: no inference row moved. A guard is not a simulation, coverage,
or accuracy claim.

Grace: no TMB, dependency, roxygen, pkgdown navigation, or platform
surface changed. The targeted tests are enough for this small runtime
guard.

Rose: the status docs now separate "guard exists" from "capability
exists," preventing a future website or bridge note from advertising the
lane early.

Shannon: work stayed in the clean `/private/tmp` worktree and no second
open PR existed before shared-file edits.

## 10. Known Limitations And Next Actions

- `latent(..., lv = ~ x)` still does not fit a predictor-informed
  latent-score model.
- `FG-18`, `RE-13`, `EXT-31`, and `LV-01` through `LV-07` remain
  blocked.
- No `X_lv_B`, `alpha_lv_B`, `B_lv` ADREPORT, `extract_lv_effects()`,
  Gaussian recovery, non-Gaussian support, tier-expanded support,
  structured-source support, or Julia bridge support exists.

Next slices:

1. Real parser/API PR for ordinary Gaussian unit-tier `latent(..., lv = ~ x)`.
2. TMB C1 implementation with `alpha_lv_B` and `B_lv` ADREPORT.
3. Extractor route for trait-scale `B_lv` and ordination components.
4. CRAN-safe rank-1 recovery, then heavy rank-1/rank-2 recovery.
