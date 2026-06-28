# After Task: R Bridge Poisson `latent(lv = ~ x)` Point Route

**Branch**: `codex/poisson-xlv-r-bridge-20260628`
**Date**: `2026-06-28`
**Roles (engaged)**: `Ada / Boole / Emmy / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Admit the held Poisson `latent(..., unique = FALSE, lv = ~ x)` route on the
R-to-Julia bridge, but keep the claim point-only, complete-response, ordinary
unit-tier, and bridge-scoped.

## 2. Implemented

- Added Poisson to `.GLLVM_JULIA_XLV_FAMILIES`.
- Added a mocked main-dispatch Poisson route test that verifies the R bridge
  builds unit-level `X_lv`, forwards the `"poisson"` family, keeps no fixed
  `X`, and preserves `lv_effects` / `alpha_lv` / score-mean payloads.
- Retargeted unsupported-family `X_lv` tests from Poisson to
  `Gamma(link = "log")`.
- Updated capability notes, fail-loud family messages, roxygen, generated Rd,
  `NEWS.md`, Design 73, Design 61, and validation-debt rows.

## 3. Files Changed

- Code: `R/julia-bridge.R`.
- Tests: `tests/testthat/test-julia-bridge.R`.
- User/developer prose: `NEWS.md`, `docs/design/73-predictor-informed-latent-scores.md`,
  `docs/design/61-capability-status.md`,
  `docs/design/35-validation-debt-register.md`,
  `man/gllvm_julia_fit.Rd`.
- Audit trail: `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/2026-06-28-r-bridge-poisson-xlv.md`.

## 3a. Decisions and Rejected Alternatives

Decision: Treat Poisson as a bridge-only point route, not as native TMB
non-Gaussian `lv` admission. Rationale: the held branch only proves R-side
marshalling into the existing Julia `X_lv` bridge; it does not add native TMB
count-family score-mean recovery or interval calibration. Rejected alternative:
rewrite `LV-05` as broad count-family support. Confidence: high.

Decision: Keep `ci_method != "none"`, response masks, fixed-effect `X + X_lv`,
mixed-family `X_lv`, NB/Gamma/Beta `X_lv`, and source-specific `lv` gated.
Rationale: none is implemented or calibrated by this slice. Confidence: high.

## 4. Checks Run

- `Rscript --vanilla -e 'invisible(parse(file="R/julia-bridge.R")); invisible(parse(file="tests/testthat/test-julia-bridge.R")); cat("parse-ok\n")'`
  -> PASS; `parse-ok`.
- `export NOT_CRAN=true; Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'`
  -> PASS; one expected `unique = FALSE` bridge warning and 18 `{JuliaCall}`
  skips.
- `export NOT_CRAN=true; Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> PASS; one expected warning and 18 `{JuliaCall}` skips.
- `export NOT_CRAN=true; Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS.
- `export NOT_CRAN=true; Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS; `man/gllvm_julia_fit.Rd` regenerated. Existing roxygen warnings
  were unrelated to `X_lv`.
- `rg -n 'X_lv|Gaussian, Poisson|binomial logit/probit|non-Gaussian `X_lv`|keyword' man/gllvm_julia_fit.Rd R/julia-bridge.R`
  -> REVIEWED; source and Rd agree on the admitted family set.
- `tail -5 man/gllvm_julia_fit.Rd`
  -> REVIEWED; clean ending.
- `grep -c '^\\keyword' man/gllvm_julia_fit.Rd`
  -> REVIEWED; printed `0`.
- `git diff --check`
  -> PASS.
- `export NOT_CRAN=true; export R_LIBS=/private/tmp/gllvmtmb-check-lib:/Users/z3437171/Library/R/arm64/4.6/library; Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; `No problems found.`
- `export NOT_CRAN=true; export R_LIBS=/private/tmp/gllvmtmb-check-lib:/Users/z3437171/Library/R/arm64/4.6/library; Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; 0 errors, 0 warnings, 0 notes in 5m 1s.

## 5. Tests of the Tests

The new Poisson `X_lv` test is a feature-combination test: it combines the
existing Julia bridge main dispatch, ordinary reduced-rank latent block,
Design 73 `lv` setup, and Poisson family mapping. The unsupported-family tests
remain negative gates, now using Gamma so the Poisson admission would fail the
old expectation if the tests were not updated deliberately.

## 6. Consistency Audit

Pattern:
`rg -n 'complete-response Gaussian and binomial|Gaussian and binomial logit/probit/cloglog `engine = "julia"`|ordinal, count|Other non-Gaussian `X_lv`|count/Gamma/Beta|unsupported non-Gaussian families|complete Gaussian and binomial|Routed only for complete Gaussian and|latent\\(lv\\).*complete|coverage (passed|validated|calibrated)|calibrated CIs|500-rep.*(passed|complete|validated)' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md R/julia-bridge.R man/gllvm_julia_fit.Rd tests/testthat/test-julia-bridge.R`

Verdict: PASS with expected hits. The remaining hits are deliberate gates for
other non-Gaussian rows beyond Poisson / standard binomial links and existing
"not calibrated" warnings.

Pattern:
`rg -n 'Gaussian, Poisson, and binomial|bridge-only Poisson|native count-family|julia_bridge_point_estimate_only_no_ci_validation|GJL-GATE-XLV|LV-0[1-7]|JUL-01|JUL-01A' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md R/julia-bridge.R tests/testthat/test-julia-bridge.R`

Verdict: PASS. The live claim is scoped to bridge-only Poisson point rows;
`LV-02`, `LV-03`, `LV-06`, and `LV-07` remain partial or blocked as planned.

Rose verdict: PASS for this narrow pre-publish slice. Public prose maps the new
claim to `JUL-01`, `JUL-01A`, and partial `LV-05`; no stable/covered claim was
introduced.

## 7. Roadmap Tick

N/A. This was a held-branch triage slice, not a roadmap restructuring.

## 7a. GitHub Issue Ledger

No new issue created. Existing bridge gate wording continues to reference
`gllvmTMB#488` through the Julia bridge gate registry.

## 8. What Did Not Go Smoothly

The first stale-wording scan was quoted incorrectly with shell backticks around
`X_lv`; zsh tried to execute `X_lv`. No files were changed. The scan was rerun
with single-quoted patterns. Local live Julia tests also remain skipped because
`{JuliaCall}` is not installed in this R library.

## 9. Team Learning

Boole: The grammar distinction held: `latent(lv = ~ x)` remains predictor-informed
score means, not augmented random regression `latent(1 + x | unit)`.

Emmy: Extractor payload semantics stayed point-only for Julia bridge fits:
`std.error = NA` and `julia_bridge_point_estimate_only_no_ci_validation`.

Curie and Fisher: The added test is routing evidence, not recovery or coverage
evidence. The next non-Gaussian scientific claim still needs family-specific
simulation depth and failed-fit denominators.

Grace: `pkgdown::check_pkgdown()` and `R CMD check --no-manual` both passed
locally from the clean `/private/tmp` worktree. The roxygen2 version mismatch
means explicit `devtools::document()` remains the source of regenerated Rd.

Rose and Shannon: Claim text now separates native TMB Gaussian/binomial support
from bridge-only Poisson point support, and no open gllvmTMB PR collision was
present at branch start.

## 10. Known Limitations And Next Actions

- No live JuliaCall Poisson `X_lv` fit ran locally.
- No Poisson `B_lv` recovery, Wald/profile/bootstrap coverage, response-mask
  compatibility, fixed-effect `X + X_lv`, mixed-family `X_lv`, NB/Gamma/Beta
  `X_lv`, or source-specific/phylo `lv` support is admitted.
- Next held branches remain the NB2/Gamma/Beta bridge branch and the CI-reader
  branch, but they should not be merged while this PR is open or without
  maintainer sign-off on the capability boundary.
