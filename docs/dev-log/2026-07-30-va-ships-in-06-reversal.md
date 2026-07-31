# Decision record — VA ships in 0.6, reversing the 2026-07-21 cut

**Date:** 2026-07-30. **Authority:** Shinichi Nakagawa, in session, recorded by Claude Code.
**Status:** maintainer decision taken at a gate. Same legitimacy as GOAL.md Amendments 1–3.

## The decision

**gllvmTMB 0.6 ships a variational-approximation engine.** This reverses Amendment 1 of
2026-07-21, which cut EVA/VA from 0.6 to 0.7 and made 0.6 Laplace-only.

The decision was taken **after** the costing and the negative record below were put in front of
the maintainer, not before. It is a decision to spend, not an oversight.

## What this reverses — stated explicitly so nothing is overridden silently

| record | what it said | status now |
|---|---|---|
| `LOOP/GOAL.md` Amendment 1 (2026-07-21) + `docs/dev-log/2026-07-21-eva-cut-to-0.7.md` | *"gllvmTMB **0.6 ships Laplace-only**. EVA moves to **0.7**."* | **REVERSED** |
| `LOOP/GOAL.md` Amendment 3 (2026-07-22) | Design 86 design-only lane; *"0.6 stays Laplace-only"*; EVA admission reconsidered at the M3 freeze window "on evidence rather than an estimate" | **superseded** — admission is now decided; the evidence requirement is met by Gate 3 below |
| `LOOP/GOAL.md:172` | *"Design 85 remains a closed NO-GO; EVA stays cut to 0.7."* | **the NO-GO is re-opened**, on the terms in "What must still be earned" |
| `docs/design/104-va-family-coverage.md` §4.1 | *"Laplace stays the package default. 0.6 ships Laplace-only. VA/EVA are internal research with no user-facing route."* | **first sentence stands** (Laplace remains the default); second and third reversed |
| `docs/design/108-va-parity-programme.md` §7 | *"Laplace remains the package default and 0.6 ships Laplace-only (Design 104 §4.1)."* | same |

**The costing the maintainer decided against.** Design 108 states: *"The engineering is **26–42
working days** excluding spatial, and the critical path to the named north star is 17–26 of them.
It is not a session. It is not a week."* That estimate is not disputed by this record. The scope
fence below is what makes a 0.6-shippable subset smaller than the full parity programme Design 108
prices.

## What this does NOT change — read before concluding anything

1. **Laplace remains the package default.** `engine="va"` is opt-in. Nothing about the default
   fitting path changes.
2. **Design 85 §10 prohibitions stand in full.** No `logLik`/AIC/BIC/LRT/model-weights from the
   ELBO; no rank selection by ELBO; `L_H` is not a marginal likelihood; the inverse VA Hessian is
   not calibrated frequentist uncertainty.
3. **No intervals.** `calibrated = FALSE` stays. No SE, no `confint`, no coverage claim from the VA
   path in 0.6. This is what makes 0.6 achievable — the ~1,900-replicate-per-cell coverage campaign
   becomes deferrable to whichever release exposes intervals.
4. **Design 105 §10's architectural breakages are not repealed by a decision.** The VA architecture
   breaks for **multinomial** and for **zero-inflated / `*_mix`** families with separate component
   predictors. Those families are out of scope for any VA route until that is redesigned.
5. **TMB template edits remain HIGH-RISK.** Design 72 §7: maintainer discussion + Codex
   implementation, never a Claude auto-merge.
6. **No advertising** until a validation-register row carries VA-vs-LA recovery evidence
   (Design 72 §7; the Design 35 overpromise pattern).

## The scope fence — what 0.6 admits

`engine = "va"` **errors** outside this class:

- `latent(..., unique = FALSE)` only — Ψ suppressed. The default `latent()` carries `diag(psi)`
  and **no VA evidence exists for it**. This fence is the difference between an honest claim and
  advertising a model class we have not measured.
- families: **binomial-logit** and **poisson-log**. (Poisson-log and Gaussian-identity are EXACT
  under the VA objective; binomial-logit uses 1-D Gauss-Hermite. Design 104 §4.2.)
- **`q <= 2`** — see the correction immediately below — `p <= 80`, **`n >= 100`**.

### ⚠ Fence correction, same day: `q <= 4` → `q <= 2`

The maintainer's goal statement named `q <= 4`. **Design 85 §11 Gate 3 is titled "joint-fit
known-DGP recovery at `q = 1/2`"** — it is defined over q=1 and q=2 only. §11 also states that
gates are **sequential** and that *"a later gate cannot compensate for a failed earlier gate"*.
Shipping a fence of `q <= 4` on the strength of a gate defined at `q <= 2` would be admitting a
region the gate never covered.

Worse, the extension to higher `q` is precisely what was already refused: the 2026-07-20 audit's
stated claim boundary is *"whether the internal Gaussian-VA experiment may advance from q=1/q=2
references to q=4/q=6 stress"*, and its decision was **NO-GO**.

**The fence is therefore `q <= 2` in 0.6.** Raising it to 4 requires either a new gate authorising
`q = 4` stress, or the maintainer explicitly shipping beyond the evidence — a decision, not an
inference an agent may make. **Flagged for Shinichi; the conservative direction was taken in the
meantime because it is the reversible one.**

### Gates 0–2 are prerequisites, not optional

§11's sequencing means Gate 3 counts only if **Gate 0** (byte-identity of the cells VA/ML/O3
receive; exact packed-loading reconstruction; `unique = FALSE` asserted), **Gate 1** (algebra and
autodiff to `1e-10`, gradients to `1e-5`, the Gaussian anchor to `1e-8`) and **Gate 2** (the O3
low-dimensional references) hold. Their status must be established before Gate 3 is run, not
assumed from the fact that a prior pilot reached Gate 3.

**Why `n >= 100` is a hard error and not a warning.** Recomputed from
`dev/totoro-grid/results/grid.csv`, the signed scale `attenuation = tr(Sigma_hat)/tr(Sigma_true)`
(bernoulli medians) is **4.302 at n=40** for the GH arm — fourfold inflation. Small `n` is
disqualified, not merely cautioned.

## The estimator: GH quadrature, not JJ

Within VA, the binomial route is **Gauss-Hermite quadrature** (`eval_method = "gh"`), not the
Jaakkola–Jordan / Pólya-Gamma bound. This is **not a new decision** — Design 104 §4.2 already reads
*"Within VA: EXACT where it exists, GH otherwise"* — but the reason is now derived rather than
assumed:

- JJ's objective is **coercive in `‖Λ‖`**: along a loading ray the ELBO slope is
  `<= Sum(n/2)(|mu_0| - xi_0) <= 0`, strictly negative whenever the predictive variance is
  positive. **JJ cannot produce a runaway.** Its 0/320 degeneracy record was therefore guaranteed
  before a fit ran — a theorem, not evidence of quality.
- The detector compounds it: `rel_frob > 10` requires `‖Sigma_hat‖_F > 9‖Sigma_true‖_F`, so a
  norm-*contracting* estimator can never trigger it. JJ's attenuation trajectory across
  n = 40/100/200/400 is **1.670 → 1.015 → 0.857 → 0.780** — it passes through 1 and keeps falling,
  a ~22% variance deficit that is not shrinking. At n=400, 95% of JJ fits contract against 11% of
  GH fits.
- By n=400 the arms are indistinguishable on `rel_frob` (GH 0.443, JJ 0.444), while GH improves
  faster than `sqrt(n)` and JJ slower — a bias floor.

`default_tier = "jj"` for binomial (`R/va-r3-proto.R:534`) is therefore under review. That
reversal is a **shipped-behaviour change** and passes its own adversarial gate before it is made.

## What must still be earned — the gate is already written and frozen

Admission is **not** granted by this decision. It is granted by **Design 85 §11 Gate 3, as
written**: `Sigma_B` relative Frobenius RMSE no more than 0.05 worse in absolute terms than ML,
and no planted axis collapsing in more than 5% of otherwise healthy, non-separated replicates, on
the primary targets **`beta`, `Sigma_B`, and fitted probabilities**.

§11 states that gates are sequential and *"tolerances cannot be widened after seeing the result."*
**We meet that gate. We do not substitute a fresh one.**

**The prior attempt failed on execution, not on the estimator.** The 2026-07-20 audit
(`docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md`) records that the runner *selected rank by
ML before fitting VA* — *"that is the Gate-4 hand-off design, not the required fixed-rank Gate-3
known-DGP comparison"* — and its Fisher/Curie lens concluded *"the pilot cannot be promoted because
the sequential recovery gate was not run as declared and failed fits must remain in the
denominator."* Gate 3 must therefore be run at **fixed rank**, with **every attempted fit in the
denominator**.

Two further requirements, from the 2026-07-30 statistical review:

- **Fix the truth; do not redraw it.** `run-grid.R` draws `Lt <- matrix(rnorm(p*q, 0, 0.6))` per
  seed, so error is estimated *averaged over a prior on Λ*, not at a fixed truth. Gate 3 uses 2–3
  pre-declared `Λ₀` spanning weak and strong signal, with only the data redrawn.
- **Report signed scale beside `rel_frob`**, stratified into diagonal / large off-diagonal /
  near-zero entries — a single scalar over 210 mostly-null `Sigma_B` cells is dominated by the
  nulls, and an unsigned metric hides contraction entirely.

## Consequence for the release

0.6 was already **NOT READY**, with the one-by-one documentation review with the maintainer as its
real blocker. This decision adds an engine to that. The release date moves accordingly; the
`protocols/cran-release-gate` default of NOT READY stands and the rung is reported, not asserted.

> Related: `LOOP/GOAL.md` (Amendment 4) · `docs/dev-log/2026-07-21-eva-cut-to-0.7.md` (superseded) ·
> `docs/design/85-highdim-nongaussian-va-formal-contract.md` §§10–11 ·
> `docs/design/104-va-family-coverage.md` §4 · `docs/design/105-va-family-densities.md` §10 ·
> `docs/design/108-va-parity-programme.md` · `docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md`
