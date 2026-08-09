# Frozen CRAN 0.7 silent-failure campaign

**Campaign ID:** `cran07-silent-failure-v2`. Version 1 is superseded before
production; no v1 production attempt ran. The eight scientific cells are
unchanged. Version 2 separates observable detector flags from the independent
planted-truth catastrophic label and changes binomial responses from Bernoulli
to integer successes out of ten trials (`weights = 10`).
The exact v2 campaign ID is compiled to this registry's canonical path and
SHA-256; cross-wired paths, copied registries, and hash drift fail before fitting.

This campaign detects fits that return without an R error but are scientifically
or numerically unusable. It does not calibrate confidence intervals and it does
not expand the supported model surface.

The design is a balanced regular half-fraction of four two-level factors. Let
`A = family` (Gaussian / binomial-logit), `B = n_unit` (60 / 150),
`C = loading_sd` (0.5 / 3), and `D = missing_rate` (0 / 0.30), coded `-1/+1`.
The complete factorial contains `2^4 = 16` cells. The registry retains the eight
cells satisfying `A * B * C * D = +1`; it is therefore an 8-cell half-fraction,
not a full factorial. Every main-effect level occurs four times and main effects
are mutually orthogonal. Main effects are aliased with three-factor interactions,
so this is a diagnostic screen rather than a causal factorial analysis.

Each attempt uses the native default Laplace route, rank-one ordinary `latent()`,
three traits, deterministic seeds, and complete attempt accounting. Missing
responses use `miss_control(response = "include")`. A returned fit is still a
failure when estimands are nonfinite, optimizer/stationarity/Hessian health fails,
a variance is below `1e-8`, an absolute total correlation reaches `0.9999`, or the
observable fitted-covariance geometry rule in `inst/sim/cran07-core/campaign.R`
fires. Planted-truth catastrophic error is tabulated separately in a complete
2 x 2 detector table and never changes attempt status. Binomial attempts assert
observed `n_trials = 10` and `diag_B_skip = 0` for every trait.

Smoke runs use 20 replicates per cell; production uses 400. Production is for
Totoro after local smoke approval. Raw per-attempt RDS files stay outside Git.
