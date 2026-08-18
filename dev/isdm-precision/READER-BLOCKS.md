# Drop-in blocks for the article rewrites (S3/S4)

Each block below is **measured**, not asserted. The measurement script and its
output are named so a reviewer can re-run them.

---

## Block 1 — the operational correlation length (Pat blocking #1)

**The problem.** The article's only reader-computed number is "the correlation
length of your covariates", and the phrase is ambiguous by a factor of three.
For an exponential correlation `exp(-d / phi)` some software reports `phi` and
some reports the *practical range* ~ `3 * phi` (the distance at which
correlation falls to 0.05). Pat: practical range 40 km gives a ratio of 0.14
and "benign, proceed"; `phi` ~ 13 km gives 0.42 and "in the biting region".
**A factor of three sits between the reader and the opposite decision.**

**The fix: define it so no convention is involved.** `phi` is the distance at
which the covariate's own correlation falls to **1/e = 0.368**. That is
computable from the raster and does not depend on what any package calls
"range".

```r
## phi = distance at which the covariate's correlation falls to 1/e.
cor_length <- function(x, y, z, n_bin = 30) {
  d   <- as.matrix(dist(cbind(x, y)))
  cp  <- outer(z - mean(z), z - mean(z)) / var(z)
  ut  <- upper.tri(d)
  brk <- seq(0, quantile(d[ut], 0.5), length.out = n_bin + 1)
  rho <- tapply(cp[ut], cut(d[ut], brk, include.lowest = TRUE), mean)
  h   <- (brk[-1] + brk[-length(brk)]) / 2
  ok  <- !is.na(rho)
  approx(rho[ok], h[ok], xout = exp(-1))$y
}
```

**Verified against known truth** (`/tmp/corlen_check.R`, 6 surfaces per row,
exponential surfaces with `phi` set by construction):

| true `phi` | recipe returns | sd over 6 surfaces |
|---|---|---|
| 0.10 | 0.102 | 0.046 |
| 0.25 | 0.205 | 0.041 |
| 0.40 | 0.253 | 0.049 |

**And its limit, measured** (`/tmp/corlen_check2.R`). The bias depends only on
`phi` relative to the **domain side**, and is identical at side 1 and side 4 —
so it is a finite-extent artefact, not a units artefact:

| `phi` / domain side | recipe / true `phi` |
|---|---|
| 0.05 | 0.89 |
| 0.10 | 1.02 |
| 0.25 | 0.82 |
| 0.40 | 0.63 |

**Two things the reader needs told:**

1. The recipe is trustworthy when `phi` is under about a tenth of your study
   region's width. Above that it **underestimates**, because a correlation
   longer than your map cannot be seen on your map.
2. The error is **always downward**, so `fuzz / phi_hat` is biased *upward* and
   the recipe errs toward "check this more carefully". For this article's
   decision that is the safe direction — but it means a large returned `phi`
   is more trustworthy than a small one.

Also: a single raster gives `phi` to roughly +/-20% (sd 0.041 at `phi` = 0.25).
Do not read the third significant figure.

---

## Block 2 — the `coords` token is inert (Pat #6; now issue #1163)

Measured this session on a live fixture: `spatial_scalar(0 + trait | coords)`
has **no column named `coords`** in the data, and the token is ignored
entirely.

| RHS token | logLik |
|---|---|
| `coords` | -63.01954 |
| `banana` | -63.01954 |
| `xy`     | -63.01954 |

Identical to eight significant figures. All spatial information enters through
`mesh =`. Filed as **#1163** — this is the silent-fallback class (#1132,
#1120, #1119, #1083): the dangerous case is a reader writing
`spatial_scalar(0 + trait | site)` with a real column and a real intention,
and getting it silently ignored with no warning.

**For the article:** say in one sentence that the grouping token on a
`spatial_*` term is not read, and that the mesh carries the geometry. Do not
present `| coords` as if it referred to something.

---

## Block 3 — version number for the "silently dropped" claim (Pat #10)

The SPDE-drop-on-`newdata` defect is fixed in **gllvmTMB 0.7.0 (development)**.
Replace "until recently" with the version, so a reader can check their own
install rather than guess what "recently" means.

---

## Block 4 — delete the interval claim (Pat #5)

`isdm-spatial-precision.Rmd` currently says integration gives "a worse answer,
with narrower intervals around it", and then states under Scope: "**No coverage
claim.** Point estimates only." The first sentence is an interval claim the
design does not support. Cut the clause; the point-estimate result stands on
its own and is the stronger statement.

---

## Block 5 — the newdata rescaling bug is INVISIBLE (Pat blocking #8)

Both articles `scale()` `env` in the training data and then `scale()` it again
on the prediction grid. Because the grid covers a different slab of landscape,
`scale()` re-centres on the *grid's* moments and the fitted coefficients are
applied to a covariate that no longer means what it meant at fit time. Pat
calls this "the single most common newdata mistake in the field", and we ship
it in a chunk a reader will copy.

**Measured** (`/tmp/scalebug.R`; 3 species, Poisson, training env raw
mean 1.97 / sd 1.34, grid env raw mean 3.13 / sd 0.91 — an ordinary
train-on-a-region, predict-on-a-map setup):

| species | within-species rank correlation | median abundance ratio | worst fold error |
|---|---|---|---|
| sp1 | **1.0000** | 0.504 | 4.2x |
| sp2 | **1.0000** | 1.537 | 2.5x |
| sp3 | **1.0000** | 0.441 | 5.5x |

**Why this matters more than an ordinary bug.** The within-species rank
correlation is *exactly* 1. The affine error preserves order perfectly, so:

- every hotspot is still a hotspot, in the same rank order;
- the map looks completely normal;
- nothing warns;
- but predicted abundance is off by up to **5.5x**, and **in opposite
  directions for different species** (sp2 up, sp1 and sp3 down), so there is
  not even a common offset a reader could notice.

The bug is invisible to every check a reader would actually perform, and it
corrupts precisely the quantity a prediction map exists to report.

**The fix, and it must carry a comment saying why:**

```r
## Centre and scale ONCE, on the training data, and reuse those two numbers.
## scale()-ing the grid on its own moments silently refits the covariate's
## meaning: the map's PATTERN survives (rank correlation 1.000) while the
## predicted values move by up to 5.5x. Nothing warns.
mu_env <- mean(train$env_raw); sd_env <- sd(train$env_raw)
train$env <- (train$env_raw - mu_env) / sd_env
grid$env  <- (grid$env_raw  - mu_env) / sd_env
```

---

## Block 6 — presence-only IS reachable; the fence was too pessimistic (Pat blocking, item A2)

Pat's first real step dead-ended: the Warbler article motivates the arm with
GBIF records, points at `rgbif`, and then fits **Poisson counts** — but GBIF
returns *presences*, and there is no `value` column to make. The plan assumed
this was out of scope. **It is not.**

`gllvmTMB()` accepts `weights =`, and for non-binomial families interprets it
as a per-observation likelihood weight. That is exactly what the Berman-Turner
quadrature device needs (Warton & Shepherd 2010; Renner et al. 2015): fit the
inhomogeneous Poisson process as a **weighted Poisson GLM** with

- presence rows: weight `w` tiny, response `y = 1/w`
- quadrature (background) nodes: weight `w` = cell area, response `y = 0`

**Measured** (`/tmp/po_quad.R`, 2 species, 5 seeds, 5/5 converged):

| species | true slope | mean estimate | sd over seeds |
|---|---|---|---|
| A | 1.10 | 1.110 | 0.093 |
| B | -0.70 | -0.641 | 0.065 |

**Quadrature density is the knob, and it is checkable** (`/tmp/po_quad2.R`,
same 5 seeds at each density, so the comparison is paired):

| quadrature nodes | est A | est B | bias A | bias B |
|---|---|---|---|---|
| 900 (30x30) | 1.144 | -0.659 | +0.044 | +0.041 |
| 3,600 (60x60) | 1.143 | -0.698 | +0.043 | +0.002 |
| 10,000 (100x100) | 1.142 | -0.715 | +0.042 | -0.015 |

Read this carefully rather than triumphantly. With 5 seeds the Monte-Carlo SE
of each mean is about **0.04**, so species A's flat `+0.042` is **within noise
and is not evidence of bias** — and it does not move with density, which is the
point. Species B's estimate *does* move monotonically toward truth and settles
by 3,600 nodes; because the seeds are paired across densities, that movement is
the informative quantity, not the level.

**The operational advice, with a number.** Increase quadrature density until the
estimates stop moving — the standard diagnostic. Here they stabilised at 3,600
nodes against roughly 180 presences per species, i.e. about **20 quadrature
nodes per presence**. That is a starting point to check, not a rule.

**The fence, and it is the package's own.** `gllvmTMB()` warns on non-unit
weights that this is a weighted objective, so `logLik()`, AIC/BIC, and ordinary
Hessian/Wald intervals are **not validated** for such a fit. Point estimates
are what this route delivers. Quote that warning in the article rather than
paraphrasing it — it is exactly the right fence and it arrives automatically.

---

## Block 7 — the midpoint objection is right about the DESIGN and wrong about the RESULT (Pat blocking #3)

Pat's objection: with arms weighted 50/50 the integrated estimate is the exact
midpoint of the two single-arm means at every fuzz level, so the article's
headline is arithmetic rather than a finding. **Tested directly**
(`/tmp/unequal.R`, 15 replicates per cell, same estimator as the article):

| design (precise / fuzzed) | fuzz | integrated - precise | replicates hurt | distance from exact midpoint |
|---|---|---|---|---|
| 220 / 220 | 0.5 | -0.279 | 15/15 | **0.023** |
| 220 / 220 | 1.0 | -0.376 | 15/15 | **0.041** |
| 400 / 100 | 0.5 | -0.105 | 15/15 | 0.149 |
| 400 / 100 | 1.0 | -0.155 | 15/15 | 0.197 |
| 100 / 400 | 0.5 | -0.438 | 15/15 | 0.165 |
| 100 / 400 | 1.0 | -0.567 | 15/15 | 0.215 |

**She is right about the design.** At 220/220 the integrated estimate sits
within 0.023-0.041 of the exact midpoint — close enough that the result reads
as averaging, which is a fair thing to distrust. The midpoint identity is an
artefact **of the balanced design specifically**: at 400/100 and 100/400 the
gap is 0.149-0.215 and the identity is gone.

**She is wrong that the claim depends on it.** The penalty survives in every
design, including the one most favourable to integration — a fuzzed arm of
only 100 rows against 400 precise rows still loses in **15 of 15** replicates.

**And the rebuild makes the evidence stronger, not weaker.** The penalty now
shows a clean dose-response in the fuzzed arm's weight
(-0.105 -> -0.279 -> -0.438 at fuzz 0.5 as that arm goes from 100 to 220 to
400 rows), which is what the attenuation mechanism predicts and what a pure
averaging artefact could not produce. The `fuzz = 0` control holds in all
three designs (6, 9 and 8 of 15 below zero — a coin flip, as it must be).

**Article consequence.** Replace the single balanced cell with the three-design
table, state n per arm explicitly (Pat's other half of #3), and lead with the
dose-response rather than the midpoint comparison.

**NOT established here.** This is still an *unbiased* presence-only arm. How
the penalty behaves when the PO arm carries accessibility-driven sampling bias
— the reason anyone integrates in the first place, and Pat's blocking #2 — is
the remaining half of S2 and depends on the S1 rebuild.

---

## Block 8 — disjoint arms work, and the mesh is why (Pat blocking #7)

Pat's structural objection: every cell in both articles carries a count row
*and* a detection row, at identical coordinates, sharing a `cell_id`. Real
eBird and ABMI rows have **disjoint coordinates and no common unit**, and the
articles never say whether that is allowed — "the first structural question
anybody adapting it has".

**Demonstrated** (`/tmp/disjoint.R`, 3 species, 180 PO sites and 90 survey
sites drawn independently over the same region):

```
shared site ids between arms      : 0
shared coordinates (x,y)          : 0
mesh nodes                        : 341
convergence 0 | iterations 21 | objective 1403 | 0.6 s
true env slopes : 0.90  -0.40   0.50
estimated       : 0.86  -0.319  0.566
```

**The mechanism, which is the part worth explaining.** The mesh is built over
the **union of both arms' locations**, and each row is projected onto it
through `A_proj`. Two arms therefore share a latent field without sharing a
single row, coordinate, or unit label — the field lives on the mesh, not on
the data. This is what makes an integrated SDM possible on real data at all,
and it is currently invisible in both articles because their contrived design
never exercises it.

**One seed, so read it as a feasibility demonstration, not a recovery result.**
What it establishes is that the fit runs, converges healthily, and lands near
truth in 0.6 s — enough for a reader to build on. Recovery quality across
seeds is S1's job, not this block's.

**Note `iterations 21`.** A healthy spatial fit uses tens of outer iterations.
Compare the false-convergence signature below.

---

## Block 9 — a spatial-path false green (narrowing measurement; issue pending)

While rebuilding the simulation, a fit reported **`convergence == 0` with
`iterations == 1` and `objective 1.9e25`**, with the spatial block frozen at
its starting values. The trigger was large counts.

**Measured narrowing** (`/tmp/falsegreen.R`, same family and structure, *no*
spatial term):

| max count | convergence | iterations |
|---|---|---|
| 21 | 0 | 18 |
| 1.9e4 | 0 | 13 |
| 7.8e6 | **1** | 12 |
| 4.2e8 | **1** | 11 |

Without a spatial term, large counts produce an **honest** `convergence = 1`.
So the false green is **specific to the spatial path**, not a generic
large-count failure. This is the sixth instance this session of the
silent-fallback class (#1132, #1120, #1119, #1083, #1163): the code took a
degenerate path and reported success.

To be filed with a minimal reproduction once the rebuild lane confirms the
mechanism. **Not an article claim** — recorded here so it is not lost.

---

## Block 10 — the claim survives a BIASED presence-only arm (Pat blocking #2)

Pat's most serious objection: the article's opportunistic arm has **no sampling
bias**, so the entire reason anyone integrates is absent from the design. Read
as written, she would "wrongly drop her survey arm".

**Tested in the design she asked for** (`/tmp/biased.R`, 400 PO / 100 survey,
15 replicates per cell). The presence-only arm is now *precise but sampling-
biased*: reporting intensity carries `gamma = 1.2` on an accessibility surface
drawn as an **independent** Gaussian field, so `env` and `access` are
orthogonal by construction (realised sample correlation -0.14 on this seed —
chance, in a strongly autocorrelated field). The survey arm is *unbiased but
fuzzed*. The analyst models the bias, as a competent one would.

| fuzz | precise | fuzzed | integrated | integrated - precise | replicates hurt |
|---|---|---|---|---|---|
| 0.00 | 0.903 | 0.915 | 0.904 | +0.001 | 10/15 |
| 0.50 | 0.903 | 0.363 | 0.835 | **-0.069** | 14/15 |
| 1.00 | 0.903 | 0.206 | 0.798 | **-0.105** | 14/15 |

**The claim survives.** With the motivation for integration present and
correctly modelled, integrating the fuzzed arm still moves the environmental
slope away from truth in 14 of 15 replicates at both non-zero fuzz levels. The
`fuzz = 0` control holds (10/15; two-sided binomial p = 0.30).

**Do not compare these magnitudes to Block 7's.** That run fitted no `access`
term, so the two are different models and only the *within-run* contrast
(integrated vs precise, same data) is valid.

**The honest framing for the article, which is narrower than it looks.** This
says the penalty falls on the **environmental slope specifically**. It does
not say the survey arm is worthless: an unbiased structured arm is exactly what
identifies and corrects the reporting bias, and that is why it is in the model
at all. The uncomfortable finding is that the *same* arm, if its coordinates
are fuzzed, damages the slope while it repairs the bias. Both are true at once,
and an article that reports only one of them is misleading. State the
trade-off, do not resolve it.

---

## CORRECTION to Block 8 — my own demonstration did not demonstrate what I said

**Block 8 above is wrong and must not be used as written.** It is left in place
rather than deleted so the error is visible.

The fit in Block 8 passed a raw `fmesher::fm_mesh_2d()` object as `mesh =` with
a formula containing **no spatial term**. I then described a mechanism —
"the mesh spans the union of both arms' locations, each row projected through
`A_proj`" — that the fit never exercised. The fit converged and recovered
sensible slopes because it was an ordinary non-spatial GLM.

**How it was caught.** A mesh-resolution sweep returned slopes identical to
three decimals across an 18-fold range of mesh nodes (59 to 1,081), which is
not robustness but inertness. Direct test (`evidence-mesh-inert.R`):

| fit | objective | npar |
|---|---|---|
| no mesh, no spatial term | 1403.424034 | 7 |
| `mesh =` supplied, no spatial term | 1403.424034 | 7 |

Identical to fifteen significant figures.

### The defect this exposes (new; sibling of #1163)

`gllvmTMB()` requires a mesh built by its own `make_mesh()`. Given a raw
`fmesher` mesh:

- **with** a spatial term -> a loud, correct error: *"Pass `mesh` as a result
  of `make_mesh()`."*
- **without** a spatial term -> **silently ignored**. No error, no warning.

A reader who builds an `fm_mesh_2d()` (as every INLA tutorial teaches) and
forgets the spatial term gets a converged, clean-looking, entirely
**non-spatial** fit. This is the silent-fallback class again.

### Block 8, redone properly

`evidence-disjoint-arms-shared-field.R`: same disjoint design (0 shared site
ids, 0 shared coordinates), mesh via `make_mesh(d, xy_cols = c("x","y"),
cutoff = 0.4)` giving `A` of 810 rows x 220 nodes against 810 long rows — and
this time **a real shared spatial field is present in the DGP**.

| model | conv | iters | objective | npar | slopes (true 0.900 / -0.400 / 0.500) | mean abs err |
|---|---|---|---|---|---|---|
| no spatial term | 0 | 24 | 1691.782 | 7 | 1.063 / -0.530 / 0.469 | 0.108 |
| `spatial_latent(d = 1)` | 0 | 54 | 1407.720 | 11 | 0.877 / -0.418 / 0.419 | **0.041** |
| `spatial_dep` | 0 | 66 | 1407.720 | 14 | 0.877 / -0.418 / 0.419 | 0.041 |

**delta logLik = 284.06** for 4 extra parameters. The field is emphatically
detected, and omitting it biases the environmental slopes — mean absolute
error falls 0.108 -> 0.041. Two of the three species improve substantially and
one (C: 0.469 -> 0.419 against a true 0.500) gets slightly worse; report all
three rather than the average alone.

`spatial_dep` and `spatial_latent(d = 1)` reach the **same** objective here, so
the 3 extra parameters of the unstructured field buy nothing on this DGP —
which is expected, since the simulated field is rank-1 by construction.

**One seed.** This is a feasibility-and-mechanism demonstration, not a recovery
result.

### What the article must say

Arms need not share locations, rows, or unit labels — the field lives on the
**mesh**, and `make_mesh()` must be built on the same long-format data passed
to `gllvmTMB()` (the package checks `nrow(A) == n_obs` and errors if not).
Say explicitly that a `mesh =` without a spatial term does nothing, because
that trap is currently unguarded.

---

## Block 11 — the unprojected mesh is a real error, and the likelihood hides it (Pat #11, Shinichi)

Both articles build the mesh on **unprojected lon/lat**. Shinichi and Pat
flagged this independently. The arithmetic was never in doubt; what mattered
was whether it changes the answer.

**The anisotropy, measured** (`evidence-projection-anisotropy.R`, Alberta box
near 54.5 N):

| | km per degree |
|---|---|
| longitude | 67.0 |
| latitude | 111.6 |
| **ratio** | **1.666x** |

A mesh built on degrees therefore treats a 67 km east-west step as equal to a
112 km north-south one. `cutoff` and `max.edge` mean different distances along
the two axes.

**Whether it matters** (`evidence-projection-seeds.R`, 5 seeds, a field that is
isotropic in true distance, `cutoff` tuned so node counts match):

| | mean abs slope error | per seed |
|---|---|---|
| lon/lat mesh | 0.1251 | 0.083 0.181 0.082 0.144 0.135 |
| UTM (km) mesh | **0.0541** | 0.047 0.084 0.047 0.049 0.043 |

**UTM is better in 5 of 5 seeds — a 57% reduction in slope error.**

**And the likelihood cannot diagnose it.** Mean objective is **1136.856** for
lon/lat against **1136.956** for UTM: the *unprojected* mesh achieves a
marginally **better** fit while being roughly twice as wrong on the quantity
the model exists to estimate. A reader comparing log-likelihoods, AIC, or
convergence would see nothing — and would be very slightly encouraged toward
the wrong choice.

**Caveat, stated.** The UTM meshes carry about 6% more nodes on average
(210-232 vs 191-219) despite tuning. A 6% node advantage is not a plausible
explanation for a 57% error reduction, but the comparison is not perfectly
matched and this is 5 seeds, not a campaign.

**Two things for the article.**

1. Project before meshing — `add_utm_columns()` is in the package, and the
   mesh, `cutoff` and `max.edge` should all be in kilometres.
2. **Keep the domain inside one UTM zone.** Zones are 6 degrees wide, so even
   a 2-degree box straddles one if it crosses a boundary: a box at
   -114.5 to -112.5 crosses the zone 11/12 line at -114 and triggers
   *"Coordinates span multiple UTM zones; using the most frequent zone."*
   That warning is real and should not be talked past.

---

## Block 12 — the offset confound is PEDAGOGICAL, not statistical (corrects my own severity rating)

I listed `offset(log_effort)` being perfectly confounded with `isdm_source`
(`cor = -1`, because effort is constant within arm) as a **high-severity**
finding. **Measured, that rating is wrong.**

**The slopes are unharmed** (`evidence-offset-confound.R`):

| effort | cor(log_eff, arm) | conv | slopes (true 0.900 / -0.400 / 0.500) | mean abs err | warnings |
|---|---|---|---|---|---|
| constant within arm | +1.0000 | 0 | 0.881 / -0.402 / 0.489 | **0.0109** | none |
| varies within arm | -0.0703 | 0 | 0.949 / -0.401 / 0.466 | 0.0284 | none |

The confounded case is not worse — it is marginally better on this seed.

**Why, proved directly:**

| model | objective | slopes |
|---|---|---|
| `offset(log_eff)` + `src` | 1899.3262 | 0.8806 / -0.4022 / 0.4887 |
| `src` only, **no offset** | **1899.3262** | 0.8806 / -0.4022 / 0.4887 |
| offset only, no `src` | 1899.8430 | 0.8811 / -0.4022 / 0.4889 |

The source intercept absorbs a constant-within-arm offset **exactly** —
identical objective to eight significant figures. There is no identifiability
problem because an offset carries **no free coefficient**: it is a known
quantity, not something competing with the intercept for estimation. The
environmental slopes are orthogonal to both.

**So what IS wrong.** The article teaches the `offset(log_effort)` idiom in the
one setting where the offset provably does nothing — a reader can delete it and
get a bit-identical fit. They then carry the idiom to their own data, where
effort *does* vary within arm and the offset is doing real work, having learned
nothing about why. That is a pedagogical defect, and the reader cannot detect
it, but it is not the statistical defect I claimed.

**Fix for the article:** make effort vary within arm so the offset is doing
visible work, and say in one line what an offset is (a known multiplier with no
estimated coefficient) — which is exactly why it does not fight the arm
intercept.

**Not filed as an issue.** Nothing is silently wrong here; the model does the
right thing. A note that an offset is exactly collinear with a fitted factor
would be a kindness, not a bug fix.

---

## Block 13 — `grid$cell_id <- cells[1]` is harmless, and the package says so (Pat #9)

Pat's question: every grid row is assigned to cell `c1`, and `cell_id` is the
`unit =` argument, so does the whole map inherit one cell's unit-level effect?
She could not tell, and "would not trust a map I could not tell about".

**Measured** (`evidence-grid-cellid.R`, a model fitted WITH a real unit-level
random intercept, so there is genuinely something that could leak):

| comparison | max abs difference in linear predictor |
|---|---|
| grid on cell 1 vs cell 2 | **0** |
| grid on cell 1 vs cell 50 | **0** |
| (range of the predictions themselves) | 4.166 |

Exactly zero against a prediction range of 4.166. **The `cell_id` value is
ignored.** The map does not inherit any cell's unit effect.

**And the package does not stay silent about it.** The call raises:

> These terms are missing at training rows too, so the result is not comparable
> with `predict(object)`. Use `newdata = NULL` for the full conditional
> predictor, or `re_form = ~0` for the fixed-effects-only one.

This is the *opposite* of the silent-fallback pattern found elsewhere this
session: the random-effect tier is dropped, the user is told, and two correct
alternatives are named.

**Fix for the article:** use Pat's own wording — the column is *required by the
design matrix, not used in the prediction* — and either show the warning or
pass `re_form = ~0` explicitly so the intent is on the page. One line closes
the item.
