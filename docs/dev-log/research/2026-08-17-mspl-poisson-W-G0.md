# G0 — Poisson \(W=\operatorname{diag}(\mu)\): KEEP / REPLACE \(W_*\) / PARK SE doors

**Status:** UNSIGNED. Paste one line below.
**When:** 2026-08-17.
**Reader:** Shinichi.
**Author:** Cursor. Docs only. No `src/` edit. No tape replace from this card.
**Evidence:** [#1064](https://github.com/itchyshin/gllvmTMB/pull/1064) (`6bc9f385`) —
`docs/dev-log/research/2026-08-16-mspl-W-onesided-audit.md`.
**Question:** Live Poisson MSPL still uses GLM-outer \(W=\operatorname{diag}(\mu)\).
Keep it, replace it with working \(W_*\), or park further SE-series doors until
that is chosen?

---

## Ranga one-sided flag

Live Poisson Jeffreys is **one-sided**: \(W=\mu=e^\eta\) vanishes at \(-\infty\)
and **rewards** \(+\infty\). Soft Jeffreys therefore kills the all-zero path and
increases as the mean runs away. Toy cell (#1064 W2): \(P_J\) rises \(+4\) per
\(+4\) in the intercept (\(-6.84\) at \(\beta_0=-8\), \(+9.16\) at \(+8\)).
Working logistic \(W_*=\mu_*(1-\mu_*)\) is two-sided (same \(P_J=-6.84\) at both
ends).

Ranga: \(Q_0\) is the reporting target; \(W_*\) must be settled **before more
SE-series doors**. A \(Q_0\) pin on a one-sided atom reports curvature of an
estimator whose existence is still open. Vault
`2026-08-16-mspl-all-families-theory` §4.3 / §6 poisson row: true \(W\) is
\(0/+\infty\); default replacement is working logistic \(W_*\) (2023 \(P^{(f)}\)).

This card does **not** replace `return eta`. That is the G0.

---

## Paste one

> **KEEP.** Poisson stays \(W=\operatorname{diag}(\mu)\). Write the one-sided existence gap into the admit notes. No SE door from this atom. Tape not replaced.

> **REPLACE.** Swap Poisson \(W=\operatorname{diag}(\mu)\) for working logistic \(W_*\) on the same \(X_*\). Retwin `R/mspl-poisson-atoms.R` and the A6 pin. Keep `admitted` or park back to `planned` until twins rematch. No public `se`. No door tonight.

> **PARK SE doors.** No new SE-series doors (nbinom beyond #998, Tweedie/Beta public, rest-family) until KEEP or REPLACE is chosen. \(Q_0\) stays the reporting target. Tape not replaced tonight.

---

## What each does

| Paste | Tape | Admit row | SE-series doors |
|---|---|---|---|
| KEEP | `return eta` stays | stays `admitted`; notes name the gap | no door from this atom |
| REPLACE | working \(W_*\) (later slice, not this PR) | keep or park to `planned` until twins rematch | still no public `se` |
| PARK SE doors | unchanged | unchanged | freeze new doors until KEEP or REPLACE |

Ranga's order is **PARK SE doors** until KEEP or REPLACE lands. Theory lean
(vault §6) is REPLACE, but that is a `src/` tape edit and a twin rematch — not
this sitting.

---

## Already true (not the decision)

- #1064 merged: documented + toy-cell measured; tape **not** replaced.
- Tweedie live tape already uses \(W_*\); public door still closed.
- nbinom2 saturates (\(W\to\varphi\)); same E3 class; #1065 is packet-only,
  still `planned`.
- Public `se=TRUE` / `vcov` / `confint` withheld (D-149 / D-148). B1 PARKED
  (D-157).
- No NEWS `covered`. No un-admit from this card.

---

## If you sign

Whoever appends SIGNED + the pasted line treats this file as the G0. KEEP or
REPLACE then needs a **separate** implementation PR. PARK SE doors is a freeze,
not a tape edit.

No `src/` from this card. No public `se`. No Tweedie door. No nbinom admit.
