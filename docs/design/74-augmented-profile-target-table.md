# Design 74 -- Augmented Structural Profile Target Table

Date: 2026-07-04; release-boundary revision 2026-07-20

Owners: Fisher, Noether, Boole, Curie, Rose, and Ada.

## Purpose

Define the symbolic targets for augmented structural random-slope profile
intervals before adding any new `confint(..., method = "profile")` route.
Several augmented point extractors and recovery tests are already covered, but a
point covariance read-out is not a calibrated likelihood-profile interval. This
note is the target map that Design 73 requires before any implementation slice.

This design promotes no route. The former Gaussian selected-entry
`rho:unit_slope:i,j` canary is retained only as an internal research prototype
and historical negative evidence. Its public route is withdrawn with all
nonlinear penalty profiles. Every augmented split profile target is `blocked`
in `.profile_route_matrix()` until a later design supplies an exact constraint
solver, exposes optimizer status, calibrates the specific target, and receives
explicit maintainer promotion.

## Shared Conventions

The current public scope is one random slope unless a row explicitly says
otherwise. Labels keep the engine's ordering:

- `unit_slope`: interleaved ordinary coefficient vector
  `(intercept.trait1, slope.x.trait1, intercept.trait2, slope.x.trait2, ...)`.
- `phy_unique_slope`: the soft-deprecated `phylo_unique(1 + x | species)`
  legacy/shared compatibility path: one shared 2 by 2 `(intercept, slope)`
  source random effect assembled from
  `report$sd_b` and `report$cor_b`. It does not describe current
  `phylo_indep()`.
- `phy_indep_slope`: current Design 79/80 `phylo_indep(1 + x | species)`;
  interleaved `2T` coefficient vector with `T` independent 2 by 2
  within-trait blocks, reported through `report$Sigma_b_dep`.
- `phy_dep`: full unstructured `(1+s)T` by `(1+s)T` source covariance with
  interleaved per-trait columns.
- `phy_slope`: `phylo_latent(1 + x | sp, d = K)` returns one `T by T`
  cross-trait matrix per LHS column. Cross-column covariance is structural zero.
- `spde_base_slope`: the `spatial_unique(1 + x | coords)` shared 2 by 2
  `(intercept, slope)` SPDE field covariance assembled from
  `report$sd_spde_b` and `report$cor_spde_b`. It does not describe current
  `spatial_indep()`.
- `spde_indep_slope`: current Design 79/80
  `spatial_indep(1 + x | coords)`; interleaved `2T` field vector with `T`
  independent 2 by 2 within-trait field blocks, reported through
  `report$Sigma_field`.
- `spde_dep`: full unstructured `2T by 2T` SPDE field covariance with
  interleaved per-trait columns.
- `spde_slope`: `spatial_latent(1 + x | coords, d = K)` returns one `T by T`
  SPDE field covariance per LHS column. Cross-column covariance is structural
  zero.

SPDE slope targets must not mix scales. Field-scale `Sigma_field` targets and
per-site marginal targets need separate denominators because marginal conversion
uses `kappa` (`sd / (sqrt(4*pi) * kappa)` or variance divided by
`4*pi*kappa^2`, depending on the reported block).

## Target Table

| Level | Point evidence | `Sigma` target | `rho` target | Communality target | Proportion target |
| --- | --- | --- | --- | --- | --- |
| `unit_slope` | `extract_Sigma(level = "unit_slope")` | `Sigma_unit_slope = Lambda_B_aug Lambda_B_aug' + Psi_B_aug` on the interleaved `2T` coefficient vector | lower triangle of `cov2cor(Sigma_unit_slope)` | coefficient-wise `diag(shared) / diag(total)`, if named as augmented coefficient communality | not public yet: must choose coefficient-wise versus trace-share denominator |
| `phy_unique_slope` | `extract_Sigma(level = "phy")` returning `level = "phy_unique_slope"` for `phylo_unique()` | `D R D` shared 2 by 2 block from `sd_b` and `cor_b` | the single shared intercept-slope correlation | not applicable; no shared-loading numerator | not public yet: block trace or coefficient denominator must be declared |
| `phy_indep_slope` | `extract_Sigma(level = "phy")` returning `level = "phy_indep_slope"` for current `phylo_indep()` | `report$Sigma_b_dep`, block-diagonal `2T` by `2T` with one free 2 by 2 block per trait | one within-trait intercept-slope correlation per trait; cross-trait entries are structural zero | not applicable; per-trait unstructured blocks have no shared-loading numerator | not public yet: coefficient-wise or trace-share denominator must match the augmented vector |
| `phy_dep` | `extract_Sigma(level = "phy")` returning `level = "phy_dep"` | `report$Sigma_b_dep`, full `(1+s)T` by `(1+s)T` block | lower triangle of `cov2cor(Sigma_b_dep)` | not applicable; full dep covariance is not a loading decomposition | not public yet: dep trace or diagonal denominator must be declared |
| `phy_slope` | `extract_Sigma(level = "phy_slope")` | list of per-LHS-column `T by T` matrices `Lambda_k Lambda_k'` | within-column lower triangle only; cross-column correlations are structural zero | per-column trait-wise share, if named as source-latent column communality | not public yet: per-column denominator must be declared |
| `spde_base_slope` | `extract_Sigma(level = "spatial")` returning `level = "spde_base_slope"` for `spatial_unique()` | shared 2 by 2 SPDE field covariance from `sd_spde_b` and `cor_spde_b` | the single shared intercept-slope field correlation | not applicable; no shared-loading numerator | not public yet: field-scale or marginal-scale denominator must be chosen |
| `spde_indep_slope` | `extract_Sigma(level = "spatial")` returning `level = "spde_indep_slope"` for current `spatial_indep()` | `report$Sigma_field`, block-diagonal `2T` by `2T` with one free 2 by 2 field block per trait | one within-trait intercept-slope field correlation per trait; cross-trait entries are structural zero | not applicable; per-trait unstructured field blocks have no shared-loading numerator | not public yet: coefficient-wise versus trace and field-scale versus marginal-scale denominators must be declared |
| `spde_dep` | `extract_Sigma(level = "spatial")` returning `level = "spde_dep"` | `report$Sigma_field`, full `2T` by `2T` field covariance | lower triangle of `cov2cor(Sigma_field)` | not applicable; full field covariance is not a loading decomposition | not public yet: field-scale or marginal-scale denominator must be chosen |
| `spde_slope` | `extract_Sigma(level = "spde_slope")` | list of per-LHS-column `T by T` field matrices `Lambda_k Lambda_k'` | within-column lower triangle only; cross-column correlations are structural zero | per-column trait-wise share, if named as SPDE-latent column communality | not public yet: per-column spatial denominator must be declared |

## Profile Gate

There is no public first canary at the 0.6 boundary. The former Gaussian
`unit_slope` selected-entry `rho:unit_slope:i,j` prototype demonstrated parser
and target plumbing, but it did not establish a reliable nonlinear profile
interval. Restoration of any selected route requires all of the following:

1. An exact or independently tolerance-certified constraint solver for the
   requested estimand.
2. A public optimizer-status ledger that records convergence, endpoint, and
   constraint residuals without silently accepting failed refits.
3. A pure test proving the token and flattening order map to the intended
   target entry.
4. A frozen known-DGP integration design covering point recovery, interval
   calibration, and retained failed endpoints.
5. Explicit boundary behavior for variance near zero and correlations near
   `+/-1`.
6. Explicit maintainer promotion of only the tested tier, target, and family;
   Mission Control and the validation register must retain every other row as
   blocked.

## What Not To Do

- Do not turn direct SD profiles or point `extract_Sigma()` read-outs into
  derived augmented profile claims.
- Do not borrow intercept-only denominators for augmented proportions.
- Do not call full dep covariance entries "communality".
- Do not mix SPDE field-scale and marginal-scale denominators.
- Do not treat `pdHess = TRUE` as interval calibration.
- Do not treat the former Gaussian canary as a partial public route or as
  evidence that another family or source-specific target is admitted.

## ARIA

Aim: make augmented profile targets explicit enough that implementation can be
small and auditable.

Risk: without this table, a future route could profile the wrong flattened entry
or report a denominator borrowed from an intercept-only model.

Implementation: `.profile_augmented_target_table()` records symbolic targets
and flattening conventions; it does not dispatch a public profile route. Design
73 and CI-11 record this as policy/target coverage only.

Assessment: `test-profile-route-matrix.R` must prove every augmented level and
estimand has exactly one target row and that every augmented nonlinear profile
route, including `rho:unit_slope:i,j`, remains `blocked`.
