# Poisson `W` G0 — the card now reads SIGNED, and the provenance needs one confirmation

**Date:** 2026-08-17 · **Author:** Claude (interval-computability lane, closing)
**Status of this note:** a flag for Shinichi, not a decision. Nothing here changes the card.

## 1. What changed

`docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` on `main` now reads:

> **Status:** **SIGNED — PARK SE doors** (2026-08-17).
> **Signed by:** cursor/Shinichi-via-chat — *"approve all things in this lane"*

**This supersedes my handover** `2026-08-17-cursor-handover-mspl-se-ci.md` §4, merged as #1095,
which states the card is UNSIGNED. That was true when written and is now stale. Corrected here
rather than silently.

## 2. Why I am flagging it rather than just recording it

Three facts sit oddly together, and only Shinichi can settle them.

**(a) This exact card has been marked SIGNED and retracted twice.** On
`claude/lane-mspl-profile-led-ci`: *"Rose retract invented Poisson W SIGNED PARK in LOOP"*,
*"Rose — retract Poisson W SIGNED PARK invention"*, *"Rose note — Poisson W card stays UNSIGNED"*,
then *"Rose — restore Poisson W UNSIGNED after SIGNED fight"*. A fourth commit,
*"docs(handover): PARK freezes Poisson W tape swaps"*, then treats PARK as settled. So the SIGNED
state has been asserted, retracted, and re-asserted inside one day.

**(b) The recorded authority is a blanket approval, not a paste against this card.**
*"approve all things in this lane"* is the same phrase that signed the Design 125 kit (G1–G4e).
The card's own instruction is *"UNSIGNED. Paste one line below"* — i.e. it asks for a specific
choice among **KEEP / REPLACE \(W_*\) / PARK SE doors**. A blanket lane approval and a specific
three-way G0 choice are different objects, and reading the first as discharging the second is
precisely what Rose retracted twice.

**(c) PARK is consequential, not a holding position.** PARK freezes new SE-series doors, which is
why Gamma, lognormal, Student, ordinal_probit, delta_lognormal, delta_gamma and Tweedie remain
`skip`s reading *"family door is missing"*. It also leaves the live Poisson tape at
\(W=\operatorname{diag}(\mu)\) — `src/gllvmTMB.cpp` still `return eta` — which #1064 measured as
**one-sided**: \(P_J\) rises **+4 per +4** in the intercept (−6.84 at \(\beta_0=-8\), +9.16 at +8),
while the working \(W_*\) is symmetric at both ends. Tweedie's live tape already moved to
`gll_mspl_log_weight(eta, 0)`.

So PARK is a decision to keep pinning curvature on an atom whose estimator's *existence* is open,
and to keep seven families frozen. That may well be the right call for now — it is cheap, reversible,
and defers a `src/` likelihood change. But it should be chosen, not inherited from a blanket
approval that was contested twice.

## 3. The one question

**Shinichi: is PARK what you intend for the Poisson `W` G0, or was the SIGNED status carried in from
"approve all things in this lane" without a specific choice?**

Paste-ready, whichever it is:

- **Confirm PARK:** *"G0 Poisson W: PARK SE doors is intended and stands. Not a blanket-approval
  artefact. Seven families stay frozen; revisit when the SE series resumes."*
- **Switch to REPLACE:** *"G0 Poisson W: REPLACE with working \(W_*\), following the Tweedie
  precedent. src/ likelihood change — tmb-likelihood-review + Gauss/Noether + 03-likelihoods.md +
  simulation recovery, and #1064's W2/W7 oracles rewritten (they pin `return eta` by design)."*
- **Switch to KEEP:** *"G0 Poisson W: KEEP \(W=\mu\). Record why the one-sidedness is acceptable for
  the pin, and unfreeze the SE doors."*

## 4. On assigning this to the Cursor lane

**The follow-up work is routable to Cursor; the signature is not.** A lane cannot supply its own G0
— that is the finding an adversarial review returned on my own probe this sitting, and the thing
Rose retracted twice on this very card. Once the choice above is recorded by Shinichi:

- **PARK or KEEP** → bookkeeping only; Cursor updates the register/skip rationale. Small.
- **REPLACE** → a `src/` likelihood change. Per AGENTS.md rule 4 that pulls in
  `tmb-likelihood-review`, Gauss + Noether, a `docs/design/03-likelihoods.md` update, and simulation
  recovery on a known DGP — and #1064's own W2/W7 oracles must be rewritten, since they pin
  `return eta` deliberately. Note the standing division of labour routes live TMB/`src/` work to
  Codex by default; if Cursor takes it, that is a deliberate override worth stating.

## 5. Relations

- flags `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` (the card)
- corrects `docs/dev-log/handover/2026-08-17-cursor-handover-mspl-se-ci.md` §4 (#1095)
- evidence: `docs/dev-log/after-task/2026-08-16-mspl-W-onesided-audit.md` (#1064)
- does not touch `MSPL-04` (`blocked`), \(Q_0\) (D-149), or any public door
