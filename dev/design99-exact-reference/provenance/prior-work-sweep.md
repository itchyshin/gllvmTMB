# Design 99 Gate-0 prior-work sweep receipt

**Role:** Rose/Jason provenance and scope  
**Worktree:** `/private/tmp/gllvmtmb-design99-exact-reference`  
**Branch:** `codex/design99-exact-reference-20260724`  
**Baseline:** `7ca5da1cba583a19a12340f0ab60007190730685`  
**Activity:** read-only predecessor inspection and byte inventory; no Design-98
source was imported, sourced, compiled, or executed, and no fit was run.

## Scope decision

Design 99 is a new private exact-reference lane. It may learn from predecessor
failure modes and software patterns, but it does not amend, replay, rescore, or
complete Designs 72, 85, or 94--98. Its outputs cannot establish VA/JJ,
package, public-API, recovery, calibration, structured-prior, or campaign
claims.

The only files written by this Gate-0 producer are under
`dev/design99-exact-reference/provenance/` and
`docs/dev-log/plan-actual/2026-07-24-design99-exact-reference.md`.

## Predecessor evidence map

| Design | Exact evidence | Terminal meaning for Design 99 |
|---|---|---|
| 72 | `docs/design/72-variational-approximation-feasibility.md`; terminal record commit `fa883fa17edcbb4a12e286e991ed5d14972277e9` | `PARKED`: convergence where Laplace failed did not cure genuine under-identification. This is a boundary, not an invitation to revive VA. |
| 85 | `docs/design/85-highdim-nongaussian-va-formal-contract.md`; `docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md`; terminal commit `ad371fc9a71204c78da2c7792a0cc25fa12edcfb` | `NO-GO`: q1/q2 did not establish the fixed-rank Gate-3 experiment, and eight applicable fits failed the frozen optimizer gate. q4/q6 remain closed. |
| 94 | Historical commit `f88f44200300f65a30d9c338e620f1de8d6f9304` | Fixed-global q=2 JJ mechanics only. Design-94 paths are absent from the Design-98 terminal tree, so the baseline records their Git objects rather than pretending they are current worktree files. |
| 95 | `dev/design95-free-jj-va/`; `docs/design/95-free-jj-variational-arc.md`; commit `8b76a9db341fa559ea6c1806286ae950fd11f31d` | Free-global diagonal-JJ mechanics passed, but the retained covariance diagnostic was not recovery or stability evidence. |
| 96 | `dev/design96-jj-recovery/`; `docs/design/96-jj-recovery-smoke.md`; commit `1e113e321d6e2f185fe1925bd10fe5420c7c5f5d` | Immutable `SMOKE_STOP`: five of six attempts missed the absolute-gradient gate and the moderate fixture failed invariant recovery. |
| 97 | `dev/design97-fullcov-jj/`; `docs/design/97-fullcov-jj-discrimination.md`; implementation commit `0ac1c348802df288799d17df6b4b6e4e8f093224`, landing correction `7a725c5ecbf46711e86fef36a29ba9bf67ac8b66` | Immutable `SMOKE_STOP`: the runner stopped before the free-global Gate-3 record. The small fixed-global comparison is not free-global or mechanism evidence. |
| 98 | `dev/design98-factorial-va-jj/`; `docs/design/98-factorial-va-jj-discriminator.md`; terminal commit `7ca5da1cba583a19a12340f0ab60007190730685` | Immutable `TECHNICAL_INCOMPLETE`: low-GH endpoints failed the 31/41/61 ladder and H61 gradient check; high-GH and JF endpoints missed their gradient gates; fixed-global comparisons were dependency-blocked. |

## Immutable Design-98 packet

The protected real packet is
`dev/design98-factorial-va-jj/results/20260724T161436-30841-62d0004f/`.
It contains 636 files in this baseline. The inventory treats the UUID, its
fixtures, inputs, terminals, payloads, logs, manifests, summaries, and retained
non-evidence smoke as read-only bytes. It must never be regenerated, repaired,
resumed, rescored, overwritten, or supplemented.

The immutable generated baseline contains 732 rows across all predecessor
groups:

- manifest: `protected-paths.json`;
- generator: `generate-protected-inventory.py`;
- file inventory: `baseline-protected-inventory.tsv`;
- summary and aggregate hashes:
  `baseline-protected-inventory-summary.json`.

At generation, and as the digest pinned for every later comparison, the
aggregate inventory SHA-256 was
`0b8910908bd9b89a21994f008f806a2e973005fc69ae1d39e5b88396c6b64531`;
the original baseline-generation manifest SHA-256 was
`03cd0293822282f0c32738e0cf1dbaeb255ac57ccba58a81caeca02cd8abb3cc`.
That original manifest hash is historical receipt metadata; later manifest
hardening does not regenerate or rewrite either baseline file.

## Fail-closed interpretation

The baseline is a provenance receipt, not an execution authorization. Before
any real Design-99 lock, another owner must run the read-only `compare` mode
and then exclusively create the distinct `prelock` receipt, requiring:

1. baseline commit identity;
2. no dirty path outside the Design-99 allowlist;
3. no missing declared predecessor path;
4. byte identity of every protected current-worktree file;
5. identity of the historical Design-94 Git objects; and
6. explicit separation between a non-evidence smoke root and any one-shot real
   UUID.

Any discrepancy is `PROVENANCE_STOP`. It cannot be waived by successful
numerics.
