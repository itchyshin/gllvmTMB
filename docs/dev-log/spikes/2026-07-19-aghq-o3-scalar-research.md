# O3 research spike — scalar AGHQ and Cox--Reid reference

**Status:** local numerical reference passed; **not a package feature, not an
advertised capability, and not non-Gaussian REML support.**

## Question

Can a one-dimensional binomial-logit random-intercept likelihood be evaluated
by adaptive Gauss--Hermite quadrature (AGHQ), then supplied to a Cox--Reid
outer adjustment, with enough numerical checks to justify designing a later
gllvmTMB-specific hook?

## Fixed model and coordinates

For group \(i\), observations have

\[
y_{ij} \sim \operatorname{Bernoulli}\{\operatorname{logit}^{-1}(x_{ij}^T\beta + z_{ij}u_i)\},
\qquad u_i \sim N(0, \sigma^2).
\]

The spike estimates fixed coordinates \(\beta\) and \(\log \sigma\).  There
is no loading rotation, rank selection, or covariance-tier parameter in this
reference.  At each fixed \(\log \sigma\), the Cox--Reid calculation profiles
\(\beta\) and adds \(\tfrac12\log|I_{\beta\beta}|\), where
\(I_{\beta\beta}\) is the numerical Hessian of the AGHQ marginal negative
log likelihood in these same fixed \(\beta\) coordinates.

## What passed locally

`dev/aghq-o3-scalar-spike.R` implements Golub--Welsch Hermite nodes, a
per-group conditional mode and curvature, log-scale summation, adaptive
quadrature, and the Cox--Reid outer objective.  On its deterministic 28-group
fixture, the ML AGHQ estimate of the random-effect SD was:

| nodes | SD | negative log likelihood |
| ---: | ---: | ---: |
| 1 | 0.7302624 | 102.4129 |
| 5 | 0.7664248 | 102.2744 |
| 9 | 0.7665423 | 102.2743 |
| 15 | 0.7665425 | 102.2743 |
| 25 | 0.7665425 | 102.2743 |

The 15-versus-25-node SD difference is below `1e-4`.  The one-node estimate
matches `lme4::glmer(..., nAGQ = 1)` within `1e-3`; the 25-node estimate
matches `lme4::glmer(..., nAGQ = 25)` within `1e-3`.  The 25-node Cox--Reid
fit was finite and converged (`SD = 0.8368754`).  These are numerical
agreement checks on one fixed fixture, not recovery or calibration evidence.

## Hard boundaries

- This code is research-only under `dev/`; it changes no TMB template, R API,
  formula grammar, roxygen, validation-debt row, NEWS item, or pkgdown page.
- It does not establish a non-Gaussian REML likelihood for gllvmTMB, nor an
  AGHQ approximation for an arbitrary latent-vector block.
- It makes no finite-sample bias, coverage, likelihood-comparison, or release
  claim.  No Totoro/DRAC campaign is authorized by this receipt.

## Promotion gate and next action

The next bounded task is an explicitly fixed-coordinate **gllvmTMB scalar
unit-score hook**: reconstruct one fitted binomial `d = 1` unit contribution
and show agreement between its one-node/Laplace form and the current joint
Laplace fit where the comparison is mathematically valid.  Only then assess a
tiny, separately budgeted \(q=2\) coupled block.

Stop rather than widen if any of these occurs: failure of the 15/25 node
ladder, non-positive conditional curvature, loss of agreement with the
external scalar reference, coordinate ambiguity, or a coupled block whose
cost/conditioning prevents a clear comparison.  \(q \geq 3\) is outside this
O3 spike.
