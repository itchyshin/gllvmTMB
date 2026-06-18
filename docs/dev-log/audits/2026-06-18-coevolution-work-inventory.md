# Coevolution Work Inventory

Date: 2026-06-18 09:05 MDT

Purpose: answer the maintainer concern that the cross-lineage coevolution
model felt "unfinished" despite several rounds of work. This audit separates
implemented and currently passing work from the larger Paper 2 model described
in `/Users/z3437171/Downloads/Paper_2_gllvmTMB_implementation_brief.md`.

Guard: PR green != bridge complete != release ready != scientific coverage
passed.

## Verdict

The one-kernel Design 65 model is implemented and still passes its fast and
heavy gates in the current checkout. The full Paper 2 model is not finished
because the Markdown brief asks for additional capabilities beyond the
implemented C0-C3 boundary: arbitrary multiple named kernel tiers, estimated
or profiled `rho`, `Gamma_shape` versus `Gamma_effect` / `Theta` extraction,
bootstrap uncertainty, mixed-family recovery, structural-missingness
diagnostics, and one-kernel versus two-kernel identifiability simulations.

In short: the one-kernel point-estimate workflow is real; the two-kernel
publishable headline model remains future work unless simulations prove it.

## Implemented And Checked

| Slice | Current status | Evidence checked |
|---|---|---|
| C0 `make_cross_kernel()` | Covered | `R/kernel-helpers.R`; `tests/testthat/test-coevolution-prototype.R`; validation row `KER-01`; after-task report `2026-05-31-kernel-c0-coevolution-prototype.md`. |
| C0 prototype through dense `phylo_*()` | Covered | Heavy planted-`Gamma` prototype in `test-coevolution-prototype.R`; validation row `COE-01`. |
| C1 generic dense `kernel_*()` surface | Covered for one named dense tier | `R/kernel-keywords.R`; parser rewrite in `R/brms-sugar.R`; single-tier aliasing in `R/fit-multi.R`; equivalence tests in `test-kernel-equivalence.R`; validation row `KER-02`. |
| C2 `extract_Gamma()` | Covered for point estimates | `R/extract-sigma.R`; fast extractor tests and heavy known-`Gamma` recovery in `test-coevolution-recovery.R`; validation row `COE-02`. |
| C2 article workflow | Internal/buildable, not first-line public claim | `vignettes/articles/cross-lineage-coevolution.Rmd`; fixture test `test-example-coevolution-kernel.R`; article records fixed-`rho`, point-estimate, no calibrated-interval scope. |
| C3 two-kernel finding | Superseded by later 2026-06-18 commits | At this audit checkpoint, `test-coevolution-two-kernel.R`, validation row `COE-03`, and Design 65 still recorded that two independent named tiers needed a second TMB data/parameter slot and NLL block. This was superseded later the same day by `89b4edc` (latent-only named multi-kernel tiers) and the follow-on COE-04 near-orthogonal recovery slice. |
| C3 two-Psi guardrail | Covered | `R/fit-multi.R` warns and collapses two non-replicated `kernel_unique()` tiers to one identifiable tier; C3 tests cover warning, negative control, and replicated single-tier recovery. |

## Tests Re-run In This Audit

- `PATH="/opt/homebrew/bin:$PATH" /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution|kernel-equivalence|example-coevolution-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 4 | PASS 99`; skips were the expected heavy
  coevolution gates.
- `PATH="/opt/homebrew/bin:$PATH" GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution|kernel-equivalence|example-coevolution-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 125`.

## Why It Still Feels Unfinished

The new Paper 2 brief defines a larger target than the implemented Design 65
C0-C3 slice. The implemented package fits one supplied cross-lineage kernel:

```r
kernel_latent(species, K = K_star, d = 2, name = "cross") +
  kernel_unique(species, K = K_star, name = "cross")
```

and extracts:

```r
extract_Gamma(fit, level = "cross", row_traits, col_traits)
```

That is not the same as fitting both:

```r
K_phy
K_non
```

with independent `Lambda`, `Psi`, and `rho` parameters. C3 explicitly found
that the current engine still has one dense-relatedness slot
(`Ainv_phy_rr`, `d_phy`, `Lambda_phy`, `g_phy_diag`) and rejects two distinct
named tiers. This is why Option B from the brief is not finished.

## Paper 2 Gaps To Close Deliberately

1. Decide whether Paper 2 is guaranteed Option A (one cross-lineage kernel) or
   headline Option B (phylogenetic plus non-phylogenetic kernels).
2. If Option B remains in scope, design a true arbitrary named-kernel engine
   instead of adding a brittle second hard-coded slot.
3. Add `Gamma_shape` and `Gamma_effect` / `Theta` terminology only when the
   API can distinguish fixed supplied `rho` from fitted or profiled `rho`.
4. Treat `rho = 0` inference as nonstandard: simulation-calibrated or
   parametric-bootstrap tests, not naive chi-square LRT wording.
5. Add kernel-separation diagnostics for the two-kernel case, including the
   cross-block similarity, effective rank, condition number, and Hessian /
   profile diagnostics.
6. Validate structural block missingness, long/wide equivalence, and mixed
   families on the cross-lineage path before public Paper 2 claims.
7. Add bootstrap uncertainty for `Gamma` / `Theta` before publishing interval
   claims.

## Current Safe Public Claim

Safe: `gllvmTMB` has a validated internal one-kernel cross-lineage workflow for
supplied dense `K_star`, fixed `rho`, and point-estimate `Gamma` extraction,
with fast and heavy tests passing in the current checkout.

Unsafe: claiming the full two-kernel Paper 2 model, estimated `rho`, calibrated
`Gamma` intervals, sparse scalability, or scientific coverage across mixed
families.
