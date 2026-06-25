# After Task: LV Binary-Probit C1 Admission

**Branch**: `codex/lv-binary-probit-20260625`
**Date**: `2026-06-25`
**Roles (engaged)**: `Ada / Boole / Gauss / Noether / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Admit the first binary response for Design 73 predictor-informed latent
scores without weakening the guardrails. The intended slice is ordinary
unit-tier `latent(..., lv = ~ x)` for pure
`binomial(link = "probit")` fits, with a real trait-scale `B_lv`
recovery/algebra test and honest status updates. Binary logit/cloglog,
ordinal, count, Gamma, Beta, mixed-family, delta/hurdle, intervals, and
Julia bridge parity must remain gated.

## 2. Implemented

- Added `link_id_vec` to `gll_prepare_lv_predictor_setup()` and passed it
  from `R/fit-multi.R`.
- Relaxed the `lv` family guard only for pure binomial-probit fits
  (`family_id_vec == 1L`, `link_id_vec == 1L`). Any mixed family, binary
  logit/cloglog, or other non-Gaussian row still aborts.
- Added a deterministic multi-trial binomial-probit fixture to
  `test-lv-parser-guard.R`.
- The new test checks fit convergence, finite gradients, family/link
  IDs, report-shape algebra, `extract_lv_effects()`, trait-scale
  `B_lv = Lambda alpha^T` recovery, and
  `total = innovation + mean`.
- Updated NEWS, Design 01/03/04/05/06/35/61/73, and
  `man/extract_lv_effects.Rd` to move `LV-05` to partial for
  binomial-probit only.

## 2a. Mathematical Contract

| Layer | Symbolic contract | Implementation / test check |
|---|---|---|
| Latent mean | `z_i = x_i alpha + e_i`, with `e_i` zero-mean | `X_lv_B` is unit-level, `alpha_lv_B` is estimated, and `U_B_total = U_lv_mean_B + z_B` is checked |
| Trait predictor | `eta_it = beta_t + lambda_t z_i` | TMB receives the same shifted latent score before family dispatch |
| Binary likelihood | `y_it ~ Binomial(n_it, Phi(eta_it))` | Admission requires `family_id_vec == 1L` and `link_id_vec == 1L` for every row |
| Trait-scale effect | `B_lv,t = lambda_t alpha` | Test compares extracted/reported `B_lv` to the DGP target within the small-fixture tolerance |
| Unsupported links | logit/cloglog do not share this C1 proof | Default binomial/logit preflight still aborts under `LV-05` |

## 3. Files Changed

Implementation:

- `R/lv-predictor.R`
- `R/fit-multi.R`
- `R/brms-sugar.R`
- `R/extractors.R`

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
- `man/extract_lv_effects.Rd`

Dev-log:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-25-lv-binary-probit-c1.md`

## 3a. Decisions and Rejected Alternatives

Decision: admit only pure binomial-probit, not all binomial links.

Rationale: probit has the clean fixed latent residual scale for the
first binary lane. Logit and cloglog remain useful, but they need their
own recovery/link-scale diagnostics before admission.

Decision: recover `B_lv`, not raw `alpha` or raw `Lambda`.

Rationale: `B_lv = Lambda alpha^T` is the trait-scale, sign-invariant
estimand for a rank-1 predictor-informed latent model. Raw loadings and
axis coefficients remain axis-convention dependent.

Rejected alternative: add a public vignette or README example now.

Rationale: this is a narrow C1 capability gate. Public-facing teaching
should wait until Gaussian recovery, binary depth, and interval status
are clearer.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  -> PASS; no open `gllvmTMB` PRs.
- `git log --all --oneline --since="6 hours ago"`
  -> REVIEWED; no conflicting in-repo edit lane detected.
- `Rscript --vanilla -e 'devtools::test(filter = "^lv-parser-guard$")'`
  -> PASS before docs update; 135 pass, 0 fail, 0 warn, 0 skip.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS; regenerated `man/extract_lv_effects.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "^lv-parser-guard$")'`
  -> PASS after docs/Rd update; 135 pass, 0 fail, 0 warn, 0 skip.
- `Rscript --vanilla -e 'devtools::test(filter = "^(lv-parser-guard|formula-grammar-smoke)$")'`
  -> PASS; 162 pass, 0 fail, 0 warn, 0 skip.
- `air format R/brms-sugar.R R/extractors.R R/lv-predictor.R tests/testthat/test-lv-parser-guard.R`
  -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "^(extractors|extractors-extra|rotate-compare-loadings)$")'`
  -> PASS; 136 pass, 0 fail, 0 warn, 0 skip.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS; no problems found.
- `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`
  -> PASS; all articles rebuilt. The Lambda constraint/profile pages
  were slow because they run optimizer/profile refits; generated
  vignette PNG scratch files were removed from the worktree.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = FALSE, error_on = "never", check_dir = "/private/tmp/gllvmtmb-lv-binary-probit-check")'`
  -> PASS with 0 errors, 1 warning, 1 note. The warning is local
  Apple clang / R header warning-group noise
  (`R_ext/Boolean.h: -Wfixed-enum-extension`) plus Eigen
  unused-variable warnings in `00install.out`; the note is
  `unable to verify current time`. Testthat inside R CMD check was OK
  (`[141s/157s]`).
- `git diff --check`
  -> PASS.

## 5. Tests of the Tests

The binary-probit test uses an explicit alignment table in comments:
`z_i = x_i alpha + e_i`, `eta_it = beta_t + lambda_t z_i`,
`y_it ~ Binomial(n, Phi(eta_it))`, fit by
`cbind(success, failure) ~ 0 + trait + latent(..., lv = ~ x)`.

Acceptance is paired with rejection: binomial-probit preflight is silent,
while the same binary fixture with the default logit link still errors
under `LV-05`. The test also checks the extractor algebra rather than
only construction, so a future report-shape regression should fail.

## 6. Consistency Audit

- `rg -n 'ordinary Gaussian unit-tier|partial / Gaussian C1|non-Gaussian support|LV-05.*remain|planned or blocked rows|Gaussian-only unit-tier|ordinary Gaussian only|non-Gaussian families, unsupported tiers' NEWS.md R docs/design tests/testthat man | head -n 120`
  -> REVIEWED; remaining hits are deliberate Gaussian row labels
  (`LV-01`), broad-gate wording, or the updated `LV-05` partial row.
- `rg -n 'binomial-probit|link_id_vec|family_id_vec|B_lv|LV-05' R/lv-predictor.R R/fit-multi.R R/extractors.R tests/testthat/test-lv-parser-guard.R docs/design/35-validation-debt-register.md NEWS.md`
  -> REVIEWED; hits match the admitted probit path and blocked broader
  family/link claims.

## 7. Roadmap Tick

No ROADMAP row was changed. Validation register row `LV-05` moved from
blocked to partial for pure binomial-probit only.

## 7a. GitHub Issue Ledger

No relevant dedicated Design 73 issue was found or closed in this slice.
The broad capability board remains open; this PR should describe the
specific `LV-05` partial movement rather than close a roadmap issue.

## 8. What Did Not Go Smoothly

`devtools::document()` again rewrote unrelated Rd files. All unrelated
generated churn was removed from the diff; only `man/extract_lv_effects.Rd`
remains because the roxygen text changed in this slice.

Some tiny `sed` / `rg` reads intermittently hung in the desktop shell.
They were interrupted and rerun with narrower commands; no running shell
sessions were left open from those reads.

`pkgdown::build_articles(lazy = FALSE)` completed, but the two Lambda
constraint/profile articles were very slow because they run many
optimizer/profile refits. That is not binary-specific, but it is worth a
future docs-performance slice so routine capability PRs can keep a
strong article gate without spending most of the wall time there.

The full local `R CMD check` finished with 0 errors, 1 warning, and
1 note. The warning came from local Apple clang / R header warning-group
noise and Eigen headers during install; the note was the local
`unable to verify current time` check note.

## 9. Team Learning

Ada kept the scope to one family/link instead of turning on all binary.

Boole's grammar guard remains the key safety rail: one ordinary unit-tier
`latent()` term only, no source-specific or augmented syntax.

Gauss and Noether confirm this slice needs no new likelihood branch:
the score-mean contribution is already before family dispatch, and the
probit observation likelihood reads the same `eta`.

Curie added recovery on the trait-scale target `B_lv`, not just a
construction smoke.

Fisher keeps the inference boundary tight: this is point/recovery
evidence, not interval calibration or CI-08/CI-10 coverage.

Rose updated every nearby status surface touched by the claim so `LV-05`
does not remain described as entirely blocked.

Grace notes that `pkgdown::check_pkgdown()`, full article rebuild, and
full local `devtools::check()` all ran before commit/PR.

Shannon notes GLLVM.jl PR #115 merged cleanly before this R-side branch
opened a PR, preserving the one-open-PR guard.

## 10. Known Limitations And Next Actions

- `LV-05` is partial for pure binomial-probit only.
- Bernoulli single-trial binary depth is still needed; the current
  recovery fixture is multi-trial for information strength.
- Binary logit/cloglog, ordinal, count, Gamma, Beta, mixed-family, and
  delta/hurdle `lv` fits remain blocked.
- No interval calibration, CI-08/CI-10 coverage, missing-response
  compatibility, tier expansion, structured-source expansion, or Julia
  bridge parity is claimed.
- The next R-side slice should either deepen binomial-probit with
  Bernoulli/screening diagnostics or run Gaussian recovery for `B_lv`,
  `Sigma`, and `Psi`.
