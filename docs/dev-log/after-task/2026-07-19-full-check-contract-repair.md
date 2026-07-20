# After Task: 0.6 full-check contract repair

## 1. Goal

Repair stale tests exposed by the 0.6 full-check run without changing the
Design 79/80 per-trait block-diagonal augmented-slope contract, accepting
visual snapshots, or touching CI-11's active evidence lane.

## 2. Implemented

The affected tests now describe the live contract: an augmented `*_indep(1 +
x)` term has `2T` columns, `3T` free Cholesky entries, and zero cross-trait
correlations.  In particular, the binomial phylogenetic cell is a structural
non-Gaussian smoke test, not an unsupported finite-sample recovery or interval
certificate.  The latent-effect bootstrap fixture is explicitly ML because
the predictor-informed latent-score component is not in the restricted
likelihood.

**Mathematical contract:** no public R API, likelihood, formula grammar,
family, NAMESPACE, generated Rd, vignette, or pkgdown navigation changed.
For `T` traits, the retained test contract is a per-trait block-diagonal
`2T x 2T` covariance: each trait has its own intercept--slope `2 x 2` block;
all cross-trait blocks are fixed to zero.  This repair does not restore the
retired shared `2 x 2` slope covariance, and it does not make any REML,
profile-coverage, AGHQ, or VA claim.

## 4. Files Touched

Test contracts only:

- `tests/testthat/test-binomial-slope-recovery.R`
- `tests/testthat/test-bootstrap-Sigma.R`
- `tests/testthat/test-bootstrap-lv-effects.R`
- `tests/testthat/test-confint-derived.R`
- `tests/testthat/test-extract-sigma-spde-base-slope.R`
- `tests/testthat/test-m1-4-extract-correlations-mixed-family.R`
- `tests/testthat/test-matrix-ordinal-unit.R`
- `tests/testthat/test-matrix-poisson-unit.R`
- `tests/testthat/test-phylo-indep-slope-spike.R`
- `tests/testthat/test-profile-proportions.R`
- `tests/testthat/test-profile-targets.R`
- `tests/testthat/test-relmat-indep-slope-gaussian.R`

This after-task receipt is the only development-log change. `README.md`,
`NEWS.md`, `ROADMAP.md`, design documents, vignettes, generated Rd files,
`_pkgdown.yml`, and `docs/dev-log/check-log.md` were deliberately untouched.

## 3a. Decisions and Rejected Alternatives

- **Decision:** retain Design 79/80's `2T` per-trait block-diagonal slope
  contract in every repaired test. **Rationale:** direct live fits and the
  current TMB map expose `3T` free Cholesky entries with cross-trait entries
  fixed to zero. **Rejected alternative:** re-pin a shared `2 x 2` covariance
  or a single `rho = 0`; that would test a retired model. **Confidence:** high.
- **Decision:** classify the two vdiffr failures as baseline defects, not as
  changes to accept in this repair. **Rationale:** the untouched `ff045a38`
  worktree reproduced both failures. **Rejected alternative:** accepting
  `.new.svg` assets without a visual review. **Confidence:** high.
- **Decision:** leave CI-11 open. **Rationale:** the Ayumi hardening receipt
  remains a prerequisite, and the source-package check is not clean.
  **Rejected alternative:** treating focused passes as a release or coverage
  certificate. **Confidence:** high.

## 5. Checks Run

- `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 devtools::test()` targeted to each
  changed test file: all targeted suites passed (the matrix ordinal suite had
  its three intentional skips).
- `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter =
  "bootstrap-lv-effects")`: 4 passed, 0 failed, 0 errors, 0 warnings after
  the ML-fixture correction.
- Full heavy `NOT_CRAN=true` run before the last correction: 11,931 passed,
  2 visual failures, and 1 stale bootstrap-lv-effects error. The targeted
  rerun above removes that error; the two visual failures were then reproduced
  from untouched `ff045a38`.
- Untouched-base reproduction:
  `NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter =
  "plot-visual-snapshots")`: the same two failures at
  `test-plot-visual-snapshots.R:336` and `:349`; not caused by this branch.
- Source build and `R CMD check --as-cran`: check tests report
  `[ FAIL 0 | WARN 1 | SKIP 1035 | PASS 4339 ]`; overall status is
  `2 WARNINGs, 1 NOTE`, from the existing vignette/source-package conditions.
- `git diff --check`: passed.
- `rg -n 'phylo_indep\\(1 \\+ x \\| sp\\)|shared 2x2|rho pinned|atanh_cor_b'
  tests/testthat/test-binomial-slope-recovery.R
  tests/testthat/test-phylo-indep-slope-spike.R
  tests/testthat/test-relmat-indep-slope-gaussian.R`: the active binomial
  contract names the per-trait block and labels shared `2 x 2` as retired.
- `rg -n 'profile_ci_proportions|bootstrap_lv_effects|REML = TRUE|reml = TRUE'
  tests/testthat/test-bootstrap-Sigma.R
  tests/testthat/test-bootstrap-lv-effects.R
  tests/testthat/test-profile-proportions.R
  tests/testthat/test-profile-targets.R`: direct profile calls stay internal,
  and the predictor-informed latent bootstrap fixture is ML.

`pkgdown::check_pkgdown()` and article rendering were not run: no rendered or
parser-facing source changed. No new compute campaign was needed; all fits
were deterministic local test fixtures.

## 6. Tests of the Tests

The repaired slope tests are a feature-combination check (non-Gaussian family
plus phylogenetic augmented slope) and include the existing malformed
`n_lhs_cols` rejection path. The profile and bootstrap repairs preserve
boundary/error expectations (unknown targets/components and withdrawn
targets). The ML-only bootstrap correction would have caught the stale
`REML = TRUE` assumption that produced the full-suite error.

## 7a. Issue Ledger

No issue was created, commented on, or closed in this repair. Existing open PR
#774 (q=1/q=2 AGHQ reference harness) was inspected for coordination only and
was not modified. CI-11 and Ayumi's hardening work remain open and owned by
their active lane.

## 8. Consistency Audit

The two exact test-contract searches in **Checks Run** found the intended
Design 79/80 terminology and internal-only profile routing. The broad VA/AGHQ
inventory was inspected only to confirm that this test-only change adds no new
claim; existing design documents remain the authoritative future-arc boundary.
No reader-facing surface changed, so no status-inventory cascade was due.

### Roadmap Tick

N/A. This is a contract-repair receipt, not a roadmap or capability change.

## 9. What Did Not Go Smoothly

The initial full heavy run mixed a real stale fixture error with two unrelated
visual snapshot failures. A fresh base-worktree reproduction was needed before
classifying the visual failures; no snapshot was accepted. The source check is
useful regression evidence but is not source-clean because it retains two
vignette packaging warnings and one incoming-feasibility note.

## 10. Known Residuals

CI-11 remains open until Ayumi's high-risk simulation/profile hardening has an
independent receipt. The two vdiffr baseline failures need a separately scoped
visual-review decision. The 0.6 latent-rank article still precedes the 1.0 VA
research arc. This repair supplies no coverage certificate, public promotion,
AGHQ extension, non-Gaussian REML inference, or VA implementation.

## 11. Team Learning (per AGENTS.md Standing Review Roles)

**Ada:** kept the repair bounded to legacy tests and the isolated worktree,
rather than using green focused tests to widen a REML or VA claim.

**Curie:** separated a structural smoke test from a recovery certificate and
preserved deterministic malformed-input coverage.

**Rose:** required a clean-base reproduction before attributing snapshot drift
to the repair; the result is a baseline blocker, not an accepted artifact.

**Grace:** recorded the exact source-check rung and its remaining warnings
instead of calling the package release-ready.

## 12. Cross-Product Coverage

This repair covers only the legacy-test products exercised by the twelve
changed files: Design 79/80 per-trait slope maps, internal profile helpers,
and the ML-only latent-effect bootstrap fixture. It does NOT cover restricted
likelihood for predictor-informed latent scores, REML covariance recovery,
profile-interval coverage, rank-selection accuracy, structured providers,
missing data, ordinal/multinomial extensions, AGHQ beyond its existing q=1/2
references, VA optimisation, a public API, NEWS/pkgdown claims, or any release
rung. Cross-product evidence for those cells remains separate and is not
implied by this repair.
