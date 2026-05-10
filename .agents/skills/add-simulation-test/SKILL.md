---
name: add-simulation-test
description: Add simulation-based parameter-recovery tests for gllvmTMB models, with explicit symbolic-math <-> implementation alignment.
---

# Add a Simulation Test

Use this skill when testing model likelihoods, links, covariance
structures, and fitting workflows in gllvmTMB.

## 1. Symbolic-math <-> implementation alignment (NEVER skip)

This is the **earliest** check, before writing any code. It catches the
failure mode that produced the May 6-7 2026 round of audit FAILs:
prose-math claims one thing, the implementation does another, and the
bug doesn't surface until a careful reader compares them.

> **The principle.** Write the symbolic math FIRST. Then build the
> simulation, the fit formula, and the recovery section to match the
> symbols one-by-one. If the symbolic decomposition has six terms, the
> simulation must draw six pieces, the fit formula must contain six
> covstruct terms, and the recovery section must extract six things.
> Any term that's in the math but missing from the code (or vice versa)
> is the bug.

For every simulation test (and every article example), build a 5-row
**alignment table** -- by hand or in a comment -- before writing any
code:

| Symbol in prose | Covstruct keyword | DGP draw | Recovery extractor | Truth value |
|---|---|---|---|---|
| $r_{st}$ | `spatial_unique(0+trait\|coords)` | `simulate_site_trait(spde_range = ..., sigma2_spa = ...)` | `extract_Sigma(level = "spde")` | `0.4` |
| $u_{st}$ | `latent(0+trait\|site, d=K) + unique(0+trait\|site)` (paired) | `Lambda_B = ..., S_B = ...` | `extract_Sigma(level = "B")` | `Lambda_B Lambda_B^T + diag(S_B)` |
| $e_{sit}$ | `latent(0+trait\|site_species, d=K) + unique(0+trait\|site_species)` (paired) | `Lambda_W = ..., S_W = ...` | `extract_Sigma(level = "W")` | `Lambda_W Lambda_W^T + diag(S_W)` |
| $p_{it}$ | `phylo_latent(species, d=K) + phylo_unique(species)` (paired) | `Cphy = ..., sigma2_phy = ...` | `extract_Sigma(level = "phy")` | `Lambda_phy Lambda_phy^T + diag(U_phy)` |
| $q_{it}$ | `latent(0+trait\|species, d=K) + unique(0+trait\|species)` (paired) **OR** `unique(0+trait\|species)` standalone | `Lambda_cluster = ..., sigma2_sp = ...` | `extract_Sigma(level = "cluster")` | `Lambda_cluster Lambda_cluster^T + diag(S_cluster)` |

The five columns must align row-by-row. If a row has anything in the
"Symbol" column but the "DGP" or "Covstruct" column is empty, the
example promises something it doesn't deliver. Audit FAILs that this
table caught include the functional-biogeography missing $q_{it}$ bug
and the phylogenetic-gllvm `Lambda_phy_true` mismatch.

### The pairing principle (apply when filling in the "Covstruct" column)

For any tier with structure, the **decomposed** mode is `latent +
unique` paired together. They are not separate options -- they're a
single pair that always appears together:

$$\Sigma_{\text{tier}} = \boldsymbol\Lambda_{\text{tier}}\boldsymbol\Lambda_{\text{tier}}^\top + \mathrm{diag}(\mathbf U_{\text{tier}})$$

`latent` alone (no `unique`) means you've explicitly chosen the
no-residual / rotation-invariant subset (rare -- usually only at the
very lowest tier or for binary responses where `unique` is
unidentifiable).

`unique` alone (no `latent`) means you've chosen the
**marginal/independent** mode (Sigma = diag(s_t^2)) -- equivalent to
`indep`. That's a different model from the decomposition. Use it
deliberately, not by accident.

`indep` alone -- explicit marginal/independent.
`dep` alone -- full unstructured Sigma.

**If you find yourself writing standalone `unique(0 + trait | g)` in
an article that's claiming a multivariate / shared-axes interpretation,
you've made the bug.** Pair it with a `latent` partner.

## 2. Simulation procedure

1. State the alignment table above.
2. Simulate data from known parameters using `simulate_site_trait()`
   where possible (it handles the multi-tier draw correctly).
3. Fit the intended `gllvmTMB()` model.
4. Check convergence diagnostics (`sanity_multi()`, `gllvmTMB_diagnose()`).
5. Check estimates on the modelled scale (Sigma at each tier; profile
   CIs where exact bounds matter) and the response scale (predictions
   at sample mean).
6. Test edge cases that are scientifically likely and numerically risky.

## 3. CRAN-Safe Tests

Keep CRAN tests small and deterministic. Use fixed seeds and moderate
tolerances. Put long simulation studies in `data-raw/` or an optional
workflow gated by `Sys.getenv("RUN_SLOW_TESTS")`, not in routine
package checks.

Recommended small-DGP defaults for CRAN-safe tests:

- `n_sites <= 30`, `n_species <= 10`, `n_traits <= 5`;
- `d_B <= 2`, `d_W <= 1`;
- one tier of complexity at a time (don't combine phylo + spatial +
  cluster in a unit test).

## 4. Required Edge Cases

For Gaussian and student-t families:
- small Sigma (variance ~ 0.01);
- large Sigma (variance ~ 100);
- correlations near 0, near +/- 0.8, and at the boundary.

For binomial / betabinomial:
- low binomial denominator (n_trials = 1) -- when the unique mode
  becomes unidentifiable.

For Tweedie / delta_lognormal / delta_gamma:
- p near 1 (Poisson-like) and near 2 (Gamma-like);
- empty-cell (all-zero) trait classes.

For ordinal_probit:
- categories with rare cells (one observation per category);
- check `extract_cutpoints()` recovers the simulated thresholds.

For phylogenetic models:
- zero phylogenetic signal (sigma2_phy = 0) and full phylogenetic
  signal (sigma2_phy >> 0);
- balanced and unbalanced trees (`ape::rcoal()` vs
  `ape::rtree(..., br = ...)`);
- small (n_species = 5) and moderate (n_species = 50) tree sizes.

For spatial models:
- isotropic and anisotropic mesh choices;
- low spatial range (mesh-bounded) and large range
  (mesh-extent-limited).

## 5. Pair acceptance with rejection

The 2026-05-10 lesson: when you add a parser-rejector / guard / assert,
unit tests covering the rejection cases do NOT substitute for tests
covering the acceptance cases. Always write both halves:

```r
test_that("guard rejects the targeted bad cases", {
  expect_error(guard(<bad_form_1>), regexp = "...")
  expect_error(guard(<bad_form_2>), regexp = "...")
})

test_that("guard still accepts the acceptance cases", {
  expect_silent(guard(<canonical_good_form>))
  expect_silent(guard(<good_form_with_user_synonym_1>))  # e.g. trait_col = "outcome"
  expect_silent(guard(<good_form_with_user_synonym_2>))  # e.g. trait_col = "item"
  expect_silent(guard(<edge_case_good_form>))            # e.g. intercept-only `1 | g`
})
```
