# Paper 1 range--amplitude orthogonal-chart design

**Status:** design-only.  This is a fresh estimator candidate, not an
authorisation to construct TMB objects, claim a result root, run a smoke,
recover parameters, or make a paper/package claim.

## 1. Why a separate lane is necessary

The sealed G3 outcomes are final: Paper 1 is `G3_RAW_INELIGIBLE` and Paper 2
is `G3_CURVATURE_INVALID`.  The exact-gradient BFGS, marginal-scale BFGS,
and gauge trust-region roots are also consumed.  The last gauge trust-region
root is an unsealed post-claim infrastructure record; it contains no worker or
numerical evidence.  None of those roots may be repaired, resumed, relabelled,
or used to select controls for this design.

This lane therefore proposes a different coordinate chart and a distinct
estimator identity:

```
PAPER1_SPDE_SLOPE_RANGE_AMPLITUDE_ORTHOGONAL_V1
```

The sole scientific predecessor is the immutable MSPDE V3 packet at
`/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde/dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3`,
commit `a6255290810269510bba87951ea2dee365861e21`, with materialized-state MD5
`e3b17636c9f5fa0e9e555a307c923724`.  Any executable packet must reread the
full V3 receipt, marker, ledger, ordered manifest, empty claim directory, and
production terminal validator before it consumes a new root.

## 2. Unchanged model and estimand

The TMB objective, random-effect declaration, likelihood, data, mesh, map,
seed, bounds, source split, and raw parameter order remain unchanged.  In
particular the engine retains two SPDE latent-slope LHS columns
(`n_lhs_cols_spde_lat = 2`) and rank one (`d_spde_slope = 1`).  For the GBIF
slope column, the raw loading block is positions 20--22,
`theta_rr_spde_slope[20:22]`, and the reported covariance remains

\[
\Sigma_{\rm GBIF,slope}=\lambda\lambda^\top.
\]

No Jacobian term is added: this is a frequentist re-expression of the same
marginal Laplace objective, not a probability-density transformation.  Every
candidate is mapped back to the raw 22-vector before exact objective/gradient
replay, candidate-specific `sdreport`, covariance assessment, or any later
recovery calculation.

## 3. Orthogonal range--amplitude chart

The frozen V3 state has positive first GBIF loading, so use the same predeclared
positive sign representative; its full random-effect sign-orbit invariance
must be demonstrated live before this chart can be used.  Let

\[
q=\log\kappa_{\rm spde},\qquad
\lambda=e^\eta(1,a,b)^\top,
\]

where `eta` is the log loading amplitude and `a,b` are the two loading ratios.
Replace the raw coordinates \((q,\lambda_1,\lambda_2,\lambda_3)\) by
\((u,v,a,b)\):

\[
u=(q+\eta)/\sqrt2,\qquad v=(q-\eta)/\sqrt2,
\]

with inverse

\[
q=(u+v)/\sqrt2,\qquad \eta=(u-v)/\sqrt2,
\qquad \lambda=e^\eta(1,a,b)^\top.
\]

All other raw positions remain unchanged.  This fixed 45-degree rotation is
chosen before evaluating this estimator; it is not estimated, adapted, or
selected from G3/BFGS/gauge traces.  It separates the log-range and log-amplitude
axes algebraically while retaining their complete interaction in the objective.

The chart is a smooth bijection from \(\mathbb R^4\) to
\(\mathbb R\times\{\lambda:\lambda_1>0\}\).  Its inverse is

\[
\eta=\log\lambda_1,\quad a=\lambda_2/\lambda_1,\quad
b=\lambda_3/\lambda_1,\quad
u=(q+\eta)/\sqrt2,\quad v=(q-\eta)/\sqrt2.
\]

Inputs with nonfinite coordinates or \(\lambda_1\le0\) fail a typed domain
gate.  A later sign flip is never used to repair them.

## 4. Derivative contract

Write \(s=\exp\eta\), \(c=1/\sqrt2\).  The nonzero derivatives of the
raw block with respect to \((u,v,a,b)\) are

\[
\partial_u q=c,\quad \partial_v q=c,
\]

\[
\partial_u\lambda=c\lambda,\quad
\partial_v\lambda=-c\lambda,\quad
\partial_a\lambda=(0,s,0)^\top,\quad
\partial_b\lambda=(0,0,s)^\top.
\]

Thus, for the exact raw gradient \((g_q,g_{\lambda_1},g_{\lambda_2},
g_{\lambda_3})\),

\[
G_u=c\{g_q+\lambda^\top g_\lambda\},\quad
G_v=c\{g_q-\lambda^\top g_\lambda\},\quad
G_a=s g_{\lambda_2},\quad G_b=s g_{\lambda_3}.
\]

The full 22-by-22 transform Jacobian must retain raw rows and chart columns in
their exact positional order, be identity outside this four-coordinate block,
and pass an independent central-difference map-Jacobian test.  A separate
quadratic composed-objective harness must compare this analytic chain gradient
to central differences of \(F(\phi)=f(T(\phi))\) at the frozen point and two
predeclared interior points.  This prevents a jointly wrong map and Jacobian
from passing a tautological test.

At the nonstationary start, any later Hessian must be constructed by finite
differences of the transformed exact gradient (or retain every nonlinear map
term explicitly).  A raw covariance inverse or a congruence transform alone
is not a transformed Hessian.

## 5. Required no-fit gates before implementation of a numerical runner

1. Full raw state and objective/gradient replay from the sealed MSPDE V3
   packet, with exact DLL/source/callback identities.
2. `T(phi0)` matches raw `theta0` to `64*.Machine$double.eps`; mapped objective
   matches V3 objective to `1e-10`; raw gradient matches the locked vector to
   `1e-6`; analytic transformed gradient matches a 22-coordinate central
   objective-difference ledger to `1e-5` using
   `eps^(1/3) * max(1, abs(phi_j))`.
3. Full random-effect sign-orbit check: the signed conditional Hessian,
   predictor, and marginal objective all agree under the exact second-field
   sign operator.  This proves the positive representative is an equivalence
   class rather than a changed estimand.
4. Pure round-trip, determinant, order, domain, and covariance-preservation
   tests, plus a compiled random-effects fixture.  No optimizer is permitted
   in this phase.

## 6. Future numerical procedure and boundaries

Only after the gates above and independent Gauss/Noether plus Fisher/Rose
reviews may a separate execution design specify a single numerical procedure.
That design must freeze its Hessian construction, any shifted-system grid,
candidate ordering, raw-coordinate covariance gates, parent deadline, terminal
schemas, exact inventories, and one-attempt root.  It may not borrow trial
radii, shifts, finite-difference values, or candidate rankings from any
consumed lane.

Numerical admission, if ever earned, remains estimator-specific and precedes
any recovery calculation.  Paper 2 does not inherit Paper 1 admission; it
requires its own sealed attempt and recovery evidence.  A non-admission or
infrastructure terminal closes this estimator without a retune or in-place
retry; a further method would require another separately reviewed algorithm
design.
