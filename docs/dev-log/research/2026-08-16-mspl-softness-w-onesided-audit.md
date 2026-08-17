# Softness / \(c_n\) + one-sided \(W\) audit (Poisson / Tweedie / nbinom)

**Date:** 2026-08-16
**Authority:** Ranga SE review + Sterzinger & Kosmidis (2023) +
Sterzinger, Kosmidis & Moustaki (2026) + live registry comments
**Status:** research audit. Not an admit packet. Not a public door.
**Companion:** `2026-08-16-mspl-se-paper-ranga-synthesis.md`

---

## Softness gate (all families)

Paper condition (2023 Thm B.2; 2026 N4):

- consistency: \(\sup \|R_n^{-1}\nabla P\|=o_p(1)\)
- asymptotic normality: \(\sup \|R_n^{-1/2}\nabla P\|=o_p(1)\)
  (equivalently \(c_n=o_p(\sqrt n)\) under the FA soft scale)

GLMM paper soft scale for logistic Jeffreys blocks:
\(c_n=\sqrt{2p/n}\) with \(p\) = free coefficients in that Jeffreys
block. FA soft Hirose/Akaike:
\(\rho=2\sqrt{2/n^3}\) so \(P^*=\sqrt{2/n}\,P\).

**Audit rule:** do not copy the logistic constant onto Poisson / NB /
Tweedie / Gamma without naming the information rate. A family with a
different rate needs its own \(c_n\) so the softness conditions hold.
Tonight: document only — no `src/` retune.

---

## \(W_*\) two-sided vanishing test

True GLM weight:
\(W_{ii}=(\mathrm{d}\mu_i/\mathrm{d}\eta_i)^2 / (\phi V(\mu_i))\).

Existence for \(\|\beta\|\to\infty\) needs \(W\to 0\) at **both**
infinities of \(\eta\). If \(W\to\infty\) or saturates as
\(\eta\to+\infty\), true Jeffreys need not give E3 (can reward
\(+\infty\)).

Default replacement when the true-family \(W\) fails: **working
logistic** \(W_*\) on the same \(X_*\) (2023 \(P^{(f)}\)). Working
\(W_*\) is an existence device, not a claim that the prior is
true-model Jeffreys.

---

## Family rows (tonight)

| Family | Live / planned atom | True \(W\) behaviour | Softness / door posture |
|---|---|---|---|
| **Poisson log** | Live GLM-outer **`W=diag(mu)`** (`R/mspl-registry.R` Phase-4 comment; five-atom note) | **One-sided:** \(W\to0\) as \(\mu\to0\); \(W\to+\infty\) as \(\mu\to+\infty\) | Point may be admitted; **atom is still a red flag** for “soft Jeffreys.” SE pins do not clear it. **G0:** replace with \(W_*\) before more SE-series doors? |
| **Tweedie log** | Hang probe `PROBE_OK` (#1047); true \(W=\mu^{2-p}/\varphi\) | **One-sided** as \(\eta\to+\infty\) (same class as Poisson); \(\varphi\to0\) boundary | **Public door CLOSED.** Do not open family 6. Working \(W_*\) + Huber required before any door. |
| **nbinom1 / nbinom2 log** | Planned door (#1007); pin fence live | Mean weight **saturates**; true Jeffreys need not send \(P\to-\infty\) as \(\|\beta\|\to\infty\) | Planned ≠ admitted. Need working two-sided \(W_*\) + Huber on log-dispersion before admit. |
| **Bernoulli logit** | Paper-backed true Jeffreys \(W=\mu(1-\mu)\) | Two-sided vanishing | Softness still family-specific at large \(n\cdot q\); CI is Lane B / B1 FAIL. |
| **Beta logit** | Atom FCN \(K_{\beta\beta}\) (#1045) | Can be two-sided on (0,1) | Atom ≠ door ≠ admit. Soft \(c_n\) + live pin still required. |

---

## What this audit authorises tonight

- Comments / research notes / pin metadata naming Q_0 vs Q_P.
- Keeping Tweedie public door **closed**.
- Keeping planned nbinom / Beta as **planned**.
- Recording Poisson `W=diag(mu)` as an open G0 question.

## What this audit does **not** authorise

- Opening Tweedie `family_id` 6 on the public prepare allow-list.
- Public `se=TRUE` / `vcov` / `confint` / NEWS `covered`.
- Flipping any registry row `planned` → `admitted`.
- Silently replacing Poisson \(W\) in `src/` without a named soft
  \(c_n\) and an admit-packet update.
- Absorbing Codex Lane B sandwich / profile / bootstrap.

---

## Pointers

- Registry: `R/mspl-registry.R` (Poisson Phase-4 `W=diag(mu)` note)
- Atom catalogue: `docs/dev-log/research/2026-08-15-mspl-glm-outer-five-atoms.md`
- Tweedie hang: `docs/dev-log/research/2026-08-16-mspl-tweedie-hang-wstar.md`
- Pin: `R/mspl-curvature-pin.R`
