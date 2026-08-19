# Claude → Claude handover — 2026-08-19 (random-slope / D-113 track 6)

You are picking up the **random-slope lane**. The authoring chat is gone; this document,
the repo, and the merged PRs are authoritative.

**START BY RUNNING** `bash ~/shinichi-brain/tools/lane_preflight.sh <repo>` — 43+ lanes were
live at handover and commits land on `main` all day. Then reconcile this file against
`git log origin/main` and classify every item `OWED` / `DONE` / `BLOCKED`.

> **MULTI-LANE REPO.** This is ONE lane's handover. The lane map
> (`docs/dev-log/handover/2026-07-25-active-lane-split.md`) is authoritative for ownership.

---

## What this lane was

Shinichi asked three questions: **can random slopes work for all distributions**, can we at
least get them **tested with intervals feasible**, and **is the capability board correct**.

The prior-work sweep reframed the whole job: this is **D-113 track 6** (Shinichi 2026-08-01,
*"at least one random slope for each distribution"*), and it was **11/16 family ids already
done** — not unstarted. Without that sweep this would have been planned as engine work.

## The three answers

1. **No engine work needed.** The TMB engine is family-agnostic for slopes: every slope
   contribution enters `eta` in one loop (`src/gllvmTMB.cpp:2468-2612`) that never reads
   `family_id_vec`; the family dispatch opens after it at `:2625`. Every refusal is R-side
   evidence policy in `.augmented_slope_family_contract()` (`R/fit-multi.R:453`), governed by
   the #388 rule at `:2044` — *a family joins the allowlist ONLY after its recovery cell passes*.
   **The one genuine engine gap: bare-bar `(1 + x | g)` has no C++ block at all.**
2. **Intervals are computable and now shipped** — `slope_sd_ci()`, merged.
3. **The board was wrong on five cells, every one UNDERSTATING the package.** Corrected.

## Merged to `main` (all verified present)

| PR | What |
|---|---|
| #1157 | the carried-over baton from the prior session (one-hot subset search) |
| #1164 | rand-slope arc — board correction, truth ledger, interval feasibility, Design 128 |
| #1166 | **`slope_sd_ci()` — new public export**, diagonal route (slice 1) |
| #1171 | truncated_poisson D-139 pre-run test: **PASS** |

## Landing State ledger

| Item | State | Resume |
|---|---|---|
| **PR #1175** slice 2 (ADREPORT) | **CARRIED-OVER — draft, pushed, UNMERGED** | See below. Needs Shinichi's sign-off: it changes `src/` and the `sdreport()` payload |
| Full suite for slice 2 | **was still running at handover** | Re-run `NOT_CRAN=true devtools::test()` to completion before recommending a merge |
| `Rose-slice2` audit | in flight, verdict not delivered | Re-run a fresh adversarial pass if its verdict never landed |
| Worktrees `/private/tmp/gllvmtmb-{randslope,slopeci,tpcell,slice2}` | scratch; branches merged except slice2 | safe to remove once #1175 resolves |

## PR #1175 — what it is and what still needs checking

Slice 1 errored on `phylo_indep(1 + x | species)` — the route that matters most for a
phylogenetic GLLVM. Slice 2 `ADREPORT()`s the marginal slope SD vectors in C++ so
`sdreport()` runs the delta method against the TMB-authoritative packing.

**Verified already (by the coordinator, independently):**
- The **hoist is behaviour-preserving** — `Sigma_B_slope` / `Sigma_B_unique_slope` moved to
  outer scope with `setZero()`, but reads are flag-guarded (`if (use_diag_B_slope == 1)` at
  `src/gllvmTMB.cpp:1620`, `if (use_rr_B_slope == 1)` at `:1657`).
- **Shared-`j` indexing is safe by construction**: `n_lhs_cols_B_lat` and
  `n_lhs_cols_B_diag` are both `2L * .n_traits_for_dep` when their flags are on.
- **114/114 pass** with `GLLVMTMB_HEAVY_TESTS=1` (102 by default).
- Cost: no measurable `sdreport()` slowdown; position-indexing: all 4 ADREPORT consumers
  filter by name.

**STILL OPEN before merging:** the full suite to completion, CI green, and — flagged for
Shinichi — **the phylo cross-check is heavy-gated**, so the guard on the headline route does
NOT run in default CI. House convention for `phylo_dep` fits, but a real gap.

## 🔴 The finding with the longest reach

**The campaign cost model was wrong by ~3 orders of magnitude.** Design 128's cited
"2.5–3.5 h" is the betabinomial **arc** total (authoring, tests, review, CI), NOT fit time.
Measured: `poisson` 9.2 s at `n_sp = 250`, 15.3 s at 300; `truncated_poisson` **20.35 s**,
`convergence = 0`, `pdHess = TRUE`, pooled ratio 1.047.

**Consequence:** these campaigns are **authoring-bound, not compute-bound**. No Totoro
(D-143 moot). D-139's >30-min gate does not bind the compute. And the single-seed scoping
that keeps cells at `partial` was a response to a cost that does not exist.

## Recommended next arc (NOT started)

**The multi-seed n-ladder for the ELEVEN already-admitted families.** That is the actual bar
for moving a RAND. SLOPE cell from `partial` to ✓ — the column has **zero** green checks
today precisely because every cell rests on a single seed. At ~10–20 s a fit this is minutes
of compute. It beats the designed campaign, which only adds a twelfth family at `partial`.

Also unowned and fair game: **#897 / #1097** (ordinal degeneracy — read
`dev/ordinal-degeneracy/pass-criteria-curvature.md` §8.2a FIRST, seven candidates already
eliminated), **#1134**, **#1149**, **#813**.

## Gotchas that cost time in this session

- **`ADREPORT` is not needed for fixed-effect SEs** — `sdreport()` already returns them for
  every `PARAMETER`. It IS needed for derived quantities. Getting this wrong sent a probe
  looking for slope SDs under names that route does not use.
- **Small-n slope fits produce plausible garbage**: `θ = -13.5` with `se = 61883`, another
  `NaN`, both with non-PD Hessians. An SE off a non-PD Hessian is not a standard error.
- **A wrong array index arrives with a cover story.** `theta_dep_chol` packs ALL diagonals
  first, then the strictly-lower triangle column-major — slope diagonals are **2/4/6**, not
  2/5/8. The wrong version was explained away as "expected single-seed noise".
- **Do not cite register codes in roxygen.** `test-reader-facing-no-register-codes.R` scans
  `man/*.Rd`. This failed the full suite once.
- **A naive timing A/B on this shared Mac lies.** A single before/after showed a 4.5×
  `sdreport()` slowdown that REVERSED under an alternating-build comparison — other lanes'
  CPU load.
- **`check-log.md` is the shared append surface**; expect a conflict on every PR and resolve
  by keeping BOTH entries.
- **Sub-agents stall on their own background monitors.** Several burned rounds waiting; run
  R in the foreground or poll actively.

## Needs Shinichi

1. **Sign-off on #1175** (changes the `sdreport()` payload — reaches every fit).
2. **#1080 item 3** — the `shape_gamma`/`cv_gamma_delta`/`scale_student` rename (breaking).
   🔴 **#1080 item 4 is SETTLED — do not re-open** (gllvmTMB #856, 2026-07-31).
3. The two collaborator-name mentions in PRs #1150/#1157.

---

## 🔴 ADDENDUM — Rose's adversarial verdict on #1175: **CHANGES REQUIRED**

Landed after the body above was written. **No defect in `src/`** — the hoist and the
dimension assumption were independently confirmed safe (and `origin/main` was rebuilt
side-by-side: 4 compiler warnings each, byte-identical, all in Eigen). But **do not merge
#1175 until these are fixed**:

1. **The headline capability is UNTESTED.** `total_lower` / `total_upper` / `total_status`
   are asserted only where they trivially equal `lower`/`upper`. The `adr_tot$ok == FALSE`
   branch degrades silently to `"unavailable"` + NA and no test would notice. Rose verified
   the path works (C++ `sd_B_slope_total` matches an R-side reconstruction to max abs diff
   **0**), so this is a missing guard, not a bug.
2. **The "INDEPENDENTLY constructed" cross-check claim is FALSE as written** — in CI-15,
   the after-task §6/§4c, AND in the coordinator's own report to Shinichi. `sd_b(j) =
   sqrt(Sigma_b_dep(j,j))` are the SAME C++ quantity, so that assertion is an algebraic
   restatement guarding R-side position selection, not C++ packing. **The packing IS tested
   — by the ground-truth recovery assertion** (known `L`, slope SDs chosen off-diagonal-
   dependent). Credit the right assertion; the claim "would have caught the 2/5/8 bug on
   day one" is false as attached.
3. **Rename the loadings-only test** — titled "recovers a known-truth slope SD" but asserts
   no truth, only `estimate > 0.01 & < 1` (under `unique = FALSE` the fit is misspecified
   against the Psi-generated fixture, so there is no clean truth). Soften "recovery cell"
   for that route in CI-15.
4. **`<<FULL_SUITE_TAIL>>` is still a literal placeholder** in after-task §7 while §5 claims
   the suite was run to completion. Real tail: `[ FAIL 0 | WARN 9 | SKIP 877 | PASS 16305 ]`.
5. **The consumer audit under-counted.** `summary.sdreport` defaults to `select = "all"`,
   which INCLUDES the report block; four test files use the bare form
   (`test-matrix-slope-{poisson,phylo-dep,phylo-latent,spatial-latent}.R`), and the
   phylo-dep one is exactly a fit that gains `sd_b` rows. All four filter by name and no
   name collides, **so the conclusion survives — but by luck of the grep, not by the stated
   coverage.** The layout shift is real: `b_fix` moved 12 rows.
6. **Soften the cost claim**; drop the mtime argument. "`cov.fixed` unaffected by ADREPORT
   count at all" overreaches — evidence supports "not measurably affected at this scale".
   And §9's "the `.so` was newer than the `.cpp`, so the baseline was fresh" is backwards:
   that is exactly when `make` SKIPS the rebuild. (`compile_dll(force = TRUE)` does not
   clean `.o` — rebuild independently.)
7. *(Optional)* Revert the `Sigma_B_unique_slope` hoist — its only reader sits INSIDE the
   `if (use_diag_B_slope == 1)` block it was already local to, so the hoist buys nothing and
   widens the diff in the repo's highest-risk file.

**Process lesson for the next session:** two agents shared the slice-2 worktree; the builder
rebased over the coordinator's commits (nothing lost, but verified rather than assumed), and
Rose spent part of her audit on a moving tree. **Stop an agent explicitly rather than
trusting its "done" report.**
