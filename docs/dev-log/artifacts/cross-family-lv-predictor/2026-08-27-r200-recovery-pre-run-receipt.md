# Cross-family LV predictor r200 recovery pre-run receipt

Date: 2026-08-27

## Aim and immutable cells

This is the smallest non-duplicative point-recovery campaign needed beyond the
already retained 3,800-attempt named rank-1 point campaign and 4,000-attempt
named `B_lv` Wald campaign. It contains exactly two cells and 200 immutable
attempts per cell:

| Cell | Rank | Units x repeats | Purpose |
|---|---:|---:|---|
| `continuous-unequal-scale-d2` | 2 | 240 x 4 | Recover `B_lv`, shared covariance/correlation, and deliberately unequal Gaussian raw-scale SD 0.25 versus lognormal log-scale SD 0.65, shared within family. |
| `five-family-d3` | 3 | 500 x 6 | Recover `B_lv` and shared covariance/correlation for Gaussian, binomial, Poisson, ordinal-probit, and multinomial responses in one predictor-informed fit. |

The plan has 400 total attempts. Seeds are fixed by
`CROSS_FAMILY_LV_SEED_BASE = 202608270`; attempts are never replaced. Started,
failed, converged, point-eligible, and unavailable attempts remain in the
denominator. Raw `alpha`, raw `Lambda`, signed axes, and individual scores are
not recovery targets.

## Frozen performance gates

These gates were specified before the measured pre-run, following the prior
Noether/Fisher ADEMP review:

- exact denominator: 200 planned and 200 attempted per cell;
- convergence rate at least 0.95;
- point availability at least 0.90;
- every `B_lv` target: absolute bias at most 0.10 and RMSE at most 0.20;
- every shared-covariance entry: absolute bias at most 0.15;
- every off-diagonal shared-correlation entry: absolute bias at most 0.10;
- Gaussian/lognormal `log(sigma)` targets in the continuous cell: absolute
  bias at most 0.10 and RMSE at most 0.20;
- maximum score identity error at most `1e-8`;
- a fit is point-eligible only with convergence code 0, finite objective and
  targets, maximum absolute gradient at most 0.01, and the score identity gate.

No correlation or new `B_lv` interval claim is proposed. Existing calibrated
Wald claims remain limited to their named rank-1 cells.

## Measured one-attempt pre-run

Command: local `NOT_CRAN=true` R process with the current package loaded from
source, running task 1 and task 2 from
`dev/cross-family-lv-predictor/recovery-campaign.R`. Retained records are under
`/private/tmp/gllvmtmb-cross-family-lv-recovery-prerun-v1/`.

| Cell | Runtime | Convergence | Max gradient | Score identity | Largest abs `B_lv` error | Largest abs correlation error | Scale log-errors |
|---|---:|---:|---:|---:|---:|---:|---|
| continuous unequal-scale d2 | 3.99 s | 0 | 0.005688 | 2.22e-16 | 0.1034 | 0.0621 | -0.00633, 0.01493 |
| five-family d3 | 79.20 s | 0 | 0.003625 | 4.44e-16 | 0.0638 | 0.0601 | not applicable |

Both attempts were point-eligible. The pre-run checks correctness rather than
only speed: the two continuous scale slots were finite and dispatched to their
matching families; every scientific target was finite; and the score identity
held numerically.

## Runtime projection and requested authority

Measured fit time is approximately
`200 * 3.99 + 200 * 79.20 = 16,638` worker-seconds. With 40 one-thread Totoro
workers the ideal fit time is 6.9 minutes. Allowing package startup, file I/O,
and load imbalance gives a conservative **10--20 minute wall-time projection**.

Requested launch: Totoro, 40 one-thread workers, 400 attempts, never GitHub
Actions, capped well below the 150-core ceiling. If the campaign exceeds 30
minutes, stop and re-report rather than silently extending it.

## Frozen source candidate

The source candidate was committed locally after the pre-run and focused
verification:

- commit: `1cb4d33a4080e251073bc864086651b535b2d028`;
- tree: `4cf7d95c1f0a2fe6d54b1488f9f0a8964a9f1553`;
- `recovery-campaign.R` SHA-256:
  `ac21ebe93c6b9ad5b1aea528345b002d2669ba2deaf9c8beab4a5a1ae7f73200`;
- `summarise-recovery.R` SHA-256:
  `1c266a8b2a503b4543fe3dc36255232f3985faf8f37610be3600dc55e6986c90`;
- `src/gllvmTMB.cpp` SHA-256:
  `ad020630271e452e7e6813d5312c6f1553808cf33171d828525607118c4d75f3`;
- `R/fit-multi.R` SHA-256:
  `f3af32440bf36d09c06e754cbfaa49a4ec5f5882319d342c8af4b8f2079aa178`;
- `R/lv-predictor.R` SHA-256:
  `1fbdbec253510087c78bb38a7cb75b6eef22e910c4d3a9c24942d8c60539ad52`.

Every retained r200 attempt must receive
`CROSS_FAMILY_LV_PINNED_SHA=1cb4d33a4080e251073bc864086651b535b2d028`
and refuses a different checkout before fitting.

## Launch disposition at bounded milestone landing

The retained r200 production campaign was **not launched** for this bounded
milestone. Its production denominator is therefore 400 planned, 0 started,
0 attempted, and 400 planned-not-started; the two measured pre-run attempts
above remain feasibility checks and are not counted as production attempts.
No remote compute was used.

The implementation may land on route-health and focused fit evidence, but
general rank-2/rank-3 recovery remains `partial`. None of the frozen recovery
gates above is marked met, and no public recovery or interval claim is earned
from this receipt. A future campaign must start from this exact source pin or
write a new pre-run receipt for a changed source candidate.
