# GOAL — va-s4-beta (IMMUTABLE — re-read at the top of EVERY arc)

## Mission

Run the locked non-exact GH family **beta** (continuous proportions on (0,1))
under the same absolute-first + dual-report + 2×2 gllvm comparator stack as
S0–S3. Process C hybrid: extend the ladder; do not open a full ultra-arc unless
G0 says so.

## Locked series position

Canonical order (Shinichi 2026-08-07): binomial → nbinom2 → betabinomial →
**beta** ← this lane → (later: tweedie / student / truncated / ordinal / delta).
Multinomial OUT.

## Headline

On Design-110-ish geometry (p=8, q=2, unique=FALSE, φ=5), does gllvmTMB LA or
VA (GH H=7) recover Σ with n, and how does gllvm LA compare?

## Defaults (documented)

- **φ = 5** — `test-beta-recovery.R` moderate concentration.
- **n ∈ {120, 400, 1000}**, ≥12 seeds, matched `n_starts=1`, `se=FALSE`.
- y clamped to `(ε, 1-ε)` with ε=1e-4 for strict Beta support.

## Comparator note

gllvm 2.0.13: `family="beta"` **LA works**; **VA unimplemented**. Always attempt
both; mark VA **N/A** with reason when refused.

## Non-goals

No fence / `auto` flip. No PASS claim from smoke alone. D-50: Totoro + `/private/tmp`.
