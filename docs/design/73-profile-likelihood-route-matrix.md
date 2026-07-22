# Profile Likelihood Route Matrix

Date: 2026-07-04; release-boundary revision 2026-07-20

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

For the 0.6 release boundary, every nonlinear penalty-profile route for
repeatability, communality, correlation, or variance proportion is withdrawn.
The former helpers and canaries are internal research prototypes only. They do
not support a public interval claim. Re-admission requires an exact constraint
solver, an exposed optimizer-status ledger, and target-specific calibration.

## Tier Symbols

| Route level | Model object | Shape | Current profile state |
| --- | --- | --- | --- |
| `unit` | ordinary between-unit covariance | `T x T` | direct log-SD covered; selected simple `Sigma` routes partial; nonlinear derived profiles blocked |
| `unit_obs` | observation / within-unit covariance | `T x T` | direct log-SD covered; selected simple `Sigma` routes partial; nonlinear derived profiles blocked |
| `cluster` | first extra diagonal grouping tier | diagonal `T` | direct log-SD covered; diagonal-only `Sigma_cluster` token partial; proportions blocked |
| `cluster2` | second extra diagonal grouping tier | diagonal `T` | direct log-SD covered; diagonal-only `Sigma_cluster2` token partial; proportions blocked |
| `phy` | phylogenetic source tier | `T x T` | direct scales covered and retained simple phylogenetic-signal route partial; nonlinear derived profiles blocked |
| `spatial` | SPDE source tier | `T x T` | direct scale covered; selected simple `Sigma` routes partial; nonlinear derived profiles blocked |
| `kernel_named` | fitted named `kernel_*()` tier | `T x T` | blocked for profile/confint; point covariance can be extracted by fitted name |
| augmented split tiers | unit/source random-regression blocks | split or augmented block | Design 74 declares target symbols; profile routes remain blocked until implementation and calibration gates |

## Estimand Routes

| Estimand | Covered profile route | Current boundary |
| --- | --- | --- |
| Direct SD / scale | `profile_targets()` on direct TMB parameter blocks | covered where the route matrix says `covered`; calibration remains target-specific |
| `Sigma` | direct diagonal route for pure-diagonal ordinary tiers; selected simple source routes | partial; full low-rank or augmented covariance needs target-explicit constraints |
| Communality | none | blocked; former fix-and-refit prototype is internal only |
| Correlation `rho` | none | nonlinear profile is blocked; point, Fisher-z/Wald, and route-specific bootstrap behavior retain separate contracts; cluster/cluster2 correlations remain structural zeros |
| Repeatability | none | blocked; former nonlinear penalty-profile prototype is internal only |
| Phylogenetic signal | retained two-component simple route | partial; richer PGLLVM decompositions use separately labelled numeric Wald fallback |
| Proportions | none | blocked; no component or denominator inherits admission from direct scale profiles |
| Augmented split targets | Design 74 target table only | implementation, boundary handling, and calibration required before any profile route is promoted |

## Current Route Snapshot

This is the operating truth for the profile route matrix as revised on
2026-07-20. It
separates direct parameter profiles from derived intervals, because a direct
profile of a log-SD or scale parameter is not the same claim as a calibrated
profile interval for a derived covariance matrix, correlation, or variance
share.

| Level | Direct SD / scale | `Sigma` | Communality | `rho` | Proportion | Other |
| --- | --- | --- | --- | --- | --- | --- |
| `unit` | covered | partial | blocked | blocked | blocked | repeatability blocked |
| `unit_obs` | covered | partial | blocked | blocked | blocked | nonlinear profiles withdrawn |
| `cluster` | covered | partial | not applicable | point-only | blocked | diagonal tier only; off-diagonal rho is structural zero |
| `cluster2` | covered | partial | not applicable | point-only | blocked | diagonal tier only; off-diagonal rho is structural zero |
| `phy` | covered | partial | blocked | blocked | blocked | simple phylogenetic signal partial |
| `spatial` | covered | partial | blocked | blocked | blocked | total spatial covariance remains separate |
| `kernel_named` | blocked | blocked | blocked | blocked | blocked | point extraction only through `extract_Sigma()` / `extract_Sigma_table()` |
| `unit_slope` | not claimed | blocked | blocked | blocked | blocked | former Gaussian selected-entry canary is internal negative evidence only |
| `phy_unique_slope` | not claimed | blocked | not applicable | blocked | blocked | shared 2x2 `phylo_unique()` target; no profile implementation |
| `phy_indep_slope` | not claimed | blocked | not applicable | blocked | blocked | current per-trait block-diagonal `phylo_indep()` target; no profile implementation |
| `phy_dep` | not claimed | blocked | not applicable | blocked | blocked | Design 74 target table declared; no profile implementation yet |
| `phy_slope` | not claimed | blocked | blocked | blocked | blocked | Design 74 target table declared; no profile implementation yet |
| `spde_base_slope` | not claimed | blocked | not applicable | blocked | blocked | shared 2x2 `spatial_unique()` target; no profile implementation |
| `spde_indep_slope` | not claimed | blocked | not applicable | blocked | blocked | current per-trait block-diagonal `spatial_indep()` target; no profile implementation |
| `spde_dep` | not claimed | blocked | not applicable | blocked | blocked | Design 74 target table declared; no profile implementation yet |
| `spde_slope` | not claimed | blocked | blocked | blocked | blocked | Design 74 target table declared; no profile implementation yet |

Two clarifications matter for future profile-function work:

- `profile_targets()` may expose a direct parameter, such as
  `sigma_phy_slope`, without making the augmented split covariance, correlation,
  or denominator target profile-ready.
- `cluster` and `cluster2` can have direct diagonal SD profiles, and the
  `Sigma_cluster` / `Sigma_cluster2` matrix tokens are diagonal-only wrappers
  around that same log-SD route. Their off-diagonal covariance rows are fixed
  structural zeros and are labelled `method = "structural_zero"`; off-diagonal
  correlations are structural zeros and must not receive fake intervals. The
  2026-07-05 fitted Gaussian canary profiles both `Sigma_cluster` and
  `Sigma_cluster2` diagonal rows on one crossed fixture; this is route evidence,
  not bootstrap or coverage calibration.
- `unique_cluster` and `unique_cluster2` remain valid point-estimate
  variance-proportion components. Their presence in the all-tier denominator
  does not admit a profile interval for a proportion, correlation, or full
  covariance.
- Named `kernel_*()` tiers are extractor-visible but interval-blocked. The
  route matrix therefore records `kernel_named` as a point-extraction boundary:
  no public `Sigma_<kernel>`, `rho:<kernel>`, communality, or proportion profile
  token exists until a kernel-specific target and denominator design is written.
- Design 74 declares augmented structural split targets and flattening
  conventions. It promotes no interval route. The former Gaussian selected-entry
  `rho:unit_slope:i,j` canary is retained only as historical/internal evidence;
  its public route is blocked with the other nonlinear penalty profiles.

## ARIA

Aim: centralize the route truth so future code can dispatch from one ledger.

Risk: users can otherwise see a point extractor or a direct parameter profile
and infer a calibrated derived interval for a more complex tier.

Implementation: construct the operating status directly in the internal matrix
and test the typed refusals. Direct labels such as `sd_cluster` and
`sd_cluster2` remain separate from withdrawn nonlinear derived profiles.

Assessment: pure route-matrix tests must pass; no route moves from partial or
blocked to covered unless it has direct code and validation-register evidence.

## Stop Rules

- Do not describe direct `sd_cluster` / `sd_cluster2` profiles or diagonal-only
  `Sigma_cluster` / `Sigma_cluster2` wrappers as full covariance support.
- Do not fabricate intervals for structural-zero cluster correlations.
- Do not use `pdHess = TRUE` as interval calibration evidence.
- Do not reactivate repeatability, communality, correlation, or proportion
  profiles without an exact constraint solver, an exposed optimizer-status
  ledger, target calibration, and explicit maintainer promotion.
- Do not profile augmented split tiers merely because Design 74 declares their
  symbols. A later slice still needs the same solver, status, boundary, and
  calibration gates for each proposed target.
- Do not mix Totoro and DRAC denominators for later calibration unless the
  simulation design explicitly says so.

## Next Gates

1. Specify and verify an exact constrained-refit solver plus an optimizer-status
   ledger before proposing any nonlinear profile route.
2. Calibrate each proposed target on a frozen known-DGP design, including
   boundary behavior and explicit failed-endpoint accounting.
3. Treat spatial, kernel, augmented, and additional-family routes as independent
   gates; no route inherits admission from another tier or family.
4. Keep internal helpers and historical canaries available for research, but do
   not expose them through public `confint(..., method = "profile")` behavior or
   use them as release evidence until explicit maintainer promotion.
