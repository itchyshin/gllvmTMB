# Draft: drmTMB coordination issue — align `|` / `||` random-slope convention

**For the maintainer to post at `itchyshin/drmTMB`** (Design 79 §9; cross-team bus
note). gllvmTMB has now shipped the `||` uncorrelated random-slope coupling across
its covariance grid, and the convention should match drmTMB's so users carry one
mental model across the twins.

---

## Title
Align the `|` / `||` random-slope convention with gllvmTMB

## Body

gllvmTMB (0.5.0) now ships the uncorrelated random-slope coupling with the lme4/brms
convention:

- **single `|`** — `mode(1 + x | g)` estimates the intercept–slope **correlation**.
- **double `||`** — `mode(1 + x || g)` drops it, i.e. exactly
  `mode(1 | g) + mode(0 + x | g)` (intercept ⟂ slope).

This holds across every covariance mode (`indep` per-trait diagonal, `dep`
Σ_int⊕Σ_slope, `latent` separate-Λ) and source (phylo/animal/kernel/spatial).

drmTMB already fits correlated random slopes `(1 + x | id)` and uses the brms
grouping-ID `(1 + x | p | id)` (correlating REs across distributional parameters —
an axis orthogonal to gllvmTMB's trait-mode axis), and it uses
`(1 | id) + (0 + x1 | id)` as the uncorrelated two-term form.

**Proposal:** confirm/adopt the same `|` = correlated / `||` = uncorrelated spelling
in drmTMB (as a first-class `||` where the two-term form is currently required), so
the convention is identical across the twins. No semantic change to drmTMB's `| p |`
grouping-ID axis — this is purely the intercept–slope coupling shorthand.

Refs: gllvmTMB `docs/design/79-covariance-mode-taxonomy.md` §3–4, §9.
