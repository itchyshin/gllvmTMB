# Does our EVA implement the same algebra as gllvm's EVA?

Curie, 2026-07-30. Worktree `/private/tmp/gllvmtmb-va-in-06`, branch
`claude/va-in-06-20260730`. Diagnostic only — no `R/`, `src/`, `inst/`, or
`dev/totoro-grid/` files were touched. Results stay LOCAL (D-50).

Everything cited below was computed in this session; nothing is carried over
from an earlier claim. Anything I could not directly verify is marked
`AGENT-INFERRED`.

## Answer, up front

**Yes — in-regime, our EVA and gllvm's EVA recover the same latent structure
to within numerical-optimisation noise (median relative disagreement on the
recovered loadings ≈ 6e-05, essentially exact 1:1 scale).** Out-of-regime
(most of the small-`n`/`p` grid), both implementations independently hit the
*same class* of pathology — a runaway coordinate on a near-flat ridge of the
EVA objective — which is symmetric evidence of a shared objective property,
not evidence that the two disagree. See Verdict.

## 0. Blocking pre-check: does gllvm's EVA support the logit link?

**Outcome: (a) — logit IS supported.** This reverses my own first pass at the
question; see the trap below.

`gllvm::gllvm()`'s Usage block defaults to `link = "probit"`, and `?gllvm`'s
Arguments entry reads (`tools::Rd_db("gllvm")`, gllvm 2.0.13):

> `link`: link function for binomial family if `method = "LA"` and beta
> family. Options are "logit" and "probit" and "cloglog".

Read literally this says the `link` **argument** only does anything for
`method = "LA"`. My first round of fits took that at face value and requested
logit via the top-level argument:

```r
gllvm(y = Y, family = binomial(), num.lv = 1, method = "EVA", link = "logit")
```

— and got a result bit-identical to the probit default no matter how I asked
(top-level `link = "logit"`, or `family = binomial(link = "logit")`). That
looked exactly like "probit-only, request ignored" (outcome b), which is what
a prior arc apparently also concluded for gllvm's binary **VA** route
(referenced in my brief; not independently re-checked here since it is a
different method).

**That conclusion was wrong, and re-testing found why.** gllvm has *two*
separate link mechanisms that happened to coincide in my first fits:

1. A top-level `link = ...` **argument** to `gllvm()`.
2. The **family object's own `$link`** component (`family = binomial(link =
   "logit")` vs `family = binomial(link = "probit")`).

Isolating them (num.lv = 0, so no latent-variable confound, `n = 200`,
`p = 6`, plus two independent gllvm-free anchors — plain
`glm(y ~ 1, family = binomial(link = ...))` fit per species column):

| configuration | logL | max\|β̂₀ − glm-logit anchor\| |
|---|---:|---:|
| EVA, top-level `link='logit'`, `family=binomial()` | −798.6615 | 4.46e-05 |
| EVA, top-level `link='probit'`, `family=binomial()` | −798.6615 | 4.46e-05 |
| EVA, `family=binomial(link='logit')` | −798.6615 | 4.46e-05 |
| EVA, `family=binomial(link='probit')` | −798.6615 | 0.446 (matches the **glm-probit** anchor to 5.4e-06 instead) |
| LA, top-level `link='probit'`, `family=binomial()` | −798.6615 | 4.46e-05 |
| LA, `family=binomial(link='probit')` | −798.6615 | 0.446 (matches glm-probit) |

The **top-level `link=` argument has no detectable effect in any
configuration tested** (EVA or LA, num.lv 0 or 1) — rows 1–2 and the LA rows
are identical regardless of what it's set to. The **family object's own
`$link` correctly and independently controls the fit for both EVA and LA**,
matching the corresponding independent `glm()` anchor to ~1e-5 (optimiser
tolerance), for both link choices.

Confirmed with latent variables present (`num.lv = 1`, `n=30`, `p=6`,
`q=1`, the actual `.eva_fit()` regime), `family = binomial(link = "logit")`
vs `family = binomial(link = "probit")` now genuinely diverge: logL
−101.9076 vs −110.2942, and per-species β̂₀ ratios of ~1.2–1.6× (consistent
with the standard logit/probit slope relationship, `AGENT-INFERRED` that the
textbook constant is ≈1.6–1.8; not independently re-derived here).

**Verdict: gllvm::gllvm(family = binomial(link = "logit"), method = "EVA")
is genuine logit-link EVA.** The correct way to request it is via the
**family object**, never the top-level `link=` argument, which is silently a
no-op for binomial regardless of method. This is a real trap in the gllvm API
surface and is the likely explanation for why a same-link comparison was
earlier believed impossible. A genuine same-link comparison against our
`.eva_fit(..., family = "binomial", link = "logit")` is therefore possible,
and everything below uses it.

Script: `dev/va-gate3/eva-parity/precheck-link.R`. Full transcript:
`dev/va-gate3/eva-parity/results/precheck-log.txt`.

## 1. Fixtures

### 1a. Sealed Gate-1 fixtures (`.eva_fixture()`)

Used `"bernoulli"` (N=2, T=2, q=1) and `"bernoulli_q2"` (N=2, T=3, q=2) — the
two Bernoulli fixtures (`"gaussian"` and `"d3_marginal_probe"` are a
different family / a different AGHQ-marginal diagnostic, out of scope here).

**Mapping verification (how I verified it):** for each fixture, the
0-based `(unit_id, trait_id)` long-format triples were reshaped into a wide
`Y` matrix, then reshaped *back* to long form the other way and diffed
against the original. Also checked `sum(y) == sum(Y)` and
`length(y) == N*T == dim(Y)`. **Both fixtures: byte-identical, dims match,
sums match** (`VERDICT mapping_ok: TRUE` in the log for both).

**Why these are not used for truth-recovery.** Two independent reasons,
both checked rather than assumed:

- **N=2 is not a converged fit's coordinate.** The frozen `(beta, theta_rr,
  a, log_A_diag, A_off)` in the JSON is a Gate-1 *objective-value* validation
  probe, not a fitted result. I evaluated our own EVA gradient at that exact
  coordinate: gradient norm 0.987 (bernoulli) and 1.515 (bernoulli_q2) — both
  far from a stationary point. So `beta`/`theta_rr` in the JSON cannot be
  read as ground truth for a recovery comparison.
- **X is a single shared intercept** (`ncol(X) == 1`), not per-species. gllvm's
  default binomial fit estimates one intercept **per species** (`params$beta0`,
  length T). Even feeding both engines the same `Y`, they would not be
  estimating the same thing labelled `beta` without changing the design —
  another reason these fixtures are mapping-check material, not recovery
  material.

**What actually happened when both engines attempted a genuine fit anyway**
(from default/data-driven starts, not the frozen coordinate): on `bernoulli`,
ours returned `failed_health_gate` with β̂ = −144,360 (frozen truth was −3);
gllvm reported `convergence = TRUE` but with a "2 parameter(s) have negative
variance estimates" warning and β̂₀ = (−18.9, ~0) — a degenerate near-perfect
fit (`logL = −1.386294 = log(1/4)`, i.e. the saturated 1-success-in-4 answer).
On `bernoulli_q2`, ours again diverged (β̂ = −269,479); gllvm **R-errored**
("NA/NaN/Inf in foreign function call"). Both engines are degenerate on N=2,
as expected — recorded honestly, not filtered.

Script: `dev/va-gate3/eva-parity/wiring-check.R`. Log:
`dev/va-gate3/eva-parity/results/wiring-check-log.txt`, RDS:
`results/wiring-check-results.rds`.

### 1b. Simulated ladder

Grid: `n ∈ {60, 150}`, `p ∈ {8, 20}`, `q ∈ {1, 2}`, 10 seeds, Bernoulli-logit
= 80 cells. DGP mirrors `dev/totoro-grid/run-grid.R`'s established recipe
(read only, not modified) for continuity with this repo's other VA/EVA
comparisons:

```r
Lt  <- matrix(rnorm(p*q, 0, 0.6), p, q)     # true loadings
u   <- matrix(rnorm(n*q), n, q)             # true latent scores
b   <- rnorm(p, 0.3, 0.3)                   # true per-species intercepts
eta <- sweep(u %*% t(Lt), 2, b, "+")
Y   <- matrix(rbinom(n*p, 1, plogis(eta)), n, p)
Sigma_true <- Lt %*% t(Lt)
```

**Both arms on byte-identical data, and how that was verified.** The same
`Y` feeds both engines: wide directly to `gllvm::gllvm(y = Y, ...)`; long to
`.eva_fit()` via
`lg <- expand.grid(unit=1:n, trait=1:p); lg <- lg[order(lg$unit, lg$trait),]`,
`yv <- as.vector(t(Y))`, `X <- model.matrix(~0+factor(lg$trait))`. Every one
of the 80 cells re-ran the same reconstruct-and-diff check as §1a
(`mapping_ok` column) — **0/80 failures**. Separately confirmed
`factor(1:p)`'s levels sort numerically (1,2,...,20), not lexicographically
(`"1","10",...`), so `X`'s column `j` and `Lambda`'s row `j` both correspond
to species `j` exactly, matching `b[j]` and `Sig_true`'s row/column `j` —
checked directly, not assumed, because a lexicographic mis-sort at `p=20`
would have silently misaligned every `beta`/`Lambda` comparison below.

`X = model.matrix(~0+factor(trait))` also makes `beta` directly comparable to
gllvm's `params$beta0` (both are one coefficient per species) — unlike the
Gate-1 fixtures' single shared intercept in §1a.

Script: `dev/va-gate3/eva-parity/simulate-ladder.R`. Raw output:
`results/ladder-results.csv` (160 rows, one per fit attempt),
`results/ladder-lambda-comparison.csv` (80 rows, one per cell). Full
transcript: `results/ladder-stdout.log`. Total wall-clock: 370 s (6.2 min).

## 2. Every attempted fit is in the denominator

160/160 fit attempts produced a row with an exact status (`==`/`identical`
matching throughout, never `grepl`); zero R-level errors, zero dropped cells.

| engine | status | n |
|---|---|---:|
| ours | `healthy` | 28 |
| ours | `failed_health_gate` | 52 |
| gllvm | `converged` (its own flag) | 79 |
| gllvm | `not_converged` (its own flag) | 1 |

## 3. Convergence flags, recorded but not trusted — and why that mattered

Both engines' self-reported status was cross-checked against one independent,
engine-neutral proxy computed identically for both: `beta_exploded = max(abs(
fitted per-species intercept)) > 15` (true intercepts are ~N(0.3, 0.3); this
threshold matches, without having copied it, the `eta_limit = 15` convention
already used by this repo's own `.va_r3_check_separation()`,
`R/va-r3-proto.R:174` — a genuine independent alignment, checked after the
fact).

| | beta_exploded = FALSE | beta_exploded = TRUE |
|---|---:|---:|
| **ours**, `healthy` | 28 | 0 |
| **ours**, `failed_health_gate` | 4 | 48 |
| **gllvm**, `convergence=TRUE` | 23 | 56 |
| **gllvm**, `convergence=FALSE` | 0 | 1 |

**Our own health gate is a reliable signal here: 28/28 `healthy` rows have no
exploded coordinate (100% specificity), and 48/52 failures do.** gllvm's
`convergence` flag is not: **70.9% of its "converged" fits (56/79) have an
independently-detected exploded coefficient anyway.** This is exactly why the
brief said to record convergence flags but never treat them as health — had I
taken gllvm's flag at face value, 56 badly-diverged fits would have been
counted as successes.

The one cell where gllvm did report `not_converged`
(`n=150,p=8,q=2,seed=6`) also has `beta_exploded=TRUE` and `rel_frob≈9.2e7` —
so its flag was informative exactly once, out of 80.

## 4. What the runaway pathology is (and isn't)

**Not classical marginal separation.** 0/80 cells have a species with a
marginal response rate ≤2% or ≥98% (checked directly). This also means the
freshly-landed `.va_r3_check_separation()` guard (`R/va-r3-proto.R:174`,
commit `08010b02`, present in this worktree's history) would not have
diagnosed it even if EVA had an analogous guard (it doesn't —
`.eva_validate_data()` in `R/eva-proto.R` has no separation check at all):
that guard's own documentation states it "is a detector on the MARGINAL
logistic regression `y ~ X - 1` alone... it makes no claim at all about the
joint `(beta, Lambda, m, L)` surface" (`R/va-r3-proto.R:161-165`). Noted as
context, not proposed as a fix — the pathology here lives exactly in the
surface that guard explicitly disclaims.

**What it looks like instead:** in the one cell inspected in detail
(`n=60,p=8,q=1,seed=1`), no species column is remotely separated (response
counts 25–46 of 60), yet ours' β̂ for species 6 diverged to −5994 while
gllvm's β̂₀ for species **4** diverged to +16.98 — a **different** species on
each side — while the other 6 of 8 species matched almost exactly between
engines (e.g. 0.268 vs 0.269, 1.191 vs 1.190). That pattern — one
implementation's optimiser walking an arbitrary coordinate to an extreme
value while everything else stays put — is a near-non-identifiable ridge in
the *joint* `(beta_j, Lambda_j)` surface for a single species, not a bug
localised to one engine: both engines hit it, just at different coordinates,
consistent with two different optimisers finding different points on the
same flat direction. It also matches a known pathology class already
documented in this project: `docs/design/vgh-phase4-eda-surface-design.md`
records an unrelated (Laplace-vs-VGH) comparison where "one species' loading
running to −119.9 against true loadings of ~0.1–1.5" was diagnosed as a
Heywood case / improper solution — the same qualitative shape. It is also
consistent with the standing repo finding that "EVA binomial fails its
health gate in 20/20 seeds — a genuine property of the Taylor-2 objective...
not a wiring bug" (`docs/dev-log/after-task/2026-07-26-va-eva-jj-engines-and-totoro-grid.md`,
verified there by finite-difference gradient check to 7.9e-9), now also shown
to recur in **gllvm's own** EVA, not just ours.

**Regime dependence** (cells with either engine's beta exploded, of 10
seeds, by n/p/q):

| n | p | q | cells with an explosion |
|---:|---:|---:|---:|
| 60 | 8 | 1 | 9/10 |
| 60 | 8 | 2 | 10/10 |
| 60 | 20 | 1 | 8/10 |
| 60 | 20 | 2 | 10/10 |
| 150 | 8 | 1 | 8/10 |
| 150 | 8 | 2 | 9/10 |
| **150** | **20** | **1** | **2/10** |
| 150 | 20 | 2 | 8/10 |

More data per species (`n=150`) combined with more species (`p=20`) and the
simplest latent structure (`q=1`) is by far the most stable cell; every other
combination explodes in 8–10 of 10 seeds. Overall: **16/80 cells (20%)** have
neither engine's beta exploded — the "clean" subset used below.

## 5. Recovery against known truth

### All 80 cells (dominated by the explosion pathology in §4 — reported for
completeness, not as the headline; medians here are meaningless as point
estimates, only useful to show the contrast with the clean subset)

| engine | median rel_frob | median κ=tr(Σ̂)/tr(Σ_true) | median β RMSE | median seconds |
|---|---:|---:|---:|---:|
| ours | 1.34e9 | 1.09e9 | 1388 | 0.63 |
| gllvm | 2.33e7 | 2.01e7 | 162 | 1.21 |

### Clean subset (16/80, neither engine's beta exploded)

| engine | median rel_frob | median κ | median β RMSE | median seconds |
|---|---:|---:|---:|---:|
| ours | 0.785 | 1.394 | 0.203 | 0.41 |
| gllvm | 0.851 | 1.460 | 0.211 | 0.57 |

Both engines recover `Sigma_B` with similar moderate error at this small
`n`/`p` scale (rel_frob ~0.8, expected for a Taylor-2 surrogate fit to
`n≤150`), both show a similar mild positive bias in `kappa` (over-attributing
~40–46% extra variance to the latent structure — a small-sample bias
direction, not a large or divergent one), and runtimes are the same order of
magnitude (ours slightly faster on the median, gllvm's max is larger: 19.6s
vs 14.4s across all 80 cells).

**Per-cell agreement** (clean subset, `|ours − gllvm| / max(|ours|,|gllvm|)`
on `rel_frob`): median relative difference **2.36e-05**. 14/16 cells agree
to within 2% of each other on this quantity; the remaining 2 are the loading
explosion noted in §6.

## 6. Direct Lambda-vs-Lambda agreement (the actual parity question)

Per Design 85 §9–10 (`docs/design/85-highdim-nongaussian-va-formal-contract.md:297-336`),
raw objective values are never compared across the two implementations, and
"raw loading and score comparisons require sign/rotation alignment" (§9.3).
This repo additionally has an established, reviewed convention for exactly
this comparison: never use raw `Lambda` directly (`R/vgh-verify.R:8-26`);
either align it first (this project's own exported helper
`compare_loadings()`, `R/rotate-loadings.R:428`, explicitly documented as "a
validation helper for comparing `gllvmTMB()` with another implementation"),
or use the rotation-invariant `G = Lambda Lambda'` directly (no alignment
needed at all: `g_rel_frob = ||G_a - G_b||_F / ||G_b||_F`,
`docs/design/vgh-phase4-eda-surface-design.md:69`).

I computed **three** independent versions of this comparison, all on the
clean 16-cell subset:

1. **My own SVD-based orthogonal Procrustes** (`simulate-ladder.R`), rotation
   only (scale fixed at 1) and with a free scale.
2. **The package's own exported `compare_loadings()`**
   (`dev/va-gate3/eva-parity/supplementary-compare-loadings.R`, re-fitting
   the same 16 cells fresh and calling the real function).
3. **`g_rel_frob`** on `G = Lambda Lambda'` — no alignment step, per
   `R/vgh-verify.R`'s convention.

| metric | median (16 cells) | median (14 cells, excl. 2 outliers — see below) |
|---|---:|---:|
| my Procrustes, rotation only | 6.298e-05 | — |
| my Procrustes, rotation+scale | 6.275e-05 | — |
| fitted scale `c` (expect ≈1 under parity) | **0.999998**, IQR [0.99997, 1.00001] | — |
| package `compare_loadings()`, relative | **6.298e-05** (bit-identical to my own Procrustes) | 5.506e-05 |
| `g_rel_frob` (rotation-invariant, no alignment) | 8.940e-05 | 7.815e-05 |
| min correlation-per-factor after alignment | 1.000000 | 1.000000 |

My hand-rolled Procrustes and the package's own `compare_loadings()` agree to
6 significant figures on independently-refit data — cross-validating both
implementations of the same closed-form solution. **The fitted scale factor
is 0.999998**, essentially exactly 1: there is no systematic scale offset
between the two engines' recovered loadings once the link is matched (the
~1.6× offset seen in the precheck's cross-link test in §0 is fully absent
here, as expected once the link genuinely matches).

**The 2 excluded cells** (`n=150,p=8,q=1,seed=8` and `n=150,p=8,q=2,seed=8`):
both pass my `beta_exploded` proxy (β̂₀ under 15) but have `g_rel_frob ≈ 1`
and `min_cor_per_factor` as low as 0.067–0.38 — gllvm's **loading** (not its
intercept) diverged in these two cells while its intercept stayed
plausible. This is an honest gap in my proxy (it only checks the intercept,
not the loading matrix) rather than a hidden problem in the comparison
method: the median-based summaries above are already robust to it (the
16-cell and 14-cell medians differ only in the third significant figure),
and it is reported rather than silently absorbed.

## 7. Context: how this compares to the JJ-vs-gllvm-VA benchmark

The existing benchmark in this repo (`docs/dev-log/after-task/2026-07-26-va-eva-jj-engines-and-totoro-grid.md`)
found our JJ engine and gllvm's `method="VA"` agree to a **median relative
difference of 2.69e-07** on binomial. That is a comparison of two **exact
closed-form/quadrature evaluations of the identical mathematical bound**
(Jaakkola-Jordan = Polya-Gamma mean-field VB), so machine-precision-level
agreement is the right expectation.

EVA is different in kind: both sides are **iterative numerical optima**
found by two independently-written optimisers (ours: `nlminb` + BFGS polish
over an explicit variational-parameter objective; gllvm: its own internal
TMB-based fit) of what is, if the algebra matches, the *same* objective
family but not a byte-identical implementation (different starting values,
different parameterisation of the variational covariance, different
convergence tolerances). Landing within **6e-05 relative disagreement**
under those conditions — about 230× looser than the exact-bound JJ/VA case,
but still agreeing to 4–5 significant figures, with an exactly-1.000 scale
factor and a perfect 1.000000 per-factor correlation — is what "same
algebra, different optimiser path" looks like. A genuine algebra difference
(e.g. a missing or extra term, a different KL convention, a different
Taylor order) would be expected to produce a small but *non-shrinking*,
systematic disagreement across cells and seeds, or a scale factor
detectably off from 1 — neither is observed.

## Verdict

**(i) Same algebra as gllvm's, established in-regime; not (ii) a
merely-defensible different method, and not (iii) buggy.**

- **In-regime** (the 20% of cells where neither implementation's optimiser
  wanders onto the shared near-flat ridge described in §4): the two
  implementations recover statistically indistinguishable `Sigma_B`/`beta`
  against known truth, and their recovered loadings agree directly — after
  rotation alignment, cross-validated two independent ways — to a median
  relative disagreement of ~6e-05 with an exactly-1.000 fitted scale. This is
  the strongest evidence available short of literally sharing source code.
- **Out-of-regime** (the other 80%): both implementations independently hit
  the *same class* of pathology — one species' `(beta, Lambda)` combination
  running away on an apparently near-non-identifiable ridge — which is a
  symmetric, shared property (both sides do it, on different coordinates,
  consistent with different optimiser paths on the same flat direction), not
  a divergence between them. It also matches this project's own prior,
  independently-derived finding that EVA's health-gate failure is "a genuine
  property of the Taylor-2 objective... not a wiring bug," now confirmed to
  recur in gllvm's own EVA as well (gllvm's `convergence=TRUE` flag fires on
  70.9% of exploded fits — its self-report just doesn't surface the same
  pathology as a failure the way ours does).
- The genuinely informative structural finding on the way to this verdict is
  the **link trap** in §0: gllvm's top-level `link=` argument is a silent
  no-op for binomial VA/EVA/LA in every configuration tested, and the family
  object (`family = binomial(link = "logit")`) is what actually controls it.
  A prior belief that no same-link comparison was possible is plausibly
  attributable to that trap rather than to an actual probit-only restriction
  in EVA.

## Caveats and what is AGENT-INFERRED

- The ~1.6–1.8× logit/probit slope-ratio cited in §0 as "the standard
  relationship" is `AGENT-INFERRED` background knowledge, not re-derived in
  this session; it was used only as a plausibility check, and the decisive
  evidence there is the independent `glm()` anchor match (~1e-5), which was
  computed, not inferred.
- The claim that gllvm's binary **VA** (not EVA) route is probit-only, cited
  in my brief as established by a prior arc, was **not** independently
  re-tested here — my precheck only concerns `method="EVA"`. Given how
  wrong my own first pass at EVA's link handling was, that VA-side claim
  should not be assumed safe without its own family-object-based re-test.
- The 20%-of-cells "clean" figure and everything downstream of it is
  specific to this exact DGP (loadings ~N(0,0.6²), intercepts ~N(0.3,0.3),
  `n≤150`, `p≤20`) mirrored from `dev/totoro-grid/run-grid.R` for continuity;
  it is not a general statement about how often EVA is usable in practice.
- `beta_exploded` (threshold 15 on the intercept) is an incomplete proxy for
  "did anything diverge" — §6 documents the one place this was caught
  (2 cells with a diverged loading but a plausible intercept). No claim in
  this report depends on `beta_exploded` alone without that caveat attached.
- Neither `.eva_fit()` (`R/eva-proto.R`) nor its `.eva_validate_data()` calls
  a separation guard analogous to `.va_r3_check_separation()`
  (`R/va-r3-proto.R:174`); noted as context in §4, not as a recommended fix,
  since that guard's own documented scope would not have caught the joint
  `(beta, Lambda)` pathology observed here even if ported.

## Files

All under `dev/va-gate3/eva-parity/` (this worktree only; not staged for
`main`):

- `precheck-link.R` → `results/precheck-log.txt` — §0, the canonical,
  reproducible precheck (supersedes ad hoc interactive probes run earlier in
  this session and not kept).
- `wiring-check.R` → `results/wiring-check-log.txt`,
  `results/wiring-check-results.rds` — §1a.
- `simulate-ladder.R` → `results/ladder-results.csv` (160 rows),
  `results/ladder-lambda-comparison.csv` (80 rows), `results/ladder-results.rds`,
  `results/ladder-stdout.log` (full transcript) — §1b–§5.
  (`results/ladder-log.txt` is an unused 0-byte artefact of an unwired `sink()`
  handle in this script; the real transcript is `ladder-stdout.log`.)
- `analyse-ladder.R` → `results/ladder-results-annotated.csv` — §2–§5
  summary computation.
- `supplementary-compare-loadings.R` → `results/clean-cells-compare-loadings.csv`,
  reads `results/clean-cells.csv` — §6, the `compare_loadings()`/`g_rel_frob`
  cross-validation.

Every number in this report was recomputed in this session from these
scripts; none is carried over from a prior claim.
