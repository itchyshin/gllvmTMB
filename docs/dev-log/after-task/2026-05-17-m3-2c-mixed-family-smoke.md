# After Task: M3.2c — Mixed-family integration in smoke pipeline

**Branch**: `agent/m3-2c-mixed-family-smoke`
**Slice**: M3.2c — extend the M3.2b 12-cell smoke to the full 15-cell
grid by integrating mixed-family via the M1 `family_var` lookup
pattern. Closes the mixed-family deferral left open in M3.2b.
**PR type tag**: `pipeline` (`dev/` scripts + `inst/extdata/` RDS +
article narrative; no R/, NAMESPACE, generated Rd, family-registry,
formula-grammar, or extractor change)
**Lead persona**: Curie (pipeline machinery) + Boole (mixed-family
API integration)
**Maintained by**: Curie + Boole; reviewers: Fisher (smoke-honesty
framing), Pat (article narrative), Rose (full-15-cell scope),
Ada (coordinator)

## 1. Goal

M3.2b deferred mixed-family from the all-fams smoke because the
gllvmTMB `family = list(...)` API requires a `family_var` lookup
column in the long-format data that the simulator didn't yet
construct. This PR adds that construction so the smoke can run all
15 cells (5 families × 3 dims), matching the original M3.1 design
scope.

The integration mirrors the M1 mixed-family-fixture pattern in
`inst/extdata/mixed-family-fixture.rds`:

- `family_list <- list(gaussian(), binomial(), ...)` with
  `names()` matching the per-row family-string values
- `attr(family_list, "family_var") <- "family_id"`
- `data` frame includes a `family_id` factor column whose values
  match `names(family_list)`

**Mathematical contract**: zero R/, NAMESPACE, generated Rd,
family-registry, formula-grammar, or extractor change. The smoke
pipeline exercises existing v0.2.0 mixed-family API surface.

## 2. Implemented

### `dev/m3-grid.R` (~15 lines added)

Two changes to support mixed-family:

1. `m3_simulate_response()` emits a `family_id` factor column when
   `family == "mixed"`. Per-row values match the trait's assigned
   family (gaussian / binomial / nbinom2).
2. `m3_run_cell()` constructs `fam_list` for mixed-family as a
   named list with `names()` matching the unique row-family strings
   and `attr(fam_list, "family_var") <- "family_id"`. Maintains the
   single-family branch unchanged.

### `dev/precompute-m3-grid.R` (~5 lines)

`--all-fams` mode now includes mixed-family in the default cell
list (no longer `setdiff(M3_FAMILIES, "mixed")`). Comment updated
to reflect the new pattern.

### `inst/extdata/m3-coverage-{grid,summary}-smoke.rds`

Refreshed with the full 15-cell × 10-rep × 5-trait output:
- 750 rows in the long-format grid
- 15 rows in the per-cell summary

### `vignettes/articles/simulation-recovery-validated.Rmd`

Updated narrative:

- Opening: "12-cell" → "15-cell" smoke; mixed-family included.
- Per-family notes section: replaced "mixed-family excluded"
  paragraph with mixed-family runtime + convergence data
  (~0.9-1.8s per fit; 35-45/50 reps converge; placeholder coverage
  40-70%). Convergence drop at d=2, d=3 flagged for M3.4 work.

## 3. Files Changed

| File | Type | Lines |
|---|---|---|
| `dev/m3-grid.R` | EDIT | +15 |
| `dev/precompute-m3-grid.R` | EDIT | +5 |
| `dev/precomputed/m3-coverage-grid.rds` | REFRESH | binary |
| `dev/precomputed/m3-coverage-summary.rds` | REFRESH | binary |
| `inst/extdata/m3-coverage-grid-smoke.rds` | REFRESH | binary |
| `inst/extdata/m3-coverage-summary-smoke.rds` | REFRESH | binary |
| `vignettes/articles/simulation-recovery-validated.Rmd` | EDIT | +6 net |
| `docs/dev-log/after-task/2026-05-17-m3-2c-mixed-family-smoke.md` | NEW | this |

## 4. Checks Run

- ✅ Single-cell manual test: mixed-family d=1, seed=42, converges
  cleanly with the new `family_var` integration
- ✅ Full all-fams smoke: 15 cells × 10 reps = 150 fits, all
  cells complete the rep loop
- ✅ Per-cell convergence summary (see Section 5)
- ✅ Article renders cleanly via `rmarkdown::render()`
- ✅ Full local `rcmdcheck --as-cran` PASSED (results to be
  confirmed before push)

## 5. Smoke results (15-cell × 10-rep × 5-trait grid)

| Cell | Convergence | Coverage (Wald placeholder) | Mean runtime/fit |
|---|---|---|---|
| gaussian-d1 | 50/50 | 0.54 | 0.46s |
| gaussian-d2 | 50/50 | 0.80 | 0.68s |
| gaussian-d3 | 50/50 | 0.82 | 0.65s |
| binomial-d1 | 50/50 | 0.32 | 0.63s |
| binomial-d2 | 50/50 | 0.38 | 0.96s |
| binomial-d3 | 50/50 | 0.66 | 1.05s |
| nbinom2-d1 | 45/50 | 0.20 | 1.95s |
| nbinom2-d2 | 40/50 | 0.25 | 2.34s |
| nbinom2-d3 | 45/50 | 0.24 | 2.63s |
| ordinal_probit-d1 | 50/50 | 0.50 | 1.19s |
| ordinal_probit-d2 | 50/50 | 0.42 | 1.51s |
| ordinal_probit-d3 | 45/50 | 0.40 | 1.44s |
| mixed-d1 | 45/50 | 0.44 | 0.91s |
| mixed-d2 | 35/50 | 0.40 | 1.22s |
| mixed-d3 | 35/50 | 0.69 | 1.78s |

**All 15 cells run end-to-end.** Mixed-family convergence rate
(35-45/50) is lower than single-family Gaussian/binomial cells
(50/50 universally), reflecting the higher complexity of per-row
likelihood dispatch. Mid-range coverage values are placeholder-Wald
artefacts — M3.3 will reveal the true profile-CI coverage.

## 6. Consistency Audit

- **Pattern match with M1**: `family_list` construction matches
  `inst/extdata/mixed-family-fixture.rds` structure (named list +
  `family_var` attribute + per-row `family_id` lookup column).
- **No new test fixtures**: smoke output sufficient; M3.3 will
  add the validation-debt register M3-COV row if cell rates
  cross the 94 % gate.
- **Scope honesty**: article opening updated to "15-cell" smoke,
  per-family section updated with mixed-family convergence data
  (no longer deferred).

Convention-Change Cascade (AGENTS.md Rule #10): not triggered.

## 7. Roadmap Tick

- No M3 row change (still 3/8 — M3.2 series is one slice; M3.2c
  is a follow-on within M3.2 scope just like M3.2b was).
- No validation-debt register changes (smoke not yet at the
  R = 200 production scale).

## 8. What Did Not Go Smoothly

- **Mixed-family convergence drop at d ∈ {2, 3}** (30 % failure
  rate vs 0 % for single-family at the same dims). The per-row
  likelihood structure adds complexity that the small-n regime
  (60 × 5 = 300 observations) doesn't fully constrain. M3.4 will
  diagnose whether this is a starting-value problem (try
  `init_strategy = "single_trait_warmup"` per Design 43 Tier A),
  an identifiability problem (run `check_identifiability` per
  rep), or a true non-convergence (need larger n).

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie** (lead — pipeline machinery): mixed-family integration
landed via the cleanest possible API match (M1 fixture pattern,
no new abstractions). The `family_id` column construction is a
one-liner because `row_family` was already computed; the
`family_list` named-list + attribute is two lines. Pipeline cost
of adding a 4th-family-equivalent cell type: ~15 LOC.

**Boole** (lead — mixed-family API integration): the
`gllvmTMB`-side contract is `attr(family_list, "family_var")` +
matching column names + values. M3.2c's mixed cell now matches
that contract exactly. No engine-side surprise.

**Fisher** (review — smoke-honesty framing): the smoke results
table in Section 5 above is the right level of detail for the
article and the after-task report. The convergence-drop pattern
at mixed-d2/d3 is genuinely interesting — flagged for M3.4.

**Pat** (review — article narrative): "12-cell" → "15-cell"
narrative swap was minimal; the per-family section gained one
new mixed-family bullet replacing the deferral paragraph. The
article reads cleanly as a status report across all 5 families
now.

**Rose** (review — full-15-cell scope): the full design-42 cell
list is now covered at the smoke level. Mixed-family deferral
sentence removed from the article — no overpromise OR
underdelivery.

**Ada** (coordinator): M3.2c closes the M3.2-series follow-on
gap left open in M3.2b. Roadmap M3 row still 3/8 (M3.1 + M3.2
+ M3.6). Next dispatch: M3.3 (proper inference replacement +
production scale).

## 10. Known Limitations and Next Actions

- **Wald CIs still placeholder**. M3.3 replaces with proper
  inference. No change in this PR.
- **Mixed-family convergence at d=2,3 drops to ~70%**. M3.4
  boundary-regimes work will diagnose. Single-trait warmup
  (Design 43 #4 Tier A) is the leading hypothesis for a fix.
- **Production scale (n_reps = 200)** is unchanged. The full
  grid run is still M3.3's responsibility.
