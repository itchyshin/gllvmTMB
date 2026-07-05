# Profile Likelihood Route Matrix

Date: 2026-07-04

Owner: Fisher with Ada, Rose, Boole, Curie, and Grace.

## Aim

Keep profile-likelihood routing honest across every covariance tier before
adding more one-off profile helpers. The current package already has strong
pieces: direct TMB profiles, derived fix-and-refit profiles, Wald fallbacks,
bootstrap helpers, and point extractors. The missing piece is a shared map that
says which tier/estimand combinations are covered, partial, planned,
point-only, not applicable, or blocked.

This design is implemented as the internal route ledger
`.profile_route_matrix()`.

## Tier Symbols

| Route level | Model object | Shape | Current profile state |
| --- | --- | --- | --- |
| `unit` | ordinary between-unit covariance | `T x T` | partial for total `Sigma`; covered for direct log-SD, communality, and rho routes |
| `unit_obs` | observation / within-unit covariance | `T x T` | partial for total `Sigma`; covered for direct log-SD, communality, and rho routes |
| `cluster` | first extra diagonal grouping tier | diagonal `T` | direct log-SD profile label covered; diagonal-only `Sigma_cluster` token partial |
| `cluster2` | second extra diagonal grouping tier | diagonal `T` | direct log-SD profile label covered; diagonal-only `Sigma_cluster2` token partial |
| `phy` | phylogenetic source tier | `T x T` | partial/covered depending on target; multi-component `H2` profile remains partial |
| `spatial` | SPDE source tier | `T x T` | partial; total spatial covariance profile needs a heavy gate |
| augmented split tiers | unit/source random-regression blocks | split or augmented block | blocked for profile until target symbols are declared |

## Estimand Routes

| Estimand | Covered route | Current boundary |
| --- | --- | --- |
| Direct SD / scale | `profile_targets()` on TMB parameter blocks | coverage calibration remains separate |
| `Sigma` | direct diagonal route for pure-diag ordinary tiers; selected source routes | full low-rank total covariance still needs target-explicit constraints |
| Communality | unit, unit_obs, and phy fix-and-refit routes | no cluster/cluster2 route because they have no shared loading numerator |
| Correlation `rho` | unit, unit_obs, phy; spatial is partial | cluster/cluster2 correlations are structural zeros, not interval targets |
| Repeatability | direct diag-only ratio route | full low-rank repeatability profile is not covered |
| Phylogenetic signal | two-component phylo signal direct profile | richer PGLLVM decompositions use labelled numeric Wald fallback |
| Proportions | unit, unit_obs, phy components; cluster and cluster2 diagonal components are partial | spatial denominator components are planned, not covered |
| Augmented split targets | none yet | symbolic target table required before implementation |

## Current Route Snapshot

This is the operating truth for the profile route matrix as of 2026-07-04. It
separates direct parameter profiles from derived intervals, because a direct
profile of a log-SD or scale parameter is not the same claim as a calibrated
profile interval for a derived covariance matrix, correlation, or variance
share.

| Level | Direct SD / scale | `Sigma` | Communality | `rho` | Proportion | Other |
| --- | --- | --- | --- | --- | --- | --- |
| `unit` | covered | partial | covered | covered | covered | repeatability partial |
| `unit_obs` | covered | partial | covered | covered | covered | - |
| `cluster` | covered | partial | not applicable | point-only | partial | diagonal tier only |
| `cluster2` | covered | partial | not applicable | point-only | partial | diagonal tier only |
| `phy` | covered | partial | covered | covered | covered | phylogenetic signal partial |
| `spatial` | covered | partial | planned | partial | planned | total spatial covariance needs heavy gate |
| `unit_slope` | not claimed | blocked | blocked | blocked | blocked | symbolic target table required |
| `phy_unique_slope` | not claimed | blocked | blocked | blocked | blocked | symbolic target table required |
| `phy_dep` | not claimed | blocked | blocked | blocked | blocked | symbolic target table required |
| `phy_slope` | not claimed | blocked | blocked | blocked | blocked | symbolic target table required |
| `spde_base_slope` | not claimed | blocked | blocked | blocked | blocked | symbolic target table required |
| `spde_dep` | not claimed | blocked | blocked | blocked | blocked | symbolic target table required |
| `spde_slope` | not claimed | blocked | blocked | blocked | blocked | symbolic target table required |

Two clarifications matter for future profile-function work:

- `profile_targets()` may expose a direct parameter, such as
  `sigma_phy_slope`, without making the augmented split covariance, correlation,
  or denominator target profile-ready.
- `cluster` and `cluster2` can have direct diagonal SD profiles, and the
  `Sigma_cluster` / `Sigma_cluster2` matrix tokens are diagonal-only wrappers
  around that same log-SD route. Their off-diagonal correlations are structural
  zeros and must not receive fake intervals.
- `unique_cluster` and `unique_cluster2` are now valid variance-proportion
  components. They enter the all-tier denominator as diagonal variance only;
  this is not a new shared-loading, correlation, or full covariance claim.

## ARIA

Aim: centralize the route truth so future code can dispatch from one ledger.

Risk: users can otherwise see a point extractor or a direct parameter profile
and infer a calibrated derived interval for a more complex tier.

Implementation: add an internal matrix plus pure tests; add missing direct
profile labels for `theta_diag_species` as `sd_cluster` and
`theta_diag_cluster2` as `sd_cluster2`; keep the legacy `sd_phy_unique` alias.

Assessment: pure route-matrix tests must pass; no route moves from partial or
blocked to covered unless it has direct code and validation-register evidence.

## Stop Rules

- Do not describe direct `sd_cluster` / `sd_cluster2` profiles or diagonal-only
  `Sigma_cluster` / `Sigma_cluster2` wrappers as full covariance support.
- Do not fabricate intervals for structural-zero cluster correlations.
- Do not use `pdHess = TRUE` as interval calibration evidence.
- Do not profile augmented split tiers until the target symbols, flattening
  convention, and denominator are written down.
- Do not mix Totoro and DRAC denominators for later calibration unless the
  simulation design explicitly says so.

## Next Gates

1. Add simulate-refit bootstrap calibration for `Sigma_cluster` and
   `Sigma_cluster2` only after a denominator-preserving design gate.
2. Add spatial shared/unique components to profile proportions only after a
   spatial denominator design covers `spatial_latent(unique = TRUE)` and legacy
   spatial compatibility syntax.
3. Repair hard-family profile stability, especially Gamma unit-tier rho
   failures, before broader claims.
4. Write a symbolic target table before any augmented structural split profile
   route.
