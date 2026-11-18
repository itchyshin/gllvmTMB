# Gate-A feasibility review: two-field private spatial iSDM

**Reviewer:** Gauss (independent read-only review)
**Verdict:** `CONDITIONAL_SHARED_RANGE_DESIGN_ONLY`

## Finding

The current private iSDM wrapper cannot represent a spatial term unchanged: it
hard-codes ordinary `latent()` and accepts neither mesh nor projection input.
However, the engine's augmented SPDE latent-slope route can represent a shared
ecological field plus GBIF-only bias field as
`spatial_latent(1 + isdm_gbif | cell_id, d = K)`.  The intercept field reaches
GBIF and PA rows; the indicator field is zero in PA rows.

## Non-negotiable limits

1. The two fields share one mesh, SPDE range, and rank.  Separate ranges or
   meshes require a future TMB architecture, not an interpretation of the
   existing route.
2. The public augmented-slope path rejects the PA cloglog link.  Any admission
   must be private and exact to the existing GBIF Poisson/log plus PA
   Bernoulli/cloglog source contract.
3. One augmented spatial term only is admissible.  Adding two terms is not a
   substitute for the intercept-plus-indicator construction.
4. Tests must prove PA eta/NLL invariance to GBIF-field perturbation, aligned
   mesh projection, mixed-family oracle parity, and no one-field collapse.

## Evidence inspected

- `R/isdm-developer-fit.R`: private wrapper currently fixes ordinary latent
  form and creates `isdm_gbif`.
- `R/fit-multi.R`: augmented spatial-latent formula construction and public
  link guard.
- `src/gllvmTMB.cpp`: field-score allocation, row-wise projected-field
  multiplication, and shared `log_kappa_spde` prior.

No source, likelihood, map, threshold, test, compilation, fit, simulation, or
profile was modified by this review.
