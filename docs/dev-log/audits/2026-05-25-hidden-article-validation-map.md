# Hidden Article Restoration Validation Map

**Date:** 2026-05-25
**Role:** Rose + Shannon
**Status:** Audit artifact only. No article, roadmap, pkgdown,
check-log, design-doc, or PR-owned file was edited.
**Scope:** the `ROADMAP.md` Restoration Queue:
`joint-sdm`, `profile-likelihood-ci`, `behavioural-syndromes`,
`mixed-family-extractors`, `animal-model`, `phylogenetic-gllvm`,
`psychometrics-irt`, `lambda-constraint`,
`simulation-recovery-validated`, `cross-package-validation`, and
`functional-biogeography`.

**Superseding coordination note, 2026-05-26:** use the article-order
correction in `ROADMAP.md` and
`docs/dev-log/audits/2026-05-20-article-gate-matrix.md` before using
the ranked queue below. Public expansion is paused. The next article
lane is `lambda-constraint` as a binary species/JSDM-style loading
constraint article; `psychometrics-irt` and `mixed-family-extractors`
remain internal/deferred.

## Coordination State

Current local branch at audit time:

```text
## codex/joint-sdm-scope-rewrite-2026-05-25
 M docs/design/04-random-effects.md
 M vignettes/articles/joint-sdm.Rmd
?? docs/dev-log/after-task/2026-05-25-joint-sdm-binary-scope-rewrite.md
```

Those dirty files were not touched. They are also explicitly outside
this audit's write scope.

Final sanity note: after this audit file was added, the working tree
also showed additional untracked files that were not created or edited
in this lane:

```text
?? docs/dev-log/audits/2026-05-25-joint-sdm-rendered-figure-qa.md
?? docs/dev-log/audits/2026-05-25-r200-readiness-review.md
?? tests/testthat/test-joint-sdm-binary-long-wide.R
```

Those look like concurrent joint-SDM / r200 validation work. Treat them
as other-agent or maintainer-owned unless proven otherwise.

Open PR state:

| PR | Branch | Files relevant to this audit | Shannon read |
|---|---|---|---|
| #261 | `codex/diagnostic-teaching-reset-2026-05-25` | `README.md`, `ROADMAP.md`, `docs/dev-log/check-log.md`, `vignettes/gllvmTMB.Rmd`, `vignettes/articles/convergence-start-values.Rmd`, after-task report | Mergeable/clean; owns ROADMAP/check-log wording for the diagnostic reset. |
| #265 | `codex/diagnostic-table-2026-05-25` | `R/diagnostic-tables.R`, `NEWS.md`, `_pkgdown.yml`, `docs/design/35-validation-debt-register.md`, `docs/design/51-posterior-predictive-diagnostics.md`, tests, Rd, ROADMAP/check-log | Mergeable/clean; introduces `diagnostic_table()` and DIA-13 but overlaps ROADMAP/check-log with #261. |
| #267 | `agent/set-c-r200-prep` | `docs/dev-log/audits/2026-05-25-set-c-joint-sdm-gate-matrix.md`, `docs/dev-log/audits/2026-05-25-m3-r200-dispatch-plan.md`, `docs/design/54-cross-package-scout-protocol.md`, `docs/dev-log/coordination-board.md` | Mergeable/clean; already contains the narrow joint-SDM gate matrix and r200 plan. |

This file deliberately does not edit any file owned by those PRs. It
does add a new audit memo under `docs/dev-log/audits/`, adjacent to
but not overlapping #267's audit files.

## Restoration Gate Used Here

A hidden article should not move public until all of the following are
true:

1. every advertised capability maps to `covered` validation-debt rows,
   or the article says exactly which rows are `partial` / `blocked`;
2. the article has runnable public examples, with long and wide calls
   side by side unless the file explicitly records why wide form is not
   supported;
3. simulated examples compare fitted estimates to known truth;
4. figure-heavy pages have Florence review;
5. `pkgdown::check_pkgdown()` and article rendering are current for
   the branch that will publish the page;
6. rendered HTML has been inspected, not just Rmd source.

Existing `pkgdown-site/articles/*.html` files prove that rendered
artifacts exist locally, but I did not find a current public-return
review for any queue item in this lane. Treat those HTML files as stale
evidence until the restoration PR rebuilds and records the inspected
path.

## Queue Map

| Article | Return condition | Likely validation rows | Existing evidence paths | Missing tests / fixtures / gates | Next task |
|---|---|---|---|---|---|
| `joint-sdm` | Return only as a pure-binary JSDM article, with long format live, wide binary absence-fill still dormant or validated, RE-09 / FG-07 / FG-08 partials footnoted, and rendered figures reviewed. Do not reintroduce mixed-family JSDM. | FAM-02 covered; FG-02/03/04 covered; RE-09 partial; FG-07/08 partial; EXT-01/04/09/18/19 covered; CI-07/09 covered; DIA-08..12 covered/partial by family; DIA-13 pending #265. | `vignettes/articles/joint-sdm.Rmd`; PR #267 `docs/dev-log/audits/2026-05-25-set-c-joint-sdm-gate-matrix.md`; `tests/testthat/test-m2-2a-binary-recovery.R`; `tests/testthat/test-m2-2b-binary-cis-extractors.R`; `tests/testthat/test-predictive-diagnostics.R`; `tests/testthat/test-extract-sigma-table.R`; `tests/testthat/test-plot-covariance-tables.R`. | Binary long/wide absence-fill equivalence fixture; prose rewrite for `unique()`, `dep()`, and `indep()` partial-status comparisons; current HTML review; Florence review of Sigma heatmap and biplot. | **WAIT** until #261/#267 and local dirty joint-SDM lane settle; then **PROSE** in a single article PR. |
| `profile-likelihood-ci` | Return as a technical inference guide only after it leads with fallback logic, Wald limitations, bootstrap/profile target status, and no M3 coverage-success implication. | CI-01..07 covered; CI-08 partial; CI-10 partial; CI-09 covered; EXT-04 mixed-family profile/bootstrap partial; EXT-13 Gaussian covered / non-Gaussian partial; MIS-15 covered. | `vignettes/articles/profile-likelihood-ci.Rmd`; `tests/testthat/test-profile-ci.R`; `tests/testthat/test-profile-targets.R`; `tests/testthat/test-confint-bootstrap.R`; `tests/testthat/test-fisher-z-correlations.R`; `docs/design/44-m3-3-inference-replacement.md`; `docs/design/50-m3-3b-surface-admission.md`; `docs/dev-log/audits/2026-05-19-m3-production-grid-artifact-review.md`; `docs/dev-log/audits/2026-05-25-m3-postpatch-rerun.md`. | Remove stale "profile is more accurate" style claims unless scoped to inspected curves; separate parameter CI support from coverage calibration; current HTML review. | **PROSE**. |
| `behavioural-syndromes` | Return after a reusable behavioural fixture or compact fixture block supports between- and within-individual covariance, repeatability, communality, and truth-vs-fit recovery with both long and wide calls. | FG-02/03/06 covered; FG-10 covered; RE-01/04 covered; RE-09 partial for within-unit latent + unique; EXT-01/03/05/06/09/18/19/25/26/27 covered; MIS-09 partial for broader rendered figure QA. | `vignettes/articles/behavioural-syndromes.Rmd`; `docs/dev-log/after-task/2026-05-21-behavioural-syndromes-heatmaps.md`; `tests/testthat/test-multi-random-intercepts.R`; `tests/testthat/test-mixed-response-unique-nongaussian.R`; `tests/testthat/test-extractors-extra.R`; `tests/testthat/test-plot-covariance-tables.R`. | Named behavioural DGP helper or shipped fixture; live wide fit equivalence rather than prose-only wide note; recovery test for the article's between/within truth; final rendered HTML and Florence review. | **VALIDATION**. |
| `mixed-family-extractors` | Return as a compact technical reference after #265 settles, with report-ready extractor tables and explicit exclusion of delta/hurdle latent-scale correlations. | MIX-01..09 covered; MIX-10 blocked; MIS-05 covered; EXT-01/03/04/05/06/13/18/20/21/22/24 covered or partial as registered; DIA-13 pending #265. | `vignettes/articles/mixed-family-extractors.Rmd`; `R/data-mixed-family.R`; `inst/extdata/mixed-family-fixture.rds`; `tests/testthat/test-stage37-mixed-family.R`; `tests/testthat/test-m1-3-extract-sigma-mixed-family.R`; `tests/testthat/test-m1-4-extract-correlations-mixed-family.R`; `tests/testthat/test-m1-5-extract-communality-mixed-family.R`; `tests/testthat/test-m1-6-extract-repeatability-mixed-family.R`; `tests/testthat/test-m1-8-bootstrap-mixed-family.R`; PR #265 `diagnostic_table()`. | Article-specific rendered table review after #265; scope table must keep MIX-10 blocked; current pkgdown check. | **FIGURE/PKGDOWN**. |
| `animal-model` | Return only after a larger pedigree fixture demonstrates A/Ainv truth, genetic covariance recovery, and avoids implying multi-matrix animal models are covered. | ANI-01..05 covered; ANI-06 partial; ANI-07/08 covered; ANI-09 partial; ANI-10 partial; EXT-01/05/06/18/19/25/26/27 covered; PHY rows only as engine-equivalence background. | `vignettes/articles/animal-model.Rmd`; `docs/design/14-known-relatedness-keywords.md`; `tests/testthat/test-animal-keyword.R`; `tests/testthat/test-pedigree-sparse-ainv.R`; `tests/testthat/test-pedigree-sparse-ainv-engine.R`; `docs/dev-log/after-task/2026-05-17-m2-8c-animal-article-cascade.md`. | Larger quantitative-genetic fixture; recovery test for G matrix / heritability on article DGP; clear exclusion of ANI-09 multi-matrix claims; rendered HTML and figure review. | **VALIDATION**. |
| `phylogenetic-gllvm` | Return after phylo vs non-phylo covariance split is tied to covered rows and partial fallback modes are labelled, with rendered figure review. | FG-12 covered; PHY-01..03 covered; PHY-04/05/06 partial; PHY-07..10 covered; EXT-01/05/07/08/18/19/25/26/27 covered; CI-05 covered. | `vignettes/articles/phylogenetic-gllvm.Rmd`; `docs/design/03-phylogenetic-gllvm.md`; `tests/testthat/test-stage35-phylo-rr.R`; `tests/testthat/test-phylo-hadfield.R`; `tests/testthat/test-phylo-q-decomposition.R`; `tests/testthat/test-phylo-mode-dispatch.R`; `tests/testthat/test-phylo-vcv-optional.R`; `tests/testthat/test-extract-omega.R`; `tests/testthat/test-extractors-extra.R`. | Current rendered HTML; Florence review of covariance/correlation plots; prose guard around scalar/indep/dep/slope partial rows. | **FIGURE/PKGDOWN**. |
| `psychometrics-irt` | Return after the M2.5 re-author path uses the now-covered binary IRT rows, carries comparator evidence into the article, and states that mixed-family wide formula is not supported. | FAM-02 covered; LAM-03 covered; LAM-04 covered; LAM-01 covered; MIX-01/02 covered if mixed Gaussian + binary stays; MIX-10 blocked only as exclusion; MIS-02 covered but not for full mixed-family wide dispatch. | `vignettes/articles/psychometrics-irt.Rmd`; `docs/design/41-binary-completeness.md`; `tests/testthat/test-m2-3-lambda-constraint-binary.R`; `tests/testthat/test-m2-3-mirt-cross-check.R`; `tests/testthat/test-m2-3-galamm-cross-check.R`; `tests/testthat/test-m2-4-suggest-lambda-constraint-binary.R`. | Shipped or reusable IRT fixture for article rendering; re-authored prose against M2.3/M2.4 evidence; decide live vs precomputed `mirt`/`galamm` comparator path; rendered HTML and figure review. | **VALIDATION**. |
| `lambda-constraint` | Return as a technical confirmatory-loading guide once the preview banner is replaced by scope rows, stale chunk labels are fixed, and rendered examples are reviewed. | LAM-01 covered; LAM-02 partial; LAM-03 covered; LAM-04 covered; EXT-14/15 covered; FG-02/03/06 covered. | `vignettes/articles/lambda-constraint.Rmd`; `R/lambda-constraint.R`; `R/suggest-lambda-constraint.R`; `tests/testthat/test-lambda-constraint.R`; `tests/testthat/test-suggest-lambda-constraint.R`; `tests/testthat/test-m2-3-lambda-constraint-binary.R`; `tests/testthat/test-m2-4-suggest-lambda-constraint-binary.R`; `docs/dev-log/after-task/2026-05-22-preview-banner-register-citations.md`. | Fix stale chunk label `fit-galamm` for a `gllvmTMB()` fit; explain LAM-02 Gaussian smoke status vs LAM-03 binary covered status; rendered HTML and heatmap review. | **PROSE**. |
| `simulation-recovery-validated` | Do not return until target-explicit M3 evidence clears the promotion gate and the article no longer presents profile-psi smoke output as if it answers the current coverage question. | CI-08 partial; CI-10 partial; EXT-13 Gaussian covered / non-Gaussian partial; MIS-16/17/18/19 covered for start/mitigation machinery; Design 50 controls promotion. | `vignettes/articles/simulation-recovery-validated.Rmd`; `inst/extdata/m3-coverage-grid-smoke.rds`; `inst/extdata/m3-coverage-summary-smoke.rds`; `dev/precomputed/m3-coverage-grid.rds`; `dev/precomputed/m3-coverage-summary.rds`; `docs/design/42-m3-dgp-grid.md`; `docs/design/44-m3-3-inference-replacement.md`; `docs/design/50-m3-3b-surface-admission.md`; `docs/dev-log/audits/2026-05-19-m3-production-grid-artifact-review.md`; `docs/dev-log/audits/2026-05-25-m3-postpatch-rerun.md`. | r200 or approved r50/r200 promotion evidence; article rewrite from profile-psi to target-explicit `Sigma_unit[tt]`; no stale 94 percent claim until CI-08/CI-10 move; rendered HTML and diagnostic figure review. | **WAIT**; maintainer has not authorised r200 in this lane. |
| `cross-package-validation` | Return only after Phase 5.5 comparator evidence is row-labelled and the article separates "live comparator", "smoke comparator", and "planned comparator". | FAM-02 covered with glmmTMB cross-check; FG-04/06 covered for latent/unique; MET-01 partial; MET-04 partial; ANI-10 partial; SPA comparator paths partial/planned; LAM-03 covered for mirt/galamm binary IRT comparator; Phase 5.5 broader rows are not yet a clean register section. | `vignettes/articles/cross-package-validation.Rmd`; `docs/design/05-testing-strategy.md`; `docs/dev-log/audits/2026-05-25-jason-cross-package-binomial-sigma-scout.md`; `tests/testthat/test-m2-2b-glmmTMB-cross-check.R`; `tests/testthat/test-m2-3-mirt-cross-check.R`; `tests/testthat/test-m2-3-galamm-cross-check.R`; `tests/testthat/test-stage2-rr-diag.R`; `tests/testthat/test-stage3-propto-equalto.R`. | Dedicated Phase 5.5 row ledger or register section; direct `meta_V` equalto comparator; spatial / animal / Hmsc / MCMCglmm comparator decisions; rendered HTML review. | **VALIDATION**. |
| `functional-biogeography` | Return last, only after component helpers, M3 evidence, spatial/phylo/meta scope, figures, and capstone truth comparisons are all covered and rendered. | FG-02/03/06/10/12/13/14; PHY-01..10; SPA-01..07; MET-01..04; RE-09; MIX rows if mixed families enter; CI-08/10; EXT-01/03/05/06/07/08/18/19/25/26/27/30; MIS-09. Many are partial or blocked in current register. | `vignettes/articles/functional-biogeography.Rmd`; `docs/dev-log/after-task/2026-05-21-sigma-heatmap-helper-functional-biogeography.md`; `tests/testthat/test-simulate-site-trait.R`; `tests/testthat/test-stage35-phylo-rr.R`; `tests/testthat/test-stage4-spde.R`; `tests/testthat/test-spatial-latent-recovery.R`; `tests/testthat/test-plot-covariance-tables.R`; M3 audit files above. | This is a capstone, not an early restoration candidate: needs component article gates, M3 target-explicit evidence, spatial/meta partials resolved or excluded, truth-vs-fit tables, and Florence review. | **WAIT**. |

## Discrepancies And Drift

1. `simulation-recovery-validated.Rmd` is stale against Design 50. It
   still describes profile-likelihood CIs on `psi_t` as the M3 article
   target, while the current gate treats `Sigma_unit[tt]` as the public
   promotion target and `psi` as diagnostic. This is the clearest
   code/docs/roadmap contradiction in the restoration queue.

2. `joint-sdm.Rmd` is much closer after the Set C gate, but the prose
   still advertises profile-likelihood as "more accurate" and names a
   planned warm-start path in a reader-facing article. That should be
   softened unless tied to a current covered row or a hidden technical
   note.

3. `lambda-constraint.Rmd` has a stale chunk label
   `fit-galamm` around a `gllvmTMB()` fit. It is small, but it is
   exactly the kind of terminology drift that makes comparator claims
   harder to audit.

4. Several hidden articles link to other hidden articles as ordinary
   next steps. That is fine while they are all internal, but any single
   restoration PR must check outbound links so a public page does not
   route readers into unreviewed hidden content.

5. The local `pkgdown-site/articles/*.html` files can mislead future
   agents into thinking "rendered" means "approved." They are useful
   build artifacts, not current return evidence unless the exact
   restoration branch records a rendered HTML review.

## Repeated Patterns

- The team keeps rediscovering the same lesson: article prose is ahead
  of validation rows unless the validation-debt register is the first
  artifact opened. The 2026-05-20 article gate matrix and PR #267
  joint-SDM gate are the right corrective pattern.
- CI pacing is now better recorded, but ROADMAP/check-log overlap in
  #261/#265 shows the old cancel-cascade risk has become a merge-order
  and ledger-overlap risk.
- Figure work improved through helper infrastructure, but hidden
  articles still contain figure-heavy narratives without final Florence
  review on the rendered HTML.
- Comparator claims are useful but need a row ledger. "Cross-package"
  currently mixes live tests, optional-package chunks, planned Phase 5.5
  work, and design assumptions.

## Missing Feedback Loops

| Missing loop | Why it matters | Safeguard |
|---|---|---|
| Article-to-register row map before editing | Prevents prose from expanding into partial/blocked capability claims. | Every restoration PR starts with a table like this one, narrowed to one article. |
| Rendered HTML signoff after source edits | Rmd source does not catch broken layout, hidden-link routing, or weak figures. | Restoration PR records local HTML path, screenshot/visual notes, and maintainer/Florence inspection status. |
| Fixture-first workflow for Tier-1 examples | Long DGP code blocks hide whether the model actually recovers intended estimands. | Build or name a reusable fixture before prose; tests compare truth to fitted estimates. |
| Comparator status vocabulary | "Validated against X" can mean objective equality, aligned loadings, smoke fit, or planned work. | Add a Phase 5.5 comparator ledger section before restoring `cross-package-validation`. |
| Link-surface audit | A restored page can expose hidden pages through See also links. | Same PR runs an outbound hidden-link scan over the restored article and visible public pages. |

## Ranked Top-5 Queue For Codex Team

1. **`simulation-recovery-validated` - WAIT.** Do not touch article
   prose until maintainer authorises the r50/r200 path. The article is
   stale against the target-explicit `Sigma_unit[tt]` gate and would
   overclaim if restored now.
2. **`behavioural-syndromes` - VALIDATION.** Build the behavioural
   fixture / recovery test first. It is a strong applied article only
   if between/within covariance and repeatability recovery are real.
3. **`animal-model` - VALIDATION.** Build a larger pedigree fixture and
   genetic covariance recovery check before prose or figures. Keep
   ANI-09 multi-matrix claims out.
4. **`psychometrics-irt` - VALIDATION.** The test evidence is much
   stronger now, but the article still needs a reusable IRT fixture and
   a clear live/precomputed comparator path before M2.5 re-authoring.
5. **`joint-sdm` - WAIT, then PROSE.** The pure-binary scope is
   restorable in principle per #267's gate, but current local and PR
   ownership make this a bad file to edit in this lane. Once the lane
   settles, do a narrow prose-only rewrite of the two partial-row
   sections and leave wide form dormant unless the fixture lands.

Near-follow-ups after those five: `mixed-family-extractors`
(`FIGURE/PKGDOWN` after #265), `lambda-constraint` (`PROSE`), and
`phylogenetic-gllvm` (`FIGURE/PKGDOWN`). `functional-biogeography`
should remain last.

## Commands Run

No R code, GitHub Actions workflow, or r200 dispatch was run.

```sh
rg -n "hidden article|Restoration Queue|validation-debt|joint-sdm|profile-likelihood|behavioural-syndromes|functional-biogeography" /Users/z3437171/.codex/memories/MEMORY.md
sed -n '1,260p' .agents/skills/shannon-coordination-audit/SKILL.md
sed -n '1,280p' AGENTS.md
git status --short --branch
gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,statusCheckRollup,updatedAt,url,author
git log --all --oneline --since="6 hours ago"
gh pr view 261 --repo itchyshin/gllvmTMB --json number,title,headRefName,files,body,url
gh pr view 265 --repo itchyshin/gllvmTMB --json number,title,headRefName,files,body,url
gh pr view 267 --repo itchyshin/gllvmTMB --json number,title,headRefName,files,body,url
find docs/dev-log/recovery-checkpoints -type f -maxdepth 1 2>/dev/null | sort | tail -n 5
rg -n "Restoration Queue|Restoration|joint-sdm|profile-likelihood-ci|behavioural-syndromes|mixed-family-extractors|animal-model|phylogenetic-gllvm|psychometrics-irt|lambda-constraint|simulation-recovery-validated|cross-package-validation|functional-biogeography" ROADMAP.md
rg -n "joint-sdm|profile-likelihood|behavioural|mixed-family|animal|phylogenetic|psychometrics|IRT|lambda|simulation-recovery|cross-package|functional|biogeography|CI-|DIA-|FG-|RE-|MIX-|PHY-|ANIMAL|LAMBDA|SIM|XPKG|IRT" docs/design/35-validation-debt-register.md
find vignettes vignettes/articles -maxdepth 2 -type f | sort | rg "(joint-sdm|profile-likelihood-ci|behavioural-syndromes|mixed-family-extractors|animal-model|phylogenetic-gllvm|psychometrics-irt|lambda-constraint|simulation-recovery-validated|cross-package-validation|functional-biogeography)"
find docs/dev-log/audits -maxdepth 1 -type f | sort | tail -n 30
wc -l vignettes/articles/joint-sdm.Rmd vignettes/articles/profile-likelihood-ci.Rmd vignettes/articles/behavioural-syndromes.Rmd vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd vignettes/articles/psychometrics-irt.Rmd vignettes/articles/lambda-constraint.Rmd vignettes/articles/simulation-recovery-validated.Rmd vignettes/articles/cross-package-validation.Rmd vignettes/articles/functional-biogeography.Rmd
rg -n "^(#|##|###)|Scope|scope|IN:|PARTIAL|PLANNED|covered|partial|blocked|eval=FALSE|TODO|FIXME|validation|Validation|render|HTML|return|fixture|fig|Figure|diagnostic|profile|bootstrap|M3|coverage|comparison|comparator|truth|recovery|wide|long" vignettes/articles/joint-sdm.Rmd vignettes/articles/profile-likelihood-ci.Rmd vignettes/articles/behavioural-syndromes.Rmd vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd vignettes/articles/psychometrics-irt.Rmd vignettes/articles/lambda-constraint.Rmd vignettes/articles/simulation-recovery-validated.Rmd vignettes/articles/cross-package-validation.Rmd vignettes/articles/functional-biogeography.Rmd
gh api 'repos/itchyshin/gllvmTMB/contents/docs/dev-log/audits/2026-05-25-set-c-joint-sdm-gate-matrix.md?ref=agent/set-c-r200-prep' --jq .content | base64 --decode
sed -n '1,180p' docs/dev-log/audits/2026-05-20-article-gate-matrix.md
rg -n "joint-sdm|profile-likelihood-ci|behavioural-syndromes|mixed-family-extractors|animal-model|phylogenetic-gllvm|psychometrics-irt|lambda-constraint|simulation-recovery-validated|cross-package-validation|functional-biogeography" _pkgdown.yml docs/articles docs/dev-log docs/design vignettes/articles -g '!docs/dev-log/check-log.md'
sed -n '1,220p' docs/dev-log/audits/2026-05-20-article-surface-reset.md
sed -n '1,220p' docs/dev-log/audits/2026-05-25-m3-postpatch-rerun.md
nl -ba _pkgdown.yml | sed -n '48,84p'
find pkgdown-site/articles docs -path '*articles*' -type f 2>/dev/null | sort | rg "(joint-sdm|profile-likelihood-ci|behavioural-syndromes|mixed-family-extractors|animal-model|phylogenetic-gllvm|psychometrics-irt|lambda-constraint|simulation-recovery-validated|cross-package-validation|functional-biogeography)"
rg -n "m3|coverage|profile|bootstrap|CI-08|CI-10|PASS_TO_SCALE|M3.3|M3.4|M3.5|r200" docs/design/42-m3-dgp-grid.md docs/design/44-m3-3-inference-replacement.md docs/design/50-m3-target-scale-diagnostics.md docs/dev-log/audits/2026-05-19-m3-production-grid-artifact-review.md docs/dev-log/audits/2026-05-25-m3-postpatch-rerun.md
rg -n "animal|Ainv|pedigree|ANI-|phylo|PHY-|lambda|LAM-|psychometrics|IRT|binary|M2\\.5|M2\\.6" docs/design/14-known-relatedness-keywords.md docs/design/41-binary-completeness.md docs/design/03-phylogenetic-gllvm.md docs/dev-log/after-task/2026-05-17-m2-8c-animal-article-cascade.md docs/dev-log/after-task/2026-05-22-preview-banner-register-citations.md
ls docs/design | rg '^50|m3'
rg -n "§5|Section 5|admission|promotion|r200|CI-08|CI-10|PASS_TO_SCALE|partial|covered" docs/design/50-m3-3b-surface-admission.md
rg -n "Preview|covered|partial|blocked|validation-debt|Scope|eval = FALSE|wide|long|fixture|truth|recovery|render|HTML" vignettes/articles/animal-model.Rmd vignettes/articles/behavioural-syndromes.Rmd vignettes/articles/functional-biogeography.Rmd vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/profile-likelihood-ci.Rmd vignettes/articles/phylogenetic-gllvm.Rmd
rg -n "Preview|covered|partial|blocked|validation-debt|Scope|eval = FALSE|wide|long|fixture|truth|recovery|render|HTML|mirt|galamm|lambda|LAM-|M3|coverage|profile|bootstrap|comparator" vignettes/articles/lambda-constraint.Rmd vignettes/articles/psychometrics-irt.Rmd vignettes/articles/simulation-recovery-validated.Rmd vignettes/articles/cross-package-validation.Rmd vignettes/articles/joint-sdm.Rmd
rg --files tests/testthat dev/precomputed inst/extdata R docs/dev-log/audits | rg "(m2-2|m2-3|m2-4|lambda-constraint|suggest-lambda|mirt|galamm|mixed-family|m1-[3-8]|animal|pedigree|phylo|profile-ci|confint|coverage|m3|diagnostic|predictive|bootstrap|extract|morphometrics|covariance|site-trait|binary|stage35|stage37)"
find inst/extdata dev/precomputed -maxdepth 2 -type f 2>/dev/null | sort
find R -maxdepth 1 -type f | sort | rg "(data-|simulate|fixture|animal|phylo|lambda|mixed|coverage|profile|bootstrap|diagnostic|predictive|extract)"
rg -n "simulate_|load_.*fixture|morphometrics|binary_irt|mixed_family|coverage-grid|animal|pedigree|phylo" R tests/testthat vignettes/articles docs/design/35-validation-debt-register.md
rg -n "\\| EXT-|\\| MET-|\\| SPA-|\\| MIS-|Phase 5.5|cross-package|glmmTMB|gllvm|galamm|MCMCglmm|Hmsc" docs/design/35-validation-debt-register.md docs/design/05-testing-strategy.md docs/dev-log/audits/2026-05-25-jason-cross-package-binomial-sigma-scout.md docs/dev-log/after-task/2026-05-15-phase1c-simulation-recovery.md
sed -n '208,230p' vignettes/articles/lambda-constraint.Rmd
sed -n '292,310p' vignettes/articles/joint-sdm.Rmd
sed -n '24,48p' vignettes/articles/simulation-recovery-validated.Rmd
test -e docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md && echo EXISTS || echo MISSING
git status --short --branch
git diff --stat -- docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md
git diff --check -- docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md
sed -n '1,260p' docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md
git status --short --branch
perl -ne 'print "$ARGV:$.: trailing whitespace\n" if /[ \t]$/; print "$ARGV:$.: CRLF\n" if /\r$/;' docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md
wc -l docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md
sed -n '18,52p' docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md
nl -ba /Users/z3437171/.codex/memories/MEMORY.md | sed -n '286,344p'
rg -n "^## Commands Run|^## Ranked Top-5" docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md
```

Two discovery commands above intentionally returned errors and were
kept as audit evidence: `docs/articles` does not exist, and the first
probe used the wrong Design 50 filename before `50-m3-3b-surface-admission.md`
was found.
