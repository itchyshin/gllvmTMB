# FLORENCE-REVIEW-2.md — re-review of the two iSDM article figures

Reviewer: Florence (independent visual QA). Worktree `/private/tmp/gllvmtmb-1132`,
HEAD `47f79bad`. Re-review of `FLORENCE-REVIEW.md` after the article rebuild.
Working files: `/tmp/florence2/`. Nothing committed; no `.Rmd` edited.

## Did I look at pixels?

Yes. Every figure was rendered to a standalone PNG at its declared
`fig.width`/`fig.height`/`dpi` and **viewed with the Read tool**, then viewed again
in luminance greyscale, in simulated deuteranopia and protanopia (Machado et al.
2009 severity-1.0 matrices applied in linear RGB), at reader size (area-averaged
downsample to the pkgdown content column), and as magnified crops of nine suspect
regions. Both **fallback paths** were forced and rendered. The Warbler map was
built with `pkgload::load_all()` on this worktree (the installed 0.7.0 is older);
the fit converged in 71 iterations at objective 437.821.

Three figures exist across the two articles: two in the precision article, one in
the Warbler article. There are no others.

---

# VERDICTS

| figure | verdict |
|---|---|
| `isdm-spatial-precision` fig 1 (three arm-size panels) | **FIX FIRST** |
| `isdm-spatial-precision` fig 2 (biased presence-only arm) | **FIX FIRST** |
| `isdm-canada-warbler` map | **FIX FIRST** |

Nothing is broken. Every defect below is a small edit. But two of them are
**regressions against the version I reviewed before**, and I lead with those
because you asked me to.

---

# Lead: two things are worse than they were

### R1. The previous figures clipped nothing. These clip six replicate points, and both captions say they don't.

Last time I checked the frame explicitly and wrote *"Nothing is clipped out of
frame… I found the `-0.0714` outlier **inside** the panel."* That was because the
old limits were `ylim = c(-0.10, 1.09)`, chosen to contain the extremes.

Both new figures use `ylim = c(0.0, 1.05)`. With `yaxs = "r"` that gives a drawn
region of `[-0.042, 1.092]` (measured from `par("usr")`, not assumed). Against
that window:

| figure | rows in file | rows outside the drawn region | which |
|---|---|---|---|
| fig 1 | 405 | **3** | 220/220 fuzz 1.0 rep 12 fuzzed `-0.0509`; 400/100 fuzz 0 reps 6 and 12 fuzzed `1.1045`, `1.0967` |
| fig 2 | 135 | **3** | 400/100 fuzz 0 rep 4 fuzzed `1.0940`; fuzz 1.0 reps 9 and 15 fuzzed `-0.0839`, `-0.0817` |

All six are from the **fuzzed** arm — the arm whose dispersion is the article's
point. The clipping is two-tailed so the *means* are unaffected (they are computed
from the full data), but the pale cloud is drawn narrower than the fuzzed arm
actually is, and both captions assert otherwise: fig 1 says *"Pale symbols are
**all** 135 replicate fits per design"*, fig 2 says *"Pale symbols are **all** 45
replicate fits"*. Neither is true as drawn.

**Fix.** `ylim = range(c(0, 1.05, d_arm$beta_hat))` in fig 1 and the equivalent in
fig 2, or hard-code `ylim = c(-0.10, 1.12)` as the previous version did. Do not
leave a limit that a future re-run of the simulation can silently overflow.

### R2. The map's in-figure fence — the one element whose whole job is to survive being lifted — is **0 px** from the bottom of the canvas.

Measured on the rendered PNG (1320 x 1060): the last row containing ink is row
**1060**, the final row of the image. That ink is the descenders of "uncertainty"
and the comma in the fence line `SIMULATED DATA -- no uncertainty shown, no real
observations`. It is not clipped on this machine's font; it is clipped on the next
one.

Worse, the three bottom `mtext` lines form a **continuous ink block from row 1004
to 1060** with no gap between them: `oma = c(2.2, 0, 0, 0)` with lines at
`-0.2 / 0.5 / 1.3` puts consecutive baselines 0.7–0.8 margin lines apart while the
text occupies 0.62–0.72 of a line. The gap is under a tenth of a line. The
precision figures, by contrast, leave 11–15 px of bottom clearance.

**Fix.** `oma = c(3.6, 0, 0, 0)` and lines at `0.2 / 1.1 / 2.2`. This is the same
font-metric fragility I flagged last time as should-fix #3; it has moved from panel
B (which no longer exists) to the fence.

---

# Answers to the four things you asked me to watch

### 1. Does the three-panel layout read, and is the dose–response visible?

**The layout reads. The panel order buries the claim.**

At reader size (800 px, area-averaged) the panel titles, axes, series and fence are
all legible; only the legend is small. The three-panel decomposition itself is a
good call — one panel per design, identical scales, identical encoding.

But the panels are ordered **220/220, 400/100, 100/400**, i.e. n(fuzzed) = **220,
100, 400**. That is not monotone. Reading left to right, the integrated series'
endpoint goes **0.522 → 0.738 → 0.344**: down, up, down. The dose–response the
article claims — penalty deepening `-0.105 → -0.279 → -0.438` as the fuzzed arm's
share grows — is present in the figure but has to be reassembled by the reader.

It is also inconsistent with everything around it. `arm-weighting-table` and
`midpoint-table` both sort by `order(-n_po)` → **400/100, 220/220, 100/400**. The
prose lists the same order. Only the figure differs.

**Fix.** `designs <- list(c(400,100), c(220,220), c(100,400))` with `dtitle`
reordered to match, and reorder the caption's parenthetical list. The green line
then descends monotonically left to right and the claim is visible without
arithmetic.

### 2. Is fig 2 consistent with fig 1?

**Yes — this one is clean.** Same three colours (`#0072B2` / `#D55E00` / `#009E73`),
same symbols (16/17/15), same line types (1/3/2), same x dodge, same axis labels,
same reference line at 0.9, same fence wording, same legend position. I compared
them side by side in colour, greyscale and both CVD renderings and found no
encoding drift. Ship the encoding.

Two size notes, not defects: fig 2 is emitted at `out.width = "70%"` against fig 1's
`"100%"`, so on the page fig 2's type renders roughly 35% larger than fig 1's; and
fig 2's legend `cex` is 0.72 against fig 1's 0.68, which widens that gap rather than
narrowing it. If you want the two to look like one system on the page, drop fig 2's
`cex` values or raise fig 1's.

### 3. Does the map's hatching read as "not estimated" rather than as a value?

**Yes. This is properly fixed, and I checked it rather than assuming.**

The previous defect was that `grey80` (relative luminance 0.604) sat at the 95th
percentile of the viridis luminance range, so in greyscale the mask read as a hot
peak. The rebuild draws a `grey85` base with `density = 26, angle = 45,
col = "grey35"` hatching over it. I viewed the mask:

- **in colour, native** — unmistakably neutral-grey-with-black-diagonals against
  both the dark purple lows (bottom-left, bottom-right) and the yellow peak
  (top-right);
- **in luminance greyscale, native** — reads as *texture*, not tone. It does not
  invert. The section's point ("a blank corner reads as a cold one") survives;
- **in greyscale at reader size (800 px, area-averaged)** — the hatch lines survive
  the downsample at both the dark and bright ends. I specifically magnified the
  top-right corner because that is where the base tone matches its neighbours;
- **under deuteranopia and protanopia** — neutral and separable from both ends of
  the ramp.

One residual worth knowing, not worth blocking on: the *base fill* is still a tone
that exists in the ramp (grey85 ≈ luminance 0.69, versus viridis top `#FDE725` at
0.782), so against the yellow corner the whole distinction is carried by the hatch
lines alone. If you want belt and braces, use `col = "white", border = "black"`
under the hatch — white is off the top of the ramp and the border reads as an
annotation boundary.

### 4. Do the fallback paths announce themselves?

**Both announce themselves loudly. Both have a placement bug.**

I forced each `.rds` missing and rendered. The banners fire, in bold `#D55E00`, and
say the right thing (including the correct script name — `generate-arm-weighting-results.R`
and `generate-biased-po-results.R` both exist in `dev/isdm-precision/`). Nothing is
drawn silently. The fallback means are also *correct*: all 27 hard-coded values in
`mu_fallback` and all 9 in `mu_bpo_fallback` match the live data to the last digit
at 3 d.p. — the degraded path plots the truth.

But:

- **fig 1's fallback banner overlaps the middle panel's title.** `mtext(side = 3,
  outer = TRUE, line = -1.1)` against `oma[3] = 0` puts it *inside* the figure
  region; the descenders of "generate-arm-weighting-results.R" cut through the
  ascenders of "n(precise)=400, n(fuzzed)=100". Both are still readable, but the
  ink collides. **Fix:** `oma = c(2.0, 0, 1.6, 0)` and `line = 0.2`.
- **fig 2's fallback banner has 4 px of clearance inside the panel box.** Measured:
  banner spans cols 150–1012; box interior is 146–1015. That is 0.4% of a 1040 px
  figure. Any font substitution that widens the glyphs by more than ~1% clips the
  warning — the one string that must never be clipped. **Fix:** shorten to
  `FALLBACK MEANS -- re-run generate-biased-po-results.R`, or move it to the bottom
  margin alongside the fence.

---

# Remaining defects, by figure

## `isdm-spatial-precision` figure 1

**F1-a (fix first).** Clipping — see R1.

**F1-b (fix first).** The prose immediately above the figure says *"At `fuzz = 0`
every design and every arm sits within 0.02 of 0.9."* **That is false, and the
figure is the disproof.** In the 400/100 design the fuzzed arm's mean at `fuzz = 0`
is **0.9662** — a deviation of **0.0662**, and it is the visibly high orange
triangle sitting well above the grey reference line in the middle panel. Every
other cell is within 0.012. **Fix:** either state the true bound ("within 0.012,
except the 100-row fuzzed arm at 0.966") or drop the numeral. A reader who checks
the one thing the figure makes checkable will find the sentence wrong.

**F1-c (fix first).** The prose says *"grow **only** the fuzzed arm — 100 rows,
then 220, then 400"*. The figure's own panel titles say otherwise: n(precise) goes
400 → 220 → 100 at the same time. What is held constant is neither the precise arm
nor the total (500, 440, 500) — it is the *share*, which is what the mechanism
sentence that follows correctly appeals to. **Fix:** "shift the balance toward the
fuzzed arm — 100 rows against 400, then 220 against 220, then 400 against 100".

**F1-d (should fix).** Panel order — see item 1 above.

**F1-e (should fix).** The truth line is neither labelled in the PNG nor
distinguishable in greyscale. `abline(h = 0.9, col = "grey45")` is unlabelled, so a
PNG lifted into a talk shows a mystery grey line; and the `precise` series lies
almost exactly on top of it at the same greyscale value (I confirmed this in the
luminance rendering — you cannot tell there are two lines). This matters more here
than usual because the figures deliberately bake a fence into the pixels for
exactly this reason. **Fix:** `lty = 2` on the reference line plus
`text(x = 1.02, y = 0.9, "true 0.9", adj = c(1, -0.4), cex = 0.7, col = "grey45")`
in the first panel.

**F1-f (should fix).** Fallback banner overlap — see item 4 above.

**F1-g (polish).** The legend's key segments are too short to render `lty = 2`
versus `lty = 3`: magnified 4x, the "fuzzed" and "integrated" keys are the same
dash-symbol-dot pattern. Line type is the redundancy channel that carries the
greyscale reading, and the legend does not teach it. **Fix:** `seg.len = 3` in the
`legend()` call.

## `isdm-spatial-precision` figure 2

**F2-a (fix first).** The caption says *"Pale symbols are all **45** replicate fits
(15 per fuzz level per arm)"*. The file has **135 rows** — 3 fuzz levels x 3 arms x
15. The two halves of the sentence contradict each other and the drawn figure shows
135 pale symbols. Fig 1's parallel caption gets this right ("135 per design").
**Fix:** 45 → 135.

**F2-b (fix first).** Clipping — see R1.

**F2-c (should fix).** Fallback banner clearance — see item 4 above.

**F2-d (polish).** Apparent type size relative to fig 1 — see item 2 above.

Everything else in fig 2 checks out, including every number in its caption and alt
text.

## `isdm-canada-warbler` map

**M-a (fix first).** Fence at the canvas edge and footnote lines touching — see R2.

**M-b (should fix, unfixed from last time).** The in-figure footnote still says
*"open circles"*. The points are `pch = 21, bg = "white"` — filled white discs — and
the figure's own alt text calls them *"small white circles"*. The figure contradicts
its own alt text about what the reader is looking at. This was should-fix #4 last
time. **Fix:** one word — "white circles: opportunistic + survey locations
(disjoint)".

**M-c (should fix).** The alt text says *"Bold red text **across the middle of the
figure**"*. The fence is at the **bottom**, below both map panels. A screen-reader
user told to look in the middle will be looking in the wrong place. **Fix:**
"across the bottom of the figure".

**M-d (should fix).** The alt text says the circles are *"scattered independently
across both panels with **no shared points**"*. Both panels carry the **identical**
240 locations — `points(dat$X, dat$Y, ...)` is called with the same data in each
loop iteration. The "disjoint" property belongs to the two *arms* (0 shared
coordinates, which I verified), not to the two *panels*. As written the alt text
asserts something visibly false. **Fix:** "The same survey and opportunistic
locations are overlaid on both panels; the two arms share no coordinate."

**M-e (should fix).** The prose above the chunk justifies the shared colour scale
with *"Both species come out of one fit and **share one latent field**, so they
belong on one shared colour scale"*. The structural half is now true — the model is
`spatial_latent(0 + trait | coords, d = 1)`, genuinely one field with per-trait
loadings, which is the honest repair of my previous blocking item. But two things:

- the *reason* does not follow. What licenses a shared colour scale is that both
  panels are relative intensities on the same response scale from the same fit;
  field-sharing is irrelevant to the scale;
- on this seed the shared field does essentially **no work for Ovenbird**. The
  fitted loadings are `(0.0515, 0.00089)`. Comparing `predict(re_form = NA)` with
  the full prediction, the field contributes **sd 0.261 of 0.941** to Canada
  Warbler's log-intensity (28%) and **sd 0.0045 of 0.328** to Ovenbird's (1.4%).
  The Ovenbird surface a reader sees is almost purely `a0 + b*env`. So a reader
  who takes the sentence at face value will conclude the shared field is what makes
  the two panels look alike, and for the right-hand panel it is not.

**Fix:** "Both species come out of one fit and are plotted on the same response
scale, so they belong on one shared colour scale — plotted separately they would
invite a comparison the scales do not support." If you want to keep the field claim,
say what it did: on this seed the shared field carries 28% of the Canada Warbler
surface's variation and 1% of the Ovenbird's.

**M-f (polish, unfixed from last time).** `relative intensity (log scale)` ends
**8 px** from the right edge of a 1320 px canvas (it was 9 px last time). Not
clipped here; same font-metric fragility. **Fix:** right margin 3.6 → 4.4.

**M-g (polish).** Each survey location is drawn **twice** — `dat` has 480 rows for
240 unique coordinates, one per species. Pure overdraw; it darkens the rims and
doubles the point ink. **Fix:** `points(unique(dat[, c("X","Y")]), ...)`.

**M-h (polish).** `asp = 1` overrides `xaxs = "i"`, leaving a ~7 px white strip
inside the frame on the left and right of each raster. At reader size it reads as a
thin blank margin *inside* the box, which is a second kind of "nothing here"
competing with the hatch. Cosmetic, but the figure is otherwise careful about
exactly this distinction.

---

# What I verified numerically, and how

All checks re-derived from the `.rds` files and the live fit; nothing carried over
from the previous review.

**`arm-weighting-results.rds`** — 405 rows, 6 columns, balanced 15 per
(design x fuzz x arm), confirmed by `table()`.

- **All 27 arm means match the article's fallback matrix `mu_fallback` exactly at
  3 d.p.** (max absolute difference 0.000 in every cell of all three designs). The
  degraded path plots the truth.
- **Headline dose–response verified**: at `fuzz = 0.5`, `integrated − precise` =
  `0.788 − 0.893 = −0.105` (400/100), `0.619 − 0.898 = −0.279` (220/220),
  `0.474 − 0.912 = −0.438` (100/400). Matches the prose exactly.
- **"15 of 15" verified** in all three designs at both non-zero fuzz levels
  (9 of 9 cells: 15/15 each). The `fuzz = 0` control gives **6, 9, 8 of 15** in
  the order 400/100, 220/220, 100/400 — exactly as the prose states.
- **Midpoint table verified**: within-replicate `mean |integrated − own midpoint|`
  = 0.023 / 0.041 at 220/220 and 0.149 / 0.196 / 0.165 / 0.215 at the unbalanced
  designs. Matches "0.023–0.041" and "0.149–0.215".
- **"retains 21–23% of the true slope"** at `fuzz = 1.0`: 22.8% / 21.1% / 23.1%. ✓
- **"every arm within 0.02 of 0.9 at fuzz = 0"**: **FALSE** — max deviation
  **0.0662** (400/100 fuzzed, mean 0.9662). All eight other cells are ≤ 0.0119.
  See F1-b.
- **Alt text**: "0.74 / 0.52 / 0.34 at fuzz 1.0" against measured
  0.738 / 0.522 / 0.344. ✓ "fuzzed falls toward 0.2" against 0.205 / 0.190 / 0.208. ✓
- **Clipping**: `par("usr")` measured as `(-0.1048, 1.1048, -0.042, 1.092)`;
  3 rows fall outside. See R1.

**`biased-po-results.rds`** — 135 rows, all at 400/100.

- All 9 fallback means match exactly at 3 d.p.
- Means: precise 0.903 flat; fuzzed 0.915 → 0.363 → 0.206; integrated 0.904 →
  0.835 → 0.798. Alt text says "0.92 → 0.21" and "0.90 → 0.80". ✓
- Replicates hurt: **14/15** at both non-zero fuzz, **10/15** at the control. ✓
- Caption's "45 replicate fits" contradicted by 135 rows. See F2-a.
- 3 rows outside the drawn region. See R1.

**Warbler map, against the live fit** (`load_all`, convergence 0, 71 iterations,
objective 437.821):

| claim | measured | verdict |
|---|---|---|
| "a handful of hatched cells" | `sum(oo)` = **9 of 900** | ✓ |
| "near the map corners" | 3 at bottom-left, 3 at bottom-right, 3 at top-right | ✓ |
| shared log colour scale spans the data | `range(map$est)` = **0.0670 – 3.2383**; `brk` endpoints back-transform to exactly those | ✓ |
| colour bar is faithful | back-solved from tick pixel rows 70 / 315 / 584 at 513.2 px per log10 unit: predicts 70.6 / 315.4 / 583.8 for 3 / 1 / 0.3 — **within 1 px** | ✓ |
| "equal aspect" | box 447.5 x 864.5 px over 263.7 x 509.5 km = **1.697 px/km in both directions** | ✓ |
| UTM zone 11N | `add_utm_columns()` reports EPSG:32611 | ✓ |
| the two panels "differ mainly in amplitude" (alt text) | `cor(log10 cawa, log10 oven)` = **0.9647**, R² = **0.9307**, regression slope **0.337**, residual sd 0.0375 against total 0.1426 | ✓ defensible |
| the mask is not flattering the surface | masked cells sit at the **26th–99.7th percentile** of the cawa surface; the three top-right ones are the **98.9th, 99.4th and 99.7th** — the mask hides the highest cells, not cold ones | ✓ honest direction |
| no point sits inside a masked cell | **0 of 240**; also **0 of 240** data points fall outside the hull | ✓ consistent |
| "share one latent field" | one `d = 1` field, loadings `(0.0515, 0.00089)`; field contributes 28% of cawa's log-surface sd and **1.4%** of oven's | structurally ✓, materially one-sided — see M-e |

---

# What I checked in greyscale, and what happened

Rec.709 luminance, computed in linear RGB with proper sRGB transfer in and out.

- **Precision fig 1, greyscale: PASSES.** Solid / dashed / dotted plus
  circle / triangle / square carry all three series cleanly. Nothing inverts. The
  one loss is that the grey reference line at 0.9 becomes indistinguishable from the
  `precise` series lying on top of it (F1-e).
- **Precision fig 2, greyscale: PASSES.** Same result, same single caveat.
- **Map, greyscale: PASSES — the previous failure is fixed.** The hatched mask reads
  as texture, not as tone, at both native and reader size, against both the dark and
  the bright end of the ramp. The viridis ramp itself remains monotonic in luminance.
  The fence loses its red but stays bold and legible.
- **Precision fig 1, deuteranopia and protanopia: PASSES.** Blue stays blue,
  vermillion goes olive, green goes grey-brown; symbol and line type carry the
  distinction the hues stop carrying.
- **Map, deuteranopia and protanopia: PASSES.** Viridis stays monotonic
  blue-to-yellow, the mask stays neutral, the fence goes olive but stays legible.

**Colour is never the only channel** in any of the three figures. That part of the
design is sound and I would not change it.

---

# What I could not check

- No physical print. "Reader size" is an area-averaged downsample to the pkgdown
  content column, not paper.
- The CVD renderings are a standard matrix model, not a person with the condition.
- I verified the map's plotted values against `map$est` and the field's contribution
  via `re_form = NA`; I did not re-derive `predict()`'s SPDE arithmetic from first
  principles. That is the package's test surface, not this figure's.
- The Warbler figure was built with `pkgload::load_all()` on this worktree. Anyone
  building the site against the installed `gllvmTMB` 0.7.0 (2026-08-17) will get a
  different map, as I recorded last time. That remains a build note, not a figure
  fault.

---

# Summary of edits

**Must fix before ship**

1. `ylim` in both precision figures so no replicate is clipped, or amend both
   captions (R1).
2. `oma`/`line` in the map so the fence is not at the canvas edge and the three
   footnote lines do not touch (R2).
3. Fig 2 caption: 45 → 135 (F2-a).
4. Precision prose: "within 0.02 of 0.9" is false at 0.9662 (F1-b).
5. Precision prose: "grow only the fuzzed arm" is contradicted by the panel titles
   (F1-c).

**Should fix**

6. Reorder fig 1's panels to 400/100, 220/220, 100/400 so the dose–response reads
   left to right and matches the tables (F1-d).
7. Label the truth line in the PNG and make it distinguishable in greyscale (F1-e).
8. Move fig 1's fallback banner out of the panel titles; give fig 2's banner real
   clearance (F1-f, F2-c).
9. Map footnote: "open circles" → "white circles" (M-b).
10. Map alt text: fence is at the bottom, not the middle (M-c); both panels carry
    the same points (M-d).
11. Map prose: the shared colour scale's justification, and what the shared field
    actually did on this seed (M-e).

**Polish**

12. `seg.len` in fig 1's legend; matched `cex` between the two precision figures;
    map right margin 3.6 → 4.4; deduplicate the map's points; the white strip inside
    the map frame.
