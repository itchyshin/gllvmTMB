# Terminal provenance and numerical-receipt review

**Reviewer:** Grace / Gauss receipt lens (Codex, independent read-only audit)  
**Date:** 2026-08-29  
Verdict: **PASS**

The retained qualification, smoke, and 52-task experiment bundles are
checksum-clean and mutually bound to the exact execution source, harness,
plans, installed package bytes, and loaded DLL. Every experiment task has one
planned identity, one started receipt, and one worker terminal disposition;
there are no replacement identities or coordinator-generated substitutes. A
fresh pure-reader reconstruction from the 52 raw attempt RDS files is exactly
identical to `independent-summary.rds`, including its serialized R object.

This review verifies provenance and numerical receipt reconstruction. It does
not independently endorse a new statistical mechanism or widen the frozen
experiment's claims.

## Severity findings

- **P0:** none.
- **P1:** none.
- **P2:** none for the bounded terminal bundle.
- **P3 — source labels require explicit closeout wording.** The plan's nested
  task `source_sha = c5bb0b80...` identifies the historical production records
  used to select seeds and sentinel classes. The attempt's top-level
  `source_sha = 09eca7b1...` identifies the qualified package source that
  actually executed the diagnostic fits. Both are correctly retained, but
  both fields share the name `source_sha`; closeout must state this distinction
  so nobody reports the experiment as having executed at `c5bb0b80...`.
- **P3 — summary-code identity is commit-bound, not qualification-manifest
  bound.** `summarise-independent.R` is deliberately outside the 17-member
  execution harness manifest. Its current SHA-256 is
  `557ef558f9b41e7d9eb52af2d507e1d614a998acb2bfef0186f7afda64c3e0aa`.
  The final landed commit will bind it, but a future standalone bundle should
  record this hash beside `independent-summary.rds`.
- **P3 — this receipt is not three-OS certification.** The qualification object
  records the exact GitHub Actions run but carries only
  `ci_platforms = c(ubuntu = "success")`. That is sufficient for the bounded
  Totoro/Linux diagnostic provenance reviewed here; it must not be reused as
  macOS or Windows package-check evidence.

## Manifest verification

Standard two-space SHA-256 verification passed for every listed member:

| Bundle | Members | Result |
| --- | ---: | --- |
| qualification | 3 | PASS |
| smoke | 21 | PASS |
| experiment | 143 | PASS |
| execution harness | 17 | PASS |
| seed selection | 2 | PASS |

The experiment manifest includes all 52 terminal attempts, all 52 started
receipts, the copied plan and qualification, launch start/terminal receipts,
the zero-disposition reconciliation, logs, command index, and
`independent-summary.rds`.

## Exact source, harness, and install binding

### Execution source — PASS

The qualified execution commit exists locally as
`09eca7b1eb9018958bad367be824871161a60af1` and resolves to tree
`fb979daa5d9a93d0804a053ff1bb00eced47ad09`. The qualification records a clean
source status. The install receipt and qualification agree on this SHA/tree,
the exact source checkout, installed package directory, installed-file
manifest, DLL path, and DLL hash.

### Historical selection source — PASS

The distinct production-evidence commit
`c5bb0b80a0a733c6d7cb1bab826003bbaa589fe4` exists and resolves to tree
`655282a18631700e033319d299e686162b52be97`. Every plan row preserves that
historical source/tree and its selected production-record SHA-256. This source
selects the frozen sentinel tasks; it is not the installed execution source.

### Harness and plans — PASS

`HARNESS_SHA256.txt` hashes to
`387066328e1c7679a2e5553e7f5d03920568047cc93bd416610ce979c7eb74b2`,
matching the qualification and every started/terminal receipt. All 17 harness
members verify. The experiment plan, smoke plan, and seed manifest hashes are,
respectively:

- `8a7ec70f6b26befca9f554f68363c161d34a93b86ea8fec0c0ad364bae3c28e5`;
- `35b043f73c6fce32406c0ab3b5424cb0e3fb24bfaabe32a6040d03d5b2bec9c6`;
- `108cd4ca8653fcca40c15252383b7fe5b7c4f63db2dd68e398268c1409dec2ba`.

They match the qualification, launch-start receipts, copied evidence files,
and compute-input files. Rebuilding both plans from the checksum-bound seed
manifest is part of qualification.

### Installed package and DLL — PASS

The install command exited 0 and explicitly names the exact source checkout
and isolated R library. The retained install log hashes to
`6be608cc785a79bfcc5ce842316bf3c6d1bda3421c45a9bd457bc47bf3871cb5`
and ends with `* DONE (gllvmTMB)`. The 99-file installed manifest is identical
between the install receipt and qualification and has canonical manifest hash
`9c63377dd3f51104f715cb99bc4d78291a56fd31c8e44c4c1511458f0226e41d`.
Its `libs/gllvmTMB.so` row matches the separately retained DLL hash
`1573bb77fc51c90461e0fff15f80acafbd91147b14d2a54a0f582458b419811c`.

The launch preflight and each task verify the installed manifest, DLL,
qualified source, harness manifest, and exact plan before entering the public
fit call. Launch-start receipts bind those same hashes; launch-terminal
receipts bind launch-start hashes and record command status 0.

## Smoke receipt

The smoke plan contains exactly four frozen task IDs: 2, 23, 24, and 25.
There are exactly four matching started and four matching worker terminal
records, all `fit_returned`, with no coordinator dispositions. Every record's
task payload exactly equals its plan row and its top-level source/tree/harness
identity equals the qualification. The smoke launch reports 4 planned,
command status 0, and 15 seconds observed wall time; the frozen projection is
38.3 seconds at 16 workers.

## Experiment denominator and dispositions

Independent enumeration, without using the reconciliation helper, produced:

| Quantity | Count |
| --- | ---: |
| planned task rows | 52 |
| unique planned IDs | 52 |
| started receipts | 52 |
| worker terminal records | 52 |
| coordinator terminal dispositions | 0 |
| replacements/unplanned IDs | 0 |
| `fit_returned` | 52 |
| error | 0 |
| interrupted | 0 |
| unavailable | 0 |

The filenames are exactly `task-000001.rds` through `task-000052.rds` in both
`started/` and `attempts/`. For every ID, both receipts reproduce the complete
17-field plan row; the top-level execution source/tree and harness hash equal
the qualification. The reconciliation receipt has `planned = 52`,
`reconciled = 0`, and an empty dispositions list. Thus every planned attempt is
preserved once and no replacement or inferred terminal record was introduced.

## Independent numerical-summary reproduction

I sourced only the pure-reader `summarise-independent.R`, read the frozen
experiment plan plus raw `output/attempts/`, `output/started/`, and coordinator
receipt, and rebuilt the summary in memory. The rebuilt object is:

- `identical()` to the retained `independent-summary.rds`;
- identical after R serialization version 3;
- consistent with retained file SHA-256
  `07b824085bd253d7a8fd1111d815445f42743606a6235f0f7c903a1f54c10edf`.

The independently reconstructed denominators are 52 planned, 52 started, 52
terminal, 52 worker, and 0 coordinator. All 16 nonspatial targets and all 36
spatial held-out/curvature/joint-precision targets are available. All eight
nonspatial pairs are available; eight spatial basin and eight termination
comparisons are comparable. None of the five frozen signals fires, and the
mechanical next-action label is `MIXED`.

This exact reproduction verifies that the summary is a deterministic view of
the retained raw records. It does not convert the `MIXED` result into a model
repair, threshold change, or promotion decision.

## Verifier results

The retained read-only verifier returned all four expected markers:

- `DIAGNOSTIC_REMOTE_QUALIFICATION_VERIFIED`;
- `DIAGNOSTIC_SMOKE_VERIFIED`;
- `DIAGNOSTIC_52_ATTEMPTS_VERIFIED`;
- `DIAGNOSTIC_SUMMARY_VERIFIED`.

I additionally ran independent checks for manifest membership, source/tree
objects, harness bytes, install/DLL cross-binding, exact task filenames,
plan-row equality, source/harness equality, launch-chain hashes, zero
replacement/coordinator dispositions, and in-memory summary identity.

## Final adjudication

| Component | Verdict |
| --- | --- |
| Qualification manifest | PASS |
| Smoke manifest and four-task ledger | PASS |
| Experiment manifest | PASS |
| Exact execution source/tree | PASS |
| Historical selection source/tree | PASS |
| Qualified harness and plan bytes | PASS |
| Installed package manifest and DLL | PASS |
| 52 planned/started/terminal denominator | PASS |
| No replacements | PASS |
| Independent summary reproduction | PASS |
| Bounded terminal provenance bundle | **PASS** |

The earned provenance statement is: **the diagnostic experiment ran exactly
52 frozen tasks from the qualified `09eca7b1...` package and checksum-bound
harness, retained one worker terminal record per started task with no
replacements, and produced an independently reproducible `MIXED` summary from
the raw attempt ledger.**
