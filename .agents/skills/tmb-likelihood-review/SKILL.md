---
name: tmb-likelihood-review
description: Review TMB likelihoods, parameter transforms, and engine plumbing before merging changes to gllvmTMB's `src/gllvmTMB.cpp` or its R wrappers.
---

# TMB Likelihood Review

Use this skill for any change to the C++ template (`src/gllvmTMB.cpp`),
density branches, parameter transforms, or the `R/fit-multi.R`
parameter-pack-and-unpack code.

## Review Checklist

- Are all constrained parameters represented internally on
  unconstrained scales?
  - Positive parameters: `log_tau`, `log_kappa`, `log_sd_*`,
    `theta_diag_*` (where the diag is exp-transformed inside the
    template).
  - Correlations: `tanh / atanh` or another stable bounded transform.
  - Reduced-rank loadings: packed lower-triangular
    (`theta_rr_*`).
- Are constants included consistently in likelihoods? `dpois(...,
  log = TRUE)`, `dbinom(..., log = TRUE)`, etc.
- Are gradients finite for simulated data at the simulation truth and
  at the fitted MLE?
- Does `sdreport()` report interpretable transformed parameters
  (`Sigma_B`, `R_B`, `phylo_signal_h2`, `repeatability_R`)?
- Does simulation recover truth under ordinary sample sizes (n_sites
  >= 30, n_traits >= 3)? Apply the `add-simulation-test` skill.
- Are boundary and weak-identification cases tested? In particular:
  - `latent` rank too high (engine should fail loud);
  - `phylo_latent` with zero phylogenetic signal
    (`sigma2_phy -> 0`);
  - `spatial_latent` with degenerate mesh (single triangle).

## Multi-tier covariance contract

The engine maintains the contract

$$\Sigma_{\text{tier}} = \boldsymbol\Lambda_{\text{tier}}\boldsymbol\Lambda_{\text{tier}}^\top + \mathrm{diag}(\mathbf U_{\text{tier}})$$

at every tier where the user pairs `latent + unique`. Any change
that touches the unpack of `theta_rr_*` or `theta_diag_*` must
preserve this. The test suite enforces it via
`test_that("extract_Sigma() composes Lambda Lambda^T + diag(s)")`.

## Cross-tier identifiability

When two tiers share the same grouping factor (e.g. both `latent(0 +
trait | site, d = K)` and `unique(0 + trait | site)`), the engine
fits the decomposition $\Sigma_B = \boldsymbol\Lambda_B
\boldsymbol\Lambda_B^\top + \mathbf S_B$. When the user supplies only
one of the pair, identifiability collapses to the no-residual
(rotation-invariant) or the marginal/independent special case. The
parser must surface this distinction to the user with a `cli_inform`
explaining which mode the engine is in.
