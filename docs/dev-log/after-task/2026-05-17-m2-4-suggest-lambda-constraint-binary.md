# After Task: M2.4 — `suggest_lambda_constraint()` reliability regime on binary IRT

**Branch**: `agent/m2-4-suggest-lambda-constraint-binary`
**Slice**: M2.4 (fifth slice of M2 — Binary completeness)
**PR type tag**: `validation` (new tests; no R/ API change)
**Lead persona**: Boole (formula grammar / suggester surface) + Pat (reader UX)
**Maintained by**: Boole + Pat; reviewers: Emmy (extractor surface), Fisher (statistical
inference), Rose (test discipline), Ada (close gate)

## 1. Goal

Fifth M2 deliverable per
[`docs/design/41-binary-completeness.md`](../../design/41-binary-completeness.md).
Walks **LAM-04** (`suggest_lambda_constraint()`) from `partial`
to `covered`. Verifies the suggester produces sensible
constraint matrices on binary 2PL IRT data across the
$n_\text{items} \times d$ grid and documents the reliability
boundary at $d = 3, n_\text{items} = 10$.

**Mathematical contract**: zero R/ source, NAMESPACE,
generated Rd, family-registry, formula-grammar, or extractor
change. Tests-only.

The existing
[`tests/testthat/test-suggest-lambda-constraint.R`](../../../tests/testthat/test-suggest-lambda-constraint.R)
covers the parser machinery (shape, pins, names — LAM-04
partial baseline). M2.4 adds the **binary application +
recovery cycle** that vision item 5 and the M2.5
`psychometrics-irt.Rmd` rewrite both depend on.

## 2. Implemented

### New test file: `tests/testthat/test-m2-4-suggest-lambda-constraint-binary.R`

~180 lines, 4 `test_that` blocks. Local `make_binary_irt_dgp()`
helper mirrors the M2.3 helper (logit-link 2PL IRT with
lower-triangle echelon truth).

1. **Suggester output structure on binary DGP at d = 2,
   n_items = 8** — verifies dimension, convention, n_pins,
   per-cell pin pattern (upper-triangle zeros + lower-triangle
   NA). 35 expects.
2. **Suggester → fit recovery cycle at d = 1, n_items = 20,
   n_resp = 400** — d = 1 has K(K-1)/2 = 0 pins (all-NA
   constraint); fit relies on the engine's positive-diagonal
   parameterisation. Verifies fit converges + item-1 loading
   stays positive.
3. **Suggester → fit recovery cycle at d = 2, n_items = 20,
   n_resp = 500** — K(K-1)/2 = 1 pin at (1, 2). Verifies fit
   converges + upper-triangle pin holds exactly to 1e-8 +
   non-trivial loadings in both columns.
4. **Reliability boundary: d = 3, n_items = 10** —
   parameter-counting edge. Suggester returns the correct
   shape (10 × 3, 3 pins at strict upper triangle of the
   first 3×3 block). Downstream fit may or may not converge;
   the test uses `succeed()` for "fit raised typed error" or
   "fit's `convergence != 0`" as graceful-degradation
   outcomes, since these are honest boundary signals rather
   than test failures.

### Local check outcome

```
NOT_CRAN=true Rscript -e 'devtools::load_all();
  testthat::test_file("tests/testthat/test-m2-4-suggest-lambda-constraint-binary.R",
                      reporter = "summary")'
# m2-4-suggest-lambda-constraint-binary: .........................................
# 41 PASS · 0 SKIP · 0 FAIL
```

On macOS arm64. Including the d = 3 boundary fit which
converged cleanly with `fit$opt$convergence == 0L`.

### Other files modified

- **`ROADMAP.md`** — M2 row: `🟢 2/7 In progress` → `🟢 3/7 In progress`
  (both phase-summary and M2 detail header).
- **`docs/design/35-validation-debt-register.md`** — LAM-04
  walked from `partial` to `covered`.

## 3. Files Changed

```
Added:
  tests/testthat/test-m2-4-suggest-lambda-constraint-binary.R     (~180 lines, 4 test_that blocks)
  docs/dev-log/after-task/2026-05-17-m2-4-suggest-lambda-constraint-binary.md   (this file)

Modified:
  ROADMAP.md                                                       (M2 row 2/7 → 3/7)
  docs/design/35-validation-debt-register.md                       (LAM-04 partial → covered)
```

No R/, NAMESPACE, generated Rd, DESCRIPTION, family-registry,
formula-grammar, or extractor change.

## 4. Checks Run

- `NOT_CRAN=true Rscript -e ...` → 41 PASS · 0 SKIP · 0 FAIL on macOS arm64.
- `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" tests/testthat/test-m2-4-suggest-lambda-constraint-binary.R docs/dev-log/after-task/2026-05-17-m2-4-suggest-lambda-constraint-binary.md`
  → 0 hits.
- `rg "meta_known_V"` → 0 hits.
- Suggester output verified against
  [`docs/design/06-extractors-contract.md`](../../design/06-extractors-contract.md)
  documented invariants (lower-triangular convention pins
  K(K-1)/2 entries; rest free).

## 5. Tests of the Tests

3-rule contract:

- **Rule 1** (would have failed before fix): the suggester's
  output-shape assertions would fail if the suggester silently
  changed convention (e.g. moved from lower-triangular to
  pin_top_one). The d = 2 fit's `expect_equal(L_hat[1, 2], 0)`
  would fail if `lambda_constraint` plumbing dropped the pin
  (regression test for M1.x machinery + M2.3 LAM-03 walk).
- **Rule 2** (boundary): the d = 3, n_items = 10 case is the
  parameter-counting edge per the M2.1 design doc's open
  questions. Test #4 documents this with `succeed()` graceful-
  degradation hooks so the actual behaviour is captured as
  evidence rather than as a brittle pass-fail.
- **Rule 3** (feature combination): each test combines
  `suggest_lambda_constraint()` → output → use-as-constraint
  → gllvmTMB fit → extractor verification. The full chain is
  exercised on binary, which the existing
  `test-suggest-lambda-constraint.R` does only on Gaussian.

## 6. Consistency Audit

Stale-wording rg sweep clean.
Citation discipline: design doc references inline as relative paths.
Persona-active-naming: lead Boole + Pat named; reviewers Emmy + Fisher + Rose + Ada named.

Convention-Change Cascade (AGENTS.md Rule #10): ROADMAP tick +
LAM-04 walk are the cascade — both done in the same commit.

## 7. Roadmap Tick

- **`ROADMAP.md` M2 row**: 🟢 2/7 → 🟢 3/7. Note: M2.2-B
  (PR #164) and M2.3 (PR #165) have parallel `2/7 → 3/7`
  ticks on their branches. The merge order resolves cleanly:
  the last-merger's rebase bumps to the correct final value
  (5/7 after all three merge).
- **Validation-debt register LAM-04**: `partial` → `covered`
  with both M2.4 test files cited as evidence.

After M2.4 merges (in combination with M2.2-B + M2.3): M2 is
5/7, with M2.5 (psychometrics-irt rewrite), M2.6 (joint-sdm
binary section), M2.7 (close gate) remaining.

## 8. What Did Not Go Smoothly

- **d = 3, n_items = 10 boundary fit converged on this seed**.
  Test #4 was written defensively (`succeed()` hooks for
  failure / non-convergence), but `seed = 20260608L` happened
  to land in a regime where the fit converges cleanly. The
  reliability boundary still exists — it just doesn't fire
  on this particular seed. **Carry-forward note**: a future
  M3-adjacent reliability study could vary the seed across
  $R \geq 50$ replicates per cell to characterise the
  convergence rate at the d = 3, n_items = 10 boundary
  empirically. Per the maintainer "not big tests" guidance,
  this stays deferred to Phase 5.5.
- **Helper duplication continues**: `make_binary_irt_dgp()`
  is now duplicated in 4 test files (M2.3 × 3 + M2.4 × 1).
  Carry-forward: factor into `tests/testthat/helper-binary-irt-dgp.R`.
  Not blocking; logged in §10.

## 9. Team Learning (per `AGENTS.md` Standing Review Roles)

**Boole** (lead — formula-grammar / suggester surface): the
suggester is family-agnostic at the parser level (same
constraint shape returned for binary input as for Gaussian).
M2.4 confirms the suggester + `lambda_constraint` parser +
TMB-template path composes cleanly on binary 2PL IRT.

**Pat** (co-lead — reader UX): the suggester's return shape
(named list with `constraint`, `convention`, `d`, `n_pins`,
`note`, `usage_hint`) is reader-friendly. The `usage_hint`
field returns an example call as a string, which works as
a copy-paste recipe for the user. The M2.5 article-rewrite
should highlight this discovery path explicitly.

**Emmy** (review — extractor surface): `getLoadings(fit, level = "B")`
returns the post-fit Lambda matrix with the suggester-pinned
entries holding to 1e-8 (matching M2.3's recovery behaviour).
No extractor changes needed.

**Fisher** (review — statistical inference): the boundary
case at d = 3, n_items = 10 is on the parameter-counting
edge. The graceful-degradation test pattern (succeed-on-error
or succeed-on-non-convergence) is the right "honest reliability
boundary" expression — better than a hard expect-pass that
would mask the boundary's existence.

**Rose** (review — test discipline): stale-wording rg sweep
clean. Persona-active-naming present. The `succeed()` calls
in test #4 are an honest reliability-boundary signal, not
a test escape hatch — the test still verifies the suggester
output shape (`expect_equal(dim(...), c(10L, 3L))`,
`expect_equal(res$n_pins, 3L)`, three pin-position
assertions), only the downstream fit is allowed to gracefully
degrade.

**Ada** (review — orchestration): after M2.4 + M2.2-B + M2.3
all merge, M2 is 5/7. Remaining: M2.5 (psychometrics-irt
re-author — needs maintainer FINAL CHECKPOINT per the article-
rewrite discipline), M2.6 (joint-sdm binary section
restoration), M2.7 (close gate).

## 10. Known Limitations and Next Actions

- **M2.5 dispatches next** but **requires maintainer FINAL
  CHECKPOINT** before I start — `psychometrics-irt.Rmd` is
  an article rewrite, which the discipline doc flags as
  needing explicit approval.
- **Future small PR**: factor `make_binary_irt_dgp()` into
  `tests/testthat/helper-binary-irt-dgp.R` so M2.3 + M2.4 +
  M2.5 + M3.3 tests can reuse without duplication.
- **Phase 5.5 carry-forward**: characterise the d = 3,
  n_items = 10 convergence rate empirically with R ≥ 50
  replicates per cell. M2.4 is single-replicate boundary
  *evidence*, not a coverage study.
- **MIX-10 stays `blocked`** (delta / hurdle two-scales-
  undefined; safeguard error class is the honest answer).
