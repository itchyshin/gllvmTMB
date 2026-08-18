# Response to the second round of reviews

Both reviewers ran **before** merge this time. That ordering is the one
process change this whole arc exists to make.

## Pat — verdict moved from "No" to **"Yes-but"**

Her first review's verdict was *"No — the first thing I would try fails."*
She can now build the data frame, project it, mesh it, fit the two-arm
model, get a presence-only arm off the ground, and draw the map.

### B2 — the most important finding of the arc, and it inverts the headline

The biased-arm design gave itself an accessibility surface that was
**measured exactly** and modelled. Given that, the presence-only arm's
environmental slope is already unbiased, so integrating a fuzzed arm can only
cost — the article measured a cost with no benefit to weigh against it.

Reproduced independently before acting (`evidence-bias-surrogate-error.R`,
12 replicates at `fuzz = 1.0`):

| what the analyst has | precise | integrated | integration **helped** |
|---|---|---|---|
| independent + measured exactly *(the design)* | 0.918 | 0.806 | 3/12 |
| confounded ρ = 0.7, still measured exactly | 0.910 | 0.812 | **0/12** |
| confounded, surrogate error sd 0.5 | 1.192 | 1.083 | **11/12** |
| confounded, not modelled | 1.722 | 1.577 | **12/12** |

The switch is not confounding — it is whether the bias surrogate is exactly
right, and nobody's is. Her own words: *"I read it carefully and still took
the wrong lesson."*

**Fixed** with a new section carrying this table, and with her fair addition:
in the reversal regime *nothing* recovers truth (1.72 vs 1.58 against 0.9).
The ranking flips; both answers are bad.

### B3 — the presence-only section printed a failed recovery as a pass

The estimates are visibly off truth, and the section's own stated diagnostic
— raise quadrature until the estimates stop moving — **green-lights it**.
They do stop moving, at the wrong place.

The cause is upstream: presences are snapped to an `nfine` lattice, which is
positional error, the companion article's own mechanism, injected by the
example. **Fixed**: the relative error is now printed, and the diagnostic is
stated as two checks with the lesson made explicit — *stability is not
accuracy*.

### B1 — the recipe does not survive contact with a raster

`cor_length()` builds a dense n×n matrix: 22,500 cells ≈ 25 s / 4 GB, a
1 km Alberta raster ≈ 8 TB. Worse, the natural workaround
(`terra::aggregate()`) inflates `phi_hat` monotonically (0.128 → 0.176 at
×6) — shrinking the risk ratio, the **unsafe** direction, opposite to the
downward bias the article promises.

**Fixed**: `n_sub` subsampling added to the function (500–2,000 cells
reproduce the full answer to ±0.007), with an explicit warning not to
coarsen.

### B4 — `d = 1` used six times, never justified

**Fixed**: a section explaining that `d` is the rank of the shared spatial
structure, why 1 is the right default, and how to choose it with more
species.

### N1, N2 — both fixed

`vignette("isdm-spatial-precision")` cannot resolve, because
`vignettes/articles` is `.Rbuildignore`d — verified. Replaced with a
description that says so. And the rescaling prose claimed the two species
move in opposite directions while its own output showed both moving down;
now stated correctly, with the point that a disagreement between species is
**not** a reliable tell.

## Florence — three "fix first", all addressed

She found a **false claim in the prose**: *"At `fuzz = 0` every design and
every arm sits within 0.02 of 0.9."* The fuzzed arm at 400/100 is **0.9662**
— verified, 0.066 off, and visibly the high triangle in that panel. Now
named rather than rounded away.

Also fixed: six replicate points clipped while both captions said "all"
(`ylim` now contains its own data); a caption saying 45 when the file has
135; the map's fence sitting on the **last pixel row** of the canvas;
"grow only the fuzzed arm" contradicted by the panel titles; panel order
reordered so the dose-response reads monotonically; the truth line now
dashed and labelled, since it was indistinguishable from the `precise`
series in greyscale; both fallback banners repositioned; "open circles" →
"white circles"; alt text corrected on the fence position and on the two
panels sharing one overlay.

**She confirmed the greyscale fix worked** — the hatched hull mask reads as
texture, not tone, at both ends of the ramp and under deuteranopia and
protanopia. She also verified 27 arm means, the dose-response, the midpoint
table, the colour bar to within 1 px, and equal aspect at 1.697 px/km in
both directions.

## One of my own fixes was wrong, and the render caught it

The `d = 1` section's loadings chunk read a parameter name that does not
exist (`lambda_spde`), returned `named numeric(0)`, and the prose after it
asserted the two loadings differ — **a claim with no evidence shown, which is
exactly the failure this whole arc is about**. The real name is
`theta_rr_spde_lv`. Corrected, and the prose rewritten to tell the reader
what to look for rather than to assert a result.

## What remains open

- Pat's **unchanged friction**: eleven `dev/isdm-precision/*` references
  against one working hyperlink; `isdm_sources()` column/level naming
  unstated (self-rescuing — the error message is good); `species:
  placeholder` unexplained; no route to map uncertainty.
- Her **N4**: mild over-correction — the midpoint rebuttal now precedes the
  correlation-length recipe, which sits late in the article.
- Florence's **polish** tier: map right margin, duplicated point overlay,
  the white strip inside the map frame.
- The `n_sub` default and the `terra::aggregate()` figures come from Pat's
  measurements, reported as hers; I did not re-run them.
