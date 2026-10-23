# FLORENCE-REVIEW.md

> **Delivery note:** this content was to be written to
> `/private/tmp/gllvmtmb-1132/FLORENCE-REVIEW.md`. Plan mode became active before
> that write, and plan mode restricts me to this plan file. The review itself is
> complete — every check below was run. Copy this file to
> `/private/tmp/gllvmtmb-1132/FLORENCE-REVIEW.md` verbatim when execution is allowed.

Reviewer: Florence (independent visual QA). Branch `claude/article-figures`,
worktree `/private/tmp/gllvmtmb-1132`. Figures produced by Tufte.

## Did I actually look?

Yes. Both figures were extracted from the supplied HTML as base64 PNGs, decoded,
and **viewed with the Read tool** at three sizes/renderings each:

- native (`isdm-spatial-precision` 1500x819 = 7.5in @ 200 dpi;
  `isdm-canada-warbler` 1320x1060 = 6.6in @ 200 dpi),
- **reader size** — downsampled to 800 px wide, which is what `out.width = "100%"`
  gives in a pkgdown content column,
- magnified crops of five suspect regions per figure.

I additionally viewed **deuteranopia**, **protanopia** (Machado et al. 2009
severity-1.0 matrices, applied in linear RGB) and **luminance-greyscale**
renderings of both figures. Tufte reported no CVD tooling; I built it, and it
changed one verdict (see should-fix #2).

Working files: `/tmp/florence/`.

---

# VERDICT: **FIX FIRST**

One blocking item. It is not a drawing fault — both figures are, as *drawings*,
the best work in this repo's article set: nothing is clipped, nothing is hidden,
nothing is clamped, and every plotted number I checked is true. The blocking item
is a **caption that states something about the model which the fitted object
contradicts**. A clean figure making a false claim is the failure this role exists
to catch.

---

## Data diff — done first, because a clean wrong figure is worse than an ugly right one

### Figure 1, `isdm-spatial-precision.Rmd` — **every claim verified TRUE**

Source: `dev/isdm-precision/precision-sim-results.rds`, 480 rows, 4 columns
(`fuzz`, `rep`, `arm`, `beta_hat`), balanced 40 per fuzz x arm.

Arm means (computed) vs claimed:

| fuzz | precise_only | fuzzed_only | integrated |
|---|---|---|---|
| 0.00 | 0.894603 (claim 0.895) | 0.910362 (0.910) | 0.902101 (0.902) |
| 0.25 | 0.901524 (0.902) | 0.578519 (0.579) | 0.741392 (0.741) |
| 0.50 | 0.907110 (0.907) | 0.402960 (0.403) | 0.651694 (0.652) |
| 1.00 | 0.902155 (0.902) | 0.216389 (0.216) | 0.545399 (0.545) |

**All twelve match to 3 d.p.** The hard-coded fallback `mu` matrix in the chunk
matches the same twelve values — the degraded path plots the truth too.

Panel B paired difference, `beta_hat.integrated - beta_hat.precise_only`, paired
on (`fuzz`, `rep`):

| fuzz | n below 0 | claimed | mean diff | caption claim |
|---|---|---|---|---|
| 0.00 | **15/40** | 15/40 ✓ | +0.0075 | (straddles zero) ✓ |
| 0.25 | **40/40** | 40/40 ✓ | -0.1601 | -0.16 ✓ |
| 0.50 | **40/40** | 40/40 ✓ | -0.2554 | -0.26 ✓ |
| 1.00 | **40/40** | 40/40 ✓ | -0.3568 | -0.36 ✓ |

Exact ties: **0**, so the prose "helps in 25 of 40 and hurts in 15" at `fuzz = 0`
is exactly right (25 + 15 = 40).

Nothing is clipped out of frame. Data range is `[-0.07139, 0.99502]` against
panel A `ylim = c(-0.10, 1.09)`; panel B range `[-0.5075, +0.0596]` against
`ylim = c(-0.56, 0.32)`. I found the `-0.0714` outlier (fuzz 1.0, rep 40,
`fuzzed_only`) **inside** the panel in the rendered image, as Tufte claimed.
The markdown table underneath, including the attenuation percentages
(-1.2 / 35.7 / 55.2 / 76.0 and -0.2 / 17.6 / 27.6 / 39.4), reproduces from the
unrounded means.

The x-axis is genuinely **linear in fuzz** (measured tick spacing 110 / 110 / 220 px)
— the attenuation curve's shape is not manufactured by a categorical axis. Jitter
and dodge are seeded (`set.seed(1)`, `set.seed(2)`), so the figure is deterministic.

**Figure 1 data verdict: clean. No corrections needed.**

### Figure 2, `isdm-canada-warbler.Rmd` — numbers verified, model claim FALSIFIED

First, a reproducibility trap I fell into and am recording so nobody repeats it.
A plain `Rscript -e 'rmarkdown::render(...)'` produced a **materially different
map** (`range(map$est)` = 0.0517-2.4597, three colour-bar ticks not four, a
different surface) and turned the article's `hull-warning` section into a
**3,600-row data-frame dump** instead of the warning class. Cause: the installed
`gllvmTMB` 0.7.0 (built 2026-08-17 23:56 UTC) predates worktree commits
`23c2169a` (out-of-hull warning) and `10015b36` (`isdm_source` through
`predict()`). Re-rendering with `pkgload::load_all(".")` reproduces the supplied
figure **byte-identically** (md5 `912a10b3833b322c151593a5c455724f`). So the
reviewed figure is correct; the article simply requires a build of this branch.
Flagged as should-fix #5, not as a figure fault.

Against the correct build:

| claim | source | measured | verdict |
|---|---|---|---|
| "nine grid cells" outside hull | caption | `sum(oo)` = **9 of 900** | ✓ |
| grey cells in "top-left and top-right corners" | alt text | all 9 at lat 59.19-59.93, lon -119.99/-119.67 and -110.45..-111.11 | ✓ |
| "120 survey locations" | alt text | `length(lon)` = **120** | ✓ |
| "log scale from about 0.06 to 7" | alt text | `range(map$est)` = **0.06208639, 7.15557765** | ✓ |
| colour bar is faithful | (mine) | back-solved from tick pixel rows (210.5/410.5/630/830.5, 419.8 px per log10 unit): bar spans **0.0626-7.12** | ✓ within measurement error |
| grey cells number ~9 *in the image* | (mine) | grey blob area / cell area = **8.7 and 8.6 cells** per panel | ✓ |
| **"differ in amplitude, not in pattern, which is what a single shared field implies"** | caption | **cor(log10 surfaces) = 0.9121, R^2 = 0.832** | **✗ FALSE — see blocking #1** |

The out-of-hull cells are **not low-intensity cells**: their `est` values are
0.583-1.695, sitting at the **63rd-93rd percentile** of the cawa surface. Greying
them therefore hides moderately-high cells, not cold ones — which is exactly the
honest thing to do and matches the caption's "not because the field was estimated
to be small there". Good.

---

## BLOCKING

### 1. The map caption and the new prose state a model structure the fit does not have

**Figure:** `isdm-canada-warbler.Rmd`, chunk `map-plot`.

**What I saw.** Viewing the two panels side by side, Ovenbird did not look like a
scaled copy of Canada Warbler: Canada Warbler's low is a broad north-south band
near -116 W plus a deep south-west corner, while Ovenbird's darkest region is a
compact blob near -115.5 W / 56 N. The luminance-greyscale rendering makes this
unmistakable. I then checked it against the fit.

**What the fit actually is.** The model is

```
value ~ 0 + trait + trait:env + isdm_source + offset(log_effort) +
  spatial_scalar(0 + trait | coords)
```

Per this repo's own grammar (`CLAUDE.md`), `scalar` is
`indep(..., common = TRUE)` — *trait-independent* effects whose **variances** are
tied to one shared value. That is not a shared field, and the fitted object
confirms it:

- `omega_spde` has length **164 = 2 x 82 mesh nodes** — **two separate spatial
  fields**, one per trait, not one shared one;
- the two fields are distinct: `sd` 0.4731 vs 0.3896, **cor(field1, field2) = 0.6759**,
  `all.equal` FALSE;
- `log_tau_spde` = `(-1.5613, -1.5613)` — *this* is what `scalar` ties: the
  variance, not the field;
- the environmental slopes are also trait-specific and differ:
  `traitcawa:env` = **0.8745**, `traitoven:env` = **0.5235**.

**Consequence for the plotted surfaces.** They are two different linear
combinations of two different spatial patterns, so they cannot be amplitude
rescalings of each other, and are not: **cor(log10) = 0.9121** (a pure amplitude
difference would give exactly 1), **R^2 = 0.832** — 16.8% of Ovenbird's
log-intensity variation is not a scaled copy of Canada Warbler's. Residual SD of
`log10(oven)` on `log10(cawa)` is 0.1048 against a total SD of 0.2557. The argmax
cells differ (-111.11/56.58 vs -111.11/56.95) and so do the argmin cells
(-116.37/49.12 vs -115.39/49.12).

**Both offending sentences are new in this diff** (they are `+` lines, not
pre-existing text):

- caption, final sentence: *"The two species differ in amplitude, not in pattern,
  which is what a single shared field implies."*
- body prose above the chunk: *"Both species come out of one fit and share one
  latent field, so they belong on one shared colour scale..."*
- alt text, softer but same overstatement: *"Ovenbird is a more muted version of
  the same surface."*

**Change to make.** Keep the shared colour scale — the justification for it
survives intact, it is just a different justification. Something like:

- prose: "Both species come out of one fit, with per-trait spatial fields sharing
  a single variance parameter, so they belong on one shared colour scale — plotted
  separately they would invite a comparison the scales do not support."
- caption: replace the final sentence with the measured fact, e.g. "The two
  surfaces correlate 0.91 on the log scale but are not identical in shape: each
  trait has its own spatial field and its own environmental slope."
- alt text: "Ovenbird shows a similar but flatter and not identical surface."

This is the one item that must not ship as written. Everything else below is
improvement, not correction.

---

## SHOULD-FIX

### 2. In greyscale the out-of-hull cells read as the HOT end, inverting the section's whole point

**Figure:** `isdm-canada-warbler.Rmd`.

**What I saw.** In the luminance-greyscale rendering the grey corners are light
patches indistinguishable from the top of the viridis ramp. Measured relative
luminance: `grey80` = **0.604**; viridis top `#FDE725` = **0.782**; viridis mid
`#21918C` = **0.225**; viridis bottom `#440154` = **0.019**. The grey sits at the
95th percentile of the ramp's luminance range. Printed in black and white — or
seen by anyone with low colour discrimination who is reading by lightness — the
nine masked cells look like a **second intensity peak** in the north corners.

The section this figure introduces says *"a blank corner reads as a cold one."*
In greyscale it reads as a **hot** one, which is the same failure inverted.

In colour and under both deuteranopia and protanopia the mask is fine: the grey
stays neutral and is clearly separable from both the blue lows and the yellow
highs. So this is greyscale-only — but Tufte's own report claims greyscale
legibility is "guaranteed structurally", and for the map it is not.

**Change to make.** Add a non-tonal cue so the mask cannot be confused with any
value: hatch the rectangles (`rect(..., density = 18, angle = 45, col = "grey35",
border = NA)` over a light fill), or draw them white with a visible black border.
Either survives greyscale and both CVD types.

### 3. Panel B's replicate counts sit 1-2 px from the panel border and will clip under a different font

**Figure:** `isdm-spatial-precision.Rmd`, panel B.

**What I saw.** At native size the leading `1` of `15/40` and the trailing `0` of
the last `40/40` are visually flush against the panel box. Measured: the counts
row spans x **904-1286**; panel B's interior is **899-1291**. That is **5 px of
padding on a 1500 px figure** — 0.33%.

The cause is in the code, and it is fragile rather than merely tight:
`text(fz, rep(0.145, 4), paste0(fr, "/40"))` centres `40/40` on `x = 1`, against
`xlim = c(-0.05, 1.05)`. The string's half-width is ~0.048 user units, so its
right edge lands at ~1.048 against a limit of 1.05. **Any font substitution that
widens the glyphs by more than ~4% clips it** — a Linux CI build, a different
`png()` device, a machine without the same default sans face. `15/40` at `x = 0`
has the same margin on the left. Tufte's report records fixing clipped
annotations in panel B twice; this is the same fault surviving at a smaller
magnitude, and it is the one that a different machine will re-open.

**Change to make.** Widen panel B to `xlim = c(-0.11, 1.12)`, or give the two end
labels `adj` values that pull them inward (`adj = c(0, 0.5)` for the first,
`adj = c(1, 0.5)` for the last). Do not rely on the current margin.

### 4. The footnote says "open circles"; the points are filled white discs, and the alt text says so

**Figure:** `isdm-canada-warbler.Rmd`.

**What I saw.** The survey markers are `pch = 21, bg = "white", col = "black"` —
white-filled circles with a black rim (a good choice, and genuinely readable on
both the dark-purple lows and the yellow peak; I checked the dot sitting on the
peak cell). But the in-figure footnote calls them *"open circles"*, which in R
idiom means `pch = 1`, unfilled. The alt text calls them *"small white circles"*.
The figure and its own alt text disagree about what the reader is looking at.

**Change to make.** Footnote to "white circles: survey locations". One word.

### 5. The article does not render correctly against an installed release — flag it, do not let CI discover it

**Both articles** are fine; this is about the build. Rendering
`isdm-canada-warbler.Rmd` against the installed `gllvmTMB` 0.7.0 (2026-08-17
23:56 UTC) yields a **different map** (max 2.46 not 7.16, three colour-bar ticks
not four, so the alt text's "about 0.06 to 7" is then wrong) **and** replaces the
`hull-warning` section's one-line output with a **3,600-row data-frame dump**.
The article states "Every number below is reproducible from this page", so this
matters: it is reproducible only from a build of this branch.

**Change to make.** Nothing in the `.Rmd`. Make sure whoever builds the site
installs from the branch, and tell `main` that the installed library on this
machine is stale. Worth a line in the handover rather than an edit.

---

## POLISH

### 6. The colour-bar axis title is 9 px from the image edge

`relative intensity (log scale)` ends at x = **1311** of a **1320** px canvas
(`mar` right = 3.6 lines, `mtext(line = 2.3)`). Not clipped, verified by eye and
by pixel extent — but it has less margin than any other element in either figure,
and it is the same font-metric fragility as #3 with less consequence. Bump the
right margin to ~4.2.

### 7. At `fuzz = 0` the three arm-mean markers partly occlude one another

Panel A. The means are 0.895 / 0.902 / 0.910 — 0.015 apart on a 1.19 span, about
13 px — and the `off = c(-0.030, 0, +0.030)` dodge is not quite enough: the green
square overlaps the right flank of the orange triangle. Magnified, all three are
still identifiable, and "the three agree at zero fuzz" is the message, so this
mostly works. If you touch it, widen the dodge to ~0.042.

### 8. `"below 0 : integrating is worse"` has a space before the colon

Panel B footnote. House prose elsewhere does not do this. Trivial.

---

## Colour-blindness — what I actually ran, and what it showed

Tufte reported this as "guaranteed in code, not verified by eye". I verified it.
Machado et al. (2009) severity-1.0 matrices for protanopia and deuteranopia,
applied in **linear** RGB with proper sRGB transfer in and out, plus a
Rec.709 luminance greyscale.

- **Precision figure, deuteranopia:** PASSES. Blue stays blue; vermillion becomes
  olive; green becomes grey-brown. Integrated and fuzzed-only converge in hue,
  but the redundant encoding does its job — square vs triangle, dashed vs dotted,
  and direct labels adjacent to their own lines. A deuteranope can read all three
  series.
- **Precision figure, protanopia:** same picture, same verdict.
- **Precision figure, greyscale:** PASSES. Integrated (lum 0.257) and fuzzed-only
  (0.222) are nearly the same grey, so colour alone would fail — line type and
  symbol carry it. This is the redundancy earning its keep, exactly as designed.
- **Map, deuteranopia and protanopia:** PASSES cleanly. Viridis stays monotonic
  blue-to-yellow; the grey mask stays neutral and separable from both ends.
- **Map, greyscale:** **FAILS** on the mask only — see should-fix #2. The viridis
  ramp itself is fine (monotonic luminance 0.019 to 0.782).

So Tufte's palettes were right; the one thing not guaranteed by choosing
Okabe-Ito and viridis was the **off-palette neutral he added**, and that is the
one that breaks.

---

## Captions and alt text

**Precision figure.** Caption and alt text both describe what is actually drawn,
and every number in them checks out (above). The caption's disclaimer — "one
simulated error model and one covariate structure... licenses no claim about
interval coverage, about non-Gaussian or grid-snapped fuzzing, or about any real
dataset" — is the right fence and is honestly placed. The alt text is genuinely
usable without sight of the image: it gives the three series' start and end
values, the direction of each, the reference line, and both panels' counts. This
is the best alt text in the repo. No change.

**Map.** Alt text is likewise substantive and accurate on every checkable number
(120 points, nine grey cells, corner locations, 0.06-7 range). Two corrections
needed, both in blocking #1: "Ovenbird is a more muted version of the same
surface" overstates, and the caption's closing sentence is false. The "carries NO
uncertainty" fence and the "grey means exactly zero, not estimated to be small"
clarification are both correct and worth keeping verbatim.

---

## Honesty audit

Nothing is smoothed, clamped, truncated, or dropped in either figure.

- All 480 replicates are plotted, including the negative estimate; the panel
  limits were chosen to contain it rather than to exclude it.
- The `fuzz = 0` control is shown and is visibly boring, which is the correct
  thing for a control to be.
- The map's log scale is **labelled as log** on the bar and in the caption, and
  it is warranted: 7.156 / 0.0621 = **115x**, so a linear scale would flatten the
  median 0.391 into the floor. Back-solving the bar from tick pixel positions
  gives 0.0626-7.12 against a true 0.0621-7.156 — **the bar does not lie**.
- The shared scale across species is the right call and the caption's reason for
  it is right; only its *model justification* is wrong (blocking #1).
- The greyed cells hide **high** values (63rd-93rd percentile), not low ones, so
  the mask cannot be flattering the surface.
- Panel A's arm dodge (+-0.030 on a 0-1 quantitative axis) very slightly displaces
  each series' x position. Conventional and negligible; noted for completeness.

## What I could not check

- I did not view either figure on physical paper; "reader size" here means an
  800 px-wide downsample, which is the pkgdown content column, not print.
- The CVD simulation is a standard matrix model, not a person with the condition.
  It is far better than the code-only guarantee it replaces, and it found a real
  defect, but it is still a model.
- I verified the map's *plotted* values against the fit's `map$est`; I did not
  independently re-derive `predict()`'s spatial-field arithmetic. That is the
  package's own test surface, not this figure's.
- Per the brief I edited neither `.Rmd`, and ran no state-mutating git command.
