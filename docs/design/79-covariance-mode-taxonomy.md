# Design 79 — The covariance-mode taxonomy: two orthogonal axes

**Status:** canonical spec (2026-07-12). Supersedes Design 55 §5's "`scalar` NOT
APPLICABLE to slopes" and reconciles the mode-semantics drift across Design
55/56/60, Design 61, the capability widget, and the keyword roxygen.

**Purpose:** one source of truth for what every covariance keyword means, for a
random *intercept* and for a random *intercept + slope*, across all five
correlation sources. The reader-facing version (for
`vignettes/articles/api-keyword-grid.Rmd`) is drafted in §8; it goes live only
when the implementation lands (§7), so the public page never documents syntax
that does not run.

---

## 1. The core idea: two orthogonal axes

A random-effect covariance in gllvmTMB is chosen along **two independent axes**.

- **Axis 1 — mode** (`scalar` / `indep` / `dep` / `latent`): the **cross-trait**
  covariance structure $\boldsymbol\Sigma_T$ among the $T$ traits.
- **Axis 2 — correlation coupling** (`|` vs `||`): for a random *intercept +
  slope* term, whether the **intercept and slope are correlated**.

They are orthogonal: the mode says how traits relate; the `|`/`||` choice says
how the intercept relates to the slope. Every mode admits both couplings. The
intercept-only grid is simply the special case where Axis 2 does not apply.

The between-group coupling is a third, fixed input (the source): identity for the
no-prefix row, the relationship matrix $\mathbf A$ for `phylo_`/`animal_`, the
SPDE precision for `spatial_`, a supplied dense $\mathbf K$ for `kernel_`. The
ordering-free definition for the intercept-only case is
$\operatorname{Cov}(b_{gt}, b_{g't'}) = \Sigma_{T,tt'}\,K_{gg'}$.

## 2. Axis 1 — modes (cross-trait covariance $\boldsymbol\Sigma_T$)

For an intercept-only term, $\boldsymbol\Sigma_T$ is:

| mode | $\boldsymbol\Sigma_T$ | params |
|---|---|---|
| `scalar` | $\sigma^2\mathbf I_T$ — one shared variance, zero cross-trait cov | 1 |
| `indep` | $\mathrm{diag}(\sigma^2_1,\dots,\sigma^2_T)$ — per-trait variance, zero cross-trait cov | $T$ |
| `dep` | free $\boldsymbol\Sigma_T$ — full unstructured | $T(T{+}1)/2$ |
| `latent` | $\boldsymbol\Lambda\boldsymbol\Lambda^{\mathsf T}(+\boldsymbol\Psi)$ — reduced rank $d$ | $Td - d(d{-}1)/2\ (+T)$ |

`indep`'s diagonal is diagonal **across traits**; observations remain correlated
**within each trait** through the source ($\mathbf A$, GMRF, $\mathbf K$). It is
not independent residual noise.

## 3. Axis 2 — correlation coupling (`|` vs `||`)

For a random intercept + slope term `mode(1 + x | g)`:

- **Single `|` = correlated.** The intercept and slope are modelled jointly and
  their covariance is **estimated**. This is the default, and matches lme4/
  glmmTMB, where a single `|` term estimates the intercept–slope correlation.
- **Double `||` = uncorrelated.** `mode(1 + x || g)` is exactly the two-term split

  $$\texttt{mode(1 \| g)} \;+\; \texttt{mode(0 + x \| g)},$$

  i.e. an intercept random effect and a slope random effect with **no
  intercept–slope covariance**. This is the lme4 `(1 + x || id)` idiom.

The principle: **a single `|` always models the correlation; `||` drops it.**
This holds for every mode and every source.

## 4. The combined taxonomy (intercept + slope, $T$ traits)

Writing the shared intercept–slope block $\mathbf G = \begin{psmallmatrix}\sigma^2_{\text{int}} & \sigma_{\text{int,slope}}\\ \sigma_{\text{int,slope}} & \sigma^2_{\text{slope}}\end{psmallmatrix}$:

| mode | `\|` correlated | params | `\|\|` uncorrelated | params |
|---|---|---|---|---|
| `scalar` | one shared $\mathbf G$ across all traits | **3** | shared $\sigma^2_{\text{int}}$ + shared $\sigma^2_{\text{slope}}$ | 2 |
| `indep` | per-trait $\mathbf G_t$, no cross-trait cov | **3T** | per-trait $\mathrm{diag}(\sigma^2_{\text{int},t},\sigma^2_{\text{slope},t})$ | 2T |
| `dep` | full unstructured $2T\times 2T$ | $T(2T{+}1)$ | full $\boldsymbol\Sigma_{\text{int}}(T{\times}T)\ \oplus\ \boldsymbol\Sigma_{\text{slope}}(T{\times}T)$ | $2\cdot T(T{+}1)/2$ |
| `latent` | reduced-rank over stacked $2T$ (intercept & slope share factors) | — | separate $\boldsymbol\Lambda_{\text{int}},\boldsymbol\Lambda_{\text{slope}}$ | — |

Notes:
- `scalar` `|` is the classic univariate random-regression $\mathbf G$-matrix
  applied identically to every trait — "scalar" now means *shared across traits*,
  not *single variance*. This is the natural extension that resolves Design 55's
  objection (§6).
- `dep` `||` is a genuine, useful model: all trait intercepts correlated and all
  trait slopes correlated, but intercept $\perp$ slope. Block-diagonal in the
  intercept/slope split.
- `latent` `||` (separate $\boldsymbol\Lambda$ per column block, no intercept–
  slope covariance) is the **current shipped** latent+slope behaviour, and is
  correctly the uncorrelated form. `latent` `|` (a shared-factor reduced-rank
  $\mathbf G$ — an axis that raises both a trait's intercept and its slope
  together) is **coherent but deferred**: it is the most exotic build and does not
  gate the release. Ship the current behaviour labelled as `||`.

## 5. Keyword surface

Sources × modes, plus the new `scalar()`/`kernel_scalar()` and the `|`/`||`
coupling:

| source | scalar | indep | dep | latent |
|---|---|---|---|---|
| none | **`scalar()`** ⟵ new | `indep()` | `dep()` | `latent()` |
| phylogenetic | `phylo_scalar()` | `phylo_indep()` | `phylo_dep()` | `phylo_latent()` |
| animal | `animal_scalar()` | `animal_indep()` | `animal_dep()` | `animal_latent()` |
| spatial | `spatial_scalar()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |
| kernel | **`kernel_scalar()`** ⟵ new | `kernel_indep()` | `kernel_dep()` | `kernel_latent()` |

- Intercept-only `scalar()` ≡ `indep(..., common = TRUE)` (byte-identical
  desugar). `kernel_scalar(unit, K = K, name = ...)` takes the same bare-`unit`
  form as `kernel_indep/dep/latent` (no formula LHS needed for the intercept-
  only mode).
- Every cell takes `(1 + x | g)` (correlated) and `(1 + x || g)` (uncorrelated).
- `unique()` / `*_unique()` / `kernel_unique()` remain soft-deprecated aliases.

## 6. Supersedes Design 55 §5 (`scalar` + slope)

Design 55 §5 recorded `scalar(LHS)` as **NOT APPLICABLE** to a slope, reasoning
that "`phylo_scalar` carries a single variance component per group; an
intercept+slope LHS would require a 2×2 covariance, contradicting the 'scalar'
semantics." That objection is resolved: under this taxonomy `scalar` means **one
$\mathbf G$-matrix shared across all traits**, so `scalar(1 + x | g)` is a
perfectly well-defined 3-parameter shared 2×2 — the *most parsimonious* full
random-regression model, not a contradiction. `scalar` + slope is **APPLICABLE**.

## 7. Implementation status (target vs current — fit-verified by S0)

The taxonomy above is the **target**. The empirical census (slice S0,
`scratchpad/semantics-census.md`, all counts fit-verified via `tmb_map`, T=3 and
T=4) establishes the current engine reality. **Headline: intercept-only cells all
match target; the mismatches are confined to slope cells, and for slopes the
current keyword names are *shifted* relative to the target.**

### 7.1 The engine-name shift (the crux finding)

For `mode(1 + x | g)`, what the current keyword actually fits vs which target
cell that engine *is*:

| current keyword (slope) | engine reality (fit-verified) | = target cell |
|---|---|---|
| `*_indep(1+x\|g)` | shared 2×2, ρ **pinned 0**, **2 params**, T-invariant | **`scalar` `\|\|`** |
| `*_unique(1+x\|g)` (deprecated) | shared 2×2, ρ **free**, **3 params** | **`scalar` `\|`** |
| `*_dep(1+x\|g)` | full 2T×2T unstructured | **`dep` `\|`** ✓ (correct) |
| `*_latent(1+x\|g)` | separate Λ_int, Λ_slope | **`latent` `\|\|`** |

The mechanical cause: the correlated augmented design matrix never indexes by
trait (`R/fit-multi.R:3085-3086` — `b_phy_aug` is one (intercept, slope) pair per
group, added identically to every trait), so both `*_indep` and `*_unique` slope
forms are **shared-across-traits**, differing only in the ρ pin
(`R/fit-multi.R:3862-3887`). So today `*_indep(1+x|g)` is **not** per-trait —
its own name's promise (matched by its intercept-only sibling) is broken once a
slope appears.

### 7.2 What exists vs what must be built

**Already exists → CHEAP (parser routing to a proven engine, S2b):**
- `scalar(1 + x \| g)` → the `*_unique` augmented engine (shared 2×2, ρ free, 3).
- `scalar(1 + x \|\| g)` → the current `*_indep` augmented engine (shared 2×2,
  ρ=0, 2).
- `dep(1 + x \| g)` → current `*_dep` augmented (full 2T×2T) — already correct.
- `latent(1 + x \|\| g)` → current `*_latent` augmented (separate Λ blocks).
- Intercept-only `scalar()` → `common = TRUE` (diag) engine. **LANDED** (tested).
- Intercept-only `kernel_scalar()` → the `kernel_indep` diagonal `phylo_rr`
  path with the per-trait `theta_rr_phy` tied to one shared level (the
  `spatial_scalar` `log_tau_spde` trick), so it stays extractable under
  `level = name`. **LANDED** (recovery-tested; 1 free variance vs `kernel_indep`'s T).
- Fix the malformed `*_scalar(1+x)` → `propto` nesting.

**Does NOT exist → the genuine engine build (S2c; stats-gated, likely C++, Totoro):**
- **`indep(1 + x \| g)`** per-trait correlated 2×2 (**3T**) — no source has it.
  This is the real new engine, and it **changes** what `*_indep(1+x)` means
  today (shared-2 → per-trait-3T): a **behavioural/API change** with existing
  tests to migrate.
- **`indep(1 + x \|\| g)`** per-trait diagonal (2T) — exists only for the none
  source, *bundled inside* `latent()`'s default Psi companion
  (`theta_diag_B_slope`, `R/fit-multi.R:1627`), never standalone.
- **`dep(1 + x \|\| g)`** block Σ_int⊕Σ_slope — does not exist.
- **`latent(1 + x \| g)`** shared-factor — deferred (§4).

### 7.3 `||` is not free sugar

The two-term split (`mode(1|g)+mode(0+x|g)`) **does not work today**: the parser
hand-refuses a standalone slope-only term for every wrapper
(`R/brms-sugar.R` guards ~1969/3421/3545/3741/3888), and a literal `||` fails
either immediately (phylo wrappers) or one stage later in
`parse_covstruct_call` (`R/parse-multi-formula.R:178-180`, which requires the bar
head to be exactly `` `|` ``). So `||` must be intercepted **before** that check
and routed to the per-trait/block engines — which, for `indep`/`dep`, **do not
exist yet**. `||` for `scalar` and `latent` *is* cheap (their engines exist);
`||` for `indep`/`dep` is coupled to the S2c engine build.

### 7.4 Consequence for sequencing

`scalar()` + `kernel_scalar()` (the maintainer's original priority) + `scalar`
slopes + `latent ||` are **cheap and non-breaking** (new keywords / routing to
existing engines) and can land in the relabel-adjacent phase. The **`indep`
redefinition is the one breaking, engine-heavy, stats-gated slice** — it builds
a per-trait correlated engine that does not exist and changes the meaning of
`*_indep(1+x)`. Migration of the current mislabelled `*_indep(1+x)` behaviour
(really `scalar ||`) is a maintainer decision (§ open question).

## 8. Reader-facing draft (for `api-keyword-grid.Rmd`, lands in S3)

> ### Two decisions, plus one for random slopes
>
> Choosing a covariance keyword is two decisions — the **source** (what relates
> the grouping levels) and the **mode** (what trait covariance holds at that
> level). A random *slope* adds a third: whether the intercept and slope are
> **correlated**.
>
> - A single bar, `mode(1 + x | g)`, **models the intercept–slope correlation**
>   (the default, as in lme4/glmmTMB).
> - A double bar, `mode(1 + x || g)`, makes them **uncorrelated** — it is exactly
>   `mode(1 | g) + mode(0 + x | g)`.
>
> The mode still sets the cross-trait structure; the bar count sets the
> intercept–slope coupling. For $T$ traits:
>
> | mode | `mode(1 + x \| g)` (correlated) | `mode(1 + x \|\| g)` (uncorrelated) |
> |---|---|---|
> | `scalar` | one 2×2 intercept–slope covariance shared across all traits (3 params) | shared intercept variance + shared slope variance |
> | `indep`  | a separate 2×2 per trait, no cross-trait covariance | a per-trait intercept variance + slope variance |
> | `dep`    | a full covariance across all trait intercepts and slopes | a full intercept covariance and a full slope covariance, with intercepts ⊥ slopes |
>
> `scalar(1 + x | g)` is the classic random-regression G-matrix applied to every
> trait — the most parsimonious random-slope covariance. Extract any of them with
> `extract_Sigma(fit, level = …)`.

(Runnable examples for the new syntax are added alongside the implementation, so
this page never shows a formula that does not fit.)

## 9. Cross-package coordination (drmTMB)

drmTMB (the brms-like distributional-regression twin) already fits correlated
random slopes `(1 + x | id)` and uses the brms grouping-ID `(1 + x | p | id)`,
which correlates random effects **across distributional parameters** — an axis
orthogonal to gllvmTMB's trait-mode axis. The **`|` = correlated / `||` =
uncorrelated** convention should be **aligned across the twins** so users carry
one mental model. Action (slice S4): a drmTMB GitHub issue proposing the aligned
convention + a directed `docs/dev-log/check-log.md` note (the cross-team bus);
Shannon audits; the maintainer posts the issue.

## Related

Design 55 (structural-slope grammar; §5 superseded here), Design 56 (augmented-
LHS engine), Design 60 (augmented-slope scoping), Design 61 (capability status),
`vignettes/articles/api-keyword-grid.Rmd`, `docs/dev-log/capability-surface.html`,
the ultra-plan at `~/.claude/plans/glistening-skipping-anchor.md`.
