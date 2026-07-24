# Design 99 exact-reference planned versus actual

**Status:** Gate-0 provenance tooling repaired and self-checked; numerical
implementation and execution not started.

## Approved goal

Establish a new private Design-99 exact-reference lane from the terminal
Design-98 head while keeping all predecessor artifacts immutable. Reuse only
documented patterns with provenance. Do not implement VA/JJ, package/public
surfaces, new C++, a simulation campaign, or push/PR work.

## Planned Gate-0 work

| Item | Planned | Actual |
|---|---|---|
| Rehydrate baseline | Confirm branch, head, worktree cleanliness, predecessor state | Confirmed branch `codex/design99-exact-reference-20260724`, clean starting tree, head `7ca5da1c` |
| Prior-work sweep | Designs 72, 85, and 94--98 with exact paths/commits and claim fences | Recorded in `dev/design99-exact-reference/provenance/prior-work-sweep.md` |
| Borrowed-pattern provenance | Design-98 context only; GLLVM.jl/drmTMB concepts only | Recorded with pinned commits/blobs and explicit non-reuse boundaries |
| Write allowlist | Separate this producer's ownership from the complete private lane | Recorded in JSON and Markdown; package/public/prior-design paths excluded |
| Protected inventory | Hash current predecessor paths plus immutable Design-98 UUID packet | Generated 732 rows; Design-98 packet contributes 636 files |
| Immutable receipt lifecycle | Prevent later checks from overwriting frozen evidence | Baseline creation is exclusive; compare is read-only; prelock and final use distinct exclusive filenames |
| Runtime isolation scanner | Reject Design-98 runtime dependencies, symlink escapes, and new C/C++ | Added recursive fail-closed scanner for future runtime source, manifests, and inputs |
| Check-log boundary | Preserve the existing Design-98 record while permitting append-only logging | Pinned the 2,573,335-byte baseline prefix by commit, Git blob, and SHA-256 |
| Design-94 absence | Avoid silently treating an absent current path as protected | Historical Git-object inventory pinned to `f88f4420` |
| Numerics/fits | None in Gate 0 | None run; Design 98 was not sourced or executed |

## Artifacts

- `dev/design99-exact-reference/provenance/protected-paths.json`
- `dev/design99-exact-reference/provenance/generate-protected-inventory.py`
- `dev/design99-exact-reference/provenance/scan-design99-runtime.py`
- `dev/design99-exact-reference/provenance/baseline-protected-inventory.tsv`
- `dev/design99-exact-reference/provenance/baseline-protected-inventory-summary.json`
- `dev/design99-exact-reference/provenance/prior-work-sweep.md`
- `dev/design99-exact-reference/provenance/borrowed-pattern-provenance.md`
- `dev/design99-exact-reference/provenance/manifest-and-allowlist-specification.md`

The immutable aggregate inventory SHA-256 remains
`0b8910908bd9b89a21994f008f806a2e973005fc69ae1d39e5b88396c6b64531`.
The hardened manifest SHA-256 is
`fd78067714b373a4808b2c65204d3f091aa20a50cc41f253febc1e62882296a4`.
The original baseline files were not rewritten: their file SHA-256 values
remain `fdef8fdaff95f473cdd44cc994acd781d2ec2400a6798eabcc1289163ef41aaa`
(TSV) and
`ffe262c5908a3f7a408c0d324700bdd7e23388bdc7dc39cb5f01fd5045ae872f`
(summary).

The exact later receipt filenames are:

- `prelock-protected-inventory.tsv`;
- `prelock-protected-inventory-summary.json`;
- `final-protected-inventory.tsv`;
- `final-protected-inventory-summary.json`.

## Deviations and open blockers

1. Design 94 is absent from the Design-98 terminal worktree. Its seven
   historical files are inventoried from commit `f88f4420`; this is explicit,
   not repaired.
2. A concurrent owner created the contract at
   `docs/design/99-exact-q2-reference-stabilization.md`; the complete-lane
   allowlist uses that exact path. The approved after-task and handover
   filenames are
   `docs/dev-log/after-task/2026-07-24-design99-exact-reference.md` and
   `docs/dev-log/handover/2026-07-24-codex-handover-design99.md`.
3. GLLVM.jl and drmTMB had unrelated dirty working trees. Only committed file
   history or pinned HEAD blobs were used, and their patterns remain
   conceptual.
4. The numerical contract remains separately owned. This provenance repair
   does not approve its unresolved Gate-0 review findings and does not
   authorize compilation, fixture creation, a fit, or a one-shot UUID.
5. `docs/dev-log/check-log.md`, an after-task report, and a handover are outside
   this producer's file ownership and were not changed.

## Self-checks

Ran without compilation, fixture creation, numerical evaluation, or fitting:

```sh
python3 -m py_compile \
  dev/design99-exact-reference/provenance/generate-protected-inventory.py \
  dev/design99-exact-reference/provenance/scan-design99-runtime.py
python3 -m json.tool \
  dev/design99-exact-reference/provenance/protected-paths.json
python3 dev/design99-exact-reference/provenance/scan-design99-runtime.py \
  --scope lane
python3 dev/design99-exact-reference/provenance/generate-protected-inventory.py \
  compare --scope lane
python3 dev/design99-exact-reference/provenance/generate-protected-inventory.py \
  compare --scope producer
```

The clean scanner passed. A temporary negative `.R` fixture using
`source(file.path(..., "design98-factorial-va-jj", ...))` and a temporary
`.cpp` fixture were both rejected. A separate temporary JSON fixture confirmed
rejection of the literal Design-98 tree, result path, and real UUID. All
negative fixtures were then deleted. A real `.R` symlink targeting
`dev/design98-factorial-va-jj/R/oracle.R` was rejected as
`runtime_symlink_forbidden` before content inspection and then unlinked.
Read-only comparison reproduced all 732 protected rows, the pinned aggregate
digest, and the 2,573,335-byte check-log prefix. Producer scope correctly
rejected the concurrently owned Design-99 contract as outside
`current_task_write_allowlist`; lane scope accepted it. A temporary-file unit
check confirmed that `exclusive_write()` raises `FileExistsError` and preserves
the first receipt bytes on a second creation attempt.

## Next gate

Another owner may proceed only after the contract's independent Gate-0 review
passes. Before any real-input lock, run:

```sh
python3 dev/design99-exact-reference/provenance/scan-design99-runtime.py --scope lane
python3 dev/design99-exact-reference/provenance/generate-protected-inventory.py compare --scope lane
python3 dev/design99-exact-reference/provenance/generate-protected-inventory.py prelock --scope lane
```

Any baseline mismatch, missing path, unexpected dirty path, predecessor
mutation, changed check-log prefix, Design-98 runtime dependency, or new C/C++
source or runtime symlink is a fail-closed stop before numerical work. The
baseline files are never regenerated or overwritten.
