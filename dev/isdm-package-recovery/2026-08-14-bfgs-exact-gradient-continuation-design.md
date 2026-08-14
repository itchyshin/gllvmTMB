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
| \(\theta_0\) | pre-continuation selected `nlminb` vector retained in `fit$isdm_polish_provenance$raw` | exactly one initial restart selected; finite positional IDs; `nlminb` convergence zero | start vector/order and complete restart-provenance hashes |
| \(f_0,g_0\) | `obj$fn(theta0)`, `obj$gr(theta0)` | objective replay within `64 * eps * max(1, abs(f0))`; exact-gradient replay finite, same names/order, and symmetric relative discrepancy `<=1e-8` | retained and replayed raw states plus discrepancies |
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

The runner disables the ordinary package fit's internal warm-restart and G2
candidate routes through a private, fail-closed iSDM control. The default
package behaviour is unchanged outside this runner. The runner must recover
the pre-continuation vector and diagnostics from
`fit$isdm_polish_provenance$raw`, prove that the restart history contains
exactly one selected initial `nlminb` run, prove that neither internal
continuation was attempted, replay `fn` and `gr` at that vector, and retain
hashes of the complete warm-restart, G2-polish, restart-history, actual control,
and start-provenance records. Missing or inconsistent evidence is
`INVALID_PROVENANCE`.

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

Terminal states are `INVALID_PROVENANCE`, `BFGS_INFRASTRUCTURE_HOLD`,
`BFGS_RAW_INELIGIBLE`, `BFGS_OPTIMIZER_ERROR`, `BFGS_CURVATURE_UNAVAILABLE`,
`BFGS_CURVATURE_INVALID`, `BFGS_NO_NUMERICAL_ADMISSION`, and
`BFGS_NUMERICAL_ADMISSION`.

`BFGS_OPTIMIZER_ERROR` is reserved for an error thrown by the single sealed
`stats::optim()` call or a malformed optimizer result. Runner failures,
timeouts, unavailable objective/gradient/curvature interfaces, and failed
post-optimizer exact replay are `BFGS_INFRASTRUCTURE_HOLD`; they are never
reported as algorithm rejection. A root containing either
`attempt-started.rds` or a terminal ledger is consumed and cannot be rerun.

## Test and execution gates

Before a paper smoke: pure quadratic exact-gradient recovery; malformed input
and control rejection; compiled fixed-effect objective; tiny random-effects
fixture with candidate `sdreport`; runner receipt/timeout/consumed-root fences;
no retry/profile/G3/remote/campaign/threshold-relaxation path; independent
Gauss/Noether and Fisher/Rose review.

Paper 2 runs first, then Paper 1, each in one fresh root with a 5-20 minute
estimate and 30-minute hard stop. Each paper has exactly one canonical,
normalized source-gate root; nested or alternate roots with the same basename
are invalid, and the normalized root is retained in the receipt. Paper 1
preflight requires Paper 2's full typed receipt, optimizer-entry marker, actual
BFGS result, current terminal manifest, and matching source, DLL, control, and
continuation-provenance hashes. A provenance or pre-BFGS infrastructure hold
does not unlock Paper 1, so ordering is executable rather than prose-only.
Numerical admission alone does not authorise
recovery, maps, empirical data, or public claims. A clean BFGS non-admission
opens the separately designed trust-region Newton lane; it does not authorise
control tuning.
