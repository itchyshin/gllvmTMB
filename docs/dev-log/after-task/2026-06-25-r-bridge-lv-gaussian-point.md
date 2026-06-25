# After Task: R bridge Gaussian predictor-informed latent-score route

**Branch**: `codex/lv-julia-bridge-20260625`
**Date**: `2026-06-25`
**Roles (engaged)**: Ada, Boole, Emmy, Grace, Curie, Fisher, Rose, Shannon

## 1. Goal

Admit the first R-to-Julia bridge route for Design 73
`latent(..., lv = ~ x)` without widening the scientific claim. The target was
complete-response ordinary Gaussian point fits only: no fixed-effect `X`, no
response mask, no CIs, and no binary/non-Gaussian or broad native-vs-Julia
parity claim.

## 2. Implemented

- `gllvm_julia_fit()` now accepts an `X_lv` matrix and passes it to
  `GLLVM.bridge_fit(X_lv = ...)` for Gaussian rows only.
- `gllvmTMB(..., engine = "julia")` builds the unit-level `X_lv` matrix from
  the existing Design 73 parser setup for admitted Gaussian bridge rows.
- New bridge gates reject non-Gaussian/binary `X_lv`, `X_lv` CIs, response
  masks with `X_lv`, and fixed-effect `X` plus `X_lv`.
- `extract_lv_effects()` and `extract_ordination(component = "mean" /
  "innovation")` now read retained Gaussian bridge payloads.
- `gllvm_julia_capabilities()` exposes `predictor_informed_lv = TRUE` only for
  Gaussian.

## 3. Files Changed

Implementation:

- `R/julia-bridge.R`
- `R/extractors.R`

Tests:

- `tests/testthat/test-julia-bridge.R`

Documentation and generated help:

- `NEWS.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`
- `man/extract_lv_effects.Rd`
- `man/extract_ordination.Rd`
- `man/gllvm_julia_capabilities.Rd`
- `man/gllvm_julia_fit.Rd`

Dev log:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-25-r-bridge-lv-gaussian-point.md`

## 3a. Decisions and Rejected Alternatives

Decision: admit only complete-response Gaussian `X_lv` bridge rows.
Rationale: the paired GLLVM.jl endpoint is Gaussian-only for this route, and
R-side metadata/interval semantics are not validated for broader rows.
Rejected alternative: silently pass `X_lv` for binary/non-Gaussian bridge fits.
Confidence: high.

Decision: keep `getLV(fit)` as total scores and expose score decomposition
through `extract_ordination(component = ...)`.
Rationale: this matches the TMB extractor API and avoids changing the
compatibility shorthand.
Rejected alternative: add a component argument to `getLV()` in the same slice.
Confidence: high.

Decision: return Julia bridge `extract_lv_effects()` rows as point-only with
`std.error = NA`.
Rationale: the route has retained payloads but no CI/delta-method validation.
Rejected alternative: infer uncertainty from the Julia fit or reuse TMB SE
language.
Confidence: high.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS; no open PRs before shared-doc edits.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> REVIEWED; no concurrent shared-file collision found.
- `gh run view 28196337855 --repo itchyshin/gllvmTMB --json databaseId,workflowName,status,conclusion,headSha,url,jobs`
  -> PASS; post-#561 pkgdown completed successfully.
- `air format R/julia-bridge.R R/extractors.R tests/testthat/test-julia-bridge.R`
  -> PASS.
- `Rscript --vanilla -e 'invisible(parse(file="R/julia-bridge.R")); invisible(parse(file="R/extractors.R")); invisible(parse(file="tests/testthat/test-julia-bridge.R")); cat("parse-ok\n")'`
  -> PASS.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'`
  -> PASS. Live JuliaCall tests skipped because `JuliaCall` is not installed;
  one existing auto-Psi bridge warning was shown.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-lv-parser-guard.R", reporter = "summary")'`
  -> PASS.
- `julia --project=/private/tmp/gllvmjl-lv-next-20260625 -e 'import Pkg; Pkg.instantiate()'`
  -> PASS; local Julia project instantiated and stayed clean.
- `julia --project=/private/tmp/gllvmjl-lv-next-20260625 /private/tmp/gllvmjl-lv-next-20260625/test/test_bridge_lv_predictor.jl`
  -> PASS; 19 pass.
- `julia --project=/private/tmp/gllvmjl-lv-next-20260625 /private/tmp/gllvmjl-lv-next-20260625/test/test_bridge_capabilities.jl`
  -> PASS; 42 pass.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e 'if (!requireNamespace("devtools", quietly = TRUE)) stop("devtools not available"); devtools::document(quiet = TRUE)'`
  -> BLOCKED; `devtools` not installed.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e 'if (!requireNamespace("roxygen2", quietly = TRUE)) stop("roxygen2 not available"); roxygen2::roxygenise(".", roclets = "rd")'`
  -> BLOCKED; `roxygen2` not installed.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e 'if (!requireNamespace("pkgdown", quietly = TRUE)) stop("pkgdown not available"); pkgdown::check_pkgdown()'`
  -> BLOCKED; `pkgdown` not installed.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 R CMD check --no-manual --no-build-vignettes .`
  -> LOCAL TOOLING FAILURE before tests: local R 4.6.0 rejected this working
  tree DESCRIPTION as missing legacy `Author`/`Maintainer` fields while the
  package uses `Authors@R`.
- `git diff --check`
  -> PASS.
- After adding the `gllvm_julia_fit(X_lv = ...)` help example:
  `air format R/julia-bridge.R R/extractors.R tests/testthat/test-julia-bridge.R`
  -> PASS; the parse check above was rerun and printed `parse-ok`; `git diff
  --check` -> PASS.
- The two focused R files were rerun after the help-example patch:
  `test-julia-bridge.R` -> PASS with local live-Julia rows skipped because
  `{JuliaCall}` is not installed; `test-lv-parser-guard.R` -> PASS.
- The direct GLLVM.jl checks were rerun after the help-example patch:
  `test_bridge_lv_predictor.jl` -> PASS, 19 pass; `test_bridge_capabilities.jl`
  -> PASS, 42 pass.
- Pre-PR GitHub refresh after `git fetch origin --prune`: no open
  `gllvmTMB` PRs; main R-CMD-check `28195571078` and pkgdown `28196337855`
  remain green at `9c59d9e`. Scheduled Power pilot sweep output was not used as
  validation-promotion evidence.
- Rendered-Rd spot-check:
  `for f in man/gllvm_julia_fit.Rd man/gllvm_julia_capabilities.Rd man/extract_ordination.Rd man/extract_lv_effects.Rd; do printf '%s\n' "--- $f"; tail -5 "$f"; printf 'keyword_count='; grep -c '^\\keyword' "$f" || true; done`
  -> PASS; all four touched Rd files closed cleanly with `keyword_count=0`.
- `Rscript --vanilla -e 'files <- c("man/gllvm_julia_fit.Rd", "man/gllvm_julia_capabilities.Rd", "man/extract_ordination.Rd", "man/extract_lv_effects.Rd"); for (f in files) { cat("--", f, "--\n"); tools::checkRd(f) }; cat("rd-check-ok\n")'`
  -> PASS; all four touched Rd files passed `tools::checkRd()`.

## 5. Tests of the Tests

The new pure-R tests exercise the desired route and four explicit refusal
families before JuliaCall can be invoked. The extractor tests use a fake
Gaussian bridge payload to prove `lv_effects`, `alpha_lv`, `scores_mean`, and
`scores_innovation` are labelled and routed. The live Julia tests are not new
in this repository, but were run directly to verify the paired endpoint still
passes.

Failure-before-fix was implicit: before this slice,
`extract_lv_effects(gllvmTMB_julia)` always aborted and
`extract_ordination(component != "total")` aborted for bridge fits; the new
tests assert the admitted payload route instead.

## 6. Consistency Audit

- `rg -n "no Julia bridge parity|Julia bridge parity|component = \"total\"|Julia bridge fits accept only|do not yet expose predictor-informed|not admitted for GLLVM.jl bridge|X_lv|predictor_informed_lv" NEWS.md docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md R/julia-bridge.R R/extractors.R man/*.Rd tests/testthat/test-julia-bridge.R`
  -> REVIEWED; stale hard-refusal wording removed. Remaining hits are scoped
  boundary statements.
- `rg -n "std\\.error = NA|julia_bridge_point_estimate_only_no_ci_validation|wald_sdreport_no_ci_validation|GJL-GATE-XLV|predictor_informed_lv" NEWS.md docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md R/julia-bridge.R R/extractors.R man/*.Rd tests/testthat/test-julia-bridge.R`
  -> REVIEWED; point-only uncertainty labels and gate ids are present where
  expected.
- `rg -n "X_lv|predictor_informed_lv|julia_bridge_point_estimate_only_no_ci_validation|GJL-GATE-XLV|component = \"mean\"|component = \"innovation\"" NEWS.md R/julia-bridge.R R/extractors.R man/gllvm_julia_fit.Rd man/gllvm_julia_capabilities.Rd man/extract_ordination.Rd man/extract_lv_effects.Rd docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md tests/testthat/test-julia-bridge.R`
  -> REVIEWED; the new argument, capability column, gate IDs, point-only
  labels, and score-component names are present in the expected
  source/help/design/test surfaces.
- Rose pre-publish verdict: PASS. Changed-line scans found no new unsupported
  method/default claim, no obsolete `meta_known_V` / `gllvmTMB_wide` / `trio`
  framing, and no new export/reference-index requirement. The `X_lv` argument
  is documented in roxygen, synced in Rd, shown in a direct-wrapper example, and
  tied to validation rows `FG-18`, `EXT-31`, `LV-01`, `JUL-01`, and `JUL-01A`.
- Shannon coordination verdict: PASS. Work stayed in
  `/private/tmp/gllvmtmb-lv-julia-bridge-20260625`; no open `gllvmTMB` PRs
  existed before staging; the branch has an after-task report and dev-log entry;
  main R-CMD-check/pkgdown are green at `9c59d9e`. The scheduled Power pilot
  sweep remains separate and is not promotion evidence.

## 7. Roadmap Tick

No roadmap row was promoted. Validation rows `FG-18`, `EXT-31`, `LV-01`,
`JUL-01`, and `JUL-01A` remain `partial` with a narrower admitted surface.

## 7a. GitHub Issue Ledger

No new issue was created. This is a continuation of the Design 73 LV lane and
the existing Julia bridge admission surface tracked in `gllvmTMB#488` via the
gate registry.

## 8. What Did Not Go Smoothly

The local R 4.6 temp library lacks `devtools`, `roxygen2`, `pkgdown`, and
`JuliaCall`, so generated Rd files were manually synced and R live-Julia tests
skipped. Direct Julia tests were still possible after `Pkg.instantiate()`.
Local `R CMD check` did not reach package tests because this R-devel build
rejected the DESCRIPTION metadata shape.

## 9. Team Learning

Ada: keep this as an R bridge admission slice, not a broad parity slice.

Boole: the existing Design 73 parser setup stayed the single source for
`lv = ~ x`; bridge-specific restrictions are extra gates, not a parallel
grammar.

Emmy: extractor returns remain row-first and labelled; `getLV()` remains the
total-score compatibility shorthand.

Grace: CI should catch full package and pkgdown checks; local tooling gaps were
recorded and the previous main pkgdown run was verified successful.

Curie: tests cover success, shape/label contracts, and unsupported
combinations. Live Julia endpoint tests passed outside R because JuliaCall is
absent.

Fisher: no interval, coverage, or recovery claim moved.

Rose: stale "no Julia bridge" wording was replaced with the narrow admitted
route plus explicit broad-parity gates.

Shannon: work stayed in `/private/tmp`; no second gllvmTMB PR was open during
edits.

## 10. Known Limitations And Next Actions

- Julia bridge `X_lv` is Gaussian point-only.
- No Julia bridge `X_lv` CI, profile, bootstrap, response-mask, fixed-effect
  `X`, mixed-family, binary, or other non-Gaussian route is admitted.
- No Gaussian recovery grid, interval calibration, CI-08/CI-10 promotion, or
  broad R-Julia parity claim moved.
- Next capability slices remain Gaussian recovery for `B_lv`/`Sigma`/`Psi`,
  Bernoulli binary depth, and missing-response/factor-runtime smoke.
