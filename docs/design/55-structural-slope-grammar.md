# Design 55 — Structural-dependence × random-slope grammar

**Maintained by:** Boole (parser + formula grammar lead), Noether
(math-vs-implementation alignment), Gauss (TMB engine + numerical
correctness), Rose (scope honesty), Shannon (cross-team
coordination).
**Lead author:** Claude/Shannon (drafting), with Boole + Noether
+ Rose lenses applied throughout. Reviewers: Ada (maintainer) +
Codex.
**Status:** Active design contract, drafted 2026-05-26.
**Backed by:** the approved plan at
[`please-have-a-robust-elephant.md`](../../) (2026-05-26),
Design 04 (4 × 5 keyword grid), Design 14 (`animal_*` ↔
`phylo_*(vcv = A)` byte-equivalence), Design 35 (validation-debt
rows RE-02 / RE-03 / FG-15 / PHY-06 / ANI-06), the augmented-LHS
guard at `R/brms-sugar.R:1543-1576` and its test at
`tests/testthat/test-augmented-lhs-guard.R` (the canonical
current-state artefacts for what's known in the codebase as
"Design 07 Stage 3" — a planned but not-yet-written design
doc), and the Explore audit transcripts dated 2026-05-26 in
this PR's discussion.

## 1. Purpose

Extend the canonical structural-dependence keywords —
`phylo_*`, `animal_*`, `spatial_*`, and the user-supplied
relatedness-matrix path via `vcv = A` — to accept an
**intercept + slope** random-effect LHS, in both gllvmTMB's
public surfaces (wide and long). Soft-deprecate
`phylo_slope()` and `animal_slope()` as top-level keywords;
they become aliases that redirect to the new syntax.

This design **does not re-derive**:

- the 4 × 5 keyword grid (Design 04, §"Vocabulary");
- the augmented-LHS Stage 3 mechanics (the planned-but-unwritten
  doc the codebase refers to as "Design 07"; the
  `cli::cli_abort` fail-loud parser-guard pattern at
  `R/brms-sugar.R:1543-1576` that this design adopts; the
  hardcoded `n_traits` sites in `R/fit-multi.R` that the guard
  error message names);
- the `animal_* ≡ phylo_*(vcv = A)` byte-equivalence contract
  (Design 14 §5);
- the per-trait link-residual machinery for non-Gaussian
  families (`R/extract-sigma.R::link_residual_per_trait()`).

It **does add**:

- a precise wide ↔ long byte-identity contract for the new
  intercept+slope LHS pattern;
- a parser-spec describing exactly where the existing
  augmented-LHS guard at `R/brms-sugar.R:1543-1576` must
  permit two new LHS forms;
- a per-cell applicability matrix for (4 structural families ×
  5 keywords × Gaussian) = 20 cells, marking each as
  applicable, not-applicable, or deferred;
- the soft-deprecation pathway for `phylo_slope()` and
  `animal_slope()`;
- stop conditions for the iterative parser-only-first
  implementation strategy.

## 2. Scope

### 2.1 Keyword surface

The intercept+slope LHS is supported (Phase A) in all five
canonical structural keywords across all four structural
families:

| Keyword | `phylo_*` | `animal_*` | `spatial_*` | `vcv = A_user` path |
|---|---|---|---|---|
| `latent(LHS, d = K)` | ✓ | ✓ (via `phylo_*(vcv = A)`) | ✓ | ✓ |
| `unique(LHS)` | ✓ | ✓ | ✓ | ✓ |
| `indep(LHS)` | ✓ | ✓ | ✓ | ✓ |
| `dep(LHS)` | ✓ | ✓ | ✓ | ✓ |
| `scalar(LHS)` | per applicability matrix §5 | per §5 | per §5 | per §5 |

Per Design 14 §5 byte-equivalence,
`animal_X(id, pedigree = ped) ≡ animal_X(id, A = pedigree_to_A(ped))
≡ phylo_X(id, vcv = pedigree_to_A(ped))` — `animal_*` is sugar
over `phylo_*(vcv = A)`. The slope extension follows the same
sugar contract: any (intercept+slope, structural-family) cell
that works on the canonical `phylo_*(vcv = A)` path
automatically works on the `animal_*` and arbitrary-A user-supplied
paths.

### 2.2 LHS pattern

**One pattern in scope, two surfaces (byte-identical fits per
gllvmTMB's two-surfaces-one-engine contract)**:

| Surface | LHS form | Reader path |
|---|---|---|
| **Wide** (`gllvmTMB(traits(...) ~ ...)`) | `(1 + x \| id)` | Random intercept + random slope per `id`; single covariate `x`. |
| **Long** (`gllvmTMB(value ~ ...)`) | `(0 + trait + (0 + trait):x \| id)` | Trait-specific random intercepts + trait-specific random slopes per `id` on covariate `x`. |

The two surfaces produce **byte-identical fits** (Σ within
1e-6, logLik to the unit). This is the wide↔long contract
already established for intercept-only structural keywords
(validation-debt **MIS-02** + **FG-03** = `covered`); the
intercept+slope extension preserves it.

The slope covariate is **a single named column** in the model
data. The standard teaching name is `x`; domain articles may
use `env`, `env_1`, `treatment`, etc., per their reader path.

### 2.3 Family progression

- **Phase A** (this design): **Gaussian only**. All four
  structural families × five canonical keywords × intercept+slope
  LHS, fully validated with recovery tests on Gaussian.
- **Phase B** (after Phase A close): extends each validated
  Phase A cell to non-Gaussian families (binomial / nbinom2 /
  ordinal-probit / mixed-family) with explicit identifiability
  notes per cell. Out of scope for this design; see Phase B in
  the approved plan.

## 3. The wide ↔ long byte-identity contract

For any (structural family, keyword) combination admitted by
the per-cell applicability matrix §5, the following two
formulas must produce byte-identical fits:

```r
# Wide surface
gllvmTMB(
  traits(y1, y2, y3, y4) ~ 0 + trait + phylo_unique(1 + x | sp),
  data = df_wide,
  family = gaussian()
)

# Long surface (canonical gllvmTMB long-format)
gllvmTMB(
  value ~ 0 + trait + phylo_unique(0 + trait + (0 + trait):x | sp),
  data = df_long,
  trait = "trait",
  family = gaussian()
)
```

**Byte-identity criteria** (tolerance 1e-6):

1. `logLik` identical to the unit.
2. `extract_Sigma(fit, level = "unit", part = "shared")`
   identical element-wise.
3. `VarCorr(fit)` per-group blocks identical for the structural
   term's covariance components: `σ²_intercept`, `σ²_slope`,
   `cov(intercept, slope)`.
4. Random-effect BLUPs identical for the species×{intercept,
   slope} expansion vs the trait-stacked {trait × {intercept,
   slope}} expansion (up to the wide-to-long reshape).

This contract is the **built-in correctness test** for every
Phase A recovery slice. A1 (the smallest viable parser-only
attempt; see §8) must include this byte-identity check as a
gating assertion.

## 4. Parser-spec changes

Per the 2026-05-26 Explore audit, the minimum-viable
parser-only change is localised. Exact line ranges follow.

### 4.1 `.assert_no_augmented_lhs()` guard

**File**: `R/brms-sugar.R:1543-1576`.

**Current behaviour** (audited 2026-05-26): the function
accepts only `1` (intercept-only) and `0 + trait`
(trait-stacked intercepts). It rejects all augmented LHS forms
with the error:

```
"Augmented LHS forms (intercept + slope, per-trait slopes,
uncorrelated `||`) require Design 07 Stage 3 engine work."
```

Call sites: `R/brms-sugar.R:2155` (`latent()` gate), `:2171`
(`unique()`), `:2359` (`indep()`), `:2439` (`dep()`).

**Required change** (Phase A1 contract): permit exactly two
additional augmented forms **when invoked from a structural
keyword context** (`phylo_*`, `animal_*`, `spatial_*`, or any
`*(vcv = A_user)` variant):

- **Pattern A** (wide): `1 + x` where `x` is a single named
  symbol referring to a column in `data`.
- **Pattern B** (long): `0 + trait + (0 + trait):x` where
  `trait` is the canonical trait symbol and `x` is a single
  named symbol.

All other augmented forms (per-trait `||`, multi-covariate `+ x + y`,
factor-by-numeric interactions beyond `(0 + trait):x`) stay
rejected with the unchanged error message.

**The guard remains live** for any non-structural context
(plain bar `(1 + x | g)` outside a structural keyword) — those
forms are blocked elsewhere and remain Stage 3 work.

### 4.2 `parse_covstruct_call()` insertion point

**File**: `R/parse-multi-formula.R:107-145`.

**Current behaviour**: returns
`list(kind = fn, lhs = cov_lhs, group = cov_group, extra = extra)`.
The `lhs` field carries the raw AST of the LHS expression.

**Required change** (Phase A1 contract): after line 122 (where
`cov_lhs` is assigned), classify the LHS into one of three
forms:

| LHS class | `extra$lhs_form` | `extra$slope_col` |
|---|---|---|
| `1` or `0 + trait` (intercept-only — existing) | `"intercept_only"` | `NULL` |
| `1 + x` (wide intercept+slope) | `"wide_intercept_slope"` | name of `x` |
| `0 + trait + (0 + trait):x` (long intercept+slope) | `"long_intercept_slope"` | name of `x` |
| anything else | (unchanged) | (rejected by guard) |

The return signature gains `extra$lhs_form` and
`extra$slope_col` fields; existing callers that read `extra`
ignore unknown fields, so the change is additive.

### 4.3 `parse_re_int_call()` non-interaction

**File**: `R/parse-multi-formula.R:156-175`.

This function handles bare-bar random intercepts `(1 | g)`
outside structural keywords. Its existing restrictions (rejects
random slopes via bar syntax) remain unchanged. The two new
LHS patterns are routed exclusively through
`parse_covstruct_call()` (§4.2), not through this function.

### 4.4 R-side TMB-data wrapper

**File**: `R/fit-multi.R`, primarily lines 680-700 (where
`X_fix` is built) and 1228-1234 + 1301 (current
`x_phy_slope` / `b_phy_slope` setup).

The Z matrix construction is the key R-side change. For a
structural keyword with `lhs_form == "wide_intercept_slope"`:

- Build a 2-column Z matrix per row: `Z = cbind(1, data[[slope_col]])`.
- The random-effect parameter `b_phy_slope` (currently a length-
  `n_aug_phy` scalar vector) becomes a `n_aug_phy × 2` matrix
  (column 0 = intercept, column 1 = slope).

For `lhs_form == "long_intercept_slope"`, the same trait-stacked
machinery already used by the intercept-only `(0 + trait | g)`
keywords expands to `(0 + trait + (0 + trait):x | g)` by
analogous reshape; the byte-identity contract §3 is the test.

### 4.5 TMB template

**File**: `src/gllvmTMB.cpp`, primarily lines 526-542 (prior)
and 701-704 (eta contribution).

Per the Explore audit, the existing scalar-slope block (single
`b * x` contribution per species) **cannot absorb** a 2-column
Z without template changes. The minimal extension:

- Promote `b_phy_slope` from `vector<Type>` (length
  `n_aug_phy`) to `matrix<Type>` (`n_aug_phy × n_lhs_cols`).
- Promote `x_phy_slope` from `vector<Type>` (length `n_obs`) to
  `matrix<Type>` (`n_obs × n_lhs_cols`).
- Replace the scalar `eta(o) += b * x` with the row-product
  `eta(o) += (b.row(species_aug_id(o)) * x_phy_slope.row(o).transpose())(0,0)`.
- Generalise the prior quadratic form: the matrix-normal prior
  `b_phy_slope ~ MN(0, Σ_b, A_phy)` factors cleanly across LHS
  columns when the off-diagonal `cov(intercept, slope)` is
  included in `Σ_b` (2 × 2 per structural family).

**Stage 3 escalation criterion** (Rose): if A1's parser-only
attempt (no template change yet) produces a fit that fails the
byte-identity contract §3 or the recovery test §5, the
template change above is required. That escalation triggers
the engine generalisation the codebase refers to as
"Design 07 Stage 3" (nine `n_traits` hardcoded sites in
`R/fit-multi.R` → `n_lhs_cols`); writing the actual numbered
design doc becomes part of the escalation. See §8.

## 5. Per-cell applicability matrix (Phase A — Gaussian)

20 cells = (4 structural families) × (5 keywords). Each cell
is one of: **APPLICABLE** (must have a passing recovery test),
**NOT APPLICABLE** (documented degenerate combination), or
**DEFERRED** (out of Phase A scope).

| Keyword \ family | `phylo_*` | `animal_*` (sugar) | `spatial_*` | `vcv = A_user` |
|---|---|---|---|---|
| `latent(LHS, d = K)` | **APPLICABLE** — random regression with factor-analytic between-individual structure on a tree | **APPLICABLE** (via Design 14 §5 sugar) | **APPLICABLE** — random regression with factor-analytic spatial structure | **APPLICABLE** |
| `unique(LHS)` | **APPLICABLE** — canonical structural-slope unit; primary A1 test case | **APPLICABLE** | **APPLICABLE** | **APPLICABLE** |
| `indep(LHS)` | **APPLICABLE** — trait-independent intercept+slope per group | **APPLICABLE** | **APPLICABLE** | **APPLICABLE** |
| `dep(LHS)` | **APPLICABLE** — fully-correlated structural intercept+slope | **APPLICABLE** | **APPLICABLE** | **APPLICABLE** |
| `scalar(LHS)` | **NOT APPLICABLE** — `phylo_scalar` carries a single variance component per group; an intercept+slope LHS would require a 2×2 covariance, contradicting the "scalar" semantics. Use `unique` or `dep` instead. | **NOT APPLICABLE** (same reasoning) | **NOT APPLICABLE** | **NOT APPLICABLE** |

**Net APPLICABLE cells**: 16 (= 4 keywords × 4 families).
`scalar` is "not applicable" by definition; documented here
once so future agents do not re-derive.

Each APPLICABLE cell requires:

- A recovery test on simulated Gaussian data with known truth
  for `σ²_intercept`, `σ²_slope`, and `cov(intercept, slope)`.
- The wide↔long byte-identity check per §3.
- A pkgdown render of the relevant article if the article uses
  the cell as a teaching example.

## 6. Soft-deprecation pathway

### 6.1 `phylo_slope(x | sp)`

Replaced by `phylo_unique(1 + x | sp)` (wide) or
`phylo_unique(0 + trait + (0 + trait):x | sp)` (long). The
soft-deprecation goes in `R/zzz-lifecycle.R` (or equivalent) via:

```r
phylo_slope <- function(formula, ...) {
  lifecycle::deprecate_soft(
    when = "0.3.0",
    what = "phylo_slope()",
    with = "phylo_unique(1 + x | sp)",
    details = c(
      "i" = "See `?phylo_unique` and Design 55 for the new syntax.",
      "i" = "`phylo_slope(x | sp)` will be removed after one minor version."
    )
  )
  # delegate to phylo_unique with constructed LHS
}
```

`phylo_slope()` remains exported for ≥ 1 minor version
(0.3.0 → 0.4.0) before removal. The deprecation message points
to Design 55 and the new keyword.

### 6.2 `animal_slope(x | id)`

Same pattern, replaced by `animal_unique(1 + x | id)` (wide) or
`animal_unique(0 + trait + (0 + trait):x | id)` (long). Per
Design 14 §5 byte-equivalence, the implementation delegates
through `phylo_unique(vcv = pedigree_to_A(ped))`.

### 6.3 `spatial_slope`

Does **not** exist as a top-level keyword and **is not added**.
Spatial random slopes are expressed via `spatial_unique(1 + x | id)`
or equivalent from the outset.

### 6.4 Article updates (Phase A6 deprecation slice)

Per the 2026-05-26 user-facing audit, six articles reference
the deprecated keywords. Each needs a one-paragraph update in
Phase A6 (deprecation slice). Order of articles and the kind of
update each needs:

| Article | Current reference | Update needed |
|---|---|---|
| `api-keyword-grid.Rmd` (lines 50, 278, 282) | `phylo_slope(x \| species)`, `animal_slope(x \| id)` as named keywords | Move to "soft-deprecated 0.3.0; see Design 55" row; redirect to new keyword form |
| `animal-model.Rmd` (line 438) | `animal_slope(x \| id)` as reaction-norm pattern | Show the new `animal_unique(1 + x \| id)` syntax; keep the reaction-norm narrative |
| `phylogenetic-gllvm.Rmd` (line 418) | Reference link to `phylo_slope` | Update link target to `phylo_unique(1 + x \| sp)` example |
| `gllvm-vocabulary.Rmd` (line 250) | `animal_slope(x \| individual, pedigree = ped)` | Update to new syntax + brief migration note |
| `choose-your-model.Rmd` (line 205) | `animal_slope(x \| individual)` cross-ref | Update to new syntax; cross-link to Design 55 |
| `data-shape-flowchart.Rmd` (line 168) | Generic `animal_slope` reference | Update to new syntax |

`lambda-constraint`, `joint-sdm`, `behavioural-syndromes`,
`morphometrics`, `functional-biogeography`, `stacked-trait-gllvm`,
`mixed-family-extractors` carry no `phylo_slope` / `animal_slope`
references and need no migration.

## 7. Reserved for later (out of Phase A scope)

These are intentionally deferred. Future agents should not
silently add them.

### 7.1 Slope-only LHS

Forms `(0 + x | id)` (wide) and `((0 + trait):x | id)` (long)
— random slope on `x` with **no random intercept** per group.
Useful when intercept variation is captured by a separate term
(e.g. `phylo_latent(0 + trait | sp) + phylo_unique((0 + trait):x | sp)`).

**Why deferred**: the user-facing question — "do I want a
random intercept AND slope, or just a slope?" — is real but
not yet a common request. The parser change to support slope-only
is a one-day extension of the A1 parser change. Decision: add
when a concrete user request arrives.

### 7.2 Two-or-more random slopes (s ≥ 2)

Validation-debt **RE-03** stays `blocked`. The current parser
will continue to reject `(1 + x + y | id)` and analogous
multi-covariate slope forms with the existing Stage 3 redirect.

### 7.3 Per-trait slope correlations

The trait-stacked LHS `(0 + trait + (0 + trait):x | id)` admits
a default covariance structure where intercepts and slopes
share a 2 × 2 covariance matrix per trait — and a fully
unstructured `2T × 2T` covariance is in scope only for the
`dep` keyword. Users wanting an arbitrary trait-by-slope
covariance specification are out of scope; the per-cell
applicability matrix §5 maps each keyword's covariance
structure to its standard meaning.

## 8. Stop conditions for A1 (the smallest-viable parser-only test)

A1 attempts `phylo_unique(1 + x | sp)` Gaussian recovery with
**parser-only** changes (per §4.1–§4.4; no TMB template change
yet). The test fixture follows the pattern of
`tests/testthat/test-phylo-slope.R`: simulate from a known DGP
on a fixed phylogeny, fit, recover `σ²_intercept`,
`σ²_slope`, `cov(intercept, slope)`. The byte-identity check §3
must also pass.

**Pass criterion**: recovery test passes within tolerance AND
byte-identity check passes. Proceed to A2.

**Fail criterion**: either the recovery test fails (estimated
variances biased or unidentified) OR the byte-identity check
fails (wide and long surfaces disagree). Per Rose: do not
proceed to A2; close A1 with a documented failure memo in
`docs/dev-log/audits/2026-MM-DD-design-55-a1-failure.md`
naming the specific assertions that failed and the most likely
cause (TMB template needs Stage 3 generalisation per §4.5).

**Escalation path**: if A1 fails, open a Stage 3 engine-work
design slice — that's the moment the planned-but-unwritten
"Design 07" actually gets written, as the parent design for
generalising `n_traits` to `n_lhs_cols` in the TMB template.
Lead: Boole + Gauss + Noether + maintainer. Resume Phase A
only after the Stage 3 work merges. Phase B remains blocked
behind Phase A close in either path.

## 9. Notation conventions

Per the 2026-05-26 user-facing audit, articles already use a
consistent set of conventions for slope examples:

- **Slope covariate name**: `x` for the generic teaching
  example; `env` / `env_1` / `env_2` for environmental
  applications (functional biogeography, joint SDM, spatial).
- **Group variable name**: `id` for pedigree contexts (animal
  models, repeatability), `species` or `sp` for phylogeny,
  `coords` for spatial, `site` for site-level random effects.
- **Trait specification**: `0 + trait` always in long form;
  `(0 + trait):x` for slopes (fixed or random); `(0 + trait | g)`
  for random structure.
- **Introductory prose style**: biology-first — name the
  biological concept (reaction norm / heritable slope /
  species-specific plasticity), then introduce the formula.

Design 55 examples adopt these conventions. New articles
introduced as part of the Phase A6 deprecation slice follow the
same style.

## 10. Cross-references

- [`docs/design/04-random-effects.md`](04-random-effects.md) —
  4 × 5 keyword grid; Items 11 / 12 reserve / plan random
  slopes inside structural keywords; M1 caps at `s = 1`.
- **"Design 07" (planned, not yet written)** — the conventional
  shorthand for the augmented-LHS Stage 3 engine-generalisation
  design. Current canonical artefacts (referenced by the guard
  error message): `R/brms-sugar.R:1543-1576` (the fail-loud
  guard implementation; the `cli::cli_abort` pattern Design 55
  reuses at §4.1); `tests/testthat/test-augmented-lhs-guard.R`
  (the guard test). The numbered doc itself becomes a written
  artefact only when the Stage 3 work starts (per §8 escalation
  path).
- [`docs/design/14-known-relatedness-keywords.md`](14-known-relatedness-keywords.md)
  — §5 `animal_*` ↔ `phylo_*(vcv = A)` byte-equivalence; §8
  "no engine work" for the animal family.
- [`docs/design/35-validation-debt-register.md`](35-validation-debt-register.md)
  — rows **RE-02** (`partial`), **RE-03** (`blocked`), **FG-15**
  (`partial`), **PHY-06** (`partial`), **ANI-06** (`partial`);
  status-change rule §"How the register is maintained" point
  4 (no `covered` without test evidence).
- [`docs/dev-log/audits/2026-05-25-day-retrospective.md`](../dev-log/audits/2026-05-25-day-retrospective.md)
  — coordination context (Design 50 §9 status-change rule,
  worktree discipline, persona-active naming) carried forward
  to this design's review cycle.

## 11. Documentation and tracker actions

Every Phase A slice must update:

- this design when its contract changes;
- after-task report referencing the relevant validation-debt
  rows;
- a Rose pre-publish audit before merge;
- the validation-debt register only when test evidence actually
  changes a row's status (Design 50 §9 carry-over rule);
- the coord-board file-ownership table when starting and
  closing a slice.

Phase A close (A7) gates:

1. 3-OS CI green on merged state.
2. Recovery test passes for every APPLICABLE cell in §5.
3. Byte-identity contract §3 passes on at least one
   representative cell per structural family.
4. `phylo_slope()` and `animal_slope()` soft-deprecated per
   §6.1 / §6.2.
5. Six articles in §6.4 updated to new syntax.
6. Validation-debt rows RE-02 / FG-15 / PHY-06 / ANI-06 walked
   to `covered (Gaussian)` with evidence paths.
7. `pkgdown::check_pkgdown()` clean.

Until Phase A closes, RE-02 / FG-15 / PHY-06 / ANI-06 stay
`partial`; RE-03 stays `blocked`.

— Boole (parser-spec § 4), Noether (math contract § 3 + § 4.5),
Gauss (TMB engine § 4.5 + § 8 escalation), Rose (scope honesty
§ 1 + § 7 + § 8 stop conditions), Shannon (drafting + cross-team
context § 10).
