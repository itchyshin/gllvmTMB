# Design 81 — Tier-3 (`cluster2` / `unit_obs`) augmented random-slope engine

**Status:** design contract (2026-07-13). Slice **B4** of the 0.5→0.6 gap-closure
ultra-plan. Members: **Noether** (symbolic ↔ implementation alignment), **tmb-engineer**
(TMB), **Gauss** (numerical verify). Model tier: Fable/Opus (new derivation + TMB semantics).

## Why

`cluster2` and `unit_obs` are today **diagonal-only** grouping slots:
- `cluster2` — a second independent per-trait intercept variance
  (`diag(0 + trait | cluster2)`), `src/gllvmTMB.cpp:970-980`, reported `sd_c2`.
- `unit_obs` — a within-unit observation factor, steered intercept-only
  (`R/fit-multi.R:706`).

A random **slope** on either tier is rejected fail-loud:
`R/fit-multi.R:1758-1766` ("The cluster2 tier is diagonal-only"). This doc adds the
uncorrelated (`indep` / `||`) augmented random slope at these tiers — the last
random-slope gap in the covariance grid.

## Scope (this slice)

- **In:** uncorrelated per-trait intercept **and** slope at the `cluster2` and
  `unit_obs` grouping slots — `(0 + trait + (0 + trait):x | cluster2)` and the `||`
  form — a **diagonal** covariance over the `C = 2T` augmented columns (intercept ⊥
  slope, traits independent). Groups are iid (no `A^{-1}` / kernel).
- **Out (documented follow-on):** the correlated (`dep` / `|`) form (full `LL^T`
  `Sigma_b` or the 2-col `atanh_cor_b` intercept–slope correlation) at Tier-3. Noted so
  the surface stays honest; not built here.

## Symbolic model (Noether — the math FIRST)

For grouping `g` (a `cluster2`/`unit_obs` level), trait `t`, augmented column set
`j ∈ {intercept_t, slope_t}` (so `C = 2T` columns):

- Random effects: `s_{j,g} ~ N(0, σ_j²)` independent across `j` and `g`.
  `Sigma_b = diag(σ_1², …, σ_C²)` — **diagonal** (the `||` / `indep` structure).
- Linear predictor contribution for observation `o` in group `g(o)`:
  `η_o += Σ_j Z[o, j] · s_{j, g(o)}`, where `Z[o, ·] = [ trait-indicator_t(o) ,
  x_o · trait-indicator_t(o) ]` — the augmented design (intercept block + `x`-scaled
  slope block), exactly the `Z_B_diag` construction of the unit tier.
- Negative log-likelihood term:
  `-log p(s) = 0.5 Σ_g Σ_j [ log(2π) + 2 log σ_j + s_{j,g}² / σ_j² ]`,
  i.e. `Σ_{g,j} -dnorm(s_{j,g}, 0, σ_j, log)`.
- Parameterisation: `σ_j = exp(θ_j)`, `θ` unconstrained (matches every existing
  diagonal block).

This is **byte-identical in form** to the live unit-tier block `use_diag_B_slope`
(`src/gllvmTMB.cpp:872-894`) — only the grouping index and the reported names change.
That is the safety argument: a *renamed copy*, exactly how `use_diag_cluster2`
(`:970-980`) is a renamed copy of `use_diag_species`.

## Alignment table (target ↔ C++ ↔ R)

| Symbol (math) | C++ (new, cloned from `diag_B_slope`) | R-side source |
|---|---|---|
| `C = 2T` augmented cols | `n_lhs_cols_c2_slope` | parser: intercept + `:x` per trait |
| `Z[o,j]` | `DATA_MATRIX(Z_c2_slope)` (n_obs × C) | `R/fit-multi.R` design build |
| `θ_j` | `PARAMETER_VECTOR(theta_diag_cluster2_slope)` (len C) | init + map |
| `s_{j,g}` | `PARAMETER_MATRIX(s_c2_slope)` (C × n_cluster2) | random block |
| `σ_j = exp(θ_j)` | `sd_c2_slope = exp(theta_…)` → `REPORT(sd_c2_slope)` | extractor reads `report$sd_c2_slope` |
| NLL term | clone of `:889-893` keyed on `cluster2_id` | — |
| `η_o +=` | clone of the `diag_B_slope` eta add, keyed on `cluster2_id(o)` (cf. diagonal add `:1840-1841`) | — |

`unit_obs` slope: the identical clone keyed on the `unit_obs` grouping id.

## Implementation spec

**C++ (`src/gllvmTMB.cpp`):** add `DATA_INTEGER(use_diag_cluster2_slope)`,
`DATA_MATRIX(Z_c2_slope)`, `DATA_INTEGER(n_lhs_cols_c2_slope)`,
`PARAMETER_VECTOR(theta_diag_cluster2_slope)`, `PARAMETER_MATRIX(s_c2_slope)`; the NLL
block (clone of `:872-894`); the `η` contribution in the eta loop (clone of the
`diag_B_slope` add, keyed on `cluster2_id(o)`). Mirror for `unit_obs`. `REPORT` the SDs
and the diagonal `Sigma`.

**R (`R/fit-multi.R`) — NO grammar change needed (verified 2026-07-13).** The augmented
slope covstruct is grouping-agnostic: the parser already marks `(1 + x | <any col>)` as
`.latent_augmented` (`R/brms-sugar.R:3275`), and `fit-multi.R` routes it to a tier purely
by grouping column — `diag_B_slope_idx <- which(diag_is_unique_augmented & groupings ==
site)` (`:633`) and `diag_W_slope_idx <- which(… & groupings == ss_name)` (`:709`). So the
Tier-3 slope is a THIRD routing: `diag_c2_slope_idx <- which(diag_is_unique_augmented &
groupings == cluster2_col)`, cloning the seven cluster2-diagonal touch-points —
detection (`:748`), guard-relax (`:1758-1766`), grouping id (`:2596`), `tmb_data`
(`:3266`), `tmb_params` (`:3394`), `tmb_map` (`:3883`), `random` (`:4404`) — with a
`Z_c2_slope` built like `Z_B_diag`, and defaults supplied on EVERY fit (use_*=0, len-1
params) so existing fits stay byte-identical. Extractor: surface `sd_c2_slope` via
`extract_Sigma(..., level = "cluster2")`. (The bare `||` grammar of B3 is a SEPARATE,
smaller change — the `||` allowlist — layered on afterwards.)

**Guard discipline:** the correlated (`dep`/`|`) Tier-3 slope stays rejected fail-loud
with a clear message pointing here — do not silently accept it.

## Verification (Curie + Gauss)

- **Symbolic alignment first** — this doc, before any code (done).
- **Recovery to a known DGP** under `GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`: simulate a
  cluster2 (then unit_obs) DGP with known per-trait intercept and slope SDs (intercept ⊥
  slope), fit `(0 + trait + (0+trait):x | cluster2)`, assert `sd_c2_slope` recovers the
  truth within tolerance and the off-block covariance is ~0 (the `||` pin). New test
  `tests/testthat/test-cluster2-slope-recovery.R`; mirror for `unit_obs`.
- **No-C++-regression:** the existing `diag_B_slope` / diagonal cluster2 fits must stay
  byte-identical (the additions are gated on new `use_*` flags default 0).
- Full-suite closure sums the **`error`** column. #388: no advertising until recovery is green.

## B3 fold — bare unprefixed `||` grammar rides this same engine

Slice **B3** (unprefixed `latent(1+x||g)` / `indep(1+x||g)` / `dep(1+x||g)`) is the SAME
engine problem as this Tier-3 build, so it folds in here (verified 2026-07-13):

- **`indep(1 + x || g)`** (fully diagonal) already has an engine — `use_diag_B_slope`
  (`R/fit-multi.R:637,1644`, Gaussian-only), reached today only via the deprecated
  `unique(1 + x | g)`. B3 for `indep||` is therefore **grammar-only**: route the bare
  `indep(1+x||g)` spelling to that existing diagonal covstruct (mark
  `diag_is_unique_augmented`), bypassing the `.assert_no_augmented_lhs` block
  (`R/brms-sugar.R:2012-2047`) and adding `indep` to the `||` allowlist
  (`R/brms-sugar.R:2443-2447`). Gaussian-only, matching the engine.
- **`dep(1 + x || g)`** (block-diagonal `Σ_int ⊕ Σ_slope`) and **`latent(1 + x || g)`**
  (separate-Λ) have **no ordinary-tier engine** — the ordinary augmented `latent`
  (`use_rr_B_slope`) is the JOINT/correlated Λ. These require the new block-diagonal /
  separate-Λ engine this design builds (the `dep_chol` parity pins with `A = I`), which
  is why B3's meaningful part is engine work, not a grammar tweak.

**Plan:** build the unit-tier `||` engine here (C++ + parser + recovery), then wire the
bare `indep||`/`dep||`/`latent||` grammar onto it in the same slice. Any change to
accepted formula syntax is a grammar change — this is maintainer-approved (Shinichi,
2026-07-13: "yes build").

## Follow-on (1.0)

Correlated Tier-3 slope (`dep`/`|` single-bar, intercept–slope CORRELATED): full `LL^T`
`Sigma_b` (clone the phylo_dep block `:1210-1272` minus `A^{-1}`) or the 2-col
`atanh_cor_b` intercept–slope correlation. (The `||` uncorrelated forms are built above.)
