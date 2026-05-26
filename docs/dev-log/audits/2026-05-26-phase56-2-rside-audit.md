# Phase 56.2 R-side `n_traits` / `n_lhs_cols` audit

**Date:** 2026-05-26
**Lead:** Ada/Codex
**Status:** Phase 56.2 implementation checklist after #289 merge

## Purpose

PR #289 landed the dormant augmented phylogenetic random-regression
TMB path: `b_phy_aug`, `Z_phy_aug`, `log_sd_b`, `atanh_cor_b`,
`use_phylo_slope_correlated`, and block-local `n_lhs_cols`.
This audit is the Phase 56.2 bridge between the older Design 56
"nine hardcoded `n_traits` sites" table and the post-#289 code.

The key correction is that the nine sites are **not** a mechanical
search-and-replace list. Some sites still correctly index traits in
the legacy phylogenetic covariance paths. The augmented structural
slope path uses `b_phy_aug` / `Z_phy_aug`; future trait or keyword
replication belongs in the block dimension, not in `n_lhs_cols`.

## Site-by-site classification

Line numbers refer to `main` after #289 (`3133863`).

| Design 56 §4 row | Current site | Classification | Reason |
|---|---:|---|---|
| sizing of `theta_rr_phy` | `R/fit-multi.R:1303-1307`; `src/gllvmTMB.cpp:469-477` | **keep `n_traits`** | This is the legacy `phylo_latent` / `phylo_dep` / diagonal-constraint `phylo_unique` Lambda path. It indexes trait covariance, not augmented LHS design columns. The augmented structural-slope path routes through `b_phy_aug`. |
| `Lambda_phy` shape | `src/gllvmTMB.cpp:469-502` | **keep `n_traits`** | `Lambda_phy` remains a trait-by-rank loading matrix for phylogenetic latent covariance. Replacing its row count with block-local `n_lhs_cols` would corrupt the existing phylogenetic covariance model. |
| `b_phy_rr` / `g_phy` sizing | `R/fit-multi.R:1308`; `src/gllvmTMB.cpp:494-499` | **keep current shape** | `g_phy` is `n_aug_phy x d_phy`; it indexes phylogenetic latent factors, not LHS columns. |
| `phylo_diag` random-effect block | `R/fit-multi.R:1312-1314`; `src/gllvmTMB.cpp:513-528` | **keep `n_traits`** | `log_sd_phy_diag` and `g_phy_diag` are per-trait phylogenetic random intercepts for the existing paired decomposition. Future augmented `phylo_unique(1 + x | sp)` should use `b_phy_aug`, not this per-trait intercept block. |
| `DATA_ARRAY` assembly | `R/fit-multi.R:1191-1197`, `1247-1249` | **already promoted** | #289 added block-local `n_lhs_cols` and `Z_phy_aug` with dimensions `n_obs x n_lhs_cols x n_phy_aug_blocks`. |
| `Cphy` / `Ainv` block sizing | `R/fit-multi.R:1026-1128` | **keep covariance dimensions** | This code builds `Cphy_inv`, `Ainv_phy_rr`, `n_aug_phy`, and `species_aug_id`. Those dimensions are tree / relatedness dimensions, not trait or LHS-column dimensions. |
| Lambda inflation / constraint guard | `R/fit-multi.R:1537-1553` | **keep `n_traits`** | `lambda_packed_map(lambda_constraint$phy, n_traits, d_phy, ...)` belongs to the trait loading matrix path. Augmented structural slopes do not consume `lambda_constraint$phy` in Phase 56.2. |
| `b_phy_slope` init | `R/fit-multi.R:1316-1320` | **legacy kept; augmented init present** | `b_phy_slope` remains for byte-identical legacy `phylo_slope()`. #289 added `b_phy_aug`, `log_sd_b`, and `atanh_cor_b` using `n_lhs_cols`. |
| `b_phy_slope` dim check | `R/fit-multi.R:1609-1619`, `1866-1871`; `src/gllvmTMB.cpp:560-574` | **already split by flag** | The R map/random lists choose legacy `b_phy_slope` versus augmented `b_phy_aug`. The C++ augmented branch has explicit dimensional guards. |

## Phase 56.2 edit consequence

The Phase 56.2 code edit should therefore be narrow:

- keep the legacy trait-indexed phylogenetic covariance paths intact;
- document the post-#289 classification in Design 56 so future agents
  do not apply the stale mechanical replacement table;
- preserve `n_lhs_cols = 1L` as the dormant default until Phase 56.3
  parser work supplies an augmented LHS form;
- leave parser acceptance, public syntax, skeleton-test activation,
  and validation-debt row movement to later phases.

## Validation target

Because Phase 56.2 is a classification / R-side discipline slice,
the key validation is regression preservation:

- `devtools::test(filter = "phase56-1-phylo-augmented-stub")`;
- `devtools::test(filter = "augmented-lhs-guard|phase56-1-phylo-augmented-stub|phylo-slope")`;
- `git diff --check`.

No `devtools::document()` is expected unless roxygen changes are made.
No `pkgdown::check_pkgdown()` is expected unless public docs, articles,
or reference topics are touched.
