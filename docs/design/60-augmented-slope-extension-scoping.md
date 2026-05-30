# Design 60 — Scoping: extending the augmented random-slope engine beyond `phylo_unique`

**Status:** Read-only scoping/audit memo. Drafted 2026-05-29.
**Type:** Design memo only — no R/ or src/ changes accompany it.
**Worktree:** `agent/fix-animal-slope` (package version 0.2.0, `DESCRIPTION`).
**Parent designs:** [Design 55 — structural-slope grammar](55-structural-slope-grammar.md),
[Design 56 — augmented-LHS engine Stage 3](56-augmented-lhs-engine-stage3.md).
**Scope:** assess what it takes to lift `phylo_unique(1 + x | sp)`'s working
augmented random-regression path to the remaining APPLICABLE cells —
`{phylo_dep, phylo_indep, phylo_latent}` and all four `spatial_*` modes.

This memo records **only what is in the code today**, with `file:line`
citations for every load-bearing claim, then maps each mode to the work
required. It is the deferred Stage-3 scoping that Design 56 §9.5 sequences
but does not itself execute.

---

## 0. Executive verdict

| Mode | Engine today | Parser guard | Effort to enable | Verdict |
|---|---|---|---|---|
| `phylo_unique(1+x\|sp)` | **works** (live engine + live test) | open | — already done | DONE |
| `phylo_indep(1+x\|sp)` | reuses phylo engine; needs ρ-pin (map) | hard guard, `:2506-2512` | **S–M** | parser-light, small engine touch |
| `phylo_dep(1+x\|sp)` | engine **caps `n_lhs_cols ≤ 2`**, block-local; full `2T×2T` not built | hard guard, `:2582-2588` | **L** | needs real new C++ |
| `phylo_latent(1+x\|sp,d)` | no augmented×factor-analytic term | (routes via `phylo` wrapper guard `:2299-2308`) | **L** | needs real new C++ |
| `spatial_unique(1+x\|site)` | **no SPDE augmented engine at all** | construction abort `:1714-1718` | **L** | needs real new C++ |
| `spatial_indep(1+x\|site)` | none | construction abort `:1680-1684` | **L** | needs real new C++ |
| `spatial_dep(1+x\|site)` | none | construction abort `:1714-1718` | **L** | needs real new C++ |
| `spatial_latent(1+x\|site,d)` | none | construction abort `:1714-1718` | **L** | needs real new C++ |

**Maintainer's hypothesis ("dep/indep should be easy") — corrected:**
`phylo_indep` is genuinely easy-ish (a diagonal special case of the engine
that already exists, reachable by pinning ρ). **`phylo_dep` is NOT easy** —
its defining feature is a full unstructured `2T × 2T` cross-trait covariance,
and the live augmented engine is explicitly **block-local with `n_lhs_cols ∈
{1,2}`** and a single block (`src/gllvmTMB.cpp:557-559`, `:199`;
`R/fit-multi.R:1212-1213`). That `2T × 2T` term does not exist in C++ and is
a real new likelihood contribution. See §3.2–§3.3 for the evidence.

The spatial family is uniformly **L**: there is no covariate-slope plumbing
anywhere in the SPDE block (§3.5).

---

## 1. Current engine state — the `phylo_unique` / `phylo_rr` augmented path

The augmented random-slope engine is wired **only** through the phylogenetic
reduced-rank (`phylo_rr`) machinery, behind the flag
`use_phylo_slope_correlated`.

### 1.1 Declarations (`src/gllvmTMB.cpp:194-281`)

- `DATA_INTEGER(use_phylo_slope_correlated)` — gate (`:198`).
- `DATA_INTEGER(n_lhs_cols)` — "block-local LHS columns: 1 or 2 in Stage 3"
  (`:199`).
- `DATA_ARRAY(Z_phy_aug)` — `n_obs × n_lhs_cols × n_phy_aug_blocks` (`:200`).
- `PARAMETER_ARRAY(b_phy_aug)` — `n_aug_phy × n_lhs_cols × n_phy_aug_blocks`
  (`:279`).
- `PARAMETER_VECTOR(log_sd_b)` — length `n_lhs_cols` (`:280`).
- `PARAMETER_VECTOR(atanh_cor_b)` — length `n_lhs_cols*(n_lhs_cols-1)/2`
  (`:281`).

The augmented arrays **reuse the phylo_rr relatedness machinery**:
`Ainv_phy_rr` (`:168`), `n_aug_phy` (`:167`), `species_aug_id` (`:170`),
`log_det_A_phy_rr` — they are not a free-standing block. This is why "the
augmented engine" is, structurally, a phylo-only object.

### 1.2 Prior contribution (`src/gllvmTMB.cpp:557-621`)

Active when `use_phylo_slope_correlated == 1`. After dimension asserts
(`:558-574` — these `error()` on any shape mismatch, satisfying Design 56
§7.2's fail-loud invariant), the prior splits:

- **`n_lhs_cols == 1`** (`:579-591`): slope-only; `Σ_b` is `1×1`, diagonal
  `exp(log_sd_b(0))^2`; quadratic form `b0' Ainv_phy_rr b0`.
- **`n_lhs_cols == 2`** (`:592-620`): intercept + slope; builds the `2×2`
  inverse-covariance in closed form from `sd_b(0)`, `sd_b(1)`, and
  `rho = tanh(atanh_cor_b(0))` (`:593-600`), then the bivariate quadratic
  `inv00*q00 + 2*inv01*q01 + inv11*q11` (`:611-614`). This is the standard
  reaction-norm / random-regression prior `vec(B) ~ N(0, Σ_b ⊗ A_phy)` with
  the Kronecker structure exploited so the cost stays `O(n_sp)`.

There is **no `n_lhs_cols > 2` branch**, and the asserts hard-reject it
(`:558-559`, "n_lhs_cols must be 1 or 2 in Phase 56.1").

### 1.3 Linear-predictor contribution (`src/gllvmTMB.cpp:780-789`)

```cpp
if (use_phylo_slope_correlated == 1) {
  Type contrib_aug = 0;
  for (int k = 0; k < b_phy_aug.dim[2]; k++)
    for (int j = 0; j < n_lhs_cols; j++)
      contrib_aug += b_phy_aug(species_aug_id(o), j, k) * Z_phy_aug(o, j, k);
  eta(o) += contrib_aug;
} else if (use_phylo_slope == 1) {            // legacy scalar slope
  eta(o) += b_phy_slope(species_aug_id(o)) * x_phy_slope(o);
}
```

The augmented `eta` contribution sums over LHS columns (intercept × 1 + slope
× x), per block. The legacy scalar `phylo_slope()` path (`b_phy_slope`,
`x_phy_slope`, `:277`, `:194`, `:543-553`) is preserved byte-for-byte and is
mutually exclusive with the augmented branch.

### 1.4 R-side plumbing (`R/fit-multi.R`)

- `use_phylo_slope_correlated <- isTRUE(phylo_slope_cs$extra$.phylo_unique_augmented)`
  (`:573-575`) — **the only activation switch**. It is set exclusively by the
  `phylo_unique` parser branch (§2.1).
- `n_lhs_cols <- if (use_phylo_slope_correlated) 2L else 1L` (`:1212`) — so the
  augmented path is **hardwired to exactly 2 columns**; there is no path that
  produces any other value.
- `n_phy_aug_blocks <- 1L` (`:1213`) — **the block dimension is hardwired to 1.**
  The `k` loop in §1.2/§1.3 always runs once. The "blocks" axis that Design 56
  §3.1 imagined for trait stacking is degenerate in the shipped code.
- `Z_phy_aug[, 1, 1] <- 1.0; Z_phy_aug[, 2, 1] <- x_phy_slope_dat` (`:1226-1227`)
  — column 0 = intercept ones, column 1 = the covariate. The wide and long
  surfaces both build this same 2-column Z (the byte-identity contract,
  Design 55 §3).
- Params init: `b_phy_aug`, `log_sd_b`, `atanh_cor_b` sized from `n_lhs_cols`
  (`:1351-1353`).
- Map discipline: when `!use_phylo_slope_correlated`, all three are
  `factor(NA)`-mapped off (`:1646-1651`), so legacy fits reproduce
  byte-identically. When active, `b_phy_aug` joins the random vector
  (`:1901-1902`).

### 1.5 Test status

`tests/testthat/test-phylo-unique-slope-gaussian.R` is **LIVE** — gated only
on package deps (`ape`, `MCMCglmm`; `:15-19`), not on `skip_until_stage3()`.
It exercises wide≡long byte-identity (`:134`), `Σ_b` recovery (`:159`), and the
negative test that forcing `n_lhs_cols = 1` under a `1+x` formula aborts
(`:181`). This is the proof that the `phylo_unique` cell is end-to-end
complete: engine → parser → R wrapper → passing recovery test.

Every other slope cell's test is a `skip_until_stage3()` placeholder with an
`expect_true(TRUE)` body (e.g. `test-spatial-unique-slope-gaussian.R:28-61`,
`test-phylo-dep-slope-gaussian.R:21-46`). The full skeleton set:
`test-{phylo,animal,relmat,spatial}-{dep,indep,latent,unique}-slope-gaussian.R`
exists, all gated, except the `phylo-unique` one above.

---

## 2. Parser guards that block dep / indep / latent / spatial slope

All guards confirmed by reading the cited lines. Two distinct guard families:
(a) a generic "augmented LHS not yet supported" assertion, and (b) per-keyword
"LHS richer than `0 + trait`" / "bar must be `0 + trait | coords`" aborts.

### 2.1 The one path that is OPEN — `phylo_unique` (`R/brms-sugar.R:2380-2426`)

`phylo_unique`'s bar-form branch classifies the LHS via `.gllvmTMB_lhs_form()`
(`:2389`) and, for `wide_intercept_slope` / `long_intercept_slope`
(`:2406-2408`), rewrites to
`phylo_slope(bar, .phylo_unique_augmented = TRUE, lhs_form, slope_col, …)`
(`:2410-2419`) — the rewrite that flips `use_phylo_slope_correlated` on in
`fit-multi.R`. Anything outside `{intercept_only, wide_intercept_slope,
long_intercept_slope}` still aborts (`:2421-2426`, "Phase 56.3 accepts only
`1 + x | species` and `0 + trait + (0 + trait):x | species`").

### 2.2 The LHS classifier (`R/brms-sugar.R:1544-1586`)

`.gllvmTMB_lhs_form()` returns `intercept_only` / `wide_intercept_slope` /
`long_intercept_slope` / `unsupported`. It already recognises both augmented
surfaces. **The classifier is mode-agnostic** — the blocking is entirely in
the per-keyword branches below, not here. This is the single most reusable
asset for the extension.

### 2.3 Per-keyword guards that BLOCK the extension

| Keyword | Guard | `file:line` | Message |
|---|---|---|---|
| `phylo_indep` | `if (!.is_zero_plus_trait(lhs_bar))` abort | `R/brms-sugar.R:2506-2512` | "`phylo_indep()` LHS richer than `0 + trait` is not yet supported … reserved for a future release" |
| `phylo_dep` | `if (!.is_zero_plus_trait(lhs_bar))` abort | `R/brms-sugar.R:2582-2588` | "`phylo_dep()` LHS richer than `0 + trait` is not yet supported" |
| `phylo` (mode-dispatch wrapper) | `if (!is_intercept_only && !is_zero_plus_trait)` abort | `R/brms-sugar.R:2299-2308` | "`phylo` augmented LHS is not yet supported … Design 07 Stage 3" |
| `spatial` (mode-dispatch wrapper) | same shape test, abort | `R/brms-sugar.R:1968-1976` | "`spatial` augmented LHS is not yet supported … Design 07 Stage 3" |
| `spatial_indep` | `normalise_spatial_orientation()` rejects any non-`0+trait` bar | `R/brms-sugar.R:1680-1684` | "`spatial_indep` bar must be `0 + trait | coords`" |
| `spatial_unique` / `spatial_scalar` / `spatial_latent` / `spatial_dep` | `normalise_spatial_orientation()` fall-through abort | `R/brms-sugar.R:1714-1718` | "`<fn>` bar must be `0 + trait | coords`" |
| bare `latent` / `unique` / `indep` / `dep` / `spatial_dep` | `.assert_no_augmented_lhs(fn, e)` | def `R/brms-sugar.R:1606-1639`; call sites `:2218`, `:2234`, `:2468`, `:2548`, `:2608` | "`<fn>` augmented LHS is not yet supported … require Design 07 Stage 3 engine work" |
| bare-bar `(1 + x | g)` (non-structural) | `parse_re_int_call()` abort | `R/parse-multi-formula.R:165-180` | "Bar-syntax … not yet implemented … correlated intercept+slope `(1 + x | group)` are coming in a future release" |

Note the **spatial guards abort at construction time** (inside the keyword
function / `normalise_spatial_orientation`), before `fit-multi.R` is reached —
matching the empirical "abort at construction" observation. The phylo dep/indep
guards abort during the `gllvmTMB()` formula-preprocessing rewrite pass.

The `phylo_latent` / `spatial_latent` keywords have **no augmented branch at
all** — a grep for `latent` ∩ {augment, slope, `lhs_form`} in `brms-sugar.R`
returns nothing; they reach the generic `phylo` / `spatial` wrapper guards
(`:2299-2308`, `:1968-1976`) or the bare-keyword guard.

---

## 3. Per-mode feasibility

The deciding question for each mode: **can it route through the existing
`b_phy_aug` / `Σ_b` block (§1.2), or does it need a new C++ likelihood term?**

### 3.1 `phylo_indep(1 + x | sp)` — **S–M** (engine reuse + ρ-pin)

- **Engine:** reusable. `indep` means the intercept–slope correlation ρ is
  fixed at 0 — i.e. the `n_lhs_cols == 2` branch (`src/gllvmTMB.cpp:592-620`)
  with `atanh_cor_b` mapped to NA, giving `rho = tanh(0) = 0`, so `inv01 = 0`
  and the quadratic decouples. **No new C++ math** — it is a strict special
  case of the live `unique` engine. Design 56 §5.3 specifies exactly this
  (diagonal `Σ_b`, `atanh_cor_b` map-pinned).
- **Parser:** lift the guard at `R/brms-sugar.R:2506-2512`; route the augmented
  LHS forms to the same `.phylo_unique_augmented = TRUE` rewrite (§2.1) but
  with an `indep` marker so the R map list pins `atanh_cor_b` to `factor(NA)`
  even when active.
- **Plumbing:** one new flag through `fit-multi.R` (e.g.
  `.phylo_indep_augmented`) that forces the `atanh_cor_b` NA-map while still
  setting `use_phylo_slope_correlated = 1`, `n_lhs_cols = 2`. The existing
  NA-map machinery (`:1646-1651`) is reused, not extended.
- **Risk:** low. Main risk is identifiability of `σ²_slope` on sparse data
  (Design 56 §5.3), which is a test-fixture concern, not an engine bug.
- **Effort: S–M.** This is the cell that justifies the maintainer's "should be
  easy" intuition — but it is easy *because it is the diagonal special case of
  the `unique` engine that already exists*, not because dep/indep are
  intrinsically simple.

### 3.2 `phylo_dep(1 + x | sp)` — **L** (real new C++ term)

- **Engine:** **NOT reusable as-is.** `dep`'s contract is the *full
  unstructured cross-trait covariance* — for an intercept+slope LHS over `T`
  traits that is a `2T × 2T` matrix (Design 55 §7.3, Design 56 §5.3:
  "full unstructured `2T × 2T` per group … Cholesky-decomposed"). The live
  engine is explicitly **block-local, `n_lhs_cols ∈ {1,2}`**
  (`src/gllvmTMB.cpp:199`, hard-asserted at `:558-559`), with a single block
  (`R/fit-multi.R:1213`, `n_phy_aug_blocks <- 1L`). The `2T × 2T` form is not
  present anywhere in C++.
- **Why it's hard, concretely:** the wide↔long byte-identity contract
  (Design 55 §3, Design 56 §5.2) depends on `Σ_b` being shared across traits at
  the prior level — a `2 × 2`, not `2T × 2T`. `dep` deliberately *breaks* that
  by making the cross-trait block unstructured. So `dep` cannot reuse the
  block-local `Σ_b` path; it needs either (a) a genuine `2T × 2T`
  `UNSTRUCTURED_CORR` parameterisation on an LHS-stacked parameter vector
  (Design 56 §5.3), or (b) routing through the `phylo_rr` reduced-rank path at
  `d = T` with augmented columns — and the existing `phylo_rr` block
  (`Lambda_phy`, `g_phy`, `src/gllvmTMB.cpp:268-269`, `:770-775`) is
  intercept-only over traits, with no covariate-column axis. Either way it is a
  new likelihood contribution + new parameter packing + new map logic.
- **Parser:** lift `R/brms-sugar.R:2582-2588`, but the guard lift is the *small*
  part — it must not lift before the engine term exists (Design 56 §7.1
  fail-loud invariant: do not loosen the guard ahead of the engine, or the
  Sokal 2026-05-09 silent-collapse recurs).
- **Risk:** medium-high. `2T × 2T` identifiability on finite samples; Cholesky
  parameterisation; the silent-collapse trap if sequenced wrong.
- **Effort: L.** This directly contradicts "dep should be easy."

### 3.3 `phylo_latent(1 + x | sp, d = K)` — **L** (real new C++ term)

- **Engine:** not reusable. `latent` is factor-analytic — `Σ_b` per LHS column
  becomes `Λ_k Λ_kᵀ + diag` (Design 56 §5.3). The existing factor-analytic
  phylo block is `phylo_rr` (`theta_rr_phy` / `Lambda_phy` / `g_phy`,
  `src/gllvmTMB.cpp:264-269`, prior `:480-507`, `eta` `:770-775`), and it has
  **no covariate-slope column** — `g_phy` is `n_aug_phy × d_phy` indexing latent
  factors, not LHS columns. Combining factor-analytic structure with an
  intercept+slope LHS is a new term: a per-LHS-column (or block-diagonal)
  reduced-rank decomposition routed through `b_phy_aug`-style augmented columns.
- **Parser:** `phylo_latent` has no augmented branch today; it hits the generic
  `phylo` wrapper guard (`:2299-2308`). Needs a new bar-form augmented branch
  analogous to §2.1.
- **Effort: L.**

### 3.4 `spatial_unique(1 + x | site)` — **L** (no SPDE augmented engine exists)

- **Engine:** **does not exist.** The SPDE block (`src/gllvmTMB.cpp:623-790`)
  models intercept-only spatial fields: per-trait `omega_spde` (`:258`,
  `:643-651`, `:760-763`) or low-rank `omega_spde_lv` (`:265`, `:672-678`,
  `:764-767`). There is **no `Z_spde_aug`, no `b_spde_aug`, no
  `use_spde_slope`/`spde…correlated`** — confirmed by grep returning nothing in
  both `src/gllvmTMB.cpp` and `R/fit-multi.R`. A spatial random slope means a
  *second SPDE field per group acting on the covariate* — `eta += (A_proj ω_α)
  + x·(A_proj ω_β)` with a `2×2` cross-field covariance — which is an entirely
  new SPDE-side contribution and parameter set.
- **Parser:** the bar is rejected at construction in
  `normalise_spatial_orientation()` (`:1714-1718`) before `fit-multi.R`.
- **Effort: L.** The SPDE precision does not "just compose" — there is no slope
  axis in the spatial engine to compose with. Design 55 §5 / 56 §9.5e listed
  `spatial_unique` as APPLICABLE and "verify SPDE precision composes," but the
  shipped engine has no augmented SPDE term to verify; it must be built first.

### 3.5 `spatial_indep` / `spatial_dep` / `spatial_latent` (1 + x | site) — **L** each

All four spatial slope cells share the same blocker as §3.4: **no augmented
SPDE engine of any kind.** Layered on top:

- `spatial_indep`: diagonal `2×2` (ρ=0) cross-field cov — once the base SPDE
  augmented term (§3.4) exists, this is its diagonal special case (analogous to
  §3.1's relationship to §3.4). But the base term must exist first → **L**.
- `spatial_dep`: full `2T × 2T` over the spatial fields → **L**, hardest spatial
  cell (combines §3.2's `2T×2T` problem with §3.4's missing-engine problem).
- `spatial_latent`: factor-analytic over LHS columns on `omega_spde_lv` → **L**.

Parser blockers: `spatial_indep` at `:1680-1684`; the others at `:1714-1718`.

### 3.6 `animal_*` and `relmat` (vcv = A) slope cells — inherit phylo, **mostly tests**

Not in the prompt's enumeration but adjacent and worth one line: per Design 14
§5 byte-equivalence, `animal_*` is sugar over `phylo_*(vcv = A)`. Their slope
cells inherit whatever the corresponding `phylo_*` cell supports — so
`animal_unique(1+x|id)` should already work through the `phylo_unique`
augmented path once the `animal_unique` parser branch routes a bar-form LHS to
it (verify), and `animal_{dep,indep,latent}` inherit §3.1–§3.3's verdicts.
Their test skeletons (`test-animal-*-slope-gaussian.R`,
`test-relmat-*-slope-gaussian.R`) are all `skip_until_stage3()` placeholders.
Effort there is **predominantly test + parser-routing**, not engine.

---

## 4. Recommended sequencing

Ordered by "parser-guard-lift + existing-engine reuse" (cheap) →
"needs real new C++ likelihood term" (expensive). This refines Design 56 §9.5,
which already sequences these as sub-phases 56.5a–56.5f.

**Tier 1 — genuinely easy (engine already exists; lift guard + ρ-pin):**

1. `phylo_indep(1+x|sp)` (§3.1) — diagonal special case of the live `unique`
   engine. Map `atanh_cor_b` to NA; lift guard `:2506-2512`. **S–M.**
2. `animal_unique` + `relmat unique` slope (§3.6) — parser routing to the
   existing `phylo_unique` augmented path + tests. **S** (verify, don't build).
3. `animal_indep` / `relmat indep` — inherit Tier-1 #1 once it lands. **S.**

**Tier 2 — real new C++ likelihood terms (do NOT lift guard first):**

4. `phylo_dep(1+x|sp)` (§3.2) — `2T × 2T` unstructured term. **L.**
5. `phylo_latent(1+x|sp,d)` (§3.3) — factor-analytic × augmented LHS. **L.**
6. SPDE base augmented term — prerequisite for all spatial cells (§3.4). **L.**
7. `spatial_unique` → `spatial_indep` → `spatial_latent` → `spatial_dep`
   (§3.4–§3.5), in that order, each on top of #6. **L** each.

The Tier-1/Tier-2 split is the actionable correction to the maintainer's
"dep/indep should be easy": **split dep from indep.** `indep` is Tier 1; `dep`
is Tier 2 and is one of the hardest cells in the matrix.

**Hard invariant for every tier (Design 56 §7.1):** no PR may lift a parser
guard (`R/brms-sugar.R` §2.3 sites) until the engine block it routes into
already understands the LHS shape it will receive. The `.assert_no_augmented_lhs`
guard and its dimension asserts in C++ (`src/gllvmTMB.cpp:558-574`) exist
precisely to prevent the Sokal 2026-05-09 silent-collapse; keep them fail-loud.

---

## 5. Confirming / correcting the maintainer's belief

> "dep/indep should be easy"

**Half right, and the half that's wrong is the expensive half.**

- **`indep` — confirmed easy (Tier 1, S–M).** Evidence: the `n_lhs_cols == 2`
  bivariate prior already exists and is live (`src/gllvmTMB.cpp:592-620`);
  `indep` is exactly that prior with ρ pinned to 0 via the existing
  `atanh_cor_b` NA-map (`R/fit-multi.R:1646-1651`). No new C++ math. The only
  work is lifting the parser guard (`:2506-2512`) and adding one routing flag.

- **`dep` — corrected to hard (Tier 2, L).** Evidence: `dep`'s defining
  semantics are a full unstructured `2T × 2T` cross-trait covariance
  (Design 55 §7.3; Design 56 §5.3). The live augmented engine is **block-local,
  capped at `n_lhs_cols ≤ 2`** (`src/gllvmTMB.cpp:199`, hard-asserted
  `:558-559`) with a single block (`R/fit-multi.R:1213`). The `2T × 2T`
  unstructured/Cholesky term is **not present in C++** and is a real new
  likelihood contribution + parameter packing + map logic. Lifting the guard
  at `:2582-2588` without that term first would reintroduce the silent-collapse
  Design 56 §7 forbids.

The likely source of the "both easy" intuition: `dep` and `indep` *look*
symmetric in the keyword grid (both per-trait covariance modes), and `indep`
genuinely reuses the shipped engine. But `dep` ≠ "`indep` with correlations
turned on" — it is "full unstructured across all `2T` columns," a structurally
larger object than the `2×2` block the engine ships with.

---

## 6. Cross-references

- [Design 55 — structural-slope grammar](55-structural-slope-grammar.md): §5
  APPLICABLE matrix (16 cells), §3 wide↔long byte-identity contract, §4
  parser-spec, §7.3 reserves the `dep` `2T×2T` form, §8 A1 stop conditions.
  This memo is the per-mode realisation of §5 against the *shipped* engine.
- [Design 56 — augmented-LHS engine Stage 3](56-augmented-lhs-engine-stage3.md):
  §3.1 parameter-shape promotion (now shipped for phylo), §5.2 block-local
  `n_lhs_cols` semantics, §5.3 per-keyword `Σ_b` variants (the source for §3.1–
  §3.5 verdicts here), §7 fail-loud invariant, §9.5a–f sub-phase sequencing
  that §4 above refines. **Design 56 §9.1 (phylo engine promotion) is DONE in
  the shipped code** (§1 evidence); §9.5b–f remain the open work this memo
  scopes.
- [Design 55 §A1 closeout](../dev-log/audits/2026-05-26-design-55-a1-closeout.md)
  and [Phase 56.2 R-side audit](../dev-log/audits/2026-05-26-phase56-2-rside-audit.md)
  — the prior artefacts establishing why the engine path (not parser-only) was
  needed.
- [Design 14 — known-relatedness keywords](14-known-relatedness-keywords.md) §5
  — `animal_* ≡ phylo_*(vcv = A)` sugar, the basis for §3.6.
- [Design 35 — validation-debt register](35-validation-debt-register.md): rows
  FG-15 / RE-02 / PHY-06 / ANI-06 = `partial`, RE-03 = `blocked`
  (`docs/design/35-validation-debt-register.md:99,136,137,157,204`). None of
  the dep/indep/latent/spatial slope cells is `covered`; only `phylo_unique`'s
  is test-backed today (§1.5).

---

*Read-only scoping memo. Every `file:line` herein was read in producing it.
No R/ or src/ files were modified. Effort tags (S/M/L) are rough order-of-
magnitude, not estimates of calendar time; Design 56 §12 carries the
phase-level day estimates.*
