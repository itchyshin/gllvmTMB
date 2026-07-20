# Design 75 -- Inference Route Truth Matrix (estimand x tier x method)

Date: 2026-07-05; release-boundary revision 2026-07-20

Owner: Fisher, with Rose, Noether, Boole, Curie, and Ada review roles.

Status: read-only audit. This note changes no package capability, no
likelihood code, no formula grammar, and no public-facing claim. It is the
Day-1 truth-lock artefact for the `gllvmTMB` completion arc and the direct
follow-on to Design 73 and Design 74.

Release-boundary correction: nonlinear penalty profiles for repeatability,
communality, correlation, and variance proportion are withdrawn. Their
Profile-LR cells below are `blocked`, including the former selected-entry
`unit_slope` canary. Direct/simple profiles and the retained two-component
phylogenetic-signal route remain separate.

## Why this note exists

Design 73 (`73-profile-likelihood-route-matrix.md`) maps covariance tiers
against estimands, but every cell in its snapshot collapses the *method* axis:
it answers "is `rho` on `unit` routed?" without separating Wald, profile,
estimated-likelihood, and bootstrap. The internal ledger
`.profile_route_matrix()` has a `method` column, but **every row it emits uses
`method = "profile"`**. Wald and bootstrap are wired in the dispatch layer
(`confint.gllvmTMB_multi`, `extract_*(ci = TRUE, method = ...)`) yet are absent
from the ledger, and estimated-likelihood / fixed-nuisance LR is not
implemented anywhere in `R/` or `src/`.

The result is a truth gap: a reader of the internal ledger sees only the
profile story, while the user-facing API exposes four method words
(`profile`, `wald`, `bootstrap`, plus the `wald(numeric)` degrade label). This
note is the honest four-method map so no method column is silently assumed to
match the profile column.

## Structural finding (the ledger-vs-dispatch gap)

1. `.profile_route_matrix()` emits **profile-only** rows. Its `status`
   vocabulary already admits `fallback`, but no `fallback` row is emitted and
   no `wald` / `bootstrap` / `estimated_likelihood` row exists.
2. The **dispatch layer does route Wald and bootstrap.** `confint()` accepts
   `method = c("profile", "wald", "bootstrap")` (loadings add `wald_asym`);
   `extract_Sigma()` / `extract_repeatability()` / the derived-summary
   extractors accept `method = c("profile", "wald", "bootstrap")`; the
   derived-summary `confint` helpers (`.confint_icc`, `.confint_phylo_signal`,
   communality/proportion/rho paths) keep method dispatch, but nonlinear
   `profile` requests now terminate with the shared typed withdrawal; `wald` /
   `bootstrap` use their separately labelled `extract_*()` companions where
   admitted.
3. **Estimated-likelihood / fixed-nuisance LR is unimplemented.** A repo-wide
   scan for `estimated.?likelihood` / `fixed.?nuisance` over `R/` and `src/`
   returns nothing; the term appears only in planning prose
   (`docs/dev-log/while-away/2026-07-04-gllvmtmb-completion-ultra-plan.md`,
   the 2026-07-05 handover). It is `planned` across the entire matrix.
4. Multi-component (3+) phylogenetic signal profile is not implemented and
   degrades to a labelled `wald(numeric)` delta-method interval
   (`R/profile-derived.R:244`). This is the only live `fallback` behaviour.

Recommended (Fisher lane, handed to Codex, not done here): extend
`.profile_route_matrix()` to carry `wald`, `bootstrap`, and
`estimated_likelihood` method rows so the internal ledger matches the four-word
dispatch reality, with a pure route test per method. Until then, this document
is the method-axis source of truth and Design 73 remains the profile-axis
source of truth.

## Cell vocabulary

A cell describes **route existence and focused-test evidence, never empirical
coverage calibration**. `pdHess = TRUE` is not calibration evidence.

| Status | Meaning in this matrix |
| --- | --- |
| `covered` | Route wired and exercised by a focused test at the advertised depth |
| `partial` | Route exists but shallower than advertised (smoke-only, diagonal-only, or elementwise-delta) |
| `opt-in` | Works only through an explicit non-default call (`method = "bootstrap"`, `nsim`, `seed`) |
| `fallback` | Requested method degrades to a cheaper labelled method (e.g. `wald(numeric)`) |
| `point_only` | Point estimate is extractable; no interval token is wired |
| `not_applicable` | Target is a structural zero or has no numerator; no interval should exist |
| `blocked` | Advertised surface but no wired interval token; must not be promoted from parser/point acceptance |
| `planned` | Named in a design doc; no implementation |

### Evidence basis per method column

- **Profile-LR**: authoritative -- copied from `.profile_route_matrix()`
  statuses. Nonlinear derived rows are blocked; direct/simple rows are
  route-ledger evidence, not coverage calibration.
- **Wald**: dispatch-confirmed by reading `confint()` / `extract_*()`; per-cell
  focused tests are thinner than the profile column. "covered" here means the
  Wald route dispatches and is dispatch-tested, never that Wald coverage is
  calibrated for a boundary-sensitive variance target.
- **Estimated-likelihood**: `planned` everywhere; no code.
- **Bootstrap**: dispatch-confirmed and `opt-in` (needs explicit `method`,
  `nsim`, `seed`). Parametric bootstrap is the intended calibration engine, but
  no coverage study promotes any cell here; treat as route existence only.

**No cell in this matrix is empirical-coverage-calibrated.** Every status is
route existence plus focused-test evidence. The empirical coverage gates are
`CI-08` and `CI-10` in the validation register, which remain open/failing; a
cell may not be described as calibrated on the strength of this matrix.
`docs/design/61-capability-status.md` records the same separation (interval
calibration is distinct from point-estimate recovery).

## Matrix -- peer tiers

`unit` (ordinary between-unit `T x T`):

| Estimand | Wald | Profile-LR | Est-Lik | Bootstrap | Validation rows |
| --- | --- | --- | --- | --- | --- |
| direct SD | covered | covered | planned | opt-in (via Sigma diag) | CI-02 |
| `Sigma` | partial (elementwise delta) | partial (diag direct; low-rank -> bootstrap) | planned | opt-in (`bootstrap_Sigma`) | CI-02;CI-03 |
| communality | partial | blocked | planned | opt-in | CI-06;EXT-05 |
| `rho` | partial | blocked | planned | opt-in | CI-07 |
| repeatability / icc | partial | blocked | planned | opt-in | CI-04 |
| proportion | partial | blocked | planned | opt-in | CI-07;EXT-21;EXT-22 |

`unit_obs` (within-unit / observation `T x T`):

| Estimand | Wald | Profile-LR | Est-Lik | Bootstrap | Validation rows |
| --- | --- | --- | --- | --- | --- |
| direct SD | covered | covered | planned | opt-in (via Sigma diag) | CI-02 |
| `Sigma` | partial (elementwise delta) | partial (diag direct; low-rank -> bootstrap) | planned | opt-in (`bootstrap_Sigma`) | CI-02;CI-03 |
| communality | partial | blocked | planned | opt-in | CI-06;EXT-05 |
| `rho` | partial | blocked | planned | opt-in | CI-07 |
| proportion | partial | blocked | planned | opt-in | CI-07;EXT-21;EXT-22 |

`cluster` and `cluster2` (diagonal `T` grouping tiers -- identical routes):

| Estimand | Wald | Profile-LR | Est-Lik | Bootstrap | Validation rows |
| --- | --- | --- | --- | --- | --- |
| direct SD | covered | covered | planned | opt-in (diag) | CI-02;RE-11 |
| `Sigma` (diag token) | partial (diag only) | partial (diag token; fitted Gaussian canary) | planned | opt-in (diag; gated) | RE-11 |
| communality | not_applicable (no shared loading) | not_applicable | not_applicable | not_applicable | RE-11 |
| `rho` (off-diagonal) | not_applicable (structural zero) | point_only (structural zero) | not_applicable | not_applicable | RE-11 |
| proportion (diag) | partial | blocked | planned | opt-in (gated) | RE-11;CI-11 |

Off-diagonal cluster/cluster2 covariances are fixed structural zeros
(`method = "structural_zero"`). No method column may fabricate an interval for
them.

## Matrix -- source tiers

`phy` (phylogenetic source `T x T`):

| Estimand | Wald | Profile-LR | Est-Lik | Bootstrap | Validation rows |
| --- | --- | --- | --- | --- | --- |
| direct SD | covered | covered | planned | opt-in | CI-02;PHY-05 |
| `Sigma` | partial (elementwise delta) | partial (direct diagonal plus separately documented phylogenetic-signal route) | planned | opt-in | CI-02;CI-05;PHY-05 |
| communality | partial | blocked | planned | opt-in | CI-06;EXT-05;PHY-08 |
| `rho` | partial | blocked | planned | opt-in | CI-07;PHY-05 |
| phylo signal | fallback (`wald(numeric)` for 3+) | partial (2-component direct) | planned | opt-in | CI-05 |
| proportion | partial | blocked | planned | opt-in | CI-07;EXT-21 |

`spatial` (SPDE source `T x T`):

| Estimand | Wald | Profile-LR | Est-Lik | Bootstrap | Validation rows |
| --- | --- | --- | --- | --- | --- |
| direct scale (`tau`/`kappa`) | covered | covered | planned | opt-in | CI-02;SPA-03 |
| `Sigma` | partial | partial (direct scale only; derived total-Sigma targets blocked) | planned | partial (heavy gate) | CI-02;SPA-02;SPA-04 |
| communality | planned | blocked | planned | planned | SPA-02 |
| `rho` | partial | blocked | planned | partial | CI-07;SPA-02;SPA-04 |
| proportion | planned | blocked | planned | planned | SPA-02 |

Spatial total-covariance intervals and spatial variance-proportion components
stay behind independent design and calibration gates. A heavier smoke test is
not sufficient to reactivate any nonlinear profile route.

## Matrix -- named kernel tier

`kernel_named` (fitted `kernel_*()` tier -- point extraction only):

| Estimand | Wald | Profile-LR | Est-Lik | Bootstrap | Point route | Validation rows |
| --- | --- | --- | --- | --- | --- | --- |
| direct SD | blocked | blocked | planned | blocked | -- | COE-04;CI-11 |
| `Sigma` | blocked | blocked | planned | blocked | `extract_Sigma()` / `extract_Sigma_table()` by fitted name | COE-04;CI-11 |
| communality | blocked | blocked | planned | blocked | -- | COE-04;CI-11 |
| `rho` | blocked | blocked | planned | blocked | via point `extract_Sigma_table()` only | COE-04;CI-11 |
| proportion | blocked | blocked | planned | blocked | not in denominator | COE-04;CI-11 |

Named kernel tiers are extractor-visible but interval-blocked on every method.
No `Sigma_<kernel>`, `rho:<kernel>`, communality, or proportion CI token
exists.

## Matrix -- augmented structural split tiers

`unit_slope` (ordinary augmented latent random-regression tier):

| Estimand | Wald | Profile-LR | Est-Lik | Bootstrap | Validation rows |
| --- | --- | --- | --- | --- | --- |
| `Sigma_unit_slope` | blocked | blocked | planned | blocked | RE-12;CI-11 |
| communality | blocked | blocked | planned | blocked | RE-12;CI-11 |
| `rho:unit_slope:i,j` | blocked | blocked | planned | blocked | RE-12;CI-11 |
| proportion | blocked | blocked | planned | blocked | RE-12;CI-11 |

`phy_unique_slope`, `phy_indep_slope`, `phy_dep`, `phy_slope`,
`spde_base_slope`, `spde_indep_slope`, `spde_dep`, `spde_slope` -- **all
estimands blocked on all interval methods.** Design 74
declares the symbolic targets, flattening order, and denominator boundaries;
`.profile_augmented_target_table()` records them as `declared_blocked` or
`not_applicable_blocked`. Point extraction/recovery may exist, but no profile,
Wald, estimated-likelihood, or bootstrap interval token is wired. `communality`
is `not_applicable` for the 2x2 `*_base_slope` blocks and the full `*_dep`
covariances (no shared-loading numerator).

Validation rows for the source augmented tiers: `RE-03`, `RE-12`, `PHY-11..18`,
`ANI-11`, `ANI-12`, `SPA-08`, `SPA-09`, `SPA-10`, all under `CI-11`.

## Hard guards restated

- Every augmented nonlinear profile interval is `blocked`, including the
  former Gaussian `rho:unit_slope:i,j` canary. Historical parser/refit evidence
  does not constitute a public route.
- Structural-zero cluster/cluster2 correlations receive no interval on any
  method.
- Mixed-family nonlinear profiles remain blocked. Point, Fisher-z, Wald, and
  route-specific bootstrap behavior retain their separate, uncalibrated
  statuses in the validation register.
- No non-Gaussian REML or AI-REML wording enters any cell.
- `pdHess = TRUE` is never cell evidence.
- No source-specific `lv = ~ env` promotion from parser or point acceptance.

## Smallest safe next PR shapes (Fisher lane, for Codex)

Ordered by leverage, each a self-contained slice:

1. **Ledger-reality sync.** Extend
   `.profile_route_matrix()` to emit `wald`, `bootstrap`, and
   `estimated_likelihood` method rows matching this matrix, plus a pure route
   test per method only after the 0.6 source/API freeze decision. This is a
   separate architecture slice, not permission to reactivate a nonlinear
   profile route.
2. **Estimated-likelihood diagnostic tier.** Implement fixed-nuisance LR as an
   explicitly-labelled diagnostic (`method = "estimated_likelihood"` or a
   distinct label), documented as *not* full profile because nuisance
   parameters are held at fitted values. Ships with a boundary-honest label and
   a focused test. Promotes the `planned` column to `opt-in` diagnostic only --
   never to a calibrated public claim.
3. **Derived-summary Wald/bootstrap test debt.** Add focused per-cell tests for
   the Wald and bootstrap companions the dispatch layer already routes
   (communality, rho, proportion, icc) so those columns rest on direct evidence
   rather than dispatch reading.

Any future nonlinear profile restoration additionally requires the Design 73
solver/status/calibration gates and explicit maintainer promotion.

None of these promotes a blocked augmented tier, a mixed-family CI, a
structural-zero interval, or a spatial total-covariance interval. Those stay
gated by their own design slices.

## ARIA

Aim: give the completion arc one four-method truth map so no method column is
silently assumed equal to the profile column, and so the ledger-vs-dispatch gap
is visible before any capability is promoted.

Risk: a reader infers that `confint(method = "wald")` or
`confint(method = "bootstrap")` returns a calibrated interval for every tier
because the API accepts the word, when the profile column is the only one with
a route ledger and estimated-likelihood is unimplemented.

Implementation: this document, plus the recommended ledger-reality sync as a
later Codex slice. No code changed in this Day-1 artefact.

Assessment: before any cell in this matrix informs user-facing wording
(README, NEWS, vignette, roxygen) or a validation-register status change,
Rose (overclaim), Fisher (uncertainty logic), and Noether (symbolic <-> R <->
TMB alignment) must review the affected rows. This matrix is internal design
evidence, not an advertised capability list.

## Cross-references

- `docs/design/73-profile-likelihood-route-matrix.md` -- profile-axis source of
  truth (this note is the method-axis companion).
- `docs/design/74-augmented-profile-target-table.md` -- augmented split target
  shapes and denominators.
- `docs/design/35-validation-debt-register.md` -- rows `CI-02`..`CI-11`,
  `RE-11`, `RE-12`, `PHY-05`, `PHY-08`, `SPA-02`..`SPA-04`, `COE-04`, `EXT-05`,
  `EXT-21`, `EXT-22`, `MIX-02`.
- `R/profile-route-matrix.R` -- `.profile_route_matrix()` (profile-only ledger).
- `R/z-confint-gllvmTMB.R`, `R/extractors.R`, `R/profile-ci.R`,
  `R/profile-derived.R` -- the four-word method dispatch layer.
