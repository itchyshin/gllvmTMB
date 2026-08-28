# Independent method review — two-cell Julia bridge terminal record

**Reviewer:** Noether (Codex mathematical-consistency role)
**Date:** 2026-08-28
**Overall verdict:** **PASS** — the repaired process evidence warrants `NO_RUN_SOURCE_CONTRACT` before any fit. The four-record denominator, frozen thresholds, estimand design, and negative claim boundary are coherent. No statistical or cross-engine parity claim is earned.

## Findings

### P1 repair — PASS: the pre-fit terminal outcome is now independently supported

The retained process chain now supports the terminal decision for both tested Julia runtimes:

- `process/julia-1_12_6.receipt` and `process/julia-1_10_10.receipt` record UTC start/finish times, runtime/depot/project paths, direct and embedded commands, separate stdout/stderr paths, direct exit `0`, embedded exit `139`, and `fit_started=false`.
- Both direct stdout logs identify the expected Julia version and print `GLLVM.bridge_capabilities()` with Gaussian and Poisson admitted for no-X fitting.
- Both embedded commands invoke the exact R bridge qualification route, `qualify-two-cell-source.R`, through the pinned R library and GLLVM.jl project; both terminate with exit `139` before the qualification script can write eligible source evidence or start a fit.
- `bridge_gate_validate_process_receipts()` requires the two fixed receipt paths and versions, direct exit `0`, embedded exit `139`, `fit_started=false`, all four bound log files, and the expected version/Gaussian/Poisson content in direct stdout (`two-cell-gate-lib.R:137-189`).
- The terminal source validator now requires `capability_status = "eligible_static_runtime_embedding_failed"`, exactly two named exit-139 values, two named receipt hashes, and two named runtime Manifest hashes/files (`two-cell-gate-lib.R:191-268`).
- The source-artifact verifier recomputes both receipt SHA-256 values and both runtime Manifest SHA-256 values, in addition to validating their contents (`two-cell-gate-lib.R:477-499`). The fresh independent source check returned `G2_SOURCE_CONTRACT_OK`.

Because `gllvmTMB(engine = "julia")` necessarily needs the embedded JuliaCall route, direct Julia success does not qualify the R bridge. Once that required embedded route terminated twice before fitting, the global source prerequisite was red. Stopping rather than launching any of the four planned fits was methodologically correct and did not consume or replace a fit attempt.

### P2 — PASS: the four-record denominator is intact

The frozen plan names exactly `gaussian-tmb`, `gaussian-julia`, `poisson-tmb`, and `poisson-julia` (`two-cell-gate-lib.R:1-15`). `records.csv:2-5` retains all four in that order, marks every record planned, not started, and unavailable under `NO_RUN_SOURCE_CONTRACT`, and gives one common terminal reason. Each corresponding attempt RDS exists, has `started = FALSE`, `status = "unavailable"`, and `result = NULL`. No replacement record exists. Fresh denominator verification returned `G3_DENOMINATOR_OK`.

Marking the two TMB records unavailable is coherent: the approved question was paired engine parity, and the global embedded-bridge source prerequisite failed. Native-only fits would not answer that question.

### P2 — PASS: the planned estimands match the loadings-only model

The planned long-format model is explicitly

`value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE)`

(`two-cell-gate-lib.R:33-70`). Thus the unit-tier shared covariance is

`Sigma = Lambda Lambda^T`

with no `Psi` term. `Sigma`, its implied correlation matrix, fitted means, and maximized log likelihood are invariant to the rank-one sign transformation `(Lambda, u) -> (-Lambda, -u)`. The planned extractor requests the unit-tier total with `link_residual = "none"` and aligns fitted values by `(trait, unit)` keys (`run-two-cell-gate.R:45-92`; `two-cell-gate-lib.R:406-453`). The design therefore avoids interpreting raw loadings or scores.

The Gaussian fixture is a deterministic parity fixture, not a known latent-variable recovery DGP. That is appropriate because recovery was explicitly out of scope, but it cannot support a recovery claim.

### P2 — PASS: threshold and no-retuning integrity is preserved

The Gaussian and Poisson thresholds remain frozen in the specification (`two-cell-gate-lib.R:16-29`) and locked by tests (`test-julia-bridge-two-cell-gate.R:7-41`). The verdict records `thresholds_frozen = TRUE` and `replacement_attempts = 0`; all records show no fit started. There was therefore no metric on which to retune, and the terminal outcome did not depend on any numerical threshold. Fresh verdict verification returned `G4_VERDICT_OK`.

For a future executable gate, `fitted_mean_max_relative` still divides by the native fitted mean with only machine epsilon as a floor. This can be unstable for Gaussian fitted means near zero. It does not affect this terminal decision; any future plan should freeze an absolute-plus-relative scale before fitting rather than repair it after results are seen.

### P2 — Closeout action: reseal the top-level artifact manifest

The current `SHA256SUMS` predates the repaired process receipts/logs, the two version-specific Manifests, and the independent reviews. A fresh `manifest` verification therefore returned `SHA256SUMS verification failed`. This does not weaken G2, which independently binds and recomputes the receipt and runtime-Manifest hashes, but it remains a closeout gate.

After all three reviews are final, regenerate `SHA256SUMS` over every retained artifact and rerun G2–G5. Writing this review necessarily changes the artifact tree, so final sealing must occur after this file lands.

### P3 — The recorded direct-command label is descriptive, not literally replayable

The receipt's `direct_command` ends in `-e using_GLLVM_bridge_capabilities`, whereas the capture script actually executes `-e 'using GLLVM; println(...); println(... GLLVM.bridge_capabilities())'` (`capture-source-qualification.sh:27-32`). The executed expression is recoverable from the retained script and is corroborated by direct stdout, so this does not invalidate the terminal proof. A future receipt schema should record the literal shell-escaped expression to make the command field replayable without consulting the capture script.

### P2 — PASS: no statistical claim is earned or implied

No likelihood, covariance, correlation, fitted-mean, convergence, recovery, or performance comparison was produced. The retained evidence earns only this narrow operational result:

> On Totoro, for the pinned gllvmTMB and GLLVM.jl sources and the two retained Julia environments, direct GLLVM.jl qualification admitted Gaussian and Poisson, while the JuliaCall-embedded bridge process exited 139 before fitting; consequently none of the four planned parity fits started.

It does **not** show that GLLVM.jl itself failed, that either statistical engine is wrong, that Gaussian or Poisson parity passed or failed, or that `engine = "julia"` is unavailable on other hosts or environments.

## Checks run

- Pure-R two-cell gate test file: **PASS**.
- Source verifier: `G2_SOURCE_CONTRACT_OK`.
- Denominator verifier: `G3_DENOMINATOR_OK`.
- Verdict verifier: `G4_VERDICT_OK`.
- Manifest verifier: **FAIL pending final reseal**; see P2 closeout action.
- Direct inspection of both receipts, all stdout/stderr logs, both source-contract representations, all four terminal attempt RDS files, both runtime Manifests' bound hashes, and the capture/validation code.
- No fit, simulation, remote command, or GLLVM.jl modification was performed by this review.

## Final disposition

**PASS for method and terminal-proof acceptance.** The original P1 evidence defect is repaired. Final closeout remains conditional on regenerating the top-level checksum manifest after all reviews and obtaining a fresh G5 pass; that is an artifact-sealing action, not a reason to run any fit or widen the scientific claim.
