# After Task: name the temporal marker in shared parser refusals (refs #TBD)

**Branch**: `cursor/temporal-marker-name-5a27`
**Date**: `2026-11-17`
**Roles (engaged)**: `Pat / Boole / Curie / Rose`

## 1. Goal

A two-trait `temporal_indep()` fit aborted with `temporal_latent() requires at least three traits.` The shared parser `.parse_temporal_latent_formula()` already records `marker_name`; the refusal strings did not use it.

## 2. Implemented

Parser refusals that named `temporal_latent()` now interpolate `marker_name`. A `temporal_latent()` call still produces the same wording. The three-trait rule, the rank-one `d = 1` gate, and every other admission check are unchanged.

## 3. Files Changed

- `R/temporal.R` — `{.fn {marker_name}}` in the shared parser refusals
- `tests/testthat/test-temporal-marker-name-refusals.R` — new indep/dep regressions
- `NEWS.md`
- `docs/dev-log/check-log.d/2026-11-17-temporal-marker-name-refusals.md`
- `docs/dev-log/after-task/2026-11-17-temporal-marker-name-refusals.md`

No README, design-doc, roxygen, Rd, or validation-debt edit. The constructor `.temporal_marker()` still names `temporal_latent()` for `d != 1`, which only that constructor reaches.

## 3a. Decisions and Rejected Alternatives

**Decision**: Change the parser messages only; leave the three-trait rule in place for `temporal_indep()` and `temporal_dep()`.
**Rationale**: Whether those modes should admit two traits is a separate design question. This slice only names the function the user called.
**Rejected alternative**: Drop the three-trait gate for indep/dep. That would change admitted models, not just the error text.
**Confidence**: high.

**Decision**: Leave `.temporal_abort()`'s default action pointing at `?temporal_latent`.
**Rationale**: All three keywords share that help page (`@rdname temporal_latent`). Existing tests match the first refusal line, not the action.
**Rejected alternative**: Thread `marker_name` into every abort, including the action. Broader than the reported lines.
**Confidence**: high.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-17-temporal-marker-name-refusals.md`.

origin/main `fc80be9e` two-trait `temporal_indep()` first line: `` `temporal_latent()` requires at least three traits. `` After the fix that call names `temporal_indep()`; the `temporal_latent()` first line is byte-identical. New tests FAIL 0 / PASS 32. Existing parser, methods, sixth-source API/regressions, refusal-classes, and #1392 help tests: FAIL 0. No `devtools::check()` or shard 3/4.

## 5. Tests of the Tests

- `two-trait temporal_indep and temporal_dep fits name the marker used` — failure-before-fix. On main both first lines said `temporal_latent() requires at least three traits.`
- `shared temporal_indep and temporal_dep parser refusals name the marker used` — feature-combination. Covers the complete-Gaussian, trait-intercept, missing-`time`, and non-bar refusals for indep and dep only.

No latent test was added or changed.

## 6. Consistency Audit

See the check-log `rg` patterns. Parser `{.fn temporal_latent}` remains only in `.temporal_marker()` (latent `d != 1`) and in a later method-not-available abort, both outside the reported lines.

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

No GitHub issue number was supplied. The commit and PR use `refs #TBD` and do not close anything.

## 8. What Did Not Go Smoothly

The VM snapshot had no R. Ubuntu `r-base` 4.3.3 plus RSPM binaries were installed before the main confirmation. Compiling `src/gllvmTMB.cpp` took about three minutes of Eigen warnings.

## 9. Team Learning

- Pat: a two-trait `temporal_indep()` user now sees the function they typed. The follow-up action still names `temporal_latent()` help, which is the shared topic.
- Boole: `marker_name` was already set from the formula head; the strings had not used it.
- Curie: new tests cover indep and dep only, so the latent wording contract stays with the existing parser file.
- Rose: GLLVModels.jl `src/temporal.jl` hard-codes the same `temporal_latent()` strings (complete Gaussian, bar form, trait-intercept block, three traits). Read-only; not changed here.

## 10. Known Limitations And Next Actions

Whether `temporal_indep()` / `temporal_dep()` should require three traits is open. The default abort action still points at `temporal_latent()` help. GLLVModels.jl still hard-codes `temporal_latent()` in `src/temporal.jl` at the lines recorded in the check-log. Later `gllvmTMB()` gates in `R/gllvmTMB.R` (Gaussian identity-link ML, Laplace, competing providers) still name `temporal_latent()`; they are not reached by the two-trait parser abort.
