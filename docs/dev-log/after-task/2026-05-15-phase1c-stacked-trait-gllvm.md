# 2026-05-15 -- Phase 1c port: stacked-trait-gllvm.Rmd

**PR type tag**: article

## Scope

Port `stacked-trait-gllvm.Rmd` from `gllvmTMB-legacy/` into the
Model guides (Worked examples) tier. This is the **foundational**
worked example for the package: a single fit that exercises the
full Nakagawa-style decomposition with global + local +
phylogeny + non-phylogenetic species + spatial + per-observation
residual terms.

## Files changed

- `vignettes/articles/stacked-trait-gllvm.Rmd` (NEW, ~190 lines):
  the full-decomposition worked example.
- `_pkgdown.yml`: add `- articles/stacked-trait-gllvm` to the
  Model guides tier.

## What changed from the legacy version

1. **Dropped "Nakagawa et al. (in prep.)" foundational citation**
   for the reduced-rank decomposition. Replaced with published
   foundations: Hui et al. 2017 (MEE), Niku et al. 2017 (JABES),
   Bollen 1989, Mulaik 2010 (factor-analysis convention),
   Anderson et al. 2025 (SPDE). Per Darwin's in-prep-citation
   discipline: cite Nakagawa et al. in prep **only** where the
   published literature doesn't already contain the result.
2. **`S_B` -> `psi_B`, `S_W` -> `psi_W`** per the
   `decisions.md` 2026-05-14 notation reversal. The
   `simulate_site_trait()` source confirms the current API uses
   `psi_*`.
3. **Dropped "Eq. 13 / 14 / 15" and "(§3.13)" in-prep
   manuscript section references**. The pedagogy doesn't need
   them; the article's biological questions stand on their own.
4. **Dropped "Phase L syntax" mention**. Internal jargon; the
   reader doesn't need to know about the package's internal
   development phases.
5. **Added biology-first preface** per Darwin reframe
   principle: lead with the 5-part scientific question the fit
   answers, then describe the model machinery. The legacy
   article led with the equation.
6. **Replaced `vignette("corvidae-two-stage")` cross-reference**
   with an Rmd-style `[label](corvidae-two-stage.html)` link
   per Kaizen 11 banned-pattern catalogue.
7. **Added cross-links** to the three already-merged Concepts
   articles (gllvm-vocabulary, api-keyword-grid,
   profile-likelihood-ci, simulation-verification) so a reader
   can navigate to the vocabulary / inference / verification
   surfaces from this entry point.
8. **YAML header normalised** to match other recently merged
   articles: dropped `author`, `date`, added `toc_depth: 3`,
   `fig.align: "center"`, `message = FALSE`, `warning = FALSE`,
   `cache = FALSE`.

## Test plan / verification

- [x] Rmd renders via `pkgdown::build_article("stacked-trait-gllvm", lazy = FALSE)`
  locally on macOS
- [x] `_pkgdown.yml` autolint clean (article listed in Model guides tier)
- [x] Banned-pattern self-audit (per Kaizen 11):
  - No `[function_name]` autolinks outside code chunks
  - No `[0, 1]` interval autolinks
  - No `[vignette("...")]` cross-refs (replaced with Rmd-style
    `[label](article.html)`)
- [x] CI 3-OS R-CMD-check runs `pkgdown::build_articles()` and
  catches render failures + missing cross-refs
- [x] `simulate_site_trait()` API parameters match
  `R/simulate-site-trait.R` signature (`psi_B`, `psi_W`,
  `sigma2_phy`, `sigma2_sp`, `sigma2_spa`)

## Roadmap tick

Phase 1c row in `ROADMAP.md`:
- Before this PR: 9/13 in main (assuming #124 + #125 land first)
- After: 10/13 in main

Articles remaining for Phase 1c after this:
phylo-spatial-meta-analysis, spde-vs-glmmTMB,
cross-package-validation, simulation-recovery.

## What went well

- Cleanest port of the day: the legacy article was already
  well-structured, so most changes were notation alignment
  (`S_*` -> `psi_*`) and in-prep citation cleanup (drop "Eq. N"
  references; replace foundational citation).
- The 5-part scientific-question framing in the preface
  makes the article navigable from the biology side; a
  reader who doesn't already know they want a "full stacked-
  trait GLLVM" can recognise their question in one of the 5
  bullets.
- Cross-links to four other articles (vocabulary, keyword
  grid, profile-likelihood-ci, simulation-verification,
  corvidae-two-stage) position this as the **hub** worked
  example.

## What did not go smoothly

- The article's `fit` chunk is `eval = FALSE` because the
  full-decomposition fit takes too long to render in CI. A
  reader cannot copy-paste the article output to verify their
  own fit matches; they have to actually run it themselves.
  This is the standard pattern for the foundational worked
  example but is a known UX weakness.
- The simulator uses `sigma2_*` (sigma-squared notation) for
  the phylogenetic / species / spatial variance scalars, but
  `psi_*` (psi notation) for the trait-unique-variance vectors.
  This is a deliberate distinction (the scalar variances are
  not part of the $\boldsymbol{\Psi}$ matrix), but a reader
  may find the mixed notation confusing. Mentioned but not
  fully resolved in the article.

## Team learning (per AGENTS.md Standing Review Roles)

- **Pat** (applied PhD user): The biology-first preface ("a
  single fit answers a multi-part question") is the entry-point
  framing applied users need. Without it, the article reads as
  a model-machinery walkthrough and the user has to back-infer
  which question the model answers. With it, the user can
  recognise their question in one of the 5 bullets and decide
  whether to read on.
- **Darwin** (biology-first audience): The reframe places the
  scientific question above the model decomposition equation.
  In-prep citations now appear only where the methodology is
  genuinely engine-specific (the `simulate_site_trait()` API,
  the `tests/testthat/test-stage[2-3]-*.R` cross-validation).
  Foundational citations point at the published literature
  (Hui 2017, Niku 2017, Bollen 1989, Mulaik 2010, Anderson 2025).
- **Boole** (formula API): The `latent + unique` paired keyword
  + `phylo_scalar + unique` paired keyword + `spatial_unique`
  + per-obs residual decomposition is exercised in canonical
  form. No legacy keyword names; no `Sigma = Lambda Lambda^T +
  diag(U)` math (psi notation throughout).
- **Gauss** (TMB-likelihood numerical correctness): The
  cross-validation against `glmmTMB` claim ("`gllvmTMB`'s
  log-likelihood matches `glmmTMB::glmmTMB()` exactly to TMB
  tolerance") is verified in `tests/testthat/test-stage[2-3]-*.R`
  -- pointer is correct as of 2026-05-15.
- **Rose** (pre-publish audit): Self-audited for banned-pattern
  cross-refs, in-prep citation discipline, and notation
  consistency with `decisions.md` 2026-05-14 (psi everywhere
  for trait-unique-variance; sigma^2 for the variance scalars
  on phylogeny / non-phylo species / spatial).
- **Jason** (literature scout): Citation roster updated --
  Anderson et al. 2025 for sdmTMB SPDE machinery (replaces
  any "in prep" claim about the spatial path), Niku et al.
  2017 for GLLVM count/biomass data (a published foundation
  the legacy article didn't cite).

## Follow-up

- After this PR lands, Phase 1c remaining ports:
  phylo-spatial-meta-analysis (416 lines, spatial deficit P5),
  spde-vs-glmmTMB (213 lines, spatial deficit P5),
  cross-package-validation (358 lines, Fisher + Jason: 6
  comparators including galamm),
  simulation-recovery (409 lines, Methods+validation tier
  30-rep study).
- Phase 1c PR count to CRAN: this is article 10 of 13 (~77%).
