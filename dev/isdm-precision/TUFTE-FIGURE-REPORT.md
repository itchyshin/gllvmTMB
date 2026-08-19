# Article figures — Tufte report

Branch `claude/article-figures`, worktree `/private/tmp/gllvmtmb-1132`.
Files touched: the two `.Rmd`s only (confirmed by `git status`).

## Constraint check, done first

`DESCRIPTION` has `ggplot2` in Suggests but **no** `viridisLite` and **no**
`patchwork`. Rather than build on a partial toolchain, both figures are
**base R**, so no dependency was added and no `requireNamespace()` guard is
needed. Colour-blind-safe palettes come from base `grDevices`:
`hcl.colors(n, "viridis")` for the continuous surface and hard-coded
Okabe–Ito hexes for the three categorical arms. `fmesher` and `Matrix`,
used by the map figure, are already hard `Imports`.

Runtime: the precision figure reads the committed RDS and fits nothing; the
warbler article's fit was already there and takes ~4 s. Both articles render
in ~6 s combined.

---

## Figure 1 — `isdm-spatial-precision.Rmd`, chunk `attenuation-figure`

The article's argument was a markdown table. It is now a two-panel figure,
with the table kept underneath as the numeric backing (the prose refers to
"the table above" twice, and a table is what you check a figure against).

**Panel A** — all 480 replicate slopes as pale jittered symbols, arm means as
solid symbols joined by lines, and a grey reference line at the true
β = 0.9. Reads the three claims directly: `precise_only` flat on truth,
`fuzzed_only` collapsing to 0.22, `integrated` sitting between them.

**Panel B** — the one thing the table could not show. The replicates are
**paired within dataset** (same `rep`, same landscape, same truth), so
`β̂_integrated − β̂_precise_only` is a within-dataset quantity. At `fuzz = 0`
it straddles zero, **15/40** below — a coin flip, which is what a working
control looks like. At every non-zero fuzz it is **40/40** below zero. This
upgrades the punchline from "the means differ" to "it happens every single
time", and I added one short paragraph of prose under *The uncomfortable
part* to say so.

Guaranteed in code, not left to the eye: Okabe–Ito colours **plus** distinct
point symbols (circle / triangle / square) **plus** distinct line types
(solid / dotted / dashed), so the figure survives greyscale printing as well
as colour-blindness; direct labels at the right edge instead of a legend;
explicit `fig.width`/`fig.height`/`dpi`.

### Render → see → fix loop: 4 iterations

1. **Draft 1.** Viewing the PNG caught four faults invisible in the code:
   panel letters `A`/`B` collided with the centred panel subtitles; **both
   x-axis titles were clipped at the panel edges** (leading "p" of
   "positional" gone on both); panel B's footnote rendered as
   "ow 0: integrating made the estimate" — clipped at both ends; and the
   "true β = 0.9" label overlapped the `fuzz = 0` point cloud.
2. **Draft 2.** Fixed by merging letter and subtitle into one left-aligned
   `bquote(bold("A") ~ ~ "...")`, shortening the axis title, and shrinking
   `cex`. Viewing again: the truth label still overlapped the cloud
   (`fuzz = 0` reaches 0.993 and the label sat at 0.975), and **panel B's
   two annotations were still clipped** — the panel is only half the figure
   width and I had over-estimated how much text fits.
3. **Draft 3.** Raised panel A's `ylim` to 1.09 and moved the truth label to
   1.055 with a short leader line down to the reference line; raised panel
   B's `ylim` to 0.32 to buy three text rows and split the header across two
   short lines. Viewed: all clear.
4. **Draft 4 (last fix).** Replaced the ASCII `x` in "(x correlation
   length)" with `×`, then **re-rendered and viewed again** to confirm
   the multiplication sign survives the `png()` device rather than assuming
   it. It does, and it also survives knitr's base64 embedding (checked
   below).

### Verified through the real pipeline, not just standalone

`html_vignette` is self-contained, so the figure is embedded as base64 and
never written to disk. I extracted the base64 payload from the rendered HTML
and **viewed that image** — it is identical to the standalone render, which
is the check that the chunk options and the UTF-8 `×` actually survive
knitr. Alt text is present on the `<img>` in the output.

### The fallback was rendered and viewed too

The `file.exists()` fallback (means from the published table, no dispersion)
is not decoration — I extracted the chunk, repointed it at a nonexistent
path, rendered it, and **looked at it**. First attempt: the note
"replicate-level file absent: difference of means only" was **clipped** in
panel B, exactly the fault that bit twice above. Split into two short lines
and re-rendered; it fits. The fallback also announces itself, so a degraded
build can never be mistaken for the real measurement.

---

## Figure 2 — `isdm-canada-warbler.Rmd`, chunk `map-plot`

Was: base-R `image()` with the default heat palette, `cawa` only, `oven`
silently discarded, no aspect correction, no colour bar.

Now: **small multiples for both species** on **one shared viridis colour
scale**, a shared colour bar, a **log** intensity scale, geographic aspect,
the survey-point overlay kept, and the out-of-hull cells marked.

- **Shared scale, and it had to be shared.** Both species come out of one
  fit and share one latent field. Per-panel scales would have made two
  different-looking maps out of one field. On a shared *linear* scale
  `cawa`'s 7.16 peak flattened everything else (median 0.39), so the scale
  is log — labelled `(log scale)` with ticks at 0.1/0.3/1/3 on the natural
  scale.
- **Aspect.** `asp = 1 / cos(mean(lat) · π/180)` = 1.73. The region is
  ~640 km wide by ~1220 km tall and the panels now say so.
- **Out-of-hull cells.** Computed with `fmesher::fm_basis()` — the same
  projector `R/mesh.R:288` builds at fit time — and flagged as rows whose
  basis is all zero. Exactly **9 of 900**, all in the top corners. They are
  drawn grey. This makes the article's abstract "a blank corner reads as a
  cold one" concrete: the reader sees which nine cells are not informed by
  the field. I added a short paragraph noting the greying is a deliberate
  choice, not something `predict()` does, so the figure does not quietly
  contradict the section that follows it.
- **Points readable on any background.** `pch = 21, bg = "white",
  col = "black"` — a white disc with a black rim is visible on both the
  dark-purple lows and the yellow peak. Plain crosses were not.

### Render → see → fix loop: 4 iterations

1. **Draft 1.** Included the mesh hull boundary drawn from `mesh$segm$bnd`
   as a white dashed line, per the brief's optional suggestion. Viewing it
   settled the question: the hull mostly lies *outside* the plotted grid, so
   only disconnected fragments appeared in the corners and along the edges
   — they read as **scratches on the image**, not as a boundary.
   **Rejected**; see below.
2. **Draft 2.** Hull line dropped, grey mask kept. Viewing caught a **white
   sliver between the image and the box on both sides of both panels**. Not
   a rendering artefact — I instrumented it and confirmed `asp` had expanded
   `usr` from the requested `[-120.16, -110.29]` to `[-120.76, -109.69]`,
   0.6° of slack per side, because the panel was wider than the aspect
   needed.
3. **Draft 3.** Computed the required aspect (1.962) against the actual
   `par("pin")` ratio (1.749) and raised the figure height 4.8 → 5.3 in so
   the slack goes to ~0. Slivers gone. But viewing showed the **two footnote
   lines in the wrong order** — I had forgotten that a larger `line` in an
   outer bottom margin puts text *lower*, so "grey cells…" printed above
   "open circles…".
4. **Draft 4 (last fix).** Swapped the two `line` values. Viewed: passes.

Then re-rendered through `rmarkdown::render()` and **viewed the base64
image extracted from the article HTML** — identical to the standalone.

---

## What I rejected, and why

- **The mesh hull outline.** Asked for as optional and conditional on it
  reading cleanly. It did not (iteration 1 above). The grey cell mask is a
  strictly better realisation of the same idea: it marks the cells that are
  actually affected rather than a boundary that mostly falls off-panel, and
  it needs no extra ink inside the data region.
- **ggplot2 + patchwork.** `ggplot2` is in Suggests but `patchwork` and
  `viridisLite` are not, and the brief forbids adding a dependency. Base R
  reaches the same standard here.
- **Per-species colour scales** on the map — see above; they would imply a
  between-species comparison the model does not support.
- **A linear intensity scale** — honest but unreadable, since one cell is
  115× the minimum. Log, labelled as log.
- **Deleting the precision article's table.** The figure leads; the table
  stays as the checkable numbers, and two prose passages point at it.
- **`echo = FALSE` for the map chunk.** The warbler article promises "every
  number below is reproducible from this page", so its plotting code stays
  visible. The precision article shows no code anywhere, so its figure chunk
  is `echo = FALSE` to match.

## Honesty notes

- Nothing was smoothed, clamped or truncated. All 480 replicate estimates
  are plotted, including the `fuzz = 1.0` replicate that came back at
  **−0.071** — a negative slope where truth is +0.9. Panel A's `ylim`
  reaches −0.10 specifically so that point is inside the panel.
- The `fuzz = 0` control row is visibly boring in both panels, which is the
  point of showing it.
- Both captions state what the figure does **not** license, matching the
  existing house voice: the precision caption disclaims interval coverage,
  other fuzzing models and any real dataset; the map caption keeps the
  original "carries NO uncertainty" wording and adds that grey means
  *exactly zero*, not *estimated to be small*.

## Not done / limits

- I could not check the figures against a real colour-blindness simulator or
  a true greyscale conversion — no such tooling here. Colour-blind safety is
  *guaranteed in code* (Okabe–Ito, viridis) and greyscale legibility is
  guaranteed structurally (distinct symbols and line types carry the arm
  identity on their own), rather than verified by eye.
- I did not view the figures at final print size on a physical page; the
  checks are at the declared `fig.width` × `dpi`.
- No `pkgdown::build_site()` run — these are `vignettes/articles/`, so
  `R CMD check` does not build them, and I verified with the exact
  `rmarkdown::render(output_dir = tempdir())` command specified.
- The map figure reaches `mesh$mesh` to get the `fm_mesh_2d`. There is no
  exported accessor for it, so this is an internal-ish reach in
  reader-facing code. It mirrors what `R/mesh.R` itself does, and the chunk
  says so in a comment, but a public accessor would be the better long-term
  answer.
- No state-mutating git command was run.
