# After Task: Named-kernel Psi SD prior, isolated implementation phase

**Branch**: integration branch `codex/psi-sd-prior-integration-20261119` at current-main base `aa3f3566c9ce996dd7b4c7da8f6d57f56dcce561`; original worktree `codex/psi-sd-prior-20261119` is preserved
**Date**: 2026-11-19
**Roles (engaged)**: Fisher, Curie, Pat, Rose, Gauss, Noether

## 1. Goal

Implement an opt-in prior for selected trait-specific Psi entries in named kernel covariance tiers. The target class is `unique_variance`, and the prior measure is `natural_sd`, meaning density on `sqrt(Psi[t,t])`. The log-SD optimizer evaluates that density without a Jacobian. The objective oracle and derivative checks are included. PR #1841 is open. Its initial three-platform checks failed on two integration issues; local fixes now pass the targeted tests, but the corrected commit still needs full CI before merge.

## 2. Implemented

`gllvmTMBcontrol(kernel_psi_sd_prior = ...)` accepts a data frame with `kernel`, `trait`, and positive `scale` columns. It applies an independent HalfNormal prior to the selected natural standard deviations `sqrt(Psi[t,t])` in the native TMB Gaussian identity-link ML Laplace route. The target is selected by named kernel and trait, supports single-kernel and multi-kernel fits, and leaves omitted kernel-trait pairs unpenalized. The objective decomposition and estimator provenance distinguish this penalty from fixed-effect priors and loading ridge penalties.

The deterministic Gaussian fit checks now separate an interior target from a zero-boundary target. The interior case uses true trait_2 variance 0.36; the selected trait_2 estimate was 0.115 in the recorded run, and the fit converged without a near-zero flag. The boundary case sets the target trait_2 variance to zero; the fit converges, returns Psi variance 1.51e-15 (SD about 3.9e-8), and reports `near_zero_sd_phy_diag`. This confirms the HalfNormal prior still permits a near-zero estimate. These small seeded fits are integration checks, not broad parameter-recovery evidence.

KER-03B remains `partial`. The HalfNormal density is on the natural SD, with no log-SD density Jacobian. For optimizer coordinate `eta = log(sigma)`, the objective contributions are `sigma^2/(2*scale^2)` plus the normalized HalfNormal constant, the gradient is `sigma^2/scale^2`, and the Hessian is `2*sigma^2/scale^2`. The HalfNormal mode is zero, so this choice does not prevent estimates near zero and is not a Heywood-case remedy.

## 3. Mathematical Contract

For each selected named kernel `k` and trait `t`, the target is `sigma[k,t] = sqrt(Psi[k,t,t])`. The prior density with respect to this natural standard deviation is `p(sigma | s) = sqrt(2/pi) / s * exp(-sigma^2 / (2*s^2))` for `sigma >= 0`, where `s` is the positive response-scale value supplied in the control table. The optimizer uses `eta = log(sigma)`, so the objective adds `sigma^2 / (2*s^2) + log(s) + 0.5*log(pi/2)` and does not add a log-SD Jacobian. The derivatives with respect to `eta` are `sigma^2/s^2` and `2*sigma^2/s^2`. This matches the natural-SD measure recorded as `measure = natural_sd` and target class `unique_variance`.

## 4. Files Touched

- R implementation and fit reporting: `R/kernel-psi-sd-priors.R`, `R/gllvmTMB.R`, `R/fit-multi.R`, `R/fixed-effect-priors.R`, `R/methods-gllvmTMB.R`, `R/standard-errors.R`, `R/vcov-coef.R`, `R/aghq-report.R`.
- Tests: `tests/testthat/test-psi-sd-priors.R`, `tests/testthat/test-loading-ridge-disclosure.R` (warning assertion updated to match the emitted MAP/AIC disclosure).
- Validation and limitation records: `docs/design/35-validation-debt-register.md`, `docs/dev-log/known-limitations.md`.
- Help: `man/gllvmTMBcontrol.Rd`, `man/standard_errors.Rd`, `man/gllvmTMB_multi-vcov.Rd`, `man/tidy.gllvmTMB_multi.Rd`.
- Task records: `docs/dev-log/check-log.d/2026-11-19-kernel-psi-sd-prior.md`, `docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md`.
- Recovery records: `docs/dev-log/recovery-checkpoints/2026-11-19-codex-psi-prior-checkpoint.md`, `docs/dev-log/recovery-checkpoints/2026-11-19-164509-codex-integration-checkpoint.md`, `docs/dev-log/recovery-checkpoints/2026-11-19-165443-codex-integration-checkpoint.md`.

Example files touched: the `gllvmTMBcontrol()` roxygen examples in `R/gllvmTMB.R` and the regenerated `man/gllvmTMBcontrol.Rd`. The examples contain both long-format and wide `traits(...)` calls. `man/standard_errors.Rd` was regenerated with the help update. No README, other roxygen examples, vignette, article, NEWS, ROADMAP, or formula grammar file changed. No standalone article was warranted because the control help already contains runnable long- and wide-format examples and no new exported topic or navigation entry was added. The public help states the supported route and limits; the design row is KER-03B.

## 3a. Decisions and Rejected Alternatives

- **Decision:** define the density on natural `sqrt(Psi[t,t])` and include the normalized HalfNormal density in the MAP objective. **Rationale:** the user asked for standard-deviation priors, and this parameter is optimized as log SD. **Rejected:** silently treating a prior on variance as a prior on SD, or omitting the normalizing constant. **Confidence:** high for the implemented target and derivatives; inference calibration is untested.
- **Decision:** keep the prior on a named-kernel route and separate from loading ridge and fixed-effect priors. **Rationale:** these are distinct parameter targets and optimization penalties. **Rejected:** reuse of the loading-ridge or fixed-effect-prior controls. **Confidence:** high for the stated route.
- **Decision:** represent the target as `unique_variance` with explicit measure `natural_sd` in the shared prior contract. **Rationale:** the target class identifies the Psi diagonal while the requested density is on its positive square root. **Rejected:** infer the density scale from the target class alone or silently switch to a natural-variance density. **Confidence:** high for this chosen target and density measure; cross-package integration remains unverified.
- **Decision:** do not add a separate public article in this phase. **Rationale:** the reference help already contains runnable long- and wide-format examples, while `_pkgdown.yml` has active competing edits and cannot be safely changed here. Revisit an article when navigation ownership clears or the shared prior schema is settled.

## 5. Checks Run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`: passed and regenerated `man/gllvmTMBcontrol.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|fixed-effect-priors", reporter = "summary")'`: passed, zero failures after the revised fixture.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: passed with no pkgdown problems. Pandoc emitted its existing `--mathml` deprecation warning.
- `git diff --check`: passed.
- `python3 /Users/z3437171/shinichi-brain/tools/slop_check.py /Users/z3437171/.codex/worktrees/psi-sd-prior-gllvmTMB/docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md`: passed with zero findings and zero em dashes.
- `python3 /Users/z3437171/shinichi-brain/tools/slop_check.py /Users/z3437171/.codex/worktrees/psi-sd-prior-gllvmTMB/docs/dev-log/check-log.d/2026-11-19-kernel-psi-sd-prior.md`: passed with zero findings and zero em dashes.
- `Rscript --vanilla -e 'res <- devtools::check(args = "--no-manual", quiet = TRUE); print(res)'`: ran for 42m 3.2s before the final provenance/help correction and revised fixture. It reported 30,970 passes, 1,252 skips, and two visual snapshot failures, with one R CMD check error, zero check warnings, and one NOTE for `TMB:::EvalADFunObject`. The same two snapshot failures at `test-plot-visual-snapshots.R:301` and `:353` were reproduced on clean base `0d065c398510dcdd0df3079eff0de36d78402202`; the latest focused tests passed after the revised fixture.
- `gh pr list --state open --limit 100 --json number,title,headRefName,url`: inspected current open PRs. NEWS has active owners including #1837, #1836, #1835, #1833, #1832, and #1820; no NEWS edit was made.
- `gh issue list --state open --search 'Psi prior' --limit 30 --json number,title,url`, `gh issue list --state open --search 'kernel prior' --limit 30 --json number,title,url`, and `gh issue list --state open --search 'unique_sd' --limit 30 --json number,title,url`: no issue specifically tracks this prior. Issue [#1816](https://github.com/itchyshin/gllvmTMB/issues/1816) was read; it requires any boundary-focused estimator to be separately targeted and validated, and confirms this non-Gaussian future work is outside the current Gaussian slice. Issue [#361](https://github.com/itchyshin/gllvmTMB/issues/361) was read as the kernel-engine umbrella; no issue was created or updated.

## 6. Tests of the Tests

The resolver tests exercise valid single-kernel and multi-kernel indices, including a Psi-disabled first kernel followed by a Psi-enabled target kernel, plus unknown kernel, unknown trait, missing Psi, invalid scale, and duplicate-target rejections. Route tests check the no-prior acceptance path, reject the Julia engine, and reject a combined loading penalty. The two-kernel fit combines structural missingness with separate objective reporting, estimator provenance, and the AIC warning. The seeded interior fit checks convergence and an estimated target SD above the near-zero threshold. The zero-boundary fit checks convergence, an estimated target SD below that threshold, and the matching boundary diagnostic. Both confirm that the prior is applied. These tests cover malformed inputs, a feature combination, and a boundary case; no test was demonstrated failing before an implementation fix. They do not establish broad recovery or calibrated uncertainty.

## 8. Consistency Audit

Exact patterns and verdicts from the check log:

- `rg -n 'kernel_psi_sd_prior|half-normal|HalfNormal|natural_standard_deviation|natural SD' R/kernel-psi-sd-priors.R R/gllvmTMB.R R/fit-multi.R tests/testthat/test-psi-sd-priors.R man/gllvmTMBcontrol.Rd docs/design/35-validation-debt-register.md`: target, scale, MAP, and scope limits agree across implementation, test, help, and KER-03B.
- `rg -n '\bS_B\b|\bS_W\b|\\bf S' R/gllvmTMB.R man/gllvmTMBcontrol.Rd docs/design/35-validation-debt-register.md`: no legacy S/U notation in the changed user-facing text.
- `rg -n 'gllvmTMB\(' R/gllvmTMB.R`: the prior examples include long and wide calls, and the long call supplies `trait = "trait"`.
- `rg -n '\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(' R/gllvmTMB.R man/gllvmTMBcontrol.Rd`: no deprecated keyword alias in the new help example.
- `rg -n 'in prep|in preparation' R/gllvmTMB.R man/gllvmTMBcontrol.Rd`: no in-preparation citation in the changed help.
- `rg -n 'meta_known_V' R/gllvmTMB.R man/gllvmTMBcontrol.Rd`: one existing general cross-reference remains; the new example does not use it.
- `rg -n 'gllvmTMB_wide' R/gllvmTMB.R man/gllvmTMBcontrol.Rd`: existing general help references remain; the new example uses `traits(...)`.
- `rg -n 'penalised fit|loading ridge or prior|kernel-Psi|named-kernel Psi SD prior|fixed-effect normal priors' R/aghq-report.R R/vcov-coef.R R/methods-gllvmTMB.R man/gllvmTMB_multi-vcov.Rd man/tidy.gllvmTMB_multi.Rd`: verified that the AIC/BIC warning and `vcov()` and `tidy()` descriptions cover kernel-Psi priors and local curvature limits.
- `rg -n 'recovers an interior|recovery fixture|recovery checks|n_species = 12|n_species = 10|runs on a replicated' tests/testthat/test-psi-sd-priors.R docs/dev-log/check-log.d/2026-11-19-kernel-psi-sd-prior.md docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md`: found the smoke-test title and no stale recovery-test title or 12-species claim.
- `rg -n 'KER-03B|kernel_psi_sd_prior|unique_sd|kernel.*prior|Psi.*prior' README.md ROADMAP.md NEWS.md docs/design/35-validation-debt-register.md docs/dev-log/known-limitations.md _pkgdown.yml`: the register and known-limitations note carry the partial status; no README, roadmap, NEWS, or pkgdown-navigation entry currently claims broader support.

Rose pre-publish audit returned PASS after it caught and corrected stale `unique_sd` wording in the known-limitations note. The local class and measure are `unique_variance` and `natural_sd`; cross-package prior-schema integration is still unverified. The exact current-main audit patterns and outcomes are recorded in the current-main section of the check log.

Status inventory: `README.md`, `ROADMAP.md`, and `_pkgdown.yml` were not changed; `NEWS.md` was left untouched because of concurrent ownership; `docs/dev-log/known-limitations.md` and KER-03B were updated. `gllvmTMBcontrol()` gained one opt-in argument; no existing argument name, default, formula keyword, or formula grammar changed. The new argument is documented in its roxygen and generated help examples. Existing examples that do not use the optional prior need no syntax update. The audited README Tiny example, keyword grid, and formula grammar remain unchanged.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed.

## 7a. Issue Ledger

No relevant open issue specifically tracks the named-kernel Psi SD prior. Search terms and results are recorded in Section 4. Issue #1816 was inspected for the boundary-estimator scope and validation requirements; issue #361 was inspected as the kernel-engine umbrella. No issue was created, commented on, closed, or edited.

## 9. What Did Not Go Smoothly

The temporary-worktree route helper returned no LOAD-FIRST manifest. Repository instructions and the dedicated worktree's Git state were used as the technical record. Curie's review showed that the first 24-species fixture exceeded the small-test recommendation and its recovery wording was too strong. The final fixture uses 10 species and is explicitly a smoke test. It does not claim recovery from the observed estimates.

## 11. Team Learning

**Fisher:** confirmed the natural-SD density, log-SD derivatives, kernel parameter offsets, and the distinction between local curvature and calibrated intervals. The HalfNormal mode at zero remains a material limit for any claim about near-zero Psi estimates.

**Curie:** confirmed the DGP and extractor alignment, then correctly challenged the recovery claim because the selected Psi estimate was 0.209 for truth 0.36 and another variance reached zero. The final test uses 10 species, a smoke-test title, and finite output assertions without claiming recovery.

**Pat:** found no blocking confusion in the help example and recommended showing multiple prior scales if a sensitivity article is added. The current example remains a usage example, not evidence of prior-scale robustness.

**Rose:** caught incorrect fixed-effect-prior provenance on kernel-only fits and missing wording about penalty conflicts. Both were corrected and rechecked before this test revision. KER-03B and known limitations now state the exact route and incomplete boundaries.

**Gauss:** found that AIC/BIC, `vcov()`, and `tidy()` prose omitted the kernel-Psi prior even though those paths handle it. The warning and help descriptions were corrected and regenerated; the focused test, documentation build, pkgdown check, and Gauss recheck pass.

**Noether:** confirmed the natural-SD math and single/multi-kernel indexing, then identified the missing case where a Psi-disabled kernel precedes a Psi-enabled kernel. A focused resolver assertion now covers that offset, and Noether confirmed the assertion.

**Memory receipt:** the canonical operating contract and efficiency procedure were read. Brain search surfaced the explicit requirement to treat Psi as a separate prior target and settle its natural scale and Jacobian. The repository `route.py` did not find a project manifest for this temporary worktree. The Golden Set was not run because this continuation added prior-specific objective and boundary checks and changed no existing shared guard class.

## 10. Known Residuals

1. **Implementation on main and three-OS CI:** not met. PR #1841 is open. Initial CI on its first head failed; the follow-up fixes pass locally and await push and exact-head CI. The code is not merged on `main`.
2. **Simulation recovery:** not met. The deterministic interior and zero-boundary smoke tests do not constitute a parameter-recovery campaign.
3. **Documentation:** Roxygen and generated help include long and wide examples and scope limits. No separate article or release note was added; preflight found 55 refs with `_pkgdown.yml` changes absent from this worktree, so navigation ownership remains unresolved.
4. **Runnable user example:** present in the `gllvmTMBcontrol()` help examples.
5. **Check log:** present with exact commands, exact `rg` patterns, outcomes, and work not run.
6. **Review:** Fisher, Curie, Pat, Rose, Gauss, and Noether engaged. Their scoped findings have been addressed and rechecked; no C++ likelihood or formula grammar changed.

### Limitations and carry-forward

The feature is opt-in and limited to native TMB Gaussian identity-link ML Laplace fits with named-kernel Psi. It does not support non-Gaussian models, Julia, REML, MSPL, AGHQ, VA, structured source attenuation, profile or bootstrap inference, or combinations with fixed-effect priors and loading penalties. Local approximate curvature is not a calibrated interval. The HalfNormal prior does not push estimates away from zero. No broad simulation recovery, interval coverage, Julia parity, merge, release, or passing three-OS CI is established. PR #1841 is open with local follow-up fixes awaiting exact-head validation.

The final focused prior, fixed-effect-prior, and loading-ridge disclosure tests passed. `pkgdown::check_pkgdown()` passed. The full package check completed in 42m 30.6s with 30,990 passes, 1,252 skips, 70 test warnings, and two visual snapshot failures at `test-plot-visual-snapshots.R:301` and `:353`; both failures reproduce on clean base `0d065c398510dcdd0df3079eff0de36d78402202`. Code, documentation, compilation, and examples passed. The check also reported one NOTE for `TMB:::EvalADFunObject`. The closeout compiler found three unrelated unmet `.unlazy` acceptance ledgers and blocked overall closeout; these belong to other work and were left untouched.

The generalized-prior lane confirmed `unique_variance` as the shared target and `natural_sd` as the explicit measure for the requested prior. This local named-kernel API implements that target and measure without editing or integrating into the lane's active four-package branch. Julia bridge parity, interval calibration, broad recovery, and cross-package integration remain unverified. Overall goal remains active.

The follow-up full package check after adding public `target_class` and `measure` fit metadata completed in 42m 22.8s. It reported 30,992 passes, 1,252 skips, 70 test warnings, and the same two visual snapshot failures at `test-plot-visual-snapshots.R:301` and `:353`, previously reproduced on the clean base. R CMD check reported one error from those failures, zero check warnings, and one NOTE for `TMB:::EvalADFunObject`. The focused prior, fixed-effect-prior, and loading-ridge disclosure suite passed after the metadata assertions. This does not resolve the full-check gate or the outstanding main-branch, Julia, recovery, interval-calibration, and ownership gates.

## 12. Cross-Product Coverage

**Covers:** native TMB, Gaussian identity-link, ML with Laplace integration, `REML = FALSE`, named-kernel `kernel_latent(..., unique = TRUE)`, and selected natural SDs `sqrt(Psi[t,t])`. Tests cover single- and multi-kernel indexing, including a later kernel after an earlier kernel without Psi.

**Does NOT cover:** Julia, non-Gaussian families, REML, MSPL, AGHQ, variational approximation, other covariance sources or grouping levels, integration into the generalized cross-package prior table, fixed-effect/loading penalty combinations, profile or bootstrap inference, calibrated intervals, or broad recovery/coverage. These routes remain unsupported or unverified and are not advertised as part of this slice.

## 13. PR #1841 integration and CI follow-up: 2026-11-19

The implementation is on branch `codex/psi-sd-prior-integration-20261119`, with PR #1841 at initial head `e2f468f260b9b0af368f88ca12cfe5ad643b1019`. The first full three-platform run and the four Ubuntu PR shards exposed two causes: the two new internal Psi-prior errors raised the bare-abort count from 770 to 772, and the capability-status generator had no mapping for KER-03B.

I added next-step advice to both internal errors, returning the count to 770. I added KER-03B to the generator as an R-only, scope-limited MAP sensitivity, then regenerated `docs/design/capability-status.md`: 82 rows, 255 mapped register rows, 37 unmapped by design, and zero unexpected unmapped rows. The generator check passed.

`Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|gapclose-parity-ledger|gapclose-next-steps", reporter = "summary")'` passed with zero failures. The expected penalised-MAP `logLik()` warning appeared. The previous CI runs remain failures on the initial head and do not validate these follow-up changes. The corrected files are local and uncommitted; full package checks and three-platform CI must pass on the new PR head before merge.

KER-03B remains `partial`. The mapping note explicitly says Julia parity, broad recovery, and calibrated uncertainty are not established. No change was made to the feature's scope or default-fit behavior.
