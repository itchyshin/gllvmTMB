# G3 marginal-curvature contract

**Status:** design-only implementation contract. This artifact replaces no
retained result and authorises no fit, retry, profile, recovery run, campaign,
model change, or public claim. The consumed `G3P_P2_S6_C360_R3_V2` root
remains a receipt-valid terminal `G3_HESSIAN_UNAVAILABLE` infrastructure HOLD:
no G3 trial ran, so it is neither G3 rejection nor numerical admission.

## Purpose and invariant

The current G3 helper asks `ADFun$he()` for fixed-parameter curvature. That API
is unavailable for the retained random-effects model. The proposed
infrastructure uses the fixed-parameter covariance returned by a
candidate-specific `TMB::sdreport()` as the inverse Hessian of the same
marginal Laplace objective. It changes only how local curvature is obtained.
It does not change the objective, exact gradient, parameterisation, map,
random effects, bounds, starts, controls, selected raw solution, source gate,
or numerical-admission threshold.

Let the selected outer parameter vector, marginal objective, and AD-exact
gradient be

\[
  \theta_0\in\mathbb R^p,\qquad
  f_0=f(\theta_0),\qquad
  g_0=\nabla f(\theta_0).
\]

For the candidate-specific `sdreport()` evaluated at \(\theta_0\), define

\[
  V_0=\operatorname{cov.fixed}(\theta_0)=H_0^{-1},\qquad
  H_0=\nabla^2 f(\theta_0),
\]

and compute the covariance-scaled score and descent direction as

\[
  d=V_0g_0,\qquad -d=-V_0g_0.
\]

The G3 trial sequence is exactly

\[
  \mathcal A=\{2^{-k}:k=0,\ldots,8\}
  =(1,1/2,\ldots,1/256),
  \qquad
  \theta_\alpha=\theta_0-\alpha d.
\]

The grid order is part of the estimator. It must not be shortened, extended,
sorted again, adapted to the result, or stopped after the first acceptable
trial. All nine trial records are retained. If more than one trial satisfies
the numerical gates, the selected trial is the first one in this frozen order
(the largest \(\alpha\)).

Because \(V_0\) must be positive definite and the raw G3 gradient is nonzero,
\(g_0^\top d=g_0^\top V_0g_0>0\); hence \(-d\) is locally descending. This
algebra is necessary but not sufficient for admission.

## Positional coordinate identity

Repeated TMB block labels are not coordinate identifiers. For position
\(j=1,\ldots,p\), construct the immutable global positional ID

\[
  \operatorname{id}_j=\operatorname{block}_j\texttt{[}j\texttt{]}.
\]

Every block label must be present and non-empty, and the resulting IDs must be
unique. The outer `par`, exact gradient, bounds, `sdreport()$par.fixed`, and
both axes of `cov.fixed` must align position-for-position before those IDs are
assigned. In particular:

1. `par`, `gradient`, and `sdreport()$par.fixed` have length \(p\), identical
   block-label order, and finite values;
2. `sdreport()$par.fixed` equals the requested \(\theta\) at that same
   position, within the same machine-precision tolerance used for objective
   replay;
3. `cov.fixed` is \(p\times p\); any supplied row/column labels must match the
   block-label order or the already-generated positional IDs exactly; and
4. no name matching, `make.unique()`, sorting, subset matching, or silent
   permutation may repair a mismatch.

Failure to establish positional identity is an infrastructure HOLD, not a
bad numerical candidate. The callback record retains the original labels and
the generated IDs.

## Curvature callback contract

The first implementation should keep `sdreport()` outside the pure numerical
trial engine. Inject a callback with the conceptual interface

```r
curvature_fn(theta, positional_ids)
```

returning exactly a typed record containing:

```r
list(
  available = <TRUE/FALSE>,
  reason = <one non-empty status string>,
  par.fixed = <numeric vector or NULL>,
  cov.fixed = <numeric matrix or NULL>,
  pdHess = <TRUE/FALSE/NA>,
  positional_ids = <character vector>,
  error = <character scalar or NA_character_>
)
```

The production adapter obtains this record from a candidate-specific
`TMB::sdreport()` call on the already-constructed TMB object, with
`par.fixed = theta`. It must not rebuild the objective or alter the map,
random-effects declaration, data, scale, or controls. Before returning, the
adapter verifies the positional-coordinate contract above.

For every available raw or candidate covariance \(V\), the numerical core
requires all of the following without silent symmetrisation or ridge repair:

\[
  V\in\mathbb R^{p\times p},\quad
  V=V^\top\ \text{to tolerance }10^{-10},\quad
  V\text{ finite},\quad
  V\succ0,\quad
  \kappa_2(V)\le10^8.
\]

Positive definiteness is established by Cholesky decomposition; conditioning
uses the exact 2-norm condition number, and the callback's `pdHess` flag must
be exactly `TRUE`. Since \(V=H^{-1}\),
\(\kappa_2(V)=\kappa_2(H)\). A callback error, absent `cov.fixed`, unavailable
`sdreport()`, or unalignable coordinates is infrastructure failure. A returned,
aligned covariance that is non-finite, non-symmetric, non-PD, or over the
condition limit is an observed numerical invalidity: it makes the raw state
ineligible or rejects that candidate trial, as applicable.

The raw `V0` supplies the single frozen direction \(d=V_0g_0\). Candidate
covariances \(V_\alpha\) are curvature guards only; they never update the
direction or create an iterative Newton method.

## Independent finite-difference curvature-direction check

Before any alpha trial, independently approximate the full Jacobian of the
AD-exact outer gradient. For coordinate \(j=1,\ldots,p\), define the default
coordinate displacement

\[
  h_j=\epsilon^{1/3}\max(1,|\theta_{0j}|),
  \qquad \epsilon=\texttt{.Machine\$double.eps},
\]

and use exactly the three predeclared multipliers

\[
  \mathcal S=(1/2,1,2).
\]

For each \(s\in\mathcal S\), construct the central finite-difference Jacobian
of the exact gradient one column at a time:

\[
  \{H_{\rm FD}^{(s)}\}_{\cdot j}=
  \frac{g(\theta_0+s h_j e_j)-g(\theta_0-s h_j e_j)}{2s h_j},
  \qquad j=1,\ldots,p.
\]

These are independent evaluations of `obj$gr`; they must not reuse
`cov.fixed`, differentiate `obj$fn`, call `obj$he`, or finite-difference a
rebuilt objective. All \(6p\) exact-gradient evaluations and displaced points
must be finite, in bounds, and in the same positional coordinate order.

Each raw finite-difference matrix must first be symmetric to tolerance
`1e-10`; only after passing that check may the explicitly retained matrix
`(H + t(H)) / 2` be used to remove round-off asymmetry. Each checked matrix
must be positive definite and have exact condition number at most \(10^8\).

For every step multiplier, solve the independently estimated curvature system

\[
  d_{\rm FD}^{(s)}=\{H_{\rm FD}^{(s)}\}^{-1}g_0
\]

without replacing it by a pseudoinverse, ridge, diagonal approximation, or
an unchecked symmetrisation. Each system must be finite. The
relative direction disagreement is

\[
  \Delta_s=
  \frac{\lVert d-d_{\rm FD}^{(s)}\rVert_2}
       {\max\{\lVert d\rVert_2,\lVert d_{\rm FD}^{(s)}\rVert_2,\sqrt\epsilon\}},
\]

and the half/default/double step sensitivity is the maximum pairwise
disagreement

\[
  \Delta_{\rm step}=
  \max_{s<t; s,t\in\mathcal S}
  \frac{\lVert d_{\rm FD}^{(s)}-d_{\rm FD}^{(t)}\rVert_2}
       {\max\{\lVert d_{\rm FD}^{(s)}\rVert_2,
                \lVert d_{\rm FD}^{(t)}\rVert_2,\sqrt\epsilon\}}.
\]

The check passes only when

\[
  \max_{s\in\mathcal S}\Delta_s\le0.01
  \qquad\text{and}\qquad
  \Delta_{\rm step}\le0.01.
\]

The half/default/double checks are conjunctive. The implementation must not
tune a failing \(h_j\), drop a coordinate or multiplier, switch to one-sided
differences, or relax either 1% gate. An unavailable exact-gradient evaluation
is `G3_CURVATURE_UNAVAILABLE`; a finite but nonsymmetric, non-PD,
ill-conditioned, direction-disagreeing, or step-sensitive result is
`G3_CURVATURE_INVALID` because `cov.fixed %*% g0` has not validated against
independently estimated marginal curvature.

## Raw eligibility and trial acceptance

After infrastructure is available, the unchanged G3 raw predicate requires:

- `nlminb` convergence code zero;
- the private iJSDM route with AGHQ, ridge, retry, and profile all disabled;
- the frozen signature and source gate;
- finite \(f_0\), \(g_0\), \(\theta_0\), and bounds;
- no boundary flag and one unique maximum absolute-gradient coordinate;
- \(10^{-3}<\lVert g_0\rVert_\infty<10^{-2}\);
- aligned, finite, symmetric, PD \(V_0\) with \(\kappa_2(V_0)\le10^8\); and
- all three finite-difference direction agreements and the pairwise
  half/default/double step-sensitivity check above.

For each \(\alpha\in\mathcal A\), retain \(\theta_\alpha\), \(f_\alpha\),
the AD-exact \(g_\alpha\), signature, and every gate/reason. Evaluate all nine
objective/gradient pairs. Request candidate `sdreport()` curvature only when
the bounds, objective, and gradient predicates pass; otherwise retain an
explicit `NOT_REQUESTED` callback state. When requested, retain the callback
record, \(V_\alpha\), eigenvalues, and condition number. A trial is acceptable
if and only if

\[
  \theta_\alpha\text{ is within bounds},\qquad
  f_\alpha\le f_0+\tau_f,\qquad
  \lVert g_\alpha\rVert_\infty\le10^{-3},
\]

and its aligned `sdreport()` covariance is finite, symmetric, positive
definite, and has condition number at most \(10^8\), with the complete
signature unchanged. The objective tolerance is frozen as

\[
  \tau_f=64\epsilon\max(1,|f_0|).
\]

The gradient gate is the unscaled/raw AD-exact gradient. A scaled gradient,
\(Vg\), small step, `pdHess` flag alone, profile shape, or recovery result can
never substitute for \(\lVert g_\alpha\rVert_\infty\le10^{-3}\).

## Mutually exclusive terminal taxonomy

| Terminal class | Exact meaning | Candidate/admission consequence |
| --- | --- | --- |
| `G3_CURVATURE_UNAVAILABLE` | Infrastructure HOLD: the correctly specified route cannot be adjudicated because raw or candidate `sdreport()` is unavailable/errors, `cov.fixed` or `par.fixed` is absent, positional identity cannot be established, or any required exact-gradient evaluation for the independent finite-difference Jacobian is unavailable. | No numerical rejection and no admission. Preserve the raw fit and exact infrastructure reason. The retained V2 `G3_HESSIAN_UNAVAILABLE` result maps conceptually to this class but is not rewritten. |
| `G3_CURVATURE_INVALID` | Curvature was returned and aligned, but raw \(V_0\) or an independently constructed \(H_{FD}^{(s)}\) is non-finite, non-symmetric, non-PD, ill-conditioned, or fails the direction or step-sensitivity gate. | No alpha trial is admitted. This is observed invalid curvature, distinct from unavailable infrastructure and from the ordinary raw G3 predicate. A candidate \(V_\alpha\) with these properties rejects that trial; it is retained in the exact grid. |
| `G3_RAW_INELIGIBLE` | Required curvature infrastructure exists and is valid, but the raw state fails the frozen G3 predicate, bounds, signature, open gradient interval, or unique-maximum/boundary rule. | No alpha candidate is selected. This is a measured raw-state exclusion. |
| `G3_NO_ACCEPTED_TRIAL` | The raw state is eligible, the exact nine-alpha ledger is complete, every required callback/evaluation was available, and no trial satisfies every bound, finite-evaluation, objective, raw-gradient, signature, and candidate-curvature gate. | G3 was genuinely evaluated but did not numerically admit the fit. Retain every trial and reason. |
| `G3_NUMERICAL_ADMISSION` | The raw state is eligible, the exact nine-alpha ledger is complete, every required callback/evaluation was available, and at least one trial satisfies every gate. | Select the first acceptable alpha in frozen order. This establishes only same-objective numerical admission for this attempt. |

Any unavailable raw or candidate callback/evaluation across the exact grid is
`G3_CURVATURE_UNAVAILABLE`, even if another trial would otherwise pass.
Partial-grid success cannot be promoted. A returned but invalid candidate
curvature is a numerical rejection for that trial; after all nine trials it
contributes to `G3_NO_ACCEPTED_TRIAL` unless a different trial passes.

No terminal class establishes recovery, Psi calibration, ecological/bias-field
separation, model adequacy, interval validity, or a public package capability.

## Symbolic-to-implementation alignment

| Symbol or rule | Proposed implementation field/interface | Source/evaluation | Retained validation and role |
| --- | --- | --- | --- |
| \(\theta_0\) | `par`, then `raw$parameter_vector` | selected `fit$opt$par` only | finite, within frozen bounds, unique positional IDs; no new start or coordinate map |
| \(f_0=f(\theta_0)\) | `obj$fn(par)`, `raw$objective` | existing marginal Laplace objective | finite and replay-matched to selected likelihood objective |
| \(g_0=\nabla f(\theta_0)\) | `obj$gr(par)`, `raw$gradient` | AD-exact gradient of the same object | finite, positional IDs, open G3 interval, unique maximum; never replaced by a scaled score |
| \(V_0=H_0^{-1}\) | `curvature_fn(par, ids)$cov.fixed` | raw candidate-specific `sdreport()` | available/aligned, finite, symmetric, PD, `kappa <= 1e8`; supplies direction |
| \(d=V_0g_0\) | `raw$direction` | matrix-vector product; no `solve(V0)` and no `obj$he()` | finite, named by positional IDs; fixed for all nine trials |
| \(H_{FD}^{(s)}\) | `direction_check$finite_difference[[s]]$hessian_checked` | coordinatewise central Jacobian of the exact `obj$gr` with `h_j * c(0.5, 1, 2)` | finite, symmetric, PD, `kappa <= 1e8`; all evaluations and checked symmetrisation retained |
| \(d_{FD}^{(s)}=(H_{FD}^{(s)})^{-1}g_0\) | `direction_check$finite_difference[[s]]$direction` | independent validation solve only | every direction agrees with `V0 %*% g0` within 1%; all pairwise step sensitivities within 1% |
| \(\theta_\alpha=\theta_0-\alpha d\) | `trials[[k]]$parameter_vector` | `alpha_grid = 2^-(0:8)` exactly | all nine in order, bounds checked, no iterative direction update |
| \(f_\alpha,g_\alpha\) | trial `objective`, `gradient` | same `obj$fn`/`obj$gr` at candidate | finite; objective nonincrease and raw gradient `<= 1e-3` |
| \(V_\alpha\) | `trials[[k]]$curvature$cov.fixed` | `curvature_fn(theta_alpha, ids)` | candidate-specific aligned finite symmetric PD covariance, `kappa <= 1e8`; guard only |
| selected \(\alpha\) | `selected` positional index plus `selected_alpha` | first acceptable entry in frozen alpha order | selection requires every preceding trial to be fully adjudicated; later trials remain retained |
| terminal result | `status` plus `infrastructure`, `eligibility`, `trials` | five-class taxonomy above | curvature unavailable, curvature invalid, raw ineligibility, no accepted trial, and numerical admission never collapse into one label |

## Recommended private implementation interface

Revise the existing private helper rather than create a second estimator:

```r
.gllvmTMB_isdm_g3_full_vector_trials(
  obj, par, lower, upper, signature, raw_state,
  curvature_fn,
  alpha_grid = 2^-(0:8),
  raw_gradient_gate = 1e-3,
  health_gradient_gate = 1e-2,
  condition_limit = 1e8,
  direction_tolerance = 0.01
)
```

`curvature_fn` is the only new engine dependency. A small production adapter
owns candidate-specific `sdreport()` calls and emits the typed callback record;
the trial helper owns positional validation, direction checking, gates,
selection, and the all-attempt ledger. Pure-logic tests inject hand-built
callback records, while one compiled-unit test exercises the real adapter.
This separation is the simplest route that makes the former Hessian
availability stop testable without hiding TMB state inside the algebraic core.

Implementation and any fresh smoke remain separately gated. This contract
does not authorise edits to `R/fit-multi.R`, the runner, tests, result roots, or
shared/public documentation.
