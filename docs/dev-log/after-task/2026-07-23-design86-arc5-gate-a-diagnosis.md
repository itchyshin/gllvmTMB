# After Task: Design 86 Arc 5 — Gate-A numerical diagnosis

**Branch:** `codex/design86-arc2r-20260723`
**Date:** 2026-07-23
**Roles engaged:** Ada, Gauss, Rose, Jason/Ranganathan

## 1. Goal

Determine whether a falsifiable, controlled numerical mechanism could support
a versioned amendment and one future smoke, while retaining the immutable
historical failure records and requiring a separate Gate-B authorization.

## 2. Implemented

Added the Gate-A specification, a deterministic non-Gate-2 TMB/optimizer
probe, a dev-only executable check, a summary receipt, and the resulting
forensic audit.  Gate A closed `PARK`; no amendment or runner was created.

## 3. Mathematical Contract

The probe uses the existing tiny Gate-1 EVA objective only.  It checks local
AD/finite-difference agreement and optimizer telemetry; it does not validate
the Design-86 DGP, historical smoke gradients, likelihood correctness,
identifiability, recovery, interval construction, or a Gate-2 result.

## 3a. Decisions and Rejected Alternatives

**Decision:** park the amendment/rerun path. **Rationale:** raw-loading scaling
was nondiscriminating and the receipt lacks the full retained A0–A3 evidence
needed for promotion. **Rejected:** interpreting the smaller scaled gradient
as a remedy; loosening health thresholds; adding starts; retrospectively
rescoring; drafting V2; or invoking a runner. **Confidence:** high that the
evidence does not meet the Gate-A promotion contract.

## 4. Files Touched

- `docs/design/86-arc5-gate-a-diagnostic-spec.md`
- `dev/design86-arc5-controlled-probe.R`
- `dev/test-design86-arc5-controlled-probe.R`
- `dev/design86-arc5-controlled-probe-receipt.json`
- `docs/dev-log/forensic/2026-07-23-design86-arc5-gate-a-audit.md`
- `docs/dev-log/plan-actual/2026-07-23-design86-arc5-gate-a.md`
- `docs/dev-log/handover/2026-07-23-codex-handover-design86-arc5-gate-a-park.md`
- `docs/dev-log/check-log.md`
- this report

No historical artifact, Design-86 runner, `R/eva-proto.R`, package C++,
public API, testthat suite, documentation surface, or generated package file
changed.

## 5. Checks Run

- Static artifact and source audit: PASS for the manifest/result/receipt
  cross-links and the `output_manifest_sha256` source semantics.
- `Rscript --vanilla dev/test-design86-arc5-controlled-probe.R`: PASS.  This
  compiled only the tiny temporary Gate-1 prototype and ran no Design-86
  runner, DGP, or smoke.
- `jsonlite::validate(...)` for the dev receipt: PASS.
- `git diff --check`: PASS.
- `git diff --exit-code HEAD -- R/eva-proto.R src/gllvmTMB.cpp dev/design86-gate2-eva-runner.R dev/design86-gate2-laplace-runner.R`: PASS (empty).
- Gauss Gate-A review: `INCONCLUSIVE`; Rose Gate-A review: `PARK`.

No Gate-2 input construction, runner invocation, smoke, campaign, Laplace,
Totoro, DRAC, package test/check, pkgdown build, push, or PR was run.

## 6. Tests of the Tests

The executable dev check independently asserts the controlled fixture label,
the TMB `parList` round trip, fixed block lengths, local AD/finite-difference
screen, a convergent quadratic gradient below `1e-4`, and a nonstationary
linear gradient not below `1e-4`.  It cannot test the historical smoke because
that would violate the frozen-artifact/no-rescore boundary.

## 7a. Issue Ledger

No issue was created.  The pre-edit `gh pr list --state open` command could
not reach the GitHub API, so no remote PR state was inferred.

## 8. Consistency Audit

The Gate-A specification, receipt, audit, and this report all state `PARK`
and withhold V2/run authority.  The receipt calls the source at execution an
untracked development file rather than falsely assigning it to `e0e16079`.
The result wording contains no Gate-2 admission, recovery, coverage, engine
cause, or public-capability claim.  No convention-change cascade or
validation-debt update applies because no public interface changed.

## 8a. Roadmap Tick

N/A — Design 86 remains a private feasibility lane; no roadmap or public
capability status changed.

## 9. What Did Not Go Smoothly

The first receipt summarized evidence instead of retaining all frozen A0–A3
raw fields.  Rose caught that the helper did not perform A0 and that the
summary was insufficient for a promotion decision.  The receipt was corrected,
and the conservative park outcome was retained rather than filling gaps with a
new probe.

## 10. Known Residuals

No numerical cause or remedy has been established.  Any future diagnosis must
start as a new approved arc with a complete audit ledger and a distinct,
falsifiable mechanism.  The two prior smoke records remain immutable.

## 11. Team Learning

**Gauss:** a lower gradient under a scaling wrapper is not evidence for a
mechanism unless the mapped traces meet the same-target and health criteria.

**Rose:** receipt completeness is a promotion condition, not a documentation
cleanup to defer after a favorable result.

**Jason/Ranganathan:** AD/finite-difference agreement and optimizer codes have
strictly local diagnostic scope and cannot validate model correctness or a
global optimum.

**Ada:** the two-gate structure successfully stopped a tempting amendment path
when the evidence was only suggestive.

## 12. Cross-Product Coverage

This arc covers only a controlled Gate-1 EVA diagnostic and the static
provenance/coordinate interpretation of two Design-86 smoke records. It does NOT cover Gate-2 recovery, the 500-attempt denominator, historical rescore,
Laplace, public/package/API/C++ work, Gate-3/4, Totoro, DRAC, or any live run.
