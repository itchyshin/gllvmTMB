# After Task: Design 86 Arc 2R — Gate-2 re-admission packet

**Branch**: `codex/design86-arc2r-20260723`  
**Date**: 2026-07-23  
**Roles (engaged)**: Ada, Gauss, Curie, Noether, Rose

## 1. Goal

Repair only the red Arc-2 Gate-2 prototype's private scope fence and audit
trail, then leave a maintainer-reviewable re-admission packet.  This arc does
not authorise or run a fresh smoke, a recovery campaign, Totoro/DRAC work,
Gate 3, Gate 4, a public API, or a shipped-engine change.

## 2. Implemented

`R/eva-proto.R` is exactly the sealed Arc-1 file again.  Gate-2 helpers are
private to the two permitted `dev/` runners; they verify the frozen fixture
and seed-array SHA-256 before constructing input, record whole-tree and
runtime provenance, and serialize unavailable numeric values as JSON `null`.
The new controlled-objective diagnostic traces all three frozen-style
`nlminb` stages and BFGS without reading Gate-2 inputs or writing campaign
artifacts.  `86-gate2r-readmission-brief.md` is a draft approval packet only.

**Mathematical contract**: no public R API, likelihood, formula grammar,
family, NAMESPACE, generated Rd, vignette, pkgdown navigation, frozen
optimiser, starts, health threshold, acceptance threshold, or DGP changed.
The private truth remains `Sigma_B = Lambda Lambda'` with `unique = FALSE`;
this arc does not make an inference claim about it.

## 4. Files Touched

- `R/eva-proto.R` — restored to its Arc-1 state; no Gate-2 support remains.
- `dev/design86-gate2-eva-runner.R` — private helper relocation, SHA receipts,
  JSON-null writer, and runtime/tree provenance.
- `dev/design86-gate2-laplace-runner.R` — runner-local DLL lookup and matching
  provenance receipt.
- `dev/design86-optimizer-diagnostic-harness.R` — controlled no-DGP stage
  trace.
- `tests/testthat/test-design86-gate2-input-contract.R` — frozen fixture,
  seed-receipt, JSON-null, and deterministic-input contract coverage.
- `tests/testthat/test-design86-optimizer-diagnostic-harness.R` — convergent
  and deliberately non-stationary trace coverage.
- `docs/design/86-gate2r-readmission-brief.md` — versioned draft packet.
- `docs/dev-log/check-log.md` and this report — closeout record.

No `NAMESPACE`, `DESCRIPTION`, `NEWS`, `man/`, vignette, `ROADMAP.md`,
validation-debt register, public R source, or `src/gllvmTMB.cpp` path changed.
No example-file cascade applies because no user-visible convention changed.

## 3a. Decisions and Rejected Alternatives

**Decision**: move Gate-2 helper code out of `R/` and into the existing private
EVA runner.  **Rationale**: the approved build brief limits executable Gate-2
support to `dev/`, and `R/` is installed package source even when unexported.
**Rejected**: amend the fence to permit package source.  **Confidence**: high.

**Decision**: add provenance and a controlled diagnostic without changing the
frozen optimiser or fixture.  **Rationale**: telemetry must be auditable before
any future amended smoke; it cannot retrospectively make the red smoke green.
**Rejected**: tune starts or thresholds now.  **Confidence**: high.

## 5. Checks Run

- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-design86-gate2-input-contract.R"); testthat::test_file("tests/testthat/test-design86-optimizer-diagnostic-harness.R")'` — PASS: 33 and 42 expectations, respectively; 0 failures, warnings, or skips.
- `Rscript --vanilla -e 'invisible(parse(...))'` for all three private scripts — PASS.
- `git diff --check` — PASS.
- `git diff --exit-code 3b479354 -- R/eva-proto.R` — PASS (empty).
- `git diff origin/main -- src/gllvmTMB.cpp` — PASS (empty).
- `! rg -n 'eva_gate2_input|expanded_data_generation_seeds|design86-gate2-anchor' dev/design86-optimizer-diagnostic-harness.R tests/testthat/test-design86-optimizer-diagnostic-harness.R` — PASS (no Gate-2 DGP, seed, or campaign-root dependency in the harness).
- `rg -n 'method\\s*=|@export' R/eva-proto.R dev/design86-gate2-eva-runner.R dev/design86-gate2-laplace-runner.R dev/design86-optimizer-diagnostic-harness.R` — only internal `optim(method = "BFGS")`; no public export or method surface.

No `devtools::test()`, `R CMD check`, `devtools::check()`, `pkgdown`, compile,
smoke, or DGP/recovery campaign was run.  The deterministic input-contract test
replays a supplied frozen seed in memory; it does not invoke a Gate-2 runner,
write a receipt, select/rank starts, or produce a smoke artifact.

## 6. Tests of the Tests

The fixture/seed checksum tests are boundary and negative tests: altered
content must fail before input construction.  The JSON-null test checks the
failure representation expected by a later scorer.  The input replay test is a
deterministic contract test.  The controlled objective tests combine all four
stages with both convergence and deliberately non-stationary behavior, so a
missing trace field or a false convergence interpretation fails visibly.

## 8. Consistency Audit

- `rg -n 'Design 86|EVA|extended variational' README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md docs/design/35-validation-debt-register.md _pkgdown.yml || true` — only design-private references; no user-facing EVA claim was added.
- `rg -n 'method\\s*=|@export' R/eva-proto.R dev/design86-gate2-eva-runner.R dev/design86-gate2-laplace-runner.R dev/design86-optimizer-diagnostic-harness.R || true` — no export or `method=` API addition; BFGS is an internal optimizer argument.
- `rg -n 'gllvmTMB\\(' R vignettes README.md NEWS.md docs/design || true` — status inventory inspected; no call site was changed by this private remediation.

Prose review (maintainer/statistical-method-developer reader): the new brief
leads with its non-authorisation boundary, names the immutable evidence and
checksums, and ends with the exact next decision.  No citation or user tutorial
is needed because it is a private design packet.

## 7a. Issue Ledger

No relevant open issue inspected or created.  `gh pr list --state open --limit
20` was attempted before editing the shared design/dev-log files but GitHub API
connectivity was unavailable; no issue/PR state was inferred from local git.

## 9. What Did Not Go Smoothly

The red Arc-2 smoke showed that data information was adequate but all starts
failed the frozen stationarity rule.  Arc 2 had also put private Gate-2 support
in installed `R/` source and serialized missing numbers unsafely.  Gate 2R
corrects those fences and records the optimiser trace needed for a future
review, but does not make the historical smoke admissible.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept the repair scoped to evidence and re-admission; a red smoke is not
permission to tune the estimator opportunistically.

**Gauss** isolated optimisation telemetry in a controlled objective so the
frozen Eva optimiser and historical DGP were not silently altered.

**Curie** added rejection tests for fixture drift, seed drift, and null
serialization alongside deterministic replay rather than relying on a happy
path.

**Noether** reviews the unchanged `Sigma_B = Lambda Lambda'` scope and whether
the amendment avoids turning the historical result into an unsupported
numerical claim.

**Rose** checks that the `R/` fence, public-path guards, prose boundary, and
handover all agree.  The first independent panel withheld the packet for a
wrong fixture path, an untested non-stationary claim, and absent runner-stage
receipt.  The repair corrected all three without changing optimiser controls;
the fresh remedial panel is the closeout decision: Noether/math-provenance,
Gauss/numerics, and Rose/scope each returned DONE for the packet only.  Their
common boundary is that this is not re-admission and conveys no smoke authority.

## 10. Known Residuals

The historical fixture and failed smoke are immutable.  Fresh smoke remains
**unauthorised**.  The next agent must obtain explicit maintainer approval of a
versioned Gate-2R amendment/fixture, including the stage-telemetry schema and
exact one-seed smoke authority, before invoking either private runner.  Totoro,
DRAC, Gate 3, Gate 4, public API, and shipped-engine work remain out of scope.

**Roadmap tick**: N/A — this is a private repair packet, not a roadmap-status
or capability change.

## 12. Cross-Product Coverage

This arc covers only private fixture provenance, receipt serialization, and
stage-trace diagnostics for the existing EVA Gate-2 runner. It does NOT cover
the DGP, estimator recovery, Laplace comparator execution, Schur intervals,
coverage/bias scoring, any response-family extension, public method surface,
`src/gllvmTMB.cpp`, Gate 3, Gate 4, Totoro, or DRAC.
