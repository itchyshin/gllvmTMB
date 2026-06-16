# Finding: shared-scalar (GLLVM.jl) vs per-trait (gllvmTMB) dispersion

Date: 2026-06-15 (Claude overnight capability run). Status: **finding, not yet
resolved** — defines a concrete engine-alignment task for the maintainer.

## Summary

A **systematic structural divergence** between the twin engines for **every
dispersion family**. It is the reason native-vs-`engine="julia"` *point*-parity
holds for the no-dispersion families but not for the dispersion families, and it
is **not** fixable by a scale transform.

## The divergence (code-confirmed)

- **gllvmTMB native (TMB)** estimates **one dispersion per trait**:
  `src/gllvmTMB.cpp` declares `PARAMETER_VECTOR(log_phi_nbinom2)`,
  `log_phi_nbinom1`, `log_phi_beta`, `log_phi_tweedie`, … each of length
  `n_traits` (lines ~562–594). So `fit$report$phi_*` is a length-`n_traits` vector.
- **GLLVM.jl (`engine="julia"`)** estimates a **single shared scalar** dispersion,
  replicated across traits, in `GLLVM.jl-integration/src/bridge.jl`:
  - NB2 `dispersion = fill(fit.r, p)` (L586)
  - NB1 `dispersion = fill(fit.φ, p)` (L595)
  - Beta `dispersion = fill(fit.φ, p)` (L603)
  - Gamma `dispersion = fill(fit.α, p)` (L611)
- ⇒ **different free-parameter counts**: native `df = julia df + (n_traits − 1)`.
  Two models with different dimension cannot maximise the same marginal likelihood.

The dispersion **scale** corresponds cleanly (identity map; both are the natural
NB2 `size`/`r` in `Var = μ + μ²/r`, both strictly positive) — that is the one
admissible parity claim.

## Empirical confirmation (NB2, representative)

Native-vs-julia NB2: logLik |diff| ~0.24–1.07 (does **not** shrink with n — so it
is structural, not optimiser); means |diff| ~1e-2–1e-1; Σ_B |diff| ~6e-2–2e-1;
native per-trait φ frequently unidentified on small fixtures (drifts to ~1e7+,
`pdHess = FALSE`). Documented + guarded in `tests/testthat/test-julia-bridge.R`
(NB2 test, commit `fa7b997`): a guard asserts `logLik gap > 1e-3` so a future
shared-dispersion alignment breaks the test loudly and prompts promotion.

## Parity-matrix consequence

| Family group | Point-parity (native vs engine="julia") | Bridge row |
|---|---|---|
| Gaussian, Poisson, Binomial (no dispersion) | **HOLDS** (logLik ~1e-9; est/Σ_B ~1e-5) | parity evidence recorded (`6c646cc`, `c06c96c`) |
| NB2, NB1, Beta, Gamma, tweedie, betabinomial (dispersion) | **cannot hold** until dispersion structure aligns | stays `partial` |
| Ordinal (cutpoints) | not yet investigated | — |

## Alignment options (maintainer decision; not done tonight)

1. Add a **shared-dispersion** option to gllvmTMB native (one φ across traits) →
   native then matches GLLVM.jl's current model. Smaller change, but reduces the
   native model.
2. Add **per-trait dispersion** to GLLVM.jl → GLLVM.jl matches native's richer
   model. This is the faithful-twin direction (native is the oracle), but it is
   engine algorithm work in `GLLVM.jl-integration`, out of scope for the R-first
   overnight pass.

No engine code was changed; this only records the finding and guards it in tests.
