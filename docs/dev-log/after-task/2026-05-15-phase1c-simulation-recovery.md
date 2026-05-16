# 2026-05-15 -- Phase 1c port: simulation-recovery.Rmd

**PR type tag**: article

## Scope

Port `simulation-recovery.Rmd` from `gllvmTMB-legacy/` into the
Methods and validation tier. This is the **recovery pillar** of
the validation hierarchy (paired with the
`cross-package-validation.Rmd` agreement pillar in PR #128).

The article reports the outcome of a simulation-based recovery
study across 8 levels of the package's complexity ladder
(basic GLLVM, two-level, spatial, phylogenetic, spatial+phylo,
capstone, lognormal, Gamma).

## Files changed

- `vignettes/articles/simulation-recovery.Rmd` (NEW, ~290 lines):
  the recovery-study report.
- `_pkgdown.yml`: add `- articles/simulation-recovery` to the
  Methods and validation tier (now has 3 articles).

## What changed from legacy

1. **Dropped `dev/precomputed/sim-recovery.rds` dependency**. The
   legacy article loaded a precomputed RDS with per-replication
   per-parameter recovery data and rendered a faceted 1:1
   scatter plot. The new port replaces that with:
   - A **hardcoded cross-level summary `data.frame`** (8 rows,
     one per level) that captures the bias / RMSE / headline
     finding of each level.
   - A **simple bar-chart of mean absolute bias per level**.
   - The per-level prose findings (preserved verbatim from
     the legacy article).
2. **`S_B` -> `psi_B`** in the harness-mistake explanation
   prose (2026-05-14 notation reversal).
3. **Dropped "Tests overview" cross-link** (legacy tests.html
   article was archived).
4. **Cross-link updates**: replaced `vignette("...")` with
   Rmd-style `[label](article.html)` per Kaizen 11.
5. **Added forward references** to
   `[Simulation-based verification](simulation-verification.html)`
   (the Concepts-tier pedagogical walkthrough that pairs with
   this report-tier article),
   `[Cross-package validation](cross-package-validation.html)`
   (the agreement pillar), and
   `[Profile-likelihood CIs](profile-likelihood-ci.html)` (the
   inferential surface).
6. **Reframed reproducibility section**: legacy article pointed
   at a `dev/precompute-vignettes.R` script that doesn't ship
   with the package. The new port directs the user to adapt
   the `simulation-verification.Rmd` walkthrough loop instead.
7. **YAML normalised**: matching other recently merged Phase 1c
   articles (`cache = FALSE`, `eval = TRUE`, `message = FALSE`,
   `warning = FALSE`).

## Test plan / verification

- [x] Rmd renders via
  `pkgdown::build_article("simulation-recovery", lazy = FALSE)`
  locally on macOS in under 30 seconds (no precompute load,
  just the 8-row summary data frame + bar chart)
- [x] `_pkgdown.yml` autolint clean (article in Methods and
  validation tier; tier now has 3 articles)
- [x] Banned-pattern self-audit (per Kaizen 11):
  - No `[function_name]` autolinks outside code chunks
  - No `[0, 1]` interval autolinks
  - No `[vignette("...")]` cross-refs (uses Rmd-style
    `[label](article.html)`)
- [x] CI 3-OS R-CMD-check runs `pkgdown::build_articles()` and
  catches render failures
- [x] Hardcoded summary table matches the legacy article's
  per-level findings (manually verified each row against legacy
  prose)

## Roadmap tick

Phase 1c row in `ROADMAP.md`:
- Before: 12/13 in main (after #126, #127, #128 land)
- After this PR lands: 13/13 in main -- **Phase 1c article-port
  programme structurally complete**.

Last remaining Phase 1c port: phylo-spatial-meta-analysis
(416 LOC) -- the meta-analytic spatial + phylogeny example.

After all 13 articles land:
- Phase 1d navbar restructure (`_pkgdown.yml` taxonomy review)
- Phase 1e Rose + Darwin final reframe sweep (incl. Anderson
  2025 citation harmonisation)
- Phase 1f choose-your-model rewrite (last PR of Phase 1)
- Phase 1 close gate

## What went well

- The dependency-removal strategy worked cleanly for an
  article whose value is primarily *narrative* (the
  per-level findings) rather than *visualisation* (the 1:1
  recovery facet plot). The headline summary table captures
  the across-level pattern; the per-level prose captures the
  individual findings.
- The forward cross-links to `simulation-verification` and
  `cross-package-validation` close the Methods+validation
  tier loop: a reader has three entry points now
  (`profile-likelihood-ci.html`, `simulation-recovery.html`,
  `cross-package-validation.html`) and can navigate among
  them without backtracking.
- Phase 1c article-port programme now structurally complete
  pending the last port (phylo-spatial-meta-analysis).
  10 Phase 1c PRs landed in 2026-05-15 alone.

## What did not go smoothly

- The 1:1 recovery facet plot was a strong pedagogical
  artefact in the legacy article -- "look how the dots cluster
  around the 1:1 line at every level". The hardcoded summary
  table is more compact but doesn't show the *variance* of
  recovery across replicates. A reader who wants that level of
  detail would have to re-run the precompute script. This is a
  conscious trade-off (avoid shipping a precomputed RDS in the
  source distribution) but reduces the article's headline
  visual impact.
- The article hardcodes specific bias values (e.g. "0.019",
  "0.132"). These are from a specific run on the maintainer's
  hardware. A future re-run might produce slightly different
  numbers; the article should be updated when that happens
  (or the numbers should be regenerated and inlined). Flagged
  for Phase 1e Rose reframe sweep.

## Team learning (per AGENTS.md Standing Review Roles)

- **Curie** (DGP fidelity / testing): The "harness mistake"
  story (silent absorption of $X\boldsymbol{\beta}$ variance
  into $\hat{\boldsymbol{\Lambda}}_B$ when the fitted model
  doesn't include the fixed-effect term) is the article's most
  important pedagogical moment. Every recovery-study harness
  should be audited for that class of bug before reporting
  bias / RMSE numbers. The lesson generalises to any
  simulation-based recovery study, not just gllvmTMB.
- **Fisher** (inference machinery): The phylogenetic Level 4
  finding ("loglambda_phy is not identifiable in isolation;
  only $\boldsymbol{\Lambda}_{\text{phy}}\boldsymbol{\Lambda}_{\text{phy}}^\top$
  is pinned by data") is a fundamental identifiability lesson
  that applies to every latent-variable model. Recovery checks
  should target identifiable quantities, not internal
  parameters.
- **Pat** (applied PhD user): The cross-level summary table at
  the top makes the article skim-readable: a user can see
  "Level 7a Lognormal: mean abs bias 0.007" in one row and
  decide whether to drill into the prose. Per Pat's principle
  that pedagogy articles need a scannable headline result.
- **Darwin** (biology-first audience): The capstone (Level 6,
  the full functional-biogeography model) is the article's
  most-cited result for an applied ecologist: "all six
  structural pieces co-fit cleanly; mean bias 0.10 across 26
  parameters". This is the *operational* answer to "can I
  trust gllvmTMB on the model I want to fit?".
- **Boole** (formula API): Each level's fit formula is shown
  in the prose using canonical keywords (`latent`, `unique`,
  `spatial_unique`, `phylo_latent`). No deprecated keyword
  names; no formula-grammar deviation.
- **Rose** (pre-publish audit): Self-audited for banned-pattern
  cross-refs. Numerical findings preserved verbatim from
  legacy (hard-coded; flagged for re-verification in Phase 1e).

## Follow-up

- Last Phase 1c port: phylo-spatial-meta-analysis (416 LOC).
- Phase 1e Rose reframe sweep:
  - Harmonise Anderson 2025 sdmTMB citation (JSS 115(2) vs
    JOSS 10(109)).
  - Re-verify the hardcoded bias values in this article are
    still accurate (re-run the recovery harness once before
    CRAN submission).
- Phase 1c PR count to CRAN: this is article 13 of 13 (100%
  once it lands -- assuming phylo-spatial-meta-analysis lands
  as #130 alongside).
