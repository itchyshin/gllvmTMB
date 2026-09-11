# Temporal--phylogenetic damped-Newton qualification

## Purpose and boundary

The retained temporal--phylogenetic recovery campaign and its C3 third-BFGS
continuation remain failed and immutable. This document defines one distinct,
developer-only numerical candidate for the existing replicated Gaussian
`temporal_indep() + phylo_indep()` model. It changes neither the likelihood,
parameterisation, public grammar, DGP, seeds, original thresholds, nor any
retained campaign receipt.

It is a single damped Newton correction from each frozen two-pass BFGS
endpoint. It is not a retry route: there is no extra BFGS pass, jitter, ridge,
eigenvalue clipping, rescaling, automatic fallback, or repeated Newton
iteration. Any failure preserves the BFGS endpoint and rejects the entire
candidate.

## Frozen local set

The six inputs are exactly the C3 set, selected before the numerical result:

| role | phi | seed |
| --- | ---: | ---: |
| retained failure | 0 | 2609188 |
| retained failure | .6 | 2609183 |
| retained failure | .6 | 2609185 |
| positional control | -.4 | 2609181 |
| positional control | 0 | 2609181 |
| positional control | .6 | 2609181 |

Each run reproduces the frozen two-pass BFGS fit using `optim(BFGS)`,
`maxit = 3000`, and `reltol = 1e-14`, from the direct 160-series DGP. It then
creates an independent `MakeADFun` object for every diagnostic and candidate
evaluation.

## Start eligibility

Every baseline must have code-zero passes, finite values, the unchanged
complete all-coordinate derivative audit, fresh outer replay, and outer
gradient in `(1e-3, 1e-2]` for a retained failure or at most `1e-3` for a
positional control. The fresh inner calculation must have matching fixed
coordinates, a random-block Hessian of the declared dimension, finite
symmetric entries, a positive-definite Cholesky factor, and
`max(abs(score_random)) <= 1e-7`.

The random block is evaluated at `last.par` immediately after fresh
`fn(theta)` with `spHess(last.par, random = TRUE)`. Its exact score is the
random block of `ADGrad(last.par)`. The full joint Hessian is not admissible
evidence for this gate.

## Curvature and trial rules

Construct the outer Hessian from central differences of the exact outer
gradient, at the three fixed coordinate steps

\[
h_j \in \{.5, 1, 2\}\,\epsilon^{1/3}\max(1,|\theta_j|).
\]

Retain every perturbation, gradient, raw Hessian, symmetrized Hessian,
eigenvalue, condition estimate, direction, and linear-solve residual. Every
scale must be finite, have relative antisymmetry at most `1e-7`, and yield a
positive-definite symmetrized Hessian with condition number at most `1e8`.
The directions from the half, default, and double scales must agree to relative
error at most `1e-6`. Use **only** the default-scale Hessian and require its
linear-solve residual to be at most `1e-10 * max(1, max(abs(g)))` and its
descent check `g' p < 0`.

Evaluate `theta + alpha p` in this exact order:

\[
\alpha \in (1, 1/2, 1/4, \ldots, 1/256).
\]

Choose the first step that remains in bounds, has a fresh finite conditional
inner calculation, and passes the Armijo rule

\[
f(\theta+\alpha p) \le f(\theta) + 10^{-4}\alpha g^\top p,
\]

with normal floating-point tolerance. No later step can be selected after an
earlier passing step.

## Final acceptance and retained evidence

The selected point must have non-increasing fresh objective, full finite
derivative audit, fresh outer replay, random score at most `1e-7`, valid
conditional random-effect Hessian, outer gradient at most `1e-3`, and the C3
unchanged drift safeguards: absolute persistence change at most `1e-5`,
relative covariance/residual/prediction changes at most `1e-4`.

Retain all trial rows and rejection reasons. The local candidate passes only
if all six cells pass. A local pass still does not alter the failed Fir
campaign or claim recovery. A remote array requires a separate measured
compute estimate and authorization.

## Measured pre-run evidence

On 2026-09-10, the worst retained C3 cell (`phi = .6`, `seed = 2609185`) took
about two minutes locally with one BLAS thread. Its corrected inner Hessian
was positive-definite (condition `808.97`) with random score
`8.12e-14`. The three outer finite-difference Hessians were
positive-definite (condition about `578`) and their Newton directions agreed
to `2.10e-9`. The undamped trial reduced the outer gradient from
`1.10553166e-3` to `1.70188015e-9`. This supports the fixed local six-cell
qualification; it is not retained recovery evidence.

## Authorized Totoro qualification result (2026-09-11)

The unchanged six-cell qualification was run on Totoro with at most 150
workers, exact source commit `1dabd4a6c5f6df6751d37eb3a596008d430c5e6a`, and
the existing R 4.5.3 / TMB 1.9.21 environment. It retained all probe,
curvature, line-search, final and decision receipts at
`/home/snakagaw/gllvmtmb-temporal-newton-1dabd4a6c-results/`.

Two of six cells accepted: retained failure `(phi=.6, seed=2609185)` and
positional control `(phi=-.4, seed=2609181)`. The remaining retained failure
`(phi=.6, seed=2609183)` completed every post-baseline gate but remained
rejected by its frozen baseline gate. The remaining three cells rejected at
the recorded step/final/replay stages. Because the contract requires all six
cells to accept, the qualification fails. This result changes no source,
fixture, seed, threshold, branch, or status of the failed Fir recovery gate.
