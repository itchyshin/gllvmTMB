# Pat's review — `isdm-spatial-precision` and `isdm-canada-warbler`

Read as an ecology PhD student who wants to fuse eBird/GBIF records with a structured
survey. I read only the rendered pages, then opened the two `.Rmd` files to check code
chunks the render hid. I did not read the package internals, the dev log, or the issues.

Both articles are unusually honest about what they do not know, and I want to say that
first because most of what follows is criticism. The precision article in particular is
the sort of thing I wish someone had written before I designed my chapter. But the
honesty is spent in the wrong places: the fences guard against claims I would not have
made, and leave open the two things I would actually have got wrong.

## Direct answers to what you asked

**"errors-in-variables", "attenuation", "correlation length" — which does the damage?**
*Attenuation* is fine; it is glossed in the same sentence ("the estimated slope is biased
toward zero") and I have met it as regression dilution. *Errors-in-variables* is a name
for a thing the previous paragraph already explained, so it costs nothing. **"Correlation
length" does all the damage**, and it does it because it is the one term I have to turn
into a number. Detail in Blocking #1.

**Does the counterintuitive result convince me?** It convinces me that fuzz attenuates the
slope *in the fuzzed arm*. It does not convince me to change what I do with my own data,
because the simulation removed the reason I was integrating in the first place (Blocking
#2) and because the arms are weighted 50/50 in a way the prose contradicts (Blocking #3).
The rhetoric — "The uncomfortable part", "That inverts the premise of the method" — is
pitched a long way above what the design supports. If I had believed it uncritically I
would have dropped my survey arm, which for my data would be the wrong call.

**The map's fences.** In prose, they are as loud as prose gets. But the object that
travels is the PNG, and the PNG says "Canada Warbler", "Ovenbird", "relative intensity",
and shows real Alberta coordinates. Nothing on the image says simulated or says
no-uncertainty. So: I would not screenshot it, having read the page. Someone who lands on
the figure would. Blocking #4.

**Did I register the simulated disclosure?** Yes — the heading "read this before reading
anything else" worked on me. Same caveat as above: it worked on the reader, not on the
artifact.

**Could I adapt either?** No, not without help. The first thing I would try fails.
Blocking #6 and #7.

---

## Blocking confusion

### 1. "Correlation length" is never defined, and it is the only number the article asks me to compute

> "How bad it is depends on one ratio: the positional error relative to the **correlation
> length of the environment**, not its size in kilometres."

> "Compare each arm's positional uncertainty to the correlation length of your covariates
> — a variogram on the raster, not a glance at the map."

I thought: fine, I'll run a variogram in `gstat` and read off the range. My covariate
variogram says range ≈ 40 km. My fuzz is 5.5 km. 5.5/40 = 0.14 → the article says "fuzz
well below the correlation length is benign" → I proceed, reassured.

But the article's own simulation uses "a single smooth **exponential-correlation**
surface", and for an exponential covariance the correlation length is conventionally the
scale parameter φ in exp(−d/φ), whereas what `gstat` and `fields` print as the *practical
range* is roughly 3φ. If the article means φ, my ratio is 5.5/13 ≈ 0.42, which is past the
0.25 where the article says the table "starts biting", and I should be worried instead of
reassured. **A factor of three sits between me and the opposite decision, and the article
never tells me which convention it used, what units the x-axis is in, or how to get the
number out of a variogram fit.**

What would have worked: one sentence with a formula and a worked number. "By correlation
length we mean φ in cor(d) = exp(−d/φ). If you fit an exponential variogram, most software
reports the *practical* range ≈ 3φ, so divide by 3 before comparing. Example: practical
range 40 km → φ ≈ 13 km → fuzz 5.5 km is a ratio of 0.42, in the biting region of the
table." That is three lines and it converts the whole article from interesting to usable.

### 2. The simulated opportunistic arm has no sampling bias — so this is not a test of the decision I face

> "Both arms observe the same landscape and the same truth: counts are generated from the
> environment at each site's **true** location, with a shared slope β = 0.9."

Nothing in the design gives the presence-only arm the defect that makes people integrate:
preferential sampling, road/effort bias, detection bias. `precise_only` is a clean,
unbiased dataset. So the result "adding a contaminated arm to a clean one makes it worse"
is close to arithmetic, and I found myself thinking *of course* rather than *how
uncomfortable*.

The question I actually have is the other one: **my GBIF arm is biased. Does a fuzzed
survey arm still buy me more than it costs?** That is a trade-off between two biases and
the article does not touch it. Worse, it does not say it does not touch it — the "Scope
and limits" list has five items and this, the one that determines whether I keep or drop
my survey data, is not among them.

This also undercuts recommended diagnostic #2:

> "Fit the arms separately first. If the precise-arm-alone and integrated slopes disagree
> materially, that gap is evidence, not noise."

In real data, that gap is evidence of *something* — positional error, or sampling bias, or
detection differences, or a genuine scale difference. The article presents it as a clean
read on positional error because in the simulation it is the only thing varying. Presented
to me as a diagnostic, I would misattribute the gap.

What would have worked: add a sixth scope bullet in the article's own voice — "**The
opportunistic arm here is unbiased.** In practice it is not, and that is why you integrate.
This measures the cost of the fuzzed arm, not the net of cost against benefit. Nothing
here says discard your survey data." And soften "That inverts the premise of the method",
which it does not, quite.

### 3. The two arms are weighted 50/50, which contradicts the article's own setup and is what produces the 40/40

The setup says:

> "a large, messy, presence-only arm (GBIF, eBird) and a **smaller**, structured survey arm"

But the published table says the integrated estimate is the exact arithmetic midpoint of
the two single-arm estimates at every row:

| fuzz | precise | fuzzed | midpoint | integrated |
|---|---|---|---|---|
| 0.00 | 0.895 | 0.910 | 0.9025 | 0.902 |
| 0.25 | 0.902 | 0.579 | 0.7405 | 0.741 |
| 0.50 | 0.907 | 0.403 | 0.6550 | 0.652 |
| 1.00 | 0.902 | 0.216 | 0.5590 | 0.545 |

That is a 50/50 pooling, i.e. equally sized and equally informative arms. If the survey arm
really were "smaller" — say a tenth of the records, which is realistic — the integrated
estimate would sit close to the precise arm and the penalty would be small. **The headline
result is a function of an arm-size choice the article never states and its own framing
contradicts.** Sample sizes per arm appear nowhere in the article.

I worked this out from the table in about two minutes, which means a reviewer will too.

What would have worked: state n per arm, and add a row or a sentence on how the penalty
scales with the arm-size ratio. If the penalty vanishes at 10:1, that is a far more useful
finding than 40/40 and it changes the recommendation from "check before fusing" to "check
before fusing *if the fuzzed arm carries real weight*".

### 4. Neither figure carries its own fence, and the figures are what leave the page

The map fences are excellent as prose:

> "They carry **NO uncertainty**: there is no interval construction behind these values"

and the whole "What this map does not carry" section. But the PNG has two `mtext()` lines
under it already ("open circles: survey locations", "grey cells: outside the mesh hull…"),
so there is an established place to put a third, and no third is put. The image shows two
real species names over real Alberta coordinates and is the single most lift-able object
on either page. Canada Warbler is SARA-listed; a plausible-looking intensity surface for a
listed species is exactly the image that ends up in someone's slide deck.

Same for the precision figure: nothing in the image says simulated, and Panel A with a
"true β = 0.9" line reads as a real measurement to a fast reader.

What would have worked: a third `mtext()` on the map — `"SIMULATED DATA — no uncertainty
shown"` — and a subtitle line on the precision figure — `"simulation; not a measurement on
any real dataset"`. Both cost one line of code and survive the screenshot.

### 5. The article says the intervals get narrower, and also says it makes no claim about intervals

> "so more data yields a worse answer, **with narrower intervals around it**, because the
> model has no way to know that one arm's covariates are mismeasured."

versus, forty lines later:

> "**No coverage claim.** Point estimates only. Whether intervals around these attenuated
> slopes retain nominal coverage is a separate question and is not answered."

The first sentence is the emotional peak of the article — bias *and* false confidence — and
it is the one claim the scope section retracts. I believed it on first read and only caught
it because the fences are good enough to read carefully. If the SEs were recorded (they
must have been, to fit the models), show them; if not, cut the clause.

### 6. `spatial_scalar(0 + trait | coords)` — there is no column called `coords`

```r
mesh <- make_mesh(dat, c("lon", "lat"), cutoff = 0.8)
fit <- gllvmTMB(value ~ ... + spatial_scalar(0 + trait | coords), data = dat, ...)
```

`dat` has `lon` and `lat`. It does not have `coords`. Nothing in the article says that
`coords` is a reserved name that means "whatever you gave `make_mesh()`". My first
adaptation attempt would be `| lon + lat` or `| cell_id`, and I would spend an evening on
it. The article also never says why `spatial_scalar()` rather than `spatial_latent()` or
`spatial_indep()`, and the recap makes it worse by writing "a `spatial_*()` term for the
shared field" as though the choice were free.

What would have worked: one sentence — "`coords` is the reserved grouping name that points
at the mesh you passed; you do not create that column." Plus one clause on why `scalar`.

### 7. The example's data shape is the one shape real integrated data never has

Every one of the 120 cells carries a count row *and* a detection row, for both species, at
identical coordinates, sharing a `cell_id`. Real arms are at different places and share
nothing. My eBird rows and my ABMI rows have disjoint coordinates and no common unit.

Two consequences I cannot resolve from the article:

- **May the arms occupy different locations, with non-overlapping `cell_id`?** The article
  never says. This is the first structural question anybody adapting it has.
- **The opportunistic arm here is Poisson counts.** The article motivates it with "GBIF
  holds ~4,200 coordinate-bearing Alberta records" and points me at `rgbif` — and GBIF
  returns *presences only*. There is no `value` column to make. Real presence-only iSDMs
  need background/quadrature points and a point-process construction, which is not
  mentioned anywhere. So the first thing I would actually try — pull my GBIF records,
  build `dat` — dead-ends before the model call, in an article titled "end to end".

What would have worked: a short paragraph — "the arms need not share locations; here they
do only to keep the example short" — and an explicit statement that turning presence-only
records into a `value` column (thinning, background points) is out of scope, with a pointer
to whichever other article covers it.

### 8. The grid chunk contains a copy-paste-ready covariate-scaling bug

Training:

```r
env <- as.numeric(scale(sin(lon / 2) + cos(lat / 3)))
```

Prediction grid:

```r
g0$env <- as.numeric(scale(sin(g0$lon / 2) + cos(g0$lat / 3)))
```

These are standardised against **different** means and SDs — 120 scattered points versus a
30×30 regular grid. The fitted slope is on the training scale and the map evaluates it on
the grid's scale. This is the single most common newdata mistake in the field and the
article ships it in the chunk a reader will copy. It is also a strange thing to find in a
package whose companion article is entirely about reading covariates on the wrong scale.

What would have worked: compute the raw covariate, then apply the *training* centre and
scale to both — `mu <- mean(raw); s <- sd(raw)` once, reused — with a comment saying why.

### 9. `grid$cell_id <- factor(cells[1], levels = levels(dat$cell_id))`

Every grid row is assigned to cell `c1`. I stared at this for a while. `cell_id` is the
`unit =` argument, so it plausibly carries something estimated. Does my whole map inherit
one cell's unit-level effect? Or is the column required-but-ignored for `newdata`? The
article says nothing, and the comment on the neighbouring line (`grid$value <- 0 #
placeholder`) proves the author knows these dummy columns need explaining.

If it is harmless, say "required by the design matrix, not used in the prediction". If it
is not harmless, the map has a problem. Either way I cannot tell, and I would not trust a
map I could not tell about.

### 10. "Until recently `predict(newdata = )` silently dropped the spatial field" — which version?

> "Until recently `predict(newdata = )` silently dropped the spatial field, so a map drawn
> from it showed a field-free surface while claiming the field. That is fixed"

I install from CRAN. Is my version fixed? "Until recently" does not tell me, and this is a
silent-wrong-answer bug — the worst kind, because my map will look fine. I need a version
number and ideally a one-liner to check.

### 11. The SPDE mesh is built in unprojected longitude/latitude

```r
mesh <- make_mesh(dat, c("lon", "lat"), cutoff = 0.8)
```

`cutoff = 0.8` degrees over 49–60° N is about 89 km north–south and about 48 km east–west
at 55° N. The mesh, and therefore the estimated range, is anisotropic for a purely
cartographic reason. The article *knows* this — it computes `asp <- 1 / cos(mean(lat) *
pi / 180)` with the comment "degrees of longitude are shorter" — but applies the correction
to the picture and not to the model.

I would copy this straight into my own analysis without a second thought, because the
article did it. And it interacts badly with the companion article, which is about spatial
distances in kilometres: I cannot compare "5.5 km fuzz" to a `cutoff` measured in degrees.

What would have worked: project to an equal-area CRS before meshing, or one sentence
saying "for a real analysis, project first; degrees are used here only to keep the example
dependency-free".

---

## Friction

- **`dev/isdm-precision/precision-sim.R` is not in the installed package and is not
  linked.** "The simulation is in `dev/isdm-precision/precision-sim.R`." I checked:
  `^dev$` is in `.Rbuildignore`, so `system.file()` will not find it. There is no
  hyperlink anywhere in either rendered page. Since the whole precision article is
  `echo = FALSE` and shows me *no code at all*, this path is my only route to reproducing
  or adapting the result, and it is a dead end unless I guess that I should go browse
  GitHub. Make it a link.

- **The precision article contains no `gllvmTMB` code.** Not one function call. I cannot
  see what model was fitted, what formula, whether `isdm_sources()` was involved, or how
  "integrated" was specified. "Treat this article as a reason to measure your own case" —
  with what? Even a five-line sketch of the fit call would let me start.

- **"a companion article" is never named or linked, in either direction.** The Warbler
  article says "the subject of a companion article" and "see the companion article on
  spatial-precision mismatch"; the precision article never mentions the Warbler one. No
  titles, no links, in either rendered page. I have to search the pkgdown index and guess.
  There are also five other `integrated-*` / `gbif-*` articles in the same folder, and
  neither of these tells me where it sits among them or which to read first.

- **No `summary(fit)` anywhere in an article called "end to end".** The code comment calls
  `bt <- c(0.8, 0.4)` "the estimand of interest" and the article never shows an estimate of
  it. The data are simulated with known truth, so a two-line recovery check — did
  `trait:env` come back near 0.8 and 0.4? — is nearly free and is the most reassuring
  thing the article could show. Instead the only success signal is `fit$opt$convergence
  #> [1] 0`, which reaches into the object's guts and tells me nothing about whether the
  answer is right.

- **`species` prints as `placeholder`.** In `head(predict(fit), 4)` there is a column
  `species` whose every value is `"placeholder"`. Unexplained. On my own data I would stop
  and assume I had specified something wrong.

- **Recommendations 3 and 4 are not measurements, but sit under a heading that says they
  are.** "What the measurement supports:" is followed by four items, of which "Aggregate
  to the fuzz scale" and "Ask for the precise coordinates" are reasoning, not results.
  Aggregating also silently changes the estimand — the slope on a 5.5 km-smoothed raster
  is not the slope on a 30 m raster — and the article only notes the half of that cost
  that is about signal ("it costs the fine-scale signal"). In an article this careful about
  fences, the unmarked mixing of measured and reasoned advice stands out.

- **`isdm_sources(ebird = ..., survey = ...)` — the names must match the factor levels of
  `isdm_source`.** Implied by the example, never stated. This will fail for someone whose
  column is called `dataset` or whose levels are `"GBIF"`/`"BBS"`, and the error message is
  not shown here so I cannot tell whether it will be a helpful one.

- **The map is drawn on the `ebird` arm and the article never says whether that matters.**
  `grid$isdm_source <- factor("ebird", ...)`, while the article has just made a point of
  telling me the arm label matters because "on the response scale `est` mixes scales by
  construction". So: would setting `"survey"` give me a different map? (I believe it shifts
  the surface by a constant and, on a relative map, does not matter — but the article
  raised the question and then left it.)

- **"Map-scale uncertainty needs an RE-aware construction that does not exist yet."** Good
  and honest. But my thesis chapter needs a map with uncertainty, and the article leaves me
  with nowhere to go. Even "there is no workaround in this package; a parametric bootstrap
  over the joint precision is the standard approach and is not implemented here" would let
  me plan.

- **The fences arrive after the figure.** "What this map does not carry" is roughly forty
  lines below the map. The caption does carry the NO-uncertainty sentence, which helps, but
  the strongest number (coverage 0.23–0.82) is far downstream of the picture it qualifies.

---

## Polish

- **"the integrated fit sits between them, which is the point."** I read this twice. The
  point of the article, or the point of integration? Given the surrounding sentences argue
  that sitting between them is *bad*, "which is the point" reads at first as approval.

- **"The two species differ in amplitude, not in pattern, which is what a single shared
  field implies."** Two problems. First, the eye disputes it: Ovenbird's darkest region is
  around −115.5, 56.3 and Canada Warbler's low is a band nearer −116.5 running south, so I
  spent a minute deciding whether I was looking at the wrong thing. Second, and more
  damaging, the causal gloss is wrong as a lesson: a shared field does *not* imply a shared
  pattern. The two species share the pattern here because they *also* share `env` and
  because their two coefficient ratios happen to be close (0.8/0.9 versus 0.4/0.5). Change
  one species' environmental slope and the patterns diverge with the same shared field. A
  student will carry away "shared field ⇒ same map up to scaling" and be wrong about their
  own fit.

- **Heading levels.** "About the data — read this before reading anything else" is an `##`
  nested under "What this shows", so in the TOC the most important warning on the page is
  indented under something else. Make it a top-level section; it earns it.

- **`fit$opt$convergence`** as the advertised success check reaches into the object. If
  there is a `check_*()` or a `summary()` line that means "this fit is fine", use that
  instead; if there is not, a sentence saying `0` means converged would help.

- **The precision article's percentages are unsigned in the direction column.** "0.895
  (0.6%)" for a value *below* 0.9 and "0.910 (−1.2%)" for one *above* — so the sign
  convention is attenuation-positive. It is consistent, but I had to derive it, and the
  header says only "with attenuation as a percentage of truth".

---

## What I would have to look up, and whether the article tells me where

| I would have to look up | Does the article point me anywhere? |
|---|---|
| What "correlation length" means numerically, and how to get it from a variogram | No — one bare mention of "a variogram" |
| Whether `coords` is a reserved name | No |
| What `spatial_scalar` is versus `spatial_latent` / `spatial_indep` | No |
| What `trait =` and `unit =` do | No |
| How to turn GBIF presence-only records into a fittable arm | No |
| Which version fixed the `predict(newdata=)` field bug | No |
| Whether to project coordinates before `make_mesh()` | No |
| What the companion article is called | No |
| Where `dev/isdm-precision/precision-sim.R` is | Named, but not shipped and not linked |
| How to put uncertainty on a map | Told it is impossible here; no alternative named |

Nine of ten dead-end. For an article pair meant to be *the* thing a student reads before
building an iSDM, that is the headline finding: the prose is careful and the exits are not
signposted.

---

## The one change I would make if I could only make one

Add the missing scope bullet to the precision article — **"the opportunistic arm here is
unbiased, which is not why you integrate; this measures a cost, not a net"** — and state
the per-arm sample sizes. Everything else on this list is a paper cut. That one is the
difference between a student checking their positional precision (right) and a student
throwing away their monitoring data (wrong, and unrecoverable once the chapter is written).
