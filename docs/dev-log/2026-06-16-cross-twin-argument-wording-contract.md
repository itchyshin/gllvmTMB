# Cross-Twin Argument And Wording Contract

Date: 2026-06-16

Reader: the maintainer, bridge implementers, documentation editors, and issue
auditors working across `gllvmTMB` / `GLLVM.jl` and `drmTMB` / `DRM.jl`.

Purpose: keep the R front ends, Julia engines, DRM sibling lessons, and GLLVM
finish programme from drifting into incompatible argument names or inflated
claim wording.

This is a governance and wording contract. It does not admit a new capability,
change a public API, or close an issue.

## Operating Rule

Use the same word only when the same thing is meant. Where DRM and GLLVM have
different model grammars, keep the package-specific name and record the mapping
rather than forcing a shared argument.

Every promoted bridge row must pass three consistency checks:

1. the R user-facing argument name is stable;
2. the Julia bridge payload uses the matching concept and labels its scale;
3. the public wording says `covered`, `partial`, `planned`, or `unsupported`
   at the same depth as the tests and validation rows.

## Shared Bridge Vocabulary

| Concept | `gllvmTMB` / `GLLVM.jl` | `drmTMB` / `DRM.jl` | Contract |
| --- | --- | --- | --- |
| R-side engine selector | `engine = c("tmb", "julia")` in `gllvmTMB()` | `engine = c("tmb", "julia")` in `drmTMB()` | Use exact R wording `engine = "julia"` for the bridge. Do not call this an engine-side algorithm selector. |
| Native R default | `engine = "tmb"` | `engine = "tmb"` | Native R/TMB remains the user-facing oracle unless a bridge row explicitly says otherwise. |
| Julia bridge primitive | `GLLVM.bridge_fit(...)` and `GLLVM.bridge_capabilities()` | `DRM.drm_bridge(...)` and `DRM.drm_bridge_inference(...)` | Julia functions are bridge primitives, not user-facing R API replacements. Return flat JuliaCall-safe payloads. |
| R bridge helpers | `gllvm_julia_setup()`, `gllvm_julia_fit()`, `gllvm_julia_capabilities()` | existing `drmTMB` bridge glue; `drm_julia_setup()` appears in the sibling check log | Package-specific helper prefixes are fine. Capability reporter columns should use the same meanings when present. |
| Future Julia-side control surface | reserved `engine_control` | reserved `engine_control` | Reserve `engine_control` for future Julia algorithm, solver, tolerance, and threading options. Do not overload `gllvmTMBcontrol()`, `drm_control()`, or `control` with untested Julia-side choices. |
| Unsupported bridge options | fail-loud R bridge gates | fail-loud R bridge gates | Error messages should say whether the block is engine support, R bridge routing, payload shape, or statistical design. |
| Capability ledger | `gllvm_julia_capabilities()` mirrors `GLLVM.bridge_capabilities()` where R admits the row | sibling DRM ledgers / dashboards should use equivalent status semantics when added | A `TRUE` CI column means an endpoint route is implemented and tested, not merely planned or engine-internal. |

## Names That Must Not Be Blurred

### `control` versus `engine_control`

`control`, `gllvmTMBcontrol()`, and `drm_control()` are native-R/TMB or package
fitted-object controls unless a narrow row proves otherwise. Future Julia-side
choices should use `engine_control` so examples do not imply users can pick
Julia optimizers, sparse algorithms, REML variants, or CI engines through the
native control object.

Until `engine_control` exists and is tested, bridge examples should describe the
default Julia fitting path only.

### `d`, `K`, and latent rank

For `gllvmTMB`, `d` is the public latent-rank argument inside `latent(...)` and
the Julia bridge payload uses `d` for that same rank. The low-level helper
`gllvm_julia_fit(..., num.lv = ...)` is an R bridge helper, not the public
formula grammar.

For DRM, `K` appears in different structured-model contexts. Do not rewrite DRM
`K` to GLLVM `d`, and do not use GLLVM `d` to describe DRM latent/phylogenetic
dimensions unless a source-map note proves they are the same estimand.

### Response masks, missing data, and coefficient masks

Use these names consistently:

| Name | Meaning | Boolean convention |
| --- | --- | --- |
| response mask / observed-cell mask | whether an observed response cell contributes to the likelihood | `TRUE` / `1` means observed; `FALSE` / `0` means missing or held out |
| missing-predictor model | a model for a missing covariate value | not a response mask |
| `Xcoef_mask` candidate | future structural-zero fixed-effect coefficient mask | `TRUE` means estimate the coefficient; `FALSE` means fix it to zero |
| observation-by-response covariate | a predictor `z[i, j, k]` whose value varies across both observation and response | separate future design lane |

Do not call `Xcoef_mask` a response mask. Do not call response-mask support
imputation. Do not fold observation-by-response covariates into the
structural-zero coefficient lane.

### Per-trait versus per-observation dispersion

In `gllvmTMB`, dispersion-family bridge parity means per-trait nuisance
parameters for NB2, NB1, Beta, and Gamma unless a row explicitly says
shared-scalar. In `GLLVM.jl`, the implementation may use grouped-dispersion
fitters, but R-facing prose should say per-trait grouped dispersion for the
native `gllvmTMB` parity target.

In `drmTMB` / `DRM.jl`, `sigma ~ x` and related scale formulas are
per-observation or model-axis dispersion regressions, not GLLVM per-trait
dispersion. Use DRM's `mu`, `sigma`, `nu`, and `rho12` language only for DRM
objects.

### Ordinal cutpoints

`gllvmTMB` ordinal parity requires per-trait cutpoints and per-trait category
counts in the bridge payload. `DRM.jl` cumulative-logit fits use ordered
cutpoints for one response in the current public slice. Both packages may say
`cutpoints`, but only GLLVM bridge rows should say `per-trait ordinal
cutpoints`.

Do not advertise ordinal scale/discrimination, ordinal random effects, or
ordinal CI endpoints unless the row-specific tests and validation ledger say
they are covered.

## REML, AI-REML, And Speed Wording

Use `REML` only where the fitted objective is actually restricted likelihood
and the comparison rules are documented.

- `gllvmTMB(REML = TRUE)` is a narrow Gaussian-only native R/TMB route unless a
  future bridge row proves an equivalent Julia route.
- `DRM.jl` direct Julia fits use `method = :REML` for tested Gaussian routes;
  that does not create a `gllvmTMB` bridge claim.
- `AI-REML` is not a synonym for fast non-Gaussian fitting. Use it only for an
  exact Gaussian average-information REML derivation or a clearly labelled
  design comparison.
- Non-Gaussian bridge acceleration should use method-specific language such as
  observed information, natural gradient, reverse-mode AD, sparse Laplace, or
  implicit Laplace adjoint, and only with parity, status, runtime, and failure
  evidence.

`pdHess = FALSE` remains an inference/status warning. It can block Wald
interval promotion, but it is not automatic proof that point estimates,
predictions, or rotation-invariant covariance summaries are unusable.

## Claim And Status Words

Use these words with fixed meanings:

| Word | Meaning |
| --- | --- |
| `covered` | tests and validation rows cover the advertised depth |
| `partial` | useful implementation exists, but one or more advertised depths are missing |
| `planned` | design or issue exists, implementation/evidence is not yet available |
| `unsupported` | deliberately rejected or out of current scope |
| `experimental` | implemented for exploration, not yet a public guarantee |

Avoid `full`, `complete`, `full parity`, `CRAN-ready bridge`, and broad
`production-ready` language unless implementation, tests, docs, issue ledger,
CI, validation row, and release wording all agree.

For public prose, use IN / PARTIAL / PLANNED / UNSUPPORTED sections or row
references. For machine-readable ledgers, use `covered`, `partial`, `planned`,
`unsupported`, and `experimental` consistently.

## CI And Interval Wording

Bridge confidence interval wording must separate:

- endpoint route implemented and tested;
- CI request recognized but status-gated;
- CI skipped because the row is unsupported;
- Hessian/Wald interval unavailable because `pdHess = FALSE` or `sdreport()`
  was skipped;
- profile/bootstrap route implemented but not calibrated by simulation.

A boolean field such as `ci_no_x_wald = TRUE` means the endpoint route exists
for that row. If the route is not implemented, use `FALSE` plus a status note;
do not use `TRUE` to mean "planned".

## Required Cross-Checks Before A Bridge Or Docs PR

Before a bridge or public-docs PR promotes a row, run a focused cross-twin
wording scan:

```sh
rg -n "engine = \"julia\"|engine_control|gllvmTMBcontrol|drm_control|control =|REML|AI-REML|pdHess|full parity|complete bridge|CRAN-ready bridge" \
  README.md NEWS.md ROADMAP.md R docs vignettes tests/testthat
```

For GLLVM bridge rows, also check the paired Julia checkout:

```sh
rg -n "bridge_fit|bridge_capabilities|engine_control|REML|AI-REML|per-trait|grouped dispersion|cutpoints|mask|fixed_effect_X|ci_no_x" \
  src test docs README.md CHANGELOG.md r
```

For DRM lessons, inspect but do not copy claims from dirty sibling checkouts:

```sh
rg -n "engine = \"julia\"|engine_control|drm_bridge|drm_bridge_inference|method = :REML|pdHess|rho12|missing-response|response mask" \
  R src test docs README.md NEWS.md
```

Record the exact files inspected and whether each mismatch is a true API drift,
a package-specific vocabulary difference, or a harmless historical note.

## Immediate Plan Update

Add this as a standing gate to the Twin Finish Programme:

1. Before each bridge, engine, or public-docs lane, Jason/Hopper runs the
   cross-twin wording and argument scan.
2. Boole decides whether a name should be shared or package-specific.
3. Rose blocks public claims if the argument name, payload field, capability
   row, validation row, and docs use inconsistent status language.
4. Shannon checks the coordination board and check-log before any branch switch
   or issue action.

This gate applies to `engine_control`, response masks, `Xcoef_mask` /
`Xcoef_fixed`, per-trait dispersion, ordinal cutpoints, REML/AI-REML wording,
CI-status columns, and `pdHess` interpretation.
