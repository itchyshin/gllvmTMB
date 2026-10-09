# After Task: Issue 1469 full correlation output

Branch: `codex/issue-1469-correlation-output`
Date: 2026-10-08

## 1. Goal

Resolve the missing reverse cells in direct correlation-table plots, repair related display controls, and verify the original ordinal example before replying.

## 2. Implemented

`extract_correlations()` accepts `entries = "all"` and `entries = "offdiag"`. The unique-pair default is preserved exactly. Expansion copies the interval payload to reversed pairs separately within each tier. Self-correlations are fixed at one, with missing bounds and method `fixed`.

Correlation heatmaps now remove supplied self-pairs before rebuilding the requested diagonal. Thus `include_diagonal = FALSE` works for full input tables, including upper triangles and separate tier panels. One-item tables retain their plotting template.

Help, README, article and extractor contract explain the layouts. The reference index now includes the existing `sigma.gllvmTMB_multi` topic.

## 3a. Decisions and Rejected Alternatives

Do not duplicate rows by default: existing pair counts, interval plots and downstream joins rely on one row per unordered pair. Reject full-layout requests combined with a specific pair. Keep mirrored estimates visibly documented as the same estimate rather than independent evidence.

The supplied example produced symmetric matrices at both ranks and under both item orders. No numerical correlation or item-labelling defect was reproduced. The confirmed runtime bug concerns diagonal filtering in plots.

## 4. Files Touched

- `R/extract-correlations.R` and its generated help: entry expansion and documented contract.
- `R/plot-covariance-tables.R`: supplied-diagonal filtering.
- Three correlation regression test files: layouts, diagonal controls and unique-pair contract.
- README, NEWS, covariance article, extractor contract and `_pkgdown.yml`: user guidance and reference coverage.
- Check log and this report: evidence and scope.

## 5. Checks Run

Fresh `R CMD INSTALL` compiled the current native source and loaded successfully. Installed-package tests passed 149 full-entry assertions, 17 diagonal-control assertions and 15 pair-layout assertions. Existing Sigma-table tests passed their applicable assertions; one mixed-family test was skipped by its CRAN guard.

The supplied data were replayed at d=1 and d=2, each under original and alphabetical item orders. All four runs returned 28 unique pairs, exactly symmetric matrices, zero named-pair discrepancies and identical reversed-pair requests.

Roxygen generation, Rd parsing and article rendering completed. `pkgdown::check_pkgdown()`, reader-surface and Actions-boundary checks passed. Existing plotting tests passed 263 assertions. The required full local check ran: 25,523 assertions passed, with 11 failures, 58 test warnings and 1,242 skips; R CMD check reported 1 error, 2 warnings and 4 notes. Five failures were a cached-S3 plot tracing harness; its local generic-capture replacement preserves all six assertions and passes in isolation. A campaign-file guard was placed after a file-dependent assertion; it now precedes the assertion. Three visual snapshot failures reproduce with the baseline correlation-display code. Two unchanged variational-prototype assertions report three healthy starts rather than four on this Mac. These remaining checks are not a clean full-suite certificate. The generated loading help default was also synchronized with its existing function signature. The two repaired check files passed 54 assertions together. A separate replay with no campaign root passed with the intended skip. The landing receipt below binds these results to the merged commit.


### Landing receipt

PR #1470 head `3bf541243592145ecfcc6208c4e7a786ae94a90e` passed all four
R-CMD-check shards in run 37870005610 before the merge gate landed it at
2026-10-09 01:54:37 UTC. Merge commit:
`4b595ac221c4559e3b4a72fa2f9aa5ca4c8163ce`.
Its tree is identical to the reviewed PR head. Main run 37872026904 completed
successfully, all four shards green. The merged source was reinstalled and all
181 correlation assertions passed again. The public ordinal example passed
all four rank/order replays again, including 64 full cells and 56 cells with
self-correlations hidden. The narrower metadata check had zero errors,
one test-dependency warning and four notes; the loading-help mismatch is gone.
The broad local residuals above remain explicitly outside this completion claim.
No issue reply has been posted.

## 6. Tests of the Tests

Before implementation all six full-entry tests failed because `entries` was unsupported. The supplied-diagonal regression failed five checks: full plots retained four cells rather than two, and an upper triangle retained three rather than one. After repair the regression suite passed. A numeric-axis assertion was corrected to compare item labels because the vertical display axis is reversed; row-count assertions remained unchanged. No tolerance was widened.

## 7a. Issue Ledger

Addresses https://github.com/itchyshin/gllvmTMB/issues/1469. This report does not imply that a public reply has been sent.

## 8. Consistency Audit

Independent runtime and public-surface reviews returned OK. The latter prompted explicit wording that Julia off-diagonal rows use method `none`, while self-pairs use `fixed`, and a corrected contract signature. Native likelihoods and Julia inference capabilities are unchanged.

## 9. What Did Not Go Smoothly

The first installed neighbour-test invocation lacked access to internal helpers. It was rerun with the package namespace as parent. Git scans of this large Dropbox worktree were slow; scoped file operations preserved other lanes. Roxygen changed unrelated topics, which were restored from HEAD. The full check exposed the harness and installed-file ordering repairs described above. Its format validator passed, but the repository-wide completion validator found unrelated unmet ijsdm and temporal ledgers; those were left untouched.

## 10. Known Residuals

Symmetry is an output-contract check, not evidence of convergence, rank adequacy or interval calibration. Full tables repeat each off-diagonal estimate. Use unique rows for pairwise inference. No collaborator raw data were committed. The local visual-snapshot and variational-prototype residuals above remain outside this correlation repair.

## 11. Team Learning

Pair-table defaults need an explicit full-table route near the extractor help. Full input tables must exercise plotting options as well as the extractor: supplied diagonal rows exposed a bug that unique-pair fixtures could not catch.

Style assessment: self-review 2/10 perceived AI-like style. Scientific, factual and reference gates pass for the bounded claims above.

## 12. Cross-Product Coverage

This change does NOT cover Julia likelihood parity, new interval methods, latent-rank selection, penalty calibration or observed-score ordinal correlations. Tests cover the R table contract and a synthetic point-only Julia adapter without running Julia.
