# After Task: Technical Reference Scope Closeout

**Branch**: `codex/technical-reference-closeout-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: `Ada / Boole / Fisher / Rose / Grace`
**Spawned subagents**: none

## 1. Goal

Close the public technical-reference gate for `response-families` and
`api-keyword-grid`. The roadmap stop condition was that scope labels
match validation-debt rows and that hidden worked examples are not
advertised as ready.

## 2. Implemented

- Added a formal scope-boundary block to `api-keyword-grid`, with IN,
  PARTIAL, and PLANNED-or-blocked row IDs.
- Added covered / partial / blocked status labels to the
  `response-families` quick lookup.
- Added register status to the `response-families`
  exported-but-not-engine-mapped table.
- Clarified that public mixed-family examples should use non-delta,
  one-link families until the two-part estimand is defined.
- Updated `ROADMAP.md` and the article gate matrix to mark both
  technical references as scope-audit passed and to move the next queue
  to #248 identifiability diagnostics.
- Added
  `docs/dev-log/audits/2026-05-24-technical-reference-final-scope-review.md`
  as the durable audit record.

## 3. Files Changed

- `vignettes/articles/api-keyword-grid.Rmd`
- `vignettes/articles/response-families.Rmd`
- `ROADMAP.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/audits/2026-05-24-technical-reference-final-scope-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-24-technical-reference-closeout.md`

No R source, TMB source, formula grammar, likelihood code, exported
functions, roxygen, generated Rd files, NAMESPACE, NEWS, README,
`_pkgdown.yml`, tests, or validation-debt statuses changed.

## 4. Checks Run

- `git status --short --branch`
  -> clean `main...origin/main` before branching.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> recent merged article/roadmap lanes only; no competing open PR.
- `gh run list --repo itchyshin/gllvmTMB --limit 8 --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,event,url,createdAt,headSha`
  -> latest `main` R-CMD-check and pkgdown completed successfully before
  this branch started.
- `rg -n "family_to_id|gaussian|binomial|poisson|nbinom|lognormal|tweedie|Beta|betabinomial|student|truncated|delta_|ordinal|stop\\(" R/fit-multi.R R/families.R`
  -> `family_to_id()` mapping and exported constructor surface checked.
- `sed -n '102,140p' docs/design/35-validation-debt-register.md`
  -> FAM-01--FAM-19 statuses checked.
- `rg -n "FG-|PHY-|SPA-|MET-|ANI-|MIX-|MIS-02|MIS-11" docs/design/35-validation-debt-register.md`
  -> keyword-grid row IDs checked.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (article in c("articles/api-keyword-grid", "articles/response-families", "articles/roadmap")) { message("Building ", article); pkgdown::build_article(article, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE) }'`
  -> completed; `pkgdown-site/articles/api-keyword-grid.html`,
  `pkgdown-site/articles/response-families.html`, and
  `pkgdown-site/articles/roadmap.html` were written.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `rg -n "Scope boundary|FAM-01|FAM-17|MIX-10|covered|partial|blocked|family_to_id|not mapped|Validation / interpretation" vignettes/articles/response-families.Rmd`
  -> family scope rows and status labels present.
- `rg -n "Scope boundary|FG-|ANI-|PHY-|SPA-|MET-|MIS-|hidden worked examples|technical reference scope" vignettes/articles/api-keyword-grid.Rmd ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> keyword scope rows and status labels present.
- `rg -n "gllvmTMB\\(" vignettes/articles/api-keyword-grid.Rmd vignettes/articles/response-families.Rmd ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> touched long-format examples retain explicit `trait = "trait"`;
  wide examples correctly omit `trait =`.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" vignettes/articles/api-keyword-grid.Rmd vignettes/articles/response-families.Rmd ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> no output.
- `rg -n "\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\(" vignettes/articles/api-keyword-grid.Rmd vignettes/articles/response-families.Rmd`
  -> no output.
- `rg -n "meta_known_V|gllvmTMB_wide|profile-likelihood default|trio|full.*rejected|only diagonal|planned.*implemented|deprecated.*0\\.1" vignettes/articles/api-keyword-grid.Rmd vignettes/articles/response-families.Rmd ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  -> expected false positives only from legitimate "marginal-only
  diagonal" wording.
- `rg -n "joint-sdm|animal-model|phylogenetic-gllvm|mixed-family-extractors|ordinal-probit|profile-likelihood-ci|functional-biogeography|psychometrics-irt|choose-your-model" vignettes/articles/api-keyword-grid.Rmd vignettes/articles/response-families.Rmd`
  -> expected false positives only from ordinary "animal-model" prose.
- `rg -n "(joint-sdm|animal-model|phylogenetic-gllvm|mixed-family-extractors|ordinal-probit|profile-likelihood-ci|functional-biogeography|psychometrics-irt|choose-your-model)\\.html" vignettes/articles/api-keyword-grid.Rmd vignettes/articles/response-families.Rmd`
  -> no output; no hidden article links were introduced.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "technical reference OR response-families OR api-keyword-grid OR article surface reset" --json number,title,url,labels,updatedAt --limit 20`
  -> #230 remains the relevant article-surface ledger.
- `find vignettes -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -print`
  -> no output.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

No tests were added. This slice changes public prose, status labels,
and ledger records only. Existing rendered article builds exercise the
touched R Markdown pages.

## 6. Consistency Audit

Article-tier audit: pass. Both pages remain Tier 2 technical
references with explicit justification in YAML front matter.

Prose-style audit: pass. The pages define status terms where they
matter and avoid presenting hidden worked examples as ready.

Rose pre-publish audit: pass. Capability claims map to validation-debt
row IDs; hidden article link scan returned no `.html` links; stale
notation and deprecated alias scans returned no output.

Boole grammar audit: pass. The keyword-grid page now names the
supported formula surface and separates lookup syntax from validation
depth.

Fisher family audit: pass for wording. The family page separates
engine-mapped single-family delta forms from blocked response-scale and
mixed-family delta/hurdle interpretation.

Grace pkgdown audit: pass locally.

## 7. Roadmap Tick

`response-families` and `api-keyword-grid` moved from "bounded
closeout passes still needed" to "technical reference scope audits
passed." The Next Shared Work Queue now starts with #248
identifiability diagnostics, followed by #228 predictive diagnostics.

## 7a. GitHub Issue Ledger

- #230, `Article surface reset and user-first tooling gate`, remains
  the relevant tracker. This PR closes the technical-reference
  condition inside that broader issue.

## 8. What Did Not Go Smoothly

No blocker. The main correction was making implicit scope boundaries
visible enough that future readers cannot confuse exported constructors
or hidden worked examples with fully supported public examples.

## 9. Team Learning

Ada kept the lane to two Tier-2 references plus their roadmap/gate
ledger.

Boole checked that grammar lookup status did not become a worked-example
claim.

Fisher checked that family labels do not overstate delta/hurdle or
mixed-family interpretation.

Rose checked validation-row traceability and hidden-article routing.

Grace checked local article rendering and pkgdown metadata.

## 10. Known Limitations And Next Actions

- This closeout does not move any validation-debt statuses.
- It does not restore phylogenetic, spatial, animal, meta-analysis,
  ordinal, joint-SDM, or mixed-family worked examples.
- The next queue item is #248 identifiability diagnostics.
