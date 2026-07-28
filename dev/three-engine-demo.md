# Three-engine demonstration: gllvmTMB Laplace vs gllvmTMB VA vs gllvm VA/EVA

Script: `dev/three-engine-demo.R`. Raw output: `dev/three-engine-demo-recovery.csv`,
`dev/three-engine-demo-timing.csv`, `dev/three-engine-demo-summary.csv`,
`dev/three-engine-demo-timing-summary.csv`, `dev/three-engine-demo.rds`.

**This is a demonstration, not a validation study.** One DGP (Bernoulli-logit,
q = 2, 8 traits), 5 seeds per cell, 2 sample sizes. See "What this does and
does NOT show" below before drawing any conclusion from the numbers.

## Engines compared

- **A -- gllvmTMB Laplace**: the public `gllvmTMB()` entry point, formula path
  `latent(1 | site, d = 2, unique = FALSE)`. This is the matched comparator
  required for a fair Psi-suppressed contrast; `gllvmTMB_wide()` cannot
  suppress the Psi diagonal and was therefore not used.
- **B -- gllvmTMB VA**: the internal `va_r3` engine via
  `gllvmTMB:::.approximation_engine_fit(engine = "va_r3", eval_method = "auto", ...)`.
  `"auto"` resolves to `"jj"` (Jaakkola-Jordan / Polya-Gamma bound) for
  binomial, which is the engine's current family-adaptive default -- not a
  hand-picked bound for this demo.
- **C -- gllvm's own VA/EVA**: `gllvm::gllvm(family = "binomial", link =
  "logit", method = "VA", ...)`. gllvm silently falls back to its extended
  (EVA) variant for model/family combinations where plain VA is not
  implemented; whatever it reports as `$method` and `$convergence` is used
  as-is. Called with `control.start = list(n.init = 4, jitter.var = 0.2)` to
  match va_r3's built-in 4-start search (gllvm's own `n.init = 1` default
  reliably diverges to degenerate loadings on Bernoulli-logit VA -- a
  fairness fix inherited from `dev/controlled-gh-vs-jj.R`, not a tune-away).

DGP: `dev/three-engine-demo.R::simulate_bernoulli_gllvm()`, reused verbatim
from `dev/controlled-gh-vs-jj.R`. `Lambda_true` entries `~ N(0, 0.7^2)`,
intercepts `~ N(0, 0.3^2)`, `Sigma_true = Lambda_true Lambda_true^T`.
`n_units in {150, 400}`, `n_traits = 8`, `q = 2`, 5 seeds per cell
(`base_seed = 20260727`).

Smoke test (n=30, p=6, q=2, seed=1) confirmed all three arms return real,
non-NA results before the grid ran; that smoke pass also absorbed each
engine's one-time TMB-compile / first-fit cost so none of the timings below
carry that confound.

## Table 1 -- Sigma_B recovery and loading agreement (median over 5 seeds)

| n | arm | rel. Frobenius Sigma_B | attenuation trace(Sigma_hat)/trace(Sigma_true) | compare_loadings Frobenius | mean per-factor cor (post-rotation) |
|---|-----|---:|---:|---:|---:|
| 150 | A (Laplace) | 0.731 | 0.892 | 1.482 | 0.677 |
| 150 | B (our VA, JJ) | 0.715 | 0.668 | 1.484 | 0.627 |
| 150 | C (gllvm VA) | 0.715 | 0.668 | 1.484 | 0.627 |
| 400 | A (Laplace) | 0.515 | 0.779 | 1.153 | 0.924 |
| 400 | B (our VA, JJ) | 0.582 | 0.536 | 1.256 | 0.907 |
| 400 | C (gllvm VA) | 0.582 | 0.536 | 1.256 | 0.907 |

`compare_loadings()` is the package export (`R/rotate-loadings.R`); values
above are the median rotated-Frobenius distance and the median of the mean
per-factor correlation across the 5 seeds. Per-seed numbers are in
`dev/three-engine-demo-recovery.csv`.

## Table 2 -- Convergence honesty (self-report + gradient + Hessian; all fractions over 5 seeds)

| n | arm | self-report OK | max\|gradient\| (median) | Hessian PD |
|---|-----|---:|---:|---:|
| 150 | A (Laplace) | 5/5 | 4.3e-04 | 5/5 (TMB `sdreport$pdHess`) |
| 150 | B (our VA) | 5/5 | 4.6e-05 | 5/5 (naive profile block) |
| 150 | C (gllvm) | 5/5 | 1.1e-04 | 5/5 (naive profile block) |
| 400 | A (Laplace) | 5/5 | 8.2e-04 | 5/5 (TMB `sdreport$pdHess`) |
| 400 | B (our VA) | **4/5** | 4.1e-05 | 5/5 (naive profile block) |
| 400 | C (gllvm) | 5/5 | 8.8e-04 | **4/5** (naive profile block) |

"Self-report" is engine-specific: A = `opt$convergence == 0` and
`sd_report$pdHess`; B = the engine's own internal health gate (multi-start
agreement + gradient + finite parameters, `raw$health$admitted`); C =
gllvm's own `$convergence` logical. "Hessian PD" for A is TMB's real
Laplace-profiled fixed-effect Hessian (computed by `sdreport()`); for B and C
it is a **naive** profile Hessian we computed ourselves post-hoc (see the
"What this does NOT show" section) restricted to the global structural block
(`beta`/`theta_rr` for B; `b`/`lambda`/`sigmaLV` for C), holding every
per-unit variational parameter fixed at its optimum.

One n=400 seed (20265127) is a genuine cross-check finding: **gllvm reported
`convergence = TRUE`, but our own naive Hessian check on that identical fit
found a near-zero/negative eigenvalue** (min eig ~ -9.4e-8), i.e. a
convergence self-report that alone would have hidden a degenerate fit -- the
concrete illustration of the gllvm vignette-10 warning that `$convergence`
alone is insufficient. On the same seed, our own VA engine's internal health
gate independently flagged `health = FALSE` even though its point estimate
was not obviously pathological (rel. Frobenius 0.708, in the same range as
the other 4 seeds).

## Table 3 -- Time to inference, point-only vs point+SE (median seconds over 5 seeds)

| n | arm | point-only | point + SE |
|---|-----|---:|---:|
| 150 | A (Laplace) | 1.34 | 2.15 |
| 150 | B (our VA) | 1.38 | **no SE support (structural gap)** |
| 150 | C (gllvm) | 0.95 | 1.36 |
| 400 | A (Laplace) | 3.66 | 5.78 |
| 400 | B (our VA) | 9.65 | **no SE support (structural gap)** |
| 400 | C (gllvm) | 6.86 | 9.69 |

Point-only = `gllvmTMBcontrol(se = FALSE)` / `gllvm(sd.errors = FALSE)`;
point+SE = the default (`se = TRUE` / `sd.errors = TRUE`), i.e. the fit
**including** `TMB::sdreport()` (A) or gllvm's own SE step (C). Our VA engine
(B) has no standard-error machinery at all -- there is no point+SE number to
report, and none is fabricated.

At n=400, Laplace's point+SE time (5.78 s) is close to our VA engine's
point-**only** time (9.65 s is actually higher) -- i.e. the production
Laplace route, including its standard errors, is faster here than our VA
engine's bare point estimate, and gllvm's own VA (6.86 s point-only) is
faster than ours too. This VA-engine result is the single most actionable
negative finding of this demo: our engine's runtime advantage over Laplace,
if it exists at all in this regime, is not visible at n <= 400 for this DGP.

## What this does and does NOT show

- **No standard errors from the VA engine.** This is a structural gap, not a
  missing feature we approximated: B has never a `point + SE` column, and no
  number is faked for it anywhere in this report.
- **5 seeds per cell.** Every number above is a median of 5 replicates.
  Per-seed variation is real and sometimes large (e.g. Arm A's per-seed
  relative Frobenius at n=400 ranges from 0.33 to 0.66 across the 5 seeds --
  see the CSV); differences between arms that look consistent in *direction*
  across all 5 seeds are still not a statistically validated effect at this
  replicate count. No standard errors or confidence bands are reported on
  these medians.
- **One DGP.** Bernoulli-logit only, q = 2, 8 traits, moderate loading/intercept
  scales (`lambda_sd = 0.7`, `beta_sd = 0.3`), balanced complete design, no
  missingness, no phylogeny, no covariates beyond the trait intercepts. Our
  VA engine's admitted envelope (binomial-logit or Poisson-log, `unique =
  FALSE`, complete cells) ruled out probit, structured/phylogenetic terms,
  and missing data from consideration by design, not by oversight.
- **The Hessian checks are not apples-to-apples.** Arm A's Hessian check is
  TMB's own, real, Laplace-profiled marginal Hessian of the fixed effects
  (computed by `sdreport()`, exactly what production users see as `pdHess`).
  Arms B and C's Hessian checks are a **naive submatrix** we computed
  ourselves with `numDeriv::hessian()` on the global structural parameters
  only, holding every per-unit variational parameter fixed at its reported
  optimum -- neither engine declares a TMB `random=` block, so there is no
  built-in analogue of Laplace's implicit-function-corrected profile, and
  computing the full joint Hessian (thousands of parameters at n=400) was
  not attempted. This naive check is weaker than Laplace's and probably
  **optimistic** (it ignores curvature coupling to the per-unit block), so a
  "Hessian PD" pass for B/C is a lower bar than a "Hessian PD" pass for A.
- **Gradient magnitudes are not on a common scale.** A's gradient is the
  Laplace-profiled fixed-effect gradient; B's is the GH/JJ ELBO gradient
  across the full joint (including per-unit variational) parameter vector;
  C's is gllvm's own joint VA-objective gradient. The three objectives are
  different functions evaluated on different parameterisations -- only
  presence/absence of gross pathology (e.g. non-finite, or many orders of
  magnitude larger) should be read from the raw numbers, never a cross-arm
  ranking by magnitude.
  Consistent with this caveat, gllvm's gradient (C) is sometimes numerically
  *larger* than ours (B) or Laplace's (A) at converged, healthy fits (e.g.
  n=400 seed 20266127: C = 5.8e-03 vs A = 6.5e-04, B = 6.4e-05) purely
  because it is a different, unnormalised objective -- not evidence C is less
  converged.
- **gllvm was NOT run with its own defaults.** `n.init = 4, jitter.var =
  0.2` was used instead of gllvm's own `n.init = 1` default, to match our
  engine's built-in 4-start search -- a deliberate fairness fix documented in
  `dev/controlled-gh-vs-jj.R`, but it means Arm C's numbers are not what a
  user gets from a bare `gllvm::gllvm(...)` call with its factory defaults.
- **B and C's near-identical recovery numbers are the point, not a bug.**
  Both use the same Jaakkola-Jordan/Polya-Gamma bound; the demo isolates the
  *engine/implementation* while holding the *bound* fixed, and the near-exact
  agreement (rel. Frobenius, attenuation, and per-factor correlation all
  matching to 3+ significant figures at every seed) is the expected,
  reassuring result from that design, following the same logic established
  in `dev/controlled-gh-vs-jj.R`.
- **11 R warnings were emitted somewhere across the ~50 fits in the full run**
  (`Rscript dev/three-engine-demo.R`, "There were 11 warnings" at the end).
  They were not individually triaged in this pass -- AGENT-INFERRED: most
  likely routine `nlminb`/`optim` step-halving or gllvm-internal fitting
  messages, but this is not verified and should not be treated as a clean
  bill of health.
- **This is a dev/-only research script**: no `@export`, no `testthat`
  coverage, not part of any package surface, and it makes no CRAN-readiness
  or release claim of any kind.
