# After Task: M1.2 — mixed-family fixture (M1-PR-A2)

**Branch**: `agent/m1-2-mixed-family-fixture`
**PR type tag**: `validation` (test fixture + smoke test; no R/ API change, but new internal helpers)
**Lead persona**: Curie (DGP + reproducibility)
**Maintained by**: Curie + Boole; reviewers: Emmy (extractor consumers); Grace (CI integration); Ada (close gate)

## 1. Goal

Second M1 deliverable per the slice contract in `ROADMAP.md`:
ship a deterministic mixed-family **test fixture** so the M1.3..M1.8
extractor PRs can write byte-stable tests without each one
re-defining its own DGP.

The fixture covers two variants:

- **3-family**: Gaussian + binomial + Poisson, 60 sites × 3 traits.
- **5-family**: + Gamma + nbinom2, 60 sites × 5 traits.

Both are produced by a seeded builder (`seed = 20260517L`) and
cached as data only (not as fitted objects — see §2 for the
TMB-portability rationale).

## 2. Implemented

### Mathematical contract

**No R/ API change** (no new `@export`). Internal helpers
`load_mixed_family_fixture()`, `fit_mixed_family_fixture()`, and
`.build_mixed_family_fixture()` live in `R/data-mixed-family.R`
with `@keywords internal` + `@noRd`. They're accessed via
`gllvmTMB:::` triple-colon from M1 extractor tests.

### Files added

- **`R/data-mixed-family.R`** — the builder + loader + fitter
  helpers (~150 lines incl. doc comments).
- **`data-raw/mixed-family-fixture.R`** — regeneration script for
  the cached RDS. Run from repo root via
  `Rscript data-raw/mixed-family-fixture.R`.
- **`inst/extdata/mixed-family-fixture.rds`** (79 KB) — the
  cached DGP data + truth (data frames + Lambda_B + psi_B +
  family assignments).
- **`tests/testthat/test-m1-2-mixed-family-fixture.R`** — 6 smoke
  tests verifying shape, cache–builder identity (on load-bearing
  columns), and fit convergence.

### Design — why we cache *data*, not *fits*

A fitted `gllvmTMB_multi` object embeds a TMB `obj` environment
that holds C++ pointers. `saveRDS` serialises the R-side
structure but those pointers are **not portable** across R
sessions or TMB rebuilds; methods that rely on them
(`obj$report()`, `obj$fn()`, profile CIs) silently fail after
reload.

The portable contract is therefore: ship the *data* and the
*DGP truth* (`Lambda_B`, `psi_B`, family assignments) in the
cached RDS, and rebuild the fit on demand with a deterministic
seeded builder. Re-fits are fast (3-family: ~0.5 s; 5-family:
~1.7 s on a 2025 laptop) so the cost is acceptable for tests
that run once per file.

This design choice is documented in the top-of-file comment in
`R/data-mixed-family.R`.

### DGP details

The 5-family Lambda_B matrix gives each trait a clear share of
two latent axes:

```
trait_1 (gaussian):  ( 1.0,  0.3)
trait_2 (binomial):  ( 0.7, -0.5)
trait_3 (poisson):   (-0.3,  0.8)
trait_4 (Gamma):     ( 0.6,  0.2)
trait_5 (nbinom2):   ( 0.4, -0.4)
psi_B = rep(0.3, n_traits)
```

The 3-family variant uses the first three rows.

After `simulate_site_trait()` returns Gaussian-scale `value`,
each row is cast per family with **group-wise mean centring** to
keep each family's distribution non-degenerate:

| Family | Cast | Resulting distribution (5-family) |
|---|---|---|
| `gaussian` | identity | mean 0.5, sd 1.5, range −3..5 |
| `binomial` | `as.integer((v − mean(v)) > 0)` | balanced 50/50 |
| `poisson` | `pmax(0L, as.integer(round(v − mean(v) + 2)))` | mean 2, range 0–5 |
| `Gamma` | `exp(v − mean(v))` | mean 1, range 0.04–28.5, sd 5.2 |
| `nbinom2` | `pmax(0L, as.integer(round(exp(v − mean(v) + 1.5))))` | mean 7, range 0–36, sd 7.0 |

Initial draft used row-wise mean (via `mapply`), which collapsed
to scalars; the group-wise loop is the correct shape.

### Convergence verification

Both fits converge in the fitter wrapper (`fit_mixed_family_fixture()`),
which asserts `fit$opt$convergence == 0` and aborts otherwise:

- 3-family: convergence = 0; logLik = -240.16; ~0.5 s
- 5-family: convergence = 0; logLik = -514.03; ~1.7 s

## 3. Files Changed

```
Added:
  R/data-mixed-family.R                                 (~150 lines)
  data-raw/mixed-family-fixture.R                       (~30 lines)
  inst/extdata/mixed-family-fixture.rds                 (79 KB)
  tests/testthat/test-m1-2-mixed-family-fixture.R       (~80 lines, 6 tests)
  docs/dev-log/after-task/2026-05-17-m1-2-mixed-family-fixture.md   (this file)
```

No NAMESPACE change (helpers are internal). `data-raw/` is
already in `.Rbuildignore` (line 18).

## 4. Checks Run

- **6 / 6 tests pass** (`NOT_CRAN=true Rscript -e 'devtools::load_all(".")' ; testthat::test_file(...)`).
- `pkgdown::check_pkgdown()` → ✔ No problems found.
- `inst/extdata/mixed-family-fixture.rds` resolves via
  `system.file()` in both isolated `Rscript` calls and
  `testthat::test_that()` blocks.
- Both fits converge.

## 5. Tests of the Tests

3-rule contract from `docs/design/10-after-task-protocol.md`:

- **Rule 1** (would have failed before fix): the cache vs
  builder identity test (test #3 in the file) initially failed
  with a 2-FAIL because the C-locale collation inside
  testthat's `withr::local` re-sorts factor levels differently
  from the system locale used to build the cache. The fix —
  comparing the load-bearing columns (site, trait, family,
  value, env_1, env_2) plus `as.character(site_species)`
  instead of the factor object — narrows the test to the
  **contract** (data values) and away from the **implementation
  detail** (factor-level sort order). The pre-fix mode would
  have surfaced locale brittleness on any CI runner with a
  different locale, so the narrowing is a permanent improvement.
- **Rule 2** (boundary): `n_families ∈ {3, 5}` is the
  match.arg boundary; smaller (1, 2) is rejected.
- **Rule 3** (feature combination): the non-degenerate-spread
  test (test #6) asserts `sd(value) > 0.1` per family on both
  fixtures; combined with the determinism + fit-convergence
  tests, this exercises (data shape + family dispatch +
  convergence) jointly.

## 6. Consistency Audit

Stale-wording rg sweep on the PR diff:

- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|meta_known_V as primary|phylo_rr\\(|gr\\(|block_V\\("` on the new files → 0 hits.
- The fixture truth uses `psi_B` (canonical lowercase psi); no
  `S_B / S_W` notation.

Convention-Change Cascade (AGENTS.md Rule #10): no
function ↔ help-file pair affected (helpers are `@noRd`);
no `@export`; no `_pkgdown.yml` change.

## 7. Roadmap Tick

- `ROADMAP.md` M1 row: now 2/10 done. M1.3 (Emmy lead,
  `extract_Sigma()` mixed-family validation) is next per Day-1
  plan.
- Validation-debt register: no row status change. The fixture is
  infrastructure; M1.3..M1.8 walk MIX-03..MIX-08 rows to
  `covered` by exercising the fixture.

## 8. What Did Not Go Smoothly

- **DGP cast logic bug (caught locally, before commit)**. First
  draft cast `value` via `mapply(function(val, tr) ...)`, which
  passes scalar `val` per call — making `mean(v) = val` and
  collapsing the Gamma + nbinom2 distributions to constants.
  Fix: replace with a per-family group-wise loop. Lesson: when
  a transformation needs the column-level mean, do it column-
  level, not row-level.
- **C-locale factor-sort regression inside testthat (caught
  locally)**. `withr::local` in testthat sets `LC_COLLATE = "C"`,
  which sorts string factor levels lexicographically instead of
  numerically-aware. The cached RDS was built in the
  maintainer's UTF-8 locale; the in-testthat fresh builder
  re-sorted levels in C-order. `site_species` factor codes
  differed even though all underlying strings were identical.
  Fix: cache-vs-builder test compares load-bearing columns + the
  *string form* of site_species, not the factor object. Lesson:
  factor level ordering is locale-dependent; don't assert on it
  in tests that the contract doesn't require.
- **Binomial balance**. First-draft cast `as.integer(v > 0)`
  gave 96.7 % 1s on the binomial trait (the trait's intercept
  pulled most values positive). Fix: cast with mean-centring,
  `as.integer((v - mean(v)) > 0)`, gives a balanced 50/50.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie** (lead, DGP + reproducibility): the seeded determinism
plus the per-family cast functions are the canonical pattern for
M1 / M2 / M3 fixtures. Future fixtures (e.g., the M3 R = 200
DGP grid in `dev/precompute-vignettes.R`) should follow this
shape: seeded simulate + per-family cast + RDS cache for the
data, builder for the fit. The lesson "cache data, not fits" is
M1+ engineering discipline; logged in
`R/data-mixed-family.R` top-of-file comment.

**Boole** (formula / API + audit cross-check): the fixture
shape — `data` + `truth` + `family_list` + `family_var` — is
what `gllvmTMB(formula, data, family = list(...))` consumes
directly. The `family_var` attribute is set on the family list
via `attr()`, matching the engine's per-row-dispatch contract
(MIX-02). M1.3..M1.8 tests can call `fit_mixed_family_fixture()`
once and exercise every extractor against the fitted model
without re-defining the DGP.

**Emmy** (extractor consumers): M1.3..M1.8 PRs will call
`gllvmTMB:::fit_mixed_family_fixture(n_families = 3L)` and
`...(n_families = 5L)` once each, then assert per-extractor
behaviour against the truth in `fixture$truth`. The "load
bearing columns" pattern (site, trait, family, value, env_*)
covers everything the extractors read.

**Grace** (CI integration): `inst/extdata/mixed-family-fixture.rds`
is 79 KB — well within reasonable package weight. The fixture
itself takes ~2 s wall-clock per family across M1.3..M1.8 = ~10 s
of CI time per file that exercises both fixtures. Combined,
M1.3..M1.8 should add ~30 s to the test suite; well within budget.

**Ada** (orchestration): M1.2 lands cleanly. Day-1 plan on track
— M1.3 dispatches next (Emmy lead, M1-PR-B1 start). The fixture
is the foundation for the entire M1 milestone; the small
upfront cost (this PR) saves duplicated DGP code across 6 future
PRs (M1.3..M1.8).

## 10. Known Limitations and Next Actions

- **M1.3 dispatches next** (Emmy lead): `extract_Sigma()`
  mixed-family validation. Walks **MIX-03 → covered**.
- The fixture is **intentionally small** (60 sites, 3–5 traits).
  Larger DGPs (R = 200 grids for M3, real-data fixtures for
  M5.5) follow the same pattern but live in separate files.
- The cached RDS includes **the simulated `value` + `family`
  column** but not the `gllvmTMB_multi` fit. Tests rebuild the
  fit. If a future PR needs a serialised fit (e.g., for
  vignette examples), that PR should add a separate
  `data-raw/mixed-family-fit.R` builder + cache the fit's
  summary (logLik, par, report — *not* the obj environment).
- **Future skill upgrade candidate**: the `rose-pre-publish-audit`
  skill (16 checks after PR #149) doesn't yet flag
  locale-dependent test assertions (the C-locale factor-sort
  trap from §8). A new check could grep test files for
  `expect_equal` on factor objects without `as.character()`.
  Deferred to next skill upgrade cycle.
