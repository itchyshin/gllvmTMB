# Dependent temporal--kernel native-`nlminb` candidate qualification

## Purpose

This is a new, separately frozen qualification candidate for the direct
Gaussian, replicated AR1 `temporal_dep() + kernel_indep()` model. It tests one
native-coordinate two-pass `nlminb` regime after the retained BFGS campaign
failed its strict outer-gradient requirement. It does not reopen, replace,
pool with, or reinterpret that failed campaign.

The retained endpoint audit shows agreement between the native objective and
an independent dense Gaussian oracle at the failed BFGS endpoint. It identifies
an outer-gradient breach but does not establish its cause or imply that this
candidate will pass.

## Frozen DGP and estimator

The direct generator is the existing independently authored 80-series,
32-occasion, three-trait, two-measurement fixture. It never calls production
temporal simulation. The formula, Gaussian ML/Laplace likelihood, maps,
transforms, fixed kernel, starting regime, and direct-DGP truth are unchanged.

The sole candidate intervention is this bundled outer solver regime:

```r
gllvmTMBcontrol(
  se = FALSE, integration = "laplace", aghq = FALSE,
  loading_ridge = NULL, n_init = 1L, init_strategy = "default",
  init_jitter = 0.3, start_method = list(method = NULL, jitter.sd = 0),
  start_from = NULL, optimizer = "nlminb", optimizer_passes = 2L,
  optArgs = list(
    scale = 1, lower = -Inf, upper = Inf,
    control = list(iter.max = 3000L, eval.max = 12000L, rel.tol = 1e-14,
      x.tol = 1e-10, abs.tol = 0, xf.tol = 2.2e-14, sing.tol = 1e-14,
      trace = 0)
  )
)
```

The developer-only diagnostic recorder is enabled only to retain endpoint
evidence; it does not change the objective, calls, starts, or adoption rule.
The bundled controls are a candidate intervention, not evidence-derived
optimal settings. A result cannot isolate which setting, if any, mattered.

## Cells, outputs, and gates

The timing pre-run is `(phi = .6, seed = 2609380)`. The nine campaign cells
are `phi = (-.4, 0, .6)` crossed with seeds `2609381:2609383`. These seeds are
disjoint from every retained BFGS campaign and diagnostic. Every invocation
atomically writes a new receipt under
`dev/temporal-program/results/occasion-32-nlminb-qualification-20260912/`;
failures are retained with the same schema.

Before the campaign: prove parser and direct-generator boundaries, receipt
immutability, exact two-pass record shape, normalized counters, unchanged
initial parameters/maps, and independent final-endpoint oracle agreement
(absolute NLL error at most `1e-6`, maximum gradient discrepancy at most
`1e-4`). Time and retain the pre-run. If the projected campaign exceeds 30
minutes, obtain separate compute approval before launch.

The campaign applies the unchanged strict native requirements: each pass has
convergence code zero, the second pass is accepted, the full maximum absolute
outer gradient is at most `1e-3`, and objective/parameters are finite. Each
persistence stratum requires all three strict successes, mean/median absolute
phi error at most `.15`/`.20`, median temporal covariance relative Frobenius
error at most `.30`, median relative error at most `.35` for each kernel
variance, and mean fixed-effect error at most `.25`.

## Claim boundary

Even if all nine cells pass, the result is bounded local direct-DGP evidence
for this frozen numerical regime. It does not establish general optimizer
superiority, recovery, coverage, outer curvature, source-pair admission,
forecasting, cross-platform readiness, merge, or release.
