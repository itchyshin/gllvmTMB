# Plan versus actual — LA-MSPL interval-feasibility Arc 3

## Goal and claim boundary

Restore a private Wald/profile/bootstrap trio across the complete deterministic
ordinary `q = 1` matrix: four regimes x logit/probit/cloglog x three resolved
`b_fix` targets. Require finite stable penalised-profile and unconditional
parametric-bootstrap endpoints in all 36 cells, while attempting paper-style
Wald curvature everywhere and retaining typed non-PD blockers.

This arc evaluates endpoint construction only. It does **not** establish
calibrated standard errors, confidence intervals, nominal 95% coverage,
bootstrap coverage, or general all-data-regime inference. Public MSPL
inference remains fail-closed.

## Fixed private method contract

| Route | Objective | Fixed acceptance rule |
| --- | --- | --- |
| Profile | Active penalised `fit$tmb_obj`, `estimator_id = 1` | Fix one target, reoptimise all nuisance coordinates, retain the full finite-grid trace, stop at the first adjacent inside/outside threshold bracket, and refine for at most 12 bisections to width `<= 1.25e-4`. |
| Bootstrap | Complete penalised MSPL refit; estimates from `fit$tmb_obj`, `estimator_id = 1` | Attempt exactly 1,000 unconditional refits per fixture without replacement draws; require at least 950 usable refits, finite ordered type-7 percentile endpoints, and endpoint MCSEs no greater than 10% of interval width. |
| Wald | Penalty-off approximate Laplace NLL tape, `estimator_id = 2`, evaluated only at the penalised MSPL estimate | Invert only finite, full-rank, positive-definite, step-stable Hessians. Return typed `likelihood_hessian_*` blockers otherwise; do not optimise, repair, clip, or substitute another Hessian. |

The Wald construction follows the likelihood-curvature route studied for
logistic MSPL by [Sterzinger and Kosmidis
(2023)](https://doi.org/10.1007/s11222-023-10217-3). Probit and cloglog are
explicit package extensions. Jackknife was not proposed by that paper and is
withdrawn from active code and campaign planning.

## ADEMP-aligned campaign

- **Aim:** private endpoint-construction feasibility.
- **Data-generating mechanisms:** deterministic 24-site, three-trait,
  complete-Bernoulli `q = 1` baseline, low-prevalence, high-prevalence, and
  strong-signal regimes; each crossed with logit, probit, and cloglog.
- **Estimands:** the three resolved `b_fix` coordinates in each fitted object.
- **Methods:** paper-style likelihood curvature, nuisance-reoptimised penalised
  profile, and unconditional parametric percentile bootstrap.
- **Performance measures:** typed availability, finite/ordered endpoints,
  profile refinement, usable-refit fraction, endpoint MCSE, provenance, and
  runtime. Bias, RMSE, coverage, and power were deliberately not evaluated.

## Plan versus actual

| Slice | Planned | Actual |
| --- | --- | --- |
| Retire jackknife | Remove active helper/tests/runner route; retain visibly withdrawn history | Completed in `8dcef28a`. A final mechanical audit found one stale method map and one recovery checkpoint; both were corrected during closeout. |
| Repair profile | Bracket-first walk plus bounded refinement; 36/36 regression | Completed in `7bf697df`: 36/36 matched centres and finite, converged, refined two-sided brackets. |
| Implement Wald | Paper-style penalty-off curvature with typed map | Completed in `7bf697df`: 7/12 fit-level Hessians supplied 21/36 target diagnostics; 5/12 were `likelihood_hessian_non_pd`, blocking 15/36 targets. |
| Bootstrap runner | Fixed manifest, atomic shards, retained failures, type-7 endpoints and MCSE | Completed in `392ba7db`, `0608a1fb`, and `5598f9e4`. Statistical review caught that usable rows needed an explicit unconditional-redraw requirement; the runner and negative test were hardened before the campaign. |
| Three-cluster compute | Fir/Nibi/Rorqual; Narval failover | Infrastructure forced a narrower final route. Fir and Rorqual project-library extraction hit file-count quota, Nibi's existing socket stopped returning commands, and Narval rejected the Fir-built library with an illegal CPU instruction before any refit. A node-local exact-source Rorqual route passed setup and all-12-case smoke, then completed every fixed shard. Case IDs and seeds never changed. |
| Verification and closeout | Exact 36,000-row receipt, independent fence/statistical reviews, durable records | Completed. All active public fences passed mechanical review. The final statistical review is recorded in the Arc 3 after-task report. |

The first Arc 3 source commit was made at 06:37 MDT and the exact bootstrap
receipt was available at about 08:03 MDT, a commit-to-result window of about
86 minutes. That window excludes earlier planning and pre-commit inspection;
continuous total task time was not separately instrumented.

## Deterministic endpoint result

| Route | Fit-level result | Target-level result | Verdict |
| --- | ---: | ---: | --- |
| Penalised profile | 12/12 fixture fits admitted | 36/36 finite-stable | PASS for the selected fixture matrix |
| Parametric bootstrap | 12/12 fixtures had 1,000/1,000 usable refits | 36/36 finite-stable | PASS for the selected fixture matrix |
| Paper-style Wald | 7/12 positive-definite; 5/12 non-PD | 21/36 finite; 15/36 typed blockers | Honest mixed feasibility map |

The bootstrap endpoint widths ranged from `0.457752898` to `2.564778956`.
The largest endpoint-MCSE/width ratio was `0.080120592`, for strong-signal
probit `b_fix[3]`, below the fixed 0.10 rule. Every retained bootstrap row had
convergence code zero, `estimator_id = 1`, and unconditional redraw confirmed.

## Compute and provenance receipt

- Package source SHA: `5598f9e44d758f764a9239adb7e0066d5671538e`.
- Source archive SHA-256:
  `f5b30c1cfab75ffe7565d4cf7ae4d03f697993ca778100f7ef70dd99f7c8e2b9`.
- Offline dependency bundle SHA-256:
  `0d3cc88236dc2962ad3f89e67d168fb52dd47688d7c0b46abe226105717ff5e5`.
- Final manifest SHA-256:
  `d9091022cb86b853672a93bc3960379096b464c0ef8e2717c7ffcf316c35c8e5`.
- Raw archive SHA-256:
  `5070f86e9f17e43bc1e9fa5b68cee6f24ea1f8e0c072a18b9f41ef8b548cd357`.
- Summary SHA-256:
  `fbca5b3ee66d6ab8c25cdd5ce766b46bf16afae46110220ba2699652cd7e9a1b`.
- Failure-table SHA-256:
  `0b953a58a94937d8cb95cfce3bc4caf9e38c525c3982aa88ef11944679bdf17f`.
- Receipt SHA-256:
  `701e2e8206d5ab41ccff72ecae10ab680e6d635dfbe8f2c22b9f4df530306b6e`.
- Durable root:
  `/project/def-snakagaw/snakagaw/gllvmtmb-mspl-arc3-5598f9e4` on Rorqual.

Rorqual setup job `19016944` completed in 1:56. The all-case smoke job
`19017079` completed in 0:12. Statistical shards were 100 refits each and
completed in fixture-specific ten-task arrays after a measured 16--24 second
first wave; later regimes took longer but remained within the right-sized
five-minute task limit.

The completed statistical task IDs were `19017652_1`--`19017652_10`,
`19017739_11`--`19017739_20`, and the disjoint fixture arrays `19017794`,
`19017801`--`19017809` for indices 21--120. All 120 statistical tasks
completed and wrote one atomic shard each.

The first production array stopped before fitting because its Bash `read`
process substitution lacked a trailing newline. Diagnostic task `19017433_1`
proved the shell cause. The repair added the newline and reran the same missing
shard keys; no statistical draw was replaced. Scheduler failures remain in the
Rorqual logs.

## Verification receipt

```sh
Rscript --vanilla -e 'devtools::test(filter = "mspl", stop_on_failure = TRUE)'
# PASS: 1,239 expectations, 0 failures, 0 warnings, 1 pre-existing skip;
# 142.7 seconds.

Rscript --vanilla inst/sim/lane-b-uncertainty/run-mspl-interval-feasibility.R \
  summarise --root /private/tmp/gllvmtmb-mspl-arc3-5598f9e4-consolidated
# PASS: raw_rows 36,000; summary_rows 36; finite_stable 36;
# public_fence unchanged.

git diff --check
# PASS at closeout.
```

Static audit found no active `jackknife` route under `R/`, `tests/testthat/`,
or `inst/sim/`; no NAMESPACE change; private dot-prefixed helpers only; and
unchanged MSPL refusals in `vcov()`, `confint()`, `profile_targets()`,
`tmbprofile_wrapper()`, and `bootstrap_Sigma()`.

Deliberate non-runs: package-wide tests, `R CMD check`, pkgdown, CI, GitHub
Actions, public documentation, q = 2, structured effects, missing data,
repeated-sampling coverage, calibrated-SE assessment, and public method
activation.

## Closure

The selected deterministic ordinary `q = 1` fixtures are privately interval
feasible through nuisance-reoptimised penalised profiles and unconditional
parametric percentile bootstrap for logit, probit, and cloglog. Paper-style
Wald curvature is privately feasible in seven of 12 fixture fits and has five
explicit non-PD blockers. Public MSPL inference remains fail-closed, and no
calibrated confidence-interval claim is authorised.
