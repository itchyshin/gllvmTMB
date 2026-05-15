# 2026-05-15 -- Phase 1c port: cross-package-validation.Rmd

**PR type tag**: article

## Scope

Port `cross-package-validation.Rmd` from `gllvmTMB-legacy/` into
the Methods and validation tier. This is the **cross-package
agreement pillar** of the validation hierarchy (alongside the
queued `simulation-recovery.Rmd` as the *recovery* pillar). It
demonstrates byte-level agreement between `gllvmTMB` and its peer
packages on identical fits, plus a Procrustes-aligned loading
comparison against `gllvm`.

## Files changed

- `vignettes/articles/cross-package-validation.Rmd` (NEW, ~310
  lines): the validation matrix + 2 live cross-package fits + a
  Phase 5.5 queue summary.
- `_pkgdown.yml`: add `- articles/cross-package-validation` to the
  Methods and validation tier (now has 2 articles).

## What changed from legacy

1. **Removed `brms` from the comparator roster entirely**. Per the
   2026-05-14 Fisher second-pass consult, `brms` is deferred
   post-CRAN because of known identifiability pathologies on
   GLLVM-style models (double-peaked posteriors when only
   $\Lambda\Lambda^\top$ is identifiable; residual covariance
   unidentifiability when latent variance and residual variance
   both float). The legacy article had brms as "⚠ optional, with
   caveats"; the new port replaces it with a single sentence in
   the matrix saying brms + lavaan are post-CRAN.
2. **`S_B -> psi_B`** in two `simulate_site_trait()` calls
   (2026-05-14 notation reversal).
3. **Dropped `[Tests overview](tests.html)` cross-link**. The
   legacy article pointed at `tests.html` (an archived legacy
   article that the current ROADMAP roster does not include).
   Replaced with a plain text reference to the standard test
   suite.
4. **Added "Why gllvmTMB adds value over gllvm and galamm" section**.
   Per the 2026-05-14 galamm-inspired-extensions scan, this
   article should highlight the **inference differentiator**:
   `gllvmTMB` ships `confint(method = c("wald", "profile",
   "bootstrap"))` plus derived-quantity profile CIs (repeatability,
   communality, phylo signal, correlations); `gllvm` and `galamm`
   are both **Wald-only**. This is the package's most defensible
   advantage in the validation narrative.
5. **Updated queued-comparator list**: dropped brms, kept
   MCMCglmm + Hmsc + galamm + sdmTMB. galamm gets an explicit
   "where Wald under-covers, gllvmTMB's profile path wins"
   framing.
6. **Updated citation list to be complete**: added Hadfield 2010,
   Hadfield & Nakagawa 2010, Niku et al. 2019, Sørensen et al.
   2023, Tikhonov et al. 2020 in the references section. Legacy
   had inline citations only.
7. **Phase 5.5 framing**: the legacy article said "coming soon"
   for the queued comparators. The new port explicitly ties them
   to the Phase 5.5 external validation sprint (per the
   2026-05-14 maintainer decision to add Phase 5.5).
8. **YAML normalised** to match other recently merged Phase 1c
   articles.

## Test plan / verification

- [x] Rmd renders via
  `pkgdown::build_article("cross-package-validation", lazy = FALSE)`
  locally on macOS (the `gllvm`-dependent section gracefully
  falls back to a notice when `gllvm` isn't installed)
- [x] `_pkgdown.yml` autolint clean (article in Methods and
  validation tier)
- [x] Banned-pattern self-audit (per Kaizen 11):
  - No `[function_name]` autolinks outside code chunks
  - No `[0, 1]` interval autolinks
  - No `[vignette("...")]` cross-refs (uses Rmd-style
    `[label](article.html)`)
- [x] CI 3-OS R-CMD-check runs `pkgdown::build_articles()` and
  catches render failures
- [x] `simulate_site_trait()` API parameters match
  `R/simulate-site-trait.R` signature (uses `psi_B`, not `S_B`)
- [x] Two cross-package agreement fits exercise: (a) `glmmTMB`
  log-likelihood agreement via `rr() + diag()`, (b) `gllvm`
  Procrustes-aligned loadings via `compare_loadings()`
- [x] gllvm section is gated by `requireNamespace()` and renders
  even when gllvm is absent

## Roadmap tick

Phase 1c row in `ROADMAP.md`:
- Before: 11/13 in main (assumes #126 + #127 land first)
- After this PR lands: 12/13 in main

Articles remaining for Phase 1c after this:
phylo-spatial-meta-analysis (416 LOC) and simulation-recovery
(409 LOC).

## What went well

- The article structure stood the test of time: the
  validation-matrix table + 2 live cross-package fits + queued
  comparators is the right pedagogical shape. Most changes were
  trimming (brms drop, tests.html drop) and adding the inference-
  differentiator section.
- The "Why gllvmTMB adds value over gllvm and galamm" section
  closes the loop on the audit's concern about positioning: a
  reader who runs the cross-package fits and sees byte-level
  agreement might wonder *why* use gllvmTMB at all over its
  peers; this section answers that with a concrete inference
  argument (profile-CI completeness) that doesn't depend on
  performance benchmarks.
- The Phase 5.5 framing for queued comparators ties the article
  forward to the external validation sprint, which is the
  CRAN-credibility deliverable.

## What did not go smoothly

- The `gllvm`-dependent section ships with conditional eval
  (`eval = GLLVM_OK`) so the article degrades gracefully on
  CI where `gllvm` isn't installed. This means CI users won't
  see the Procrustes alignment; they get a "install gllvm
  locally" notice instead. The article is still self-contained
  but the CI-rendered output is incomplete for that section.
- The Anderson 2025 sdmTMB citation still uses the legacy JSS
  reference (115(2):1-46). PR #126 stacked-trait-gllvm uses
  JOSS. Phase 1e Rose sweep should reconcile.

## Team learning (per AGENTS.md Standing Review Roles)

- **Fisher** (statistical inference): The "Why gllvmTMB adds value
  over gllvm and galamm" section is the inference-completeness
  argument. galamm's `confint.galamm()` documents only Wald;
  gllvm's `confint.gllvm()` is Wald only. gllvmTMB's three-method
  `confint.gllvmTMB_multi()` + derived-quantity profile CIs
  (PR #119 + PR #120 + PR #122) make the package the
  inference-complete alternative for non-quadratic profile
  shapes -- exactly where Wald CIs systematically under-cover.
- **Jason** (literature scout): The comparator roster matches the
  2026-05-14 plan: glmmTMB, gllvm, galamm, sdmTMB, MCMCglmm, Hmsc.
  brms deferred post-CRAN per Fisher; lavaan deferred post-CRAN
  per the galamm-inspired-extensions scan. The Mizuno et al. 2026
  EcoEvoRxiv preprint for "spatial = phylogenetic" reframing is
  not yet in this article (it's framed in
  [SPDE vs glmmTMB](spde-vs-glmmTMB.html)); cross-package-validation
  focuses on engine-level agreement, not on the higher-level
  unification.
- **Pat** (applied PhD user): The article opens with the
  validation hierarchy distinction: *correctness* (recovery) vs
  *agreement* (cross-package). A reader can decide which of the
  two pillars they care about and navigate to the right article
  (this one for agreement, simulation-recovery for correctness).
- **Curie** (DGP / testing): The article reuses
  `simulate_site_trait()` in canonical form. No bespoke DGP; the
  same simulator drives both the Gaussian agreement fit and the
  binomial Procrustes-alignment fit.
- **Boole** (formula API): Both `latent + unique` (canonical
  paired form) and `rr() + diag()` (glmmTMB's native form) are
  shown side-by-side. The reader sees the keyword mapping
  explicitly: `gllvmTMB::latent()` corresponds to
  `glmmTMB::rr()`; `gllvmTMB::unique()` corresponds to
  `glmmTMB::diag()`.
- **Rose** (pre-publish audit): Banned-pattern audit clean.
  In-prep citation discipline: no Nakagawa in-prep citation
  used as foundational; the McGillycuddy 2025 paper (the
  published `glmmTMB::rr()` source) is the foundational
  citation for the reduced-rank machinery.

## Follow-up

- Phase 1c remaining ports: phylo-spatial-meta-analysis
  (416 LOC) and simulation-recovery (409 LOC).
- Phase 1e Rose reframe sweep: harmonise Anderson 2025 sdmTMB
  citation across all articles (JSS vs JOSS).
- Phase 5.5 external validation sprint will execute the queued
  comparators (MCMCglmm, Hmsc, galamm, sdmTMB live fits) on a
  wider DGP grid.
- Phase 1c PR count to CRAN: this is article 12 of 13 (~92%).
