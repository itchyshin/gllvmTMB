# Article Council Ledger

**Date:** 2026-06-18
**Scope:** governance ledger for the full article estate.
**Status:** planning / triage control, not a navbar or article-content change.

This ledger implements the article-council step before any further public
article movement. It records the intended decision for every vignette/article
currently on disk, including pages that are visible, hidden, technical,
internal, or candidates for merge/retirement.

The controlling guard remains:

```text
PR green != bridge complete != release ready != scientific coverage passed
```

No article moves into the public navbar just because it exists. A page moves
only when its capability rows, examples, reader path, figure evidence, rendered
HTML, and review notes agree.

## Council

| Role | Article-council responsibility |
|---|---|
| Ada | Final go/no-go, sequence, and one-article-at-a-time discipline. |
| Pat | First-time applied-reader path: question, runnable code, interpretation. |
| Rose | Stale-claim scan, validation-row alignment, and hidden-link audit. |
| Grace | pkgdown, render, CRAN, dependency, and check evidence. |
| Boole | Formula/API syntax, keyword consistency, and example grammar. |
| Fisher | Inference, interval, coverage, and comparator claim boundaries. |
| Curie | Simulation fixtures, recovery tests, truth tables, and scoring evidence. |
| Florence | Figure quality, accessibility, and uncertainty display. |
| Darwin | Biological/ecological story and applied interpretation. |
| Gauss | Likelihood, parameterisation, and numerical stability. |
| Noether | Symbolic equations, notation, and math-to-code alignment. |
| Emmy | S3/helper/object coherence and data-object contracts. |
| Jason | External landscape, sister-package comparators, and source-map lessons. |
| Shannon | Coordination: branch, PR, handoff, and hot-file collision checks. |

## Decision Workflow

For each article, run this workflow before changing navbar status:

1. Inventory the article file, YAML tier, current navbar/pkgdown status,
   examples, figures, and outgoing links.
2. Map every advertised capability to validation-debt row IDs and row status:
   `covered`, `partial`, `opt-in`, or `blocked`.
3. Write the one reader-shaped question the article answers.
4. Choose one action: keep public, rewrite, merge, split, demote to Tier 2,
   keep internal, or retire from navigation.
5. Name evidence work: example object, truth/comparator table, diagnostics,
   long/wide calls, failure mode, and row-level claims.
6. Name figure work for Florence when plots carry interpretation.
7. Render the touched article(s) and inspect the HTML before navbar changes.
8. Run Rose/Pat/Grace publication checks.
9. Record the result in `docs/dev-log/check-log.md` and an after-task report.

## Current Visible Surface

| Article | Current nav | Proposed tier | Action | Capability rows | Blockers | Reviewers | Exact next edit | Render/check command |
|---|---|---|---|---|---|---|---|---|
| `vignettes/gllvmTMB.Rmd` | Get Started / intro | Tier 1 entry path | Keep public; audit after article decisions | FG-01..FG-06, FAM-01, EXT/DIA rows used by examples | Must not route to hidden immature pages; long/wide examples must stay current | Ada, Pat, Boole, Rose, Grace | After article decisions, audit outgoing links and long/wide examples against current public surface | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `morphometrics` | Articles / Model guide | Tier 1 worked example | Keep public; use as exemplar | FG-02, FG-03, FG-06, FAM-01, EXT-01, EXT-05, EXT-09, EXT-18/19, EXT-25/26 | Re-render if figures, fit object, or truth-vs-fit prose changes | Ada, Pat, Darwin, Fisher, Florence, Rose, Grace | No content move now; keep as benchmark for Tier 1 rewrites | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `model-selection-latent-rank` | Articles / Model guide | Tier 1 narrow worked example | Keep public with narrow claim | FG-04, FG-06, DIA-03, DIA-08, DIA-10 | Must remain a Gaussian teaching fixture, not universal rank calibration | Ada, Curie, Fisher, Pat, Boole, Rose, Grace | Keep wording tied to diagnostics-first AIC/BIC, not proof of biological rank | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `joint-sdm` | Articles / Model guide | Tier 1 worked example | Keep public with binary caveats | FAM-02/FAM-03, FG-02, FG-03, DIA rows, EXT rows | Stronger binary or loading-constraint claims need rerendered review; as of 2026-06-18 it no longer routes readers to hidden lambda articles | Pat, Darwin, Fisher, Florence, Rose, Grace | Re-review before using it as support for `lambda_constraint` promotion | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `lambda-constraint` | Internal drafts and technical notes | Candidate Tier 1, not yet safe | Keep internal until reader/browser review and loading-uncertainty figure repair pass | LAM-02..LAM-04, FAM-02/FAM-03, EXT-14/15 | Article-gate matrix says binary loading-constraint lane must stay coherent before promotion; 2026-06-18 cleanup removed public-dropdown visibility; 2026-06-19 focused render and rendered scope review passed, with seven figure assets checked. The 2026-06-19 browser/layout slice shortened the visible H1 and desktop first-viewport screenshot passed, but Confidence Eye remains a blocker: the rendered figure shows hollow points only because the Wald loading-CI path is unavailable under a non-PD Hessian. The section now says this explicitly | Ada, Boole, Noether, Fisher, Florence, Pat, Rose, Grace | Repair the loading-uncertainty figure with a PD fixture or profile/bootstrap loading intervals, then rerun browser/mobile and public-placement review; companion stays behind it | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `lambda-constraint-suggest` | Internal drafts and technical notes | Candidate Tier 2 companion | Keep internal until main lambda article is coherent and companion evidence is refreshed | LAM-04, EXT-14/15 | Companion should not be public before the main teaching path is stable; 2026-06-18 cleanup moved it with `lambda-constraint`; 2026-06-19 routine-render unblock marks `profile_retention`, data-driven refit, model-comparison, and Confidence Eye chunks display-only so the page builds without the cold-cache 40-refit path. Rendered HTML keeps the internal gate and display-only note; stale PNG files remain in the output directory but are not referenced | Boole, Pat, Fisher, Rose, Grace | If promoting later, run the retained-loading/profile path manually, refresh evidence and figures, then do browser and public-placement review | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/lambda-constraint-suggest", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `covariance-correlation` | Articles / Concepts | Tier 1 concept/worked explanation | Keep public | FG-02, FG-03, FG-06, EXT-01, EXT-04/05, EXT-18/19, EXT-25/26, EXT-30 | Re-render if matrix displays or interval provenance changes | Ada, Pat, Fisher, Florence, Rose, Grace | No content move now; preserve interval-provenance wording | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `api-keyword-grid` | Articles / Concepts | Tier 2 technical reference | Keep public as reference | FG-01..FG-17, PHY, SPA, MET, ANI rows as labelled | Must stay synchronized with parser and validation vocabulary | Ada, Boole, Rose, Grace | Re-audit if keyword grid or row statuses move | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `response-families` | Articles / Concepts | Tier 2 technical reference | Keep public as reference | FAM-01..FAM-19, MIX rows, EXT rows | Sync to register before any family-depth claim changes | Gauss, Fisher, Rose, Grace | Re-audit family labels and blocked/partial rows before release text | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `fit-diagnostics` | Articles / Methods | Tier 1 methods article | Keep public; diagnostic-only | DIA-08, DIA-10, DIA-11, DIA-12, DIA-13 | Must not imply interval calibration or posterior predictive checks | Ada, Pat, Fisher, Florence, Rose, Grace | Keep diagnostics-first wording and failure-mode examples | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `convergence-start-values` | Articles / Methods | Tier 1 methods/troubleshooting | Keep public | DIA-01..DIA-10, CI-02/03, EXT-13/18 | Re-audit if `pdHess`, profile, bootstrap, or starts change | Fisher, Grace, Rose, Pat | No content move now | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `pitfalls` | Articles / Methods | Tier 1 applied safety article | Keep public | FG, EXT, LAM, MET, MIS rows used by examples | Must not recommend hidden immature pages | Ada, Pat, Boole, Rose, Grace | Audit outgoing links after hidden/public reshuffle | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `missing-data` | Articles / Methods | Tier 1 scoped methods article | Keep public only within MIS scope | MIS-01..MIS-31 as covered/partial, MIS-32 blocked | Must not imply multiple `mi()`, MI pooling, or broad missingness engines | Fisher, Rose, Grace, Pat, Boole | Keep chunk policy and scope boundary; re-audit if MIS rows move | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `profile-likelihood-ci` | Articles / Technical reference | Tier 2 methods reference | Keep public as technical reference | CI-01..CI-10, EXT-13 | Keep API mechanics separate from calibrated coverage; no broad release/scientific coverage claim | Fisher, Gauss, Noether, Grace, Rose | 2026-06-18 slice moved it out of the internal bucket, added Tier 2 YAML, and tightened scope wording | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `troubleshooting-profile` | Articles / Technical reference | Tier 2 troubleshooting reference | Keep public as technical reference | CI-01..CI-10, EXT-13, DIA-01/DIA-03/DIA-05 | Must remain troubleshooting, not guaranteed profile success | Fisher, Grace, Rose | 2026-06-18 slice moved it out of the internal bucket with `profile-likelihood-ci`; no content rewrite | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `roadmap` | Top nav and internal section | Contributor status page | Keep top-nav only | Not applicable | Should not appear as a recommended user article | Ada, Grace, Rose | Keep as top-nav status; avoid article-dropdown routing except internal build listing | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |

## Hidden / Internal Estate

| Article | Current nav | Proposed tier | Action | Capability rows | Blockers | Reviewers | Exact next edit | Render/check command |
|---|---|---|---|---|---|---|---|---|
| `animal-model` | Internal drafts | Tier 3 candidate Tier 1 draft | Keep internal until final placement decision and larger-evidence gaps close | ANI-01..ANI-12, DIA-08, related FG/EXT rows | Reader/scope bridge now maps heritability, bivariate G, rank-1 G, and heritable reaction-norm questions to model objects, known simulation truth, and readouts; rendered diagnostic table shows optimizer convergence, gradient, `sdreport`, and `pd_hessian` passing for all four examples; Florence review passes the current point-estimate genetic-correlation heatmap; 2026-06-19 rendered HTML scope review and rendered-asset dimension check passed; 2026-06-19 system-Chrome browser review passed with desktop/mobile layout checks, heatmap load, descriptive alt text, no overclaim wording, and only expected narrow-layout overflow. Larger-pedigree and cross-package agreement evidence remain partial, so this stays internal | Darwin, Noether, Curie, Fisher, Florence, Rose | Make a final public-placement decision only after larger-pedigree and cross-package evidence boundaries are accepted; keep internal meanwhile | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/animal-model", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `behavioural-syndromes` | Internal drafts | Tier 3 candidate Tier 1 draft | Keep internal until final public-placement review | RE-04, RE-09, EXT-05, EXT-06, EXT-18, EXT-25..EXT-27, DIA-08, DIA-13 | Wide-format fit now renders and matches the long-form likelihood to `2.6e-09`; diagnostic table now renders with optimizer convergence, gradient, `sdreport`, and `pd_hessian` passing for both long and wide layouts under the independent-diagonal warm start; reader-path bridge now maps question, model object, code section, and readout; Florence review now passes the current point-estimate covariance, ordination, loading-recovery, and truth-comparison figures after ordination/loading layout polish; Pat/Darwin cleanup now passes after gate/citation/dependency/claim-boundary cleanup; rendered-asset review passed; 2026-06-19 system-Chrome browser review passed after the in-app browser was unavailable: desktop and mobile screenshots plus full-page captures were inspected, all six images loaded with nonzero dimensions, five article figures have descriptive alt text, local image/link checks found no missing targets, stale overclaim scan found only the intended internal gate, and mobile showed no document-level horizontal scroll beyond expected scrollable code blocks | Pat, Darwin, Fisher, Curie, Florence, Rose, Grace | Make a final public-placement decision only after confirming whether this internal two-level worked example should join the public article dropdown; keep it internal meanwhile | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/behavioural-syndromes", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `choose-your-model` | Internal drafts | Candidate Tier 1 navigation guide | Keep internal until linked article surface is public-safe | Depends on stabilized public surface | The 2026-06-19 slice added Tier 3 YAML, an internal navigation-draft gate, explicit wording that linked worked examples remain internal, and removed "validated rungs" / publication-grade CI wording. Focused render, rendered HTML scope review, and ladder-figure asset check passed | Pat, Rose, Grace, Boole | Rebuild as a public decision guide only after linked biological/advanced/capstone articles have public-placement decisions | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/choose-your-model", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `cross-lineage-coevolution` | Internal drafts | Tier 3 until COE gates close | Keep internal | COE-01..COE-04, KER rows | Fixed-rho point-estimate only; no intervals, in-engine `rho`, formal null thresholds, or full scientific coverage. The 2026-06-19 slice added explicit Tier 3 gating, the Paper 2 two-source covariance identity, and a raw reciprocal-dependence versus residualized tip-kernel screen tied to the COE-04 diagnostic gate | Jason, Noether, Fisher, Florence, Rose | Keep internal; next decision is whether to split C4/C5 prose or wait for in-engine `rho` / interval evidence before public rewrite | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/cross-lineage-coevolution", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `cross-package-validation` | Internal drafts | Tier 3 until comparator evidence exists | Keep internal | Phase 5.5 comparator rows, CI-08, CI-10, MET-01 | Comparator evidence remains incomplete; the 2026-06-19 slice added Tier 3 YAML, an internal comparator-ledger gate, evidence-specific scope wording, partial-row language, and removed broad "every shared structure" / "correct" / "inference-complete" claims. Rendered HTML scope review and the optional gllvm plot asset check passed | Jason, Fisher, Noether, Rose, Grace | Build the actual Phase 5.5 comparator ledger before public prose; keep interval and mixed-family claims row-specific until CI-08/CI-10 move | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/cross-package-validation", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `data-shape-flowchart` | Internal drafts | Tier 3 routing draft | Keep internal; merge idea into Get Started later only after target examples are public | FG-01..FG-03 | Current draft routes to several hidden example pages; not safe as public navigation | Pat, Boole, Rose | 2026-06-19 rendered internal review passed after fixing MathML `\mathrm{}` notation; revisit after biological examples are promoted | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/data-shape-flowchart", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `functional-biogeography` | Internal drafts | Final capstone | Keep internal | Component helper rows plus M3/CI rows | M3 evidence and component helpers not complete; avoid publication-grade claims without proof. The 2026-06-19 slice added Tier 3 YAML, strengthened the internal capstone gate, updated default-`latent()` / compatibility-`unique()` wording, kept CI-08/CI-10 partial, and replaced the remaining publication-grade phrase with point-estimate teaching language. Focused render, rendered HTML scope review, and heatmap asset checks passed | Ada, Darwin, Fisher, Florence, Grace, Rose | Leave public promotion until M3/CI/component evidence closes; keep as internal capstone method demo meanwhile | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/functional-biogeography", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `gllvm-vocabulary` | Articles / Technical reference | Tier 2 glossary | Keep public as compact terminology reference | Cross-cutting FG/FAM/EXT/DIA vocabulary only; no row movement | Hidden worked-example links must stay pruned | Boole, Pat, Rose, Grace | 2026-06-18 slice restored it as Tier 2, added scope wording, and removed hidden-page routing | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `mixed-family-extractors` | Internal drafts | Tier 3 mixed-response extractor draft | Keep internal | MIX-01..MIX-10, DIA-13, EXT-01/05/06/13/18/27, CI-10 | Reader/scope bridge now maps per-row family dispatch, diagnostic metadata, latent-scale Sigma, heatmap correlations, Fisher-z/bootstrap examples, and bootstrap Sigma output to readouts; rendered fit-health status counts show PASS 10 / WARN 3; the point-estimate correlation heatmap passes as an internal figure. 2026-06-19 slice added a compact broader-family map: Gaussian/binomial/Poisson runnable here, NB/beta still needing a broader teaching fixture, delta/hurdle blocked by MIX-10, and mixture families outside scope. The 2026-06-19 system-Chrome browser slice passed after the in-app browser was unavailable: desktop/mobile screenshots and full-page captures were inspected, the heatmap loaded with descriptive alt text, local image/link checks found no missing targets, stale overclaim scan found only the intended internal gate, and mobile showed no document-level horizontal scroll beyond expected scrollable code/output blocks. CI-10 remains partial and MIX-10 remains blocked | Fisher, Emmy, Rose, Pat, Grace, Florence | Add runnable NB/beta teaching fixture and final public-placement review before any public move | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/mixed-family-extractors", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `ordinal-probit` | Internal drafts | Tier 3 threshold-trait technical draft | Keep internal until extractor, interval, residual-diagnostic, and placement caveats are current | FAM-14, EXT cutpoint rows, JUL ordinal bridge exclusions where relevant | The 2026-06-19 runnable-fixture slice replaced syntax-only examples with a compact two-trait ordinal example in long and wide form. Rendered output shows a near-zero long/wide log-likelihood difference, `extract_cutpoints()` rows, `extract_Sigma(..., link_residual = "auto")` adding the fixed ordinal residual variance, and passing `check_gllvmTMB()` fit-health rows. `response-families` now matches the register by saying FAM-14 is covered. The 2026-06-19 system-Chrome browser slice passed after the in-app browser was unavailable: desktop/mobile screenshots and full-page captures were inspected, the package-logo image loaded, local image/link checks found no missing targets, stale overclaim scan found only the intended internal gate, and mobile showed no document-level horizontal scroll beyond expected scrollable code/output blocks. The article still stays internal for EXT-10/cutpoint depth, ordinal intervals, exact ordinal residual diagnostics, and public placement. No article PNG assets are expected | Fisher, Noether, Rose, Grace, Pat | Make a final public-placement decision only after ordinal extractor/interval/residual-diagnostic caveats are settled | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/ordinal-probit", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `phylogenetic-gllvm` | Internal drafts | Tier 3 candidate Tier 1 draft | Keep internal until final public-placement decision | PHY rows, EXT phylo-signal rows, DIA rows | Reader/scope bridge now names the phylogenetic versus non-phylogenetic split, row anchors, and point-estimate boundary; diagnostic table now renders with optimizer convergence, gradient, `sdreport`, and `pd_hessian` passing for both long and wide layouts; Florence review passes the current point-estimate total-correlation heatmap; 2026-06-19 rendered HTML scope review and rendered-asset dimension check passed. 2026-06-19 system-Chrome browser review passed with desktop/mobile layout checks, loaded logo and heatmap with alt text, no overclaim wording, and only expected table/math overflow | Darwin, Noether, Fisher, Florence, Rose | Make a final public-placement decision after checking whether this belongs ahead of advanced structured-dependence articles; keep internal meanwhile | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/phylogenetic-gllvm", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `psychometrics-irt` | Internal drafts | Tier 3 preview | Keep internal | LAM rows, FAM-02/FAM-03, comparator rows | Binary lambda/JSDM article and `mirt` comparator path not designed; 2026-06-19 slice added explicit Tier 3 YAML, standard internal article gate wording, replaced cross-domain validation wording with cross-domain preview, and passed rendered HTML/asset checks | Noether, Fisher, Pat, Rose | Do not promote until after lambda-constraint rewrite and comparator design | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/psychometrics-irt", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `random-regression-reaction-norms` | Internal drafts, Tier 3 YAML | Tier 3 candidate Tier 1 draft | Keep Tier 3 until uncertainty and placement review pass | RE-12 partial, DIA-08, EXT-01, EXT-06, CI rows for uncertainty limits | Reader/scope bridge now maps the behavioural reaction-norm question to long/wide fit equivalence, augmented covariance blocks, known-truth recovery, repeatability curves, and diagnostics; rendered optimizer and gradient rows pass, while `sdreport` and Hessian warn as expected because `se = FALSE`; 2026-06-19 rendered HTML scope review passed after aligning the opening note to the standard internal article gate, and four figure assets passed dimension checks. 2026-06-19 system-Chrome browser review passed with desktop/mobile layout checks, current figures loaded with descriptive alt text, no overclaim wording, and only expected table/code overflow. Non-Gaussian augmented `unique()` remains guarded and interval calibration remains open | Pat, Fisher, Rose, Grace, Florence | Make a final uncertainty-review and public-placement decision before public promotion | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/random-regression-reaction-norms", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `random-slopes-nongaussian` | Internal drafts | Tier 3 technical draft | Keep internal | PHY-11..18, SPA-08..10, ANI-11/12, RE-03, FAM-17, MIX-10, CI rows | Reader/scope bridge now maps long/wide grammar, small Gaussian fit, Poisson fit, correlated `phylo_dep` syntax, and spatial twin syntax to their readouts; rendered log-likelihood equality and optimizer/gradient PASS rows are present; 2026-06-19 rendered HTML scope review passed and no figure assets are expected. The 2026-06-19 system-Chrome browser slice passed: fresh render, desktop/mobile screenshots, full-page captures, image/link checks, stale-overclaim scan, and true 390px mobile layout metrics found no document-level horizontal scroll beyond expected scrollable table/code blocks. Confidence intervals and non-Gaussian `s >= 2` remain explicitly not promoted | Pat, Fisher, Rose, Grace, Noether | Keep as structured workflow until the phylo/structured-dependence learning path, uncertainty caveats, and final public-placement decision are public-ready | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/random-slopes-nongaussian", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `simulation-recovery-validated` | Internal drafts | Tier 3 until M3 passes | Keep internal | CI-08, CI-10, M3 rows, DIA rows | M3 target-explicit statistical gates not passed; CI-08 and CI-10 remain partial. The 2026-06-19 slice retitled the page to `Simulation recovery: M3 smoke grid`, added Tier 3/internal coverage-triage gating, named the failed M3.3 production gate, and removed validated/release-readiness implications. Rendered HTML scope review passed; no figure assets expected | Curie, Fisher, Florence, Grace, Rose | Wait for target-explicit scoring evidence and a successful production gate before public rewrite | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/simulation-recovery-validated", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `simulation-verification` | Internal drafts | Tier 3 diagnostic draft | Keep internal | Test-strategy and M3 rows | Developer-facing unless converted into a compact reference; 2026-06-19 slice added explicit Tier 3 YAML and standard internal article gate, removed publication-ready/publication-grade wording, and passed rendered HTML/asset checks | Curie, Rose, Grace | Decide whether to merge into validation docs rather than public articles after M3 target-explicit gates close | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/simulation-verification", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |
| `stacked-trait-gllvm` | Internal drafts | Tier 3 conceptual draft | Keep internal; superseded by Get Started + Morphometrics for now | FG-01..FG-06 | Duplicates the public entry path and mixes in hidden advanced examples | Pat, Boole, Rose | 2026-06-19 rendered internal review passed; mine only compact concept text later if Get Started needs it | `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/stacked-trait-gllvm", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'` |

## Immediate Article Order

1. Stabilise the current public set and remove hidden-page routing.
2. Resolve the `lambda-constraint` lane because it affects binary/JSDM teaching.
3. Decide `profile-likelihood-ci` and `troubleshooting-profile` public Tier 2
   placement. **Done 2026-06-18:** both are visible as Technical reference
   pages, with `profile-likelihood-ci` carrying explicit Tier 2 and scope
   wording.
4. Decide whether `data-shape-flowchart`, `stacked-trait-gllvm`, and
   `gllvm-vocabulary` merge into Get Started or return as compact guides.
   **Done 2026-06-18:** `gllvm-vocabulary` returned as visible Tier 2
   glossary; `data-shape-flowchart` and `stacked-trait-gllvm` stay internal
   Tier 3 drafts until their target examples are safe.
5. Triage biological worked examples: `behavioural-syndromes`,
   `phylogenetic-gllvm`, and `animal-model`.
   **Started 2026-06-18:** `behavioural-syndromes` stays internal as a
   Tier 3 candidate Tier 1 draft. **2026-06-19 update:** the runnable wide
   call now renders and matches the long-form likelihood. **2026-06-19
   follow-up:** the diagnostic table now renders too. **2026-06-19 repair:**
   adding the independent-diagonal warm start makes the key long and wide
   diagnostic rows pass. **2026-06-19 reader-path slice:** a compact reader
   bridge now maps the biological questions to model objects, code sections,
   and readouts. **2026-06-19 Florence slice:** the current point-estimate
   figures pass after ordination/loading layout polish. **2026-06-19
   Pat/Darwin slice:** the article gate, citation hook, unused dependency,
   and overclaiming simulated-example prose were cleaned up; final rendered
   HTML review still blocks promotion. **2026-06-19 rendered-asset slice:**
   the rebuilt HTML, stale-text checks, PASS diagnostic rows, five PNG assets,
   and Quick Look top-page thumbnail passed. **2026-06-19 browser slice:**
   the in-app browser was unavailable, but system Chrome desktop/mobile
   screenshots, full-page captures, image/link checks, and mobile layout
   metrics passed with only expected scrollable code-block overflow; public
   promotion still waits for a final placement decision. **2026-06-19 phylogenetic slice:** `phylogenetic-gllvm` gained
   explicit Tier 3/internal gating plus a reader/scope bridge tying the
   phylogenetic/non-phylogenetic split to validation rows and the point-estimate
   boundary; diagnostic table, figure review, and rendered review remain before
   public movement. **2026-06-19 phylogenetic diagnostics slice:** the article
   now renders long/wide `diagnostic_table()` evidence with the key
   optimizer/gradient/`sdreport`/Hessian rows passing; figure and rendered
   review still block public movement. **2026-06-19 phylogenetic Florence
   slice:** the current two-facet total-correlation heatmap passes as a
   point-estimate figure with readable labels, appropriate diverging scale, and
   explicit no-interval caption; rendered review passed and a later
   system-Chrome browser review passed. **2026-06-19
   animal-model slice:** the article gained explicit Tier 3/internal gating, a
   reader/scope bridge, rendered diagnostic-table evidence for the
   heritability, bivariate G, rank-1 G, and reaction-norm examples, and a
   Florence pass for the current genetic-correlation heatmap. It stays internal
   until final public-placement review and larger-evidence boundaries pass.
6. Triage advanced methods: `random-regression-reaction-norms`,
   `random-slopes-nongaussian`, `mixed-family-extractors`, and
   `ordinal-probit`. **2026-06-19 random-regression slice:** the ordinary
   Gaussian reaction-norm article gained a reader/scope bridge, removed an
   unused `dplyr` attach, rendered with long/wide log-likelihood equality,
   optimizer/gradient PASS rows, expected `se = FALSE` `sdreport`/Hessian
   WARN rows, and two point-estimate/truth-comparison figures. It stays
   Tier 3 until uncertainty and placement review pass; a later system-Chrome
   browser review passed. **2026-06-19
   structured random-slopes slice:** `random-slopes-nongaussian` gained
   explicit Tier 3/internal gating plus a reader/scope bridge for long/wide
   grammar, small Gaussian and Poisson fits, correlated `phylo_dep` syntax, and
   the spatial twin. It rendered with log-likelihood equality and
   optimizer/gradient PASS rows; no interval calibration or non-Gaussian
   `s >= 2` promotion is claimed. **2026-06-19 random-slopes browser slice:**
   system Chrome desktop/mobile screenshots, full-page captures, stale-overclaim
   scan, image/link parser, and true 390px mobile layout metrics passed with
   only expected scrollable table/code overflow; public placement and
   uncertainty decisions remain open. **2026-06-19 mixed-family extractor
   slice:** `mixed-family-extractors` gained Tier 3 YAML and a reader/scope
   bridge for per-row family dispatch, diagnostic metadata, latent-scale Sigma,
   heatmap correlations, and interval API examples. It rendered with compact
   PASS/WARN diagnostic counts and a point-estimate correlation heatmap; CI-10
   remains partial and MIX-10 remains blocked. **2026-06-19 ordinal-probit
   slice:** `ordinal-probit` was demoted from stale Tier 2 YAML to Tier 3
   internal technical draft, gained a reader/scope bridge, and taught
   `phylo_indep()` / `indep()` for standalone diagonal syntax while retaining
   `unique()` only as an unidentifiable observation-level guardrail.
   **2026-06-19 ordinal runnable-fixture slice:** the article now runs a compact
   two-trait ordinal example in long and wide form, renders near-zero long/wide
   log-likelihood difference, cutpoint extraction, latent-scale Sigma with the
   fixed ordinal residual, and `check_gllvmTMB()` fit-health rows. FAM-14 is
   covered in the validation register. **2026-06-19 ordinal browser slice:**
   system Chrome desktop/mobile screenshots, full-page captures, stale-overclaim
   scan, image/link parser, and mobile layout metrics passed with only expected
   scrollable code/output overflow; EXT/cutpoint depth, ordinal intervals, exact
   ordinal residual diagnostics, and public placement remain open.
7. Leave capstones and validation articles last: coevolution,
   cross-package validation, simulation recovery, and functional biogeography.

## Publication Gate

A navbar/content PR that follows this ledger must record, for each moved page:

- tier and one-sentence justification;
- validation-row IDs and row statuses;
- reader question;
- touched files and examples;
- rendered HTML path inspected;
- exact stale-wording scans;
- Pat/Rose/Grace outcome;
- Florence outcome for figure-heavy pages;
- final navbar diff.

Until then, this ledger is the repo-visible control artifact and does not by
itself promote, demote, or retire any article.
