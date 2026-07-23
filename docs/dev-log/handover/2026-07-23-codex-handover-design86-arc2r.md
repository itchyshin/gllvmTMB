# Handover — Design 86 Arc 2R Gate-2 re-admission packet

## State

Arc 2R is complete only as a **maintainer-reviewable approval packet**. It does
not re-admit Gate 2 and does not authorise a new smoke. Worktree:
`/private/tmp/gllvmtmb-design86-arc2r`; branch:
`codex/design86-arc2r-20260723`; base Arc-2 stop: `3ab3b3a9`.

## What changed

- `R/eva-proto.R` is byte-identical to Arc-1 `3b479354`.
- Gate-2 support is private under `dev/`; there are only EVA and Laplace
  runners, plus a no-DGP controlled diagnostic harness.
- Frozen fixture/seed receipt validation, null-safe JSON, whole-tree/runtime
  provenance, and all-four-stage runner telemetry are implemented and tested.
- The draft packet is `docs/design/86-gate2r-readmission-brief.md`.

## Evidence

- Fixture SHA-256: `fb71826c84cf94ee288e8843d8997423247da9459cdb83a3ed8e1bb4373034d6`.
- Seed-array SHA-256: `9ab57cfb07f29e16a648088bbdfb4ebe6bb848a42b43ff3c48e7c76a67c4e29a`.
- Focused tests: input/provenance 33 PASS; diagnostic harness 42 PASS.
- Source guards: `git diff --exit-code 3b479354 -- R/eva-proto.R` and `git
  diff origin/main -- src/gllvmTMB.cpp` are empty.
- No Gate-2 runner/smoke or campaign was invoked by Arc 2R. Deterministic
  input replay is an in-memory fixture contract test only.

## Historical status and hard stop

The Arc-2 smoke stays red: information Q10 passed, but all four starts failed
the frozen `max_abs_gradient < 1e-4` rule. No winner or interval exists. Treat
historical fixture and artifacts as immutable.

**Fresh smoke remains unauthorised.** The maintainer must explicitly approve a
versioned Gate-2R amendment/fixture stating its canonical path and SHA,
seed-array receipt, exact approved runner/source hashes, clean-tree rule,
stage-receipt schema, and one-seed smoke authority. That approval must not
silently alter starts, optimiser controls, thresholds, or DGP. Totoro/DRAC,
Gate 3, Gate 4, public API, and shipped-engine work remain prohibited.

## First safe command after approval

Only after a signed amendment: read `docs/design/86-gate2r-readmission-brief.md`,
verify its listed hashes and guards, then follow the newly approved one-seed
smoke command. Do not reuse this handover as execution authority.
