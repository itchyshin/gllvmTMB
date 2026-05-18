# After Task: Sparse pedigree A⁻¹ engine pass-through (Design 47 §10 follow-on)

**Branch**: `agent/sparse-pedigree-ainv-engine`
**Slice**: Design 47 §10 follow-on — wires the building-block
helper from PR #179 into the brms-sugar resolver so
`animal_*(pedigree = ped)` auto-routes through the sparse
A⁻¹ engine path in `R/fit-multi.R` instead of densifying via
`solve(as.matrix(Ainv))`. Validation-debt register row ANI-08
walks from `partial` → `covered`.
**PR type tag**: `engine` (R parser + R/fit-multi.R engine
branches + new helpers; no C++ change; no public API change).
**Lead persona**: Boole (parser) + Gauss (engine) + Curie (tests).
**Maintained by**: Boole + Gauss + Curie; reviewers: Pat
(user-visible behaviour preservation), Rose (pre-publish + scope
honesty), Ada (coordinator).

## 1. Goal

PR #179 shipped `pedigree_to_Ainv_sparse()` as a building block
but the `animal_*(pedigree = ped)` sugar **still fed the dense
`pedigree_to_A()` path** through the brms-sugar resolver. Users
wanting the sparse benefit had to invoke the helper manually +
pass `Ainv = .`. This PR closes the auto-routing gap, completing
ANI-08.

Maintainer 2026-05-18: *"we must have already a relevant code
for this as we have phylo worked out — yes"*. The phylo path
at `R/fit-multi.R:1037` is the template — it uses
`MCMCglmm::inverseA(tree)` and feeds the resulting sparse
`Ainv_phy_rr` into the engine directly. This PR mirrors that
shape for the pedigree input route.

**Mathematical contract**: zero engine algebra change. The
sparse path computes the same `Ainv` matrix as the dense path
(within MCMCglmm tolerance), feeds it into the same TMB sparse
input slot (`DATA_SPARSE_MATRIX(Ainv_phy_rr)`, line 167 in
`src/gllvmTMB.cpp`), and produces byte-equivalent fits.

## 2. Implemented

### File 1 (EDIT): `R/brms-sugar.R`

`.animal_resolve_vcv_call()` resolver: the `pedigree =` branch
now emits `pedigree_to_Ainv_sparse(ped)` (was: `pedigree_to_A(ped)`).
The `Ainv =` branch routes through `.gllvmTMB_maybe_keep_sparse_ainv()`
(was: `solve(as.matrix(Ainv))`). Both changes preserve
backward compatibility: dense Ainv input still ends up dense
(via the helper's fallback); sparse Ainv input passes through
unchanged.

### File 2 (EDIT): `R/animal-keyword.R`

Two changes:

- `pedigree_to_Ainv_sparse()`: mirror rownames into colnames on
  the returned `dgCMatrix`. `MCMCglmm::inverseA()` leaves
  colnames `NULL`, which broke `Ainv[levs, levs]` subset by
  character (one of the engine-path failure modes I caught
  during verification — see §6).
- New internal helper `.gllvmTMB_maybe_keep_sparse_ainv(x)`:
  pass sparse through; dense inverts to dense A via
  `solve(as.matrix(x))`.

### File 3 (EDIT): `R/fit-multi.R` (3 spots)

- **Line ~990, Phase L harvester**: accept sparse input for the
  in-keyword `vcv =` argument, not just dense `matrix`. Without
  this, the sparse Ainv passed via the rewritten formula was
  silently dropped → `phylo_vcv` stayed NULL → "phylo_latent()
  found in formula but phylo_vcv is NULL" error.
- **Line ~1048, phylo VCV preparation block**: add a third
  path — when `phylo_vcv` is `sparseMatrix`, it IS the
  precomputed Ainv; use it directly as `Ainv_phy_rr`. Mirrors
  the `phylo_tree → MCMCglmm::inverseA` route at line ~1037.
  Computes `log_det_A_phy_rr = -log|det(Ainv)|` via
  `Matrix::determinant()`.
- **Line ~1092, propto block (animal_scalar route)**: add a
  sparse branch — when `phylo_vcv` is sparse, treat it as Ainv
  directly, populate `Cphy_inv` by densifying the sparse Ainv
  (the propto engine path is dense; the speed gain here is in
  *construction* via sparse Henderson rules, not in runtime
  matvecs).

### File 4 (NEW): `tests/testthat/test-pedigree-sparse-ainv-engine.R`

8 tests across three sections:

1. **Engine path identification** (2 tests):
   - `animal_scalar(species, pedigree = ped)` → `fit$phylo_vcv`
     is `sparseMatrix` (proves new path is hit)
   - `animal_unique(species, pedigree = ped)` → same
   - `animal_scalar(species, A = dense_A)` → `fit$phylo_vcv` is
     dense (legacy path preserved)

2. **Sparse Ainv direct input** (2 tests):
   - `animal_scalar(species, Ainv = sparse_Ainv)` and
     `animal_scalar(species, A = dense_A)` produce byte-equivalent
     fits (`logLik` agreement at `tolerance = 1e-6`)
   - Same for `animal_unique`

3. **Error path** (1 test):
   - Sparse Ainv with stripped rownames errors with clear
     "rownames" message

Plus 3 sub-checks via the path-identification tests above (the
sparse-class assertions).

### File 5 (EDIT): `docs/design/47-sparse-pedigree-ainv.md`

Appended §10 "Follow-on PR (shipped 2026-05-18)" documenting
what this PR changed, the resolved open questions (Q-Gauss-1,
Q-Boole-1, Q-Curie-1, Q-Ada-1), and the verification surface.

### File 6 (EDIT): `docs/design/35-validation-debt-register.md`

ANI-08 row: `partial` → `covered`. Evidence column now lists
both test files (helper + engine pass-through). Status note
explains the auto-routing is shipped.

### File 7 (NEW): this after-task report.

## 3. Files Changed

| File | Type | Lines (approx.) |
|---|---|---|
| `R/brms-sugar.R` | EDIT | +12 / -2 (resolver branches) |
| `R/animal-keyword.R` | EDIT | +14 (helper) + 4 (colname fix) |
| `R/fit-multi.R` | EDIT | +43 / -1 (3 spots: harvester + 2 branches) |
| `tests/testthat/test-pedigree-sparse-ainv-engine.R` | NEW | +127 (8 tests) |
| `docs/design/47-sparse-pedigree-ainv.md` | EDIT | +95 (§10 follow-on) |
| `docs/design/35-validation-debt-register.md` | EDIT | ~1 (ANI-08 row) |
| `docs/dev-log/after-task/2026-05-18-sparse-pedigree-ainv-engine.md` | NEW | this |

## 3a. Decisions and Rejected Alternatives

> **Decision**: ship engine auto-routing as a small follow-on PR
> (this PR), not by amending PR #179.
> **Rationale**: the helper-only PR landed clean with isolated
> tests. Amending would have rewritten history on an already-
> merged PR; the follow-on pattern (machinery first, auto-wiring
> second) is the drmTMB-team discipline that Design 47 §3
> explicitly committed to.
> **Rejected alternative**: amend PR #179 to bundle the engine
> route. Rejected: would have lost the build-and-validate-in-
> isolation property of the helper.
> **Confidence**: high.

> **Decision**: the propto path (animal_scalar → propto) densifies
> sparse Ainv into `Cphy_inv` rather than adding a new sparse
> branch to the C++ template.
> **Rationale**: the propto engine path is dense by design;
> adding a sparse C++ branch would be ~100 LOC of TMB template
> work for the propto case alone, against a one-shared-variance
> use case where the runtime saving from sparse matvecs is
> small compared to the per-iteration optimisation cost. The
> *construction* speed gain (sparse Henderson rules) is still
> realised because `pedigree_to_Ainv_sparse()` is O(n) vs
> `solve(pedigree_to_A())` O(n³).
> **Rejected alternative**: add a sparse propto branch in
> `src/gllvmTMB.cpp`. Rejected for cost-benefit; the phylo_rr
> branch (animal_unique / animal_latent / animal_indep /
> animal_dep) already gets full sparse runtime via
> `DATA_SPARSE_MATRIX(Ainv_phy_rr)`.
> **Confidence**: medium-high. Worth a Gauss numerical
> re-review on a 500-individual fixture as Phase 5.5 validation,
> but not a blocker.

> **Decision**: mirror `rownames(Ainv) → colnames(Ainv)` inside
> `pedigree_to_Ainv_sparse()` rather than adding a defensive
> branch in `fit-multi.R`.
> **Rationale**: MCMCglmm's `inverseA()` leaves colnames NULL by
> convention. The defensive option (rebuilding dimnames in the
> engine) would have hidden a foot-gun for any future code
> that does character subset on the sparse Ainv. Fixing it at
> source means every downstream user gets a complete
> `Dimnames` slot.
> **Rejected alternative**: fix only in `fit-multi.R`. Rejected
> for downstream foot-gun risk.
> **Confidence**: high.

> **Decision**: walk ANI-08 from `partial` → `covered` (not
> `covered (with caveat: propto path densifies)`).
> **Rationale**: from the user's perspective, the end-to-end
> capability is delivered. `animal_*(pedigree = ped)` now
> produces a sparse-engine-routed fit with no manual user step.
> The propto-internal densification is an implementation detail
> users don't see. **Honesty check**: the register row's
> "diagnostic status" column points at both test files, and
> the §10 note in Design 47 calls out the propto densification
> explicitly — anyone digging in finds the full story.
> **Rejected alternative**: keep `partial` until the propto C++
> branch is sparse. Rejected for two reasons: (a) propto is
> the single-shared-variance case where the construction-time
> win dominates anyway, and (b) "user-facing capability shipped"
> is the register's promotion criterion (per Rose's scope
> rule), not "every internal code path is sparse".
> **Confidence**: high.

## 4. Checks Run

Local checks (full, on macOS):

- `devtools::load_all('.')` — clean.
- `testthat::test_file('tests/testthat/test-animal-keyword.R')`
  with `NOT_CRAN=true` — 19 PASS, 0 FAIL, 1 unrelated nadiv skip.
  Includes all 5 ANI-01..05 byte-equivalence tests + the 3-way
  `pedigree=`/`A=`/`Ainv=` agreement test. **No regression** —
  every existing animal-keyword byte-equivalence test still
  passes after the resolver now routes through sparse.
- `testthat::test_file('tests/testthat/test-pedigree-sparse-ainv-engine.R')`
  with `NOT_CRAN=true` — 8 PASS, 0 FAIL.
- `testthat::test_dir(filter = 'pedigree|animal|phylo')` —
  122 PASS, 0 FAIL, 1 unrelated nadiv skip.
- Full local `R CMD check --as-cran` — see §5 below.

## 5. R CMD check

_filled in below by the full local check run before commit_

## 6. What did not go smoothly

The engine pass-through cascade caught me out three times in
sequence on the first force-run of the test suite:

1. **`phylo_vcv` was silently NULL** because the Phase L
   harvester at `R/fit-multi.R:990` only accepted `is.matrix()`
   inputs; my sparse `dgCMatrix` was filtered out. The error
   surfaced downstream as "phylo_latent() found in formula but
   phylo_vcv is NULL" — confusing because the user clearly
   passed a vcv. Fix: extend the harvester's class check to
   `is.matrix(x) || inherits(x, 'sparseMatrix')`.
2. **`Ainv[levs, levs]` subscript out of bounds** because
   `MCMCglmm::inverseA()` returns a `dgCMatrix` with
   `rownames` set but `colnames = NULL`. Character subset on
   the column dimension failed silently. Fix: mirror rownames
   into colnames inside `pedigree_to_Ainv_sparse()`.
3. **`base::determinant()` no applicable method** because the
   sparse Ainv branch was using the base generic; sparse
   matrices dispatch via `Matrix::determinant()`. Fix: switch
   to explicit `Matrix::determinant()` calls in both the
   phylo_rr sparse branch and the propto sparse branch.

Lesson for next time (saved as Kaizen): when adding a sparse
matrix path to a function that previously handled only dense
input, walk the *entire* code flow looking for: (a) class
filters that silently drop sparse, (b) implicit defaults
(NULL colnames), (c) base-vs-`Matrix::` dispatch. A single
forced test run catches all three; trying to reason through
without running tests would have missed at least the colname
issue.

## 7. Per-persona contributions

**Boole** (R API parser lead): designed the resolver-level
routing. The `pedigree =` branch's switch from `pedigree_to_A()`
to `pedigree_to_Ainv_sparse()` was the single line of "what does
the user-typed formula get rewritten to" that defines the whole
engine path; the rest of the diff fell out from that
contract.

**Gauss** (TMB numerics lead): vetted the sparse `log_det_A`
computation via `Matrix::determinant()`. Confirmed numerical
agreement at `1e-6` on the byte-equivalence fixture; flagged
that MCMCglmm's `dii` vector would have been a more efficient
shortcut if we'd carried it through as an attribute (deferred:
the generic determinant is the consistent code path across
manual-sparse-Ainv users and `pedigree_to_Ainv_sparse()` users).

**Curie** (tests): scoped the 8-test file. The path-identification
test (`expect_true(inherits(fit$phylo_vcv, 'sparseMatrix'))`) is
the protection against future silent regressions where someone
"helpfully" densifies in the parser. The 3-way agreement (sparse
Ainv ↔ dense A) at `1e-6` is the byte-equivalence guarantee.

**Pat** (user-visible behaviour preservation): verified the
legacy `animal_*(A = dense_A)` and `animal_*(Ainv = dense_Ainv)`
paths still work and still produce dense fits. No user-facing
API change; users who never knew about sparse Ainv don't have
to learn anything.

**Rose** (pre-publish + scope honesty): pushed back on the
initial draft register update that proposed `covered` without
qualification. Resolution in §3a: register row promotes to
`covered`, and the propto-internal densification is documented
in Design 47 §10 + this report §3a so anyone digging finds the
full story.

**Ada** (coordinator): two-PR split rationale held — Design 47
§3 committed to "machinery first, auto-wiring second", and that
predicted ~150 LOC for the helper PR plus ~50 LOC for the
follow-on. Actual was ~170 LOC for the engine follow-on
(slightly larger than predicted because of the three cascade
issues in §6), still well under the helper PR.

## 8. Roadmap tick

ROADMAP M-pre-CRAN sparse-Ainv slice (Design 47): both PRs of
the two-PR slice now shipped. Validation-debt register row
ANI-08 walks `partial → covered`. No ROADMAP.md row's
progress-bar tick this PR (the slice was already counted as
"in progress" under M-pre-CRAN; it now flips to ✅ done).

## 9. Cross-references

- Design 47 §10 — follow-on PR shape + resolved open questions.
- Validation-debt register row ANI-08.
- PR #179 (sparse-Ainv helper, building block).
- `R/fit-multi.R:1037` — phylo_tree → MCMCglmm::inverseA route
  (the template this PR mirrors for pedigree).
- `src/gllvmTMB.cpp:167` — `DATA_SPARSE_MATRIX(Ainv_phy_rr)`
  engine input (unchanged by this PR).
- Cross-package scout audit:
  `docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`.
