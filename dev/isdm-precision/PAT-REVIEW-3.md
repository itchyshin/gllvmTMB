# Pat's third review — `isdm-spatial-precision` and `isdm-canada-warbler`

Round 3, on the revised articles. As before I checked by running things, not by
reading `REVIEW-2-RESPONSE.md`. Both articles render clean from source (10 s and
15 s). Every number below is one I measured in this worktree.

I got one of my own round-2 blockers wrong, and the article believed me. That is
the most important thing in this review, so it is item B3 and it is not buried.

---

## 1. Verdict

**Yes-but.**

I could now take these two articles and fit an integrated SDM to my own data. The
one question I actually brought — *do I keep my fuzzed ABMI arm?* — is now
answered, correctly, in a section I would reach. That was B2, my "if I could only
make one change" item, and it is genuinely fixed. B1 is close. N1 and N2 are
fixed.

The "but" is smaller than last time but it is sharper in kind. One section now
tells me a fault exists where I have measured that none does, and hands me a
mechanism to go chase. Two chunks I would copy do the wrong thing silently. None
of those stop me fitting the model; all three would cost me days.

---

## 2. My four round-2 blockers

| | item | status |
|---|---|---|
| **B1** | `cor_length()` unusable on a raster | **partly** |
| **B2** | headline inverts under realistic surrogate error | **fixed** |
| **B3** | presence-only prints a failed recovery as a pass | **not fixed — now wrong in the other direction** |
| **B4** | `d = 1` never justified | **partly** |

---

### B2 — fixed. Take the credit for this one.

This was my #1 ask and the fix is real. `evidence-bias-surrogate-error.R`
reproduces the article's table to the digit on my machine:

```
independent + modelled exactly   precise 0.918  integ 0.806  | helped  3/12
confounded rho=0.7, exact        precise 0.910  integ 0.812  | helped  0/12
confounded, surrogate sd 0.5     precise 1.192  integ 1.083  | helped 11/12
confounded, not modelled         precise 1.722  integ 1.577  | helped 12/12
```

The section is headed imperatively, sits before the conclusion sections, carries
my fair addition (in the reversal regime *nothing* recovers truth), and ends with
the sentence I needed: *"positional precision is a cost you should measure, not a
reason to discard a structured arm."* Reading linearly, I would now keep my ABMI
arm and go measure my fuzz-to-φ ratio. That is the right answer and I would not
have got there from round 2.

Three places still carry the un-conditioned claim, and they are the three places a
reader meets first. I am listing them as **S1** below rather than reopening B2,
because the substance is fixed and this is consistency, not evidence.

### B1 — partly. The fatal half is fixed; two things remain.

**Fixed, and I checked:** `n_sub` genuinely solves the scaling problem. On a
300 × 300 covariate raster (90,000 cells) the whole thing now runs in **0.33 s**.
The subsample is accurate — over 8 draws against a full-raster answer of 0.1276:

| `n_sub` | mean | sd |
|---|---|---|
| 2000 | 0.1283 | 0.0053 |
| 1000 | 0.1263 | 0.0084 |
| 500 | 0.1271 | 0.0089 |
| 200 | 0.1241 | 0.0266 |

The article's "±0.007 at 500–2,000 cells" holds. The `terra::aggregate()` warning
is in, worded correctly, and is the thing that would have saved me.

**Not fixed — the step I actually get stuck on.** I have a `SpatRaster`. The
article's action step 1 still says *"Use the recipe above on your own raster."* I
did exactly that:

```
cor_length(r)
#> Error: argument "y" is missing, with no default
```

That message does not tell me what to do. The bolded fence — *"Do not hand this a
whole raster"* — reads as *this function cannot take raster data*, when the truth
after `n_sub` is the opposite: it can take every cell, it just needs them as
vectors. The one line I asked for in round 2 is still not there:

```r
r <- as.data.frame(x, xy = TRUE, na.rm = TRUE)   # SpatRaster -> x, y, z
phi <- cor_length(r[[1]], r[[2]], r[[3]])
```

With that line I got φ = 27.0 km on a 600 km domain in a third of a second.
Without it I was reading `?dist`.

**Newly introduced by this fix — see N1 below.** `set.seed()` inside the function.

### B3 — not fixed, and it is now wrong rather than silent. My fault as much as theirs.

**I was wrong in round 2 and I need to say so first.** I reported that the
quadrature ladder "stops moving 11% and 22% from truth" and concluded the
estimator was materially biased. Every row of my ladder was run on **seed 21** —
the same presence realisation — so of course they agreed with each other. I
mistook a fixed random draw for a converged estimate. My round-2 B3 diagnosis was
an artefact of my own single-seed test, and the article took it seriously and
wrote it up.

**What is actually true.** At the article's exact shipped settings
(`nfine = 60`, `nq = 60`), over **30 seeds**:

| | truth | mean | sd across seeds | 95% CI | t vs truth |
|---|---|---|---|---|---|
| cawa | 0.8 | 0.8188 | 0.1027 | [0.782, 0.856] | t = 1.00, p = 0.325 |
| oven | 0.4 | 0.4099 | 0.0975 | [0.375, 0.445] | t = 0.56, p = 0.583 |

**The recipe is unbiased.** The printed 0.687 / 0.291 is seed 21 sitting **−1.29
and −1.21 sd** below the mean — an ordinary draw. Across seeds cawa ranges 0.656
to 1.033. With 160 presences, `1/sqrt(160) = 0.079` is the back-of-envelope
standard error, against a measured 0.103. There is nothing to explain.

**And the mechanism the article now asserts is not the mechanism.** It says the
presences are snapped to the `nfine` lattice, that this is positional error, and
that raising `nfine` moves the estimates. I tested all three, 12 seeds each:

| | cawa bias | oven bias |
|---|---|---|
| shipped (nfine 60) | +0.4% | +7.7% |
| nfine 150 | −0.1% | −9.7% |
| nfine 300 | −5.5% | −9.8% |
| **presences jittered within their cell (real positional error added)** | **+0.5%** | **+2.1%** |

Raising `nfine` does not help — at 300 it is worse. And *adding* genuine
positional error, by jittering each presence inside its cell and re-reading `env`
at the displaced point, changes essentially nothing. It cannot be
errors-in-variables: in this simulation the presence's `env` is read at the very
node whose intensity generated it, so there is no mismatch to attenuate.

So the section now: prints a fluctuation, tells me in bold to **"Read that error
before you copy the recipe"**, calls it *"the most instructive thing in this
section"*, invents a cause, attributes that cause to the companion article, and
builds *"stability is not accuracy"* on top of it. Round 2 was a silent wrong
pass. This is a loud wrong fail, and for a teaching article that is worse: I would
now go audit my GBIF records' coordinate provenance for a defect that is not
there, when the answer is "you have 160 presences."

**The fix is the one the rest of this arc already applies everywhere else:** run
more than one seed. Fifteen replicates and an se, exactly as the precision
article does in every one of its cells. Then the honest lesson is the genuinely
useful one — *on one seed a slope will swing ±0.1; that is your standard error,
not your model* — and the coordinate-rounding advice can stay as general advice
without being sold as the diagnosis of a fault.

"Stability is not accuracy" is a true and valuable sentence. It just needs a case
where it is true.

### B4 — partly. Better than round 2, and the part I most needed still fails at my P.

**Real gains.** `d` is now defined as a rank, the default is justified, and the
loadings chunk runs (the `lambda_spde` → `theta_rr_spde_lv` fix landed). I checked
the guard rails: with 2 species `d = 3` errors loudly and correctly
(*"loading rank must be between 1 and the number of rows"*), so I cannot silently
overfit. And the article's stated tell is right at 2 species — `d = 2` gives an
objective identical to `d = 1` to three decimals (437.821) with a zero second
column.

**Where it fails, which is exactly my case.** I simulated 12 species with a
**true rank of 2**:

| | AIC | rms loading per column |
|---|---|---|
| d = 1 | 8228.32 | 0.0237 |
| **d = 2** | **7694.98** | 0.0236 · 0.0148 |
| d = 3 | 7714.39 | 0.0239 · 0.0117 · 0.0112 |
| d = 4 | 7732.39 | 0.0232 · 0.0116 · 0.0064 · **0.0140** |

Two things follow. **AIC gets it exactly right** — it picks d = 2, the truth. The
article withdraws AIC (*"makes no claim about `AIC` being calibrated for this
comparison"*) after naming "a real improvement in fit" as the criterion, which
leaves me with a criterion and no instrument. **And the tell the article does
give me fails.** "Extra dimensions tend to arrive with near-zero loadings" is true
at P = 2 and false at P = 12: there is no cliff, and at d = 4 the fourth column
(0.0140) is larger than the third (0.0064). If I had followed the article's advice
I would have kept raising `d`.

**The loadings are also on no stated scale.** The article's own fit prints
`cawa 0.0515, oven 0.0009` against true simulated loadings of 0.9 and 0.5, and
tells me to "compare those two numbers" with no reference for what counts as
small. I worked out what they mean by differencing `predict()` against
`predict(re_form = ~0)`:

```
cawa : field contributes sd 0.309 to eta  ->  7.6% of eta variance
oven : field contributes sd 0.005 to eta  ->  0.0% of eta variance
```

So in the article's own headline fit the shared field does **nothing** for one of
the two species — the Ovenbird map is `intercept + slope × env`. The article
half-concedes this in the map section ("a structural fact rather than the reason
the two surfaces resemble each other"), which is fair, but it never states it, and
the section title is still *"Two arms that share no location still share one
field."* Those four lines of `re_form = ~0` are the diagnostic I need at 12
species and they are the ones not shown.

**Still untouched:** my round-2 question *"when would I want `spatial_indep()`
instead?"* `spatial_indep`, `spatial_dep`, `spatial_scalar` and `spatial_unique`
are all exported. With 12 species that is a live choice — 12 independent fields
versus k shared ones — and neither article mentions it exists.

---

## 3. Still blocking, numbered

**S1. The un-conditioned claim survives in the three places read first.** B2's fix
is real but does not propagate:

- The precision article's `description:` (the pkgdown card, the search result):
  *"the penalty survives across arm-size designs and a biased opportunistic arm."*
- **"The uncomfortable part"**, which sits *after* the reversal section, restates
  the cost at full strength — "15 of 15", *"inverts the premise of the method"* —
  with no back-reference. Read linearly I get the correction and then get it
  un-corrected by the most rhetorically loaded section in the pair.
- The Warbler article, item 1 of "About the data", labelled **"the short
  version"**: *"integrating a fuzzed arm can leave you further from the truth than
  discarding it."* That is the sentence a reader carries away, and the Warbler
  article is the one I would open first — it has the map.

One clause in each of the three. Otherwise B2 is fixed everywhere except where it
is read.

**S2. B3 as above** — the section teaches a defect that is not there.

**S3. The raster→vector line for `cor_length()`** — B1's remaining half.

**S4. No scale for the loadings, and no `d` criterion that survives to 12
species** — B4's remaining half, plus `spatial_indep()`.

**S5. N3 from round 2 is unchanged and was not in the response document.** The two
guidance bullets still pull opposite ways as applied to the only quantity I can
observe: "trustworthy when `phi` is under about a tenth of your region's width"
versus "a large returned `phi` is more trustworthy than a small one." And the
silent failure I reported is still silent — a perfectly planar covariate, φ = ∞,
returns **0.3885** on a unit domain with no `NA` and no warning. The article's own
domain table is also non-monotone (0.89, 1.02, 0.82, 0.63), so "the error is
always downward" is not quite what the table shows. The rule that works, and
that neither bullet states: *if φ̂ exceeds about a tenth of your domain width,
treat it as a lower bound only.*

---

## 4. Newly worse

**N1. `cor_length()` now silently resets the caller's RNG.** Introduced by the B1
fix. `set.seed(seed)` inside the function sets the *global* seed:

```
set.seed(99); rnorm(1)                          #>  0.2139625
set.seed(99); junk <- cor_length(x, y, z); rnorm(1)   #>  1.512686
```

In a copy-paste recipe placed at the top of a workflow, every random thing
downstream — a bootstrap, a train/test split, a simulation — is silently reset to
seed 1's stream, and reproduces identically across calls. This is precisely the
class of bug both articles exist to warn about: *something quietly means a
different thing at two points in the workflow, and nothing warns.* Two-line fix:
`old <- .Random.seed` / `on.exit(...)`, or `withr::with_seed()`, or just
`sample.int(length(x), n_sub)` with the seed left to the caller.

**N2. The B4 loadings chunk silently mislabels at any `d > 1`.** The reduced-rank
constraint means the parameter vector is `P*d − d(d−1)/2`, not `P*d`: for P = 12
that is 12, 23, 33, 42. The chunk is `setNames(..., spp)`. Copied at d = 2 with 12
species:

```
   sp1    sp2  ...   sp12   <NA>   <NA>   <NA> ...
0.7185 0.5589      0.5034 0.0049 0.4217 0.7243
```

No error, no warning — twelve names pasted onto twenty-three numbers, so **every
label after the first column is wrong** and the rest are `NA`. This is in the
section written to answer B4, i.e. the section aimed squarely at readers with more
than two species. It is the single thing in either article I would most likely
copy and misread.

**N3. A cross-reference that over-promises.** The precision article sends me to
the Warbler article for *"within-species rank correlation exactly 1.000"* and
*"up to 5.5× in opposite directions for different species."* What the Warbler
article shows is 0.9984 / 1.0000, both species down, max 1.86×. The 5.5× figure
lives in `READER-BLOCKS.md` Block 5, which I cannot open. Minor, but I went
looking for numbers that were not there.

**N4. Small.** *"On the response scale `est` mixes scales by construction"* sits
under output showing negative values — `predict()` defaults to the link scale. The
point is right (cloglog and log are different links too); the sentence names a
scale the reader is not looking at.

---

## 5. Over-correction? No.

I flagged this risk in round 2 and I want to answer it honestly: it has not
happened. Both articles grew ~13% (574→650 and 732→828 lines). The added fencing
is all load-bearing — the `weights` refusal, the hull warning, the `re_form`
warning, the "Scope and limits" list, the reversal section — and each one told me
something I would have got wrong. Nothing reads as author protection.

My structural complaint stands unchanged and unfixed, and the response document
says so: **"Get the ratio right first" is the most useful content in either
article and sits at line 468 of 650**, behind a rebuttal of an objection I did not
make. Promote it; demote the midpoint section to a note.

Unchanged friction, all previously acknowledged: 13 `dev/isdm-precision/*`
references against one working hyperlink (`^dev$` is still in `.Rbuildignore`);
`isdm_sources()` column/level naming still unstated, still self-rescuing via a good
error message; `species: placeholder` still printed and still unexplained; "About
the data — read this before reading anything else" still nested at `##` under
"# What this shows"; still no route to map uncertainty.

---

## 6. Publish as-is?

**Not quite — but the gap is small and specific.**

I would publish after four changes, three of which are one line each:

1. **Fix B3.** Run the presence-only recovery over ~15 seeds and report the mean
   and se. The current section teaches a defect that is not there and sends
   readers to audit their coordinate provenance for it. This is the only item I
   would call a genuine barrier to publication, and it is my error as much as the
   author's.
2. **`withr::with_seed()` or an `on.exit()` restore in `cor_length()`.** A silent
   global RNG reset in a recipe readers are told to copy.
3. **The `setNames()` chunk** — either guard it or say it is `d = 1` only.
4. **Three clauses for S1** — the `description:`, one back-reference in "The
   uncomfortable part", and "the short version" in the Warbler article.

Everything else on my list is improvement, not correction, and I would not hold
publication for it.

To be clear about where this has got to: B2 was the item that mattered, and it is
fixed. On round 1 the first thing I tried failed. On round 2 I could fit the model
but would have thrown away my monitoring data. On round 3 I would fit the model,
keep the ABMI arm, and go measure my fuzz-to-φ ratio — which is the correct
sequence of decisions. What is left is three copy-paste hazards and one section
that needs a second seed.
