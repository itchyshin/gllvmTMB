# Totoro interval-campaign infrastructure incident

Date: 2026-08-25

Lane: `codex/interval-calibration-release`

Original immutable root: `/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25`

Original archive SHA-256: `0402b3e1484f56c92fa40cf362c4bb30b5c1de7feba221250261ad907d89c396`

## Archive custody

The retained archive is
`/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25/archives/totoro-interval-campaign-2026-08-25.tar`
on Totoro and is mirrored locally at
`dev/interval-calibration/results/2026-08-25-retained-campaigns/totoro/totoro-interval-campaign-2026-08-25.tar`.
Both copies are 338,350,080 bytes and have SHA-256
`0402b3e1484f56c92fa40cf362c4bb30b5c1de7feba221250261ad907d89c396`.
The adjacent `.tar.sha256` file is 171 bytes. Verification uses
`sha256sum -c totoro-interval-campaign-2026-08-25.tar.sha256` on Totoro
and `shasum -a 256 totoro-interval-campaign-2026-08-25.tar` on macOS.
The mirrored checksum file retains Totoro's absolute archive path, so a local
`shasum -c` attempt correctly failed to resolve that remote-only pathname; the
direct local hash above returned the expected SHA-256. The original remote root
and both archive copies remain immutable.

## Disposition

The first Totoro sequence is **invalid infrastructure evidence**, not a
scientific interval-calibration campaign. It is retained in full and is not
pooled with a corrected run.

All 85,000 expected identities are present once, their deterministic seeds
match their frozen manifests, and all five canonical checksum manifests pass.
However, every shard failed before optimisation because the worker launcher
replaced `R_LIBS_USER` with the packet-only library. The omitted Totoro user
library contained the package's runtime dependencies. The exact retained
CI-09, PVT-02, and CI-13 errors are `there is no package called ‘assertthat’`;
CI-14/15 discarded the inner error text but have the same absent-library
session receipt and sub-second fail-fast pattern.

The first-wave runners then misclassified these dependency errors as
`base_fit_failed` or `scientific_base_failure`. Those labels are not used as
scientific outcomes. Independent packet audits reclassified all 85,000 rows
as infrastructure failures with zero eligible intervals. Coverage, clustered
MCSE, and lower coverage band are therefore not estimable, and no route is
promoted or called scientifically failed from this archive.

## Exact retained counts

| Packet | Expected and retained | Eligible | Infrastructure failures after audit |
|---|---:|---:|---:|
| PVT-02 | 5,000 | 0 | 5,000 |
| CI-09 | 30,000 | 0 | 30,000 |
| CI-13 | 20,000 | 0 | 20,000 |
| CI-14 | 10,000 | 0 | 10,000 |
| CI-15 | 20,000 | 0 | 20,000 |

## Repair and retry boundary

The orchestration repair:

1. validates the complete runtime dependency set during host preparation,
   session-receipt construction, and each shard;
2. carries both the source-SHA-specific packet library and the pinned Totoro
   user library into every worker;
3. retains CI-14/15 `failure` and `fit_health` diagnostics in the canonical
   runner provenance; and
4. reports empty-denominator CI-14/15 MCSE as `NA`, not zero.

The original archive and remote root remain untouched. The corrected retry is
restricted to the same five approved packets, cells, replicate identities,
seeds, 96-worker maximum, single-thread BLAS, sequential ordering, and two-hour
per-wave hard stop. It uses a new immutable root:
`/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25-r2`.

The pre-run timing basis remains the successful local smoke receipt. Expected
wall times at 96 workers are approximately 17 minutes (PVT-02), 29 minutes
(CI-09), 22 minutes (CI-13), 8 minutes (CI-14), and 23 minutes (CI-15), before
contention and aggregation. Each is below its already approved two-hour hard
stop. A corrected one-shard post-guard fit must be inspected before the full
retry sequence starts.

## Retry post-guard identity incident

The corrected post-guard reached the real PVT-02 optimiser and completed at
2026-08-25 22:39:43 UTC. It used the frozen campaign identity `PVT02`, cell 1,
replicate 50001, seed 800050001, and returned the scientific outcome
`fit_failed`. The retry sequence then executed the same identity again at
22:40:52 UTC, also returning `fit_failed`. Both valid-environment executions
are retained; neither is rewritten or deleted.

This duplicate is an operational-provenance failure, not permission to choose
the more favourable result. The first valid execution, the post-guard shard,
is the sole canonical scientific row for that identity. The later campaign
execution is marked `duplicate_excluded` and cannot enter a coverage,
availability, failure-rate, or promotion denominator. The original
missing-dependency execution remains `infrastructure_excluded`. A cross-root
operational ledger retains all three executions at
`2026-08-25-pvt02-r50001-cross-root-ledger.csv`. Future launchers require a
validated post-guard receipt: an in-manifest identity must be imported as the
campaign's canonical row, while an out-of-manifest identity must remain
`preflight_only`.

The active retry library was checked before CI-15: `Matrix` 1.7-5 and `ape`
5.8-1 were both present, alongside the ten previously checked dependencies.
The immutable audit receipts are
`2026-08-25-r2/deployment/runtime-dependency-audit.tsv` and
`2026-08-25-r2/deployment/post-guard-receipt-v2.rds` on Totoro. The V2 receipt
binds the canonical shard by its true SHA-256,
`9088ed70f21c9884f098bc403d51dfee2709c0217d5159d060721b1b4d9aadac`.
The earlier `post-guard-receipt.rds`, whose field was populated with an MD5
rather than a SHA-256, is preserved but explicitly superseded and cannot pass
the launcher gate. This closes the
specific risk that a missing phylogenetic dependency could be misclassified as
a CI-15 scientific failure; it does not promote any interval route.

CI-10 is separate. Its Fir dependency environment was valid, and all 18 rep-3
base fits genuinely failed before the 499-bootstrap stage. Those scientific
failures are terminal and are not rerun. The cost array therefore does not
measure successful nested-bootstrap cost and does not authorise the full
CI-10 campaign.
