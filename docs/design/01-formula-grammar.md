# Formula Grammar

**Maintained by:** Boole (R API + formula grammar lead).
**Reviewers:** Noether (math-vs-implementation alignment) and Rose
(public-consistency audit).

The formula grammar is the heart of `gllvmTMB`. The 3 × 5 covariance
keyword grid is the public-API contract; everything in the engine
serves it. Per **AGENTS.md Design Rule #3**, no change to this grammar
ships without updating this document first.

The package should learn from `glmmTMB`, `gllvm`, and `galamm` without
copying their grammars wholesale. The public grammar is built around
two principles:

1. **Memorable, biology-first keyword names.** `latent()`, `unique()`,
   `phylo_latent()`, `spatial_unique()` — each name encodes both the
   correlation source and the covariance mode.
2. **Strict pairing rules.** `latent` and `unique` come as a pair when
   the user wants the decomposition $\Sigma = \Lambda\Lambda^\top + \Psi$.
   The engine enforces this so users cannot accidentally fit a
   rank-degenerate model.

## Status map

Use three status words consistently across all documentation, NEWS
entries, and articles:

- **implemented**: parsed, fitted, documented, and tested in the
  validation-debt register (`docs/design/35-validation-debt-register.md`)
  with status `covered`.
- **reserved**: parsed or reserved as public grammar, but rejected
  by `gllvmTMB()` until the likelihood / extractor / tests exist.
- **planned**: shown only to explain the roadmap; not parsed yet.

| Syntax | Current status | Notes |
| --- | --- | --- |
| `gllvmTMB(value ~ ..., data = df_long)` | implemented | Canonical long-format entry point. One row per `(unit, trait)`. |
| `gllvmTMB(traits(t1, t2, ...) ~ ..., data = df_wide)` | implemented | Wide-format entry point. The `traits(...)` LHS marker triggers internal pivot to long. |
| `gllvmTMB_wide(Y, ...)` | implemented | Matrix-in entry point. Soft-deprecated as of 0.2.0 in favour of the formula-API path; retained for the per-cell weight-matrix workflow. |
| `0 + trait` and `(0 + trait):x` | implemented | Long-form trait-stacked fixed-effect grammar. |
| `latent(0 + trait \| g, d = K)` | implemented | Reduced-rank loadings for $T$ traits across grouping factor `g`, rank $K \le T$. |
| `unique(0 + trait \| g)` | implemented | Trait-diagonal $\boldsymbol\Psi$ on grouping factor `g`. |
| `latent + unique` paired | implemented | The decomposition $\Sigma = \boldsymbol\Lambda\boldsymbol\Lambda^\top + \boldsymbol\Psi$. |
| `indep(0 + trait \| g)` | implemented | Compound-symmetric trait covariance (all off-diagonals equal). |
| `dep(0 + trait \| g)` | implemented | Fully unstructured trait covariance estimated directly. |
| `(omit)` ↔ scalar covariance | implemented | Omitting the `unique`/`indep`/`dep` slot means *no trait-specific term*; only the keyword's correlation source contributes. |
| `phylo_latent(species, d = K, tree = tree)` | implemented | Reduced-rank phylogenetic loadings using sparse $A^{-1}$. |
| `phylo_unique(species, tree = tree)` | implemented | Trait-diagonal $\boldsymbol\Psi_\text{phy}$ scaled by phylogenetic covariance. |
| `phylo_scalar(species, vcv = Cphy)` | implemented | Single trait-scalar phylogenetic random effect; the simplest phylogenetic mixed-model form. |
| `phylo_indep` / `phylo_dep` | implemented | Compound-symmetric and unstructured phylogenetic trait covariance. |
| `spatial_latent / spatial_unique / spatial_scalar / spatial_indep / spatial_dep` | implemented | Spatial analogues of the phylo keywords; require a precomputed `mesh = make_mesh(...)`. |
| `meta_known_V(value, V = V)` | implemented | Known sampling covariance, desugars to `equalto(0 + obs \| grp_V, V)`. Pass `known_V = V` to `gllvmTMB()` alongside. |
| `block_V(study, sampling_var, rho_within)` helper | implemented | Builds the standard compound-symmetric block-diagonal `V` for within-study correlation. |
| `(1 \| group)` ordinary random intercept | implemented | Pass-through to `glmmTMB`-style random intercept; orthogonal to the 3 × 5 keyword grid. |
| `(1 + x \| g)` ordinary random slope | **reserved** | Parser does not accept random slopes inside the 3 × 5 keywords yet. Planned for M1 (Gaussian completeness). |
| `latent(0 + trait \| g) + lambda_constraint = list(B = M)` | implemented | Confirmatory factor analysis on the latent loadings; pins specific entries of $\boldsymbol\Lambda$. |
| `suggest_lambda_constraint(fit)` | implemented (Gaussian); **reserved** for binary | Helper that recommends constraint matrices. Validated on Gaussian only; binary-fit validation is M2 work. |
| `meta_V(value, V = V)` / `meta_V(value, w = w, scale = "proportional")` | **planned (post-CRAN)** | Unification of known-additive and proportional sampling-variance forms per Nakagawa 2022 EcoLetters. See vision doc "Planned extensions". |
| `weights = w` argument | **planned (post-CRAN)** | glmmTMB-style row-weights, separate from `meta_known_V()`. See vision doc "Planned extensions". |

## Two data shapes

`gllvmTMB` accepts both data shapes through a single entry point. The
long form is canonical; the wide form is a pivot-then-fit
convenience. They produce byte-identical log-likelihoods.

### Long format (canonical)

One row per `(unit, trait)` observation, with explicit `trait`,
`unit`, and (for two-level models) `unit_obs` factor columns plus
the response column `value`:

```r
gllvmTMB(
  value ~ 0 + trait + (0 + trait):env +
    latent(0 + trait | site, d = 2) +
    unique(0 + trait | site),
  data = df_long,
  unit = "site"
)
```

The long form makes the trait-stacked grammar visible row by row.
Pairs of keywords (`latent + unique`) read literally: the
right-hand side lists trait-by-trait covariance pieces.

### Wide format via the `traits(...)` LHS helper

One row per unit, one column per trait. The `traits(...)` LHS
marker tells the parser to pivot the wide data to long internally,
then expand the compact RHS shorthand:

```r
gllvmTMB(
  traits(length, mass, wing, tarsus, bill) ~ 1 + env +
    latent(1 | individual, d = 2) +
    unique(1 | individual),
  data = df_wide,
  unit = "individual"
)
```

The compact RHS shorthand is:

| Wide shorthand | Long expansion |
|----------------|----------------|
| `1` | `0 + trait` |
| `env` | `(0 + trait):env` |
| `latent(1 \| g, d = K)` | `latent(0 + trait \| g, d = K)` |
| `unique(1 \| g)` | `unique(0 + trait \| g)` |
| `indep(1 \| g)` | `indep(0 + trait \| g)` |
| `dep(1 \| g)` | `dep(0 + trait \| g)` |
| `phylo_*` and `spatial_*` keywords | Pass through unchanged. |
| `(1 \| group)` ordinary RE | Pass through unchanged. |

The pivot uses `tidyr::pivot_longer()` internally; the response
column becomes a hidden `value` column on the long side, and the
trait names supplied to `traits(...)` become the factor levels of
the new `trait` column. Per the persona-active discipline, the
parser test suite is owned by Curie; the parser implementation is
owned by Boole.

User-facing examples in README, vignettes, and Tier-1 articles
should pair the long and wide forms side-by-side with a `logLik`
agreement check (the `morphometrics.Rmd` pattern). This is a
public-API contract: both forms produce identical fits.

## The 3 × 5 covariance keyword grid

The grid is the user-facing public-API contract. Rows are
correlation sources; columns are covariance modes:

| correlation \ mode | scalar | unique | indep | dep | latent |
|---|---|---|---|---|---|
| **none** | (omit) | `unique()` | `indep()` | `dep()` | `latent()` |
| **phylo** | `phylo_scalar()` | `phylo_unique()` | `phylo_indep()` | `phylo_dep()` | `phylo_latent()` |
| **spatial** | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

**Column meanings** (what the keyword does to the $T \times T$
trait covariance):

- **scalar** → one variance shared across traits; the
  correlation-source structure scales the same diagonal across
  all traits. (omit) means *no term*.
- **unique** → trait-diagonal $\boldsymbol\Psi$; per-trait variances.
  Paired with `latent` to form the rank-$K$ + diagonal
  decomposition.
- **indep** → compound-symmetric trait covariance (all off-diagonal
  pairs equal); estimates one off-diagonal correlation.
- **dep** → fully unstructured $T \times T$ trait covariance,
  estimated directly with $T(T+1)/2$ free entries.
- **latent** → reduced-rank loadings $\Lambda \in \mathbb{R}^{T \times K}$
  with $K \le T$. The implied shared trait covariance is
  $\Lambda\Lambda^\top$.

**Row meanings** (the source of correlation across the grouping
factor):

- **none** → independent across grouping-factor levels; the
  keyword's covariance lives entirely on the trait axis.
- **phylo** → phylogenetic correlation on the grouping factor via
  sparse $A^{-1}$ (the tree-derived covariance matrix). Requires
  either `tree = ape::phylo` or `vcv = Cphy` as a keyword argument.
- **spatial** → spatial correlation via SPDE / GMRF precision
  (inherited from `sdmTMB`). Requires `mesh = make_mesh(...)`.

## The `latent + unique` pairing rule

The package's headline decomposition is

$$
\boldsymbol\Sigma = \boldsymbol\Lambda\boldsymbol\Lambda^\top + \boldsymbol\Psi
$$

where $\boldsymbol\Lambda$ is $T \times K$ (rank $K < T$) and
$\boldsymbol\Psi$ is the diagonal trait-unique-variance matrix
(factor-analysis / SEM convention; Bollen 1989, Mulaik 2010,
lavaan). On the public API:

- `latent(0 + trait | g, d = K)` estimates $\boldsymbol\Lambda$.
- `unique(0 + trait | g)` estimates $\boldsymbol\Psi$.

**Pairing rule**: when both keywords reference the same grouping
factor `g`, the engine combines them into the decomposition above.
Either keyword alone gives a constrained submodel:

- `latent(...)` alone → $\boldsymbol\Sigma = \boldsymbol\Lambda\boldsymbol\Lambda^\top$
  (rank-deficient; only works when $K < T$ and the diagonal can be
  zero, e.g. ordinal-probit with structural zeros).
- `unique(...)` alone → $\boldsymbol\Sigma = \boldsymbol\Psi$
  (diagonal-only; no shared trait axes).

The same pairing rule applies to `phylo_latent + phylo_unique`
and `spatial_latent + spatial_unique`.

## Long-format trait-stacked grammar

In the long form, the response column `value` holds one observation
per `(unit, trait)` pair. The fixed-effects grammar uses
`0 + trait` as the trait-specific intercept term:

```r
value ~ 0 + trait                       # T trait-specific intercepts
value ~ 0 + trait + (0 + trait):x       # T intercepts + T trait-specific x slopes
value ~ 0 + trait + x                   # T intercepts + shared x slope (rare; usually want trait-specific)
```

The `(0 + trait):x` pattern is the canonical way to give each
trait its own slope on covariate `x`. Without the `0 + trait` in
the prefix, R's contrast convention adds a reference-trait baseline
that confuses the trait-stacked interpretation.

Random effects use the same `0 + trait` convention:

```r
latent(0 + trait | site, d = 2)         # Lambda_B is T x 2
unique(0 + trait | site)                # Psi_B is T x T diagonal
```

## Default column names

`gllvmTMB()` looks for these column names by default:

| Default name | Role | Override argument |
|--------------|------|-------------------|
| `trait` | trait factor (long format) | `trait = "..."` |
| `site` | between-unit grouping (canonical for JSDM) | `unit = "..."` |
| `site_species` | within-unit grouping (two-level) | `unit_obs = "..."` |
| `species` | species axis (phylogenetic + species random effects) | `cluster = "..."` |

**Persona-active naming rule (Pat 2026-05-16)**: examples should
KEEP the explicit `unit = "..."`, `unit_obs = "..."`, `cluster = "..."`
arguments even when they match defaults, because they tell the
reader which data column plays which role. DROP only the literal
`trait = "trait"` which is pure noise when the column is named
`trait`.

## Crossed-vs-nested random-effect encoding

The `gllvmTMB` parser does NOT currently support the `(1 | g1/g2)`
slash-form for explicit nesting. Use the `lme4` convention of
**globally unique level names** to encode nesting as
crossed-with-unique-levels:

```r
# Nested: session within individual.
# Build unique session_id by combining individual + session number:
df$session_id <- factor(paste(df$individual, df$session, sep = "_"))

# Now the engine sees session_id as a crossed factor whose levels
# happen to be uniquely associated with one individual each.
gllvmTMB(
  value ~ 0 + trait +
    latent(0 + trait | individual, d = 2) +
    unique(0 + trait | individual) +
    latent(0 + trait | session_id, d = 1) +
    unique(0 + trait | session_id),
  data = df,
  unit = "individual",
  unit_obs = "session_id"
)
```

This is mathematically equivalent to the slash-form
`individual / session` when session levels are globally unique.
Articles that use this convention (e.g. `behavioural-syndromes.Rmd`)
must include a "Nested or crossed?" callout box explaining the
encoding.

## Phylogenetic axis convention

Phylogenetic keywords (`phylo_scalar`, `phylo_unique`, `phylo_indep`,
`phylo_dep`, `phylo_latent`) operate on the **species axis**. They
take one of two equivalent keyword arguments:

- `tree = ape::phylo` — pass the phylogeny object; the engine
  computes `ape::vcv(tree, corr = TRUE)` and inverts via the
  Hadfield & Nakagawa (2010) sparse $A^{-1}$ trick.
- `vcv = Cphy` — pass the precomputed correlation matrix directly.

The package-level `phylo_vcv = Cphy` argument on `gllvmTMB()` is
retained as a backward-compatibility path but is **deprecated** in
favour of the in-keyword `vcv = Cphy` argument since 0.2.0.

## Spatial axis convention

Spatial keywords (`spatial_*`) require a precomputed mesh built via
`make_mesh(df, c("lon", "lat"), cutoff = ...)`. The mesh is passed
to `gllvmTMB()` via the top-level `mesh =` argument. The SPDE /
GMRF precision approximation is the Lindgren-Rue-Lindström (2011)
construction inherited from `sdmTMB` (Anderson et al. 2025).

Spatial keywords accept the coordinate columns implicitly through
the mesh; the formula side uses `(0 + trait | coords)`:

```r
gllvmTMB(
  value ~ 0 + trait +
    spatial_unique(0 + trait | coords, mesh = mesh),
  data = df,
  mesh = mesh
)
```

## `meta_known_V()` desugaring

`meta_known_V(value, V = V)` is sugar for a specific `equalto`
random-effect block. Internally:

```r
df$obs   <- factor(seq_len(nrow(df)))   # one factor level per row
df$grp_V <- factor(rep("a", nrow(df)))  # single shared level
# meta_known_V(value, V = V) parses to:
#   equalto(0 + obs | grp_V, V)
# and the engine adds V to the residual covariance.
```

Users should supply the matrix `V` via the top-level
`known_V = V` argument when using `meta_known_V()` in the formula.
For block-diagonal within-study correlation, build `V` via
`block_V(study_id, sampling_var, rho_within)`.

## Random-effect eligibility

Currently:

- **Random intercepts** `(1 | group)`: implemented for ordinary
  groups; implemented inside the 3 × 5 keywords as the default
  random-intercept on the grouping factor.
- **Random slopes** `(0 + x | g)` or `(1 + x | g)`: **reserved**.
  Not currently parsed inside the 3 × 5 keywords. The M1 Gaussian
  completeness milestone (per ROADMAP) adds random-slope support
  for the `latent + unique` paired keywords as the first
  random-slope path. Other 3 × 5 cells get random-slope support
  one keyword at a time after M1 closes.

Random-slope design and parser details will live in
`docs/design/42-random-slopes-grammar.md` when written as part of
the M1.1 slice.

## Reserved / planned grammar extensions

These are **NOT** currently parsed. They are documented here so the
public-API surface stays open to them and so future work knows the
target shape.

- `meta_V(value, V = V)` / `meta_V(value, w = w, scale = "proportional")` —
  unification of additive and proportional sampling-variance forms;
  post-CRAN.
- `weights = w` argument on `gllvmTMB()` — glmmTMB-style row-weights;
  post-CRAN. Must coexist cleanly with `meta_known_V()` per the
  drmTMB Phase 2b discipline: `meta_known_V()` rejects non-unit
  `weights` until joint-block weighting is documented.
- `phylo_slope(...)` / `spatial_slope(...)` — phylogenetic and
  spatial random slopes; post-M1.
- `cluster × unit` nesting (e.g. study × site or class × pupil) —
  currently only crossed designs work via globally unique level
  names. True hierarchical nesting parser is post-CRAN.
- `latent_interact(0 + trait | unit, d = K, by = x)` — galamm-style
  loadings that vary as a function of a covariate; post-CRAN
  (see vision doc).

## Not in the MVP

These are **OUT of scope** for the 0.2.0 release and may or may
not enter later releases:

- Single-response distributional regression — that's `drmTMB`'s
  lane. Mixed-family multi-trait fits are in scope; single-response
  is not.
- Bayesian fits — gllvmTMB is maximum-likelihood / Laplace-
  approximation. Bayesian alternatives are `Hmsc`, `MCMCglmm`, and
  `brms`.
- REML estimation — planned post-0.2.0 as a Gaussian-only feature
  matching the `glmmTMB` / `lme4` convention (`docs/dev-log/decisions.md`
  2026-05-14 REML scope entry).
- Adaptive Gauss-Hermite quadrature (AGHQ) or variational
  approximation (VA) integrators — Laplace-only at 0.2.0
  (`docs/dev-log/audits/2026-05-15-external-audit-2-response.md`
  "stay Laplacian" decision). AGHQ for low-d binary and VA for
  high-d binary are post-CRAN candidates only if the Phase 5.5
  external validation sprint surfaces real cases.
- Zero-inflated count families on multi-trait fits. Post-CRAN.
- SPDE barrier-mesh for irregular spatial domains. Post-CRAN
  (track sdmTMB's barrier-mesh work).
- `gllvmTMB_wide(Y, ...)` matrix-in API has been demoted to a
  per-cell-weight-matrix-only path. The recommended path for all
  new code is the formula API with `traits(...)` LHS.
