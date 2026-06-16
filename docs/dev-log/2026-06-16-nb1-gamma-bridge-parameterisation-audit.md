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
  labels, grouped `phi` payload, and native report-shape check.
- PARTIAL: fitted-object log-likelihood parity and broader estimator parity.
- NEXT: a fixed-parameter likelihood audit, then a more stable native-vs-Julia
  no-X fixture before the row can move beyond route/shape evidence.

## Gamma Decision

Gamma is not aligned at the oracle level yet.

Ordinary native Gamma in `gllvmTMB` uses scalar `sigma_eps` as the coefficient of
variation. The likelihood is
`shape = 1 / sigma_eps^2`, `scale = mu / shape`, so all traits share the same
Gamma CV in the current native route. The simulation path in
`R/methods-gllvmTMB.R` uses the same scalar `sigma_eps`.

Julia grouped Gamma estimates `alpha_g` and supports per-trait grouping
(`group = 1:p`), with `Var = mu^2 / alpha_t`. The R bridge correctly maps that
engine scale to a public `sigma_t = 1 / sqrt(alpha_t)`, but a per-trait
`sigma_t` vector is not the current native R/TMB Gamma oracle.

Gamma therefore needs an explicit maintainer decision before promotion:

| Option | What changes | Upside | Cost |
| --- | --- | --- | --- |
| A. Expand native `gllvmTMB` Gamma | Add per-trait Gamma CV/shape in TMB/R, plus reports, maps, simulation, tests, docs, and extractors. | Matches the original per-trait nuisance target for NB2/NB1/Beta/Gamma. | Larger native family change; needs Gauss/Noether/Fisher review and recovery tests. |
| B. Use shared Gamma grouping in the Julia bridge when claiming oracle parity | Route bridge Gamma with `G = 1` until native per-trait Gamma exists; keep Julia grouped Gamma as engine-internal/experimental. | Fastest path to honest `df`/`logLik` parity against the current native oracle. | Defers the per-trait Gamma ambition and must be labelled clearly. |
| C. Keep current per-trait Gamma bridge route but do not promote parity | Leave the route as useful route/shape evidence only. | No behavior churn. | The public row remains partial and cannot support native parity claims. |

Recommended default for the next bridge PR is **B unless Ada explicitly chooses
A before bridge landing**. It preserves the native-oracle rule and avoids a
false Gamma parity claim while leaving Julia grouped Gamma available for the
larger per-trait Gamma design.

## Issue And Capability Impact

- `gllvmTMB#488`: this is a bridge gate-vs-engine drift case plus an oracle-shape
  mismatch. The issue should not be closed until each gate has an explicit row
  saying whether it is engine support, bridge routing, or statistical design.
- `gllvmTMB#340`: the public capability board should treat Gamma bridge
  grouped-dispersion as `partial` unless one of the decisions above lands.
- `GLLVM.jl#91/#96`: relevant if NB1 fitted-object parity is blocked by Laplace
  robustness or optimizer behavior rather than source parameterisation.
- `GLLVM.jl#98`: relevant if family dispatch/payload shape changes during the
  bridge cleanup.

## Next Tests

1. NB1 fixed-parameter likelihood check:
   compare native and Julia kernels on the same `beta`, `Lambda`, and `phi`
   target where possible, before blaming the optimizer.
2. NB1 stable no-X fitted fixture:
   require exact `df`, finite status, trait labels, `phi` scale identity, and a
   recorded tolerance for fitted log-likelihood.
3. Gamma decision test:
   if Option B lands, assert the bridge Gamma row uses one dispersion group and
   exact `df = p + rr_df + 1`; if Option A lands, add native per-trait Gamma
   recovery and update all public scale/report paths.

## Team Dispatch

- Ada: choose Gamma Option A, B, or C before any Gamma parity wording.
- Hopper: implement bridge grouping/gate changes after the decision.
- Karpinski: keep Julia grouped Gamma available and labelled by engine scale.
- Gauss/Noether: review Gamma CV/shape equations before any native TMB change.
- Fisher/Curie: design the NB1 fixed-parameter check and Gamma decision test.
- Rose: block wording that says Gamma native parity while the oracle is scalar.
- Shannon: require a live issue read before commenting on or closing `#488`.

