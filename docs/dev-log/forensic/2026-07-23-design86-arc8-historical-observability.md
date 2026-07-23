# Design 86 Arc 8: terminal historical-observability decision

**Status:** private terminal decision.  
**Evidence baseline:** `codex/design86-arc2r-20260723` at `fd828a2d`.  
**Decision:** `HISTORICAL_MECHANISM_UNOBSERVABLE`.

## Question and evidence identity

This memo asks only whether the two immutable G2/EVA smoke chains retain the shared labelled numerical state needed to identify or exclude a historical failure mechanism. It does not re-run, rescore, reconstruct, or diagnose either smoke.

| Smoke | Manifest SHA-256 | Result SHA-256 | Receipt SHA-256 | Cross-link result |
|---|---|---|---|---|
| Anchor, seed `86200001` | `dc01e37b...d585f63` | `ec286f75...52bc9398` | `25da532e...f8b3ed9` | Result and receipt both name the manifest; receipt `output_manifest_sha256` equals the result SHA. |
| V1, seed `86200002` | `c5a3fbb9...896c9fb8` | `afda2d76...4fb191a` | `57cbf3de...d7aeadb` | Result and receipt both name the manifest; receipt `output_manifest_sha256` equals the result SHA. |

All six stored files rehashed on 2026-07-23. The field called `output_manifest_sha256` is a result-JSON digest, not evidence of an absent fourth stored artifact (Arc 5 audit). The records share engine/DLL digests, denominator identifier, ordered-cell-map digest, and truth digest; they differ in source commit, driver and runner digests, realised response, and replicate-input digests. They are comparable frozen-contract failures, not executable replications (Arc 4 forensic memo).

## Retained state and observability matrix

| Candidate historical mechanism | Necessary discriminator | Retained state | Permitted conclusion |
|---|---|---|---|
| Optimizer semantics | Full labelled trajectory, directions/steps, line-search state, termination messages, and complete gradients at each evaluation | Anchor: absent. V1: four stage summaries, but no complete gradient vectors, labelled coordinate map, or all optimizer state. | Neither identified nor excluded. |
| Coordinate conditioning / transforms | Full historical parameter vector, parameter-role/transform map, scaling map, and exact inverse-coordinate comparison | Anchor: absent. V1 stage parameters exist, but no complete historical role/transform mapping or comparable anchor state. | Neither identified nor excluded. |
| AD-gradient fidelity | Objective evaluations and full AD gradients at fixed historical coordinates, plus independent derivative checks | Absent for both. Controlled Arc 5--7 checks concern different, non-Gate-2 objectives. | Neither identified nor excluded. |
| Ridge, rank, or geometry | Physical-coordinate map, stationary curvature/profile data, and a mechanism-specific signature at both historical states | Absent for both. Arc 6--7 controls are local controlled evidence, not historical-state evidence. | Neither identified nor excluded. |
| Response separation | Retained realised arrays and fixed-effect design, with a predeclared separation signature | Only realised-input digests are retained; arrays and a historical signature are absent. | Neither identified nor excluded. |

Both results retain four code-zero starts whose final `max_abs_gradient` values exceed the frozen `1e-4` health threshold; `accepted_starts = false`, `collapsed = true`, and no winner or interval exists. This establishes two valid frozen-health failures, not convergence, a shared cause, or an absence of a cause. The anchor has only final per-start summaries; V1 additionally has four stage summaries per start. That asymmetry cannot discriminate a common numerical mechanism.

## Terminal category

`HISTORICAL_MECHANISM_UNOBSERVABLE` applies because integrity and cross-links pass while necessary discriminating state is absent. The other categories do not apply: no required hash/link fact failed; no retained shared signature identifies a mechanism; and no retained contradiction excludes one.

> The immutable records establish valid, comparable frozen-health failures. They do not retain the common labelled numerical state required to identify or exclude an optimizer, coordinate, derivative, separation, or geometry mechanism. The historical mechanism is therefore unobservable from this evidence; this is neither a causal diagnosis nor evidence that no mechanism exists.

## Boundaries and closure

This decision retires the current Design-86/EVA admission path. It does not establish Gate-2 admission, recovery, coverage, an interval, likelihood correctness, an engine defect, a numerical remedy, or a public capability. It authorizes no V2 amendment, Gate B, runner call, input/DGP construction, compile, probe, historical rescore, seed/start/threshold change, smoke, campaign, Laplace, public/API/C++ work, push, or PR.

Any future evidence request is a separately approved new research design, not a continuation authorized by this record.

## Evidence paths

- `docs/dev-log/simulation-artifacts/2026-07-22-design86-gate2-anchor-smoke-rerun2/`
- `docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/`
- `docs/dev-log/forensic/2026-07-23-design86-arc4-forensic-decision.md`
- `docs/dev-log/forensic/2026-07-23-design86-arc5-gate-a-audit.md`
- `docs/dev-log/forensic/2026-07-23-design86-arc6-gate-a-audit.md`
- `docs/dev-log/forensic/2026-07-23-design86-arc7-gate-a-audit.md`
