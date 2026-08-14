# LA-MSPL private uncertainty-method map

## Scope and invariant

This map covers only ordinary, complete, single-trial Bernoulli LA-MSPL fits
with `q = 1`, three resolved fixed effects, zero offsets, and logit, probit, or
standard cloglog links. The deterministic evidence uses four fixed regimes:
baseline, low prevalence, high prevalence, and strong latent signal.

Objective roles are deliberately different. Penalised profile traces and
bootstrap target estimates come from the active `fit$tmb_obj`
(`estimator_id = 1`). The paper-style Wald diagnostic evaluates the full
penalty-off approximate Laplace NLL Hessian (`estimator_id = 2`) only at the
penalised MSPL estimate. It never optimises that tape or relabels the estimate
as maximum likelihood.

## Route map

| Route | Private evidence | Current state | Claim boundary / blocker |
| --- | --- | --- | --- |
| Nuisance-reoptimised penalised profile | Four regimes x three links x three resolved `b_fix` targets | **36/36 finite-stable diagnostic endpoints** | Every centre matched and both sides had finite, converged threshold brackets refined to the fixed tolerance. These are penalised-objective threshold endpoints, not likelihood-profile confidence intervals. |
| Unconditional parametric percentile bootstrap | Exactly 1,000 attempted refits in each of 12 fixtures; 36,000 target rows | **36/36 finite-stable diagnostic endpoints** | All 12,000 refits were usable and all endpoint MCSEs were at most 0.080121 of interval width. This is endpoint-construction feasibility, not coverage or calibration evidence. |
| Paper-style likelihood curvature (Wald) | Penalty-off approximate Laplace Hessian at each of 12 penalised MSPL estimates | **21/36 finite target diagnostics; 15/36 typed blockers** | Seven fit-level Hessians were finite, full-rank, positive definite, and step-stable, supplying 21 target diagnostics. Five fit-level Hessians were non-PD, blocking all 15 targets in those fits. No pseudoinverse, clipping, nearest-PD repair, or penalised-Hessian substitution was used. Logit follows the construction studied by [Sterzinger and Kosmidis (2023)](https://doi.org/10.1007/s11222-023-10217-3); probit and cloglog are package extensions. |
| Godambe/sandwich | Active-objective/TMB decomposition audit | **Typed blocker: `score_decomposition_unavailable`** | The Laplace log determinant and global MSPL penalties prevent use of the reported joint NLL as additive active-objective site scores; no validated site-score decomposition is exposed. |
| Delete-one-site jackknife | Historical exploratory admission only | **WITHDRAWN — not paper-backed and no longer active** | Arc 3 removed the helper, tests, runner procedure, and campaign route. Historical reports remain only as visibly withdrawn provenance. |

## Objective and failure discipline

The profile reoptimises every nuisance coordinate on `fit$tmb_obj` after
fixing one resolved `b_fix` coordinate. The bootstrap simulates unconditional
q = 1 site effects and Bernoulli responses, refits the complete penalised MSPL
procedure, and extracts only estimator-ID-1 target estimates. The automatically
constructed penalty-off tape may perform its existing provenance check but
cannot supply bootstrap estimates.

The Wald diagnostic is the sole route that evaluates the penalty-off tape. It
does so for curvature only, at the penalised estimate, and returns typed
`likelihood_hessian_*` failures without numerical repair. The 21 successful
targets arise from seven fit-level Hessians; they are not 21 independent
Hessian successes.

## Campaign receipt

The fixed campaign source was
`5598f9e44d758f764a9239adb7e0066d5671538e`. Its final manifest SHA-256 was
`d9091022cb86b853672a93bc3960379096b464c0ef8e2717c7ffcf316c35c8e5`.
The raw archive, summary, failure table, and receipt SHA-256 values were,
respectively:

- `5070f86e9f17e43bc1e9fa5b68cee6f24ea1f8e0c072a18b9f41ef8b548cd357`;
- `fbca5b3ee66d6ab8c25cdd5ce766b46bf16afae46110220ba2699652cd7e9a1b`;
- `0b953a58a94937d8cb95cfce3bc4caf9e38c525c3982aa88ef11944679bdf17f`;
- `701e2e8206d5ab41ccff72ecae10ab680e6d635dfbe8f2c22b9f4df530306b6e`.

Durable artifacts are under
`/project/def-snakagaw/snakagaw/gllvmtmb-mspl-arc3-5598f9e4` on Rorqual.

## Public fence

The package's MSPL `vcov()`, `confint()`, `profile_targets()`,
`tmbprofile_wrapper()`, `bootstrap_Sigma()`, and standard-error paths remain
fail-closed. This map does not change `MSPL-04` from `blocked`, expose a
user-facing candidate, or claim calibrated standard errors, confidence
intervals, or coverage.

## Completion condition

The finite-feasibility milestone is complete for the selected deterministic
ordinary `q = 1` regimes: profile and bootstrap endpoints are available in all
36 cells, and the paper-style Wald route has an explicit success/blocker map.
Any repeated-sampling coverage study, public promotion, `q > 1` extension, or
structured/missing-data extension requires a separate arc and approval gate.
