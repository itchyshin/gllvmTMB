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

Use **four** status words consistently across all documentation,
NEWS entries, and articles. The four-state system separates parser
support from end-to-end verification:

- **covered**: implementation, focused tests, and a row in
  `docs/design/35-validation-debt-register.md` confirming
  evidence. Safe to advertise in README / NEWS / articles.
- **claimed**: the parser accepts the syntax and `gllvmTMB()`
  runs without error on a tiny example. **Not yet validated
  end-to-end.** Phase 0B verification work moves each `claimed`
  row to `covered` or downgrades it. **Do not advertise `claimed`
  rows as features** in user-facing prose.
- **reserved**: parsed or reserved as public grammar, but rejected
  by `gllvmTMB()` until the likelihood / extractor / tests exist.
- **planned**: shown only to explain the roadmap; not parsed yet.

> **Why a 'claimed' state exists.** Phase 0A writes this design
> doc honestly: most current syntax is `claimed` because the
> Phase 1c article-port crisis (2026-05-15) showed that "parser
> accepts it" does not mean "end-to-end works". Phase 0B is the
> phase that walks every `claimed` row to one of `covered`
> (verified end-to-end with a smoke-test file path) or
> `reserved` (the parser accepts it but the engine fails or the
> extractor is broken; we downgrade until fixed) with test
> evidence. Until Phase 0B closes, treat `claimed` rows as
> **promissory notes**, not features.
>
> **Promotion criterion** (what walks `claimed` → `covered`):
> a passing test in `tests/testthat/` that exercises the
> syntax + verifies `fit$opt$convergence == 0L` + a non-trivial
> `extract_Sigma()` (or other extractor) output, plus a row in
> `docs/design/35-validation-debt-register.md` linking to that
> test file with status `covered`. Anything less keeps the row
> at `claimed`.
>
> **Vocabulary note**: this status map (parser syntax) uses
> `covered / claimed / reserved / planned`. The separate
> validation-debt register (capability validation) uses
> `covered / partial / opt-in / blocked` (drmTMB convention).
> Different artefacts, different vocabularies, both intentional.

| Syntax | Current status | Notes |
| --- | --- | --- |
| `gllvmTMB(value ~ ..., data = df_long)` | **covered** | Canonical long-format entry point. One row per `(unit, trait)`. Test evidence: `tests/testthat/test-canonical-keywords.R`, `test-keyword-grid.R` (validation-debt register FG-02; Phase 0B promotion 2026-05-16). |
| `gllvmTMB(traits(t1, t2, ...) ~ ..., data = df_wide)` | **covered** | Wide-format entry point. The `traits(...)` LHS marker triggers internal pivot to long; long+wide `logLik` agreement is part of the contract. Test evidence: `test-traits-keyword.R`, `test-wide-weights-matrix.R` (validation-debt register FG-01, FG-03; Phase 0B promotion 2026-05-16). |
| `gllvmTMB_wide(Y, ...)` | **removed in 0.2.0** | Matrix-in entry point. Removed per maintainer 2026-05-16 decision; use `gllvmTMB(traits(...) ~ ..., data = df_wide)` instead. |
| `0 + trait` and `(0 + trait):x` | **covered** | Long-form trait-stacked fixed-effect grammar. Test evidence: `test-stage1-stacked-fixed-effects.R`, `test-canonical-keywords.R` (via validation-debt register FG-02; Phase 0B promotion 2026-05-16). |
| `latent(0 + trait \| g, d = K)` | **covered** | Reduced-rank loadings for $T$ traits across grouping factor `g`, rank $K \le T$. Test evidence: `test-stage2-rr-diag.R`, `test-keyword-grid.R` (validation-debt register FG-04; Phase 0B promotion 2026-05-16). |
| `unique(0 + trait \| g)` | **covered** | Trait-diagonal $\boldsymbol\Psi$ on grouping factor `g`. Test evidence: `test-stage2-rr-diag.R`, `test-cross-sectional-unique.R` (validation-debt register FG-05; Phase 0B promotion 2026-05-16). |
| `latent + unique` paired | **covered** | The decomposition $\boldsymbol\Sigma = \boldsymbol\Lambda\boldsymbol\Lambda^\top + \boldsymbol\Psi$. Test evidence: `test-stage2-rr-diag.R`, `test-mixed-response-sigma.R` (validation-debt register FG-06; Phase 0B promotion 2026-05-16). |
| `indep(0 + trait \| g)` | **covered** | Compound-symmetric trait covariance (all off-diagonals equal). Test evidence: `test-stage3-propto-equalto.R` (Gaussian) + `test-formula-grammar-smoke.R` (binomial) (validation-debt register FG-07; Phase 0B.2 promotion 2026-05-16). |
| `dep(0 + trait \| g)` | **covered** | Fully unstructured trait covariance estimated directly. Test evidence: `test-stage3-propto-equalto.R` (Gaussian) + `test-formula-grammar-smoke.R` (Poisson) (validation-debt register FG-08; Phase 0B.2 promotion 2026-05-16). |
| `(omit)` ↔ scalar covariance | **covered** | Omitting the `unique`/`indep`/`dep` slot means *no trait-specific term*; only the keyword's correlation source contributes. Test evidence: `test-stage2-rr-diag.R` (`rr() alone matches glmmTMB`), `test-canonical-keywords.R` (`latent()`-only fits without diagonal pairing) (Phase 0B.3 promotion 2026-05-16 — the omit cell is exercised whenever `latent()` is used without `unique()`/`indep()`/`dep()`). |
| `phylo_latent(species, d = K, tree = tree)` | **covered** | Reduced-rank phylogenetic loadings using sparse $A^{-1}$. Test evidence: `test-stage35-phylo-rr.R`, `test-phylo-q-decomposition.R` (validation-debt register PHY-02 paired form; Phase 0B promotion 2026-05-16). |
| `phylo_unique(species, tree = tree)` | **covered** | Trait-diagonal $\boldsymbol\Psi_\text{phy}$ scaled by phylogenetic covariance. Test evidence: `test-stage35-phylo-rr.R`, `test-phylo-q-decomposition.R` (validation-debt register PHY-02 paired form; Phase 0B promotion 2026-05-16). |
| `phylo_scalar(species, vcv = Cphy)` | **covered** | Single trait-scalar phylogenetic random effect; the simplest phylogenetic mixed-model form. Test evidence: `test-stage35-phylo-rr.R` + `test-formula-grammar-smoke.R` (dense-vcv path) (validation-debt register PHY-04; Phase 0B.2 promotion 2026-05-16). |
| `phylo_indep` / `phylo_dep` | **covered** | Compound-symmetric and unstructured phylogenetic trait covariance. Test evidence: `test-stage35-phylo-rr.R` + `test-formula-grammar-smoke.R` (both forms) (validation-debt register PHY-05; Phase 0B.2 promotion 2026-05-16). |
| `spatial_latent(0 + trait \| sites, mesh = mesh)` or `spatial_latent(0 + trait \| sites, coords = c("lon", "lat"))` and siblings | **covered** | Spatial analogues of the phylo keywords. Grouping factor is `sites`; spatial geometry supplied via either `mesh = make_mesh(...)` or `coords = c("lon", "lat")` (engine builds the mesh internally). See "Spatial axis convention" below. Test evidence: `test-spatial-latent-recovery.R` (spatial_latent), `test-stage4-spde.R` (spatial_unique), `test-formula-grammar-smoke.R` (spatial_indep, spatial_dep, spatial_scalar) (validation-debt register SPA-03, SPA-04; Phase 0B.2 promotion 2026-05-16). |
| `meta_V(value, V = V)` | **covered** | Known sampling covariance, desugars to `equalto(0 + obs \| grp_V, V)`. Pass `known_V = V` to `gllvmTMB()` alongside. Test evidence: `test-formula-grammar-smoke.R` (single-V additive form) + `test-block-V.R` (block-V form via `block_V()` helper) (validation-debt register MET-01, MET-02; Phase 0B.4 promotion 2026-05-16). The legacy `meta_known_V(value, V = V)` is retained as a deprecated alias; both names desugar identically in the parser. See "Meta-analysis keyword" below for the rename history. |
| `block_V(study, sampling_var, rho_within)` helper | **covered** | Builds the standard compound-symmetric block-diagonal `V` for within-study correlation. Test evidence: `test-block-V.R` (validation-debt register MET-02; Phase 0B promotion 2026-05-16). |
| `(1 \| group)` ordinary random intercept | **covered** | Pass-through to `glmmTMB`-style random intercept; orthogonal to the 3 × 5 keyword grid. Test evidence: `test-multi-random-intercepts.R` (validation-debt register RE-01; Phase 0B promotion 2026-05-16). |
| `(1 + x \| g)` ordinary random slope | **reserved** | Parser does not accept random slopes inside the 3 × 5 keywords yet. Planned for M1 (Gaussian completeness). |
| `(1 \| g1/g2)` slash-form nested random effects | **rejected** | Not parsed. Use globally unique level names instead (see "Crossed-vs-nested" below). |
| `latent(0 + trait \| g) + lambda_constraint = list(B = M)` | **covered (Gaussian)** | Confirmatory factor analysis on the latent loadings; pins specific entries of $\boldsymbol\Lambda$. Test evidence: `test-lambda-constraint.R` asserts pinned-entry values within `1e-8` tolerance for diagonal-pin, off-diagonal-pin-to-zero, off-diagonal-pin-to-non-zero, W-level, and simultaneous B+W pin cases (validation-debt register LAM-01, LAM-02; Phase 0B.3 promotion 2026-05-16). Phase M2 verifies on binary (LAM-03 stays partial until M2.3). |
| `suggest_lambda_constraint(fit)` | **covered (Gaussian)** | Helper that recommends constraint matrices. Test evidence: `test-suggest-lambda-constraint.R` asserts the helper returns well-typed `T x d` matrices with correct upper-triangle pinning, dimension, row/column names, and `usage_hint` for `lower_triangular` and `pin_top_one` conventions across `K = 1, 2, 3` (validation-debt register LAM-04 Gaussian regime; Phase 0B.3 promotion 2026-05-16). Phase M2 verifies on binary at $n_\text{items} \in \{10, 20, 50\}$, $d \in \{1, 2, 3\}$ (LAM-04 binary stays partial until M2.4). |
| `meta_V(value, w = w, scale = "proportional")` | **planned (post-CRAN)** | Unification of known-additive and proportional sampling-variance forms per Nakagawa 2022 EcoLetters. See vision doc "Planned extensions". |
| `weights = w` argument | **planned (post-CRAN)** | glmmTMB-style row-weights, separate from `meta_V()`. See vision doc "Planned extensions". |

**Persona-active engagement on this table:** Boole owns the column
"Current status" — every change to the column requires a Boole
review. Rose owns cross-checking each row against
`docs/design/35-validation-debt-register.md`. Curie owns turning
`claimed` rows into `covered` rows in Phase 0B by writing the
backing smoke tests.

## Two data shapes

`gllvmTMB` accepts both data shapes through a single entry point:
`gllvmTMB()`. The long form is canonical (one row per
`(unit, trait)`); the wide form is a pivot-then-fit convenience
triggered by the `traits(...)` LHS helper. Both produce
byte-identical log-likelihoods. **Both stay in the public API**
(maintainer 2026-05-16 decision B: keep both, pair them
side-by-side in articles).

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
Pairs of keywords (`latent + unique`) read literally: the right-
hand side lists trait-by-trait covariance pieces.

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

### Removed: `gllvmTMB_wide(Y, ...)` matrix-in API

The legacy matrix-in entry point `gllvmTMB_wide(Y, ...)` is
**removed from the public API in 0.2.0** (maintainer 2026-05-16
decision). Users with matrix-format data should pivot to a wide
data frame and call `gllvmTMB(traits(...) ~ ..., data = df_wide)`.

(Migration helper for legacy users may be considered post-CRAN
if external feedback shows persistent matrix-first workflows.)

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
  (inherited from `sdmTMB`). Requires `mesh = make_mesh(...)`
  passed as a keyword argument.

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

`gllvmTMB()` looks for these column names by default in long format:

| Default column name | Role | Override argument |
|---------------------|------|-------------------|
| `trait` | trait factor (long format) | `trait = "..."` |
| `site` | between-unit grouping (canonical for JSDM) | `unit = "..."` |
| `site_species` | within-unit grouping (two-level) | `unit_obs = "..."` |
| `species` | species / cluster axis | `cluster = "..."` |

All four arguments tell the engine which data column plays which
semantic role. The engine ships with sensible defaults (JSDM-style
`site` / `site_species` / `species` / `trait`), but real-world
data rarely matches those names — a behavioural-ecology study has
column `behavior`, a meta-analysis has `outcome`, a psychometric
study has `item`, an evolutionary study has `measurement`, etc.

### `trait =` argument is long-format only

In **long format**, the `trait =` argument names the column that
holds the trait factor. Default is `"trait"`; override when the
column has a different name:

```r
# Long format with non-default trait column:
gllvmTMB(
  response ~ 0 + behavior + (0 + behavior):env +
    latent(0 + behavior | individual, d = 2) +
    unique(0 + behavior | individual),
  data = df_long,
  trait = "behavior",
  unit  = "individual"
)
```

In **wide format**, the `traits(t1, t2, ...)` LHS helper *is* the
trait spec — the engine pivots internally and generates a `trait`
factor column with levels `t1, t2, ...`. **No `trait =` argument
is needed (or accepted) in wide format**; the LHS marker does the
job:

```r
# Wide format (no trait = argument; traits() LHS is the spec):
gllvmTMB(
  traits(boldness, exploration, aggression) ~ 1 + env +
    latent(1 | individual, d = 2) +
    unique(1 | individual),
  data = df_wide,
  unit = "individual"
)
```

The two paths reach the same engine through the same internal long
format. Both produce byte-identical log-likelihoods (the long+wide
agreement contract — `morphometrics.Rmd` pattern).

### Persona-active naming rule (Pat + Ada 2026-05-16)

Examples KEEP all four arguments explicitly **even when they match
defaults**, because they tell the reader which data column plays
which role. The rule applies **uniformly** to `trait`, `unit`,
`unit_obs`, `cluster` — no special case for any of them.

**Why explicit always**: a reader who doesn't know the defaults
(most readers) gets the role-to-column mapping at a glance. Verbose
but legible. The two-line cost of writing four explicit arguments
is repaid every time someone reads the example without having to
look up the function signature.

### Example variety: trait-column variants

Articles should show varied trait-column names across the worked-
example roster to make the API feel real:

| Article | Trait column | Reason |
|---------|-------------|--------|
| `morphometrics.Rmd` | `trait` (default) | Generic 5-trait body-measurement example; default name fits. |
| `joint-sdm.Rmd` | `species` (overridden as `trait =`)* | JSDM trait axis is actually species columns. |
| `behavioural-syndromes.Rmd` | `behavior` | Behavioural ecology phrasing. |
| `psychometrics-irt.Rmd` | `item` | Psychometric phrasing. |
| `phylo-spatial-meta-analysis.Rmd` | `outcome` | Meta-analytic effect-size phrasing. |
| `mixed-response.Rmd` | `measurement` or `kind` | Mixed-family domain phrasing. |

\* In JSDM the trait axis literally is species; the data column
might still be named `species` and the formula uses
`0 + species + (0 + species):env`. This is a naming clash with
the `cluster` slot (also `species` by default) — JSDM articles
must call this out explicitly to avoid reader confusion.

## Unit, unit_obs, and cluster: crossed vs nested

`gllvmTMB` distinguishes three grouping factors with different
relationship rules (maintainer 2026-05-16 ratification):

- **`unit`** is the between-unit grouping factor (default name
  `site`; rename via `unit = "..."`). Examples: site, individual,
  study, person.
- **`unit_obs`** is the within-unit grouping factor (default name
  `site_species`; rename via `unit_obs = "..."`). Examples:
  site_species (within-site row), session_id (within-individual
  observation), effect_id (within-study row).
- **`cluster`** is the cluster axis (default name `species`;
  rename via `cluster = "..."`). Used by phylogenetic keywords
  (`phylo_*`) and species-axis random effects. Examples: species,
  family (taxonomic), item (psychometric).

**Relationship rules:**

| Relationship | Required? | Why |
|--------------|-----------|-----|
| `unit` ↔ `unit_obs` | **MUST be nested** | `unit_obs` represents observations *within* a `unit`. Every `unit_obs` level corresponds to exactly one `unit` level. Encoded as crossed-with-globally-unique-levels (see next section). |
| `unit` ↔ `cluster` | **may be crossed** | `cluster` (species, item) is a separate axis from `unit` (site, person). A species can occur at many sites; an item can be answered by many people. |
| `cluster` ↔ `unit_obs` | **may be crossed** | A within-unit observation indexes both `unit_obs` and the cluster axis (e.g. a `site_species` row indexes a site × species pair; an `effect_id` row indexes a study × outcome pair). |

This is why the canonical JSDM example uses `unit = "site"`,
`unit_obs = "site_species"`, `cluster = "species"`: site contains
its site_species observations (nested); species cross with sites
(crossed); each site_species row indexes one (site, species)
combination.

## Crossed-vs-nested random-effect encoding

The `gllvmTMB` parser does NOT support the `(1 | g1/g2)`
slash-form for explicit nesting. **This is a deliberate exclusion**
(maintainer 2026-05-16). Use the `lme4` convention of **globally
unique level names** to encode the `unit` ↔ `unit_obs` nesting:

```r
# Nested: session within individual.
# Build unique session_id by combining individual + session number:
df$session_id <- factor(paste(df$individual, df$session, sep = "_"))

# Now the engine sees session_id as a factor whose levels are
# uniquely associated with one individual each.
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
`phylo_dep`, `phylo_latent`) operate on the **cluster axis**
(default column name `species`; rename via `cluster = "..."`).
They take one of two equivalent keyword arguments:

- `tree = ape::phylo` — pass the phylogeny object; the engine
  computes `ape::vcv(tree, corr = TRUE)` and inverts via the
  Hadfield & Nakagawa (2010) sparse $A^{-1}$ trick.
- `vcv = Cphy` — pass the precomputed correlation matrix directly.

The package-level `phylo_vcv = Cphy` argument on `gllvmTMB()` is
retained as a backward-compatibility path but is **deprecated** in
favour of the in-keyword `vcv = Cphy` argument since 0.2.0.

```r
gllvmTMB(
  value ~ 0 + trait +
    phylo_latent(species, d = 1, tree = tree) +
    phylo_unique(species, tree = tree),
  data = df,
  cluster = "species"
)
```

## Spatial axis convention

Spatial keywords (`spatial_scalar`, `spatial_unique`, `spatial_indep`,
`spatial_dep`, `spatial_latent`) operate on a **sites grouping
factor** with the spatial geometry supplied via either a
precomputed mesh or coordinate columns. The canonical form
(maintainer 2026-05-16 ratification) is:

```r
# With a precomputed mesh:
spatial_unique(0 + trait | sites, mesh = mesh)

# Or with coordinate columns (engine builds the mesh internally):
spatial_unique(0 + trait | sites, coords = c("lon", "lat"))
```

The `sites` grouping factor identifies which observations share a
spatial location. The `mesh` argument is built via
`make_mesh(df, c("lon", "lat"), cutoff = ...)`. The SPDE / GMRF
precision approximation is the Lindgren-Rue-Lindström (2011)
construction inherited from `sdmTMB` (Anderson et al. 2025).

The earlier syntax `spatial_unique(0 + trait | coords)` (with
`coords` as the grouping-factor name) is **deprecated** in favour
of the new form, which puts the grouping factor and the spatial
geometry argument on equal footing with the rest of the keyword
grammar (every keyword has a `g` grouping factor; spatial keywords
additionally take `coords =` or `mesh =`).

## Meta-analysis keyword: `meta_V` (renamed from `meta_known_V`)

Maintainer 2026-05-16: the current `meta_known_V(value, V = V)` is
being **renamed to `meta_V(value, V = V)`** as part of this design
revision (NOT post-CRAN). The renamed keyword opens the door to a
future `scale = "proportional"` mode that unifies the additive
known-V form with the multiplicative weighted-regression form per
Nakagawa 2022 EcoLetters (see vision doc "Planned extensions").

```r
# Current name (deprecated alias):
meta_known_V(value, V = V)

# New canonical name:
meta_V(value, V = V)            # additive known-V (current behaviour)
meta_V(value, V = V, scale = "known")  # explicit; equivalent

# Future post-CRAN extension:
# meta_V(value, w = w, scale = "proportional")
```

Both names parse the same way internally (the keyword desugars to
`equalto(0 + obs | grp_V, V)`). `meta_known_V()` is retained as a
deprecated alias with a soft-deprecation warning starting 0.2.0.

Users supply the matrix `V` via the top-level `known_V = V`
argument when using the additive form. For block-diagonal
within-study correlation, build `V` via
`block_V(study_id, sampling_var, rho_within)`.

## Random-effect eligibility

Currently:

- **Random intercepts** `(1 | group)`: claimed inside the 3 × 5
  keywords as the default random-intercept on the grouping
  factor.
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

- `meta_V(value, w = w, scale = "proportional")` — proportional
  / multiplicative sampling-variance mode (post-CRAN).
- `weights = w` argument on `gllvmTMB()` — glmmTMB-style row-
  weights; post-CRAN. Must coexist cleanly with `meta_V(scale =
  "known")` per the drmTMB Phase 2b discipline.
- `phylo_slope(...)` / `spatial_slope(...)` — phylogenetic and
  spatial random slopes; post-M1.
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
- `gllvmTMB_wide(Y, ...)` matrix-in API. **Removed in 0.2.0**
  per maintainer 2026-05-16 decision. The formula API with
  `traits(...)` LHS is the recommended path.

## Cross-references

- `docs/design/00-vision.md` — package vision, "Planned extensions"
  section names `meta_V` and `weights = w` as architectural intents
  this grammar leaves room for.
- `docs/design/35-validation-debt-register.md` (forthcoming, Phase
  0A step 7) — every `claimed` row in this status map gets a
  corresponding register row with evidence column.
- `docs/dev-log/decisions.md` 2026-05-14 notation reversal entry
  — Greek $\boldsymbol\Psi$ for the diagonal trait-unique-variance
  matrix.
- AGENTS.md Design Rule #3 — no formula-grammar change without
  updating this document first.
