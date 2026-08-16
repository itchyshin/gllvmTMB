# G2j diagonal-Psi recovery certificate

## Frozen target and exact scale

The retained G2i target for the six species is

\[
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},\qquad
z_c\sim N(0,1),\quad e_{cs}\sim N(0,\psi_s^2),
\]

so that the between-cell ecological covariance is

\[
\Sigma_B=\Lambda\Lambda^\mathsf{T}+
\operatorname{diag}(\psi_1^2,\ldots,\psi_6^2).
\]

The G2i engine stores the six diagonal coordinates as
\(\theta_{\mathrm{diag},s}=\log\psi_s\), reports
`sd_B[s] = exp(theta_diag_B[s])`, and the recovery metric compares variances:

\[
\widehat\Psi_{ss}=(\widehat{sd}_{B,s})^2
=\exp(2\widehat\theta_{\mathrm{diag},s})
\quad\text{against}\quad \psi_s^2.
\]

The retained G2i audit proves, to `1e-12`, that the unique extractor equals
`report$sd_B^2`, and that this equals `exp(2 * theta_diag_B)`.  It separately
proves `extract_Sigma(part = "shared") = Lambda_B Lambda_B'`.  Therefore the
G2i hold is **not** a variance-versus-SD mistake, a shared-versus-total
extractor mistake, or a trait-order mismatch.

| Object | Symbol | Retained source |
| --- | --- | --- |
| Truth diagonal target | \(\psi_s^2\) | `truth$psi_variance` |
| Fitted log-SD | \(\widehat\theta_{\mathrm{diag},s}\) | outer fixed parameter |
| Reported SD | \(\widehat\psi_s\) | `fit$report$sd_B` |
| Recovered diagonal variance | \(\widehat\psi_s^2\) | `extract_Sigma(..., part = "unique")$s` |
| Shared covariance only | \(\widehat\Lambda\widehat\Lambda^\mathsf T\) | `extract_Sigma(..., part = "shared")$Sigma` |
| Full covariance | \(\widehat\Lambda\widehat\Lambda^\mathsf T+\widehat\Psi\) | reconstructed, not confused with the shared extractor |

## Retained evidence

The seed-86122 realised independent residual variances are close to their
generation parameters (maximum difference `0.0104`), so the problem is not an
unusually large realised \(e_{cs}\) draw.  The fitted diagonal variances are

| Species | Truth \(\psi_s^2\) | Fitted \(\widehat\psi_s^2\) | Error | \(\theta\) SE | lower-profile \(\Delta\)NLL at -1 |
| --- | ---: | ---: | ---: | ---: | ---: |
| sp1 | 0.1225 | 0.3020 | +0.1795 | 0.180 | 3.633 |
| sp2 | 0.0900 | 0.0891 | -0.0009 | 0.476 | 0.440 |
| sp3 | 0.1600 | 0.3756 | +0.2156 | 0.138 | 7.119 |
| sp4 | 0.1024 | 0.2489 | +0.1465 | 0.217 | 2.432 |
| sp5 | 0.1444 | 0.0810 | -0.0634 | 0.560 | 0.324 |
| sp6 | 0.1156 | 0.0417 | -0.0739 | 0.880 | 0.125 |

All six retained profiles are finite and converged, but the lower direction is
weak for sp2, sp5, and sp6.  This asymmetry is expected on the log-SD scale
near small diagonal variance; it is evidence against interpreting a finite
profile as evidence of precise recovery.  The fixed-effect covariance also
shows local loading--diagonal correlations up to `0.415`, consistent with
allocation between the rank-one shared component and the diagonal remainder.

The large sp3 error is not explained by a flat local profile: the true
variance `0.1600` lies below its local Wald interval (`0.2186` to `0.6454`).
Thus G2j cannot call the predeclared `0.20` criterion inappropriate merely
because one component failed.  Nor can one seed distinguish rare-sample error
from systematic finite-sample/Laplace component-allocation bias.

Numerical evidence is ancillary.  The fit reports a positive-definite Hessian,
scaled stationarity, and optimizer convergence; the retained maximum raw
gradient is `0.002726537` in a fixed-effect coordinate, not a diagonal-Psi
coordinate.  It blocks G2i admission under the frozen rule but does not supply
evidence for a diagonal-Psi parameterisation bug.

## Ranked conclusion

1. **Component-information limitation — supported.** One shared realised
   ecological factor must be split from six residual components.  Three lower
   profiles are weak and local loading--Psi correlations are material.
2. **One-seed calibration uncertainty — supported but unresolved.** The exact
   DGP draw is ordinary, yet one fit cannot measure the probability of an
   error exceeding `0.20` or separate stochastic failure from systematic bias.
3. **Numerical admission limitation — ancillary.** The raw-gradient rule is
   not met, but retained convergence/Hessian evidence does not attribute the
   Psi error to numerical nonstationarity.
4. **Extractor/variance-scale mismatch — rejected.** The exact transform and
   both covariance extractors agree.
5. **Threshold inappropriateness — not established.** The frozen threshold
   remains unchanged; changing it would require calibration evidence rather
   than this held replicate.

## Recommended next design

Do **not** alter the DGP, estimator, or threshold now.  The next justified
step is a calibration campaign on the exact frozen six-species fixture and
G2i estimator, reporting the diagonal-Psi criterion alongside all other
admission/recovery criteria on an all-attempt denominator.  Its purpose is to
measure frequency and diagnose the component-allocation pattern, not to turn
this seed into a pass.

G2j does NOT cover a changed number of species, spatial structure, detection
parameters, source additions, empirical data, public API/package work, or a
Paper 2 efficacy claim.
