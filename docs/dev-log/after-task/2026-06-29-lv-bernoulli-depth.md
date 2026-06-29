# After Task: LV Bernoulli Single-Trial Depth Gate

**Branch**: `codex/lv-bernoulli-depth-20260628`
**Date**: `2026-06-29`
**Roles (engaged)**: `Ada / Curie / Fisher / Boole / Grace / Rose`

## 1. Goal

Add the next ordinary C1 `latent(..., lv = ~ x)` evidence slice for pure
single-trial binomial responses. The goal is to show that Bernoulli `logit`,
`probit`, and `cloglog` point routes recover the link-scale
`B_lv = Lambda alpha^T` target in a controlled complete-response setting,
without implying interval calibration or broader non-Gaussian support.

## 2. Implemented

- Added `tests/testthat/test-lv-bernoulli-depth.R`.
- The test constructs deterministic Bernoulli DGPs for `logit`, `probit`, and
  `cloglog` links with `z_i = x_i alpha + e_i` and
  `eta_it = beta_t + lambda_t z_i`.
- Each link runs separation diagnostics before fitting: each trait must have
  both outcomes, finite per-trait GLM coefficients, and non-saturated fitted
  probabilities.
- Each fit checks the native TMB `lv_B` route, link IDs, convergence, gradient,
  `X_lv_B`, `alpha_lv_B`, `U_lv_mean_B`, `U_B_total`, `B_lv_unit`, and the
  `total = innovation + mean` ordination decomposition.
- The recovery gate targets the rotation-invariant link-scale trait effect
  reported by `extract_lv_effects()`, not raw `alpha` or raw `Lambda`.

## 3. Files Changed

Tests:

- `tests/testthat/test-lv-bernoulli-depth.R`

Evidence records:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-29-lv-bernoulli-depth.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep this as a pure Bernoulli single-trial depth gate.
Rationale: Bernoulli single-trial behaviour is the gap between earlier
binomial point-route smoke tests and a credible binomial C1 claim.
Rejected alternative: include ordinal, multi-trial binomial edge cases, missing
responses, or interval coverage in the same PR.
Confidence: high for the bounded point/recovery slice; no interval claim.

Decision: gate on `B_lv`, not raw `alpha` or raw `Lambda`.
Rationale: `B_lv = Lambda alpha^T` is the identifiable link-scale predictor
effect for this slice, while raw factors/loadings remain rotation/sign
sensitive.
Rejected alternative: assert recovery of raw latent-score coefficients.
Confidence: high; matches the Gaussian LV evidence pattern.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> REVIEWED; no open gllvmTMB PRs at the pre-edit check.
- `git log --all --oneline --since="6 hours ago" -- docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-29-lv-bernoulli-depth.md tests/testthat/test-lv-bernoulli-depth.R`
  -> REVIEWED; only this queued Bernoulli branch had touched the new test file.
- `git rebase origin/main`
  -> PASS; branch rebased cleanly after PR #571, with top commit
  `6c068367 test(lv): add Bernoulli single-trial depth gate`.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-bernoulli-depth", reporter = "summary")'`
  -> PASS; focused Bernoulli depth tests completed with no failures.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS; parser guard remained green with the existing informational
  sigma-eps auto-suppression message.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 5m01.1s with 0 errors, 0 warnings, and
  0 notes. As in earlier slices, `check()` did not re-document because local
  roxygen2 8.0.0 differs from the declared 7.3.2.
- `gh run list --repo itchyshin/gllvmTMB --limit 5 --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url,createdAt`
  -> REVIEWED; the post-merge main `R-CMD-check` run for #571 was still
  `in_progress`, so the branch was not opened as the next PR yet.
- `git diff --check`
  -> PASS; no whitespace errors.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-29-lv-bernoulli-depth.md`
  -> PASS; validator returned successfully.

## 5. Tests of the Tests

The new test is prophylactic and depth-oriented. It would fail if the
`lv = ~ x` parser stopped populating `X_lv_B`, if TMB stopped reporting
`alpha_lv_B`, `U_lv_mean_B`, `U_B_total`, or `B_lv_unit`, if standard
Bernoulli link IDs drifted, if fitted gradients became too large, if separation
made the DGP uninformative, or if extracted `B_lv` moved outside the explicit
link-specific recovery tolerances.

## 6. Consistency Audit

- `rg -n "latent\\([^\\n]*lv\\s*=|lv\\s*=\\s*~|predictor-informed|B_lv|LV-0[1-7]" tests/testthat/test-lv-bernoulli-depth.R docs/dev-log/check-log.md docs/dev-log/after-task/2026-06-29-lv-bernoulli-depth.md`
  -> REVIEWED; the new evidence records describe a bounded Bernoulli depth
  slice, not full LV completion.
- `rg -n "coverage|interval|Wald|profile|bootstrap" tests/testthat/test-lv-bernoulli-depth.R docs/dev-log/after-task/2026-06-29-lv-bernoulli-depth.md`
  -> REVIEWED; interval language is limited to explicit "not claimed" scope
  boundaries.

## 7. Roadmap Tick

No roadmap row is promoted in this branch. The relevant status remains:
ordinary binomial/Bernoulli C1 is deeper than smoke, but interval coverage,
missing responses, ordinal rows, mixed-family cells, masks, `X + X_lv`, and
source-specific `lv` are still outside the claim.

## 7a. GitHub Issue Ledger

No new issue was created. This is a continuation of the Design 73 LV lane and
the LV validation-debt rows rather than a standalone user-facing feature.

## 8. What Did Not Go Smoothly

The branch was ready locally before the post-#571 main R CMD check finished.
Per CI pacing, the next PR should wait until that main run clears.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: keep the LV arc in narrow, mergeable slices; this one deepens binomial
point/recovery evidence only.

Curie: the test includes DGP diagnostics before fitting so a lucky or separated
Bernoulli sample cannot masquerade as model evidence.

Fisher: recovery is stated for `B_lv` with tolerances; interval calibration is
explicitly absent.

Boole: the formula route remains ordinary unit-tier
`latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x)`.

Grace: local `devtools::check(args = "--no-manual")` passed, but the branch
should wait for main CI before opening the next PR.

Rose: the after-task and check-log preserve the "ordinary C1 partial" boundary
and avoid promoting broad non-Gaussian or interval support.

## 10. Known Limitations And Next Actions

- No Bernoulli interval coverage grid yet.
- No missing-response Bernoulli validation yet.
- No ordinal, Poisson, NB2, Gamma, Beta, or mixed-family interval claim.
- No masks, `X + X_lv`, source-specific `lv`, or phylo R exposure claim.
- Next safest action: wait for the post-#571 main R CMD check to finish, then
  open this branch as the next small PR if it remains clean.
