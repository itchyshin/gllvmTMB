# Design 86 Gate 2R — re-admission brief

**Status:** DRAFT — requires explicit maintainer sign-off before any new Gate-2 smoke.

## Purpose and boundary

Gate 2R repairs the private prototype fence and the audit trail exposed by the
red Gate-2 smoke.  It does not revise the frozen optimiser, starts, health
thresholds, acceptance thresholds, DGP, or the historical fixture.  It does
not authorise a new smoke, Totoro/DRAC work, Gate 3, Gate 4, a public method,
or a change to the shipped engine.

The historical frozen fixture remains
`docs/design/86-eva-gate2-anchor-parameters.json`, with SHA-256
`fb71826c84cf94ee288e8843d8997423247da9459cdb83a3ed8e1bb4373034d6`.
Its 500-seed array receipt remains
`9ab57cfb07f29e16a648088bbdfb4ebe6bb848a42b43ff3c48e7c76a67c4e29a`.
The failed Arc-2 smoke artifacts are historical evidence and are not amended
or re-scored here.

## Repaired private contract

1. `R/eva-proto.R` is restored byte-for-byte to the sealed Arc-1 state
   (`3b479354`).  Gate-2 fixture, hash, input, and receipt helpers live only
   in `dev/design86-gate2-eva-runner.R`; the Laplace runner sources that
   private runner.  The only Gate-2 executables are the EVA and unchanged-live
   Laplace runners under `dev/`.
2. Before input construction, the EVA runner verifies the frozen fixture SHA
   and the seed-array receipt.  A mismatch stops execution.  Receipts encode
   unavailable numeric quantities as JSON `null`, record R/TMB/compiler and
   platform details, and report whole-tree cleanliness from `git status
   --porcelain`.
3. The EVA runner retains a stage receipt for each frozen optimiser stage; it
   does not alter stage order, controls, starts, or selection.  The separate
   `dev/design86-optimizer-diagnostic-harness.R` is a controlled-objective
   diagnostic only.  It traces all three `nlminb` stages and BFGS (parameters,
   objective, maximum absolute gradient, convergence/message, and evaluation
   counts).  It neither reads the Gate-2 fixture or seed list, calls the DGP,
   emits a Gate-2 receipt, nor ranks starts.

The deterministic input-replay test is a private fixture-contract test only:
it constructs identical inputs for a supplied seed but does not call either
Gate-2 runner, create a campaign receipt, select a start, or constitute a
smoke.  No Gate-2 runner was invoked in Gate 2R.

## Diagnostic interpretation

The controlled diagnostic proves that the required telemetry schema is
available for convergent and deliberately non-stationary objectives.  The
runner's matching receipt records each frozen stage without changing its
controls.  Neither result diagnoses the red EVA smoke or alters the frozen optimisation policy,
or establish that any future Gate-2 fit is healthy.  The historical result
therefore remains: the information screen passed, but all four starts failed
the frozen stationarity criterion; no winner or interval was admitted.

## Required maintainer sign-off

Before any new smoke, the maintainer must approve a new, versioned Gate-2R
amendment and fixture.  That approval must explicitly state:

- the fixture version, canonical path, SHA-256, seed-array receipt, and any changed values;
- whether the frozen starts, stage controls, and stationarity rule remain
  unchanged (the Gate-2R default is unchanged);
- the required per-stage telemetry schema and treatment of missing numeric
  values as JSON `null`;
- the precise one-seed smoke authority, output location, and failure rule;
- the exact approved runner/source hashes and requirement that the recorded
  `source_tree_clean` value is `true` before input construction;
- that a smoke may not become a recovery campaign or authorize Totoro/DRAC,
  Gate 3, Gate 4, public API, or shipped-engine work.

Until that signed amendment exists, a fresh smoke is unauthorised.

## Re-admission evidence checklist

The maintainer should require the following receipt with a future amendment:

- `git diff --exit-code 3b479354 -- R/eva-proto.R` is empty;
- `git diff origin/main -- src/gllvmTMB.cpp` is empty;
- fixture-SHA rejection, seed-receipt rejection, JSON-null encoding, and
  deterministic replay contract tests pass;
- the controlled optimiser harness records every required stage on convergent
  and non-stationary objectives;
- the harness contains no Gate-2 input-generator, seed-array, or campaign-root
  dependency;
- the three independent math, numerical, and scope reviews clear the packet.

This brief is an approval packet, not approval itself.
