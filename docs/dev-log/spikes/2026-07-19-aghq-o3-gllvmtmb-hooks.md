# O3 research spike — gllvmTMB scalar hook and bounded q = 2 reference

**Status:** local numerical reference passed; **not a package feature, not a
non-Gaussian REML implementation, and not a public capability claim.**

## Fixed-coordinate question

The preceding scalar reference established adaptive quadrature mechanics in a
standalone binomial random-intercept model.  This continuation asks a narrower
gllvmTMB question: with fitted \(b_{\rm fix}\) and lower-triangular
\(\Lambda_B\) held fixed, does the joint TMB Laplace objective equal the sum
of independently reconstructed unit-score Laplace factors?  If so, does a
tiny \(q=2\) adaptive grid have a stable node ladder and acceptable local
conditioning?

For each unit \(i\), the held-fixed conditional model is

\[
y_{it} \sim \operatorname{Binomial}\{n_{it},
 \operatorname{logit}^{-1}(x_{it}^T\beta + \lambda_t^T u_i)\},
\qquad u_i \sim N_q(0,I_q).
\]

This uses the existing ordinary `latent(..., unique = FALSE)` coordinate
system.  It does not profile \(\beta\) or \(\Lambda_B\), so it is neither an
AGHQ refit nor a Cox--Reid/non-Gaussian REML estimator.

## q = 1 result

`dev/aghq-o3-gllvmtmb-unit-hook.R` fits a deterministic two-trait, multi-trial
binomial `latent(..., d = 1, unique = FALSE)` fixture and extracts only
`b_fix`, `Lambda_B`, and the TMB data required for the unit factors.  The
one-node adaptive integral reproduces the joint TMB Laplace objective to
`1.4e-9`.  The AGHQ negative-objective ladder was:

| nodes | objective |
| ---: | ---: |
| 1 | 192.0855 |
| 5 | 192.0447 |
| 9 | 192.0446 |
| 15 | 192.0446 |
| 25 | 192.0446 |

The 15/25 difference is below `1e-4`.

## bounded q = 2 result

`dev/aghq-o3-q2-coupled-spike.R` uses the same fixed-coordinate protocol for
a two-score, two-trait fixture.  The adaptive transform is
\(u=m+\sqrt2R^{-1}x\), where \(R^TR\) is the conditional Hessian at the
mode.  The one-node product is the Laplace identity; the node ladder is:

| nodes per axis | objective | maximum conditional-Hessian condition number |
| ---: | ---: | ---: |
| 1 | 315.2202 | 1.7880 |
| 3 | 315.1960 | 1.7880 |
| 5 | 315.1959 | 1.7880 |
| 7 | 315.1959 | 1.7880 |
| 9 | 315.1959 | 1.7880 |

The joint-Laplace difference is `9.8e-8`; the 7/9 difference is below `1e-4`.
This proves numerical behaviour only for the fixed small fixture.

## Decision and hard stop

The O3 research spike has shown a coherent low-dimensional reference path for
q = 1 and q = 2.  It **stops at q = 2**.  A tensor grid grows as
\(n_q^q\); even the modest 9-node rule is 81 points per unit at q = 2 and 729
at q = 3, before mode/Hessian work.  No q >= 3 implementation, public knob,
coverage campaign, or AGHQ-versus-Laplace efficacy claim is justified here.

The next decision is methodological, not incremental coding: select a
scalable high-dimensional alternative (for example a structured Laplace or
variational route) only after a separate design/evidence plan.  Any later
non-Gaussian restricted-likelihood work must first state which fixed
coordinates are restricted and how loading/rotation terms are handled.
