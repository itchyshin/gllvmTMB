# Check-log: Named-kernel Psi SD prior

**Goal:** Implement and validate an opt-in half-normal prior on selected
named-kernel trait-specific Psi SDs. No GitHub issue number was attached to
this isolated implementation lane.

**Commands and results:**

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` passed and
  regenerated `man/gllvmTMBcontrol.Rd` after the final help wording change.
- `Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|fixed-effect-priors", reporter = "summary")'`
  passed with zero failures after the simulated-fit smoke fixture was revised to
  use 10 species across 12 sites. This includes objective, gradient, Hessian,
  target-index, route-guard, objective-decomposition, provenance, and AIC-warning
  checks. The fit emitted the expected `logLik()` warning for a penalized MAP
  point. In the retained fixture run, Psi was
  (0.081, 0.115, 0.240) for truth (0.16, 0.36, 0.64), the zero shared
  covariance estimate had maximum absolute entry 0.249, intercepts were
  (-0.189, 0.113, 0.598), convergence was 0, and the objective was finite.
  This simulated-fit smoke test does not establish parameter recovery.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with no pkgdown
  problems. Pandoc emitted its existing `--mathml` deprecation warning.
- `git diff --check` passed.
- `Rscript --vanilla -e 'res <- devtools::check(args = "--no-manual", quiet = TRUE); print(res)'`
  ran for 42m 3.2s. Package code, documentation, compilation, and examples
  passed. The test suite reported 30,970 passes, 1,252 skips, and two visual
  snapshot failures. `R CMD check` ended with one error from those failures,
  zero check warnings, and one NOTE for the existing `TMB:::EvalADFunObject`
  call. This full check ran before the final provenance/help correction and
  before the known-truth test was added; the latest focused prior and fixed-
  effect tests passed after those changes.
- On detached clean `origin/main` at `0d065c398510dcdd0df3079eff0de36d78402202`,
  `Rscript --vanilla -e 'devtools::test(filter = "plot-visual-snapshots", reporter = "summary")'`
  reproduced the same two failures at `test-plot-visual-snapshots.R:301` and
  `:353`. The temporary comparison worktree was removed without changes.

**Consistency scans and verdicts:**

- `rg -n 'kernel_psi_sd_prior|half-normal|HalfNormal|natural_standard_deviation|natural SD' R/kernel-psi-sd-priors.R R/gllvmTMB.R R/fit-multi.R tests/testthat/test-psi-sd-priors.R man/gllvmTMBcontrol.Rd docs/design/35-validation-debt-register.md` found the same target, scale, MAP, and limitation wording in implementation, tests, help, and row KER-03B.
- `rg -n '\bS_B\b|\bS_W\b|\\bf S' R/gllvmTMB.R man/gllvmTMBcontrol.Rd docs/design/35-validation-debt-register.md` returned no legacy S/U notation in the changed user-facing text.
- `rg -n 'gllvmTMB\(' R/gllvmTMB.R` enumerated the help call sites. The new prior example has long and wide calls; the long call supplies `trait = "trait"`, and both calls ran in the full check's examples phase.
- `rg -n '\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(' R/gllvmTMB.R man/gllvmTMBcontrol.Rd` returned no deprecated keyword aliases in the new help text.
- `rg -n 'in prep|in preparation' R/gllvmTMB.R man/gllvmTMBcontrol.Rd` returned no in-preparation citations in the changed help.
- `rg -n 'meta_known_V' R/gllvmTMB.R man/gllvmTMBcontrol.Rd` found one existing cross-reference to the deprecated alias in the general keyword overview; it is not used by the new prior example.
- `rg -n 'gllvmTMB_wide' R/gllvmTMB.R man/gllvmTMBcontrol.Rd` found existing legacy wrapper references elsewhere in the general help; the new example uses the `traits(...)` formula.
- `rg -n 'penalised fit|loading ridge or prior|kernel-Psi|named-kernel Psi SD prior|fixed-effect normal priors' R/aghq-report.R R/vcov-coef.R R/methods-gllvmTMB.R man/gllvmTMB_multi-vcov.Rd man/tidy.gllvmTMB_multi.Rd` found the corrected AIC/BIC warning and the `vcov()` and `tidy()` scope statements in source and regenerated help.
- `rg -n 'recovers an interior|recovery fixture|recovery checks|n_species = 12|n_species = 10|runs on a replicated' tests/testthat/test-psi-sd-priors.R docs/dev-log/check-log.d/2026-11-19-kernel-psi-sd-prior.md docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md` found the final smoke-test title and no stale recovery-test title or 12-species claim.

**Reviews:** Fisher found no mathematical blocker and confirmed the natural-SD density, log-SD derivatives, parameter offsets, and narrow claim boundary. Rose's two findings on provenance and penalty-conflict wording were fixed and rechecked. Curie confirmed the 10-species fixture as a smoke test and found no blocker. Noether confirmed the Psi-disabled earlier-kernel offset assertion. Gauss confirmed the AIC/BIC warning and `vcov()` and `tidy()` help fixes. Pat read the help example and found no blocking confusion; Pat suggested showing a comparison across prior scales if a future sensitivity article is added.

**Not run:** No three-OS CI, article build, coverage campaign, Julia parity, interval-coverage study, profile/bootstrap inference, or release.

**Claim boundary:** KER-03B remains `partial`. The evidence supports the native-TMB Gaussian ML Laplace MAP sensitivity, objective/derivative checks, and deterministic interior and zero-boundary fit checks. It does not support calibrated intervals, prevention of near-zero estimates, broad recovery, Julia parity, or cross-package integration. No NEWS entry was added because active PRs #1837, #1836, #1835, #1833, #1832, and #1820 also edit `NEWS.md`; this lane made no PR, merge, or release.

## Continuation checks: 2026-11-19

- `Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|fixed-effect-priors", reporter = "summary")'` passed with zero failures after the test file was split into deterministic interior and zero-boundary fit cases. The expected penalized-MAP `logLik()` warning appeared.
- The zero-boundary simulation fit converged and extracted trait_2 Psi variance `1.51e-15`, corresponding to natural SD about `3.9e-8`; `.gllvmTMB_boundary_flags()` returned `near_zero_sd_phy_diag`. The interior target fit converged without a near-zero flag. These are integration checks only.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with “No problems found.” Pandoc emitted repeated existing `--mathml` deprecation warnings.
- `git diff --check` passed after the test and report edits.
- `Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|fixed-effect-priors|loading-ridge-disclosure", reporter = "summary")'` passed with zero failures. The PSI-prior and fixed-effect-prior tests passed; the expected MAP `logLik()` warning appeared. The loading-ridge disclosure test now matches the emitted warning text, “ordinary likelihood-based interpretation is unsupported”; both assertions pass.
- `Rscript --vanilla -e 'res <- devtools::check(args = "--no-manual", quiet = TRUE); print(res)'` completed in 42m 30.6s. Code, documentation, compilation, and examples passed. Tests reported 30,990 passes, 1,252 skips, 70 warnings, and two failures, both the visual snapshot changes at `test-plot-visual-snapshots.R:301` and `:353`. These two failures were reproduced on clean base `0d065c398510dcdd0df3079eff0de36d78402202`. R CMD check reported one error from the snapshot failures, zero check warnings, and one NOTE for the existing `TMB:::EvalADFunObject` call. The stale loading-ridge warning assertions no longer fail.
- The generalized-prior lane confirmed `unique_variance` as the shared target class and `measure = natural_sd` for the requested prior. The log-SD optimizer evaluates the natural-SD density without a Jacobian. This local named-kernel route stays isolated from the lane's active four-package branch.
- `Rscript --vanilla '/Users/z3437171/Dropbox/Github Local/Shinichi/tools/check-after-task.R' '/Users/z3437171/.codex/worktrees/psi-sd-prior-gllvmTMB/docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md'` passed the required report structure check.
- `python3 /Users/z3437171/shinichi-brain/tools/closeout.py check /Users/z3437171/.codex/worktrees/psi-sd-prior-gllvmTMB/docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md` failed the overall acceptance gate because three unrelated repository ledgers remain unmet: `./.unlazy/ijsdm-response-information-forensics/GATES.md`, `./.unlazy/ijsdm-response-information-GATES.md`, and `./.unlazy/temporal-ar1/GATES.md`. These belong to other work and were not changed.
- `rg -n 'psi_variance|near_zero_sd_phy_diag|zero-boundary|interior' tests/testthat/test-psi-sd-priors.R docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md docs/dev-log/recovery-checkpoints/2026-11-19-codex-psi-prior-checkpoint.md` confirmed the variance-to-SD transform, separate fit cases, and matching boundary assertion. The checkpoint was then corrected to describe the extracted value as variance.
- `rg -n 'does NOT cover|_pkgdown.yml|55 refs|unique_variance|HalfNormal' docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md docs/dev-log/check-log.d/2026-11-19-kernel-psi-sd-prior.md` confirmed the claim boundary, generalized target convention, and article-navigation deferral. A separate public article was not added because preflight found 55 competing `_pkgdown.yml` refs; the runnable reference help remains the user example.
- `rg -n 'KER-03B' docs/design/35-validation-debt-register.md` returned line 335, with `unique_variance` as the target class and `natural_sd` as the explicit measure.
- Full package check completed as recorded above. The focused follow-up suite and AIC disclosure test passed; only the two clean-base-reproduced visual snapshot failures remain.

**Continuation claim boundary:** KER-03B remains `partial`. The test split checks an interior fit and an explicitly near-zero boundary fit; it does not establish recovery or that the prior avoids boundary estimates. Cross-package integration and Julia bridge parity remain unverified.

## Full-check rerun after public prior metadata assertions: 2026-11-19

- `Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|fixed-effect-priors|loading-ridge-disclosure", reporter = "summary")'` passed with zero failures after the fitted-object metadata assertions for `target_class = "unique_variance"` and `measure = "natural_sd"` were added. The expected penalized-MAP `logLik()` warning appeared.
- `Rscript --vanilla -e 'res <- devtools::check(args = "--no-manual", quiet = TRUE); print(res)'` completed in 42m 22.8s. It reported 30,992 passes, 1,252 skips, 70 test warnings, and two visual snapshot failures at `test-plot-visual-snapshots.R:301` and `:353`. R CMD check ended with one error from those snapshots, zero check warnings, and one NOTE for the existing `TMB:::EvalADFunObject` call. The two snapshot failures were previously reproduced on clean base `0d065c398510dcdd0df3079eff0de36d78402202`; this rerun does not alter that baseline evidence. No new full check is claimed clean.
- `git diff --check` passed after the metadata change. No implementation source, public documentation, NEWS, or shared navigation files were edited after the check began.

## Cross-lane coordination: 2026-11-19

After Shinichi requested coordination, I first sent the `DRM priors and ridge penalties` lane a design summary. The lane acknowledged that it recorded the separate Psi design and limits, then returned to its own four-package acceptance run. On 2026-11-19 I sent the concrete gllvmTMB implementation plan: named-kernel `unique_variance` targets; a normalized HalfNormal density on natural Psi SD with no log-SD Jacobian; native TMB Gaussian identity ML Laplace scope; objective, derivative, interior-fit, and near-zero-boundary checks; and partial-only claims with no Julia parity or calibrated-uncertainty claim. This is coordination only, not authorization to integrate the prototype into the four-package branch. The Psi-prior implementation remains isolated on `codex/psi-sd-prior-20261119`; the prior lane was still active on its own acceptance run when last checked.

## Source ownership coordination: 2026-11-19

After Shinichi authorized coordination, brief ownership questions were posted to every open PR touching the three integration files. The GitHub connector returned HTTP 403 for all eight attempts; authenticated `gh pr comment` succeeded. Each returned comment was read back with `gh api` and matched the intended text exactly.

- `R/fit-multi.R`: [#1834](https://github.com/itchyshin/gllvmTMB/pull/1834#issuecomment-7010744795), [#981](https://github.com/itchyshin/gllvmTMB/pull/981#issuecomment-7010749034)
- `R/methods-gllvmTMB.R`: [#1828](https://github.com/itchyshin/gllvmTMB/pull/1828#issuecomment-7010749725), [#1826](https://github.com/itchyshin/gllvmTMB/pull/1826#issuecomment-7010750397)
- `R/gllvmTMB.R`: [#1824](https://github.com/itchyshin/gllvmTMB/pull/1824#issuecomment-7010750999), [#1823](https://github.com/itchyshin/gllvmTMB/pull/1823#issuecomment-7010751657), [#1822](https://github.com/itchyshin/gllvmTMB/pull/1822#issuecomment-7010752125), [#1820](https://github.com/itchyshin/gllvmTMB/pull/1820#issuecomment-7010752592)

No implementation file was edited. Replies and PR state remain to be checked before resuming source integration.

### Follow-up ownership check: PR #1838

A new open PR #1838 appeared on `R/fit-multi.R` after the initial eight ownership comments. Shinichi asked me to sort out the overlap and continue, so I posted the same concise ownership question to #1838: https://github.com/itchyshin/gllvmTMB/pull/1838#issuecomment-7011568117. `gh api repos/itchyshin/gllvmTMB/issues/comments/7011568117` confirmed the exact text. No replies are present yet on any of the nine coordination comments.

## Maintainer-assigned integration and current-main validation: 2026-11-19

Shinichi assigned the Psi-prior lane responsibility for integrating its work in the three shared source files. The original dirty worktree remains preserved at `codex/psi-sd-prior-20261119`. A new branch, `codex/psi-sd-prior-integration-20261119`, was created in `/Users/z3437171/.codex/worktrees/psi-sd-prior-integration` from current `origin/main` commit `902c069c8daaf131a0e0031edf990e36d29bbd41`. `git apply --3way /tmp/psi-sd-prior-integration.patch` applied the implementation and task records without conflicts. The nine affected PRs were notified that this lane is taking integration responsibility; their branches were not modified. The current open-PR file scan found no PR editing `docs/design/35-validation-debt-register.md`.

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`: passed on the integration branch.
- `Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|fixed-effect-priors|loading-ridge-disclosure", reporter = "summary")'`: passed with no failures; the expected penalized-MAP `logLik()` warning appeared.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: passed with no problems; Pandoc emitted its existing `--mathml` deprecation warnings.
- `git diff --check`: passed before documentation regeneration.
- `Rscript --vanilla -e 'res <- devtools::check(args = "--no-manual", quiet = TRUE); print(res)'`: completed in 44m 0.7s on `902c069c8daaf131a0e0031edf990e36d29bbd41` plus the Psi-prior patch. It reported 30,998 passes, 1,252 skips, 70 test warnings, and two visual snapshot failures at `test-plot-visual-snapshots.R:301` and `:353`. `R CMD check` reported one error due to those two failures, zero check warnings, and one NOTE for `TMB:::EvalADFunObject`.
- On a clean detached worktree at the exact same `origin/main` commit, `Rscript --vanilla -e 'devtools::test(filter = "plot-visual-snapshots", reporter = "summary")'` reproduced the two snapshot failures at the same lines. This confirms the current-main baseline has these failures without the Psi-prior changes.
- GitHub CLI readback matched the takeover notice exactly on all nine affected PRs: #1834, #981, #1838, #1828, #1826, #1824, #1823, #1822, and #1820. No owner response was present at the latest check.

The patch is not committed and no PR or three-OS CI run exists yet. Do not merge or release without separate authorization. KER-03B remains `partial`; Julia parity, broad recovery, and calibrated uncertainty remain unsupported or unverified.

## Rose and after-task audit: 2026-11-19

Rose pre-publish verdict: PASS after correcting one stale sentence in `docs/dev-log/known-limitations.md`. It had said shared `unique_sd` target integration was pending; the local contract is `target_class = unique_variance` and `measure = natural_sd`. Cross-package prior-schema integration remains unverified.

- `rg -n 'kernel_psi_sd_prior|natural_sd|unique_variance|half-normal|HalfNormal|response units|response-unit' R/gllvmTMB.R man/gllvmTMBcontrol.Rd docs/design/35-validation-debt-register.md docs/dev-log/known-limitations.md`: the control argument, natural-SD measure, target class, support limits, and KER-03B `partial` claim agree.
- `rg -n '\bS_B\b|\bS_W\b|\\bf S|diag\(U\)|U_phy|U_non' R/gllvmTMB.R man/gllvmTMBcontrol.Rd`: no obsolete S/U notation in the changed help.
- `rg -n 'gllvmTMB\(' R/gllvmTMB.R`: the help contains long and wide fit calls; the long-format call supplies `trait = "trait"`, and the wide call uses `traits(...)`.
- `rg -n 'gllvmTMBcontrol' NAMESPACE _pkgdown.yml`: the existing export and pkgdown reference topic are present; no new public function or navigation entry was added.
- `sed -n '2747,3005p' R/gllvmTMB.R | rg -n '\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(|meta_known_V|gllvmTMB_wide|in prep|in preparation|\bS_B\b|\bS_W\b|diag\(U\)|U_phy|U_non'`: no stale alias, wrapper, citation, or notation in the new control/example block.
- `Rscript --vanilla '/Users/z3437171/Dropbox/Github Local/Shinichi/tools/check-after-task.R' '/Users/z3437171/.codex/worktrees/psi-sd-prior-integration/docs/dev-log/after-task/2026-11-19-kernel-psi-sd-prior.md'`: report structure check passed. The bundled acceptance check remains UNMET because of three unrelated `.unlazy` ledgers: `ijsdm-response-information-forensics/GATES.md`, `ijsdm-response-information-GATES.md`, and `temporal-ar1/GATES.md`. These are outside this feature and were not changed.
- `python3 /Users/z3437171/shinichi-brain/tools/slop_check.py` on the after-task report and this check log: both passed with zero findings and zero em dashes.
- `graft build`: passed and refreshed the ignored local graph cache after the code changes.
- `git diff --check`: passed after the report and known-limitations edits.

The after-task report now includes the explicit mathematical contract and the current-main validation results. No formula grammar, likelihood, family, or function signature other than the additive `gllvmTMBcontrol()` argument changed. No standalone article was added because the control help already has runnable long- and wide-format examples and the feature adds no new exported topic. No README, NEWS, ROADMAP, or `_pkgdown.yml` edit is required for this local review branch.

## PR #1841 merge-gate follow-up: 2026-11-19

**Source under test:** PR head `e2f468f260b9b0af368f88ca12cfe5ad643b1019` before the follow-up commit.

**Commands and results:**

- `Rscript dev/gapclose/build-capability-status.R` passed and wrote 82 rows, mapping 255 register rows, with 37 unmapped-by-design rows and zero unexpected unmapped rows.
- `Rscript dev/gapclose/build-capability-status.R --check` passed: 82 rows, zero unmapped register rows.
- `Rscript --vanilla -e 'devtools::test(filter = "psi-sd-priors|gapclose-parity-ledger|gapclose-next-steps", reporter = "summary")'` passed with zero failures. The expected penalised-MAP `logLik()` warning appeared.
- `Rscript --vanilla -e 'source("dev/gapclose/count-bare-aborts.R"); hits <- count_bare_aborts("R"); cat(length(hits), "bare aborts found\\n")'` returned 770 after adding next-step advice to two internal Psi-prior errors.
- `rg -n 'KER-03B|Named-kernel Psi SD priors|Julia parity, broad recovery' dev/gapclose/build-capability-status.R docs/design/capability-status.md docs/design/35-validation-debt-register.md` found the matching KER-03B mapping, scope note, and `partial` register row.
- `git diff --check` passed.

**Pre-fix CI evidence:** PR run `44585940971` completed on the source under test. Ubuntu shards 1 and 2 passed; shard 3 failed only the 770 bare-abort guard; shard 4 failed the three assertions caused by KER-03B being unmapped. The manual three-platform run `44586781505` failed on Windows, macOS, and Ubuntu with the same two causes. The exact failures were `772 > 770` and the generator reporting `KER-03B` as its sole unmapped register row. These runs predate the follow-up changes and do not validate them.

**Not run after the follow-up changes:** Full package check, three-platform CI, coverage workflow, Julia parity, or merge. Push the corrected commit and wait for the exact-head checks before merge.

**Claim boundary:** The local mapping and targeted tests pass. They do not establish that the corrected commit passes package checks or three-platform CI.
