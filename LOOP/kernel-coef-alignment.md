# Kernel response-column coefficients: symbolic alignment

For row `i`, response column `t`, fixed-effect row `x_it`, and coefficient
basis `z_i`, the admitted Gaussian point model is

```text
y_it = x_it^T beta + z_i^T b_t + epsilon_it
B = [b_1^T; ...; b_T^T]
B ~ MN(0, K_rho, Sigma_coef)
Cov(vec(B^T)) = K_rho (x) Sigma_coef
K_rho = rho K + (1-rho) diag(K), 0 <= rho <= 1
epsilon_it ~ N(0, sigma_e^2)
```

`K` is one labelled dense covariance across response columns, retained on its
supplied marginal scale. Numeric `rho` fixes source strength. `rho = NULL`
estimates `rho = inv_logit(eta_rho)` in `(0, 1)`. A single bar frees the full
lower-Cholesky `Sigma_coef`; a double bar maps every strict-lower entry to zero.

| Symbol in prose | Keyword / engine object | DGP draw | Recovery extractor | Truth |
|---|---|---|---|---|
| `x_it^T beta` | ordinary fixed formula terms | `X beta` | `coef(fit)` | declared fixed coefficients |
| `z_i` | explicit `1`, `0 + x`, or `1 + x` basis | full-rank coefficient design | extractor basis labels | declared intercept/predictors |
| `K` | `kernel_coef(..., K = K, name = name)` | fixed labelled dense SPD matrix | `$source` | supplied matrix, labels, name, scale |
| `K_rho` | fixed precision or spectral estimated-rho route | form covariance-scale mixture | `$K_rho` | supplied-scale mixture above |
| `rho` | numeric or `NULL` | fixed or interior truth | `$rho`, `$rho_status` | declared/estimated strength |
| `Sigma_coef` | `|` or `||` | declared full/diagonal SPD covariance | `$Sigma`, `$R` | coefficient covariance |
| `B` | shared `b_phy_aug` matrix-normal engine | `L_K Z L_Sigma^T` | random coefficient contribution | one coefficient vector per response column |
| `epsilon_it` | `family = gaussian()` | iid Gaussian residual | fitted dispersion | declared residual variance |

## Admission oracles

1. No-intercept `rho = 1` hard-dispatches to the released `kernel_slope()`
   route and is identical in TMB data, maps, random indices, objective,
   gradient, report, fitted values, and warning behaviour under both bars.
2. The kernel endpoint uses raw `K`, never the dense phylogenetic `1e-8 I`
   conditioning seam.
3. The matched wide coefficient model is exactly equivalent to the long
   coefficient model; released `kernel_slope()` remains long-only.
4. Fixed mixtures preserve non-unit diagonals. `rho = 0` is IID only when
   `diag(K) = 1`.
5. Estimated strength rejects an uninformative standardized identity source
   and matches direct precision/log-determinant and finite-gradient oracles.
