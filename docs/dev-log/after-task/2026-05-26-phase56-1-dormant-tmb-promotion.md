# After-task -- Phase 56.1 dormant TMB promotion

**Date:** 2026-05-26
**Lead:** Ada / Codex
**Status:** Implementation draft ready for PR after final local review.
**Spawned subagents:** none.

## Task goal

Land the Phase 56.1 engine stub from Design 56 without changing the public
formula grammar: add the dormant TMB/R plumbing needed for a future
augmented-LHS phylogenetic random-regression block, while keeping the current
`phylo_slope()` path active and parser guards unchanged.

## Mathematical contract

The active public path is unchanged:

```text
b ~ N(0, sigma_slope^2 A_phy)
eta_i <- eta_i + b[species_i] * x_i
sigma_slope = exp(log_sigma_slope)
```

The dormant internal path is:

```text
vec(B) ~ N(0, Sigma_b %x% A_phy)
sd_b_j = exp(log_sd_b_j)
rho_jk = tanh(atanh_cor_b_jk)
eta_i <- eta_i + sum_k sum_j b_phy_aug[species_i, j, k] * Z_phy_aug[i, j, k]
```

For Phase 56.1, `n_lhs_cols` is block-local and restricted to 1 or 2. With
`use_phylo_slope_correlated = 0`, the wrapper maps `b_phy_aug`, `log_sd_b`,
and `atanh_cor_b` off and uses the legacy `b_phy_slope` path. This is not a
parser, public API, user-facing syntax, family, or NAMESPACE change.

## Files changed

- `src/gllvmTMB.cpp`: added dormant data, parameters, prior, dimension checks,
  and linear-predictor contribution behind `use_phylo_slope_correlated`.
- `R/fit-multi.R`: added dormant data/parameter/map-list stubs with the flag
  defaulting to false.
- `tests/testthat/test-phase56-1-phylo-augmented-stub.R`: new regression test
  for default dormancy plus finite objective/gradient probes for
  `n_lhs_cols = 1` and `n_lhs_cols = 2`.
- `docs/design/03-likelihoods.md`: recorded the dormant likelihood/prior
  contract.
- `docs/dev-log/recovery-checkpoints/2026-05-26-081743-ada-checkpoint.md`:
  recovery checkpoint after context compaction / stream loss.
- `docs/dev-log/check-log.md`: exact commands, scans, outcomes.
- This after-task report.

## Checks run

- Full suite before the final doc-only likelihood entry:
  `Rscript --vanilla -e 'devtools::test()'` ->
  `FAIL 0 | WARN 1 | SKIP 13 | PASS 2813`; warning was the pre-existing
  `level = "spde"` deprecation in `test-spatial-latent-recovery.R`.
- Focused Phase 56.1 after Gauss/Noether review and after rebase:
  `Rscript --vanilla -e 'devtools::test(filter = "phase56-1-phylo-augmented-stub")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 9`.
- Adjacent phylo engine slice:
  `Rscript --vanilla -e 'devtools::test(filter = "phylo-slope|phase56-1-phylo-augmented-stub|phylo-hadfield|phylo-mode-dispatch|phylo-q-decomposition")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 54`.
- Parser/default guard slice after rebase:
  `Rscript --vanilla -e 'devtools::test(filter = "augmented-lhs-guard|phase56-1-phylo-augmented-stub|phylo-slope")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 21`.
- `git diff --check` -> clean.

Not run: `devtools::document()` (no roxygen/Rd/NAMESPACE change),
`pkgdown::check_pkgdown()` (no pkgdown/reference/article surface change),
`devtools::check(args = "--no-manual")` (left for PR 3-OS CI).

## Consistency audit

- `rg -n 'use_phylo_slope_correlated|b_phy_aug|log_sd_b|atanh_cor_b|n_lhs_cols|Z_phy_aug|Dormant phylogenetic random-regression block' R/fit-multi.R src/gllvmTMB.cpp tests/testthat/test-phase56-1-phylo-augmented-stub.R docs/design/03-likelihoods.md docs/design/56-augmented-lhs-engine-stage3.md`
  -> code, test, Design 03, and Design 56 expose the same dormant flag,
  block-local dimension, parameter names, and coverage path.
- `rg -n 'PARAMETER_MATRIX\\(log_sd_b\\)|n_lhs_cols = T|n_lhs_cols = 2T|T × 2|T x 2|log_sd_b_intercept|log_sd_b_slope' docs/design/03-likelihoods.md docs/design/56-augmented-lhs-engine-stage3.md R/fit-multi.R src/gllvmTMB.cpp tests/testthat/test-phase56-1-phylo-augmented-stub.R`
  -> only intentional Design 56 explanatory hits remain: "not T or 2T",
  full `dep` 2T x 2T reservations, and "not earlier-draft scalar names".
- `rg -n 'phylo_slope|b_phy_slope|phylogenetic random slope|random slope|phylo.*prior|Ainv_phy|Sigma_b|b_phy_aug|log_sd_b|atanh_cor_b' docs/design/03-likelihoods.md`
  -> no hits before the doc edit; now the dormant prior contract is recorded.

## Tests of the tests

The new regression is prophylactic because the public parser keeps the branch
unreachable. It still satisfies the boundary / feature-combination rule: it
flips the internal TMB flag directly, maps the legacy random slope off, and
checks finite objective and gradients for both the scalar (`n_lhs_cols = 1`)
and bivariate (`n_lhs_cols = 2`, with `atanh_cor_b`) branches. The TMB review
initially caught that only the scalar branch was being exercised; the test was
expanded from 7 to 9 passing expectations.

## What did not go smoothly

An early `air format` pass reformatted a long R file, so that formatting churn
was backed out before the final diff. The first full-suite process survived a
context compaction but lost its UI output handle; a recovery checkpoint was
written and the full suite was rerun with captured output.

## Team learning

**Ada** kept the branch narrow after #281/#286/#282-#284 merged, rebasing only
after the coordination lane cleared.

**Boole** checked that this PR leaves parser fail-loud behaviour intact; the
`augmented-lhs-guard` test still passes.

**Gauss** reviewed the TMB prior algebra and caught the missing bivariate
branch test. The final branch uses log-SD and tanh-correlation transforms.

**Noether** checked the implementation against
`vec(B) ~ N(0, Sigma_b %x% A_phy)` and the normalizing constants for
`Sigma_b %x% A_phy`.

**Curie** required the dormant branch to be exercised by a real
`TMB::MakeADFun()` construction, not only by source inspection.

**Rose** enforced the Design Rule #4 doc cascade by adding the Phase 56.1
contract to `docs/design/03-likelihoods.md`.

**Shannon** coordinated merge order: #281, #286, #282, #283, #284, then this
56.1 branch.

## Design docs and documentation

`docs/design/03-likelihoods.md` now contains the dormant Phase 56.1
phylogenetic random-regression prior. Design 56 had already been made
canonical by #286 before this branch rebased. No README, NEWS, roxygen,
generated Rd, vignette, article, or pkgdown navigation changed.

## Roadmap tick

N/A. This is Phase 56.1 dormant plumbing only; no public capability row moves
and no `ROADMAP.md` status chip changes.

## GitHub issue ledger

Inspected:

```sh
gh issue list --repo itchyshin/gllvmTMB --state open --search 'Phase 56 OR structural slope OR phylo_slope OR random slope OR augmented LHS' --json number,title,url,labels,updatedAt
```

Result: `[]`. No relevant open issue; no new issue created because the active
tracking surface is Design 56 plus the merged scaffold PRs.

## Known limitations and next actions

- `use_phylo_slope_correlated` remains false in public fits.
- Parser activation is still Phase 56.3; this PR deliberately does not loosen
  `.assert_no_augmented_lhs()`.
- The `n_traits` -> `n_lhs_cols` audit edit remains Phase 56.2.
- Skeleton recovery-test activation remains Phase 56.4+.
- Validation-debt rows do not move until recovery evidence lands and the
  public syntax is activated.
