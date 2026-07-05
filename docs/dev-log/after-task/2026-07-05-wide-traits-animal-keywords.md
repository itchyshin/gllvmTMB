# After Task: Wide traits animal keyword pass-through

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Boole / Curie / Rose / Shannon`

## 1. Goal

Close the local parser bug from issue #604: wide-format `traits(...)` formulas
were preserving `phylo_scalar()`, `phylo_unique()`, and `phylo_slope()` as
covariance markers, but were incorrectly wrapping the animal mirrors
`animal_scalar()`, `animal_unique()`, and `animal_slope()` as fixed-effect trait
interactions.

## 2. Implemented

- Added `animal_scalar`, `animal_unique`, and `animal_slope` to
  `.traits_covstruct_keywords`.
- Extended the existing `traits()` covariance-keyword-grid test to cover the
  animal source family under wide RHS expansion.
- Added a focused no-regression assertion that `:animal_` does not appear in
  the expanded wide formula.
- Recorded the new parser evidence in validation-debt rows `FG-03`, `ANI-01`,
  `ANI-02`, and `ANI-06`.

## 3. Files Changed

- `R/traits-keyword.R`
- `tests/testthat/test-traits-keyword.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-wide-traits-animal-keywords.md`

## 3a. Decisions and Rejected Alternatives

Decision: add only the exported animal mirrors that exist locally:
`animal_scalar`, `animal_unique`, and `animal_slope`.

Rationale: issue #604 suggested `animal_rr` only if it exists. A local search
found no public `animal_rr` keyword, so adding it would create false grammar.

Rejected alternative: fit-level animal tests in this slice. The failing surface
was the wide RHS expander; the existing animal engine and byte-equivalence tests
already cover the long forms. This slice keeps the change parser-only.

Confidence: high for the parser bug; no new likelihood or inference claim.

## 4. Checks Run

```sh
git status --short --branch
git rev-parse --short HEAD
gh issue view 604 --repo itchyshin/gllvmTMB --json number,title,state,body,url,labels
rg -n "traits_covstruct_keywords|traits_expand_rhs|animal_scalar|animal_unique|animal_slope|animal_rr|phylo_scalar|phylo_unique|phylo_slope" R tests/testthat
gh pr list --state open --limit 20
git log --all --oneline --since="6 hours ago"
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); rhs <- quote(1 + animal_scalar(individual) + animal_unique(individual) + animal_slope(env_temp | individual)); cat(paste(deparse(gllvmTMB:::.traits_expand_rhs(rhs)), collapse = " "), "\n")'
Rscript --vanilla -e 'invisible(parse("R/traits-keyword.R")); invisible(parse("tests/testthat/test-traits-keyword.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-traits-keyword.R", reporter = "summary")'
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-canonical-keywords.R", reporter = "summary")'
git diff --check
```

Outcomes:

- Pre-fix reproducer showed `(0 + trait):animal_scalar(...)`,
  `(0 + trait):animal_unique(...)`, and `(0 + trait):animal_slope(...)`.
- Post-fix micro-check showed `animal_scalar(...)`, `animal_unique(...)`, and
  `animal_slope(...)` passing through as covariance markers.
- Parse passed.
- `test-traits-keyword.R` passed with one existing CRAN-gated skip.
- `test-canonical-keywords.R` passed with three existing INLA skips.

## 5. Tests of the Tests

Failure-before-fix was directly observed with a micro-check. The new
`expect_no_match(":animal_")` assertion would have caught that exact expansion
shape. The test is parser-level by design; it does not claim new fit recovery.

## 6. Consistency Audit

```sh
rg -n "animal_scalar\\(|animal_unique\\(|animal_slope\\(|:animal_" R/traits-keyword.R tests/testthat/test-traits-keyword.R docs/design/01-formula-grammar.md docs/design/35-validation-debt-register.md
```

Verdict: the grammar docs already advertised the animal family; the validation
register now records the wide parser evidence. The only `:animal_` hit is the
negative test pattern.

## 7. Roadmap Tick

N/A. This is a bug-fix truth lock for an already-advertised formula surface.

## 7a. GitHub Issue Ledger

- Inspected open issue #604:
  `https://github.com/itchyshin/gllvmTMB/issues/604`.
- Local fix implemented. Issue not closed here because the branch has not been
  pushed or merged in this slice.

## 8. What Did Not Go Smoothly

The initial broad `rg` over all tests was too noisy. The useful path was to
inspect `R/traits-keyword.R`, the existing `test-traits-keyword.R` grid test,
and the exported animal keyword definitions directly.

## 9. Team Learning

- Ada: kept the slice to issue #604 rather than opening a new animal-model lane.
- Boole: confirmed this is formula grammar pass-through, not engine semantics.
- Curie: reused the existing covariance-keyword-grid test and added the exact
  negative pattern that would have failed before the fix.
- Rose: kept the validation register honest: no status promotion, only new
  evidence for an already-covered surface.
- Shannon: pre-edit lane check showed no open PR list output and recent commits
  were local branch work, so the shared dev-log/register edits were safe.

## 10. Known Limitations And Next Actions

- No TMB likelihood, extractor, profile, bootstrap, or new public capability was
  added.
- Issue #604 should be closed only after the local branch is pushed and merged
  or the maintainer explicitly asks for GitHub-side closure.
- Continue the completion arc by taking the next small truth-lock issue or by
  returning to the broader profile target taxonomy for unit / observed /
  cluster / structural combinations.
