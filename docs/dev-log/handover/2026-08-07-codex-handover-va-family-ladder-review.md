# Handover to Codex — review VA family n-ladder battery (all distributions)

**Author:** Cursor · **Target:** Codex (fresh session)  
**Date:** 2026-08-07  
**Mode:** **read-only scientific review** — do **not** merge, flip fence, open PRs, or start Totoro unless Shinichi amends.

Shinichi: *“do you have our new tests of all distributions — I want Codex to have a look at them and what it thinks about it.”*

---

## 0. Rehydrate

```sh
cd /private/tmp/gllvmtmb-va-gh-all-families
git fetch origin
git checkout codex/va-gh-all-families
git pull --ff-only
git status -sb
export NOT_CRAN=true
```

Read in order:

1. `AGENTS.md` (D-50: campaign CSVs stay local — `/private/tmp/va-*`, not GitHub artifacts)
2. **This handover**
3. Working-position lock: `docs/dev-log/audits/2026-08-07-va-series-synthesis.md`
4. Each ladder audit listed below (+ optional raw `ladder-summary.csv` under `/private/tmp/…`)
5. Design fence context: `docs/design/110-va-gh-h7-all-scalar-families.md` (do not rewrite)

Parallel product lane **C** (Arc-1 merge) is **separate** — handover  
`docs/dev-log/handover/2026-08-07-cursor-handover-va-arc1-merge-fence.md`.  
**Do not absorb C into this review.**

---

## 1. What “the new tests” are

Not a single `testthat` suite — a **Totoro / local absolute-recovery n-ladder battery** (Design-110-shaped DGP, abs bars β RMSE ≤ 0.35 ∧ Σ rel Frob ≤ 0.50, matched starts / warm timing where claimed).

| Wave | Families | Audit |
| --- | --- | --- |
| Binary GH | logit / probit / cloglog | `docs/dev-log/audits/2026-08-07-va-binomial-gh-nladder.md` (+ 500×20 cloglog-vs-probit, LA-vs-AGHQ timed) |
| NB2 | `nbinom2` | `…-va-nbinom2-nladder.md` (+ 2×2 smoke) |
| S3 | betabinomial, beta | `…-va-betabinomial-nladder.md`, `…-va-beta-nladder.md` |
| S4 GH-hard | tweedie, student, truncated_poisson, ordinal, delta_gamma | `…-va-s4-gh-hard-nladder.md` |
| B siblings | truncated_nbinom2, delta_lognormal | `…-va-truncnb2-delta-ln-nladder.md` |
| Exact S0 | gaussian / poisson / gamma / lognormal | S0a/S0b scientific ledgers under `docs/dev-log/audits/2026-08-07-va-s0*` |
| Synthesis | all → working position | `…-va-series-synthesis.md` |

**Raw CSVs (D-50, local):** e.g.  
`/private/tmp/va-s2-nbinom2-nladder-20260807/`,  
`/private/tmp/va-s4-*-nladder-20260807/`,  
`/private/tmp/va-s4-truncated-nbinom2-nladder-20260807/`,  
`/private/tmp/va-s4-delta-lognormal-nladder-20260807/`.

Typical geometry: `n ∈ {120,400,1000}`, `p=8`, `q=2`, `unique=FALSE`, 8–12 seeds, arms **gtmb LA** vs **gtmb VA** (± gllvm when available).

---

## 2. Engine / algorithm decisions (stress-test these)

Canonical lock: `docs/dev-log/audits/2026-08-07-va-series-synthesis.md`.  
Related: LA-vs-AGHQ timed binary; fairness/`n_starts`; PoisG Σ-scale; #947 (WAIC later); #948 (Hui NB2 closed VA parked).

### Everyday product story

| Tool | Role |
| --- | --- |
| **Laplace (LA)** | **Near-universal default** — abs β/Σ competitive or best on most families once n is decent; AIC/LRT valid; fast |
| **LA + named ridge** (`aghq_ridge` with AGHQ **off**) | Mode-B **runaway** stopper; ~LA-fast; **MAP not MLE** → select structure on **unpenalised LA**, then ridge-refit winner only (#947 WAIC/CV later) |
| **VA-GH (H=7)** | Sensitivity / research; **exception: NB2 large-n abs Σ** (~3× LA, worth it); elsewhere often ≈ LA recovery at 3–50× cost |
| **Exact / closed VA** | Exact quartet comparator (gaussian/pois/gamma/lognormal); not a speed play at q=5 |
| **AGHQ(+ridge)** | Opt-in for binary **latent σ/ρ** / integral; **not** S1 abs β/Σ winner; **do not call “LA-GH”** — names are Laplace / AGHQ / VA-GH |
| **gllvm closed VA** | Fast; often **Σ collapse** — rf≈1 can be zero-estimator; always 2×2 |

### Binary

- Prefer **probit** (+ LA everyday; VA-GH for sensitivity).
- **Cloglog** OK under LA (comparable to probit); PoisG **not** for Σ (collapse).
- **Logit** weak for abs Σ under GH → **JJ** if VA logit; logit-GH dig parked.

### Family carve-outs (from ladders)

- **NB2:** LA small-n/cost; **VA-GH at large n for abs Σ**.
- **Most other measured families** (betabin, beta, tweedie, student, ztpois, ordinal, delta_*, truncnb2): prefer **LA** when both clear; truncnb2 mild VA mid-n edge.
- **Exact quartet:** prefer LA; AGHQ not needed.
- **Multinomial VA:** later (not Design 110 scalar).

### Do not advertise as Σ recovery

PoisG, AC magnitudes, gllvm closed-VA collapse, unmatched `n_starts` timing as “VA≈LA speed”.

### Fence / product

Arc-1 fence + `calibrated=FALSE` stay; this battery does **not** licence Laplace→VA default flip or soft-PASS of Arc-2.

---

## 2b. Ladder takeaways Codex should also challenge

1. Σ recovers with **larger n** on hard cells (NB2, binary, S3/S4) — n=120 often shared abs fail.
2. “We beat gllvm” often = missing arm / closed-VA collapse / stuck Σ — name mechanisms.
3. Timing only fair with matched starts, warm DLL, same SE policy.

---

## 3. What Codex should deliver

Write a **short adversarial review** (new audit or after-task under `docs/dev-log/audits/` or `after-task/`):

| Ask | Detail |
| --- | --- |
| Coverage map | Which Design-110 / family cells are measured vs missing? |
| Estimand honesty | Abs Σ bar fairness; collapse vs runaway; n_starts/SE timing caveats |
| Family-default table | Agree / amend LA vs VA recommendations per family |
| NB2 large-n VA win | Robust or overfitted to this DGP? |
| Binary story | Probit-first justified? |
| Gaps | multinomial, coverage/intervals, q>2, unique=TRUE, trials axes |
| Risk to C | Any finding that should block Arc-1 code PR / NEWS wording? |

**Out of scope:** implementing Hui closed-form NB2 (#948), WAIC (#947), multinomial VA, fence flips, merging C.

---

## 4. Landing / ownership

- Evidence branch: `codex/va-gh-all-families`  
- Review can stay docs-only on that branch  
- Do not stage `lanes/*/results` or `/private/tmp` into git

---

## 5. How to Resume (paste into Codex)

```text
Rehydrate from docs/dev-log/handover/2026-08-07-codex-handover-va-family-ladder-review.md + AGENTS.md. Read docs/dev-log/audits/2026-08-07-va-series-synthesis.md (engine decisions: LA / LA-ridge / VA-GH / AGHQ) and the listed 2026-08-07 VA n-ladder audits. Deliver an adversarial scientific review of (1) the all-family ladder battery and (2) whether the LA-default + LA-ridge + VA-GH carve-outs hold. Docs-only; no fence/merge/Totoro unless asked.
```
