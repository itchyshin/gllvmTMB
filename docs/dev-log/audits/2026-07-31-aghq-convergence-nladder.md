# The AGHQ adaptation loop essentially never reports convergence — and the reason is a fixed tolerance

**2026-07-31 · Claude (Fable 5) · AGHQ estimator-validation lane · found while smoke-testing the campaign**
**270 fits total (120 local on current source, 150 on Totoro). Results LOCAL (D-50).**

---

## The finding

**Under the engine's own convergence criterion, the AGHQ arm converges 0–2.5% of the time
at n = 100 and 0% at n = 400 and n = 1600.**

| n | `aghq` | `aghq_ridge` |
|---|---|---|
| 100 | **0%** (Totoro) / 2.5% (local) | 20% / 15% |
| 400 | **0%** | **0%** |
| 1600 | **0%** | **0%** |

*(Totoro, 25 seeds/cell, gllvmTMB built 2026-07-29; local, 40 seeds, current source. The
n = 100 cell is the cross-check between the two builds and they agree within MCSE, which
is why the older Totoro build is adequate for this probe.)*

This matters because **n = 1600 is exactly the regime where AGHQ is supposed to help** —
it is where the audit put the σ crossover and where the campaign's pre-registered
prediction P2 expects AGHQ to win.

### Two clarifications, because the wrong field makes this invisible

`opt$convergence` is **not** the convergence signal on the AGHQ path. It is nlminb's code
for the **per-pass iteration cap** set by the continuation schedule, and it returns 1
("iteration limit reached") on a perfectly healthy fit. The engine's own verdict is
`aghq$stop_reason`, and the only value meaning converged begins
`"converged (adaptation mode fixed; gradient below tolerance)"`.

**This is not the same thing as the fits being bad.** The runaway/accuracy behaviour is
separate and is reported elsewhere. What is measured here is that the loop stops without
being able to *certify* a stationary point.

---

## Why: the gradient grows with n, the tolerance does not

`aghq_grad_tol` defaults to a **fixed 1e-4**. The gradient actually reported at the stop:

| n | fits reporting a gradient | median max\|grad\| | min | max | × tolerance |
|---|---|---|---|---|---|
| 100 | 12 | 1.39e-04 | 1.06e-04 | 1.87e-04 | **1.4** |
| 400 | 27 | 2.68e-04 | 1.32e-04 | 3.81e-04 | **2.7** |
| 1600 | 37 | 6.72e-04 | 2.79e-04 | 6.84e-02 | **6.7** |

Median \|grad\| goes 1.39e-04 → 2.68e-04 → 6.72e-04 as n goes 100 → 400 → 1600. The step
ratios are **1.93** and **2.51** against an n-ratio of 4.00 each step — i.e. the gradient
grows roughly like **√n**, which is the scale of the score, while the tolerance is a
constant.

The composition shifts accordingly. As n rises, `stalled` gives way to `gradient above
tolerance`:

| n | converged | grad above tolerance | stalled at cap 1 | adaptation failed |
|---|---|---|---|---|
| 100 | 5 | 12 | **33** | 0 |
| 400 | 0 | 27 | 22 | 1 |
| 1600 | 0 | **37** | 11 | 2 |

### The counterfactual

Under a tolerance scaled as `1e-4 × (n/100)`:

| n | converged under fixed 1e-4 | near-misses a scaled tolerance would clear |
|---|---|---|
| 400 | 0/50 | **27 of 27** |
| 1600 | 0/50 | **34 of 37** |

**At n ≥ 400, every "gradient above tolerance" stop is a near-miss against an unscalable
constant** — at a point the engine itself describes as having a *fixed adaptation mode and
a stagnated objective*.

---

## What this does NOT establish

- **The `stalled at cap 1` branch does not report its gradient**, so those fits (33/22/11)
  **cannot be classified from outside the engine**. The counterfactual above is a **lower
  bound** on what a scale-aware tolerance would recover, and the stalled fits remain
  genuinely unknown. **Recommend the engine report `max |grad|` on the stalled branch** —
  without it, a stall cannot be told apart from a legitimate local-optimum stop.
- **That these are true optima is supported, not proven.** "Adaptation mode fixed and
  objective stagnated" is the engine's description, and the gradient is within a small
  multiple of tolerance — but neither is a stationarity certificate.
- **The √n reading is a description of three points**, not a derived rate. It is consistent
  with the score's scale; it is not a proof about this objective.

---

## This is the same defect class the repo is already tracking

`aghq_grad_tol = 1e-4` is **a fixed absolute constant standing in for a scale the data
determines** — precisely the class of:

- **#847** — the ridge's `tau = 2`, fixed when it should scale;
- **#857** — the scale-dependent-constant inventory, *"48, not 2 — reformulate not patch"*;
- `loading_absolute_thresh = 6` in `R/diagnose.R:440`.

It belongs on that inventory, and it may be the most consequential instance found so far,
because unlike the others it does not merely bias an estimate — **it makes the engine
unable to certify convergence in the regime the method is for.**

---

## Consequence for the campaign

The ADEMP campaign (`docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md`) is designed,
pre-registered, and turnkey. **It should not run its full 16,000 fits yet**, for one
concrete reason rather than caution in general:

The design's analysis population (ii), *converged-only fits*, is the population that
actually answers "is AGHQ a better **estimator**" as opposed to "does the AGHQ code produce
better numbers". **That population is empty at every n.** Verified: the summariser's
converged-only section prints nothing at n = 100 with 40 seeds.

Running now would produce a complete table in which every cell carries the
`OPTIMISER-LIMITED` tag — comparing Laplace *at its optimum* against AGHQ *somewhere*.
That is the exact class of number this lane exists to stop producing.

**Recommended sequence:**

1. **Make `aghq_grad_tol` scale-aware, or make convergence reportable under both a fixed
   and a scale-aware criterion.** Cheap, and it is the same fix #847 needs for τ.
2. **Have the stalled branch report its gradient.** One `sprintf`; without it a third of
   the fits are unclassifiable.
3. **Then run the campaign.** The design does not change — only the convergence measure
   becomes usable, which makes population (ii) real.

Steps 1 and 2 are engine changes and therefore the maintainer's call, not this lane's.

---

## Provenance

- Local: `dev/aghq-evidence/24-estimator-campaign.R`, STAGE=smoke NSIM=40 (200 fits, of
  which 120 AGHQ), current source at `c4f02f8f`.
- Totoro: `dev/aghq-evidence/25-convergence-nladder.R`, 150 fits, 60 cores, ~14 min,
  gllvmTMB 0.6.0 built 2026-07-29. Own lane directory `~/gllvmtmb-aghq-20260731`;
  **Codex's `design90`/`design91` directories were not touched.**
- Analysis: `dev/aghq-evidence/25-analyse.R`. Data: `25-convergence-nladder.csv`.
- **Note for whoever runs the campaign on Totoro: its installed build is 2026-07-29 and
  predates both #844 and the `aghq_start_par` hook that campaign arm 4 requires.** It must
  be reinstalled from the campaign branch first. Checking the build date rather than the
  branch is the standing lesson from this lane.
