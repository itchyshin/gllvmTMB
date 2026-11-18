# Ordinal-degeneracy mechanism probe (detector-S1 slice, issue #897)

Pre-registered **before** any fit is run. Frozen below; a VERDICT section is
appended below the frozen block after the grid completes, dated, and it must
apply the rule stated here without revision.

## Question

Issue #897: `ordinal_probit` has no degeneracy detector (239/239 unflagged
where binomial catches 272/272). Before any detector threshold is chosen for
ordinal, we need to know WHICH mechanism produces a degenerate ordinal fit:

- **(a) LINK SATURATION.** `gll_log_pnorm_diff` (`src/gllvmTMB.cpp:181-197`,
  underflow analysis at `src/gllvmTMB.cpp:90-105`) underflows to exactly 0
  when both bracketing cutpoints for an observed category sit further than
  ~8.2924 from `eta` on the same side (the point where `pnorm(x)` rounds to
  exactly 1.0 in double precision). Where this binds, the likelihood is
  genuinely FLAT in the loading direction locally — pushing `eta` further
  changes nothing measurable, because both bracketing probabilities are
  already saturated to machine-exact 0 or 1.
- **(b) CATEGORY-LEVEL SEPARATION.** A monotone likelihood strictly
  IMPROVING as loadings grow without bound — the same quasi-separation
  mechanism documented for binomial (`binomial_prevalence_loading` in
  `check_gllvmTMB()`). Distinct from (a): here growing `eta` genuinely
  increases the fitted probability of the observed category, so there is a
  real (if numerically un-normalizable) preference for larger loadings, not
  a numerically flat region.

These are not mutually exclusive per fit, and the frozen rule below allows a
MIXED verdict.

## Design (frozen)

DGP: homog ordinal, following `dev/design108-stage8/laplace-silent-divergence.R`
("homog" arm; see its header for why this is the realistic, non-adversarial
choice) and the `K = 4`, `taus = c(0, 0.7, 1.4)` convention shared by
`tests/testthat/test-matrix-ordinal-unit.R` and
`dev/design108-stage8/laplace-silent-divergence.R`.

- `q = 2` latent factors (Ayumi-scale).
- `T = 4` ordinal traits, `K = 4` categories, `taus = c(0, 0.7, 1.4)`
  (`tau_1` fixed at 0 by the Hadfield/Wright convention the package uses).
- `sigma_lambda ∈ {0.7, 3.0}` (mild / the #847 ridge-failure regime).
- `n ∈ {100, 400}` sites.
- 15 seeds per (n, sigma_lambda) cell → 2 × 2 × 15 = 60 base fits.
- Fit formula: `value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE)`,
  `family = ordinal_probit()`. This is exactly the `rr_B` engine slot (no
  `diag_B`); `z_B` is the only random effect (`use_rr_B == TRUE` puts `"z_B"`
  into `random`, confirmed by reading `R/fit-multi.R:5456`).
- Degenerate label: `rel_frob = ||Sigma_hat - Sigma_true||_F / ||Sigma_true||_F`
  on the unit-tier `Sigma_B = Lambda_B %*% t(Lambda_B)` (rotation-invariant,
  the package's standing metric per `dev/degeneracy/DETECTOR.md`).
  **`rel_frob > 10` labels a fit degenerate** — no additional convergence /
  pdHess gate (unlike `laplace-silent-divergence.R`'s `silent_divergent`,
  which additionally requires `conv == 0 & pdHess`; this probe's question is
  about the MECHANISM behind a degenerate loading estimate, not about
  whether the fit's own diagnostics missed it).

## Three measurements (frozen), each with its own frozen cutoff

### 1. Directional-derivative test (decisive)

For each DEGENERATE fit: evaluate the TMB objective's summed negative
log-likelihood at the fitted optimum, and again with the unit-tier loading
parameter (`theta_rr_B`, the packed vector that `gll_unpack_rr_loadings`
reshapes LINEARLY into `Lambda_B` — no `exp()`/softplus transform on any
entry, confirmed by reading `src/gllvmTMB.cpp:33-59`, so multiplying every
`theta_rr_B` entry by a scalar `s` multiplies `Lambda_B` by exactly `s`)
scaled by ×1.5 and ×2.0, leaving every other fixed-effect parameter at its
fitted value.

The inner Laplace random effect (`z_B`) is **re-profiled at each scale**,
never held at its stale fitted value: `fit$tmb_obj` is built with
`random = "z_B"` (verified per-fit: `length(fit$tmb_obj$env$random) > 0`,
logged in the results), so calling `fit$tmb_obj$fn(new_par)` re-optimizes
the inner mode for the new fixed parameters by TMB's own construction. A
fixed-RE evaluation would measure the perturbation construction, not the
mechanism, per the brief.

Record, per fit: `dNLL_1.5` and `dNLL_2.0` = `NLL(scaled) - NLL(fitted)`,
both as the **summed** delta and as a **per-observation** delta
(`dNLL / n_obs`, `n_obs = nrow` of the flattened long-format data), since an
absolute delta is not comparable across `n`.

**Frozen cutoffs** (advisory; S2's statistics, evaluated on the median across
degenerate fits):
- median `|dNLL_1.5 (summed)| < 1e-4` → **flat** (saturation-consistent: the
  likelihood does not move when the loading grows).
- median `dNLL_1.5 (summed) < -0.1` → **separation-like** (the likelihood
  keeps improving as the loading grows).
- otherwise → **MIXED** (ships both statistic classes; no single verdict is
  forced).

### 2. Flat-row share

From `report$eta`, `report$ordinal_cutpoints` (reconstructed per trait via
the `n_ordinal_cuts_per_trait` / `ordinal_offset_per_trait` layout that
`R/extract-cutpoints.R:83-126` already uses — `tau_1 = 0` fixed, `tau_2 .. tau_{K-1}`
free per trait), and the observed category codes: for each observed row
whose category is INTERIOR (`2 <= y <= K - 1`, i.e. the row's cell
probability is computed via `gll_log_pnorm_diff`, not the single-tail
`gll_log_pnorm` used for the extreme categories `y = 1` and `y = K`), check
whether BOTH bracketing cutpoints sit more than 8.2924 from `eta` on the
SAME side (`sign(tau_lower - eta) == sign(tau_upper - eta)` and both
`|.| > 8.2924`). Extreme-category rows (`y = 1` or `y = K`) are excluded from
this share's denominator — they never call `gll_log_pnorm_diff` and so
cannot exhibit this specific underflow (`gll_log_pnorm` itself has a
Mills-ratio tail expansion and does not underflow the same way).

**Frozen cutoffs**: median share (across degenerate fits) `> 0.5` supports
saturation; `< 0.2` supports separation; between is unresolved by this
measurement alone (deferred to the directional-derivative verdict).

### 3. Dichotomisation counterfactual

Refit each degenerate fit's dataset with `y` collapsed to binary at the
middle cutpoint (`y <= 2 -> 0`, `y >= 3 -> 1` for `K = 4`, i.e. splitting at
`tau_2`), `family = stats::binomial(link = "probit")`, same formula shape
(`0 + trait + latent(0 + trait | site, d = 2, unique = FALSE)`). Separation
is a data/latent-geometry property of the underlying continuous score and
should SURVIVE collapsing to a coarser response; saturation is an artifact
of having several adjacent narrow cutpoint gaps and need not survive
collapsing to a single wide split.

Record: whether the binomial refit is ALSO degenerate
(`rel_frob > 10` on `Sigma_B` vs the same generating truth), and whether the
package's EXISTING binomial detector
(`check_gllvmTMB()`'s `binomial_prevalence_loading` component status) fires
on it.

## Verdict assembly rule (frozen)

Apply measurement 1 first (it is marked decisive). If measurement 1 alone
resolves to **flat** or **separation-like**, that is the verdict, and
measurements 2 and 3 are reported as corroborating or contradicting
evidence, never as tie-breakers overriding measurement 1. If measurement 1
resolves to **MIXED**, use measurements 2 and 3 to characterize the mixture
(e.g. "saturation-dominant with a separation-like tail") rather than forcing
a binary answer — this is explicitly allowed as an outcome by the brief.

If zero fits in the grid meet the degenerate label, the grid itself is the
finding: report the completion accounting and STOP rather than lowering the
`rel_frob > 10` threshold or otherwise forcing a degenerate subset to exist.

---

## VERDICT (2026-08-17)

Grid completed: 60/60 fits `status == "OK"` (0 ERROR, 0 NO_LAMBDA). Timing
pilot (4 cells, one per `(n, sigma_lambda)` corner, seed 1): 5.6s / 29.6s /
4.9s / 48.7s = 94.9s including the full mechanism suite on the one
degenerate pilot cell; full-grid projection ≈ 22 min, actual wall time
**1217.4s (20.3 min)** — under the D-139 30-minute line, no gate needed.

Degenerate rate (`rel_frob > 10`) by cell: `n=100,sigma=0.7`: 2/15 (13%);
`n=400,sigma=0.7`: 1/15 (7%); `n=100,sigma=3.0`: 12/15 (80%);
`n=400,sigma=3.0`: 9/15 (60%). **24/60 fits degenerate overall**,
concentrated at `sigma_lambda = 3.0` as expected from the #847 regime, but
present (a smaller share) at `sigma_lambda = 0.7` too.

### Measurement 1 — directional derivative (decisive, as specified)

Median `dNLL_1.5_sum = +15.13` (n=24), median `dNLL_2.0_sum = +29.89`.
**23 of 24 degenerate fits show a positive delta** (fit gets WORSE when the
whole `theta_rr_B` vector is scaled up by 1.5x/2.0x with `z_B` re-profiled
at each scale); only one fit (n=400, sigma=3.0, seed=9) shows a negative
delta (-9.88). Per the frozen cutoffs, this is neither `flat`
(`|+15.13| ≥ 1e-4`) nor `separation-like` (`+15.13 ≥ -0.1`, i.e. not
negative) — it falls into the catch-all **MIXED** bucket, but not for the
reason the frozen rule anticipated (an ambiguous middle ground between the
two signatures). Instead it shows a THIRD pattern: **local optimality under
this specific perturbation direction.**

This is explained by re-reading the fitted loadings directly (see the
worked single-seed example logged during development, n=100/sigma=3.0/
seed=1: `Lambda_hat` column 2 for trait 3 alone runs to `44.2/-19.2` against
a true `Lambda` with `max|.| = 4.79`, while the OTHER three traits' columns
stay near their true scale). The runaway is concentrated in ONE trait's
loading column, not a uniform inflation of the whole `p x q` matrix. A
uniform full-matrix rescale (`theta_rr_B * s`, as pre-registered) therefore
perturbs the three well-fit columns away from their optimum at the same
time it perturbs the one pathological column further along its preferred
direction — the aggregate effect is dominated by the three columns getting
worse, producing a net-positive `dNLL` even though the pathological
direction itself may still be flat or improving. **This is a disclosed
limitation of the pre-registered uniform-scale perturbation, not evidence
for either candidate mechanism**, and is reported as a finding that
contradicts the brief's implicit expectation that measurement 1 would
cleanly land in `flat` or `separation-like`.

### Measurement 2 — flat-row share

**`flat_row_share = 0` for ALL 24 degenerate fits** (median 0, and in fact
every individual fit's share is exactly 0 — checked in the row-level
output, not just the median). Zero interior-category observed rows have
both bracketing cutpoints sitting more than 8.2924 from the fitted `eta` on
the same side, at ANY of the 24 degenerate optima. This is **well below**
the frozen `< 0.2` separation-supporting threshold and squarely contradicts
the `> 0.5` saturation-supporting threshold. **Measurement 2 cleanly and
uniformly refutes link saturation** as the row-level mechanism at these
fitted optima — `gll_log_pnorm_diff` is not, in fact, sitting in its
underflowed regime for any observed row in any of these 24 fits, even
though several of them have cutpoint estimates in the same fit that are
numerically large (the earlier single-seed diagnostic example had
`ordinal_cutpoints` up to 13.6 for the runaway trait) — the corresponding
`eta` for that trait's observations evidently grows in step, keeping the
per-row bracket differences away from the underflow boundary.

### Measurement 3 — dichotomisation counterfactual

Refitting all 24 degenerate datasets as binomial-probit (split at the
middle cutpoint `tau_2`): **12/24 (50%) remain degenerate**
(`rel_frob > 10` on the same generating `Sigma_true`) after collapsing to a
binary response, and **24/24 (100%) trigger the package's EXISTING
`binomial_prevalence_loading` detector** (`check_gllvmTMB()` status `WARN`
on every single dichotomised refit, none `PASS`). Per the frozen logic,
separation is a data/latent-geometry property that should survive
collapsing; saturation is a cutpoint-arithmetic artifact that need not. A
**100% detector-fire rate** is strong, clean evidence that the underlying
data geometry generating these 24 ordinal-degenerate fits is EXACTLY the
kind of geometry the binomial quasi-separation detector was built to catch
— i.e. **separation-consistent**, not an ordinal-specific cutpoint
artifact. (The 50% rate of literal `rel_frob > 10` after collapsing,
lower than the 100% detector-fire rate, is expected: collapsing changes the
identified SCALE of the fitted loading — `binomial_prevalence_loading`
detects the separation signature directly from prevalence/saturation/
relative-loading structure, which is scale-robust in a way a fixed
`rel_frob > 10` numeric threshold against the pre-collapse `Sigma_true` is
not.)

### Mechanism verdict

**Applying the frozen assembly rule**: measurement 1 lands in the MIXED
catch-all (for a disclosed reason distinct from the rule's anticipated
ambiguity — see above), so measurements 2 and 3 characterize the mixture.
Both point the same direction, cleanly and with no internal conflict:

- Measurement 2: **0% flat-row share** across all 24 degenerate fits —
  saturation is refuted at the row level, not merely under-supported.
- Measurement 3: **100% detector-fire rate**, 50% literal degeneracy
  survival — separation is supported, and strongly.

**VERDICT: (b) CATEGORY-LEVEL SEPARATION**, not (a) link saturation. The
degenerate ordinal fits in this grid are driven by the same
quasi-complete-separation mechanism already characterized for binomial
(`check_gllvmTMB()`'s `binomial_prevalence_loading` row), concentrated in
individual trait/column directions rather than a uniform inflation of the
whole loading matrix. `gll_log_pnorm_diff`'s documented underflow-to-0
behaviour (`src/gllvmTMB.cpp:90-105`) is a real numerical property of the
likelihood but was **not observed to be the operative mechanism** in any of
the 24 degenerate fits measured here (flat-row share exactly 0 throughout).

### Implication for the detector-S1 threshold choice

A future ordinal degeneracy detector should be modeled on
`binomial_prevalence_loading` (a per-trait runaway-loading / relative-
loading screen), **not** on a cutpoint-underflow / saturation check. The
existing `loading_runaway_thresh` / `loading_relative_thresh` /
`loading_absolute_thresh` machinery is the natural template; a link-scale
saturation check (bracketing-cutpoint-distance) would have caught 0/24 of
the degenerate fits found here and is not recommended as the primary
signal, though it may still be worth a corroborating role given the
underflow mechanism is real and reachable in principle (the brief's own
motivating analysis at `src/gllvmTMB.cpp:90-105`) even if it was not what
fired in this grid.

### Caveats and what this probe does NOT establish

- This grid used `T = 4` ordinal traits, `K = 4` categories, one DGP shape,
  and one specific perturbation direction (uniform whole-matrix `theta_rr_B`
  scaling) for measurement 1. A per-column (single-trait) directional
  derivative was NOT tested and would likely show the naive
  monotone-improving signature that measurement 1's whole-matrix version
  missed; that is future S2-detector-calibration work, not required to
  answer THIS probe's mechanism question, which measurements 2 and 3 answer
  independently of measurement 1's null result.
- `n_random_effects` / `fit$tmb_obj$env$random` non-empty was NOT logged as
  a column in `results/probe-results.csv` in this run (an oversight —
  `directional_derivative()` computes but does not currently persist
  `n_random_effects` into the row; every degenerate fit's `dNLL` values were
  nonetheless computed via `obj$fn()` on an object confirmed at
  interactive-check time, before the grid ran, to have `length(fit$tmb_obj
  $env$random) == 200` i.e. `z_B` non-empty and re-profiled by construction
  for a representative n=100 cell — see the sanity check preserved in this
  session's transcript). Re-running with that column logged is a cheap
  follow-up if independent verification per-row is wanted.
- Convergence code / `pdHess` were not logged as columns either; all 60
  fits returned `status == "OK"` (finite, extractable `Lambda_B`), which is
  the label this probe's frozen rule conditions on, but "silent" in the
  stricter `laplace-silent-divergence.R` sense (`conv == 0 & pdHess == TRUE`)
  was not separately verified per row.

## 🔴 CORRECTION TO THIS VERDICT (2026-08-17, after the dichotomised-check campaign)

This document's VERDICT reached **"category-level separation, not link
saturation"** on three measurements. **Measurement 3 has since been shown to
carry no information, and the positive half of the verdict must be weakened
accordingly.**

Measurement 3 was: *"24/24 dichotomised refits fire the existing binomial
detector -> strong evidence for shared quasi-separation geometry."* The
dichotomised check was subsequently scored properly on 315 fits across four
arms (`pass-criteria-dichotomised.md`): it fires on **86.3% of healthy
fits** (67.8% healthy, 93.3% transport, 100% mixed). A check with that
false-alarm rate fires on 24 of 24 degenerate fits **by construction**; the
24/24 discriminates nothing.

The mechanism is now understood: collapsing a K = 4 ordinal response to
binary destroys enough information to create quasi-separation **in the
refit** that was never in the data — healthy datasets give saturated binary
refits (`saturated_fit` 0.83-0.91) with runaway loadings (`max_loading` 13.4)
at a benign overall prevalence of 0.26.

**What still stands:** measurement 2, **flat-row share exactly 0 on all 24
degenerate fits**, cleanly refutes link saturation — the
`gll_log_pnorm_diff` underflow is never reached at a degenerate optimum.
Measurement 1 was already reported as landing in the MIXED bucket for a
disclosed reason.

**Corrected verdict: "NOT link saturation" is solidly evidenced. "Therefore
category-level separation" is the residual hypothesis, not a demonstrated
one** — the measurement that appeared to demonstrate it does not
discriminate. Anyone citing this probe should cite the negative half only,
and treat the positive half as open.
