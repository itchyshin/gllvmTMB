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
