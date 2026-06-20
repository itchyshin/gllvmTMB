# After Task: Salvage coevolution exports from the dirty branch (Item 1)

## 1. Goal

The HELD-item audit found that the only genuinely net-new gllvmTMB code on the
dirty branch `codex/r-bridge-grouped-dispersion` was two **uncommitted** exported
functions at risk of loss: `extract_coevolution_modules` and
`diagnose_kernel_separability`. Maintainer approved the two new exports. Rescue
them — plus their helper cluster — onto a clean branch off `main`, where the
#494 coevolution engine they build on already lives.

## 2. Implemented

- `extract_coevolution_modules()` (exported): module/community structure from a
  fitted 2-kernel `gllvmTMB_multi` coevolution model, on the shape or effect
  scale. Helpers `.matrix_inv_sqrt`, `.coevolution_axis_table` (both were
  dirty-tree-only) ported alongside.
- `diagnose_kernel_separability()` (exported): pre-fit Frobenius-style overlap
  between dense fixed kernels, with overlap class + recommendation. Helpers
  `.kernel_separability_names/_thresholds/_matrix/_class/_recommendation` and
  `.kernel_pair_similarity` (dirty-tree-only) ported alongside.
- Both layer on existing `main` infrastructure (`extract_Sigma`, `extract_Gamma`,
  `.gamma_level_rho`, `.gamma_trait_arg`, `.warn_high_overlap_gamma` — all on
  `main` via #494); the dependency closure was verified bounded (no further
  dirty-tree-only symbols).

## 3. Files Changed

- `R/extract-sigma.R` (+230: `extract_coevolution_modules` + 2 helpers).
- `R/kernel-helpers.R` (+182: `diagnose_kernel_separability` + 6 helpers).
- `NAMESPACE` (+2 exports, regenerated).
- `man/extract_coevolution_modules.Rd`, `man/diagnose_kernel_separability.Rd`
  (new, generated).
- `tests/testthat/test-coevolution-modules-salvage.R` (new, focused).

## 3a. Decisions and Rejected Alternatives

> **Decision**: Cherry-pick-subset (port only the 2 functions + their bounded
> helper closure) onto fresh `main`, not rebase/merge the 120-commit dirty branch.
> **Rationale**: the audit found the committed divergence is mostly superseded
> (coev C++ byte-identical to #494; bridge subsumed by #492/#493).
> **Rejected**: merging/rebasing the branch — huge conflicts for ~zero net gain.
> **Confidence**: high.

> **Decision**: Ship `diagnose_kernel_separability` with full focused tests now;
> ship `extract_coevolution_modules` with code + docs + a guard test, and defer
> its full fit-based recovery test to a port-before-merge step.
> **Rationale**: its recovery test needs the heavy 2-kernel coevolution fit
> fixture (`fx`/`fit_full` in `test-coevolution-two-kernel.R`); porting that
> faithfully is a separate sub-task. The PR is HELD anyway (new exports).
> **Rejected**: porting the 2226-line dirty test wholesale (risks dragging in
> other dirty-tree fixture deps).
> **Confidence**: medium.

## 4. Checks Run

- `Rscript -e 'devtools::document()'` → EXIT 0; NAMESPACE gained both exports;
  both `man/*.Rd` generated; package loaded clean.
- `Rscript -e 'devtools::test(filter="coevolution-modules-salvage")'` → **EXIT 0**,
  full suite green: diagnose (orthogonal vs high-overlap classes, <2-kernel guard,
  dim-mismatch guard); `extract_coevolution_modules` non-multi guard; **and a
  fit-based recovery test** (below).
- **Recovery test (added)**: rather than port the heavy `.c3_*` 2-kernel fixture,
  the recovery test uses the **shipped** `coevolution-kernel-example.rds` and the
  same on-main fit pattern as `test-example-coevolution-kernel.R`: fit the
  `kernel_latent(..., name = "cross") + kernel_unique(...)` wide model, then
  `extract_coevolution_modules(fit, level = "cross", row_traits, col_traits)`.
  Asserts convergence, `gllvmTMB_coevolution_modules` class, `dim(R) = 2x2` with
  correct host/partner trait names, finite R, a sensible decomposition (nonneg
  descending singular values, shares in [0,1]), and **recovery**: `R` aligns with
  the simulated `truth$Gamma` (`abs(cor) > 0.5`). Verified locally (probe:
  convergence 0, `dim(R)=2x2`, `n_modules=2`).
- `git diff --check` → clean.
- Not run: full `devtools::check()` (CI will run the full matrix).

## 5. Known Limitations and Next Actions

- The recovery test is now present (shipped-example route). DoD recovery gate met.
- Two new public exports → the return-value contract should be added to
  `docs/design/06-extractors-contract.md` and a validation-debt register row
  created before any "covered" claim. Merge HELD for maintainer.
