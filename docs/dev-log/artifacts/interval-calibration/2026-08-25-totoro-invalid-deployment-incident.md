# Totoro interval-campaign infrastructure incident

Date: 2026-08-25  
Lane: `codex/interval-calibration-release`  
Original immutable root: `/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25`  
Original archive SHA-256: `0402b3e1484f56c92fa40cf362c4bb30b5c1de7feba221250261ad907d89c396`

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

CI-10 is separate. Its Fir dependency environment was valid, and all 18 rep-3
base fits genuinely failed before the 499-bootstrap stage. Those scientific
failures are terminal and are not rerun. The cost array therefore does not
measure successful nested-bootstrap cost and does not authorise the full
CI-10 campaign.
