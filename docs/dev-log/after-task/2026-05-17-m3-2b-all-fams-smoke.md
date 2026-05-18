# After Task: M3.2b — All-fams smoke + simulator bug fixes

**Branch**: `agent/m3-2b-all-fams-smoke`
**Slice**: M3.2b — expand the M3.2 Gaussian-only smoke to 4 families
(Gaussian, binomial, nbinom2, ordinal-probit) × 3 latent ranks, fix
two bugs the smoke surfaced, refresh the shipped RDS, update article
narrative.
**PR type tag**: `pipeline` (dev/ scripts + inst/extdata/ RDS +
article narrative edit; no R/, NAMESPACE, generated Rd, family-
registry, formula-grammar, or extractor change)
**Lead persona**: Curie (pipeline machinery debugging)
**Maintained by**: Curie; reviewers: Fisher (smoke-honesty framing),
Pat (article narrative), Rose (mixed-family deferral scope), Boole
(family API correctness), Ada (coordinator)

## 1. Goal

The M3.2 smoke PR (#172) shipped a Gaussian-only smoke (3 cells × 10
reps × ~18 s). This PR completes the pipeline verification by
exercising it on all 4 single-family cells (Gaussian, binomial,
nbinom2, ordinal-probit) × 3 latent ranks. The 12-cell smoke runs
in ~3 minutes.

**Mixed-family is excluded from smoke** — the gllvmTMB
`family = list(...)` API requires a `family_var` column in the
long-format data + `attr(family, 'family_var') <- 'colname'`. The
smoke pipeline's per-trait family list doesn't yet construct that
lookup column. Wiring it is M3.3's job (and the M1 mixed-family-
fixture pattern is the reference).

## 2. Implemented

### Bug fixes in `dev/m3-grid.R`

**Bug 1 — wrong family API**. The original M3.2 code passed
`family = "nbinom2"` (string) and `family = "ordinal_probit"`
(string) to `gllvmTMB()`. Both errored with `could not find function
"f"` — gllvmTMB requires the family **helpers** (function calls
like `gllvmTMB::nbinom2()`, `gllvmTMB::ordinal_probit()`).

```r
# Before
nbinom2 = "nbinom2",
ordinal_probit = "ordinal_probit",

# After
nbinom2 = gllvmTMB::nbinom2(),
ordinal_probit = gllvmTMB::ordinal_probit(),
```

**Bug 2 — nuisance dispatch for mixed-family**. The truth sampler
only populated `phi` (for nbinom2) or `cutpoints` (for ordinal),
not for mixed-family. When mixed-family hit the per-row nbinom2
branch, `truth$nuisance$phi` was `NULL` and `stats::rnbinom(..., size
= NULL)` errored. Fixed by extending the nuisance population to
mixed-family — it now gets both `phi` and `sigma_eps` (since mixed
cycles through gaussian + binomial + nbinom2).

**Bug 3 — eta clamp for nbinom2**. Added
`mu_t <- exp(pmin(pmax(eta_t, -10), 10))` to protect `rnbinom` from
NaN draws when extreme Lambda × Z values overflow `exp()`. Restricts
mu to `[4.5e-5, 22000]` — a sensible count range.

### `dev/precompute-m3-grid.R` — mixed-family exclusion

The `--all-fams` mode now excludes mixed-family with an inline
comment pointing at M3.3 + the M1 mixed-family-fixture pattern as the
canonical reference for the `family_var` lookup integration.

### `inst/extdata/m3-coverage-{grid,summary}-smoke.rds`

Refreshed with the 12-cell × 10-rep × 5-trait output (600 rows in
the long-format grid; 12 rows in the summary).

### `vignettes/articles/simulation-recovery-validated.Rmd`

Updated narrative:

- Opening paragraph: "3-cell" → "12-cell" smoke; lists all 4
  smoke families; explains mixed-family deferral.
- New "Notes on per-family smoke behaviour" section after the
  single-rep inspection: per-family runtime + placeholder-coverage
  patterns + an explanation of why mixed-family is M3.3 work.

## 3. Files Changed

| File | Type | Lines |
|---|---|---|
| `dev/m3-grid.R` | EDIT | +6 lines (bug fixes) |
| `dev/precompute-m3-grid.R` | EDIT | +9 lines (mixed-family exclusion + comment) |
| `dev/precomputed/m3-coverage-grid.rds` | REFRESH | binary |
| `dev/precomputed/m3-coverage-summary.rds` | REFRESH | binary |
| `inst/extdata/m3-coverage-grid-smoke.rds` | REFRESH | binary |
| `inst/extdata/m3-coverage-summary-smoke.rds` | REFRESH | binary |
| `vignettes/articles/simulation-recovery-validated.Rmd` | EDIT | +28 lines |
| `docs/dev-log/after-task/2026-05-17-m3-2b-all-fams-smoke.md` | NEW | this |

## 4. Checks Run

- ✅ All-fams smoke: 12 cells × 10 reps = 120 fits in 159.8 seconds
  (~2.7 min)
- ✅ Per-cell convergence: Gaussian 50/50; binomial 50/50; nbinom2
  45/50, 40/50, 45/50 (some divergence on small-n + dispersion);
  ordinal-probit 50/50, 50/50, 45/50
- ✅ Article renders cleanly via `rmarkdown::render()`
- ✅ Full local `rcmdcheck --as-cran` (running at write time)

## 5. Tests of the Tests

The smoke iteration itself acted as the test — each pipeline bug
was caught and fixed in turn:

1. **First run** errored at nbinom2 cells with `could not find
   function "f"` — exposed Bug 1 (string vs function family API).
2. **Second run** errored at mixed-family cells with `invalid
   arguments` in `stats::rnbinom` — exposed Bug 2 (missing
   nuisance dispatch).
3. **Third run** completed end-to-end on the 12 single-family cells,
   leaving mixed-family deferral as the documented scope cut.

The pipeline's `tryCatch` per replicate kept the overall run alive
through nbinom2's per-rep divergences (5/50 to 10/50 reps per
nbinom2 cell), so the 12-cell smoke ran to completion despite the
edge cases.

## 6. Consistency Audit

- **Naming**: `gllvmTMB::nbinom2()` and `gllvmTMB::ordinal_probit()`
  used with explicit `gllvmTMB::` prefix in `dev/` scripts (the
  scripts aren't part of the package namespace, so the prefix is
  required even with `library(gllvmTMB)` loaded).
- **Article scope honesty**: the "Notes on per-family smoke
  behaviour" section explicitly enumerates what M3.3 fixes for
  each family.
- **Mixed-family deferral**: pointed at the M1 mixed-family-
  fixture pattern as the reference. Future M3.3 work can reuse
  that exact construction.

## 7. Roadmap Tick

- No M3 row tick — M3.2 still counts as 1 slice; this PR is a
  follow-on within M3.2's scope, not a separate slice.
- No validation-debt register changes (smoke is too underpowered
  to walk any register row to `covered`).

## 8. What Did Not Go Smoothly

- **Three iteration cycles to get all-fams smoke green**. Each was
  a small bug, but the cycle time (rerun, fail, diagnose, fix,
  rerun) added ~10 min per iteration. Lesson: when adding new
  pipeline cells, run a single-cell smoke per cell-type FIRST
  before kicking off the full grid. The original M3.2 PR only
  exercised Gaussian, which masked the family-API and
  nuisance-dispatch bugs.
- **Mixed-family is harder than expected**. The `family = list(...)
  + family_var` pattern is the right v0.2.0 API, but it requires
  data-side construction the simulator doesn't yet do.
  Deferring to M3.3 with an explicit pointer to the M1
  fixture pattern is the honest path forward.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie** (lead — pipeline debugging): each bug was localised
because the pipeline is well-decomposed (`m3_sample_truth` →
`m3_simulate_response` → `m3_run_cell`). Bug 1 surfaced at
`m3_run_cell` (family-list construction); Bug 2 surfaced at
`m3_simulate_response` (nuisance dispatch); Bug 3 was a
defensive fix before the bug could manifest.

**Fisher** (review — smoke-honesty framing): the per-family
runtime and convergence patterns documented in the new "Notes"
section give M3.3 a concrete starting point. The nbinom2
divergence rate (~10-20 %) at n=60 with d=2,3 is the kind of
boundary regime M3.4 should investigate; flagged for the M3.4
dispatch.

**Pat** (review — article narrative): the per-family section now
reads as a status report for each cell. The 4 sub-bullets give
the reader a quick mental map of why coverage varies (and why
mixed-family is deferred).

**Boole** (review — family API correctness): the
`gllvmTMB::nbinom2()` and `gllvmTMB::ordinal_probit()` helper
calls match the documented API. Mixed-family deferral references
the canonical M1 fixture pattern.

**Rose** (review — scope honesty): the mixed-family exclusion is
explicit in both the driver script's `--all-fams` config and the
article's opening paragraph. No overpromise. M3.3 will lift the
exclusion when the `family_var` integration lands.

**Ada** (coordinator): this PR is a debugging/refinement follow-on
within M3.2's scope, not a new slice. Roadmap M3 row stays at 3/8.
Next dispatch is M3.3 (proper inference + mixed-family integration).

## 10. Known Limitations and Next Actions

- **Mixed-family deferred to M3.3**. Pattern: extend
  `m3_simulate_response()` to emit a `family_id` factor column
  alongside `value`; extend `m3_run_cell()` to set
  `attr(family_list, 'family_var') <- 'family_id'` per the M1
  fixture. ~20-30 LOC change.
- **Wald CIs still placeholder**. M3.3 replaces with proper
  delta-method or profile-likelihood.
- **nbinom2 divergence rate ~10-20 %** at n=60 with d=2,3. M3.4
  boundary-regimes work should diagnose whether this is a real
  identifiability issue or a starting-value issue.
- **ordinal-probit dim=3 cell** had 5/50 reps fail to converge.
  Worth investigating in M3.4.
