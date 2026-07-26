# The controlled bound-vs-implementation experiment: GH vs JJ, same engine

**Fisher pass. Internal research only — no `@export`, no `method=` argument, no
public claim.** Script: `dev/controlled-gh-vs-jj.R`. Raw data:
`dev/controlled-gh-vs-jj.csv` / `.rds` (80 rows: 2 sizes x 10 seeds x 4 arms).
Never call an ELBO a likelihood.

## The question

An earlier, uncontrolled comparison (`dev/bound-vs-estimates-recovery.R` /
`dev/bound-vs-estimates.md`, this repo, this session) found that gllvmTMB's
Gauss-Hermite VA (GH, our engine) recovers `Sigma_B` **worse** than gllvm's
`method = "VA"` (Jaakkola-Jordan/Polya-Gamma, JJ, their engine): median
relative Frobenius error 2.19 vs 0.87 at n=60, 0.90 vs 0.55 at n=100. That
comparison confounds two things that changed at once: **the bound** (GH is
provably tighter than JJ) and **the implementation** (optimiser, starts,
health gates, numerics all differ between our engine and gllvm's). This
experiment separates them by adding a same-engine JJ arm (`eval_method =
"jj"`, added to `R/va-r3-proto.R` / `inst/tmb/gllvmTMB_va_r3.cpp` earlier this
session) so GH and JJ can be run through the identical optimiser, starts, and
gates.

## Design

Four arms on the **identical** simulated Bernoulli-logit matrix per seed
(`q = 2`, `Lambda_true ~ N(0, 0.7^2)`, `beta_true ~ N(0, 0.3^2)`, Gaussian
latent scores; sizes (n=60, p=12) and (n=100, p=20), 10 seeds per cell, same
DGP and seed formula as the prior 3-arm study for direct comparability):

- **A**: ours, GH — `.approximation_engine_fit(engine = "va_r3", eval_method
  = "auto", H = 15L, ...)`. Gauss-Hermite quadrature evaluation of
  `E[softplus(eta)]`.
- **B**: ours, JJ — the identical call with `eval_method = "jj"`. Same TMB
  template, same `nlminb` optimiser, same 4-start search
  (`R/va-r3-proto.R`'s `starts <- lapply(1:4, ...)` runs unconditionally for
  both `eval_method` values), same health gates. Only the per-observation
  evaluation of the expected softplus term differs (closed-form JJ bound vs
  15-point Gauss-Hermite quadrature).
- **C**: `gllvm::gllvm(family = "binomial", link = "logit", num.lv = 2,
  method = "VA")` — the JJ bound, gllvm's own optimiser/starts/gates.
  `control.start = list(n.init = 4, jitter.var = 0.2)` to match A/B's 4-start
  budget (gllvm's single-start default reliably diverges on this DGP; see
  the prior study's pitfall #2).
- **D**: gllvmTMB Laplace, Psi-suppressed —
  `traits(...) ~ 1 + latent(1 | site, d = 2, unique = FALSE)`,
  `family = binomial()`. Not called via `gllvmTMB_wide()` (known positive-logLik
  defect on binary data).

Metric (rotation-invariant only; loadings never compared elementwise):
`rel_frob = ||Sigma_hat - Sigma_true||_F / ||Sigma_true||_F` and
`atten = trace(Sigma_hat) / trace(Sigma_true)`. Every fit wrapped in
`tryCatch`; all 80/80 fits returned a usable `Sigma_hat` (`ok = TRUE`
throughout — the failure mode here is silent numerical divergence with a
clean convergence code, not a hard error; see contrast 3).

## Results

### n = 60, p = 12 (10 seeds)

| Arm | rel. Frobenius error (median [IQR]) | attenuation ratio (median [IQR]) | median time |
|---|---|---|---|
| A: ours, GH | 2.189 [1.779, 2.487] | 2.754 [2.309, 2.905] | 2.74 s |
| B: ours, JJ | **0.863** [0.786, 0.974] | 1.182 [1.060, 1.316] | **0.43 s** |
| C: gllvm, JJ | 0.866 [0.786, 0.974] | 1.182 [1.059, 1.316] | 0.52 s |
| D: gllvmTMB Laplace | 2750.5 [721.6, 7478.1] | 2000.7 [571.3, 5678.1] | 4.41 s |

Arm A status: 8/10 `failed_variance_domain`, 2/10 `healthy`. Arm B status:
10/10 `healthy`. Arm C: 10/10 `converged`. Arm D: 10/10 `pdHess = TRUE`, but
8/10 land on a degenerate loading (`rel_frob > 10`, up to 55206x) — see
contrast 3.

### n = 100, p = 20 (10 seeds)

| Arm | rel. Frobenius error (median [IQR]) | attenuation ratio (median [IQR]) | median time |
|---|---|---|---|
| A: ours, GH | 0.895 [0.684, 1.099] | 1.441 [1.274, 1.688] | 11.22 s |
| B: ours, JJ | **0.554** [0.469, 0.656] | 0.883 [0.820, 1.128] | **1.39 s** |
| C: gllvm, JJ | 0.554 [0.469, 0.656] | 0.883 [0.820, 1.128] | 1.48 s |
| D: gllvmTMB Laplace | 1.058 [0.683, 1.131] | 1.586 [1.235, 1.701] | 6.46 s |

Arm A status: 6/10 `healthy`, 3/10 `failed_health_gate`, 1/10
`failed_variance_domain`. Arm B status: 8/10 `healthy`, 2/10
`failed_health_gate`. Arm C: 10/10 `converged`. Arm D: 10/10 `pdHess = TRUE`,
2/10 degenerate.

These medians (arm A, and arm D/its historical counterpart arm C) reproduce
the prior 3-arm study's numbers essentially exactly, as expected from the
identical DGP and seed formula — a useful internal consistency check that
nothing else changed between the two scripts.

## The three decisive contrasts

### 1. A vs B — same engine, different bound. This isolates THE BOUND.

**B (JJ) beats A (GH) in 10/10 seeds at both sizes.** Median
`rel_frob_A - rel_frob_B` = **+1.282** at n=60 and **+0.379** at n=100 (A
worse in both cases, by a wide and consistent margin — not a coin-flip
tie). This is the whole point of the experiment: holding the optimiser,
starts, and health gates fixed and changing only the per-observation
evaluation of `E[softplus(eta)]` from 15-point Gauss-Hermite quadrature to
the closed-form Jaakkola-Jordan bound, **the looser bound produces the
better point estimate of `Sigma_B`, every single time in this design.**
Bound tightness genuinely hurts recovery here; this is not an artifact of
comparing across implementations.

### 2. B vs C — same bound, different engine. This isolates THE IMPLEMENTATION.

**B and C are numerically indistinguishable.** Max absolute difference in
`rel_frob` across all 20 seeds: 0.0071 (n=60) and 0.0006 (n=100); median
difference is 0 to five decimal places at both sizes. Two independently
written TMB/optimisation stacks (our `va_r3` template with `eval_method =
"jj"` vs gllvm's C++ VA implementation), given the same bound, converge to
essentially the same `Sigma_B` estimate on every seed tested.

**Combined verdict on contrasts 1+2: the original A-vs-C gap was
overwhelmingly THE BOUND, not the implementation.** Since B (our engine, JJ
bound) reproduces C (gllvm, JJ bound) almost exactly, and A (our engine, GH
bound) is reliably worse than B by the same engine, the entire gap that
looked like an implementation problem in the earlier uncontrolled study is,
on this evidence, attributable to the choice of evaluation bound — a
provably tighter ELBO (GH) yields a worse `Sigma_B` point estimate than a
provably looser one (JJ) in this exact recovery design. This reverses the
naive expectation that a tighter bound should track a better fit, and it is
not an artifact of our engine being a worse optimiser: our own engine, using
the JJ bound, matches gllvm's implementation almost exactly.

### 3. D's silent-failure rate

Measured directly (`pdHess == TRUE` AND `rel_frob > 10`, i.e. a clean
reported convergence landing on a loading matrix off by orders of
magnitude): **10/20 (50%)** — 8/10 at n=60, 2/10 at n=100. All 20/20 fits
report `pdHess = TRUE` regardless of whether the loading is sane, so the
Hessian-positive-definiteness flag carries **zero information** about
whether this particular fit is trustworthy. Restricting to the 12/20
non-degenerate fits: rel_frob median 1.222 (n=60, n=2) / 0.932 (n=100, n=8),
atten median 1.653 / 1.393 — competitive with arm A but still behind arm
B/C, and this is the subset a user has no way to identify from the reported
diagnostics alone. This reproduces the prior study's Laplace-arm finding
essentially exactly (8/10 and 2/10 degenerate there too), which is expected
since arm D here and arm C there are the identical call on the identical
data.

## Honest limitations

- 10 seeds per cell is enough to see a consistent, sizeable, 10/10-seed
  direction of effect for contrast 1, and a near-zero max-diff for contrast
  2; it is not a formal hypothesis test and the seeds are not independent
  across arms (same simulated data per seed, so contrasts 1 and 2 are paired
  comparisons, which is the correct and stronger design for isolating a
  within-seed effect — but it also means the 10 "replicates" share sampling
  variation, not fully independent evidence about the DGP in general).
- This design uses one loading scale (`sd = 0.7`) and one latent
  dimensionality (`q = 2`); the result that JJ beats GH here should not be
  read as "JJ always beats GH" — it is a documented, reproducible finding in
  *this* design, not a swept generalisation.
- Arm A's own health gates flag most of these fits as outside its certified
  operating domain (14/20 `failed_variance_domain`/`failed_health_gate`
  across both cells) — this may be exactly the regime where GH quadrature
  behaves worst, and the gap could look different in a regime GH's own
  diagnostics certify as healthy. That said, contrast 1 is not confounded by
  arm A's health-gate rate: arm B and arm A are evaluated on the identical
  fitted objective machinery, so whatever is driving arm A's worse
  `rel_frob` is a property of the GH bound itself in this regime, whether or
  not the health gate also flags it.
- The 10/20 (50%) silent-failure figure for arm D differs from an "8/20"
  figure mentioned as an earlier recollection in this task's brief; it
  matches exactly the previously published 3-arm study's own reported
  breakdown (8/10 at n=60, 2/10 at n=100) for the identical call on the
  identical data, so it is treated here as the correct, reproduced number.

## Bottom line

The tighter Gauss-Hermite bound does not produce a better `Sigma_B`
estimate than the looser Jaakkola-Jordan bound in this design, and this is
now demonstrated with the confound removed: it holds when the optimiser,
starts, and health gates are held fixed (A vs B), and it is not an artifact
of our engine being weaker than gllvm's (B vs C are indistinguishable).
Whatever advantage a tighter variational bound offers in principle, it is
not visible in the point estimate of the loading covariance for
Bernoulli-logit GLLVMs at this sample size and loading scale — and the
practical case for JJ over GH here is reinforced by JJ's ~5-8x faster
wall-clock and its being `healthy`/`converged` far more often. Separately,
Laplace with Psi suppressed is the least trustworthy arm precisely because
its own diagnostics (`pdHess = TRUE`) give no signal when it has silently
diverged, which happens on half the fits tested.
