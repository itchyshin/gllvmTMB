# After-task: coevolution fixed-rho metadata regression

Date: 2026-06-19 15:38 MDT

Branch: `codex/coevolution-engine-split-20260619`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## 1. Implemented claim

Real fitted multi-kernel `make_cross_kernel()` tiers now retain fixed-`rho`
host/partner metadata after `R/fit-multi.R` subsets and symmetrises the stored
matrix, so `predict_cross_covariance()` can infer omitted `row_levels` /
`col_levels` and correctly report `kernel_includes_rho = TRUE`.

This is a fixed-rho point-extractor metadata repair for KER-03 / COE-03. It
does not estimate `rho`, produce intervals, calibrate null thresholds, or move
COE-04 beyond `partial`.

## 2. Code paths checked

- `R/fit-multi.R`: records cross-kernel metadata before level alignment and
  reattaches a fitted-level version to each stored `fit$kernel_matrices[[name]]`.
- `R/kernel-helpers.R`: adds `.cross_kernel_metadata_for_levels()` so host and
  partner defaults follow the fitted matrix level order.
- `R/extract-sigma.R`: unchanged predictor semantics; it now receives the
  metadata it already required.
- `tests/testthat/test-coevolution-two-kernel.R`: adds a real fitted
  multi-kernel `make_cross_kernel()` regression using omitted `row_levels` /
  `col_levels`, `kernel_includes_rho = TRUE`, fixed `rho`, and finite
  `fit$fit_health$max_gradient`.
- `docs/design/35-validation-debt-register.md`,
  `docs/design/65-cross-lineage-coevolution-kernel.md`, and `NEWS.md` now name
  the real-fit metadata-retention behavior.

## 3. Math / syntax alignment

The estimator is unchanged:

| Symbol | R syntax | Implementation | Check |
|---|---|---|---|
| `K_r` | `kernel_latent(species, K = K_r, name = r)` | stored in `fit$kernel_matrices[[r]]` after level alignment | metadata preserved on stored real-fit matrix |
| `rho_r` | `make_cross_kernel(..., rho = rho_r)` | fixed metadata on `K_r`, not a TMB parameter | `fit$kernel_levels$rho` and matrix metadata agree |
| `Gamma_shape_r` | `extract_Gamma(..., scale = "shape")` | `Lambda_H,r Lambda_P,r^T` | used by pair-specific prediction |
| pair covariance | `predict_cross_covariance()` | `Gamma_shape_r * K_r[i, j]` | no second multiplication by `Gamma_effect_r` |

## 4. Examples and docs

No examples or vignettes changed in this slice. The existing roxygen text for
`predict_cross_covariance()` already promised omitted host/partner defaults for
`make_cross_kernel()` tiers; this slice makes the real fitted multi-kernel path
honor that promise.

`devtools::document()` was not rerun because no roxygen source changed.

## 5. Tests of the test

The new regression is a feature-combination test: it combines a real
multi-kernel TMB fit, `make_cross_kernel()` metadata, omitted pair-level
arguments, fixed-rho reporting, and fitted-gradient diagnostics. It specifically
covers the bug found by Faraday's read-only audit, where fake-fit tests kept the
attribute manually but the real fit lost it during matrix subsetting.

Second-pass strengthening, after Descartes and Hypatia reviewed the split:

- added a mixed-rank two-kernel fit where one named fixed-kernel tier uses
  `d = 2` and a second tier uses `d = 1`;
- checked that `fit$kernel_levels$rank`, `fit$report$Lambda_kernel`, and
  `extract_Sigma(..., part = "shared")` all respect the per-tier rank offsets;
- tightened the real cross-kernel metadata regression from finite-gradient
  evidence to `fit$fit_health$max_gradient < 1e-3`.

This closes Descartes' immediate offset/gradient review request for the fixed
multi-kernel engine split. It does not close Hypatia's scientific-coverage
warnings: mixed-family recovery, formal null calibration, interval calibration,
module/rank calibration, and broad non-Gaussian coverage remain outside this
slice.

## 6. Commands run

- `git status --short --branch`
  -> branch `codex/coevolution-engine-split-20260619`, dirty coevolution lane.
- `git diff --check`
  -> clean before and after the patch.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> exit code 0; expected heavy rows skipped.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> exit code 0.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
  -> exit code 0; expected heavy rows skipped.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
  -> exit code 0.
- After the second-pass test strengthening:
  `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> exit code 0; expected heavy rows skipped.
- After the second-pass test strengthening:
  `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> exit code 0.
- After the second-pass test strengthening:
  `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
  -> exit code 0; expected heavy rows skipped.
- After the second-pass test strengthening:
  `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
  -> exit code 0.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `Rscript --vanilla -e 'rcmdcheck::rcmdcheck(path = ".", args = "--no-manual", quiet = TRUE, error_on = "never", check_dir = "/tmp/gllvmtmb-rcmdcheck-coevolution-metadata-20260619", env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"))'`
  -> `0 errors | 1 warning | 0 notes`.
- `rg -n "WARNING|ERROR|NOTE|clang|fixed-enum|R_ext/Boolean|whether package.*can be installed|Status" /tmp/gllvmtmb-rcmdcheck-coevolution-metadata-20260619/gllvmTMB.Rcheck/00check.log /tmp/gllvmtmb-rcmdcheck-coevolution-metadata-20260619/gllvmTMB.Rcheck/00install.out /tmp/gllvmtmb-rcmdcheck-coevolution-metadata-20260619/gllvmTMB.Rcheck/tests/testthat.Rout`
  -> only warning was the known Apple Clang / R header warning:
  `R_ext/Boolean.h:62:36: warning: unknown warning group '-Wfixed-enum-extension', ignored`.

## 7. Stale wording scan

Exact scan:

```sh
rg -n "in-engine rho|rho estimation|rho interval|rho intervals|scientific coverage|release ready|release readiness|bridge complete|kernel_includes_rho" R/kernel-helpers.R R/fit-multi.R R/extract-sigma.R tests/testthat/test-coevolution-two-kernel.R docs/design/35-validation-debt-register.md docs/design/65-cross-lineage-coevolution-kernel.md NEWS.md
```

Verdict: expected guardrail hits only. The scan found the project guard,
explicit blocked `rho`/coverage wording, the `kernel_includes_rho` roxygen
field, and the new real-fit regression assertion.

## 8. Register / roadmap / NEWS

- `docs/design/35-validation-debt-register.md`: KER-03 and COE-03 now state
  that real fitted `make_cross_kernel()` matrices retain metadata after level
  alignment.
- `docs/design/65-cross-lineage-coevolution-kernel.md`: C3.1 and C3
  verification now name retained real-fit metadata for
  `predict_cross_covariance()`.
- `NEWS.md`: fixed-rho pair-specific prediction now records omitted-level
  defaults and `kernel_includes_rho`.

No validation row was promoted. COE-03 and COE-04 stay partial where inference,
Psi grammar, null calibration, interval calibration, and in-engine `rho` remain
open.

## 9. Review roles

- Faraday (read-only TMB/engine audit) found the real-fit metadata blocker.
- Descartes (TMB/engine split audit) passed the scoped fixed multi-kernel engine
  path and requested a mixed-rank two-kernel offset guard plus numeric gradient
  threshold evidence; both were added in this second-pass test strengthening.
- Hypatia (simulation/test audit) kept the scientific-coverage verdict at WARN:
  fixed Poisson-style coverage and metadata recovery are not mixed-family
  recovery, null calibration, interval calibration, or broad COE-04 completion.
- Gauss/Noether checklist applied through the project-local
  `tmb-likelihood-review` skill. No TMB indexing blocker was found by the
  read-only audit; this slice adds fitted-gradient threshold evidence but does
  not add a full gradient-at-truth proof.
- Rose checklist applied through the after-task audit protocol.

## 10. Not run / not claimed

- Did not rerun `devtools::document()` because roxygen source was unchanged.
- Did not run full `devtools::test()` after this metadata-only fix; focused and
  heavy `kernel|coevolution` gates plus R CMD check were run instead.
- Did not push.
- Did not mutate GLLVM.jl #101.
- Did not claim bridge completion, release readiness, CRAN readiness, public
  article placement, in-engine `rho`, interval calibration, Type-I calibration,
  module uncertainty, or scientific coverage.
