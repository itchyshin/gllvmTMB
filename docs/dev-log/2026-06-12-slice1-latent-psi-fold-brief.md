# Slice 1 implementation brief — fold Ψ into `latent`, retire residual `unique()`

**Date:** 2026-06-12 · **Author:** Claude (gllvmTMB thread) · **Status:** spec for
the implementer (the parallel Claude thread, run from GLLVM.jl) + Boole / Gauss /
Noether / Curie review. **Not started — needs maintainer go** (formula-grammar
checkpoint). Design: `docs/dev-log/2026-06-12-latent-psi-fold-design.md`. Map:
`docs/dev-log/2026-06-12-unique-deprecation-audit.md`.

## Scope

**Slice 1 only:** the *residual* `unique()` retires; `latent` gains the
between-unit Ψ by default. **Augmented `*_unique(1 + x | g)` is OUT of scope**
(Slice 2 — it folds into `latent(1 + x | g)` later). Do not deprecate the
augmented form in this slice.

## Behaviour spec

1. `latent(0 + trait | g, d = K)` → ΛΛᵀ + Ψ_(between-unit), where Ψ is added
   **iff the family/data already identify it** — reuse the existing guard logic,
   do not invent new identifiability rules:
   - the "When you do *not* need `unique()`" rules (`unique-keyword.R:46–75`);
   - the per-family OLRE/single-obs block (`fit-multi.R:3329`) — single-obs
     Bernoulli, ordinal, delta auto-skip/warn exactly as today.
2. `latent(..., residual = FALSE)` → ΛΛᵀ only (the old bare-`latent` behaviour;
   rotation-invariant / confirmatory).
3. **Paired** `latent(...) + unique(...)` → `unique()` emits
   `lifecycle::deprecate_warn`, becomes a **no-op** (Ψ already default-on) →
   **byte-identical fit** to today.
4. **Standalone** `unique(0 + trait | g)` with no `latent` on that grouping →
   `deprecate_warn` → route to `indep()` (the marginal diagonal; numerically
   equal).
5. `*_unique` (`animal_/phylo_/spatial_/kernel_`) → `deprecate_warn`, fold into
   the matching `*_latent` default where identifiable (existing phylo
   three-piece / four-component rules).
6. **Bare `latent`** (no explicit `residual=`) fires the transition warning —
   *"the default now includes a per-trait residual Ψ; pass `residual = FALSE`
   for the old rotation-invariant fit."* **[maintainer to lock: clean-break
   (leaning) vs warn-one-cycle-then-flip].**
7. Augmented `unique(1 + x | g)` → **unchanged** (regression-guarded; Slice 2).

## Files (R)

| File | Change |
|---|---|
| `R/brms-sugar.R` | `latent` parser branch: inject the default Ψ term + accept `residual =`; `unique`/`*_unique` branches: `deprecate_warn` + route per spec |
| `R/fit-multi.R` | read the new default; **reuse** the existing identifiability guards (no new logic); the over-param guard (565–650) is unchanged |
| `R/unique-keyword.R`, `R/animal-keyword.R`, `R/kernel-keywords.R` | `deprecate_warn` in the keyword fns; keep `@export` (deprecated-but-live this cycle) |
| `man/*_unique.Rd` | regenerate (`devtools::document()`) |

## Tests (Curie — ship with the engine)

- **byte-identity:** `latent + unique` == `latent` (new default), logLik + key
  params to < 1e-8, across Gaussian / Poisson / nbinom2 / Gamma / Beta.
- **opt-out:** `latent(..., residual = FALSE)` == today's bare `latent` (Λ-only).
- **identifiability:** single-obs binary + ordinal → default Ψ **not** added (no
  spurious parameter); matches the existing skip.
- **standalone:** `unique()` alone == `indep()` (logLik equal).
- **deprecation:** `expect_warning` / snapshot on `unique()`, `*_unique`, and bare
  `latent`.
- **regression:** augmented `unique(1 + x | g)` still fits unchanged.

## Docs / cascade (Claude — after the engine lands)

Grid (`AGENTS.md` / `CLAUDE.md` / `01-formula-grammar.md`), register row flips
(`35-validation-debt-register.md`), NEWS + `decisions.md` entry, then the
`latent + unique → latent` page cascade across the ~28 bucket-A pages, one PR
each (the soft-deprecation keeps unmigrated pages warning-but-working).

## Maintainer lock-ins before start

1. Bare-`latent` transition: **clean-break** (leaning) vs warn-one-cycle.
2. Gauss sign-off that reusing the existing identifiability guards for the
   default is sound (esp. the φ-coexistence families).
