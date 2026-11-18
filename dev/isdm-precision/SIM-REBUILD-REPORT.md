# Rebuilding the shared iSDM simulation so it recovers its own truth

**Curie (S1), 2026-08-18.** Script: `dev/isdm-precision/precision-sim.R` (429
lines, rewritten). Gate artefact: `precision-sim-gate.rds`. Compute: local,
~18 min for the 30-replicate gate. No package dependency added; no `.Rmd`
touched; no git command run.

## 1. Gate results — 30 replicates, all measured

| # | assertion | measured | verdict |
|---|---|---|---|
| G1a | `\|cor(env, access)\| < 0.05` | **−0.0000** | **PASS** |
| G1b | `\|cor(env, latent field)\| < 0.05` | **−0.0000** | **PASS** |
| G2a | `mean cor(beta_hat, beta_true) > 0.95` | **0.9941** (min over reps **0.9690**) | **PASS** |
| G2b | `mean\|err\| / (sqrt(2/pi) · mean sd_MC) < 3` | **1.07** | **PASS** |
| G3 | `cor(\|err\|, log PO count)` not sig. positive | **r = −0.073, p = 0.972** | **PASS** |
| G4 | `\|cor(log_effort, source)\| < 0.9`, effort varies within arm | **+0.0064** | **PASS** |
| G5 | one UTM zone, no zone-straddle warning | **1 zone, 0 warnings** | **PASS** |
| G6 | arms share zero `cell_id` | **0 shared** (300 PO + 60 survey units) | **PASS** |

30/30 fits succeeded. `mean|err| = 0.1028` against a realised true-slope SD of
**0.514** and a Monte-Carlo SD of 0.1209. **No threshold was changed** to
achieve this.

G2b deserves a word because it is the one I defined rather than inherited.
`sd_MC` is the across-replicate spread of each species' estimate; under correct
specification `E|err| = sqrt(2/pi)·sd_MC`, so the ratio is 1 by construction and
**systematic** error inflates the numerator while leaving the denominator alone.
The measured **1.07** says the typical error is 7% larger than pure Monte-Carlo
noise predicts. The old design's equivalent ratio was not computable because it
never got replicates, but `mean|err| = 1.81` against a slope SD of 0.45 is an
order of magnitude worse than the noise floor.

**Replicate count = 30, justified not guessed.** G3 binds: a one-sided t-test on
30 per-replicate correlations detects a mean correlation of ≈0.30 at ~90% power
given the observed between-replicate SD of ≈0.30. The failure being guarded
against was **+0.60**, so 30 has ample margin.

## 2. What was actually wrong — three causes, not one

The brief named one mechanism. There were three, and **the named one was the
smallest**.

### (a) `cor(env, access) = 0.649` — real, and fixed

Both were smooth functions of longitude. `access` is now residualised on `env`
at the analysis cells, so the correlation is exactly 0 rather than merely small.

### (b) `cor(env, latent field)` — the larger cause

The latent field was *also* a smooth function of the same two coordinates, and
the model fits it with **per-species loadings**. `beta_j·env` and
`lambda_j·field` are then two rank-1 spatial terms competing species by species
— textbook spatial confounding — and abundant species have the most leverage to
resolve the trade-off wrongly, which is precisely the `cor(|err|, log PO) =
+0.60` signature.

Measured, isolating it: with `access` modelled and **no** spatial term,
recovery is `cor = 0.994, mean|err| = 0.187`. Add the spatial term and it goes
to `mean|err| = 7.808` with slopes of **+20.97** against a true +1.28. The
coordinator's independent probe (no `access` covariate at all; slopes
1.96/1.42/1.87 against a true 0.70) reaches the same conclusion from the other
side. The field is now residualised on **both** `env` and `access`.

### (c) A silent optimiser failure at large counts — nobody had named this

Past a count magnitude, `gllvmTMB()` returns **`convergence == 0` after ONE
iteration at an objective of ~1e21–1e25**, with every spatial parameter still at
its starting value and the env slopes at |beta| ~ 20. `fit$opt$convergence` does
not catch it; `fit$opt$iterations` does.

Bisection (12 species, disjoint arms, `kappa` = the PO intensity offset):

| species | kappa 0.0 | kappa 1.0 | kappa 2.0 |
|---|---|---|---|
| 2 | iters 59, obj 529 | iters 94, obj 796 | iters 440, obj 1683 |
| 4 | iters 99, obj 1099 | iters 118, obj 1590 | **non-finite** |
| 12 | iters 95, obj 3435 | iters 80, obj 4952 | **non-finite** |

The simulation now runs at `KAPPA_PO = 0.5` (max PO cell count 150; 327–1186
records per species — realistic for an eBird-derived arm) and `isdm_fit()`
rejects any fit with `iterations <= 1` or a non-finite objective.

**Negative control proving the guard discriminates** (not just that it passes):

```
kappa=0.5  maxcount=150  raw: conv=0 iters=68 obj=4.27e+03  guard: accepted
kappa=1.5  maxcount=371  raw: conv=0 iters= 1 obj=8.72e+20  guard: REJECTED
```

## 3. What did NOT work — do not repeat these

1. **Fixing `access` alone.** Sufficient only without the spatial term.
   Established twice, independently (§2b).
2. **Rescaling the projected coordinates.** `log_kappa_spde` starts at 0, which
   in kilometres is a practical range of 2.83 km on a 225×443 km domain — this
   looks exactly like the bug and is not. Sweeping the coordinate scale by
   1/1, 1/10, 1/50, 1/100, 1/200 changed nothing, and on a known-good small
   setup the objective is **identical to 4 d.p. at scale 1 and scale 1/100**
   (524.3 both). Coordinate scale is a red herring; count magnitude is the cause.
3. **Blaming `isdm_source:access`.** It fails in combination with the spatial
   term — but so do `po_access` and a plain `access` main effect. The term was
   innocent.
4. **Blaming the disjoint arms (G6).** Measured fine at 2, 4 and 12 species for
   kappa 0 and 1. Gate 6 costs nothing.
5. **Coarsening the mesh** to `cutoff = 80`: `make_mesh()` aborts with *"Mesh
   A_st must be a sparse projection with one row per coordinate row."*
6. **A high-frequency `env` component.** I predicted in the plan that `env`
   would have to be pushed outside the SPDE's representable span to defeat the
   confounding in (b). **That prediction was wrong** — residualising the *true*
   field against `env` was sufficient, and the `env` surface stays smooth and
   exactly mappable, which the warbler article's map needs.

## 4. Design as built

12 real Alberta boreal songbirds (CAWA, OVEN, TEWA, BLPW, BBWA, BTNW, CMWA,
MAWA, SWTH, WTSP, YRWA, RBNU). Domain lon [−118.5, −115.0] × lat [54.0, 58.0],
wholly inside UTM zone 11, projected to km via `add_utm_columns()`. 300
presence-only cells (Poisson) and 60 survey cells (cloglog detection) at
**disjoint** locations. Effort varies within each arm and is centred in both, so
the offset is not a relabelling of the arm indicator. The PO arm carries
accessibility bias (`B_ACCESS = 1.2`) and the model estimates it as a
PO-arm-only thinning term, which is the standard iSDM specification.
`spatial_latent(0 + trait | coords, d = 1)` matches the DGP: one shared field,
per-species loadings. Recovered loading-vs-truth correlation **0.98–0.99**.

`isdm_landscape()` returns a `covariates()` closure carrying the stored
orthogonalisation coefficients, so a prediction grid gets the **identical**
affine map the model was trained under — which is the structural fix for the
`scale()`-twice newdata bug (Pat #8), not just a patch of it.

`isdm_simulate(..., fuzz_km =)` displaces the survey arm's *recorded*
coordinates without moving the organisms. It is 0 by default and exists so the
precision re-test runs on this same simulation rather than forking it.

## 5. Landscape robustness

The landscape is **fixed** by design (both articles show one landscape;
replicates vary the observation process). Checked at three further landscape
seeds, 4 replicates each:

| seed | cor(env,access) | cor(env,field) | fits | cor | mean\|err\| | G3 |
|---|---|---|---|---|---|---|
| 11 | −0.0000 | +0.0000 | 4/4 | 0.9947 | 0.124 | −0.209 |
| 777 | −0.0000 | +0.0000 | 4/4 | 0.9944 | 0.165 | −0.125 |
| 31337 | +0.0000 | +0.0000 | 4/4 | 0.9942 | 0.112 | −0.111 |

Not one lucky landscape.

**Reproducibility:** two independent `Rscript` invocations produce
**byte-identical** gate output. Every seed is set explicitly; nothing depends on
the ambient RNG state.

## 6. Still unsatisfactory — stated, not smoothed over

1. **A small but statistically real positive bias remains.** Pooled mean error
   **+0.0274, SE 0.0066, t = 4.17**. It is uniform (11 of 12 species positive,
   range −0.002 to +0.054), so it is one shared mechanism rather than noise —
   most likely finite-sample Poisson/cloglog MLE bias plus the residue of the
   spatial confounding that orthogonalisation reduces but does not abolish. It
   is **5.3% of the true slope SD** and 23% of one Monte-Carlo SD, so it is
   immaterial for an illustrative article, but **no article should quote these
   slopes as unbiased.** G2b was designed to expose exactly this, and it does.
2. **The margin to the silent-failure boundary is only about 3× in intensity**
   (running at kappa 0.5; failure at 1.5). Anyone who raises the intensity,
   the slope spread, or the effort spread **must re-run the gate**. The
   `iterations <= 1` guard makes such a failure loud rather than silent, but it
   does not prevent it.
3. **G3 has a built-in confound I did not remove.** `|err|` and PO count are
   both driven by `|beta_j|` — a species with a steeper env slope generates more
   records *and* has more room to be wrong. So G3 is a weaker test than it
   looks. It is still the right test (it is what caught the original failure),
   and the measured value is **negative**, which is the healthy sign; but a
   near-zero G3 should not be read as clean.
4. **The precision claim has NOT been re-tested.** That is S2. The old
   `precision-sim-results.rds` (2-species fuzz sim, 40 reps) is now **orphaned**
   — the script that produced it no longer exists in this file. `fuzz_km` is
   provided so the re-test runs on this simulation.
5. **Coordination hazard.** While this ran, another lane committed 18
   `evidence-*.R`/`generate-*.R` scripts into `dev/isdm-precision/` and rewrote
   `isdm-spatial-precision.Rmd` to reference `arm-weighting-results.rds` and
   `biased-po-results.rds`. Commit `d58cd8e7` **swept my in-progress
   `precision-sim.R` into that commit**. The file content is intact and
   verified, but nobody chose to commit it — reconcile before the PR.
