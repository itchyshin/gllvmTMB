# Phase 0B.2 — smoke-test spec for 9 NEEDS-SMOKE rows

**Maintained by:** Curie (test-writing lead) and Rose (audit lead).
**Reviewers:** Pat (applied-user legibility), Boole (parser-syntax
correctness), Ada (orchestrator ratifies).
**Status:** DRAFT — Pat + Rose + Boole review BEFORE Curie writes
any test code (vision rule #2). No test files in this PR; this is
the planning artefact.

## Purpose

Per the Phase 0B audit (PR #134, commit `150dbad`), 6 rows in
`docs/design/01-formula-grammar.md` were marked **NEEDS-SMOKE**.
Rows #13 and #14 expand into multiple sub-tests, giving **9 smoke
tests total**. This spec records each test's target row, fixture,
assertions, and the tests-of-the-tests rule it satisfies.

After Pat + Rose ratify this spec, **PR-0B.2** writes the actual
tests in **one new file** `tests/testthat/test-formula-grammar-smoke.R`
(per maintainer choice 1(a) 2026-05-16).

## 3-rule tests-of-the-tests contract (recap)

Per `docs/design/10-after-task-protocol.md`, every new test must
satisfy at least one of:

1. **Failure-before-fix verification** — test demonstrated to fail
   before a fix.
2. **Boundary case** — variance near zero, rank-deficient
   $\boldsymbol\Lambda$, family × $d$ edge regime, etc.
3. **Feature combination** — combines the new feature with at
   least one already-supported neighbouring feature.

For Phase 0B smoke tests, **rule 3 (feature combination)** is the
typical fit: the parser-syntax row was tested on the M0 Gaussian
baseline; the smoke combines it with a non-Gaussian family or a
related keyword.

## The 9 smoke tests

Each test follows the same skeleton:

```r
test_that("<row name> parses, fits, and produces a sensible <extractor>", {
  set.seed(<seed>)
  # ... fixture (small, fast, CRAN-safe) ...
  fit <- gllvmTMB(<formula>, data = df, trait = "trait", unit = "<unit>", ...)
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_equal(fit$opt$convergence, 0L)
  Sigma <- extract_Sigma(fit, level = "<level>", part = "<part>")$Sigma
  expect_true(is.matrix(Sigma))
  expect_equal(dim(Sigma), c(T, T))
  expect_true(min(eigen(Sigma, symmetric = TRUE, only.values = TRUE)$values) >= -1e-8)
  # ... plus row-specific assertions ...
})
```

### Test 1 — `indep(0 + trait | g)` non-Gaussian (row #7)

| Field | Value |
|-------|-------|
| Target row in `01-formula-grammar.md` | `indep(0 + trait \| g)` |
| Register row | FG-07 (`partial`) |
| 3-rule contract item | **Rule 3** — combines `indep()` with `family = binomial()` (non-Gaussian regime) |
| Fixture | 50 sites × 4 traits; binomial-logit responses simulated with low rho (≈ 0.1) |
| Parse + fit assertions | `gllvmTMB(value ~ 0 + trait + indep(0 + trait \| site), data = df_long, trait = "trait", unit = "site", family = binomial())` → `s3_class("gllvmTMB_multi")` + `convergence == 0L` |
| Extractor assertion | `extract_Sigma(fit, level = "unit", part = "total")` returns 4×4 compound-symmetric matrix; off-diagonals approximately equal; on-diagonal positive |
| Promotes on pass | `claimed` → `covered`; register row FG-07 `partial` → `covered` (binomial regime confirmed) |

### Test 2 — `dep(0 + trait | g)` non-Gaussian (row #8)

| Field | Value |
|-------|-------|
| Target row | `dep(0 + trait \| g)` |
| Register row | FG-08 (`partial`) |
| 3-rule contract item | **Rule 3** — combines `dep()` with `family = poisson()` |
| Fixture | 50 sites × 3 traits (small T because `dep` has T(T+1)/2 parameters); Poisson-log responses |
| Parse + fit assertions | `gllvmTMB(value ~ 0 + trait + dep(0 + trait \| site), data = df_long, trait = "trait", unit = "site", family = poisson())` → `s3_class` + `convergence == 0L` |
| Extractor assertion | `extract_Sigma(fit, level = "unit", part = "total")` returns 3×3 positive-definite matrix; min eigenvalue > 1e-6 |
| Promotes on pass | `claimed` → `covered`; FG-08 → `covered` |

### Test 3 — `phylo_scalar(species, vcv = Cphy)` (row #12)

| Field | Value |
|-------|-------|
| Target row | `phylo_scalar(species, vcv = Cphy)` |
| Register row | PHY-04 (`partial`) |
| 3-rule contract item | **Rule 3** — exercises the `vcv = Cphy` path (alternative to `tree = tree`) on Gaussian fit |
| Fixture | 15 species via `ape::rcoal(15)`; 30 sites × 3 traits; `Cphy <- ape::vcv(tree, corr = TRUE)` |
| Parse + fit assertions | `gllvmTMB(value ~ 0 + trait + phylo_scalar(species, vcv = Cphy), data = df_long, trait = "trait", unit = "site", cluster = "species")` → `s3_class` + `convergence == 0L` |
| Extractor assertion | `extract_Sigma(fit, level = "phy", part = "total")` returns 3×3 scalar matrix (all diagonals equal); positive |
| Promotes on pass | `claimed` → `covered`; PHY-04 → `covered` |

### Test 4 — `phylo_indep(0 + trait | species)` (row #13a)

| Field | Value |
|-------|-------|
| Target row | `phylo_indep(0 + trait \| species, tree = tree)` |
| Register row | PHY-05 (`partial`, shared with phylo_dep) |
| 3-rule contract item | **Rule 3** — combines compound-symmetric trait covariance with phylogenetic correlation |
| Fixture | 20 species; 40 sites × 3 traits |
| Parse + fit assertions | `gllvmTMB(value ~ 0 + trait + phylo_indep(0 + trait \| species, tree = tree), data = df_long, trait = "trait", unit = "site", cluster = "species")` → `s3_class` + `convergence == 0L` |
| Extractor assertion | `extract_Sigma(fit, level = "phy", part = "total")` returns 3×3 compound-symmetric (off-diagonals equal); positive |
| Promotes on pass | `claimed` → `covered`; PHY-05 partial → covered (compound-symmetric form confirmed) |

### Test 5 — `phylo_dep(0 + trait | species)` (row #13b)

| Field | Value |
|-------|-------|
| Target row | `phylo_dep(0 + trait \| species, tree = tree)` |
| Register row | PHY-05 (`partial`, shared with phylo_indep) |
| 3-rule contract item | **Rule 3** — unstructured trait covariance × phylogenetic correlation |
| Fixture | 20 species; 40 sites × 3 traits |
| Parse + fit assertions | `gllvmTMB(value ~ 0 + trait + phylo_dep(0 + trait \| species, tree = tree), ...)` → `s3_class` + `convergence == 0L` |
| Extractor assertion | `extract_Sigma(fit, level = "phy", part = "total")` returns 3×3 positive-definite; min eigenvalue > 1e-6 |
| Promotes on pass | `claimed` → `covered`; PHY-05 → `covered` (both phylo_indep + phylo_dep) |

### Test 6 — `spatial_indep(0 + trait | sites, coords = ...)` (row #14a)

| Field | Value |
|-------|-------|
| Target row | `spatial_indep(0 + trait \| sites, mesh = mesh)` (and `coords =` form) |
| Register row | SPA-04 (`partial`) |
| 3-rule contract item | **Rule 3** — compound-symmetric trait covariance × SPDE spatial correlation |
| Fixture | 40 sites via `simulate_site_trait(n_sites=40, ..., spatial_range=0.3)`; mesh via `make_mesh()` |
| Parse + fit assertions | `gllvmTMB(value ~ 0 + trait + spatial_indep(0 + trait \| site, mesh = mesh), data = df_long, trait = "trait", unit = "site")` → `s3_class` + `convergence == 0L` |
| Extractor assertion | `extract_Sigma(fit, level = "spatial", part = "total")` returns 3×3 compound-symmetric; positive |
| Promotes on pass | `claimed` → `covered`; SPA-04 → `covered` (compound-symmetric form) |

### Test 7 — `spatial_dep(0 + trait | sites, ...)` (row #14b)

| Field | Value |
|-------|-------|
| Target row | `spatial_dep(0 + trait \| sites, mesh = mesh)` |
| Register row | SPA-04 (`partial`, shared with spatial_indep) |
| 3-rule contract item | **Rule 3** — unstructured trait covariance × spatial correlation |
| Fixture | 40 sites; 3 traits (small T) |
| Parse + fit assertions | `gllvmTMB(value ~ 0 + trait + spatial_dep(0 + trait \| site, mesh = mesh), ...)` → `s3_class` + `convergence == 0L` |
| Extractor assertion | `extract_Sigma(fit, level = "spatial", part = "total")` returns 3×3 positive-definite; min eigenvalue > 1e-6 |
| Promotes on pass | `claimed` → `covered`; SPA-04 → `covered` (both spatial_indep + spatial_dep) |

### Test 8 — `spatial_scalar(0 + trait | sites, ...)` (row #14c)

| Field | Value |
|-------|-------|
| Target row | `spatial_scalar(0 + trait \| sites, mesh = mesh)` |
| Register row | SPA-03 (`partial`) |
| 3-rule contract item | **Rule 3** — single-scalar trait covariance × spatial correlation |
| Fixture | 40 sites; 3 traits |
| Parse + fit assertions | `gllvmTMB(value ~ 0 + trait + spatial_scalar(0 + trait \| site, mesh = mesh), ...)` → `s3_class` + `convergence == 0L` |
| Extractor assertion | `extract_Sigma(fit, level = "spatial", part = "total")` returns 3×3 scalar matrix (all diagonals equal); positive |
| Promotes on pass | `claimed` → `covered`; SPA-03 → `covered` |

### Test 9 — `meta_V(value, V = V)` single-V (row #15)

| Field | Value |
|-------|-------|
| Target row | `meta_V(value, V = V)` single-V (additive scale) |
| Register row | MET-01 (`partial`) |
| 3-rule contract item | **Rule 3** — combines `meta_V` known-V additive form with `latent + unique` on the same fit (the block-V regime already covered by `test-block-V.R`; single-V is the gap) |
| Fixture | 50 effect sizes × 3 outcomes (small meta-analytic dataset); known-V single diagonal matrix; site grouping |
| Parse + fit assertions | `gllvmTMB(value ~ 0 + trait + latent(0 + trait \| site, d = 1) + meta_V(value, V = V), data = stage1_summary, trait = "trait", unit = "site", known_V = V)` → `s3_class` + `convergence == 0L` |
| Extractor assertion | `extract_Sigma(fit, level = "unit", part = "total")` returns 3×3 positive-definite; the `known_V` diagonal does NOT appear in $\Sigma_\text{unit}$ (it's residual-level); min eigenvalue > 1e-6 |
| Promotes on pass | `claimed` → `covered`; MET-01 → `covered` |

## Summary

- **9 smoke tests**, all in new file `tests/testthat/test-formula-grammar-smoke.R`.
- **Estimated test-file size**: ~150-200 lines of test code (test 1 sets up the fixture pattern; tests 2-9 reuse it with minor tweaks).
- **Estimated CI cost**: each test fits a small model (~30-50 obs × 3 traits); total runtime should be < 30 seconds.
- All 9 tests target `partial` register rows that get promoted to `covered` on pass.

## What Pat + Rose + Boole should check

**Pat (applied-user legibility)**:
- Are the fixtures realistic enough that the test "reads like" a user call? Or do they look like contrived test code?
- Are the column-purpose annotations (Option A: `trait = "trait"`, `unit = "site"`, etc.) explicit?
- Should the assertions surface useful messages on failure (e.g. cite the register row)?

**Rose (consistency audit)**:
- Does every test cite its register row in the comment header?
- Does every promoted register row have a back-link from `01-formula-grammar.md` status map after PR-0B.2 merges?
- Are there `partial` rows the audit missed? (E.g. is `phylo_slope` covered by `test-phylo-slope.R` already, or does it need its own smoke?)

**Boole (parser-surface correctness)**:
- For test 6 (spatial_indep): is `mesh =` the canonical argument now (over the legacy `coords | sites` orientation)? Should the smoke also exercise the alternative `coords = c("lon", "lat")` form?
- For test 9 (meta_V single-V): is the `known_V = V` top-level argument still active, or has it been renamed during the `meta_known_V → meta_V` rename?

**Ada (orchestrator)**:
- PR-0B.2 should land all 9 tests in one PR (Curie writes the file once), correct?
- After PR-0B.2 merges: a single follow-up doc commit walks the 9 `claimed` rows in `01-formula-grammar.md` to `covered`, OR each test PR also updates the status map in the same commit. (Recommend: same commit; the test file existence IS the promotion evidence.)

## Out of scope for PR-0B.2

- **NEEDS-AUDIT-FIRST rows** #9, #19 → PR-0B.3.
- **Row #18** (`lambda_constraint` Gaussian path): the audit said "Gaussian smoke probably already passes via `test-lambda-constraint.R`; verify pinned-entry values within tolerance". This is closer to NEEDS-AUDIT-FIRST than NEEDS-SMOKE. Recommend including it in PR-0B.3 alongside #9 and #19, not PR-0B.2.
- **LAM-03 binary IRT** → M2 work (not 0B).
- **LAM-04 `suggest_lambda_constraint` binary regime** → M2 work (not 0B).

## Cross-references

- `docs/dev-log/audits/2026-05-16-phase0b-claimed-row-audit.md` — parent audit doc.
- `docs/design/01-formula-grammar.md` — target status map.
- `docs/design/35-validation-debt-register.md` — FG-07, FG-08, PHY-04, PHY-05, SPA-03, SPA-04, MET-01 rows.
- `docs/design/10-after-task-protocol.md` "Tests of the Tests" section — 3-rule contract.
- `docs/design/05-testing-strategy.md` — testing-strategy design doc owned by Curie + Fisher.

## Persona engagement (read order)

1. **Pat** reads first: are the smokes legible and applied-user-friendly?
2. **Rose** reads second: are the register cross-references correct?
3. **Boole** reads third: any parser-surface gotchas in the proposed call sites?
4. **Ada** ratifies last: gives go-ahead for Curie to write the file.

After ratification: **Curie** writes `test-formula-grammar-smoke.R` on a new branch, opens PR-0B.2.
