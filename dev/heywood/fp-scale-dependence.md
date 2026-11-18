# `loading_absolute_thresh` is regime-dependent — a structural finding, filed as a NEGATIVE result for #851/#855

Filed alongside issue #1098's retune (`loading_absolute_thresh` 6 -> 8, see
`fp-attribution.R` / `fp-attribution-findings.md` for the full attribution).

**Correction (D-43 panel, ceiling-tier review):** an earlier draft of this
note filed the mechanism under the #851/#855 "latent standardisation pushes
the response scale into Lambda" class. **That framing is wrong for this
arm and this family.** Read past the correction before acting on this
note's "what would actually fix it" section — the class's usual remedy
does not transfer here, and that non-transfer is itself the finding.

## The mechanism — corrected

`extreme_magnitude` (the `binomial_prevalence_loading` arm this issue
retuned) is a fixed constant on the link scale: `max_loading_unit >=
loading_absolute_thresh`. The #851/#855 class describes constants that
break because the *response's own scale* is free and gets absorbed into
Lambda by latent standardisation — that is real for gaussian and
lognormal, where `sd(y)` is an arbitrary, unbounded quantity the model has
no way to pin down in advance.

**Binomial-probit has no such free scale.** The probit link fixes the
residual (liability) variance at exactly 1 by construction — that is what
"probit" means. A binomial loading is therefore identified in **absolute**
units already; there is no response-scale degree of freedom for
standardisation to push into Lambda. Filing this arm under the
units-dependence class was a category error: the units are not the
problem.

What is actually varying across the calibration pools is not a unit
system, it is the **true effect size** — the DGP's own `sigma_lambda`, the
SD of the true per-entry loading. `loading_absolute_thresh = 6` (or 8) is,
in effect, a **hidden prior on plausible latent SD**: it says "no
identified binomial trait's loading should plausibly exceed this many
liability-scale units." That prior is defensible at `sigma_lambda = 0.7`
and false at `sigma_lambda = 3.0` — not because the units moved, but
because the true regime moved past what the constant was implicitly
calibrated to expect. This is **effect-size / regime dependence**, not
units-dependence.

**Why this changes the handoff to #851/#855.** The class's proposed
device for the gaussian/lognormal case is `tau -> tau * sd(y_t)` — rescale
the constant by the response's own empirical scale. Binomial has no
analogue: `y` is 0/1, `sd(y) = sqrt(p_hat(1-p_hat))` is bounded in `(0,
0.5]` and carries no information about the *latent* loading scale, only
about realised prevalence. The other obvious device — judge
`max_loading_unit` against a quantile of the fit's own loading
distribution rather than an absolute constant — **collapses into
`loading_relative_thresh`**, the ratio-based arm (`relative_loading`) this
absolute arm exists specifically to supplement (see `R/diagnose.R`'s own
comment: a ratio is blind to a uniformly-inflated loading matrix, which is
exactly the regime a relative statistic cannot see). **Neither of the
class's usual devices transfers to this arm.** This note should be read as
recording that the binomial instance of the scale-dependent-constants
symptom **may not be fixable by the class's device**, not as one more case
the device will resolve — a negative scoping result, not a to-do item.

## The exceedance arithmetic — an oracle prediction that matches measurement

Pool 2 draws `Lambda_true ~ N(0, sigma_lambda^2)` entrywise, independently,
over a `p x q` matrix (`q = 2` fixed; `p in {12, 27}`), so `p*q` iid draws
per fit (24 or 54). `max_loading_unit` reads `max_ij |Lambda_ij|` (row-max
of `abs()`, then maxed again across traits by the check row's `any()`
logic — equivalent to the matrix-wide max). For an **oracle** using the
TRUE loadings (not the fitted ones), the exceedance probability at
threshold `c` is exact order-statistics arithmetic for `N` iid symmetric
draws:

```
P(max|Lambda_true| < c) = [P(|Z| < c/sigma)]^N = [2*Phi(c/sigma) - 1]^N
P(max|Lambda_true| >= c) = 1 - [2*Phi(c/sigma) - 1]^N          (N = p*q)
```

Computed directly (not copied — `pnorm()` values below, `q = 2` throughout):

| `sigma_lambda` | `p` | `N = p*q` | `P(max >= 6)` | `P(max >= 8)` |
|---|---|---|---|---|
| 3.0 | 12 | 24 | **0.6729** | **0.1685** |
| 3.0 | 27 | 54 | **0.9191** | **0.3398** |
| 0.7 | 12 | 24 | ~0 (`z = 8.57`) | ~0 |
| 0.7 | 27 | 54 | ~0 | ~0 |

This reproduces the claimed range exactly: **0.67 (p=12) to 0.92 (p=27)**
at threshold 6, falling to **0.17-0.34** at threshold 8. At
`sigma_lambda = 0.7` the oracle predicts essentially zero exceedance at
either threshold — for the true loadings, matching the near-zero FPR
pool 1 and pool 2's own `sigma_lambda = 0.7` cells both show.

**This is not merely a plausible story — it is a mechanism with a
quantitative, falsifiable prediction, and the prediction is checked
against the measured (fitted, not oracle) FPR:**

| `sigma_lambda = 3.0`, healthy subset | `p` | oracle `P(max_true >= 6)` | measured FPR at 6 | oracle `P(max_true >= 8)` | measured FPR at 8 |
|---|---|---|---|---|---|
| | 12 | 0.6729 | 0.4013 | 0.1685 | 0.2420 |
| | 27 | 0.9191 | 0.5415 | 0.3398 | 0.3321 |

The oracle over-predicts at threshold 6 and lands very close at threshold
8 (0.3398 vs 0.3321 for `p=27`; 0.1685 vs 0.2420 for `p=12`). The
over-prediction at 6 is expected, not a failure of the mechanism: the
"healthy" (`rel_frob<=10`) conditioning removes some fits whose recovery
went badly, and a fitted loading is not the true loading (estimation noise
and any shrinkage move it, in either direction, away from the oracle
value). The functional relationship the mechanism predicts —
**exceedance probability rises steeply in `sigma_lambda` and in `p`, and
roughly halves when the threshold moves from 6 to 8** — is exactly the
qualitative and, at threshold 8, near-quantitative pattern measured. This
turns the scale-dependence claim from a correlation into a mechanism with
a number attached.

## Ruling out the alternative: is "healthy" itself the scale-dependent thing?

The obvious competing explanation: `rel_frob <= 10` is a *relative* error
bound, but `||Sigma_true||_F` itself grows roughly `sigma_lambda^2`-fold
(~9x from `sigma_lambda = 0.7` to `3.0`), so the *same* relative bound
admits absolutely larger reconstruction error at `sigma_lambda = 3` — i.e.
the population being labelled "healthy" could itself be less accurately
recovered at large scale, and the false-positive framing would be an
artefact of a scale-dependent LABEL, not a scale-dependent detector.

This is checked directly in `fp-attribution-findings.md`: re-running the
same attribution under `rel_frob <= 0.5` — an absolute-relative-error
band ten times tighter, chosen specifically to defuse this alternative —
still gives FPR 0.2156 (n=422 healthy, WARN=91), materially unchanged
from the native-cutoff figure of 0.2500. The false-positive rate is not an
artefact of where the health boundary is drawn; tightening it an order of
magnitude leaves the conclusion in place.

## The measurement (summary table)

Two calibration pools, both fitting a single unstructured latent term
(`latent(0 + trait | site, d = q, unique = FALSE)`, no phylo/spatial/SPDE
tier — confirmed by reading each generator, so `max_loading` and
`max_loading_unit` coincide in both):

| pool | true loading SD (`sigma_lambda`) | healthy n | WARN | FPR |
|---|---|---|---|---|
| `dev/heywood/fp-sweep-full.csv` (homog/sparse, SD 0.7-1.0) | 0.7-1.0 | 2,499 (rel_frob<=10) | 1 | 0.04% |
| `design108-stage8-grid.csv`, `sigma_lambda=0.7` | 0.7 | 494 | 19 | 3.85% |
| `design108-stage8-grid.csv`, `sigma_lambda=3.0` | 3.0 | 434 | 213 | 49.08% |

`aghq_ridge = 2` (a weakly-informative prior on the loadings) reduces the
effect (46.0% -> 13.5% FPR at `sigma_lambda = 3.0`, arm-conditional
breakdown in `fp-attribution-findings.md`) but does not remove it, because
it penalises the estimator, it does not change what threshold the
detector reads the (penalised) estimate against.

## Why the original calibration missed this

The 3,944-fit pool that originally justified `loading_absolute_thresh = 6`
(`dev/heywood/fp-sweep.R`, NEWS.md's 0.6.0 entry) fixed its loading SD at
0.7 (`homog`) or a two-group mix topping out at 1.0 (`sparse50`/`sparse75`).
It never crossed a loading scale anywhere near 3.0 — the regime `#847`
later measured as `aghq_ridge = 2`'s own failure point. **Loading SD is
the one parameter this arm thresholds directly** — leaving it out of the
calibration grid's design was a design gap in that campaign, not
misfortune. A calibration pool can only report a false-positive rate for
the region of parameter space it visits; the 232/928 = 25% figure in #897
was the first evidence to visit the region this one never designed itself
to reach.

## An unmeasured caveat: this evidence is probit-only

`extreme_magnitude` is gated on `family_id == 1L` (binomial) for **every**
link, but both calibration pools here fit **probit** exclusively
(`binomial_probit` / `stats::binomial(link = "probit")`). Logit-scale
loadings run larger than probit-scale loadings for the same underlying
model (the standard logistic/probit variance-matching ratio, `~1.6-1.8`,
commonly cited as `~1.7`) — so the same fixed threshold is, in effect,
reached by a smaller true effect size on the logit link than on probit.
**The FPR measured here should be read as a lower bound for logit fits**,
not a transportable number; no logit evidence exists in either pool. See
the roxygen caveat added in this same PR.

## What #1098 did and did not do

`loading_absolute_thresh` was raised 6 -> 8 as an interim measure: FPR
0.2500 -> 0.1552 on the pool above, sensitivity on its degenerate fits
1.0000 -> 0.9963 (one additional missed fit of 272). This is a point move
along one ROC curve, not a structural fix — no fixed link-scale constant
threshold is correct across every true loading scale a fit may have, so
the next threshold value would fail the same way if the loading scale
grows again. See `docs/design/35-validation-debt-register.md`'s DIA-08
row (2026-08-17, issue #1098 entry) — recorded `partial`, not `covered`.

## What would actually fix it (revised)

Because this is effect-size dependence, not units-dependence, the
#851/#855 rescaling device (`tau -> tau * sd(y_t)`) has **no Bernoulli
analogue**, and the natural alternative (a quantile of the fit's own
loading distribution) collapses into the existing `loading_relative_thresh`
ratio arm. A genuine fix would need a statistic that is neither a fixed
absolute constant nor a within-fit ratio — for instance, information that
is external to the single fit being screened (a prior elicited from
substantive knowledge of plausible effect sizes, or a population-level
empirical Bayes estimate of the loading-SD distribution across many
fits of the same kind of data). That is a materially harder proposition
than the class's usual per-fit rescaling, and is **not** attempted here.
This note is filed as a negative scoping result for #851/#855: the class's
device does not transfer to this arm, and any future attempt should start
from that constraint rather than rediscover it.
