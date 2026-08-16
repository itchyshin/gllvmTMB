# G2o no-fit postmortem certificate

**Status:** diagnostic only. `G2N_LOCAL_PRERUN_HOLD`,
`G2K_CALIBRATION_HOLD`, and `G2C_SMOKE_ADMISSION_HOLD` remain in force.

## Evidence boundary

This certificate reads the completed G2n root
`g2n-local-prerun-20260812-0630` and the retained 150-attempt G2k gradient
bundle `g2k-gradient-diagnostic-20260812-007`. Its fresh G2o output is
`results/g2o-postmortem-20260812-002`. It runs no fit, optimizer, profile, or
simulation, and makes no model, DGP, parameter-map, source-gate, threshold, or
recovery-metric change.

## Symbolic-to-artifact alignment

The locked state and observations are

\[
\eta_{cs}=x_c^\top\beta_s+\lambda_s z_c+e_{cs},\quad
e_{cs}\sim N(0,\psi_s^2),\qquad
Y^G_{cs}\sim\operatorname{Poisson}\{a^G_c e^{\eta_{cs}+\delta_s+b_c\gamma_s}\},
\]
\[
Y^S_{csv}\sim\operatorname{Bernoulli}\{1-e^{-a^S_{cv}e^{\eta_{cs}}}\},
\qquad \Psi_{ss}=e^{2\theta_{\mathrm{diag},s}}.
\]

| Quantity | Retained field | G2o descriptive calculation | What it can establish |
| --- | --- | --- | --- |
| Fixed effects \((\alpha,\beta,\delta,\gamma)\) | first 24 `opt$par` values, `b_fix` | block gradient and covariance-scaled score \(Vg\), where \(V=\mathrm{cov.fixed}\) | local score scale, not a new candidate |
| Shared factor \(\Lambda\) | `theta_rr_B` | same block calculation | compare with `b_fix`; no loading repair |
| Unique variances \(\Psi\) | `theta_diag_B`, extracted Psi | truth--estimate table and retained profiles | calibration pattern, not causal mechanism |
| Curvature | `cov.fixed`, lower profile deltas | block \(\kappa(V)\), profile summary | local conditioning only |
| Source separation | G2n post-run addendum | GBIF finite bias, survey `NA` bias, rank/correlation/information gate | fixed DGP/source gate remained valid |

## Case-C `b_fix` residual

G2n's raw maximum is `b_fix`, position 2: the species-2 intercept, with
\(|g|=0.002726537\). The complete intercept block has
\(\|g\|_2=0.003747007\), and its *marginal six-coordinate* covariance
submatrix has \(\kappa=2.114\). The largest descriptive covariance-scaled
score \(Vg\) in that block is \(6.96\times10^{-6}\), or only
\(9.28\times10^{-5}\) local standard errors.  The other fixed-effect blocks
are similarly well conditioned (\(\kappa=1.19\)--\(2.51\)) and have maximum
local movements below \(1.01\times10^{-4}\) standard errors.

This excludes severe *within-block* covariance anisotropy in this retained
fit. It does **not** diagnose cross-block/full-Hessian geometry, establish
whether rescaling would help, or prove stationarity: the frozen absolute score
is still above \(10^{-3}\), and `Vg` is reported only as a local diagnostic—not
evaluated as an optimizer candidate. Thus it is insufficient to specify a safe
new Case-C estimator.

Across the completed 150/150 private FIR campaign summarized by G2k, 73 of 89
raw-gradient failures have `b_fix` as their maximum block (16 have
`theta_rr_B`). This is not a denominator drawn from the earlier incomplete
Totoro root. The recurrence makes this a real design issue, but does not
identify an admissible repair from the retained evidence.

## Diagonal-Psi miss

G2n's maximum Psi variance error is species 3:
\(\hat\psi_3^2=0.375640\) versus truth \(0.160000\), error \(0.215640\).
Species 1 and 4 are also overestimated; species 5 and 6 are underestimated.
This is a variance-partition error, not a shared-covariance error: the shared
covariance metric passes.

The lower profile pattern does not support a simple explanation by weak lower
curvature.  Species 3, the worst Psi error, has lower \(\Delta\ell=7.119\),
whereas species 2, 5, and 6 have weak lower deltas 0.440, 0.324, and 0.125.
In the available G2k attempts, Psi-failing fits have median four weak lower
profiles while Psi-passing fits have median five; the retained Spearman
association between maximum Psi error and the number of weak lower profiles is
\(-0.487\).  This is evidence against claiming that the observed Psi miss is
explained by that one lower-profile diagnostic.

It remains plausible that six species, rank one, and this amount of repeated
PA/GBIF information create finite-sample variance-partition calibration limits.
But G2o cannot distinguish that explanation from a structural limitation of
this fixed DGP/estimand: only a separately designed calibration experiment can
do so.  It is not evidence for a likelihood change, generic zero inflation, or
a spatial extension.

## Next-arc decision table

| Proposed next action | Decision | Reason |
| --- | --- | --- |
| Relax the raw gradient gate or count `Vg` as convergence | NO-GO | Changes the frozen numerical criterion; local movement is not a certificate. |
| Add a Case-C retry/Newton repair for `b_fix` | NO-GO | The residual is recurrent but no predeclared, identifiable estimator follows from it. |
| Change the ecological likelihood, add zero inflation, or introduce spatial effects | NO-GO | G2o has no evidence that any of these mechanisms causes either HOLD. |
| Claim Psi profile weakness explains the recovery miss | NO-GO | G2n and G2k retained patterns contradict that simple account. |
| Design a new, pre-registered Psi calibration/information experiment before fitting | GO, design only | Needed to distinguish finite-information calibration from a structural variance-partition limit. |
| Design a distinct Case-C estimator only after algebraic invariants and adversarial no-fit tests are specified | GO, design only | Required before another iJSDM fit; no existing candidate is admitted. |

The correct next task is therefore a fresh **design-only** estimator-and-Psi
calibration specification.  It must define what new information or estimator
would identify the diagnosis before any new fit is authorized.
