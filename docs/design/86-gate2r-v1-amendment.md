# Design 86 Gate-2R V1 amendment

**Status:** CANDIDATE ONLY — this document grants no smoke authority until its
Gate-B signature fields are completed exactly as specified below.

## Purpose

G2R-V1 preserves the historical red Gate-2 smoke as immutable evidence while
reserving one prospective, auditable smoke. It does not diagnose, rehabilitate,
re-score, or select a winner from the historical smoke.

## Gate A — bounded build authority

The maintainer's instruction to implement this packet authorizes only the
candidate fixture, private runner guard, static checks, and review packet. It
does not authorize a runner invocation, input construction, DGP draw, compile,
artifact, smoke, recovery campaign, Totoro/DRAC, Gate 3, Gate 4, public API,
or shipped-engine work.

## Frozen historical evidence

- Historical fixture: `docs/design/86-eva-gate2-anchor-parameters.json`
  (`fb71826c84cf94ee288e8843d8997423247da9459cdb83a3ed8e1bb4373034d6`).
- Historical seed receipt:
  `9ab57cfb07f29e16a648088bbdfb4ebe6bb848a42b43ff3c48e7c76a67c4e29a`.
- Historical smoke seed: `86200001`; all four starts failed the frozen
  `max_abs_gradient < 1e-4` health rule. No historical winner or interval exists.

## G2R-V1 prospective contract

- Candidate fixture: `docs/design/86-eva-gate2r-v1-parameters.json`.
- Candidate fixture SHA-256: `c1528ae61aef414ae181fb53ca717d6080c6630a1d7d0773c964883eeeedee03`.
- Reserved smoke seed: `86200002`, from the unchanged frozen 500-seed array.
- Sole output root:
  `docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed`.
- DGP, starts, stage controls, health/acceptance/winner rules, interval rule,
  collapse rule, and all-failure semantics are byte-for-byte inherited in
  meaning from the historical fixture. No fifth/replacement start, threshold
  relaxation, conditioning, redraw, or retrospective score is permitted.
- The machine-readable fixture predicates and the EVA runner are the sole
  scorer. No separate scorer exists.

## Candidate source receipt

Base commit: `403be73c150a44d3c6c325b194fbed2559b41965`.

| Source | SHA-256 |
| --- | --- |
| `dev/design86-gate2-eva-runner.R` | `8295e18756b507fd2c5a47503bf2980a6c64315083a0a0cc2c0cf5bab7df27fb` |
| `dev/design86-gate2-laplace-runner.R` | `74de71bbb81da3fa740397eb8f74bb236194fa00ac299407b219806951d9f856` |
| `R/eva-proto.R` | `84e2939e720e0c873b5dcc3ec0e932eb1ebc5d748688774a009ba6d579001e8b` |
| `inst/tmb/gllvmTMB_eva.cpp` | `f19194b6c75e7226a59515f9fafbd419c5c315630556fb424b9ec83774b76d64` |
| `R/fit-multi.R` | `2c6d3cda72d19f9ba2d3658c4eb237fe526c04af507d57154abaacec159d83b4` |
| `src/gllvmTMB.cpp` | `aca02ae8dd3a94c614e39ae4d250102f1ff0cac0d91a9f8b57497bba189c5874` |

The final Gate-B signer must re-check every listed hash, require
`source_tree_clean = true` before input construction, and require stage
telemetry with JSON `null` for unavailable numeric values. Stage states remain
`attempted`, `error`, and `skipped_after_failure`.

## Gate B — final smoke authority

**Gate-B status:** UNSIGNED

**Fixture SHA-256:** `PENDING`

**Maintainer:** PENDING

**Signed on:** PENDING

Replacing the four fields above with a consistent signed record is the only
mechanism that can permit the private runners to proceed. The signature grants
exactly the reserved seed and output root above. It does not authorize any
further run, campaign, compute target, Gate 3/4, public API, shipped-engine
change, or public claim. This arc ends before the signed runner is invoked.

## Required final review

Before Gate B, verify that `R/eva-proto.R` is unchanged from `3b479354`,
`src/gllvmTMB.cpp` is unchanged from `origin/main`, the historical fixture and
artifacts are untouched, the candidate fixture retains the original seed-array
receipt, and the private runners fail before input construction while this
amendment remains unsigned.
