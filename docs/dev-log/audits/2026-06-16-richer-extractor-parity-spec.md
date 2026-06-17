# Richer Extractor Parity Spec: Julia Bridge

Date: 2026-06-16

Branch: `codex/r-bridge-grouped-dispersion`

Roles: Ada (ordering), Emmy (R object and S3 extractor surface), Hopper
(R-Julia payload contract), Karpinski (Julia post-fit payloads), Fisher
(inference/status), Florence (visual consequences), Rose (claim boundary).

## Purpose

Split "richer extractor parity" into testable rows so the next bridge work does
not promote a broad claim from one raw payload. The current admitted surface is
useful but narrow: `gllvmTMB_julia` objects expose retained unit-tier covariance
and raw ordination payloads on the GLLVM.jl engine scale. They do not yet claim
native TMB extractor parity, family-aware residual augmentation, rotations,
interval tables, or structured-tier extraction.

This document is a spec and audit only. It adds no implementation, no public
article claim, no NEWS expansion, and no validation-register status change.

## Current Admitted Surface

`JUL-01A` currently covers raw unit-tier accessors:

- `extract_Sigma()`, `extract_Sigma_B()`, `getResidualCov()`, and
  `getResidualCor()` route for ordinary `level = "unit"` / `"B"`.
- `extract_ordination()`, `getLoadings()`, and `getLV()` route raw loadings
  and scores.
- Complete balanced mixed-family no-X/no-mask/no-CI bridge objects can use the
  same retained raw payloads.
- The returned covariance is the retained engine-scale object:

```text
Sigma_unit = Lambda Lambda^T
```

or the equivalent `Sigma` payload returned by GLLVM.jl. The Julia bridge does
not yet add the native TMB family-aware `link_residual = "auto"` diagonal.

## Parity Rows To Split

| Row | Target | Promotion condition | Current status |
| --- | --- | --- | --- |
| EXT-JL-RAW | Raw unit-tier payload shape and labels | R accessors preserve trait names, dimensions, symmetric `Sigma`, unit-diagonal `R`, and finite loadings/scores for every admitted family row. Direct R fake-payload tests and live JuliaCall tests agree with the paired GLLVM.jl bridge payload. | Partly admitted through `JUL-01A`; raw payload is retained on the object/summary but public covariance extraction now applies native scale semantics. |
| EXT-JL-NATIVE-POINT | Native TMB point parity where faithful | For rows with a native TMB oracle, compare objective/logLik/df and invariant covariance quantities. Use `Sigma` / correlation first because raw loadings and scores are sign/rotation dependent when `d > 1`. | Gaussian no-link-residual covariance/correlation parity is now tested; selected grouped objective/df evidence exists elsewhere; broad extractor parity remains gated. |
| EXT-JL-LINK-RESIDUAL | `link_residual = "auto"` augmentation | Julia bridge retains or recomputes the family-specific residual diagonal needed to match native `extract_Sigma(..., link_residual = "auto")`. Tests cover Gaussian, Poisson, Bernoulli binomial, NB2, NB1, Beta, and Gamma separately. | First scale split admitted: `none` reconstructs `Lambda Lambda^T`, `auto` uses retained residual-augmented payloads where available, and Gaussian/lognormal rows follow native no-op residual semantics. Full residual-split reporting and all-family native parity remain gated. |
| EXT-JL-ROTATION | Rotated ordination semantics | `getLoadings(..., rotate = "varimax" / "promax")` and rotated `getLV()` preserve fitted linear predictors or `Lambda %*% t(scores)` up to tolerance, keep `Sigma` invariant, and match the R rotation convention after sign/order anchoring. | Gated. Current R methods reject rotated Julia bridge loadings/scores. |
| EXT-JL-STRUCTURED | Structured and augmented tiers | Julia engine can produce and label `unit_obs`, `unit_slope`, `phy`, `phy_slope`, `spatial`, `spde_slope`, `cluster`, and `cluster2` payloads, with level-specific tests against native extractor shape and scale. | Gated; keep loud bridge errors. |
| EXT-JL-INTERVAL | Interval-bearing extractor tables | CI/status payloads support `extract_correlations()`, `extract_Sigma_table()`, plot helpers, and bootstrap/profile-derived rows with explicit status columns. | Gated beyond scalar `confint()` rows. |
| EXT-JL-MIXED | Mixed-family richer extractors | Complete balanced mixed-family fits expose only raw retained payloads until residual augmentation, masks, X rows, CIs, and status semantics are specified for each response block. | Raw retained payload admitted; richer mixed-family extractors gated. |

## Native-Parity Rules

Native TMB is the R-facing oracle for object shape, labels, status language,
and extractor defaults. GLLVM.jl is the engine oracle for bridge payload values.
The tests should not mix those roles.

Use native-vs-Julia numerical parity only where the model is genuinely the
same. Faithful initial cells are:

- Gaussian no-X complete balanced reduced-rank fits.
- Poisson and Bernoulli binomial no-X complete balanced reduced-rank fits.
- NB2, NB1, Beta, and current shared-Gamma bridge rows on the small complete
  balanced fixtures already used for point parity.
- Ordinal and ordinal-probit rows for raw scores/loadings/covariance only;
  category-level CI and residual semantics remain separate rows.

Do not compare raw `Lambda` or score matrices across engines for `d > 1`
without a sign/order/rotation rule. Prefer invariant checks:

- `Sigma = Lambda Lambda^T`;
- correlation matrices;
- fitted linear predictors reconstructed from loadings and scores;
- df/logLik/objective where the likelihood parameterisation is known to match.

If a faithful comparator does not exist, record "no faithful comparator" and
use a source-map comparison instead.

## Link-Residual Contract

`link_residual = "auto"` is a family-aware covariance augmentation, not a
display choice. Before Julia bridge promotion, each family row needs an
explicit formula and retained data requirement:

- Gaussian: residual variance on the response scale.
- Poisson: mean-dependent diagonal approximation, if the native extractor uses
  it in the compared route.
- Bernoulli binomial: trial-count-aware diagonal on the relevant scale.
- NB2 and NB1: dispersion-specific mean-variance relation.
- Beta: precision-specific residual contribution.
- Gamma: current shared-shape bridge route first; native per-trait Gamma shape
  waits for the later R/TMB expansion.
- Ordinal: do not promote until category-scale residual semantics are decided.

The R bridge must keep `link_residual = "auto"` visibly non-native until this
contract is implemented and tested.

## Rotation Contract

Rotations are interpretation aids, not new fitted models. A Julia bridge
rotation row must prove:

- `Lambda Lambda^T` is invariant before and after rotation.
- The loadings/scores product is preserved to numerical tolerance.
- Axis order and sign anchoring are deterministic enough for examples and
  tests.
- `getLoadings()`, `getLV()`, `extract_ordination()`, and figure helpers agree
  on the returned convention.

Florence should prefer covariance/correlation figures for public examples until
this row is covered. Rotated ordination plots can follow after the status and
uncertainty language is honest.

## Structured-Tier Contract

Structured extractor parity is downstream of Julia engine support. The R bridge
must keep current loud gates until GLLVM.jl returns level-specific payloads for
the relevant fitted terms. The first admissible structured row should be the
dense phylo-equivalent kernel path only after the C1 dense-kernel equivalence
gate is green; sparse phylo, spatial/SPDE, random slopes, and coevolution rows
should not be pulled into this extractor PR.

## Evidence Matrix

| Evidence layer | Required before promotion | Notes |
| --- | --- | --- |
| Pure R fake-payload tests | Shape, labels, default forcing, gate messages, mixed-family raw payloads. | Fast guard against S3 and argument drift. |
| Live JuliaCall tests | Every admitted family row returns finite payloads through `gllvmTMB(..., engine = "julia")`. | Use the paired `GLLVM.jl-integration` checkout. |
| Direct GLLVM.jl tests | `GLLVM.bridge_fit` payloads match native GLLVM.jl fitters where available. | Keeps R payload bugs separate from engine bugs. |
| Native TMB parity tests | Only for faithful cells; compare invariants before raw loadings/scores. | Avoid false failure from rotation/sign non-identifiability. |
| Capability-ledger drift check | `gllvm_julia_capabilities()` notes, `JUL-01A`, and gate messages agree. | Rose blocks "full extractor parity" wording. |
| Status/CI tests | Interval rows include endpoint values plus unavailable/status reasons. | Fisher owns weak-Hessian and failed-CI behavior. |

## Comparator And Package-Scouting Notes

Native `gllvmTMB` is the shape and user-facing semantics oracle. GLLVM.jl is
the bridge payload oracle.

External packages are learning sources, not automatic numerical comparators:

- `gllvm`, `boral`, and `Hmsc` can inform ordination vocabulary and ecological
  examples, but their likelihoods and random-effect layers usually differ.
- `glmmTMB` is useful for ordinary single-response GLMM family checks, not for
  latent multivariate covariance extractor parity.
- `MultiTraits` can inform trait-space and network visual grammar only; it is a
  raw-trait analysis package, not a fitted GLLVM likelihood comparator.
- `MixedModels.jl` and `Turing.jl` may help with Julia-side API ideas, but they
  do not define the R bridge extractor contract.

## Implementation Sequence

1. Add a pure-R extractor-parity test matrix for raw payload shape, labels, and
   gate messages, without expanding public claims.
2. Add live JuliaCall row coverage for the same raw payload matrix across the
   admitted families.
3. Add native TMB invariant parity cells only where faithful, starting with
   Gaussian and already-scoped grouped-dispersion fixtures.
4. Write and test the `link_residual = "auto"` contract by family.
5. Add rotation semantics after invariant tests and figure/status language are
   stable.
6. Add interval-bearing extractor tables after CI payload/status rows exist.
7. Start structured-tier extractor work only after the corresponding Julia
   structured fit/payload is available.

## Non-Goals For The Next PR

- No structured-tier extractor implementation.
- No `newdata` prediction or simulation.
- No unconditional random-effect redraws.
- No ordinal residual or ordinal simulation promotion.
- No broad speed or CRAN-readiness claim.
- No issue closure without live issue inspection and Rose/Shannon signoff.
