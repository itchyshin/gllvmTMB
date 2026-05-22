# gllvmTMB Live Roadmap

*Reset: 2026-05-20. The previous long roadmap is archived at
`docs/dev-log/roadmap-archive/2026-05-20-pre-reset-roadmap.md`.*

This is the live dashboard for the reset period. It is deliberately
short. The project already has many notes, audits, and draft articles;
the live roadmap should tell contributors what is public, what is gated,
and what must happen next.

The principle for the reset is simple:

> An article becomes public only when the package has the infrastructure
> to make that article useful, honest, and easy to follow.

Visible does not mean publication-ready. It means the page belongs to
the small curated working surface while it passes final rendered-HTML,
reader-path, and validation-row review.

## Current Public Surface

The visible learning path is intentionally small.

| Group | Article | Purpose | Status |
|---|---|---|---|
| Model guide | `articles/morphometrics` | First complete Gaussian worked example. | Visible, under HTML review. |
| Concepts | `articles/covariance-correlation` | Explain `Sigma`, correlations, `Lambda`, `psi`, communality. | Visible, under HTML review. |
| Concepts | `articles/api-keyword-grid` | Formula keyword syntax map. | Visible as technical reference. |
| Concepts | `articles/response-families` | Supported families and validation status. | Visible as technical reference. |
| Methods | `articles/convergence-start-values` | Hard-fit survival guide. | Visible, under wording review. |
| Methods | `articles/pitfalls` | Common mistakes and fixes. | Visible, under HTML review. |

Hidden pages remain on disk. They must not be routed from the landing
page or visible articles as recommended next steps until their return
conditions pass.

## Active Reset Slices

| Slice | Work | Owner lenses | Done when |
|---|---|---|---|
| 1 | Roadmap archive and new dashboard | Ada, Rose, Grace | Old roadmap archived; this dashboard renders through `articles/roadmap`. |
| 2 | Six-article pkgdown nav | Ada, Grace, Rose | `_pkgdown.yml` shows Model guide / Concepts / Methods only; Roadmap stays top-nav only. |
| 3 | Landing page cleanup | Pat, Darwin, Rose | First screen routes to the six-article path and does not advertise hidden pages. |
| 4 | Get Started cleanup | Pat, Boole, Grace | Beginner path shows long and wide fits early without a page-long DGP block. |
| 5 | Public article safety fixes | Rose, Boole, Fisher | Public articles use `trait = "trait"` in long fits, stable `Psi/psi` notation, and no hidden-page next-step links. |
| 6 | Morphometrics HTML review | Pat, Darwin, Florence, Fisher | Rendered HTML is inspected; truth-vs-fit language and figures are acceptable. |
| 7 | Example-data contract | Emmy, Curie, Noether | Done: `docs/design/52-example-object-contract.md` and `tests/testthat/test-example-morphometrics.R`. |
| 8 | Morphometrics example object | Curie, Pat, Fisher | Done: `inst/extdata/examples/morphometrics-example.rds`; Get Started and Morphometrics use it; long/wide equivalence is tested. |
| 9 | Covariance edge-case example object | Curie, Fisher, Pat | Done when `covariance-edge-cases-example.rds` backs the covariance and pitfalls pages, and long/wide equivalence plus `unique()` effect are tested. |
| 10 | Extraction/plotting contracts | Emmy, Fisher, Florence, Pat | Done when report-ready table columns are specified and plot helpers expose metadata/data for article audits. |
| 11 | Reference index cleanup | Rose, Grace, Pat | Done when `_pkgdown.yml` separates first-line APIs from advanced diagnostics, hides deprecated aliases where appropriate, and `pkgdown::check_pkgdown()` passes. |
| 12 | Symbol-to-syntax alignment blocks | Boole, Noether, Pat | Done when public conceptual pages pair each equation with defined symbols, the matching R formula, and a plain-language interpretation. |
| 13 | Florence-grade plot polish | Florence, Fisher, Darwin, Pat | Done when covariance/correlation, ordination, loading, communality, repeatability, and diagnostic plots pass rendered figure review and colour-accessibility checks. |

Launch-audit checkpoint, 2026-05-21: Slices 1-5 and 7-8 have passed the
public-site launch gate. The six visible pages, Get Started, article index,
and Roadmap render locally; no visible page inspected in the browser links to
hidden immature articles. Slice 6 has passed launch-level HTML review, but
publication-grade figure interpretation still needs Florence review as each
model guide becomes final.

Symbol-to-syntax checkpoint, 2026-05-21: Slice 12 first pass added explicit
alignment blocks to the math-heavy visible pages
`covariance-correlation`, `api-keyword-grid`, and
`convergence-start-values`. These blocks pair each displayed covariance
symbol with the R formula/extractor and a plain-language interpretation.
`morphometrics` already carries paired long/wide formulas and recovery
equations; `pitfalls` and `response-families` remain wording-review targets
as their examples are made more systematic.

After these infrastructure slices, resume article restoration one page at a time.

## Long Horizon To Finish

The live roadmap stays short by design, but it must still show the path to the
end. The old roadmap was archived because it mixed ready work, aspirations, and
draft articles too freely. This replacement keeps a compact horizon and expands
only when a stage becomes active.

| Stage | Goal | Main gate before moving on |
|---|---|---|
| Reset public surface | Keep only the small user-first site visible. | Six pages, landing page, Get Started, Reference, and Roadmap agree. |
| Infrastructure first | Provide prepared examples, internal scenario generators, extractor tables, and diagnostics so examples are not long setup scripts. | Example objects and report-ready tables are tested. |
| Symbol and syntax clarity | Reintroduce enough math to teach the model without losing applied users. | Every symbol is defined and paired with R syntax plus interpretation. |
| Florence plot system | Move from functional plots to publication-quality scientific graphics. | Rendered figures are informative, colour-blind friendly, uncertainty-aware, and reviewed in HTML. |
| Diagnostics and uncertainty | Stabilise `pdHess`, profile, bootstrap, and simulation-grid language. | #228 resumes only after diagnostic terms and plot semantics are stable. |
| Article restoration | Bring hidden articles back one at a time. | Each article has its example object, long/wide status, validation rows, figure review, and maintainer HTML review. |
| Pre-CRAN | Audit public API, examples, docs, pkgdown, reverse dependencies, and CRAN notes. | Local checks and 3-OS CI are clean; validation-debt register is current. |
| Publication-quality claims | Support strong methodological claims with target-explicit simulation and external comparators. | M3 inference gates and Phase 5.5 comparator evidence pass. |

## Article Gate Matrix

The controlling gate table is:

`docs/dev-log/audits/2026-05-20-article-gate-matrix.md`

Each article row records reader, public status, required functions,
validation-debt rows, long/wide status, truth or comparator, figure gate,
reviewer signoff, and the exact return condition for the public navbar.

## Infrastructure Gates

Public examples should consume infrastructure rather than forcing readers
to reverse-engineer it from long setup chunks.

| Gate | Required capability | First target |
|---|---|---|
| Example data | Reproducible prepared objects with long data, wide data, truth, estimands, formulas, fit arguments, story, and alignment table. | `morphometrics-example.rds`; `covariance-edge-cases-example.rds` |
| Simulation helpers | Internal scenario generators with stable seeds and named estimands. | Morphometrics, covariance edge cases, behavioural syndrome. |
| Extraction tables | Report-ready covariance, correlation, communality, repeatability, phylogenetic signal, ordination, diagnostics, and uncertainty tables. | Contract in `docs/design/53-report-ready-extractor-plot-contract.md`; first tidy table helper still pending. |
| Plot helpers | Data-first plots that consume extractor tables and expose audit metadata. | `plot.gllvmTMB_multi()` now attaches `gllvmTMB_meta` and `gllvmTMB_data`; current plot helpers are functional but still basic. Figure-3-style `correlation_ellipse`, `communality`, and dimension-aware 1D/2D/3D `ordination` are the starting grammar. Dominant-axis forests, score distributions, interval-aware ellipse borders, richer uncertainty displays, colour-blind palettes, and rendered Florence review are pending before publication-grade claims. |
| Diagnostics | `check_gllvmTMB()` first; `pdHess = FALSE` treated as an uncertainty warning, not automatic model death. | Public methods pages. |
| Profile/bootstrap uncertainty | Explicit fallback language and worker-level diagnostics before claims. | Keep `profile-likelihood-ci` hidden. |
| Validation evidence | Every public claim cites a validation-debt row as `covered`, `partial`, or `blocked`. | Six visible articles. |

## Restoration Queue

| Hidden article | Return condition |
|---|---|
| `joint-sdm` | Joint SDM example object; runnable long + wide; binary validation caveats; diagnostic table; figure review. |
| `profile-likelihood-ci` | Profile/bootstrap status cleaned; fallback/Wald caveats first; no M3 coverage overclaim. |
| `behavioural-syndromes` | Behavioural example object; between/within covariance; repeatability; truth recovery. |
| `mixed-family-extractors` | Mixed-family example object; report-ready extractor tables. |
| `animal-model` | Larger pedigree fixture; A/Ainv truth; genetic covariance recovery. |
| `phylogenetic-gllvm` | Phylo helper; phylo versus non-phylo split; validation rows. |
| `psychometrics-irt` | Binary/IRT helper; constraint validation; comparator evidence. |
| `lambda-constraint` | Confirmatory loading helper and reliability checks. |
| `simulation-recovery-validated` | M3 target-explicit statistical gate passes. |
| `cross-package-validation` | Phase 5.5 comparator evidence exists. |
| `functional-biogeography` | Final capstone; component helpers and M3 evidence complete. |

Blocked articles have no navbar entry, no README routing, and no
recommended-next-step link from visible pages. Partial articles may return
only as clearly labelled technical notes after HTML review.

## Finish-Line Criteria

Phase 1 can close only when:

- the landing page and Get Started are coherent;
- the six visible articles pass rendered HTML review;
- no visible page routes to hidden immature pages;
- the first example object infrastructure exists;
- public claims map to validation-debt rows;
- roadmap, issue #230, check-log, and after-task reports agree.

Pre-CRAN requires a complete public API audit, clean CRAN-style checks,
clean pkgdown, runnable examples, and a current validation-debt register.

Publication-quality claims require M3 target-explicit inference gates,
external validation or Phase 5.5 comparator evidence, and restored
advanced articles only after their gates pass.

## Working Rules During Reset

- #230 owns the reset ledger. Child issues are opened only when work starts.
- #228 stays parked until diagnostic terminology, tables, and plot semantics
  are stable.
- Every meaningful slice updates `docs/dev-log/check-log.md`, writes an
  after-task report, updates this roadmap when status changes, and comments
  on #230.
- Every Tier-1 worked example shows long and wide formulas side by side
  unless the article explicitly records why the wide form is not applicable.
- Every figure-heavy article gets Florence review on rendered figures.
