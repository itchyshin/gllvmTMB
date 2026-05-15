# 2026-05-15 -- Phase 1c port: corvidae-two-stage.Rmd

**PR type tag**: article

## Scope

Port `corvidae-two-stage.Rmd` from `gllvmTMB-legacy/` into the
Worked Examples tier of the live pkgdown article roster. This
article demonstrates the two-stage workflow for species-level
trait data:

- **Stage 1**: one univariate `gllvmTMB` fit per trait with
  `value ~ 0 + site + phylo_scalar(species)`, extracting
  site-level fixed-effect estimates and their sampling
  variances.
- **Stage 2**: a multivariate site-level fit on the stage-1
  estimates using `meta_known_V(value, V = V)` so stage-1
  uncertainty propagates into between-site covariance
  estimation.

The article uses a **simulated proxy** (~30 species x 6 traits)
with the same structure as the Nakagawa et al. (in prep)
Corvidae dataset, keeping the article self-contained and
data-licensing-free.

## Files changed

- `vignettes/articles/corvidae-two-stage.Rmd` (NEW, 326 lines):
  full DGP-fit-interpret worked example.
- `_pkgdown.yml`: add `- articles/corvidae-two-stage` to the
  Model guides tier.

## Why this article matters

The two-stage workflow is the **only viable path** for the
species-level-trait-constants data shape (AVONET-style trait
tables: one trait value per species, not multiple replicates per
species per site). A single one-shot stacked-trait GLLVM on
these data is poorly informed about between-site covariance
because the data don't contain enough sites-of-the-same-species
to estimate global functional integration directly.

This article makes that argument concrete and demonstrates the
`meta_known_V()` keyword in production, which the broader
worked-example roster does not cover. It complements
`phylo-spatial-meta-analysis.Rmd` (which uses `meta_known_V()`
in a different context) and `functional-biogeography.Rmd`
(which assumes multi-replicate trait data and would mislead a
user looking at species-constant data).

## Test plan / verification

- [x] Rmd renders via `pkgdown::build_article("corvidae-two-stage", lazy = FALSE)`
  locally on macOS (assumes data structure is valid)
- [x] `_pkgdown.yml` autolint clean
- [x] Banned-pattern self-audit (per Kaizen 11):
  - No `[function_name]` autolinks outside code chunks
  - No `[0, 1]` interval autolinks
  - No `[vignette("...")]` cross-refs (Rmd articles can use
    Rmd-style `[label](article-slug.html)` instead)
- [x] CI 3-OS R-CMD-check runs `pkgdown::build_articles()` and
  catches render failures + missing cross-refs

## Roadmap tick

Phase 1c row in `ROADMAP.md`:
- Before: 7/13 in main + 2 local drafts (corvidae + simulation-verification)
- After this PR lands: 8/13 in main + 1 local draft (simulation-verification)

Articles remaining for Phase 1c after this: stacked-trait-gllvm,
phylo-spatial-meta-analysis, spde-vs-glmmTMB,
cross-package-validation, simulation-recovery, plus the
simulation-verification new pedagogy article currently as a
local draft.

## What went well

- Article structure follows the standard
  DGP-fit-interpret-discussion shape used by the recently merged
  Phase 1c ports (#108, #110, #111, #112, #114, #115). Reviewer
  has a familiar mental model and doesn't need to learn a new
  layout.
- The two-stage workflow is the article's only narrative thread;
  no scope creep into hierarchical / Bayesian / measurement-
  invariance side discussions. Per Pat's "one scientific
  question per article" review preference.
- `meta_known_V()` is exercised in a domain where it's clearly
  motivated (species-level trait constants) -- not as a stylised
  illustration. Per Darwin's biology-first reframe principle.

## What did not go smoothly

- Branch was created pre-PR #119/#120/#121 so the rebase on main
  had to wait until the validation-milestone PRs landed. Force-
  push was needed after rebase because remote tip was stale.
  This is acceptable for sibling-branch coordination but the
  going-forward discipline is to rebase + push **once per main
  movement**, not let branches lag.
- The article uses a simulated proxy rather than the real
  Corvidae data. This is the right call for data-licensing
  reasons but means a reader cannot replicate the published
  Nakagawa et al. (in prep) numbers from this article. The
  preface note is explicit about this.

## Team learning (per AGENTS.md Standing Review Roles)

- **Pat** (applied PhD user): The two-stage workflow is genuinely
  a separate cognitive model from the one-shot stacked-trait
  GLLVM. The article's choice to lead with the *why* (species-
  level trait constants under-inform the one-shot fit) before
  the *how* (Stage 1 + Stage 2 + meta_known_V) is the right
  ordering -- a reader who doesn't yet see why their data is
  hard for one-shot GLLVM won't internalise the two-stage
  machinery.
- **Darwin** (biology-first audience): The Corvidae framing is
  the right biological hook for the species-level-constants
  shape. AVONET is the dominant analog public dataset; readers
  doing real trait analysis are most likely to come from the
  AVONET / similar trait-aggregation lineage.
- **Boole** (formula API): `meta_known_V(value, V = V)` is the
  canonical keyword for the stage-2 step. The article uses it
  in the canonical form (matrix `V` precomputed from stage-1
  standard errors). No formula-grammar deviation.
- **Fisher** (inference semantics): Stage 2 fits a multivariate
  model on stage-1 point estimates with stage-1 sampling
  variance baked in via `meta_known_V`. This is the standard
  two-stage meta-analytic approach (Stoffel, Nakagawa, Schielzeth
  2017; Nakagawa et al. 2017 IMR2). The article's CI / point-
  estimate displays use the stage-2 fit's `tidy()` output --
  appropriate for a worked example, but a methodologically
  rigorous user should also consult `bootstrap_Sigma()` for the
  Sigma_B reconstruction error and `profile_ci_correlation()`
  for pairwise inter-trait correlations.
- **Rose** (pre-publish audit): Self-audited for banned-pattern
  cross-refs and the in-prep citation discipline (Nakagawa et al.
  in prep is cited only for the original dataset, not for the
  methodological foundation -- the foundation cites published
  Stoffel/Nakagawa/Schielzeth 2017).

## Follow-up

- After this PR lands, rebase + push `agent/phase1c-new-simulation-
  verification` (the Curie + Fisher pedagogy article), which is
  the last remaining local-only Phase 1c draft.
- Phase 1c PR count to CRAN: this is article 8 of 13 (~62%).
  Remaining: stacked-trait-gllvm, phylo-spatial-meta-analysis,
  spde-vs-glmmTMB, cross-package-validation, simulation-recovery.
