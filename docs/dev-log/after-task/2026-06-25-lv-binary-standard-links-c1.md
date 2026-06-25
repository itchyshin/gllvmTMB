# After Task: LV Binary Standard-Link C1 Admission

**Branch**: `codex/lv-binary-links-20260625`
**Date**: `2026-06-25`
**Roles (engaged)**: `Ada / Boole / Gauss / Noether / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Broaden the Design 73 binary `latent(..., lv = ~ x)` C1 lane from
pure binomial-probit to the full set of standard binary links already
used by `gllvmTMB`: logit, probit, and cloglog. The slice must keep the
capability row honest: ordinary unit-tier only, pure binomial only,
multi-trial point/recovery evidence only, and no interval, Bernoulli,
mixed-family, Julia, DRAC, or production-simulation claim.

## 2. Implemented

- Relaxed the `lv` family/link guard to admit pure `binomial()` fits
  with `link_id` in `0, 1, 2`: logit, probit, and cloglog.
- Generalized the binary fixture in `test-lv-parser-guard.R` so each
  link has its own deterministic DGP, inverse link, seed, intercepts,
  convergence/gradient gate, and latent-predictor trait-effect
  (`B_lv`) tolerance.
- Kept the likelihood path unchanged. The already-implemented score
  mean is added before family dispatch, so the same TMB path feeds the
  existing binomial link likelihoods.
- Updated `extract_lv_effects()` so binary `lv` tables report
  `validation_row = "EXT-31; LV-05"` while Gaussian tables continue to
  report `EXT-31; LV-01`.
- Updated NEWS and Design 01/03/04/05/06/35/61/73 to describe the
  pure-binomial standard-link C1 surface and keep all broader rows
  gated.

## 2a. Mathematical Contract

| Layer | Symbolic contract | Implementation / test check |
|---|---|---|
| Latent mean | `z_i = x_i alpha + e_i`, with `e_i` zero-mean | `X_lv_B` is unit-level, `alpha_lv_B` is estimated, and `U_B_total = U_lv_mean_B + z_B` is checked |
| Trait predictor | `eta_it = beta_t + lambda_t z_i` | TMB receives the shifted score before family dispatch |
| Binary likelihood | `y_it ~ Binomial(n_it, g^{-1}(eta_it))` | Test loops over `g^{-1}` equal to logit, probit, and cloglog inverse links |
| Latent-predictor trait effect | `B_lv,t = lambda_t alpha` | Test compares `extract_lv_effects(type = "trait_effect")` to the DGP target for each link |
| Row label | binary `lv` is `LV-05`; Gaussian `lv` is `LV-01` | Extractor tests assert `EXT-31; LV-05` for binary and `EXT-31; LV-01` for Gaussian |

This PR does not change the binomial likelihood parameterisation,
random-effect prior, or any TMB C++ family code. It only admits and
tests existing binary links on the Design 73 score-mean path.

## 3. Files Changed

Implementation:

- `R/lv-predictor.R`
- `R/extractors.R`
- `R/brms-sugar.R`

Tests:

- `tests/testthat/test-lv-parser-guard.R`

Documentation and status:

- `NEWS.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/04-random-effects.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`

Dev-log:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-25-lv-binary-standard-links-c1.md`

No generated Rd file changed. The extractor schema did not change; only
the per-fit `validation_row` value became family-aware.

## 3a. Decisions and Rejected Alternatives

Decision: admit all three standard binary links together.

Rationale: `src/gllvmTMB.cpp` already dispatches logit, probit, and
cloglog binomial likelihoods from the same linear predictor. Once the
Design 73 score-mean contribution is upstream of family dispatch,
probit-only admission was unnecessarily narrow for the binary C1 lane.

Decision: keep the fixture multi-trial rather than Bernoulli.

Rationale: multi-trial counts give enough information for a CRAN-safe
small recovery/algebra gate. Single-trial Bernoulli depth remains a
separate `LV-05` follow-up because separation and weak information need
their own diagnostics.

Rejected alternative: update README/pkgdown tutorials now.

Rationale: this is still a C1 point/recovery gate. A public worked
article should wait until Gaussian recovery, Bernoulli binary depth, and
interval status are less fragile.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS; no open `gllvmTMB` PRs.
- `git log --all --oneline --since='6 hours ago' -- docs/design docs/dev-log/check-log.md docs/dev-log/after-task R tests NEWS.md | head -50`
  -> REVIEWED; only the merged probit slice touched this lane.
- `air format R/extractors.R tests/testthat/test-lv-parser-guard.R`
  -> PASS; no output.
- `Rscript --vanilla -e 'parse("R/lv-predictor.R"); parse("R/extractors.R"); parse("tests/testthat/test-lv-parser-guard.R"); cat("parse ok\n")'`
  -> PASS; parsed cleanly.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); pkgload::load_all(".", helpers = FALSE, attach_testthat = TRUE, quiet = TRUE); testthat::test_file("tests/testthat/test-lv-parser-guard.R")'`
  -> PASS; 185 pass, 0 fail, 0 warn, 0 skip.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); pkgload::load_all(".", helpers = FALSE, attach_testthat = TRUE, quiet = TRUE); testthat::test_file("tests/testthat/test-extractors.R")'`
  -> PASS; 17 pass, 0 fail, 0 warn, 0 skip.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); pkgload::load_all(".", helpers = FALSE, attach_testthat = TRUE, quiet = TRUE); testthat::test_file("tests/testthat/test-multi-trial-binomial.R"); testthat::test_file("tests/testthat/test-m2-2a-binary-recovery.R")'`
  -> PASS/expected skips; multi-trial binomial 5 pass, 3 CRAN skips;
  M2.2a binary recovery 5 expected heavy skips.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); pkgload::load_all(".", helpers = FALSE, attach_testthat = TRUE, quiet = TRUE); cat("pkgload ok\n")'`
  -> PASS.
- `R CMD build --no-build-vignettes .`
  -> PASS; built `gllvmTMB_0.2.0.tar.gz`, then the tarball was moved to
  `/private/tmp/gllvmtmb-binary-links-check-current/`.
- `R_LIBS=/private/tmp/gllvmtmb-install-lib-4.6:/private/tmp/gllvmtmb-r-lib-4.6:/Library/Frameworks/R.framework/Versions/4.6/Resources/library R_LIBS_USER=/private/tmp/gllvmtmb-empty-r-user-lib R CMD check --no-manual --no-build-vignettes /private/tmp/gllvmtmb-binary-links-check-current/gllvmTMB_0.2.0.tar.gz`
  -> BLOCKED; local R 4.6.0 segfaulted during `checking package
  namespace information`, before package tests, through
  `requireNamespace("gllvm", quietly = TRUE)` and TMB namespace loading.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); if (!requireNamespace("pkgdown", quietly = TRUE)) stop("pkgdown not available in this R library stack"); pkgdown::check_pkgdown()'`
  -> BLOCKED; `pkgdown` is not installed in the active R 4.6 library stack.
- `R_LIBS=/private/tmp/gllvmtmb-r-lib-4.6 Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-r-lib-4.6", .libPaths())); if (!requireNamespace("devtools", quietly = TRUE)) stop("devtools not available in this R library stack"); devtools::test(filter = "^lv-parser-guard$")'`
  -> BLOCKED; `devtools` is not installed in the active R 4.6 library stack.
- `git diff --check`
  -> PASS.

## 5. Tests of the Tests

The new binary-link test is not just a parser admission check. It fits
three deterministic multi-trial binomial models, one each for logit,
probit, and cloglog, and verifies convergence, link IDs, finite report
shapes, finite gradients, `B_lv = Lambda alpha^T` recovery, and
`total = innovation + mean`.

The test keeps a negative boundary too: invalid link id `3` and mixed
binomial/non-binomial family vectors still abort under `LV-05`. That
guards against accidentally converting `LV-05` into broad non-Gaussian
admission.

## 6. Consistency Audit

- `rg -n 'pure binomial-probit|binomial-probit is admitted|binary logit/cloglog|logit/cloglog.*blocked|unsupported non-Gaussian families/links|other non-Gaussian links/families|probit only|binomial-probit only|single-family binomial\(link = "probit"\)' NEWS.md R docs/design tests/testthat/test-lv-parser-guard.R`
  -> PASS; no stale probit-only wording remains in the touched Design
  73 surfaces.
- `rg -n "binomial-probit|logit/probit/cloglog|standard binary links|standard-link binary|LV-05|validation_row" NEWS.md R docs/design tests/testthat/test-lv-parser-guard.R | head -220`
  -> REVIEWED; remaining `binomial-probit` hits are older unrelated
  binary/slope design history or existing binary completeness docs, not
  new Design 73 `lv` overclaims.
- `rg -n "validation_row = \"EXT-31; LV-01\"|validation_row = \"EXT-31; LV-05\"|LV-05" R/extractors.R tests/testthat/test-lv-parser-guard.R docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md`
  -> PASS; binary extractor rows are tested as `LV-05`, Gaussian rows as
  `LV-01`, and the validation register carries the matching partial row.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. Validation register row `LV-05` remains
`partial`, but its admitted C1 surface widened from pure
binomial-probit to pure binomial logit/probit/cloglog.

## 7a. GitHub Issue Ledger

- `gh issue list --repo itchyshin/gllvmTMB --state open --search "latent lv OR predictor-informed OR latent-score" --json number,title,state,url,updatedAt --limit 20`
  -> REVIEWED; broad capability/simulation issues only:
  #340, #346, #348, #349, #526, and #230.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "LV-05 OR binary OR binomial logit probit cloglog" --json number,title,state,url,updatedAt --limit 20`
  -> REVIEWED; broad roadmap/support issues only:
  #340, #341, #343, #348, #332, and #437.

No relevant dedicated Design 73 binary-link issue was found or closed.
No new issue was created because the remaining follow-ups are already
captured in the validation register rows and broad capability board.

## 8. What Did Not Go Smoothly

`R CMD check` remains blocked in the local R 4.6 stack by a segfault
during namespace parsing, before package tests run. The traceback goes
through `requireNamespace("gllvm", quietly = TRUE)` and TMB namespace
loading. This is not evidence against the binary-link change, but it
means CI must provide the broad package check for this PR.

The active R 4.6 library stack did not have `devtools` or `pkgdown`.
Rather than installing a broad developer stack mid-slice, the local
evidence used `pkgload` plus `testthat::test_file()` for focused
source-tree tests, and recorded the blocked commands explicitly.

One stale-wording `rg` attempt used shell backticks in the pattern and
triggered command substitution. It was rerun with a safe literal pattern;
the reproducible pattern is recorded above.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the patch to one capability row: pure-binomial standard links
for ordinary unit-tier `lv`, not broader non-Gaussian admission.

Boole's grammar check remains unchanged: only ordinary unit-tier
`latent()` can carry `lv`, and non-ordinary/source/kernel forms still
fail before metadata can be dropped.

Gauss and Noether confirmed no new likelihood branch was needed because
the `lv` score mean enters `eta` before existing binomial link dispatch.
The math contract is therefore link-scale `B_lv`, not response-scale
probability effects.

Curie made the binary fixture link-parametric instead of copy-pasting a
probit test three times. That keeps the recovery target identical while
letting each link choose stable intercepts and tolerances.

Fisher kept the inference boundary tight: this is point/recovery
evidence for multi-trial fixtures, not interval calibration, Type-I
error, CI-08/CI-10, or single-trial Bernoulli depth.

Grace recorded the local broad-check blocker and the missing
`devtools`/`pkgdown` stack instead of treating targeted tests as a full
package check.

Rose caught the row-label mismatch in `extract_lv_effects()` so binary
tables now point to `LV-05` rather than hiding under the Gaussian
`LV-01` label.

Shannon confirmed no open `gllvmTMB` PR before this branch and no
same-file collision beyond the already-merged probit slice.

## 10. Known Limitations And Next Actions

- `LV-05` is still partial: pure binomial logit/probit/cloglog only.
- Bernoulli single-trial binary depth remains the next binary-specific
  validation need.
- No interval calibration, CI-08/CI-10 coverage, missing-response
  compatibility, factor-predictor runtime recovery, other non-Gaussian
  family support, mixed-family support, tier/source expansion, or Julia
  bridge parity is claimed.
- The next R-side scientific slice should choose between Bernoulli
  binary depth and Gaussian recovery for `B_lv`, `Sigma`, and `Psi`.
