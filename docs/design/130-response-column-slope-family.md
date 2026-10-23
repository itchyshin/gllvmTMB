# Design 130 — Response-column slope helper family

**Reader:** R API contributors, statistical-method developers, and reviewers
who need one authoritative contract for predictors whose coefficients vary
across response columns.
**Status:** Active grammar and model contract, 2026-08-24. The ordinary,
phylogenetic, animal, and dense-kernel helpers form the fixed-source slice.
The dedicated spatial slice now implements the same locked grammar and has
local Gaussian point-recovery, projection, alignment, and extraction evidence.
This is not evidence for the deferred non-Gaussian or interval regimes.
Design 133 reuses this exact projected-SPDE source for the bounded public
`spatial_coef(..., rho = 1)` intercept/slope basis; it does not deprecate or
alter the slope-only helper.
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

The spatial column slice therefore uses a labelled `gllvmTMBmesh` built from a
trait-level table containing exactly one finite coordinate pair for every
declared trait level, for example

```r
column_mesh <- make_mesh(
  column_locations,
  xy_cols = c("x", "y"),
  id_col = "trait"
)
```

The optional `id_col` records one character label for each projection row.
It is opt-in: ordinary `make_mesh()` calls and the shape of their returned
objects remain unchanged. `spatial_slope()` requires the mesh's `id_col` to
equal the resolved trait-column name. After label alignment, the projection is

```text
A_column: T x n_mesh.
```

Each trait must have its own unique finite coordinate pair. Missing, extra, or
duplicated trait labels and duplicated coordinate pairs fail before fitting.
An ordinary observation-aligned mesh cannot be guessed or recycled by row
count.

Alignment is label-based. The spatial gate proves that permuting the
trait-coordinate table and its labelled projection leaves the objective and
extracted `Sigma_predictor` unchanged after realignment. It also proves that
an unlabelled mesh, a missing or extra label, a duplicate label, or a
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

The implementation factorizes sparse `Q(kappa)` once and solves the `T`
right-hand sides in `A_column'`. It therefore does not materialize the full
dense mesh inverse. It forms only the required projected `T x T` covariance,
normalizes it to exact unit diagonal, and reports that `K_column`. The positive
range parameter is `kappa = exp(log_kappa_spde)` and the extractor reports the
isotropic practical range `sqrt(8) / kappa` in the supplied coordinate units.
For `P` predictors, `||` leaves exactly the `P` log-Cholesky diagonal entries
of `Sigma_predictor` free and pins all `P(P - 1) / 2` lower entries; `|` leaves
the full log-Cholesky parameterization free. This mapping depends on `P`, not
on the number of response columns `T`.

## 7. Extraction contract

All five helpers use `extract_Sigma(fit, level = "column_slope")`. The returned
object
contains:

- `Sigma`: named `P x P` `Sigma_predictor`;
- `R`: its named correlation matrix, with a stable zero-variance boundary;
- `part`: `"indep"` or `"dep"`; for `P = 1`, both bar spellings canonicalize
  to `"dep"` so the complete public extractor objects are identical;
- `predictors`: the ordered predictor names;
- `column_labels`: the declared trait levels in fitted order; and
- `source`: at least `type`, `grouping`, and `labels`, plus the kernel name,
  matrix-scale provenance, or spatial coordinate/range metadata when relevant.

For `source$type = "spatial"`, the source metadata additionally contains the
label-aligned coordinate matrix and coordinate-column names,
`coordinate_units = "as_supplied"`, fitted `kappa`, `practical_range`,
`normalization = "exact_projected_unit_diagonal"`, and the normalized
`K_column`.

The extractor reports predictor covariance, not the full `TP x TP`
coefficient covariance. A method developer reconstructs the latter as
`kronecker(K_column, Sigma)` in trait-major order. `extract_Sigma(level =
"phy")`, `"spatial"`, or another intercept-tier level must not silently return
this object.

An ordinary `slope()` term may coexist with a separate species-axis
phylogenetic covariance. In that model, `extract_Sigma(level =
"column_slope")` returns `Sigma_predictor` for the identity-linked response
columns, while `extract_Sigma(level = "phy")` returns the distinct species
phylogenetic covariance. The two extractors must never substitute for one
another. Structured column sources (`phylo_slope()`, `animal_slope()`, and
`kernel_slope()`) remain refused beside another phylogenetic tier until the
global source-harvesting path is replaced by fully term-local source objects.

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
sources, Gaussian recovery, multi-predictor kernel `||`, a custom resolved
response-column name with a numeric predictor literally named `trait`, and
historical phylogenetic/animal compatibility. The phylogenetic gate also
compares a non-identity pedigree with its equivalent dense `A` and sparse
`Ainv` inputs.
`tests/testthat/test-ordinary-column-slope-phylo-coexistence.R` proves the
two-axis comparative model: `slope(x | trait)` uses `Ainv_phy_slope = I_T`, a
predictor-only design, and the `b_phy_aug` block, while the separate
`phylo_latent(0 + trait | species, ...)` term uses the species tree and its own
random block. Both covariance extractors are exercised, all fitted gradients
are finite, and the structured-source combinations that still share global
source harvesting fail loudly.
`tests/testthat/test-spatial-column-slope.R` is the dedicated spatial gate. It
checks opt-in mesh labels without changing ordinary mesh objects; a `P = 2`,
`T = 6` diagonal parameter map; no intercept; exact agreement with an
independent projected-covariance oracle; exact unit diagonal; a finite
automatic-differentiation gradient for `log_kappa_spde`; source metadata; `P = 1`
bar identity; label-permutation invariance; malformed meshes; the Gaussian
boundary; and a small `T = 25`, `P = 2` known-DGP recovery. The local fail-closed
gate passed 39 assertions with no failures, warnings, or skips. A regression
filter covering the full response-column slope family, RHS routing, article
formal checks, and existing spatial slope tests passed 221 assertions with no
failures or warnings; six legacy recovery tests remained skipped by their own
explicit heavy-test environment gates.

Deferred and unadvertised:

- wide `traits(...)` column-predictor grammar;
- reduced-rank or `latent()` covariance among predictor coefficients;
- non-Gaussian and mixed-family response-column slopes;
- confidence intervals, bootstrap coverage, or calibrated covariance tests;
- multiple response-column slope sources in one model.

These limits do not retract the separate, older intercept-plus-slope
random-regression routes in Designs 55, 56, 60, and 64.

## 9. Repository evidence and reconciliation

- `R/brms-sugar.R::.gllvmTMB_column_slope_cols()` and
  `tests/testthat/test-phylo-column-slope-indep.R` define the shipped
  predictor-only, no-intercept basis and trait-major matrix oracle.
- `tests/testthat/test-fixed-column-slope-family.R` extends that oracle to the
  ordinary and dense-kernel sources and locks one-predictor public-object
  identity plus RHS-not-trait compatibility.
- `tests/testthat/test-ordinary-column-slope-phylo-coexistence.R` locks the
  independent response-column-slope and species-phylogeny blocks used by the
  comparative worked example.
- `R/fit-multi.R` stores a dedicated column-slope source, labels, mode, and
  predictor list; `R/extract-sigma.R` returns the current
  `level = "column_slope"` object.
- `R/mesh.R` provides the opt-in `id_col` / `row_labels` alignment contract for
  response-column coordinates without changing ordinary mesh objects.
- `src/gllvmTMB.cpp` evaluates the dedicated response-column SPDE block by
  sparse factorization and projected solves, normalizes `K_column` exactly,
  and keeps marginal predictor covariance in `Sigma_predictor`.
- `tests/testthat/test-spatial-column-slope.R` locks the spatial design,
  normalization, mapping, permutation, malformed-input, extraction, gradient,
  and small known-DGP recovery oracles.
- `R/phylo-tree-precision.R` constructs tree covariance on a correlation
  scale by default.
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
