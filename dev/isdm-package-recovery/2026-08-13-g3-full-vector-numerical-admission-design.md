# G3 prospective full-vector numerical-admission design

**Status:** private no-fit implementation only. G3 is a new prospective
estimator candidate, not a repair, reclassification, or relaxation of the
historical Paper 1 Case-D or Paper 2 Case-C/Psi records.

## Candidate

For an ordinary selected outer solution \(\theta_0\), full outer gradient
\(g_0\), and aligned positive-definite fixed Hessian \(H_0\), G3 evaluates
only the deterministic bounded trial sequence

\[
\theta(\alpha)=\theta_0-\alpha H_0^{-1}g_0,
\qquad \alpha\in\{1,1/2,\ldots,1/256\}.
\]

It is a candidate of the same Laplace objective, not a convergence criterion:
acceptance still requires `max(abs(gradient)) <= 1e-3`. A small Newton step,
PD curvature, a profile shape, or a covariance-scaled diagnostic alone cannot
admit a result.

## Symbolic-to-implementation alignment

| Symbol/rule | G3 contract field | DGP | Later extractor | invariant |
| --- | --- | --- | --- | --- |
| \(\theta_0\) | named raw outer vector | unchanged historical comparator | raw vector | no new coordinate/map/transform |
| \(g_0\) | named raw gradient | unchanged | raw/candidate gradient | raw gate remains \(10^{-3}\) |
| \(H_0\) | symmetric PD fixed Hessian | unchanged | eigen/condition receipt | no covariance shortcut or reordering |
| \(\theta(\alpha)\) | `g3_newton_trial()` | no new draw | candidate vector | same objective, bounds and signatures |
| \(A_i^{G3}\) | `g3_accept()` | unchanged | all-attempt ledger | objective non-increase, PD Hessian, raw gate |
| \(\Psi_{ss}\) | `exp(2 * theta_diag_B_s)` | unchanged Paper 2 DGP | unchanged Psi metric | numerical admission never waives Psi recovery |

## Eligibility and rejection

G3 is eligible only for a finite, code-0 `nlminb` raw state in the strict
`(1e-3, 1e-2)` interval, with no boundary flag, one maximum, a unique named
outer vector, aligned finite symmetric PD Hessian, and condition number at most
`1e8`. The objective/gradient, maps, data, random effects, bounds, scale,
controls, starts, selection and source gate have distinct signatures and must
match before candidate acceptance.

Reject before objective evaluation for any non-PD/ill-conditioned or reordered
Hessian, tied maximum, boundary, non-finite state, candidate outside bounds, or
signature mismatch. Retain the raw state and exact rejection reason.

## Historical comparator fence

Paper 1 B2 remains `Case D`, `NO_CANDIDATE`, and
`PRIVATE_NUMERICAL_ADMISSION_HOLD`; its sole maximum is
`theta_rr_spde_slope`. Paper 2 S=6 remains Case C, `NO_CANDIDATE`, and
`PAPER2_PRIVATE_STOP_HOLD`; its diagonal-Psi variance error remains 0.2156398.
G3 is not run on either retained record and cannot change their labels.

## Smallest-smoke proposal — not approved

After G3's pure logic and compiled-unit layers have separately passed review,
one fresh immutable smoke per family would be proposed: Paper 1 `S=3,C=360,r=3`
and Paper 2 `S=6,C=360,r=3`. Provisional wall-clock estimates are 10--15 minutes
for Paper 1 and 15--25 minutes for Paper 2: both are deliberately conservative
relative to the retained 12.324-second and 448.155-second ordinary-fit receipts,
allowing the bounded candidate evaluations and validation receipts. The runner
must stop and re-report if that estimate is exceeded. If a fresh implementation
cannot support either estimate, it must conduct only a timing pre-run and return
for approval before a full smoke.

No recovery, field separation, Psi-information, empirical, scale, or public
claim follows from an accepted G3 numerical state.
