# After Task: R bridge binary predictor-informed latent-score route

**Branch**: `codex/lv-binary-julia-bridge-20260626`
**Date**: `2026-06-26`
**Roles (engaged)**: Ada, Boole, Emmy, Grace, Curie, Fisher, Rose, Shannon

## 1. Goal

Extend the narrow Design 73 R-to-Julia bridge for
`latent(..., lv = ~ x)` from Gaussian point fits to complete-response binomial
logit/probit/cloglog point fits, while keeping all interval, mask, fixed-effect
`X`, mixed-family, and broad parity claims gated.

## 2. Implemented

- `binomial(link = "logit")`, `binomial(link = "probit")`, and
  `binomial(link = "cloglog")` now map to `binomial`,
  `binomial_probit`, and `binomial_cloglog` bridge keys.
- The predictor-informed latent-score bridge admission set is now
  `gaussian`, `binomial`, `binomial_probit`, and `binomial_cloglog`.
- The main `gllvmTMB(..., engine = "julia")` dispatch passes unit-level `X_lv`
  for those binary standard-link rows when the fit has no fixed-effect `X`, no
  response mask, and `ci_method = "none"`.
- `gllvm_julia_capabilities()` now marks `predictor_informed_lv` and
  `cbind_binomial` for the admitted binary link labels.
- `extract_lv_effects()` documentation now says Gaussian and binomial
  logit/probit/cloglog Julia bridge rows are point-only and carry
  `std.error = NA`.
- Design 06, Design 35, Design 61, Design 73, NEWS, and generated Rd files were
  updated to state the admitted binary point route and the remaining gates.

## Mathematical Contract

For the admitted bridge rows, the R parser constructs a unit-level matrix
`X_lv` from the one-sided `lv` formula. The paired Julia fit decomposes the
score entering the linear predictor into

```text
u_i = X_lv,i alpha + e_i
```

where `e_i` is the zero-mean latent innovation. The reported trait-scale effect
is

```text
B_lv = Lambda alpha^T
```

with point estimates only on the Julia bridge. The link-specific binary mean is
kept on the GLLVM.jl side: logit uses the logistic link, probit uses the normal
CDF link, and cloglog uses `1 - exp(-exp(eta))`. No uncertainty calibration,
profile likelihood, bootstrap, mask, fixed-effect `X` plus `X_lv`, mixed-family,
or broad native-vs-Julia parity claim moved.

## 3a. Decisions and Rejected Alternatives

Decision: admit only complete-response binary standard-link point rows.
Rationale: the paired GLLVM.jl branch implements the binary `X_lv` endpoint for
logit, probit, and cloglog only, and the R bridge has no interval evidence for
those rows. Rejected alternative: admit all non-Gaussian `X_lv` rows.
Confidence: high.

Decision: keep fixed-effect `X` support narrower than `X_lv` support.
Rationale: R fixed-effect `X` rows still have a different admission surface, and
probit/cloglog fixed-effect parity is not validated in this slice. Rejected
alternative: add probit/cloglog to `.GLLVM_JULIA_X_FAMILIES`.
Confidence: high.

Decision: leave the GLLVM.jl branch pushed but do not open a new Julia PR while
draft PR #113 remains open. Rationale: the project currently has a one-PR queue
guard for Julia-side capability work. Rejected alternative: open a second
GLLVM.jl PR anyway.
Confidence: high.

## 4. Files Touched

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
- `man/gllvm_julia_fit.Rd`

Dev log:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-26-r-bridge-binary-xlv.md`
- `docs/dev-log/recovery-checkpoints/2026-06-26-055406-codex-stop-checkpoint.md`
- `docs/dev-log/recovery-checkpoints/2026-06-26-061518-codex-stop-checkpoint.md`

## 5. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS; no open gllvmTMB PRs.
- `git log --all --oneline --since="6 hours ago" -- AGENTS.md CLAUDE.md ROADMAP.md CONTRIBUTING.md docs/dev-log/check-log.md docs/design docs/dev-log/after-task inst/COPYRIGHTS DESCRIPTION`
  -> PASS; no concurrent shared-file edits found.
- `gh pr list --repo itchyshin/GLLVM.jl --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> REVIEWED; draft PR #113 remains open and `DIRTY`.
- `air format R/julia-bridge.R R/extractors.R tests/testthat/test-julia-bridge.R`
  -> PASS.
- `Rscript --vanilla -e 'invisible(parse("R/julia-bridge.R")); invisible(parse("R/extractors.R")); invisible(parse("tests/testthat/test-julia-bridge.R")); cat("parse-ok\n")'`
  -> PASS.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6:/private/tmp/gllvmtmb-install-lib-4.6:/Users/z3437171/Library/R/arm64/4.6/library Rscript --vanilla -e 'roxygen2::roxygenise()'`
  -> PASS with existing unresolved-link warnings unrelated to this slice.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6:/private/tmp/gllvmtmb-install-lib-4.6:/Users/z3437171/Library/R/arm64/4.6/library Rscript --vanilla -e 'pkgload::load_all(export_all = TRUE, helpers = TRUE, quiet = TRUE); Sys.unsetenv("GLLVM_JL_PATH"); res <- testthat::test_file("tests/testthat/test-julia-bridge.R"); failed <- vapply(res, function(x) any(x$results$failed), logical(1)); if (any(failed)) quit(status = 1)'`
  -> PASS; `FAIL 0 | WARN 1 | SKIP 18 | PASS 480`.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6:/private/tmp/gllvmtmb-install-lib-4.6:/Users/z3437171/Library/R/arm64/4.6/library Rscript --vanilla -e 'pkgload::load_all(export_all = TRUE, helpers = TRUE, quiet = TRUE); res <- testthat::test_file("tests/testthat/test-lv-parser-guard.R"); failed <- vapply(res, function(x) any(x$results$failed), logical(1)); if (any(failed)) quit(status = 1)'`
  -> PASS; `FAIL 0 | WARN 0 | SKIP 0 | PASS 199`.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6:/private/tmp/gllvmtmb-install-lib-4.6:/Users/z3437171/Library/R/arm64/4.6/library Rscript --vanilla -e 'pkgload::load_all(export_all = TRUE, helpers = TRUE, quiet = TRUE); res <- testthat::test_file("tests/testthat/test-extractors.R"); failed <- vapply(res, function(x) any(x$results$failed), logical(1)); if (any(failed)) quit(status = 1)'`
  -> PASS; `FAIL 0 | WARN 0 | SKIP 0 | PASS 17`.
- Standalone live R-to-Julia binary `X_lv` smoke with
  `GLLVM_JL_PATH=/private/tmp/gllvmjl-binomial-xlv-20260625`
  -> PASS before the stop checkpoint; logit, probit, and cloglog printed
  `live-binary-xlv-ok`.
- Broad live `tests/testthat/test-julia-bridge.R` with
  `GLLVM_JL_PATH=/private/tmp/gllvmjl-binomial-xlv-20260625`
  -> REVIEWED before the stop checkpoint; unrelated older live bridge failures
  remained, but the new binary `X_lv` live test did not fail.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6:/private/tmp/gllvmtmb-install-lib-4.6:/Users/z3437171/Library/R/arm64/4.6/library Rscript --vanilla -e 'Sys.unsetenv("GLLVM_JL_PATH"); devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS after installing optional local test dependencies `ape` and
  `MCMCglmm`; `0 errors | 0 warnings | 0 notes`.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6:/private/tmp/gllvmtmb-install-lib-4.6:/Users/z3437171/Library/R/arm64/4.6/library Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; `No problems found`.
- `git diff --check`
  -> PASS.
- Rendered-Rd spot-check for `man/extract_lv_effects.Rd` and
  `man/gllvm_julia_fit.Rd`
  -> PASS; both close cleanly and report `keyword_count=0`.
- `tools::checkRd()` on `man/extract_lv_effects.Rd` and
  `man/gllvm_julia_fit.Rd`
  -> PASS; printed `rd-check-ok`.
- GLLVM.jl targeted tests:
  `test_bridge_missing_mask.jl` -> 83 pass;
  `test_bridge_lv_predictor.jl` -> 94 pass;
  `test_binomial_fit.jl` -> 8 pass;
  `test_bridge_ci.jl` -> 64 pass.
- `julia --project=. --startup-file=no -e 'using Pkg; Pkg.test()'`
  -> PASS; `GLLVM.jl | 4629 pass, 1 broken, 4630 total, 49m24.9s`.
- `julia --project=docs --startup-file=no -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate(); include("docs/make.jl")'`
  -> PASS; local Documenter/Vitepress build completed with existing local-link,
  asset, npm-audit, and deployment-skip warnings.

## 6. Tests of the Tests

The test set covers both acceptance and rejection.

Acceptance evidence:

- Family mapping tests assert logit/probit/cloglog mapping to the exact Julia
  bridge keys.
- A mocked main-dispatch test verifies that `gllvmTMB(..., engine = "julia")`
  sends `X_lv` with the correct `n x q` shape, row names, column name, `N = 1L`,
  no fixed `X`, no mask, and `ci_method = "none"` for all three binary links.
- A live direct-wrapper test fits binomial logit/probit/cloglog `X_lv` payloads
  against the paired GLLVM.jl branch and checks `lv_effects`, `alpha_lv`,
  `scores_mean`, `scores_innovation`, and total = mean + innovation algebra.

Rejection evidence:

- Unsupported `binomial(link = "cauchit")` still fails loudly.
- Mixed-family vectors containing probit binary rows remain gated.
- `poisson()` with `X_lv` still fails under `GJL-GATE-XLV-FAMILY`.
- Existing tests continue to gate `X_lv` CI requests, masks with `X_lv`, and
  fixed-effect `X` plus `X_lv`.

The new tests satisfy the feature-combination rule: they combine the existing
Design 73 `lv` parser route with the Julia bridge family/link dispatch and the
extractor score-decomposition contract.

## 7a. Issue Ledger

No new GitHub issue was opened. The slice continues the Design 73
predictor-informed latent-score lane and the existing Julia bridge ledger rows
`FG-18`, `RE-13`, `EXT-31`, `LV-01`, `LV-04`, `LV-05`, `JUL-01`, and
`JUL-01A`.

## 8. Consistency Audit

- `rg -n 'Gaussian Julia bridge|complete-response Gaussian|Gaussian .*X_lv|non-Gaussian/binary|binary/non-Gaussian|unsupported Julia bridge `X_lv`' NEWS.md R docs/design man tests/testthat/test-julia-bridge.R`
  -> REVIEWED. Expected row-specific Gaussian hits remain for the Gaussian
  bridge test title and `LV-01`. Stale binary/non-Gaussian hard-refusal wording
  was removed or narrowed to "other non-Gaussian" rows.
- `rg -n 'binomial_probit|binomial_cloglog|predictor_informed_lv|julia_bridge_point_estimate_only_no_ci_validation|GJL-GATE-XLV|std\.error = NA|component = "mean"|component = "innovation"' NEWS.md R/julia-bridge.R R/extractors.R man/extract_lv_effects.Rd man/gllvm_julia_fit.Rd docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md tests/testthat/test-julia-bridge.R`
  -> REVIEWED. Binary link labels, point-only uncertainty labels, gate IDs, and
  score-component language appear in the expected implementation, help, design,
  and test surfaces.
- Prose-style review verdict: PASS with a narrow claim boundary. The reader is
  an R package contributor or method developer checking bridge support; the
  prose states the admitted route first, then the remaining gates.
- Shannon coordination verdict: WARN/PASS. The gllvmTMB lane has no competing
  PR and no recent shared-file collision. The only warning is queue-level:
  GLLVM.jl draft PR #113 remains open, so the paired Julia branch should not
  get a second Julia PR until that queue is clear.

## 9. What Did Not Go Smoothly

The full GLLVM.jl `Pkg.test()` took 49 minutes and had two long silent stretches.
Process sampling showed CPU-heavy linear algebra/GC work, not an idle wait. The
suite eventually passed.

The first Julia docs command failed because the docs environment was not
instantiated. A plain `Pkg.instantiate()` then failed because `GLLVM` is
unregistered in the docs environment. The repo-local pattern
`Pkg.develop(PackageSpec(path=pwd()))` solved it.

R CMD check initially failed because the temporary R library lacked optional
test dependencies `ape` and then `MCMCglmm`. After installing both into the temp
library, the same `devtools::check(args = "--no-manual")` command passed with
zero errors, warnings, or notes.

## 10. Known Residuals

- Julia bridge `X_lv` rows remain point-only: no Wald/profile/bootstrap CI
  admission.
- Response masks with `X_lv`, fixed-effect `X` plus `X_lv`, mixed-family
  `X_lv`, and ordinal/count/Gamma/Beta/delta-hurdle `X_lv` rows remain gated.
- Bernoulli single-trial binary depth, Gaussian recovery grids, missing-response
  compatibility, factor-predictor runtime recovery, and interval calibration
  remain future validation slices.
- The paired GLLVM.jl binary `X_lv` branch is pushed and locally validated, but
  no Julia PR was opened because draft PR #113 is still occupying the Julia
  queue.
- No CI-08/CI-10 validation row was promoted.

## 11. Team Learning

Ada: this is a capability bridge slice, not a parity proclamation.

Boole: family-link dispatch can widen independently from fixed-effect `X`
support, but the capability ledger must show that split explicitly.

Emmy: retained bridge payloads remain sufficient for score decomposition and
trait-effect tables, provided uncertainty status is labelled point-only.

Grace: full local R CMD check needs optional phylo packages in the temp library;
record dependency setup before interpreting failures as code regressions.

Curie: acceptance tests need to check exact bridge payload shape and algebra, not
only that the call returns a `gllvmTMB_julia` object.

Fisher: binary point recovery does not imply interval coverage, Bernoulli depth,
or Type-I/coverage admission.

Rose: stale wording should change from "binary unsupported" to "other
non-Gaussian unsupported"; leaving old binary refusal text would have hidden the
new admitted row.

Shannon: keep the GLLVM.jl branch pushed but do not open a second Julia PR while
the Student-t draft remains open.
