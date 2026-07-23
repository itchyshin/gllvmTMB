# Design 86 Arc 4: forensic decision packet after two EVA smoke failures

**Status:** private, read-only decision support.  
**Evidence baseline:** `codex/design86-arc2r-20260723` at `60ba2108`.  
**Audience:** the maintainer deciding whether to park, amend, or defer the private Design 86 feasibility lane.

## Purpose and boundary

This packet compares the two immutable G2/EVA smoke records.  It answers a
narrow question: what do their receipts, inputs, and frozen health outcomes
establish?  It does not diagnose the cause of the failures or recommend a
numerical change.

Neither smoke completes the fixed 500-attempt Gate-2 denominator or yields a
Gate-2 admission verdict.  Both name the fixed denominator
`G2_ALL_500_ATTEMPTS`, but together they contain two smoke draws rather than
the frozen 500-attempt denominator.  They therefore establish no recovery,
bias, coverage, interval, Laplace-comparison, or public capability claim.

## Evidence identity and provenance

| Item | Historical anchor smoke | Prospective G2R-V1 smoke |
|---|---|---|
| Seed and artifact root | `86200001`; `2026-07-22-design86-gate2-anchor-smoke-rerun2` | `86200002`; `2026-07-23-design86-gate2r-v1-one-seed` |
| Result / receipt linkage | result input-manifest SHA `dc01e37b...d585f63`; receipt gives the same manifest SHA and output-manifest SHA `ec286f75...52bc9398` | result input-manifest SHA `c5a3fbb9...896c9fb8`; receipt gives the same manifest SHA and output-manifest SHA `afda2d76...4fb191a` |
| Source commit | `e77cc977b9bf68c88af175fdca2d37fe8a84cf0a` | `74dacae5f1266ea39386cd3055137b3eba0c71c4` |
| Engine / DLL SHA-256 | `f19194b6...74b76d64` / `8640bd4a...d81ae43d` | `f19194b6...74b76d64` / `8640bd4a...d81ae43d` |
| Driver / runner SHA-256 | `8b46a280...f690c6651` / `2a383b9f...b4985519` | `84e2939e...d579001e8b` / `8295e187...ab7df27fb` |
| Common DGP structure | `G2_ALL_500_ATTEMPTS`; ordered-cell-map SHA `2f53f888...5b0d5e2b`; truth SHA `535d3ed2...12a4a7bd` | same denominator, ordered-cell-map SHA, and truth SHA |
| Distinct realised inputs | response SHA `193d97f6...73890b66`; replicate-input SHA `6b9fde40...f7c175c84` | response SHA `c8339270...5adae3f3`; replicate-input SHA `79d30d1d...e510f02b7` |
| Information diagnostic | `I_unit_q10_type8 = 0.7518268` | `I_unit_q10_type8 = 0.7341114` |

The source commits and driver/runner hashes differ, while engine and DLL hashes
agree.  The records are therefore comparable frozen-contract smoke failures,
not code-identical executable replications.  Each receipt reports a clean
source tree before its own input construction.  The V1 receipt also records
R 4.6.0, TMB 1.9.21, and the arm64 clang++ runtime; the historical receipt has
no `runtime` field.

## Frozen health outcome

The V1 fixture defines a healthy start as code zero, finite values, and
`max_abs_gradient < 1e-4`; it forbids a fifth/replacement start and
retrospective rescoring.  The historical record is interpreted under the same
frozen health threshold.  The final recorded outcomes are:

| Seed | Start | Code | Negative EVA | Final max abs. gradient | Healthy |
|---|---:|---:|---:|---:|---|
| `86200001` | 1 | 0 | 534.119395 | 0.158985 | no |
| `86200001` | 2 | 0 | 571.530692 | 0.027450 | no |
| `86200001` | 3 | 0 | 533.791185 | 0.365480 | no |
| `86200001` | 4 | 0 | 571.527672 | 8.434513 | no |
| `86200002` | 1 | 0 | 528.304497 | 0.033703 | no |
| `86200002` | 2 | 0 | 528.145963 | 0.103768 | no |
| `86200002` | 3 | 0 | 528.341852 | 0.072232 | no |
| `86200002` | 4 | 0 | 528.489025 | 0.105011 | no |

For seed `86200002`, each start used the recorded `nlminb_1`, `nlminb_2`,
`nlminb_3`, and BFGS stages.  BFGS returned convergence code zero for all four
starts, but its final gradients remained above the frozen threshold.  Code zero
is consequently not a health pass under this contract.

Both records have `accepted_starts = false` and `collapsed = true`.  The
historical result represents its missing winner as `"NA"`; the V1 result uses
JSON `null`.  Neither representation supplies a selected healthy start.  No
winner, Schur interval, or beta estimate was produced.

## What the evidence supports—and does not support

The supported conclusion is limited: two distinct realised smoke inputs, under
the documented G2/EVA structure and frozen health rule, each exhausted their
four permitted starts without a healthy result.  The V1 artifact chain is
internally linked by its recorded manifest, result, and receipt hashes.  This
is valid receipt evidence plus repeated frozen-health failure.

The evidence does **not** identify whether the failure arises from the
optimizer, parameterization, likelihood, model geometry, or an interaction of
those factors.  The controlled diagnostic harness cannot settle that question:
it traces a quadratic or deliberately nonstationary controlled objective and
explicitly never constructs a Gate-2 input.  Its role is limited to validating
the meaning of stage telemetry, not attributing a cause to either smoke.

## Maintainer decisions

1. **Park or close the private feasibility lane.** Preserve both smoke records
   as immutable negative feasibility evidence and make no further Design 86
   change.
2. **Request a new, separately versioned amendment.** First commission an
   independent numerical review; only then may a new amendment define a
   specific question, altered contract, source/fixture hashes, disjoint output
   root, and fresh pre-run authorization.  It must not retrospectively alter or
   rescore these records.
3. **Defer.** Keep the lane parked pending independent numerical analysis, with
   no amended run or public claim in the meantime.

This packet does not select among those options.  A changed runner, health
threshold, start set, DGP, scorer, seed set, output root, or engine would be a
new protocol decision and is not authorized here.

## Evidence paths

- `docs/design/86-gate2r-v1-amendment.md`
- `docs/design/86-eva-gate2r-v1-parameters.json`
- `docs/dev-log/simulation-artifacts/2026-07-22-design86-gate2-anchor-smoke-rerun2/`
- `docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/`
- `dev/design86-optimizer-diagnostic-harness.R`
