# After Task: Missing Response Cells

**Branch**: `codex/symbol-syntax-alignment-2026-05-21`
**Date**: `2026-05-21`
**Roles (engaged)**: `Ada / Emmy / Curie / Rose / Grace / Pat`

## 1. Goal

Make the response trait cell behave like an observation-level data cell: if
the response is `NA`, the model should treat that unit-trait cell as
unobserved instead of forcing users to listwise-drop the whole unit.

## 2. Implemented

- Long-format `gllvmTMB(value ~ ..., data = df_long)` now drops rows with
  missing scalar responses before weight normalisation and before the TMB
  likelihood is built.
- Long-format `cbind(successes, failures)` binomial rows are dropped when
  either response component is missing.
- Observation weights are subset to retained response rows before validation.
  This lets weights attached only to observed rows reach the engine while
  preserving the existing long-format shape checks.
- Wide `traits(...)` already dropped missing response cells through
  `pivot_longer(values_drop_na = TRUE)`; its skipped NA test is now active
  against a covstruct model.
- Missing predictors and fixed-effect design entries still error. This task
  changed response-missingness only.

## 3. Files Changed

- `R/gllvmTMB.R`: added response-missingness preprocessing and roxygen docs.
- `R/fit-multi.R`: split the internal NA guard into response and design-matrix
  diagnostics.
- `tests/testthat/test-missing-response.R`: added long-format scalar-response
  and `cbind()` missing-response tests.
- `tests/testthat/test-traits-keyword.R`: re-enabled the wide `traits(...)`
  missing-cell test with a covstruct model.
- `NEWS.md`: advertised the supported missing-response contract with row
  `MIS-21`.
- `docs/design/35-validation-debt-register.md`: added covered row `MIS-21`.
- `man/gllvmTMB.Rd`: regenerated from roxygen.
- `R/data-mixed-family.R`: qualified `stats::setNames()` to clear an R CMD
  check global-function NOTE.
- `R/z-confint-gllvmTMB.R`: qualified `utils::modifyList()` to clear an R CMD
  check global-function NOTE.

## 3a. Decisions and Rejected Alternatives

- Decision: drop only rows whose response expression is missing. Rationale:
  this preserves the multivariate ragged-response likelihood users expect from
  packages such as `MCMCglmm`, without discarding other observed traits for the
  same unit. Rejected alternative: listwise-drop all rows sharing the same unit,
  which would make wide and long input behave differently and waste observed
  data. Confidence: high for MAR-style observed-cell likelihood handling.
- Decision: keep predictor/design missingness as an error. Rationale: a missing
  design row cannot be evaluated by the fixed-effect matrix. Rejected
  alternative: silently dropping predictor-NA rows too, which would make data
  loss less explicit. Confidence: high.

## 4. Checks Run

- `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent work was the current PR #233 branch and merged PR #232; no
  competing shared-log lane was visible.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `man/gllvmTMB.Rd`.
- `tail -5 man/gllvmTMB.Rd`
  -> ended in the expected `\seealso{...}` block.
- `grep -c '^\\keyword' man/gllvmTMB.Rd`
  -> `0`.
- `Rscript --vanilla -e 'devtools::test(filter = "missing-response|traits-keyword")'`
  -> 63 passes, 0 failures, 0 warnings, 0 skips after relaxing the tiny
  ragged wide smoke test away from an optimizer-convergence assertion.
- `Rscript --vanilla -e 'devtools::test(filter = "missing-response|traits-keyword|weights-unified|gllvmTMB-args")'`
  -> 117 passes, 0 failures, 0 warnings, 4 expected skips in
  `test-gllvmTMB-args.R`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean.
- Full check:
  `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> 0 errors, 1 warning, 4 notes before the namespace-note cleanup. Warning
  was local macOS SDK lookup / compile warning noise during package install;
  notes were top-level files (`air.toml`, generated `Rplots.pdf`), legacy NEWS
  section parsing, unused `nlme`, and unqualified `setNames` / `modifyList`.
- Local install probe:
  `R CMD INSTALL --preclean --library=/tmp/gllvmtmb-install-lib .`
  -> package installed; reproduced the local SDK warning:
  `xcrun --show-sdk-version` exits 1 because the Command Line Tools SDK cannot
  be located by `xcrun`.
- Cleanup after full check: removed ignored generated `Rplots.pdf`, qualified
  `stats::setNames()` and `utils::modifyList()`.
- `Rscript --vanilla -e 'devtools::test(filter = "missing-response|traits-keyword|weights-unified|gllvmTMB-args|stage37-mixed-family|confint")'`
  -> 165 passes, 0 failures, 1 expected deprecation warning, 4 expected skips.
- Short check after cleanup:
  `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE)'`
  -> 0 errors, 1 local SDK install warning, 3 notes (`air.toml`, legacy NEWS
  section parsing, unused `nlme`). The prior global-function NOTE was gone.

## 5. Tests of the Tests

- `test-missing-response.R` is a boundary-case test: it exercises missing
  response rows in the long-format scalar-response path.
- The same file is also a feature-combination test: missing responses are
  combined with long-format weights and with `cbind(successes, failures)`
  binomial responses.
- The re-enabled `traits(...)` test is a boundary-case test for ragged wide
  response cells. It asserts the dropped-cell count and retained engine data
  size rather than requiring optimizer convergence on a deliberately tiny
  ragged example.

## 6. Consistency Audit

Command:

```sh
rg -n 'NA in response or design matrix|remove NA rows before fitting|Missing response|Response `NA`s|MIS-21' R/gllvmTMB.R R/fit-multi.R man/gllvmTMB.Rd NEWS.md docs/design/35-validation-debt-register.md tests/testthat/test-missing-response.R tests/testthat/test-traits-keyword.R
```

Verdict: old combined NA wording is gone; new MIS-21 documentation appears in
roxygen, Rd, NEWS, and the validation register.

- `rg -n 'trio|profile-likelihood default|gllvmTMB_wide\\(Y, \\.\\.\\.\\) was removed|removed in 0\\.2\\.0|meta_known_V\\(|diag\\(S\\)|diag\\(s\\)|diag\\(U\\)|\\\\bf S|\\bS_B\\b|\\bS_W\\b|unsupported .* implemented|all-missing traits' NEWS.md R/gllvmTMB.R man/gllvmTMB.Rd README.md vignettes/articles/morphometrics.Rmd docs/design/35-validation-debt-register.md docs/design/06-extractors-contract.md docs/design/53-report-ready-extractor-plot-contract.md`
  -> only intentional existing mentions were found: `meta_known_V()` as a
  deprecated alias, an internal comment about the removed sdmTMB fallback, and
  the new NEWS limitation that all-missing traits still need explicit user-side
  decisions.
- `rg -n 'gllvmTMB\\(' NEWS.md R/gllvmTMB.R man/gllvmTMB.Rd README.md vignettes/articles/morphometrics.Rmd docs/design/06-extractors-contract.md docs/design/53-report-ready-extractor-plot-contract.md`
  -> touched long-format examples still pass `trait = "..."` explicitly where
  required; wide examples use `traits(...)` and no `trait =`.
- `rg -n "@export|export\\(extract_Sigma_table\\)|extract_Sigma_table" R/extract-sigma-table.R NAMESPACE _pkgdown.yml man/extract_Sigma_table.Rd docs/design/35-validation-debt-register.md NEWS.md`
  -> previous slice's new export is present in `NAMESPACE`, generated Rd,
  `_pkgdown.yml`, NEWS, and row `EXT-18`.

Rose pre-publish gate: PASS for this slice. No public missing-response claim is
unbacked; row `MIS-21` is `covered`; no stale "remove NA rows" instruction
remains in the touched user-facing docs.

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row changed; this is a focused constructor/data-handling
hardening slice.

## 7a. GitHub Issue Ledger

- `gh issue list --state open --search "missing response NA" --limit 10`
  -> no open matching issues.
- `gh issue list --state open --search "traits NA" --limit 10`
  -> no open matching issues.
- `gh issue list --state open --search "wide format" --limit 10`
  -> found #230, "Article surface reset and user-first tooling gate".
- `gh issue view 230 --json number,title,body,labels,url`
  -> #230 is the broad public article/tooling gate. No comment added because
  this task is lower-level constructor hardening and does not itself close one
  of the enumerated issue gates.

## 8. What Did Not Go Smoothly

- The source audit showed an asymmetry: wide `traits(...)` already dropped
  missing response cells, but explicit long-format input still hit the generic
  `NA in response or design matrix` abort. The fix was small, but the user-facing
  contract needed tests and docs so the behavior is no longer implicit.
- The first re-enabled wide ragged-data test required convergence on a tiny
  intentionally ragged model and failed with optimizer convergence code `1`.
  The test now verifies acceptance, dropped-cell metadata, and retained data
  size, while the long scalar and `cbind()` missing-response tests verify clean
  convergence.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- Ada kept the scope to response-missingness only: no TMB likelihood changes,
  no formula grammar changes, and no broad missing-data framework.
- Emmy caught the architecture boundary: the C++ likelihood should continue to
  receive finite response vectors; the public R wrapper owns observed-cell
  filtering and weight alignment.
- Curie shaped the tests around the actual risk: scalar long rows, `cbind()`
  response rows, weights, and wide `traits(...)` cells.
- Rose checked the public claim against the validation register and assigned
  `MIS-21`, avoiding a duplicate `MIS-18` row.
- Grace verified roxygen, pkgdown, and whitespace checks.
- Pat's applied-user lens is the reason the NEWS and help text say plainly
  that other observed traits for the same unit remain in the likelihood.

## 10. Known Limitations And Next Actions

- This is not a full missing-data model. It fits the observed-cell likelihood
  after dropping missing response cells.
- Predictor, grouping-variable, and design-matrix missingness still error.
- All-missing traits or all-missing units remain a modelling/design decision;
  they are not promoted as a supported feature in this slice.
