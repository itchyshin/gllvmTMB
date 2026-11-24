# After Task: Exact-zero paired Gaussian route, implementation phase

**Branch**: `codex/two-kernel-zero-observation-20261122`
**Date**: 2026-11-23
**Roles engaged**: Ada, Gauss, Noether

## 1. Goal

Implement the exact `V_obs = 0` Gaussian marginal route for two named dense kernels in the isolated gllvmTMB branch, verify the likelihood and paper-specific design checks, then run the separately authorized five-case route-fidelity replay. The replay is not an observed-data fit or recovery campaign.

## 2. Implemented

The branch admits exactly two named `kernel_latent(..., unique = TRUE)` terms for Gaussian TMB ML/Laplace models with trait-specific intercepts, unit weights, and at most one observed record per unit-trait cell. When `known_sigma_eps = 0`, the observation covariance term is omitted. No `log(0)`, epsilon, or hidden variance floor enters this route. Objective, gradient, Hessian, report, profile, and SE paths retain exact routing at the joint-zero Psi boundary, with dense and Woodbury evaluations recorded during optimization.

The independent dense Gaussian tests cover positive-error controls, exact zero, structural masks, rank one and two, shared/unique/total Sigma identities, the dispatch threshold, and returned-fit curvature/profile calls. The focused suite passed after adding the exact-boundary ladder. A further low-level test passed for nonzero trait-specific fixed slopes. The paper-specific route checks also passed without optimization: the Rose design reached TMB-data preparation with its frozen Brownian A plus identity I kernels and 3,432-cell mask; the lacertid response-free design matched a dense Gaussian objective and fixed-mean gradient with seven nonzero size slopes.

This is a branch-local implementation phase. The source is not merged on `main`, 3-OS CI has not run, and the formula gate still rejects public size-covariate models on the exact-zero route.

## 3a. Decisions and Rejected Alternatives

The target covariance is `V_obs = J_obs {Sigma_A ⊗ A + Sigma_I ⊗ I} J_obs^T`, where `Sigma_r = Lambda_r Lambda_r^T + diag(psi_r)` and each `psi_rt >= 0`. The observation-error covariance is exactly zero. The computation can switch between mathematically equivalent dense and fast backends near the Psi boundary; that switch is a numerical evaluation choice, not a model floor.

The public gate stays limited to the two named kernel terms and an intercept-only mean. Lacertid's size slopes were retained in a low-level dense-oracle check; they were not dropped, residualised, or added to the public formula gate. Rose's historical positive record-SD fit and lacertid's historical fixed-error fit are not reclassified as exact-zero fits.

**Roadmap tick**: N/A. No `ROADMAP.md` status row changed in this phase.

## 4. Files Touched

- `NEWS.md`
- `R/exact-marginal-gaussian.R`
- `R/fit-multi.R`
- `R/gllvmTMB.R`
- `dev/two-kernel-zero-observation/dense-gaussian-oracle.R`
- `dev/two-kernel-zero-observation/RECOVERY_PLAN.md`
- `dev/two-kernel-zero-observation/recovery-pilot.R`
- `dev/two-kernel-zero-observation/recovery-pilot-result.rds`
- `dev/two-kernel-zero-observation/rose-mask-route-check.R`
- `dev/two-kernel-zero-observation/lacertid-fixed-slope-oracle.R`
- `dev/two-kernel-zero-observation/sign-start-pair.R` (staged, parse checked, not run on fits)
- `docs/design/03-likelihoods.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.d/2026-11-23-exact-two-kernel-zero-observation.md`
- `docs/dev-log/after-task/2026-11-23-exact-two-kernel-zero-observation-phase.md`
- `man/gllvmTMB.Rd`
- `man/predict.gllvmTMB_multi.Rd` (regenerated from source documentation)
- `src/gllvmTMB.cpp`
- `tests/testthat/helper-paired-exact-oracle.R`
- `tests/testthat/test-paired-exact-marginal-gaussian.R`
- `tests/testthat/test-zzzz-coevolution-known-fixed-error.R`
- Ignored generated outputs under `pkgdown-site/articles/` from the partial article build.

No manuscript, prior/penalty-lane, or Psi-SD-lane file was changed.

## 5. Checks Run

- `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla -e 'devtools::test(filter = "paired-exact-marginal-gaussian|zzzz-coevolution-known-fixed-error", reporter = "summary")'`: passed before the final test-only slope addition. The positive-error control objective differed from the independent dense oracle by `1.85e-13`.
- `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla -e 'devtools::test(filter = "paired-exact-marginal-gaussian", reporter = "summary")'`: passed after the threshold ladder and fixed-slope oracle test were present.
- `devtools::document(quiet = TRUE); pkgdown::check_pkgdown()`: exited 0; pkgdown reported no problems. Pandoc printed `--mathml` and `--mathjax` deprecation notices.
- `CI=true OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`: completed in 46m19.1s with 0 errors, 0 warnings, and 1 NOTE: `Unexported object imported by a ':::' call: TMB:::EvalADFunObject`. The temporary `.Rcheck` directory is gone. Exact source and installed DLL hashes are recorded in `docs/dev-log/check-log.d/2026-11-23-exact-two-kernel-zero-observation.md`.
- `R_LIBS_USER=/tmp/gllvmTMB-exact-zero-lib:/Users/z3437171/Library/R/arm64/4.6/library OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla dev/two-kernel-zero-observation/rose-mask-route-check.R /Users/z3437171/.codex/worktrees/paper2-supplement-boundary/coevolution`: passed 6 assertions. It verified the 464-tip order, 3,432 observed-cell map, Brownian A and identity I raw kernels, and exact-route admission before optimizer creation. Observed response values were not read.
- `R_LIBS_USER=/tmp/gllvmTMB-exact-zero-lib:/Users/z3437171/Library/R/arm64/4.6/library OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 Rscript --vanilla dev/two-kernel-zero-observation/lacertid-fixed-slope-oracle.R /Users/z3437171/.codex/worktrees/paper2-supplement-boundary/coevolution`: passed. Using the response-free 186 by 7 lacertid design with seven nonzero trait-specific size slopes and synthetic zero responses, the objective gap was `2.05e-12` and the fixed-mean gradient gap was `1.71e-13`. No optimizer was started and no observed response was read.
- `pkgdown::build_articles(lazy = FALSE)`: partial, not passed. It rendered through the final long `where-does-the-tree-go.Rmd` article before the run exceeded about 50 minutes and was stopped. A source-matched `pkgdown::build_articles(lazy = TRUE)` retry was stopped at five minutes while that article's synthetic examples were still running.
- `git diff --check`: passed after the phase report and route-check scripts were added.
- `Rscript --vanilla -e 'invisible(parse("dev/two-kernel-zero-observation/sign-start-pair.R")); cat("R parse: PASS\\n")'`: passed for the draft one-arm paired sign-start harness. Independent review has held it from fit use. No optimizer or model fit was run from this harness.
- Standard `python3 ~/shinichi-brain/tools/check-after-task.R <report>`: did not pass. Its repo-wide acceptance-ledger reverify stopped at the unrelated `./.unlazy/temporal-ar1/GATES.md` with `APPROVAL REQUIRED GATES:G0` and a parse/unreadable diagnostic. The checker was interrupted; the temporal-AR1 ledger was not edited. The report's custom structural audit passed all 12 required headings, placeholder scan, and required receipt checks. No repository-local `check-after-task.R` copy exists in this branch.
- Totoro source-matched route-fidelity replay: five cases returned with exit status 0 under one single-threaded worker. The deterministic responses were regenerated from the archived master design and generators. Cases were P2 n=50 IDs 1 and 3 (seeds 17100050 and 17300050), n=200 IDs 2 and 8 (17200200 and 17800200), and n=400 ID 1 (17100400). Each recorded the exact branch and source, fit helper, likelihood helper, Linux DLL, and instrumented runner hashes listed below. All five recorded both dense and Woodbury objective/gradient calls, and each reached minimum per-trait Psi sum zero. Optimizer code was 0 in all five, while the package-level convergence flag was FALSE in all five under its unprojected-gradient criterion. Projected gradient maxima were 0.000576, 0.000756, 0.002165, 0.001625, and 0.004715. Maximum raw gradients were 7.10, 5.06, 12.73, 17.83, and 4.81, with positive KKT-compatible signs at zero Psi coordinates; standard errors were disabled. These are route-fidelity observations, not five clean optimum certifications or recovery evidence.

  Per-case GNU-time wall/RSS: n=50 ID1 25.64 s / 700120 kB; n=50 ID3 33.22 s / 697144 kB; n=200 ID2 515.85 s / 5908424 kB; n=200 ID8 661.71 s / 5903024 kB; n=400 ID1 3520.92 s / 22501644 kB. Combined fit wall was 4757.34 s (79m17s); peak RSS was 22501644 kB (about 21.46 GiB). No timeout or failed case occurred. The controller and fit process groups have stopped. The five RDS outputs and logs remain in `/home/snakagaw/sim-archive/gllvmTMB/exact-zero-route-fidelity-20261123/`; their exact hashes are in the remote `sha256sum-receipt.txt` manifest, SHA-256 `51336c255f69987e034b4e4ef10a820bc2eb81b81ef2a7baa9c86a3be3bda314`.

  Totoro preflight before the replay reported R 4.6.1 and ample memory. An initial install that contained a stale Mac object failed the package load check; no fit used that library. A clean source-only Linux build was then installed in the isolated `lib-clean` library and its DLL hash was checked before any fit. The source/build identity was: base HEAD `49cf245d59f039818d16a8beaed5e48a4bde375c`; `src/gllvmTMB.cpp` `6ebc976a0e94d68ed40684ecd6b99cdd599c34adf0c432496ae66f49cd40e695`; `R/fit-multi.R` `2c7af3953d85fb665573daec44f95c8ed902c447ea32eec9cabeae23990c226a`; `R/gllvmTMB.R` `49deb8eb2562c281f604200053f32a6b03e4c1f248fa7232769510da089cb096`; `R/exact-marginal-gaussian.R` `2a041e88581fbf4e323a2a057aa42d7aa1e95fcf82fad1d84c9dc9dd690ec5e2`; installed Linux DLL `8669e0205400e4180a14c8a71dd8fff347b4cda54891a4c62e3e8d934f31bb9d`; master design `4e0d43df7ad8bcc2a6b18f7a6614ee93b5e4e31707c54d329ea5efd51a0415ef`; runner `c46ef378b4301dadddc78745407020120f766e2b8cdcf0166b688d27612e093d`; generator `7ec2bfd52c7cc6785c83238b89ea8fef3c70972040196de05deed780bcc81cea` (nested campaign responses) and `db1f8f37ed1d412941de827add4d1d39e8a7194bb08e35847a173707215bd17a` (Gaussian generator). This route-fidelity replay is excluded from recovery denominators and does not establish recovery, consistency, uncertainty calibration, or profile/bootstrap coverage.

Full package-check identity: base HEAD `49cf245d59f039818d16a8beaed5e48a4bde375c`; `R/fit-multi.R` `2c7af3953d85fb665573daec44f95c8ed902c447ea32eec9cabeae23990c226a`; `R/gllvmTMB.R` `49deb8eb2562c281f604200053f32a6b03e4c1f248fa7232769510da089cb096`; `R/exact-marginal-gaussian.R` `2a041e88581fbf4e323a2a057aa42d7aa1e95fcf82fad1d84c9dc9dd690ec5e2`; `src/gllvmTMB.cpp` `6ebc976a0e94d68ed40684ecd6b99cdd599c34adf0c432496ae66f49cd40e695`; installed `gllvmTMB.so` `befea8069c15aa9aa1de67493cfaf8e9912e936853b9672d1dbf65032c4e560f`.

## 6. Tests of the Tests

The boundary ladder checks exact backend selection at Psi sums `0`, `0.0005`, `0.001`, `0.0011`, and `0.01`; it asserts dense routing through the exact threshold and the fast backend above it, then compares objective, gradient, and Hessian with the selected backend. The joint-zero returned-fit tests exercise Hessian, sdreport/SE, and profile calls, covering the previously reproduced post-fit Woodbury mismatch. The positive-error test compares the fitted TMB objective against a separately coded dense covariance calculation. The new seven-trait slope check includes nonzero coefficients and compares the exact TMB mean gradient with the dense Gaussian derivative. Parser rejection tests cover duplicated unit-trait cells and a single-kernel zero-error formula. These are boundary, feature-combination, and explicit rejection tests; no deliberate mutation test was run.

After the focused TMB suite was rerun, `Rscript --vanilla dev/two-kernel-zero-observation/dense-gaussian-oracle.R` passed the independent exact-zero and positive-error NLLs, analytic-vs-finite-difference gradients (maximum gaps `1.37919e-07` and `6.31176e-10`), zero shared/unique/total identity gap, zero omission gap, positive-error variance-increment gap `3.46945e-17`, and structural-mask gap 0. This validates the dense calculation independently; the focused package tests compare the TMB route to it.

## 7a. Issue Ledger

**GitHub issue ledger:** Open issue searches used `gh issue list --state open --search 'exact zero Gaussian kernel'` and `gh issue list --state open --search 'known_sigma_eps paired kernel'`. They returned no directly applicable open implementation issue. The first returned #1357, #488, and #1359, which are unrelated test-sweep or Julia-bridge items. No issue was commented, closed, or created in this phase. Open PRs were inspected for edits to this report path; no collision was found. No message was sent to PR authors.

## 8. Consistency Audit

- `rg '\bS_B\b|\bS_W\b|\\bf S' .`: prior occurrences were confined to historical check-log material; the new likelihood and extraction description uses `psi` and `Psi`.
- `rg -n 'gllvmTMB\(' R vignettes README.md NEWS.md docs/design`: the examples remain consistent with the documented long- and wide-format entry points; no public formula example was changed in this phase.
- `rg 'in prep|in preparation' docs vignettes`: existing matches are historical or explicitly scoped validation notes; no new foundational citation claim was added.
- `rg '\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(' vignettes`: no deprecated alias was introduced by this change.
- `rg 'meta_known_V' README.md NEWS.md docs vignettes`: the existing deprecated-alias boundary remains unchanged.
- `rg 'gllvmTMB_wide' README.md NEWS.md docs vignettes`: the existing soft-deprecation wording remains unchanged; no new use was introduced.
- `rg -n 'KER-03C|known_sigma_eps = 0|exact two-kernel' README.md ROADMAP.md NEWS.md docs/design R/gllvmTMB.R man/gllvmTMB.Rd`: the exact-zero route is described as partial and linked to KER-03C; no claim of broad family, engine, or formula support was added.

The `pkgdown::build_articles(lazy = FALSE)` check is partial, so this audit does not certify that every article renders. The scope gate in code still rejects the unsupported public size-covariate formula, while the low-level slope test demonstrates objective and mean-gradient support only.

## 9. What Did Not Go Smoothly

The full article render exceeded its 20 to 40 minute estimate and reached about 50 minutes. The first attempt also used the default installed package instead of the isolated 0.8.0 branch library and failed on an unavailable export; the corrected isolated-library render then spent most of its time in the final article. I stopped both attempts at explicit limits. A brain-wide closeout script also resolved relative paths against the brain vault and created a temporary untracked file outside this worktree. I removed that file before recording its hash; a later read-only check found it absent. No further brain-vault changes were made. The standard after-task checker is not a clean pass: its repo-wide reverify stopped on the unrelated temporal-AR1 approval gate. The custom structural audit is separate evidence and does not replace that check.

## 10. Known Residuals

This branch remains dirty and unmerged; 3-OS CI has not run. The site-wide article render is partial. Exact-zero support remains restricted to two named dense Gaussian kernel tiers, trait-specific intercepts, ML/Laplace, unit weights, no offsets, no extra covariance except explicit `meta_V`, and one observed record per unit-trait cell. The public size-covariate formula gate is unchanged. The Rose result is an admission/data-preparation check, not an observed-data fit. The lacertid result is a low-level dense-oracle check with synthetic responses, not public formula support or an observed-data refit. Two prior known-truth pilot fits had substantial covariance errors and do not establish a recovery trend. No calibrated profile or bootstrap interval coverage has been shown. Julia parity has not been tested.

The coevolution paper lane's five-case route-fidelity replay is complete as described above. A draft dev-only hook harness for the separate two-response by two-start sign comparison is at `dev/two-kernel-zero-observation/sign-start-pair.R`; its R syntax parses, but independent reviews have placed it on hold for fit use. It still needs to derive and verify formula/kernel order, raw kernels, observed masks and response/design hashes from the actual fit inputs; compare the 6 by 6 host-partner Gamma and weighted observable surfaces with dimension-checked truth; verify all start bounds and loaded build identity; and preserve complete per-arm outcomes. It also needs a deterministic no-fit dense-object evaluation to refine the time estimate. No sign-start fit has been launched. Initial projections for four n=400 optimizer calls are 235 to 259 minutes based on the measured 58m41s fit and historical q90 64m39s per fit, before refining the dense-object and audit overhead; this exceeds the three-hour cap. The harness will remain on hold until these checks and independent review pass, and any run will require an extended cap approved by the user.

## 11. Team Learning

**Gauss** found and reproduced a post-fit exact-zero boundary defect: a returned fit could retain a Woodbury backend that evaluated boundary trials differently from the dense likelihood. The implementation now routes returned-fit curvature and profile evaluations consistently, and the tests exercise those APIs rather than only optimizer objective calls.

**Noether** checked that the two-kernel covariance and exact-zero observation contract match the implementation. The fixed-slope check separates low-level Gaussian mean support from the public formula gate, preventing a successful oracle from being misreported as public covariate admission.

**Memory receipt:** The canonical operating contract, codex-efficiency procedure, repository instructions, and after-task audit skill were read. The repository routing check reported no LOAD-FIRST manifest; the lane preflight identified a multi-lane repository, so this work stayed on its isolated branch.

**Golden Set:** Not checked. The boundary, dense-oracle, and parser-rejection tests were used for this new likelihood route.

## 12. Cross-Product Coverage

Covers: TMB ML/Laplace Gaussian objective, gradient, Hessian, profile and SE routing for two named dense kernels under exact zero observation covariance; positive-error control; structural masks; one observation per unit-trait cell; named shared/unique/total Sigma identities; Rose A plus I route preparation; low-level fixed-size-slope mean objective and gradient oracle; five source-matched optimizer-route cases spanning n=50, 200, and 400. The five cases exercise both numerical routes at joint-zero Psi but are not a recovery experiment.

Does NOT cover: public size-covariate admission to the exact-zero route; formulas written as `phylo_latent() + latent()`; sparse phylogenetic or spatial kernels; non-Gaussian families; REML, MSPL, priors or penalties; Julia; observed Rose or lacertid refits; broad parameter recovery; calibrated uncertainty or interval coverage; 3-OS CI; merge or release.

### Reader-facing example addendum (2026-11-23)

The primary `gllvmTMB()` help example now includes an executable exact-zero example in both long and wide format. It simulates the response from the sum of the two named kernel-tier covariances, so `known_sigma_eps = 0` is consistent with the stated data-generating model. The example also uses unit weights, one row per unit-trait cell, and the admitted trait-specific intercept formula. `devtools::document()` regenerated `man/gllvmTMB.Rd`; `pkgdown::check_pkgdown()` reported no problems; `pkgload::run_example("man/gllvmTMB.Rd")` completed both new fits and returned identical log likelihoods (-25.17735). The affected example files were `R/gllvmTMB.R` and generated `man/gllvmTMB.Rd`. Exact-formula example scans found no other example that claimed zero observation error, and existing positive `known_sigma_eps` examples remain valid. No article code was changed or rendered in this addendum; the earlier site-wide article-render limitation remains.

## Addendum: Totoro Linux watchdog smoke, 2026-11-23

The separate sign-start watchdog safety gate has now passed a bounded no-fit smoke on Totoro Linux. It used the watchdog's actual signal and deadline paths with a hash-pinned dummy controller and a TERM-resistant shell child; it did not load gllvmTMB or start an optimizer. The final run completed in 53 seconds with exit 0. Signal mode recorded one `interrupted` arm and three `not_started_interrupted` arms; deadline mode recorded one `controller_deadline` arm and three `not_started_controller_deadline` arms. Each run registered four arms and wrote one terminal outcome per arm. The final receipt reports zero remaining process-group members for PGIDs 2462429 and 2463621 and `optimizer_fits=0`.

The paper lane independently read the remote receipts and checked both process groups; its verdict was PASS. Final smoke-receipt SHA-256 is `5b4c4742de70be3b11764aa005bc38c758da2051ca136d52d6b0eca29a4e695f`; launch receipt SHA-256 is `2d0d8169a9383a625eef4c9f52d862e8b6b68762c347b1fb303750a8b45fb67f`. The complete run files and exact script hashes are recorded in `docs/dev-log/after-task/2026-11-23-sign-start-linux-process-smoke.md` and `docs/dev-log/check-log.md`.

The smoke report's required structure passed the standard after-task checker. Its repo-wide acceptance-ledger reverify exited 1 on three unrelated UNMET gates: `.unlazy/ijsdm-response-information-forensics/GATES.md`, `.unlazy/ijsdm-response-information-GATES.md`, and `.unlazy/temporal-ar1/GATES.md`. None was modified by this lane.

This is process cleanup and writeback evidence only. It does not validate the paired optimizer fits, recovery, exact-zero inference, or uncertainty. The four-fit sign diagnostic remains paused pending its separate user-approved time cap and final harness review. A fresh full local package check started at 14:45 on 2026-11-23 and is still active after the latest code/test edits; the earlier completed check above remains prior evidence and does not close that rerun.


## Current-source full package check rerun

The current-source `devtools::check(args = "--no-manual", quiet = TRUE)` rerun completed on 2026-11-23 in 1h26m46.3s. The command exited 0 with 0 errors, 0 check warnings, and 1 NOTE: the existing `TMB:::EvalADFunObject` unexported-object import note. `testthat.Rout` reported 31,159 passed, 1,259 skipped, and 75 test warnings; R CMD check reported the tests stage OK. The same run completed package-vignette checks and reported examples OK. Its temporary `.Rcheck` directory was removed after completion.

Exact checked source identity: base HEAD `49cf245d59f039818d16a8beaed5e48a4bde375c`; `R/fit-multi.R` SHA-256 `2c7af3953d85fb665573daec44f95c8ed902c447ea32eec9cabeae23990c226a`; `R/gllvmTMB.R` `49deb8eb2562c281f604200053f32a6b03e4c1f248fa7232769510da089cb096`; `R/exact-marginal-gaussian.R` `a7192e22930a602e6e98991604858f14c9b9164ad9444696c330ee501496da16`; and `src/gllvmTMB.cpp` `6ebc976a0e94d68ed40684ecd6b99cdd599c34adf0c432496ae66f49cd40e695`. During the check, the packaged source copies for those four files matched the worktree. The check-built macOS `gllvmTMB.so` SHA-256 was `e37aa26278a29f1693772c44c333199c2ab848dbe213abe9709b2d0e1d881691`. This result supersedes the earlier full-check receipt for helper SHA `2a041e88581fbf4e323a2a057aa42d7aa1e95fcf82fad1d84c9dc9dd690ec5e2`.

### PR CI mapping correction (2026-11-24)

The first exact-head PR check exposed an unmapped `KER-03C` row in the R-to-Julia capability ledger; Ubuntu shards 1 and 4 failed the ledger test for that reason, while shards 2 and 3 passed. The correction records the exact-zero two-kernel route as R-only with no registered Julia twin in `dev/gapclose/build-capability-status.R` and regenerates `docs/design/capability-status.md`. The generator check passed with 0 unmapped rows; the focused ledger test passed 32 checks; and the combined exact-zero plus ledger test run completed with exit 0 after merging current `origin/main` at `f4cee11c9caed0f4fc0ae3c98fc2bac4db91cda1`. The new four-shard PR run and full three-OS CI have not yet completed. No recovery, interval-coverage, or paired-start fit was run.
