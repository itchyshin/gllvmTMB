# After-task — reader-first rebuild of the SDM article set

**Date:** 2026-08-19
**Branch:** `claude/reader-first` (10 commits off `main`)
**Lane:** Claude Code, articles only. No `R/`, `src/`, `NAMESPACE`, or `tests/` changes.

## Scope

The maintainer read the live Canada Warbler article and reported he did not
understand much of it — "some details without good explanations and insider
voices". He set the acceptance test explicitly:

> can an ecology graduate student read this for the first time — will it be useful?

That test, not correctness, governed this task. The articles were already
correct; they were written for reviewers.

Audience contract adopted: a second-year ecology PhD student who knows GLMMs,
AIC and eBird, and has never heard of TMB, SPDE, latent variables, or meshes.

## Outcome

Five pages changed; two are new.

| page | state |
|---|---|
| `sdm-start-here.Rmd` | **new** — front door: one-surface/four-windows figure, decision-tree flowchart, routing table, honest exits |
| `unit-of-analysis.Rmd` | **new** — what a "site" is; two Tufte figures; taxon-by-data survey; measured cost of gridding |
| `isdm-canada-warbler.Rmd` | rewritten reader-first (~4,200-word main path, evidence moved to "For the record") |
| `isdm-spatial-precision.Rmd` | rewritten reader-first |
| `gllvm-vocabulary.Rmd` | gains a Species-distribution terms section (intensity, arm, offset, point process, quadrature, cloglog, mesh) |

`_pkgdown.yml`: `sdm-start-here` first in the SDM navbar menu and articles
index; `unit-of-analysis` first under Concepts.

## What the reviews changed

**Florence (figures).** Unit-article figure 1 shipped only after key labels
were moved clear of the 90-minute ring (struck through at reader width), the
accent colour was darkened for contrast, and the caption was made explicit
that the rings are minutes and the pooled count's effort is deliberately not
shown.

**Pat (cold read, as the target student).** Six must-fixes, all applied:

1. ABMI's link and expansion sat on the second mention, not the first.
2. `spOccupancy` unlinked at its first appearance (the routing table).
3. The iNaturalist geoprivacy claim had no citation — now Koo et al. (2025),
   *Conservation Biology* 39, e70050.
4. **"arm"** was used on the front door and never defined — now defined at
   first use in every article that uses it, plus a vocabulary entry.
5. **"fences"/"gate"** — internal project vocabulary in reader-facing prose.
6. The vocabulary page the articles point confused readers to contained none
   of the SDM terms they would stumble on.

Her most valuable finding was structural: every article assumed long format,
but most community data arrive as a wide site x species matrix, and no page
showed the reshape. `unit-of-analysis.Rmd` now shows the `pivot_longer()` call
and names the `traits()` wide grammar as the alternative.

## Corrections made to standing claims

**Occupancy models are not "a different model family".** An earlier statement
of mine, repeated in `unit-of-analysis.Rmd`, was too strong. A multi-species
occupancy model is a binary joint SDM plus a detection submodel; the extra
layer is estimable only because repeat visits supply the information to split
occurrence from detection, and with a single visit the two collapse. The
corrected framing is used consistently across the front door, the unit
article, and the honest-exits section.

## Checks

- All five pages render from a clean environment (`envir = new.env()`); the
  four-article loop must render each in its own environment, otherwise the
  articles trample each other's objects.
- Both new figures inspected as rendered pixels at 700 px reader width, in
  colour and greyscale. The decision tree distinguishes destinations from
  honest exits by border style and italics, not colour.
- All 13 internal links verified against real `.Rmd` filenames; all 5 external
  URLs return HTTP 200.
- Every in-text citation verified against Crossref or the publisher: Gábor et
  al. 2022 (*MEE* 13:2289-2302), Renner et al. 2015 (*MEE* 6:366-379), Warton
  & Shepherd 2010 (*AoAS* 4:1383-1402), Sólymos et al. 2013 (*MEE*
  4:1047-1058), Fletcher et al. 2019 (*Ecology* 100:e02710), Moudrý et al.
  2023 (*PPG* 47:467-482), Koo et al. 2025 (*Conserv Biol* 39:e70050), van
  Strien et al. 2013 (*JAE* 50:1450-1458).
- Every evidence file the articles read is tracked in git, re-checked against
  the clean-checkout failure of 2026-08-1x (a pkgdown build sees only tracked
  files).

## Measured result folded in

Gridding cost on the 12-species design (`cawa12-gridding.rds`): cells of
0.1-0.2 degrees cost nothing detectable (correlation with truth 0.943/0.946
against 0.926 ungridded); at 0.4 degrees (~25 x 44 km) mean absolute slope
error rises from 0.244 to 0.385. The controlling quantity is cell size
relative to the habitat correlation length, which is the same mechanism the
precision article measures for positional error.

## Follow-ups (not done here)

- A worked path from a real eBird/GBIF download to the model-ready long frame.
  This is the single remaining adaptability gap Pat named, and it is the
  packaged-dataset + ten-line-quickstart idea already on the list.
- Map uncertainty: `predict()` still refuses `se.fit` with new data. Stated in
  the articles as a limit; tracked in #1176.
- Grain-size / insect-first article: #1178.
- Cosmetic nits from Pat's report (unlinked `fmesher`/`INLA`/`terra`, author
  truncation style) left for a later sweep.
