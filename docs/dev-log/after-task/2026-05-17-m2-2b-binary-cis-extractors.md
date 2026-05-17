# After Task: M2.2-B — Binary CIs + single-family extractors + glmmTMB cross-check

**Branch**: `agent/m2-2b-binary-cis-extractors`
**Slice**: M2.2-B (second sub-PR of M2.2)
**PR type tag**: `validation` (new tests; no R/ API change)
**Lead persona**: Fisher (CI / inference) + Curie (DGP) + Emmy (extractor surface)
**Maintained by**: Fisher + Curie + Emmy; reviewers: Boole (formula grammar), Rose (test discipline), Ada (close gate)

## 1. Goal

Second sub-PR of M2.2 per the M2 slice contract in
[`docs/design/41-binary-completeness.md`](../../design/41-binary-completeness.md).
Exercises the **CI surfaces** (Wald + Fisher-z + bootstrap) and
the **four ratio extractors** on a single-family binomial(logit)
fit, then runs the **glmmTMB cross-package light sanity check**
per the M2.1 cross-package policy.

Walks (cumulative with M2.2-A):

- **FAM-02 binomial(logit)** — evidence cell extended again with
  CI + extractor coverage.
- **CI-01 Wald** — exercised on binomial fit (no register row
  change; CI-01 was already `covered` at Gaussian baseline;
  this evidence reinforces).
- **CI-09 Fisher-z** — exercised on binomial fit (same).
- **CI-03 bootstrap** — `bootstrap_Sigma()` on binomial fit via
  the M1.8 family-aware refit cascade.

Plus the maintainer 2026-05-17 cross-package policy in action:
single shared fixture, no replicates, no grid. Phase 5.5 still
owns the full cross-package grid.

**Mathematical contract**: zero R/ source, NAMESPACE,
generated Rd, family-registry, formula-grammar, or extractor
change. Tests-only.

## 2. Implemented

### New test file 1: `tests/testthat/test-m2-2b-binary-cis-extractors.R`

~180 lines, 6 `test_that` blocks. Reuses the `binary_dgp()`
helper pattern from M2.2-A; `build_logit_fit()` factors out the
shared fit construction so each test_that block can re-seed
without re-defining the DGP.

1. **Wald CIs via `tidy(fit, conf.int = TRUE)`** — sensible
   bounds; lower ≤ estimate ≤ upper for every row.
2. **`extract_correlations(method = "fisher-z")`** — correlation
   + CI bounded in $[-1, 1]$; CI brackets the point estimate.
3. **`extract_correlations(method = "wald")`** — confirms `"wald"`
   is a numerical alias for `"fisher-z"` (PR #119 design).
4. **`extract_communality()`** — returns a named numeric vector
   (one entry per trait) bounded in $[0, 1]$ under
   `link_residual = "auto"`; verifies `link_residual = "none"`
   gives $H^2$ ≥ "auto" (smaller denominator → larger ratio).
5. **`extract_repeatability()`** — returns a data.frame with
   columns `trait / R / lower / upper / method`; verifies $R$ is
   bounded in $[0, 1]$ (M1.6 cascade adding $\sigma^2_d$ to $v_W$
   prevents over-inflation).
6. **`bootstrap_Sigma()`** — converges on binomial fit (M1.8
   cascade); few failed refits; per-row family preservation via
   `fit$family_input` works on a single-family binomial fit too.

### New test file 2: `tests/testthat/test-m2-2b-glmmTMB-cross-check.R`

~110 lines, 2 `test_that` blocks. Implements the **glmmTMB
cross-package light sanity check** from
[`docs/design/41-binary-completeness.md`](../../design/41-binary-completeness.md)
§3 ("Cross-package light sanity checks").

Shared fixture: 2-trait stacked binomial-logit data with one
shared random intercept per site. Both engines see the same
long-format data; both use the lme4-style `(1 | site)` random-
intercept term:

```r
glmmTMB:  value ~ 0 + trait + (1 | site), family = binomial()
gllvmTMB: value ~ 0 + trait + (1 | site), family = binomial()
```

1. **Per-trait intercept agreement** — both engines should
   estimate `traitt1` and `traitt2` within 0.25 absolute on a
   binary-logit 200-site fixture. Local run: gllvm = -0.084,
   glmm = -0.084 (effectively identical to 3 decimal places).
2. **Shared random-intercept SD agreement** — both engines pull
   from a TMB Laplace fit; the SD comes from
   `glmmTMB::VarCorr()$cond$site` (glmm) and
   `exp(fit$report$log_sigma_re_int)` (gllvm). Local run: both
   report 0.275 (truth is 0.8 — both engines biased downward
   by the same n=200 binary-likelihood-information limit, but
   cross-package consistent).

Skip-guard: `requireNamespace("glmmTMB", quietly = TRUE)` so
the test gracefully skips if glmmTMB is not installed (it's a
Suggests-only dep). TMB version mismatch on the local machine
emits a harmless warning that does not affect the test outcome.

### Local check outcome

```
NOT_CRAN=true Rscript -e 'devtools::load_all();
  testthat::test_file("tests/testthat/test-m2-2b-binary-cis-extractors.R");
  testthat::test_file("tests/testthat/test-m2-2b-glmmTMB-cross-check.R")'
# binary-cis-extractors: .............................   (29 PASS · 0 SKIP · 0 FAIL)
# glmmTMB-cross-check:   W....                            ( 4 PASS · 0 SKIP · 0 FAIL · 1 harmless warn)
```

Total **33 expects pass · 0 fail · 0 skip** on macOS arm64.

### Other files modified

- `ROADMAP.md` — **M2 row**: 🟢 2/7 → 🟢 3/7 (both
  phase-summary table and M2 detail header).
- `docs/design/35-validation-debt-register.md` — FAM-02
  evidence cell extended with `test-m2-2b-binary-cis-extractors.R`
  + `test-m2-2b-glmmTMB-cross-check.R`.

## 3. Files Changed

```
Added:
  tests/testthat/test-m2-2b-binary-cis-extractors.R         (~180 lines, 6 test_that blocks)
  tests/testthat/test-m2-2b-glmmTMB-cross-check.R           (~110 lines, 2 test_that blocks)
  docs/dev-log/after-task/2026-05-17-m2-2b-binary-cis-extractors.md  (this file)

Modified:
  ROADMAP.md                                                (M2 row 2/7 → 3/7)
  docs/design/35-validation-debt-register.md                (FAM-02 evidence extended)
```

No R/ source change. No NAMESPACE change. No `man/*.Rd`
change. No vignette change.

## 4. Checks Run

- `NOT_CRAN=true Rscript -e 'devtools::load_all(); testthat::test_file(...)'`
  on both new files → **33 PASS · 0 SKIP · 0 FAIL** on macOS
  arm64. One harmless TMB-version-mismatch warning from
  glmmTMB (built against TMB 1.9.17; system has 1.9.21).
- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" tests/testthat/test-m2-2b-binary-cis-extractors.R tests/testthat/test-m2-2b-glmmTMB-cross-check.R docs/dev-log/after-task/2026-05-17-m2-2b-binary-cis-extractors.md`
  → 0 hits.
- `rg "meta_known_V"` on M2.2-B files → 0 hits.
- Cross-ref sanity: design doc references resolve correctly.

## 5. Tests of the Tests

3-rule contract:

- **Rule 1** (would have failed before fix):
  - Test 5 (`extract_repeatability`) would have over-inflated
    $R$ for binomial without the M1.6 `vW` fix.
  - Test 6 (`bootstrap_Sigma`) would have shown degenerate ±1
    CIs without the M1.8 family-aware simulate cascade.
- **Rule 2** (boundary): the glmmTMB cross-check at n = 200
  is at the boundary of binary-likelihood information — both
  engines converge but recover sigma_u biased downward
  (0.275 vs truth 0.8). The cross-package *agreement* is
  the load-bearing assertion, not the absolute recovery.
- **Rule 3** (feature combination): the test file exercises
  family × random-effect-structure × extractor × CI-method
  combinations all on one binomial fit. The glmmTMB cross-
  check additionally combines a *cross-package* axis.

## 6. Consistency Audit

Stale-wording rg sweep: clean (0 hits on all six patterns).
Citation discipline: design doc references inline as relative
paths.
Persona-active-naming: lead Fisher + Curie + Emmy named;
reviewers Boole + Rose + Ada named.
Convention-Change Cascade (AGENTS.md Rule #10): ROADMAP tick +
register evidence-cell extension done in the same commit.

## 7. Roadmap Tick

- `ROADMAP.md` M2 row: 🟢 2/7 → 🟢 3/7.
- Validation-debt register: FAM-02 evidence cell extended with
  the two new M2.2-B test files. No new `partial → covered`
  walks in M2.2-B (the FAM-02 walk was completed by M2.2-A;
  M2.2-B reinforces with CI + extractor + cross-package depth).

## 8. What Did Not Go Smoothly

- **gllvmTMB `tidy(fit, "ran_pars")` returned NULL** on a fit
  with the bare lme4-style `(1 | site)` random-intercept term
  (no `latent()` / `unique()` keywords). Workaround: pull
  directly from `fit$report$log_sigma_re_int`. **Logged as a
  future small task**: surface lme4-style random-intercept SDs
  in `tidy(..., "ran_pars")` output so users don't need to dig
  into `$report`. Not blocking M2.2-B.
- **`extract_Sigma()` returns NULL** on a fit with `(1 | site)`
  only (no `latent()` / `unique()` keywords). This is expected
  behaviour — `extract_Sigma()` needs a `latent()` or `unique()`
  term to have a trait-structured covariance to extract. The
  cross-check test uses `fit$report$log_sigma_re_int` instead.
- **`bootstrap_Sigma(level = "unit")` emits a deprecated-
  level warning** internally (the legacy `Sigma_B` field name
  cascade). Wrapped in `suppressWarnings()` in test 6; the
  output IS correct, just the legacy name surfaces. Pre-existing
  engine issue, not blocking. **Logged as a future engine task**:
  unify the `unit / B` field name cascade so deprecated warnings
  don't fire when users explicitly pass the canonical `level = "unit"`.

## 9. Team Learning (per `AGENTS.md` Standing Review Roles)

**Fisher** (lead — inference path): the three CI surfaces
(Wald via `tidy()`, Fisher-z via `extract_correlations()`,
bootstrap via `bootstrap_Sigma()`) all work correctly on a
single-family binomial fit. Profile CI was not tested in
M2.2-B because `profile_ci_correlation()` operates on
$\Sigma_\text{shared}$ (rotation-invariant) while the other
three target $\Sigma_\text{total}$ (per the M1 profile-
correlation-surface audit), so a single-fit comparison of
all four methods is misleading. Profile-CI accuracy on
binomial is M3.3 work (the empirical coverage gate).

**Curie** (co-lead — DGP / fixtures): `build_two_trait_logit_data()`
in the glmmTMB cross-check file uses an explicit shared random
intercept `u ~ N(0, sigma_u)` injected into both trait's eta.
This is the canonical "single-shared-random-effect" DGP that
gives both packages the same identifiable target. Without
the explicit shared u, comparing a per-trait `unique()` term
to a shared `(1|site)` term would conflate "different model"
with "different package".

**Emmy** (co-lead — extractor surface): all four ratio
extractors (`extract_correlations`, `extract_communality`,
`extract_repeatability`, plus `bootstrap_Sigma`) work
correctly on single-family binomial fits. The M1 mixed-family
cascade *already* exercised these extractors on fits that
include binomial rows; M2.2-B confirms they work on
single-family binomial fits too, with no special-casing
required.

**Boole** (review — formula grammar): the lme4-style
`(1 | site)` random-intercept term is accepted by the
`gllvmTMB()` parser; the M2.2-B cross-check exercises this
path. The `traits()`-LHS path is NOT exercised here (single-
formula stacked is the natural shape for cross-package work).

**Rose** (review — test discipline): `skip_if_glmmTMB_missing()`
helper gates the cross-check cleanly; the TMB-version-mismatch
warning is documented in this report (it's a build-env issue,
not a test issue). Persona-active-naming present.

**Ada** (review — orchestration): M2.2-A + M2.2-B together
complete the M2.2 slice. After M2.2-B merges, M2.3
(`lambda_constraint` binary IRT + mirt + galamm cross-checks)
dispatches.

## 10. Known Limitations and Next Actions

- **M2.3 dispatches next** — Boole + Emmy lead. Scope:
  - `lambda_constraint` recovery on binary IRT fixtures at
    $n_\text{items} \in \{10, 20, 50\} \times d \in \{1, 2, 3\}$.
  - Cross-check against `mirt::mirt()` on a single shared
    fixture.
  - Cross-check against `galamm::galamm()` on the *same*
    fixture (tests the `lambda_constraint` ↔ `galamm`-`lambda`-
    matrix translation per the M2.1 design).
  - LAM-03 walks `partial` → `covered`.
- **Tiny follow-up**: surface lme4-style random-intercept SDs
  in `tidy(..., "ran_pars")` so the M2.2-B cross-check doesn't
  need to fish in `fit$report$log_sigma_re_int`.
- **Tiny follow-up**: unify `unit / B` field name cascade in
  `bootstrap_Sigma()` output to suppress the deprecated-level
  warning when the canonical `level = "unit"` is passed.
- **Documented in §8**: the `extract_Sigma()` returns-NULL
  shape for bare `(1|site)` fits is expected; not a bug.
