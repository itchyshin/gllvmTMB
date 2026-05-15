# 2026-05-15 -- Phase 1c port: phylo-spatial-meta-analysis.Rmd

**PR type tag**: article

## Scope

Port `phylo-spatial-meta-analysis.Rmd` from `gllvmTMB-legacy/` into
the Model guides (Worked examples) tier. This is the **last
remaining Phase 1c article port**; after it lands, the Phase 1c
article-port programme is **structurally complete (13/13)**.

The article fills both open gaps from the Mizuno, Williams, Lagisz,
Senior & Nakagawa (2026) unified phylogenetic + spatial
meta-analysis framework:

1. Combining phylogeny *and* space in one model (rarely done in
   practice across `metafor`, `glmmTMB`, `brms`).
2. Multi-trait outcomes with a trait-covariance layer that none of
   the three reference packages exposes directly.

The model demonstrated is the full meta-analytic stack:
`phylo_scalar() + spatial_unique() + meta_known_V() + latent()` in
one `gllvmTMB()` call, plus the `block_V()` helper for compound-
symmetric within-study sampling correlation.

## Files changed

- `vignettes/articles/phylo-spatial-meta-analysis.Rmd` (NEW,
  ~420 lines): the full worked example.
- `_pkgdown.yml`: add `- articles/phylo-spatial-meta-analysis` to
  the Model guides tier.

## What changed from legacy

The legacy article was in good shape and required minor edits:

1. **Dropped the deprecated `fit_site_meta()` mention**. The
   legacy article referenced it as a "now-deprecated helper". The
   helper itself was removed pre-0.2.0, so the mention is no
   longer needed -- the direct `gllvmTMB()` call shown in the
   article is the canonical path.
2. **Added cross-links** to recently merged sibling articles:
   - `[Stacked-trait GLLVM](stacked-trait-gllvm.html)` (#126) --
     the full six-piece decomposition with replicated trait data.
   - `[Corvidae two-stage workflow](corvidae-two-stage.html)`
     (#124) -- a different `meta_known_V()` use case.
   - `[Cross-package validation](cross-package-validation.html)`
     (#128) -- agreement of `meta_known_V()` against
     `glmmTMB::equalto()`.
   - `[Simulation-based recovery](simulation-recovery.html)`
     (#129, pending) -- recovery of `phylo_scalar()` and
     `spatial_unique()` parameters on simulated data.
3. **Notation harmonisation**: `Sigma_B` -> `\boldsymbol{\Sigma}_{\text{unit}}`,
   `R_B` -> `\mathbf{R}_{\text{unit}}` to match the canonical
   matrix notation used across Phase 1c articles.
4. **YAML normalised** to match other recently merged Phase 1c
   articles (`cache = FALSE`, `eval = TRUE`, `message = FALSE`,
   `warning = FALSE`).
5. **No `S_B`/`psi_B` notation issues**: the article uses
   `Sigma_B` (matrix) and `lam_phy` (engine-derived scalar)
   throughout; it does not call `simulate_site_trait()` so no
   `psi_*` parameter rename was needed.

## Test plan / verification

- [x] Rmd renders via
  `pkgdown::build_article("phylo-spatial-meta-analysis", lazy = FALSE)`
  locally on macOS
- [x] `_pkgdown.yml` autolint clean (article in Model guides tier)
- [x] Banned-pattern self-audit (per Kaizen 11):
  - No `[function_name]` autolinks outside code chunks
  - No `[0, 1]` interval autolinks
  - No `[vignette("...")]` cross-refs (uses Rmd-style
    `[label](article.html)`)
- [x] CI 3-OS R-CMD-check runs `pkgdown::build_articles()` and
  catches render failures
- [x] All five fit chunks (`fit_phy`, `fit_spa`, `fit_both`,
  `fit_multi`, `fit_multi_block`) use canonical keywords with
  proper `trait`, `unit`, `known_V` arguments

## Roadmap tick

Phase 1c row in `ROADMAP.md`:
- Before: 12/13 in main + 1 in CI (#129 simulation-recovery)
- After this PR lands: **13/13 in main -- Phase 1c
  article-port programme structurally complete**.

After Phase 1c structural completion:
- Phase 1d navbar restructure (`_pkgdown.yml` taxonomy review)
- Phase 1e Rose + Darwin reframe sweep (incl. A1 IRT pedagogy
  note + A2 measurement-error callout + Anderson 2025 citation
  harmonisation)
- Phase 1f choose-your-model rewrite
- Phase 1 close gate

## What went well

- The legacy article was already structured according to current
  conventions (Rmd-style cross-refs, no `S_B` notation,
  canonical keyword form). Most edits were additive cross-links
  to the recently-merged sibling articles + minor notation
  polish.
- The article fills a unique pedagogical niche in the roster:
  meta-analysis users coming from `metafor` / `glmmTMB` /
  `brms` need a worked example that combines phylogeny + space
  + multi-trait + known sampling V in one fit. None of the
  other Phase 1c articles cover this intersection.
- The Mizuno et al. (2026) EcoEvoRxiv preprint framing
  ("spatial and phylogenetic random effects are the same
  statistical object on different distance metrics") gives the
  article a clean conceptual hook. The published preprint
  citation lets us avoid an in-prep citation here.
- The 9-section structure (framework -> simulate -> 1-trait
  phylo -> 1-trait spatial -> phylo+spatial -> multi-trait ->
  block-V -> diagnostics -> see also) provides a logical
  reading path for the meta-analyst who arrives knowing
  `metafor` but not `gllvmTMB`.

## What did not go smoothly

- The article uses a small simulated dataset (200 effect sizes)
  to keep render time reasonable. The legacy article notes that
  "warnings from `gllvmTMB_diagnose()` on small simulated data
  are normal" because meta-analytic intercepts are often weakly
  identified. This is honest pedagogy but means a reader's
  first impression of the diagnostic is a warning rather than a
  clean pass.
- The `meta_known_V()` desugaring boilerplate (creating `obs`
  and `grp_V` factors before the fit) is verbose. A future
  helper that hides this boilerplate would make the article
  cleaner; flagged for Phase 6 post-CRAN.

## Team learning (per AGENTS.md Standing Review Roles)

- **Pat** (applied PhD user): The 9-section structure walks the
  meta-analyst from familiar single-trait single-structure
  territory to the unified four-piece fit. The reader
  internalises the keyword grid by seeing each piece added
  incrementally rather than as a wall of formula syntax in
  section 1.
- **Darwin** (biology-first audience): The growth-and-survival
  effect-size framing is a real meta-analytic question (e.g.
  Lagisz et al., Nakagawa lab meta-analyses on amphibian
  population responses). Not a stylised toy.
- **Boole** (formula API): The article exercises
  `phylo_scalar(species, vcv = Cphy)` +
  `spatial_unique(0 + outcome | coords, mesh = ...)` +
  `meta_known_V(value, sampling_var = vi)` +
  `latent(0 + outcome | study, d = 1)` in one fit. Canonical
  keyword form throughout. No legacy keyword names.
- **Fisher** (inference semantics): The discussion of phylogeny
  / spatial competing-for-variance under correlated species
  geography is a real identifiability concern. Mentioned but
  not deeply explored; flagged for the Phase 1e Rose+Darwin
  sweep as a candidate for cross-link to `pitfalls.Rmd`.
- **Jason** (literature scout): The Mizuno et al. 2026
  EcoEvoRxiv preprint citation is the canonical reference for
  the "spatial = phylogenetic" framing. No in-prep Nakagawa
  citation needed for this foundational claim -- Mizuno 2026
  is the published version.
- **Rose** (pre-publish audit): Self-audited for banned-pattern
  cross-refs and notation consistency. The four sibling-
  article cross-links resolve once #129 lands (#126, #124,
  #128 are already in main; #129 is in CI).

## Follow-up

- After this PR lands, Phase 1c article-port programme is
  structurally complete (13/13). The remaining Phase 1 work is
  navbar restructure (1d), Rose+Darwin reframe sweep (1e), and
  choose-your-model rewrite (1f).
- Phase 1c PR count: **13 of 13 (100 %)** once this PR + #127 +
  #129 land. Total Phase 1c PRs from 2026-05-15 alone: 11
  (#108, #110-#115, #124, #125, #126, #127, #128, #129,
  plus this one = 12 articles + 1 hygiene PR #123).
