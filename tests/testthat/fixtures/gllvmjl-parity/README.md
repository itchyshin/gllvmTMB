# gllvmTMB <-> GLLVModels.jl parity fixtures

Reference values for `tests/testthat/test-gllvmjl-parity-fixtures.R`. The
test refits each table with gllvmTMB and compares quantities that do not
depend on the rotation of the latent axes.

- `data-<family>.csv`: long-format responses (`site`, `trait`, `y`); p = 5
  traits, n = 100 sites, simulated from a rank-2 latent model by `gen-data.R`.
- `reference.csv`: GLLVModels.jl values, one row per number (`case`,
  `quantity`, `i`, `j`, `value`). Quantities: `loglik`; `LL` =
  Lambda Lambda^T; and, for Gaussian only, `Sigma` = Lambda Lambda^T +
  sigma_eps^2 I.
- `reference-meta.csv`: per case, the GLLVModels.jl route, its `converged`
  flag and log-likelihood.
- `gen-reference.jl`: writes the two reference files. It refuses to run
  unless the GLLVModels.jl checkout is clean and at the pinned commit.

Pinned GLLVModels.jl commit: `aed938e1f377a2f584848c5dd100f10f1782b00d`
(version 0.3.0, Julia 1.12.6). Generated 2026-10-31.

The model on both sides is `y ~ 0 + trait + latent(0 + trait | site, d = K,
unique = FALSE)` for K = 1, 2, fitted by Laplace. On the Julia side, five
families go through `bridge_fit` (the contract behind `engine = "julia"`);
Tweedie has no bridge route at the pin and is fitted with `fit_gllvm(...,
disp_group = :species, power_group = :species)`, which matches gllvmTMB's
per-trait dispersion and per-trait power.

To regenerate: run `Rscript gen-data.R`, then `julia --project=<env>
gen-reference.jl <GLLVModels.jl checkout>` from this directory, and update the
pin here and in the test file if it moves.

## Second set: covariates, a random site effect, an offset, K = 3

Reference values for `tests/testthat/test-gllvmjl-parity-extra.R`, same pinned
commit and same approach (the test refits the stored tables with gllvmTMB; Julia
is not needed to run it).

- `data-<group>-<family>.csv`: long-format tables written by `gen-data-extra.R`
  with the covariate or offset column alongside `site`, `trait`, `y`.
  - `xcov-*` (p = 5, n = 100): site-level covariates `x1`, `x2`, one coefficient
    each shared by all traits; gaussian, poisson, nbinom2, binomial, zip.
  - `rowre-*` (p = 5, n = 150): one random intercept per site shared by all
    traits, SD 0.7; poisson, binomial.
  - `offset-*` (p = 5, n = 100): a log-exposure `off` that varies by site and
    trait; poisson, nbinom2.
  - `k3-*` (p = 6, n = 150): rank-3 data; gaussian, poisson.
- `reference-extra.csv`, `reference-extra-meta.csv`: GLLVModels.jl values in the
  same layout as the first set, plus `gamma` (covariate coefficients, `i` =
  covariate), `beta` (trait intercepts, `i` = trait) and `sigma_row` (SD of the
  random site effect).
- `gen-reference-extra.jl`: writes the two reference files. Same pin check as
  `gen-reference.jl`.

gllvmTMB side: `y ~ 0 + trait + x1 + x2 + latent(...)`, `y ~ 0 + trait +
(1 | site) + latent(...)` and `y ~ 0 + trait + offset(off) + latent(...)`, each
with `latent(0 + trait | site, d = K, unique = FALSE)`. Julia side: `bridge_fit`
with `X` (xcov, k3), `fit_row_random_gllvm` (rowre), and `fit_poisson_gllvm` /
`fit_nb_gllvm_grouped(group = 1:p)` with `offset =` (offset). `bridge_fit` wires
an offset for Gaussian only, and gllvmTMB refuses a Gaussian offset, so the offset
cases use the native count fitters. For Gaussian the covariate route takes the
full mean structure, so `X` holds the five trait dummies and then `x1`, `x2`.

Not compared, because the two packages do not fit the same model: Gaussian offset
(gllvmTMB refuses it); a random site effect for Gaussian and NB2 (GLLVModels.jl
has one shared dispersion under a row effect); Tweedie with covariates (no route
at the pin); ZIP with covariates (see the skips in the test: GLLVModels.jl lets the
covariates act on the zero part too).

To regenerate: `Rscript gen-data-extra.R`, then `julia --project=<env>
gen-reference-extra.jl <GLLVModels.jl checkout>`. Generated 2026-11-01.
