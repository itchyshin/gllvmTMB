# NB1 Reduced-Rank Bridge Fisher-Boundary Fix

## Purpose

Record the paired R/Julia evidence that resolves the small-fixture reduced-rank
NB1 bridge gap found earlier on 2026-06-16.

## Diagnosis

The R and Julia NB1 source parameterisation already agreed:

```text
Var(y | mu, phi) = mu * (1 + phi)
```

The gap came from the Julia expected-information helper near `phi -> 0`.
`GLLVM._nb1_fisher_mu(mu, phi)` used a trigamma-difference expression divided
by `phi^2`. At `phi = 1e-9`, cancellation made the Fisher information collapse
to `1e-12` for ordinary `mu`, even though the Poisson-limit value should be
near `1 / mu`. That made the Julia Laplace log-determinant too favourable for
boundary NB1 reduced-rank fits.

## Fix

The paired Julia runtime now uses the Poisson-limit branch
`1 / (mu * (1 + phi))` for `phi <= 1e-6`, with regression coverage in
`GLLVM.jl-integration/test/test_nb1.jl`.

## Evidence

Targeted Julia check:

```sh
julia --project=. test/test_nb1.jl
```

Result: `34/34 pass`.

Live R bridge check:

```sh
GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge", reporter = "summary")'
```

Result: completed cleanly.

Reduced-rank NB1 fixture after the fix:

```text
formula       = value ~ 0 + trait + latent(0 + trait | unit, d = 1)
family        = nbinom1()
native logLik = -52.4618425767
Julia logLik  = -52.4619219625
df            = 6 on both sides
delta         = -7.9386e-05
```

Fixed-parameter cross-check:

```text
Julia objective at native fitted parameters = -52.4618425607
native TMB objective at native parameters   = -52.4618425772
delta                                       =  1.65e-08
```

## Claim Boundary

Allowed wording:

- NB1 bridge source scale is aligned with native `gllvmTMB`.
- NB1 bridge has no-latent fitted-object parity on the small fixture.
- NB1 bridge has reduced-rank (`d = 1`) fitted-object point parity on the small
  complete balanced fixture.

Still blocked:

- NB1 bridge confidence intervals.
- NB1 bridge masks and non-Gaussian fixed-effect covariates.
- Broad NB1 simulation recovery or speed claims.
- Structured terms and mixed-family NB1 rows.
