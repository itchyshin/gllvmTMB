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
