# CRAN 0.7 campaign v3 gate correction

This directory is the frozen runner and aggregation overlay for the three v3
campaigns. It sources the immutable v2 DGP, fit, extractor, attempt-schema, and
per-attempt persistence files from `../cran07-core/`; it does not copy or alter
them. The canonical v2 registry paths and SHA-256 digests are reused exactly.
V3 has new campaign IDs and disjoint seed offsets, so no v2 attempt can be
silently reused.

V2 is discovery-only evidence. Its completed 680-fit pilot exposed an aggregation
error: detector sensitivity was required separately in cells with no planted
catastrophic positives, while preregistered covariance, Psi, correlation, and
large-versus-small RMSE gates were absent from the executable summary. No v2
production campaign is authorised and no v2 result can promote a release claim.
The scientific thresholds are unchanged; v3 corrects their aggregation before
the first v3 fit.

Pilot admission uses exactly 20 attempts per each of all 34 registry cells.
Each cell must be complete, have no more than 3 unusable attempts, no more than
1 unclassified attempt, and zero nonfinite core estimands. Detector sensitivity
and specificity are qualified once across the complete 680-attempt pilot:
sensitivity at least 0.95 and specificity at least 0.90. Both global denominators
must be nonzero. Every attempt whose status is not `usable`, including an
unclassified status, counts as unusable; the unclassified limit remains a
separate gate. The global receipt exposes admitted and held sets. Detector
qualification plus a nonempty admitted set authorises production only for that
explicit subset; all 34 cells need not pass.

Production uses exactly 400 attempts per explicitly admitted cell. Gates are:
stationary-usable rate at least 0.95; positive-Hessian rate at least 0.90; zero
unclassified outcomes; specificity at least 0.90 when negatives exist; exact
one-sided 95% upper bound below 0.02 for catastrophic-but-healthy attempts;
standardized absolute beta bias at most 0.10; applicable mean-matrix relative
Frobenius bias at most 0.15 for `Sigma_shared` and `Sigma_total`; per-trait Psi
bias at most 0.20 relatively, except absolute bias at most 0.01 for `psi_small`;
and applicable absolute correlation bias at most 0.10, relaxed only to 0.15 for
`rho_boundary98`. Every beta, Sigma, Psi, and correlation component requires
exactly 400 finite applicable contributions with replicates exactly `1:400`.
Missing Psi passes only for `dep()`; it fails for `indep()` and `latent()`.
The exact expected beta names and every covariance/correlation component are
derived from the frozen registry using a base-R model matrix and algebraic
component grid, never from observed output or an installed package. Missing and
unexpected applicable keys fail. Sensitivity is not re-required inside healthy
production cells.

The six core small/large pairs (`indep`, `dep`, Gaussian latent, Poisson, NB2,
and binomial) additionally require every frozen expected component to satisfy
`RMSE_large <= RMSE_small + SE_boot(delta_RMSE)`. The standard error uses 2,000
independent paired-stage bootstrap draws with frozen base seed 370830001; each
cell is resampled independently within each bootstrap draw. Missing components,
anything other than exactly 400 finite errors with replicates `1:400` per side,
and nonfinite quantities fail closed.

`run-batch.R` requires a v3 campaign ID, a frozen stage, an external output
directory, and a manifest destination. It rejects v2/unknown IDs and arbitrary
replicate counts. `summarize-batch.R` requires the saved manifest; completeness
is checked against the stage's full canonical cell set or the explicit admitted
production set, not inferred from whichever files happen to exist.
The bijection compares campaign ID, registry SHA-256, canonical cell number,
cell ID, replicate, and seed.

`production-closeout.R` requires core, silent-failure, and robustness production
summaries plus the pilot receipt. It verifies each exact admitted subset and
reports held pilot cells. It executes an RMSE pair only when both core cells were
admitted; either side absent gives that family claim `HOLD`. The broad verdict
passes only when every admitted cell in all three campaigns and all six core
pairs pass. A missing silent-failure or robustness summary is `HOLD`.

This correction performs no model fitting itself. Production remains Totoro/DRAC
compute, never GitHub Actions.
