# Arc C feasibility probe — AC's ψ-collapse is a dose-response, and ordinal sits at the wrong end

**Date:** 2026-08-04 · **Compute:** Totoro, serial, arm order rotated per replicate
**Cell:** N=120, T=10, q=1, `psi_true` = 0.6, `n_trials` ∈ {2, 4, 6, 12, 20} × 3 seeds (15 cells, 75 rows)
**Data:** `dev/va-speed/arcC/c-nt*.rds` · **Harness:** `18-four-way.R`

## The question, and why this is a proxy

`lanes/mature-va-ordinal/LOOP/GOAL.md` left one thing open: **AC collapses ψ at low `n_trials`, and
the binomial remedy was to end on GH — but there is no ordinal GH tier to warm into.** So can
ordinal use Albert–Chib at all?

**The literal question cannot be measured today.** Ordinal VA is family code 5 and it is **not
built** — that is precisely what Arc C would build. Measuring it would require having already done
the arc the probe is meant to size.

So this measures the **mechanism** instead, in the family that does exist. AC's ψ-collapse is
driven by *information per observation*, and `n_trials` is the dial for that in `binomial_probit`.
Sweeping it locates the information level at which AC's ψ becomes usable.

## Result — a clean monotone dose-response

**ψ recovered, against a planted truth of 0.6:**

| `n_trials` | ours-AC | ours-GH | **AC as % of truth** | GH as % of truth |
|---:|---:|---:|---:|---:|
| 2 | 1.0e-07 | 0.447 | **0.0 %** | 74.5 % |
| 4 | 2.2e-05 | 0.531 | **0.0 %** | 88.4 % |
| 6 | 0.072 | 0.599 | **11.9 %** | 99.7 % |
| 12 | 0.464 | 0.600 | **77.4 %** | 99.9 % |
| 20 | 0.536 | 0.602 | **89.3 %** | 100.4 % |

All 75 rows `[ok]`. Three seeds per level; the medians are reported.

**AC's ψ recovery is not a switch, it is a curve.** It is *totally* collapsed below `n_trials = 4`
(recovering 0.00002 % and 0.004 % of the truth — effectively zero), still broken at 6 (12 %), and
only becomes arguably usable somewhere between 12 (77 %) and 20 (89 %). **GH is essentially exact
from `n_trials = 6` upward.**

## The feasibility answer for ordinal — and it is NEGATIVE

An ordinal response is a **single categorical draw** with K levels. Whatever K is, it is one
observation of one unit, not a count of successes out of many trials — so its information about the
latent scale sits at the **very low end** of the axis swept above, near `n_trials` of 1–3, not 12
or 20.

At that end of the curve, **AC recovers 0.0 % of the planted ψ.**

So, taking the three options `GOAL.md` left open:

| option | verdict |
|---|---|
| **(a) ship ordinal AC fenced** | **not viable if ψ is part of the model.** It would not be a biased ψ; it would be a ψ pinned at zero while the fit reports success. That is the "identified but biased, more dangerous than unidentified" failure this lane already named |
| **(b) build an ordinal GH tier too** ("doubles the arc") | **the honest route.** GH recovers ψ correctly across the whole sweep |
| **(c) ship AC only in regimes where ψ is recovered** | **there is no such regime for ordinal.** The favourable regime is high information per observation, which a single categorical draw does not have |

**Arc C is therefore bigger than "build family code 5 on the proven crux."** The crux
(`va_r3_log_pnorm_diff`) is necessary and proven, but an AC-only ordinal family would ship a
variance component pinned at zero. Plan for (b), or scope the family explicitly to ψ-free use.

## ⚠ Where the inference is, and it is one step

The **measurement** is AC's ψ recovery as a function of `n_trials` in binomial-probit — 15 cells,
monotone, unambiguous.

The **inference** is that an ordinal observation sits at the low-information end of that same axis.
That is reasoning from the structure of the likelihood (one categorical draw vs a count out of
`n_trials`), **not** a measurement of ordinal itself — which, again, cannot be made until the family
exists. It is a strong inference and it points one way, but it is an inference, and building an
ordinal GH tier would let it be checked directly.

## An unexplained observation, recorded not claimed

On **accuracy** (`rel_frob`, loadings), the ranking inverts at high `n_trials`: ours-GH is *worse*
than ours-AC at `n_trials` = 12 (0.301 vs 0.283) and 20 (0.318 vs 0.243), while being far better on
ψ. Three seeds; the arms overlap; this is **not** a claim. Noted because it is the opposite of what
"GH is the accurate tier" would predict, and because Arc E saw GH win accuracy at `n_trials` = 6.
If it survives more seeds it is worth understanding.

## Regime

One N, one T, q=1, `psi_true` = 0.6, binomial-probit only, 3 seeds per level. `psi_true` = 0.6 was
chosen deliberately: at `psi_true` = 0 the collapse is invisible because zero is the right answer,
which would flatter AC at every level of the sweep.
