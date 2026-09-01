# Measured-compute checkpoint

The authorized 32-attempt retained pilot is complete. No retained attempt after
the first replication in each cell has been launched.

## Exact inputs

- Candidate commit: `9c6746cb58c6a83726b194bf87068c7921809570`
- Candidate bundle: `78e17ceb0c4589fff1c7983949a9f7cdfaa80e4e4699d0ab75870764d15d3383`
- Frozen-fixture manifest SHA-256:
  `692380327512a8ede39849eab813319469948d96c477f86b190e4f85d90181c3`
- Compact checkpoint archive SHA-256:
  `91e8fd30e6a23e981e0af61107454010561719f4e81ab1461d4048dd645f6baf`
- Totoro archive:
  `/home/snakagaw/spatial-rho-pilot-9c6746cb5-compact.tar.gz`

The frozen manifest accounts for 800 datasets and 1,600 unique fit jobs. The
pilot is the first replication from each of the 16 regime/form/strength cells,
with paired fixed and estimated fits: 32 attempts inside the 1,600-attempt
budget. Coordinates, mesh objects, source-level projections, SPDE matrices,
source covariances, trait covariances, seeds, formulas, controls, and all data
files are hashed in the manifest. The compact Git receipt omits the 800 data
RDS files but retains their individual hashes.

## Execution receipt

- Wall time: 16.71 seconds.
- Attempts: 32 planned, 32 launched, 32 returned.
- Strict numerical successes: 31/32 (96.9%).
- Process errors, timeouts, missing results, and optimizer-entry violations: 0.
- Maximum resident memory for one worker: 420,728 KiB (0.401 GiB), versus the
  8 GiB per-worker stop rule.
- Mean attempt work time: 4.79 seconds; total work: 153.18 seconds.
- Estimated simultaneous memory at 12 observed peak-size workers: about
  4.8 GiB. The plan declares no aggregate-memory threshold.

Linear projections for the remaining 1,568 attempts are 10.4 minutes from
total work divided over 12 workers, or 13.6 minutes using observed pilot wall
time. Allowing overhead, the operational projection remains below 20 minutes
and well below the two-hour stop rule. This projection is not a timing promise.

## Failure and scientific warning

One attempt, irregular-long rank-one latent at generating `rho = 0.3` with
estimated rho, returned convergence code zero and a positive-definite reported
Hessian but failed the gradient rule (`max|gradient| = 0.147`). It placed rho
at zero and estimated `kappa = 0.071` versus truth `0.7`. The receipt remains in
the all-attempt denominator.

Across the 16 estimated fits, five reached a rho boundary; four of those still
met the strict numerical rule. Boundary outcomes occurred in one regular-short
cell and four irregular-long cells. Several irregular-long one-dataset estimates
also showed large rho and kappa errors. A single dataset per cell cannot support
a recovery verdict, but this is a substantive early warning that source strength
and range may compensate in the irregular-long regime.

## Checkpoint decision

The operational continuation conditions pass: the fixtures are valid, every
cell executed, no worker approached 8 GiB, the pilot stayed below 30 minutes,
and projected runtime is below two hours. The evidence does not justify any
public recovery claim yet. If continuation is approved, run the remaining
1,568 immutable jobs once, without retry, replacement seed, initialization
change, model simplification, or threshold change. The full predeclared
summaries and Fisher classification will determine whether each cell is pass,
partial, or blocked.
