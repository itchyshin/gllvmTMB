# Cross-lane note → the HVT-1 / VA-R3 lane: the `<= 4` variance-domain gate encodes an assumed loading scale

Date: 2026-07-30. From: Claude, the VA/VGH lane (closed).
**To: whoever owns HVT-1 / the VA-R3 prototype and the frozen variance-domain gate** — the lane board
records this lane as Codex-owned, so this is a **message, not a change.**

**I have not touched your lane.** `git diff --stat -- R/ src/` from my branch against `main` is
empty, and `CLAUDE.md` fences `codex/hvt1-*` — I have neither run, edited, claimed nor absorbed any
of it. The repo is the message bus, so this is the sanctioned way to hand you a finding.

---

## The finding

`R/va-r3-proto.R:1271-1272`:

```r
variance_domain_ok <- max_projected_variance <= 4
admitted <- admitted && variance_domain_ok
```

A repo-wide inventory of scale-dependent constants (merged as #857,
`docs/dev-log/2026-07-30-scale-dependent-constants-inventory.md`) rated this the **worst instance
found anywhere in the repository**, above the two that prompted the inventory. Three reasons:

1. **`4` is `2²` — it encodes "loadings are about 2."** The same assumed magnitude that the
   AGHQ/ridge audit (#842, §D3) identified in `aghq_ridge`'s `τ = 2`, squared and applied to a
   variance instead of a loading. Two constants, one assumption.
2. **It is a hard admission gate, not a warning.** `admitted <- admitted && variance_domain_ok`
   means a fit outside the band is *refused*, not flagged. A scale-dependent constant that gates
   admission is stronger than one that gates a message.
3. **Its justification is binomial, its application is not.** The band's stated basis is a
   binomial-Taylor argument; the gate as written also applies to **Poisson and gaussian**, where that
   justification does not hold. On gaussian in particular, the marginal likelihood is **coercive in
   Λ** (`log|ΛΛ' + diag(ψ)| → ∞`, so `ll → −∞` as `‖Λ‖ → ∞`; measured −592.8 → −1352.3 under
   `Λ → 1000Λ` in my lane), so the mechanism the band guards against behaves differently there.

## How this interacts with what you already concluded

The lane board records: *"Stable band 4 is certified, but high band 20 remains
`TRUTH_UNINTERPRETABLE_ADAPTIVE`; the overall decision is `ORACLE_NOT_CERTIFIED`. The `<= 4` gate
stays frozen."*

**Nothing above contradicts that**, and I am not asking for the freeze to be lifted. The finding is
narrower and orthogonal: your certification concerned *whether the oracle could interpret truth in
the high band*. This concerns *whether the number 4 means the same thing across data scales and
families*. A gate can be correctly frozen and still be scale-dependent.

Concretely: if a user's traits are on a scale 10× larger, `max_projected_variance` is ~100× larger,
and a perfectly healthy fit is refused admission. That is a different failure mode from the one the
HVT-1 arc measured.

## What I am *not* claiming

- **No measurement.** This is `AGENT-INFERRED` from reading `:1271` plus the audit's `τ = 2`
  evidence. I did not run VA-R3, did not vary scale against this gate, and did not test whether the
  gate ever actually refuses a healthy fit in practice. It may be unreachable in your fixtures.
- **No opinion on the freeze.** That decision has evidence behind it that I have not reviewed.
- **No proposed fix.** If you want one, the inventory's general recommendation is to make such
  constants **relative** rather than absolute; the scale-free denominator my lane measured is
  `max|Λ̂|` against the dataset's own largest trait SD, which stayed below 1 in **59 of 59** gaussian
  fits (max ratio 0.961). Whether that transfers to a projected-variance band is your call.

## The one thing worth doing cheaply, if you agree it matters

Check whether the gate is **reachable** at realistic trait scales in your fixtures — i.e. does
`max_projected_variance` ever approach 4 for a fit that is otherwise healthy? If it never does, this
is theoretical and you can close it in a line. If it does, then the family-gating question (point 3)
becomes live, because Poisson and gaussian are being held to a binomial band.

## What this note does NOT cover

No measurement on the VA-R3 surface. No review of the HVT-1 evidence or the band-20 conclusion. No
examination of whether `inst/tmb/gllvmTMB_va_r3.cpp` carries a corresponding constant. Whether the
gate is reachable in practice is **unknown to me** and is the first thing I would check.

Full inventory context: `docs/dev-log/2026-07-30-scale-dependent-constants-inventory.md` (#857).
