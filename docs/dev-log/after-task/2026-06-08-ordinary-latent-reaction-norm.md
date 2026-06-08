# After Task: Ordinary Latent Reaction-Norm Component

**Superseded-in-branch note:** this report records the first RE-12 latent-only
slice. The same branch now implements the ordinary Gaussian paired
`latent + unique` reaction-norm path; see
`docs/dev-log/after-task/2026-06-08-ordinary-gaussian-reaction-norm.md` for
the current closeout. Statements below that call augmented `unique()` pending
describe the intermediate state before the follow-on implementation.

**Branch**: `codex/status-random-regression-article-2026-06-08`  
**Date**: `2026-06-08`  
**Roles (engaged)**: `Ada / Boole / Gauss / Noether / Curie / Fisher / Pat / Rose / Grace`

## 1. Implemented Claim

`latent(1 + x | unit, d = K)` and the long-form
`latent(0 + trait + (0 + trait):x | unit, d = K)` now fit the ordinary
unit-tier latent/shared random-regression component. The capability is
`partial` under RE-12 because the paired augmented `unique()` component and
admission-grade recovery are not implemented yet.

## 2. Mathematical Contract

For trait `t` on individual `i` at context value `x`, the implemented latent
component is

```text
eta_it = fixed_it + u_it + b_it x
(u_i1, b_i1, ..., u_iT, b_iT)' = Lambda_aug z_i
z_i ~ N(0, I_K)
Sigma_B_slope = Lambda_aug Lambda_aug'
```

The row-level design matrix `Z_B_lat` selects two rows of the augmented
coefficient vector for each observation: the trait intercept row with weight 1
and the trait slope row with weight `x`. This matches the R syntax and the TMB
implementation. It does not include `Psi_B,aug`; `extract_Sigma(level =
"unit_slope")` returns the shared latent covariance only.

| Symbol | R syntax | TMB object | Extractor | Status |
|---|---|---|---|---|
| `z_i` | `latent(... | unit, d = K)` | `z_B_slope` | random effect only | implemented |
| `Lambda_aug` | `d = K` | `Lambda_B_slope` from `theta_rr_B_slope` | reported | implemented |
| `Sigma_B_slope` | latent shared block | `Sigma_B_slope` | `extract_Sigma(level = "unit_slope")` | implemented |
| `Psi_B,aug` | augmented `unique()` | not present | `part = "unique"` errors | pending |

## 3. Code Paths

- `R/brms-sugar.R` routes supported ordinary augmented `latent()` forms to a
  marked `rr()` term carrying `.latent_augmented`, `lhs_form`, and `slope_col`.
- `R/fit-multi.R` builds `Z_B_lat`, `theta_rr_B_slope`, `z_B_slope`,
  `d_B_slope`, and `n_lhs_cols_B_lat = 2 * n_traits`; it rejects the unit_obs
  tier, delta/hurdle families, excessive `d`, and B-tier loading constraints on
  this augmented path. It also rejects a second ordinary `latent()` term at the
  same unit tier because the augmented latent vector already includes the
  intercept block.
- `src/gllvmTMB.cpp` estimates `Lambda_B_slope`, adds the augmented latent
  contribution to `eta`, applies the standard-normal prior on `z_B_slope`, and
  reports `Sigma_B_slope`.
- `R/extract-sigma.R` and `R/normalise-level.R` expose
  `level = "unit_slope"` / internal `B_slope`.

## 4. Documentation And Status

Updated `README.md`, `NEWS.md`, `ROADMAP.md`,
`docs/design/01-formula-grammar.md`, `docs/design/03-likelihoods.md`,
`docs/design/04-random-effects.md`, `docs/design/05-testing-strategy.md`,
`docs/design/35-validation-debt-register.md`, `docs/design/61-capability-status.md`,
`docs/dev-log/audits/2026-05-20-article-gate-matrix.md`, and the two random-slope
articles. The ordinary reaction-norm article stays internal until augmented
`unique()` and recovery land.

## 5. Tests And Checks

- Focused guard test: `22 passed, 0 failed`.
- New ordinary latent random-regression test: `29 passed, 0 failed`.
- Full `devtools::test()` with `NOT_CRAN=true`: `FAIL 0`, `WARN 0`,
  `SKIP 704`, `PASS 2576`.
- `devtools::document()` completed; `man/extract_Sigma.Rd` spot-check had
  keyword count `0`. The later `devtools::check()` documentation pass also
  regenerated current-R link formatting in `man/add_utm_columns.Rd`,
  `man/extract_correlations.Rd`, `man/make_mesh.Rd`, and `man/reexports.Rd`.
- Both affected articles rendered with `pkgdown::build_article(...,
  new_process = FALSE)`.
- `pkgdown::check_pkgdown()` returned `No problems found`.
- `git diff --check`, `_pkgdown.yml` YAML parse, and touched R-file parse were
  clean.
- `devtools::check(args = "--no-manual")` was run after the local gates. It
  reported `0 errors`, `1 warning`, and `2 notes`; exit status was non-zero
  because `R CMD check` treats warnings as failure. The warning was the local
  macOS/R toolchain header warning about unknown warning group
  `-Wfixed-enum-extension`; notes were future timestamp verification and
  existing `NEWS.md` section-title parsing. No latent random-regression test or
  example failure was reported.

## 6. Tests Of The Tests

The new tests satisfy the project contract in three ways. They verify the bug
that used to silently drop augmented latent slope columns now routes to a
dedicated engine path. They include boundary/rejection checks for rank and
unit_obs placement, plus the same-tier double-latent guard. They combine the
new feature with both long and wide formula surfaces and with a Poisson
non-Gaussian smoke fit.

## 7. Consistency Audit

The exact stale-wording scans and outcomes are recorded in
`docs/dev-log/check-log.md`. The important results were: no escaped-pipe
artifacts in the rendered articles, no stale `S_B` / `S_W` notation in touched
public files, and only expected legacy/status hits for `phylo_slope()` /
`animal_slope()`.

## 8. Known Limitations

- Augmented `unique(1 + x | unit)` and long-form augmented `unique()` are still
  missing, so the full `Lambda_aug Lambda_aug^T + Psi_B,aug` decomposition is
  not implemented.
- Recovery for intercept-intercept, slope-slope, and intercept-slope blocks is
  not admission-grade yet.
- Delta, hurdle, and two-stage families remain out of scope for this slope
  covariance lane.
- `lambda_constraint$B` is rejected on the augmented path until the constraint
  shape is extended from `T x K` to `2T x K`.

## 9. Next Bounded Action

Implement augmented ordinary `unique()` for `Psi_B,aug`, add the paired
extractor path, and then run a small recovery fixture for the three augmented
covariance blocks before promoting the reaction-norm article out of internal
status.

## 10. Verdict

RE-12 is correctly `partial`: the latent/shared random-regression component is
working and tested, but the full behavioural-syndrome random-regression article
is not public-ready until the augmented unique and recovery gates clear.
