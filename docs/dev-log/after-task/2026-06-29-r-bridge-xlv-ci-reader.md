# After Task: R Bridge `X_lv` Wald CI Reader Plumbing

**Branch**: `codex/xlv-ci-reader-rebase-probe-20260628`  
**Date**: `2026-06-29`  
**Roles (engaged)**: `Ada / Emmy / Fisher / Grace / Rose / Shannon`

## 1. Goal

Surface retained Julia-bridge `X_lv` Wald payloads through
`extract_lv_effects()` for admitted complete-response ordinary
`latent(..., unique = FALSE, lv = ~ x)` bridge rows, while keeping the claim
strictly reader/plumbing scope rather than calibrated interval coverage.

## 2. Implemented

- `extract_lv_effects()` now keeps the point-only NA path for
  `ci_method = "none"` and surfaces finite `std.error`, `lower`, and `upper`
  when a Julia bridge fit retains Wald `lv_effects` payloads.
- The Julia bridge `gllvm_julia_fit()` and main `gllvmTMB(..., engine =
  "julia")` paths route `ci_method = "wald"` for admitted `X_lv` rows.
- Profile/bootstrap `X_lv` intervals still fail loudly; response masks with
  `X_lv`, fixed-effect `X + X_lv`, mixed-family `X_lv`, source-specific `lv`,
  and calibrated coverage claims remain outside this slice.

## 3. Files Changed

- Code: `R/extractors.R`, `R/julia-bridge.R`.
- Tests: `tests/testthat/test-julia-bridge.R`.
- Generated Rd: `man/extract_lv_effects.Rd`,
  `man/gllvmTMB_julia-methods.Rd`, `man/gllvm_julia_fit.Rd`.
- Audit trail: `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/2026-06-29-r-bridge-xlv-ci-reader.md`.

## 3a. Decisions and Rejected Alternatives

Decision: expose Wald payloads only through `extract_lv_effects()`, not
`confint()`, for predictor-informed `X_lv` bridge rows. Rationale: this keeps
the payload semantics tied to the trait-effect table and avoids implying a
general interval interface for `X_lv`. Confidence: high.

Decision: label Wald reader rows as `julia_bridge_wald_delta_method` while
keeping point-only rows as
`julia_bridge_point_estimate_only_no_ci_validation`. Rationale: downstream
users can distinguish finite Wald reader output from calibrated coverage
evidence. Confidence: high.

Rejected alternative: promote Julia bridge `X_lv` intervals to calibrated CI
support. Rationale: no 500-rep bridge coverage grid, MCSE, failed-fit
denominators, or profile/bootstrap rescue evidence exists for this route.
Confidence: high.

## 4. Checks Run

- `gh pr list --state open --limit 20 --json number,title,headRefName,mergeStateStatus,isDraft,url`
  -> REVIEWED; PR #570 was the only open gllvmTMB PR before this audit-only
  edit.
- `git log --all --oneline --since='6 hours ago' -- docs/dev-log/check-log.md docs/dev-log/after-task`
  -> PASS; no recent shared-file edits in those paths.
- `export NOT_CRAN=true; export R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library; export GLLVM_JL_PATH=/private/tmp/gllvmjl-phylo-xlv; export PATH="$HOME/.juliaup/bin:$PATH"; Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", desc = "extract_lv_effects surfaces Wald X_lv CIs and preserves the NA path")'`
  -> PASS; 15 assertions, 0 failures, 0 warnings, 0 skips.
- `export NOT_CRAN=true; export R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library; export GLLVM_JL_PATH=/private/tmp/gllvmjl-phylo-xlv; export PATH="$HOME/.juliaup/bin:$PATH"; Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", desc = "gllvmTMB routes Gaussian X_lv Wald CIs through the Julia bridge")'`
  -> PASS; 7 assertions, 0 failures, 0 warnings, 0 skips. Julia emitted the
  known local `LogExpFunctionsInverseFunctionsExt` precompile error
  (`UndefVarError: loglogistic not defined`) before continuing.
- `export NOT_CRAN=true; export R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library; unset GLLVM_JL_PATH; export PATH="$HOME/.juliaup/bin:$PATH"; Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 5m 10.1s with 0 errors, 0 warnings, and
  0 notes. Local roxygen2 8.0.0 differs from the declared 7.3.2, so
  `devtools::check()` did not re-document during the check.
- `export R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library; Rscript --vanilla -e 'files <- c("man/extract_lv_effects.Rd", "man/gllvmTMB_julia-methods.Rd", "man/gllvm_julia_fit.Rd"); for (f in files) { cat("--", f, "--\n"); tools::checkRd(f) }; cat("rd-check-ok\n")'`
  -> PASS; `rd-check-ok`.
- `for f in man/extract_lv_effects.Rd man/gllvmTMB_julia-methods.Rd man/gllvm_julia_fit.Rd; do printf '%s\n' "--- $f"; tail -5 "$f"; printf 'keyword_count='; grep -c '^\\keyword' "$f" || true; done`
  -> PASS; each file ended cleanly and `keyword_count=0`.
- `rg -n 'coverage (passed|validated|calibrated)|calibrated CIs|500-rep.*(passed|complete|validated)|profile/bootstrap.*X_lv|julia_bridge_point_estimate_only_no_ci_validation|julia_bridge_wald_delta_method|Wald.*payload' R/extractors.R R/julia-bridge.R man/extract_lv_effects.Rd man/gllvmTMB_julia-methods.Rd man/gllvm_julia_fit.Rd tests/testthat/test-julia-bridge.R`
  -> REVIEWED; expected hits only. The changed surfaces say Wald payload
  reader output is not calibrated coverage; profile/bootstrap `X_lv` rows
  remain not admitted.
- `git diff --check`
  -> PASS before the audit-only docs were added.
- `gh pr checks 570`
  -> PASS before the audit-only docs were added; `ubuntu-latest (release)`
  passed in 13m43s.

## 5. Tests of the Tests

The new tests are feature-combination tests. They combine retained Julia bridge
`lv_effects` payloads with `extract_lv_effects()`, both for a pure mocked
payload and for a live `gllvmTMB(..., engine = "julia", ci_method = "wald")`
route. The same test file also checks the point-only NA path, so a regression
that silently labels `ci_method = "none"` rows as interval evidence would fail.

## 6. Consistency Audit

Pattern:
`rg -n 'coverage (passed|validated|calibrated)|calibrated CIs|500-rep.*(passed|complete|validated)|profile/bootstrap.*X_lv|julia_bridge_point_estimate_only_no_ci_validation|julia_bridge_wald_delta_method|Wald.*payload' R/extractors.R R/julia-bridge.R man/extract_lv_effects.Rd man/gllvmTMB_julia-methods.Rd man/gllvm_julia_fit.Rd tests/testthat/test-julia-bridge.R`

Verdict: PASS with expected hits. The active reader surfaces distinguish
`julia_bridge_wald_delta_method` from
`julia_bridge_point_estimate_only_no_ci_validation`, and the prose explicitly
says Wald payloads are reader output, not calibrated coverage.

Rose verdict: PASS for this narrow reader-plumbing slice. No broad CI,
profile/bootstrap, response-mask, fixed-effect `X + X_lv`, mixed-family, or
native non-Gaussian support claim is introduced.

## 7. Roadmap Tick

N/A. This lands the held CI-reader plumbing branch in the R bridge queue; it
does not change the V1 finish line or promote any validation-debt row to
covered interval support.

## 7a. GitHub Issue Ledger

No new issue created. The PR is #570:
<https://github.com/itchyshin/gllvmTMB/pull/570>.

## 8. What Did Not Go Smoothly

A full local `R CMD check` with `GLLVM_JL_PATH=/private/tmp/gllvmjl-phylo-xlv`
failed in pre-existing live-Julia bridge parity tests unrelated to this PR:
grouped-dispersion df/native parity and Gaussian TMB-vs-Julia Sigma/logLik
comparisons. The CI-shaped check leaves `GLLVM_JL_PATH` unset, so those live
Julia tests skip, matching ordinary GitHub R-CMD-check behavior. The two
CI-reader-specific targeted tests passed with `GLLVM_JL_PATH` set.

## 9. Team Learning

Emmy: `extract_lv_effects()` now has three visible uncertainty states:
native TMB `wald_sdreport_no_ci_validation`, Julia bridge point-only
`julia_bridge_point_estimate_only_no_ci_validation`, and Julia bridge Wald
reader payload `julia_bridge_wald_delta_method`.

Fisher: finite Wald payloads are not interval calibration. Coverage, MCSE,
failed-fit denominators, and any profile/bootstrap rescue remain separate
evidence requirements.

Grace: The PR was rebased onto `main` after #569 merged, checked locally in a
clean `/private/tmp` worktree, pushed as draft PR #570, and passed GitHub
`ubuntu-latest (release)` before this audit-only docs commit.

Rose and Shannon: Claim language stays narrow and the one-open-PR gate is
respected. Other queued LV branches wait behind #570.

## 10. Known Limitations And Next Actions

- No calibrated bridge `X_lv` interval claim.
- No profile/bootstrap `X_lv` interval route.
- No response-mask `X_lv`, fixed-effect `X + X_lv`, mixed-family `X_lv`,
  source-specific `lv`, or phylo grammar support.
- After #570 clears again with the audit-only docs commit, the next R-side
  branch should be chosen from the queued guard/depth branches under the
  one-open-PR rule.
