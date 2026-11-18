# Spatial response-column coefficient alignment

For observation row `i`, response column `t`, and ordered coefficient basis
`z_i`, the new term is

```text
eta_it,coef = z_i^T b_t
vec(B^T) ~ N(0, K_spatial(kappa) (x) Sigma_coef)
Q(kappa) = kappa^4 C0 + 2 kappa^2 G1 + G2
K_raw(kappa) = A_column Q(kappa)^(-1) A_column^T
K_spatial(kappa) = D^(-1) K_raw(kappa) D^(-1)
D = diag(sqrt(diag(K_raw(kappa))))
rho = 1
```

`K_spatial(kappa)` is the projected, unit-diagonal response-column spatial
correlation already used by `spatial_slope()`. The first public
`spatial_coef()` slice does not add a spatial nugget mixture: `rho = NULL` and
numeric `rho < 1` are rejected. A future
`rho K_spatial(kappa) + (1-rho) I` model needs a separate spatial-plus-IID
field and joint range/share identifiability evidence.

| Symbol in prose | Keyword / engine field | DGP draw | Recovery extractor | Truth value |
|---|---|---|---|---|
| `z_i` | explicit `1`, `0 + x`, or `1 + x` basis; `Z_spde_aug` | row predictor matrix with a literal ones column for `(Intercept)` | `extract_Sigma(..., level = "column_coef")$basis` plus fitted design checks | ordered basis used by the fixture |
| `K_spatial(kappa)` | labelled `gllvmTMBmesh`; `spatial_column_K` | projected SPDE covariance normalized to unit diagonal | `$source$K_column`, `$source$kappa`, `$source$range` | planted mesh and kappa/range regime |
| `Sigma_coef` | `Sigma_field`; `|` full, `||` diagonal map | planted `P x P` coefficient covariance | `$Sigma` and `$R` | planted variances/correlation |
| `B` | `omega_spde_aug` projected through `A_column` | matrix-normal coefficient draw | coefficient contribution, report, and fitted values | response-column intercept/slope deviations |
| fixed C3/C4 means | ordinary fixed `0 + pathway` | pathway intercepts | `coef()` | planted C3 and C4 means |
| fixed C3/C4 slopes | ordinary fixed `moisture:pathway` | pathway slopes | `coef()` | planted C3 and C4 slopes |

Long and `traits(...)` wide calls must prepare the same stacked data, basis,
mesh labels, maps, objective, report, and fitted values after canonical row
ordering. The no-intercept `rho = 1` path must hard-rewrite to the released
`spatial_slope()` spelling and preserve its warnings, parameters, maps,
objective, gradient, report, and fitted values exactly.
