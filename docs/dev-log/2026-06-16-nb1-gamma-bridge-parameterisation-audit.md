# NB1/Gamma Bridge Parameterisation Audit

Date: 2026-06-16

Branch: `codex/r-bridge-grouped-dispersion`

Reader: bridge implementers, validation-row auditors, and issue triagers for
`gllvmTMB#488` and the twin finish programme.

Purpose: resolve the follow-up left by the grouped-dispersion main-dispatch
smoke. NB1 and Gamma both route through the Julia grouped-dispersion payload, but
only rows whose parameterisation matches the native R/TMB oracle can be promoted
from route/shape evidence to native parity.

This audit changes no code and closes no issue.

## Source Map

| Row | Native `gllvmTMB` source | Julia source | R bridge source | Finding |
| --- | --- | --- | --- | --- |
| NB1 | `src/gllvmTMB.cpp` `fid == 15`, `phi_nbinom1` report | `src/families/negbin1.jl`, `src/families/grouped_dispersion.jl` | `R/julia-bridge.R` public map | Same model scale: `Var = mu * (1 + phi)`. The remaining parity gap is evidence/optimisation, not a scale mismatch. |
| Gamma | `src/gllvmTMB.cpp` `fid == 4`, scalar `sigma_eps` CV | `src/families/gamma.jl`, `src/families/grouped_dispersion.jl` | `R/julia-bridge.R` public map | Current native oracle is shared-CV; Julia grouped Gamma is per-trait/grouped shape `alpha`. This is useful engine functionality but not native parity today. |

## NB1 Decision

NB1 is aligned at the parameterisation level.

Native `gllvmTMB` uses the linear-variance NB1 model
`Var(y) = mu * (1 + phi)` and reports one `phi_nbinom1` value per trait. The
Julia NB1 family uses the same variance rule and the same public bridge scale:
`phi` is the overdispersion, not an NB2-style reciprocal size.

The current `JUL-01` limitation for NB1 should therefore stay narrow:

- IN: route/shape evidence through `gllvmTMB(..., engine = "julia")`, trait
  labels, grouped `phi` payload, native report-shape check, and fixed-parameter
  kernel evidence. The fixed-parameter check in `test-julia-bridge.R` evaluates
  Julia `nb1_grouped_marginal_loglik_laplace()` with zero loadings and compares
  it to the native linear-variance kernel
  `dnbinom(mu = mu, size = mu / phi)`. The follow-up no-latent fitted-object
  test fits `value ~ 0 + trait` with `engine = "julia"` and `engine = "tmb"`,
  confirming exact `df`, trait/unit labels, NB1 `phi` scale, and fitted
  log-likelihood parity on the small fixture.
- PARTIAL: reduced-rank (`K > 0`) fitted-object log-likelihood parity and
  broader estimator parity.
- NEXT: a stable reduced-rank NB1 fitted fixture before the row can move beyond
  no-latent plus route/kernel evidence.

## Gamma Decision

Gamma is now aligned with the current native oracle for the bridge parity path,
using shared grouping.

Ordinary native Gamma in `gllvmTMB` uses scalar `sigma_eps` as the coefficient of
variation. The likelihood is
`shape = 1 / sigma_eps^2`, `scale = mu / shape`, so all traits share the same
Gamma CV in the current native route. The simulation path in
`R/methods-gllvmTMB.R` uses the same scalar `sigma_eps`.

Julia grouped Gamma estimates `alpha_g` and supports per-trait grouping
(`group = 1:p`), with `Var = mu^2 / alpha_t`. The bridge now routes ordinary
Gamma with one shared group (`group = rep(1, p)`) so the public
`sigma = 1 / sqrt(alpha)` vector expands the same scalar coefficient of
variation native `gllvmTMB` reports as `sigma_eps`.

The decision table remains useful for the later per-trait Gamma expansion:

| Option | What changes | Upside | Cost |
| --- | --- | --- | --- |
| A. Expand native `gllvmTMB` Gamma | Add per-trait Gamma CV/shape in TMB/R, plus reports, maps, simulation, tests, docs, and extractors. | Matches the original per-trait nuisance target for NB2/NB1/Beta/Gamma. | Larger native family change; needs Gauss/Noether/Fisher review and recovery tests. |
| B. Use shared Gamma grouping in the Julia bridge when claiming oracle parity | Route bridge Gamma with `G = 1` until native per-trait Gamma exists; keep Julia grouped Gamma as engine-internal/experimental. | Fastest path to honest `df`/`logLik` parity against the current native oracle. | Defers the per-trait Gamma ambition and must be labelled clearly. |
| C. Keep current per-trait Gamma bridge route but do not promote parity | Leave the route as useful route/shape evidence only. | No behavior churn. | The public row remains partial and cannot support native parity claims. |

Decision implemented in the paired bridge runtime: **Option B**. It preserves
the native-oracle rule and avoids a false per-trait Gamma parity claim while
leaving Julia grouped Gamma available for the larger native per-trait Gamma
design.

Small-fixture evidence after the route change:

- Julia Gamma `logLik = 17.595906505513`.
- Native TMB Gamma `logLik = 17.595906784863`.
- Delta `-2.7935e-07`.
- `df = 5` for both engines.
- Julia `dispersion_group_id = c(1, 1)`.
- Julia public `sigma = c(0.0077397024, 0.0077397024)`, matching native
  `sigma_eps = 0.0077397018`.

## Issue And Capability Impact

- `gllvmTMB#488`: this is a bridge gate-vs-engine drift case plus an oracle-shape
  mismatch. The issue should not be closed until each gate has an explicit row
  saying whether it is engine support, bridge routing, or statistical design.
- `gllvmTMB#340`: the public capability board should treat Gamma bridge
  grouped-dispersion as `partial` unless one of the decisions above lands.
- `GLLVM.jl#91/#96`: relevant if reduced-rank NB1 fitted-object parity is
  blocked by Laplace robustness or optimizer behavior rather than source
  parameterisation.
- `GLLVM.jl#98`: relevant if family dispatch/payload shape changes during the
  bridge cleanup.

## Next Tests

1. NB1 stable reduced-rank fitted fixture:
   require exact `df`, finite status, trait labels, `phi` scale identity, and a
   recorded tolerance for fitted log-likelihood when `K > 0`.
2. Gamma shared-oracle bridge test:
   now covered in `tests/testthat/test-julia-bridge.R` and
   `GLLVM.jl-integration/test/test_bridge_grouped_dispersion.jl`: Gamma uses
   one dispersion group, exact `df = p + rr_df + 1`, native-vs-Julia `logLik`
   parity on the small complete balanced fixture, and public `sigma` equality
   to native `sigma_eps`.

## Team Dispatch

- Ada: keep Option B as the bridge default until a native per-trait Gamma
  expansion is explicitly opened.
- Hopper: keep shared Gamma bridge grouping tested and labelled.
- Karpinski: keep Julia grouped Gamma available and labelled by engine scale.
- Gauss/Noether: review Gamma CV/shape equations before any native TMB change.
- Fisher/Curie: design the NB1 fixed-parameter check and Gamma decision test.
- Rose: block wording that says Gamma native parity while the oracle is scalar.
- Shannon: require a live issue read before commenting on or closing `#488`.
