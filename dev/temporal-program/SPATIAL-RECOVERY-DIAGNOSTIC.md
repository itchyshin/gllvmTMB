# Spatial recovery diagnostic

## Question

The retained 80-series spatial campaign is partial because its positive-AR1
cell has unstable spatial scale and range estimates. This note checks whether
that reflects an SPDE parameter-scale mismatch between the independent DGP and
the native likelihood before proposing any new fixture.

## Parameterization check

The direct DGP in `run-spatial-recovery.R` draws each field as

\[
\omega_t = \tau_t^{-1} Q(\kappa)^{-1/2}z_t,
\qquad Q(\kappa)=\kappa^4M_0+2\kappa^2M_1+M_2.
\]

The native likelihood constructs the same `Q_base` in
`src/gllvmTMB.cpp` and applies `SCALE(GMRF(Q_base), 1/tau)` to each
trait field. Thus the recovery comparison correctly uses `exp(log_tau_spde)`
against the DGP's `tau`, not its reciprocal.

For this Matérn-SPDE parameterization the marginal SD is

\[
\sigma_t = (\sqrt{4\pi}\,\kappa\tau_t)^{-1}.
\]

It is therefore also useful to inspect this derived quantity rather than only
the native `tau` coordinates.

## Retained evidence

The frozen campaign has ten attempts per persistence value. Strict
convergence counts are 10/10 at `phi = -0.4`, 9/10 at `phi = 0`, and 8/10 at
`phi = 0.6`.

For the strict attempts, median relative errors for the derived spatial SDs
are `(0.092, 0.195, 0.139)` at `phi = -0.4`, `(0.100, 0.235, 0.243)` at
`phi = 0`, and `(0.435, 0.425, 0.996)` at `phi = 0.6`. Median relative range
(`kappa`) errors are `0.209`, `0.297`, and `1.542`, respectively.

The bad positive-persistence cell therefore remains bad on the derived
scientific scale; it is not repaired by re-expressing `tau`. The existing
partial verdict and frozen thresholds stand.

## Next evidence, if pursued

A follow-up must be a separately named, predeclared spatial design with more
independent locations and fresh fixed seeds. It must retain this failed
80-series fixture, use the direct SPDE DGP again, and report both native
`tau`/`kappa` and derived spatial-SD errors. It cannot replace the current
receipt or silently revise its thresholds.
