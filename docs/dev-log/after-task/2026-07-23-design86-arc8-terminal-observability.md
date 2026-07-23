# After Task: Design 86 Arc 8 — terminal historical observability

**Branch:** `codex/design86-arc2r-20260723`  
**Date:** 2026-07-23  
**Roles engaged:** Ada, Gauss/Noether, Rose, Ebbinghaus

## 1. Goal

Determine whether the immutable G2/EVA smoke chains retain enough shared, labelled numerical state to identify or exclude a historical failure mechanism.

## 2. Implemented

Added a private terminal observability memo, plan-versus-actual record, and handover. The result is `HISTORICAL_MECHANISM_UNOBSERVABLE`; the current Design-86/EVA admission path is retired.

## 3. Evidence contract

The chain audit rehashed two manifests, two results, and two receipts, then reconciled manifest/result/receipt links and identity fields. The numerical matrix required full labelled optimizer traces, coordinate/transform maps, historical derivative/curvature evidence, and retained realised inputs where needed to distinguish a mechanism. Those discriminators are not retained jointly across the two records.

## 3a. Decisions and Rejected Alternatives

**Decision:** `HISTORICAL_MECHANISM_UNOBSERVABLE`. **Rejected:** interpreting code zero as convergence; extrapolating controlled Arc 5--7 results to the historical smokes; calling absence of telemetry evidence of engine correctness; or treating unobservability as authority for a retry, V2, or Gate B.

## 4. Files Touched

- `docs/dev-log/forensic/2026-07-23-design86-arc8-historical-observability.md`
- `docs/dev-log/plan-actual/2026-07-23-design86-arc8-historical-observability.md`
- `docs/dev-log/handover/2026-07-23-codex-handover-design86-arc8-terminal.md`
- `docs/dev-log/check-log.md` and this report

No immutable smoke artifact, runner, `R/eva-proto.R`, package C++, public API, generated package surface, or validation-debt status changed.

## 5. Checks Run

- SHA-256 rehash of all six immutable manifest/result/receipt files: PASS.
- Manifest/result/receipt link and receipt-identity audit: PASS.
- `git diff --exit-code HEAD -- R/eva-proto.R src/gllvmTMB.cpp dev/design86-gate2-eva-runner.R dev/design86-gate2-laplace-runner.R`: PASS (empty).
- Forbidden-wording scan over all Arc 8 records: PASS.
- Gauss/Noether numerical review and Rose provenance/scope review: both support `HISTORICAL_MECHANISM_UNOBSERVABLE`.

No runner, input/DGP construction, compile, probe, smoke, campaign, Laplace, Totoro, DRAC, push, or PR was run.

## 6. Tests of the Tests

The hash checks establish byte identity and chain linkage only. The observability matrix tests whether each proposed historical claim has the required retained discriminator; it does not manufacture missing state or test the EVA objective.

## 7a. Issue Ledger

No issue was created. `gh pr list --state open --limit 20` returned no open items in this environment.

## 8. Consistency Audit

The Arc 8 records use `unobservable`, not `inconclusive`, to prevent an unsupported implication that a new run is authorized. They make no Gate-2, recovery, coverage, interval, engine-cause, remedy, or public-capability claim.

## 8a. Roadmap Tick

N/A — the private admission lane is retired, not promoted.

## 9. What Did Not Go Smoothly

The planned tiered Luna route remained unavailable because its dispatcher could not persist Codex state. Inline read-only mechanical verification replaced it and is recorded as routing drift.

## 10. Known Residuals

The historical cause remains unknown. This record does not rule out a future, independently approved research design with new evidence; it only closes the current admission path.

## 11. Team Learning

**Gauss/Noether:** a causal numerical claim needs shared labelled state and a discriminating signature, not merely repeated failed health checks.

**Rose:** valid provenance and absent observability are distinct findings; neither should be rewritten into a causal claim.

**Ada:** a terminal negative decision is evidence discipline, not an invitation to repair a historical record retrospectively.

## 12. Cross-Product Coverage

This arc covers only historical observability of two private smoke records. It does not cover Gate-2 admission, recovery, bias, coverage, intervals, likelihood correctness, optimizer/engine cause, remedy, public/package/API/C++ work, Gate-3/4, or any live compute.
