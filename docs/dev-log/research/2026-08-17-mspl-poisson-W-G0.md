# G0 — Poisson \(W=\operatorname{diag}(\mu)\): KEEP / REPLACE \(W_*\) / PARK SE doors

**Status:** **SIGNED — PARK SE doors** (2026-08-17).
**When:** 2026-08-17.
**Reader:** Shinichi.
**Author:** Cursor. Docs only. No `src/` edit. No tape replace from this card.
**Signed by:** cursor/Shinichi-via-chat — *"approve all things in this lane"* /
interrupt paste `G1 PARK SE doors` (2026-08-17).
**Evidence:** [#1064](https://github.com/itchyshin/gllvmTMB/pull/1064) (`6bc9f385`) —
`docs/dev-log/research/2026-08-16-mspl-W-onesided-audit.md`.
**Question:** Live Poisson MSPL still uses GLM-outer \(W=\operatorname{diag}(\mu)\).
Keep it, replace it with working \(W_*\), or park further SE-series doors until
that is chosen?

---

## SIGNED paste (2026-08-17)

> **PARK SE doors.** No new SE-series doors (nbinom beyond #998, Tweedie/Beta public, rest-family) until KEEP or REPLACE is chosen. \(Q_0\) stays the reporting target. Tape not replaced tonight.

**Effect:** freeze new SE-series doors. Tape (`return eta` / live
\(W=\operatorname{diag}(\mu)\)) **unchanged**. Admit rows unchanged. Does **not**
invent KEEP or REPLACE — those remain future choices requiring a separate
implementation PR if chosen. No public `se`. No Tweedie door. No nbinom admit
from this card.

**Authority note:** Shinichi’s interrupt paste **`G1 PARK SE doors`** (with the
approve-all block) **is** the SIGNED freeze. A prior Rose reading that Gate 1’s
template line “card stays UNSIGNED until KEEP/REPLACE” blocked SIGNED-PARK is
**superseded** by that explicit paste. KEEP/REPLACE stay open for a later paste;
PARK is the signed door-freeze now.

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

This card does **not** replace `return eta`. The signed choice is **PARK**, not
REPLACE.

---

## Alternatives not chosen (still available later)

> **KEEP.** Poisson stays \(W=\operatorname{diag}(\mu)\). Write the one-sided existence gap into the admit notes. No SE door from this atom. Tape not replaced.

> **REPLACE.** Swap Poisson \(W=\operatorname{diag}(\mu)\) for working logistic \(W_*\) on the same \(X_*\). Retwin `R/mspl-poisson-atoms.R` and the A6 pin. Keep `admitted` or park back to `planned` until twins rematch. No public `se`. No door tonight.

---

## What each does

| Paste | Tape | Admit row | SE-series doors |
|---|---|---|---|
| KEEP | `return eta` stays | stays `admitted`; notes name the gap | no door from this atom |
| REPLACE | working \(W_*\) (later slice, not this PR) | keep or park to `planned` until twins rematch | still no public `se` |
| **PARK SE doors (SIGNED)** | unchanged | unchanged | **freeze** new doors until KEEP or REPLACE |

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

## If you later choose KEEP or REPLACE

Append a new SIGNED line naming KEEP or REPLACE. That choice then needs a
**separate** implementation PR. PARK SE doors remains the freeze until then.

No `src/` from this card. No public `se`. No Tweedie door. No nbinom admit.
