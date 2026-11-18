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

## 7. Amendment after independent mathematical audit (2026-08-15)

Sections 1--6 above are retained unchanged as the original design record.  This
section is appended after the audit at
`2026-08-15-paper1-range-amplitude-orthogonal-map-audit.md`, which found six
items.  Where this section conflicts with an earlier section, this section
governs.

**7.1 Corrected evidence citation (audit F4).**  Section 2 cites the engine for
`n_lhs_cols_spde_lat = 2` and `d_spde_slope = 1`.  Both are `DATA_INTEGER`
inputs (`src/gllvmTMB.cpp:366`, validated as "must be 1 or 2" at
`src/gllvmTMB.cpp:1811-1812`), so the source establishes only that the engine
*supports* those values, never what the frozen Paper 1 model uses.  The binding
evidence is the sealed MSPDE V3 state.  The gate specified in Section 5 must
**re-assert the shape at runtime** from that state -- both integers, the
22-length raw vector, and the positional layout -- with a typed failure token,
rather than assuming it.

**7.2 Scoped limitation: one kappa, two loading columns (audit F1).**  The
engine declares a single `log_kappa_spde` (`src/gllvmTMB.cpp:748`) while the
SPDE latent-slope block carries two LHS columns, laid out consecutively with
`len_per_col = p * rank - rank * (rank - 1) / 2`
(`src/gllvmTMB.cpp:1830,1836-1837`).  Raw 17--19 is therefore the intercept
column and raw 20--22 the GBIF slope column.  Both columns' fields are governed
by the same kappa, so the kappa-versus-amplitude trade-off exists for both.
**This chart separates kappa from the slope amplitude only.**  The intercept
amplitude remains confounded with the same kappa and stays in the identity block
of the Jacobian.

Measured on the sealed V3 state during the audit, the untreated amplitude is the
**dominant** one: `||lambda_intercept|| = 33.522` against
`||lambda_slope|| = 0.10321`, a ratio of **324.79**.  The chart therefore treats
the numerically minor of the two kappa-amplitude confoundings.

This is a scoped limitation of the estimator, not a defect to be repaired in
this lane (maintainer decision, 2026-08-15).  Widening to a six-coordinate chart
would be a materially different estimator requiring its own identity, contract,
and review.  The later execution design required by Section 6 **may not assume
the range--amplitude ridge has been removed**; it has been removed for the
smaller of two amplitudes, and the larger is 325 times its size.

**7.3 The orthogonal factor is inert with respect to conditioning (audit F2).**
The map composes as a nonlinear amplitude/direction split of lambda after an
orthogonal linear factor.  The orthogonal factor is an orthogonal similarity on
the curvature, so it preserves eigenvalues and cannot change the condition
number.  Carrying out the congruence directly on `[[A,B],[B,C]]` gives a
transformed cross-term of exactly `(A - C)/2`, **independent of B**, so the
factor decorrelates the (log-range, log-amplitude) pair **if and only if
`A = C`**.  Nothing establishes that equality here.

Two consequences follow that a weaker `tan(2*theta) = 2B/(A-C)` argument hides.
Because the outcome does not depend on `B` at all, the transform **can create
correlation in an already-diagonal block** (`A=3, B=0, C=0.4` gives `0 -> 1.30`)
and **can amplify an existing cross-term without bound** (`A=10, B=0.1, C=0`
gives `0.1 -> 5.0`, a fiftyfold increase).  The correct statement is not that
the factor fails to remove the cross-term but that it **cannot control it**.
The inertness is moreover exact for the whole four-coordinate block: with
`T = E . blkdiag(R, I2)` and the second factor linear, the transformed curvature
is an orthogonal congruence with no second-order term.

Section 3's statement that the chart "separates the log-range and log-amplitude
axes algebraically" is accordingly true of the *coordinates* and not of the
*curvature*.  The chart's value can come only from the nonlinear split, or from
axis alignment exploited by a numerical procedure that is not affine-invariant.
**The execution design required by Section 6 must state which anisotropy it
exploits**; a procedure that is affine-invariant in exact arithmetic gains
nothing from the orthogonal factor.

The gate must **compute and report** the transformed curvature entries \(A\) and
\(C\) for the chart's (u,v) pair and the true diagonalising angle
\(\tfrac12\operatorname{atan2}(2B,\,A-C)\) at the frozen point, written into the
ledger.  This is a **reported diagnostic and explicitly not a pass/fail
criterion** (maintainer decision, 2026-08-15): no threshold on \(|A-C|\) has
evidence behind it, and inventing one now would close the lane on a criterion
manufactured after the design.  Its purpose is to inform the execution design.

Note also that "orthogonal" here denotes an orthogonal coordinate map, **not**
Cox--Reid parameter orthogonality (\(i_{\psi\lambda}=0\)), which this chart does
not deliver.

**7.4 Per-coordinate gradient tolerance (audit F3).**  Section 5 gate 2 requires
the transformed gradient to match a 22-coordinate central-difference ledger to
`1e-5`.  The supplied helper `rao_relative_error` divides the largest deviation
by the largest magnitude anywhere in the vector, so a single wrong coordinate
can hide behind a large one, and when all components are below 1 the denominator
pins to 1 and the tolerance is silently absolute.

That is the regime at the frozen point.  Measured on the sealed V3 state:
`max|g| = 2.8237e-4`, `min|g| = 1.5687e-6`, and **4 of the 22 coordinates
already have `|g| < 1e-5`** -- for those, the stated tolerance *exceeds the
quantity being tested*, so a 100% error is undetectable.  On the chart's own
log-range coordinate, `|g_16| = 8.86e-5`, an absolute `1e-5` admits an 11%
relative error.

**A per-coordinate *relative* tolerance does not fix this, and was tried.**  The
first attempt, `rao_coordinatewise_relative_error`, kept the floor at 1 and
therefore still judged absolutely every coordinate below unity -- which is every
coordinate here.  On the sealed state it passes a **100% error** on the smallest
gradient coordinate (returns `5.53e-6` against a `1e-5` gate).

**And a strictly relative `1e-5` is unreachable.**  With `|f| = 2549.04` the
best attainable central-difference accuracy is about
`(eps*|f|)^(2/3) = 6.84e-9` absolute, i.e. `2.42e-5` relative against
`max|g| = 2.82e-4` and `4.36e-3` against `min|g| = 1.57e-6`.  **All 22 of 22
coordinates fail a true `1e-5` relative gate.**  Section 5 gate 2 as literally
written is therefore unsatisfiable, and would only ever pass by virtue of the
floor.

Gate 2 accordingly requires a **mixed** criterion,
`|x_j - y_j| <= atol + rtol * |y_j|` for every `j`, with `y` the
finite-difference ledger, via `rao_coordinatewise_discrepancy(x, y, atol, rtol)`.
Both tolerances are **required arguments with no default**.  `atol` must be
justified against the *measured* central-difference noise floor of the objective
under test -- measured, for instance, by differencing at several step sizes and
observing where the estimate stops improving.  **The two numbers are
deliberately not fixed here**; the execution design fixes them after that
measurement.  `rao_relative_error` remains valid for scalar comparisons;
`rao_coordinatewise_relative_error` remains a diagnostic for the masking face
alone.  Neither may gate the ledger.

(Note for the record: the figure `0.002431251466981631` that appears in the G3
adjudication belongs to the consumed `G3_P1_S3_C360_R3_V3` root, not to the
MSPDE V3 predecessor this chart starts from.)

**7.4a Read the start state from the packet, never from a literal.**  The
contract's test fixture carries `theta[16] = 2.687653160`, but the sealed value
is `2.6876531596114015` -- a difference of `3.886e-10`, which is **27,345 times**
the `64*.Machine$double.eps` tolerance that Section 5 gate 2 itself imposes.
Positions 20--22 are bit-identical; position 16 is not.  Any gate that starts
from the fixture and asserts `T(phi0) = theta0` to `64*eps` will fail at
coordinate 16 for a reason that has nothing to do with the chart.  The gate must
read `theta0` from the sealed packet.

**7.4b Record the cancellation witness.**  At the frozen point `q = 2.687653`
and `eta = log(lambda_1) = -2.715757`, so `u = (q + eta)/sqrt(2)` is formed from
`q + eta = -0.02810406` -- a subtraction of near-equal magnitudes that destroys
about **two decimal digits** in the chart's own primary coordinate, worsening
without bound as kappa approaches the reciprocal of the amplitude.  The gate must
record `q + eta` alongside `lambda_1` as a conditioning witness.  This compounds
7.4: the coordinate least able to tolerate noise is the one the chart
manufactures by cancellation.

**7.4c The determinant is never checked.**  The contract validates only
`any(!is.finite(jacobian))`.  At `lambda_1 = 1e-160` and at denormal
`lambda_1`, every finiteness check passes while `det J_local` has underflowed to
exactly `-0`; at `lambda_1 = 1e160` it is `-Inf` with round-trip error `5.09e146`.
The chart is thus admitted at points where it is numerically non-invertible,
silently.  A determinant check belongs in the contract; its floor is left to the
execution design, since it depends on the conditioning the numerical procedure
requires.

**7.5 Predeclared reference coordinate (audit F5).**  Section 3 writes
`lambda = e^eta (1, a, b)`, which silently makes `lambda_1` the amplitude
reference while `lambda_2, lambda_3` become ratios.  **Index 1 is hereby
recorded as predeclared**, fixed before evaluating this estimator and not
selected from data; at the frozen point `lambda_1` is not the largest-magnitude
component, and a data-selected reference would forfeit the fixed-chart property
this design rests on.  Because \(\det J = -\lambda_1^{3}\), the chart degenerates
as `lambda_1` approaches zero, so the gate must **record `lambda_1` at the
frozen point** as a conditioning witness.

**7.6 The no-Jacobian argument needs a THIRD condition, and it is the untested
one.**  Section 2's argument has a pointwise half and an argmin half.  The
pointwise half holds unconditionally: the chart touches only fixed parameters
(verified -- `random = c("s_B", "g_spde_slope")`, and neither appears in
`parameter_order` or `map`), so the inner Laplace integral is untouched and
`f(T(phi))` is the identical number.

The argmin half needs more.  `T` is a bijection onto `R x {lambda_1 > 0}`, **not
onto R^4**.  If the raw optimum had `lambda_1 <= 0`, `T^{-1}(argmin f)` would be
undefined.  What makes the restriction without loss of generality is exactly the
**full random-effect sign-orbit property of Section 5 gate 3 -- which is
untested**.  Until it passes on the immutable V3 state, this chart is
established as an exact re-expression of the objective's *values* but **not of
its optimum**.  Gate 3 should therefore be sequenced **first** among the live
gates, not third.  Note also that the chart pushes the `lambda_1 = 0` boundary
to `eta -> -infinity`, so a raw path crossing it cannot be represented at all.

**7.7 Confirmed unchanged.**  The audit confirmed, and this amendment does not
alter: the derivative contract of Section 4, and bijectivity of the chart on its
stated domain (round-trip error `1.39e-17` at the frozen point;
`det J = -lambda_1^3` exactly, orientation-reversing, nonzero throughout the
domain).
