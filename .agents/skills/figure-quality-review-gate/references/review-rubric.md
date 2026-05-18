# Figure quality review rubric

Score each category 0, 1, or 2.

- 0 = unacceptable; blocks publication quality.
- 1 = acceptable but needs revision.
- 2 = publication-ready.

A figure needs no 0s and a total of at least 16/20 to pass.

## 1. Scientific message

- 0: The viewer cannot tell what comparison or result matters.
- 1: Message is inferable but not visually prioritized.
- 2: Message is apparent within seconds.

## 2. Geometry and estimand match

- 0: Wrong geometry or misleading display.
- 1: Mostly appropriate but not optimal.
- 2: Geometry precisely matches the data and estimand.

## 3. Uncertainty

- 0: Intervals are fake, unsupported, hidden, or misleading.
- 1: Intervals are present but not clearly explained or styled.
- 2: Interval encoding is honest, clear, and documented.

## 4. Scales and reference structure

- 0: Scales mislead or obscure results.
- 1: Scales are adequate but could be improved.
- 2: Scales, ticks, limits, and reference lines support interpretation.

## 5. Labels and typography

- 0: Labels are unreadable, raw, or absent.
- 1: Labels are readable but not polished.
- 2: Labels are concise, scientific, and manuscript-readable.

## 6. Facets and layout

- 0: Facets create empty, cramped, or misleading panels.
- 1: Facets are usable but not ideal.
- 2: Layout makes comparisons easier.

## 7. Color and accessibility

- 0: Color is inaccessible or arbitrary.
- 1: Color is usable but not robust to print or color vision differences.
- 2: Color is restrained, consistent, and redundant with other encodings where needed.

## 8. Visual hierarchy

- 0: Backgrounds, grids, legends, or decorations dominate.
- 1: Hierarchy is acceptable but not elegant.
- 2: Data and scientific comparison dominate.

## 9. Export readiness

- 0: Figure clips, blurs, or fails at manuscript dimensions.
- 1: Export likely works but has not been checked.
- 2: Vector or high-DPI export is verified and legible.

## 10. Package integration

- 0: Figure is a one-off or has side effects.
- 1: Function returns a plot but lacks tests or docs.
- 2: Function is documented, tested, returns ggplot, and fits package conventions.

## Frequent reasons to fail a figure

- Unmodified ggplot2 default appearance.
- Mostly empty facets or one-observation panels that obscure comparison.
- Shared y-axis across incompatible parameters.
- Missing zero reference line for correlations or signed effects.
- Non-finite intervals silently removed without preserving point estimates.
- Long raw parameter labels displayed without wrapping or interpretation.
- Legend duplicates facet variable or axis labels.
- Exported figure is not legible at single-column or double-column width.
