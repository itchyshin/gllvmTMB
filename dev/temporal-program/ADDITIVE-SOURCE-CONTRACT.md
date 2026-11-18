# Additive temporal-source contract

## Scope

This contract admits one temporal intercept source together with exactly one
static source: `spatial_*`, `phylo_*`, `animal_*`, or `kernel_*`. It is limited
to Gaussian identity-link ML/Laplace, source `rho = 1`, no temporal slopes,
rank-one temporal latent terms, and source modes already implemented for the
chosen source.

For observation `i`, temporal series `g_i`, time `t_i`, source level `h_i`, and
trait `j_i`, the covariance is

\[
V_{ii'} = I(g_i=g_{i'}) r_T(t_i,t_{i'}) [\Sigma_T]_{j_i j_{i'}}
+ K_S(h_i,h_{i'}) [\Sigma_S]_{j_i j_{i'}} + [V_B+V_W+D_\epsilon]_{ii'}.
\]

The two random fields are independent before observing data. Posterior
components need not remain independent and forecast uncertainty must use the
full joint covariance.

## What this is not

This contract does not admit `K_S(h_i,h_{i'}) r_T(t_i,t_{i'}) Sigma_ST`.
That product is a source-by-time interaction: an evolving spatial field or
time-correlated phylogenetic/animal/kernel process. It needs its own state,
normalization, prediction, simulation and recovery contract.

It also does not admit two non-temporal structured sources alongside time,
estimated source attenuation, outcome-derived kernels, temporal rank above one,
or non-Gaussian temporal likelihoods.

## Pair-specific admission

| Pair | Required input and guard | Identification control |
|---|---|---|
| temporal + spatial | fixed coordinates/mesh and projected static field; series and coordinate labels are distinct | reject trajectory fixtures where distance and lag bases are proportional; retain range/persistence diagnostics |
| temporal + phylo | fixed labelled tree/VCV; series maps to a declared tip/unit partition | retain repeated-time and related-tip contrasts; flag near-constant temporal process competing with lineage field |
| temporal + animal | declared pedigree/relationship matrix with provenance preserved | reject identity-like relationship matrices when an ordinary unit effect creates the same basis |
| temporal + kernel | fixed labelled, externally supplied kernel | reject proportional temporal and kernel covariance bases; no outcome-trained kernel |

## Acceptance evidence for every pair

1. Independently construct the additive observation covariance and compare
   normalized Gaussian NLL and central gradients with native TMB.
2. Show that a deliberately substituted product kernel differs from the stated
   additive model.
3. Preserve temporal series/time and source labels through long/wide rewriting,
   row permutation, update/refit and extraction.
4. Simulate the complete joint model and compare mean/covariance moments with
   the same dense oracle; retain failed fits in recovery fixtures.
5. Test source-specific malformed inputs and each excluded interaction route.

## Implementation map

The initial fence appears in `R/temporal.R` and `R/gllvmTMB.R`. Engine effects
already enter additively in `src/gllvmTMB.cpp`: temporal at the response
predictor and the source-specific spatial, phylogenetic and kernel routes in
later predictor additions. Before relaxing either fence, the implementation
must prove which existing source terms can co-occupy current R/TMB slots and
must map every unsupported source mode off explicitly.
