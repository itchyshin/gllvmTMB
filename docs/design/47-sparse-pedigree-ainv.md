# Design 47 — Sparse pedigree → A⁻¹ direct engine path

**Maintained by**: Boole (R API lead) + Gauss (TMB-side
numerical lead). **Active reviewers**: Pat (user workflow),
Curie (byte-equivalence tests), Rose (pre-publish + scope),
Ada (coordinator).
**Status**: Active — pre-CRAN slice per maintainer correction
2026-05-18 ("sparse A⁻¹ should be precran!").
**Closes**: validation-debt register row ANI-08 (sparse A⁻¹
direct engine path) — walks from `partial` to `covered` when
this PR + the follow-on auto-routing PR ship.

## 1. Why this matters

The maintainer corrected my earlier classification: sparse A⁻¹
for animal models is **not v0.3.0 work** — it should land
pre-CRAN. The cross-package scout audit (Design 47's sibling
work) confirmed that gllvmTMB **already has sparse A⁻¹ for
phylogeny** via `MCMCglmm::inverseA(tree)` (`R/fit-multi.R:1037`)
and the TMB engine takes a `DATA_SPARSE_MATRIX(Ainv_phy_rr)`
input (`src/gllvmTMB.cpp:167`). The gap is **only on the
pedigree side**.

Currently `animal_*(id, pedigree = ped)`:

1. R: `pedigree_to_A(ped)` → **dense** A (O(n²) memory)
2. R: `solve(A)` → dense Ainv → `Matrix::Matrix(., sparse=TRUE)` (densely-stored sparse)
3. C++: same engine as phylo

For n_individuals = 500: dense path = 2 GB memory + O(n³)
inversion. Sparse path via Henderson-Quaas: ~10 MB + O(n).

The engine path is already sparse-capable. We just need the R-side
to feed it sparse Ainv directly when the input is a pedigree.

## 2. Scope of THIS PR

**Minimal slice (this PR)**: ~150 LOC of R + tests.

1. **New exported helper** `pedigree_to_Ainv_sparse(pedigree)` —
   wraps `MCMCglmm::inverseA(pedigree)$Ainv` with input
   validation + rowname guarantee.
2. **`Ainv =` path accepts sparse input without densification.**
   The existing `Ainv =` argument to `phylo_*()` and `animal_*()`
   already accepts sparse input; per Design 14, the current
   behaviour was to densify internally. **Change**: detect
   sparse `Ainv` and pass through directly.
3. **Documentation**: roxygen for `pedigree_to_Ainv_sparse()` +
   example showing the manual sparse workflow:
   ```r
   Ainv <- pedigree_to_Ainv_sparse(ped)
   fit  <- gllvmTMB(value ~ ... + animal_scalar(id, Ainv = Ainv),
                    data = df, ...)
   ```
4. **Test**: byte-equivalence (within TMB tolerance) between the
   dense-A-input path and the sparse-Ainv-input path on a
   shared 20-individual half-sib fixture (the existing animal
   test fixture).
5. **Update Design 14** §3 to note the sparse-Ainv path is now
   available pre-CRAN; cross-ref this design doc.
6. **Update validation-debt register row ANI-08** from `partial`
   (v0.3.0 follow-up) to `covered (sparse direct path shipped
   2026-05-18; auto-routing follow-on PR-X)`.

**Auto-routing follow-on (separate PR, post-this)**: ~50 LOC of
parser change in `R/brms-sugar.R` to make
`animal_*(id, pedigree = ped)` automatically use the sparse path.
Until that lands, the manual workflow (call
`pedigree_to_Ainv_sparse()` then pass `Ainv =`) is the user
interface.

## 3. Why split this into two PRs

**This PR** lands the building block (sparse helper + sparse
`Ainv=` pass-through). Tested in isolation. Small surface area
to review.

**Follow-on PR** changes the parser to auto-route `pedigree=` ->
sparse. Touches `.animal_resolve_vcv_call()` and 6 animal_*
keyword stubs. Bigger review burden; benefits from this PR's
building block already merged + tested.

This sequencing matches drmTMB-team discipline: machinery first;
auto-wiring second.

## 4. Implementation plan

### Step 1 — New function `pedigree_to_Ainv_sparse(pedigree)`

In `R/animal-keyword.R`, add:

```r
#' Sparse pedigree A^{-1} via Henderson-Quaas
#'
#' @param pedigree A 3-column data frame: id, sire, dam.
#' @return A sparse `dgCMatrix` representation of A^{-1}.
#' @export
pedigree_to_Ainv_sparse <- function(pedigree) {
  if (!requireNamespace("MCMCglmm", quietly = TRUE))
    cli::cli_abort("MCMCglmm is required ...")
  ## Standardise column order: MCMCglmm expects (id, dam, sire)
  ped_std <- .standardise_pedigree_columns(pedigree)
  inv <- MCMCglmm::inverseA(ped_std)
  inv$Ainv  # dgCMatrix
}
```

Plus a helper `.standardise_pedigree_columns()` matching the
M2.8 MCMCglmm-style by-name lookup that `pedigree_to_A()`
already does.

### Step 2 — Sparse Ainv pass-through

In `R/fit-multi.R` around the phylo VCV preparation block
(~line 1010), branch on whether the user-supplied Ainv is sparse:

```r
if (!is.null(Ainv_input)) {
  if (inherits(Ainv_input, c("dgCMatrix", "dgRMatrix", "dsCMatrix"))) {
    Ainv_phy_rr <- Ainv_input  # sparse pass-through
    log_det_A_phy_rr <- as.numeric(determinant(Matrix::solve(Ainv_phy_rr),
                                                logarithm = TRUE)$modulus)
    n_aug_phy <- nrow(Ainv_phy_rr)
    species_aug_id <- match(levs, rownames(Ainv_phy_rr)) - 1L
  } else {
    ## dense path — existing behaviour
    Ainv_phy_rr <- Matrix::Matrix(Ainv_input, sparse = TRUE)
    log_det_A_phy_rr <- -as.numeric(determinant(Ainv_input,
                                                logarithm = TRUE)$modulus)
    ...
  }
}
```

(Note: log_det_A is computed differently for sparse vs dense
inputs because we have Ainv but need log|A| = -log|Ainv|. For
the sparse-from-MCMCglmm case, the more efficient formula uses
the `inv$dii` vector that MCMCglmm provides, but for the
generic sparse-input case we fall back to a sparse `det(Ainv)`.
Worth a Gauss double-check on numerical stability.)

### Step 3 — Test

`tests/testthat/test-pedigree-sparse-ainv.R`: byte-equivalent
fit on the existing 20-individual half-sib fixture (from
`test-animal-keyword.R`). Compare `logLik`, `extract_Sigma`
between:
- `animal_scalar(id, A = pedigree_to_A(ped))` (dense path)
- `animal_scalar(id, Ainv = pedigree_to_Ainv_sparse(ped))` (sparse path)

Expected: identical to TMB tolerance (~1e-10).

### Step 4 — Documentation updates

- `R/animal-keyword.R` roxygen for `pedigree_to_Ainv_sparse()`
  with `@examples`
- Design 14 §3 updated: "pedigree → Ainv sparse direct path is
  available pre-CRAN via `pedigree_to_Ainv_sparse()`; auto-routed
  from `pedigree=` argument in the follow-on PR"
- Validation-debt register row ANI-08: `partial` → `covered`

## 5. Honest scope (what this PR does NOT do)

- **Auto-routing from `pedigree=`**: follow-on PR. Until then,
  users get sparse via the manual workflow.
- **`MCMCglmm::inverseA()` deep customization**: we use the
  package as-is. If `MCMCglmm` is unavailable, the user must use
  the dense `pedigree_to_A()` path (existing behaviour).
- **Multi-pedigree support** (multiple A⁻¹ matrices in one fit,
  e.g., for V_A + V_C maternal-genetic): post-CRAN. Tracked as
  register row ANI-09 (multi-matrix animal model).
- **Benchmark write-up**: a 1000-individual speed comparison
  could land in a follow-on article. Not required for this PR;
  the engineering claim (~24× speedup at n=500) is documented in
  Design 14 already.

## 6. Cross-references

- Design 14 — known-relatedness keywords (`animal_*` + `phylo_*`
  + the A-vs-V naming boundary).
- Design 43 — ASReml speed techniques §4 #2 (sparse A⁻¹ ranked
  Tier A).
- Validation-debt register row ANI-08.
- `R/animal-keyword.R` — `pedigree_to_A()` (dense path; this
  PR ADDS the sparse counterpart, doesn't replace).
- `R/fit-multi.R:1037` — existing `MCMCglmm::inverseA(tree)`
  call for phylo; this PR mirrors for pedigree.
- `src/gllvmTMB.cpp:167` — `DATA_SPARSE_MATRIX(Ainv_phy_rr)`
  engine input; unchanged.
- Cross-package scout audit (Design 43 sibling):
  `docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`

## 7. Open questions

- **Q-Gauss-1**: log_det_A computation for the sparse path —
  use `MCMCglmm`'s `dii` vector (efficient, exact) or generic
  sparse-determinant (works for any sparse Ainv input)? My lean:
  prefer `dii` when available (i.e., when the Ainv came through
  `pedigree_to_Ainv_sparse()` and we cached it as an attribute);
  fall back to generic sparse `det()` for user-supplied sparse
  Ainv from elsewhere.
- **Q-Boole-1**: should `pedigree_to_Ainv_sparse()` be exported
  or internal? My lean: **exported** — users may want to inspect
  Ainv structure, time the conversion separately, or pre-cache
  for repeated fits.
- **Q-Curie-1**: byte-equivalence tolerance — `expect_equal()`
  with `tolerance = 1e-8` per existing M2.8 fixture pattern.
  Confirmed in M2.8 byte-equivalence tests.
- **Q-Ada-1**: register row ANI-08 status — `partial` (because
  auto-routing isn't shipped) or `covered` (because the manual
  workflow IS available)? My lean: `partial` until auto-routing
  PR lands; honest scope.

## 8. Persona contributions

- **Boole** (lead, R API): function signature + naming
  (`pedigree_to_Ainv_sparse()`); column-standardisation
  convention; `Ainv =` sparse pass-through pattern.
- **Gauss** (lead, TMB numerics): log_det_A computation strategy;
  numerical stability of the sparse pass-through.
- **Pat** (review, user workflow): the manual workflow surfaces
  cleanly in the roxygen `@examples` block — users can see
  "call this helper, then pass Ainv=" pattern.
- **Curie** (review, tests): byte-equivalence test against
  existing M2.8 fixture; covers both single-A `animal_scalar()`
  and multi-trait `animal_latent + animal_unique`.
- **Rose** (review, scope honesty): §5 explicit out-of-scope;
  this PR is the building block, not the auto-routing.
- **Ada** (coordinator): two-PR split rationale (machinery first,
  auto-wiring second); register row ANI-08 progression.

## 9. Next actions

1. **N1** — Implement `pedigree_to_Ainv_sparse()` in
   `R/animal-keyword.R`
2. **N2** — Add sparse pass-through to `R/fit-multi.R` phylo VCV
   block
3. **N3** — Add `test-pedigree-sparse-ainv.R` byte-equivalence
4. **N4** — Update Design 14 §3 + register row ANI-08
5. **N5** — After-task report + commit + push
6. **N6** — Follow-on PR: auto-routing parser change for
   `animal_*(pedigree=ped)` → sparse Ainv. **NOT this PR.**
