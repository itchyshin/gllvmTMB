# 2026-05-15 -- Phase 1c port: spde-vs-glmmTMB.Rmd

**PR type tag**: article

## Scope

Port `spde-vs-glmmTMB.Rmd` from `gllvmTMB-legacy/` into the
Model guides (Worked examples) tier. This is the **spatial
benchmark / motivation article**: a head-to-head timing
comparison of the sparse SPDE engine
(`gllvmTMB::spatial_unique()`) vs the dense
`glmmTMB::exp()` covariance path on the same multi-trait
multivariate spatial model.

The article fills the **spatial example deficit** from the
audit (P5): the existing roster has only `joint-sdm.Rmd` and
the spatial term as a subsection of `functional-biogeography.Rmd`
-- no article makes the case for *why* the sparse SPDE engine
matters until now.

## Files changed

- `vignettes/articles/spde-vs-glmmTMB.Rmd` (NEW, ~210 lines):
  the SPDE-vs-exp benchmark + crossover analysis.
- `_pkgdown.yml`: add `- articles/spde-vs-glmmTMB` to the
  Model guides tier.

## What changed from legacy

1. **Dropped `dev/precomputed/spde-bench.rds` dependency**.
   The legacy article loaded a precomputed RDS from
   `dev/precomputed/`, which doesn't exist in the current
   repo. The new port **inlines the 3-row benchmark data
   frame** literally as a `data.frame()` constructor so the
   article renders self-contained.
2. **`S_B -> psi_B`** in the `simulate_site_trait()` call (and
   removed the no-longer-present `S_B` shorthand since the new
   API uses `psi_B` directly).
3. **Renamed function references from
   `gllvmTMB::spatial()` to `gllvmTMB::spatial_unique()`**.
   The bare `spatial()` keyword is the deprecated alias; the
   canonical 3 x 5 keyword grid uses `spatial_unique()` for
   the diagonal-mode spatial covariance.
4. **Replaced `vignette("functional-biogeography")`
   cross-reference** with Rmd-style `[label](article.html)`
   per Kaizen 11 banned-pattern catalogue.
5. **Added cross-link to `[Stacked-trait GLLVM](stacked-trait-gllvm.html)`**
   so a reader of the spatial benchmark can navigate to the
   full-decomposition worked example showing
   `spatial_unique()` together with the other four modes.
6. **YAML header normalised** to match other recently merged
   Phase 1c articles (`cache = FALSE`, `eval = TRUE`,
   `message = FALSE`, `warning = FALSE`).

## Test plan / verification

- [x] Rmd renders via `pkgdown::build_article("spde-vs-glmmTMB", lazy = FALSE)`
  locally on macOS in under a minute (no benchmark execution;
  `bench_one()` is `eval = FALSE`)
- [x] `_pkgdown.yml` autolint clean (article in Model guides
  tier)
- [x] Banned-pattern self-audit (per Kaizen 11):
  - No `[function_name]` autolinks outside code chunks
  - No `[0, 1]` interval autolinks
  - No `[vignette("...")]` cross-refs (replaced with
    `[label](article.html)`)
- [x] CI 3-OS R-CMD-check runs `pkgdown::build_articles()` and
  catches render failures
- [x] Inline data frame matches the precomputed RDS at
  `_workshop/legacy-dev/precomputed/spde-bench.rds`
  (verified via Rscript readRDS)
- [x] `simulate_site_trait()` signature in `bench_one()`
  matches `R/simulate-site-trait.R` (uses `psi_B`,
  `sigma2_spa`, etc.)

## Roadmap tick

Phase 1c row in `ROADMAP.md`:
- Before: 9/13 in main + 1 in CI (#126 stacked-trait-gllvm)
- After this PR lands: 11/13 in main (assuming #126 lands
  first) -- spatial example deficit P5 closed.

Articles remaining for Phase 1c after this:
phylo-spatial-meta-analysis (the meta-analysis-style spatial
+ phylogeny example), cross-package-validation (Fisher + Jason
roster), simulation-recovery (Methods+validation tier).

## What went well

- Cleanest port of the day for the "drop precomputed
  dependency" case: replacing a `readRDS()` load with an
  inline `data.frame()` constructor is mechanically simple
  and removes a class of fragility (the article no longer
  cares where precomputed files live).
- The spatial-example deficit (audit P5) is now visibly
  addressed in the Model guides tier: a reader scanning the
  article roster sees "spde-vs-glmmTMB" as a flagship "why
  pick the SPDE engine" entry point.
- Cross-links to `[Stacked-trait GLLVM](stacked-trait-gllvm.html)`
  and `[Functional biogeography](functional-biogeography.html)`
  position this article as the *motivation* for the spatial
  term, with those two articles as the *demonstration*.

## What did not go smoothly

- The Anderson et al. 2025 sdmTMB citation in the legacy
  article points at *Journal of Statistical Software*
  (115(2):1-46), whereas the
  `stacked-trait-gllvm.Rmd` port (PR #126) cites *Journal of
  Open Source Software* (10(109):7536). One of these is
  wrong. The legacy article was written by the maintainer so
  I'm preserving the legacy JSS citation here and flagging
  the inconsistency. **Follow-up needed**: confirm the canonical
  Anderson 2025 sdmTMB citation and harmonise across all
  articles in the Phase 1e Rose reframe sweep.
- The benchmark is currently 3 reps per cell, on small
  fixtures (40, 80, 160 sites). A publication-grade timing
  would use `bench::mark()` or 10+ reps. The article notes
  this in Caveats but a hostile reader could complain.

## Team learning (per AGENTS.md Standing Review Roles)

- **Pat** (applied PhD user): The "what we found" summary
  section is the article's payload. A reader who skims to
  that section gets the answer to "when does the SPDE engine
  matter?" in three bullets. The benchmark code and
  asymptotic-complexity sections are for the reader who
  wants to verify. This 2-tier reading shape (skim
  conclusions, drill into details) is what worked-example
  articles should do.
- **Darwin** (biology-first audience): The article is
  computational-rationale not biological-question first.
  This is correct -- the question is "which engine for what
  size of dataset", not "what does this answer scientifically".
  Belongs in Model guides (Worked examples) tier as
  *infrastructure motivation*, not in Methods+validation.
- **Boole** (formula API): `spatial_unique(0 + trait | coords)`
  is the canonical keyword form (renamed from the legacy
  article's `spatial(...)` which used the deprecated bare-name
  alias). No formula-grammar deviation.
- **Gauss** (numerical correctness): The asymptotic claim
  (SPDE O(n_mesh^1.5) vs dense exp O(n^3) Cholesky) is the
  textbook complexity for these two paths. The crossover
  point (between n_sites=40 and n_sites=80 on the
  maintainer's hardware) is hardware-dependent but the
  *shape* of the curves is the invariant.
- **Jason** (literature scout): The Mizuno et al. 2026
  EcoEvoRxiv preprint is the right framing for "spatial and
  phylogenetic random effects are the same statistical object"
  -- a published article doesn't yet exist for this claim, so
  the EcoEvoRxiv preprint is the canonical reference.
- **Rose** (pre-publish audit): Self-audited for banned-pattern
  cross-refs, the JSS vs JOSS Anderson 2025 citation
  inconsistency flagged as Follow-up.

## Follow-up

- Phase 1c remaining ports: phylo-spatial-meta-analysis
  (416 LOC), cross-package-validation (358 LOC),
  simulation-recovery (409 LOC).
- Phase 1e Rose reframe sweep: confirm the Anderson 2025
  sdmTMB citation (JSS 115(2) vs JOSS 10(109)) and harmonise
  across all articles.
- Phase 1c PR count to CRAN: this is article 11 of 13 (~85%).
