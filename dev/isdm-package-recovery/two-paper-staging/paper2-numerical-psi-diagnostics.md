# Paper 2 — numerical admission and diagonal-Psi recovery are different outcomes

## Status

Private design draft. Paper 2 remains nonspatial and synthetic. The retained
S=6 record is Case C with `NO_CANDIDATE` and a private STOP/HOLD; it is one
negative record, not a rate, a causal explanation, or a completed result paper.

## The scientific problem

A successful optimiser return is not enough to establish that a multivariate
integrated model is numerically admissible or that its diagonal residual
variance is recovered. The article therefore keeps two outcomes separate for
each attempt \(i\):

\[
A_i=\mathop{\mathrm{admitted}}_i,\qquad
P_i=I\left\{\max_s\left|\widehat\Psi_{i,ss}-\Psi_{i,ss}\right|\le0.20\right\}.
\]

Here \(A_i\) is the frozen joint numerical predicate, including its profile,
Hessian, boundary, and all-attempt rules. \(P_i\) is a diagonal-Psi variance
recovery criterion. Neither quantity explains, replaces, nor relaxes the other.

## Frozen estimator

The private estimator combines GBIF Poisson observations and three repeated PA
cloglog observations through a shared cell-by-species ecological state. Its
rank-one shared covariance is \(\Lambda\Lambda^\mathsf{T}\); diagonal residual
variance remains separate,

\[
\Psi_{ss}=\exp(2\theta_{\mathrm{diag},s}).
\]

The likelihood, DGP, transforms, maps, thresholds, three-start strategy, and
all-attempt denominator are frozen. In particular, a raw residual in
`b_fix` or `theta_rr_B` is not eligible for a boundary-only polish simply
because its gradient is numerically similar.

## Evidence sequence

1. A fresh, explicitly approved C2 no-fit packet must bind the immutable
   receipt, all-attempt table, profile-role memo, and provenance sidecar.
2. A future campaign, if separately approved, retains \(S=6,20,60\), 20
   independent replicates per cell, and every failure. Its primary display is
   the \(A_i\) by \(P_i\) four-cell table with count/20 and binomial MCSE.
3. The existing negative record cannot support a probability, a species-number
   gradient, recovery, or reader-facing conclusion. The protected holds remain
   historical evidence, not parameters to tune.

## Figure plan

P2-F1 is a model-and-gate schematic. P2-F2 may be laid out privately as a
single `n=1` audit card. Results figures—admission/Psi mosaics, error
distributions, and profile diagnostics—remain prohibited until a newly
approved all-attempt campaign earns a private GO.

## Intended contribution if the gates are passed

The paper would provide transparent all-attempt evidence about when a defined
estimator is admitted and when diagonal-Psi recovery meets its predeclared
criterion. It would not report spatial performance, empirical distributions,
occupancy or detection, absolute abundance, generic zero inflation,
arbitrary-source integration, or 10,000-species scalability.
