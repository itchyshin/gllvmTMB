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
Rejected candidates retain the baseline and an explicit list of failed gates;
no fit state is overwritten.

## Local pre-run receipt

`phi = 0`, `seed = 2609188` completed locally from the exact current source in
about three minutes. The third pass was a near no-op: gradient
`1.367721e-4`, persistence change `3.27e-15`, covariance relative change
`2.93e-15`, residual relative change `7.91e-16`, and predictor relative change
`4.15e-15`. It passed the local comparison because the two-pass Mac endpoint
already passed the gradient gate. This does not predict or repair the retained
Fir gradient `1.614525e-3`.

## Retained local result

The complete frozen local set is retained in
`dev/temporal-program/results/continuation/phylo-third-pass-local-six-20260910/`.
All six receipts were run from `fd91016718109592224a98110750fe6d23ea317c` with
one BLAS thread. Five cells met C3's local predicates. The remaining retained
failure, `phi = .6`, `seed = 2609185`, had a final outer gradient of
`1.105532e-3`, exceeding the unchanged `1e-3` gate; every other same-solution
and fresh-state predicate passed. The full values and failed-gate label are in
`summary.csv`.

Therefore C3 is rejected. It does not justify a Fir submission, a fourth BFGS
pass, a changed stopping threshold, or any recovery claim. The original Fir
campaign remains the controlling failed phylogenetic receipt.

The original C3 receipts also recorded an `inner_hessian` diagnostic using
TMB's default `spHess()` call. That call is the full joint Hessian, rather
than the conditional random-effect block, so its reported condition values
cannot be used to qualify a later Newton step. This does not change C3's
rejection: its frozen failure was the independently recomputed outer gradient
`0.001105532 > 0.001`. Future candidates must use the corrected
`spHess(last.par, random = TRUE)` diagnostic and its independent analytic
precision test.

The first retained C3 receipt predated the `rejection_reasons` field. The raw
gates still identify `gradient` as its only failure, and the summary records
that diagnosis. The runner now writes `rejection_reasons` directly, with a
unit test, so a later candidate cannot omit it.
