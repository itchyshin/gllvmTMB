# Systematic binomial dig — logit vs probit (JJ / GH / AC vs gllvm)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Script:** `lanes/va-s1-binomials/scripts/probe-binomial-logit-probit-systematic.R`  
**Local results (D-50):**
- logit: `/private/tmp/va-s1-binomial-logit-systematic-20260807/`
- probit: `/private/tmp/va-s1-binomial-probit-systematic-20260807/`  
**Prior scientific logit 2×2 (GH only):** `docs/dev-log/audits/2026-08-07-va-s1-binomial-gllvm-2x2.md`  
**No public fence change. No default-H change.**

---

## A. Glossary (mandatory)

| Term | Meaning |
| --- | --- |
| **β RMSE** | Root-mean-square error of fixed-effect coefficients β̂ vs **planted Design-110 truth**. Not SE width. Not distance to gllvm’s β̂. |
| **Σ rel Frob** | ‖Σ̂ − Σ_true‖_F / ‖Σ_true‖_F for loadings-only Σ = ΛΛ′ (no link-implicit residual). **Unbounded above; >1 allowed.** Σ̂→0 ⇒ rel≈1 (zero estimator / collapse — not “good”). |
| **pass_abs** | Seed passes iff β RMSE ≤ **0.35** and Σ rel Frob ≤ **0.50**. |
| **Our VA ≠ gllvm VA** | gllvmTMB private R3 ELBO tiers vs `gllvm::gllvm(method="VA")`. Same estimand (planted truth), different engines. |
| **GH** | Gauss–Hermite quadrature tier (`eval_method="gh"`, H=7 here). |
| **JJ** | Jaakkola–Jordan / PG bound — **logit only** (`eval_method="jj"`). |
| **AC** | Albert–Chib closed-form tier — **probit only** (`eval_method="ac"`). Empirically ≈ gllvm VA on probit. |
| **Truth** | Planted DGP β and Σ. Never “how close to gllvm.” |

**Misread risk this dig closes:** today’s scientific FAIL was **binomial logit**, not “binary / Bernoulli in general.” Probit is a separate cell.

**Misread risk (Σ challenge 2026-08-07):** gtmb logit Σ rel 3.7–4.9 is **real runaway**, not a scorer bug. gllvm VA’s ~1.0 on logit is **Σ̂≈0 collapse** (`sigma.lv`~1e−6), not a recovery we are “4× worse than.” See `2026-08-07-va-s1-binomial-gllvm-2x2.md` Shinichi-challenge section.

---

## B. Cell card (shared Design-110 shape)

| Field | Value |
| --- | --- |
| family / link | binomial / **logit** (panel 1) or **probit** (panel 2) |
| n, p, q | 120, 8, **2** |
| n_trials | 1 |
| unique | **FALSE** (Σ = ΛΛ′) |
| seeds | `10801:10824` (24) |
| H | 7 (GH only; inert for JJ/AC) |
| engine path | **private** `.va_r3_fit` (Arc-2 / Design-110 path). Public `integration="va"` fence admits both links at q≤2 but was **not** the VA route timed here. |
| arms (logit) | `gtmb_va_gh`, `gtmb_va_jj`, `gtmb_la`, `gllvm_va`, `gllvm_la` |
| arms (probit) | `gtmb_va_gh`, `gtmb_va_ac`, `gtmb_la`, `gllvm_va`, `gllvm_la` |
| scorers | β via FE/`coef` / R3 `beta`; Σ via `Sigma_B` or ΛΛ′ — **not** `extract_Sigma` link-implicit |
| cores | 8 (cap 10) |

---

## C1. Logit panel (SDM flagship) — JJ extension

**Cell card:** binomial / **logit** · n=120 p=8 q=2 · trials=1 · unique=FALSE · seeds 10801:10824 · H=7 · private R3 · arms GH/JJ/LA + gllvm VA/LA · scorers planted β / Σ_B.

| arm | β RMSE | Σ rel Frob | pass_abs | healthy | secs |
| --- | ---: | ---: | ---: | ---: | ---: |
| **gtmb_va_gh** | **0.233** | **4.86** | 0 | 1 | 3.02 |
| **gtmb_va_jj** | **0.201** | **2.10** | 0 | 1 | 0.72 |
| gtmb_la | 0.221 | 2.81 | 0 | 1 | 1.62 |
| **gllvm_va** | **0.137** | **0.997**† | 0 | 1 | 0.06 |
| gllvm_la | 0.148 | 1.44 | 0 | 1 | 0.44 |

† **gllvm VA Σ̂≈0** on logit (collapse / zero-estimator baseline, rel≈1). Not a successful Σ recovery. gtmb 4.86 is **runaway** (hand-checked ‖Σ̂‖_F ≫ ‖Σ‖_F). Both fail abs Σ≤0.50.

Paired mean Δ (ours − gllvm_va): **GH** dβ=+0.096 dΣ=+3.86; **JJ** dβ=+0.065 dΣ=+1.11.  
ΔΣ vs collapsed gllvm VA overstates “how much worse we are at recovery.”

Matches Totoro scientific GH row (β≈0.233 / Σ≈4.86 vs gllvm ≈0.137 / 0.997).

### Logit verdict

1. FAIL was **binomial logit**, not “binary in general.”
2. **JJ narrows the gap** vs GH (β 0.20 vs 0.23; Σ 2.1 vs 4.9) but **does not close** abs recovery.
3. **GH still loses** on logit β; Σ failure mode is **runaway** (ours) vs **collapse** (gllvm VA). Thesis “GH should beat gllvm≈AC” is **not restored by JJ** on this cell — and AC is not a logit tier.
4. **Σ rel 3.7–4.9 is not impossible / not a scorer bug** (verdict A). Rel Frob >1 is allowed.

---

## C2. Probit panel — does GH beat gllvm?

**Cell card:** binomial / **probit** · n=120 p=8 q=2 · trials=1 · unique=FALSE · seeds 10801:10824 · H=7 · private R3 · arms GH/AC/LA + gllvm VA/LA · scorers planted β / Σ_B.

| arm | β RMSE | Σ rel Frob | pass_abs | healthy | secs |
| --- | ---: | ---: | ---: | ---: | ---: |
| **gtmb_va_gh** | **0.138** | **1.74** | 0 | 1 | 6.15 |
| **gtmb_va_ac** | **0.119** | **0.968** | 0 | 1 | 1.37 |
| gtmb_la | 0.135 | 1.42 | 0 | 1 | 1.69 |
| **gllvm_va** | **0.119** | **0.975** | 0 | 1 | 0.06 |
| gllvm_la | 0.238 | 15.3† | 0 | 1 | 0.75 |

† gllvm LA Σ mean inflated by runaway seeds — not used for the GH thesis.

Paired mean Δ (ours − gllvm_va): **GH** dβ=+0.019 dΣ=+0.76; **AC** dβ≈0.000 dΣ=−0.007.  
Beat rate GH vs gllvm_va: β better **2/24**, Σ better **0/24**. AC β matches gllvm within 1e−4 on **23/24**.

### Probit verdict

**Do we beat gllvm on probit with GH?** **No** on this Design-110 cell (q=2, n=120, p=8, trials=1, unique=FALSE).  
**AC ≈ gllvm VA** (parity confirmed). GH is **worse** than both (small β gap, clear Σ gap). The mature-VA thesis “GH > gllvm ≈ AC” is **not supported** here; at best this cell recovers **AC ≈ gllvm**, not a GH win.

---

## C3. Contrast table (GH vs gllvm by link)

| link | gtmb GH β / Σ | gllvm VA β / Σ | dβ / dΣ (GH − gllvm) | thesis “GH beats gllvm” |
| --- | ---: | ---: | ---: | --- |
| **logit** | 0.233 / 4.86 | 0.137 / 0.997 | +0.096 / +3.86 | **FAIL** |
| **probit** | 0.138 / 1.74 | 0.119 / 0.975 | +0.019 / +0.76 | **FAIL** (narrower) |

| link | best our VA tier | vs gllvm |
| --- | --- | --- |
| logit | JJ (0.201 / 2.10) | still worse |
| probit | AC (0.119 / 0.968) | **ties** gllvm |

---

## D. Process / fence

- Local only (≤8 cores). Totoro not needed for this dig.
- Public fence **unchanged**; probit is fence-admitted for `integration="va"` at q≤2, but this dig used **private** `.va_r3_fit` so JJ/AC and GH share one path.
- STOP at G0: next dig choice = more binomial (e.g. larger-n / mature-VA cell where GH thesis was claimed) vs **nbinom2**.

---

## One-line chat returns

- **Glossary:** β RMSE & Σ rf are vs **planted** Design-110 truth; pass_abs 0.35/0.50; our VA ≠ gllvm; AC≈gllvm on probit; JJ=logit bound; GH=quadrature. Rel Frob >1 allowed; ≈1 can mean Σ̂→0.
- **Logit:** FAIL stands; JJ helps but does not reach abs recovery; GH Σ is **runaway** (real); gllvm VA Σ is **collapse** (rel≈1).
- **Probit:** GH does **not** beat gllvm; AC **ties** gllvm.
- **Misunderstand risk:** calling the flagship FAIL “binary” without saying **logit**; reading gllvm VA Σ≈1 as “good.”
- **Σ challenge:** (A) 3.7–4.9 possible = near-total Σ failure; not scorer bug.
