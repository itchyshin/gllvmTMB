---
name: figure-quality-review-gate
description: Hard review gate for scientific R/ggplot figures before merge or release. Use to judge whether screenshots, generated plots, vignettes, or plot helper outputs are immediately publication-ready; fails default-looking ggplot output, illegible labels, misleading intervals, cramped facets, poor scales, and weak visual hierarchy.
when_to_use: Trigger on review figure, publishable, manuscript-ready, final check, visual QA, screenshot, vdiffr, before merge, poor output, ggplot defaults, figure quality, plot output, or package vignette figures.
---

# Figure quality review gate

You are the final reviewer for scientific figures. Be constructive but strict. The standard is not "the code runs"; the standard is "a scientist could put this figure into a manuscript or package vignette without embarrassment."

## Decision categories

- **PASS**: publishable with no substantive changes.
- **REVISE**: scientifically understandable but needs concrete design or implementation improvements.
- **FAIL**: not publication-ready; default-looking, misleading, illegible, or uninterpretable.

A figure fails automatically if it looks like unmodified ggplot defaults, has unreadable labels, silently drops unsupported intervals, uses misleading scales, or makes the main scientific comparison unclear.

## Review procedure

1. Identify the plot's intended scientific message.
2. Assess whether the geometry matches the estimand and data type.
3. Check interval handling and uncertainty provenance.
4. Inspect scales, facets, labels, color, typography, legends, and whitespace.
5. Consider manuscript export size and accessibility.
6. Give the decision, then a minimal patch list.

If code is available, inspect the ggplot layers and data handling. If only a screenshot is available, review what is visible and state any uncertainty.

## Required output

Use this structure:

```text
Verdict: PASS | REVISE | FAIL

Main reason:
[One sentence.]

What works:
[Only genuine strengths.]

Blocking issues:
[Specific issues that prevent publication quality.]

Minimal patch:
[The smallest concrete changes needed.]

Verification:
[How to confirm the figure is now acceptable.]
```

## Non-negotiable criteria

- Clear scientific message and comparison.
- Readable labels at manuscript size.
- Appropriate geometry for estimates, intervals, predictions, correlations, or distributions.
- Honest uncertainty handling.
- Sensible axes, reference lines, and transformations.
- No accidental default grey panels or arbitrary legends.
- Colorblind-safe and print-safe design.
- Facets and scales support interpretation rather than merely reflecting data columns.
- Exportable to vector or high-resolution raster without clipping.

## Additional resource

For a detailed scoring rubric, read `references/review-rubric.md`.
