# Julia Per-Trait Dispersion And Ordinal Cutpoints Spec

Date: 2026-06-16

Branch: `codex/julia-per-trait-dispersion-spec`

## Purpose

Align the Julia bridge with native `gllvmTMB` for nuisance parameters that are
trait-specific in the R/TMB oracle. The decision is to move the Julia route
toward the native `gllvmTMB` contract, not to weaken the native oracle to a
shared-scalar convenience model.

This is a specification only. It does not admit new bridge rows, change public
docs, or close issues.

## Decision

1. Native `gllvmTMB` remains the oracle for `df`, `logLik`, per-trait
   dispersion, ordinal cutpoints, prediction, residuals, covariance extractors,
   fitted object shape, and post-fit accessors.
2. The R-twin default for dispersion families must be per trait. In Julia this
   means grouped-dispersion fits with `group = 1:p` for the R bridge default.
   Shared scalar dispersion may remain an explicit internal/debug option, or an
   intentional comparator for an R-side shared-dispersion model, but it is not
   the default bridge parity claim.
3. Ordinal parity requires trait-specific cutpoints in Julia. The current shared
   cutpoint vector is useful engine functionality but cannot be used for a full
   native-`gllvmTMB` ordinal parity claim.
4. Every payload crossing the bridge must be trait-labelled and scale-labelled.
   The Julia payload can carry engine-native nuisance parameters, but the R side
   must map them to the native `gllvmTMB` public scale before extractors or
   summaries compare against the oracle.
5. Capability rows move only after implementation, direct Julia tests, R bridge
   parity tests, CI/status handling, validation rows, and claim wording agree.

## Current Truth

| Surface | Current state | Implication |
| --- | --- | --- |
| Native `gllvmTMB` | Dispersion-family nuisance parameters are per trait where the family carries them; ordinal cutpoints are per ordinal trait. | This is the oracle. |
| `GLLVM.jl-integration` grouped dispersion | `fit_nb_gllvm_grouped`, `fit_nb1_gllvm_grouped`, `fit_beta_gllvm_grouped`, and `fit_gamma_gllvm_grouped` exist. Tests check that constant per-trait vectors reduce to shared scalar likelihoods, and smoke tests exercise per-species/grouped fits. | The engine is not starting from zero for dispersion. The remaining R-twin gap is bridge routing, scale mapping, and admission tests. |
| `GLLVM.jl-integration` bridge one-part route | `bridge_fit` currently calls the shared scalar one-part fitters for NB2, NB1, Beta, and Gamma, fills `dispersion = fill(fit.<scalar>, p)`, and counts `+1` nuisance parameter in `df`. | This is not native `gllvmTMB` parity for the default R bridge. |
| `GLLVM.jl-integration` ordinal route | `OrdinalFit` has one ordered cutpoint vector `tau` shared across traits and reports `df = rr_df + C - 1`. | Per-trait ordinal cutpoints still need engine work before bridge parity. |
| Main `gllvmTMB` branch | Current `origin/main` has the lean Julia bridge surface. The fuller `origin/engine-julia` branch remains a draft/next-release bridge lane with conflicts against current main. | Land this spec as planning evidence; do not merge or advertise bridge parity from it. |

## Dispersion Shape Contract

For a `p`-trait response matrix, the Julia bridge should carry both group-level
and trait-expanded nuisance fields.

Required bridge fields for grouped dispersion fits:

```text
trait_names              :: Vector{String}      length p
dispersion_group         :: Vector{Float64}     length G, engine-native scale
dispersion_group_id      :: Vector{Int}         length p, ids in 1..G
dispersion               :: Vector{Float64}     length p, expanded engine-native scale
dispersion_parameter     :: String              "r", "phi", or "alpha"
dispersion_engine_scale  :: String              human-readable variance rule
dispersion_public_scale  :: String              native gllvmTMB public-scale rule
```

Default R-twin grouping:

```text
G = p
dispersion_group_id = 1:p
```

Intentional shared grouping:

```text
G = 1
dispersion_group_id = rep(1, p)
```

Shared grouping must be explicit in the call, capability row, test name, and
claim boundary. A scalar-looking `dispersion` vector produced by filling a shared
fit is not enough evidence for per-trait parity.

## Family Scale Map

The implementation must verify these mappings against `src/gllvmTMB.cpp` and
`R/fit-multi.R` immediately before code changes. The table is the design target
for the bridge, not a substitute for Gauss/Noether source review.

| Family | Julia engine parameter | Julia variance rule | R public/native map |
| --- | --- | --- | --- |
| NB2 / `nbinom2` | `r_t` size | `Var = mu + mu^2 / r_t` | For gllvm-style dispersion, `phi_t = 1 / r_t`. For the `gllvmTMB` variability-oriented `sigma`, `sigma_t = 1 / sqrt(r_t)` under the current design note. |
| NB1 / `nbinom1` | `phi_t` | `Var = mu * (1 + phi_t)` | Identity on the model overdispersion scale; the public `sigma` wording in `docs/design/03-likelihoods.md` must be checked before extractor mapping. |
| Beta | `phi_t` precision | `Var = mu * (1 - mu) / (1 + phi_t)` | `sigma_t = 1 / sqrt(phi_t)` for the variability-oriented public scale. |
| Gamma | `alpha_t` shape | `Var = mu^2 / alpha_t` | `sigma_t = 1 / sqrt(alpha_t)` for the coefficient-of-variation public scale. |

`Tweedie` has grouped dispersion support on the Julia side, but it is outside
the immediate R bridge parity slice unless the family is separately admitted in
the bridge matrix.

Gaussian per-species variance is also a related parity topic, but this spec's
implementation slice is NB2, NB1, Beta, Gamma, and ordinal cutpoints.

## Dispersion `df` And `logLik`

For a complete no-X one-part reduced-rank fit with `p` traits, rank `K`, and
`G` dispersion groups:

```text
rr_df = p * K - K * (K - 1) / 2
df    = p + rr_df + G
```

For the R-twin default, `G = p`. For intentional shared dispersion, `G = 1`.
`df` must be exact. `logLik` must be reported on the same likelihood criterion
and approximation route used by the fit. Do not compare ML and REML; non-Gaussian
REML remains unsupported.

No-X point rows should promote before X rows. For X rows, the implementation
must decide whether a grouped-dispersion covariate fitter exists for that family;
if it does not, the R bridge should keep the row gated or explicitly mark it as
shared-dispersion-only, not silently reuse the no-X claim.

## Ordinal Cutpoint Contract

The current Julia ordinal family uses one ordered cutpoint vector shared across
traits. Native `gllvmTMB` parity needs trait-specific cutpoints.

Required bridge fields for per-trait ordinal fits:

```text
trait_names       :: Vector{String}      length p
n_categories      :: Vector{Int}         length p
cutpoints         :: Matrix{Float64}     p x max(n_categories - 1), NaN padded
cutpoint_mode     :: String              "per_trait" or "shared"
cutpoint_link     :: String              "logit" or "probit"
```

Engine parameterization target:

```text
tau[t, 1] = psi[t, 1]
tau[t, c] = tau[t, c - 1] + exp(psi[t, c])  for c > 1
```

Trait-specific category counts are allowed. For a trait with `C_t` categories,
that trait contributes `C_t - 1` free cutpoints. For shared category count `C`,
the native parity `df` contribution is `p * (C - 1)`, not `C - 1`.

Ordinal `df` target:

```text
df = rr_df + sum_t (C_t - 1)
```

Shared cutpoints may remain available as `cutpoint_mode = "shared"` for Julia
experiments or source comparisons, but an R bridge row using that mode must be
labelled partial/shared-cutpoint, not native parity.

## Implementation Sequence

1. Julia direct tests first.
   - Keep existing grouped-dispersion exact-reduction tests.
   - Add tests that `bridge_fit` routes NB2, NB1, Beta, and Gamma no-X complete
     rows through the grouped fitters by default.
   - Add tests that `df` changes from `+1` to `+p` under default per-trait
     grouping.
   - Add trait-label tests for `dispersion`, `dispersion_group`, and
     `dispersion_group_id`.
2. R bridge routing second.
   - Decode the new payload fields.
   - Map engine-native nuisance values to the R public scale used by native
     extractors.
   - Keep `gllvm_julia_capabilities()` and `GLLVM.bridge_capabilities()` in
     lockstep.
3. Native parity tests third.
   - Fit small native `gllvmTMB` oracle fixtures and Julia bridge fixtures for
     NB2, NB1, Beta, and Gamma no-X point rows.
   - Require exact `df`, matching trait labels, finite convergence/status, and
     same-scale nuisance estimates.
   - Use fixed-parameter likelihood kernel checks at machine precision where
     possible; use fitted-object tolerances only where optimiser paths differ.
4. Ordinal engine work fourth.
   - Add an `OrdinalPerTraitFit` or equivalent trait-specific cutpoint mode.
   - Preserve current shared-cutpoint tests.
   - Add per-trait cutpoint recovery, `df`, prediction-probability, class
     prediction, and extractor tests.
5. R admission last.
   - Promote rows in the capability matrix only after implementation, tests,
     CI/status wording, docs, validation rows, and issue comments agree.

## Minimum Test Matrix

| Row | First admissible depth | Required tests |
| --- | --- | --- |
| NB2 no-X complete | Point parity | grouped route, `df = p + rr_df + p`, `r <-> sigma/phi` map, native-vs-Julia `logLik`, trait labels |
| NB1 no-X complete | Point parity | grouped route, identity overdispersion map, `df`, native-vs-Julia `logLik`, trait labels |
| Beta no-X complete | Point parity | grouped precision route, `sigma = 1 / sqrt(phi)`, `df`, native-vs-Julia `logLik`, trait labels |
| Gamma no-X complete | Point parity | grouped shape route, `sigma = 1 / sqrt(alpha)`, `df`, native-vs-Julia `logLik`, trait labels |
| Ordinal no-X complete | Point parity plus prediction payload | per-trait cutpoint engine, `df = rr_df + sum(C_t - 1)`, probability prediction, class prediction, `extract_cutpoints()` parity |
| Masked dispersion rows | Planned after no-mask | grouped route with mask, observed-cell `nobs`, native-vs-Julia point parity, explicit CI-status |
| X dispersion rows | Planned after no-X | grouped-dispersion X fitter or explicit shared-only gate; no silent scalar fallback |
| CI/status rows | Planned after point parity | unavailable-CI status until Wald/profile/bootstrap endpoints are validated |

Suggested fitted-object tolerances for first promotion:

```text
df: exact integer equality
trait labels and family labels: exact
fixed-parameter likelihood kernels: abs(delta) <= 1e-10 where available
fitted native-vs-Julia logLik: abs(delta) <= 1e-4 unless the issue row records
  a stricter family-specific tolerance
nuisance scale conversion: exact formula check plus estimate tolerance recorded
  per family
```

## Issue And Claim Boundary

Implementation should update `gllvmTMB#488` because this is a gate-vs-engine drift
case: engine pieces exist for grouped dispersion, but the bridge default still
routes scalar one-part fits.

Potential Julia issue links to refresh when implementation begins:

- `GLLVM.jl#98` if per-response family or bridge family dispatch is touched.
- `GLLVM.jl#91/#96` if Laplace robustness, Hessian behaviour, or convergence
  gates block promotion.

Do not close any issue from this spec. Issue action requires live issue reads,
linked local evidence, and Shannon/Rose signoff.

## Non-Scope

This spec does not implement:

- structural-zero fixed-effect coefficient masks (`codex/xcoef-structural-zero-spec`);
- observation-by-response covariates `z[i, j, k]`;
- mixed-family CI endpoints;
- response masks for dispersion families beyond the first planned point rows;
- structured `phylo_*`, `animal_*`, `spatial_*`, or `kernel_*` bridge support;
- non-Gaussian REML or AI-REML;
- CRAN-main bridge landing.

## Review Responsibilities

- Hopper: bridge payload and R decoding contract.
- Karpinski: Julia grouped/ordinal implementation and allocation/runtime path.
- Gauss: variance rules, transforms, optimizer stability.
- Noether: equation-to-code map, `df`, `logLik`, and scale conversions.
- Fisher: inference/status and CI promotion boundary.
- Curie: direct Julia, R bridge, malformed-input, and parity tests.
- Rose: claim wording, validation rows, stale row detection.
- Shannon: coordination check before branch switches, PR opening, or issue
  closure.
