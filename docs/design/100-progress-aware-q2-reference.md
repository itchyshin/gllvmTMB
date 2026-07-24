# Design 100: progress-aware Q2 reference record contract

## Purpose and status

This is a prospective, private, record-only contract for a possible Q2 reference
workflow.  It defines immutable launch, progress, and terminal records so that a
future, separately approved workflow can report what completed without replacing
or reinterpreting evidence.  It is not a numerical design, a fixture, a benchmark,
or a package feature.  No positive terminal in this contract is a scientific,
calibration, recovery, or public-capability claim.

**Status:** draft private contract.  The only positive record status is
`PROGRESS_COMPLETE`; it means that the declared record components completed under
this schema, not that a reference is valid or fit for use.

## Strict fences

This slice must not construct, read, transform, hash, or validate a realised
fixture; create or reserve a UUID; construct an objective; select starts; call an
optimizer; evaluate a quadrature or numerical integral; or build an information
ladder.  The record helpers reject field names that would smuggle those objects
into a record.

In particular, this contract does not admit VA, JJ, EVA, ELBO, variational,
Laplace, or cross-estimator work.  It does not call the package, source compiled
code, add a package API, or establish compatibility with any package path.  It
does not launch local, Totoro, DRAC, GitHub Actions, or other compute.  A later
approved design must supply its own fixture, UUID, optimizer, information-ladder,
estimator, package, and compute contracts rather than extending this one in place.

Design 99 remains immutable evidence only.  This contract does not copy its
fixture, UUID, records, optimiser controls, information ladder, source hashes, or
result paths.

## Record model

All records are UTF-8 JSON written once with exclusive creation.  A collision or
interrupted exclusive write is a mechanical failure: no helper overwrites, repairs,
or appends an existing record.  The helpers use `jsonlite::toJSON()` and
`jsonlite::fromJSON()` conventions, but only when a caller explicitly writes or
reads a record.

Every launch binds a task to a `contract_hash`, `input_hash`, and opaque
`run_label`; `run_label` is not a UUID.  Each terminal repeats those bindings and
also carries the hash of its launch.  Hashes are SHA-256 text values supplied by
the future approved workflow; this slice does not create inputs to hash.

### Launch record

`d100-launch-v1` requires `task_id`, `task_kind` (`pattern` or `component`),
`run_label`, `contract_hash`, `input_hash`, `launched_at`, `host`, `parent_pid`,
`mode`, and `liveness_timeout_s`.  Its permitted modes are `RECORD_ONLY` and
`COST_PRECHECK`; neither mode authorises a fit or numerical evaluation.

### Liveness and progress records

`d100-progress-v1` events require a task/run binding, a positive `sequence`,
state `progress`, timestamp, host, process id, and integer `completed`/`total`
counts.  For one task, sequences must strictly increase, `completed` must never
decrease, and `total` must remain fixed.  An event may be written only when it
preserves that monotone series.

`d100-liveness-v1` is a separate observational stream with its own strictly
increasing sequence and state `alive`.  It proves only that its emitting process
was observed; it never changes a progress, component, pattern, or whole-gate
deadline.  Conversely, a strictly advancing progress event may refresh only its
predeclared stale-progress window, capped by the already-frozen hard deadlines.
Both streams are operational telemetry, never numerical output.

### Terminal record

Every `d100-terminal-v1` requires the launch binding, `status`, `reason_code`,
start and finish timestamps, host, process id, exit status, and `telemetry` with
`wall_time_s`, `progress_event_count`, and `last_progress_sequence`.

A pattern terminal additionally requires `pattern_id`, `pattern_hash`,
`pattern_index`, `pattern_n_obs`, `component_ids`, and named
`component_terminal_hashes`.  A component terminal additionally requires
`pattern_id`, `component_id`, `component_kind`, `component_input_hash`,
`attempt_index`, `progress_event_hashes`, and `result_hash`.  Those hashes attest
only to immutable record linkage; they are not a fixture, optimisation, or
information claim.

## Terminal taxonomy

Each status has one of its listed reasons; unknown status/reason pairs are
malformed.

| Status | Allowed reasons | Meaning |
| --- | --- | --- |
| `PROGRESS_COMPLETE` | `ALL_COMPONENTS_RECORDED` | Required record components reached their declared terminal state. |
| `COST_BENCHMARK_STOP` | `COST_BENCHMARK_EXCEEDED`, `COST_BENCHMARK_UNAVAILABLE` | A prospective cost estimate did not authorise a launch; no compute is run here. |
| `PROVENANCE_STOP` | `CONTRACT_HASH_MISMATCH`, `IMMUTABLE_WRITE_CONFLICT` | Record identity or immutability failed. |
| `SCOPE_STOP` | `FENCED_FIELD_PRESENT`, `UNAPPROVED_MODE` | A prohibited domain entered the record request. |
| `MECHANICAL_STOP` | `MALFORMED_RECORD`, `LAUNCH_RECORD_INVALID`, `NON_MONOTONE_PROGRESS` | Schema or progression mechanics failed. |
| `INFRASTRUCTURE_INCOMPLETE` | `MISSING_TERMINAL`, `MALFORMED_TERMINAL`, `LIVENESS_EXPIRED` | Required operational record is absent or invalid. |
| `LAUNCH_FAILURE` | `PROCESS_LAUNCH_FAILED` | A later approved launcher could not start its declared task. |
| `TIMEOUT` | `LIVENESS_TIMEOUT` | A task exceeded its declared liveness window. |
| `ORPHAN` | `PARENT_PROCESS_EXITED` | The parent process disappeared before a valid terminal. |
| `INTERRUPTED` | `USER_INTERRUPT` | An explicit interruption occurred. |
| `CRASH` | `UNHANDLED_ERROR` | The worker ended unexpectedly. |
| `SIGNALED` | `PROCESS_SIGNAL` | The operating system signalled the worker. |
| `DEPENDENCY_BLOCKED` | `UPSTREAM_TERMINAL_NOT_COMPLETE` | A declared dependency did not complete; no fallback is implied. |
| `TECHNICAL_INCOMPLETE` | `REQUIRED_RECORD_MISSING` | A required private record is unavailable. |

`COST_BENCHMARK_STOP`, all failures, and `PROGRESS_COMPLETE` are private process
labels only.  None can be converted into an estimator, reference-quality, package,
or compute claim without a new approved design.

## Verification boundary

The companion tests are literal schema and monotonicity checks.  They do not call
integration, quadrature, an objective, a fixture generator, an optimiser, the
package, or any compute backend.  Running those tests is intentionally left to the
integrating owner of the future approved workflow.
