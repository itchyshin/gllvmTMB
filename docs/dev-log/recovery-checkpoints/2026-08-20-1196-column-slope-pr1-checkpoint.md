# PR-1 diagonal column slopes — recovery checkpoint

- **Branch:** `codex/1196-column-slopes-diagonal`
- **HEAD:** `fc3d65e7` before the uncommitted review follow-up.
- **Worktree:** `/private/tmp/gllvmtmb-1196-column-slopes-diagonal`
- **Status:** pushed, no pull request opened.

## What is in the branch

`phylo_indep(0 + lat + temp | trait, tree/vcv = ...)` now routes through the
existing matrix-normal `b_phy_aug + theta_dep_chol` engine with a term-local
RHS-resolved phylogenetic precision/map. Its predictor-basis Cholesky is
diagonal, so it has no random intercept and no latitude-temperature covariance.
`extract_Sigma(fit, level = "column_slope")` returns that named predictor
covariance rather than a trait-level Sigma.

The existing `phylo_slope()` scalar helper is not changed. The new term fails
loudly for non-Gaussian responses, non-bare/non-numeric/non-finite predictors,
a RHS other than the resolved `trait`, and a second phylogenetic tier with a
different indexing axis.

## Evidence run

- `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "phylo-column-slope-indep", reporter = "summary")`: pass. The retained four-seed Gaussian cell checks both mean SD recovery and the nonidentity trait-source matrix; its identity-source negative control has a worse objective.
- `devtools::test(filter = "phylo-column-slope-indep|phylo-slope-rhs-routing", reporter = "summary")`: pass with the heavy recovery cell correctly skipped.
- `devtools::test(filter = "phylo-indep-slope-gaussian", reporter = "summary")`: no failures; two heavy recovery tests skipped without `GLLVMTMB_HEAVY_TESTS=1`.
- `pkgdown::check_pkgdown()`: pass (13 pre-existing/non-blocking warnings reported by pkgdown).
- `git diff --check`: pass before the commits.
- One local Gaussian recovery pre-run (12 traits x 50 units): true slope SDs
  `(lat = 0.60, temp = 0.35)`, estimates `(0.466, 0.306)`, convergence `0`.
  This is a calibration probe, not a campaign or coverage claim.

## Gates still owed

**2026-08-24 design-record reconciliation:** the phrase “Design 130 contract
files” below referred to an unnumbered future contract when this checkpoint
was written. It now resolves to
`docs/design/130-response-column-slope-family.md`. Design 130 supersedes the
old helper-deprecation proposals in Designs 55 and 56 and records the spatial
column-coordinate contract separately from the first fixed-source
implementation slice. The numbered gate list is retained as historical lane
state.

1. Do not open/merge PR-1 until the active foreign lanes release the shared
   Design 130 contract files (`docs/design/01-formula-grammar.md`,
   `03-likelihoods.md`, `06-extractors-contract.md`) or the maintainer assigns
   their ownership.
2. With an approved campaign plan, run the broader multi-seed Gaussian
   campaign on Totoro if claim-bearing coverage, rather than the retained
   regression gate, is needed. The user requires a measured pre-run and
   explicit approval before Totoro; do not use GitHub Actions for it.
3. Add the resulting validation-debt row, check-log entry, design docs,
   after-task report, and PR review before readiness.
4. PR-2 (`phylo_dep`, `phylo_slope(|/||)`, animal parity) stays sequential;
   wide grammar and non-Gaussian column slopes remain deferred.

## Resume

```sh
cd /private/tmp/gllvmtmb-1196-column-slopes-diagonal
git status --short --branch
Rscript --vanilla -e 'devtools::test(filter = "phylo-column-slope-indep", reporter = "summary")'
```
