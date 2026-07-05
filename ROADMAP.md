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

The visible learning path is intentionally curated. Restored pages return only
when their examples, validation rows, and scope boundaries are synchronized
with the live package.

| Group | Article | Purpose | Status |
|---|---|---|---|
| Model Guides | `articles/morphometrics` | First complete Gaussian worked example. | Visible; final rendered figure/prose audit passed. |
| Model Guides | `articles/model-selection-latent-rank` | Choosing candidate latent rank with AIC/BIC beside diagnostics. | Visible after 2026-06-09 model-selection slice; Gaussian ordinary-`latent()` teaching fixture only, not universal rank-selection calibration. |
| Model Guides | `articles/joint-sdm` | Binary JSDM worked example. | Visible; binary caveats and diagnostics remain under active audit. |
| Model Guides | `articles/lambda-constraint` | Confirmatory loading constraints for binary species distributions. | Visible loading-constraint guide; keep binary scope and interval caveats explicit. |
| Model Guides | `articles/lambda-constraint-suggest` | Data-driven loading-constraint suggestion companion. | Visible technical companion; zero-pin and profile-retention diagnostics stay explicit. |
| Model Guides | `articles/missing-data` | Missing response and scoped missing-predictor workflows. | Visible; engine naming and predictor scope stay bounded by MIS rows. |
| Concepts | `articles/gllvm-vocabulary` | Plain-English glossary for package terms. | Visible after 2026-06-22 article-accessibility slice. |
| Concepts | `articles/covariance-correlation` | Explain `Sigma`, correlations, `Lambda`, `psi`, communality. | Visible; final rendered figure/prose audit passed. |
| Concepts | `articles/api-keyword-grid` | Formula keyword syntax map. | Visible; technical reference closeout passed. |
| Concepts | `articles/response-families` | Supported families and validation status. | Visible; technical reference closeout passed. |
| Diagnostics & Validation | `articles/fit-diagnostics` | First post-fit triage before interpreting fitted models. | Visible after 2026-06-09 diagnostics-article slice; diagnostic-only claims tied to DIA-08 / DIA-10 / DIA-11 / DIA-12 / DIA-13. |
| Diagnostics & Validation | `articles/convergence-start-values` | Hard-fit survival guide. | Visible; final wording audit passed. |
| Diagnostics & Validation | `articles/profile-likelihood-ci` | Profile / bootstrap / Wald interval mechanics and caveats. | Visible Tier 2 reference after the 2026-06-18 methods-reference placement slice; must continue to distinguish API coverage from calibrated coverage. |
| Diagnostics & Validation | `articles/troubleshooting-profile` | Profile-interval failure modes and remedies. | Visible Tier 2 companion reference after the 2026-06-18 methods-reference placement slice. |
| Diagnostics & Validation | `articles/gllvm-vocabulary` | Plain-English terminology glossary for public articles. | Visible Tier 2 glossary after the 2026-06-18 entry-path placement slice; hidden worked-example links removed. |
| Diagnostics & Validation | `articles/pitfalls` | Common mistakes and fixes. | Visible; final prose audit passed. |
| Diagnostics & Validation | `articles/missing-data` | Missing response and scoped missing-predictor workflows. | Visible; engine naming and predictor scope stay bounded by MIS rows. |

Hidden pages remain on disk. They must not be routed from the landing
page or visible articles as recommended next steps until their return
conditions pass.

## Active Reset Slices

| Slice | Work | Owner lenses | Done when |
|---|---|---|---|
| 1 | Roadmap archive and new dashboard | Ada, Rose, Grace | Old roadmap archived; this dashboard renders through `articles/roadmap`. |
| 2 | Curated pkgdown nav | Ada, Grace, Rose | `_pkgdown.yml` shows Model Guides / Concepts / Diagnostics & Validation / Developer Notes; Roadmap stays top-nav for readers and appears only under Developer validation notes for pkgdown index completeness; under-audit pages are labelled as developer notes rather than first-stop tutorials. |
| 3 | Landing page cleanup | Pat, Darwin, Rose | First screen routes to the curated public path and does not advertise hidden pages as ready. |
| 4 | Get Started cleanup | Pat, Boole, Grace | Beginner path shows long and wide fits early without a page-long DGP block. |
| 5 | Public article safety fixes | Rose, Boole, Fisher | Public articles use `trait = "trait"` in long fits, stable `Psi/psi` notation, and no hidden-page next-step links. |
| 6 | Morphometrics HTML review | Pat, Darwin, Florence, Fisher | Done: rendered HTML, truth-vs-fit language, and current figures passed `docs/dev-log/audits/2026-05-24-morphometrics-final-figure-prose-review.md`. |
| 7 | Example-data contract | Emmy, Curie, Noether | Done: `docs/design/52-example-object-contract.md` and `tests/testthat/test-example-morphometrics.R`. |
| 8 | Morphometrics example object | Curie, Pat, Fisher | Done: `inst/extdata/examples/morphometrics-example.rds`; Get Started and Morphometrics use it; long/wide equivalence is tested. |
| 9 | Covariance edge-case example object | Curie, Fisher, Pat | Done: `inst/extdata/examples/covariance-edge-cases-example.rds` backs the covariance and pitfalls pages; `tests/testthat/test-example-covariance-edge-cases.R` covers the object contract. |
| 10 | Extraction/plotting contracts | Emmy, Fisher, Florence, Pat | Done: `docs/design/53-report-ready-extractor-plot-contract.md` specifies row-first extractor tables and plot metadata/data attributes. |
| 11 | Reference index cleanup | Rose, Grace, Pat | Done: `_pkgdown.yml` separates first-line APIs, helpers, diagnostics, validation utilities, and loadings; compatibility/internal topics are hidden from the visible index where appropriate. |
| 12 | Symbol-to-syntax alignment blocks | Boole, Noether, Pat | Done: visible conceptual pages pair covariance symbols with R syntax, extractors, and plain-language interpretation. |
| 13 | Florence-grade plot polish | Florence, Fisher, Darwin, Pat | Partial: helper metadata, colour-safe palettes, confidence-eye displays, matrix correlation layouts, and visual snapshots exist; full rendered article-figure review remains open. |
| 14 | Visible article closeout sequence | Ada, Pat, Fisher, Florence, Rose | Done for the original reset surface: `morphometrics` and `covariance-correlation` have final rendered figure/prose audits; `pitfalls` has final prose audit; `convergence-start-values` has final wording audit; `response-families` and `api-keyword-grid` have technical reference scope audits. Restored pages need their own status-sync and rendered checks. |
| 15 | Codex / Claude Code work sharing | Ada, Shannon, Rose | In progress: keep one active PR, record handoffs in repo files, and split work by non-overlapping lanes before opening parallel edits. |
| 16 | Latent-rank model selection | Ada, Curie, Fisher, Pat, Boole, Rose, Grace | In progress: public article uses a shipped Gaussian rank fixture, shows long and wide calls, compares AIC/BIC beside `check_gllvmTMB()` rows, and records rendered checks without claiming universal rank-selection calibration. |

Launch-audit checkpoint, 2026-05-21: Slices 1-5 and 7-8 passed the
initial public-site launch gate. The original launch pages, Get Started,
article index, and Roadmap rendered locally; no visible page inspected in the
browser linked to hidden immature articles. Slice 6 passed launch-level HTML review, but
publication-grade figure interpretation still needs Florence review as each
model guide becomes final.

Symbol-to-syntax checkpoint, 2026-05-21: Slice 12 first pass added explicit
alignment blocks to the math-heavy visible pages
`covariance-correlation`, `api-keyword-grid`, and
`convergence-start-values`. These blocks pair each displayed covariance
symbol with the R formula/extractor and a plain-language interpretation.
`morphometrics` already carries paired long/wide formulas and recovery
equations; `pitfalls` now has a final prose closeout; and
`response-families` / `api-keyword-grid` have technical reference scope
closeouts, with covered/partial/blocked labels tied to validation-register
rows.

Surface-reconciliation checkpoint, 2026-05-24: merged helper work now covers
the first report-ready Sigma/correlation table and plot surface. The validation
register records `extract_Sigma_table()` (EXT-18), row-first covariance and
correlation plots (EXT-19), bootstrap-derived table rows and plot overlays
(EXT-20..EXT-24), estimate-vs-truth table and plot helpers (EXT-25..EXT-26),
matrix-style Sigma/correlation displays (EXT-27 and EXT-30), and rotated
loading table/plot helpers (EXT-28..EXT-29). These are infrastructure claims,
not final publication-grade figure claims.

Morphometrics closeout checkpoint, 2026-05-24: the current rendered
Morphometrics article passed the final figure/prose closeout recorded in
`docs/dev-log/audits/2026-05-24-morphometrics-final-figure-prose-review.md`.
This closes the Morphometrics page only; the other visible articles still need
their own final rendered passes.

Covariance/correlation closeout checkpoint, 2026-05-24: the current rendered
covariance/correlation article passed the final figure/prose closeout recorded
in
`docs/dev-log/audits/2026-05-24-covariance-correlation-final-figure-prose-review.md`.
The key boundary is that matrix displays show extractor-supplied rows and
interval columns; they do not create or calibrate new uncertainty evidence.

Technical reference closeout checkpoint, 2026-05-24: `response-families` and
`api-keyword-grid` passed the bounded technical reference scope review recorded
in
`docs/dev-log/audits/2026-05-24-technical-reference-final-scope-review.md`.
They remain Tier-2 lookup pages, not worked examples; their status labels map
to validation-register rows and they do not advertise hidden worked examples
as ready.

Identifiability diagnostics checkpoint, 2026-05-24: #248 is implemented in the
existing `check_gllvmTMB()` machine-readable table rather than as a parallel
diagnostic API. DIA-08 now includes Hessian rank, rotation-convention,
weak-axis, near-zero `psi`, `sigma_eps` boundary, and cross-loading structure
rows for fitted latent-variable models. These rows are warnings and routing
signals; rank confirmation still belongs to `check_identifiability()` and the
M3 validation grid.

Coordination checkpoint, 2026-05-24: Codex and Claude Code can share the
remaining reset work, but only through explicit lanes. Codex owns the live
roadmap, check-log, PR pacing, and cross-file consistency gates. Claude Code is
best used for bounded implementation or prose slices that can be reviewed as a
single PR: one visible article wording pass, one diagnostic helper, one test
fixture, or one hidden-article restoration prep at a time. Before either agent
edits shared coordination files (`ROADMAP.md`, `docs/dev-log/check-log.md`,
after-task reports, `docs/design/`, `AGENTS.md`, `CLAUDE.md`, or
`_pkgdown.yml`), run the pre-edit lane check from `AGENTS.md` and leave the
handoff in a PR comment, check-log entry, or after-task report rather than in
chat alone.

Article-order correction checkpoint, 2026-05-26: broad public article
expansion paused until the binary loading-constraint lane is coherent. The
exception is evidence-led restoration where the capability grid is already
covered and the public wording is synchronized. The 2026-06-08 random-slope
work stayed internal after reader review: ordinary Gaussian reaction norms and
structured slope grids remain buildable drafts, not first-click teaching pages.
The 2026-06-09 model-selection article is a narrow Gaussian `latent() +
unique()` restoration because it uses a tested fixture, long and wide calls,
and diagnostics-first AIC/BIC wording. No public promotion of
`mixed-family-extractors`, `psychometrics-irt`, or `lambda-constraint` until
the binary lambda/JSDM article plan lands. Keep mixed-family response teaching
separate from loading-constraint teaching.

Lambda surface cleanup checkpoint, 2026-06-18: `lambda-constraint` and
`lambda-constraint-suggest` remain buildable but moved out of the public
Articles dropdown and into the internal article bucket. The public
`joint-sdm` article no longer routes readers to those hidden pages as
recommended next steps. The next lambda action remains the binary JSDM
article plan and rendered review, not a capability promotion.

After these infrastructure slices, resume article restoration one page at a time.

## Next Shared Work Queue

Use this queue when deciding what Codex or Claude Code should pick up next.
Keep each item to one branch and one pull request.

| Order | Lane | Good owner | Stop condition |
|---|---|---|---|
| 1 | Latent-rank model-selection article | Codex + Curie/Fisher/Pat/Boole/Rose/Grace | `model-selection-latent-rank` is public, uses a tested Gaussian fixture, shows long and wide calls, compares AIC/BIC after fit-health checks, renders its figures, and records the rendered checks. |
| 2 | Binary lambda/JSDM article plan | Codex or Claude Code + Boole/Fisher/Florence/Rose | Rewrite `lambda-constraint` as the first binary loading-constraint teaching article, using a binary species/JSDM-style example rather than mixed psychometrics. Keep the article internal until the plan, example, figure contract, and rendered HTML review are recorded. |
| 3 | Hidden article restoration, one page at a time | Codex or Claude Code + Pat/Rose/Fisher | Only after the article has an example object, long + wide calls where meaningful, validation rows, diagnostic table, figure review, and rendered HTML review. Do not combine mixed-family responses with loading constraints in one teaching article. |

If two agents are active, prefer one public-documentation lane and one
implementation/test lane. Do not let both agents edit the roadmap, check-log,
same article, or same design document in parallel.

## Cross-Agent Rules

- One active PR should touch the public surface at a time unless the
  branches are demonstrably disjoint.
- Shared coordination files need the `AGENTS.md` pre-edit lane check before
  edits and a repo-visible handoff after edits.
- Claude Code should not infer ownership from chat alone; the current lane
  should be named in a PR comment, check-log entry, or after-task report.
- If a branch changes formula grammar, likelihoods, exported APIs, generated
  Rd, `_pkgdown.yml`, or validation-debt status, stop and widen the reviewer
  set before continuing.

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
| Diagnostics and uncertainty | Stabilise `pdHess`, profile, bootstrap, fitted-model predictive checks, residual diagnostics, and simulation-grid language. | `fit-diagnostics` teaches the exported diagnostic surface while keeping claims diagnostic-only, not interval calibration or Bayesian posterior prediction. |
| Article restoration | Bring hidden articles back one at a time. | Each restored article has examples or exact syntax chunks, long/wide status where meaningful, validation rows, figure/prose review, and rendered checks. Binary lambda/JSDM planning still comes before mixed-family or psychometrics promotion. |
| Pre-CRAN | Audit public API, examples, docs, pkgdown, reverse dependencies, and CRAN notes. | Local checks and 3-OS CI are clean; validation-debt register is current. |
| Publication-quality claims | Support strong methodological claims with target-explicit simulation and external comparators. | M3 inference gates and Phase 5.5 comparator evidence pass. |

## Article Gate Matrix

The controlling gate table is:

`docs/dev-log/audits/2026-05-20-article-gate-matrix.md`

Each article row records reader, public status, required functions,
validation-debt rows, long/wide status, truth or comparator, figure gate,
reviewer signoff, and the exact return condition for the public navbar.

The current article-council ledger is:

`docs/dev-log/audits/2026-06-18-article-council-ledger.md`

This ledger extends the gate matrix to the whole article estate. It records
each on-disk article's current navigation status, proposed tier, action,
capability rows, blockers, reviewers, exact next edit, and render/check
command. The ledger is the required first step before any future navbar move,
article merge, article split, demotion to technical reference, or retirement
from navigation. It does not itself promote or hide any page.

## Infrastructure Gates

Public examples should consume infrastructure rather than forcing readers
to reverse-engineer it from long setup chunks.

| Gate | Required capability | First target |
|---|---|---|
| Example data | Reproducible prepared objects with long data, wide data, truth, estimands, formulas, fit arguments, story, and alignment table. | `morphometrics-example.rds`; `covariance-edge-cases-example.rds` |
| Simulation helpers | Internal scenario generators with stable seeds and named estimands. | Morphometrics, covariance edge cases, behavioural syndrome. |
| Extraction tables | Report-ready covariance, correlation, communality, repeatability, phylogenetic signal, ordination, diagnostics, and uncertainty tables. | Contract in `docs/design/53-report-ready-extractor-plot-contract.md`; `extract_Sigma_table()`, `compare_Sigma_table()`, rotated-loading tables, `diagnostic_table()`, and bootstrap-backed Sigma/correlation/communality/repeatability rows are covered where the validation register says so. |
| Plot helpers | Data-first plots that consume extractor tables and expose audit metadata. | `plot.gllvmTMB_multi()` and exported plot helpers attach `gllvmTMB_meta` and `gllvmTMB_data`; confidence-eye, matrix heatmap/ellipse, Sigma comparison, communality, integration, ordination, and rotated-loading displays have object or snapshot tests. Dominant-axis forests, score distributions, diagnostic plots, and rendered Florence review remain pending before publication-grade claims. |
| Diagnostics | `check_gllvmTMB()` first; `pdHess = FALSE` treated as an uncertainty warning, not automatic model death; fitted-response checks use `predictive_check()` / `residuals()` within DIA-11 / DIA-12 scope and `diagnostic_table()` within DIA-13 scope. | `fit-diagnostics`, public methods pages, and Get Started. |
| Profile/bootstrap uncertainty | Explicit fallback language and worker-level diagnostics before claims. | `profile-likelihood-ci` is visible as a guarded methods page; keep its prose clear that API coverage and fallback mechanics are not calibrated coverage evidence. |
| Validation evidence | Every public claim cites a validation-debt row as `covered`, `partial`, or `blocked`. | Current visible article set. |

## Restoration Queue

| Hidden article | Return condition |
|---|---|
| `random-regression-reaction-norms` | Buildable internal draft after #466. The article now uses a shipped behavioural-syndrome example object with `individual` as unit and `session_id` as repeated occasion, long and wide formulas, diagnostics, augmented-covariance recovery, and repeatability curves, but it stays hidden until the reader path is plain-language and fully reviewed. |
| `random-slopes-nongaussian` | Buildable internal structured-slope workflow. Keep hidden until the phylogenetic GLLVM / structured-dependence reader path is ready; do not present it as an interval-calibration article. |
| `behavioural-syndromes` | Internal Tier 3 candidate Tier 1 after the 2026-06-18 article-council gate. Needs runnable long + wide where meaningful; between/within covariance; repeatability; truth recovery; diagnostic table; Florence figure review; rendered HTML review before public article prose expansion. |
| `mixed-family-extractors` | Keep internal until the broader mixed-response teaching story covers Gaussian, binomial, Poisson/NB, beta/proportion, and the route-only delta/hurdle cases (designed, convergence-gated — MIX-10) with report-ready extractor tables. This is not the loading-constraint lane. |
| `animal-model` | Larger pedigree fixture; A/Ainv truth; genetic covariance recovery. |
| `phylogenetic-gllvm` | Phylo helper; phylo versus non-phylo split; validation rows. |
| `psychometrics-irt` | Preview/internal until after the binary lambda/JSDM article is coherent and the `mirt` comparator path is explicitly designed. The current page is not the final IRT article. |
| `lambda-constraint` | First rework target for binary loading constraints: binary species/JSDM-style example, separate from mixed-family response teaching, with interval-aware matrix figures via `plot_correlations(..., style = "heatmap", matrix_layout = "estimate_ci")` whenever CI columns are displayed. |
| `simulation-recovery-validated` | M3 target-explicit statistical gate passes. |
| `cross-package-validation` | Phase 5.5 comparator evidence exists. |
| `functional-biogeography` | Final capstone; component helpers and M3 evidence complete. |

Blocked articles have no navbar entry, no README routing, and no
recommended-next-step link from visible pages. Partial articles may return
only as clearly labelled technical notes after HTML review.

## Finish-Line Criteria

Phase 1 can close only when:

- the landing page and Get Started are coherent;
- the public article set passes rendered HTML review;
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
- DIA-11 / DIA-12 / DIA-13 diagnostics are exported; keep public prose
  diagnostic-only and do not describe these displays as interval calibration,
  formal residual tests, latent-rank proof, or Bayesian posterior prediction.
- Every meaningful slice updates `docs/dev-log/check-log.md`, writes an
  after-task report, updates this roadmap when status changes, and comments
  on #230.
- Every Tier-1 worked example shows long and wide formulas side by side
  unless the article explicitly records why the wide form is not applicable.
- Every figure-heavy article gets Florence review on rendered figures.
- Articles that teach full covariance decomposition, communality, or
  `Sigma = shared + unique` use `latent + unique`; a latent-only formula must
  say it is latent-only and must not imply a free unique component.
- Correlation matrices that display interval columns use
  `plot_correlations(..., style = "heatmap", matrix_layout = "estimate_ci")`;
  `plot_Sigma_heatmap()` remains point-estimate-only.
