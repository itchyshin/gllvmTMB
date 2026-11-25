# Check-log: prior-table R suite reconciliation

## Goal

Reconcile the current-main gllvmTMB generalized-prior and unique-variance table path with the latest focused suite failures, then validate the corrected source without merging overlapping work.

## Commands and results

- `Rscript --vanilla -e 'devtools::test(filter = "prior-table|psi-sd-priors|fixed-effect-priors|isdm-diagnostic-(contract|receipts)", stop_on_failure = TRUE)'`: passed 493 checks, 0 failures, 0 warnings.
- `Rscript --vanilla -e 'devtools::test(filter = "interval-calibration-claims|reader-facing-no-register-codes|register-evidence-paths", stop_on_failure = TRUE)'`: passed 31 checks, 0 failures, 0 warnings.
- `Rscript --vanilla -e 'devtools::test(filter = "gapclose-next-steps", stop_on_failure = TRUE)'`: passed 52 checks, 0 failures, 0 warnings; bare-abort inventory is 770, at the existing ceiling.
- `Rscript --vanilla -e 'devtools::test(filter = "diagnose-ordinal-spde-sweep", stop_on_failure = TRUE)'`: passed 10 checks.
- `Rscript --vanilla -e 'devtools::test(filter = "issue-1484-ordinal-floor-documented", stop_on_failure = TRUE)'`: passed 7 checks.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`: completed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: passed with no problems; Pandoc emitted its existing `--mathml` deprecation warnings.
- R parse of all eight changed R source/test files: passed.
- `git diff --check`: passed.
- `python3 /Users/z3437171/shinichi-brain/tools/slop_check.py <absolute README/article paths>`: passed with no findings above the configured threshold.

The corrected focused checks cover empty prior tables, fixed-only/Psi-only/mixed table dispatch, selector errors, the normalized natural-SD Gamma penalty, prior-table diagnostics, the ordinal help topic, calibration wording, navigation labels, validation-register paths, and next-step guidance.

## Not run

The full gllvmTMB suite has not yet run on this corrected source. The earlier full run on source `00e8ff22771a98c03c92c77ca2b76749d9981320` is terminal red and is retained as diagnostic evidence only. The independent public-table v2 probe passed 146/146 on an earlier immutable working-tree snapshot; the parser, prior adapters, fit dispatcher, and public entry point match the current source byte-for-byte, but the complete current source was not frozen for that run. No merge or release was performed.

## Claim boundary

Focused tests, documentation checks, and the earlier public-table probe do not establish a full-package pass on the final source. A source-pinned full suite and final-source receipt remain required. Open PR #1874's Covered-Flip Gate text/test and PR #1876's calibration-boundary edits remain untouched in their own branches; the isolated candidate retains its separate KER-03A evidence-path correction and current claim boundary.
