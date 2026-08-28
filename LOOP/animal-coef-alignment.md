# Animal response-column coefficients: symbolic alignment

For unit `i`, response column `t`, fixed-effect row `x_it`, and coefficient
basis `z_i`, the admitted Gaussian point model is

```text
y_it = x_it^T beta + z_i^T b_t + epsilon_it
B = [b_1^T; ...; b_T^T]
B ~ MN(0, K_rho, Sigma_coef)
vec(B) ~ N(0, Sigma_coef (x) K_rho)
K_rho = rho A + (1 - rho) diag(A),  0 <= rho <= 1
epsilon_it ~ N(0, sigma_e^2)
```

`A` is the labelled animal covariance obtained from exactly one of a pedigree,
a covariance matrix `A`, or a precision matrix `Ainv`. The supplied diagonal is
preserved. `|` estimates a full lower-Cholesky `Sigma_coef`; `||` maps its
off-diagonal entries to zero.

| Symbol in prose | Keyword / formula term | DGP draw | Recovery extractor | Truth |
|---|---|---|---|---|
| `x_it^T beta` | pathway fixed means such as `0 + pathway + latitude:pathway` | multiply the fixed design by `beta` | `coef(fit)` | declared pathway intercepts and slopes |
| `A` and `K_rho` | `animal_coef(..., pedigree/A/Ainv, rho = rho)` | resolve labelled `A`, then form `rho * A + (1-rho) * diag(A)` | `extract_Sigma(fit, level = "column_coef")` source metadata | supplied `A` and fixed `rho` |
| `Sigma_coef` | `1 + latitude | trait` or `1 + latitude || trait` | declared coefficient covariance | `extract_Sigma(fit, level = "column_coef")$Sigma` | declared intercept variance, slope variance, and covariance (zero under `||`) |
| `B` | `animal_coef(1 + latitude | trait, ...)` | `chol(K_rho) %*% Z %*% t(chol(Sigma_coef))` with iid standard-normal `Z` | fitted random coefficient contribution and `Sigma_coef` | one intercept and slope deviation per response column |
| `epsilon_it` | `family = gaussian()` | iid `N(0, sigma_e^2)` | Gaussian dispersion from the fitted object | declared residual variance |

## Admission oracles

1. At `rho = 1` with no intercept, long
   `animal_coef(0 + latitude | trait, ...)` must hard-route to and be
   byte-identical to released long `animal_slope(latitude | trait, ...)`.
2. The matched wide `traits(...)` coefficient model must be byte-identical to
   the long coefficient model. The released slope helper remains deliberately
   long-only.
3. `pedigree`, `A`, and `Ainv` must resolve to the same labelled source when
   they encode the same relationship matrix.
4. Fixed interior `rho` preserves `diag(A)`; estimated `rho = NULL` remains
   outside this lane.
