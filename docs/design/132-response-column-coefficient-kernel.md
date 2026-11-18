# Design 132 — Dense-kernel response-column coefficients

**Status:** implementation contract for public Gaussian point-model
`kernel_coef()`. This extends Design 131 without modifying the released
`kernel_slope()` API or the 5 x 3 covariance grid.

## Model

```text
eta_it,coef = z_i^T b_t
B ~ MN(0, K_rho, Sigma_coef)
K_rho = rho K + (1-rho) diag(K)
```

The labelled dense positive-definite covariance `K` stays on its supplied
marginal scale. `rho` changes correlation strength only and is a variance share
only when `diag(K) = 1`.

## Public grammar

```r
kernel_coef(1 + x | trait, K = K, name = "kernel", rho = NULL)
kernel_coef(1 + x || trait, K = K, name = "kernel", rho = 0.6)
```

`K` is required and must be a base dense numeric matrix with finite entries,
unique non-empty row and column names, exact response-column label coverage,
symmetry, and positive definiteness. Sparse matrices are rejected because
elsewhere they can mean precision, while public `K` means covariance. `name`
is one non-empty string. Numeric `rho` fixes `[0,1]`; `NULL` estimates one
interior value through the spectral route established by `phylo_coef()`.

The basis, bar, Gaussian-family, single-source, fixed-overlap, and long/wide
rules follow Design 131. `|` estimates full `Sigma_coef`; `||` maps strict-lower
Cholesky entries to zero.

## Exact released endpoint

```text
kernel_coef(0 + predictors <bar> trait, K, name, rho=1)
== kernel_slope(predictors <bar> trait, K, name)
```

The equality covers TMB data, maps, random indices, objective, gradient,
report, fitted values, and warnings. The endpoint uses raw `K` and must not
inherit the dense phylogenetic `K + 1e-8 I` seam.

Intercept-bearing `rho = 1`, fixed interior values, and estimated `rho` reuse
the admitted matrix-normal engine. No C++ likelihood change is expected. Wide
coefficient fits equal their long counterparts; this does not admit wide
`kernel_slope()`.

## Extraction and scope

`extract_Sigma(fit, level = "column_coef")` returns the ordered basis
covariance/correlation, fixed or estimated `rho`, effective `K_rho`, and source
metadata including `type = "kernel"`, labels, `name`, and
`scale = "as_supplied"`.

IN: Gaussian native-Laplace point fits, one dense kernel, fixed or estimated
strength, long and `traits(...)` wide data, explicit intercept and bare numeric
slopes, both bars. PARTIAL: deterministic recovery covers a bounded regime,
not broad calibration. PLANNED: intervals, non-Gaussian families, simultaneous
sources, latent coefficient covariance, and spatial coefficients. All current
`*_slope()` helpers remain warning-free and non-deprecated.

## Required evidence

Strict parsing and malformed sources; raw-K slope identity under both bars;
identity-kernel transitivity; direct fixed and spectral precision/logdet
oracles with non-unit diagonals; estimated-rho non-identifiability rejection;
fixed/estimated label permutation; full/diagonal maps; exact fixed/estimated
long/wide equality under both bars; finite truth and optimum gradients;
small-DGP full-covariance recovery plus bounded non-CRAN estimated-rho,
grand-mean, diagonal-covariance, and coefficient-mode recovery; extractor metadata; docs/pkgdown;
small/large variance and zero/positive/negative correlation edges; near-zero and
high estimated-rho stress; missing-response and rare-pathway acceptance;
independent review; three-OS exact-head CI; normal merge; exact-main CI/site.
