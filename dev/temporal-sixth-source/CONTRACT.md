# G0 contract: native temporal covariance source

## Purpose

This lane extends the existing, bounded AR1 temporal latent-score provider to
one **temporal source** with the three ordinary trait-covariance modes.  A
private state is one `(series, time)` pair; it is never substituted for the
user's `unit` or `unit_obs` columns.

## Public grammar

The three temporal terms accept a bar term and a bare time column:

```r
temporal_indep(0 + trait | series, time = occasion, structure = "ar1")
temporal_dep(0 + trait | series, time = occasion, structure = "ar1")
temporal_latent(0 + trait | series, time = occasion, d = 1,
                unique = FALSE, structure = "ar1")
```

`structure = "ar1"` requires ordered finite integer occasions, retains their
gaps, and estimates a signed persistence `phi = (1 - 1e-6) tanh(theta)` with
correlation `phi^abs(t_a - t_b)`.  `structure = "ou"`
requires finite numeric elapsed time, strictly increasing within series, and
uses positive decay `rho = exp(-exp(theta) * distance)`.  The time column is
not coerced or re-ranked for OU.

## Model alignment

For series `g`, occasions `a, b`, trait covariance `S`, and time correlation
`R`, the temporal effect obeys

`Cov(u_ga, u_gb) = R(a, b) S`.

| Symbol | Keyword | DGP draw | Recovery/extractor | Truth |
| --- | --- | --- | --- | --- |
| `u_ga` | `temporal_indep()` | `L_R e_g`, one process per trait | `extract_temporal()` | `R ⊗ diag(psi^2)` |
| `u_ga` | `temporal_dep()` | `L_R E_g L_S^T` | `extract_temporal()` | `R ⊗ Sigma` |
| `u_ga` | `temporal_latent(..., unique = FALSE)` | `L_R z_g Lambda^T` | `extract_temporal()` | `R ⊗ Lambda Lambda^T` |
| `u_ga` | `temporal_latent(..., unique = TRUE)` | latent draw plus temporal trait-Psi draw | `extract_temporal()` | `R ⊗ (Lambda Lambda^T + Psi)` |

The temporal source owns a dedicated private `(series, time)` state index and
dedicated temporal parameters/random effects; it must not reuse or overwrite
the ordinary `z_B`, `unit`, or `unit_obs` tier.  Ordinary intercept modes at
the `unit` and `unit_obs` tiers remain admissible, while a temporal
source cannot be combined with phylo, animal, spatial, or kernel sources in
this lane.  Gaussian identity-link ML / native TMB / Laplace is the only
admitted fitting route.  New-data prediction, intervals, rank above one,
slopes, non-Gaussian families, and combined source providers remain refused.

## Prototype migration boundary

The former prototype had the distinct covariance
\(K\otimes\Lambda\Lambda^T + I\otimes\Psi_W\) and reused the B-tier
implementation. Its exact shared subset is retained and exercised natively:
for consecutive-time AR1, rank one, no Psi, and no ordinary B/W component, the
old B-tier code and `temporal_latent(unique = FALSE)` agree at matched fixed
parameters for the objective, gradient, shared innovation draw, loadings, and
posterior state scores. That is the only migration equality claim.

The prototype's IID-Psi model has no such equality claim. Changing
`unique = TRUE` to \(K\otimes\Psi_T\) intentionally changes the objective,
gradient, simulation, and extraction target. The sixth-source dense oracle
instead verifies the active declared covariance in every public AR1/OU cell.

## Numerical oracle

The test oracle constructs the dense covariance `R ⊗ S` independently of the
TMB likelihood and compares its Gaussian marginal NLL and finite-difference
gradient with the native objective at fixed parameter values.  AR1 keeps
integer gaps; OU uses elapsed numeric time exactly.
