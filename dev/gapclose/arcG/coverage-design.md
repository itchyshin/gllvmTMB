# Design: repeated-sampling coverage of `ordination_uncertainty()`

Status: **DESIGN ONLY. No package code, no `dev/` campaign script has been
run, no compute has been touched.** This document follows the ADEMP
framework (Morris, White & Crowther 2019, *Stat Med* 38:2074-2102) and the
Williams et al. (2024, *MEE* 15:1926-1939) 11-item reporting checklist; a
self-audit against both closes the document.

Owner: unassigned. Register row this would eventually inform: EXT-38
(`docs/design/35-validation-debt-register.md:410`), currently `partial`.
**This document does not propose promoting EXT-38** — that is a maintainer
decision downstream of evidence this design has not yet produced.

Capability under study: `ordination_uncertainty()`, `R/ordination-uncertainty.R`
(shipped 2026-09-03, PR #1253, issue #1243). Read in full from
`origin/main` before writing this design; every claim about current
behaviour below cites file and line from that read.

---

## 0. Why a coverage study is not a routine addition here

The register row states plainly: *"no repeated-sampling coverage campaign
has been run for either `se` or `cov`"* (`docs/design/35-validation-debt-register.md:410`).
That sentence undersells the difficulty. `ordination_uncertainty()` returns
the covariance of a **random effect**, not a fixed parameter — and "coverage"
for a random-effect interval is not one question but at least two that
disagree with each other by construction (Section 2). A design that skips
straight to "run N seeds, check coverage, report a percentage" would answer
a question nobody asked and could report a passing number that means
nothing. Sections 1-2 settle the estimand before anything is gridded.

---

## 1. The estimand, in one sentence a reader can check

> For unit `s` and latent axis `k`, does the Wald interval
> `z_hat[s,k] ± z_{1-alpha/2} * se[s,k]` — built from `ordination_uncertainty()`'s
> own `se` (equivalently `sqrt(diag(cov[,,s]))`, `R/ordination-uncertainty.R:290-296`)
> — contain the DGP's true latent score `u_true[s,k]`, **after a single
> global per-axis sign alignment applied to the whole fit** (Section 3),
> at the rate its nominal level `1 - alpha` promises?

A reader can check this directly: pick one simulated unit, read off
`z_hat`, `se`, apply `qnorm(1 - alpha/2)`, and ask whether the (sign-aligned)
truth used to generate that unit's data falls inside the two numbers.
Coverage is the proportion of `(unit, replicate)` pairs, restricted to
converged fits with a positive-definite Hessian (Section 5), for which
containment holds.

**Secondary estimand (Section 8.3):** the joint (per-unit, all-axes)
Mahalanobis statistic `m_s = (z_hat_s - u_true_s)' Cov_s^{-1} (z_hat_s - u_true_s)`
against `qchisq(1-alpha, df = d)` — the exact quantity
`ordiplot(ellipse = TRUE)` draws (`R/ordination-uncertainty.R:326-333`,
`.gllvmTMB_ellipse_xy()`). The univariate interval is the primary target
because it is the simpler, more falsifiable check and it is what `se`
alone (without `cov`'s off-diagonal) already promises; the ellipse check
reuses the same fits at no extra compute and is the one that actually
validates the feature the package advertises for `ordiplot()`.

---

## 2. Which coverage — marginal or conditional — and why

**This design measures marginal coverage as the primary target.** Marginal
coverage is taken over the joint distribution of `(u, y)`: each simulation
replicate draws a *fresh* true latent score `u_s ~ N(0, I_d)` for every
unit, generates data from it, refits, and asks whether the interval built
from that one fit contains that replicate's own truth. This is:

- **The design every existing recovery campaign in this repo already runs**
  (`dev/gapclose/arcD/recovery/RESULTS.md`, `dev/gapclose/arcF/recovery/RESULTS.md`
  both redraw the true latent field every seed) — reusing that
  infrastructure (Section 8) means this design adds one estimator on top of
  an already-vetted campaign shape, not a new one.
- **The practically relevant question for `ordiplot(ellipse = TRUE)`'s
  actual users**: a reader fits the model once to their own dataset and
  draws one ellipse per site. They cannot ask "conditional on my sites'
  unknown true scores, is my ellipse calibrated" because they never learn
  their own truth. What marginal coverage answers instead is: *"across the
  population of datasets and true latent configurations this model could
  plausibly have been fit to, how often does the reported ellipse contain
  the truth?"* That is the frequentist guarantee a Wald interval can
  actually claim, and it is the one this package's own docs gesture at
  when they call the estimand "closer to a prediction interval than a
  confidence interval" (`R/ordination-uncertainty.R:97-101`).

**Conditional coverage — at one FIXED true score, varying only the
resampled data — is expected to be worse, and is measured for free as a
diagnostic, not as a second campaign.** The standard random-effects result
(shrinkage / BLUP theory; e.g. the small-area-estimation MSE literature,
Prasad & Rao 1990, *JASA* 85:163-171, though this design does not depend
on that specific citation, only on the qualitative mixed-model fact that a
naive conditional-variance interval omits estimation error in the
variance components) is that an interval built from
`Var(u | y, theta_hat)` has approximately correct **marginal** coverage
while being **conditionally** wrong in a structured way: too *wide* near
the centre of the latent distribution (shrinkage pulls `z_hat` toward
zero more than the interval's fixed half-width accounts for, so intervals
centred near `u = 0` tend to already contain the truth almost trivially)
and too *narrow* in the tails (a unit with a large true `|u|` gets
shrunk toward zero harder, so the interval, still centred near the
shrunk `z_hat`, is more likely to miss the true, larger-magnitude value).

Rather than run a second, separately-designed fixed-truth campaign, this
design **exploits the marginal campaign's own pooled data**: because
`u_true` is drawn continuously and independently every replicate, and the
grid (Section 4) accumulates many thousands of `(unit, seed)` pairs, those
pairs can be **binned by `|u_true|`** after the fact and coverage computed
within each bin. A bin is an approximation to "coverage at a fixed true
score" (it is coverage over a narrow band of true scores, not literally
one point), but it costs zero extra compute and is where the shrinkage
prediction becomes checkable: coverage should be highest in the
smallest-`|u_true|` bin and fall off in the largest-`|u_true|` bin, and
the gap between bins is exactly the signature the conditional-coverage
theory predicts, while the pooled-over-all-bins number is the marginal
coverage headline. Section 8.2 has the concrete binning and the
clustering caveat (units within one fit share `theta_hat`, so per-bin
counts are not i.i.d.; see Section 6's MCSE treatment).

**If the two disagree in the predicted direction** (marginal near
nominal, binned-conditional showing the wide-near-zero / narrow-in-tails
pattern), that is not a defect to fix — it is the DGP-theory prediction
confirmed, and the write-up should say so in exactly those terms, per the
task's own framing. **If they do not** — e.g. conditional coverage is flat
across bins, or marginal itself is badly off — that is the more
interesting, reportable finding (Section 6 pre-declares which pattern
counts as "expected" vs. "surprising").

---

## 3. Sign alignment (identifiability)

**Established from the source, not assumed.** `gll_unpack_rr_loadings()`
(`src/gllvmTMB.cpp`, cited at `R/ordination-uncertainty.R:33`) packs
`Lambda_B`/`Lambda_W` with a **structurally zero** strict upper triangle
and a **free-signed** diagonal. By the uniqueness of the lower-triangular
(QR-style) decomposition, the only orthogonal transform that keeps a
generic invertible lower-triangular matrix lower-triangular is a diagonal
signature matrix (entries in `{-1, +1}`) — so `rotate = "none"` scores are
identified **up to a per-axis sign flip only, never a continuous
rotation and never an axis permutation** (`R/ordination-uncertainty.R:33-46`).
The task brief's own framing ("verified 2026-09-03: the strict upper
triangle is exactly zero") matches this reading exactly.

**Consequence for `d >= 2`: nothing beyond sign needs handling.** Each of
the `d` axes has its own independent sign ambiguity (one flip per axis,
`2^d` possible global flip patterns for a `d`-axis fit), but no
permutation or continuous rotation is in play, so the alignment procedure
below is the *complete* fix, not a partial one. This is a structural claim
established by the packing, not an empirical one this design needs to
re-derive — but it is worth a cheap built-in check (below) precisely
because "the theory says so" and "the shipped C++ actually behaves that
way on every simulated fit" are different claims, and only the second is
what a coverage campaign can certify.

**Alignment procedure — one global decision per axis per fit, never per
unit:**

1. For fit `f` and axis `k`, compute `rho_k = cor(z_hat[, k], u_true[, k])`
   pooling over all `n` units in that one fit (the DGP's true score
   matrix is fully known in simulation).
2. Set `s_k = sign(rho_k)` (or `s_k = +1` by convention if `rho_k` is
   exactly `0`, which should not occur with continuous data). Multiply
   the fit's *entire* column `k` of `z_hat` (equivalently, flip axis `k`'s
   truth) by `s_k` before computing containment.
3. Apply the *same* `s_k` to every unit `s` in that fit — the flip is a
   property of the fit's axis, not of any individual unit or replicate
   draw within it.

**Gap closed 2026-09-04 (orchestrator): a WEAK axis is not a coverage
failure, and must not be reported as one.** The procedure above assumes
`rho_k` is decisively signed. The document notes that an exact `rho_k = 0`
will not occur with continuous data, which is true and beside the point —
the hazard is `rho_k` merely *small*. At the smallest cells (`n_units = 40`,
or the weakly-loaded axis of a `d = 2` fit) the axis may simply not be
recovered; the sign is then close to a coin flip, and roughly half those
fits get the orientation wrong. That produces near-total interval failure
which would be tabulated as catastrophic undercoverage, when the real
finding is *"this cell does not identify the axis at all"*. Those are
different results and only one of them is about calibration.

Therefore: **record `|rho_k|` for every (fit, axis) and report its
distribution per cell alongside coverage.** Pre-declare a weak-axis
threshold, treat cells whose `|rho_k|` mass sits near zero as
**uninformative about coverage** rather than as failures, and report the
count either way rather than dropping them silently. If a cell is
uninformative, that is a finding about the identifiability floor and
belongs in the write-up as such.

**Why this does not manufacture coverage.** The flip is a **single binary
decision per axis per fit** (`2^d` possible outcomes for a `d`-axis fit,
independent of `n`), resolved once using the *global* correlation between
the whole score vector and the whole truth vector — never by choosing,
per unit or per interval, whichever hemisphere happens to make that one
interval succeed. The two candidate orientations (`s_k = +1` vs. `s_k =
-1`) are the *only* two hypotheses about which fixed labelling the
package's arbitrary-sign optimizer settled on for that fit; picking
between them with the truth (available only because this is a
simulation) resolves a nuisance transformation that is mathematically
tied to the same estimator (loadings and scores flip together because
`eta = Lambda z` is invariant to `(Lambda, z) -> (-Lambda, -z)`) — it does
not touch the *magnitude* of `z_hat` or the *width* of the interval,
which are the only two quantities coverage actually depends on. A unit
whose interval would fail under the correct orientation still fails after
alignment; alignment only prevents the ~50%-of-axes rate of trivial,
uninformative failure that would result from comparing against the wrong
global label.

**Cross-check, reported not enforced:** also compute `s_k` from
`cor(Lambda_hat[, k], Lambda_true[, k])` (the loadings, via the existing
`compare_loadings()` machinery, `R/rotate-loadings.R:428-448`, though that
helper's full Procrustes rotation is *not* used here — only its
sign-relevant SVD intuition — because a full orthogonal rotation is
strictly more general than this fit's actual identifiability class and
using it would silently paper over a real permutation bug were one to
exist). If the loadings-based and scores-based sign decisions disagree
for some fit, record it as a per-fit diagnostic flag rather than silently
picking one — disagreement would itself indicate a weakly identified axis
(the two flip decisions were compared, not adjudicated, for exactly the
`|rho_k|` near zero case Section 3 anticipates) worth surfacing.

**Shrinkage, named as a side quantity, not folded into the coverage
number.** Because `z_hat` is a posterior-mode estimate under a `N(0, I)`
prior on `u`, it is shrunk toward zero relative to the true DGP draw by
construction — correct behaviour for the estimand, not a defect. This
design reports the linear attenuation slope of `z_hat` regressed on the
sign-aligned `u_true` (pooled per grid cell) alongside coverage. A slope
`< 1` is expected and increasingly so at smaller `n_units`; it is **not**
itself a pass/fail criterion, but its magnitude will visibly track the
conditional-coverage bin pattern from Section 2 and is worth reporting in
the same table so a reader sees the mechanism, not just the symptom.

---

## 4. Data-generating mechanism (Williams item 2)

**Reused, not invented:** `simulate_site_trait()` (`R/simulate-site-trait.R`),
exactly the DGP `test-ordination-uncertainty.R` already uses for its own
numeric checks — the `.ordu_fit_K1` (`d = 1`) and `.ordu_fit_K2` (`d = 2`)
fixtures. This is the right DGP to reuse for three reasons: (1) it is the
DGP the function's own correctness tests are built on, so choosing it
means the coverage study inherits a fixture whose point-estimate
machinery is already independently verified (dense-`solve()` cross-check,
`tests/testthat/test-ordination-uncertainty.R`); (2) it is a Gaussian
response, matching `ordination_uncertainty()`'s only currently-supported
likelihood surface for this kind of check (Section 7 names why
non-Gaussian is out of scope); (3) it produces multiple observation rows
per `(site, trait)` cell (`mean_species_per_site` replicate species per
site), giving each site's score genuine within-fit replication rather
than a single observation per cell, matching how the shipped fixtures are
built.

**Hierarchical structure:** site `s = 1..n_units`, species `i` nested
within site (Poisson-thinned, mean `mean_species_per_site`, truncated at
`n_species`), trait `t = 1..n_traits`. One row per `(site, species,
trait)` triple.

**Latent structure:** `u_s ~ N(0, I_d)` (unit-level latent score,
between-site tier). `eta_{sit} = alpha_t + Lambda_B[t, ] %*% u_s`,
`y_{sit} ~ N(eta_{sit}, psi_B[t])` (Gaussian response, unit-level `latent()`
term only — no within-site LV component, matching the shipped fixtures).

**Fit formula (exactly the fixtures'):**
`value ~ 0 + trait + latent(0 + trait | site, d = d)`, `unit = "site"`.
Default `gllvmTMBcontrol()` (`se = TRUE`) throughout, so `sd_report` and
`pdHess` are always available.

**Loadings / intercepts, fixed per grid cell (not redrawn per seed —
`u_s` and residual noise are what vary across seeds):**

- `n_traits = 4` cells reuse the K2 fixture's own
  `Lambda_B = matrix(c(1.0, 0.7, -0.3, 0.5, 0.3, -0.5, 0.8, 0.2), nrow=4, ncol=2)`
  (`tests/testthat/test-ordination-uncertainty.R`, `.ordu_fit_K2`) for
  `d = 2` cells, and its own first-column subset (or the K1 fixture's
  `matrix(c(0.9, 0.6, -0.4, 0.5), nrow=4, ncol=1)`) for `d = 1` cells;
  `psi_B = rep(0.3, 4)`; `alpha` left `NULL` (simulator default,
  documented random but seeded by the DGP's own `seed=`).
- `n_traits = 8` cell (the parameter-count axis, Section 4's grid):
  append 4 more traits' loadings drawn **once**, fixed for the whole
  design (not per replicate), from the same magnitude band as the K2
  fixture (`runif(4, 0.3, 1.0)`, random sign, one draw, hard-coded into
  the campaign script once chosen) and `psi_B = rep(0.3, 8)`. This keeps
  the identifiability regime comparable across the `n_traits` axis rather
  than introducing a second uncontrolled source of variation.

**Conditions varied — the grid (Section 5's justification per axis):**

| Factor | Levels | Axis purpose |
|---|---|---|
| `n_units` (`n_sites`) | 40, 80, 160, 320 | Section 2's falsifiable prediction: undercoverage gap should shrink as `n_units` grows (more data to estimate `theta`, less fixed-parameter uncertainty relative to the score covariance) |
| `d` (latent rank) | 1, 2 | Isolates whether the joint-precision block extraction itself, not just the QR-uniqueness argument, is right for the off-diagonal (cross-axis) case — matches the K1/K2 fixture split exactly |
| `n_traits` | 4, 8 | A second, independent route to more fixed-parameter uncertainty (more loadings + intercepts to estimate) without adding units — tests whether the undercoverage driver is really "how much fixed-effect uncertainty is there" rather than merely "how many sites" |

Grid: `n_traits = 4` crossed with `d in {1,2}` and `n_units in
{40,80,160,320}` = 8 cells, plus `n_traits = 8` at `d = 2`,
`n_units = 80` only (one additional cell, not a full second `n_traits`
sweep — kept to the single cell that isolates the parameter-count effect
against the `n_traits=4, d=2, n_units=80` cell already in the primary
grid) = **9 cells total**.

`mean_species_per_site` is held fixed at 6 (the K2 fixture's value)
across every cell — deliberately not varied; Section 7 names this as an
axis the study will not establish.

**Seeds:** 1:500 per cell, disjoint from the shipped fixtures' own seeds
(2101 for K1, 2025 for K2) — new evidence, no overlap, matching
`dev/gapclose/arcF/recovery/RESULTS.md`'s convention. Section 6 justifies
500 by its MCSE.

**Fits per cell:** 500. **Total fits: 9 x 500 = 4,500.**

---

## 5. Acceptance criterion (pre-declared) and what counts as failure

**Nominal levels checked:** 90% and 95% (two-sided Wald,
`z_{1-alpha/2}` from `qnorm`), following this repo's existing convention
of reporting both (`docs/dev-log/2026-08-15-missing-data-evidence-chapter-DRAFT.md`'s
Wave-1 table reports both 90% and 95% together).

**Primary metric, per cell, per nominal level:** empirical coverage
pooled across all `(unit, seed)` pairs from converged, positive-definite-
Hessian fits (Section 5's convergence bookkeeping below) restricted to
`level = "unit"`.

**Pre-declared bands** (MCSE derivation in Section 6):

- **Consistent with nominal:** empirical coverage within nominal ±
  `3 x MCSE_cluster` (~±2.9 percentage points at 500 seeds, Section 6).
  This is a null result — the interval performs as its Wald construction
  would suggest, and Section 2's marginal-coverage argument is not
  contradicted.
- **Predicted undercoverage (expected, not a failure):** coverage below
  nominal by more than `3 x MCSE_cluster`, **and** the gap (nominal minus
  observed) is non-increasing across `n_units in {40, 80, 160, 320}` at
  matched `d`/`n_traits`. This is Section 2's headline prediction; finding
  it is the design working as intended, not the package failing.
- **Failure / surprise, needing investigation before any register
  wording:**
  1. Coverage **below** nominal by more than `3 x MCSE_cluster` that does
     **not** shrink (flat or widens) as `n_units` grows — falsifies the
     fixed-parameter-uncertainty account and would point at something
     else (e.g. a defect in the joint-precision block extraction that
     the existing `1e-6`-tolerance point checks in
     `test-ordination-uncertainty.R` did not catch because they check
     numerical agreement with an independent `solve()`, not calibration
     against a known truth).
  2. Coverage **above** nominal by more than `3 x MCSE_cluster` at any
     cell — the theoretical account (Section 2) gives no mechanism for
     an interval built from a plug-in conditional variance to be too
     *wide*; overcoverage would be the more interesting and more urgent
     finding of the whole study.
  3. The binned-by-`|u_true|` conditional-coverage curve (Section 8.2)
     failing to show the predicted shape (highest near `u=0`, falling in
     the tails) — would suggest the marginal/conditional account from
     mixed-model theory does not transport cleanly to this specific
     joint-precision estimator, which is itself a legitimate, reportable
     result distinct from a calibration failure.
- **Secondary (ellipse) metric, same bands:** empirical proportion of
  `(unit, seed)` pairs with `m_s <= qchisq(1 - alpha, df = d)` compared
  against `1 - alpha`, same MCSE-based bands. Reported only for `d = 2`
  cells (the `d = 1` case has no cross-axis term and reduces to the
  univariate check).

**Convergence and PD-Hessian bookkeeping (never silently dropped, Williams
item 10b):** every cell reports `convergence == 0` rate and `pdHess`
rate separately, mirroring `dev/gapclose/arcD/recovery/RESULTS.md` and
`dev/gapclose/arcF/recovery/RESULTS.md`'s tables. Coverage is computed
only among fits with both `convergence == 0` and `pdHess == TRUE` (a
non-PD Hessian makes `ordination_uncertainty()` itself return `NA` with a
warning, `R/ordination-uncertainty.R:225-235` — those rows genuinely
carry no interval to check). If either rate falls materially below 100%
at any cell, that rate is reported alongside coverage, not folded into
the denominator silently.

---

## 6. Monte Carlo standard error for the seed count

**The correct unit of replication for MCSE is the seed, not the
(unit, seed) pair.** Within one fit, all `n_units` scores share the same
`theta_hat` (loadings, intercepts, dispersion) and the same joint
precision `Q`, so their coverage outcomes are correlated — a naive
`sqrt(p(1-p) / (n_units * n_seeds))` formula would understate the true
MCSE by treating within-fit draws as independent. The defensible
approach: for each seed, compute that seed's own coverage proportion
(averaged over its `n_units` sites), then treat the 500 per-seed
proportions as the (approximately) independent replicates and compute
`MCSE = sd(per-seed coverage) / sqrt(500)`.

**A conservative upper bound**, usable now without running anything,
treats each seed's per-seed coverage proportion as if it had the
worst-case Bernoulli variance `p(1-p)` at `p = 0.95` (this over-states
the true per-seed variance, because averaging over `n_units` within a
seed can only reduce it, so this bound is safe, not optimistic):
`MCSE <= sqrt(0.95 * 0.05 / 500) ~= 0.0097` (~1.0 percentage point) at
95% nominal, and `sqrt(0.90 * 0.10 / 500) ~= 0.0134` (~1.3 points) at
90% nominal. Both clear the simulation-design skill's "MCSE <= ~1%"
target band at `n_sim ~ 500` (see `references/williams-2024-checklist.md`'s
companion MCSE table). The actual (non-conservative) MCSE, computed from
the empirical `sd()` of the 500 per-seed proportions once the campaign
runs, will be reported alongside every coverage number per Williams item
11 — this pre-registered bound is what justifies the seed count in
advance, not what gets reported as the final answer.

`3 x MCSE` (Section 5's band width) is therefore approximately ±2.9
percentage points at 95% nominal and ±4.0 points at 90% nominal, using
the conservative bound.

---

## 7. What this study will NOT establish

- **Any non-Gaussian family.** `ordination_uncertainty()` is not
  family-restricted in its own code, but every existing numeric check
  (`test-ordination-uncertainty.R`) and this design's DGP are Gaussian.
  Binomial/Poisson/etc. curvature is genuinely different (non-quadratic
  log-likelihood near the mode) and coverage there is a **separate,
  unmeasured** question this design does not answer, even by
  extrapolation.
- **`level = "unit_obs"` (the within-unit, `z_W`, tier).** Wired through
  the identical code path (`R/ordination-uncertainty.R:221-224`) but with
  no dedicated point-estimate cross-check even in the shipped test file
  (register row EXT-38's own text says so) — building its DGP (within-
  unit replication as the LV target, not between-site) is a different
  simulator and a natural follow-up, not a free extension of this one.
- **Rotated scores** (`rotate = "varimax"` / `"promax"`) — the function
  does not compute a covariance for them at all
  (`R/ordination-uncertainty.R:111-123`); there is nothing to measure.
- **Every refused fit class** (Section 8's list) — `engine = "julia"`,
  `integration = "va"`, `estimator = "mspl"`, likelihood-weighted fits,
  predictor-informed `latent(..., lv = ~x)` fits, and fits without
  `sdreport()` all error before returning an interval-bearing object.
- **Spatial (`spatial_latent`) or phylogenetic (`phylo_latent`)
  structure**, augmented-slope terms, missing-data interactions, multiple
  latent terms in one fit, or mixed-family fits — none are exercised;
  each changes the loading/covariance structure in ways this design's
  single reused DGP does not probe.
- **`d > 2`.** The QR-uniqueness argument in Section 3 is general to any
  `d`, but this design only exercises `d in {1, 2}`, matching the
  shipped fixtures; a `d = 3+` cell would need a new hand-verified
  fixture and is out of scope here.
- **Sensitivity to `mean_species_per_site`** (observation replicate
  depth per site) — held fixed at 6 throughout; not an axis of this
  grid.
- **True conditional coverage at one exact fixed score** — Section 2's
  binned approximation is a diagnostic, not a substitute for a
  purpose-built fixed-truth design (which would need units whose true
  score is held constant across many independent data redraws, a
  different campaign shape entirely).
- **Any claim about `predict_missing()`, `predict(newdata=)`, or other
  prediction-uncertainty surfaces** — those are separate estimands under
  separate design documents (Design 119, Design 129) already in this
  repo; this design is scoped to `ordination_uncertainty()` alone.

---

## 8. Refusal surface

`ordination_uncertainty()` refuses, each with a distinct error class
(`R/ordination-uncertainty.R`):

| Refused class | Line | Why |
|---|---|---|
| `engine = "julia"` bridge fits | :177-182 | no native TMB `sdreport` |
| `integration = "va"` fits | :184-189 | different, unvalidated approximate posterior |
| non-`gllvmTMB_multi` fits | :191-195 | wrong object type |
| predictor-informed `latent(..., lv = ~x)` at `level = "unit"` (`fit$use$lv_B`) | :205-210 | mean-term uncertainty not propagated |
| fits with no `sd_report` (`se = FALSE`) | :214-219 | no curvature to read |
| non-PD Hessian | :225-235 | returns `NA` with a warning, not an abort |
| `estimator = "mspl"` fits | via `.gllvmTMB_mspl_assert_inference()` (called before the above) | separate inference machinery |
| likelihood-weighted fits | via `.gllvmTMB_require_unweighted_inference()` | weighting changes the estimand |

**None of these belong in this coverage study.** Each refusal (except the
non-PD-Hessian case, which is a degenerate *result* the study already
tracks per Section 5) means the function does not return an
interval-bearing object at all — there is no `se`/`cov` to check coverage
of, so a "coverage" arm for a refused class is not a smaller or harder
version of this study, it is a different, currently unanswerable
question ("what would calibrated inference look like for a route this
function does not implement"). Any of those is a legitimate *separate*
design (e.g. a future VA-specific coverage study once VA's own posterior
gets its own validation), not a cell missing from this one.

---

## 9. D-139 compute estimate

**This is a guess with a stated basis, not a measurement — nothing in
this design has been run.**

**Per-fit cost has two components that this design deliberately does not
conflate:**

1. **The model fit + the extra `sdreport(fit$tmb_obj, getJointPrecision =
   TRUE)` call** (`R/ordination-uncertainty.R:246`, a *second* `sdreport()`
   beyond the fit's own production call at `getJointPrecision = FALSE`).
   Basis for the estimate: Design 129's own measurement
   (`docs/design/129-prediction-uncertainty-new-locations.md`, "S0b Q2")
   found `getJointPrecision = TRUE` costs **no material overhead** over
   `FALSE` at two tested joint-precision sizes (dimension 255: 0.46s vs.
   0.44s; dimension 2,130: 6.17s vs. 6.34s) — closer to linear than
   quadratic in the tested range, not the O(P^2) pathology Design 108
   found in a *different* code path (dense `nlminb` workspace at
   `random = NULL`, which does not apply here). This design's largest
   cell (`n_units = 320`, `n_traits = 8`, `d = 2`) has a joint-precision
   dimension on the order of a few hundred (roughly `n_units * d +
   n_traits * (d + 1) + dispersion terms`, well under Design 129's
   2,130-dimension test point), so the extra `sdreport()` call itself is
   expected to be cheap — plausibly comparable to or cheaper than the fit
   itself. Base fit time: this design's Gaussian, small-`n_units`,
   rank-1/2 fits are structurally simpler than `dev/gapclose/arcF`'s
   `ordinal_logit`/`censored_poisson` fits (no cutpoints, no censoring
   likelihood), whose own largest cells (`n_unit = 1200`,
   `n_site = 800`) ran at 2.3s and 4.1s median on Totoro
   (`dev/gapclose/arcF/recovery/RESULTS.md`). **Estimate: 1-4 seconds for
   the fit itself across this grid's sizes, plus a comparable or smaller
   amount for the extra `sdreport()` call.**

2. **The sparse multi-RHS solve inside `ordination_uncertainty()` itself
   — flagged here as the likely cost driver, and currently
   UNMEASURED anywhere in this repo** (a search of every prior
   `getJointPrecision` timing note in `docs/` and `dev/` — Design 108,
   Design 119, Design 129, `dev/getlv-score-se-RESULTS.md` — found timing
   only for the `sdreport()` call itself, never for what happens next).
   `ordination_uncertainty()` builds a sparse indicator matrix `W` with
   `d * n_units` columns and calls `Matrix::solve(Q, W)`
   (`R/ordination-uncertainty.R:266-279`) — a sparse solve against **as
   many right-hand sides as there are latent-score parameters**, not a
   single solve. Design 129's S0b measurement never exercised a
   multi-column solve of this kind; it measured only `sdreport()` and a
   50-draw sparse-Cholesky *sample* (a different, much smaller operation:
   1.7ms for 50 draws at dimension 255). At this design's largest cell
   (`n_units = 320`, `d = 2`), `W` has **640 columns** — an order of
   magnitude more RHS columns than anything previously timed in this
   repo. Sparse solves with many RHS columns can scale worse than
   linearly in the column count depending on the solver's factorisation
   reuse, so this is genuinely unknown, not merely unverified.
   **Estimate: unknown; could range from negligible (if the sparse
   Cholesky factorisation is reused efficiently across columns, as
   `Matrix::solve()` on a `dsCMatrix`/`dgCMatrix` typically does) to
   several seconds at the largest cell if it does not.**

**Total core-hours, presented as a range bounded by (1) alone (optimistic,
ignoring the flagged unknown) and a cautious multiplier for (2):**

- Optimistic (fit + extra `sdreport()` only, ~2-8s/fit across the grid,
  weighted toward the low end since most cells are smaller than the
  largest): 4,500 fits x ~3s average ~= 13,500 core-seconds ~= **3.75
  core-hours**.
- Cautious (adds an assumed 2-5x multiplier at the largest 2-3 cells for
  the unmeasured solve step, without any basis stronger than "this is the
  flagged unknown"): plausibly **6-12 core-hours** total.

**Both estimates are well past the D-139 30-minute line**, so per that
discipline this design does not get launched on this estimate alone. The
concrete next step, exactly as the task specifies: **a pre-run test**
before any grid launch —

1. One fit at the single largest cell (`n_units = 320`, `n_traits = 8`,
   `d = 2`), one seed, outside the 1:500 campaign set (matching
   `dev/gapclose/arcF`'s and `arcD`'s own pre-run convention of a seed
   outside the main range).
2. Time three things **separately**, not as one number: (a) the model
   fit itself, (b) the `sdreport(getJointPrecision = TRUE)` call, (c) the
   `Matrix::solve(Q, W)` step inside `ordination_uncertainty()` — the
   function would need a one-line timing instrument around that call, or
   the three steps can be run by hand outside the function using the same
   `fit$tmb_obj` (the function's own code is short enough to replicate
   inline for this purpose without modifying the package).
3. If (c) is comparable to or smaller than (a)+(b), the optimistic
   estimate above stands and the full grid is a same-day Totoro run well
   under the >30-min approval line once multiplied out at ~100 cores. If
   (c) dominates and scales with `n_units * d` faster than linearly, the
   grid's largest `n_units` cells should be re-costed (or trimmed) before
   asking for launch approval — this is exactly the scenario the pre-run
   exists to catch, matching Design 108's own lesson about not trusting
   an un-timed code path at the top of a grid.

**For reference (task-supplied anchor):** a recent 300-fit recovery
campaign on this package cost 0.19 core-hours on Totoro
(`dev/gapclose/arcF/recovery/RESULTS.md`, 666.7 core-seconds for 300
fits). This design's 4,500 fits, at that reference rate alone (ignoring
both of this function's extra costs above), would be ~2.85 core-hours —
consistent with the "optimistic" bound above and reinforcing that the
extra `sdreport()`/solve overhead, not the base fit, is what could push
the true cost meaningfully higher.

---

## 10. Sections 8.1-8.3 — analysis detail (Williams items 7-8)

**8.1 — Coverage table.** One row per cell x nominal level (9 cells x 2
levels = 18 rows), columns: `n_units`, `d`, `n_traits`, nominal level,
converged fraction, PD-Hessian fraction, pooled coverage, cluster-based
MCSE (Section 6), attenuation slope (Section 3), pass/predicted-fail/
surprise-fail classification (Section 5).

**8.2 — Binned conditional-coverage diagnostic (free, from the same
fits).** Pool all `(unit, seed)` pairs within a cell (or across the
`n_units` sweep at fixed `d`/`n_traits`, for more bins), bin by decile of
`|u_true|` (sign-aligned, per axis), report per-bin coverage and its
cluster-adjusted MCSE (bootstrap over seeds within each bin, since a
single seed can contribute to several bins). Plot or tabulate coverage
against `|u_true|` decile — the shape (declining from centre to tail) is
the falsifiable signature named in Section 2.

**8.3 — Ellipse (Mahalanobis) table, `d = 2` cells only.** Same structure
as 8.1, metric is the `m_s <= qchisq()` proportion from Section 1's
secondary estimand.

---

## Williams et al. (2024) self-audit

| # | Item | Status | Where addressed |
|---|---|---|---|
| 1 | Aims | done | Section 0 (why), Section 1 (estimand) |
| 2 | DGP + n_sim justified | done | Section 4 (DGP, reused), Section 6 (MCSE -> n=500) |
| 3 | Estimand / target | done | Section 1 (primary + secondary), Section 2 (marginal vs. conditional decision) |
| 4 | Methods literature cited | done | Section 2 (BLUP/small-area shrinkage theory), Section 4 (reused package DGP + tests) |
| 5 | Performance measures (formulas) | done | Section 1, Section 5, Section 10.3 (Mahalanobis) |
| 6 | Software / packages / versions | partial | design names Totoro + gllvmTMB build provenance pattern (Section 9, citing arcF's PROVENANCE.txt convention) but no build has happened to pin a SHA yet — deferred to execution |
| 7 | Code for DGP available | partial | DGP fully specified (Section 4) and it IS shipped package code (`simulate_site_trait()`), but no campaign script has been written (this is a design, not an implementation) |
| 8 | Code for performance measures | partial | formulas fully specified (Sections 1, 5, 10) but not yet coded |
| 9 | Worked-example case study | not done | out of scope for a design document; would be the campaign's own write-up |
| 10 | Full performance table | not done | table SHAPE specified (Section 10.1) but no results exist |
| 11 | MCSE reported alongside | done (planned) | Section 6 pre-registers the MCSE target and the cluster-correct computation to use once run |

---

## If the coverage question turns out to be ill-posed

It does not, on the reading in Section 2 — marginal coverage is a
well-posed, falsifiable, and practically relevant question for this
estimand, and the binned-conditional diagnostic answers the harder
question at zero extra cost. The one genuine open risk is the compute
estimate in Section 9: if the sparse multi-RHS solve scales badly with
`n_units * d`, the grid as specified may need to shrink its largest cells
before launch, but that is a scope/cost question, not a statistical
ill-posedness one, and the pre-run in Section 9 is exactly the mechanism
for resolving it before any full-grid approval is sought.
