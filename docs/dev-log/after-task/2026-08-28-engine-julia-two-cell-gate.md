# After-task — exact two-cell `engine = "julia"` bridge gate

## 1. Goal

Test exactly four planned loadings-only fits on Totoro—Gaussian TMB, Gaussian Julia, Poisson TMB, and Poisson Julia—from frozen gllvmTMB and GLLVM.jl source pins, or retain a reproducible terminal receipt proving why fitting could not start. Preserve all four planned records, use no replacements or threshold retuning, stop at 30 minutes, and keep intervals, structured covariance, richer predictors, recovery, performance, API, CI, and public promotion out of scope.

## 2. Implemented

The lane froze gllvmTMB `86e95fff170767b23980152b7d6fce9bb2207718` and GLLVM.jl `00a2d7b7024b21f55cb124bee2d2e4cf8a546b40`, their trees, archive hashes, GLLVM.jl `Project.toml`, both runtime-generated Manifests, the installed gllvmTMB shared library, and the R session. A deterministic pure-R harness defines the exact four-attempt denominator, fixtures, invariant estimands, frozen thresholds, stop behavior, and evidence verifiers.

Totoro direct Julia processes loaded the exact GLLVM.jl source and advertised Gaussian and Poisson under Julia 1.12.6 and 1.10.10. The R 4.5.3 / JuliaCall 0.17.6 embedded route then exited 139 under both Julia versions during `gllvm_julia_setup()`, before any fit began. Atomic process receipts retain each exact command and environment, timestamps, stdout/stderr paths, direct exit `0`, bridge exit `139`, and `fit_started=false`. The source oracle verifies those receipts, their SHA-256 identities, and both runtime Manifests.

The terminal outcome is `NO_RUN_SOURCE_CONTRACT`: zero of four planned fits started, all four are retained as unavailable, and no replacement attempt was made. This is host/runtime evidence, not statistical parity evidence and not evidence that GLLVM.jl model code failed.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd, vignette, or pkgdown navigation changed. The frozen planned model was `value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE)`, so the intended shared covariance was `Sigma = Lambda Lambda^T` with no `Psi`. Had fitting started, only rotation-invariant `Sigma`, implied correlation, fitted means, and log likelihood would have been compared. None was estimated.

## 4. Files Touched

- `LOOP/GOAL.md`, `LOOP/arcs.md`, and `LOOP/checkpoint.md`: durable execution and recovery state.
- `dev/julia-bridge-gate/two-cell-gate-lib.R`: frozen design, denominator, target, process-receipt, manifest, review, closeout, and scope verifiers.
- `dev/julia-bridge-gate/run-two-cell-gate.R`: exact four-attempt executor, retained but not invoked.
- `dev/julia-bridge-gate/qualify-two-cell-source.R`: embedded runtime qualifier.
- `dev/julia-bridge-gate/capture-source-qualification.sh`: atomic direct-Julia and JuliaCall process receipt wrapper.
- `dev/julia-bridge-gate/write-terminal-source-receipt.R`: terminal receipt and all-attempt record writer.
- `dev/julia-bridge-gate/verify-two-cell-gate.R`: gate CLI.
- `tests/testthat/test-julia-bridge-two-cell-gate.R`: focused pure-R positive and negative controls.
- `docs/dev-log/artifacts/julia-bridge/two-cell-gate/attempts/*.rds`: four unavailable planned records.
- `docs/dev-log/artifacts/julia-bridge/two-cell-gate/process/*`: two command receipts and eight stdout/stderr logs.
- `docs/dev-log/artifacts/julia-bridge/two-cell-gate/GLLVM-Manifest.toml`, `GLLVM-Manifest-julia-1.12.6.toml`, and `GLLVM-Manifest-julia-1.10.10.toml`: retained runtime dependency resolutions.
- `docs/dev-log/artifacts/julia-bridge/two-cell-gate/R-sessionInfo.txt`, `records.csv`, `runtime-failures.txt`, `source-contract.rds`, `source-contract.txt`, `verdict.rds`, `verdict.txt`, and `SHA256SUMS`: environment, denominator, terminal decision, and checksum evidence.
- `docs/dev-log/artifacts/julia-bridge/two-cell-gate/reviews/method.md`, `scope.md`, and `provenance.md`: independent terminal reviews.
- `docs/dev-log/plan-actual/2026-08-28-engine-julia-two-cell-gate.md`: plan reconciliation.
- `docs/dev-log/check-log.md`: exact closeout commands and outcomes.

No README, NEWS, ROADMAP, design contract, vignette, roxygen, generated help, package source, or GLLVM.jl source file changed.

## 3a. Decisions and Rejected Alternatives

The source contract is terminal because the embedded route required by `engine = "julia"` failed before fit admission in two qualified Julia runtimes. Direct `using GLLVM` success does not substitute for embedded R-to-Julia qualification. Native-only TMB fits were not started because the approved estimand was paired engine parity. The four planned records remain the denominator; no replacement, optimizer change, threshold change, or workaround was admitted.

## 5. Checks Run

- Focused pure-R harness: `HARNESS_TESTS_PASS`; 15 tests and 75 expectations at terminal verification.
- Source oracle: `G2_SOURCE_CONTRACT_OK`; exact pins, hashes, runtime Manifests, direct capability logs, raw commands, stdout/stderr files, exit statuses, and pre-fit status verified.
- Denominator oracle: `G3_DENOMINATOR_OK`; exactly four planned records, zero started, four unavailable.
- Verdict oracle: `G4_VERDICT_OK`; terminal no-run, frozen thresholds, zero replacements.
- Manifest oracle: `G5_MANIFEST_OK`; every retained evidence member matched the standard two-space SHA-256 manifest.
- Independent review oracle: `G6_INDEPENDENT_REVIEWS_OK` after the first review correctly rejected self-asserted exit evidence and the lane added raw process receipts.
- Closeout and scope oracles: `G7_CLOSEOUT_OK` and `G8_SCOPE_BOUNDARY_OK`.
- `git diff --check`: pass.
- No fit, `devtools::check()`, pkgdown build, CI, push, PR, merge, release, or public issue mutation was run; none is needed for this internal terminal evidence lane.

## 6. Tests of the Tests

The harness rejects a changed source SHA, a terminal record that claims fitting started, absent or malformed process receipts, a direct-GLLVM nonzero status, a JuliaCall status other than 139, missing process logs, a missing denominator row, an added replacement row, retuned/unknown verdicts, malformed or altered SHA manifests, non-finite invariant targets, and timeout loss of unstarted planned records. The independent method and provenance reviews supplied the most important negative control: the original hard-coded exit-139 receipt failed review even though its structural oracle passed. The repaired oracle now reads and hashes raw per-process receipts and their referenced logs.

## 8. Consistency Audit

Exact scope scans:

```sh
rg -n 'engine = ["'"']julia["'"']|NO_RUN_SOURCE_CONTRACT|JuliaCall|GLLVM\.jl' LOOP dev/julia-bridge-gate tests/testthat/test-julia-bridge-two-cell-gate.R docs/dev-log/artifacts/julia-bridge/two-cell-gate docs/dev-log/after-task/2026-08-28-engine-julia-two-cell-gate.md docs/dev-log/plan-actual/2026-08-28-engine-julia-two-cell-gate.md
rg -n 'X_lv|offset|mask|missing|structured|Psi|interval|coverage|recovery|performance|public' LOOP dev/julia-bridge-gate tests/testthat/test-julia-bridge-two-cell-gate.R docs/dev-log/artifacts/julia-bridge/two-cell-gate docs/dev-log/after-task/2026-08-28-engine-julia-two-cell-gate.md docs/dev-log/plan-actual/2026-08-28-engine-julia-two-cell-gate.md
git diff --name-only origin/main
git diff --check
```

Verdict: the first scan found only the intended exact bridge gate and terminal boundary. The second found only explicit deferrals, negative controls, and claim restraints; it found no implementation of deferred work. The path and whitespace scans found only lane-owned files and no whitespace defects. Reader-facing stale-wording scans are not applicable because no reader-facing package surface changed.

## 11. Team Learning

**Ada:** kept the gate bounded to exact sources, two families, four planned records, and a pre-fit terminal alternative. The next plan should name raw process receipts as a source-gate deliverable from the outset.

**Curie:** the test-first denominator harness preserved all planned outcomes even when no fit could start. Future executable parity work should also replace the near-zero-sensitive fitted-mean relative metric before observing results, under a newly approved frozen plan.

**Noether:** rejected the first terminal bundle because it merely asserted exit 139. This forced the evidence chain to couple the verdict to exact commands, raw logs, process statuses, hashes, and both runtime Manifests.

**Grace:** verified immutable archives, trees, package binaries, runtime dependency resolutions, and receipt hashes. Host-specific Julia embedding failures must remain separate from model correctness and portability claims.

**Rose:** confirmed the all-attempt denominator and deferred-scope fences. Foreign metadata dirt in the separate GLLVM.jl checkout prevents a whole-checkout cleanliness claim; immutable archive pins are the load-bearing source provenance.

## 4a. Design-Doc Updates

None. This lane changed no package design, implementation, family, likelihood, formula grammar, or validation-register claim.

## 4b. pkgdown and Documentation Updates

None. No reader-facing documentation, generated help, vignette, NEWS, README, navigation, or site artifact changed.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row or public status changed.

## 7a. Issue Ledger

Inspected open issue [#488](https://github.com/itchyshin/gllvmTMB/issues/488), “Bridge-gate drift: R wrapper may reject engine=\"julia\" features GLLVM.jl already supports (audit).” The terminal runtime evidence is relevant context but does not resolve that broader capability-drift audit. No comment, closure, new issue, PR, or other external mutation was authorized or made.

## 9. What Did Not Go Smoothly

The first terminal receipt hard-coded the two exit values, retained an empty Julia 1.10 log, retained no Julia 1.12 raw log, and bound only one runtime Manifest. Independent review correctly failed it. A bounded qualification-only replay then captured exact commands, environments, separate logs, and atomic shell exit receipts for both Julia versions; no fit was started. The first local test command also used the non-exported `testthat::all_passed`; closeout uses `testthat:::all_passed` for the installed testthat version. Initial manifest and verifier invocations used the wrong working directory/path and were rerun from explicit roots.

## 10. Known Residuals

No statistical comparison exists: Gaussian and Poisson parity, convergence, covariance, correlation, fitted-mean, log-likelihood, recovery, interval, and performance claims are all unearned. The earned claim is only that, on this Totoro environment and these exact pins, direct GLLVM.jl qualification succeeded but JuliaCall embedding exited 139 before fitting under Julia 1.12.6 and 1.10.10.

The next work belongs in a fresh, separately owned GLLVM.jl/runtime lane: diagnose JuliaCall 0.17.6 plus RCall embedding with R 4.5.3 on Totoro, retain a core/backtrace and build/runtime logs, and identify a compatible runtime or an engine-side defect. GLLVM.jl model code should not change until the failure is localized. Any future four-fit parity gate needs new explicit approval and fresh exact pins; it must not replace these four terminal records.

## 12. Cross-Product Coverage

This gate covers only complete balanced Gaussian and Poisson, rank-1 ordinary unit-tier loadings-only formulas, the exact two frozen source pins, and source qualification on one Totoro R 4.5.3 host under Julia 1.12.6 and 1.10.10. Because no fit started, it does NOT cover statistical engine parity even in those two cells. It also does NOT cover X or X_lv, masks, missing responses, offsets, mixed families, structured covariance providers, Psi, intervals, recovery, calibration, performance, newdata, simulation, API behavior, CI platforms, other Julia/R/JuliaCall/RCall combinations, or any public capability claim.
