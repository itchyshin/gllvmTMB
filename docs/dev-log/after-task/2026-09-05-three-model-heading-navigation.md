# After Task: Three-model-heading pkgdown navigation

**Branch**: `codex/gllvmtmb-navigation-renewal-ui-20260905`  
**Date**: 2026-09-05  
**Roles (engaged)**: Ada, Pat, Rose

## 1. Goal

Give the pkgdown article portfolio three explicit model routes—General model guides,
Species Distribution Models, and Phylogenetic comparative models—while retaining Get
started and Concepts and diagnostics as supporting routes.

## 2. Implemented

`_pkgdown.yml` gives every article source one primary article-index placement. The
Gaussian morphology example is the first General route and a Get started shortcut;
the response-family guide follows it for non-Gaussian choices. Known-source strength
is General, tree-centred workflows are PCM, and the random-slopes article remains
indexed as an explicitly labelled developer note under Concepts and diagnostics.

## 3. Files Changed

- `_pkgdown.yml`: navigation labels, reader shortcuts, article-index descriptions,
  and primary article placement.
- `docs/dev-log/after-task/2026-09-05-three-model-heading-navigation.md`: this report.
- `docs/dev-log/check-log.md`: compact validation receipt.

No R code, formula grammar, likelihood, family, NAMESPACE, generated Rd, vignette
body, README, NEWS, ROADMAP, or validation-debt register changed.

## 3a. Decisions and Rejected Alternatives

Morphology is General rather than a duplicate Get started index entry, because the
portfolio has one primary placement per article. Its Get started shortcut preserves
the first-reader route. PCM is reserved for workflows where the phylogeny is central;
the reusable known-source-strength method remains General.

## 4. Checks Run

- `git diff --check` -> pass.
- YAML assertion of the five reader routes, all article sources, and no duplicate
  primary placement -> `three_routes_and_primary_article_placement=PASS`.
- `Rscript --vanilla -e 'pkgdown::build_home() ...'` ->
  `rendered_home_navigation=PASS`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> known unrelated reference-index
  failure: `anova.gllvmTMB_multi`, `chibar2_pvalue`, `extract_latent_scores`,
  `ordinal_logit`, `ordination_uncertainty`, `select_lv`, and `variance_lrt` are
  missing from the reference index. This navigation change does not alter reference
  topics.

## 5. Tests of the Tests

No package tests changed: this is a declarative pkgdown configuration change. The
static assertion catches duplicate or missing article homes; the home render catches
invalid navigation wiring.

## 6. Consistency Audit

- `rg -n 'Model Guides|General model guides|Species Distribution Models|Phylogenetic comparative models|Developer note' _pkgdown.yml` -> the three requested headings are present; the
  random-slopes item remains visibly labelled as a developer note.
- `rg -n 'articles/(morphometrics|structured-source-strength|random-slopes-nongaussian)' _pkgdown.yml` -> shortcuts and single primary index placements match the agreed
  classification.

## 7. Roadmap Tick

N/A: navigation taxonomy changed, but no ROADMAP status changed.

## 7a. GitHub Issue Ledger

No relevant open issue; no issue created. Open PRs were inspected only for collision
avoidance before shared documentation records were edited.

## 8. What Did Not Go Smoothly

The broad pkgdown consistency check is still blocked by seven pre-existing missing
reference-index topics. It is recorded separately rather than being hidden by this
navigation-only work.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the scope to navigational taxonomy rather than silently folding in article
repairs. Pat's reader path is Gaussian morphology first, then response-family choice.
Rose's consistency check is the unique primary placement rule plus an explicit
developer-note label for the Tier-3 random-slopes page.

## 10. Known Limitations And Next Actions

Article-body repairs remain separate work: the Warbler and spatial-precision SDM
pages, categorical-PGLMM real-data wording, and source-strength boundaries need
self-contained reader review. The seven missing reference topics remain a distinct
pkgdown repair task. No deployment or publication occurred.
