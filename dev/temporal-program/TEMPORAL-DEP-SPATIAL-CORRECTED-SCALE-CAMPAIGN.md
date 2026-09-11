# Corrected-scale dependent temporal--spatial recovery campaign

## Status

**Pre-run retained; full campaign held for a compute decision.** This is a new, isolated campaign. It does not amend,
replace, or reinterpret the four frozen `dep-spatial-recovery-20260911`
attempts.

## Purpose and scope

The native model is the replicated Gaussian AR1 `temporal_dep() +
spatial_indep()` cell described in `TEMPORAL-DEP-SPATIAL-CONTRACT.md`. Its
direct DGP creates a non-diagonal stationary temporal field, trait-diagonal
SPDE fields, and measurement noise. This campaign measures only the named
fixed fixture; it cannot make a general recovery, coverage, cross-platform,
release, forecast, interval, profile, bootstrap, selection, OU,
temporal-latent/Psi, or wider-source claim.

## Corrected estimand and immutable boundary

The DGP samples each SPDE draw divided by `tau`, while native TMB stores
`tau = exp(log_tau_spde)`. This campaign compares `exp(log_tau_spde)` to the
precision-scale truth `(0.85, 1.10, 1.35)`. The older four receipts compared
the inverse and remain timing/optimizer history only.

The fixture, seeds, optimizer, two-pass rule, and thresholds are otherwise
unchanged: 80 series, 16 occasions, two measurements, three traits,
`phi = (-.4, 0, .6)`, and seeds `2609331:2609333`. Every planned attempt must
be retained, including errors and failed criteria. There is no replacement,
retry, threshold relaxation, or changed optimizer.

## Receipt protocol

The only accepted execution entry point is:

```sh
DEP_SPATIAL_CAMPAIGN=corrected-scale-20260911 \
  DEP_SPATIAL_ONE=<1..9> \
  Rscript --vanilla dev/temporal-program/run-dep-spatial-recovery.R
```

It writes one result and one phase receipt under
`dev/temporal-program/results/corrected-scale-20260911/`. A pre-existing
result or phase receipt rejects the attempt before fitting. The legacy runner
path rejects before fitting, as does a corrected-campaign invocation without
an explicit attempt index. After all nine terminal receipts exist, only
`--finalize` may construct the campaign summary.

## Fixed decision rule

Within each persistence stratum, all three attempts must have terminal success,
optimizer code zero, an accepted second pass, and maximum outer gradient at
most `1e-3`. The frozen summary then requires mean/median absolute persistence
error at most `.15`/`.20`, median temporal-covariance relative Frobenius error
at most `.30`, median relative errors at most `.35` for each `tau`, at most
`.50` for `kappa`, and mean absolute fixed-effect error at most `.25`.

## Compute gate

The previous non-retained smoke was stopped at 37 seconds after exceeding its
11.797-second historical estimate and had no terminal outcome. It is therefore
not a valid pre-run. The retained first cell (`phi=-.4`, `seed=2609331`) then
completed in 19.693 seconds with terminal success, both optimizer passes
accepted, and maximum outer gradient `1.1863489e-05`; its result and final
phase receipts are in the campaign directory. A straight-line nine-cell
projection is about three minutes, but the same fixture family also has a
retained 215.571-second fit-only tail. A conservative serial projection
therefore exceeds 30 minutes. Obtain a distinct compute decision before the
remaining eight cells, then route them to Totoro or DRAC with one BLAS thread
and at most four local cores.
