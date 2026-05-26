# Design 56 — Augmented-LHS engine generalisation (Stage 3)

**Maintained by:** Boole (parser-spec), Gauss (TMB template),
Noether (math-vs-implementation alignment), Curie (simulation +
recovery tests), Rose (scope honesty), Shannon (cross-team
coordination).
**Lead authors:** maintainer (Ada) + Boole + Gauss + Noether.
**Composed by:** Claude/Shannon under maintainer authorisation
2026-05-26 (full authorisation following Design 55 §A1 closeout
in PR #279).
**Status:** Active design contract. Stub opened 2026-05-26 by
Design 55 §A1 closeout; expanded into the full design the same
day after maintainer go-ahead.
**Triggered by:**
[Design 55 §A1 closeout memo](../dev-log/audits/2026-05-26-design-55-a1-closeout.md) —
parser-only hypothesis structurally disconfirmed by code review.
**Backed by:**
[Design 55 §4-§8](55-structural-slope-grammar.md) (the parent
design specifying the grammar this engine work serves), the
2026-05-26 Explore audit transcripts on parser + engine state,
the Sokal 2026-05-09 silent-collapse empirical confirmation
documented at `R/brms-sugar.R:1530-1542`.

## 1. Purpose

Generalise the gllvmTMB TMB template and R-side wrapper so that
augmented LHS patterns (currently just intercept + slope —
`(1 + x | id)` wide / `(0 + trait + (0 + trait):x | id)` long)
flow correctly through the engine for every structural
random-effect block (phylo / animal / spatial / user-supplied
A). The current state of affairs is that the parser already
*rejects* these forms with a fail-loud `Design 07 Stage 3`
redirect; the silent-collapse bug Sokal documented in
2026-05-09 means the *naïve* fix (loosen the parser without
extending the engine) would produce silently-wrong fits, which
is worse than the current explicit rejection.

This design specifies:

- the **parameter-shape promotion** for each structural
  random-effect block (vector → matrix, with explicit
  `n_lhs_cols` dimension);
- the audit + edit of every hardcoded `n_traits` site in
  `R/fit-multi.R` that would silently truncate augmented LHS;
- the **2×2 (intercept, slope) covariance** parameterisation
  and the cross-family invariants it must respect;
- the fail-loud / silent-collapse boundary that every PR in
  this lane must respect;
- the migration of the deprecated `phylo_slope()` /
  `animal_slope()` keywords into the new general path;
- the implementation phases (56.1–56.6) that take the work
  from this design to Phase A unblock.

## 2. Scope

In scope:
- **Engine work for `n_lhs_cols ∈ {1, 2}` only**: intercept-only
  (the current state, `n_lhs_cols = T`) and intercept + slope
  on a single covariate (the new state, `n_lhs_cols = 2T` per
  Design 55 §3 wide↔long contract).
- All four structural families (phylo / animal / spatial /
  user-supplied A) and the keyword subset Design 55 §5 marks
  APPLICABLE (16 cells = 4 keywords × 4 families;
  `scalar` × any family stays NOT APPLICABLE).
- Gaussian first (Phase A). Non-Gaussian (Phase B) inherits the
  engine state once Phase A closes.
- Soft-deprecation of `phylo_slope()` and `animal_slope()`
  driven by Phase 56.6 register-update slice.

Out of scope (reserved):
- **`s ≥ 2` random slopes** (validation-debt **RE-03** =
  `blocked`). The matrix promotion path described below
  generalises to `n_lhs_cols > 2` naturally, but the parser
  guard stays strict against the multi-covariate forms in this
  design.
- **Slope-only LHS** `(0 + x | id)`. Design 55 §7.1 says
  *"add when a concrete user request arrives"*. The parser
  change to permit `(0 + x | id)` is a single-day extension
  once Phase 56.3 lands; not in this design.
- **Non-default covariance structures within `(1 + x | id)`**.
  The intercept-slope correlation parameterisation in §2.3 is
  the only supported form per Design 55 §7.3.

## 3. Parameter-shape generalisation

### 3.1 The b_phy_* block

The current `phylo_slope` block in `src/gllvmTMB.cpp:526-542`
declares:

```cpp
PARAMETER(log_sigma_slope);
PARAMETER_VECTOR(b_phy_slope);  // length n_aug_phy
DATA_VECTOR(x_phy_slope);       // length n_obs (single covariate)
```

The contribution at `src/gllvmTMB.cpp:701-704` is a scalar
product:

```cpp
eta(o) += b_phy_slope(species_aug_id(o)) * x_phy_slope(o);
```

**New shape (Phase 56.1)**:

```cpp
DATA_INTEGER(n_lhs_cols);        // 1 (intercept-only) or 2 (intercept + slope)
PARAMETER_MATRIX(log_sd_b);      // n_lhs_cols × n_aug_phy_blocks
PARAMETER_VECTOR(atanh_cor_b);   // length n_aug_phy_blocks (one ρ per block when n_lhs_cols=2)
PARAMETER_ARRAY(b_phy_aug);      // n_aug_phy × n_lhs_cols × n_aug_phy_blocks
DATA_ARRAY(Z_phy_aug);           // n_obs × n_lhs_cols × n_aug_phy_blocks (column 0 = 1's; column 1 = x covariate)
```

The contribution loop:

```cpp
for (int o = 0; o < n_obs; o++) {
  for (int k = 0; k < n_aug_phy_blocks; k++) {
    int sp_id = species_aug_id(o, k);
    if (sp_id < 0) continue;  // skip if block doesn't apply to this row
    Type contrib = 0;
    for (int j = 0; j < n_lhs_cols; j++) {
      contrib += b_phy_aug(sp_id, j, k) * Z_phy_aug(o, j, k);
    }
    eta(o) += contrib;
  }
}
```

### 3.2 Analogous promotions

The same matrix promotion applies to every structural block
that may absorb augmented LHS:

| Current block | New shape | Sites changed |
|---|---|---|
| `b_phy_slope` (vector) | `b_phy_aug` (3D array) | `src/gllvmTMB.cpp:186-195, 526-542, 701-704` |
| `b_phy_diag` (vector × n_traits) | `b_phy_aug` (3D array, `n_lhs_cols = T × 2` for trait-stacked + slope-stacked) | `src/gllvmTMB.cpp` phylo_diag block |
| `b_spde_*` for spatial keywords | analogous 3D array | `src/gllvmTMB.cpp` spde block |
| `b_animal_*` (sugar over phylo) | inherits phylo block automatically | n/a, no engine code (Design 14 §8) |
| `b_phy_rr` (matrix `n_aug × d`) | unchanged shape; augmented LHS treated as extra `d` columns conceptually but routed through the new `b_phy_aug` path instead | `src/gllvmTMB.cpp:456-494` |

**Backward compatibility**: when `n_lhs_cols == 1`, the matrix
operations degenerate cleanly to the current vector behaviour.
The new `b_phy_aug` block subsumes the current `b_phy_slope`
block.

## 4. The `n_traits` → `n_lhs_cols` audit

Per the long-standing audit referenced in
`R/brms-sugar.R:1530-1536` ("Sokal's empirical confirmation,
2026-05-09 gating verification, commit 7e90f036"), there are
**nine hardcoded `n_traits` sites in `R/fit-multi.R`** that
silently truncate when the formula carries an augmented LHS.

Phase 56.2 enumerates and edits each:

| Site (approximate line) | Current literal | Phase 56.2 edit |
|---|---|---|
| `R/fit-multi.R:~1150` (sizing of `theta_rr_phy`) | `n_traits` | `n_lhs_cols` |
| `R/fit-multi.R:~1152` (Lambda_phy shape) | `n_traits` | `n_lhs_cols` |
| `R/fit-multi.R:~1154` (b_phy_rr sizing) | `n_traits` | `n_lhs_cols` |
| `R/fit-multi.R:~1173` (phylo_diag random-effect block) | `n_traits` | `n_lhs_cols` |
| `R/fit-multi.R:~1180` (DATA_ARRAY assembly) | `n_traits` | `n_lhs_cols` |
| `R/fit-multi.R:~1185` (Cphy / Ainv block sizing) | `n_traits` | `n_lhs_cols` (some sites stay `n_traits` if they index trait-specific variance; document per-site) |
| `R/fit-multi.R:~1187` (Lambda inflation guard) | `n_traits` | `n_lhs_cols` |
| `R/fit-multi.R:~1227-1234` (b_phy_slope init) | `n_traits` | replaced by `b_phy_aug` init using `n_lhs_cols` |
| `R/fit-multi.R:~1301` (b_phy_slope dim check) | `n_traits` | replaced by `b_phy_aug` |

Site-by-site decisions (whether to keep `n_traits` or promote
to `n_lhs_cols`) must be documented in the Phase 56.2 PR's
after-task report. Some sites correctly index per-trait
quantities (e.g. trait-specific variance components) and stay
as `n_traits`; others index "columns of the random-effect
design matrix" and become `n_lhs_cols`.

## 5. The 2×2 (intercept, slope) covariance parameterisation

### 5.1 The bivariate prior

For each structural family + keyword admitted by Design 55 §5
APPLICABLE matrix, the augmented random-effect block has a
2×2 covariance per group:

$$
\boldsymbol{\Sigma}_b = \begin{pmatrix}
\sigma^2_\alpha & \rho \sigma_\alpha \sigma_\beta \\
\rho \sigma_\alpha \sigma_\beta & \sigma^2_\beta
\end{pmatrix}
$$

where $\sigma^2_\alpha$ is the intercept variance,
$\sigma^2_\beta$ is the slope variance, and $\rho \in [-1, 1]$
is the intercept-slope correlation.

The full prior for the species-by-LHS-column random effect
matrix $\mathbf{B} \in \mathbb{R}^{n_{\text{sp}} \times 2}$ is
matrix-normal:

$$
\text{vec}(\mathbf{B}) \sim \mathcal{N}_{2 n_{\text{sp}}}\big(\mathbf{0},\ \boldsymbol{\Sigma}_b \otimes \mathbf{A}_{\text{phy}}\big)
$$

This is the standard random-regression / reaction-norm prior
(Henderson, Lynch & Walsh, drmTMB's `(1 + x | id)` Gaussian
default). The structural matrix $\mathbf{A}_{\text{phy}}$ is
the relatedness matrix (pedigree-A, tree-VCV, SPDE precision,
or user-supplied — Design 14 §5 byte-equivalence).

### 5.2 Parameterisation in TMB

Three new parameters per applicable block:

```cpp
PARAMETER(log_sd_b_intercept);  // log σ_α
PARAMETER(log_sd_b_slope);      // log σ_β
PARAMETER(atanh_cor_b);          // atanh(ρ); ρ = tanh(atanh_cor_b)
```

Reconstruction in C++:

```cpp
Type sd_int = exp(log_sd_b_intercept);
Type sd_slp = exp(log_sd_b_slope);
Type cor    = tanh(atanh_cor_b);
matrix<Type> Sigma_b(2, 2);
Sigma_b(0, 0) = sd_int * sd_int;
Sigma_b(1, 1) = sd_slp * sd_slp;
Sigma_b(0, 1) = sd_int * sd_slp * cor;
Sigma_b(1, 0) = Sigma_b(0, 1);
```

The negative-log-density contribution uses TMB's
`MVNORM_t<Type>` machinery with the Kronecker product:

```cpp
// log density of vec(B) ~ N(0, Sigma_b ⊗ A_phy)
matrix<Type> B_mat = b_phy_aug.col(k);  // n_aug_phy × 2
matrix<Type> Sigma_inv = atomic::matinv(Sigma_b);
matrix<Type> BMatA = B_mat.transpose() * Ainv_phy * B_mat;  // 2 × 2
Type quad = (Sigma_inv * BMatA).trace();
Type ldet = n_aug_phy * log(Sigma_b.determinant()) + 2 * Ainv_phy_logdet;
nll -= -0.5 * quad - 0.5 * ldet - 0.5 * 2 * n_aug_phy * log(2*M_PI);
```

The Kronecker trick (computing $\text{tr}(\boldsymbol{\Sigma}_b^{-1} \mathbf{B}^\top \mathbf{A}^{-1} \mathbf{B})$
instead of the full $2n_{\text{sp}} \times 2n_{\text{sp}}$
inverse) keeps the cost linear in $n_{\text{sp}}$ and avoids a
prohibitive $O((2n_{\text{sp}})^3)$ matrix inverse.

### 5.3 Per-keyword variants

| Keyword | Σ_b shape | Σ_b parameters |
|---|---|---|
| `latent(LHS, d = K)` | block-diagonal across LHS columns (each column gets its own factor-analytic decomposition Lambda_k Lambda_k^T + diag) | `theta_rr_lhs[k]` per LHS column; `log_psi_lhs[k]` per LHS column |
| `unique(LHS)` | full 2×2 (intercept-slope correlation estimated) | `log_sd_b_intercept`, `log_sd_b_slope`, `atanh_cor_b` |
| `indep(LHS)` | diagonal (ρ = 0 fixed; no intercept-slope correlation) | `log_sd_b_intercept`, `log_sd_b_slope` (cor_b mapped to 0) |
| `dep(LHS)` | full unstructured 2T × 2T per group (the unrestricted form) | Cholesky-decomposed Σ_b parameterisation per Design 55 §7.3 reservation |
| `scalar(LHS)` | NOT APPLICABLE per Design 55 §5 | n/a |

**Identifiability constraints (Phase 56.1.1)**:

- For `unique`: when the data on one of {α, β} is sparse
  (e.g. fewer than ~20 unique `id` levels per LHS column), the
  estimated `ρ` may sit near ±1. The TMB optimizer handles
  this via the `atanh` reparameterisation, but the recovery
  test must check finite gradient and sane SE.
- For `indep`: the `ρ = 0` constraint is *map*-pinned in TMB
  (the `atanh_cor_b` parameter is mapped to NA). The optimizer
  ignores it; the prior is diagonal.
- For `dep`: the full $2T \times 2T$ Cholesky uses TMB's
  `UNSTRUCTURED_CORR` machinery applied to the LHS-stacked
  parameter vector.

## 6. Cross-family generalisation (Phase B preparation)

Per Agent 2's 2026-05-26 Explore audit, the TMB template's
structural-block priors are **family-agnostic at the prior
level**. The family enters only at the response-likelihood
node, *after* the linear predictor `eta` has accumulated all
random-effect contributions. The link-residual machinery at
`R/extract-sigma.R:99-280` (`link_residual_per_trait()`) is
**post-hoc** — it computes the latent-scale residual variance
for `extract_Sigma()` reporting, not as part of the fit
itself.

Implication: once Phase 56.1–56.4 lands the engine state for
Gaussian, non-Gaussian families inherit the new path
automatically. Phase B0 (scoping audit) is the empirical
verification that the inheritance is clean; B1–B4 are the
per-family recovery tests on validated Phase A cells.

Edge cases the B0 scoping audit must address (per Design 55
§B0):

- **Spatial × ordinal-probit at d=3**: identification check.
- **Animal × binomial with trait-stacked slopes**: small-pedigree
  over-parameterisation check.
- **NB2 ψ↔φ trade-off** (per Design 42 binomial-`psi` rule): if
  the slope LHS interacts with the family's overdispersion
  parameter, document.

## 7. The fail-loud / silent-collapse boundary

This design **must enforce** the invariant that the Sokal
2026-05-09 anti-pattern cannot recur:

> No PR that loosens the `.assert_no_augmented_lhs()` guard at
> `R/brms-sugar.R:1543-1576` may merge unless the engine block
> it routes the new LHS forms through already understands
> `n_lhs_cols > T` (or `n_lhs_cols ≥ 2 × n_keyword_terms`).

Concretely:

1. **PR-review checklist** (added by Phase 56.3): the parser
   change PR description must cite the specific engine block
   (line range in `src/gllvmTMB.cpp`) and the corresponding
   `R/fit-multi.R` site that has been updated *first*.
2. **Run-time assertion** (added by Phase 56.1): the TMB
   template asserts `n_lhs_cols == Z_phy_aug.cols()` at the
   start of the augmented block; mismatch is a `Rcpp::stop()`
   not a silent truncation.
3. **Test coverage** (added by Phase 56.4 onwards): every
   recovery test for an APPLICABLE Phase A cell includes a
   *negative test* — fit the same data with the augmented LHS
   forced to truncate (e.g. by passing `n_lhs_cols = 1` while
   the formula carries `(1 + x | id)`) and assert the engine
   `Rcpp::stop()`s.

## 8. Migration of `phylo_slope()` and `animal_slope()`

Per Design 55 §6.1 and §6.2:

- The existing `phylo_slope(x | sp)` engine path becomes a
  **special case** of the new `b_phy_aug` block: it's
  equivalent to `phylo_unique((0 + x) | sp)` in the long
  format (intercept-omitted, slope-only LHS) — *except* that
  the slope-only LHS pattern is reserved for later per Design
  55 §7.1. To preserve backward compatibility without exposing
  the reserved syntax to users, `phylo_slope(x | sp)`
  internally rewrites to `phylo_unique((0 + 0 + x) | sp)` (the
  literal "no-intercept" form recognised by the parser as
  slope-only, but invoked through the deprecated keyword
  alias). Or, more cleanly: `phylo_slope(x | sp)` is
  rewritten by the parser into the new engine path with a
  `Z_phy_aug` matrix that has only the slope column —
  `n_lhs_cols = 1`, equivalent to the current scalar-slope
  semantics.
- `animal_slope(x | id)` continues to be sugar over
  `phylo_slope(x | id, vcv = pedigree_to_A(ped))` per Design
  14 §5 byte-equivalence; the migration path is automatic.
- Phase 56.6 emits the `lifecycle::deprecate_soft()` warnings
  on first use of each.

**Backward compatibility test**: a `phylo_slope(x | sp)` fit
on the existing `test-phylo-slope.R` fixture must produce
byte-identical results before and after Phase 56.1–56.6 lands
(logLik to 1e-6, σ² recovery within Monte Carlo noise). This
is Phase 56.5's first deliverable.

## 9. Implementation phases

Sketched chronologically. Each phase is one PR slice; the
sequence is sequential (no parallelisation across phases) until
56.4 onward.

### 9.1 Phase 56.1 — TMB template promotion (engine PR)

- Promote `b_phy_slope` → `b_phy_aug` (3D array per §3.1).
- Add `DATA_INTEGER(n_lhs_cols)` to the template; thread
  through every block that touches structural random effects.
- Add the 2×2 covariance parameterisation per §5.2.
- Add the runtime assertion per §7.2.
- Behind a `use_phylo_slope_correlated` data-flag default
  `FALSE`; existing fits route through the legacy path when
  `n_lhs_cols == 1`.
- **No R-side or parser change in this PR**. The template
  compiles and links; existing tests pass byte-identically.

**Lead**: Gauss + Boole. **Reviewers**: Noether + maintainer.
**~3-5 days**.

### 9.2 Phase 56.2 — `n_traits` → `n_lhs_cols` audit edit (R-side PR)

- Per-site audit of the nine sites in `R/fit-multi.R` (§4 table).
- Edit each to use `n_lhs_cols` where it indexes RE design
  columns; keep `n_traits` where it indexes per-trait
  quantities.
- Add `n_lhs_cols` to the TMB data list (default = `n_traits`
  for backward compatibility; set to `2 * n_traits` when
  augmented LHS is detected).
- **Existing tests pass byte-identically**.

**Lead**: Boole + Gauss. **Reviewers**: Noether + Rose.
**~2-3 days**.

### 9.3 Phase 56.3 — parser changes from Design 55 §4 (parser PR)

- Modify `.assert_no_augmented_lhs()` at
  `R/brms-sugar.R:1543-1576` to permit `1 + x` LHS within
  phylo_* keywords (§4.1 of Design 55).
- Extend `parse_covstruct_call()` at
  `R/parse-multi-formula.R:107-145` to classify LHS form into
  `intercept_only` / `wide_intercept_slope` /
  `long_intercept_slope` (§4.2 of Design 55).
- Extend `phylo_unique` rewrite at
  `R/brms-sugar.R:2317-2325` to accept bar form (currently
  only bare species).
- Build the augmented Z matrix in `R/fit-multi.R` and pass it
  to TMB as `Z_phy_aug` (§4.4 of Design 55).
- **The PR-review checklist invariant (§7.1) is enforced here**:
  this PR's description cites the engine block (`src/gllvmTMB.cpp`
  line range from Phase 56.1) and `R/fit-multi.R` site from
  Phase 56.2 that have been updated to handle augmented LHS.

**Lead**: Boole + Gauss. **Reviewers**: Noether + Rose +
maintainer. **~2-3 days**.

### 9.4 Phase 56.4 — recovery test for `phylo_unique(1 + x | sp)` Gaussian

- The test Design 55 §A1 originally specified, now runs
  against the new engine.
- **NEW**: `tests/testthat/test-phylo-unique-slope-gaussian.R`,
  mirroring `tests/testthat/test-phylo-slope.R` structure.
- Recovery targets: `σ²_intercept`, `σ²_slope`,
  `cov(intercept, slope)` on simulated phylo data with known
  truth (Hadfield A⁻¹).
- **Byte-identity check**: same fixture in wide-format
  `(1 + x | id)` and long-format `(0 + trait + (0 + trait):x | id)`
  produces identical logLik + identical Σ to 1e-6.
- **Negative test** (§7.3 invariant): force `n_lhs_cols = 1`
  while the formula carries `(1 + x | id)`; assert
  `Rcpp::stop()`.

**Lead**: Curie + Boole. **Reviewers**: Fisher + Rose + Noether.
**~2-3 days**.

### 9.5 Phase 56.5 — extend to remaining Design 55 §5 APPLICABLE cells

After 56.4 passes, walk the Design 55 §5 APPLICABLE matrix one
keyword at a time:

- 56.5a: `phylo_latent(1 + x | sp, d = K)` recovery + byte-identity
- 56.5b: `phylo_indep(1 + x | sp)` recovery (diagonal Σ_b; no cov term)
- 56.5c: `phylo_dep(1 + x | sp)` recovery (full 2T × 2T)
- 56.5d: animal_* family (mostly tests; byte-equiv via Design 14 §5)
- 56.5e: spatial_* family (verify SPDE precision composes)
- 56.5f: user-supplied A (relmat) family
- Backward-compat byte-identity for `phylo_slope(x | sp)` per §8.

Each sub-phase is its own PR.

**Lead per sub-phase**: Boole + Curie (parser/test), Gauss
(engine verification per cell). **Reviewers**: Noether + Rose.
**~3-5 days total**.

### 9.6 Phase 56.6 — soft-deprecation + register update

Per Design 55 §A6:

- Soft-deprecate `phylo_slope()` and `animal_slope()` via
  `lifecycle::deprecate_soft()`.
- Update the six articles per Design 55 §6.4 user-facing audit:
  `api-keyword-grid`, `animal-model`, `phylogenetic-gllvm`,
  `gllvm-vocabulary`, `choose-your-model`,
  `data-shape-flowchart`.
- `NEWS.md` entry.
- Walk validation-debt rows **RE-02**, **FG-15**, **PHY-06**,
  **ANI-06** and add a new **SPA-slope** row, all to `covered`
  for Gaussian with evidence paths.
- Phase A close per Design 55 §A7.

**Lead**: Emmy + Rose + Shannon. **Reviewers**: maintainer.
**~1-2 days**.

## 10. Verification

### 10.1 Per-phase close gates

| Phase | Close gate |
|---|---|
| 56.1 | TMB template compiles + links; existing tests pass byte-identically |
| 56.2 | All 9 `n_traits` sites audited and edited; existing tests pass byte-identically |
| 56.3 | Parser permits new LHS forms; `Z_phy_aug` correctly built; PR-review checklist enforced (§7.1) |
| 56.4 | Recovery test passes for `phylo_unique(1+x|sp)` Gaussian; byte-identity wide↔long; negative test passes |
| 56.5 (each sub-phase) | Per-cell recovery test passes; byte-identity check passes |
| 56.6 | Soft-deprecation live; articles updated; validation-debt register reflects merged state |

### 10.2 Stage 3 overall close (= Design 55 Phase A close)

All hold:

1. 3-OS CI green on merged state across all six sub-phases.
2. Recovery test passes for every APPLICABLE cell in Design
   55 §5 matrix (16 cells: 4 keywords × 4 structural families,
   Gaussian).
3. Byte-identity contract (Design 55 §3) passes on at least one
   representative cell per structural family.
4. `phylo_slope()` and `animal_slope()` soft-deprecated.
5. Six articles updated per Design 55 §6.4.
6. Validation-debt rows walked to `covered (Gaussian)`.
7. `pkgdown::check_pkgdown()` clean.

### 10.3 Per-PR verification (every slice)

- `devtools::install(quick = TRUE)` builds the modified template.
- `devtools::test(filter = "<slice keyword>")` passes locally.
- `devtools::check()` clean (no R CMD check warnings).
- `pkgdown::check_pkgdown()` clean.
- Rose pre-publish audit.
- After-task report referencing register rows.

## 11. Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| `b_phy_aug` 3D array shape introduces TMB autodiff complications (some `ARRAY` shapes have edge cases on Windows) | Medium | Phase 56.1 runs `devtools::check()` on all 3 OSes before merge; document any platform-specific quirks |
| 2×2 covariance ρ estimate sits near ±1 in finite-sample fits (identifiability borderline) | Medium-high | Phase 56.4 test fixture includes both well-identified and borderline cases; document SE behaviour |
| Existing `phylo_slope` tests fail byte-identity after migration | Low (current path is a special case of new path) | Phase 56.5 backward-compat test gates the rest of 56.5; if byte-identity fails, fix before continuing |
| `n_traits` audit misses a site (silent truncation persists) | Medium | Phase 56.4's *negative test* (§7.3) — fit with wrong `n_lhs_cols` and assert `Rcpp::stop()` — exposes any missed site |
| Cross-family inheritance (Phase B) reveals identifiability issues per cell | Medium | Phase B0 scoping audit (Design 55) is the gate; B1-B4 may flag some cells `blocked` per family |
| Multi-week calendar slip during Stage 3 implementation | High | Each phase 56.N is its own PR; partial completion is acceptable and tracked in the register |

## 12. Effort + calendar

Per phase per §9:

| Phase | Days |
|---|---|
| 56.1 (TMB template) | 3-5 |
| 56.2 (R-side audit edit) | 2-3 |
| 56.3 (parser) | 2-3 |
| 56.4 (recovery test) | 2-3 |
| 56.5 (six sub-phases) | 3-5 |
| 56.6 (deprecation + register) | 1-2 |
| **Total** | **13-21 days** |

Realistic calendar: **2-3 weeks of focused work** from
authorisation to Design 55 Phase A close. Plus Phase B
(Design 55) is another ~17-25 days per the parent plan.

## 13. What this design does NOT cover

- Slope-only LHS `(0 + x | id)` — Design 55 §7.1 reservation.
- `s ≥ 2` random slopes — RE-03 stays `blocked`.
- Non-Gaussian families — Design 55 Phase B work, inheriting
  this engine state.
- Articles authoring (only the deprecation-driven updates per
  §9.6).
- `coverage_study()` at R = 200 — Phase B's B5 work.

## 14. Cross-references

- [Design 55 — Structural-dependence × random-slope grammar
  (Phase A0)](55-structural-slope-grammar.md) — parent design.
- [Design 55 §A1 closeout memo](../dev-log/audits/2026-05-26-design-55-a1-closeout.md)
  — empirical case for why this work exists.
- `R/brms-sugar.R:1530-1576` — `.assert_no_augmented_lhs()`
  guard + Sokal silent-collapse documentation; the error
  message that has been referring to "Design 07 Stage 3" all
  along now points here.
- `R/brms-sugar.R:2317-2325` — `phylo_unique` bare-name
  rewrite path (must be extended in Phase 56.3 to accept bar
  form).
- `R/parse-multi-formula.R:107-145` — `parse_covstruct_call()`
  (Phase 56.3 extends to classify LHS form).
- `R/fit-multi.R:1150-1301` — the nine `n_traits` audit sites
  (Phase 56.2 edits each).
- `src/gllvmTMB.cpp:186-195, 456-494, 496-524, 526-542,
  701-704` — phylo + spde + slope blocks; Phase 56.1 promotes
  the slope block.
- [Design 14 — Known-relatedness keywords](14-known-relatedness-keywords.md)
  §5 — animal_* sugar contract that this engine work
  preserves automatically.
- [Design 35 — Validation-debt register](35-validation-debt-register.md)
  rows **RE-02**, **RE-03**, **FG-15**, **PHY-06**, **ANI-06**
  — blocked behind this design.
- `tests/testthat/test-augmented-lhs-guard.R` — the existing
  guard test; Phase 56.3 extends it to cover the new
  permitted forms.
- `tests/testthat/test-phylo-slope.R` — backward-compat byte-
  identity gate per §8.
- [Design 04 — Random effects](04-random-effects.md) §"Items
  11/12" — the original `reserved` / `planned` status that
  this design moves to `in progress`.
- [Design 42 — M3 DGP grid](42-m3-dgp-grid.md) — binomial-`psi`
  rule that Phase B must respect.

— Boole (parser-spec §3.1 + §4 + §9.3), Gauss (TMB template
§3 + §5.2 + §9.1), Noether (math §5.1 + identifiability
§5.3 + cross-family §6), Curie (recovery tests §9.4 + §9.5),
Rose (scope §2 + invariant §7 + risk §11), Shannon (drafting
+ coordination §12 + §13).
