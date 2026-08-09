# Frozen CRAN 0.7 robustness campaign

**Campaign ID:** `cran07-robustness-v2`. Version 1 is superseded before
production; no v1 production attempt ran. The eight scientific cells are
unchanged. Version 2 separates observable detector flags from the independent
planted-truth catastrophic label and changes binomial responses from Bernoulli
to integer successes out of ten trials (`weights = 10`).
The exact v2 campaign ID is compiled to this registry's canonical path and
SHA-256; cross-wired paths, copied registries, and hash drift fail before fitting.

This separate 8-cell campaign crosses four first-release families (Gaussian,
Poisson, negative-binomial 2, and binomial-logit) with two data-path scenarios:
20% response values missing completely at random, and a three-level factor whose
rare level occupies 5% of units. All cells use native default Laplace, ordinary
rank-one `latent()`, 150 units, three traits, deterministic seeds, and the same
immutable attempt-status and estimand schemas as the core campaign.

The missing-response cells use `miss_control(response = "include")`. The
rare-level cells include trait-specific factor effects and require exact equality
between planted model-matrix column names and fitted `X_fix_names`; ambiguity is
recorded as `estimand_mapping_error`, never patched by positional guessing.
Binomial attempts additionally require observed `n_trials = 10` and
`diag_B_skip = 0` for every trait. Every summary contains the full 2 x 2 table
of observable `detector_flagged` by independent `catastrophic_truth_error`.

Smoke runs use 20 replicates per cell; production uses 400. This campaign tests
point-estimate and silent-failure robustness only. It does not establish interval
coverage, broad missing-data validity, or rare-level performance beyond this DGP.
Raw per-attempt RDS files stay outside Git and production is reserved for Totoro.
