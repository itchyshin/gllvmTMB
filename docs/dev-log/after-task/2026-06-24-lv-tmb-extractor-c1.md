# After Task: Predictor-Informed Latent-Score C1 TMB And Extractors

**Branch**: `codex/lv-tmb-plumbing-20260624`
**Date**: `2026-06-24`
**Roles (engaged)**: `Ada / Boole / Gauss / Noether / Curie / Fisher / Emmy / Grace / Rose / Shannon`

## 1. Goal

Move Design 73 from parser/API preflight to the smallest fitted C1
capability: ordinary Gaussian unit-tier `latent(..., lv = ~ x)` with
TMB score-mean plumbing, point extractors, and row-backed partial status.

This slice must not claim Gaussian recovery, intervals, non-Gaussian
support, tier/source expansion, DRAC evidence, GPU work, or Julia parity.

## 2. Implemented

- Added TMB data/parameter plumbing for `use_lv_B`, `n_lv_B`,
  `X_lv_B`, and `alpha_lv_B`.
- Preserved the zero-mean innovation prior and changed only the
  B-tier score contribution to use `X_lv_B alpha_lv_B + z_B` when
  `lv` is active.
- Reported `alpha_lv_B`, `U_lv_mean_B`, `U_B_total`, and `B_lv_unit`;
  `B_lv_unit` is ADREPORTed for later uncertainty work, but uncertainty
  is not calibrated in this slice.
- Routed the R-side `fit_multi()` preflight output into TMB data,
  parameters, maps, fit metadata, and `fit$lv`.
- Extended `extract_ordination()` with
  `component = c("total", "innovation", "mean")` while preserving the
  existing return names `scores`, `loadings`, and `row_id`.
- Added exported `extract_lv_effects()`:
  - `type = "trait_effect"` returns point-estimate rows for
    `B_lv = Lambda alpha^T`;
  - `type = "axis_effect"` returns raw `alpha` with
    `rotation_status = "axis_scale_rotation_dependent"`;
  - `std.error` remains `NA` with
    `uncertainty_status = "point_estimate_only_no_ci_validation"`.
- Expanded `test-lv-parser-guard.R` from parser preflight to small
  long/wide Gaussian C1 fit smoke, report-shape checks, score
  decomposition checks, extractor algebra checks, and unsupported-level
  / no-`lv` extractor errors.
- Added a deterministic ordinary-default `latent(..., lv = ~ x)` smoke
  so the C1 path is covered both with the default Psi companion
  (`use_diag_B = TRUE`) and the explicit loadings-only
  `unique = FALSE` subset.
- Updated `NEWS.md`, `_pkgdown.yml`, generated Rd, and Design
  01/03/04/06/35/61/73 so the package now says "C1 partial" instead of
  "planned / blocked".

## 3a. Decisions and Rejected Alternatives

Decision: return `B_lv = Lambda alpha^T` as the preferred public table.

Rationale: `B_lv` is on the trait linear-predictor scale and is the
rotation-stable quantity Design 73 names as the primary estimand. Raw
`alpha` remains available only as `type = "axis_effect"` with explicit
rotation-dependent metadata.

Decision: keep the old `extract_ordination()` return shape.

Rationale: adding a `component` list element broke existing exact-name
tests in `test-extractors.R` and `test-extractors-extra.R`. The
component argument now changes the returned `scores` matrix without
adding a new top-level element.

Decision: mark `FG-18`, `RE-13`, `EXT-31`, `LV-01`, and `LV-04` as
`partial`, not `covered`.

Rationale: this is smoke/algebra evidence. It proves a small Gaussian
fit can reach TMB and extractors, not that `B_lv`, `Sigma`, `Psi`,
standard errors, or intervals recover across a simulation design.

Rejected alternative: fit factor-predictor runtime recovery in this PR.
The parser/TMB path accepts the resulting column count, but a factor
runtime/recovery cell belongs with the next recovery tranche rather than
this TMB plumbing PR.

## 4. Files Touched

Implementation:

- `src/gllvmTMB.cpp`
- `R/fit-multi.R`
- `R/lv-predictor.R`
- `R/extractors.R`
- `NAMESPACE`

Tests:

- `tests/testthat/test-lv-parser-guard.R`

Generated/reference docs:

- `man/extract_ordination.Rd`
- `man/extract_lv_effects.Rd`
- `_pkgdown.yml`

Status and design:

- `NEWS.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/04-random-effects.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`

Dev-log:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-24-lv-tmb-extractor-c1.md`

## 5. Checks Run

- `git status --short --branch`
  -> PASS; active worktree is
  `/private/tmp/gllvmtmb-lv-tmb-plumbing-20260624` on
  `codex/lv-tmb-plumbing-20260624`.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS; no open PRs before this PR.
- `gh run view 28137682170 --repo itchyshin/gllvmTMB --json databaseId,workflowName,status,conclusion,headSha,createdAt,updatedAt,url`
  -> PASS; post-#557 main R-CMD-check completed `success`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS; regenerated `NAMESPACE`, `man/extract_ordination.Rd`, and
  `man/extract_lv_effects.Rd`.
- `air format R/extractors.R R/lv-predictor.R tests/testthat/test-lv-parser-guard.R`
  -> PASS; no output.
- `Rscript --vanilla -e 'devtools::test(filter = "^lv-parser-guard$")'`
  -> PASS after the compatibility/default-Psi patch; 113 pass, 0 fail,
  0 warn, 0 skip.
- `Rscript --vanilla -e 'devtools::test(filter = "^(extractors|extractors-extra|rotate-compare-loadings|julia-bridge)$")'`
  -> PASS; 535 pass, 16 skip, 1 warning, 0 fail. The skips were
  expected local `GLLVM.jl` path skips. The warning was the existing
  Julia bridge ordinary-`latent()` Psi advisory.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; no problems found.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = FALSE, error_on = "never", check_dir = "/private/tmp/gllvmtmb-lv-tmb-plumbing-check")'`
  -> WARN; 0 errors, 1 warning, 0 notes. The warning was the known
  local Apple clang/R header diagnostic
  `unknown warning group '-Wfixed-enum-extension'`; testthat inside
  R CMD check was OK (`[131s/149s]`).
- `git diff --check`
  -> PASS.

## 6. Tests of the Tests

The focused LV suite exercises both acceptance and rejection:

- acceptance: ordinary Gaussian long and `traits(...)` wide
  `latent(..., lv = ~ x)` fits reach TMB, produce finite reports, and
  satisfy `total = innovation + mean`;
- feature combination: the wide `traits(...)` surface and
  loadings-only subset (`unique = FALSE`) both run through the C1 path;
- ordinary-default path: `latent(..., lv = ~ x)` keeps its Psi
  companion (`use_diag_B = TRUE`) while preserving
  `U_B_total = U_lv_mean_B + z_B`;
- boundary/rejection: malformed formulas, unsupported tiers/sources,
  non-Gaussian families, `REML = TRUE`, fixed/LV overlap, and
  extractor calls on unsupported levels or no-`lv` fits still error.

The neighbor suite initially failed because `extract_ordination()` grew
a new top-level `component` element. That failure proved the tests still
guard backward-compatible extractor shape. The implementation was
changed to preserve the old list names.

## 7a. Issue Ledger

- `gh issue list --repo itchyshin/gllvmTMB --state open --search "latent lv OR predictor-informed OR latent-score" --json number,title,state,url,updatedAt --limit 20`
  -> REVIEWED. No dedicated Design 73 issue exists. Broad related
  issues are #340 capability board, #346 simulation/coverage framework,
  and #349 power-simulation capstone.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "Design 73 OR LV-01 OR LV-02 OR extract_lv_effects" --json number,title,state,url,updatedAt --limit 20`
  -> REVIEWED. Same broad issues only.

No issue was closed. No new issue was created. The PR should mention
the next recovery slice (`LV-02`) rather than closing a roadmap issue.

## 8. Consistency Audit

- `rg -n "latent\\([^\\n]*lv\\s*=|lv\\s*=\\s*~|predictor-informed|latent-score|B_lv|LV-0[1-7]|FG-18|RE-13|EXT-31" README.md ROADMAP.md docs/dev-log/known-limitations.md docs/design NEWS.md vignettes _pkgdown.yml R tests/testthat man/extract_ordination.Rd man/extract_lv_effects.Rd`
  -> PASS; hits are the intended C1 partial story, blocked follow-up
  rows, implementation, tests, and generated help. No README/vignette
  example was added.
- `rg -n "planned / blocked|blocked / planned|no parser|no TMB runtime|no runtime claim|before TMB construction|aborts before TMB|planned first implementation|future unit-level|not implemented yet|no exported function|no implemented likelihood" docs/design/01-formula-grammar.md docs/design/03-likelihoods.md docs/design/04-random-effects.md docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md NEWS.md R/lv-predictor.R R/fit-multi.R`
  -> PASS; remaining hits are historical Design 73 implementation-stage
  wording and the fit preflight comment for unsupported regimes.
- `rg -n "REML|AI-REML|Gaussian-only|non-Gaussian.*REML|REML.*non-Gaussian" docs/design/73-predictor-informed-latent-scores.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md NEWS.md R/lv-predictor.R R/fit-multi.R tests/testthat/test-lv-parser-guard.R`
  -> PASS; `REML = TRUE` remains rejected for `lv`, and non-Gaussian
  REML wording stays guarded.
- `rg -n "Julia|GLLVM\\.jl|parity|engine = \\\"julia\\\"|engine = 'julia'" docs/design/73-predictor-informed-latent-scores.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md NEWS.md R/extractors.R`
  -> PASS; Julia language remains row-backed and does not claim `lv`
  parity.
- `rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design | head -n 80`
  -> PASS/manual spot-check; no new long-format user example was added
  without `trait =`.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S|meta_known_V|gllvmTMB_wide|full.*rejected|only diagonal|planned.*implemented|No accepted parser|reserved-surface fail-loud guard only" README.md ROADMAP.md NEWS.md docs vignettes R tests/testthat`
  -> REVIEWED; hits are known compatibility/historical/dev-log mentions
  or unrelated existing aliases, not new `lv` overclaims in touched
  user-facing files.

## 9. What Did Not Go Smoothly

Roxygen2 repeatedly refreshed unrelated Rd files
(`add_utm_columns`, `extract_correlations`, `gllvmTMB-package`,
`make_mesh`, `phylo_latent`, and `reexports`). Those generated-only
changes were restored out of the diff after `devtools::document()` and
again after `devtools::check()`.

The first extractor implementation added `component` as a new list
element from `extract_ordination()`. Existing exact-name tests caught
that as a backward-compatibility regression, so the function now keeps
the prior list shape.

The status-inventory scan found stale Design 01/03/04/06 text still
saying the `lv` surface was planned or stopped before TMB. Those docs
were patched in this slice instead of leaving the update to a later docs
pass.

## 10. Known Residuals

- `FG-18`, `RE-13`, `EXT-31`, `LV-01`, and `LV-04` are `partial`, not
  `covered`.
- `LV-02` Gaussian recovery of `B_lv`, `Sigma`, and `Psi` remains
  blocked.
- Missing-response compatibility (`LV-03`), non-Gaussian support
  (`LV-05`), tier-expanded support (`LV-06`), structured-source support
  (`LV-07`), and Julia parity remain blocked/planned.
- `extract_lv_effects()` returns `std.error = NA`; interval and
  ADREPORT uncertainty calibration are not admitted.
- Factor `lv` predictors have parser/rank checks and TMB column-count
  support but not a runtime/recovery smoke cell yet.
- Local `devtools::check()` still has the known Apple clang warning; CI
  remains the 3-OS gate after the PR opens.
- No full article rebuild was run in this slice; no public README or
  vignette example was added.

## 11. Team Learning

Ada kept the slice narrow: fitted C1 + point extractors, then stop
before recovery and docs article work.

Boole's parser/API boundary remains useful: only ordinary Gaussian
unit-tier `latent()` can carry `lv`; unsupported tiers and sources still
fail loudly.

Gauss and Noether aligned the math and C++ path: the innovation prior
stays centred, `X_lv_B alpha_lv_B` shifts the score mean, and the
ordinary `Psi` companion is unchanged.

Curie's tests now cover acceptance, algebra, and rejection. The
neighbor extractor tests caught the return-shape regression that the
new happy path alone would have missed. A late TMB-review pass also
added the default-Psi ordinary `latent()` smoke so the NEWS claim that
the Psi companion is preserved has direct test coverage.

Fisher's boundary is the next tranche: smoke/algebra is not recovery.
The pass/fail target must be `B_lv`, `Sigma`, and `Psi`, not raw
rotation-dependent `alpha`.

Emmy's extractor lesson is to preserve existing list contracts when
adding a selector argument. New information can be exposed through the
selected matrix/table, not by changing legacy names.

Grace confirmed the local gates: pkgdown passed and R CMD check had only
the known local Apple clang warning.

Rose caught the stale design-doc story. Design 01/03/04/06 needed the
same row-backed update as NEWS and the validation register.

Shannon confirmed one active worktree/branch and no open PR before this
slice; the dirty Dropbox mission-control checkout was not used.
