# After Task: R Bridge Gate-ID Registry

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: Ada, Hopper, Boole, Fisher, Rose, Shannon, Grace

## 1. Goal

Make the Julia bridge's deliberate R-side admission refusals auditable. Each
primary user-facing stop should carry a stable `GJL-GATE-*` identifier, have a
registry row, and point back to the bridge drift issue instead of being only a
free-text message.

## 2. Implemented

- Added `.gllvm_julia_gate_registry()` with gate id, status, source, reason,
  representative test path, issue, and validation row columns.
- Added `.gllvm_julia_gate_message()` so intentional bridge refusal messages
  are prefixed with their gate id.
- Tagged the current primary R admission stops for unsupported families, CI
  rows, post-fit `newdata` / probability / ordinal / simulation refusals,
  missing CI payloads, structured terms, multiple reduced-rank blocks,
  two-column binomial responses, mask plus X rows, fixed-effect-X family gates,
  and non-canonical non-Gaussian X designs.
- Added tests that pin the registry schema, exact gate-id set, issue linkage,
  validation row linkage, and representative refusal messages.

This slice does not route a new family, likelihood, extractor, CI endpoint,
simulation path, structured term, or Julia engine feature.

## 3. Files Changed

- Bridge code: `R/julia-bridge.R`
- Tests: `tests/testthat/test-julia-bridge.R`
- Validation/status ledgers: `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/coordination-board.md`, `docs/dev-log/check-log.md`
- After-task report: this file

## 4. Checks Run

- Pre-edit coordination:
  `gh pr list --state open --json number,title,headRefName,author,updatedAt`
  -> one open draft PR, #489, on `codex/r-bridge-grouped-dispersion`.
- Recent hot-file scan:
  `git log --all --oneline --since="6 hours ago" --name-only -- R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task docs/dev-log/coordination-board.md`
  -> recent edits were from the current Codex bridge stack only.
- Formatting:
  `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task/2026-06-16-r-bridge-gate-id-registry.md docs/design/35-validation-debt-register.md`
  -> completed quietly.
- No-Julia R bridge test:
  `GLLVM_JL_PATH='' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed with `0` failures and `13` expected live-Julia skips.
- Live R-to-Julia bridge test:
  `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'`
  -> completed with `0` failures.
- Whitespace:
  `git diff --check`
  -> clean.

## 5. Tests of the Tests

The registry schema test would fail if a gate row lost its issue link,
validation row, representative test path, unique id, or `gated` status. The
refusal-message tests would fail if the current primary bridge gates drifted
back to anonymous text-only errors.

## 6. Consistency Audit

- `JUL-01` remains `partial`.
- All new gate ids point to `gllvmTMB#488`; no issue was closed from local
  evidence alone.
- Gate ids identify R-side admission stops, not malformed internal Julia payload
  validation errors. Payload contract errors remain ordinary errors because
  they diagnose broken bridge data rather than unsupported user capabilities.
- No public README, NEWS, vignette, pkgdown page, or generated Rd claim was
  promoted.

## 7. Roadmap Tick

This is evidence for the bridge gate-vs-engine hardening lane under `JUL-01`
and PR #489. It prepares the later drift guard but does not claim that every
future engine capability is auto-admitted by R.

## 7a. GitHub Issue Ledger

Update `gllvmTMB#488` after the commit is pushed and GitHub checks finish. If
the branch remains green, mention that primary R bridge admission stops now
carry `GJL-GATE-*` ids and have registry/test coverage.

## 8. What Did Not Go Smoothly

The source scan surfaced many internal payload validation errors that also
mention `engine = 'julia'`. Those are not all admission gates. The registry
therefore covers the primary R refusal surface in this slice, while payload
contract classification remains a later cleanup if Rose wants every internal
diagnostic grouped by class.

## 9. Team Learning

- Ada: Make refusal paths auditable before widening the bridge surface again.
- Hopper: Bridge gates need stable ids that users, tests, and issues can refer
  to across R and Julia changes.
- Boole: User-facing stop messages should name whether a row is unsupported,
  not yet routed, or rejected by the current bridge contract.
- Fisher: CI and simulation refusals are statistical status claims; keep them
  linked to validation rows.
- Rose: Anonymous "not routed yet" text is easy to forget; registry rows make
  drift visible.
- Shannon: A previous planning branch had a gate-registry commit, but this
  branch needed its own implementation evidence and after-task report.
- Grace: Targeted bridge suites are the right local gate; GitHub PR checks stay
  the platform gate.

## 10. Known Limitations And Next Actions

- Add a generated drift report later that compares `gllvm_julia_capabilities()`
  and `GLLVM.bridge_capabilities()` row-by-row.
- Classify internal payload validation errors separately if they need stable
  diagnostic ids.
- Keep `newdata`, unconditional simulation, ordinal residual/simulation,
  structured terms, mixed-family CIs, mixed-family masks/X, and richer
  interval-bearing extractors gated until each lane has implementation,
  tests, docs, and validation-row evidence.
