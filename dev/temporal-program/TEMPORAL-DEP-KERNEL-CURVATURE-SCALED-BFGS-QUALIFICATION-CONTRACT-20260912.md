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
