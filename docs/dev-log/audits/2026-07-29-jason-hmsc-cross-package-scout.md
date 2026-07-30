# Jason cross-package scout: what `Hmsc` has that we do not

**Author**: Jason (cross-package / literature lens), Claude Code session
2026-07-29.
**Date**: 2026-07-29.
**Triggered by**: maintainer question — *"what can we learn from this package
and related publications? <https://github.com/hmsc-r/HMSC> — a lot of good
ideas although it is Bayesian."*
**Scope**: read-only. No `R/`, no tests, no NAMESPACE, no ROADMAP edits. This
audit records findings and a ranked recommendation; it decides nothing.
**Evidence tags**: **[V]** verified first-hand this session (fetched source or
ran locally); **[A]** from a sub-agent scout, sourced but not re-verified by me;
**[R]** recall / prior note, unverified; **[I]** my inference.

---

## 1. The one-line answer

The valuable thing to take from `Hmsc` is **not** a model structure and **not**
its Bayesian machinery. It is the **evidence layer** — held-out
cross-validation, a named fit-metric set, and a shipped known-truth fixture —
plus the fact that `Hmsc` is **GPL-3 and therefore licence-compatible as a
validation oracle**. That lands precisely on the thing the mission-control board
names as the 0.6 blocker: *the gap to submission is EVIDENCE, not capability.*

**The finding that reframes the question** is a comparison of investment, not of
features:

| | `Hmsc` 3.4-1 | `gllvmTMB` 0.5.0 |
|---|---|---|
| Response families | **4** `[V]` | **~32** `[A]` |
| Held-out CV + fit metrics | full triad `[V]` | **ABSENT** `[A]` |
| Coverage-validated interval cells | n/a (posterior) | **1** `[A]` |
| Shipped example/test dataset | 1, known DGP `[V]` | **none** `[V]` |

`Hmsc` ships four distributions and a deep evaluation surface. We ship ~32
families, of which only Gaussian / Poisson / NB2 / binomial are "taught paths",
one coverage-validated interval cell package-wide, and no way at all to ask
*"how well does this model predict data it has not seen?"* **[I]** On the
evidence axis the asymmetry runs against us, and it runs against us in the exact
place that is blocking the release.

**Three openings run the other way**, and all three sit inside machinery we
already own (§4, §5):

1. **Turnkey cross-validated predictive scoring for a JSDM exists
   Bayesian-only** — no frequentist package ships it.
2. **No published frequentist method puts a confidence interval on
   variance-partition shares.** We have `VP()`, profile/bootstrap/delta
   machinery, and a live coverage-certification discipline. Bayesian packages
   get this free from the posterior; the ML side has not attempted it.
3. **Conditional prediction is closed-form for us and expensive for them** — a
   Schur-complement solve against `Hmsc`'s extra Gibbs sweeps.

**[I]** And a fourth, quieter one: no dedicated coverage-simulation study exists
for `gllvm`'s parameters at all. The CI-08 programme reads internally as
remedial. Measured against the field, nobody else has published the
measurement.

---

## 2. What was already known — do not re-derive

Recalled before scouting, per the recall-first rule.

- **`DR3-gllvm-jsdm-2026-07-01`** (brain vault, marked UNVERIFIED) already holds
  the competitive landscape: `Hmsc` vs `gllvm` vs `sjSDM` vs `ecoCopula` vs
  `boral` vs `VAST`, the Bayesian/ML split, the GPU story, and the phylogenetic
  state of the art. **This audit does not repeat it.** `[R]`
- **The repo already positions `Hmsc`** as an external Bayesian comparator, in
  six places, and already *plans* the comparison: `docs/design/05-testing-strategy.md:75`
  — "`Hmsc` for phylogenetic + spatial JSDM | Residual correlation structure
  comparison | `phylo_latent + spatial_unique` capstone | **planned (Phase
  5.5)**". `docs/design/00-vision.md:47` warns not to copy any of their grammars
  wholesale; `:112` says "`Hmsc` is Bayesian (slow)". `[A]`
- **Bolker's follow-up email (2026-07-28), item 5** already corrected the record
  that Ovaskainen is the closest subject match to this package of anyone named,
  and floated `Hmsc` as a **latent-variable oracle** that would soften the
  "must be built, not adopted" verdict in
  [#800](https://github.com/itchyshin/gllvmTMB/issues/800). It recorded two
  things as **unchecked**: whether `Hmsc` ships fixtures, and its licence. `[R]`

**This audit's job is the part none of those cover**: what is actually inside
the package and its tests, and what of it is transferable to a
maximum-likelihood engine.

---

## 3. Verified facts about `Hmsc` (first-hand this session)

### 3a. The two unchecked items from the Bolker note are now checked

- **Licence: GPL-3** (`DESCRIPTION`, `hmsc-r/HMSC` master, v3.4-1). `[V]`
  This matters: #800 rejected vendoring `glmmTMB` material because it is
  **AGPL-3** against our GPL-3. `Hmsc` carries **no such conflict**.
- **It ships fixtures. Yes.** `[V]`
  - `tests/testthat/` — 7 files: `test-recovery-sanity.R` (10.9 kB),
    `test-sampling.R`, `test-initialParameters.R`, `test-setHmsc.R`,
    `test-setPriors.R`, `test-setRL.R`, `test-WAIC.R`.
  - `tests/Examples/Hmsc-Ex.Rout.save` — a saved-output regression file.
  - `data/TD.rda` (301 kB) — one simulated dataset **plus a fitted model
    object**, generated by a checked-in script, `data-raw/simulateTestData.R`.
  - `tests/` is **not** in `.Rbuildignore`, so this travels in the source
    tarball.

### 3b. The `TD` fixture is a fully specified known-truth DGP

From `data-raw/simulateTestData.R` and `man/TD.Rd` `[V]`: `set.seed(66)`,
4 species × 50 units × 10 plots; one continuous + one categorical environmental
variable; a coalescent tree with Brownian `C`; a trait fully structured by
phylogeny; **known** `gamma = [[-2, 2], [-1, 1]]`, **known** loadings
`lambda = c(-2, 2, 1.5, 0)` (note the deliberate zero), spatial
`Sigma = 2^2 * exp(-d / 0.35)`, probit-thresholded to binary occurrence.

**[I]** This is a ready-made phylo + spatial + trait + hierarchical fixture with
every generating parameter written down — which is exactly the shape of the
`phylo_latent + spatial_unique` capstone that `05-testing-strategy.md:75` has
had parked at Phase 5.5. The generating recipe is ~40 lines of `ape` + `MASS`;
it can be **re-derived rather than vendored**, so even the licence question can
be sidestepped.

### 3c. Important caveat — their updater tests are weaker than their names claim

`test-sampling.R` names every test `"updateX is correct"`, but the assertions
are seed-pinned sums and dimensions `[V]`:

```r
expect_equal(round(sum(Gamma)), 0)
expect_equal(round(sum(eta[[1]])), -6)
```

These are **change-detectors**, not correctness checks. Useful — they catch
unintended drift — but they certify nothing statistical. The genuinely
statistical file is `test-recovery-sanity.R`, and it is gated off by default
behind `Sys.getenv("RUN_HMSC_SANITY_TESTS") == "true"`.

**[I]** Two consequences. First, **`Hmsc` is a weak oracle at the
updater/internal level and a reasonable one at the fitted-model and DGP level**
— scope any adoption accordingly. Second, this is a naming lesson in our own
direction of travel: `"X is correct"` over `round(sum(x)) == -6` is the exact
overclaim the house standard forbids. We gate expensive tests the same way
(`GLLVMTMB_HEAVY_TESTS`, 9 uses) `[V]`, so the pattern is shared; the naming
should not be.

### 3d. The testing idea genuinely worth stealing

`test-recovery-sanity.R` does something we do not: it recovers **one parameter
block at a time, conditional on the truth of all the others** `[V]`. Feed
`updateEta()` the true `Lambda` and check `cor(eta_hat, eta_true) > 0.8`; feed
`updateBetaLambda()` a near-noiseless `Z` and check `cor(beta_hat, beta_true) >
0.9`; check `updateRho` lands within ±2 grid steps of the true index.

**[I]** The TMB analogue is not the Gibbs updater but the **objective block**:
fix the random effects at their true values and check the conditional mode of
the fixed effects; fix `Lambda` at truth and check the `psi` block; fix
everything but the phylogenetic scale and check that. Our 307 test files /
1,908 `test_that()` calls include ~20 `*-recovery.R` files `[V]`, but they are
whole-model recoveries — which is why a failure costs a multi-day bisect (the
2026-05-25 binomial `psi` episode that produced Design 54 is the canonical
case). Block-conditional recovery localises the failure *before* the
investigation starts.

### 3e. The API surface, verified from source `[A]`

Sub-agent scout read `R/`, `man/`, `NAMESPACE` and `DESCRIPTION` directly (the
pkgdown site 404s; CRAN is at 3.3-7, master at 3.4-1). Items that are *not* in
DR3 and *not* in our docs:

- **`XSelect`** — spike-and-slab covariate inclusion, per species-group.
- **`XRRR` / `ncRRR`** — reduced-rank regression on a *separate* covariate block.
- **`covRhoGroup`** — per-covariate-group phylogenetic signal `rho`, not one
  scalar for the whole model.
- **`phyloFast`** — linear-time tree algorithms instead of a dense `C`. **[I]**
  This is the same structural point as Bolker's item 1 (sparse phylogenetic
  precision / Woodbury): they already took the sparse route and made it a
  user-facing switch.
- **`sMethod = "Full" | "GPP" | "NNGP"`** — three explicit cost/accuracy tiers
  for spatial latent factors, with `constructKnots()` for the predictive-process
  knots.
- **`taxToPhylo()`** — build a phylogeny substitute from a **taxonomy table**
  when no tree exists.
- **`constructGradient()` / `plotGradient()`** — predict along one focal
  covariate with three principled treatments of the non-focal covariates
  (hold at expectation/mode, regress on the focal, or fix).
- **CORAL** (`coralTrain`, `coralPredict`, + 6 more) — "Common-tO-RAre-Learning"
  (*Nature Methods* 2025 `[A]`): fit fast per-species models on common species,
  transfer the priors to score very large numbers of rare taxa.
- **`computeSAIR()`** — shared vs idiosyncratic responses to measured and latent
  predictors.
- **The evaluation triad**: `createPartition(nfolds, column)` →
  `computePredictedValues(partition =, partition.sp =)` →
  `evaluateModelFit()`. Metrics branch by family: RMSE / R² (normal);
  RMSE / TjurR² / AUC (probit); RMSE / SR² plus an occurrence-vs-conditional
  split `O.RMSE, O.AUC, O.TjurR2, C.RMSE, C.SR2` (counts). `partition.sp`
  gives **species-fold** CV, i.e. hold out species and predict them from the
  others.
- **Conditional prediction** — `predict(..., Yc = )`, extra Gibbs steps updating
  latent factors given known species outcomes.
- **Docs**: five numbered static-PDF vignettes (univariate → multivariate low →
  multivariate high → spatial → **performance on simulated data**), plus the
  Ovaskainen & Abrego (2020) Cambridge book and a recurring taught course.

---

## 4. Where each idea already exists frequentist-ly

Checked against the **installed** `gllvm` 2.0.13 rather than recalled `[V]` —
56 exports, `tools::Rd_db()` descriptions read directly.

| Idea | `Hmsc` | `gllvm` 2.0.13 (installed) | `gllvmTMB` 0.5.0 |
|---|---|---|---|
| Variance partitioning | `computeVariancePartitioning` (+`R2T`) | `VP()` / `plotVarPartitioning`, `calcr2scaled` | `VP()` ("mirrors `gllvm::VP()`") |
| Residual associations | `computeAssociations` + posterior support | `getResidualCor(adjust=)` | `getResidualCor`, **point-only** |
| Environment correlations | — | `getEnvironCor/Cov` | — |
| Co-occurrence probability | via posterior | **`predictPairwise(se.fit=)`** | **ABSENT** |
| Species-richness prediction | via posterior | **`predictSR()`** | **ABSENT** |
| Conditional prediction | `predict(Yc=)` | `predictLVs`, `predictPairwise` | **ABSENT** (MIS-07 gated) |
| Held-out CV | `createPartition` + `computePredictedValues` | `goodnessOfFit(y=, pred=)` accepts held-out | **ABSENT** |
| Fit metrics | `evaluateModelFit` (7 named) | `goodnessOfFit`: cor/RMSE/MAE/MARNE | **ABSENT** |
| Trait / fourth-corner | `TrData`/`TrFormula` → `Gamma` | fourth-corner via `TR` | **ABSENT** |
| Phylo signal | `rho`, per-covariate via `covRhoGroup` | per-covariate signal (v2.0) | H² derived + profile CI |
| Phylo speed route | `phyloFast` | NNGP / band | sparse `A⁻¹` |
| Spatial | Full / GPP / NNGP | correlation structures | SPDE/GMRF only |
| Ordination / biplot | `biPlot` | `ordiplot`, `phyloplot` | `ordiplot`, `plot_*` |
| Prediction error | posterior | `getPredictErr(CMSEP=)` | — |
| Shipped datasets | `TD` (simulated, known truth) | 6 real datasets | **none** |

**[I] The table splits into two very different halves, and the split is the most
useful thing in this audit.**

**Half one — already transferred, we are simply behind.** Fourth-corner traits,
per-covariate phylogenetic signal, ordination, residual correlations, variance
partitioning, co-occurrence probability, species-richness prediction: `gllvm`
2.0 has all of it, in TMB, installed on this machine. Where we show ABSENT here,
**both** comparators have the feature. Nothing to invent; a gap to close or
consciously decline.

**Half two — transferred by nobody, and both sit inside our existing
machinery.** `[A]`

- **Turnkey cross-validated predictive metrics for a JSDM are
  Bayesian-only.** The sub-agent found no `CV.gllvm`-style function; `sjSDM_cv`
  tunes hyperparameters rather than scoring species, and `mvabund` does
  resampling p-values, not held-out scores. Wilkinson et al. 2021 *MEE*
  12:394–404 supply the paradigm-agnostic marginal/conditional/joint taxonomy,
  but no frequentist package ships the workflow.
- **No published frequentist method puts a confidence interval on the
  variance-partition shares themselves.** Point estimates exist everywhere
  (`gllvm::VP`, `boral::calc.varpart`, the Nakagawa & Schielzeth / Ives / `rr2`
  / `partR2` lineage). Bayesian tools get interval uncertainty free from the
  posterior; the ML side has nothing.
- **No dedicated coverage-simulation study exists for `gllvm`'s regression or
  covariance parameters at all.** The literature reports bias and RMSE, not
  coverage.

**[I]** That third point recasts the CI-08 programme. The coverage work reads
internally as remedial — thirteen of fifteen cells below nominal, one certified
cell. Measured against the field, *nobody else has published the measurement*.
And the second point is a target that sits exactly where this package is already
strong: we have `VP()`, and we have profile/bootstrap/delta machinery and an
active certification discipline. An interval on a variance-partition share is a
contribution the Bayesian packages get for free and the frequentist ones have
not attempted.

**[I] One risk flag, not an opportunity.** The board records Laplace as the
default and, for 0.6, the **only** integration route, with EVA cut to 0.7. The
`gllvm` literature documents that plain Laplace is measurably biased for binary
responses, worsening with discreteness, and that VA/EVA reduce but do not
eliminate it `[A]`. Our binary paths are Laplace-only by construction. This is a
known, published, external weakness landing on a route we have no alternative
to — worth an explicit position before 0.6, even if the position is "documented
limitation".

---

## 5. Ranked recommendation

Adopt / adapt / decline, most valuable first. **None of this is a decision.**

1. **Held-out predictive evaluation — ADOPT.** `createPartition` →
   `computePredictedValues(partition=)` → `evaluateModelFit`. Nothing in it is
   Bayesian. It is the standard by which the JSDM benchmark literature judges
   these models, and we currently cannot answer the question at all. It is also
   *evidence*, which is the named 0.6 blocker. **Highest value per unit of
   work.**
2. **`Hmsc` as an oracle — ADOPT, scoped to fitted-model and DGP level.**
   GPL-3, ships `TD`, DGP fully written down and re-derivable in ~40 lines.
   Feeds #800 and un-parks the Phase 5.5 capstone. Scope it away from their
   updater tests (§3c).
3. **Ship a fixture dataset — ADOPT.** We ship none; 98 of 138 man pages carry
   examples and 16 simulate inline `[V]`. `data-raw/examples/` already holds
   seven generator scripts, so the infrastructure is half-built and `LazyData:
   true` is already set.
4. **Block-conditional recovery tests — ADAPT** (§3d). Localises failures that
   currently cost days.
5. **Closed-form conditional prediction — ADOPT, and this one is a
   differentiator, not catch-up.** `[A]` In `Hmsc`, predicting species A given
   species B observed is *not* closed-form: `computePredictedValues(Yc=,
   mcmcStep=)` runs extra Gibbs sweeps per prediction, and cross-validating it
   multiplies that cost by the number of folds. In a Gaussian-latent
   Laplace/TMB model, conditioning the latent block on observed species is a
   **Schur-complement update** — exact, one linear solve, no resampling. This
   is the prediction type Wilkinson et al. 2021 (*MEE* 12:394–404) identify as
   where joint models should help most and where evaluation is thinnest.
   Pair it with their four-way taxonomy (marginal / joint / conditional-marginal
   / conditional-joint) in the `predict()` documentation.
6. **Trait / fourth-corner layer — CONSIDER, post-0.6.** A genuine capability
   gap: `Hmsc` has it, `gllvm` has it, we do not. Note `[A]` that `Hmsc`'s
   `Gamma` *partially pools* species slopes toward the trait-predicted mean,
   whereas the established frequentist fourth corner (`traitglm`, `gllvm`'s
   `TR`) is fixed-effect — so "add the trait layer" is two different features,
   and the hierarchical one is the less-packaged of the two. `extract_Gamma()`
   is already taken by the coevolution kernel, so naming needs care.
7. **`R2T` and `computeSAIR` — ADAPT, cheap.** `[A]` Both are post-hoc linear
   algebra on fitted `Beta`/`Lambda` and need no posterior: the
   trait-explained share of variance, and the shared-vs-idiosyncratic split of
   species responses to measured and latent predictors. Our variance-partition
   dispatcher already exists, so these are refinements to a live surface.
8. **`constructGradient` / `plotGradient` — ADAPT.** Cheap, purely
   post-fit, and the three-way treatment of non-focal covariates is a real
   interpretation contribution rather than a plotting convenience.
9. **`taxToPhylo` — ADAPT.** Very cheap, high applied value for users with a
   taxonomy and no tree.
10. **`phyloFast` — AUDIT, do not build.** Confirm whether our sparse `A⁻¹`
    path is already the equivalent. Converges with Bolker item 1; a grep, not a
    project.
11. **Scale-resolved association reporting — ADAPT (habit, not code).** `[A]`
    `computeAssociations()` returns one matrix **per random level**, so
    co-occurrence is reported by spatial/nested scale rather than pooled. Our
    stackable `latent()`/`indep()` terms already support the structure; the
    borrowable part is making the per-level output the default presentation.
12. **CORAL — WATCH.** Too new to chase; note it exists.
13. **GPU — NOTE ONLY.** `[A]` Rahman et al. 2024 report >1000× on dense
    benchmarks but **zero** benefit for NNGP, because the sparse solves defeat
    the accelerator. Sparse SPDE work stays CPU-bound whatever the estimator;
    do not read the headline speedup as transferable to our spatial path.

**DECLINE, with reasons:**

- **Posterior support for associations** (`plotBeta(param="Support")`). The
  frequentist analogue is a *calibrated interval* on the residual correlation —
  which is exactly the unresolved CI-08 problem. Shipping a support-flavoured
  display without calibrated coverage would be the overclaim the board is
  already fenced against.
- **Multiplicative-gamma shrinkage for choosing the number of factors** —
  intrinsically prior-based, *and contested on its own terms*: Durante 2017
  (*Stat. Probab. Lett.* 122:198–204) shows the intended shrinkage holds only
  for particular hyperparameter settings and the prior tends to over-retain
  factors `[A]`. It is not a tuning-free gold standard we are missing out on.
  The ML answer remains information criteria or cross-validated rank
  selection.
- **WAIC** — posterior-predictive by construction.
- **Their grammar** — `00-vision.md:47` already rules this out, and the
  four-block Beta/Gamma/rho/Omega vocabulary is a *documentation* idea, not an
  API one. Worth borrowing as a reader's mental model, not as keywords.
- **GPP/NNGP spatial tiers** — SPDE is the TMB-native answer and we already have
  it. Revisit only if a real dataset breaks it.

### 5a. Three literature findings that constrain what we may *claim* `[A]`

These are not features. They are external results that bear directly on the
honesty fencing already in force, and two of them are supportive.

- **Do not market joint estimation as a predictive upgrade.** Norberg et al.
  2019 (*Ecol. Monogr.* 89:e01370), a 33-model comparison, found joint /
  latent-factor SDMs gave **no reliable species-level predictive edge** over
  stacked single-species SDMs, worst for rare species; any advantage was
  community-level and regime-dependent. Zurell et al. 2020 (*J. Biogeogr.*
  47:101–113) found probabilistic stacked SDMs matched or beat joint SDMs for
  assemblage prediction. **[I]** The defensible claim for this package is
  structure recovery and uncertainty quantification — which is what the
  existing recovery-only framing already says. This is external support for a
  position we hold, not a reason to change it.
- **Residual correlations are not biotic interactions — cite Poggiato.**
  Poggiato et al. 2021 (*TREE* 36:391–401) argue the residual `Omega`/`Sigma`
  of *any* JSDM, Bayesian or not, is confounded by missing and misspecified
  covariates. **[I]** The repo's standing "do not advertise delta/hurdle
  latent-scale correlation as interaction" fence now has a citable external
  basis rather than resting on house caution alone.
- **The book may be the adoption mechanism.** `[A]` HMSC's uptake plausibly
  owes as much to one 372-page structured narrative (Ovaskainen & Abrego 2020)
  and a recurring taught course as to the papers. **[I]** That is an argument
  for a coherent cookbook *sequence* over incremental vignettes — and the
  pending one-by-one article review with Shinichi is where that call belongs,
  so it is raised here and not acted on.

### 5b. Addendum (2026-07-30) — do we need the features, or do we need `Hmsc` as a checker?

Maintainer asked the sharper version of the question. Answer: **build the
evidence layer; do not build a validation programme on `Hmsc`.**

**Why `Hmsc` is a poor validation backbone, despite being licence-compatible:**

1. **Cross-package agreement with a Gibbs sampler is the weakest evidence
   available.** The estimands differ — a posterior mean under the MGP shrinkage
   prior is not the MLE — so *disagreement is not diagnostic*. It cannot
   distinguish "our engine is wrong" from "their prior is doing work". It can
   never certify coverage, which is the actual 0.6 blocker.
2. **It can only reach a corner of our surface.** Four families
   (normal / probit / Poisson / lognormal-Poisson) against our ~32. Roughly
   28 families have no `Hmsc` comparator even in principle.
3. **Their internal tests are change-detectors** (§3c), so package maturity is
   not itself a guarantee.
4. **The valuable part needs no install.** The oracle content is the
   *known-truth DGP*, which is ~40 lines of `ape` + `MASS` and can be
   re-derived. Known-truth recovery dominates cross-package agreement: the truth
   is known exactly, it covers any family we can simulate, and it is what
   coverage work already requires.

**Where an `Hmsc` comparison IS worth ~1 day**: the `phylo_latent +
spatial_unique` capstone at `05-testing-strategy.md:75`, where no frequentist
comparator implements phylogeny + spatial + latent factors simultaneously. That
is Design 54's falsification role — a bounded tie-breaker, not a programme.

**Feature vs evidence split, so this does not become 0.6 scope creep:**

| | Before 0.6 (evidence) | 0.7+ (capability) |
|---|---|---|
| CV + metrics | internal `dev/` script producing held-out scores for the release evidence pack | exported `cv_gllvmTMB()` user API |
| Fixture | known-truth DGP used by tests | shipped `data/` object + docs |
| Recovery tests | block-conditional tests (cost saving now) | — |

**[I] On "`Hmsc` can model things other packages cannot"** — true but narrower
than it sounds. Genuinely distinctive: uncertainty propagated into every derived
quantity (interval-bearing variance-partition shares, association support);
**covariate-dependent associations** (`HmscRandomLevel(xData=)`); spike-and-slab
covariate selection (`XSelect`); species-fold CV (`partition.sp`); CORAL. Not
distinctive: traits/fourth-corner, phylogenetic signal, spatial factors,
ordination, variance partitioning — `gllvm` 2.0 and others have all of these
(§4). Its edge is **uncertainty and two niche structures, not model coverage**;
ours is family breadth and speed. The one item worth watching as a real
capability gap is covariate-dependent associations.

---

## 6. What this does *not* cover

- No claim about **relative accuracy** of `Hmsc` and `gllvmTMB` on any dataset.
  Nothing was fitted. `Hmsc` is **not installed** on this machine `[V]`, and
  installing it is the maintainer's call.
- No assessment of `Hmsc`'s **runtime** beyond the recalled GPU-port figure.
- The **Ovaskainen & Abrego (2020) book** was not read; the vignette *content*
  was not read, only its structure.
- No verification that `TD`'s fitted object is reproducible from the script at
  current `Hmsc` versions (the script is dated 2020-02-29).
- This scout says nothing about whether any of it should be done **before
  0.6**. Items 1–3 are evidence-shaped and therefore arguably in scope; 5–7 are
  capability-shaped and arguably not.

---

## 7. Sources

First-hand: `github.com/hmsc-r/HMSC` master — `DESCRIPTION`, `NAMESPACE`,
`.Rbuildignore`, `tests/testthat/*`, `data-raw/simulateTestData.R`, `man/TD.Rd`,
`man/{computeSAIR,coralTrain,constructKnots,computeAssociations,evaluateModelFit,constructGradient}.Rd`.
Local: `gllvm` 2.0.13 namespace + `tools::Rd_db()`; this repo's `DESCRIPTION`,
`man/`, `tests/`, `data-raw/`.
Prior notes: brain `DR3-gllvm-jsdm-2026-07-01`; Bolker follow-up
2026-07-28 §5; [#800](https://github.com/itchyshin/gllvmTMB/issues/800);
`docs/design/{00-vision,05-testing-strategy,54-cross-package-scout-protocol}.md`.

Literature `[A]` — sourced by sub-agent scout, DOIs recorded, not re-verified
by me:

| Work | DOI | Why it is here |
|---|---|---|
| Ovaskainen et al. 2017, *Ecol. Lett.* 20:561–576 | 10.1111/ele.12757 | The Beta/Gamma/rho/Omega framework |
| Tikhonov et al. 2020, *MEE* 11:442–447 | 10.1111/2041-210X.13345 | The package paper |
| Tikhonov et al. 2020, *Ecology* 101:e02929 | 10.1002/ecy.2929 | GPP / NNGP spatial scaling |
| Ovaskainen et al. 2016, *MEE* 7:549–555 | 10.1111/2041-210X.12501 | Scale-resolved association networks |
| Ovaskainen et al. 2016, *MEE* 7:428–436 | 10.1111/2041-210X.12502 | Spatially autocorrelated latent factors |
| Bhattacharya & Dunson 2011, *Biometrika* 98:291–306 | 10.1093/biomet/asr013 | The MGP shrinkage prior |
| Durante 2017, *Stat. Probab. Lett.* 122:198–204 | — (arXiv:1610.03408) | Why that prior is contested |
| Rahman et al. 2024, *PLOS Comput. Biol.* 20:e1011914 | 10.1371/journal.pcbi.1011914 | GPU: dense yes, sparse no |
| Norberg et al. 2019, *Ecol. Monogr.* 89:e01370 | 10.1002/ecm.1370 | Joint ≠ better prediction |
| Zurell et al. 2020, *J. Biogeogr.* 47:101–113 | 10.1111/jbi.13608 | Stacked SDMs match joint |
| Wilkinson et al. 2019, *MEE* 10:198–211 | 10.1111/2041-210X.13106 | JSDM software comparison |
| Wilkinson et al. 2021, *MEE* 12:394–404 | 10.1111/2041-210X.13518 | Four-way prediction taxonomy |
| Poggiato et al. 2021, *TREE* 36:391–401 | 10.1016/j.tree.2021.01.002 | Residual correlation ≠ interaction |
| Niku et al. 2019, *MEE* 10:2173–2182 | 10.1111/2041-210X.13303 | The `gllvm` Laplace/TMB route |
| Korhonen et al. 2025, *PeerJ* 13:e20338 | — | `gllvm` 2.0 feature surface |
| van der Veen & O'Hara 2024 | arXiv:2408.05333 | Fast phylogenetic mixed effects |
| Ovaskainen & Abrego 2020, Cambridge UP | 10.1017/9781108591720 | The book as adoption mechanism |
