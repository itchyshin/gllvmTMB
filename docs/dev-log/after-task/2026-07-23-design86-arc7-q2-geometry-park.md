# After Task: Design 86 Arc 7 — q=2 geometry diagnosis (PARK)

**Branch:** `codex/design86-arc2r-20260723`
**Date:** 2026-07-23
**Roles engaged:** Ada, Gauss/Noether, Rose, Jason/Ranganathan, Curie

## 1. Goal

Determine whether q=2 loading/variational geometry identifies a structural
mechanism or one objective-preserving coordinate candidate for the immutable
EVA smoke failures.

## 2. Implemented

Added a dev-only deterministic q=2 harness, fixed-design controls, raw
`NON_GATE2` ledger, frozen protocol, bounded source map, and Gate-A audit.
Gate A is `PARK`; no V2 or live lane was created.

## 3. Mathematical Contract

For the q=2 lower-triangular packing, Arc 7 checks the five-coordinate loading
map, discrete sign reflections, a common-scale KL control, local scalar/AD/FD
agreement, fixed-design rank/separation controls, and four-stage telemetry.
It does not rescore the smoke records, establish a historical cause, validate
the EVA likelihood, establish global identifiability, or supply a remedy.

## 3a. Decisions and Rejected Alternatives

**Decision:** PARK. The constructed separable control is a protocol stop
condition, the q=2 map is locally full rank, the scale ray has positive KL
cost, and the ledger is not promotion-complete. **Rejected:** treating the
separable control as historical evidence; treating code zero as health;
retrofitting A4; V2 drafting; runner invocation; or retrying a controlled
probe for a more favourable outcome.

## 4. Files Touched

- `docs/design/86-arc7-gate-a-q2-protocol.md`
- `dev/design86-arc7-q2-geometry-probe.R`
- `dev/test-design86-arc7-q2-geometry-probe.R`
- `docs/dev-log/forensic/2026-07-23-design86-arc7-non-gate2-q2-geometry/`
- `docs/dev-log/forensic/2026-07-23-design86-arc7-gate-a-audit.md`
- `docs/dev-log/forensic/2026-07-23-design86-arc7-numerical-source-map.md`
- `docs/dev-log/plan-actual/2026-07-23-design86-arc7-q2-geometry.md`
- `docs/dev-log/handover/2026-07-23-codex-handover-design86-arc7-q2-park.md`
- `docs/dev-log/check-log.md` and this report

No historical artifact, runner, `R/eva-proto.R`, package C++, public API,
generated package surface, or validation-debt status changed.

## 5. Checks Run

- `Rscript --vanilla dev/test-design86-arc7-q2-geometry-probe.R`: PASS; only
  the temporary q=2 prototype compiled.
- Controlled ledger JSON validation: PASS.
- q=2 reflection equality and predicted scale-KL comparison: PASS.
- Historical/V1 manifest/result/receipt SHA-256 rehash: PASS.
- `git diff --exit-code HEAD -- R/eva-proto.R src/gllvmTMB.cpp dev/design86-gate2-eva-runner.R dev/design86-gate2-laplace-runner.R`: PASS (empty).
- Gauss/Noether Gate-A review: PARK. Rose Gate-A review: PARK.

No package-wide check, runner, input/DGP, smoke, campaign, Laplace, Totoro,
DRAC, push, or PR was run.

## 6. Tests of the Tests

The executable test runs all fixed q=2 controls through the actual temporary
TMB objective and asserts the `NON_GATE2` label, PARK-pending harness result,
and required raw sidecars. It is a prophylactic diagnostic harness test. The
independent scalar oracle and retained per-coordinate differences test local
derivatives, not historical smoke gradients.

## 7a. Issue Ledger

No issue was created. `gh pr list --state open --limit 20` could not reach
GitHub; no remote PR state was inferred.

## 8. Consistency Audit

Exact stale-wording scan:
`rg -n -i 'gate[- ]?2 (pass|admission)|recovery|coverage|engine cause|numerical remedy|public capability|successful convergence' docs/design/86-arc7-gate-a-q2-protocol.md docs/dev-log/forensic/2026-07-23-design86-arc7-gate-a-audit.md docs/dev-log/after-task/2026-07-23-design86-arc7-q2-geometry-park.md`.
The documents consistently state PARK and prohibit promotion. No public claim
exists, so no validation-debt row or convention-change cascade applies.

## 8a. Roadmap Tick

N/A — this remains a private diagnostic lane.

## 9. What Did Not Go Smoothly

The initial implementation worker produced no files and was interrupted; the
two dev files were then completed locally. The planned Luna route had already
failed because its dispatcher could not write the Codex state database and was
denied its app-server operation. Those are routing deviations. Rose also found
that the resulting ledger is not promotion-complete, which correctly reinforces
PARK rather than prompting an evidence-repair rerun.

## 10. Known Residuals

Arc 7 does not identify a mechanism for either smoke failure. The controlled
separation/rank behavior is not evidence that historic data were separated.
A future diagnosis needs a fresh mechanism and an independently approved,
complete evidence contract.

## 11. Team Learning

**Gauss/Noether:** lower-triangular identification removes continuous q=2
rotations but leaves discrete sign symmetry; local rank does not explain a
historical optimizer trace.

**Rose:** a controlled negative record can be useful while still being
insufficient for promotion; that distinction must remain explicit.

**Jason/Ranganathan:** AD/FD, termination codes, and Hessians have strictly
local diagnostic meanings.

**Ada:** conditional V2 planning remains safe only when each Gate-A stop
condition actually closes the live route.

## 12. Cross-Product Coverage

This arc covers a fixed q=2 EVA geometry diagnostic only. It does NOT cover
historical q=2 failure cause, Gate-2 admission/recovery, the 500-attempt
denominator, DGP performance, intervals, Laplace, public/package/API/C++ work,
Gate-3/4, Totoro, DRAC, or a live run.
