# Article Gate Matrix

**Date:** 2026-05-20
**Issue ledger:** #230
**Roadmap:** `ROADMAP.md` reset dashboard
**Purpose:** make article visibility depend on implemented capability, rendered
HTML review, validation evidence, and reader usefulness.

## Gate Contract

Public navbar entry requires:

1. rendered HTML review with the maintainer;
2. Pat new-user reading pass;
3. Rose stale-claim and validation-row scan;
4. Grace `pkgdown::check_pkgdown()` pass;
5. Florence review for figure-heavy pages;
6. long and wide formulas for Tier-1 worked examples, unless explicitly not
   applicable;
7. a truth/comparator table when the example is simulated;
8. no route from visible pages to hidden immature pages as recommended next
   steps.

## 2026-05-26 Article-Order Correction

Public expansion is paused until the next article lane is ordered correctly.
The public set remains `morphometrics`, `covariance-correlation`,
`api-keyword-grid`, `response-families`, `convergence-start-values`, and
`pitfalls`. Do not promote `mixed-family-extractors`, `psychometrics-irt`,
or `lambda-constraint` while this correction is open.

The next teaching lane is binary loading constraints: rework
`lambda-constraint` around a binary species/JSDM-style example, not mixed
psychometrics. `psychometrics-irt` stays Preview/internal until that article
is coherent and the `mirt` comparator path is designed.
`mixed-family-extractors` stays internal until it covers the broader
mixed-response story: Gaussian, binomial, Poisson/NB, beta/proportion, and
blocked delta/hurdle cases.

Mixed-family response teaching and loading-constraint teaching remain separate
lanes. Any correlation-matrix figure that displays interval columns uses
`plot_correlations(..., style = "heatmap", matrix_layout = "estimate_ci")`;
`plot_Sigma_heatmap()` is point-estimate-only.

## Public Surface Rows

| Article | Reader | Main question | Public status | Required functions | Capability rows | Long/wide status | Truth or comparator | Figure gate | Reviewer signoff | Return condition |
|---|---|---|---|---|---|---|---|---|---|---|
| `morphometrics` | Applied user | How do I fit and interpret a Gaussian latent + unique morphology model? | Visible; final rendered figure/prose audit passed | `gllvmTMB()`, `traits()`, `extract_Sigma()`, `extract_ordination()`, `extract_communality()`, `plot.gllvmTMB_multi()`, `plot_correlations()`, `plot_Sigma_comparison()` | FG-02, FG-03, FG-06, FAM-01, EXT-01, EXT-05, EXT-09, EXT-19, EXT-23, EXT-25, EXT-26, MIS-22 | Both shown | Known Gaussian truth from `morphometrics-example.rds`; one-dataset truth-vs-fit check; cached bootstrap correlation fixture supports visual uncertainty examples but is not calibration evidence | Passed 2026-05-24: `docs/dev-log/audits/2026-05-24-morphometrics-final-figure-prose-review.md` | Ada, Pat, Darwin, Fisher, Florence, Grace, Rose | Keep public. Re-run final rendered review if the article's figures, fitted example, or interpretation text changes. |
| `covariance-correlation` | Applied + technical user | Why does `unique()` change correlations and communality? | Visible; final rendered figure/prose audit passed | `gllvmTMB()`, `traits()`, `extract_Sigma()`, `extract_Sigma_table()`, `compare_Sigma_table()`, `plot_Sigma_table()`, `plot_correlations()` | FG-02, FG-03, FG-06, EXT-01, EXT-04, EXT-05, EXT-18, EXT-19, EXT-25, EXT-26, EXT-30 | Both shown through `covariance-edge-cases-example.rds` | Known Gaussian truth from `covariance-edge-cases-example.rds`; one-dataset `unique()` edge-case test | Passed 2026-05-24: `docs/dev-log/audits/2026-05-24-covariance-correlation-final-figure-prose-review.md` | Ada, Pat, Fisher, Florence, Rose, Grace | Keep public. Re-run final rendered review if the article's matrix displays, fitted example, or interval-provenance text changes. |
| `api-keyword-grid` | Technical user | Which formula keyword names which covariance mode and correlation row? | Visible; technical reference scope audit passed | Formula parser, `traits()`, covariance keywords | FG-01..FG-09, FG-12..FG-15, PHY-01..PHY-10, SPA-01..SPA-07, MET-01..MET-04, ANI-01..ANI-10, MIS-02, MIS-11 (mixed covered/partial/blocked per article scope table) | Both shown for ordinary bar-style terms | Not applicable | None | Ada, Boole, Grace, Rose | Passed 2026-05-24: `docs/dev-log/audits/2026-05-24-technical-reference-final-scope-review.md`. Re-run if keyword status rows, grid syntax, hidden worked-example routing, or validation-register row status changes. |
| `response-families` | Applied + technical user | Which family can I fit, and what is its validation status? | Visible; technical reference scope audit passed | `family_to_id()`, `gllvmTMB()`, `extract_Sigma()`, `extract_Omega()` | FAM-01..FAM-19, MIX-01..MIX-10, EXT-01..EXT-08 | Both shown for single-family; mixed-family wide not applicable yet | Not applicable | None | Ada, Fisher, Grace, Rose | Passed 2026-05-24: `docs/dev-log/audits/2026-05-24-technical-reference-final-scope-review.md`. Re-run if `family_to_id()`, exported family constructors, delta/hurdle boundaries, or mixed-family interpretation claims change. |
| `convergence-start-values` | Applied user | What should I do when fitting is hard? | Visible; final wording audit passed | `check_gllvmTMB()`, `gllvmTMBcontrol()`, `sanity_multi()`, `confint_inspect()`, `extract_Sigma_table()` | DIA-01..DIA-10, EXT-13 partial, EXT-18, CI-02, CI-03 | Both shown where examples use the public fit path | Diagnostic example | None unless diagnostic plots added | Ada, Fisher, Grace, Rose | Passed 2026-05-24: `docs/dev-log/audits/2026-05-24-convergence-final-wording-review.md`. Re-run if `pdHess`, bootstrap/profile, start-method, or diagnostics claims change. |
| `pitfalls` | Applied user | What mistakes look like package bugs, and how do I fix them? | Visible; final prose audit passed | `gllvmTMB()`, `extract_Sigma()`, `rotate_loadings()`, `suggest_lambda_constraint()`, `meta_V()` | FG-02, EXT-01, EXT-09, LAM-04, MET-01, MET-02 | Long shown; wide equivalence intentionally points to Get Started | Small reproducible diagnostics | None | Ada, Pat, Boole, Rose, Grace | Passed 2026-05-24: `docs/dev-log/audits/2026-05-24-pitfalls-final-prose-review.md`. Re-run if article examples, scope-boundary rows, or hidden-article next steps change. |

## Hidden Article Rows

| Article | Reader | Main question | Public status | Required functions | Capability rows | Long/wide status | Truth or comparator | Figure gate | Reviewer signoff | Return condition |
|---|---|---|---|---|---|---|---|---|---|---|
| `joint-sdm` | Applied ecology user | How do I fit and interpret a binary joint species distribution model? | Hidden | `gllvmTMB()`, `traits()`, binary families, diagnostics, extractors, plots | FAM-02/FAM-03, FG-02, FG-03, DIA rows, EXT rows | Present but must be rechecked | Known binary truth + caveats | Needed | Pat, Darwin, Fisher, Florence, Grace, Rose | Joint SDM example object; binary validation caveats; diagnostic table; rendered figures. |
| `profile-likelihood-ci` | Technical user | When should I use profile/bootstrap intervals instead of Wald intervals? | Hidden | `confint()`, `tmbprofile_wrapper()`, `profile_targets()`, bootstrap helpers | CI-01..CI-10, EXT-13 | Not applicable | Coverage/comparator evidence | Possibly | Fisher, Gauss, Noether, Grace, Rose | Profile/bootstrap status cleaned; fallback language first; no M3 coverage overclaim. |
| `behavioural-syndromes` | Applied ecology/evolution user | How do between- and within-individual covariance differ? | Hidden | two-level `latent + unique`, repeatability, communality, plots | FG-02, FG-03, EXT-05, EXT-06, DIA rows | Missing/needs rebuild | Known behavioural truth | Needed | Pat, Darwin, Fisher, Florence | Behavioural example object; between/within covariance and repeatability recovery. |
| `mixed-family-extractors` | Technical user | How do extractors behave when traits use different likelihoods? | Hidden technical reference; hold internal | mixed-family fits, extractor tables | MIX-01..MIX-10, EXT rows partial | Not applicable until a broader mixed-response fixture exists | Known mixed-family truth | Needed if plots added | Fisher, Emmy, Rose | Broader mixed-response expansion first: Gaussian, binomial, Poisson/NB, beta/proportion, and blocked delta/hurdle cases; keep separate from loading constraints. |
| `animal-model` | Evolutionary quantitative-genetics user | How do I estimate genetic covariance with a pedigree? | Hidden | `animal_*()`, `pedigree_to_A()`, `pedigree_to_Ainv_sparse()`, heritability/extractors | ANM rows, FG rows, EXT rows | Missing/needs rebuild | Larger pedigree truth | Needed | Darwin, Noether, Curie, Fisher, Florence | Larger pedigree fixture; A/Ainv truth; genetic covariance recovery. |
| `phylogenetic-gllvm` | Comparative biology user | How do phylogenetic and non-phylogenetic covariance components split? | Hidden | `phylo_*()`, `extract_phylo_signal()`, diagnostics | PHY-01..PHY-10, EXT-07 | Present but must be rechecked | Known phylo truth | Needed | Darwin, Noether, Fisher, Florence | Phylo helper; phylo versus non-phylo split; validation rows checked. |
| `psychometrics-irt` | Methods + applied user | How does binary IRT relate to `lambda_constraint`? | Hidden Preview/internal; defer | binary fits, `lambda_constraint`, comparator tools | LAM-02, LAM-03, FAM-02 | Missing/needs rebuild | `mirt`/`galamm` comparator path must be designed before promotion | Needed | Noether, Fisher, Pat | Wait until the binary lambda/JSDM article is coherent; the current page is not the final IRT article. |
| `lambda-constraint` | Technical user | How do I constrain loading matrices safely? | Hidden; next rework lane | `lambda_constraint`, `suggest_lambda_constraint()`, rotation helpers | LAM-02..LAM-04, EXT-14, EXT-15 | Present but must be rechecked | Binary species/JSDM-style confirmatory loading truth | Required if matrix intervals appear | Boole, Noether, Fisher, Florence, Rose | First binary loading-constraint teaching article; use a binary species/JSDM-style example and keep mixed-family response teaching out of this lane. |
| `simulation-recovery-validated` | Developer + methods user | Does simulation recovery meet the statistical gate? | Hidden | `coverage_study()`, grid artifacts, diagnostics, plots | CI-08, M3 rows, DIA rows | Not applicable | M3 target-explicit evidence | Needed | Curie, Fisher, Florence, Grace, Rose | M3 target-explicit statistical gate passes and missing-CI ledger is honest. |
| `cross-package-validation` | Methods user | How does gllvmTMB compare with sister packages? | Hidden | comparator scripts, extracted estimands | Phase 5.5 rows | Not applicable | External comparator evidence | Needed | Jason, Fisher, Noether, Rose | Phase 5.5 comparator evidence exists. |
| `functional-biogeography` | Applied capstone reader | How do multiple structures combine in one ecological workflow? | Hidden | all component helpers, diagnostics, plots, uncertainty | Mixed Phase 1/M3/Phase 5 rows | Missing/needs rebuild | Known capstone truth | Required | Ada, Darwin, Fisher, Florence, Grace, Rose | Last capstone; all component helpers and M3 evidence complete. |
| `choose-your-model` | Applied user | Which model should I try first? | Hidden | decision tree, status labels, examples | Depends on public surface | Needs rewrite | Not applicable | None | Pat, Rose, Grace | Returns only after public surface and hidden-link targets are stable. |
| `data-shape-flowchart` | New user | Is my data long, wide, or matrix-like? | Hidden | data-shape helpers and formula examples | FG-01..FG-03 | Needs rewrite | Not applicable | None | Pat, Boole, Rose | Integrated with landing/Get Started and long/wide examples. |
| `gllvm-vocabulary` | Technical user | What do package terms mean? | Hidden | reference definitions | All rows by term | Not applicable | Not applicable | None | Boole, Rose | Returns as compact glossary after terminology sweep. |
| `ordinal-probit` | Technical user | How are ordered-category traits represented? | Hidden | `ordinal_probit()`, cutpoint extractors, diagnostics | FAM-14, EXT-16 | Missing/needs rebuild | Ordered-category truth | Maybe | Fisher, Noether, Rose | Ordinal validation and reader-facing caveats pass. |
| `simulation-verification` | Developer | How are simulation checks organised? | Hidden/internal | test helpers and validation register | M3 and test-strategy rows | Not applicable | Simulation evidence | None | Curie, Rose | Returns only as technical note if needed. |
| `stacked-trait-gllvm` | New user | What is a stacked-trait GLLVM? | Hidden | intro examples | FG rows | Missing/needs rewrite | Not applicable | None | Pat, Boole, Rose | Either merged into Get Started or restored after duplication audit. |
| `troubleshooting-profile` | Technical user | How do I troubleshoot profile intervals? | Hidden | profile helpers | CI rows | Not applicable | Profile evidence | None | Fisher, Grace, Rose | Merge with profile-likelihood article or restore after CI gate. |
| `roadmap` | Maintainer + contributor | What is current project state? | Top-nav only | pkgdown wrapper | Not applicable | Not applicable | Not applicable | None | Ada, Grace, Rose | Never appears in the article dropdown; rendered via top nav. |

## Restoration Rule

Restoration is one article per PR or bounded slice. The PR or after-task
report must name the active reviewers, the validation rows, the rendered HTML
path inspected, the stale-wording scans, and the exact reason the page is safe
for the public navbar.
