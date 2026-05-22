# Report-Ready Extractor And Plot Contract

**Date:** 2026-05-21
**Status:** active infrastructure contract
**Maintained by:** Emmy, Fisher, Florence, Pat, Grace, Rose
**Related docs:** `06-extractors-contract.md`, `46-visualization-grammar.md`,
`52-example-object-contract.md`

Public articles should not reverse-engineer fitted-object internals. The
reader-facing path is:

```text
example object -> gllvmTMB() fit -> extractor table -> plot helper -> article
```

This document records the table and plot metadata contracts that make that path
auditable. It is deliberately narrower than the full visualization roadmap:
the goal of this slice is stable infrastructure, not final figure polish.

## Extractor Table Contract

Any extractor output used directly in a public article should be report-ready:
one row per estimand, stable column names, explicit uncertainty status, and
enough metadata to trace the row back to a validation-debt entry.

Minimum columns for tidy extractor tables:

| Column | Meaning |
|---|---|
| `term` or `estimand` | Human-readable target, such as `Sigma[length,mass]` or `rho[boldness,activity]`. |
| `trait` / `trait_i` / `trait_j` | Trait identity; pairwise tables use `trait_i` and `trait_j`. |
| `level` | Canonical covariance level: `unit`, `unit_obs`, `cluster`, `phy`, `spatial`, or `Omega`. |
| `component` | `total`, `shared`, `unique`, `link_residual`, or a named variance-share component. |
| `estimate` | Numeric point estimate on the stated scale. |
| `lower`, `upper` | Interval bounds when available; otherwise `NA_real_`. |
| `interval_method` | `none`, `fisher-z`, `wald`, `profile`, `bootstrap`, or another explicit method. |
| `interval_status` | `none`, `provided`, `partial`, `missing`, `boundary`, `failed`, or `not_applicable`. |
| `scale` | `link`, `latent`, `response`, `standardised`, or `correlation`. |
| `validation_row` | Row ID from `docs/design/35-validation-debt-register.md` when the table backs a public claim. |

Matrix extractors such as `extract_Sigma()` may still return matrices for
interactive use. When an article needs comparison, annotation, or plotting, use
or build a tidy table with the columns above rather than indexing internals
inside the article.

## Plot Metadata Contract

Every public `plot.gllvmTMB_multi()` result and exported plot helper now
carries:

```r
attr(p, "gllvmTMB_meta")
```

with fields:

| Field | Meaning |
|---|---|
| `type` | Plot type requested by the user. |
| `source` | Extractor or extractor family used to build the plot. |
| `level` | Canonical covariance level(s) represented in the plot. |
| `interval_status` | Whether the plot includes intervals. |
| `rotation_status` | Whether the plotted target is rotation-invariant or loadings/ordination are rotation-ambiguous. |
| `notes` | Extractor or plotting caveats that must not be lost in article code. |

Plots also carry:

```r
attr(p, "gllvmTMB_data")
```

with the prepared plotting data. For most plots this is identical to
`p$data`. Ordination stores a list with `scores` and `loadings`, because the
top-level `ggplot$data` is empty when the plot is assembled from multiple
layers. This keeps article code from digging through layer internals.

## Current Implemented Metadata

| Plot type | Source | Level | Rotation status | Data exposed |
|---|---|---|---|---|
| `correlation` | `extract_Sigma` | `unit`, `unit_obs`, or one available level | `rotation_invariant` | `p$data`; `attr(p, "gllvmTMB_data")` |
| `correlation_ellipse` | `extract_Sigma` | `unit`, `unit_obs`, or one available level | `rotation_invariant` | `attr(p, "gllvmTMB_data")` |
| `loadings` | `getLoadings` | requested canonical level(s) | `rotation_ambiguous_loadings` | `p$data`; `attr(p, "gllvmTMB_data")` |
| `integration` | `extract_ICC_site + extract_communality` | `unit`, `unit_obs` | `rotation_invariant` | `p$data`; `attr(p, "gllvmTMB_data")` |
| `communality` | `extract_communality` | `unit`, `unit_obs`, or one available level | `rotation_invariant` | `p$data`; `attr(p, "gllvmTMB_data")` |
| `variance` | `extract_proportions` | `unit`, `unit_obs` | `rotation_invariant` | `p$data`; `attr(p, "gllvmTMB_data")` |
| `ordination` | `extract_ordination` | requested canonical level | `rotation_ambiguous_loadings` | `attr(p, "gllvmTMB_data")` |
| `correlations_forest` | `extract_correlations` | requested canonical level(s) | `rotation_invariant` | `attr(p, "gllvmTMB_data")` |
| `correlations_raindrop` | `extract_correlations` | requested canonical level(s) | `rotation_invariant` | `attr(p, "gllvmTMB_data")`; `attr(p, "gllvmTMB_raindrop_data")` |
| `sigma_table_forest` | `extract_Sigma_table` | requested canonical level(s) | `rotation_invariant` | `attr(p, "gllvmTMB_data")` |
| `sigma_table_raindrop` | `extract_Sigma_table` | requested canonical level(s) | `rotation_invariant` | `attr(p, "gllvmTMB_data")`; `attr(p, "gllvmTMB_raindrop_data")` |

The current correlation plot data is built from `extract_Sigma_table()`. It
includes both backwards-compatible plotting columns (`row`, `col`, `value`) and
report-ready columns (`estimand`, `trait_i`, `trait_j`, `estimate`, `level`,
`component`, `matrix`, `triangle`, `interval_method`, `interval_status`,
`scale`, `validation_row`). It also includes visual-support columns
(`display_value`, `label`, `label_colour`) so the diagonal can be muted without
deleting the self-correlation rows. Article chunks should use the report-ready
columns.

The current correlation-ellipse plot data converts the same correlation cells
into ellipse polygons. It preserves `trait_i`, `trait_j`, `estimate`, `level`,
`triangle`, `interval_method`, and `interval_status`, plus visual-support
columns `x`, `y`, `group`, `significant`, and `border_colour`. The
`significant` column is future-compatible with interval-aware correlation
tables; with the current matrix-first `extract_Sigma()` path it remains
`FALSE`.

The exported `plot_correlations()` and `plot_Sigma_table()` helpers are
row-first views over tidy covariance/correlation tables. Their default
`style = "interval"` is a forest plot with points for every estimate and
interval segments only where finite bounds exist. `style = "raindrop"` adds a
frequentist compatibility display reconstructed from finite interval bounds;
correlation rows use Fisher's z scale and covariance rows use the displayed
estimate scale. Rows without finite bounds remain point-only and are drawn as
open points so the missing uncertainty display is visible. For fitted
correlation rows, `extract_correlations(..., method = "bootstrap")` is the
usual next path when bootstrap uncertainty is appropriate. For Sigma-table
rows, the plot helper needs bootstrap-derived or otherwise interval-bearing
rows; `extract_Sigma_table()` itself is still point-estimate infrastructure.
Raindrops omit interval segments by default so the midpoint and compatibility
shape carry the display; callers can set `show_intervals = TRUE` when an
overlaid CI line is genuinely useful. These raindrops are not posterior
densities and should not be captioned as Bayesian credible distributions.

The current integration plot data includes row-level `has_interval`,
`interval_method`, and `interval_status` columns. The plot-level metadata uses
`interval_status = "partial"` when at least one interval is present and at
least one requested interval is missing.

The current communality plot data is point-estimate only. It has two rows per
trait per available latent tier: `Shared latent (c^2)` and
`Trait-specific uniqueness`, with `proportion` summing to 1 within each
trait/tier.

The current ordination data is dimension-aware. One-dimensional fits expose
score-strip data and loading lollipops. Two-dimensional fits expose one score
table and one display-scaled loading table for the requested axis pair.
Three-dimensional fits expose a static pair grid with rows repeated for
`LV1 vs LV2`, `LV1 vs LV3`, and `LV2 vs LV3`; this is deliberately a printable
ggplot representation, not a perspective 3D rendering.

The current visual baseline uses colourblind-safe internal palettes and
rotation/interval captions in the built-in plot types and covariance table
helpers. This metadata and palette work is still not a publication-quality
claim. It is the plumbing Florence and Pat need before figures can be audited
quickly in articles.

## Article Gate

A figure-heavy article should not become public unless:

1. the figure is built from an extractor table or a plot helper with metadata;
2. the caption names the biological question and the estimand;
3. interval provenance is visible when intervals appear;
4. rotation ambiguity is stated when loadings or ordination axes are shown;
5. the rendered HTML has been reviewed by the relevant team roles: Florence
   for visual quality, Fisher for uncertainty, Pat for reader interpretation,
   and Rose for claim consistency.

## Current Limitations

- `extract_Sigma_table()` is point-estimate only. Interval columns are present
  for compatibility, but table-level interval joins still need a separate
  implementation.
- `plot_Sigma_table(style = "raindrop")` can draw raindrops only when supplied
  rows already contain finite interval bounds. It does not compute Sigma
  intervals.
- Plot metadata and first-pass Florence palette/caption safeguards exist, but
  every new article figure still needs rendered HTML review before it is
  treated as publication-grade.
- `plot(type = "variance")` depends on `extract_proportions()` availability and
  remains tied to the current validation status of that extractor.
- No `vdiffr` snapshot tests have been added yet; current tests inspect object
  class, data shape, and metadata only.

## Next Implementation Targets

1. Add figure-ready estimate-vs-truth tables for example objects.
2. Add interval-aware correlation and communality table contracts so ellipse
   borders/stars and communality whiskers reflect real uncertainty rather than
   point estimates.
3. Add dominant-axis loading and score-distribution helpers for the GLLVM
   overview Figure 3 family of plots.
4. Continue the Rose/Florence surface scan for hidden or technical articles
   that still present covariance, correlation, or communality outputs only as
   raw matrices or tables.
