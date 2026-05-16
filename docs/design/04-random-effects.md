# Random Effects

**Maintained by:** Boole (R API + parser owner for the 3 × 5
keyword grid) and Fisher (inference semantics on the
reduced-rank decomposition).
**Reviewers:** Curie (simulation-recovery + boundary cases),
Gauss (TMB numerical implementation), Noether (math-vs-
implementation alignment), Emmy (S3 dispatch on the random-
effects output).

The random-effects machinery is the heart of `gllvmTMB`. The
3 × 5 covariance keyword grid (see
`docs/design/01-formula-grammar.md`) is the user-facing surface;
this document describes the contract underneath — what each
keyword does to the latent variables, how the TMB template
integrates them, and how identifiability is managed.

**Status discipline**: 4-state vocabulary (`covered / claimed /
reserved / planned`). Most current rows are `claimed`; Phase 0B
verifies via per-keyword simulation-recovery tests. Random
**slopes** inside the 3 × 5 keywords are `reserved` (M1 work).

## Order of implementation

The development sequence (mirrors drmTMB's order-of-implementation
discipline, adapted for the multi-trait stacked grammar):

1. **No random effects.** Long-format fixed-effects-only fit:
   `value ~ 0 + trait + (0 + trait):env`. Baseline; serves
   primarily as a comparator for the random-effects fits.
2. **Ordinary random intercepts** `(1 | g)`. Pass-through to
   `glmmTMB::glmmTMB()`-style RE. Orthogonal to the 3 × 5 grid;
   used for groupings that are NOT the unit / unit_obs / cluster
   axes. **Status: `claimed`** (Phase 0B verifies).
3. **`unique(0 + trait | g)` trait-diagonal** $\boldsymbol\Psi$.
   Per-trait variance on the grouping factor. **Status: `claimed`**.
4. **`latent(0 + trait | g, d = K)` reduced-rank** loadings.
   The `glmmTMB::rr()` machinery (McGillycuddy et al. 2025)
   adapted to the trait-stacked grammar. **Status: `claimed`**.
5. **`latent + unique` paired decomposition** producing
   $\Sigma = \Lambda\Lambda^\top + \Psi$. **Status: `claimed`**.
6. **`indep(0 + trait | g)` compound-symmetric** trait
   covariance. **Status: `claimed`**.
7. **`dep(0 + trait | g)` unstructured** trait covariance.
   **Status: `claimed`**.
8. **Phylogenetic random effects** (`phylo_*` keywords) via
   sparse $A^{-1}$. **Status: `claimed`**.
9. **Spatial random effects** (`spatial_*` keywords) via SPDE
   / GMRF precision. **Status: `claimed`**.
10. **`meta_V(value, V = V)` known-sampling-covariance random
    effect**. Desugars to `equalto(0 + obs | grp_V, V)`.
    **Status: `claimed`** (Phase 0B verifies via comparator vs
    `glmmTMB::equalto()`).
11. **Random slopes** `(0 + x | g)` or `(1 + x | g)` inside the
    3 × 5 keywords. **Status: `reserved`** (M1 Gaussian
    completeness work; see `docs/design/42-random-slopes-grammar.md`
    forthcoming).
12. **Phylogenetic / spatial random slopes** (`phylo_slope`,
    `spatial_slope`). **Status: `planned`** (post-M1, after
    Gaussian random slopes prove out).

## Vocabulary

The 3 × 5 keyword grid plus ordinary RE form the
random-effects vocabulary:

| Source | Keyword pattern | What it adds to the linear predictor |
|--------|-----------------|-------------------------------------|
| Ordinary RE | `(1 \| g)` | Standard random intercept by `g`; not multi-trait-aware |
| 3 × 5 grid: scalar | (omit / `phylo_scalar` / `spatial_scalar`) | Single scalar covariance source for all traits |
| 3 × 5 grid: `unique` | `unique() / phylo_unique() / spatial_unique()` | Per-trait variance ($\Psi$) on grouping factor |
| 3 × 5 grid: `indep` | `indep() / phylo_indep() / spatial_indep()` | Compound-symmetric trait covariance |
| 3 × 5 grid: `dep` | `dep() / phylo_dep() / spatial_dep()` | Unstructured trait covariance |
| 3 × 5 grid: `latent` | `latent() / phylo_latent() / spatial_latent()` | Reduced-rank $\Lambda$ ($T \times K$) |
| `meta_V` | `meta_V(value, V = V)` | Known sampling covariance added to residual |

## Reduced-rank reparameterisation (`latent(...)`)

The reduced-rank `latent(0 + trait | g, d = K)` keyword
implements $\boldsymbol\Lambda \in \mathbb{R}^{T \times K}$ via
the `glmmTMB::rr()` parameterisation (McGillycuddy, Popovic,
Bolker & Warton 2025, *J. Stat. Softw.* 112(1)). The mathematical
model is:

$$
\eta_{it} = \mu_t + \boldsymbol\lambda_t^\top \mathbf{u}_{g(i)} \quad
\mathbf{u}_\ell \sim \mathcal{N}(\mathbf{0}, I_K)
$$

where $\boldsymbol\lambda_t \in \mathbb{R}^K$ is the loadings
vector for trait $t$, $\mathbf{u}_\ell$ are the latent factor
scores for grouping level $\ell$, and $g(i)$ maps row $i$ to its
group level.

### Internal parameterisation

To make $\boldsymbol\Lambda$ identifiable up to rotation:

- $\boldsymbol\Lambda$ is parameterised as **lower-triangular**
  with **positive diagonal**.
- The $K(K-1)/2$ upper-triangular entries are zero.
- The diagonal entries are on the log scale: $\lambda_{kk} = \exp(\tilde\lambda_{kk})$.
- The lower-triangular off-diagonal entries are unconstrained
  real numbers.

This gives $T \cdot K - K(K-1)/2$ free parameters (instead of
$T \cdot K$), which is the standard rotation-resolution
convention from factor analysis.

### Rotation invariance

The shared trait covariance $\boldsymbol\Lambda\boldsymbol\Lambda^\top$
is identifiable, but $\boldsymbol\Lambda$ alone is identifiable
only up to rotation. The triangular-with-positive-diagonal
parameterisation fixes the rotation. For post-hoc varimax /
oblimin rotation on the loadings, see `rotate_loadings()` and
the `lambda-constraint.Rmd` worked example.

### `lambda_constraint` for confirmatory factor analysis

When users have prior structure on $\boldsymbol\Lambda$ (e.g.
psychometric IRT pinning specific item-factor loadings to known
values), the `lambda_constraint = list(B = M)` argument lets
them pin entries of $\boldsymbol\Lambda$ in the between-tier
$B$. The pinned entries are not estimated; the remaining
entries are estimated subject to the constraint. **Status:
`claimed`** for Gaussian; **`reserved` for binary** (the M2
slice verifies binary IRT confirmatory loadings).

`suggest_lambda_constraint(fit)` returns a recommended
constraint matrix given an exploratory fit. **Status: `claimed`**
for Gaussian; **`reserved` for binary** (M2 verifies at
$n_\text{items} \in \{10, 20, 50\}$, $d \in \{1, 2, 3\}$).

## Trait-diagonal $\boldsymbol\Psi$ (`unique(...)`)

The `unique(0 + trait | g)` keyword implements the diagonal
trait-unique-variance matrix $\boldsymbol\Psi = \text{diag}(\psi_1^2, \ldots, \psi_T^2)$:

$$
\eta_{it} = \cdots + v_{\ell t}, \quad
v_{\ell t} \sim \mathcal{N}(0, \psi_t^2)
$$

### Internal parameterisation

- $\psi_t^2$ is on the log scale: $\psi_t^2 = \exp(2 \tilde\psi_t)$.
- One free parameter per trait.

### Paired with `latent(...)`

When both `latent(0 + trait | g, d = K)` and `unique(0 + trait | g)`
appear in the formula with the same grouping factor `g`, the
engine combines them into the canonical decomposition:

$$
\boldsymbol\Sigma_g = \boldsymbol\Lambda\boldsymbol\Lambda^\top + \boldsymbol\Psi
$$

This is the **headline decomposition** named in
`docs/design/00-vision.md`. See `01-formula-grammar.md` for the
pairing rule's full mechanics.

## Compound-symmetric `indep(...)` and unstructured `dep(...)`

**`indep(0 + trait | g)`** estimates a single trait-by-trait
correlation $\rho$ shared across all off-diagonal pairs:

$$
\boldsymbol\Sigma_\text{indep} = \sigma^2 [(1 - \rho) I_T + \rho \mathbf{1}\mathbf{1}^\top]
$$

Two free parameters: $\sigma^2$ (log scale) and $\rho$ (atanh
scale with guarded $0.99999999 \cdot \tanh$ to ensure positive
definiteness).

**`dep(0 + trait | g)`** estimates the full $T \times T$
unstructured trait covariance via Cholesky factorisation:

$$
\boldsymbol\Sigma_\text{dep} = L L^\top
$$

where $L$ is the lower-triangular Cholesky factor with positive
diagonal. $T(T+1)/2$ free parameters.

**Use case distinction**:
- `unique` alone → trait-independent (no off-diagonal).
- `indep` → all trait pairs share one correlation; useful when
  there's no prior reason for asymmetric structure.
- `dep` → estimate every entry; statistically expensive but
  most flexible.
- `latent + unique` → reduced-rank shared structure +
  trait-specific residuals; the headline decomposition.

## Phylogenetic random effects (`phylo_*`)

Phylogenetic keywords add a sparse-precision structure on the
cluster axis (default column name `species`; rename via
`cluster = "..."`). The math is the Hadfield & Nakagawa (2010)
sparse-$A^{-1}$ representation:

$$
\mathbf{g}_\text{phy} \sim \mathcal{N}(\mathbf{0}, \boldsymbol\Sigma_\text{phy} \otimes A)
$$

where $A$ is the phylogenetic correlation matrix derived from
the tree. $A$ is dense ($n_\text{species} \times n_\text{species}$)
but $A^{-1}$ is sparse when the tree has many internal nodes.

### Tier vs partition

A clarification that matters for users coming from a "tier"
mental model: when the phylo keyword's grouping factor equals
`unit` (the canonical case where `unit = species`), `phylo_*`
terms are conceptually a **partition of the between-unit
variance** distinguished by phylogenetic correlation across
species — *not* a separate grouping level. The total
between-species variance for trait $t$ is

$$
\sigma^2_t \;=\; (\Lambda_\text{phy}\Lambda_\text{phy}^\top)_{tt}
            + (\Lambda_\text{non}\Lambda_\text{non}^\top)_{tt}
            + \psi^2_t
$$

— all at the same grouping factor (species), distinguished
by *correlation structure across species* ($A^{-1}$ versus
$I$), not by *grouping*. `extract_Omega()` returns the
integrated $\Omega$ in this case;
`extract_Sigma(level = "phy")` returns the phylo *share*
alone, useful for slot-level inspection but conceptually a
partition of `level = "unit"`.

When the phylo grouping factor differs from `unit` (e.g.
`unit = individual`, phylo grouping = `species`), phylo
genuinely lives at a different grouping axis and the
"separate tier" reading applies. The keyword grammar is the
same; only the interpretation shifts with the data layout.

### `phylo_latent + phylo_unique` paired decomposition

Mirrors the non-phylo pair:

$$
\boldsymbol\Sigma_\text{phy} = \boldsymbol\Lambda_\text{phy}\boldsymbol\Lambda_\text{phy}^\top + \boldsymbol\Psi_\text{phy}
$$

`phylo_latent(species, d = K, tree = tree)` estimates
$\boldsymbol\Lambda_\text{phy}$; `phylo_unique(species, tree = tree)`
estimates the diagonal $\boldsymbol\Psi_\text{phy}$.

### Three-piece fallback

When the paired form is under-identified (small $n_\text{species}$,
weak phylogenetic signal), the canonical fallback drops one
$\boldsymbol\Psi$ and keeps a single trait-specific diagonal:

$$
\boldsymbol\Omega = \boldsymbol\Lambda_\text{phy}\boldsymbol\Lambda_\text{phy}^\top + \boldsymbol\Lambda_\text{non}\boldsymbol\Lambda_\text{non}^\top + \boldsymbol\Psi
$$

See `docs/design/03-phylogenetic-gllvm.md` for the three-piece
contract.

## Spatial random effects (`spatial_*`)

Spatial keywords use the Lindgren-Rue-Lindström (2011) SPDE
construction inherited from `sdmTMB`. The precision matrix is

$$
Q_\text{spde} = \kappa^4 M_0 + 2\kappa^2 M_1 + M_2
$$

built on a triangular mesh via `make_mesh()`. Observations are
linked to mesh nodes via a sparse $n \times n_\text{mesh}$
projection matrix $A_\text{proj}$:

$$
\eta_\text{spatial}(\text{obs}) = A_\text{proj} \cdot \mathbf{w}_\text{mesh}
$$

where $\mathbf{w}_\text{mesh} \sim \mathcal{N}(\mathbf{0}, Q_\text{spde}^{-1})$.

### Spatial syntax convention (2026-05-16)

Spatial keywords take a grouping factor `sites` plus geometry
specification (`mesh = mesh` or `coords = c("lon", "lat")`):

```r
spatial_unique(0 + trait | sites, mesh = mesh)
# or
spatial_unique(0 + trait | sites, coords = c("lon", "lat"))
```

Both reach the same engine via the precomputed mesh. The
`sites` grouping factor groups observations sharing a spatial
location; the geometry argument supplies the SPDE mesh.

### Tier vs partition

Same logic as the phylogenetic "Tier vs partition" subsection
above. When the spatial keyword's grouping factor equals
`unit` (the canonical case where `unit = sites`),
`spatial_*` terms are a **partition of the between-unit
variance with spatial correlation structure** ($Q_\text{spde}$
versus $I$), not a separate grouping level.
`extract_Sigma(level = "spatial")` returns the spatial
*share* — useful for slot-level inspection, but conceptually
a partition of `level = "unit"` in the canonical case. When
the spatial grouping factor differs from `unit`, spatial
genuinely lives at a different grouping axis.

## `meta_V()` known-sampling-covariance random effect

`meta_V(value, V = V)` adds a known sampling-covariance term
to the residual:

$$
\mathbf{y} = X\boldsymbol\beta + Z\mathbf{u} + \boldsymbol\varepsilon, \quad
\boldsymbol\varepsilon \sim \mathcal{N}(\mathbf{0}, V + \sigma^2 I)
$$

where $V$ is supplied as `known_V = V`. Internally desugars to
`equalto(0 + obs | grp_V, V)`. See `docs/design/01-formula-grammar.md`
for the desugaring details and `block_V()` for compound-
symmetric block-diagonal `V` construction.

**Planned post-CRAN**: `meta_V(value, w = w, scale = "proportional")`
adds the multiplicative weighted-regression mode per Nakagawa
2022 EcoLetters. See vision doc "Planned extensions".

## Random slopes — design plan (M1 work; ONE random slope only)

`gllvmTMB` does NOT currently support random slopes inside the
3 × 5 keywords. The M1 Gaussian completeness milestone (per
ROADMAP, post-Phase-0C) adds **a single random slope** to the
`latent + unique` paired keywords. This section is the design
contract; the M1.1 slice doc
`docs/design/42-random-slopes-grammar.md` (forthcoming) covers
parser + TMB-template details.

### Why we cap at 1 slope for the foreseeable future

Maintainer 2026-05-16 design decision: **start with 1 slope
only**. Reasoning:

- **Slope-slope correlations get hard fast.** With 2 random
  slopes per trait, the model estimates per-trait
  intercept-intercept, slope-intercept, slope-slope, AND
  cross-trait correlations for each. The reduced-rank Lambda
  absorbs some of this, but identification is fragile.
- **Most ecological use cases need only 1 slope.** Personality
  plasticity to one environment, longitudinal trait change
  with time, reaction norms across a single gradient — all
  single-slope cases. JSDM env-by-species is typically a
  fixed-effect `(0 + trait):env` interaction, not a random
  slope.
- **Validation cost scales fast.** A single coverage study at
  $s = 1$ across families is already substantial; doing it at
  $s = 2$ and $s = 3$ doubles and triples the validation surface.
- **Easier to expand than to retreat.** If 1-slope fits work
  cleanly through M1 and post-M1 user feedback shows real
  demand for 2 slopes, we can add 2 slopes in a focused
  follow-up. Releasing 3-slope support that turns out to be
  unreliable would be worse than waiting.

### Cost-scaling reference (informational only)

For $T$ traits and $s$ random slopes, the per-level random-effect
vector has length $T(1+s)$:

| Slopes | Latent vector per level | Unstructured $\Sigma$ entries | Reduced-rank ($K$) |
|--------|-------------------------|-------------------------------|---------------------|
| 0 (intercept only) | $T$ | $T(T+1)/2$ | $TK$ loadings + $T$ diag |
| **1 slope (M1 scope)** | $2T$ | $T(2T+1)$ | $2TK$ + $2T$ diag |
| 2 slopes (planned, post-M1) | $3T$ | $\frac{3T(3T+1)}{2}$ | $3TK$ + $3T$ diag |
| 3 slopes (planned, post-2-slopes) | $4T$ | $2T(4T+1)$ | $4TK$ + $4T$ diag |
| 4+ slopes | $5T+$ | huge | rejected at parse time |

For $T = 10$: 0 → 55 cov entries; 1 → 210; 2 → 465; 3 → 820.

### Allowed long-format syntax (M1 scope)

```r
# 0 random slopes (current; intercept only). Status: covered.
gllvmTMB(
  value ~ 0 + trait + (0 + trait):env +
    latent(0 + trait | site, d = 2) +
    unique(0 + trait | site),
  data = df,
  unit = "site"
)

# 1 random slope (M1.1). Status: claimed (M1.1 verifies).
gllvmTMB(
  value ~ 0 + trait + (0 + trait):env +
    latent(0 + trait + (0 + trait):env | site, d = 2) +
    unique(0 + trait + (0 + trait):env | site),
  data = df,
  unit = "site"
)

# 2+ random slopes: REJECTED at parse time in M1.
# (Will be planned for a post-M1 slice if user feedback shows
# real demand AND M1.1 stabilises.)
```

### Allowed wide-format syntax (M1 scope)

```r
# 1 random slope via traits() LHS shorthand:
gllvmTMB(
  traits(t1, t2, t3) ~ 1 + env +
    latent(1 + env | site, d = 2) +
    unique(1 + env | site),
  data = df_wide,
  unit = "site"
)
```

Expansion: `1` → `0 + trait`; `1 + env` → `0 + trait + (0 + trait):env`.
Same engine.

### Slope cap (parser-enforced)

| Slopes inside `latent + unique` | Status | Parser behaviour |
|---------------------------------|--------|------------------|
| 0 | `covered` | accepted (current path) |
| 1 | `claimed` (M1.1) | accepted; per-trait intercept + 1 slope |
| 2 | `planned (post-M1)` | **rejected at parse time in M1** with `class = "gllvmTMB_too_many_slopes"`; revisited as a focused post-M1 slice if user demand surfaces AND M1.1 stabilises |
| 3 | `planned (post-2-slopes)` | rejected; conditional on the 2-slope slice landing first |
| 4+ | `rejected (long-term)` | always rejected; this combinatorial regime is not in scope |

Error message for the rejected cases:

> *"Random slopes inside `latent + unique` are capped at 1 in
> the 0.2.0 release (the maintainer 2026-05-16 design decision;
> see `docs/design/04-random-effects.md` 'Random slopes — design
> plan' section). 2-slope and 3-slope support are planned for
> post-M1 releases conditional on validation evidence. For now,
> reduce to a single random slope OR use a reduced-rank
> covariance structure (`indep` / `dep`) to absorb the
> across-predictor variation, OR fit the additional predictors
> as fixed-effect `(0 + trait):x` interactions."*

### What happens internally for $s$ slopes

For `latent(0 + trait + (0 + trait):x_1 + ... + (0 + trait):x_s | g, d = K)`:

- The per-level random-effect vector has length $T(1 + s)$,
  indexed by (trait, intercept-or-slope-index).
- $\boldsymbol\Lambda \in \mathbb{R}^{T(1+s) \times K}$ captures
  shared variation across intercepts and slopes.
- The implied covariance is
  $\boldsymbol\Sigma_g = \boldsymbol\Lambda\boldsymbol\Lambda^\top + \boldsymbol\Psi$
  on the $T(1+s)$-dimensional vector.
- $\boldsymbol\Psi$ has $T(1+s)$ diagonal entries (one per
  (trait, intercept-or-slope) combination).
- Slope-slope correlations (across $T$ traits, across $s$
  slopes) are captured implicitly through $\boldsymbol\Lambda$'s
  rows.

This is mathematically the **same structure** as the
intercept-only case — just with a wider per-level vector. The
reduced-rank decomposition still applies; $K$ can stay
modest (1, 2, or 3) regardless of how many slopes.

### Computational cost

- $T(1+s)$ latent variables per group level → $T(1+s) \cdot K$
  loadings → Laplace approximation cost scales with $K$ (not
  with $T$ or $s$ directly, because the random-effect vector
  reshapes into the $K$-dim factor scores).
- Each group level $\ell$ has $K$ factor scores per
  intercept-or-slope; total integration is over $K \cdot n_g$
  random variables.
- Roughly linear in $T \cdot s$ for the loadings dimension; not
  combinatorial in $T$.

### Phylogenetic / spatial random slopes — `planned (post-M1)`

`phylo_slope(species, d = K, tree = tree, slope = ~ env)` and
`spatial_slope(0 + trait | sites, mesh = mesh, slope = ~ env)`
are **NOT** in the M1 scope. After M1 lands and stabilises
Gaussian random slopes on the non-phylo, non-spatial keywords,
the phylo / spatial extensions get their own design + slice.

The combinatorial cap also applies: max 3 slopes inside
`phylo_latent + phylo_unique` and `spatial_latent + spatial_unique`
respectively. Parser enforcement extends to the phylo/spatial
keywords when they ship.

### Identifiability diagnostic

`check_identifiability(fit)` extends to flag rank-deficiency in
the $T(1+s) \times K$ Lambda when slopes are present. Test
fixture (M1.5):

1. Simulate from $d = K$ truth with $s$ random slopes per
   $T$ traits.
2. Fit with $d = K+1$ (spurious extra factor).
3. Verify `check_identifiability()` flags the spurious column
   via Procrustes-aligned near-zero residual magnitude.

### Coverage study scope

M1.5 `coverage_study()` runs on the M1 slope-count cases:
$s \in \{0, 1\}$, $T = 10$ traits, $n_g = 50$ to $100$ sites,
$K \in \{1, 2, 3\}$, $R = 200$ replicates per cell. Target
$\ge 94 \%$ empirical coverage on:

- per-trait random-intercept variances $\psi_t^2$
- per-trait random-slope variance (at $s = 1$)
- pairwise intercept-slope correlations within trait (at $s = 1$)
- the implied repeatability (intercept-only and intercept+slope
  cases)

Slope-slope correlation coverage (which would test the 2-slope
or 3-slope regime) is deferred to the post-M1 slice that adds
2 random slopes, IF that slice ships.

### Slope-only random effects (planned, post-M1)

The current design assumes random slopes accompany a random
intercept (the `(0 + trait + (0 + trait):x | g)` pattern). Pure
slope-only random effects (`(0 + (0 + trait):x | g)`, no
intercept) are **`planned (post-M1)`**. The use case (slope
varies across levels, but no per-level intercept offset) is
rare; comes back as a follow-up slice after M1 closes.

### Other 3 × 5 cells

Other 3 × 5 cells (`indep`, `dep`, and the phylo / spatial
analogues) get random-slope support **one at a time after M1
closes**. The order is:

1. M1.1-M1.3: `latent + unique` paired keyword with 1, 2, 3
   slopes (Gaussian).
2. M2: same machinery extended to binomial (`family =
   binomial()`).
3. Post-M2: `phylo_latent + phylo_unique` slopes.
4. Post-M2: `spatial_latent + spatial_unique` slopes.
5. Post-CRAN: `indep` / `dep` slopes (less common; lower
   priority).

## Crossed-vs-nested encoding

`gllvmTMB`'s engine accepts crossed-with-globally-unique-levels
nesting; the slash form `(1 | g1/g2)` is **explicitly rejected**
(see `docs/design/01-formula-grammar.md`).

### Relationship rules (maintainer 2026-05-16)

- **`unit` ↔ `unit_obs`**: MUST be nested. `unit_obs` represents
  observations *within* a `unit`. Encoded as crossed-with-
  globally-unique-levels:

  ```r
  df$session_id <- factor(paste(df$individual, df$session, sep = "_"))
  ```

- **`unit` ↔ `cluster`**: MAY be crossed. `cluster` (species,
  item) is a separate axis from `unit` (site, person). Species
  can occur at many sites; items can be answered by many people.

- **`cluster` ↔ `unit_obs`**: MAY be crossed.

See `01-formula-grammar.md` for the full unit / unit_obs /
cluster taxonomy.

## Numerical scales and constraints

| Quantity | Internal scale | Notes |
|----------|----------------|-------|
| Variance components ($\psi_t^2$, $\sigma_g^2$) | log | Positive definite by construction |
| Loadings diagonal ($\lambda_{kk}$) | log | Positive by construction |
| Loadings off-diagonal | unconstrained | Lower-triangular only |
| Correlations ($\rho$ in `indep`) | guarded atanh | $\rho = 0.99999999 \cdot \tanh(\eta_\rho)$ |
| Phylogenetic scaling ($\sigma^2_\text{phy}$) | log | Multiplies the sparse $A^{-1}$ precision |
| SPDE inverse-range ($\kappa$) | log | $\kappa > 0$; practical range $= \sqrt{8}/\kappa$ |
| SPDE marginal SD ($\tau$) | log | Used in $\sigma^2 = 1/(4\pi\kappa^2\tau^2)$ |

## Boundary cases and identifiability

### Variance near zero

A `unique()` term with $\psi_t^2 \to 0$ collapses to a
degenerate point mass at zero — the trait has no residual
variance after the shared structure. `sanity_multi()` flags
this as a boundary-pinned variance component.

### Rank deficiency

If $K \ge T$ in `latent(0 + trait | g, d = K)`, the loadings
matrix is over-parameterised and the rotation-resolution
constraint becomes non-binding. The engine rejects $K \ge T$
at parse time.

### Spurious extra factors

If the user specifies $d = 2$ when the true rank is $d = 1$,
`pdHess` may be `TRUE` and `sanity_multi()` may pass — but
the second factor is noise. `check_identifiability()` (PR #105)
catches this via Procrustes-aligned recovery across simulate-
refit replicates: the spurious column has near-zero residual
magnitude.

### Phylogenetic identifiability levels

Three levels (per `03-phylogenetic-gllvm.md`):

1. The model converges with finite likelihood.
2. The total $\boldsymbol\Sigma_\text{phy}$ and $\boldsymbol\Sigma_\text{non}$
   are stable enough to interpret.
3. The split into $\boldsymbol\Lambda\boldsymbol\Lambda^\top$ and
   $\boldsymbol\Psi$ is stable across ranks, starts, and
   reasonable comparator fits.

Level 2 is usually the biological target; level 3 is fragile.

## Diagnostics for random-effects fits

| Diagnostic | What it checks | Status |
|-----------|----------------|--------|
| `sanity_multi(fit)` | pdHess; convergence; boundary-pinned variance components; rank deficiency | claimed |
| `gllvmTMB_diagnose(fit)` | Combined report of optimizer state + Hessian + standard errors | claimed |
| `check_identifiability(fit, sim_reps = 100L)` | Procrustes-aligned simulate-refit recovery of $\boldsymbol\Lambda$; spurious-factor flag | covered (PR #105 + tests in `test-check-identifiability.R`) |
| `gllvmTMB_check_consistency(fit, n_sim = 100L)` | TMB::checkConsistency() wrapper; marginal score centred at zero | covered (PR #121) |
| `confint_inspect(fit, parm)` | Visual profile-curve verification | covered (PR #120) |
| `coverage_study(fit, parm, n_reps, methods)` | Empirical CI coverage on a fitted model via parametric bootstrap | covered (PR #122) |
| `extract_residual_split(fit)` | Per-trait residual variance decomposition | claimed |

The Phase 1b validation milestone (PRs #105, #120, #121, #122
all merged) brought four of the seven diagnostics to `covered`.
The remaining three are Phase 0B verification targets.

## Cross-references

- `docs/design/00-vision.md` — package vision; the 3 × 5 grid
  + reduced-rank decomposition + phylogenetic and spatial
  extensions ARE the package's identity.
- `docs/design/01-formula-grammar.md` — full formula grammar
  contract; the 3 × 5 keyword grid + `traits()` LHS expansion
  + unit / unit_obs / cluster taxonomy + crossed-vs-nested rule.
- `docs/design/02-family-registry.md` — per-family registry;
  the link-residual contract that combines with the trait
  covariance for mixed-family latent-scale correlation.
- `docs/design/03-likelihoods.md` — per-family TMB likelihood
  + random-effects integration details.
- `docs/design/03-phylogenetic-gllvm.md` — phylogenetic GLLVM
  contract; the paired vs three-piece decomposition; PIC
  retirement context.
- `docs/design/05-testing-strategy.md` (forthcoming, Phase 0A
  step 5) — per-keyword required edge cases.
- `docs/design/06-extractors-contract.md` (forthcoming) — what
  every `extract_*()` returns for each random-effect type.
- `docs/design/35-validation-debt-register.md` (forthcoming,
  Phase 0A step 7) — evidence ledger.
- `docs/design/42-random-slopes-grammar.md` (forthcoming, M1.1
  slice) — random-slopes design + parser + TMB extension.
- `R/fit-multi.R` — main fit-multi() entry; calls the parser
  + dispatches to TMB.
- `src/gllvmTMB.cpp` — the TMB template.
- `R/extract-sigma.R` — `link_residual_per_trait()`.
- AGENTS.md Design Rules #3 (no formula-grammar change without
  this doc) and #5 (no new tier without simulation recovery on
  a known DGP at the new tier).

## Persona-active engagement

- **Boole** owns the parser surface for the 3 × 5 keywords +
  ordinary RE + slash-form-rejected enforcement.
- **Fisher** reviews inference semantics on the reduced-rank
  decomposition — what $\boldsymbol\Lambda$ rotation does to
  CI reporting; per-keyword profile CI validity; coverage at
  boundary cases.
- **Curie** writes the per-keyword simulation-recovery tests
  and the boundary-case test suite (variance near zero, rank
  deficiency, spurious factor).
- **Gauss** owns the TMB-template extensions for each new
  random-effect keyword (when M1 adds random slopes, Gauss
  drafts the C++ before merge).
- **Noether** audits the math-vs-implementation alignment
  for the reduced-rank reparameterisation (triangular-with-
  positive-diagonal $\Lambda$) and the phylogenetic /
  spatial precision constructions.
- **Emmy** reviews the S3 dispatch on random-effects output:
  `extract_Sigma()`, `extract_correlations()`,
  `extract_ordination()`, `extract_repeatability()`,
  `extract_phylo_signal()`. Are the return shapes coherent
  across keyword combinations?
- **Rose** audits per-row honesty on the order-of-implementation
  table (reserved is not advertised as a feature; covered rows
  have evidence).
- **Ada** ratifies the `claimed → covered` promotion when
  Phase 0B + Phase 1 evidence arrives.

## How this doc grows

The order-of-implementation table will fill in with evidence
(test file paths, comparator alignment notes, boundary-case
findings) as Phase 0B verifies each keyword and as M1 / M2 land
random-slope support. By the time `meta_V`'s proportional mode,
`phylo_slope`, `spatial_slope`, and the cluster × unit nesting
parser become reality (post-CRAN), this doc will be
substantially longer — matching drmTMB's trajectory.
