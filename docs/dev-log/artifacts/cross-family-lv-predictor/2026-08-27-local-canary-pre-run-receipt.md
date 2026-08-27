# Local five-family LV predictor canary: pre-run receipt

Date: 2026-08-27
Status: complete; three bounded fits ran, with one automatic-Psi result later
revoked as identifiability evidence
Driver: `dev/cross-family-lv-predictor/five-family-canary.R`

## Intended run

One complete-response route-health fit with 80 units, two replicates per unit,
five observed response families (Gaussian, binomial-logit, Poisson,
ordinal-probit, and multinomial), one numeric unit-level LV predictor, and rank
3. The first run uses `unique = FALSE`; default automatic Psi is a separate
second canary only after the first passes.

This is one fit, not a recovery, calibration, simulation, or benchmark
campaign. The simulator itself was checked without fitting:

```text
SIMULATOR_LOGIC_OK
```

## Estimate before fit

Projected local wall time: **1--10 minutes** for the first fit, including source
loading and extraction checks. The estimate is conservative relative to the
retained package history:

- `docs/dev-log/after-task/2026-05-17-m1-pr-b1-sigma-correlations.md` records
  approximately 9 seconds for the existing five-family fit rebuilds;
- `docs/dev-log/check-log.md` records a later eight-file mixed-LV focused replay
  at 29.13 seconds;
- the new canary is smaller than the public 500-unit by six-replicate teaching
  fixture and disables standard errors.

The projected upper bound is below the 30-minute local-action threshold.

## Correctness smoke

The run passes only if all of the following are true:

1. optimizer convergence code is zero;
2. `Sigma_shared` and `R_shared` are finite and correctly labelled;
3. `B_lv_unit` is finite;
4. total latent scores equal mean plus innovation to tolerance `1e-8`;
5. the nominal response is represented by its two baseline contrasts without
   malformed or duplicated expansion;
6. every failed attempt is retained rather than silently replaced by a new
   seed or altered fixture.

The first run is a route-health test only. It does not establish recovery,
coverage, arbitrary family composition, or interval calibration.

## Authorization and stop rule

The fit may start locally only after:

- exact-main run `33067429411` succeeds on merged PR #1216 SHA
  `870944744ff090fe8676e853ebc03957204571c0`;
- the five shared paths are explicitly released;
- this branch is rebased once onto that verified main;
- the production guard is changed by a failing-test-first patch and the
  focused construction test is green.

Stop and re-report if the fit exceeds 10 minutes or projects beyond 30 minutes.
Do not start a multi-seed or retained campaign from this receipt.

## Execution receipt

All prerequisites above were satisfied. The branch was rebased once onto
`870944744ff090fe8676e853ebc03957204571c0`; construction and scale tests were
GREEN before fitting.

| Cell | Wall time | Convergence | Max absolute gradient | Result |
|---|---:|---:|---:|---|
| rank 3, loadings-only | 8.58 s | 0 | 0.001523585 | all six checks passed |
| rank 2, loadings-only | part of 18.76 s pair | 0 | 0.0007440824 | all six checks passed |
| rank 3, automatic Psi | part of 18.76 s pair | 0 | 0.00006971072 | numerical checks passed, but the model is over-parameterised; preserved as a failed scientific attempt, not route evidence |

Every fit returned finite, labelled `Sigma_shared` and `R_shared`, finite
`B_lv_unit`, and the exact total = mean + innovation score identity. These are
route-health results only. They do not promote recovery or interval coverage.

## Superseding identifiability verdict

The automatic-Psi rank-3 fit above has 15 rotation-adjusted free loadings and
four engine-free diagonal parameters but only 15 covariance moments. Its small
gradient therefore does not prove an identified decomposition. The later
Noether/Fisher review revoked that row as evidence and added a fail-loud
parameter-dimension gate. The loadings-only rank-2/rank-3 fits remain valid
route-health evidence; an identified five-response rank-2 automatic-Psi
construction cell replaces the revoked claim.
