# 2026-06-30 -- LV axis-effect default and alpha SEs

## 1. Goal

Make the per-axis LV coefficient the default `extract_lv_effects()` output and
add standard errors plus Wald confidence intervals for `alpha`, without
replying to Ayumi's GitHub comment yet.

Mathematical contract: this is an extractor/API and documentation change, not a
likelihood, family, parser, or TMB objective change. For unit `i`, predictor
`j`, axis `k`, and trait `t`,

\[
z_{ik} = \sum_j x_{ij}\alpha_{jk} + e_{ik},
\qquad
\eta_{it} = \mu_t + \sum_k \lambda_{tk}z_{ik}.
\]

The default extractor target is now the axis / CLV coefficient
\(\alpha_{jk}\). The induced trait-scale effect remains available as

\[
B_{tj} = \sum_k \lambda_{tk}\alpha_{jk},
\qquad
B = \Lambda\alpha^\top.
\]

Axis-effect intervals are conditional on the fitted loading constraint and axis
orientation. They are not rotation-invariant calibrated coverage claims.

## 2. Implemented

- `extract_lv_effects()` now defaults to `type = "axis_effect"`.
- Added `conf.level = 0.95`.
- Native TMB axis effects now return `std.error`, `lower`, and `upper` when
  `se = TRUE` produces a positive-definite `sdreport()`. The SEs are read from
  the fixed-parameter `alpha_lv_B` block.
- Native TMB trait effects still use `ADREPORT(B_lv_unit)` but now also return
  Wald `lower` / `upper` columns.
- Julia bridge extractor rows now use the same axis-default schema. Existing
  trait-effect Wald payloads are preserved, and optional future alpha payloads
  (`alpha_lv_se`, `alpha_lv_lower`, `alpha_lv_upper`) are normalised and
  surfaced.

## 3a. Decisions and Rejected Alternatives

- Chose `axis_effect` as the default because it is the usual GLLVM / constrained
  latent-variable coefficient. This directly supersedes the older
  2026-06-24 after-task note that called `B_lv` the preferred public table.
- Kept `trait_effect` explicit rather than removing it. `B_lv` is useful as the
  rotation-invariant induced trait-scale slope surface.
- Did not change the TMB objective or add `ADREPORT(alpha_lv_B)`, because
  `alpha_lv_B` is already a fixed parameter and its covariance is available in
  `summary(fit$sd_report, "fixed")`.
- Did not claim calibrated axis-effect coverage. The returned intervals are
  Wald summaries conditional on the fitted axis convention.
- Did not post to Ayumi. The maintainer asked to hold the reply until SEs were
  implemented.

## 4. Files Touched

- `R/extractors.R`
- `R/julia-bridge.R`
- `tests/testthat/test-lv-parser-guard.R`
- `tests/testthat/test-lv-gaussian-recovery.R`
- `tests/testthat/test-julia-bridge.R`
- `tests/testthat/test-lv-factor-runtime.R`
- `tests/testthat/test-lv-bernoulli-depth.R`
- `tests/testthat/test-lv-missing-response.R`
- `man/extract_lv_effects.Rd`
- `man/gllvm_julia_fit.Rd`
- `man/gllvmTMB_julia-methods.Rd`
- `NEWS.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-30-lv-axis-effect-se.md`

No examples, vignettes, README, `_pkgdown.yml`, NAMESPACE, or TMB source files
were changed.

## 5. Checks Run

- `air format R/extractors.R R/julia-bridge.R tests/testthat/test-lv-parser-guard.R tests/testthat/test-lv-gaussian-recovery.R tests/testthat/test-julia-bridge.R tests/testthat/test-lv-factor-runtime.R tests/testthat/test-lv-bernoulli-depth.R tests/testthat/test-lv-missing-response.R`
  -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard|lv-gaussian-recovery|lv-factor-runtime|lv-bernoulli-depth|lv-missing-response|julia-bridge", reporter = "summary", stop_on_failure = TRUE)'`
  -> PASS. Nineteen live Julia tests skipped because `{JuliaCall}` is not
  installed. One heavy rank-2 recovery test skipped because
  `GLLVMTMB_HEAVY_TESTS` was unset. One existing Julia bridge Psi warning was
  emitted.
- `Rscript --vanilla -e 'devtools::test(filter = "lv-wald-coverage-harness", reporter = "summary", stop_on_failure = TRUE)'`
  -> PASS; two opt-in live fit smokes skipped.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS with pre-existing roxygen warnings for uninstalled `MCMCglmm` and
  unresolved internal links; regenerated the three changed Rd files.
- `Rscript --vanilla -e 'files <- c("man/extract_lv_effects.Rd", "man/gllvm_julia_fit.Rd", "man/gllvmTMB_julia-methods.Rd"); for (f in files) { cat("--", f, "--\n"); tools::checkRd(f) }; cat("rd-check-ok\n")'`
  -> PASS.
- `git diff --check -- R/extractors.R R/julia-bridge.R tests/testthat/test-lv-parser-guard.R tests/testthat/test-lv-gaussian-recovery.R tests/testthat/test-julia-bridge.R NEWS.md docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md man/extract_lv_effects.Rd man/gllvm_julia_fit.Rd man/gllvmTMB_julia-methods.Rd`
  -> PASS.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> FAIL because the default R library path lacks `MCMCglmm`; 20 phylo/animal
  tests aborted in the tree path. This was an environment failure, not an
  extractor regression.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-r-live-lib:/private/tmp/gllvmtmb-check-lib:$HOME/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS in 4m 54s; `0 errors | 0 warnings | 0 notes`.

Not run: `pkgdown::check_pkgdown()` and article renders. No vignette code,
parser grammar, pkgdown navigation, or examples changed.

## 6. Tests of the Tests

The default-output tests would fail if `extract_lv_effects(fit)` returned
`B_lv` instead of `alpha`. The `sdreport` tests compare alpha SEs directly to
the `summary(fit$sd_report, "fixed")` rows, so an ordering mismatch in
`alpha_lv_B` would fail. The `conf.level = 0.80` check would fail if the
interval width ignored the requested level. The invalid `conf.level = 1` check
covers the new argument's failure path. The trait-effect tests still compare
`B_lv` SEs to `ADREPORT(B_lv_unit)` and would fail if the explicit
`type = "trait_effect"` route broke.

## 7a. Issue Ledger

- Reviewed Ayumi's comment
  `Ayumi-495/urbanisation_map#issuecomment-4845237642`; it identified the
  default/SE mismatch. No GitHub reply was posted.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'extract_lv_effects alpha axis effect' ...`
  -> no matching open gllvmTMB issue.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'latent lv alpha standard error' ...`
  -> no matching open gllvmTMB issue.
- Roadmap tick: N/A; no `ROADMAP.md` row, status chip, or progress bar changed.

## 8. Consistency Audit

- `rg -n 'preferred.*B_lv|B_lv.*preferred|trait-scale table is the preferred|raw \`alpha\` only|extract_lv_effects\(fit, level = "unit", type = "trait_effect"\)|extract_lv_effects\(\) returns trait-scale|type = "axis_effect"\) \| ❌ no|point estimates only: \`std.error = NA\`|axis_effect.*diagnostic use' R docs/design NEWS.md man tests/testthat/test-lv*.R tests/testthat/test-julia-bridge.R`
  -> PASS; no stale current-source hits. Historical after-task reports were
  left unchanged.
- `rg -n 'extract_lv_effects\(fit\)|extract_lv_effects\([^\n]*\)' tests/testthat/test-lv*.R tests/testthat/test-julia-bridge.R | head -120`
  -> REVIEWED; bare default calls are now intentional axis-effect checks, while
  B/trait-effect recovery checks call `type = "trait_effect"` explicitly.

The validation-debt row `EXT-31` remains partial. Existing coverage rows for
`B_lv` are not repurposed as alpha coverage evidence.

## 9. What Did Not Go Smoothly

One test initially failed because it expected `extract_lv_effects(no_payload)`
to require `lv_effects`. After the default switch, that call correctly returns
the available `alpha_lv` table. The test now checks the missing-`lv_effects`
error on `type = "trait_effect"`.

Roxygen initially warned about an invalid
`[extract_lv_effects(type = "trait_effect")]` link. The link was changed to
`[extract_lv_effects()]` plus plain text.

The first full `devtools::check()` used the default R library path, which did
not have `MCMCglmm`; rerunning with the project check libraries resolved the
environment issue and passed cleanly.

## 10. Known Residuals

Axis-effect Wald intervals are conditional on the fitted loading constraint and
axis orientation. They are not rotation-invariant in the way
`B_lv = Lambda alpha^T` is. No source-specific LV rows, factor-predictor
interval coverage, Julia alpha CI production payload, or broad calibrated alpha
coverage grid landed in this slice.

## 11. Team Learning

Ada: the clean side worktree avoided contaminating the large dirty dashboard /
bridge checkout and kept this API slice reviewable.

Boole: the default object should match the user's first mental model. Here that
is the per-axis CLV coefficient, while the trait-scale induced slope should be
explicitly named.

Fisher: finite Wald SEs are not the same as calibrated interval coverage. The
reporting language keeps alpha CI output conditional on the axis convention and
keeps `EXT-31` partial.

Rose: historical after-task notes can remain true for their date, but current
source docs need a clean superseding decision. The stale-wording scans exclude
old after-task notes for that reason.
