# gllvmTMB roadmap

## Phase 0 — bootstrap (0.2.0)  Status: in flight

The 2026-05-10 reset: started gllvmTMB from a clean repo, modelled on
drmTMB's "regimented" team and tooling. Cherry-picked the
gllvmTMB-native subset from the legacy repo; cut the 68 sdmTMB-
inherited exports that were not engine-coupled.

- Package skeleton: DESCRIPTION, NAMESPACE (auto), .Rbuildignore,
  inst/COPYRIGHTS, src/Makevars, src/gllvmTMB.cpp.
- R/: gllvmTMB-native parser + extractors + methods (~30 files).
- tests/testthat/: gllvmTMB-using tests only (~75 files); inherited
  sdmTMB tests dropped.
- vignettes/: Get Started + 7 Tier-1 worked-example articles.
- Team: drmTMB-canonical roles in `.codex/agents/` (10 files) and
  `.agents/skills/` (6 skills, including the new
  `article-tier-audit` skill and the symbolic-math alignment
  bake-in to `add-simulation-test`).
- docs/: design + dev-log scaffolding modelled on drmTMB.
- CI: 3-OS R-CMD-check + pkgdown workflows.

## Phase 1 — finalise the cuts (0.2.1)  Status: planned

The 0.2.0 bootstrap left some "hide-internal" functions still
@export'd because the existing test suite calls them by bare name.
0.2.1 finishes the cuts:

- Hide `extract_Sigma_B`, `extract_Sigma_W`, `getLoadings`, `getLV`,
  `getResidualCov`, `getResidualCor`, `VP`, `ordiplot`,
  `extract_two_U_via_PIC`, `compare_PIC_vs_joint`, `gengamma`, the
  `profile_ci_*` quartet, and `block_V` -- update tests to use
  `gllvmTMB:::` prefix or migrate to canonical alternatives.
- Drop the unused families (`gamma_mix`, `lognormal_mix`,
  `nbinom2_mix`, `nbinom1`, `truncated_nbinom1`, `censored_poisson`,
  `delta_beta`, `delta_gamma_mix`, `delta_gengamma`,
  `delta_lognormal_mix`, `delta_truncated_nbinom1`,
  `delta_truncated_nbinom2`, `delta_poisson_link_gamma`,
  `delta_poisson_link_lognormal`) -- these have no engine slot in
  `R/fit-multi.R`'s family map and would fail at fit time anyway.

## Phase 2 — CRAN-readiness (0.2.x)  Status: planned

The CRAN blockers identified in the 2026-05-10 audit:

- Title `<= 65` chars (already met: 30 chars).
- DESCRIPTION cph trimmed to surviving upstream code (already
  trimmed: 5 cph entries).
- NEWS.md restructured to `# gllvmTMB 0.2.0` / `## Major changes`
  format.
- Vignette built by R CMD check fits a small fast model (or use
  precomputed .rds and `--no-build-vignettes`-friendly fallbacks).
- 3-OS CI green for >= 2 weeks.
- DOIs in DESCRIPTION verified by `tools:::doi_db()` or curl.
- `cran-comments.md` written.

## Phase 3 — methods paper (1.0.0)  Status: planned

The Nakagawa et al. (in prep.) functional-biogeography manuscript
serves as the package's methods paper. 1.0.0 ships when:

- the manuscript is accepted;
- a reproducibility-report article in `vignettes/articles/` mirrors
  the manuscript's analysis;
- the public API is frozen.

## Phase 4 — extensions (post-1.0)  Status: planned

The legacy package's deferred design notes record candidates:

- `add_barrier_mesh()` SPDE barrier path for coastal data;
- random-slope bar syntax `(1 + x | g)` (currently
  intercept-only is supported);
- ZINB / zero-inflated Poisson for sparse count traits;
- two-level `phylo + cluster` cross-pollination (the audit's
  "two-U" path -- currently exposed as `compare_dep_vs_two_U()`
  and `compare_indep_vs_two_U()`).

Each extension follows the `add-family` / `add-simulation-test`
skills.

## Out of scope

- Single-response models (use `glmmTMB`).
- Spatial-only single-response models (use `sdmTMB`).
- Bayesian sampling (use `brms` or `MCMCglmm`).
- Dimension-reduction-only (without a likelihood model -- use
  `gllvm` for that flavour).
