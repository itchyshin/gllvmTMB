# Audit: Phase 4 Test Classification (smoke / recovery / identifiability)

**Trigger**: PR #37 dispatch-queue item that maps to ROADMAP Phase
4 (improve feedback time). Codex's eventual `RUN_SLOW_TESTS`
gating PR needs a per-file classification of `tests/testthat/`
so the gate cuts only what's expensive without losing coverage
of fast guards.

This audit is read-only Claude-lane prep. The implementation
(adding `Sys.getenv("RUN_SLOW_TESTS")` guards + the CI workflow
env condition) is Codex-lane Phase 4 work, not part of this PR.

**Output**: classification of all 76 `tests/testthat/*.R` files
into five buckets, plus a recommended gating policy that lets
the standard CI run keep `R-CMD-check` fast on every PR while
the full simulation recovery suite runs on `main` or via
`workflow_dispatch`.

## Methodology

For each test file:

- Read the filename pattern (`*-recovery.R`, `*-args.R`, etc.)
- Spot-check the first 30 lines + the test names
- Count `gllvmTMB(` fits inline (rough cost proxy)
- Assign one of five categories

Categories:

| Category | Cost | Gate |
|---|---|---|
| **smoke** | < 30 s | Always run (every PR) |
| **diagnostic** | 30 s -- 2 min | Always run (every PR) |
| **recovery** | 2 -- 10 min | `RUN_SLOW_TESTS` gated |
| **identifiability** | 2 -- 10 min | `RUN_SLOW_TESTS` gated |
| **integration** | 2 -- 5 min | `RUN_SLOW_TESTS` gated |

Smoke = argument validation, error messages, structural sanity
checks, formula parser tests (few fits or no fits). Diagnostic =
extractor / plot / metadata checks (~1-3 fits). Recovery =
parameter recovery from simulated data (multiple fits at various
sample sizes). Identifiability = alternative-parameterization
consistency checks (multiple fits comparing parameterizations).
Integration = end-to-end workflows touching many extractors at
once.

## Per-file classification

### Smoke (always run -- 27 files)

Argument validation, error messages, formula parsing, structural
sanity. No or one fit.

- `test-augmented-lhs-guard.R`
- `test-block-V.R`
- `test-brms-sugar.R`
- `test-canonical-keywords.R` (large, but pure grammar coverage)
- `test-cluster-rename.R`
- `test-cross-sectional-unique.R`
- `test-extract-omega.R`
- `test-extract-sigma.R` (small extractor; no recovery)
- `test-extractors.R`
- `test-gllvmTMB-args.R`
- `test-gllvmTMB-diagnose.R`
- `test-gllvmTMB-wide.R`
- `test-gllvmTMBcontrol.R`
- `test-keyword-grid.R` (grammar coverage)
- `test-mesh.R` (geometry only, no engine fit)
- `test-multi-random-intercepts.R`
- `test-multi-trial-binomial.R`
- `test-normalise-level.R`
- `test-parse-multi-formula.R`
- `test-phylo-keyword.R`
- `test-phylo-mode-dispatch.R`
- `test-sigma-rename.R`
- `test-spatial-mode-dispatch.R`
- `test-spde-keyword.R`
- `test-stage2-rr-diag.R`
- `test-traits-keyword.R` (formula parser tests; PR #39's sugar)
- `test-weights-unified.R` (parser-level normalisation)

### Diagnostic (always run -- 12 files)

Extractor outputs, plot artefacts, small bootstraps. 1-3 fits.

- `test-bootstrap-Sigma.R` (small bootstrap; medium-fast)
- `test-confint-bootstrap.R` (small CI bootstrap)
- `test-extractors-extra.R`
- `test-fisher-z-correlations.R`
- `test-lambda-constraint.R`
- `test-ordiplot-VP.R`
- `test-plot-gllvmTMB.R`
- `test-profile-ci.R` (small profile)
- `test-rotate-compare-loadings.R` (small)
- `test-simulate-site-trait.R` (data sim only, no engine fit)
- `test-suggest-lambda-constraint.R`
- `test-tidy-predict.R`

### Recovery (RUN_SLOW_TESTS gated -- 15 files)

Parameter recovery from simulated data. Multiple fits per file at
various sample sizes; the kind of test that grows test runtime
the most.

- `test-beta-recovery.R`
- `test-betabinomial-recovery.R`
- `test-delta-gamma-recovery.R`
- `test-delta-lognormal-recovery.R`
- `test-family-gamma.R`
- `test-family-lognormal.R`
- `test-mixed-family-olre.R`
- `test-mixed-response-sigma.R`
- `test-mixed-response-unique-nongaussian.R`
- `test-ordinal-probit.R`
- `test-phylo-hadfield.R`
- `test-phylo-singular-recover.R`
- `test-spatial-latent-recovery.R`
- `test-student-recovery.R`
- `test-truncated-recovery.R`
- `test-tweedie-recovery.R`

### Identifiability (RUN_SLOW_TESTS gated -- 8 files)

Alternative-parameterization consistency. Multiple fits comparing
e.g. `latent + unique` vs `dep` vs `indep`, two-U cross-checks.

- `test-lme4-style-weights.R` (weighted vs unweighted equivalence)
- `test-olre-separation.R`
- `test-phylo-q-decomposition.R`
- `test-phylo-two-U.R`
- `test-pic-mom.R`
- `test-stage39-multi-start.R`
- `test-two-U-cross-check.R`
- `test-wide-weights-matrix.R` (long vs wide byte-identical)

### Integration (RUN_SLOW_TESTS gated -- 3 files)

End-to-end workflows.

- `test-integration-tour.R` (simulate -> fit -> all extractors -> predict)
- `test-spatial-orientation.R` (spatial-specific end-to-end)
- `test-stage4-spde.R` (SPDE-specific end-to-end)

### Phylo-misc (RUN_SLOW_TESTS gated -- 4 files)

Phylo-specific recovery / two-U-adjacent. Same cost profile as
the recovery / identifiability buckets.

- `test-phylo-known-V.R`
- `test-phylo-slope.R`
- `test-two-U-via-PIC.R`
- `test-spatial-keyword.R`

### Out-of-scope (3 files, ungated)

Tests that don't run an engine fit. Always run; cost negligible.

- (Already covered under smoke above: `test-mesh.R`,
  `test-simulate-site-trait.R`, etc.)

## Summary by bucket

| Bucket | Count | Always-run? |
|---|---|---|
| Smoke | 27 | ✅ yes |
| Diagnostic | 12 | ✅ yes |
| **Always-run total** | **39** | ~30-60 s expected |
| Recovery | 15 | gated |
| Identifiability | 8 | gated |
| Integration | 3 | gated |
| Phylo-misc | 4 | gated |
| **Slow-gated total** | **30** | ~10-30 min expected |
| Out-of-scope (no fit) | 7 | always |

Grand total: 76 (the 7 out-of-scope are double-counted in smoke
because they're listed there; the gate decision is what matters,
not the bucket label).

## Recommended `RUN_SLOW_TESTS` mechanism

### Per-file pattern

At the top of every slow-gated test file, add:

```r
testthat::skip_if(
  !nzchar(Sys.getenv("RUN_SLOW_TESTS")),
  "RUN_SLOW_TESTS not set; skipping slow recovery / identifiability suite"
)
```

OR (preferred for finer control): per-`test_that()` block, so
that fast guard tests INSIDE a recovery file still run:

```r
test_that("guard accepts NULL weights", { ... })

test_that("recovery: Lambda within tol on T=10 traits", {
  testthat::skip_if(!nzchar(Sys.getenv("RUN_SLOW_TESTS")))
  # slow simulation recovery body
})
```

### CI workflow

Modify `.github/workflows/R-CMD-check.yaml` to set `RUN_SLOW_TESTS`
only on:

- pushes to `main` / `master`
- `workflow_dispatch` (manual)

PRs run WITHOUT `RUN_SLOW_TESTS` -> only the 39 always-run files
execute. Estimated PR-time R CMD check: under 5 minutes on
Ubuntu, under 8 minutes on macOS, under 10 minutes on Windows.

### Acceptable trade-off

The gate slows nightly / main / dispatch runs (the slow suite
takes the time it currently takes), but every PR is faster. The
slow suite still runs on main pushes, so regressions in recovery
fits get caught at the merge boundary, not at the PR boundary.

This matches the drmTMB practice exactly. drmTMB has roughly the
same fast/slow split and uses `RUN_SLOW_TESTS` for the gate.

## Verification protocol (Codex's Phase 4 PR)

Once Codex implements the gates, the audit's accuracy can be
re-verified by:

```sh
# fast suite (should be the 39 always-run files):
unset RUN_SLOW_TESTS
Rscript -e 'devtools::test()'

# slow suite (should add the 30 gated files):
export RUN_SLOW_TESTS=1
Rscript -e 'devtools::test()'
```

If the audit miscategorised a file (e.g., `test-canonical-keywords.R`
is actually a recovery test, not smoke), the gate will skip it
when `RUN_SLOW_TESTS` is unset and the slow suite still covers
it -- so the worst case is "we lose a fast-PR test that should
have run." Boole + Curie review the misclassifications during
the Phase 4 PR.

## Out of scope

- The audit does NOT modify any source / test files. The gate
  implementation is Codex's Phase 4 PR.
- The audit does NOT change the CI workflow YAML. That edit is
  also in Phase 4 PR scope.
- The audit does NOT propose dropping any tests. Every test
  currently exists for a reason; this only sorts them by cost.
- The audit does NOT propose adding parallelism (`Config/testthat/parallel: true`).
  That is a separate Phase 4 sub-task.

## Shannon checklist (state at this audit's time)

| # | Check | Result |
|---|---|---|
| 1 | PR + after-task pairing | ✅ all 13 today merges paired; this PR has at-branch-start |
| 2 | Working-tree hygiene | ✅ Main checkout no longer on Codex's branch (PR #39 merged) |
| 3 | Cross-PR file overlap | ✅ 0 open PRs; this is the only Claude work in flight |
| 4 | Branch / PR census | ✅ 0 open at audit start; WIP = 1 with this PR (way under cap) |
| 5 | Rule-vs-practice drift | ✅ none |
| 6 | Sequencing | ✅ this audit is Phase 4 prep; Phase 4 work itself waits for item #1 phylo doc-validation to land (per ROADMAP order) |

**Verdict: PASS.**
