# Phylogenetic temporal optimizer qualification

## Purpose

The retained phylogenetic temporal recovery campaign is an immutable failed engineering gate. Fir job `59096255` completed all 30 fits, but strict successes were 10/10, 9/10, and 8/10 for `phi = -.4`, `0`, and `.6`; three final outer gradients exceeded the frozen `1e-3` limit. This document specifies the diagnostic work required before any optimizer setting, parameter map, or likelihood implementation is changed.

The observed result does **not** establish a likelihood defect. Astra's independent review found that the R and C++ likelihood source used by the Fir runtime was byte-identical to the staged source and that the current two-pass acceptance rule can retain a code-zero BFGS endpoint without requiring a smaller outer gradient. The next work therefore qualifies optimizer evidence; it does not reinterpret the recovery campaign or relax its gate.

## Immutable baseline

The following remain fixed and retained:

- the 160-series phylogenetic recovery DGP, observations, seeds, parameter maps, thresholds, and two-pass BFGS settings;
- raw Fir receipts at `/private/tmp/temporal-phylo-fir-59096255/array-retry2-20260910` and the repository copy at `results/failed/phylo-recovery-160-fir-59096255-20260910/`;
- the terminal status and strict verdict of the three phi strata; and
- the canonical passing-receipt location, which must remain absent until a separate retained campaign actually passes its unchanged gate.

No recovery result is replaced, pooled, reseeded, or threshold-adjusted in this qualification work.

## Diagnostic contract

For each requested optimizer pass, retain an `optimizer_pass_history` row with a stable pass label and all of:

| Field | Requirement |
|---|---|
| `pass`, `pass_label` | Requested pass number and stable human-readable label. |
| `objective`, `convergence`, `accepted` | End-point objective, optimizer result, and explicit acceptance predicate. |
| `outer_gradient_max`, `outer_gradient_coordinate` | Maximum absolute outer gradient and its positional label. |
| `finite_difference_max`, `finite_difference_coordinate`, `finite_difference_error_max`, `finite_difference_error_coordinate` | Independent all-coordinate derivative-audit summary. |
| `fresh_state_ok` | A newly built outer objective agrees with the recorded endpoint. |
| `fn_evaluations`, `gr_evaluations`, `message`, `warnings`, `elapsed_seconds` | Optimizer diagnostics required to distinguish stopping from numerical failure. |
| `start`, `end`, `gradient`, `fresh_gradient` | Labelled, retained vectors in a reproducible machine-readable form. |

A fresh-state check means rebuilding `MakeADFun` from the original saved data, parameters, map, random-effect declaration, and DLL state. It must retain the same outer-coordinate order; agree in objective to `64 * .Machine$double.eps * max(1, abs(objective))`; and have finite coordinatewise gradients agreeing with the recorded gradient under a declared numerical tolerance. A second evaluation of the same closure does not satisfy this contract.

The implementation must also retain the conditional-mode/inner optimization status, Hessian availability and conditioning diagnostics, plus an independently recomputed endpoint objective. These are diagnostics, not new acceptance criteria. The inner Hessian must be the **conditional random-effect block** at the mode reached by the fresh `fn(theta)` call: retain `fresh$env$last.par`, verify its fixed coordinates equal `theta`, then call `spHess(last.par, random = TRUE)`. Calling `spHess()` with its defaults instead returns the full joint sparse Hessian; it cannot diagnose the Laplace inner mode. Retain the runtime TMB version, random-block dimension, finite/symmetry/positive-definiteness verdict, reciprocal condition estimate, and the maximum conditional score from the random block of the exact joint `ADGrad` evaluation. The direct small Gaussian fixture checks this matrix against its analytic conditional precision before a Newton candidate may rely on it. Any Newton candidate must make these inner checks explicit eligibility conditions; `fresh_state_ok` alone only establishes outer objective/gradient replay.

## Independent test fixture and oracle

The former CRAN-safe test file is retained at `dev/temporal-program/retained-source-pair-tests/test-temporal-phylo-optimizer-qualification.R`, with a direct 4-series × 4-occasion × 2-replicate × 3-trait Gaussian additive DGP. It uses fixed phylogenetic covariance, fixed effects `(.2, -.3, .1)`, temporal and phylogenetic trait-diagonal variation, and residual noise. It deliberately does not call the production temporal simulator or reuse the 160-series recovery DGP. It is developer history, not a package test or a supported workflow, because temporal--phylogenetic combinations are deferred.

At a fixed non-optimal outer vector, the test compares the TMB outer gradient with central finite differences of its own dense additive Gaussian negative log likelihood for every free outer coordinate. Expected positional labels include fixed effects, the temporal persistence transform, the three temporal diagonal coordinates, the three phylogenetic coordinates, and residual log-SD. The test records the maximum discrepancy and its coordinate. Actual coordinate ordering is read from the fitted objective and must be identical in the fresh-state rebuild.

The existing source-pair oracle in `test-temporal-program-phylo-replicated.R` remains unchanged as the covariance and temporal-correlation derivative check. It does not become evidence for all coordinates or recovery.

A developer control fixture records:

- a passing fixed-vector derivative table;
- a test-only altered derivative vector that fails and localizes the injected coordinate; and
- immutable provenance for the retained recovery strata: passing `phi = -.4`, failed `phi = 0` and `.6`, with the retained summary path and `TRUE/FALSE/FALSE` verdict.

Changing that retained summary path or verdict must make the validator fail. This control is provenance only and cannot replace recovery evidence.

## Continuation rule

Only after the diagnostic contract and independent tests pass may one continuation candidate be proposed. The candidate must be frozen before execution and compared with the unchanged two-pass settings on predeclared engineering fixtures: the three retained failing fits and deterministic passing controls drawn from each phi stratum. It may not select the best start, change the DGP, or exclude failures.

For every candidate comparison, require non-increasing objective, finite values, outer gradient at or below `1e-3`, stable all-coordinate derivative checks, and predeclared tolerances for fitted covariance, residual variation, correlation, and training predictions. A code-zero endpoint with a high gradient, a non-finite derivative, an objective increase, or a state-rebuild mismatch is rejected and must leave the original fitted state intact.

## Compute and evidence boundary

The instrumentation and small fixture run locally with one BLAS thread and at most four local cores. The qualification fixtures are timed before any remote replay. If a retained replay or recovery campaign is projected above 30 minutes, record the measured pre-run result and obtain a separate compute approval before submission. Totoro is suitable for rehearsal; Fir/DRAC is suitable for a retained array. No GitHub Actions run is evidence for this campaign.

This qualification does not admit a temporal-plus-phylogenetic recovery claim, alter the likelihood, or broaden any temporal-source combination. The existing temporal provider remains locally implemented and bounded by its passed gates only.

## Acceptance sequence

1. Add test-first failures for labelled histories, all-coordinate audit length and labels, fresh-state rebuild receipts, injected-coordinate localization, and immutable-control validation.
2. Add diagnostic instrumentation without changing the likelihood, parameterization, thresholds, or optimizer settings.
3. Run the small independent fixture and relevant existing temporal/phylogenetic tests.
4. Review diagnostics with Astra/Noether before selecting any continuation candidate.
5. Measure the replay fixture, then seek a distinct compute approval only if the retained run exceeds 30 minutes.
