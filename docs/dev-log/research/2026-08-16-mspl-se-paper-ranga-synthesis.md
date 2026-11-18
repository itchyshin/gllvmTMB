# MSPL SE — paper + Ranga synthesis (2026-08-16)

**Date:** 2026-08-16 (overnight)
**Roles:** Ranga (verdict) · Ada (ingest) · Cursor (land)
**Status:** research receipt. Not a covered claim. Not permission for
public `se=TRUE` / `vcov` / `confint` / NEWS `covered`.

**Sources**

- Sterzinger & Kosmidis (2023) *Stat Comput* 33:53
  (`~/Desktop/s11222-023-10217-3-1.pdf`)
- Sterzinger, Kosmidis & Moustaki (2026) *Psychometrika*
  (`~/Desktop/maximum-softly-penalized-likelihood-in-factor-analysis.pdf`)
- Live pin: `R/mspl-curvature-pin.R` (D-149 availability)
- Board: `docs/dev-log/research/2026-08-16-mspl-se-series-board.md`
- Sibling theory note: vault / Desktop
  `2026-08-16-mspl-all-families-theory.md` (AGENT-INFERRED; not admit)

**Agent paste (one line):** *Pins check that both Hessians exist at θ̃;
papers report unpenalized observed J (Q_0); softness + Laplace error +
separate CI work still gate “SE”; one-sided W blocks honest Jeffreys
doors for Tweedie/Poisson/nbinom until W_\* is settled.*

---

## Verdict

For eventual SEs, the papers point at **unpenalized observed information
at the MSPL point θ̃** — our **Q_0**. **Q_P / Q_0 PD is the right first
availability gate**, not a public-SE recipe. Softness, Laplace
approximation error, and CI calibration remain separate paper steps.
B1’s hold-out **10.6% PASS** (G1–G5 FAIL) fits that separation.

| Object | Role tonight |
|---|---|
| **Q_0** | Paper-aligned **reporting target** if/when an SE is ever formed |
| **Q_P** | Availability / interiority companion only |
| Public `se=TRUE` | **Still withheld** (estimator guard) |
| Wald CI | **Do not ship** (KF2021 undercoverage; B1 FAIL) |

---

## 1. What curvature to report (Ranga table)

| Choice | Paper stance |
|---|---|
| **Penalized vs unpenalized** | Report the **approximate / unpenalized log-likelihood** Hessian at the MSPL point — captions say SEs from the “negative Hessian of the **approximate log-likelihood**” / “inverse of the negative Hessian of the **approximate likelihood**” (2023 Tables 2–3 & sim captions). FA uses **unpenalized** ℓ for AIC/BIC at MSPL (2026 §7). That is **Q_0**, not Q_P. |
| **Observed vs expected** | Theory uses **observed** \(J(\theta)=-\nabla_\theta\nabla_\theta^\top \ell(\theta)\) (2023 §7). Simulations invert that numerical Hessian. Expected Fisher is not what they report. |
| **Asymptotics** | Under soft penalization, \(\sqrt{n}(\tilde\theta-\hat\theta_{\mathrm{ML}})=o_p(1)\) and \(\tilde\theta\) shares ML’s \(I(\theta_0)^{-1}\) limit (2023 Thm B.2; 2026 Thm 5.2 + Slutsky). So Q_P and Q_0 agree **to first order** only when \(c_n\) is soft; they are not interchangeable as finite-sample objects near the boundary. |

**Agent rule:** pin both; if/when an SE is ever formed, **paper-aligned
target = Q_0**. Do not treat \(Q_P^{-1}\) as the default public SE
without a G0.

---

## 2. Is Q_P / Q_0 the right first gate?

**Yes as D-149 availability** (both Hessians finite/PD at θ̃; unrepaired;
not `sdreport`). That matches “interior MSPL point + usable curvature.”

**Not sufficient** as a paper-complete SE gate. Still required before any
“MSPL has SEs” claim:

1. **Softness** — \(\sup \|R_n^{-1/2}\nabla P\|=o_p(1)\) (2023 Thm B.2;
   2026 N4 \(c_n=o_p(\sqrt n)\)). Family-specific \(c_n\) / info rates,
   not a blind logistic constant.
2. **Laplace / approx-likelihood error** — App. B.4: asymptotics need
   extra conditions on \(\bar S-S\) when ℓ is approximate (LA-MSPL).
3. **Equivariance of \(P^{(f)}\)** if contrast SEs matter (2023 §6) —
   bglmer-style penalties fail this; Jeffreys-style does not.
4. **CI calibration is a separate programme** — finiteness ≠ Wald
   coverage (B1 G1–G5 10.6% PASS). Lane B owns binary intervals;
   D-149 pins stay non-public.

---

## 3. Red flags before more Beta / Tweedie / nbinom doors

| Family | Flag (paper-backed or direct consequence) |
|---|---|
| **Beta** | Atom (#1045) ≠ door ≠ admit. True Jeffreys can be two-sided on (0,1), but soft \(c_n\), prepare fence, and live Q_P/Q_0 pin still required. No public door from atom alone. |
| **Tweedie** | True GLM weight \(W=\mu^{2-p}/\varphi\) is **one-sided** as \(\eta\to+\infty\) (same structural class as Poisson \(W=\mu\)). Hang fix (#1047 `PROBE_OK`) ≠ existence of a soft Jeffreys atom ≠ door. Leave draft; **do not open family 6**. |
| **nbinom1/2** | Mean weight **saturates**; true Jeffreys need not send \(P\to-\infty\) as \(\|\beta\|\to\infty\). Need working two-sided \(W_*\) + Huber on log-dispersion; planned door ≠ admitted. |
| **Poisson (already admitted point)** | Live tape still documents GLM-outer `W=diag(mu)` — paper Jeffreys for logistic is two-sided vanishing \(W\); **one-sided \(W\) is the existence red flag** for “soft Jeffreys” on counts. SE pins on that cell do not clear the atom. |
| **All three** | 2023 Thm C.1 nabla bound is **logit-specific**; other families’ \(\nabla P\) bounds are open. Laplace domination still open (B.4). |

Durable audit companion:
`docs/dev-log/research/2026-08-16-mspl-softness-w-onesided-audit.md`.

---

## 4. Executable next-SE checklist

### Code tonight (DONE in this PR when landed)

- [x] Keep **Q_P / Q_0 PD availability** pins; record which tape fails;
      no repair / pseudoinverse.
- [x] Document **Q_0 = paper reporting target** in pin header + return
      metadata (`paper_reporting_target`, `role`).
- [x] Softness / \(c_n\) + **W_\* / one-sided audit** note for Poisson
      (live), Tweedie, nbinom.
- [x] Refresh SE series board + Mission Control `next_safe_action` to
      Ranga’s G0 list.
- [x] **Do not** open Tweedie public door; **do not** public `se`;
      **do not** flip admits; **do not** absorb Lane B.

### Stop for G0 (morning — Shinichi)

1. Which matrix ships if public SE ever opens: **Q_0 vs Q_P vs sandwich**
   (papers practice Q_0; asymptotics say soft equivalence only).
2. **B1 aftermath** (park / B2 / new construction) — Lane B only.
3. Whether to **replace live Poisson `W=diag(mu)`** before more
   SE-series doors.
4. Hard stop: public `vcov` / `confint` / `se=TRUE` / NEWS `covered`
   from pins alone.

### Safe after G0 (not tonight)

- Soft \(c_n\) derivation / pin per family before new doors.
- Working \(W_*\) replacement design for one-sided / saturating weights
  (Poisson, Tweedie, nbinom) — existence device, not true-model Jeffreys.
- Beta prepare door only after fence; lift `skip_if` only when live;
  still no admit.
- Multi-seed availability grid (local) once softness story is named.

---

## Non-claims

Forming a finite SE on a pin cell is not “MSPL has standard errors.”
First-order soft equivalence of \(Q_P\) and \(Q_0\) is not a finite-sample
excuse to ship \(Q_P^{-1}\). B1 FAIL is not an SE-series input for
non-binomial pins. This note does not admit anyone.
