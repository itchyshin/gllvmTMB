# After Task: LV Factor Predictor Runtime Gate

**Branch**: `codex/lv-factor-runtime-20260628`
**Date**: `2026-06-29`
**Roles (engaged)**: `Ada / Boole / Noether / Fisher / Curie / Rose / Grace`

## 1. Goal

Move ordinary unit-tier `latent(..., lv = ~ x)` one step closer to V1 by
proving that observed factor-valued LV predictors are not only parsed, but fit
and recover the trait-by-factor effect in a deterministic Gaussian DGP.

The scope is intentionally narrow: ordinary Gaussian, complete responses,
observed complete LV predictors, no extra fixed-effect RHS covariate, no
source-specific covariance term, no intervals, no mixed families, and no phylo
Model A exposure.

## 2. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation change.

The new test exercises this existing ordinary LV model:

- `z_i = X_lv,i alpha + e_i`, with `e_i ~ N(0, 1)`;
- `X_lv,i` is the one-hot habitat design matrix produced by `lv = ~ habitat`;
- `eta_it = beta_t + lambda_t z_i`;
- `y_it ~ Gaussian(eta_it, psi_t)`;
- the recovery target is `B_lv = Lambda alpha^T`, surfaced by
  `extract_lv_effects(type = "trait_effect")`.

This PR does not change parameterisation. It records runtime and recovery
evidence for the existing implementation.

## 3. Implemented

- Added `tests/testthat/test-lv-factor-runtime.R`.
- The test builds a three-trait, three-level factor DGP and fits
  `latent(0 + trait | unit, d = 1, lv = ~habitat)`.
- It checks the internal TMB shapes for `X_lv_B`, `alpha_lv_B`,
  `U_lv_mean_B`, `U_B_total`, and `B_lv_unit`.
- It verifies `B_lv_unit = Lambda_B %*% t(alpha_lv_B)` at report precision.
- It verifies `extract_lv_effects()` returns the expected trait-by-level
  estimates and validation rows.
- It checks score decomposition consistency:
  `total = innovation + mean`.
- It includes a rare-nonempty factor-level smoke test and an empty-level
  rejection test.

## 4. Files Changed

Tests:

- `tests/testthat/test-lv-factor-runtime.R`

Evidence records:

- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-29-lv-factor-runtime.md`

## 4a. Decisions and Rejected Alternatives

Decision: test the estimable `B_lv` target rather than raw `alpha` or
`Lambda`.
Rationale: sign/scale conventions make raw latent parameters fragile, while
`B_lv = Lambda alpha^T` is the user-facing trait-by-predictor estimand.
Rejected alternative: assert raw alpha/Lambda closeness.
Confidence: high.

Decision: keep this as Gaussian ordinary-runtime evidence only.
Rationale: factor predictors need to be banked before broadening into
non-Gaussian families, missing predictors, masks, source-specific covariance,
or interval calibration.
Rejected alternative: combine factor runtime with missing-response or
non-Gaussian tests in one PR.
Confidence: high.

Decision: include rare-level and empty-level tests in the same file.
Rationale: the user-facing factor predictor path should distinguish a rare but
observed level from a rank-deficient empty level before later docs advertise
factor examples.
Rejected alternative: test only balanced factors.
Confidence: medium-high.

## 5. Checks Run

- `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,baseRefName,isDraft,mergeStateStatus,url`
  -> REVIEWED; no open gllvmTMB PRs after PR #573 merged.
- `git log --all --oneline --since="6 hours ago" -- docs/dev-log/check-log.md docs/dev-log/after-task tests/testthat R docs/design/35-validation-debt-register.md`
  -> REVIEWED; recent nearby work was limited to the merged source-specific
  guard and Bernoulli LV depth slices.
- `git fetch origin main`
  -> PASS; fetched current `main`.
- `git rebase origin/main`
  -> PASS; branch rebased cleanly after PR #573.
- `git diff --check origin/main...HEAD`
  -> PASS; no whitespace errors before evidence edits.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-factor-runtime", reporter = "summary")'`
  -> PASS; focused factor-runtime tests completed with no failures.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS; parser guard remained green with the existing informational
  sigma-eps auto-suppression message.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed in 4m45.6s with 0 errors, 0 warnings, and
  0 notes. As in earlier slices, `check()` did not re-document because local
  roxygen2 8.0.0 differs from the declared 7.3.2.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "lv latent factor" --json number,title,state,url,labels --limit 20`
  -> REVIEWED; returned issue #348 only.
- `gh issue view 348 --repo itchyshin/gllvmTMB --json number,title,state,url,labels,body`
  -> REVIEWED; #348 is the non-Gaussian family-validation umbrella and does
  not need a comment or closure for this ordinary Gaussian factor-runtime
  test slice.
- `rg -n "LV-04|factor.*lv|factor.*LV|lv.*factor|predictor-informed|FG-18|RE-13|EXT-31|LV-05" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md ROADMAP.md NEWS.md README.md docs/dev-log/known-limitations.md | head -n 220`
  -> REVIEWED; expected hits are the Design 73 status files, NEWS scope
  boundary, and validation rows. No README, roadmap, or known-limitations
  promotion is required for this test/evidence slice.
- `rg -n "until Bernoulli|Bernoulli single-trial depth,|no Bernoulli single-trial depth|Bernoulli binary depth|factor-predictor runtime smoke" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md`
  -> PASS; no stale pre-PR #572 or pre-factor-runtime wording remains in the
  current status rows.
- `rg -n "LV-04.*(covered|complete|calibrated)|factor-valued.*(covered|complete|calibrated)|factor-valued.*interval|factor-predictor.*(covered|complete|calibrated)|factor-predictor.*interval|source-specific.*factor-valued|phylo.*factor-valued|mixed-family.*factor-valued|non-Gaussian.*factor-valued" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md tests/testthat/test-lv-factor-runtime.R`
  -> REVIEWED; hits are explicit limitations or partial-row boundaries, not
  promoted claims.
- `Rscript --vanilla /Users/z3437171/shinichi-brain/tools/check-after-task.R docs/dev-log/after-task/2026-06-29-lv-factor-runtime.md`
  -> PASS; validator returned successfully.
- `git diff --check`
  -> PASS; no whitespace errors after evidence edits.

## 6. Tests of the Tests

This test would fail if factor LV predictors stopped fitting, if the one-hot
factor design columns were dropped or renamed, if `B_lv_unit` no longer matched
`Lambda_B %*% t(alpha_lv_B)`, if `extract_lv_effects()` stopped surfacing the
trait-by-level target, if the total/mean/innovation score decomposition drifted,
or if empty factor levels slipped past preflight into fitting.

## 7. Consistency Audit

- `rg -n "lv\\s*=\\s*~\\s*habitat|factor predictor|factor-valued|B_lv|LV-04" tests/testthat/test-lv-factor-runtime.R docs/dev-log/after-task/2026-06-29-lv-factor-runtime.md`
  -> REVIEWED; expected hits are confined to the new test and evidence
  records.
- `rg -n "factor.*support|complete|coverage|interval|non-Gaussian|mixed-family|source-specific|phylo" tests/testthat/test-lv-factor-runtime.R docs/dev-log/after-task/2026-06-29-lv-factor-runtime.md`
  -> REVIEWED; broad support/completion words appear only in explicit scope
  boundaries and limitations.
- `rg -n "LV-04|factor.*lv|factor.*LV|lv.*factor|predictor-informed|FG-18|RE-13|EXT-31|LV-05" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md ROADMAP.md NEWS.md README.md docs/dev-log/known-limitations.md | head -n 220`
  -> REVIEWED; factor-runtime evidence is present in the validation register
  and capability-status synthesis. Public NEWS remains bounded to the existing
  Design 73 scope statement and row IDs.
- `rg -n "until Bernoulli|Bernoulli single-trial depth,|no Bernoulli single-trial depth|Bernoulli binary depth|factor-predictor runtime smoke" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md`
  -> PASS; the stale Bernoulli-pending and factor-runtime-pending phrases are
  gone from current status rows.
- `rg -n "LV-04.*(covered|complete|calibrated)|factor-valued.*(covered|complete|calibrated)|factor-valued.*interval|factor-predictor.*(covered|complete|calibrated)|factor-predictor.*interval|source-specific.*factor-valued|phylo.*factor-valued|mixed-family.*factor-valued|non-Gaussian.*factor-valued" docs/design/35-validation-debt-register.md docs/design/61-capability-status.md tests/testthat/test-lv-factor-runtime.R`
  -> REVIEWED; all hits keep factor support partial or name limitations.

## 8. Roadmap Tick

No public roadmap row is promoted. This branch changes the LV arc evidence
ledger from local queued-ready to mergeable factor-predictor runtime evidence
only after CI is green.

## 8a. GitHub Issue Ledger

`gh issue list --repo itchyshin/gllvmTMB --state open --search "lv latent factor"
--json number,title,state,url,labels --limit 20` returned issue #348 only.
`gh issue view 348 --repo itchyshin/gllvmTMB --json number,title,state,url,labels,body`
showed #348 is the non-Gaussian family-validation umbrella, so it is not
advanced, commented, or closed by this ordinary Gaussian factor-runtime test
slice. No new issue was created; the slice is tracked through the check-log,
after-task report, and mission-control LV board.

## 9. Documentation And Pkgdown

No roxygen, generated Rd, vignette, README, NEWS, or `_pkgdown.yml` files
changed. The validation-debt register and capability-status synthesis were
updated to record the new evidence and to remove stale Bernoulli-pending
wording after PR #572. `devtools::document()` and `pkgdown::check_pkgdown()`
were therefore not run locally for this test/design-evidence branch.

## 10. What Did Not Go Smoothly

Nothing substantive. The branch was behind main by the Bernoulli and
source-specific guard slices, but rebased cleanly.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

Ada: this is a useful forward slice because it turns factor LV predictors into
runtime evidence without bundling adjacent missingness or family work.

Boole: formula syntax stays ordinary and memorable:
`latent(0 + trait | unit, d = 1, lv = ~habitat)`.

Noether: the test pins the symbolic target to the implementation identity
`B_lv_unit = Lambda_B %*% t(alpha_lv_B)`.

Fisher: the recovery claim is point recovery only; interval calibration and
coverage remain outside this slice.

Curie: the rare-level and empty-level cases make the test more useful than a
single balanced DGP while staying small enough for routine checks.

Grace: focused tests and full local R CMD check passed after rebase; the PR is
ready for the one-open-PR lane.

Rose: the report keeps factor support bounded to the tested regime and names
the missing regimes before they can leak into public prose.

## 12. Known Limitations And Next Actions

- No interval coverage is claimed for factor predictors.
- No non-Gaussian, mixed-family, missing-predictor, missing-response, mask,
  `X + X_lv`, source-specific, or phylo Model A factor-predictor support is
  claimed.
- Next safest action: run the consistency scans and after-task validator, open
  this as the next PR, monitor CI, merge only if GitHub R-CMD-check is green,
  then update mission control.
