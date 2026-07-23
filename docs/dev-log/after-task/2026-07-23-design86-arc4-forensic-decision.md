# After Task: Design 86 Arc 4 — post-smoke forensic decision packet

**Branch:** `codex/design86-arc2r-20260723`  
**Date:** 2026-07-23  
**Roles engaged:** Ada, Gauss, Rose, Melissa

## 1. Goal

Create a private, evidence-bounded decision packet explaining what the two immutable G2/EVA smoke records establish after their frozen-health failures, without changing the runner, protocol, engine, public package, or Gate-2 status.

## 2. Implemented

Added a forensic memo that compares the two artifact chains, records all eight final-start outcomes, distinguishes receipt validity from frozen-health failure, and presents neutral park/amend/defer decisions. It contains no numerical diagnosis or remedy.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, pkgdown navigation, runner, or shipped-engine change. The memo only
records the frozen health contract already present in the immutable evidence.

## 4. Files Touched

- `docs/dev-log/forensic/2026-07-23-design86-arc4-forensic-decision.md`
- `docs/dev-log/plan-actual/2026-07-23-design86-arc4-forensic.md`
- `docs/dev-log/check-log.md`
- this report

No README, NEWS, ROADMAP, validation-debt register, R source, C++ source, tests, examples, vignette, roxygen, generated Rd, pkgdown, or runner changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** retain a neutral decision packet. **Rationale:** the two records support comparable frozen-contract failures but not a causal diagnosis. **Rejected:** treating code-zero exits as healthy, identifying an optimizer cause, recommending a numerical fix, or turning two smokes into a Gate-2 denominator verdict. **Confidence:** high for artifact facts; deliberately no inference beyond them.

## 5. Checks Run

- `git status --short --branch`, `git log --all --oneline --since='6 hours ago'`, and `gh pr list --state open --limit 20`: local lane check passed; GitHub API was unreachable, so remote PR state was not inferred.
- `jq -e ...` against each smoke result: PASS for denominator, no healthy starts, gradients above `1e-4`, and collapse semantics.
- `shasum -a 256` for both manifests and results: PASS; computed values match the memo's cited links.
- `git diff --check`: PASS.
- `rg -n -i 'gate[- ]?2 (pass|admission)|recovery|bias|coverage|laplace comparison|optimizer cause|numerical fix|public capability|successful convergence' docs/dev-log/forensic/2026-07-23-design86-arc4-forensic-decision.md`: initial hit was an explicit negation; final Rose review confirmed wording is bounded.
- Gauss final review: PASS. Rose final review: two precision corrections applied, then PASS.

No runner, input construction, compilation, simulation, package test, package check, pkgdown build, Totoro, or DRAC job was run; those actions were outside the approved arc.

## 6. Tests of the Tests

No code or tests changed. The `jq` assertions directly inspect the immutable failure boundary: four unhealthy starts, no accepted winner, and collapse for each record. They are evidence checks, not a new test suite.

## 8. Consistency Audit

- `rg -n -i 'gate[- ]?2 (pass|admission)|recovery|bias|coverage|laplace comparison|optimizer cause|numerical fix|public capability|successful convergence' docs/dev-log/forensic/2026-07-23-design86-arc4-forensic-decision.md` — verdict: prohibited terms occur only as explicit exclusions; Rose verified no positive overclaim remains.
- `rg -n 'max_abs_gradient|accepted_starts|selected_start|collapsed|G2_ALL_500_ATTEMPTS|fifth|replacement|retrospective|Gate 3|Gate 4' docs/design/86-gate2r-v1-amendment.md docs/design/86-eva-gate2r-v1-parameters.json` — verdict: the memo's frozen-health, no-replacement, denominator, and scope fences agree with the signed V1 contract.

The convention-change cascade and validation-debt register are not applicable: no convention or public capability statement changed.

## 8a. Roadmap Tick

N/A — Design 86 remains a private feasibility lane and no `ROADMAP.md` row changed.

## 7a. Issue Ledger

No relevant open issue was established and no issue was created. `gh pr list` was attempted but the GitHub API was unreachable; no remote state was inferred.

## 9. What Did Not Go Smoothly

The original plan requested Luna-tiered mechanical verification, but no Luna dispatcher receipt was produced; Ada performed the equivalent read-only checks inline. The plan-versus-actual record preserves this as a routing drift rather than claiming Luna execution. Rose also caught two wording imprecisions before closeout: the historical receipt lacks a `runtime` field, and a smoke can be a G2 artifact without completing the 500-attempt Gate-2 denominator.

## 11. Team Learning

**Ada:** kept the arc inside its private, no-run boundary and recorded the routing deviation rather than normalizing it.

**Gauss:** confirmed that the facts support repeated frozen-health failure, not a numerical cause or remedy.

**Rose:** required exact provenance language and corrected the Gate-2 and historical-runtime statements before closure.

**Melissa:** recorded the missing Luna receipt as a material routing drift with no accompanying evidence or scope drift.

## 10. Known Residuals

The memo does not decide whether to park, amend, or defer; that choice belongs to the maintainer. Any amended run requires a new signed versioned amendment, independent numerical review, frozen provenance, a disjoint output root, and fresh pre-run authority. The two smoke records remain immutable.

## 12. Cross-Product Coverage

This arc covers only the two Design 86 EVA smoke records, their provenance, and
their frozen-health outcomes. It does not cover estimator recovery, the
500-attempt Gate-2 denominator, Laplace, intervals, campaigns, response-family
work, public/package/API work, `src/gllvmTMB.cpp`, Gate 3, Gate 4, Totoro, or
DRAC.
