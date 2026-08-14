# Exact-gradient BFGS continuation design

## Scope

Estimator ID: `BFGS_EXACT_GRADIENT_CONTINUATION_V1`. This is a distinct
private estimator opened by the terminal G3 adjudication. It does not rewrite
G2/G3 history and changes no likelihood, Laplace approximation, DGP,
parameter transform, map, random-effect declaration, starting fit, scientific
estimand, or public API.

## Symbolic contract

Given the sole retained `nlminb` solution \(\theta_0\), use the same marginal
Laplace objective and exact outer gradient,

\[
  f(\theta),\qquad g(\theta)=\nabla f(\theta),
\]

and run exactly one unconstrained BFGS continuation

\[
  \theta_B=\operatorname{BFGS}(f,g;\theta_0).
\]

All constraints remain embedded in the package's existing unconstrained
parameter transforms. No finite-difference gradient, bounds projection,
restart, jitter, line-search tuning after inspection, profile, ridge, or G3
step is permitted.

Frozen control is

```r
list(maxit = 500L, reltol = 1e-12, trace = 0L, REPORT = 1L)
```

with `stats::optim(method = "BFGS", fn = obj$fn, gr = obj$gr)`. The control,
method, start, objective signature, and gradient signature are hashed and
retained.

## Alignment

| Mathematical object | Implementation | Validation | Evidence |
| --- | --- | --- | --- |
| \(\theta_0\) | sole selected `fit$opt$par` | finite positional IDs; `nlminb` convergence zero | start vector/order hash |
| \(f_0,g_0\) | `obj$fn(theta0)`, `obj$gr(theta0)` | exact replay; finite | raw state and hashes |
| BFGS estimator | `stats::optim(..., method="BFGS")` | exact frozen call and controls | result, counts, message, elapsed time |
| \(f_B,g_B\) | exact `fn`/`gr` replay at returned `par` | finite; same signature | candidate state |
| \(V_B\) | candidate-specific `sdreport$cov.fixed` | exact parameter replay/order; finite, symmetric, PD, `pdHess=TRUE`, condition `<=1e8` | covariance/eigenvalues/hash |
| admission | frozen predicates below | all conjunctive | terminal ledger |

## Raw eligibility

The input fit must have `nlminb` convergence zero, finite objective/gradient,
no boundary flag, unique positional IDs, unchanged signature, AGHQ/ridge/retry/
profile disabled, and maximum raw gradient strictly above `1e-3` but below
`1e-2`. Raw PD curvature is not required: Paper 1 entered this lane precisely
because its retained raw marginal Hessian was non-PD.

## Numerical admission

Admission requires all of:

- BFGS convergence code zero;
- finite candidate and exact replay identity;
- \(f_B\le f_0+64\epsilon\max(1,|f_0|)\);
- \(\|g_B\|_\infty\le10^{-3}\);
- candidate-specific `sdreport` curvature finite, symmetric to `1e-10`, PD,
  `pdHess=TRUE`, and condition at most `1e8`;
- unchanged parameter order, objective, map, data, random set, transforms,
  controls, starts, DLL content, and source commit.

Terminal states are `INVALID_PROVENANCE`, `BFGS_RAW_INELIGIBLE`,
`BFGS_OPTIMIZER_ERROR`, `BFGS_CURVATURE_UNAVAILABLE`,
`BFGS_CURVATURE_INVALID`, `BFGS_NO_NUMERICAL_ADMISSION`, and
`BFGS_NUMERICAL_ADMISSION`.

## Test and execution gates

Before a paper smoke: pure quadratic exact-gradient recovery; malformed input
and control rejection; compiled fixed-effect objective; tiny random-effects
fixture with candidate `sdreport`; runner receipt/timeout/consumed-root fences;
no retry/profile/G3/remote/campaign/threshold-relaxation path; independent
Gauss/Noether and Fisher/Rose review.

Paper 2 runs first, then Paper 1, each in one fresh root with a 5-20 minute
estimate and 30-minute hard stop. Numerical admission alone does not authorise
recovery, maps, empirical data, or public claims. A clean BFGS non-admission
opens the separately designed trust-region Newton lane; it does not authorise
control tuning.
