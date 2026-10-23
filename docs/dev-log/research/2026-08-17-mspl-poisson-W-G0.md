# G0 — Poisson \(W=\operatorname{diag}(\mu)\): KEEP / REPLACE \(W_*\) / PARK SE doors

**Status:** **SIGNED — REPLACE** (2026-08-17).
**When:** 2026-08-17.
**Reader:** Shinichi.
**Author:** cursor/Shinichi-via-chat — *"as you recommended"* (after Cursor REPLACE recommendation). Docs only. No `src/` edit in this signature PR.
**Evidence:** [#1064](https://github.com/itchyshin/gllvmTMB/pull/1064) (`6bc9f385`) —
`docs/dev-log/research/2026-08-16-mspl-W-onesided-audit.md`.
**Provenance:** [#1096](https://github.com/itchyshin/gllvmTMB/pull/1096) §3 REPLACE paste; see
`docs/dev-log/research/2026-08-17-poisson-W-G0-signature-provenance.md` (**RESOLVED — REPLACE**).
**Question (closed):** Live Poisson MSPL still uses GLM-outer \(W=\operatorname{diag}(\mu)\).
Keep it, replace it with working \(W_*\), or park further SE-series doors until
that is chosen?

---

## SIGNED paste (2026-08-17) — REPLACE

> **G0 Poisson W: REPLACE with working \(W_*\), following the Tweedie
> precedent. src/ likelihood change — tmb-likelihood-review + Gauss/Noether + 03-likelihoods.md +
> simulation recovery, and #1064's W2/W7 oracles rewritten (they pin `return eta` by design).**

Authority: Shinichi chat *"as you recommended"* after Cursor’s REPLACE recommendation
(2026-08-17). This is an **explicit three-way choice** against this card.

**Prior PARK from “approve all” / `G1 PARK SE doors` is superseded.** That freeze was a
blanket-lane artefact (#1096 provenance flag). The three-way paste above discharges the G0.

---

## What REPLACE unlocks — and what it does *not*

| Layer | After this G0 |
|---|---|
| **Programme** | Unlocked: Codex may change the Poisson MSPL tape (`return eta` → working \(W_*\)) under the review/recovery contract in the paste. |
| **This PR** | Docs/signature only. **Implementation not started.** No `src/`, no twin rematch, no oracle rewrite here. |
| **SE-series doors** | **Stay closed** until twins rematch and simulation recovery is green. REPLACE does **not** open Gamma / lognormal / Tweedie public / rest-family doors. Park-on-doors holds until code lands and rematch passes. |
| **Public surface** | No public `se=TRUE` / `vcov` / `confint`. `MSPL-04` stays `blocked`. No Design 118. Lane B PROTECTED. No rebuild of #1090. |

---

## Ranga one-sided flag (why REPLACE)

Live Poisson Jeffreys is **one-sided**: \(W=\mu=e^\eta\) vanishes at \(-\infty\)
and **rewards** \(+\infty\). Soft Jeffreys therefore kills the all-zero path and
increases as the mean runs away. Toy cell (#1064 W2): \(P_J\) rises \(+4\) per
\(+4\) in the intercept (\(-6.84\) at \(\beta_0=-8\), \(+9.16\) at \(+8\)).
Working logistic \(W_*=\mu_*(1-\mu_*)\) is two-sided (same \(P_J=-6.84\) at both
ends).

Ranga: \(Q_0\) is the reporting target; \(W_*\) must land **before more
SE-series doors**. Vault `2026-08-16-mspl-all-families-theory` §4.3 / §6 poisson
row: true \(W\) is \(0/+\infty\); default replacement is working logistic \(W_*\)
(2023 \(P^{(f)}\)). Tweedie live tape already uses \(W_*\).

---

## Alternatives not chosen

> **KEEP.** Poisson stays \(W=\operatorname{diag}(\mu)\). Write the one-sided existence gap into the admit notes. No SE door from this atom. Tape not replaced.

> **PARK SE doors.** Freeze new SE-series doors without choosing KEEP/REPLACE. Tape unchanged. *(Previously signed via blanket approve-all; **superseded** by REPLACE above.)*

---

## What each would have done

| Paste | Tape | Admit row | SE-series doors |
|---|---|---|---|
| KEEP | `return eta` stays | stays `admitted`; notes name the gap | no door from this atom |
| **REPLACE (SIGNED)** | working \(W_*\) (**Codex impl PR**, not this signature) | keep or park to `planned` until twins rematch | still no public `se`; doors closed until rematch green |
| PARK SE doors | unchanged | unchanged | freeze until KEEP or REPLACE |

---

## Already true (not the decision)

- #1064 merged: documented + toy-cell measured; tape **not yet** replaced (await Codex).
- Tweedie live tape already uses \(W_*\); public door still closed.
- nbinom2 saturates (\(W\to\varphi\)); same E3 class; #1065 is packet-only,
  still `planned`.
- Public `se=TRUE` / `vcov` / `confint` withheld (D-149 / D-159). B1 PARKED
  (D-157).
- No NEWS `covered`. No un-admit from this card.

---

## Next (Codex — implementation not started)

See `docs/dev-log/handover/2026-08-17-codex-poisson-W-REPLACE.md`.

1. `src/gllvmTMB.cpp`: Poisson MSPL weight `return eta` → working \(W_*\) (Tweedie precedent).
2. Twin rematch `R/mspl-poisson-atoms.R` + A6 pin.
3. Rewrite #1064 W2/W7 oracles (they pin `return eta` by design).
4. `tmb-likelihood-review` + Gauss/Noether + `docs/design/03-likelihoods.md` + simulation recovery.
5. Only after rematch green: revisit SE-series door freezes (still no public `se` without separate G0).

**Cursor does not implement `src/` unless Shinichi explicitly overrides** (he did not — only signed G0).

No public `se`. No Tweedie door. No nbinom admit from this card. No Design 118. Lane B PROTECTED. No rebuild #1090.
