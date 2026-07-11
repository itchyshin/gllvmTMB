# pkgdown estate disposition before gllvmTMB 0.5.0

**Date:** 2026-07-11  
**Branch:** `claude/release-0.5.0`  
**Status:** IN PROGRESS — release work is paused

## Completion boundary

The package code can be complete while the package remains unfit to release. The
0.5.0 release does not proceed until every row in this ledger has an explicit
disposition, every retained reader page has been reviewed individually, the public
navigation has been consolidated, and the rendered site has been inspected from a
reader's perspective.

The public estate currently contains the Get Started vignette plus 32 article files.
Five pages have completed the page-by-page review, 11 confirmed public keepers remain,
and 17 pages need a maintainer disposition before detailed editing.

## Disposition meanings

- **SHIP:** keep on the public site and review as a reader-facing page.
- **MERGE:** preserve useful material inside a stronger retained page, then remove the
  redundant public route.
- **HIDE:** retain as a developer artefact but remove it from the public navbar,
  article index, search, and sitemap.
- **CUT:** retire the page after checking and repairing every inbound link.
- **REWRITE:** retain the topic, but do not ship the current page without a substantial
  reader-first rewrite.

## A. Completed page reviews

These rows are complete only for the page-review stage. They remain subject to the
final cross-page navigation, link, render, and stale-wording audit.

| Page | Tier | Disposition | Review state | Notes |
|---|---:|---|---|---|
| `vignettes/gllvmTMB.Rmd` | 1 | SHIP | reviewed | Get Started path reviewed; recheck in final rendered estate. |
| `morphometrics.Rmd` | 1 | SHIP | reviewed | Canonical Tier-1 exemplar. |
| `model-selection-latent-rank.Rmd` | 1 | SHIP | reviewed | Rank-selection claims fenced to the demonstrated fixture. |
| `joint-sdm.Rmd` | 1 | SHIP | reviewed | Binary JSDM orientation and honesty fixes applied. |
| `covariance-correlation.Rmd` | 2 | SHIP | reviewed | Covariance/correlation framing and interval boundaries applied. |
| `fit-diagnostics.Rmd` | diagnostics | SHIP | panel fixes applied; maintainer visual check pending | Pat, Fisher, and Rose recommendations applied: authoritative convergence verdict, every warning exposed and interpreted, conditional-diagnostic scope, family-evidence boundary, plot interpretation, and responsive navigation. |
| `convergence-start-values.Rmd` | diagnostics | SHIP | panel fixes applied; maintainer visual check pending | Fisher, Rose, and Pat recommendations applied: scaled-gradient verdict, separate baseline/no-SE fits, convergence/inference/identifiability lanes, symptom-linked starts, restart interpretation, and narrower bootstrap scope. |
| `pre-fit-response-screening.Rmd` | diagnostics | SHIP | reviewed | Live wide/long screens passed; advisory thresholds and separation boundary checked against implementation/tests. |

## B. Confirmed public keepers still requiring individual review

The order below follows the reader path rather than filename order. Each row needs a
separate content review, edit, render check, stale-content scan, and recorded outcome.

| Order | Page | Current route | Proposed disposition | State | Main question |
|---:|---|---|---|---|---|
| 10 | `pitfalls.Rmd` | Diagnostics | SHIP | pending | Are every symptom, diagnosis, and remedy current and actionable? |
| 11 | `profile-likelihood-ci.Rmd` | Diagnostics | SHIP | pending | Are profile, Wald, and bootstrap claims limited to actual support and calibration? |
| 12 | `troubleshooting-profile.Rmd` | Diagnostics | SHIP | pending | Are all four failure modes current, reproducible, and linked to a next action? |
| 13 | `missing-data.Rmd` | Model Guides | SHIP | pending | Is the long article a coherent user path, and are unsupported missingness regimes unmistakable? |
| 14 | `gllvm-vocabulary.Rmd` | Concepts | SHIP | pending | Is this a concise glossary rather than duplicated tutorial prose? |
| 15 | `api-keyword-grid.Rmd` | Concepts | SHIP | pending | Does the reader see the canonical 4 x 4 grid without compatibility-history noise? |
| 16 | `fixed-effect-zero-constraints.Rmd` | Concepts | SHIP | pending | Does this narrow page earn a separate route or belong in the formula reference? |
| 17 | `response-families.Rmd` | Concepts | SHIP | pending | Is the covered/partial/blocked family surface clear without internal bookkeeping? |

## C. Pages requiring maintainer disposition before detailed review

These are deliberately not treated as keepers yet. The proposed disposition is a
starting recommendation, not an action already authorised.

| Page | Current visibility | Proposed disposition | Reason / consolidation target | Maintainer decision |
|---|---|---|---|---|
| `choose-your-model.Rmd` | Developer navbar | REWRITE or MERGE | The user question is valuable, but the 736-line under-audit draft overlaps Get Started, the keyword grid, and the model guides. | pending |
| `animal-model.Rmd` | Developer navbar | HIDE pending REWRITE | A central quantitative-genetic topic, but the current reader path still depends on under-audit output/accessor choices. | pending |
| `phylogenetic-gllvm.Rmd` | Developer navbar | REWRITE | Phylogenetic modelling is central enough to preserve, but the 823-line draft is not currently a first-click guide. | pending |
| `behavioural-syndromes.Rmd` | Developer navbar | REWRITE or MERGE | Strong biological question, but current Tier-3 status and overlap with the two random-slope pages need resolution. | pending |
| `random-regression-reaction-norms.Rmd` | Developer navbar | MERGE | Consolidate the reader-facing random-slope story rather than maintain parallel behavioural pages. | pending |
| `random-slopes-nongaussian.Rmd` | Developer navbar | MERGE or HIDE | Specialist family-by-slope coverage belongs with one retained reaction-norm guide or developer evidence. | pending |
| `cross-lineage-coevolution.Rmd` | Developer navbar | HIDE | Fixed-kernel point estimates do not yet justify a public methods guide with interval or estimated-rho implications. | pending |
| `lambda-constraint.Rmd` | Developer navbar | REWRITE | Confirmatory loadings can justify one Tier-2 page after a full reader-path review. | pending |
| `lambda-constraint-suggest.Rmd` | Developer navbar | MERGE | A separate 610-line companion fragments one loading-constraint workflow. | pending |
| `mixed-family-extractors.Rmd` | Developer navbar | MERGE or REWRITE | Could become a concise advanced section linked from Response families; current page risks latent-scale overinterpretation. | pending |
| `ordinal-probit.Rmd` | Developer navbar | MERGE | The family-specific explanation may fit better inside Response families unless a full worked example is retained. | pending |
| `psychometrics-irt.Rmd` | Developer navbar | HIDE | Narrow domain draft and current mixed-response evidence do not make it a core 0.5.0 reader route. | pending |
| `cross-package-validation.Rmd` | Developer navbar | HIDE | Maintainer/reviewer evidence, not a how-to page; keep out of public search and first-click navigation. | pending |
| `simulation-recovery-validated.Rmd` | Developer navbar | HIDE and RENAME | Developer evidence; the slug itself overclaims validation. Rename only with a complete cross-reference cascade. | pending |
| `simulation-verification.Rmd` | Developer navbar | HIDE or MERGE | Overlaps the recovery ledger; retain one coherent developer validation artefact, not two public pages. | pending |
| `roadmap.Rmd` | top-level navbar | HIDE | A project-state page is not part of the user learning path and becomes stale quickly. | pending |
| `functional-biogeography.Rmd` | file only; removed from nav/index | REWRITE or CUT | The ambitious capstone was already pulled because the current article exceeds its evidence and reader-readiness. | pending |

## D. Package reference and non-article surfaces

Article cleanup alone is insufficient. These surfaces receive their own audit after
the article dispositions are settled:

| Surface | Required check | State |
|---|---|---|
| `README.md` / landing page | reader route, version/lifecycle wording, no stale or internal claims | reviewed once; final estate check pending |
| `_pkgdown.yml` navbar and article index | only retained reader routes visible; no developer drafts in search/navigation | pending |
| desktop navbar breakpoint | at 1024 px, all navigation and search remain visible without horizontal overflow | source fix applied; browser verification passed at 1024 px and 390 px; final full-site render pending |
| exported roxygen and `man/*.Rd` | source/Rd agreement, useful examples, no internal register codes or stale claims | initial code sweep done; semantic review pending |
| `NEWS.md` / Changelog | plain-language release history without internal register codes | in progress; not committed as complete |
| printed examples and extractor tables | no hidden internal columns or provenance keys in rendered output | implementation present; full render verification pending |
| pkgdown Reference index | every exported topic placed once, with reader-shaped grouping and descriptions | pending |
| site search and sitemap | no hidden/cut drafts or internal rule files discoverable | pending |
| cross-links | no dead, circular, or misleading links after merge/hide/cut decisions | pending |

## E. Release gate

Do not open or advance the 0.5.0 release PR from this ledger alone. The gate opens
only after all rows have a final decision, all retained pages have completed review,
the site renders cleanly, visual inspection passes, and the after-task audit records
both what was completed and what remains outside 0.5.0.
