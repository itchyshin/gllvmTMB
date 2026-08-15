# Paper 1 spatial-slope gauge-coordinate design

**Status:** design-only feasibility contract.  It authorises no fit, smoke,
recovery calculation, campaign, retry, source-likelihood edit, or public
claim.  It opens a new estimator-design lane only after the immutable MSPDE
state has passed the pure coordinate checks below.

## Why this is a new lane

The historical marginal-SPDE and BFGS roots remain immutable.  The MNCB and
BFGS continuations produced no provenance-admissible numerical result: their
terminalisation failures are infrastructure records, not evidence about the
ecological model or either numerical estimator.  They must not be repaired,
relabelled, resumed, or used to tune the next method.

The next candidate is not another finite-difference bracket or BFGS retry.
It changes the *fixed-coordinate chart* used for the GBIF spatial-slope
loading while preserving the same rank-one spatial covariance and the same
marginal TMB objective on its declared gauge domain.  The working estimator
name is

```
PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1
```

It is a new, separately named estimator.  No execution is authorised by this
document.

## Frozen predecessor and local target

The only permissible scientific predecessor is the sealed MSPDE V3 packet,
not a copied state file in isolation:

```
canonical root: /private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde/dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3
root: MSPDE_P1_S3_C360_R3_V3
commit: a6255290810269510bba87951ea2dee365861e21
all-attempt-ledger.rds: a9f19416c126a9f2054092835cdb8aaa
attempt-started.rds: 8b5421d35a4b50d46b690eee0c2b3cb2
file-manifest.csv: 32f93c4de1988dad08ac01f12e30a674
root-receipt.rds: 1940354271459b695e3ed2af70f1ca9c
session-info.rds: 817aea4f16c4ddc7d844bb7af342024e
time-estimate.md: e0a79bbfdb48668328d5f0224e6bd40f
v2-materialized-state.rds: e3b17636c9f5fa0e9e555a307c923724
```

Before any future preflight, its whole-root manifest, receipt, marker, ledger,
and production V3 terminal validator must all be re-read and pass.  Only then
may the materialized state supply the locked 22-coordinate order, objective
\(f_0=2549.0400257185738\), and exact outer gradient.  The relevant last six
coordinates are two rank-one, three-trait loading blocks:

\[
\lambda_{\mathrm{intercept}}=(21.61793515681646,-21.08106681592886,
14.56027253661505)^\top,
\]

\[
\lambda_{\mathrm{GBIF}}=(0.06615484034380216,-0.005920383591143399,
-0.07900112916196837)^\top.
\]

They are respectively positions 17--19 and 20--22 of
`theta_rr_spde_slope`.  The C++ engine uses rank \(d_{\rm spde,slope}=1\)
and two LHS columns.  Its second block is reported as
`Sigma_spde_slope_slope` and contributes through
`Lambda_spde_slope(t, 0, 1) * A_g_spde_slope(o, 0, 1)`.

The finite predecessor has \(\lambda_{\mathrm{GBIF},1}>0\) and
\(\lVert\lambda_{\mathrm{GBIF}}\rVert_2=0.1032118803803431\).  It is
therefore inside the open chart below; no boundary convention is being chosen
from an incomplete BFGS trace.

## Coordinate map and exact inverse

Leave the first 19 raw TMB coordinates unchanged.  Replace only the GBIF
block by \(\phi=(\eta,a,b)\in\mathbb R^3\):

\[
s(\phi)=\sqrt{1+a^2+b^2},\qquad
\lambda(\phi)=\frac{e^\eta}{s(\phi)}(1,a,b)^\top.
\]

This is a smooth bijection from \(\mathbb R^3\) to the open hemisphere
\(\{\lambda\in\mathbb R^3:\lambda_1>0\}\).  Its inverse is

\[
\eta=\log\lVert\lambda\rVert_2,\qquad
a=\lambda_2/\lambda_1,\qquad b=\lambda_3/\lambda_1.
\]

For the frozen start,

\[
\phi_0=(-2.270971312595905,-0.08949282562508763,
-1.1941851684835898)^\top,
\]

and forward--inverse reconstruction must have symmetric relative error

\[
\frac{\max_j|\operatorname{inverse}(\operatorname{map}(\phi))_j-\phi_j|}
{\max(1,\max_j|\phi_j|)}\le64\epsilon,
\]

with the same \(64\epsilon\) relative rule for
`map(inverse(lambda))` on the positive hemisphere.  The analytic Jacobian
must agree with a central finite-difference map Jacobian to relative
\(10^{-7}\) on the frozen point and predetermined nontrivial interior points.
Inputs with nonfinite coordinates, a nonpositive raw first loading, or a
nonfinite/nonpositive determinant are rejected; they are never repaired by a
sign flip selected after observing an objective.

The Jacobian used by the new estimator is retained explicitly:

\[
J(\phi)=\left[
\lambda,\quad
\frac{e^\eta}{s^3}(-a,1+b^2,-ab)^\top,\quad
\frac{e^\eta}{s^3}(-b,-ab,1+a^2)^\top
\right].
\]

Its determinant is \(e^{3\eta}/s^3>0\), so the chart itself introduces no
finite-coordinate singularity.  The raw surface \(\lambda_1=0\) is not in
the chart.  This is a deliberate local gauge domain, not a claim that the
chart covers every raw representation.

## Ecological-model equivalence on the gauge domain

For the GBIF slope column, the reported trait covariance is

\[
\Sigma_{\mathrm{GBIF,slope}}=\lambda\lambda^\top.
\]

Consequently the forward map preserves the covariance exactly:

\[
\Sigma(\phi)=\lambda(\phi)\lambda(\phi)^\top.
\]

The original rank-one spatial field is expected to have the simultaneous sign
symmetry \((\lambda,g)\mapsto(-\lambda,-g)\), but this is an executable
precondition, not an inference from the GMRF quadratic alone.  A future
no-fit gate must construct the full random-effect sign operator \(S\) that
negates **every** random-effect coordinate in the GBIF slope-field slice and
leaves all other random-effect blocks unchanged.  It must establish all of:

\[
S^\top Q S=Q,\qquad \operatorname{linpred}(\lambda,g)=\operatorname{linpred}(-\lambda,Sg),
\qquad f(\theta)=f(\theta_{\rm sign})
\]

to the retained objective replay tolerance, with unchanged maps, constraints,
data, random declaration, DLL, and positional order.  The last identity is a
live marginal-Laplace objective replay, not a symbolic assertion.  Only after
that gate passes may the positive-hemisphere choice be described as fixing one
representative of an existing sign orbit.  The covariance equality alone is
already exact, but full likelihood/estimand equivalence remains unclaimed
until this gate passes.  The starting state already lies in the positive
representative.  Any future implementation must stop with a typed
`GAUGE_DOMAIN_HOLD` if it cannot establish this nonzero, positive-hemisphere
start condition.

This is frequentist optimization of a re-expressed likelihood, not a change
of variables in a parameter prior.  **No Jacobian determinant is added to the
objective.**

## Objective and gradient alignment

Let \(T:\mathbb R^{22}\to\mathbb R^{22}\) replace the last three raw
coordinates by \(\lambda(\eta,a,b)\), leaving all other coordinates fixed.
The prospective estimator uses

\[
F(\varphi)=f(T(\varphi)),\qquad
G(\varphi)=\nabla F(\varphi)=D T(\varphi)^\top g(T(\varphi)).
\]

The full transform Jacobian is identity outside positions 20--22 and the
displayed \(J\) in that block.  `obj$fn` and `obj$gr` remain the original
TMB marginal Laplace callbacks; every raw gradient is still checked against
the immutable positional order before the chain rule is applied.  A candidate
is always projected back to the original raw coordinates before objective
replay, `sdreport`, covariance extraction, recovery, or any ecological claim.

The no-fit live frozen-state identity gate is conjunctive and uses no
optimizer.  With \(\epsilon=\texttt{.Machine\$double.eps}\), it must retain
the raw and transformed callback values and require:

\[
\frac{\lVert T(\varphi_0)-\theta_0\rVert_\infty}
{\max(1,\lVert\theta_0\rVert_\infty)}\le64\epsilon,
\qquad
\frac{|F(\varphi_0)-f_0|}{\max(1,|f_0|)}\le10^{-10},
\]

\[
\frac{\lVert g(T(\varphi_0))-g_0\rVert_\infty}
{\max(1,\lVert g(T(\varphi_0))\rVert_\infty,
\lVert g_0\rVert_\infty)}\le10^{-6}.
\]

For every transformed coordinate \(j\), the independently evaluated central
objective derivative uses the frozen step

\[
h_j=\epsilon^{1/3}\max(1,|\varphi_{0j}|),\qquad
G^{\rm FD}_j=\frac{F(\varphi_0+h_je_j)-F(\varphi_0-h_je_j)}{2h_j}.
\]

All calls must be finite and preserve the exact raw positional order.  The
analytic chain-rule gradient and this central difference must have symmetric
relative discrepancy at most \(10^{-5}\):

\[
\frac{\lVert G(\varphi_0)-G^{\rm FD}\rVert_\infty}
{\max(1,\lVert G(\varphi_0)\rVert_\infty,
\lVert G^{\rm FD}\rVert_\infty)}\le10^{-5}.
\]

No tolerance, step, coordinate, or source/DLL identity may be selected after
these results are observed.

| Mathematical object | Future implementation | Required pure validation | Retained evidence |
| --- | --- | --- | --- |
| \(\lambda\leftrightarrow(\eta,a,b)\) | pure R map, inverse, analytic \(J\) | round trip and finite positive determinant | map version and max error |
| \(\Sigma=\lambda\lambda^\top\) | raw C++ loading packet unchanged | entrywise equality before/after transform | covariance error |
| sign orbit | full random-effect sign operator | \(S^\top QS\), predictor, and live marginal replay | sign-map and replay records |
| \(G=D T^\top g\) | checked original `obj$gr` followed by chain rule | quadratic harness **and** no-fit live frozen-state replay | max relative errors |
| candidate curvature | candidate raw-coordinate `sdreport$cov.fixed` | original positional axes, finite/symmetric/PD/pdHess/condition gates | raw covariance and axes |
| ecological recovery | existing raw-coordinate extractor only | only after numerical admission | separate recovery ledger |

## Future estimator boundary

If the pure map and full sign-orbit checks pass, a later, separately reviewed
execution design may specify one full-22-dimensional trust-region/Newton
procedure in \(\varphi\)-coordinates.  It must predeclare its radius
schedule, acceptance rule, exact-gradient callback count, candidate selection,
hard time limit, terminal schemas, and a fresh source-gate root.

At the retained nonstationary state, its transformed Hessian must not be
approximated by the congruence term alone.  It must use either

\[
H_\varphi=D T^\top H_\theta D T+
\sum_{k=1}^{22}g_{\theta,k}\nabla_\varphi^2T_k
\]

with every term retained and validated, or a separately predeclared symmetric
finite-difference construction of the already transformed exact gradient
\(G\).  A raw-coordinate Hessian, covariance inverse, or MNCB
finite-difference trace cannot be relabelled as \(H_\varphi\).  The future
design must test the chosen construction on a quadratic map harness and at
the frozen live state before an attempt is authorised.
It must not use the incomplete MNCB finite-difference prefix or either BFGS
partial trace to choose any control.

The later procedure must additionally lock all of the following to the MSPDE
predecessor: fixture and seed; data/map/random declarations; TMB source and
DLL contents; the 22 raw coordinate IDs; the starting objective and gradient;
all numerical-admission thresholds; and the recovery truth.  Its receipt must
bind the complete predecessor packet above, current runner/contract/design
and map-helper hashes, the actual DLL path/content hash, and both the raw and
transformed candidate vectors, gradients, objectives, and covariance axes.
It must retain the complete transformed and raw candidate states.  Its
numerical admission must be estimator-specific and cannot upgrade, repair, or
reinterpret the historical MNCB/BFGS records.

No recovery, Paper 1 result, model-performance claim, or public statement is
allowed unless that later estimator seals a provenance-valid numerical
admission terminal first.
