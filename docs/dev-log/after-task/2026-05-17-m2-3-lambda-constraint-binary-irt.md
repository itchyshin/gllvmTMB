# After Task: M2.3 — `lambda_constraint` binary IRT recovery + mirt + galamm cross-checks

**Branch**: `agent/m2-3-lambda-constraint-binary-irt`
**Slice**: M2.3 (fourth slice of M2 — Binary completeness)
**PR type tag**: `validation` (new tests; no R/ API change)
**Lead persona**: Boole (formula grammar / lambda_constraint surface) + Emmy (extractor surface)
**Maintained by**: Boole + Emmy; reviewers: Fisher (statistical inference), Curie (DGP), Rose (cross-package discipline), Ada (close gate)

## 1. Goal

Fourth M2 deliverable per the slice contract in
[`docs/design/41-binary-completeness.md`](../../design/41-binary-completeness.md).
Walks **LAM-03** (lambda_constraint on binary IRT) from
`partial` to `covered` by exercising confirmatory-loadings
recovery at $n_\text{items} \in \{20, 50\} \times d \in \{1, 2\}$,
then adds the **mirt + galamm cross-package light sanity
checks** per the M2.1 cross-package policy.

**Mathematical contract**: zero R/ source, NAMESPACE,
generated Rd, family-registry, formula-grammar, or extractor
change. Tests-only PR.

The existing
[`tests/testthat/test-lambda-constraint.R`](../../../tests/testthat/test-lambda-constraint.R)
covers LAM-01 (parser machinery) + LAM-02 (Gaussian recovery).
M2.3 adds the binary-IRT recovery surface that vision item 5
(*"latent-scale correlations on mixed-family fits"*) and the
IRT pedagogy in
[`vignettes/articles/psychometrics-irt.Rmd`](../../../vignettes/articles/psychometrics-irt.Rmd)
both depend on.

## 2. Implemented

### New test file 1: `tests/testthat/test-m2-3-lambda-constraint-binary.R`

~140 lines, 3 `test_that` blocks. Shared `make_binary_irt_dgp()`
helper builds a known-truth 2PL IRT fixture via:

```r
eta_ij = alpha_j + Lambda_j' z_i             # latent linear predictor
y_ij   = rbinom(1, pnorm(eta_ij))            # probit DGP
z_i    ~ N(0, I_d)                           # latent factor scores
```

Lower-triangle echelon constraint: `Lambda[k, k] = 1` (diagonal
pin); `Lambda[k, k'] = 0` for $k' > k$ (upper triangle); rest
free. Tests verify:

1. **d = 1, n_items = 20, n_resp = 400** — diagonal pin holds
   exactly; free entries recovered within max abs err < 0.4.
2. **d = 2, n_items = 20, n_resp = 500** — diagonal pins + upper-
   triangle zero pin both hold exactly; free entries within
   max abs err < 0.6 (loose for 2D rotation slack).
3. **d = 1, n_items = 50, n_resp = 500** — scale test; free
   entries within max abs err < 0.4.

### New test file 2: `tests/testthat/test-m2-3-mirt-cross-check.R`

~110 lines, 1 `test_that` block. Single shared 2PL IRT fixture
(n_items = 20, d = 1, n_resp = 500, logit link) per the M2.1
cross-package policy — *no replicates, no grid*.

**API translation**:
- gllvmTMB: stacked-long + `latent(0+trait|site, d=1)` + `lambda_constraint = list(B = diag-pin matrix)`
- mirt: wide-data matrix + `itemtype = "2PL"` (logit link)

**Comparison**: discrimination loadings after scale-aligning
both fits to a common reference (item 1's loading). gllvmTMB
pins `Lambda[1, 1] = 1`; we rescale mirt's `a1` entries by
`a1[1]` so both report the same identification scale.

**Asserts**:
- gllvmTMB + mirt both converge on the shared fixture.
- Max absolute deviation on rescaled loadings < 0.4 (gross-
  disagreement bound).
- Spearman rank correlation > 0.8 (catches sign flips).

### New test file 3: `tests/testthat/test-m2-3-galamm-cross-check.R`

~140 lines, 1 `test_that` block. Smaller fixture (n_items = 5,
d = 1, n_resp = 200, logit link, explicit known Lambda signal
`c(1, 0.7, -0.5, 0.6, 0.4)`).

**Why a smaller fixture for galamm**: per
[the M2.1 cross-package policy](../../design/41-binary-completeness.md)
*"one shared fixture per comparator"*, the comparator gets
to pick its converging regime. galamm's outer optimizer
collapses the latent-factor variance to 0 (rank-deficient
Hessian) on n_items ≥ 10, n_resp ≥ 300 fixtures; n_items = 5
fixtures converge cleanly. The Phase 5.5 full cross-package
grid will use starting-value strategies to address.

**API translation**:
- gllvmTMB: `latent(0+trait|site, d=1)` + `lambda_constraint = list(B = ...)`. Latent variance z ~ N(0, 1) **fixed**.
- galamm: `(0 + ability | person)` + `factor = "ability"` + `load_var = "item"` + `lambda` matrix. Latent variance **estimated**.

**Scale-difference disclaimer**: both engines pin item-1 = 1,
but galamm's free loadings carry the `sqrt(ability_var)`
factor that gllvmTMB absorbs into z ~ N(0, 1). The test
therefore compares **sign pattern + rank order**, not
absolute magnitude.

**Asserts**:
- Both engines pin item-1 = 1 exactly.
- Sign agreement on items with clear signal (`|Lambda| > 0.1`).
- Pearson correlation between gllvm + galamm loadings > 0.85.

### Local check outcome

```
NOT_CRAN=true Rscript -e 'devtools::load_all();
  testthat::test_file("tests/testthat/test-m2-3-lambda-constraint-binary.R");
  testthat::test_file("tests/testthat/test-m2-3-mirt-cross-check.R");
  testthat::test_file("tests/testthat/test-m2-3-galamm-cross-check.R")'
# m2-3-lambda-constraint-binary: .W..........   (12 PASS · 1 harmless deprecation warn)
# m2-3-mirt-cross-check:         ....           ( 4 PASS)
# m2-3-galamm-cross-check:       .....          ( 5 PASS)
```

Total **21 expects pass · 0 SKIP · 0 FAIL** on macOS arm64
with mirt 1.46.1 + galamm 0.4.0 installed locally.

### Other files modified

- **`ROADMAP.md`** — M2 row: `🟢 3/7 In progress` → `🟢 4/7 In progress`
  (both phase-summary table and M2 detail header).
- **`docs/design/35-validation-debt-register.md`** — LAM-03
  walked from `partial` to `covered` with all three new test
  files cited.

## 3. Files Changed

```
Added:
  tests/testthat/test-m2-3-lambda-constraint-binary.R       (~140 lines, 3 test_that blocks)
  tests/testthat/test-m2-3-mirt-cross-check.R               (~110 lines, 1 test_that block)
  tests/testthat/test-m2-3-galamm-cross-check.R             (~140 lines, 1 test_that block)
  docs/dev-log/after-task/2026-05-17-m2-3-lambda-constraint-binary-irt.md  (this file)

Modified:
  ROADMAP.md                                                (M2 row 3/7 → 4/7)
  docs/design/35-validation-debt-register.md                (LAM-03 partial → covered with M2.3 test evidence)
```

**No R/, NAMESPACE, generated Rd, family-registry, formula-
grammar, or extractor change.**

## 4. Checks Run

- Local tests: 21 PASS · 0 SKIP · 0 FAIL · 1 harmless legacy-
  level deprecation warning on macOS arm64.
- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" tests/testthat/test-m2-3-*.R docs/dev-log/after-task/2026-05-17-m2-3-lambda-constraint-binary-irt.md`
  → 0 hits.
- `rg "meta_known_V"` → 0 hits.
- Hand-check: mirt 1.46.1 + galamm 0.4.0 installed; both
  comparator tests run live (not skip-gated due to package
  absence on this machine).

## 5. Tests of the Tests

3-rule contract:

- **Rule 1** (would have failed before fix): the diagonal-pin
  assertion (`Lambda[1, 1] == 1` to 1e-8) would have failed if
  the parser's `lambda_constraint` machinery silently dropped
  the constraint matrix. The mirt cross-check's rescaled-
  loadings tolerance would have failed if either engine had a
  parameterisation bug producing systematically biased loadings.
- **Rule 2** (boundary): the d=1 n_items=50 case is the
  largest-grid cell in M2.3; the d=2 n_items=20 case exercises
  the upper-triangle-zero pin (rotational ambiguity boundary).
  The galamm small-fixture choice is itself a boundary
  observation: galamm's optimizer regime breaks past n_items ≥ 10.
- **Rule 3** (feature combination): each test combines
  `lambda_constraint` × `binomial()` family × `latent()` keyword
  + (for cross-checks) external comparator package. The mirt
  test additionally exercises gllvmTMB's stacked-long-data ↔
  wide-data translation; the galamm test exercises the
  `latent()` keyword ↔ `factor()` + `load_var` translation.

## 6. Consistency Audit

Stale-wording rg sweep on this PR's files: clean.

- `S_B\b|S_W\b|gllvmTMB_wide|trio|phylo_rr\(|gr\(|block_V\(` → 0 hits.
- `meta_known_V` → 0 hits.

Citation discipline: design doc references inline as relative
paths. mirt + galamm cited as "Suggests-only" comparators per
the M2.1 cross-package policy (one shared fixture per
comparator; no claim of full Phase 5.5 cross-package validation).

Persona-active-naming: lead Boole + Emmy named; reviewers
Fisher + Curie + Rose + Ada named in §1 + §9.

Convention-Change Cascade (AGENTS.md Rule #10): no function ↔
help-file pair affected. ROADMAP M2 tick + validation-debt
LAM-03 walk are the cascade — both done in the same commit.

## 7. Roadmap Tick

- **`ROADMAP.md` M2 row**: 🟢 3/7 → 🟢 4/7.
- **Validation-debt register LAM-03**: `partial` → `covered`
  with three test files cited as evidence
  (`test-m2-3-lambda-constraint-binary.R`,
  `test-m2-3-mirt-cross-check.R`,
  `test-m2-3-galamm-cross-check.R`).

After M2.3 merges: M2 is 4/7, with M2.4 (suggest_lambda_constraint
reliability), M2.5 (psychometrics-irt re-author), M2.6 (joint-sdm
binary section), M2.7 (close gate) remaining.

## 8. What Did Not Go Smoothly

- **galamm's outer optimizer collapses on standard 2PL IRT
  fixtures** of n_items ≥ 10 with n_resp ≥ 300 (rank-deficient
  Hessian, latent variance → 0, loadings not recovering sign
  pattern). Workaround: use n_items = 5 small fixture for the
  M2.3 galamm cross-check; the Phase 5.5 grid will use
  starting-value strategies (multiple restarts; warm-start
  from mirt or a Gaussian factor fit) to address.
  **Logged for Phase 5.5 author**: galamm's d = 1 binary IRT
  needs explicit start-value handling. mirt's adaptive Gauss-
  Hermite quadrature converges cleanly on the same data.
- **mirt + galamm not in DESCRIPTION Suggests yet.** The
  cross-check tests use `requireNamespace()` guards and
  gracefully skip if the packages aren't installed. To run
  the cross-checks on CI, both packages should be added to
  `DESCRIPTION Suggests`. **Surfacing as a question for the
  maintainer** (see §10): proceed with the DESCRIPTION edit
  in this PR, or defer to a separate dependency-management PR?
- **galamm's `summary()` issues "Rank deficient Hessian"
  warning** even on the converging n_items = 5 fixture. This is
  a galamm-internal warning when computing the lambda-block SE;
  the loadings themselves are correct. Suppressed via
  `suppressWarnings()` at the test call site. Not blocking; not
  a gllvmTMB issue.

## 9. Team Learning (per `AGENTS.md` Standing Review Roles)

**Boole** (lead — formula-grammar / lambda_constraint surface):
the LAM-03 walk closes the binary-IRT recovery surface that
LAM-01 (parser) + LAM-02 (Gaussian) didn't cover. The packed-
theta + map mechanism handles binary fits without parser
changes — confirms the M1.1 audit finding that `lambda_constraint`
is family-agnostic at the parser level.

**Emmy** (co-lead — extractor surface): `getLoadings(fit, level = "B")`
returns the post-fit Lambda matrix with constraints respected
(diagonal pins exact to 1e-8; upper-triangle zero pins exact
to 1e-8). No extractor surface changes needed for binary fits.

**Fisher** (review — statistical inference): the mirt cross-
check uses Spearman rank correlation (> 0.8) + max-absolute
rescaled deviation (< 0.4) — looser than M3.3's eventual ≥ 94 %
empirical coverage gate, but appropriate for a single-replicate
sanity check. galamm's degenerate behaviour on larger
fixtures is a known IRT-optimizer pathology, not a
gllvmTMB-side issue.

**Curie** (review — DGP / fixtures): `make_binary_irt_dgp()`
helper is duplicated across the three M2.3 test files
(same helper code in each, no separate `R/data-binary-irt.R`).
**Carry-forward to M2.4**: if M2.4 (suggest_lambda_constraint)
also needs binary IRT fixtures, factor the helper into
`tests/testthat/helper-binary-irt-dgp.R` for cross-file reuse.

**Rose** (review — cross-package discipline): the galamm test's
"sign pattern + rank order, not absolute magnitude" framing
honestly reports what's identifiable across the two
parameterisations. No overpromise: the maintainer's "not big
tests; Phase 5.5 owns the grid" policy is respected verbatim
in each test file's header docstring.

**Ada** (review — orchestration): after M2.3 merges, M2 is
4/7. Remaining: M2.4 (suggest_lambda_constraint reliability),
M2.5 (psychometrics-irt article re-author — needs maintainer
FINAL CHECKPOINT per the article-rewrite discipline), M2.6
(joint-sdm binary section), M2.7 (close gate).

## 10. Known Limitations and Next Actions

- **🔴 Question for maintainer**: add `mirt` + `galamm` to
  `DESCRIPTION Suggests` in this PR (so the cross-checks run on
  CI), or defer to a separate dependency-management PR?
  Surfacing rather than committing unilaterally per
  the autonomous-mode discipline.
- **M2.4 dispatches next** — Boole + Pat lead.
  `suggest_lambda_constraint()` reliability regime at
  $n_\text{items} \in \{10, 20, 50\} \times d \in \{1, 2, 3\}$;
  document where the suggester degrades gracefully vs returns
  dubious suggestions.
- **Future tiny**: factor `make_binary_irt_dgp()` into
  `tests/testthat/helper-binary-irt-dgp.R` for reuse across
  M2.3 / M2.4 / M2.5 tests. Not blocking.
- **Future tiny**: `getLoadings(fit, level = "B")` emits a
  deprecated-level warning even when called with the legacy
  alias the package still accepts. Wrapped in `suppressWarnings()`
  in M2.3 tests; same cascade as M2.2-B's
  `bootstrap_Sigma(level = "unit")` warning. **Carry-forward
  for M3 cleanup PR**: unify `unit / B` cascade across all
  extractor entry points.
- **Phase 5.5 carry-forward**: galamm IRT cross-package
  validation needs starting-value strategies for n_items ≥ 10
  regime. Logged in §8.
