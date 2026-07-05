# After Task: Phylo Tree Log-Determinant Sign Guard

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Noether / Fisher / Curie / Rose / Grace / Shannon`

## 1. Goal

Close issue #611 locally: the `phylo_tree` Hadfield sparse-Ainv route should
use the correct `log|A_aug|` sign so reported objective / logLik / AIC / BIC
match the equivalent dense `phylo_vcv` route.

## 2. Implemented

- Changed the tree route from `-sum(log(inv$dii))` to `sum(log(inv$dii))`.
- Updated the inline comment to `log det A = sum(log(dii))`.
- Tightened the existing Hadfield regression so tree and dense paths must agree
  on objective and `logLik()`, not only point estimates.

## 3. Files Changed

- `R/fit-multi.R`
- `tests/testthat/test-phylo-hadfield.R`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-phylo-tree-logdet-sign.md`

## 3a. Decisions and Rejected Alternatives

Decision: patch the R-side precomputed determinant sign only. Rationale: the
C++ likelihood already expects `log_det_A_phy_rr` as `log|A|`; dense and sparse
direct routes already supply that convention. Rejected alternative: touch the
TMB likelihood; that would risk changing all phylogenetic routes when only the
tree setup constant was wrong. Confidence: high.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/fit-multi.R")); invisible(parse("tests/testthat/test-phylo-hadfield.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-phylo-hadfield.R")'
```

Outcomes:

- Parse check: `parse-ok`.
- `test-phylo-hadfield.R`: 15 pass, 0 fail, 0 warn, 0 skip.

## 5. Tests of the Tests

The added objective/logLik expectations are a direct failure-before-fix guard:
the old sign left MLEs aligned but shifted the marginal objective constant.
After the fix, the sparse tree route and dense `phylo_vcv` route agree on both
point estimates and the reported likelihood.

## 6. Consistency Audit

Final audit command:

```sh
rg -n "log_det_A_phy_rr <-|sum\\(log\\(inv\\$dii\\)\\)|issue #611|phylo_tree.*log|logLik|AIC|source-specific.*lv|mixed-family CI|interval calibration" R/fit-multi.R tests/testthat/test-phylo-hadfield.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-07-05-phylo-tree-logdet-sign.md
```

Verdict: found the corrected sign, tree-vs-dense objective/logLik regression,
and claim-boundary text only. This slice does not promote source-specific `lv`,
mixed-family CI, or interval calibration.

## 7. Roadmap Tick

N/A. This is a correctness repair for an existing sparse phylogenetic route.

## 7a. GitHub Issue Ledger

- Inspected issue #611 and implemented the local fix. No GitHub comment or
  closure was made because this branch remains unpublished.

## 8. What Did Not Go Smoothly

No technical blocker. The only care point was distinguishing the precomputed
normalizing constant from model-estimation behavior: MLE agreement was already
tested, but objective/logLik agreement was missing.

## 9. Team Learning

Ada kept the slice scoped to a correctness repair. Noether verified the
determinant convention across dense, sparse direct, tree, and C++ likelihood
paths. Fisher kept the likelihood-vs-estimate distinction explicit. Curie added
the missing objective/logLik regression to the existing tree-vs-dense test.
Rose kept the wording away from new interval or capability claims. Grace
recorded the focused command evidence. Shannon left the public issue untouched
until the unpublished branch is reviewed or pushed.

## 10. Known Limitations And Next Actions

No full package check or release gate was run. Next candidates remain the
open issue map around missing data / mixed-family correctness and stale enum
cleanup; broader simulation and interval calibration still belong to separate
planned slices.
