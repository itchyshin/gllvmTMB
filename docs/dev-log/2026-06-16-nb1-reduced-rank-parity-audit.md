# NB1 Reduced-Rank Bridge Parity Audit

## Purpose

Check whether the NB1 bridge can move beyond no-latent fitted-object parity to
reduced-rank (`d = 1`) native-vs-Julia fitted-object parity.

## Verdict

Do **not** promote reduced-rank NB1 parity yet.

The source parameterisation is aligned and the no-latent fitted object matches
native `gllvmTMB`, but reduced-rank fits still show objective and nuisance/
loading allocation drift. The drift is not solved by simply tightening the Julia
grouped NB1 optimiser tolerance, and the closest small fixtures are dominated
by NB1 dispersion boundary behaviour.

## Evidence Summary

All probes used the same R-side formula shape:

```r
value ~ 0 + trait + latent(0 + trait | unit, d = 1)
```

with `family = nbinom1()`, complete balanced two-trait data, and the paired
Julia runtime at `GLLVM.jl-integration@903b5b9`.

### Existing grouped-dispersion fixture

The small fixture already used by `test-julia-bridge.R` fits both engines with
matching `df = 6`, but native TMB and Julia are not objective-equivalent:

```text
native convergence = 0
logLik_julia       = -51.4272640583
logLik_tmb         = -52.4618425767
delta              =  1.034579
phi_julia          = 6.475e-08, 1.091e-09
phi_tmb            = 2.997e-07, 3.960e-08
```

The loadings are similar, but the objective gap is too large for a parity row.

### Boundary-dominated deterministic fixtures

Rounded deterministic latent fixtures with `n = 40` gave close objectives, but
native TMB generally returned convergence code `1` under `nlminb`. Switching to
`optim`/BFGS sometimes returned convergence code `0`, but the fits remained
near the NB1 `phi -> 0` boundary:

```text
scale = 1, BFGS: delta = -6.5713e-04, phi_tmb = 3.73e-05, 2.01e-07
scale = 2, BFGS: delta = -2.3405e-03, phi_tmb = 1.28e-05, 3.77e-05
scale = 4, BFGS: delta =  3.3301e-04, phi_tmb = 2.09e-05, 1.87e-04
```

These are useful numerical diagnostics, but they are not clean reduced-rank NB1
parity evidence because the nuisance parameters sit on or near the boundary.

### Non-boundary seed search

A small seed search over `n in {30, 60, 120}` and seeds `1:8`, with true
overdispersion `phi = c(1.5, 2.5)`, did not find a tight non-boundary parity
fixture. The best converged non-boundary candidate across default, BFGS, and
residual-start native controls was:

```text
n                 = 30
seed              = 8
native convergence = 0
df_julia, df_tmb  = 6, 6
delta             = -0.07678
min(phi_tmb)      = 1.339
max phi delta     = 1.73
lambda_julia      = -0.1066, 0.7140
lambda_tmb        =  0.1672, -0.5420
```

This looks like a reduced-rank allocation / optimiser / Laplace-surface issue,
not a simple tolerance choice.

### Julia optimiser tolerance probe

Direct calls to `GLLVM.fit_nb1_gllvm_grouped(..., K = 1)` with
`g_tol` tightened from `1e-5` to `1e-11` did not move the fitted values on the
deterministic fixtures. The Julia path was already converged to its current
local optimum by the default tolerance.

## Interpretation

NB1 is currently in three evidence tiers:

| Tier | Status | Evidence |
| --- | --- | --- |
| Source parameterisation | covered | `Var = mu * (1 + phi)`, native `phi_nbinom1`, Julia `phi` |
| No-latent fitted object | covered | `value ~ 0 + trait`, `df = 4`, logLik delta `4.253763e-08` |
| Reduced-rank fitted object | blocked/partial | `d = 1` objective and parameter allocation drift |

The next technical owner should treat this as a Gauss/Karpinski investigation:
compare the reduced-rank NB1 marginal objective at the **same** parameters on
both sides, then separate objective-form drift from optimiser/local-mode drift.

## Claim Boundary

Allowed wording:

- NB1 bridge source scale is aligned with native `gllvmTMB`.
- NB1 bridge has no-latent fitted-object parity on the small fixture.
- Reduced-rank NB1 bridge parity remains partial and should not be advertised.

Blocked wording:

- "NB1 bridge parity is complete."
- "Grouped NB1 reduced-rank fits match native TMB."
- Any speed or inference claim for NB1 reduced-rank rows.

## Next Actions

1. Add a fixed-parameter reduced-rank NB1 objective comparison against native TMB
   if a stable native objective-evaluation path can be exposed.
2. Check whether boundary handling should use a shared lower bound or profiling
   convention across R/TMB and Julia.
3. Only after objective-form parity is proven, revisit a fitted reduced-rank
   parity test with a non-boundary fixture.
