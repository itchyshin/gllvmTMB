# After Task: R Bridge NB2 / Gamma / Beta `latent(lv = ~ x)` Point Routes

**Branch**: `codex/nbgammabeta-xlv-r-bridge-20260628`
**Date**: `2026-06-28`
**Roles (engaged)**: `Ada / Boole / Emmy / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Port the held NB2 / Gamma / Beta `latent(..., unique = FALSE, lv = ~ x)`
R-to-Julia bridge admission onto current `main` after the Poisson bridge slice
merged, while keeping the claim complete-response, ordinary unit-tier,
bridge-scoped, point-only, and explicitly not interval-calibrated.

## 2. Implemented

- Added `negbinomial`, `gamma`, and `beta` to
  `.GLLVM_JULIA_XLV_FAMILIES`, preserving the capability-ledger ordering.
- Added a mocked main-dispatch test for NB2, Gamma(log), and Beta `X_lv`
  bridge rows that verifies family mapping, no fixed `X`, no response mask,
  `ci_method = "none"`, and the unit-level `X_lv` shape.
- Kept `nbinom1()` as the unsupported-family fail-loud probe.
- Updated Julia bridge capability notes, fail-loud family messages, roxygen,
  generated Rd, `NEWS.md`, Design 73, Design 61, and validation-debt rows.

## 3. Files Changed

- Code: `R/julia-bridge.R`.
- Tests: `tests/testthat/test-julia-bridge.R`.
- User/developer prose: `NEWS.md`,
  `docs/design/73-predictor-informed-latent-scores.md`,
  `docs/design/61-capability-status.md`,
  `docs/design/35-validation-debt-register.md`,
  `man/gllvm_julia_fit.Rd`.
- Audit trail: `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/2026-06-28-r-bridge-nbgammabeta-xlv.md`.

## 3a. Decisions and Rejected Alternatives

Decision: Treat NB2, Gamma, and Beta as bridge-only point routes, not native
TMB non-Gaussian `lv` admission. Rationale: this slice validates R-side
marshalling into the Julia bridge and mocked main-dispatch routing; it does not
add native TMB count/continuous-positive family score-mean recovery or interval
calibration. Rejected alternative: promote `LV-05` to broad non-Gaussian native
support. Confidence: high.

Decision: Keep `ci_method != "none"`, response masks, fixed-effect `X + X_lv`,
mixed-family `X_lv`, NB1, ordinal, and source-specific `lv` gated. Rationale:
none is implemented or calibrated by this slice. Confidence: high.

Decision: Add t-based small-sample interval calibration as a future inference
candidate, not as a current claim. Rationale: small-`N` evidence may favor
t-critical intervals over normal-Wald intervals, but coverage, MCSE, interval
width, and failed-fit denominators still need their own grid. Confidence:
medium.

## 4. Checks Run

- `Rscript --vanilla -e 'invisible(parse(file="R/julia-bridge.R")); invisible(parse(file="tests/testthat/test-julia-bridge.R")); cat("parse-ok\n")'`
  -> PASS; `parse-ok`.
- `export NOT_CRAN=true; Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'`
  -> PASS; one expected warning about Julia bridge `unique = FALSE`, and 18
  live JuliaCall tests skipped because `{JuliaCall}` is not installed in the
  default test library.
- `export NOT_CRAN=true; Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS; regenerated `man/gllvm_julia_fit.Rd`. Existing roxygen unresolved-link
  warnings were unrelated to `X_lv`.
- `export NOT_CRAN=true; Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> PASS; same expected warning and 18 `{JuliaCall}` skips.
- `export NOT_CRAN=true; Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS.
- `export NOT_CRAN=true; export R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:/Users/z3437171/Library/R/arm64/4.6/library; export GLLVM_JL_PATH=/private/tmp/gllvmjl-phylo-xlv; export PATH="$HOME/.juliaup/bin:$PATH"; Rscript --vanilla - <<'RS' ... live NB2/Gamma/Beta X_lv smoke ... RS`
  -> PASS; printed `live-nbgammabeta-xlv-ok` for `nbinom2`, `gamma`, and
  `beta`, with models `negbinomial_xlv_rr`, `gamma_xlv_rr`, and `beta_xlv_rr`
  and `lv_effects = 3x1`. Julia emitted the known
  `LogExpFunctionsInverseFunctionsExt` precompile error
  (`UndefVarError: loglogistic not defined`) before continuing; all R-side
  payload and extractor checks passed. The live GLLVM.jl target was
  `/private/tmp/gllvmjl-phylo-xlv` at local commit `bcf2680`.
- `rg -n 'Gaussian, Poisson, and binomial|Poisson and binomial|Poisson, and binomial|beyond Poisson|count/Gamma/Beta|NB/Gamma/Beta|other non-Gaussian bridge families|ordinal/NB/Gamma/Beta|Named Julia bridge rows now exist only for the complete-response Gaussian, Poisson' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md R/julia-bridge.R man/gllvm_julia_fit.Rd tests/testthat/test-julia-bridge.R`
  -> PASS; no hits after the `EXT-31` ledger row was updated.
- `rg -n 'coverage (passed|validated|calibrated)|calibrated CIs|500-rep.*(passed|complete|validated)|t-based.*(passed|validated|calibrated)|t-Wald.*(passed|validated|calibrated)' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md R/julia-bridge.R man/gllvm_julia_fit.Rd tests/testthat/test-julia-bridge.R`
  -> REVIEWED; expected cautionary hits only: Design 61 says 500-rep calibration
  evidence has not landed and records t-based intervals as a future candidate,
  not a passed/validated claim.
- `git diff --check`
  -> PASS.
- `export NOT_CRAN=true; Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; `No problems found.`
- `export NOT_CRAN=true; Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 5m 9.7s with 0 errors, 0 warnings, and
  0 notes.
- `gh run view 28332014688 --repo itchyshin/gllvmTMB --json status,conclusion,jobs`
  -> PASS; main-branch #568 merge check `ubuntu-latest (release)` passed in
  13m15s on commit `7ba0890`.

## 5. Tests of the Tests

The new NB2 / Gamma / Beta test is a mocked feature-combination test: it
combines the existing Julia bridge main dispatch, ordinary reduced-rank latent
block, Design 73 `lv` setup, and family mapping. The unsupported-family tests
still exercise `GJL-GATE-XLV-FAMILY` via `nbinom1()`, so the newly admitted
families would fail the old expectation if the tests were not deliberately
updated.

## 6. Consistency Audit

Pattern:
`rg -n 'Gaussian, Poisson, and binomial|Poisson and binomial|Poisson, and binomial|beyond Poisson|count/Gamma/Beta|NB/Gamma/Beta|other non-Gaussian bridge families|ordinal/NB/Gamma/Beta|Named Julia bridge rows now exist only for the complete-response Gaussian, Poisson' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md R/julia-bridge.R man/gllvm_julia_fit.Rd tests/testthat/test-julia-bridge.R`

Verdict: PASS. No active public/source surface still says Poisson is the only
non-binomial bridge point route.

Pattern:
`rg -n 'coverage (passed|validated|calibrated)|calibrated CIs|500-rep.*(passed|complete|validated)|t-based.*(passed|validated|calibrated)|t-Wald.*(passed|validated|calibrated)' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md R/julia-bridge.R man/gllvm_julia_fit.Rd tests/testthat/test-julia-bridge.R`

Verdict: PASS with expected cautionary hits. Design 61 explicitly says 500-rep
calibration evidence has not landed and describes t-based intervals as a future
small-sample comparator only.

Rose verdict: PASS for this narrow pre-publish slice. Public prose maps the new
claim to `JUL-01`, `JUL-01A`, partial `FG-18`, partial `RE-13`, partial
`EXT-31`, and partial `LV-05`; no coverage-calibrated or native TMB count-family
claim is introduced.

## 7. Roadmap Tick

N/A. This was a held-branch triage slice, not a roadmap restructuring.

## 7a. GitHub Issue Ledger

No new issue created. Existing bridge gate wording continues to reference the
Julia bridge gate registry.

## 8. What Did Not Go Smoothly

The held branch was stacked on the old Poisson branch. Current `main` already
had Poisson through #568, so the first cherry-pick conflicted in the
`GJL-GATE-XLV-FAMILY` wording. Codex resolved that conflict toward the
current complete-response Gaussian / Poisson / NB2 / Gamma / Beta / binomial
standard-link point-route set.

## 9. Team Learning

Boole: The grammar distinction still holds: `latent(lv = ~ x)` remains
predictor-informed score means, not augmented random regression
`latent(1 + x | unit)`.

Emmy: Extractor payload semantics stay point-only for Julia bridge fits:
`std.error = NA` and `julia_bridge_point_estimate_only_no_ci_validation`.

Curie and Fisher: The added test is routing evidence, not recovery or coverage
evidence. NB2 / Gamma / Beta scientific claims still need family-specific
simulation depth and failed-fit denominators.

Grace: This branch was prepared in a clean `/private/tmp` worktree off the
post-#568 `origin/main` SHA. Local `pkgdown::check_pkgdown()` and
`R CMD check --no-manual` passed, and the main-branch check from the #568 merge
passed before this branch was pushed.

Rose and Shannon: Claim text separates native TMB Gaussian/binomial support from
bridge-only non-Gaussian point support, and no open gllvmTMB PR collision was
present at branch start.

## 10. Known Limitations And Next Actions

- No NB2 / Gamma / Beta `B_lv` recovery grid, Wald/profile/bootstrap coverage,
  response-mask compatibility, fixed-effect `X + X_lv`, mixed-family `X_lv`,
  NB1, ordinal, or source-specific/phylo `lv` support is admitted.
- Next after this PR is the CI-reader held branch, but it cannot imply interval
  calibration unless a coverage grid exists.
- Add t-based small-sample interval rows to the Gaussian `B_lv` coverage design
  as a candidate comparator against normal-Wald and profile/bootstrap intervals.
