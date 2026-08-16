# G2j retained diagonal-Psi diagnosis protocol

G2j is a read-only audit of the committed G2i seed-86122 pre-run root.  It
does not construct a TMB objective, re-optimise, profile, retry, simulate, or
change the fixture, estimator, threshold, or package.

For species \(s\), the fitted covariance is

\[
\Sigma_B=\Lambda\Lambda^\mathsf{T}+\Psi,
\qquad \Psi=\operatorname{diag}(\psi_1^2,\ldots,\psi_6^2),
\qquad \psi_s=\exp(\theta_{\mathrm{diag},s}).
\]

The audit must prove all three equalities separately:

\[
\widehat{\Psi}_{ss}^{\rm extract}=(\widehat{sd}_{B,s})^2
=\exp\{2\widehat\theta_{\mathrm{diag},s}\},
\qquad \widehat\Sigma^{\rm shared}_B=\widehat\Lambda\widehat\Lambda^\mathsf{T}.
\]

This distinguishes a variance-scale/extractor error from error in the
estimated covariance decomposition.  It then reads the retained six
five-offset profiles and the fixed-effect covariance from `sdreport`; it does
not treat a local Hessian as a global identifiability proof.

The only permissible diagnosis classes are:

| Evidence | G2j interpretation |
| --- | --- |
| Any equality fails | `EXTRACTION_OR_SCALE_MISMATCH` |
| Equalities hold, profiles/Hessian show weak or asymmetric component information, and the held metric remains | `COMPONENT_INFORMATION_LIMITED_NOT_EXTRACTION_MISMATCH` |
| Equalities and component diagnostics pass but the one-seed threshold alone fails | `ONE_SEED_CRITERION_UNRESOLVED` |

No class authorizes a retry.  A multi-seed campaign is admissible only as a
separate, frozen calibration study after this audit; it cannot turn a held
single result into a pass.
