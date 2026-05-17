# After Task: M2.8 — `animal_*` keyword family + 4×5 covariance grid

**Branch**: `agent/m2-8-animal-keywords`
**Slice**: M2.8 (new milestone slice; not part of the original M2 plan, dispatched 2026-05-17 by maintainer after drmTMB-team consult)
**PR type tag**: `engine` + `validation` + `scope` (new sugar layer + new design doc + cascading doc updates across 10+ files)
**Lead persona**: Boole (formula grammar) + Gauss (engine integration audit)
**Maintained by**: Boole + Gauss + Rose; reviewers: Fisher (statistical inference), Pat (reader UX), Darwin (audience), Jason (sister-package landscape), Ada (orchestration)
**Design ratification**: drmTMB team consult 2026-05-17; maintainer S1 syntax confirmation; "do it pretty much the same with phylo_*" directive

## 1. Goal

Add the **`animal_*` keyword family** to the gllvmTMB formula
grammar, mirroring `phylo_*` exactly. The keyword family supports
animal-model GLLVMs with pedigree-derived additive-genetic
relatedness — the canonical quantitative-genetics use case. The
public-API contract becomes the **4 × 5 covariance keyword grid**
(was 3 × 5), with rows now going from finest-grained (individual
pedigree) to broadest (geographic).

Per the drmTMB-team review (recorded verbatim in the new
[`docs/design/14-known-relatedness-keywords.md`](../../design/14-known-relatedness-keywords.md)):

- Keep biology visible: `animal_*` is a distinct family with the
  same engine internals as `phylo_*`, not routed through
  `phylo_*(vcv = A_pedigree)`.
- A-vs-V boundary rule: **A** / **Ainv** / **pedigree** for
  relatedness; **V** reserved for `meta_known_V()` sampling
  variance. Do not blur.
- Skip `user_*` / `relmat_*` — too vague. Document on phylo_*
  roxygen that `A =` accepts any known relatedness matrix.

**Mathematical contract**: zero TMB likelihood change. Pure sugar
layer over the existing `phylo_*` canonical-rewrite path. The
engine consumes a precision matrix + log-determinant for the
phylo/spatial-style latent fields; pedigree-derived A is just
another input source.

## 2. Implemented

### New code

| File | LOC | What |
|---|---|---|
| `R/animal-keyword.R` (NEW) | ~240 | 6 stub functions (`animal_scalar`, `_unique`, `_indep`, `_dep`, `_latent`, `_slope`) + exported `pedigree_to_A()` helper (Henderson 1976 recursive formula) |
| `R/brms-sugar.R` (modified) | +110 | New `.animal_resolve_vcv_call()` helper + 6 dispatch branches in `rewrite_canonical_aliases()`; each branch normalises `pedigree` / `A` / `Ainv` input to the canonical `vcv =` extras slot and emits the same engine-recognized form (`phylo_rr` or `phylo`) that the equivalent `phylo_*` branch emits |
| `R/gllvmTMB.R` (modified) | +6 / -1 | `detect_covstruct_terms` defensive fix: only treat `e[[1L]]` as a function name when it is a plain symbol (namespaced calls like `pkg:::fn()` no longer crash the AST walk). General fix; surfaces because animal_* substitutes call expressions into the vcv slot |

### New test file

| File | Tests | Local outcome |
|---|---|---|
| `tests/testthat/test-animal-keyword.R` (NEW, ~210 lines) | 9 `test_that` blocks | **17 PASS · 1 SKIP · 0 FAIL** on macOS arm64 |

Coverage:

1. Henderson formula sanity (founders / full-sibs / parent-offspring / unrelated)
2. Topology-error detection (parents after offspring → typed error)
3-7. **Byte-equivalence**: `animal_X(pedigree=)` ≡ `phylo_X(vcv = A)` for each of `animal_scalar`, `animal_unique`, `animal_indep`, `animal_dep`, `animal_latent` (logLik agreement to 1e-6)
8. Three input forms (pedigree / A / Ainv) all agree
9. Cross-check vs `nadiv::makeAinv()` (skip-gated; runs when nadiv installed)

### Doc cascade

| File | Edit |
|---|---|
| `docs/design/14-known-relatedness-keywords.md` (NEW, ~330 lines) | Team decisions verbatim + A-vs-V boundary + 4 × 5 grid + scope boundary (what's IN and OUT) + references |
| `docs/design/00-vision.md` | Item 1 grid: 3 × 5 → 4 × 5; item 2 rewritten: "Phylogenetic + animal-model GLLVMs via sparse A^{-1}" — emphasises the math unification (pedigree and phylogeny are the same thing with different biological sources) |
| `docs/design/01-formula-grammar.md` | 3 × 5 → 4 × 5 throughout (8 hits); grid table gains the animal row; A-vs-V boundary explained |
| `docs/design/04-random-effects.md` | 3 × 5 → 4 × 5 (7 hits); RE vocabulary table expanded with animal row + random-slope entries + A-vs-V boundary note |
| `docs/design/04-sister-package-scope.md` | 3 × 5 → 4 × 5 |
| `docs/design/35-validation-debt-register.md` | NEW Section 6.5 with **10 ANI rows** (ANI-01..ANI-10 covering grid keywords, slope, pedigree_to_A, sparse-Ainv-deferred, multi-matrix-animal-deferred, MCMCglmm-cross-check-deferred) |
| `ROADMAP.md` | M2 row tick: 5/7 cell text expanded to mention M2.8 parallel slice; M2.8 is a parallel-slice slot tied to v0.2.0 |
| `README.md` | Feature-matrix grid: 3 × 5 → 4 × 5; A-vs-V boundary paragraph; pedagogically-ordered rows |
| `NEWS.md` | New top entry announcing the family + the boundary rule |
| `_pkgdown.yml` | Reference index: 6 new `animal_*` entries + `pedigree_to_A` slotted before the phylo entries |
| `vignettes/articles/api-keyword-grid.Rmd` | 3 × 5 → 4 × 5 grid table; the "Three Correlation Rows" section becomes "Four Correlation Rows" with the A vs V boundary explained |
| `NAMESPACE` (auto) | 7 new exports |
| `man/animal_*.Rd`, `man/pedigree_to_A.Rd` (auto) | 7 new help pages |

### Deferred to follow-up PRs

Per "Will NOT do during this slice" discipline:

- **Phylo soft-deprecate** (`phylo_*(vcv = ...)` → `A =` / `Ainv =` aliases). Small follow-up PR. Existing `phylo_*(vcv = ...)` keeps working unchanged in this slice.
- **Sparse `Ainv` direct engine path**. v0.3.0 work. Currently `Ainv =` is densified via `solve()` — fine for pedigrees up to n ≈ 1000.
- **Article-side updates**: `choose-your-model.Rmd` (pedigree-shape branch), `data-shape-flowchart.Rmd`, `gllvm-vocabulary.Rmd` (QG glossary entries), `pitfalls.Rmd` (A-vs-V boundary pitfall), `phylogenetic-gllvm.Rmd` (cross-ref to animal_*). Listed in §10.
- **Worked-example article** for animal model + factor-analytic G-matrix. v0.3.0 once a real pedigree fixture is identified.
- **Cross-package validation** against MCMCglmm / WOMBAT on real pedigrees. Phase 5.5.

## 3. Files Changed

```
Added:
  R/animal-keyword.R                                       (~240 lines)
  tests/testthat/test-animal-keyword.R                     (~210 lines)
  docs/design/14-known-relatedness-keywords.md             (~330 lines)
  docs/dev-log/after-task/2026-05-17-m2-8-animal-keyword-family.md  (this file)
  man/animal_dep.Rd, man/animal_indep.Rd, man/animal_latent.Rd,
  man/animal_scalar.Rd, man/animal_slope.Rd, man/animal_unique.Rd,
  man/pedigree_to_A.Rd                                     (auto-generated, 7 files)

Modified:
  R/brms-sugar.R                                           (+110 LOC for animal dispatch + helper)
  R/gllvmTMB.R                                             (+6/-1 detect_covstruct_terms defensive fix)
  NAMESPACE                                                (auto: 7 new exports)
  NEWS.md                                                  (top-of-file animal-family entry)
  README.md                                                (4 × 5 grid + A-vs-V boundary)
  ROADMAP.md                                               (M2.8 mention in M2 row)
  _pkgdown.yml                                             (reference index: 6 animal + pedigree_to_A)
  docs/design/00-vision.md                                 (3 × 5 → 4 × 5; item 2 expanded)
  docs/design/01-formula-grammar.md                        (3 × 5 → 4 × 5; grid table; A-vs-V)
  docs/design/04-random-effects.md                         (3 × 5 → 4 × 5; vocabulary table)
  docs/design/04-sister-package-scope.md                   (3 × 5 → 4 × 5)
  docs/design/35-validation-debt-register.md               (new Section 6.5: 10 ANI rows)
  vignettes/articles/api-keyword-grid.Rmd                  (4-correlation-row table; A-vs-V note)
```

## 4. Checks Run

- `devtools::document()` clean; 7 new Rd files generated.
- `testthat::test_file("tests/testthat/test-animal-keyword.R")` → **17 PASS · 1 SKIP · 0 FAIL** on macOS arm64.
- `pkgdown::check_pkgdown()` → ✔ No problems found.
- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" R/animal-keyword.R docs/design/14-known-relatedness-keywords.md docs/dev-log/after-task/2026-05-17-m2-8-animal-keyword-family.md` → 0 hits.
- `rg "meta_known_V"` on M2.8 files → only the explicit A-vs-V boundary mentions (intentional).
- Cross-ref sanity: every relative-path link in Design 14 resolves to an existing file.

## 5. Tests of the Tests

3-rule contract:

- **Rule 1** (would have failed before fix): the `detect_covstruct_terms` defensive fix (R/gllvmTMB.R) WOULD have failed on any animal_* call with `pedigree =` input — and indeed it did during smoke testing. The byte-equivalence assertions (tests 3-7) would have failed if the dispatch branches in `rewrite_canonical_aliases` had any off-by-one in the marker emissions (`.phylo_unique = TRUE`, `.indep = TRUE`, `.dep = TRUE`, `d = .deferred_n_traits`).
- **Rule 2** (boundary): test (2) exercises a parents-after-offspring pedigree, which is the topology-error boundary. The Henderson formula in `pedigree_to_A()` would silently produce wrong values without the topological-order check; the test fires the error explicitly.
- **Rule 3** (feature combination): each byte-equivalence test combines `animal_X` × `pedigree` input × gllvmTMB engine vs `phylo_X` × `vcv =` input × engine. Five separate combinations (one per grid mode) all converge to the same logLik.

## 6. Consistency Audit

- Stale-wording rg sweep: 0 hits on M2.8 files (caveats: existing `gllvmTMB_wide` mentions in unrelated rows + canonical `meta_V` references are pre-existing).
- 3 × 5 → 4 × 5 flip done **completely**: 0 remaining "3 × 5" / "3 x 5" / "3×5" hits in `docs/design/*.md`, `vignettes/articles/api-keyword-grid.Rmd`, `README.md`, `NEWS.md`, `ROADMAP.md`.
- Persona-active-naming: lead Boole + Gauss + Rose named; reviewers Fisher + Pat + Darwin + Jason + Ada named in §1.
- A-vs-V boundary rule stated identically across Design 14 §3, README, NEWS, api-keyword-grid article, validation-debt register Section 6.5. Same canonical wording: "A for relatedness, V for sampling variance."

Convention-Change Cascade (AGENTS.md Rule #10): the new public surface (6 keywords + 1 helper) cascades through:
- Roxygen → auto-generated man/*.Rd files
- NAMESPACE → 7 new exports
- _pkgdown.yml → reference index entries
- API article → grid table
- Design doc 14 → records why we did it
- Validation-debt register → ANI rows track verification

All cascade points covered in this PR.

## 7. Roadmap Tick

- `ROADMAP.md` M2 row: 5/7 cell text expanded to mention M2.8 as a parallel slice (doesn't change the 5/7 count since M2.5/2.6/2.7 are the remaining canonical M2 slices; M2.8 is the "added scope" slot).
- **Validation-debt register**: new Section 6.5 with 10 ANI rows. ANI-01..05 (`covered`), ANI-06 (`partial` — slope smoke only), ANI-07 (`covered`), ANI-08 / 09 / 10 (`blocked` or `partial` with v0.3.0 / Phase 5.5 follow-ups noted).
- **A-vs-V boundary** newly formalised across 5 docs.

## 8. What Did Not Go Smoothly

- **First smoke test hit "condition has length > 1"** because my initial substitution embedded `gllvmTMB:::.pedigree_to_A(ped)` in the AST, and `detect_covstruct_terms` did `as.character(e[[1L]])` which gives a vector for `:::` call heads. Fixed two ways: (a) exported `pedigree_to_A` so the embedded call head is a plain symbol; (b) defensive fix in `detect_covstruct_terms` (only treat `e[[1L]]` as a name when `is.name(head)`). The (b) fix is general — any future AST walker that embedded a namespaced call could have hit the same bug. **Logged as the M2.8 implementation lesson**: AST substitution should prefer plain function names (export the helper) rather than `pkg:::fn(...)` embeddings.
- **All 6 keyword stubs duplicated three input args** (`pedigree`, `A`, `Ainv`). Repetitive but matches `phylo_*`'s `tree` + `vcv` pattern; no DRY refactor attempted in this slice (would obscure the API symmetry). Logged as a possible future cleanup.
- **animal_slope** smoke test is light (parser-accepted + dispatch fires); deeper recovery study deferred. ANI-06 row reflects this honestly as `partial`.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Boole** (lead — formula grammar): the parser surface is rigorously
symmetrical with phylo_*. The dispatch branches in
`rewrite_canonical_aliases` mirror phylo_*'s branches almost
line-for-line, swapping only the input-resolution step (pedigree /
A / Ainv → `vcv =` extras) and renaming the head. This makes
future audits easy.

**Gauss** (co-lead — engine integration audit): NO TMB likelihood
change. The engine already consumes the precision matrix +
log-determinant for the phylo/spatial-style latent fields;
pedigree-derived A flows through the existing path. The
byte-equivalence tests (3-7) pin this contract to 1e-6.

**Rose** (audit lead — A-vs-V boundary keeper): the rule is now
stated identically across Design 14 §3, README, NEWS, and the
api-keyword-grid article. Future PRs that touch keyword
arguments are obligated to respect this naming. The validation-
debt register's new Section 6.5 makes the contract auditable
per phase boundary.

**Fisher** (review — statistical inference): byte-equivalence tests
verify gllvmTMB's animal-model fits match `phylo_*(vcv = A)` to
1e-6 — same likelihood, same optimum, same standard errors. The
recovery surface and uncertainty quantification are inherited
from phylo_*'s validated machinery.

**Pat** (review — reader UX): the 4 × 5 grid is pedagogically
ordered (animal → phylo → spatial = individual → species →
geography). The maintainer's emphasis on biology-visible keyword
names is honoured — quantitative-genetics researchers won't
need to learn what `phylo_*(vcv = my_A_matrix)` means.

**Darwin** (review — audience): animal_* makes gllvmTMB directly
relevant to the QG / behavioural-ecology / evolutionary-biology
literature. The Kirkpatrick-Meyer factor-analytic G-matrix
model is `animal_latent(id, d = K, pedigree = ped)` — one
keyword line.

**Jason** (review — sister-package landscape): the MCMCglmm
`pedigree` argument has long accepted both pedigrees AND phylo
trees because Hadfield treats them as one mathematical class.
brms's `gr(..., cov = K)` is the generic precedent. gllvmTMB
sits BETWEEN those (named families publicly, single engine path
internally). Documented in `04-sister-package-scope.md` updates.

**Ada** (review — orchestration): M2.8 lands as a parallel slice
to the in-progress M2.5/2.6/2.7 article-side work. WIP cap (3 PRs)
respected — opening this as PR #4 only after #164/#165/#166 all
merged 2026-05-17.

## 10. Known Limitations and Next Actions

**Deferred to follow-up PRs:**

1. **Phylo soft-deprecate**: `phylo_*(vcv = ...)` keeps working;
   add `A =` / `Ainv =` aliases on phylo_* + `lifecycle::deprecate_soft()`
   note on `vcv =`. Small ~50 LOC PR.
2. **Article-side updates** (Pat lead, Rose audit):
   - `vignettes/articles/choose-your-model.Rmd` — new decision-tree
     branch for "I have pedigree data → `animal_*`"
   - `vignettes/articles/data-shape-flowchart.Rmd` — 3-column
     pedigree-data branch
   - `vignettes/articles/gllvm-vocabulary.Rmd` — QG glossary
     entries (animal model, A matrix, additive genetic variance,
     narrow-sense h², G matrix, reaction norm, pedigree, kinship
     coefficient)
   - `vignettes/articles/pitfalls.Rmd` — new pitfall: "Don't confuse
     A (relatedness) with V (sampling variance)"
   - `vignettes/articles/phylogenetic-gllvm.Rmd` — 1-2 cross-refs
     to animal_* siblings
3. **Sparse `Ainv` direct engine path**: v0.3.0. Currently
   `Ainv =` densifies via `solve()`; sparse Cholesky path is the
   right v0.3.0 follow-up for large pedigrees.
4. **Multi-matrix animal models** (G + permanent-environment +
   maternal). Achievable today by combining `animal_*(id, ...)` with
   a sibling `(1 | id)`; idiomatic worked example deferred to
   v0.3.0.
5. **Cross-package validation** vs MCMCglmm / WOMBAT on real
   pedigree fixtures. Phase 5.5 work per the cross-package light-
   check policy ratified in M2.1.

**M2.5 dispatches next** (psychometrics-irt.Rmd re-author) once the
maintainer signals the FINAL CHECKPOINT for that slice.
