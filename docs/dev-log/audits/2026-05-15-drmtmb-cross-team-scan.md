# drmTMB cross-team learning scan -- 2026-05-15

Brief pass over the sister project's recent merges (Jason scout
cadence, ~30 min). Last scan filed under
`docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md`. drmTMB
acquired five new merges on 2026-05-14 -- 2026-05-15:

| drmTMB commit | Subject |
|---|---|
| c91d619 | Stabilize profile target namespace (#35) |
| 6e28997 | Add Phase 6c random slope roadmap |
| 2e3a485 | Plan Phase 6 profile inference |
| 7c15944 | Fit Gaussian aggregation path |
| e77765d | Stage 5b/Slice 47-50 large-data scaling |

Below: what gllvmTMB can borrow, what drmTMB might borrow from us,
and where the two roadmaps overlap.

## What gllvmTMB can learn from drmTMB

### 1. `profile_targets()` namespace pattern (drmTMB Slice 52)

drmTMB introduced an internal `validate_profile_targets()` guard with
a **controlled vocabulary** for the per-target inventory:

- `target_type` &isin; `{direct, derived}`
- `profile_note` &isin; `{ready, tmb_object_required, missing_tmb_parameter, derived_target, derived_unstructured_correlation}`
- `transformation` &isin; `{linear_predictor, exp, rho12_tanh, tanh, derived_group_scale, unstructured_corr, ordered_cutpoint}`

Each row tracks whether a target is profile-ready and, if not, why
(no TMB object, missing parameter, derived quantity, etc.).

**Borrow opportunity** for the Phase 1b validation milestone:
Fisher's planned `confint_inspect(fit, parameter = "...")` function
should adopt the same controlled-vocabulary pattern. Today our
`profile_ci_*()` family is per-quantity (`profile_ci_rho()`,
`profile_ci_communality()`, etc.) with ad-hoc error messages on
unreachable cases. A single `profile_targets()` inventory returning
a tidy data frame with `target / target_type / profile_note /
transformation / profile_ready` columns would be a much cleaner
surface. drmTMB's design lives in `R/profile.R` and is verified by
`tests/testthat/test-profile-targets.R`; we should mirror this
both in API surface and test design when we ship `confint_inspect()`.

### 2. Memory-light fits via `drm_control(keep_tmb_object = FALSE)`

drmTMB carries an `keep_tmb_object` control flag that drops the TMB
automatic-differentiation object after fitting. This shrinks
serialized fit objects substantially (the TMB ADFun and its environment
are the bulk of a fit's memory footprint) at the cost of disabling
post-fit `tmbprofile()`.

We don't have an analog. `gllvmTMBcontrol()` could grow a similar
flag. **Tentative placement**: Phase 6 / post-CRAN, gated by the same
Phase 5.5 validation that confirms our `fit$tmb_obj` is the right
discardable element. Not urgent for 0.2.0.

### 3. Gaussian aggregation path (drmTMB Slices 47-50)

drmTMB built a sparse fixed-effect parity scaffold + reduced-storage
Gaussian fit path for large-data scaling. This is a single-response
package optimisation; the design considerations (sparse storage,
fixed-effect density diagnostics, structured-covariance memory-light
storage) are orthogonal to our stacked-trait engine. **Not directly
borrowable**; flagged for Phase 6 reference if scaling becomes a
gllvmTMB bottleneck (it isn't today).

## What drmTMB can learn from gllvmTMB

### 1. `check_identifiability()` (PR #105 in flight)

Procrustes-aligned simulate-refit identifiability diagnostic. Catches
the spurious-extra-factor failure mode (`pdHess = TRUE`,
`sanity_multi()` passes, but a column of $\boldsymbol\Lambda$ is
unidentifiable in direction). drmTMB's Phase 6c random-slope work
will face an analogous failure mode: two-slope fits where one slope
is unidentifiable across the structured-dependence layer. Once #105
lands, a port of the Procrustes-based design to drmTMB's
`random-slope` lane would be valuable.

### 2. 15-family link-residual fixture pattern (PR #106, merged)

The mock-fit-per-family-ID fixture in `tests/testthat/test-link-
residual-15-family-fixture.R` exercises every branch of
`link_residual_per_trait()` without the cost of fitting 15 different
models. drmTMB has fewer families but the same pattern would close
the analogous coverage gap on their per-family code paths in
`R/extract.R`-equivalent files.

### 3. `check_auto_residual()` safeguard (PR #104, merged)

If drmTMB ever implements an analog of `extract_correlations(
link_residual = "auto")` for its single-response family palette,
they should also implement the safeguard (or skip the auto path
entirely for ordinal-probit, where the latent residual is already 1
by construction).

### 4. `codex-checkpoint.R` is two-way already

Lifted from drmTMB on 2026-05-15 (PR #103). The tool reads
`docs/dev-log/check-log.md` tail + recent after-tasks + git state
and writes a Markdown checkpoint. Already cross-deployed; mentioned
here for completeness.

## Roadmap overlap: random slopes

Both packages now have an explicit pre-CRAN (gllvmTMB) /
post-CRAN-6c (drmTMB) random-slope roadmap. drmTMB's design choices
worth mirroring:

- **One slope first, two later**. drmTMB Phase 6c starts with the
  single-slope contract
  $\mu_i = x_i^\top \beta + a_{0,g[i]} + a_{1,g[i]} z_i$
  and only opens slope-slope correlations after recovery evidence on
  the single-slope path. gllvmTMB's Phase 1c-slope plan should adopt
  the same conservative sequencing (single-slope before
  slope-correlation models).

- **Profile-likelihood CIs in the same lane**. drmTMB stages
  profile-likelihood CIs for random-slope SDs in Phase 6c rather
  than punting them to a later phase. We should do the same: the
  Phase 1c-slope close gate should require profile-CI coverage on
  the new slope variance components, not defer that to Phase 5.

- **Biological example slate**. drmTMB names thermal plasticity,
  desiccation plasticity, disturbance reaction norms, and bivariate
  plasticity syndromes as the Phase 6c worked-example targets.
  gllvmTMB's Phase 1c-slope already lists the parallel multi-trait
  versions in the Phase 6 deferred-applied-ecology backlog (the
  `temporal-trait-change`, `plasticity-across-gradients` articles).
  When Phase 1c-slope dispatches we should keep this article slate
  in mind.

## Action items

1. **Phase 1b validation milestone**: Adopt drmTMB's
   `profile_targets()` controlled-vocabulary pattern when designing
   `confint_inspect()`. ~1 day extra scope; high-value structural
   simplification.

2. **Phase 1c-slope plan revision** (no PR; ROADMAP edit when 1c-slope
   dispatches): adopt drmTMB's "one slope first" sequencing + the
   "profile-CI in the same lane" rule. Slot the four biological
   plasticity-syndrome articles parallel to drmTMB's Phase 6c
   worked-example slate.

3. **Post-#105 outreach**: when `check_identifiability()` lands, file
   an issue on `itchyshin/drmTMB` flagging the Procrustes-based design
   as transferable to drmTMB's Phase 6c random-slope work.

4. **No urgent code change** triggered by this scan. drmTMB's
   memory-light path and aggregation work are orthogonal to our
   current correctness-first Phase 1b focus.

## Cadence

Next Jason scan: at the start of Phase 1c-slope dispatch (estimated
~1-2 weeks after Phase 1b validation milestone closes). The drmTMB
team is on a slice cadence (one slice/day); we likely see ~7-10 new
merges by the next scan.
