# W one-sidedness audit — live Poisson Jeffreys, Tweedie true W, nbinom saturation

**Date:** 2026-08-16
**Tip read:** `origin/main` @ `3faa1a46` (#1058)
**Status:** research + pure-R oracles. **Not a tape replace.** Not an
admit. Not a door. Not public `se=TRUE`. Not NEWS `covered`.

**Reader:** the next MSPL conductor who is about to open another
SE-series door, and Shinichi at the G0 that would replace the Poisson
weight.

**Ranga (this sitting):** \(Q_0\) is the reporting target. \(W_*\)
must be settled before more SE-series doors.

Concurrent sibling (pin metadata + paper synthesis, no toy-cell
oracles): `cursor/mspl-se-ranga-synthesis` —
`docs/dev-log/research/2026-08-16-mspl-softness-w-onesided-audit.md`
and `docs/dev-log/research/2026-08-16-mspl-se-paper-ranga-synthesis.md`.
This note is the **measurement companion**: it pins the \(+\infty\)
weight path that Phase-4 E2 never measured and does not touch
`R/mspl-curvature-pin.R`.

This is **LA-MSPL**. The GLM-outer atom is
\(\tfrac12\log\det(X_*^\top W X_*)\) at the fixed-only predictor
\(\eta=X_{\mathrm{fix}}b_{\mathrm{fix}}+\mathrm{offset}\). It is
**not** \(I_{\mathrm{LA}}(\beta)\).

---

## 1. Verdict

Live Poisson MSPL still uses GLM-outer \(W=\operatorname{diag}(\mu)\)
(`log w = η` in `gll_mspl_log_weight_glm()`, `family_id == 2`). That
weight vanishes as \(\eta\to-\infty\) and **grows** as \(\eta\to+\infty\).
Soft Jeffreys therefore kills the all-zero path and **rewards**
\(\|\beta\|\to+\infty\). That is an existence risk for the admitted
experimental Poisson point (`poisson:log:ordinary:q1,q2` =
`admitted` / `admit_packet`).

This sitting **documents** the risk and measures it on a toy cell.
It does **not** replace the tape. Replacing Poisson \(W=\mu\) with
working logistic \(W_*\) is a Shinichi G0, not an overnight edit.

Tweedie true \(W=\mu^{2-p}/\varphi\) has the same one-sided bug
(already known; hang note
`docs/dev-log/research/2026-08-16-mspl-tweedie-hang-wstar.md`).
The **live** Tweedie tape already uses working \(W_*\). nbinom2
saturates (\(W\to\varphi\) as \(\eta\to+\infty\)), so \(P_J\) stays
finite on the large-mean path and does not supply E3. nbinom1
quasi-weight \(\mu/(1+\varphi)\) is one-sided like Poisson; the live
NB1 tape is the PMF-summed exact \(I_\eta\), not that quasi weight.

---

## 2. Ranga: \(Q_0\) first, \(W_*\) before more SE doors

Ranga's W_* rule (vault `2026-08-16-mspl-all-families-theory` §4.3,
AGENT-INFERRED; cloned from the 2023 Jeffreys atom, not a new
theorem) is the two-sided vanishing test:

> True GLM weight \(W_{ii}=(d\mu_i/d\eta_i)^2/(\varphi V(\mu_i))\).
> Existence for \(\|\beta\|\to\infty\) needs \(W\to 0\) at **both**
> infinities of \(\eta\). If \(W\to\infty\) or saturates as
> \(\eta\to+\infty\), true Jeffreys does not give E3. It can reward
> \(+\infty\). Default replacement: working logistic \(W_*\) on the
> same \(X_*\) (2023 \(P^{(f)}\)).

Ranga's SE pin (same note §5; Design 225 / `R/mspl-curvature-pin.R`)
names three Hessians at the MSPL point. The reporting target is

\[
Q_0=-\nabla^2_\theta\,\ell_{\mathrm{LA}}\big|_{\tilde\theta},
\]

the penalty-off curvature, evaluated and never optimised
(`fit$mspl$unpenalized_tmb_obj`, `estimator_id = 2`). \(Q_P\) is the
penalised companion. Neither is a public `vcov`. Forming a finite
pin is not “MSPL has standard errors.”

**Consequence for this sitting:** do not open another SE-series door
while the admitted Poisson atom still fails the two-sided test.
Tweedie already moved to \(W_*\). Poisson has not. nbinom2
saturation is the same class of E3 failure (finite \(P\), not
\(-\infty\)). A \(Q_0\) pin on a one-sided or saturating atom
reports curvature of an estimator whose existence is still open.

---

## 3. Live tape vs true W (origin/main @ `3faa1a46`)

| Family | `family_id` | Live GLM-outer \(W\) | True GLM \(W\) | Two-sided? | Registry / door |
|---|---:|---|---|---|---|
| Poisson log | 2 | \(W=\mu=e^\eta\) (`return eta`) | same | **no** — \(0/+\infty\) | `admitted` / `admit_packet`; public `mspl` |
| Tweedie log | 6 | working logistic \(W_*=\mu_*(1-\mu_*)\) via `gll_mspl_log_weight(eta, 0)` | \(\mu^{2-p}/\varphi\) | true W **no**; live \(W_*\) **yes** | `planned`; **no** public door (probe env only) |
| nbinom2 log | 5 | \(W=\mu\varphi/(\varphi+\mu)\) | same | saturates (\(0/\varphi\)) | `planned`; public planned door |
| nbinom1 log | 15 | PMF-summed exact \(I_\eta\) at fixed \(\varphi\) | quasi \(\mu/(1+\varphi)\) is one-sided | exact \(I_\eta\) at \(+\infty\) OPEN; quasi **no** | `planned`; public planned door |
| Bernoulli logit | 1 | \(W=\mu(1-\mu)\) | same | **yes** | `admitted` (B2 partial) |

Source: `src/gllvmTMB.cpp` `gll_mspl_log_weight_glm()`;
`R/mspl-registry.R` notes; Poisson helpers
`R/mspl-poisson-atoms.R` (`W = diag(mu)`).

The five-atom note
(`docs/dev-log/research/2026-08-15-mspl-glm-outer-five-atoms.md`)
already said Poisson is “coercive one-sidedly only.” That was
written when Poisson was `planned`. The atom did not change when
G0 2026-08-16 flipped the row to `admitted`. Phase-4 oracles E2
pin only the all-zero / \(\beta\to-\infty\) side.

---

## 4. Toy-cell measurement (optional, this PR)

Design: intercept + one covariate, four stacked rows, slope fixed
at \(-0.4\), the same toy \(X_*\) as the Phase-4 Poisson / NB2 /
Tweedie oracles. Sweep the intercept \(\beta_0\in\{-8,-4,0,4,8\}\).
Pure R. No live `gllvmTMB(..., estimator="mspl")`. No `se=TRUE`.

Poisson \(W=e^\eta\):

| \(\beta_0\) | mean \(W\) | \(P_J=\tfrac12\log\det(X_*^\top W X_*)\) |
|---:|---:|---:|
| −8 | \(3.5\times10^{-4}\) | −6.84 |
| 0 | 1.05 | +1.16 |
| +8 | \(3.1\times10^{3}\) | **+9.16** |

\(P_J\) rises by 4 each time \(\beta_0\) rises by 4
(\(\log\det\) tracks \(\log\mu=\beta_0+\cdots\)). The atom is
linear in the intercept on this design. Soft Jeffreys **increases**
as the mean runs away.

Working logistic \(W_*=\mu_*(1-\mu_*)\), \(\mu_*=\operatorname{expit}(\eta)\):

| \(\beta_0\) | mean \(W_*\) | \(P_J\) |
|---:|---:|---:|
| −8 | \(3.5\times10^{-4}\) | −6.84 |
| 0 | 0.244 | −0.26 |
| +8 | \(3.5\times10^{-4}\) | **−6.84** |

Symmetric. Both infinities send \(P_J\to-\infty\).

Tweedie **true** \(W=\mu^{2-p}/\varphi\) at \(p=1.5\), \(\varphi=1.4\):

| \(\beta_0\) | mean \(W\) | \(P_J\) |
|---:|---:|---:|
| −8 | 0.013 | −3.18 |
| +8 | 39.5 | **+4.82** |

Same one-sided sign as Poisson, slower because the exponent is
\(2-p=0.5\). Live Tweedie no longer uses this weight.

nbinom2 \(W=\mu\varphi/(\varphi+\mu)\) at \(\varphi=2\):

| \(\beta_0\) | mean \(W\) | \(\max W/\varphi\) | \(P_J\) |
|---:|---:|---:|---:|
| −8 | \(3.5\times10^{-4}\) | 0.00025 | −6.84 |
| 0 | 0.67 | 0.43 | +0.74 |
| +8 | 1.999 | 0.99955 | **+1.84** |
| +12 | 2.000 | 0.99999 | +1.84 |

The large-mean path **saturates**. \(P_J\) approaches a finite
limit near \(\tfrac12\log\det(X_*^\top \varphi X_*)\). E3 fails
because \(P\) does not go to \(-\infty\).

nbinom1 **quasi** \(W=\mu/(1+\varphi)\) at \(\varphi=1\) is
one-sided like Poisson (\(P_J=-7.53\) at \(\beta_0=-8\),
\(+8.47\) at \(+8\)). The live NB1 tape is exact \(I_\eta\), not
this quasi weight. Exact \(I_\eta\) at \(\eta\to+\infty\) is not
settled by this toy cell.

Replay: `tests/testthat/test-mspl-W-onesided-oracles.R`.

---

## 5. What this is not

- Not a Poisson tape replace. `return eta` stays until G0.
- Not an un-admit of Poisson. The experimental point row is
  unchanged. The #990 operational PASS / admit-evidence FAIL still
  stands in the registry notes.
- Not a Tweedie public door. Family 6 stays off the prepare
  allow-list. Working \(W_*\) is already on that fenced tape.
- Not an nbinom admit packet. Saturation is a keep-or-drop science
  question for a later packet, not a tonight flip.
- Not public `se=TRUE`, not a \(Q_0\) pin lift, not a Wald CI, not
  NEWS `covered`.
- Not a proof of E1–E3 + domination for any count family under
  Laplace. The toy cell is a weight-path measurement, not a GLLVM
  existence theorem.

---

## 6. G0 menu (do not execute from this PR)

1. **Keep** Poisson \(W=\mu\) and write the existence gap into the
   admit notes (one-sided, experimental, no SE door from this atom).
2. **Replace** Poisson \(W=\mu\) with working logistic \(W_*\) on
   the same \(X_*\), retwin `R/mspl-poisson-atoms.R` and the A6
   admit-packet pin, keep `admitted` / `admit_packet` or park back
   to `planned` until the twins rematch.
3. **Park** further SE-series doors (nbinom live pins beyond #998,
   Tweedie/Beta public door, rest-family doors) until (1) or (2) is
   chosen.

Ranga's order is (3) until (1) or (2) lands: \(Q_0\) remains the
reporting target, and \(W_*\) is unsettled on the one admitted
count family that still uses true one-sided \(W\).

---

## 7. Related

- Vault: `memory/2026-08-16-mspl-all-families-theory` §4.3 \(W_*\),
  §5 \(Q_0\), §6 Poisson / Tweedie / nbinom rows
- `docs/dev-log/research/2026-08-15-mspl-glm-outer-five-atoms.md`
- `docs/dev-log/research/2026-08-16-mspl-tweedie-hang-wstar.md`
- Sibling synthesis (open): [#1061](https://github.com/itchyshin/gllvmTMB/pull/1061)
  `docs/dev-log/research/2026-08-16-mspl-softness-w-onesided-audit.md`
- `docs/dev-log/research/2026-08-16-mspl-se-series-board.md`
- `docs/dev-log/research/2026-08-16-note-to-se-series-lane.md`
- `R/mspl-curvature-pin.R`, `R/mspl-poisson-atoms.R`
- Sterzinger & Kosmidis (2023) \(P^{(f)}\); Kosmidis & Firth (2021)
  finiteness ≠ calibrated Wald
