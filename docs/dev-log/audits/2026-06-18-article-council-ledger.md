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
| `lambda-constraint` | Internal drafts and technical notes | Candidate Tier 1, not yet safe | Keep internal until rewrite/review passes | LAM-02..LAM-04, FAM-02/FAM-03, EXT-14/15 | Article-gate matrix says binary loading-constraint lane must be coherent before promotion; 2026-06-18 cleanup removed public-dropdown visibility | Ada, Boole, Noether, Fisher, Florence, Pat, Rose, Grace | Rework around a binary species/JSDM-style example, then render and inspect before public return | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `lambda-constraint-suggest` | Internal drafts and technical notes | Candidate Tier 2 companion | Keep internal until main lambda article is coherent | LAM-04, EXT-14/15 | Companion should not be public before the main teaching path is stable; 2026-06-18 cleanup moved it with `lambda-constraint` | Boole, Pat, Fisher, Rose, Grace | Reassess as technical companion after the main lambda article passes reader review | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
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
| `animal-model` | Internal drafts | Candidate Tier 1 | Keep internal | ANI rows, FG rows, EXT rows | Needs larger pedigree fixture and A/Ainv truth recovery | Darwin, Noether, Curie, Fisher, Florence, Rose | Design example object and truth table before prose expansion | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `behavioural-syndromes` | Internal drafts | Candidate Tier 1 | Keep internal until evidence path is ready | RE-12, EXT repeatability/communality rows, DIA rows | Needs between/within covariance, repeatability, diagnostics, figures, and rendered review | Pat, Darwin, Fisher, Curie, Florence, Rose, Grace | Build one reader-shaped story from the behavioural example object; do not publish ledger-style prose | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `choose-your-model` | Internal drafts | Candidate Tier 1 navigation guide | Rewrite later | Depends on stabilized public surface | Current public surface and hidden-link targets are still moving | Pat, Rose, Grace, Boole | Rebuild after the public/hidden article list stabilizes | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `cross-lineage-coevolution` | Internal drafts | Tier 3 until COE gates close | Keep internal | COE-01..COE-03, KER rows | Fixed-rho point-estimate only; no intervals or in-engine `rho` | Jason, Noether, Fisher, Florence, Rose | Split C4/C5 and second engine-slot decision before public rewrite | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `cross-package-validation` | Internal drafts | Tier 3 until comparator evidence exists | Keep internal | Phase 5.5 comparator rows | Comparator evidence not complete | Jason, Fisher, Noether, Rose, Grace | Build comparator ledger before article prose | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `data-shape-flowchart` | Internal drafts | Tier 3 routing draft | Keep internal; merge idea into Get Started later only after target examples are public | FG-01..FG-03 | Current draft routes to several hidden example pages; not safe as public navigation | Pat, Boole, Rose | 2026-06-18 slice added Tier 3 YAML and an internal gate note; revisit after biological examples are promoted | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `functional-biogeography` | Internal drafts | Final capstone | Keep internal | Component helper rows plus M3/CI rows | M3 evidence and component helpers not complete; avoid "publication-grade" without proof | Ada, Darwin, Fisher, Florence, Grace, Rose | Leave last; soften claims if touched before capstone gate | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `gllvm-vocabulary` | Articles / Technical reference | Tier 2 glossary | Keep public as compact terminology reference | Cross-cutting FG/FAM/EXT/DIA vocabulary only; no row movement | Hidden worked-example links must stay pruned | Boole, Pat, Rose, Grace | 2026-06-18 slice restored it as Tier 2, added scope wording, and removed hidden-page routing | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `mixed-family-extractors` | Internal drafts | Candidate Tier 2/advanced Tier 1 | Keep internal | MIX rows, EXT rows, FAM delta/hurdle blocked rows | Mixed-response teaching not ready; delta/hurdle cases must stay explicit | Fisher, Emmy, Rose, Pat, Grace | Build broader mixed-response story before public placement | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `ordinal-probit` | Internal drafts with Tier 2 YAML | Candidate Tier 2 | Keep internal until validation/caveats current | FAM-14, EXT cutpoint rows, JUL ordinal bridge exclusions where relevant | Needs ordinal validation and cutpoint caveats synced | Fisher, Noether, Rose, Grace | Re-audit against current FAM-14 status before moving | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `phylogenetic-gllvm` | Internal drafts | Candidate Tier 1 | Keep internal | PHY rows, EXT phylo-signal rows, DIA rows | Needs phylo/non-phylo split and validation-row helper example | Darwin, Noether, Fisher, Florence, Rose | Build reader-shaped phylo example before linking random-slope pages | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `psychometrics-irt` | Internal drafts | Tier 3 preview | Keep internal | LAM rows, FAM-02/FAM-03, comparator rows | Binary lambda/JSDM article and `mirt` comparator path not designed | Noether, Fisher, Pat, Rose | Do not promote until after lambda-constraint rewrite and comparator design | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `random-regression-reaction-norms` | Internal drafts, Tier 3 YAML | Candidate Tier 1 later | Keep Tier 3 | RE-12 partial, CI rows for uncertainty limits | Plain-language reader path not passed; non-Gaussian augmented `unique()` guarded | Pat, Fisher, Rose, Grace, Florence | Rewrite opening and uncertainty caveats before public review | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `random-slopes-nongaussian` | Internal drafts | Candidate Tier 1/Tier 2 later | Keep internal | PHY-11..18, SPA-08..10, ANI-11/12, RE-03, FAM-17, MIX-10, CI rows | Needs phylogenetic/structured-dependence reader path; no CI calibration claims | Pat, Fisher, Rose, Grace, Noether | Keep as structured workflow until phylo GLLVM page is public | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `simulation-recovery-validated` | Internal drafts | Tier 3 until M3 passes | Keep internal | CI-08, CI-10, M3 rows, DIA rows | M3 target-explicit statistical gates not passed | Curie, Fisher, Florence, Grace, Rose | Wait for scoring evidence before public rewrite | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `simulation-verification` | Internal drafts | Tier 3 or future Tier 2 | Keep internal | Test-strategy and M3 rows | Developer-facing unless converted into a compact reference | Curie, Rose, Grace | Decide whether to merge into validation docs rather than public articles | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |
| `stacked-trait-gllvm` | Internal drafts | Tier 3 conceptual draft | Keep internal; superseded by Get Started + Morphometrics for now | FG-01..FG-06 | Duplicates the public entry path and mixes in hidden advanced examples | Pat, Boole, Rose | 2026-06-18 slice added Tier 3 YAML and an internal gate note; mine only compact concept text later if Get Started needs it | `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'` |

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
6. Triage advanced methods: `random-regression-reaction-norms`,
   `random-slopes-nongaussian`, `mixed-family-extractors`, and
   `ordinal-probit`.
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
