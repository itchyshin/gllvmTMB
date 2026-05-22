# After Task: User-Facing Site Preview

**Branch**: `codex/florence-covariance-plots-2026-05-21`
**Date**: `2026-05-22`
**Roles (engaged)**: `Ada / Pat / Rose / Grace`

## 1. Goal

Make the pkgdown landing page and link-preview metadata sell the package by
the user problem: fitting multivariate response models from wide data, with the
same `gllvmTMB()` entry point available for already-stacked long data. The
previous preview led with "Stacked-Trait GLLVMs with TMB", the standalone TMB
engine, and the 4 x 5 keyword grid, which is accurate internally but poor
public positioning.

## 2. Implemented

- Changed the package title to `Fit Multivariate Models from Wide Response
  Data`.
- Rewrote the DESCRIPTION opening so pkgdown and social previews start with
  sites, individuals, species, studies, responses, and the wide `traits()`
  workflow.
- Rewrote the `gllvmTMB()` roxygen opening and `data` parameter to present wide
  and long input as two user routes into the same internal stacked-trait model.
- Updated citation text in the README, `inst/CITATION`, and the behavioural
  syndromes article.
- Replaced remaining "Long data are canonical" wording in two public articles.
- Fixed the hidden animal-model article render by qualifying the
  `pedigree_to_A()` helper call.
- Diagnosed the failed manual pkgdown workflow as a GitHub Pages environment
  protection rejection for the PR branch, not as an R/pkgdown build failure.

## 3. Files Changed

- Metadata and reference source: `DESCRIPTION`, `R/gllvmTMB.R`,
  `inst/CITATION`.
- Generated documentation: `man/gllvmTMB-package.Rd`, `man/gllvmTMB.Rd`.
- Public prose and articles: `README.md`,
  `vignettes/articles/api-keyword-grid.Rmd`,
  `vignettes/articles/animal-model.Rmd`,
  `vignettes/articles/behavioural-syndromes.Rmd`,
  `vignettes/articles/ordinal-probit.Rmd`.
- Audit trail: `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/2026-05-22-user-facing-site-preview.md`.

## 3a. Decisions and Rejected Alternatives

Decision: use `Fit Multivariate Models from Wide Response Data` as the public
title.
Rationale: it names the primary user action and data shape without hiding that
long data are still supported.
Rejected alternative: retain "Stacked-Trait GLLVMs with TMB" as the title and
only soften the body text. That would leave link previews selling the engine.
Confidence: high for public positioning; the exact title can still be tuned by
the maintainer before merge.

Decision: keep TMB, sdmTMB, and phylogenetic citations in DESCRIPTION after the
opening sentence.
Rationale: package metadata still needs to credit implementation dependencies
and literature, but previews should no longer lead with them.
Rejected alternative: remove engine/literature details from DESCRIPTION
entirely. That would make citation/provenance weaker.
Confidence: medium-high.

## 4. Checks Run

- `gh pr list --state open --json number,title,headRefName,baseRefName,author,url`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `gh run list --workflow pkgdown.yaml --limit 6 --json databaseId,status,conclusion,headBranch,headSha,displayTitle,createdAt,updatedAt,url`
  -> latest manual pkgdown run `26282665628` failed immediately on the PR
  branch.
- `gh api repos/itchyshin/gllvmTMB/check-runs/77362484836/annotations --jq '.'`
  -> deployment rejected because branch `codex/symbol-syntax-alignment-2026-05-21`
  is not allowed to deploy to `github-pages` by environment protection rules.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated the touched Rd files.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, upgrade = "never", quiet = TRUE)'`
  -> completed.
- `Rscript --vanilla -e 'cat("pedigree_to_A exported:", "pedigree_to_A" %in% getNamespaceExports("gllvmTMB"), "\n")'`
  -> `pedigree_to_A exported: TRUE`.
- `Rscript --vanilla -e 'pkgdown::build_site(new_process = FALSE, install = FALSE)'`
  -> completed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

No new tests were added. This slice changed public metadata, roxygen prose,
generated Rd, and article wording. The failure-before-fix evidence is the local
pkgdown render failure in `vignettes/articles/animal-model.Rmd` before the
local namespace refresh and helper qualification; after the fix and install
refresh, the full site build completed.

## 6. Consistency Audit

- `rg -n "Stacked-Trait GLLVMs with TMB|A standalone Template Model Builder|4 x 5 covariance keyword grid pairs|long-format multivariate generalised linear latent variable|Long data are canonical|long data are canonical|Fit Multivariate Response Models from Wide Trait Tables|Wide Trait Tables|wide response table" DESCRIPTION README.md inst/CITATION R man vignettes _pkgdown.yml pkgdown-site/index.html`
  -> no hits.
- `rg -n "og:title|og:description|twitter:title|twitter:description|Fit Multivariate|wide data frame|Stacked-Trait|standalone Template|4 x 5 covariance keyword grid" pkgdown-site/index.html pkgdown-site/reference/gllvmTMB-package.html pkgdown-site/reference/gllvmTMB.html`
  -> local generated metadata leads with `Fit Multivariate Models from Wide
  Response Data` and the wide-data workflow. No old preview title or
  standalone-template wording appears in these rendered pages.

Rose verdict: pass for this narrow metadata/prose consistency check.

## 7. Roadmap Tick

N/A. This was a public-positioning and deploy-diagnosis cleanup for PR #233,
not a new roadmap capability.

## 7a. GitHub Issue Ledger

No relevant open issue was inspected or created. This was direct maintainer
feedback on PR #233 and the public pkgdown page.

## 8. What Did Not Go Smoothly

The manual pkgdown workflow dispatch failed before any job steps ran. The
GitHub annotations showed this was because the PR branch is not allowed to
deploy to the `github-pages` environment. Local pkgdown also initially failed
because the installed local namespace was stale and did not export
`pedigree_to_A()`, even though the source `NAMESPACE` did. Refreshing the local
install aligned the local build with the workflow's `local::.` install step.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: kept the task scoped to site positioning, generated docs, pkgdown
diagnosis, and audit trail rather than opening a new feature lane.

Pat: the public entry now starts where most applied users are likely to start:
a wide response table and the `traits(...)` formula interface.

Rose: stale preview wording and the "Long data are canonical" phrasing were
searched explicitly across source, generated docs, articles, and local HTML.

Grace: separated a GitHub Pages environment-protection failure from actual
pkgdown build health; local `build_site()` and `check_pkgdown()` are green.

## 10. Known Limitations And Next Actions

- The public live site will not change from this PR branch because
  `github-pages` environment protection rejects PR-branch deployments.
- After PR #233 merges to `main`, the normal pkgdown workflow should deploy the
  updated landing page. If the maintainer wants branch previews, the Pages
  environment protection rules would need a separate policy change.
- Full `devtools::check()` was not rerun for this metadata/prose slice. The
  previous PR head had passing 3-OS R-CMD-check; this slice should still run
  through PR CI after push.
