# Pat's second review — `isdm-spatial-precision` and `isdm-canada-warbler`

Re-test, not a rubber stamp. I read both rendered pages and both `.Rmd` files, then
ran code in the worktree to check the things I doubted rather than believing them.
Everything numeric below is something I measured myself; the scripts are in my
scratchpad and the settings are stated inline so they can be re-run.

---

## 1. Verdict

**Yes-but.**

The distance travelled is large and I want to say so before the criticism. Last time
my answer was "No, not without help — the first thing I would try fails." This time I
can build the data frame, project it, mesh it, fit the two-arm model, get a
presence-only arm off the ground, and draw the map. Four of my eleven blocking items
are closed outright and three more are closed better than I asked for.

The "but" is that two of the things I would do are wrong, and one of them is the
decision the article pair exists to inform. Specifically: I cannot compute the article's
central number from my own raster, and the article's loudest, best-evidenced claim
**reverses sign** under conditions that describe every real eBird dataset I know of —
including mine.

---

## 2. Blocking items that remain

### B1. The correlation-length recipe does not survive contact with a raster

This was my #1 and the rebuild took it seriously: the ambiguity is gone. `phi` is
defined without convention (distance at which correlation falls to 1/e), the practical
range ≈ 3φ conversion is stated, the recipe is validated against known truth, and its
domain bias is measured. I reproduced the validation table and the domain table and
both hold. As a *definition* this is fixed.

As a *procedure* it is not, because `cor_length()` takes vectors and builds a dense
n × n distance matrix. My covariate raster is a raster. Measured on this machine:

| points fed in | time | dense distance matrix |
|---|---|---|
| 900 | 0.0 s | 0.01 GB |
| 3,600 | 0.6 s | 0.10 GB |
| 10,000 | 4.0 s | 0.80 GB |
| 22,500 | 24.9 s | 4.05 GB |

A 1 km Alberta raster is ~10⁶ cells: 8 TB. The article says "Use the recipe above on
your own raster" and never says the one word that makes that work — **subsample**.

I tested whether subsampling is safe, because if it is, this is a one-sentence fix.
It is (60 × 60 surface, true φ = 0.15; full-raster answer 0.1276):

| points | mean φ̂ | sd over 5 draws |
|---|---|---|
| 2,000 | 0.1296 | 0.0060 |
| 1,000 | 0.1231 | 0.0068 |
| 500 | 0.1222 | 0.0074 |
| 200 | 0.1327 | 0.0110 |

But the reflex an ecologist actually has when a raster is too big is `terra::aggregate()`,
not `sample()`. I measured that too, on the same surface:

| coarsening | φ̂ |
|---|---|
| none (3,600 cells) | 0.1276 |
| ×2 | 0.1413 |
| ×3 | 0.1468 |
| ×4 | 0.1556 |
| ×6 | 0.1764 |

Aggregating **inflates** φ̂ monotonically — +38% at ×6. Inflating φ shrinks my
`fuzz / φ` ratio and moves me toward "benign", which is the *unsafe* direction and the
exact opposite of the direction the article promises its errors run ("the error is
always downward... the safe direction").

**What I could not do:** get φ from my own raster without either an out-of-memory
error or a silently wrong answer biased the wrong way.

**Fix:** one sentence. `## on a real raster: r <- as.data.frame(x, xy = TRUE); i <- sample(nrow(r), 2000)`
— plus "do not aggregate the raster first; block-averaging inflates φ̂."

### B2. The headline result inverts in the case I actually have

The biased-arm section exists to answer my old #2, and it is a genuine addition. But
look at what the design fixes: the accessibility surface is (a) constructed statistically
independent of `env`, and (b) **measured exactly and included in the model**. Under
those two conditions the opportunistic arm's environmental slope is already unbiased —
so there is nothing for the survey arm to repair, and integration can only cost. The
trade-off the article says exists is not instantiated anywhere in its evidence.

I re-ran the article's own `evidence-biased-po.R` changing one thing at a time
(12 replicates, 400 precise / 100 fuzzed, at **fuzz = 1.0 × correlation length** — the
article's worst case for integration; truth = 0.9; "helped" = integrated closer to
truth than precise-alone, the article's own criterion):

| condition | precise alone | integrated | integration helped |
|---|---|---|---|
| access independent + modelled exactly *(the article)* | 0.906 | 0.805 | 0/12 |
| access confounded ρ = 0.3 + modelled exactly | 0.886 | 0.815 | 1/12 |
| access confounded ρ = 0.7 + modelled exactly | 0.907 | 0.844 | 0/12 |
| access confounded ρ = 0.7, modelled with sd 0.5 error | 1.189 | 1.081 | **11/12** |
| access confounded ρ = 0.7, modelled with sd 1.0 error | 1.472 | 1.346 | **12/12** |
| access confounded ρ = 0.3, **not** modelled | 1.228 | 1.129 | **10/12** |
| access confounded ρ = 0.7, **not** modelled | 1.741 | 1.624 | **12/12** |

The switch is not the confounding. Confounding alone changes nothing — every
"modelled exactly" row still hurts. The switch is whether the analyst has an
**exactly measured** surrogate for the reporting bias. Nobody has that. Every eBird
integration I have read uses an imperfect effort or road-density proxy. Give the
proxy even modest measurement error and integrating my fuzzed ABMI arm moves the
slope *toward* truth in 11–12 of 12 replicates, at the fuzz level the article calls
its worst case.

The article does say the trade-off exists, in prose, twice, and names both conditions
of its design honestly. That is not enough. It states the *cost* with two figures,
four tables, replicate counts, "15 of 15", and a section titled "The uncomfortable
part"; it states the *benefit* in one unmeasured paragraph. I read the whole thing
slowly and carefully and my takeaway was still "integrating a fuzzed arm moves you
away from truth; check before fusing." That is the wrong takeaway for my data. This
is my original #2 — the item I named as the one change I would make — **moved, not
closed**.

To be fair to the article, and this should go in it too: in the unmodelled-bias
regime *nothing* recovers truth (at fuzz 1.0: precise 1.741, fuzzed 0.193, integrated
1.624 against a truth of 0.9). The ranking flips but both answers are bad. The correct
lesson is "at fuzz ≈ φ you have no good option", not "keep the survey arm" and not
"drop it".

**What I could not do:** decide whether to keep my ABMI arm — which is the single
question I brought to these articles.

### B3. The presence-only section prints a failed recovery as a pass

My old #3 dead-ended immediately; now it does not, and that is a real gain — I have
runnable Berman–Turner code, I know `weights =` is the hook, the package's own
warning about weighted objectives is quoted rather than paraphrased, and the honest
correction that it does **not** combine with `isdm_sources()` is demonstrated with the
actual error rather than asserted. Good.

But the section's own printed sanity check is:

```
#> true slopes: 0.8 0.4   estimated: 0.687 0.291
```

14% and 27% low, with no comment. The article then says: "Increase the quadrature
grid until the estimates stop moving — the standard diagnostic." I did exactly that:

| quadrature nodes | nodes/presence | estimated slopes |
|---|---|---|
| 900 | 5 | 0.650, 0.263 |
| 3,600 *(as shipped)* | 21 | 0.687, 0.291 |
| 8,100 | 46 | 0.699, 0.301 |
| 14,400 | 82 | 0.705, 0.306 |
| 25,600 | 146 | 0.710, 0.310 |

They stop moving. They stop 11% and 22% from truth. **The article's stated diagnostic
returns a green light on a materially wrong answer.**

The culprit is not the quadrature grid at all — it is `nfine = 60`, the lattice the
example generates presences on, which snaps every presence to a cell centre and so
coarsens the covariate *at the presences*. That is positional error: the companion
article's own mechanism, injected by this article's own simulation. Refine the
presence lattice to `nfine = 150` and the same fit gives 0.880 / 0.491.

The dev-log's Block 6, where the "20 nodes per presence" figure comes from, recovers
truth well (1.110 vs 1.10; −0.641 vs −0.70). That number was carried into a different
setup where it does not do the same job.

**What I could not do:** tell, on my own GBIF fit, whether a slope 15% off means my
node density is too low, my data, or the device. Cheapest fix: raise `nfine`, or add
one sentence saying the miss is a lattice artefact of the simulation and not a
property of the estimator.

### B4. `spatial_latent(0 + trait | coords, d = 1)` is used six times and never justified

Half of my old #6 is closed brilliantly — see §3. The other half is untouched. With
two species I copy `d = 1` and it works. With my twelve species I do not know whether
`d = 1` is still right, what `d` is trading off here, or when I would want
`spatial_indep()` instead. The precision article contains no `gllvmTMB` code at all, so
it cannot help; the recap calls it "a `spatial_*()` term for the shared field" as
though the choice were free, which is the same phrasing I flagged last time.

**What I could not do:** choose `d` for my own species set.

---

## 3. Closed from my original list

- **#3 (arm weighting, 50/50).** Fully. Three explicit designs, n stated per arm, a
  dose-response (−0.105 → −0.279 → −0.438 as the fuzzed arm grows), and the midpoint
  objection met by name with a *within-replicate* midpoint rather than a midpoint of
  means. This is the strongest part of the rebuild and it is what the previous version
  most needed.
- **#4 (figures carry no fence).** Fully. I extracted all three PNGs from the rendered
  HTML and looked at the pixels. All three carry the fence inside the image — the map
  in bold red, both simulation panels in grey. Screenshot-safe.
- **#5 ("narrower intervals" vs "no coverage claim").** Closed by deletion of the
  clause. The scope bullet stands alone now.
- **#6, first half (`coords`).** Better than I asked. Not a sentence but a live demo:
  `c(coords = 437.8214, banana = 437.8214)`. And it goes further than my complaint — it
  names the hazard in the *other* direction, that a real `site` column would also be
  silently ignored, with an issue number.
- **#7, first half (data shape).** Fully. `shared (X, Y) between arms: 0`,
  `shared obs_id between arms: 0`, and the mechanism stated plainly: the field lives on
  the mesh, the mesh spans the union, every row projects through `A_proj`. I tested
  whether I understood it well enough for my own data by trying a case the article does
  *not* show — arms disjoint in **extent** (opportunistic south, survey north) rather
  than interleaved. It fits and converges across three seeds. That is the actual test
  the item was asking: the explanation was good enough that I could predict a case the
  article never covered, and I was right.
- **#8 (the `newdata` scaling bug).** Fully, and better than a fix — the right version
  is done first with a comment saying why, and then the broken version is run *live*
  with its cost printed. I now understand why it matters, which I did not before.
- **#9 (`grid$cell_id`).** Fully, and this is the best single answer in either article.
  Answered in place ("required by the design matrix, not used in the prediction"), then
  demonstrated on a purpose-built model with a genuine unit-level random effect, showing
  the real warning — and then the detail I would never have worked out, that neither
  documented alternative is what the map itself uses, because `re_form = ~0` would zero
  the spatial field too.
- **#10 (version).** Mostly. "Before gllvmTMB 0.7.0 (development)" is a number I can
  act on. No `packageVersion("gllvmTMB")` one-liner, which is the obvious completion.
- **#11 (unprojected mesh).** Fully. `add_utm_columns()`, `cutoff` in km, the
  zone-straddle warning shown live — and the detail that makes it stick: the likelihood
  marginally *prefers* the wrong mesh (1136.856 vs 1136.956), so AIC will not catch it.
  I would have copied the degrees version straight into my chapter.
- **Polish.** "which is the point" gone. The false gloss "shared field ⇒ same pattern"
  gone from the prose. The unsigned attenuation-percentage column gone with the table
  that carried it.

---

## 4. Newly introduced, or made worse

### N1. `vignette("isdm-spatial-precision")` does not work

Used twice in the Warbler article as the pointer to the companion. But
`vignettes/articles` is in `.Rbuildignore`, and `tools::pkgVignettes()` on this source
tree lists exactly one vignette: `gllvmTMB.Rmd`. These are pkgdown-only articles. For
any installed user that call errors. My original friction was that the companion was
never named; naming it with a call that fails is a regression in kind. The precision
article's back-reference — plain backticks, "the companion article on mapping
(`isdm-canada-warbler`)" — is the honest form.

### N2. The rescaling section contradicts its own printed output

Prose: "they move by tens of percent **here in opposite directions for the two
species**". Output, in the same section:

```
#> cawa: rank correlation 0.9984, value ratio (wrong/right) 0.538 to 0.942
#> oven: rank correlation 1.0000, value ratio (wrong/right) 0.801 to 0.979
```

Both species move **down**. "Opposite directions" is true of the Block 5 demo, which
the *precision* article cites correctly ("sp2 up, sp1 and sp3 down"); it is not true of
the run displayed here, and the word "here" makes it a claim about this run. Finding a
teaching article contradicted by its own output, in the section teaching the subtlest
point in either article, cost me more trust than the error is worth.

### N3. The two correlation-length guidance bullets pull opposite ways

1. "The recipe is trustworthy when `phi` is under about a tenth of your study region's
   width."
2. "a large returned `phi` is more trustworthy than a small one."

I can only ever observe φ̂. Applied to φ̂ these are contradictory: bullet 1 says small is
trustworthy, bullet 2 says large is. They mean different things — "accurate as an
estimate" versus "reliable as a lower bound" — but a reader acting on them gets
opposite instructions, in the passage that fixes my #1 item.

I tested the failure mode. A perfectly planar covariate — infinite correlation length —
returns **0.388** on a unit-side domain: finite, plausible-looking, silent, no `NA`, no
warning. At true φ = 2.0 on the same domain it returns 0.112–0.305 across seeds, a
3× spread. The rule that actually works is: *if φ̂ exceeds about a tenth of your domain
width, distrust it and treat it as a lower bound only.* Neither bullet says that, and
the stated "±20% (sd 0.041)" precision — measured at φ = 0.25 — will read as general.

### N4. Mild over-correction in the precision article's structure

The first ~100 lines are now arm-size designs, a midpoint rebuttal addressed to "a fair
reader"/"she", and a defence of the article's own previous version. The rebuttals are
useful to me and dead weight to everyone else — a reader who never made the midpoint
objection must read a section arguing against it before reaching the recipe, which is
the most valuable content in either article and now sits in section 9 of 11. Consider
promoting "Get the ratio right first" and demoting the midpoint section to a note.

Otherwise I do not think the fencing has gone too far. The "Scope and limits" list is
doing real work — "Fixed effects only", "One error model", "One bias mechanism" are all
things I would have assumed otherwise. None of it reads as author protection. The
`weights` refusal, the hull warning, and the `re_form` warning are all fences that
*help*: each one told me something I would have got wrong.

---

## 5. Still open from my friction list, unchanged

- **`dev/` paths are still not shipped and still not linked.** `^dev$` remains in
  `.Rbuildignore`. There are now **eleven** references to `dev/isdm-precision/*` across
  the two articles and **one** working hyperlink in either article (issue #1163). Every
  load-bearing citation in both pieces — the simulations, the projection evidence, the
  quadrature-density check, the recovery campaign — points at a path an installed reader
  cannot open. This got worse in volume, not better.
- **`isdm_sources()` naming.** Still never stated that the data column must literally be
  called `isdm_source` and its levels must match the argument names. I tested it: with
  my column called `dataset` it fails, and the error message is genuinely good — it names
  the required column and suggests `attr(family, 'family_var')`. Self-rescuing, so
  friction rather than blocking, but one sentence would still save the round trip.
- **The map is drawn on the `ebird` arm** and the article still never says whether
  choosing `"survey"` would change it — having made a point that the arm label matters
  because `est` mixes scales.
- **`species: placeholder`** still appears in `head(predict(fit), 4)`, still unexplained.
  On my own data I would stop and assume I had mis-specified something.
- **No route to map uncertainty.** "Map-scale uncertainty needs an RE-aware construction
  that does not exist yet" — still no named alternative, not even "a parametric bootstrap
  over the joint precision is the standard approach and is not implemented here". My
  thesis chapter needs a map with uncertainty and I still have nowhere to go.
- **"About the data — read this before reading anything else"** is still `##` nested
  under `# What this shows`, so the most important warning on the page is indented under
  something else in the TOC.

---

## 6. The one change I would make if I could only make one

Add one measured sentence to the biased-arm section, stating the condition that
produces the result and what happens without it:

> The accessibility surface here is measured exactly and included in the model. Give
> it even modest measurement error — sd 0.5 on a unit-scale covariate — and the sign
> of this comparison reverses: integration then moves the slope **toward** truth in 11
> of 12 replicates at fuzz = 1.0. The penalty measured above is what you pay when your
> opportunistic arm's bias is already fully controlled. If it is not, the fuzzed
> structured arm is buying you something this article does not price.

That is the article's own script with one line changed. Without it, the best-evidenced
claim in the pair — the one carrying the figures, the tables, and the "15 of 15" —
points a reader with real data the wrong way. It is the same wrong way I flagged the
first time, and it is still the difference between a student checking their positional
precision (right) and a student throwing away their monitoring data (wrong, and
unrecoverable once the chapter is written).
