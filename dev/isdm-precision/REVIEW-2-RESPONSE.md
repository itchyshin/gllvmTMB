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

---

# Round 3 — and B3 was made WORSE by round 2

Pat's third verdict is again **"Yes-but"**: B1 partly, **B2 fixed**,
**B3 not fixed — wrong in the other direction**, B4 partly.

## The finding that matters, and the chain of errors behind it

**Her round-2 quadrature ladder was run on a single seed.** The rows agreed
because the random draw was fixed, not because the estimator had converged
to a biased value. She reported that as evidence of a biased-but-stable
estimate; I wrote it into the article as a diagnosed defect, complete with a
mechanism.

**Both steps were wrong, and the mechanism was wrong on its face.** The
presence's `env` is read at the very lattice node whose intensity generated
it, so there is no measurement error to have. Her checks confirm it: raising
`nfine` to 300 makes the estimate *worse* (−5.5%), and adding genuine
positional error by jittering presences inside their cells changes nothing
(+0.5%).

**The estimator is not detectably biased.** Her 30 seeds: cawa 0.8188,
95% CI [0.782, 0.856] against 0.8 (p = 0.325); oven 0.4099, CI [0.375,
0.445] against 0.4 (p = 0.583). My own Block 6 data, tested rather than
eyeballed, agrees: 1.1099 (sd 0.093) vs 1.10, t = 0.24, p = 0.82; −0.6405
(sd 0.065) vs −0.70, t = 2.06, p = 0.11 — both CIs contain the truth.

The printed 0.687 / 0.291 is one seed sitting about 1.3 sd out, with ~160
presences giving a Monte Carlo sd near 0.08–0.10.

**Fixed** by reporting the single fit as one draw, giving the across-seed
evidence, and deleting the invented mechanism and the "stability is not
accuracy" lesson built on it. The section now says the useful thing instead:
do not diagnose an estimator from one replicate — naming that this article
did exactly that.

## Two silent hazards my own round-2 fixes introduced

Both are precisely the class these articles exist to warn about.

1. **`cor_length()` clobbered the caller's RNG.** The `n_sub` fix put a bare
   `set.seed()` inside the function. Demonstrated: `rnorm(1)` after
   `set.seed(99)` returns 0.2140 without the call and 0.6166 with it. Now
   saves and restores `.Random.seed`, with a comment saying why.
2. **The `d = 1` loadings chunk mislabelled at any `d > 1`.** A reduced-rank
   loading matrix for P traits at rank d holds `P*d − d(d−1)/2` free values,
   not P. At `d = 2` with 12 species `setNames(..., spp)` would paste 12
   names onto 23 numbers and pad with `NA` — in the section written for
   readers with more than two species. Now guarded.

## Where she corrected the article in the article's favour

**AIC picks `d = 2` correctly** with 12 species and true rank 2 (7695.0 vs
8228.3 and 7714.4) — the instrument the section disowned is the one that
works. The tell it offered instead ("extra dimensions arrive with near-zero
loadings") holds at P = 2 and **fails** at P = 12.

## Still open after round 3

Her friction list (dev-path references, `species: placeholder`, no route to
map uncertainty), Florence's polish tier, and the `d` guidance, which should
be rewritten around AIC rather than around the loading-magnitude tell.
