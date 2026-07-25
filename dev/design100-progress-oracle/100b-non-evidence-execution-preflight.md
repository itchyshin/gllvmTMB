# Design 100-B: direct-2D non-evidence execution preflight

**Status:** `PREFLIGHT_ONLY — NOT APPROVED — NOT EXECUTABLE`

**Source anchor:** `bc8da7e5124eb83bbca7d370f1dba6482b3af176`.
**Design-99 boundary:** `d673dd61e42ca3c43836744ae27e979fca2b3d0b` is immutable and is neither an input nor a fallback.

## Purpose and absolute fence

This is a prospective operational freeze for a possible private direct-2D
oracle execution.  It is not a fixture, a UUID, a numerical run, an estimate,
or evidence.  It creates no output root and no receipt.  It does not run R,
build or invoke a worker, benchmark, optimise, evaluate an integral, or start
an information ladder.  It does not alter any package path or start VA, JJ, or
EVA work.

Nothing in this document permits replaying, repairing, re-scoring, or using
Design 99.

## Worker freeze: fail closed

The checked-in `scripts/oracle-worker.R` is *not* the required worker: it is a
declarative metadata CLI and refuses `--execute`.  Its source SHA-256 at the
source anchor is
`160245de7bd7feabc92842510a9dd48cad9121e0cbad75973c783dc51614e662`.
It is frozen here as **ineligible for execution**.

The sole eligible worker is `direct-2d-original-u-v1`, materialised privately
at `dev/design100-progress-oracle/scripts/direct-2d-worker.R`.  Before a
launcher can be enabled, its complete source SHA-256 must be appended to a new,
immutable approval receipt.  No source substitution or fallback to the
Design-99 worker is permitted.  The source is present only to freeze the
algorithm; it has not been sourced or run.

**Frozen worker SHA-256:**
`ab03c12da437f8ae323c23fd8c7768f881b6817d72de0b7cae26de4e05d382a2`.

The future worker's fixed remit is exactly one original-coordinate
two-dimensional direct evaluation per declared pattern.  It has no optimiser,
start selection, adaptive node choice, retry, fallback estimator, package call,
or information ladder.  Its only terminal routes are the existing
`d100-terminal-v1` taxonomy.

## Symbolic alignment: source-only kernel

For a fixed six-bit pattern \(y\), future-supplied \(\beta\in\mathbb R^6\),
and future-supplied \(\Lambda\in\mathbb R^{6\times2}\), the worker freezes
only the finite direct rule

\[
\eta_t(u)=\beta_t+\lambda_t^\top u,\qquad
\widetilde\pi_y=
\sum_{r=1}^{5}\sum_{s=1}^{5}w_rw_s
\prod_{t=1}^{6}\operatorname{Bernoulli}\{y_t;\operatorname{logit}^{-1}(\eta_t(z_r,z_s))\}.
\]

The nodes \(z\) and weights \(w\) are the frozen normalized-standard-normal
five-point rule in the worker.  This is one finite calculation rule, not an
information ladder or an assertion of exactness.

| Symbol | Worker representation | DGP/fixture | Fit or optimisation | Recovery/truth |
| --- | --- | --- | --- | --- |
| \(y\) | four embedded six-bit patterns | expressly absent | none | none |
| \(u\) | fixed 25-point original-`u` tensor grid | none | none | none |
| \(\beta\) | later manifest `beta[6]` | absent | no fit | no truth value |
| \(\Lambda\) | later manifest `lambda[6,2]` | absent | no fit | no truth value |
| \(\widetilde\pi_y\) | one private pattern probability | no realised output | no objective | no accuracy or reference claim |

## Deterministic task-set freeze

The preflight freezes the *shape* and ordering of the task graph without
constructing a scientific fixture:

| Field | Frozen value |
| --- | --- |
| dimension | `q = 2` only |
| coordinate system | `original_u` only |
| backend | `direct-2d-original-u-v1` only |
| pattern order | `pattern-001` = `000000`, `pattern-002` = `010101`, `pattern-003` = `101010`, `pattern-004` = `111111`, lexicographically |
| components per pattern | one: `direct-2d` |
| queue order | `pattern_id`, then backend, task id, and component path, as `d100_freeze_task_graph()` specifies |
| retries | none; every terminal is absorbing |
| coordinate rule | one fixed normalized-N(0,1) 5-point Gaussian-Hermite rule per axis; its 25 original-`u` tensor coordinates are column-major and embedded in the worker source |
| model kernel | six-trait Bernoulli-logit conditional pattern probability; `beta[6]` and `lambda[6,2]` are required only from a later approved manifest |
| fixture boundary | no counts, `beta`, `lambda`, seed, UUID, or realised data are present in this source or preflight |

The four patterns are algorithmic test patterns, not a realised data fixture.
An execution request must supply a separately approved manifest for `beta` and
`lambda`; without it, the frozen worker remains non-executable.

## Prospective timeout and concurrency schedule

All values are hard upper bounds from the execution launch epoch.  Progress or
liveness may not extend component, pattern, or whole-gate deadlines.

| Control | Frozen value |
| --- | ---: |
| `max_workers` | 1 |
| component deadline | 300 seconds |
| pattern deadline | 300 seconds |
| stale-progress deadline | 60 seconds |
| liveness watchdog | 30 seconds |
| whole-gate deadline | 1,260 seconds |
| launch policy | deterministic serial order; no retry or replacement worker |

The 1,260-second whole gate is four serial 300-second pattern caps plus one
60-second terminal-record allowance.  It is a safety envelope, not a runtime
estimate or benchmark.

## Cost envelope and compute route

This is intentionally a non-evidence spend ceiling, not a measured cost:

- At most four worker launches and four direct-2D task attempts.
- At most one live worker at a time and 1,260 seconds of total wall-clock gate
  occupancy.
- No parallel backend, GPU, Totoro, DRAC, GitHub Actions, package test, or
  benchmark is authorized.  If an approved worker cannot meet this local,
  serial envelope, it must terminalize; it cannot widen the envelope.

## Output root and receipt contract

The prospective execution root is exactly
`/private/tmp/gllvmtmb-design100b-direct2d-output`.  It is a name only in this
preflight: the directory does not yet exist and must not be created before
approval.

Before any launch, a new exclusive-write `d100b-execution-approval-v1` receipt
must be present at
`/private/tmp/gllvmtmb-design100b-direct2d-output/approval/execution-approval.json`.
It must contain exactly these bindings:

1. source anchor `bc8da7e5...`, immutable Design-99 anchor `d673dd61...`, and
   this preflight's SHA-256;
2. the complete source SHA-256 of the materialised `direct-2d-worker.R`;
3. an immutable task-manifest hash binding the four ordered opaque pattern ids,
   their actual approved payloads, and the original-`u` coordinate values;
4. the timeout schedule, worker cap, output root, and cost envelope above;
5. `run_class = "NON_EVIDENCE"`, `executable = true`,
   `numeric_benchmark_created = false`, and
   `numeric_benchmark_executed = false`; and
6. an explicit maintainer approval statement and timestamp.

Every launch, progress, liveness, component terminal, and pattern terminal
then uses the existing exclusive-write record schema under that root.  Missing,
malformed, replaced, or inconsistent bindings terminalize the gate and forbid
overwriting or a retry.  A `PROGRESS_COMPLETE` terminal remains a private
operational record only: it is not an exact-reference, calibration, recovery,
or capability result.

## Approval gate

**No computation is authorized.**  A maintainer must explicitly approve all of
the following in one message before any R, benchmark, or worker command is run:

> Approve Design-100-B direct-2D non-evidence execution under this preflight:
> four serial opaque patterns, original-u q=2 only, one worker, the stated
> 300/300/60/30/1260-second schedule, the stated local cost ceiling, and the
> prospective output root/receipt contract.

Approval does not authorize a fixture or UUID, optimisation, an information
ladder, a package-path change, or VA/JJ/EVA.  Each requires a distinct later
approval.
