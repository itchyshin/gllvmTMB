# After Task: LV Native Gaussian Recovery

## Goal

Move the Design 73 ordinary unit-tier Gaussian `latent(..., lv = ~ x)`
lane from routing/smoke evidence to focused native TMB recovery evidence,
without promoting interval coverage, missing-response support, mixed-family
support, source-specific `lv`, or broad Julia bridge parity.

## Implemented

Added `tests/testthat/test-lv-gaussian-recovery.R`. The CRAN-safe rank-1
fixture simulates a known Gaussian predictor-informed latent-score DGP, fits
`value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ x)`, and checks
convergence, positive-definite `sdreport()`, finite `ADREPORT(B_lv_unit)` SEs,
extractor/report SE agreement, an independent manual delta-method SE
calculation for `B_lv`, primary `B_lv` recovery, and secondary total-`Sigma`
recovery with finite non-negative `Psi`. A heavy rank-2 fixture repeats the
rotation-stable `B_lv` / `Sigma` recovery target while deliberately avoiding raw
`alpha` or raw `Lambda` as pass/fail quantities.

`LV-02` moved from `blocked` to `partial`. `LV-01`, `FG-18`, `RE-13`, and
`EXT-31` now point at the new evidence where relevant. `LV-03`, `LV-06`, and
`LV-07` remain blocked; `LV-05` remains a narrow pure-binomial point/recovery
row; Wald SEs remain labelled `wald_sdreport_no_ci_validation`.

## Mathematical Contract

The tested ordinary Gaussian C1 model is:

```text
z_i = M_i alpha + e_i,    e_i ~ N(0, I_K)
eta_it = beta_t + lambda_t' z_i + q_it
q_it ~ N(0, psi_t^2)
B_lv = Lambda alpha'
Sigma_unit = Lambda Lambda' + Psi
```

No public formula grammar, likelihood parameterization, family code, exported
function, roxygen, generated Rd, vignette, or pkgdown navigation changed in this
slice. The new evidence validates recovery targets for the existing native TMB
ordinary Gaussian path only. It is not REML / AI-REML, not `latent(1 + x |
unit)`, not phylo/spatial/kernel `lv`, not a mean-only constrained ordination,
and not interval calibration.

## Files Changed

- `tests/testthat/test-lv-gaussian-recovery.R`: new focused Gaussian DGP,
  fit helper, manual delta-SE check, CRAN-safe rank-1 test, and heavy rank-2
  test.
- `NEWS.md`: updated the Design 73 entry so it says focused Gaussian recovery
  is partial, while interval, Bernoulli depth, missing response, mixed family,
  source-specific, and broad Julia bridge rows remain gated.
- `docs/design/01-formula-grammar.md`
- `docs/design/03-likelihoods.md`
- `docs/design/04-random-effects.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/61-capability-status.md`
- `docs/design/73-predictor-informed-latent-scores.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-28-lv-native-gaussian-recovery.md`

## Checks Run

- `air format tests/testthat/test-lv-gaussian-recovery.R` -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "lv-gaussian-recovery", reporter = "summary")'`
  -> PASS; rank-1 ran and rank-2 skipped behind `GLLVMTMB_HEAVY_TESTS=1`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "lv-gaussian-recovery", reporter = "summary")'`
  -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "lv-parser-guard", reporter = "summary")'`
  -> PASS.
- `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> PASS with 18 live-Julia skips because `{JuliaCall}` is not installed and
  one expected Julia-bridge `Psi` warning.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> PASS.
- `git diff --check` -> PASS.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> FAIL because `{MCMCglmm}` was not visible to the built-check test
  environment; the failures were existing phylo/tree rows, not the new LV
  Gaussian recovery file.
- `mkdir -p /private/tmp/gllvmtmb-check-lib && R_LIBS_USER=/private/tmp/gllvmtmb-check-lib Rscript --vanilla -e '.libPaths(c(Sys.getenv("R_LIBS_USER"), .libPaths())); install.packages("MCMCglmm", repos = "https://cloud.r-project.org")'`
  -> PASS; installed `{MCMCglmm}` and dependencies into a temporary library.
- `NOT_CRAN=true R_LIBS=/private/tmp/gllvmtmb-check-lib:/Users/z3437171/Library/R/arm64/4.6/library Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> PASS; R CMD check completed with 0 errors, 0 warnings, and 0 notes.
- After rebasing onto #564's merge commit `aa5d1980`,
  `Rscript --vanilla -e 'devtools::test(filter = "lv-gaussian-recovery", reporter = "summary")'`
  -> PASS; `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> PASS; and
  `git diff --check` -> PASS.

## Tests Of The Tests

This is a recovery-test slice rather than a bug reproducer. It satisfies the
boundary/feature-combination rule by combining Design 73 `lv = ~ x` with the
ordinary Gaussian latent block, `sdreport()`, `ADREPORT(B_lv_unit)`, extractor
SEs, `extract_Sigma(part = "shared" / "unique" / "total")`, and a heavy rank-2
rotation-aware target.

The test would catch: broken `alpha_lv_B` routing, lost `B_lv_unit` ADREPORT
rows, extractor/report SE disagreement, an incorrect rank-1 delta gradient,
failure to preserve the ordinary `Psi` companion in native TMB, and accidental
promotion of raw `alpha` / `Lambda` as rank-2 pass/fail targets.

## Consistency Audit

- `rg -n 'not yet a recovery-validated|not yet Gaussian recovery|not Gaussian recovery|Gaussian recovery.*pending|small Gaussian.*smoke/algebra|no Gaussian recovery grid|recovery and interval evidence\s+remain pending|LV-02.*blocked' NEWS.md docs/design docs/dev-log/known-limitations.md README.md ROADMAP.md`
  -> PASS; no stale hits.
- `rg -n 'lv =|predictor-informed|latent-score mean|B_lv|LV-0[1-7]|FG-18|RE-13|EXT-31' NEWS.md docs/design README.md ROADMAP.md docs/dev-log/known-limitations.md tests/testthat/test-lv-gaussian-recovery.R`
  -> REVIEWED; updated rows show LV-02 as partial and keep blocked rows
  blocked.
- `rg -n 'complete|covered|validated|interval calibration|coverage|wald_sdreport_no_ci_validation|julia_bridge_point_estimate_only_no_ci_validation|Bernoulli single-trial|mixed-family|phylo_latent\([^\n]*lv|spatial_latent\([^\n]*lv|kernel_latent\([^\n]*lv' NEWS.md docs/design/35-validation-debt-register.md docs/design/61-capability-status.md docs/design/73-predictor-informed-latent-scores.md docs/design/04-random-effects.md docs/design/06-extractors-contract.md`
  -> REVIEWED; the new claim is partial/gated, Wald SEs remain no-CI, Julia
  `X_lv` remains point-only, and source-specific / mixed-family `lv` rows remain
  rejected or planned.
- `printf 'rows='; rg '^\| [A-Z]+-[0-9A-Z]+ \|' docs/design/35-validation-debt-register.md | wc -l; printf 'covered='; rg '^\| [A-Z]+-[0-9A-Z]+ \|.*\| `covered' docs/design/35-validation-debt-register.md | wc -l; printf 'partial='; rg '^\| [A-Z]+-[0-9A-Z]+ \|.*\| `partial' docs/design/35-validation-debt-register.md | wc -l; printf 'blocked='; rg '^\| [A-Z]+-[0-9A-Z]+ \|.*\| `blocked' docs/design/35-validation-debt-register.md | wc -l; printf 'opt-in='; rg '^\| [A-Z]+-[0-9A-Z]+ \|.*\| `opt-in' docs/design/35-validation-debt-register.md | wc -l`
  -> REVIEWED; 213 rows, 173 covered, 30 partial, 10 blocked, 0 opt-in.

## What Did Not Go Smoothly

The first recovery fixture at `n_units = 36` recovered `B_lv` but missed the
secondary total-`Sigma` relative-error band, so the CRAN-safe rank-1 fixture was
raised to `n_units = 72`. The first rank-2 run also exposed that the simple
manual delta calculation is valid only for rank 1 because the rank-2 loading
parameterization is constrained; the test now checks manual delta SEs only where
the gradient is actually aligned with the free parameters.

The first full package check failed because `{MCMCglmm}` was absent from the
library visible to source-package tests. Installing it into a temporary
`/private/tmp` library and rerunning with that library plus the normal user
library in `R_LIBS` produced a clean 0/0/0 check.

## Team Learning

Noether: the symbolic and implementation targets stayed aligned once the test
focused on `B_lv = Lambda alpha'` and `Sigma = Lambda Lambda' + Psi`; raw
`alpha` and `Lambda` remain rank-dependent diagnostics, not rank-2 truth targets.

Gauss: native TMB `Psi` preservation is now explicitly tested through
`extract_Sigma(part = "total") = shared + diag(unique)`, while the Julia bridge
route remains a `unique = FALSE` point-only path.

Curie and Fisher: this is recovery evidence, not interval evidence. The next
inference slice needs 500 reps/cell, MCSE, convergence denominators, PD-Hessian
denominators, and a decision about Wald versus profile/bootstrap rescue.

Boole and Pat: docs continue to separate predictor-informed latent-score means
from augmented random regression `latent(1 + x | unit)`.

Rose and Shannon: the status inventory now says `LV-02` partial, not blocked,
and the register tally was recounted from row tokens after the promotion.

Grace: validation ran from the clean `/private/tmp` worktree. No public claim is
based on the dirty Dropbox checkout.

## Design-Doc Updates

Updated Design 73, the validation-debt register, capability status, formula
grammar, likelihood notes, random-effects notes, testing strategy, and extractor
contract. The key invariant across all pages is: ordinary native TMB Gaussian
recovery is partial; interval calibration and broader family/tier/source support
remain gated.

## Pkgdown / Documentation Updates

No roxygen, generated Rd, vignette, article, `_pkgdown.yml`, or pkgdown
navigation files changed. `pkgdown::check_pkgdown()` passed after the NEWS and
design-doc updates.

## Roadmap Tick

N/A. No `ROADMAP.md` status chip or progress bar changed in this recovery-test
slice.

## GitHub Issue Ledger

- `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,isDraft,mergeStateStatus,url,updatedAt`
  found one open PR, #564, `claude/xlv-bridge-closeout`, clean and non-draft.
- Post-rebase coordination refresh: #564 was clarified, passed CI, and merged
  at `aa5d1980c36ceab93b10942145249d14472985d8`; a fresh open-PR census then
  returned `[]` before this native Gaussian branch was published.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "Design 73 OR LV-02 OR latent lv OR predictor-informed latent" --json number,title,state,url,updatedAt --limit 20`
  returned #526, #348, #346, #349, and #340. These are broader spatial,
  family-validation, simulation/coverage, power, and capability-board issues.
  No issue was closed or created in this slice.

## Known Limitations

No Gaussian 500-rep coverage grid, no Bernoulli single-trial depth, no
missing-response compatibility, no factor runtime recovery, no Poisson / NB /
Gamma / Beta / ordinal / mixed-family `lv`, no response masks, no fixed-effect
`X + X_lv`, no Julia `X_lv` intervals, no source-specific R grammar, no
GLLVM.jl PR #127 fix, and no DRAC campaign ran here.

## Next Actions

1. Run the native TMB Gaussian `B_lv` interval coverage grid with at least 500
   reps/cell and MCSE/failed-fit denominators.
2. Add Bernoulli single-trial binomial depth and separation diagnostics.
3. Add missing-response and factor-runtime smokes for ordinary unit-tier `lv`.
4. Keep source-specific `phylo_latent(..., lv = ~ x)` fail-loud in R until
   GLLVM.jl Model A CI and DRAC evidence are clean.
