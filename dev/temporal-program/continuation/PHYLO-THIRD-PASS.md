# Temporal--phylogenetic third-pass qualification

## Candidate C3

C3 compares an unchanged two-pass BFGS fit with exactly one third BFGS pass
from its second endpoint. It keeps the data-generating process, seed, model,
parameter map, random effects, optimizer method, `maxit = 3000`, and
`reltol = 1e-14` fixed. It adds no jitter, penalty, rescaling, seed selection,
or further restart.

The original Fir recovery receipt remains immutable and failed. C3 cannot turn
that receipt into recovery evidence. It is only a platform-specific numerical
qualification candidate.

## Frozen comparison set

The comparison has six attempts:

| role | phi | seed |
|---|---:|---:|
| retained failure | 0 | 2609188 |
| retained failure | .6 | 2609183 |
| retained failure | .6 | 2609185 |
| deterministic passing control | -.4 | 2609181 |
| deterministic passing control | 0 | 2609181 |
| deterministic passing control | .6 | 2609181 |

The controls are the first retained seed in each persistence stratum, selected
by position rather than objective or recovery quality.

## Acceptance

For every attempt, C3 must retain all three optimizer histories and accept only
when its first two candidate passes reproduce the baseline; the third endpoint
has convergence zero, a finite complete derivative audit, a fresh-state match,
and outer gradient at most `1e-3`; and its independently rebuilt objective is
no higher than the two-pass baseline plus `64 * eps * max(1, abs(objective))`.

As a same-solution safeguard, AR1 persistence may differ by at most `1e-5`,
each covariance component and residual variance by relative Frobenius error at
most `1e-4`, and training linear predictors by relative error at most `1e-4`.
Rejected candidates retain the baseline and rejection diagnostics; no fit state
is overwritten.

## Local pre-run receipt

`phi = 0`, `seed = 2609188` completed locally from the exact current source in
about three minutes. The third pass was a near no-op: gradient
`1.367721e-4`, persistence change `3.27e-15`, covariance relative change
`2.93e-15`, residual relative change `7.91e-16`, and predictor relative change
`4.15e-15`. It passed the local comparison because the two-pass Mac endpoint
already passed the gradient gate. This does not predict or repair the retained
Fir gradient `1.614525e-3`.

The complete local receipt is deliberately kept outside the repository at
`/private/tmp/temporal-phylo-third-pass-local-phi0-seed2609188.rds`; the
candidate runner refuses to overwrite a receipt.
