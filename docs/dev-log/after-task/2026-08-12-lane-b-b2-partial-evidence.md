# After Task: Lane B B2 partial ordinary evidence

**Branch**: `codex/lane-b-mspl-reconcile-951`  
**Date**: 2026-08-12  
**Audience**: gllvmTMB maintainers and statistical-method developers.

## 1. Goal

Record the useful completed portion of the frozen ordinary B2 simulation after
the recovery pools reached terminal scheduler states. This is a closeout of the
partial-evidence phase, not the frozen B2 adjudication and not a release claim.

## 2. Evidence retained

The frozen ordinary table planned 2,880 shards (72,000 replicates). The
completed-shard extract contains 2,586 shards and 64,650 replicates (89.8%);
294 shards timed out. A separate permutation audit has 88 timed-out shards.
The missing ordinary work is concentrated in the hard `n_unit = 200`,
high-dimensional, mixed-extreme-prevalence cells. Five cells have no completed
shard: probit q2 `O059`; cloglog q1 `O083` and `O084`; and cloglog q2 `O091`
and `O092`. Four further cells have 5--80% completion. These omissions rule
out a design-wide average or cellwise B2 promotion verdict.

Each result below conditions on both ML and MSPL producing a usable primary fit
for the same completed replicate. Thus the loss and MSE comparisons describe
the paired usable subset; they do not substitute for a failure-inclusive,
frozen adjudication.

| Link | q | Paired usable fits | ML log loss | MSPL log loss | Difference (MSPL - ML) | ML beta MSE | MSPL beta MSE |
|---|---:|---:|---:|---:|---:|---:|---:|
| complementary log-log | 1 | 6,435 | 0.547 | 0.512 | -0.035 | 192.2 | 10.9 |
| complementary log-log | 2 | 5,475 | 0.577 | 0.530 | -0.047 | 192.4 | 10.0 |
| logit | 1 | 4,111 | 0.604 | 0.589 | -0.015 | 211.9 | 16.8 |
| logit | 2 | 3,114 | 0.627 | 0.600 | -0.027 | 250.8 | 21.5 |
| probit | 1 | 7,423 | 0.517 | 0.476 | -0.041 | 215.1 | 8.6 |
| probit | 2 | 6,573 | 0.536 | 0.475 | -0.061 | 212.2 | 13.1 |

Across the completed data, ML usable-fit rates range from about 28% to 69%
across link-by-q strata; the corresponding MSPL rates range from 84% to 100%.
Every represented link-by-q stratum favours MSPL on conditional log loss and
beta MSE.

## 3. Interpretation

The completed portion is informative: for the represented ordinary,
complete-Bernoulli conditions, LA-MSPL is substantially more likely than
unpenalised ML to supply a usable point fit and has better paired conditional
point-estimation diagnostics. This direction holds separately for logit,
probit, and complementary log-log at q = 1 and q = 2.

It does **not** show the full B2 effect in the missing hard cells; prove that
the frozen queue is complete; or establish calibrated standard errors,
profile intervals, confidence intervals, likelihood-ratio tests, AIC, or BIC.
The package's fail-closed MSPL inference fence remains correct.

## 4. Operational status

The observed recovery pools are terminal: Rorqual completed; Nibi recorded
2,678 completed tasks and 22 failures; and the four Trillium recovery jobs
timed out. Scheduler completion is not an authenticated scientific receipt.
No partial artifacts were assembled into the authoritative frozen B2 result,
and the protected original FIR jobs were not modified.

## 5. Checks run

- Read the completed-shard summary and cell-completion extract retained in the
  Lane B recovery workspace.
- Verified that the result table is link-specific and q-specific rather than
  pooled across logit, probit, and complementary log-log.
- Queried live Slurm terminal states for the Rorqual, Nibi, and Trillium
  recovery jobs on 2026-08-12.
- `git diff --check` is required before any later source or documentation
  update; no estimator, harness, or frozen campaign artifact was changed here.

## 6. Tests of the evidence

The summary intentionally retains the timeout denominator and explicitly
names zero-completion cells. The pairing restriction for loss and MSE prevents
an apparent improvement from being created by comparing different subsets of
replicates. It does not test the missing cells, so it cannot be converted into
a complete simulation test.

## 7. Capability status

**Partial internal evidence only.** The experimental estimator remains
point-estimation-only for its existing fenced surface. This report does not
change the validation-debt register, public documentation, or 0.7 integration
classification.

## 8. Consistency audit

The wording agrees with the existing Lane B after-task report:
finite softly penalised estimates and point-recovery diagnostics are distinct
from calibrated inference. Results are reported separately by link and latent
dimension, so no logit result is borrowed for probit or complementary log-log.

## 9. What did not go smoothly

The campaign runtime was highly heterogeneous. The selectively missing
high-dimensional mixed-extreme cells exhausted shard wall-time limits, while
most ordinary work completed. Multiple recovery pools also supplied scheduler
records but not a single authenticated, collision-free frozen overlay.

## 10. Known residuals

- The complete frozen B2 queue has not been authenticated or adjudicated.
- The five zero-completion cells and four partially completed cells remain
  unrepresented or underrepresented.
- The partial results do not support an MSPL standard-error or interval claim.
- Any future targeted retry needs a fresh queue-union calculation, a duration
  estimate, and explicit maintainer approval before submission.

## 11. Next decision

The maintainer has accepted the partial evidence as sufficient **for now**.
Keep the recovery artifacts intact but dormant. Resume only if a later decision
requires complete frozen-B2 adjudication; then authenticate all raw/receipt
pairs, compute the exact missing queue, and retry only those missing blocks.

