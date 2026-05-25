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
| Model guide | `articles/morphometrics` | First complete Gaussian worked example. | Visible; final rendered figure/prose audit passed. |
| Concepts | `articles/covariance-correlation` | Explain `Sigma`, correlations, `Lambda`, `psi`, communality. | Visible; final rendered figure/prose audit passed. |
| Concepts | `articles/api-keyword-grid` | Formula keyword syntax map. | Visible as technical reference. |
| Concepts | `articles/response-families` | Supported families and validation status. | Visible as technical reference. |
| Methods | `articles/convergence-start-values` | Hard-fit survival guide. | Visible; final wording audit passed. |
| Methods | `articles/pitfalls` | Common mistakes and fixes. | Visible; final prose audit passed. |

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
| 6 | Morphometrics HTML review | Pat, Darwin, Florence, Fisher | Done: rendered HTML, truth-vs-fit language, and current figures passed `docs/dev-log/audits/2026-05-24-morphometrics-final-figure-prose-review.md`. |
| 7 | Example-data contract | Emmy, Curie, Noether | Done: `docs/design/52-example-object-contract.md` and `tests/testthat/test-example-morphometrics.R`. |
| 8 | Morphometrics example object | Curie, Pat, Fisher | Done: `inst/extdata/examples/morphometrics-example.rds`; Get Started and Morphometrics use it; long/wide equivalence is tested. |
| 9 | Covariance edge-case example object | Curie, Fisher, Pat | Done: `inst/extdata/examples/covariance-edge-cases-example.rds` backs the covariance and pitfalls pages; `tests/testthat/test-example-covariance-edge-cases.R` covers the object contract. |
| 10 | Extraction/plotting contracts | Emmy, Fisher, Florence, Pat | Done: `docs/design/53-report-ready-extractor-plot-contract.md` specifies row-first extractor tables and plot metadata/data attributes. |
| 11 | Reference index cleanup | Rose, Grace, Pat | Done: `_pkgdown.yml` separates first-line APIs, helpers, diagnostics, validation utilities, and loadings; compatibility/internal topics are hidden from the visible index where appropriate. |
| 12 | Symbol-to-syntax alignment blocks | Boole, Noether, Pat | Done: visible conceptual pages pair covariance symbols with R syntax, extractors, and plain-language interpretation. |
| 13 | Florence-grade plot polish | Florence, Fisher, Darwin, Pat | Partial: helper metadata, colour-safe palettes, confidence-eye displays, matrix correlation layouts, and visual snapshots exist; full rendered article-figure review remains open. |
| 14 | Visible article closeout sequence | Ada, Pat, Fisher, Florence, Rose | In progress: `morphometrics` and `covariance-correlation` have final rendered figure/prose audits; `pitfalls` has final prose audit; `convergence-start-values` has final wording audit; `response-families` and `api-keyword-grid` still need bounded closeout passes. |
| 15 | Codex / Claude Code work sharing | Ada, Shannon, Rose | In progress: keep one active PR, record handoffs in repo files, and split work by non-overlapping lanes before opening parallel edits. |

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
equations; `pitfalls` now has a final prose closeout, while
`response-families` remains a wording-review target as its examples are
made more systematic.

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

After these infrastructure slices, resume article restoration one page at a time.

## Next Shared Work Queue

Use this queue when deciding what Codex or Claude Code should pick up next.
Keep each item to one branch and one pull request.

| Order | Lane | Good owner | Stop condition |
|---|---|---|---|
| 1 | Technical reference closeout for `response-families` and `api-keyword-grid` | Claude Code + Rose/Boole | Scope labels match validation rows and no hidden worked examples are advertised as ready. |
| 2 | #248 identifiability diagnostics | Codex or Claude Code + Fisher/Emmy | Programmatic diagnostics are designed before user-facing claims or plots expand. |
| 3 | #228 predictive diagnostics | Codex + Fisher/Grace | Starts only after diagnostic wording and plot semantics are stable on the public methods pages. |

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
| Extraction tables | Report-ready covariance, correlation, communality, repeatability, phylogenetic signal, ordination, diagnostics, and uncertainty tables. | Contract in `docs/design/53-report-ready-extractor-plot-contract.md`; `extract_Sigma_table()`, `compare_Sigma_table()`, rotated-loading tables, and bootstrap-backed Sigma/correlation/communality/repeatability rows are covered where the validation register says so. Diagnostics tables beyond current fit-health rows remain next work. |
| Plot helpers | Data-first plots that consume extractor tables and expose audit metadata. | `plot.gllvmTMB_multi()` and exported plot helpers attach `gllvmTMB_meta` and `gllvmTMB_data`; confidence-eye, matrix heatmap/ellipse, Sigma comparison, communality, integration, ordination, and rotated-loading displays have object or snapshot tests. Dominant-axis forests, score distributions, diagnostic plots, and rendered Florence review remain pending before publication-grade claims. |
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
