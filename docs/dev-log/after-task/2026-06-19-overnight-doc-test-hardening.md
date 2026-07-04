# After-task — Overnight doc + test hardening (two staged branches)

Date: 2026-06-19 (Claude / Ada + Curie, autonomous overnight run)
Mode: ultracode; maintainer away. PR-free, push-free, no row promotion.

## Scope

Safe autonomous hardening slices from the Phase-1 gap map (Ada's ranked plan,
Rose-audited), executed on clean isolated branches off `main` and `c061ce2`.
Hard guard held: no merge, no push, no scientific/register promotion, no
grammar/likelihood/family/TMB change.

## Outcome

### Branch `claude/doc-examples-20260619` (off `main`, commit `870f374`)
- **S7** — `latent()` and `traits()`, the two headline grammar entry points,
  had no roxygen `@examples` while sibling keywords did. Added `\dontrun`
  examples grounded in known-good calls: `latent()` uses the exported
  `simulate_site_trait()` long-format helper (mirrors
  `test-canonical-keywords.R`); `traits()` uses the README canonical wide call
  `traits(t1, t2, t3) ~ 1 + latent(1 | unit, d = 2)`. Default-Psi convention;
  no `unique()`.
- **OC1** — corrected the stale `_pkgdown.yml` `news.releases` comment that
  claimed the v0.2.0 tag / GitHub release "does not exist yet". Both exist (tag
  `416f8e4`; release "gllvmTMB 0.2.0 — first public release", 2026-06-04).
  Comment-only; **no `releases:` block added** (maintainer decision).
- Checks: `devtools::document()` regenerated `man/latent.Rd` + `man/traits.Rd`;
  `pkgdown::check_pkgdown()` clean; `git diff --check` clean. Unrelated
  `extract_correlations.Rd` roxygen-version drift reverted to stay surgical.
- **Second commit `facd82b`** — grounded `@examples` for 10 more exported
  functions, from the finder sweep (each re-grounded against its cited test
  fixture before applying): `gllvmTMBcontrol` (runnable, not `\dontrun` — the
  three calls were executed live to confirm), `flag_unreliable_loadings`,
  `meta_V`, `meta_known_V`, and the six `animal_*` keywords (`animal_scalar`,
  `animal_unique`, `animal_indep`, `animal_dep`, `animal_latent`,
  `animal_slope`). The `animal_slope` draft was corrected (it had invented a
  `(0+trait):x` term; rewritten to match the real ANI-06 test). Independently
  verified: all 10 `man/*.Rd` carry `\examples`; `document()` +
  `check_pkgdown()` clean; `git diff --check` clean; the same unrelated
  `extract_correlations.Rd` drift reverted again.

### Branch `claude/input-validation-tests-20260619` (off `main`, commit `edb6dc1`)
- **T1–T15** — 15 pure-R `expect_error` guards for already-documented abort
  branches, from the finder sweep, added to the matching existing test files
  (and a new `test-kernel-helpers.R`): `flag_unreliable_loadings` column /
  `null_region` guards; `make_cross_kernel` / `.cross_kernel_*` rho / eps / W
  dims / name-collision / matrix-type / finiteness / square / symmetry;
  `pedigree_to_A` column-count / duplicate-id; the `gllvmTMB()` REML scalar
  guard; `.qchisq_threshold` level range; `.invert_profile_derived` class guard.
- Each guard was verified two ways (correct substring matches the real abort;
  a deliberately-wrong substring makes the test fail) so none pass vacuously;
  cli/glue markup matched with `fixed = TRUE`.
- Independently re-verified by the orchestrator (filter
  `loading-ci|kernel-helpers|animal-keyword|gllvmTMBcontrol|gllvmTMB-input|profile-ci|profile-derived-curves`):
  **FAIL 0 | WARN 0 | SKIP 69 | PASS 76** (baseline 53; +23; SKIP unchanged —
  all new tests are ungated pure-R).

### Deferred (maintainer convention decision)
- ~20 grounded example drafts for diagnostics/profile/extractor functions
  (`profile_*`, `check_*`, `extract_Sigma_B/_W`, `extract_ICC_site`,
  `getResidualCov/Cor`, `ordiplot`, `VP`, `gllvmTMB_wide`) use the
  soft-deprecated paired `latent()+unique()` form from their test fixtures.
  Drafts are ready; publishing teaches deprecated syntax, and a naive
  `unique()`→`indep()` swap can change model structure. Left for the maintainer
  to choose the published form (see the morning briefing, decision item 5).

### Branch `claude/bridge-followups-20260619` (off `c061ce2` = #492 head)
- **S8** (commit `9f16865`) — added a `\dontrun` `@example` to the exported
  `gllvm_julia_fit()`, grounded in its real signature (`y` is p×n; admitted
  Gaussian no-X fit; Wald-CI no-X row). `\dontrun` because the bridge needs a
  local GLLVM.jl install.
- **S1–S3** (commit `6b5588476249ffc9de65912a78ec0b9ef9276a6e`) — pure-R
  negative tests for previously-untested defensive branches in
  `R/julia-bridge.R`, added to `tests/testthat/test-julia-bridge.R` using the
  existing `fake_*` fixtures (no Julia):
  - S1 `.gllvm_julia_normalise_result()` grouped-dispersion stops: group-id
    count ≠ p; non-finite/≤0 group; ids out of range.
  - S2 `.gllvm_julia_normalise_ci()`: length-mismatch stop; `ci_status`
    `"unavailable"` and `"empty"` status paths.
  - S3 `.gllvm_julia_mask_placeholder()`: per-family placeholders
    (poisson/binomial/negbinomial/nb1 → 0, beta → 0.5, gamma → 1,
    ordinal/ordinal_probit → 1) and the `switch()` default stop for
    gaussian/lognormal.
- **S5 skipped** (deliberate): `gllvm_julia_gate_registry()` already
  self-documents via `@return` + a `head()` example; enumerating 19 volatile
  gate ids in prose would only add drift.

## Checks

- Bridge gate (independently re-run by the orchestrator, not just the subagent):
  `env -u GLLVM_JL_PATH Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path=NULL);
  devtools::test(filter="julia-bridge")'` →
  **FAIL 0 | WARN 0 | SKIP 14 | PASS 373** (baseline 357; +16 = S1 3 + S2 3 +
  S3 10). The 14 skips are the unchanged live-Julia rows — the new tests add
  zero skips, confirming the pure-R tier alone grew.
- Doc branch: `document()` + `pkgdown::check_pkgdown()` clean.

## Definition-of-Done status (honest)

Documentation + test hardening only; no new feature/family/likelihood/grammar.
Both branches are **staged locally, un-pushed, PR-free** — folding them into
#492 / a sibling PR, and any merge, is the maintainer's call. No register row
moved off `partial`.

## Follow-up (maintainer)

- Decide whether to PR/merge `claude/doc-examples-20260619` (doc-only, low-risk,
  mergeable per AGENTS.md merge authority once CI'd) and
  `claude/bridge-followups-20260619` (builds on #492 head — merge order with
  #492 matters).
- Bridge `.jl` evidence note (proposed map slice S6) was **dropped**: the cited
  `test_bridge_capabilities.jl` / `test_bridge_mixed.jl` were not found at the
  expected `../GLLVM.jl-integration/test/` path, so no citation was added
  (cite-what-you-read).
