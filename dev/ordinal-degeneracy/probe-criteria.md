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

<!-- VERDICT section appended below, dated, after the grid completes. -->
