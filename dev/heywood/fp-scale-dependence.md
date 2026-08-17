# `loading_absolute_thresh` is scale-dependent — a structural finding for #851/#855

Filed alongside issue #1098's retune (`loading_absolute_thresh` 6 -> 8, see
`fp-attribution.R` / `fp-attribution-findings.md` for the full attribution).
This note is the root-cause statement for the #851/#855 standardisation
programme; the maintainer files it to the tracker.

## The mechanism

`extreme_magnitude` (the `binomial_prevalence_loading` arm this issue
retuned) is a fixed constant on the link scale: `max_loading_unit >=
loading_absolute_thresh`. It is justified by an identification fact — the
latent scores are standard normal by construction, so a binomial loading
*is* the trait's latent SD in link units, and a large value implies a
fitted probability indistinguishable from 0 or 1.

That justification is correct **only when the true loading scale is
small**. It says nothing about what happens when the DGP's true loadings
are themselves large. A correctly-recovered fit of a large-loading-scale
truth produces a large `max_loading_unit` *because the truth is large*, not
because anything collapsed. The detector cannot tell these two situations
apart: it reads "loading is big" as "loading has run away," which is only
true relative to some reference scale it never asks for.

This is the general pattern already on file for this repo's
scale-dependent-constants class (`docs/dev-log/2026-07-30-scale-dependent-constants-inventory.md`):
*standardising the latent scores pushes the response's own scale into
Lambda*. Any absolute constant applied downstream of that standardisation
inherits the response scale it was never written to see.

## The measurement

Two calibration pools, both fitting a single unstructured latent term
(`latent(0 + trait | site, d = q, unique = FALSE)`, no phylo/spatial/SPDE
tier — confirmed by reading each generator, so `max_loading` and
`max_loading_unit` coincide in both):

| pool | true loading SD (`sigma_lambda`) | healthy n | WARN | FPR |
|---|---|---|---|---|
| `dev/heywood/fp-sweep-full.csv` (homog/sparse, SD 0.7-1.0) | 0.7-1.0 | 2,499 (rel_frob<=10) | 1 | 0.04% |
| `design108-stage8-grid.csv`, `sigma_lambda=0.7` | 0.7 | 494 | 19 | 3.85% |
| `design108-stage8-grid.csv`, `sigma_lambda=3.0` | 3.0 | 434 | 213 | 49.08% |

Same detector, same threshold (6, the pre-#1098 default), three loading
scales, three FPRs spanning two orders of magnitude — 0.04% to 49%. The
false-positive rate is not a property of the detector or the threshold; it
is a property of where the true loading scale sits relative to the fixed
constant.

`aghq_ridge = 2` (a weakly-informative prior on the loadings) reduces the
effect (46.0% -> 13.5% FPR at `sigma_lambda = 3.0`, arm-conditional
breakdown in `fp-attribution-findings.md`) but does not remove it, because
it is a penalty on the estimator, not a rescaling of the detector's
reference frame.

## Why the original calibration missed this

The 3,944-fit pool that originally justified `loading_absolute_thresh = 6`
(`dev/heywood/fp-sweep.R`, NEWS.md's 0.6.0 entry) fixed its loading SD at
0.7 (`homog`) or a two-group mix topping out at 1.0 (`sparse50`/`sparse75`).
It never crossed a loading scale anywhere near 3.0 — the regime `#847`
later measured as `aghq_ridge = 2`'s own failure point. A calibration pool
can only report a false-positive rate for the region of parameter space it
visits; this one could not have found the failure mode being described
here, because it never visited it. The 232/928 = 25% figure in #897 was
the first calibration evidence to cross that region.

## What #1098 did and did not do

`loading_absolute_thresh` was raised 6 -> 8 as an interim measure: FPR
0.2500 -> 0.1552 on the pool above, sensitivity on its degenerate fits
1.0000 -> 0.9963 (one additional missed fit of 272). This is a point move
along one ROC curve, not a structural fix — no fixed link-scale constant
threshold is correct across every loading scale a fit may have, so the
next threshold value would fail the same way if the loading scale grows
again. See `docs/design/35-validation-debt-register.md`'s DIA-08 row
(2026-08-17, issue #1098 entry) — recorded `partial`, not `covered`.

## What would actually fix it

A structural fix needs the detector to reference something that scales
with the fit's own true loading scale, not a constant fixed at design
time — e.g. judging `max_loading_unit` against a per-fit residual/response
scale (mirroring the D3 fix already proposed for `aghq_ridge`'s own `tau`:
`tau -> tau * sd(y_t)`), or against a quantile of the fit's own loading
distribution rather than an absolute link-scale value. That is squarely
the #851/#855 standardisation programme's territory — this note is the
binomial-detector instance of the same root cause already catalogued
there, not a new proposal.
