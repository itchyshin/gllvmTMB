# Dependent temporal--kernel curvature-scaled BFGS qualification

The accepted one-cell pre-run is elevated here to a separate nine-cell
qualification, never to a recovery claim.  The direct Gaussian DGP, formula,
maps, fixed kernel, two-pass BFGS baseline, and strict criteria are unchanged.
Each new receipt applies one curvature-scaled warm-start BFGS continuation.

The cells are `phi = (-.4, 0, .6)` crossed with seeds `2609371:2609373`.
They are the existing long-occasion qualification data, evaluated under a new
solver regime and retained in a distinct result directory.  The one-cell
pre-run is timing evidence only and is not pooled into the campaign.

Every cell must retain a complete receipt, including all native curvature
values, scaling, warm-start provenance, baseline and candidate endpoints, and
independent dense NLL and central-gradient checks.  A cell is strict only when
the candidate has convergence zero, non-increasing objective, outer gradient
at most `1e-3`, NLL error at most `1e-6`, and gradient error at most `1e-4`.
The nine-cell summary uses the frozen recovery thresholds; any failure remains
retained and prevents a recovery or admission claim.

The pre-run took 103 seconds.  Nine serial cells estimate to about 16 minutes;
on Totoro, use nine independent single-thread workers with BLAS pinned to one
thread.  This remains below the 30-minute campaign threshold but requires the
clean committed source to be staged remotely before execution.  No GitHub
Actions run may be used for this evidence.

## Retained execution result

Totoro executed detached commit `8d68950921c4eae9dc0cb420e78117d59bc73c1f`
on 2026-09-13 with nine independent single-thread workers and BLAS pinned to
one thread. All nine receipts were retained locally. The executable receipt
verifier checked their identities, optimizer histories, independent NLL and
central-gradient oracles, and the frozen per-persistence recovery summaries.
Every `phi = (-.4, 0, .6)` cell passed. The largest mean absolute persistence
error was `.00974`, the largest median temporal covariance Frobenius error was
`.04585`, the largest median kernel-variance relative error was `.17593`, and
the largest mean fixed-effect error was `.05901`.

This qualifies the named nine-cell long-occasion temporal--kernel fixture under
this solver regime only. It does not establish general recovery, interval
coverage, source-combination admission beyond its existing contract,
cross-platform verification, merge, or release readiness.
