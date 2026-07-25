# S8 — Does `phylo_unique(1 + x | species)` really differ structurally from `phylo_indep(1 + x | species)`?

Evidence engineering task (Curie lens). Worktree
`/Users/z3437171/local-scratch/worktrees/gllvmtmb-slope-semantics`, branch
`claude/slope-semantics-evidence-20260725`.

## 1. The NEWS claim, verbatim

`NEWS.md` lines 140-155 ("Changed" section):

> Current `phylo_indep()`, `animal_indep()`, and `spatial_indep()`
> intercept-and-slope terms fit **one independent 2 x 2 (intercept, slope)
> block per trait**: within-trait correlation is estimated for `|`, fixed to
> zero for `||`, and cross-trait covariance is zero. Current `*_dep()` routes
> instead use a full 2T x 2T augmented covariance. The soft-deprecated
> `phylo_unique()`, `animal_unique()`, and `spatial_unique()` slope forms
> retain their legacy shared 2 x 2 channels; **they are not aliases for the
> current `*_indep()` shape**.

(the load-bearing sentence is at line 144-146: "The soft-deprecated
`phylo_unique()`, `animal_unique()`, and `spatial_unique()` slope forms
retain their legacy shared 2 x 2 channels; they are not aliases for the
current `*_indep()` shape.")

## 2. What the code says

- `R/brms-sugar.R` lines 28-31 (roxygen for the covariance grid) makes a
  **narrower, different claim** — about the **standalone** (intercept-only)
  case only: "`unique` standalone (without `latent`) and `indep` standalone
  are mathematically identical (both produce `diag(sigma^2_t)`); the keyword
  distinction is documentary, not operational." This says nothing about the
  augmented-slope case, so it does not contradict the NEWS slope claim — the
  two passages describe two different cells (standalone vs. slope) of the
  same keyword pair.
- `tests/testthat/test-canonical-keywords.R:429-458` only tests the
  **standalone** pair (`phylo_indep(0 + trait | species)` vs.
  `phylo_unique(species)`), confirming byte-identical objectives there. No
  existing test exercised the augmented-slope pair before this task.
- `R/fit-multi.R` parser/engine trace (read-only, not edited):
  - `phylo_unique(1 + x | species)` sets `.phylo_unique_augmented` (not
    `.phylo_dep_augmented`), so `use_phylo_dep_slope` stays `FALSE` and
    `use_phylo_slope_correlated` is driven only by the legacy flag
    (`R/fit-multi.R:1442-1444`). Its design array is built at
    `R/fit-multi.R:3247-3259`: `n_lhs_cols <- 2L` (fixed at 2, **regardless
    of `n_traits`**), and `Z_phy_aug[, 1, 1] <- 1`, `Z_phy_aug[, 2, 1] <-
    x_phy_slope_dat` are populated **identically for every row regardless of
    trait** — i.e. one (intercept, slope) random-effect block, shared by
    every trait.
  - `phylo_indep(1 + x | species)` is instead routed onto the `phylo_dep`
    2T-wide engine with the `.indep_blockdiag` pin
    (`R/fit-multi.R:1453-1481`): `n_lhs_cols <- (1 + n_phy_slope) * n_traits`
    (`R/fit-multi.R:3218-3219`), i.e. `2 * n_traits` for a single slope, with
    the design array built per-trait (`R/fit-multi.R:3236-3246`) and the
    cross-trait Cholesky entries of the unstructured `Sigma_b_dep` pinned to
    zero, leaving one free 2x2 (intercept, slope) block **per trait**.
  - `R/extract-sigma.R` reports the two paths through different slots:
    the closed-form engine reports `report$sd_b` (length 2) /
    `report$cor_b` (length 1) and no `Sigma_b_dep`
    (`R/extract-sigma.R:951-1005`); the dep/indep engine reports
    `report$Sigma_b_dep` (the full `(1+s)T x (1+s)T` matrix,
    `R/extract-sigma.R:886-905`).
  - `tests/testthat/test-phase56-3-phylo-unique-parser.R:64-84` and
    `tests/testthat/test-extract-sigma-augmented-unique.R` already pin
    `n_lhs_cols == 2` and the `sd_b`/`cor_b` reporting for the
    `phylo_unique` augmented path in isolation, but neither file compares it
    to `phylo_indep` on the same data — so the code strongly implies the
    NEWS claim, but nothing exercised both keywords side by side before this
    task.

## 3. Experiment

Same DGP, one seed, gaussian family, small data (structural question, not a
recovery question): `n_sp = 20` (star tree via `ape::rcoal`, no VCV
confound), `n_traits = 3`, `n_rep = 5` (300 long-format rows). Truth was
drawn **per-trait** (distinct `sigma2_int`, `sigma2_slope`, `rho` per trait,
phylogenetically correlated intercept/slope draws) so the comparison is not
rigged toward either keyword. Both models fit on the identical
`data.frame`/tree/`Cphy`/family:

```r
value ~ 0 + trait + phylo_unique(1 + x | species, vcv = Cphy)   # deprecated
value ~ 0 + trait + phylo_indep(1 + x | species,  vcv = Cphy)   # canonical
```

`gaussian()` family, `phylo_tree = tree, unit = "species", cluster =
"species"`. Script:
`/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/ed064c95-cada-4788-83e8-ac5c0503c042/scratchpad/s8-experiment.R`.

## 4. Fitted structures, side by side

| | `phylo_unique(1+x\|species)` | `phylo_indep(1+x\|species)` |
|---|---|---|
| `tmb_data$n_lhs_cols` | **2** | **6** (= 2 x n_traits) |
| `tmb_data$use_phylo_slope_correlated` | 1 | 1 |
| free parameters (`length(opt$par)`) | **7** | **13** |
| `report$sd_b` | `c(0.317, 0.321)` (length 2, shared) | `c(0.609, 0.499, 0.726, 0.730, 0.897, 0.527)` (length 6; a diagonal-derived convenience vector, not the load-bearing slot for this engine) |
| `report$cor_b` | `0.104` (length 1, shared) | *(not the load-bearing slot for this engine)* |
| `report$Sigma_b_dep` | `NULL` | 6x6, **block-diagonal**: 3 free 2x2 blocks (one per trait) on the diagonal, all off-block entries exactly `0` |
| `report$cor_b_mat` | *(n/a)* | 6x6 correlation analogue of `Sigma_b_dep`, same block-diagonal pattern (within-trait rho = 0.080, -0.260, 0.410 per trait; all cross-trait entries 0) |
| convergence / pd_hessian / sdreport_ok | 0 / TRUE / TRUE | 0 / TRUE / TRUE |
| `opt$objective` (neg log-lik) | **299.26** | **145.21** |
| `extract_Sigma(fit, level="phy")$level` | `"phy_unique_slope"` | `"phy_indep_slope"` |
| `extract_Sigma(...)$note` | *"2x2 (intercept, slope) covariance **shared across traits**"* | *"the trait-stacked ... covariance ... `indep` is block-diagonal across traits (per-trait blocks, no cross-trait covariance)"* |

**Non-degeneracy check (done, not assumed):** both fits have
`convergence == 0`, `fit_health$pd_hessian == TRUE`,
`fit_health$sdreport_ok == TRUE`, `max_gradient` on the order of `1e-4`–`1e-5`.
`phylo_unique`'s `sd_b` (0.317, 0.321) is far from the zero boundary and
`cor_b` (0.104) is far from ±1. `phylo_indep`'s `Sigma_b_dep` diagonal
entries (0.371, 0.249, 0.527, 0.533, 0.804, 0.278) are all far from zero and
its within-trait correlations (0.080, -0.260, 0.410) are all far from ±1. Two
collapsed fits would prove nothing; neither fit is collapsed.

Objective difference: `fit_indep$opt$objective - fit_unique$opt$objective =
-154.05` (not byte-identical, `all.equal(..., tolerance = 1e-10)` is FALSE).
The direction (indep fits far better here) is a property of this
particular per-trait DGP and is **not** asserted as a general direction in
the new test (marginal-likelihood comparisons across different random-effect
structures are not guaranteed monotone by nesting, unlike fixed-effect
likelihood-ratio comparisons) — only that the two objectives differ, which
they do by 154 units of neg-log-lik, far outside numerical noise.

## 5. VERDICT: **CLAIM VERIFIED**

`phylo_unique(1 + x | species)` and `phylo_indep(1 + x | species)` build
genuinely different covariance structures:

- `phylo_unique` slope: **one (intercept, slope) 2x2 covariance block,
  estimated once and applied identically to every trait** — `n_lhs_cols ==
  2`, `report$sd_b` (len 2) / `report$cor_b` (len 1), no `Sigma_b_dep`.
- `phylo_indep` slope: **one INDEPENDENT (intercept, slope) 2x2 block per
  trait**, no cross-trait covariance — `n_lhs_cols == 2 * n_traits`,
  `report$Sigma_b_dep` block-diagonal with `n_traits` free 2x2 blocks.

These have different numbers of free parameters (7 vs. 13 in the
experiment, and in general `T + 4` vs. `4T + 1` for `T` traits — strictly
more for `phylo_indep` whenever `T > 1`), a different random-effect
dimension (76 vs. 228 entries of `b_phy_aug` in the wider n_sp=20 run — the
per-trait engine allocates `n_traits` times as many phylogenetic random
effects), and are reported through different `report`/`extract_Sigma()`
slots. NEWS.md's claim is correct and is **not** in tension with the
`R/brms-sugar.R` roxygen, because that roxygen is scoped to the standalone
(intercept-only) case, which is a genuinely different (and correctly
equivalent) cell.

No corrected NEWS wording is proposed — the existing text is accurate.

## 6. New test

`tests/testthat/test-unique-indep-slope-semantics.R` (testthat 3, fixed
seed 563, star tree / identity VCV so only the slope-covariance shape is
under test, `n_sp = 8`, `n_traits = 2`, `n_rep = 3` for speed). Five
`test_that()` blocks:

1. `phylo_unique(1+x|species)` fires the unique-family deprecation warning.
2. The two keywords build different engines: `n_lhs_cols` (2 vs. 2 x
   n_traits), non-degeneracy (`convergence == 0`, `fit_health$converged`,
   `fit_health$pd_hessian` for both), and `length(opt$par)` strictly greater
   for `phylo_indep`.
3. `phylo_unique` reports a single shared `sd_b`(len 2)/`cor_b`(len 1) block
   with no `Sigma_b_dep`, and the reported values are away from the
   zero/±1 boundaries.
4. `phylo_indep` reports a block-diagonal `Sigma_b_dep` (dim `2*n_traits`
   square), off-diagonal cross-trait blocks exactly zero, within-trait
   entries not all zero, diagonal (variance) entries away from the zero
   boundary.
5. The two objectives at their respective MLEs are not equal (asserted
   `!isTRUE(all.equal(..., tolerance = 1e-6))`), unlike the
   byte-identical-objective standalone pair in
   `test-canonical-keywords.R`.

**Result:** all 5 blocks pass, ~4.2 s wall time
(`testthat::test_file("tests/testthat/test-unique-indep-slope-semantics.R")`).

## 7. Secondary task outcome: nbinom1 canonical twins ADDED

`tests/testthat/test-tiers-nbinom1.R:144` (`phylo_unique(species)`) and
`:271` (`spatial_unique(0 + trait | site)`) were, before this task, the
**only** nbinom1 structured-tier coverage, both written through the
soft-deprecated spelling with no canonical `*_indep()` twin — confirmed by
grepping the whole suite for `nbinom1` + `phylo_indep`/`spatial_indep`
(none existed).

Timed the existing heavy file first
(`GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`): the full 3-cell
`test-tiers-nbinom1.R` runs in **6.5 s**, so adding two canonical twins
(same seeds/DGP/bands, standalone intercept-only case, which per §5 above is
the keyword-equivalent cell, not the slope cell) was judged fast and safe.

Added `tests/testthat/test-tiers-nbinom1-canonical-twins.R` (new file,
kept separate from `test-tiers-nbinom1.R` to avoid touching a file any
concurrent agent might also be editing), with:

- `nbinom1 x phylo_indep(0 + trait | species)`: same seed (101), same
  `n_sp = 50`, same 4x-band total-phylo-variance check as the deprecated
  twin. Asserts `fit$use$phylo_indep` (not `fit$use$phylo_rr`, which is the
  deprecated cell's flag).
- `nbinom1 x spatial_indep(0 + trait | site)`: same `simulate_site_trait()`
  call/seed as the deprecated twin. Asserts `fit$use$spatial_indep` and
  `fit$use$spde`.

**Result:** both new twins pass, **6.3 s** wall time for the whole new file
(`GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`); the original
`test-tiers-nbinom1.R` still passes unchanged (6.6 s). No slow fits were
encountered — the secondary task was completed, not skipped.

## 8. Warnings, verbatim

From the exploratory experiment (`gllvmTMB(..., phylo_tree = tree, ...)`,
displayed once per R session):

```
! `phylo_tree = ...` as a global argument to `gllvmTMB()` is deprecated.
ℹ Pass `tree = ...` inside the phylo_*() keyword instead, e.g.
  `phylo_latent(species, d = 2, tree = tree)`.
→ The legacy global path still works; the in-keyword syntax avoids silent
  index/order mismatch.
This message is displayed once per session.
```

From every `phylo_unique(...)` call (the expected, correct deprecation
warning for the soft-deprecated keyword — not suppressed, not filtered):

```
! Formula keyword `phylo_unique()` is soft-deprecated as of gllvmTMB 0.2.0
  (compatibility syntax).
ℹ `unique()` / `*_unique()` are compatibility syntax while Psi moves into the
  latent-family grammar.
→ For standalone diagonal tiers use `indep()` / `*_indep()`; ordinary
  `latent()` now carries Psi by default.
```

No other warnings were observed from either fit (`phylo_indep(...)` calls
produced no warnings in the experiment or in the new tests).

## 9. Verification commands run

```r
devtools::load_all(".")   # loads clean, package-startup EXPERIMENTAL notice only
devtools::test(filter = "unique|indep|canonical")
```

Result: **33 test files, 460 expectations, 0 failures, 0 unexpected
warnings, 70 skipped (all gated `skip_if_not_heavy()`/missing-package
skips, pre-existing), 390 passed.** This run includes the new
`test-unique-indep-slope-semantics.R` (5/5 pass) alongside the pre-existing
suite — no regressions introduced.

```
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true
testthat::test_file("tests/testthat/test-tiers-nbinom1-canonical-twins.R")  # 2/2 pass, 6.3s
testthat::test_file("tests/testthat/test-tiers-nbinom1.R")                  # 3/3 pass, 6.6s (unchanged)
```
