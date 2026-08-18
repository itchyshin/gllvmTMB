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
