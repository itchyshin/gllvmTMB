# Design-103 private adjudication

**Status: TECHNICAL_PARTIAL — mechanism diagnosis closed without a recovery or
capability claim.**

## Scope and immutable inputs

Design-103 used only the frozen Design-102 q=2 Bernoulli-logit records under
`/project/def-snakagaw/snakagaw/design102-20260724/records/` and their frozen
fixture generator.  The four retained endpoints are QD, QF, JD, and JF.  The
estimand is rotation-invariant \(\Lambda\Lambda^T\); this private tier has no
diagonal Psi.  No package source, public documentation, EVA, VA, JJ, or GitHub
Actions workflow was changed or used.

## Calibration and retained terminals

| Job | Purpose | Terminal evidence |
| --- | --- | --- |
| 50783423 | GH101 four-method cell, 3 GB | OOM after 1:14; batch MaxRSS 3.14 GB |
| 50784354 | same, 8 GB | OOM after 1:11; batch MaxRSS 8.38 GB |
| 50789255 | same, 16 GB | TIMEOUT at 1:00:29; batch MaxRSS 11.75 GB |
| 50954328 | corrected pilot predecessor | cancelled before start; 0:00 |
| 50954566 | method-level pilot launch | immediate script-order failure; 0:03 |
| 50955251 | GH61 plus GH101 sentinel, 8 GB | OOM after 1:12; batch MaxRSS 8.38 GB |
| 50956936 | GH61 QF only, N=240 correlated | completed in 14:18; MaxRSS 4.35 GB |
| 50964478 | capped GH61 failure-pattern array | 3 completed method receipts; 3 in-flight tasks cancelled after 0:21; remaining tasks cancelled before dispatch |
| 50966355 | fixed-coordinate GH101 selection, two regimes | both completed in 1:46 and 1:49; batch MaxRSS 9.76 and 9.95 GB |

The valid GH61 pilot (`50956936`) was not healthy: it reached the 80-iteration
limit with maximum gradient 0.0469, beta RMSE 13.9, and relative covariance
error 3611.  The first three N=24 near-diagonal array receipts independently
showed the same endpoint pathology:

| Method | Optimizer code | max gradient | beta RMSE | relative covariance error |
| --- | ---: | ---: | ---: | ---: |
| QD | 1 | 9.21e-05 | 202 | 1.90e7 |
| QF | 0 | 1.39e-05 | 846 | 3.58e8 |
| JD | 1 | 1.94e-04 | 145 | 9.39e6 |

Thus a zero optimizer code was not accepted as a health certificate.  The
bounded common-refit endpoint is invalid, so no recovery comparison was made
from it.

## Fixed-coordinate GH101 selection diagnostic

Each GH101 task evaluated all three healthy Design-102 starts per method with
one common fixed-coordinate marginal objective, without optimization.  The
native and GH101 winners, together with the largest within-method GH101 gap,
were:

| Regime | Method | native winner | GH101 winner | GH101 gap |
| --- | --- | --- | --- | ---: |
| near_diag | QD | QD-B | QD-B | 3.37e-05 |
| near_diag | QF | QF-A | QF-C | 4.59e-06 |
| near_diag | JD | JD-A | JD-A | 2.95e-05 |
| near_diag | JF | JF-C | JF-A | 7.87e-05 |
| correlated | QD | QD-A | QD-B | 7.13e-06 |
| correlated | QF | QF-C | QF-A | 2.30e-05 |
| correlated | JD | JD-C | JD-B | 4.07e-05 |
| correlated | JF | JF-B | JF-C | 3.17e-05 |

The common-scale start gaps are all below 8e-05.  Consequently, start selection
is **not a material explanation in these two N=240 coordinates**.  This does
not establish a universal selection result beyond the frozen coordinates.

## Mechanism verdicts

| Candidate mechanism | Verdict | Evidence boundary |
| --- | --- | --- |
| Selection | **Not supported materially** at the two tested N=240 coordinates | Native/GH101 start disagreements are numerical near-ties (<8e-05). |
| Approximation | **Not adjudicable** | GH101 global refits were infeasible in the five-hour/resource envelope; the bounded GH61 refit endpoint was pathological. |
| Information | **Not adjudicable** | No healthy common-refit N ladder exists.  The N=24 failures do not isolate information from the unstable refit chart. |
| Chart/scale | **Not adjudicable** | Both regimes were scored for selection, but there is no healthy post-refit regime contrast. |

## Closure and next boundary

Design-103 establishes an execution fact, not a package fact: in this loading
chart, direct marginal-GH refitting is resource-infeasible at GH101 and yields
pathological bounded-GH61 terminals at the sampled coordinates.  A future
mechanism study requires a newly approved, symbolically reviewed alternative
parameterization or regularized reference objective with its own pilot and
health contract.  It must not relabel these results as support for an
approximation, information, chart/scale, or EVA claim.

Receipts are retained locally under
`/private/tmp/gllvmtmb-design103-results/records/` and remotely under
`/project/def-snakagaw/snakagaw/design103-20260724/records/`.
