# Structured spatial rho recovery and clean landing — acceptance ledger

Candidate source at approval: `61a0f0701e02c5c864057e0711523ba97b1d03d3`.
Approved by Shinichi on 2026-08-31 through the complete Ultra Plan reproduced in
`dev/structured-rho/spatial-recovery/PLAN.md`.

No tolerance, seed, source geometry, fit method, attempt ceiling, or verdict
rule may change after the retained pilot begins. Every executable receipt must
name its candidate bundle hash and frozen-fixture manifest hash.

| Gate | Requirement | Status | Evidence |
| --- | --- | --- | --- |
| G0 | Exact scientific, compute, and remote authority recorded | met | `PLAN.md` |
| G1 | Two regimes, formulas, sources, seeds, thresholds, and hashes frozen | met | manifest SHA-256 `692380327512a8ede39849eab813319469948d96c477f86b190e4f85d90181c3`; `frozen/` receipts |
| G2 | Simulator and covariance oracle do not call production attenuation helpers | met | Noether read-only source review of `freeze-*.R`, `study-metrics.R`, and `fit-study.R` |
| G3 | Eight toy attempts terminal; one optimizer each; complete finite records | met | bundle `30434660f3`; fixture `70b7a9ea57`; 8/8 returned, 6/8 strict successes, 2 boundary/non-PD failures retained; peak 279,504 KiB |
| G4 | First 32 retained attempts terminal; timing, memory, failures, and projection reported | met | `PILOT.md`; 32/32 returned, 31 strict; 16.71 s; peak 420,728 KiB; remainder projected below 20 min |
| G5 | Exactly 1,600 terminal retained attempts; no retries or replacements | met | `full-evidence/attempts.csv`; 1,600/1,600 terminal rows, 32 pilot plus 1,568 remainder rows |
| G6 | Joint rho/kappa and covariance summaries plus Fisher verdicts complete | met | `RESULTS.md`; Fisher/Rose reconciliation: 1,600/1,600 terminal rows, 1,494 strict successes, 14 partial cells, 2 blocked cells, and no passing estimated-rho cell |
| G7 | Clean landing branch descends from refreshed main and reconciles imported/excluded files | pending | landing manifest |
| G8 | Exact landing SHA passes source, test, documentation, render, Rd, and local package gates | pending | check receipts |
| G9 | Two Terra-high and one Sol-high reviewers report no unresolved finding | pending | review files |
| G10 | Draft PR plus fast three-OS and heavy Ubuntu receipts point to one SHA | pending | GitHub receipts |
| G11 | Validation register, check log, after-task, reconciliation, and handoff agree | pending | closure audit |
| G12 | No merge, tag, release, version bump, publication, hard deletion, or other-repo edit | in force | git and remote audit |

## Immutable numerical-success rule

One optimizer invocation; convergence code zero; positive-definite reported
Hessian; finite objective, parameters, covariance, and gradient; maximum
absolute outer gradient at most `0.01`.

## Immutable bounded-pass rule

For each estimated-rho regime/form/strength cell: numerical success at least
80%; `abs(rho bias) + 2 MCSE <= 0.10`; `rho RMSE + 2 MCSE <= 0.20`;
`abs(relative kappa bias) + 2 MCSE <= 0.20`; relative kappa RMSE plus two
MCSEs at most `0.35`; boundary-frequency upper 95% Wilson limit at most `0.20`;
and median total-covariance error no more than `0.10` above the paired
fixed-at-truth benchmark.

`partial` means interpretable results with at least one missed pass condition.
`blocked` means less than 60% numerical success, systematic boundary
concentration, or unstable rho/range separation. Fifty datasets do not support
interval calibration or a universal spatial-identification claim.

For mechanical classification, systematic boundary concentration means an
observed conditional boundary frequency of at least `0.50`. Unstable rho/range
separation means `abs(cor(rho error, log(kappa / kappa truth))) >= 0.80` among
successful estimated fits together with either rho RMSE above `0.20` or relative
kappa RMSE above `0.35`. These are blocking flags; Fisher still signs the final
named-cell verdict and may make a result more conservative, never less.
