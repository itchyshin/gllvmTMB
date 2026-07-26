# VA-R3 variance-domain gate runner

This private research runner tests the frozen VA-R3 prototype only.  It does
not add package code, exports, tests, or a public claim.

The fixture is deliberately restricted to complete multi-trial binomial-logit
data: `q = 2`, `T = 2`, `N = 10`, and `n_trials = 12`.  It never creates or
accepts `n_trials = 1`, and it does not source, import, or depend on
`dev/va-bernoulli.R`.  The frozen post-calibration campaign maps observed
bands 4, 6, 10, and 20 to the finite-fixture cells respectively
`nominal_prior_target`/seed 12/2026074012, 50/2026074050, 55/2026074055, and
45/2026074045.  Their retained calibration receipt is
`calibration-receipts/2026-07-26-post-calibration-cell-map.md`, with expected
observed maxima 4.614, 5.988, 8.674, and 22.191.  The predeclared observed
projected-variance bands are [3, 6], [5, 7], [8, 12], and [18, 24].  These are
calibrated finite-fixture cells, not an estimator guarantee.  A campaign with
any missed or unavailable band is marked `WITHHELD` and refuses to report a
variance-domain gate conclusion.

Run the one-target smoke test from the worktree root:

```sh
Rscript --vanilla dev/va-variance-gate/run-va-variance-gate.R --smoke
```

Run the local four-target campaign (no remote submission is performed):

```sh
Rscript --vanilla dev/va-variance-gate/run-va-variance-gate.R --campaign
```

To select a calibrated cell explicitly, use its observed-band label (not its
nominal-prior target), for example `--observed-bands=10`.

Each run writes an immutable-at-creation output directory under `results/`:

- `source-manifest.rds` records the exact source checksums, git head, frozen
  configuration, R version, and TMB version;
- `attempts-and-results.rds` retains all four optimisation starts, all fixed
  ELBO evaluations, and every truth-ladder attempt; and
- `summary.csv` reports the result without hiding failed or uninterpretable
  rows, including the observed-band label, `nominal_prior_target`, expected
  observed value, receipt path, and `observed_band_hit`.

For each best H61 VA coordinate, the runner evaluates the ELBO at exactly the
same coordinate using H15, H25, and H61.  It separately evaluates the true
two-dimensional marginal likelihood using product Gauss-Hermite at H151, H301,
H501, and H801.  The truth is `stable` only when all values are finite and the
predeclared H501-to-H801 tail difference is at most `1e-3`; otherwise it is
`uninterpretable`.  `ELBO - truth` is populated only for stable truth.  This
is intentionally a non-adaptive product-GH evaluator: AGHQ is never used.
