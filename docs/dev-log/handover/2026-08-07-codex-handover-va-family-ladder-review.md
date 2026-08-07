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

## 2. Locked takeaways Codex should stress-test (not accept blindly)

From synthesis (challenge these):

1. **LA everyday default** — VA often ≈ recovery but 3–50× slower.
2. **NB2 exception:** VA-GH wins abs Σ at n≈1000 (~0.92 vs LA ~0.42) at ~3× cost.
3. **Binary:** prefer probit; cloglog OK under LA; logit GH weak for abs Σ.
4. **AGHQ:** wins old σ/ρ grids; not S1 abs winner; not “LA-GH”.
5. **Closed-form traps:** PoisG / AC / gllvm VA Σ collapse ≠ recovery.
6. **gllvm “losses”** often = missing arm or closed-VA collapse — name mechanisms.
7. Fence / `calibrated=FALSE` unchanged by this battery.

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
Rehydrate from docs/dev-log/handover/2026-08-07-codex-handover-va-family-ladder-review.md + AGENTS.md. Read the listed 2026-08-07 VA n-ladder audits and the series synthesis. Deliver an adversarial scientific review of the all-family ladder battery (coverage, estimands, LA vs VA defaults, gaps, risks to Arc-1 NEWS). Docs-only; no fence/merge/Totoro unless asked.
```
