# After-task — VGH Phase 2: the packing transform, and landing #819

Date: 2026-07-29. Lane: `claude/vgh-phase2-20260730` (worktree
`/private/tmp/gllvmtmb-vgh-p2`). Platform: Claude.

## What this slice set out to do

Execute Phase 2's first two steps under an ultra-plan: settle the rotation
hand-off, and satisfy the preconditions for landing PR #819.

## What actually happened

### 1. The rotation "blocker" dissolved, and the handover named the wrong helper

The Phase 1 handover framed rotational identifiability as an unresolved design
decision between two routes, to be settled before any hand-off code. A prior-work
sweep found it is neither unresolved nor a decision:

- **Already ratified, in a sister repo.** `HSquared.jl` decision
  `2026-06-19-fa-rotation-convention.md`: *"bridge and do inference ONLY on
  rotation-invariant functionals of `G`; never bridge raw loadings `Λ`."* It
  records that the likelihood is **exactly flat along the rotation orbit**.
- **So a start value needs a valid PACKING, not a chosen rotation.** Any
  orthogonal `Q` landing `Lambda` in the template's form sits at the same
  objective.
- **The two "routes" are not alternatives.** Lower-triangular packing is the
  hand-off; `.procrustes_align()` needs a reference target and is a *comparison*
  tool. Picking one leaves the other job undone.

**The load-bearing correction.** The handover directs Phase 2 to
`.va_r3_rotate_to_lower_triangular()` (`R/va-r3-proto.R:367`), which rotates
`Lambda` **alone** — no score rotation, no sign fix. VGH carries a real `amean`,
so that route moves the linear predictor by O(1): **measured 5.55** on a
unit-scale fixture. The correct helper is `.gllvmTMB_lower_triangular_rotation()`
(`R/init-warmstart.R:335`), which rotates loadings and scores by the same `Q` and
fixes the diagonal sign. GLLVM.jl independently uses the score-aware form
(`src/ppca_init.jl:97`).

### 2. `.vgh_to_laplace_start()` — evidence

| Check | Result |
|---|---|
| `eta` preserved, synthetic fixture | 1.33e-15 |
| `eta` preserved, **live VGH fit** (scale 3.209) | **4.44e-16** |
| `G = Lambda Lambda'` preserved, live fit | 2.22e-16 |
| packed length, 5 traits @ rank 2 | 9 (reduced form; dense would be 10) |
| `z` orientation | 2 x 60 (rank x units) |
| strict-upper after rotation | 2.96e-17 |
| test suite | 19 assertions, 0 failures |
| **negative control**: Lambda-only rotation moves `eta` | **5.55** — fires |

Five silent-failure modes are now hard errors: score rotation, the rank-x-units
transpose, the reduced packed length, `.gllvmTMB_pack_rr_theta()` discarding the
strict upper triangle unchecked, and `.gllvmTMB_apply_start_from()` skipping a
mismatched start in silence (`.vgh_assert_start_landed()`).

### 3. `Psi` — fail closed, documented

VGH fits `Sigma = Lambda Lambda'` with no diagonal tier; `theta_diag_B` defaults
to `0.0`, i.e. **sd 1.0 per trait** (`src/gllvmTMB.cpp:995`). Seeding VGH's
`Lambda` into a model with a free diagonal inflates every trait's starting
variance by exactly 1.0 — a start *further* from the optimum than a cold one, and
invisible in a mean speedup number. Decision and reasoning:
`docs/dev-log/2026-07-29-vgh-phase2-psi-scope.md`. VGH's own admission guard
already refuses Psi data (`R/va-vgh.R:377-381`), so the fence exists upstream; the
wiring must simply never invent a `Psi`.

### 4. PR #819 preconditions

- **Reconciled by merging, not rebasing** — the branch is pushed with an open PR,
  so a rebase would force-push published history. Automatic merge, no conflicts
  (`a4d7a08d`), pushed as a fast-forward. PR #819 is now **MERGEABLE**.
- **`rcmdcheck --as-cran`: 0 errors, 0 warnings, 1 NOTE** — the note is the benign
  "New submission / Maintainer" CRAN-incoming note. This is the full check Phase 1
  never ran.

## Corrections to my own plan, made mid-flight

1. **Do NOT prune `dev/vgh/*`.** The plan called it scratch to strip from #819.
   It is not: `dev` is in `.Rbuildignore:21`, so it never reaches the check, and
   commit `c18ccc51` deliberately *preserved* the `ab-runs` receipts from a
   volatile worktree. Deleting them would have destroyed evidence another lane had
   just rescued.
2. **My own oracle asserted a promise the code shouldn't make.** The first run
   failed on "transform rejects a mismatched pair". The transform measures `eta`
   before and after *its own* rotation, so it faithfully preserves an upstream
   corruption. The code was right and the test was wrong; the boundary is now
   documented in `R/vgh-warmstart.R` rather than papered over.

## State, and what is blocked on whom

| Item | State |
|---|---|
| Merge reconciliation | **done**, pushed |
| `rcmdcheck --as-cran` on the merged Phase-1 tree | **green** (0/0/1) |
| PR #819 merge | **blocked — maintainer only.** `R/va-vgh.R` is package code; the repo's merge rule reserves the merge. Not an agent action. |
| S3 wiring into `R/fit-multi.R` | **blocked twice**: the corrected sequence puts Phase 2 code after #819 lands, and **PR #818 (REML lane) touches the same file** |
| S5 Totoro campaign | needs S3. Totoro verified reachable (384 cores, load 0.23) |

## Not established

- The green check covers the **merged Phase-1 tree**, which is exactly what #819
  contains. It does **not** cover the Phase 2 files added afterwards; those need
  their own check before they land.
- No speedup has been measured. The `>=1.5x` claim has no evidence yet, and the
  multimodality risk (a warm start converging to a *different* optimum) remains
  entirely untested — that is what the per-seed campaign is for.
