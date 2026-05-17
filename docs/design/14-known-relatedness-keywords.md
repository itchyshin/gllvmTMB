# Design Doc 14 — Known-relatedness keyword families

**Status**: Ratified 2026-05-17 (drmTMB team review + maintainer dispatch).
**Slice**: M2.8 (delivered the `animal_*` keyword family per this contract).
**Maintained by**: Boole + Gauss + Rose (formula grammar + engine + audit).
**Reviewers**: Fisher (statistical inference), Pat (reader UX),
Darwin (audience), Jason (sister-package landscape), Ada (orchestration).
**Cross-refs**:
[`01-formula-grammar.md`](01-formula-grammar.md) (4×5 grid contract);
[`04-random-effects.md`](04-random-effects.md);
[`00-vision.md`](00-vision.md) item 2 (phylogenetic + animal GLLVM
unification);
[`04-sister-package-scope.md`](04-sister-package-scope.md) (MCMCglmm
parallel); [`35-validation-debt-register.md`](35-validation-debt-register.md).

## 1. Goal

The gllvmTMB formula grammar models structured random effects whose
covariance is a **known relatedness matrix** \eqn{\mathbf A}. The
three sources of \eqn{\mathbf A} we currently support are:

1. **Phylogenetic** — \eqn{\mathbf A} is the species-level
   phylogenetic VCV derived from an evolutionary tree (Hadfield 2010;
   Nakagawa & Santos 2012).
2. **Spatial** — \eqn{\mathbf A^{-1}} is the sparse SPDE / GMRF
   precision matrix derived from a mesh of geographic coordinates
   (Lindgren, Rue, Lindström 2011).
3. **Animal** (NEW, M2.8) — \eqn{\mathbf A} is the additive-genetic
   relatedness matrix derived from a pedigree (Henderson 1976) or
   provided directly by the user.

This design doc records the team's decisions about the **public
API**, the **A-vs-V naming boundary**, and the **scope of `animal_*`**.

## 2. Why three keyword families instead of one generic `relmat_*()`

The drmTMB-team review (2026-05-17) considered routing all known-
relatedness models through a single generic `phylo_*(species, vcv = K)`
or a new `relmat_*(group, K = K)` keyword. The team converged on
**three biology-visible families** (`phylo_*`, `spatial_*`, `animal_*`)
with shared internals but distinct public names. Reasons:

- **Reader UX (Pat)**: scientists pick keywords by their biological
  meaning, not by mathematical abstraction. A QG researcher
  expects `animal_model(pedigree = ped)`, not `relmat(group, K = A)`.
  A field ecologist expects `phylo_*` to talk about evolutionary
  history. A spatial statistician expects `spde` / `spatial_*`.
- **Audience (Darwin)**: keyword names anchor users in their
  literature. `animal_*` keywords map directly to the MCMCglmm
  `animal_model` paradigm; `phylo_*` to comparative phylogenetics;
  `spatial_*` to species distribution modelling.
- **Overpromise prevention (Rose)**: separate keywords let articles
  and validation-debt rows say "the animal-model surface is
  validated against pedigrees of size N at family F" without
  blurring into "the spatial surface is validated at mesh size M".
  One keyword family = one validation lane.
- **Sister-package precedent (Jason)**: MCMCglmm's `pedigree`
  argument accepts both pedigrees AND phylo trees because the
  engine treats them as the same mathematical object. brms uses
  `gr(..., cov = K)` as the generic. We sit BETWEEN those:
  named families publicly, single engine path internally.

A future low-level escape hatch (`relmat_*()` or `knownvcv_*()`) for
the rare case of a non-biological relatedness matrix is **deferred**.
For v0.2.0, the answer is: pass any known matrix via
`phylo_*(species, A = K)` — the keyword name is biology-flavoured
but the math is fully generic.

`user_*()` was considered and rejected (Boole + Jason: "too vague").

## 3. The A-vs-V naming boundary

**Rule (Rose, ratified 2026-05-17): A for relatedness, V for
sampling variance.** Do not blur.

| Symbol | Meaning | Keywords / args |
|---|---|---|
| **A** | Known relatedness covariance matrix (\eqn{n \times n}). Population-genetics convention. | `phylo_*(..., A = A)`, `animal_*(..., A = A)`, `spatial_*` (via mesh + parameters) |
| **Ainv** | Sparse precision matrix (inverse of A). For pedigree + tree, Ainv is sparse and structured. | `phylo_*(..., Ainv = Ainv)`, `animal_*(..., Ainv = Ainv)` |
| **pedigree** | Three-column data frame (`id`, `sire`, `dam`); converted to A internally via [pedigree_to_A()]. | `animal_*(..., pedigree = ped)` (only animal family) |
| **V** | **Sampling variance** — the known measurement-error variance in **meta-analysis**. Reserved for `meta_known_V(value, V = vi_or_V)`. | `meta_known_V(value, V = V)` |

The boundary matters because population geneticists, comparative
biologists, and meta-analysts use overlapping but distinct
notation. Conflating A and V invites misinterpretation
("V is the same as A? — but A is N×N positive-definite, V is
diagonal-or-block-diagonal sampling variance from a meta-analysis").
The validation-debt register's MET-* (meta-analysis) and ANI-*
(animal model) rows reflect this lane separation.

**Soft-deprecation plan for legacy `phylo_*(vcv = ...)`**: the
existing `tree =` / `vcv =` arguments on `phylo_*()` keep working
through v0.3.0. A `lifecycle::deprecate_soft()` note suggests
`A = ` / `Ainv = ` aliases for forward compatibility with the
animal_* + spatial_* convention. This is **a separate small PR**
(deferred from M2.8 to keep this slice focused on the new family).

## 4. The 4×5 covariance keyword grid

After M2.8 the grid is **4 sources × 5 modes**:

|         | scalar         | unique         | indep          | dep         | latent         |
|---------|----------------|----------------|----------------|-------------|----------------|
| none    | (omit)         | `unique()`     | `indep()`      | `dep()`     | `latent()`     |
| **animal** | `animal_scalar()` | `animal_unique()` | `animal_indep()` | `animal_dep()` | `animal_latent()` |
| phylo   | `phylo_scalar()` | `phylo_unique()` | `phylo_indep()` | `phylo_dep()` | `phylo_latent()` |
| spatial | `spatial_scalar()` | `spatial_unique()` | `spatial_indep()` | `spatial_dep()` | `spatial_latent()` |

Per pedagogical zoom-out: **individual** (animal pedigree) →
**species** (phylogeny) → **geography** (spatial). Animal sits at
the top of the table as the finest-grained relatedness.

Plus the **random-slope keywords** alongside the grid:
`phylo_slope(x | species)`, `animal_slope(x | id)` (and spatial
random slopes if/when they land in v0.3.0).

## 5. Implementation: `animal_*` is sugar over `phylo_*`

Per Gauss's review: **no new TMB likelihood is needed.** The engine
already consumes a precision matrix and log-determinant for the
phylo/spatial-style latent fields. `animal_*` is a pure sugar
layer on top of the existing `phylo_*` canonical-rewrite path:

```
animal_scalar(id, pedigree = ped)            # user formula
  → phylo(id, vcv = pedigree_to_A(ped))      # rewrite_canonical_aliases pass 1
  → propto(0 + id | trait,
           pedigree_to_A(ped))               # desugar_brms_sugar pass 2
  → engine: rank-1 propto with given vcv     # parse_covstruct_call
```

The pedigree → A conversion happens during `parse_covstruct_call`'s
`eval(extra, envir = formula_env)` step. `pedigree_to_A()` is
exported so users can compute and inspect A directly. The function
implements Henderson's (1976) recursive formula and is cubic-time;
for pedigrees of \eqn{n > 5000} a sparse-`Ainv` direct engine path
is a v0.3.0 follow-up.

**Byte-equivalence**: for any pedigree → A conversion, all five grid
keywords satisfy

```r
animal_X(id, pedigree = ped)  ≡  animal_X(id, A = pedigree_to_A(ped))
                              ≡  phylo_X(id, vcv = pedigree_to_A(ped))
```

(verified at `tests/testthat/test-animal-keyword.R` — 17 PASS · 1 SKIP).

## 6. Argument convention per keyword family

| Family | Position 1 | Named args (relatedness input) | Other |
|---|---|---|---|
| `phylo_*` | bare `species` (or bar-form for `_indep`/`_dep`/`_slope`) | `tree = phy` OR `vcv = C` OR **`A = A`** OR **`Ainv = Ainv`** (`A` / `Ainv` aliases shipped 2026-05-17) | `d = K` on `_latent` |
| `spatial_*` | bar-form `0 + trait \| coords` | `mesh = mesh` (SPDE) | `d = K` on `_latent` |
| `animal_*` | bare `id` (or bar-form for `_indep`/`_dep`/`_slope`) | `pedigree = ped` OR `A = A` OR `Ainv = Ainv` | `d = K` on `_latent` |

## 7. Test contract

| Capability | Test file | What's pinned |
|---|---|---|
| `pedigree_to_A()` Henderson formula sanity | `test-animal-keyword.R` (1-2) | A_ii = 1 + F_i; full-sib A = 0.5; parent-offspring A = 0.5; founder pairs A = 0; topology error |
| `animal_*(pedigree=)` ≡ `phylo_*(vcv = A)` byte-equivalence | `test-animal-keyword.R` (3-7) | logLik agreement to 1e-6 on `animal_scalar`, `_unique`, `_indep`, `_dep`, `_latent` |
| Three input forms agree | `test-animal-keyword.R` (8) | `animal_scalar(pedigree=)` ≡ `(A=)` ≡ `(Ainv=)` |
| `nadiv::makeAinv()` cross-check | `test-animal-keyword.R` (9) | gracefully skip if `nadiv` not installed; otherwise A agrees within 1e-8 |

## 8. Scope boundary — what's NOT in M2.8

- **No engine work.** TMB template untouched.
- **Phylo soft-deprecate (`vcv =` → `A =` / `Ainv =`)** — shipped
  2026-05-17 as a small follow-up PR (M2.8b). All 5 `phylo_*`
  grid keywords (`phylo_scalar`, `_unique`, `_indep`, `_dep`,
  `_latent`) accept `A =` and `Ainv =` aliases byte-equivalently
  with `vcv =`. Existing `phylo_*(vcv = ...)` continues to work
  unchanged.
- **No `relmat_*` / `user_*` keyword.** Skipped per §2; documented
  on `phylo_*` roxygen that `A = ` accepts any known relatedness
  matrix.
- **Sparse-`Ainv` direct engine path.** v0.3.0 follow-up. For now,
  `Ainv =` input is densified via `solve()` — fine for pedigrees
  up to \eqn{n \approx 1000}.
- **Multi-matrix animal models** (G + permanent-environment +
  maternal). Each adds a second `(1 | id)` random effect with its
  own variance; can already be done by combining `animal_*(id, ...)`
  with a sibling `(1 | id)` term. Idiomatic article example deferred
  to v0.3.0.
- **Cross-package validation against MCMCglmm / WOMBAT** on real
  pedigree fixtures. Phase 5.5 work.

## 9. References

- Henderson, C.R. (1976). *A simple method for computing the
  inverse of a numerator relationship matrix used in prediction of
  breeding values.* Biometrics 32:69-83.
- Hadfield, J.D. (2010). *MCMC methods for multi-response
  generalized linear mixed models: The MCMCglmm R package.* JSS
  33(2).
- Hadfield, J.D. (2026). MCMCglmm course notes — Structured random
  effects (pedigrees + phylogenies + user-defined covariance
  structures as one mathematical class).
- Kirkpatrick, M., & Meyer, K. (2004). *Direct estimation of
  genetic principal components: Simplified analysis of complex
  phenotypes.* Genetics 168:2295-2306.
- Meyer, K. (2009). *Factor-analytic models for genotype ×
  environment type problems and structured covariance matrices.*
  Genetics Selection Evolution 41:21.
- Runcie, D.E., & Mukherjee, S. (2013). *Dissecting High-
  Dimensional Phenotypes with Bayesian Sparse Factor Analysis of
  Genetic Covariance Matrices.* Genetics 194:753-767.
- Wilson, A.J., et al. (2010). *An ecologist's guide to the animal
  model.* Journal of Animal Ecology 79:13-26.
