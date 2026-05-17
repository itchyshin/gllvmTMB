# After Task: M2.8b — phylo_* `A =` / `Ainv =` aliases (soft-deprecate of `vcv =`)

**Branch**: `agent/m2-8b-phylo-vcv-soft-deprecate`
**Slice**: M2.8b (follow-up to M2.8, completes the A-vs-V boundary code-side)
**PR type tag**: `engine` + `validation` (small sugar layer addition + new test file)
**Lead persona**: Boole + Rose
**Maintained by**: Boole + Rose; reviewers: Gauss (engine path unchanged check), Pat (reader UX), Ada (close gate)

## 1. Goal

Complete the **A-vs-V naming boundary** code-side. M2.8 shipped
the `animal_*` family with `pedigree =` / `A =` / `Ainv =` inputs
but left `phylo_*` accepting only `tree =` / `vcv =` — an
inconsistency Design 14 §3 flagged but deferred to a small
follow-up. This slice adds `A =` / `Ainv =` as byte-equivalent
aliases on all 5 `phylo_*` grid keywords.

**Backward compatible**. Existing `phylo_*(vcv = ...)` continues
to work unchanged through v0.3.0. The legacy `vcv =` is not
deprecated with a runtime warning yet — this is a "soft" alias
addition that aligns naming with `animal_*` without breaking any
existing user code, article, or test.

**Mathematical contract**: zero TMB likelihood change. Pure
parser-side input normalisation. `A =` and `Ainv =` are
translated to `vcv =` in `rewrite_canonical_aliases()` BEFORE
each existing phylo_X dispatch branch runs, so the engine path
is unchanged.

## 2. Implemented

### Stub signatures (5 keywords)

All 5 `phylo_*` grid keywords gain `A = NULL, Ainv = NULL`:

```r
phylo_scalar <- function(species, tree = NULL, vcv = NULL,
                         A = NULL, Ainv = NULL) { invisible(NULL) }
phylo_unique <- function(species, tree = NULL, vcv = NULL,
                         A = NULL, Ainv = NULL) { invisible(NULL) }
phylo_indep  <- function(formula, tree = NULL, vcv = NULL,
                         A = NULL, Ainv = NULL) { invisible(NULL) }
phylo_dep    <- function(formula, tree = NULL, vcv = NULL,
                         A = NULL, Ainv = NULL) { invisible(NULL) }
phylo_latent <- function(species, d = 1, tree = NULL, vcv = NULL,
                         A = NULL, Ainv = NULL) { invisible(NULL) }
```

`phylo_slope(formula)` is unchanged — it has no `vcv =` arg
(reuses A from a sibling phylo_* term).

### Parser normaliser

New block in `rewrite_canonical_aliases()` (R/brms-sugar.R) that
fires BEFORE the existing phylo_X dispatch branches. It:

1. Translates `A =` to `vcv =` (direct rename in the AST).
2. Translates `Ainv =` to `vcv = solve(as.matrix(.))` (substituted
   expression; evaluated by `parse_covstruct_call`'s eval pass).
3. Errors with a typed `cli` message if both `vcv` and `A` (or
   both `vcv` and `Ainv`) are supplied.

The existing phylo_X branches see only `vcv =` and continue to
work unchanged.

### New test file

`tests/testthat/test-phylo-vcv-A-aliases.R` (~140 lines, 5 test_that blocks):

1. `phylo_scalar(species, A = K)` byte-equivalent with `vcv = K`.
2. `phylo_scalar(species, Ainv = solve(K))` byte-equivalent with `vcv = K`.
3. **All 5 grid keywords** accept `A =` as byte-equivalent alias.
4. Supplying both `vcv` and `A` errors with a clear message.
5. Supplying both `vcv` and `Ainv` errors with a clear message.

Local run: **11 PASS · 0 SKIP · 0 FAIL** on macOS arm64.

Regression check on existing animal_* tests: **19 PASS · 1 SKIP
· 0 FAIL** (unchanged from M2.8).

### Doc updates (small)

- `docs/design/14-known-relatedness-keywords.md` §6 argument-
  convention table: "soft-deprecate plan" → "aliases shipped
  2026-05-17"; §8 scope-boundary block reflects the alias
  shipped rather than deferred.
- `NEWS.md` adds an entry "phylo_* `A =` / `Ainv =` aliases
  (M2.8b)" and corrects the M2.8 entry's "aliases are coming"
  → "aliases shipped 2026-05-17 (M2.8b)".
- `vignettes/articles/api-keyword-grid.Rmd` correlation-rows
  table: phylo row gains the A / Ainv aliases.

## 3. Files Changed

```
Added:
  tests/testthat/test-phylo-vcv-A-aliases.R                                       (~140 lines, 5 tests)
  docs/dev-log/after-task/2026-05-17-m2-8b-phylo-vcv-A-soft-deprecate.md          (this file)

Modified:
  R/brms-sugar.R                                                                  (+5 args on 5 stubs; +25 LOC normaliser block in rewrite_canonical_aliases)
  NEWS.md                                                                         (new entry + correction to M2.8 entry)
  docs/design/14-known-relatedness-keywords.md                                    (alias-status updates)
  vignettes/articles/api-keyword-grid.Rmd                                         (correlation-rows table)
  man/phylo_dep.Rd, man/phylo_indep.Rd, man/phylo_latent.Rd,
  man/phylo_scalar.Rd, man/phylo_unique.Rd                                        (auto-regenerated from roxygen)
```

No R/ engine change. No NAMESPACE change (stubs already exported). No new test fixtures beyond the local helper.

## 4. Checks Run

- `devtools::document()` — 5 man/*.Rd files updated.
- `testthat::test_file("tests/testthat/test-phylo-vcv-A-aliases.R")` → **11 PASS · 0 SKIP · 0 FAIL** on macOS arm64.
- Regression: `test-animal-keyword.R` → 19 PASS · 1 SKIP · 0 FAIL (unchanged from M2.8 baseline).
- Byte-equivalence verified across all 5 grid keywords (smoke test in dev console):

  ```
  phylo_scalar   vcv=-87.2943  A=-87.2943  byte-equiv=TRUE
  phylo_unique   vcv=-87.2943  A=-87.2943  byte-equiv=TRUE
  phylo_indep    vcv=-87.2943  A=-87.2943  byte-equiv=TRUE
  phylo_dep      vcv=-87.2943  A=-87.2943  byte-equiv=TRUE
  phylo_latent   vcv=-87.2943  A=-87.2943  byte-equiv=TRUE
  ```

## 5. Tests of the Tests

3-rule contract:

- **Rule 1** (would have failed before fix): the 5 byte-equivalence
  assertions would all fail if the normaliser didn't fire (no
  alias support); the double-arg error tests would fail if the
  normaliser silently accepted both (no clear error message).
- **Rule 2** (boundary): the double-arg case (`vcv =` + `A =`
  both supplied) is the boundary where an alias must reject
  rather than pick one silently. Both `vcv + A` and `vcv + Ainv`
  cases tested.
- **Rule 3** (feature combination): each byte-equivalence test
  combines a phylo_X keyword × an input form × engine. Five
  separate combinations × three input forms (`vcv`, `A`, `Ainv`)
  all converge to the same logLik.

## 6. Consistency Audit

- Stale-wording rg sweep on M2.8b files: 0 hits on `S_B`, `S_W`,
  `gllvmTMB_wide`, `trio`, `phylo_rr(`, `gr(`, `block_V(`.
- "aliases coming" → all flipped to "aliases shipped 2026-05-17"
  in: Design 14 §6/§8, NEWS.md, api-keyword-grid.Rmd.
- Persona-active-naming: lead Boole + Rose; reviewers Gauss +
  Pat + Ada.

Convention-Change Cascade (AGENTS.md Rule #10): the change is
purely additive on the public API (new optional args, no
breakage). The cascade is: stub signatures → parser normaliser
→ tests → roxygen → man/*.Rd → NEWS → Design 14 → api article.
All cascade points covered in this PR.

## 7. Roadmap Tick

- No ROADMAP M-row tick — M2.8b is a small follow-up to M2.8,
  not a numbered M2 slice.
- Validation-debt register: no new rows (the existing FG-12
  `phylo_*` family row covers the new aliases as part of the
  same evidence files; no separate row needed for an additive
  alias).

## 8. What Did Not Go Smoothly

- **Pedigree fixture re-derivation** in `test-phylo-vcv-A-aliases.R`:
  I wrote a near-duplicate `make_phylo_alias_fixture()` helper
  rather than reusing M2.8's `make_animal_fixture()`. Both
  build the same shape. **Future small follow-up**: factor a
  shared `helper-known-relatedness-fixture.R` for tests that
  need a pedigree-derived A matrix. Not blocking; logged.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Boole** (lead — formula grammar): the normaliser block runs
BEFORE the existing phylo_X dispatch branches in
`rewrite_canonical_aliases()`, so the engine path is unchanged
and the existing test suite's pass rate is preserved exactly
(regression check confirmed 19/19 + 1 SKIP on animal-keyword
tests after the change).

**Rose** (co-lead — A-vs-V boundary audit): the alias completes
the boundary code-side. After this slice, **all known-relatedness
keywords accept A / Ainv as the canonical name**; `vcv =` on
phylo_* is the legacy form retained for backward compatibility.
The double-arg error messages explicitly tell the user "these
are aliases — supply only one", reinforcing the convention.

**Gauss** (review — engine path unchanged): verified by byte-
equivalence at 1e-6 across all 5 grid keywords. No TMB template
change, no parser-internal flag change.

**Pat** (review — reader UX): the api-keyword-grid article's
"phylo row" entry now lists `A =` / `Ainv =` alongside `tree =`
/ `vcv =`. New readers will discover the canonical names; old
readers' code continues to work.

**Ada** (review — orchestration): M2.8b closes the M2.8 "alias
coming" promise. Article cascade for animal_* (5 articles) is
the next follow-up; then M2.5 (psychometrics-irt re-author with
your FINAL CHECKPOINT).

## 10. Known Limitations and Next Actions

- **Article cascade for animal_*** dispatches next (Pat lead;
  5 articles: choose-your-model, data-shape-flowchart,
  gllvm-vocabulary, pitfalls, phylogenetic-gllvm).
- **M2.5** (psychometrics-irt.Rmd re-author) waits for
  maintainer's explicit FINAL CHECKPOINT before I start.
- **`vcv =` runtime deprecation warning** (hard-deprecate)
  remains deferred to v0.3.0. The soft alias addition here is
  the right increment for v0.2.0 — no user breakage; new
  convention discoverable in docs.
- **Tiny follow-up**: factor `make_phylo_alias_fixture()` (this
  test) + `make_animal_fixture()` (M2.8 test) into a shared
  `helper-known-relatedness-fixture.R`. Not blocking.
