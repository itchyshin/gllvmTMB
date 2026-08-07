# GOAL — va-s3-betabinomial (IMMUTABLE — re-read at the top of EVERY arc)

## Mission

Run the locked non-exact GH family **betabinomial** under the same absolute-first
+ dual-report + 2×2 gllvm comparator stack as S0/S1/S2. Process C hybrid:
extend the ladder; do not open a full ultra-arc unless G0 says so.

## Locked series position

Canonical order (Shinichi 2026-08-07): binomial → nbinom2 → **betabinomial** ←
this lane → beta → (later …). Multinomial OUT.

## Headline

On Design-110-ish geometry (p=8, q=2, unique=FALSE, trials=10, φ=3), does
gllvmTMB LA or VA (GH H=7) recover Σ with n, and how do they compare to gllvm
when feasible?

## Defaults (documented)

- **trials = 10** — Design-59 / `test-betabinomial-recovery.R` default; multi-trial
  required for identifiable φ (Bernoulli n=1 collapses to binomial).
- **φ = 3** — moderate overdispersion (Stoklosa-ish; same as recovery tests).
- **n ∈ {120, 400, 1000}**, ≥12 seeds, matched `n_starts=1`, `se=FALSE`.

## Comparator note

gllvm 2.0.13: `family="beta.binomial"` VA unimplemented; LA errors on every
`Ntrials` shape tried. Reserve arms and mark **N/A** with reason — do not drop
from the 2×2 panel silently.

## Non-goals

No fence / `auto` flip. No PASS claim from smoke alone. D-50: Totoro + `/private/tmp`.
