# Design 46 — Visualization grammar + Florence figure gate

**Maintained by**: Florence (lead) + Ada (orchestrator).
**Active reviewers**: Pat (applied-user UX), Fisher (uncertainty
fidelity), Darwin (biological framing), Grace (CI / pkgdown
build), Rose (pre-publish + scope honesty).
**Status**: Active — Florence recruitment slice 2026-05-18; current helper
surface refreshed 2026-05-22.
**Mirrors**: drmTMB Design 39 + Florence figure gate (sister-
project pattern, adopted with gllvmTMB-specific adaptations).
**Backed by**: AGENTS.md Standing Review Roles entry for Florence
(added in this PR).

## 1. Why this design doc exists

The package has had `R/plot-gllvmTMB.R` and `R/plot.R` (a 5-type
plot dispatcher) since early versions, plus ggplot2 usage in 7
articles, but **no shared visualization standard**. Recent M3
articles (`simulation-recovery-validated.Rmd`,
`animal-model.Rmd`) ship as tables only — a gap Pat has been
flagging.

The maintainer recruited Florence on 2026-05-18 (parallel to
drmTMB) with a clear charter: own publication-quality figures,
own ggplot helper design, own the gallery / tutorial, defer to
Pat for reader UX and to Fisher for uncertainty fidelity.

This document captures the visualization grammar Florence
operates under + her review gate.

## 2. Visualization scope for gllvmTMB

Visualization touches **three layers**:

| Layer | What | Owner |
|---|---|---|
| **Engine outputs** | `R/plot-gllvmTMB.R` dispatcher (`correlation`, `correlation_ellipse`, `loadings`, `integration`, `communality`, `variance`, `ordination`) | Florence + Emmy |
| **Article figures** | Each Worked Example + Concepts article's inline ggplot chunks | Florence + Pat + Darwin |
| **Gallery / tutorial** | New `visualizing-gllvmTMB.Rmd` (planned) — all plot types side-by-side with rotation caveats + interactive demo | Florence + Pat |

`gllvmTMB`'s multivariate scope makes the plot palette richer
than drmTMB's:

- **G-matrix / Sigma_unit heatmaps** (animal-model, joint-sdm,
  morphometrics articles)
- **Loading biplots** for `latent()` decomposition (with rotation
  disclaimer)
- **Forest plots** for genetic correlations + per-trait
  heritability H^2 + repeatability + communality (with proper
  CI methods: profile / Wald / bootstrap)
- **Profile-shape plots** for `confint_inspect()` and the M3
  empirical coverage outputs
- **Coverage-rate forest plots** (per-cell M3 grid summary)
- **Ordination plots** (Z scores) — d ∈ {1, 2, 3, 3+} aware
- **Variance-decomposition stacked bars** (H^2 + C^2_non + ψ^2)

## 3. Florence Figure Gate

A reader-facing plot passes the gate before it appears in a
tutorial, gallery, or report.

| Gate | Minimum standard for gllvmTMB |
|---|---|
| **Interpretability** | The title, axes, facets, and caption name the biological / latent-variable question, the fitted parameter (Lambda, Sigma_unit, h^2, etc.), the **rotation status** (rotation-invariant target vs rotation-ambiguous direction), and the reporting scale (link / response / standardised). |
| **Uncertainty** | Confidence bands, interval bars, or missing-interval markers match the **CI method** (`fisher-z` / `wald` / `profile` / `bootstrap`) and the plotting `interval_status` (`none` / `provided` / `partial` / `missing` / `boundary` / `failed` / `not_applicable`). Capability status (`covered` / `partial` / `blocked`) belongs in the validation-debt register, not in a figure legend. A plain line is **not** presented as an interval. Boundary-pinned variances are visually marked (one-sided arrow / open glyph), not silently truncated. |
| **Evidence** | The plot's data table is inspectable. Raw observations, prediction grids, the `extract_*()` output, or simulation-recovery RDS files are visible in the surrounding workflow when needed for interpretation. `check_identifiability()` / `gllvmTMB_check_consistency()` outputs appear in companion plots when the fit is at a boundary regime. |
| **Accessibility** | Colour choices are colourblind-friendly (default to viridis or Okabe-Ito); line widths remain legible in print at single-column manuscript width; panels are readable at pkgdown defaults; redundant encodings used when groups matter (colour AND shape). |
| **Composability** | The helper returns an ordinary `ggplot` object. The underlying data table is exposed via `$data` and `attr(., 'gllvmTMB_meta')`. Custom downstream plots (ecology/evolution figures combining multiple extractors) compose naturally. |
| **Rotation honesty** | When loadings `Lambda` are displayed without a constraint, the caption notes "loading sign and rotation are not identifiable; the rotation-invariant target is the implied Sigma". Required for any `loadings`-type plot. |

## 3a. M3 Diagnostic Report Gate

M3 diagnostic figures are not deferred to the later Phase 1c-viz public
plot layer. They are part of the M3.3b surface-admission gate defined
in `docs/design/50-m3-3b-surface-admission.md`.

Before any r50 or r200 M3.3b run, Florence reviews a tiny rendered
diagnostic report. The report must show:

- coverage against the 0.90 pilot threshold and 0.94 promotion gate;
- estimate/truth ratios by trait, with a ratio = 1 reference line;
- fitted NB2 `phi`/truth and fitted link-residual diagnostics when
  NB2 is present;
- fit failures, CI missingness, bootstrap failures, `pdHess`, and
  `sdreport` status;
- target, method, and fit-mode labels on every panel.

The report data must preserve one row per replicate and trait whenever
that grain exists. Failed fits and missing intervals stay visible.
`psi/profile` diagnostics must not be drawn as if they were total
`Sigma_unit_diag/bootstrap` promotion evidence, and known-phi
point-only diagnostics must not be plotted as coverage evidence.

Florence can fail the report if the figure hides weak cells behind
averages, drops denominators, uses default-looking panels, or makes the
main inference decision depend on a caption the reader can miss.

Current dev implementation: `dev/m3-grid.R` builds the report from the
long grid via `m3_source_map_dashboard_data()` and renders a dev-only
PNG contact sheet with `m3_write_source_map_dashboard()`. This is not
an exported plotting API; it is an M3 admission-review artefact.

## 4. Skills powering Florence's work

Four skills installed at `.agents/skills/` (2026-05-18):

| Skill | Used for |
|---|---|
| `scientific-figure-art-director` | High-level design critique; "verdict + redesign brief" pattern |
| `publication-ggplot-engineer` | R/ggplot2 implementation; package theme; CI ribbons |
| `r-plot-helper-package-engineer` | R-package contract for plot helpers; roxygen + tests |
| `figure-quality-review-gate` | Pre-merge audit of plot-touching PRs |

When a PR touches `R/plot*.R`, `vignettes/articles/*.Rmd` with
ggplot, or `man/plot.*.Rd`, Florence is invoked via the
relevant skill(s) as the default lead. Pat / Fisher / Darwin
contribute as reviewers per the figure-gate dimensions above.

## 4a. Florence operating mode upgrade (2026-05-21)

Florence is now the **lead scientific illustrator and ggplot engineer** for
the public visual layer, not only an end-stage reviewer. Plot work starts with
her questions:

1. What scientific comparison should the reader see within a few seconds?
2. What estimand, scale, level, interval method/status, and rotation status are
   visible in the figure or caption?
3. Does the plot use a colourblind-safe palette and redundant encoding where
   groups matter?
4. Does the plotted data remain inspectable through `attr(p, "gllvmTMB_data")`
   and `attr(p, "gllvmTMB_meta")`?
5. What would Pat, Darwin, Fisher, Noether, Grace, and Rose reject before a
   figure-dependent article goes public?

The current helper baseline is deliberately modest:

- signed quantities use a blue-white-vermillion diverging scale;
- grouped summaries use Okabe-Ito-inspired colours plus shapes where possible;
- loadings and ordination captions state rotation/sign ambiguity;
- integration plots carry row-level interval status;
- correlation plots preserve extractor notes so latent-only correlation
  warnings are not hidden behind polished heatmaps.
- covariance/correlation table helpers can draw forest plots and confidence
  eyes; confidence eyes are soft filled compatibility shapes with hollow
  estimate markers, no outer eye outline, optional CI lines via
  `show_intervals = TRUE`, and `style = "raindrop"` retained as a compatibility
  alias.

This is a **safety and accessibility upgrade**, not a publication-ready
stamp. A public article figure still needs rendered HTML review by Florence
and Pat, plus Noether whenever a caption states a `Sigma`, `Lambda`, `Psi`, or
rotation-invariance claim.

## 4b. GLLVM overview Figure 3 plot-suite target (2026-05-21)

The GLLVM overview paper's Figure 3 is the current visual north star for
ordinary multivariate GLLVM summaries. Florence interprets it as four related
outputs, not one monolithic plot:

| Figure 3 panel / user example | gllvmTMB helper target | Current status |
|---|---|---|
| Ordination biplot: scores plus trait loading arrows | `plot(type = "ordination")` | Implemented as dimension-aware static output: 1D score strip, 2D biplot, 3D pair-grid; d > 3 uses selected axes. |
| Loading matrix table | Extractor/table helper, not a plot | Planned; should be a report table because the reader needs exact signs and magnitudes. |
| Correlation ellipse matrix | `plot(type = "correlation_ellipse")` | Implemented for point-estimate correlations and optional `bootstrap_Sigma(..., what = "R")` intervals; borders/stars mark supplied intervals that exclude zero. Still needs rendered-figure QA beyond the current morphometrics fixture. |
| Communality / uniqueness bars | `plot(type = "communality")` | Implemented for point estimates and optional `bootstrap_Sigma(..., what = "communality")` intervals on the `c^2` boundary. Still needs rendered-figure QA and broader interval-calibration examples. |
| Dominant-axis loading forest with bootstrap CIs | Future `plot(type = "dominant_loadings")` or a table-driven helper | Planned; requires bootstrap-aligned loading/axis summaries and rotation/sign convention checks. |
| Score histograms / density panels | Future score-distribution helper | Planned; should consume `extract_ordination()` score tables and avoid over-interpreting latent axes as mechanisms. |
| Integration-index forest with repeatability and communality CIs | `plot(type = "integration")` | Implemented for point estimates and optional bootstrap-object intervals for repeatability and communality. Still needs rendered-figure QA and fuller tutorial use. |

Panel composition for articles should happen at the article/gallery layer. The
S3 plot method should keep returning ordinary ggplot objects with audit
metadata so each panel can be inspected, tested, and rewritten independently.

## 5. Implementation contract for `plot_*()` helpers

Public plot helpers in `R/plot-gllvmTMB.R` and any new helpers:

- Return a `ggplot2::ggplot` object. Never save files (export is
  a separate utility).
- Separate data preparation from rendering; expose the data
  table via `$data` or an attribute.
- Validate required columns; report actionable errors with `cli`.
- Preserve rows without finite intervals as point/line estimates;
  do not invent or hide them. Use `interval_status = "boundary"`
  or `"missing"` markers per the gate.
- Use colourblind-safe defaults; avoid colour as the only group
  encoding.
- Prefer direct labels for small T; legends only when T > 5 or
  when the plot is overdetermined.

## 6. Current visualization debt ledger

The older Phase 1c-viz checklist is no longer 0/7. The current ledger is:

| Target | Current status | Remaining debt |
|---|---|---|
| Missing static dispatcher types | Partial: `correlation_ellipse`, `communality`, `variance`, and dimension-aware `ordination` are implemented. | `phylo_signal`, `residual_split`, and any future dominant-axis helpers remain planned. |
| Repeatability / integration forest | Partial: `plot(type = "integration")` draws repeatability and communality summaries with optional bootstrap-object intervals. | Needs rendered QA, article use, and clearer boundary/failure glyphs. |
| Dimension-aware ordination | Partial: 1D strip, 2D biplot, 3D pair grid, d > 3 selected axes, varimax default, axis ordering, user-supplied sign anchors, standardized loading arrows, and one anchored rotated ordination `vdiffr` snapshot are implemented. | Interactive 3D remains planned; rotation/sign conventions need continued tutorial guidance and broader visual snapshots. |
| Confidence-eye covariance/correlation plots | Partial: `plot_correlations()` and `plot_Sigma_table()` draw interval forests and confidence eyes from finite bounds; one Confidence Eye correlation `vdiffr` snapshot guards the no-outer-line / hollow-point design. | No calibration claim; interval-bearing input remains the user's responsibility; `plot_Sigma_table()` still lacks a visual snapshot. |
| Estimate-vs-truth visuals | Partial: `compare_Sigma_table()` and `plot_Sigma_comparison()` cover row-first table and visual comparison helpers. | Needs simulation/example article integrations beyond object tests. |
| Matrix heatmaps | Partial: `plot_Sigma_heatmap()` covers point-estimate Sigma/R heatmaps. | No uncertainty display and no multi-model layout helper yet. |
| Plot polish | Partial: captions now cover interval provenance, missing intervals, and rotation honesty; confidence eyes omit CI lines by default; first `vdiffr` snapshots guard the two most polished public plot surfaces. | Full rendered HTML review and broader visual snapshots remain open. |
| Gallery article | Planned. | `visualizing-gllvmTMB.Rmd` should wait until the helper surface is stable enough to teach without churn. |
| M3 figure cascade | Planned / dev-only. | M3 diagnostic report helpers remain development artefacts until surface-admission evidence is ready. |

## 7. What's out of scope for this design note

- The full implementation of items 1-8 above (each gets its own
  slice).
- A new theme package (not needed; the publication-ggplot-engineer
  skill defines the package-level theme directly).
- Removing plot helpers from sister-package inheritance
  (`plot_anisotropy*` from sdmTMB stays per CLAUDE.md "Reusing
  sdmTMB / drmTMB Code").

## 8. Cross-references

- AGENTS.md Standing Review Roles: Florence entry (added in this
  PR, line ~353).
- drmTMB Design 39 + Florence figure gate (sister-package
  pattern).
- ROADMAP Phase 1c-viz row (Florence's main owned scope).
- 4 ggplot skills under `.agents/skills/`:
  `scientific-figure-art-director`, `publication-ggplot-engineer`,
  `r-plot-helper-package-engineer`, `figure-quality-review-gate`.
- M3.6 article `simulation-recovery-validated.Rmd` (priority
  first target for Florence's figure cascade).

## 9. Persona contributions to this draft

- **Florence** (lead): figure gate (§3), implementation contract
  (§5), Phase 1c-viz inheritance (§6).
- **Ada** (coordinator): role recruitment + mirroring drmTMB
  Design 39; cross-pollination decision.
- **Pat** (review, applied UX): reader-facing minimum standards
  in §3; pet-peeve about shared/unique/total in §6 #5.
- **Fisher** (review, uncertainty): interval-status integration
  with extractor outputs (§3 Uncertainty row).
- **Darwin** (review, biology framing): biological-question
  requirement on titles/axes/captions in §3 Interpretability.
- **Grace** (review, CI/pkgdown): vdiffr snapshot tests in §6.
- **Rose** (review, scope honesty): §7 "What's out of scope"
  explicitly enumerated.
- **Emmy** (review, API architecture): `$data` exposure +
  `attr(., 'gllvmTMB_meta')` composability pattern in §5.

## 10. Open questions

- **Q-Florence-1**: should the package theme be a published
  function (`theme_gllvmTMB()`) or only internally used? My lean:
  internal-only until Phase 1c-viz #1-#5 are done, then expose.
- **Q-Pat-1**: should the rotation-disclaimer caption be auto-
  appended by every `loadings`-type helper, or opt-out? My lean:
  auto-append with `add_rotation_caption = FALSE` opt-out.
- **Q-Grace-1**: vdiffr snapshot tests bloat the repo (~50 KB per
  test). Cap at one snapshot per plot type, or allow per-DGP?
  My lean: per plot type only; per-DGP is parameter-recovery
  territory, not figure-quality.
- **Q-Fisher-1**: when `extract_*()` returns `interval_source =
  "not_available"` (e.g. profile failed at boundary), should the
  plot show an open-glyph marker, an "interval not computed"
  caption note, or silently omit? My lean: open-glyph plus
  caption note. Silent omission violates the Uncertainty gate.
