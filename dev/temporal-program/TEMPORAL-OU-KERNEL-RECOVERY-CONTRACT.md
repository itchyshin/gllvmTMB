# Irregular-time OU temporal--kernel recovery contract

## Claim being checked

This fixture checks one narrow model only: replicated Gaussian
`temporal_indep(..., structure = "ou") + kernel_indep(...)` with a fixed
labelled diagonal kernel. It is direct-DGP engineering evidence for the named
fixture, not a general decay-rate recovery or interval-coverage claim.

## Frozen data-generating process

There are 80 labelled series, 12 irregular elapsed times
`(0, .4, 1.1, 2.1, 3.4, 5.0, 6.9, 9.1, 11.6, 14.4, 17.5, 21.0)`, two complete
measurements per state, and three traits. Independent stationary OU fields
have trait variances `(.55, .42, .63)^2` and rates `(.25, .70, 1.40)` across
the three fixed persistence strata. A labelled nonidentity kernel contributes
trait variances `(.35, .28, .40)^2`; independent measurement noise has SD
`.30`. Fixed trait means are `(.2, -.3, .1)`.

The simulator is written directly from these equations and never calls package
simulation. The fixed plan has rates `(.25, .70, 1.40)` and seeds
`2609371:2609373`, for nine attempts. Each fit uses the public long formula
and retains terminal state, optimizer pass history, objective, gradient,
decay-rate estimate, each variance estimate, and fixed effects.

## Frozen decision rule

An attempt is strict only with terminal success, both optimizer passes accepted
at convergence code zero, finite objective, and maximum outer gradient at
most `1e-3`. Every rate stratum needs all three strict attempts. The stratum
must also have mean and median absolute log-rate error at most `.35` and `.45`,
median relative error at most `.35` for every temporal and kernel variance,
and mean fixed-effect absolute error at most `.25`.

No seed replacement, threshold relaxation, source change, or output overwrite
is permitted. The runner requires a new output directory and a requested plan
index. A single-cell pre-run measures time only and cannot be summarized as a
recovery verdict. The completed nine-cell result remains local if the measured
serial estimate is at most 30 minutes; otherwise it needs distinct compute
approval before Totoro or DRAC execution.
