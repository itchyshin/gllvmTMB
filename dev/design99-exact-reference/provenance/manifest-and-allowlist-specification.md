# Design 99 protected-path and write-allowlist specification

## Current Gate-0 producer allowlist

Only these paths may change in the present task:

```text
dev/design99-exact-reference/provenance/
docs/dev-log/plan-actual/2026-07-24-design99-exact-reference.md
```

Any other dirty path is a collision and stops this producer.

## Complete private-lane allowlist

The exact complete-lane allowlist is:

```text
dev/design99-exact-reference/
docs/design/99-exact-q2-reference-stabilization.md
docs/dev-log/plan-actual/2026-07-24-design99-exact-reference.md
docs/dev-log/check-log.md
docs/dev-log/after-task/2026-07-24-design99-exact-reference.md
docs/dev-log/handover/2026-07-24-codex-handover-design99.md
```

This does not authorize package `R/`, package `src/`, `inst/`, `man/`,
`tests/testthat/`, `vignettes/`, README, NEWS, NAMESPACE, DESCRIPTION,
`_pkgdown.yml`, workflows, Designs 72/85/94--98, or any Design-98 result path.

The shared-file pre-edit lane check remains mandatory before changing
`docs/design/`, `docs/dev-log/check-log.md`, or
`docs/dev-log/after-task/`. This specification does not override another
agent's file ownership.

## Inventory schema

`protected-paths.json` declares:

- the exact baseline commit;
- the immutable Design-98 real UUID;
- the current-task and proposed complete-lane allowlists;
- current-worktree protected groups for Designs 72, 85, and 95--98;
- a historical Git-tree group for absent Design-94 paths at `f88f4420`; and
- the complete Design-98 real-packet directory.

The generator requires an explicit `--scope producer` or `--scope lane`.
Producer scope enforces `current_task_write_allowlist`; lane scope enforces
`complete_lane_allowlist`. This prevents a caller from silently widening the
current producer's ownership while still allowing the full lane to perform its
later prelock and final checks.

`generate-protected-inventory.py` produces one tab-separated row per file with:

```text
group source path kind bytes sha256 git_blob status
```

For current-worktree entries, SHA-256 covers the filesystem bytes and
`git_blob` is recomputed from those bytes. For Design 94, SHA-256 covers the
blob content read from the pinned historical commit. The summary records
group-level counts/bytes, manifest and aggregate inventory SHA-256, missing
paths, baseline head, branch, UUID, and the fact that Design 98 was not
executed.

## Immutable receipts and required lifecycle

The pinned predecessor digest is
`0b8910908bd9b89a21994f008f806a2e973005fc69ae1d39e5b88396c6b64531`.
It is stored in `protected-paths.json`, not learned from a newly generated
receipt.

1. `generate-protected-inventory.py baseline --scope producer` exclusively
   creates `baseline-protected-inventory.tsv` and
   `baseline-protected-inventory-summary.json`. It refuses if either exists.
   The two original receipt-file SHA-256 values are also pinned in the
   manifest, so neither file can be altered while preserving only its embedded
   inventory digest.
2. `generate-protected-inventory.py compare --scope lane` writes nothing and
   requires the current inventory, frozen baseline TSV, and baseline summary to
   reproduce the pinned digest.
3. Immediately before the one-shot real lock,
   `generate-protected-inventory.py prelock --scope lane` exclusively creates
   `prelock-protected-inventory.tsv` and
   `prelock-protected-inventory-summary.json`. This mode runs the runtime
   scanner itself before writing either receipt.
4. After terminal aggregation, `generate-protected-inventory.py final --scope
   lane` exclusively creates `final-protected-inventory.tsv` and
   `final-protected-inventory-summary.json`. This mode also runs the runtime
   scanner itself before writing either receipt.
5. Every mode verifies that the first 2,573,335 bytes of
   `docs/dev-log/check-log.md` equal Git blob
   `9eb152e6894e6033ead47c6176947e229cec5ff4` and SHA-256
   `14f2beb50f007940bef74f1b5b67e1794daac37315221b3d197b8119c07f0b42`.
   This protects the complete baseline, including the Design-98 block, while
   permitting append-only Design-99 entries.
6. Before prelock and final, run `scan-design99-runtime.py --scope lane`. It
   recursively scans runtime source, manifests, and inputs outside
   `provenance/`, rejects Design-98 tree/UUID/result or dynamic-load
   references, rejects every runtime symlink before following its target, and
   rejects new C/C++ source files.
7. Retain baseline, prelock, final, and scanner command outcomes in the
   terminal after-task report.

## Fail-closed states

- wrong baseline commit: `PROVENANCE_STOP`;
- dirty path outside the explicitly selected allowlist: `PROVENANCE_STOP`;
- missing protected current path: `PROVENANCE_STOP`;
- missing historical Design-94 Git object: `PROVENANCE_STOP`;
- predecessor byte/hash change: `PROVENANCE_STOP`;
- any write under Design 98 or its UUID: `PROVENANCE_STOP`;
- source or execution dependency on Design-98 code: `SCOPE_STOP`;
- package/public diff: `SCOPE_STOP`;
- reuse without a pinned source and independent test: `PROVENANCE_STOP`.
- changed Design-98 check-log prefix: `PROVENANCE_STOP`;
- Design-98 runtime/source/manifest/input reference: `SCOPE_STOP`;
- runtime symlink under the Design-99 private lane: `SCOPE_STOP`;
- new Design-99 C/C++ source file: `SCOPE_STOP`.

Numerical success cannot override these states.
