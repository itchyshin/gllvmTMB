# After-Task Report: Psi / `unique()` Second Article Sweep

**Date:** 2026-06-18 16:42 MDT
**Branch:** `codex/r-bridge-grouped-dispersion`
**Guard:** `PR green != bridge complete != release ready != scientific coverage passed`

## Scope

This slice followed the coevolution model closeout by continuing the
Psi / `unique()` cleanup called out on the local mission-control
dashboard. It did not change formula grammar, parser behavior, TMB
likelihoods, or exported functions.

## Outcome

- `response-families.Rmd` now separates identifiable observation-level
  `unique()` terms from standalone marginal diagonal tiers, which should use
  `indep()`.
- `animal-model.Rmd` now teaches `animal_indep()` for standalone marginal
  genetic diagonals, keeps `animal_unique()` as explicit genetic Psi in
  `animal_latent() + animal_unique()`, and removes stale wording that said the
  ANI-11 augmented `animal_unique(1 + x | id)` read-out was missing.
- `phylogenetic-gllvm.Rmd` now states that standalone marginal phylogenetic
  diagonal models use `phylo_indep()`, while `phylo_unique()` is the explicit
  Psi component when paired with `phylo_latent()`.
- `functional-biogeography.Rmd` now uses `spatial_indep()` and
  `phylo_indep()` for adjustment-only controls, while preserving
  `spatial_latent() + spatial_unique()` and
  `phylo_latent() + phylo_unique()` for true partitioning decompositions.

## Checks

- Pre-edit lane check:
  - `gh pr list --state open` showed only draft PR #489.
  - `git log --all --oneline --since="6 hours ago"` showed the current
    mission-control / coevolution commits on this branch.
  - `git diff --check` was clean before edits.
- Rendered the touched articles with:
  `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (article in c("articles/response-families", "articles/animal-model", "articles/phylogenetic-gllvm", "articles/functional-biogeography")) { message("Building ", article); pkgdown::build_article(article, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
  - `response-families` rendered.
  - `animal-model` rendered.
  - `phylogenetic-gllvm` rendered.
  - `functional-biogeography` rendered, including the edited evaluated
    `fit-m2` formula with `spatial_indep()` and `phylo_indep()`.
- Source/rendered stale-wording checks confirmed the new `indep()` /
  `*_indep()` wording in the touched source and HTML pages.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- Dashboard JSON validated with `python3 -m json.tool`, was synced to
  `/tmp/gllvm-dashboard/`, and the live dashboard at
  `http://127.0.0.1:8770/status.json` showed the `2026-06-18 16:42 MDT`
  second-sweep state.
- `git diff --check` passed after edits.

## Rose Addendum

Rose's narrow pre-publish pass found one fixable gap: the top NEWS entry and
three edited article passages taught the `unique()` / `indep()` distinction but
did not name the validation rows tightly enough. The follow-up patch added row
anchors for `FG-05`, `FG-06`, `FG-07`, `ANI-03`, `ANI-11`, and `FAM-06`, then
rebuilt all four touched articles again. `pkgdown::check_pkgdown()`, stale
wording scans, dashboard JSON validation, and `git diff --check` remained clean.

## Not Claimed

- No parser-wide deprecation warning was added for `unique()` or
  source-specific `*_unique()`.
- No API removal or lifecycle escalation is claimed.
- No Paper 2 multi-kernel explicit-Psi support is claimed.
- No bridge completion, release readiness, or scientific coverage completion
  is claimed.
