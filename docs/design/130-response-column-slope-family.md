# Design 130 — Response-column slope helper family

**Reader:** R API contributors, statistical-method developers, and reviewers
who need one authoritative contract for predictors whose coefficients vary
across response columns.
**Status:** Active grammar and model contract, 2026-08-24. The ordinary,
phylogenetic, animal, and dense-kernel helpers are the first implementation
slice. The spatial helper has the same locked public grammar, but its
column-coordinate engine and recovery evidence remain a separate slice.
**Supersedes:** the deprecation and replacement proposals in Design 55 §6 and
Design 56 §§8, 9.6, and 10.2. Those sections remain in place as historical
records. This design does not supersede their intercept-plus-slope
random-regression contracts.

## 1. Purpose

Ecologists often regress several response columns on the same environmental
predictors and ask whether related columns change similarly along those
gradients. This design gives that question one formula family. It separates
two covariance axes that earlier slope documents sometimes blurred:

- `K_column` describes dependence among the response columns; and
- `Sigma_predictor` describes covariance among the predictor coefficients.

The helper family is public, long-format, slope-only formula sugar. It does
not add another likelihood block and it does not add a random intercept.

## 2. Locked public grammar

Every new helper has predictors on the left of the bar and the declared trait
column on the right:

```r
slope(x1 + x2 || trait)
phylo_slope(x1 + x2 | trait, tree = tree)
animal_slope(x1 + x2 | trait, pedigree = pedigree)
kernel_slope(x1 + x2 | trait, K = K, name = "environment")
spatial_slope(x1 + x2 | trait, mesh = column_mesh)
```

Here `trait` means the column named by the resolved `trait =` argument to
`gllvmTMB()`, not necessarily a literal variable called `trait`. The parser
must reject a new helper call whose right-hand side is not that declared
column. Predictors must be distinct, finite numeric columns. Transformations,
factor expansion, an intercept, and a trait indicator are outside this first
grammar.

The bar chooses predictor covariance:

| Helper spelling | Canonical expansion | Predictor covariance |
|---|---|---|
| `source_slope(x1 + ... + xP || trait, ...)` | `source_indep(0 + x1 + ... + xP | trait, ...)` | diagonal `Sigma_predictor` |
| `source_slope(x1 + ... + xP | trait, ...)` | `source_dep(0 + x1 + ... + xP | trait, ...)` | full `Sigma_predictor` |

`source_` is empty for `slope()`, and is `phylo_`, `animal_`, `kernel_`, or
`spatial_` for the four structured sources. Thus `slope()` expands to
`indep()` or `dep()`. These helpers sit beside, not inside, the canonical
5 x 3 keyword grid: the grid has five correlation sources (`none`, `animal`,
`phylo`, `spatial`, `kernel`) and three trait-covariance modes (`indep`, `dep`,
`latent`). A slope helper selects the `indep` or `dep` cell after declaring a
predictor basis; it is not a fourth mode.

For `P = 1`, `|` and `||` are identical models because a `1 x 1` full matrix
is diagonal. They must produce the same objective, parameters, and extracted
matrix, apart from harmless mode metadata. Documentation should prefer `||`
when the author wants to emphasize the absence of cross-predictor covariance.

## 3. Statistical model

Let `T` be the number of response columns and `P` the number of declared
predictors. For observation `i` of column `t`, let `x_i` be the `P`-vector of
predictor values and `b_t` the corresponding random coefficient vector. The
column-slope contribution is

```text
eta_it,column = x_i^T b_t.
```

Stack coefficients in trait-major order,

```text
b = (b_1^T, b_2^T, ..., b_T^T)^T,
```

and define

```text
b ~ N(0, K_column (x) Sigma_predictor).
```

`(x)` denotes the Kronecker product. In matrix entries,

```text
Cov(b_t,p, b_u,q) = K_column[t,u] * Sigma_predictor[p,q].
```

The `||` spelling constrains `Sigma_predictor[p,q] = 0` for `p != q`; the
single-bar spelling estimates a positive-definite full matrix. The main
formula supplies fixed response-column intercepts, usually `0 + trait`.
Neither helper expansion contains `1`, so it cannot silently add a random
intercept.

The five sources define `K_column` as follows:

| Helper | `K_column` | Required alignment |
|---|---|---|
| `slope()` | `I_T` | declared trait levels |
| `phylo_slope()` | tree-derived response-column correlation, or labelled `vcv` / `Ainv` equivalent | tip or matrix labels equal declared trait levels |
| `animal_slope()` | pedigree/additive-relatedness matrix supplied through `pedigree`, `A`, or `Ainv` | animal labels equal declared trait levels |
| `kernel_slope()` | labelled dense positive-definite `K` | row and column labels equal declared trait levels; `name` identifies the source |
| `spatial_slope()` | normalized projected SPDE correlation at response-column coordinates | exactly one coordinate pair per declared trait level; see §6 |

For user-supplied `A` and `K`, the package aligns labels but does not silently
change the scientific scale. Therefore `Sigma_predictor` is conditional on
the supplied matrix scale; the fitted object and extractor must retain that
scale provenance. Tree-derived `K_column` is correlation-scaled, consistent
with `.gllvm_phylo_tree_precision(correlation = TRUE)`.

## 4. Symbolic-to-implementation alignment

The table below is the minimum complete DGP and recovery contract. A test may
use `P = 1` for bar parity or `P = 2` for covariance-mode recovery, but it must
not omit any column of this table.

| Symbol in model | Public formula / canonical term | DGP draw | Linear-predictor contribution | Recovery extractor and truth |
|---|---|---|---|---|
| `K_column = I_T` | `slope(x1 + x2 || trait)` → `indep()`; `slope(x1 + x2 | trait)` → `dep()` | draw `B = L_K Z L_Sigma^T` with `L_K = I_T` and diagonal/full `Sigma_predictor` according to the bar | row `i,t`: `x_i^T B[t,]` | `extract_Sigma(level = "column_slope")$Sigma`; truth `Sigma_predictor`, source `ordinary` |
| labelled phylogenetic `K_column` | `phylo_slope(x1 + x2 || trait, tree = tree)` → `phylo_indep()`; single bar → `phylo_dep()` | same matrix-normal draw with `L_K L_K^T = K_column` from the tree and diagonal/full `Sigma_predictor` | same | same truth; source `phylo`, labels equal tree tips in trait order |
| labelled additive `K_column` | `animal_slope(x1 + x2 || trait, A = A)` → `animal_indep()`; single bar → `animal_dep()` | same draw with `L_K L_K^T = A` and diagonal/full `Sigma_predictor` | same | same truth; source `animal`; `A`, `Ainv`, and pedigree routes agree after alignment |
| labelled dense `K_column` | `kernel_slope(x1 + x2 || trait, K = K, name = "k")` → `kernel_indep()`; single bar → `kernel_dep()` | same draw with `L_K L_K^T = K` and diagonal/full `Sigma_predictor` | same | same truth; source `kernel`, source name `k`, supplied scale retained |
| projected SPDE `K_column(kappa)` | `spatial_slope(x1 + x2 || trait, mesh = column_mesh)` → `spatial_indep()`; single bar → `spatial_dep()` | draw on the trait-coordinate projection using normalized `K_column(kappa)` from §6 and diagonal/full `Sigma_predictor` | same | same truth on the marginal normalized scale; source `spatial`, labels equal the mesh column labels |
| `Sigma_predictor = diag(v_1, ..., v_P)` | any `||` row above | choose positive diagonal truth and draw `B` as above | same | diagonal estimate; all off-diagonals structurally zero |
| full `Sigma_predictor = L_Sigma L_Sigma^T` | any `|` row above | choose positive-definite truth with at least one nonzero off-diagonal | same | full named estimate and `R`; planted off-diagonal recovered |
| no random intercept | every helper row | simulate only `B[t,p] x_i,p`; put column intercepts in fixed `0 + trait` term | no coefficient multiplying an all-ones random-effect column | prepared design has exactly `P` columns and predictor names only |
| `P = 1` parity | `source_slope(x | trait)` and `source_slope(x || trait)` | one-column `B` draw | identical | objectives, fitted parameter, and `1 x 1` extracted `Sigma` identical |

The DGP identity `B = L_K Z L_Sigma^T`, for an i.i.d. standard-normal
`T x P` matrix `Z`, gives
`Cov(vec_trait-major(B)) = K_column (x) Sigma_predictor`. Tests must use this
ordering explicitly; a predictor-major Kronecker product is a different model.

## 5. Compatibility boundary

The pre-existing calls `phylo_slope(x | species, ...)` and
`animal_slope(x | individual, ...)`, whose right-hand side is not the declared
trait column, remain runtime-compatible. They retain their historical
group-indexed, shared-across-response interpretation. They are compatibility
behaviour, not the new teaching model, and they are not deprecated by this
design.

The parser distinguishes the routes by the resolved right-hand side:

- RHS equals the declared trait column: use the response-column contract in
  this design, including `P = 1`;
- RHS differs from the declared trait column: only the historical
  `phylo_slope()` and `animal_slope()` routes may continue;
- RHS differs for `slope()`, `kernel_slope()`, or `spatial_slope()`: fail
  loudly and show the declared trait-column spelling.

This rule intentionally supersedes the old plan to replace or remove
`phylo_slope()` and `animal_slope()` in Designs 55 and 56. New tutorials teach
the RHS-equals-trait form for response-column questions. Historical calls are
documented only in a compatibility note or in material specifically about the
old group-indexed model.

## 6. Spatial response-column coordinates and normalization

The existing observation-spatial contract builds `make_mesh()` from coordinate
rows aligned with fitted observations and stores an `n_obs x n_mesh`
projection `A_st` (`R/mesh.R`; `tests/testthat/test-mesh.R`). A response-column
spatial slope needs a different alignment: coordinates describe response
columns, not sites or observation rows.

The spatial column slice must therefore use a `gllvmTMBmesh` built from a
trait-level table containing exactly one finite coordinate pair for every
declared trait level. The mesh object must retain those trait labels. After
alignment, its projection is

```text
A_column: T x n_mesh.
```

Each trait must have its own unique finite coordinate pair. Missing, extra, or
duplicated trait labels and duplicated coordinate pairs fail before fitting.
An ordinary observation-aligned mesh cannot be guessed or recycled by row
count.

Alignment is label-based. The spatial leaf must prove that permuting the
trait-coordinate table and its labelled projection leaves `K_column`, the
objective, and extracted `Sigma_predictor` unchanged after realignment. It
must also prove that a missing label, an extra label, a duplicate label, or a
duplicated coordinate pair fails before optimization.

`make_mesh()` currently passes numeric coordinates to `fmesher` without
centering or standardizing them and warns for very large magnitudes
(`R/mesh.R`). The column route preserves that contract. Coordinate units set
the meaning of `kappa`, `cutoff`, and practical range. Users should supply an
equal-distance projection and choose one explicit unit, commonly kilometres;
the package must not silently transform degrees, metres, or kilometres.

Let

```text
Q(kappa) = kappa^4 M0 + 2 kappa^2 M1 + M2,
C_raw(kappa) = A_column Q(kappa)^(-1) A_column^T,
D(kappa) = diag(diag(C_raw(kappa))),
K_column(kappa) = D(kappa)^(-1/2) C_raw(kappa) D(kappa)^(-1/2).
```

This exact projected normalization, not the continuum approximation
`1 / (4 pi kappa^2 tau^2)`, defines the response-column correlation matrix.
Every projected marginal variance must be finite and strictly positive before
normalization; otherwise fitting fails loudly.
It gives unit diagonal at the actual column coordinates, leaves `kappa` to
describe spatial correlation range, and leaves marginal coefficient variance
in `Sigma_predictor`. Design 64 remains authoritative for observation-spatial
GMRF field scaling; this section is the distinct response-column contract.

## 7. Extraction contract

The four first-slice helpers use
`extract_Sigma(fit, level = "column_slope")`; `spatial_slope()` must use the
same level when its dedicated implementation lands. The returned object
contains:

- `Sigma`: named `P x P` `Sigma_predictor`;
- `R`: its named correlation matrix, with a stable zero-variance boundary;
- `part`: `"indep"` or `"dep"`; for `P = 1`, both bar spellings canonicalize
  to `"dep"` so the complete public extractor objects are identical;
- `predictors`: the ordered predictor names;
- `column_labels`: the declared trait levels in fitted order; and
- `source`: at least `type`, `grouping`, and `labels`, plus the kernel name,
  matrix-scale provenance, or spatial coordinate/range metadata when relevant.

The extractor reports predictor covariance, not the full `TP x TP`
coefficient covariance. A method developer reconstructs the latter as
`kronecker(K_column, Sigma)` in trait-major order. `extract_Sigma(level =
"phy")`, `"spatial"`, or another intercept-tier level must not silently return
this object.

## 8. Validation and scope boundary

The first admission is long-format Gaussian point estimation. Required tests
cover parser expansion, source-label alignment, `P = 1` bar parity, `P = 2`
diagonal and full recovery, trait-major Kronecker ordering, no random
intercept, extractor labels, malformed predictors, and incompatible RHS or
source matrices. Existing evidence in
`tests/testthat/test-phylo-column-slope-indep.R` and
`tests/testthat/test-phylo-slope-rhs-routing.R` establish the initial
phylogenetic model and the historical RHS-routing boundary; new source-family
tests extend that evidence rather than reinterpret it.
`tests/testthat/test-fixed-column-slope-family.R` is the first fixed-source
alignment gate: it checks the ordinary trait-major design, one-predictor bar
identity, dense-kernel permutation invariance and scale metadata, malformed
sources, Gaussian recovery, and historical phylogenetic/animal compatibility.

Deferred and unadvertised:

- wide `traits(...)` column-predictor grammar;
- reduced-rank or `latent()` covariance among predictor coefficients;
- non-Gaussian and mixed-family response-column slopes;
- confidence intervals, bootstrap coverage, or calibrated covariance tests;
- multiple response-column slope sources in one model; and
- the spatial helper until its trait-coordinate projection, normalization,
  recovery, and extractor metadata pass their own gates.

These limits do not retract the separate, older intercept-plus-slope
random-regression routes in Designs 55, 56, 60, and 64.

## 9. Repository evidence and reconciliation

- `R/brms-sugar.R::.gllvmTMB_column_slope_cols()` and
  `tests/testthat/test-phylo-column-slope-indep.R` define the shipped
  predictor-only, no-intercept basis and trait-major matrix oracle.
- `tests/testthat/test-fixed-column-slope-family.R` extends that oracle to the
  ordinary and dense-kernel sources and locks one-predictor public-object
  identity plus RHS-not-trait compatibility.
- `R/fit-multi.R` stores a dedicated column-slope source, labels, mode, and
  predictor list; `R/extract-sigma.R` returns the current
  `level = "column_slope"` object.
- `R/phylo-tree-precision.R` constructs tree covariance on a correlation
  scale by default.
- `R/mesh.R` shows that mesh coordinates are finite numeric values used in
  their supplied units, and that the present projection is row-aligned.
- Design 64 derives the existing observation-spatial SPDE normalization; it
  does not define response-column coordinates.
- Designs 55 and 56 proposed deprecating slope helpers in favour of augmented
  intercept-plus-slope keywords. Current runtime behaviour and this locked
  family contract reject that replacement. Their history remains useful, but
  their deprecation sections are no longer normative.

## References

Lindgren F, Rue H, Lindström J (2011). An explicit link between Gaussian
fields and Gaussian Markov random fields: the stochastic partial differential
equation approach. *Journal of the Royal Statistical Society: Series B*, 73,
423–498.
