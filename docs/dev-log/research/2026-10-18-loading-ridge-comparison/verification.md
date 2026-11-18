# Documentation verification

The copied aggregate CSVs and summary JSON match the audited campaign files byte for byte. Exactly 24,000 attempts, 6,000 paired datasets, 144,000 effect rows, 48 recovery cells and 500 attempts per cell/scale were checked. The frozen evidence SHA256SUMS passed before documentation assessment; the final manifest includes the added verification files.

Commands run in the isolated source-161abe09 worktree:

- `git diff --check`: passed.
- `pkgdown::check_pkgdown()`: passed, "No problems found". Pandoc emitted existing math-rendering deprecation notices.
- `pkgdown::build_article("articles/fit-diagnostics", lazy = FALSE, quiet = TRUE)`: passed. All article chunks ran, including the five small example fits. The final long/wide ridge covariance comparison printed exactly 0. The explicit loading-ridge-sensitivity anchor exists in the rendered HTML and matches the README link.
- Pure-R constructor readback: loading_ridge formal NULL; default aghq FALSE and ridge-explicit flags FALSE; explicit Inf and 2 preserve their requested values. The separate AGHQ default is 2. No package source was edited.
- `git diff --name-only -- R src man`: empty.
- Numerical documentation check: copied unavailable counts 64/56/66/62; paired covariance reduction 0.018069 with MCSE 0.002095; all quoted coverage figures and all-attempt differences match the retained CSVs.
- Independent statistical and narrow Rose review: PASS. Reviewed the modified README block, diagnostics section, decision, EXT-31 addendum and record against the retained data. No method/default/scope inconsistency found.
- `slop_check.py` on the README, article and study record: passed. No em dash was introduced in the changed text. Exact-draft assessments are separate JSON files and do not certify authorship.

Article execution used the existing local gllvmTMB 0.7.1 installation at /Users/z3437171/Library/R/arm64/4.6/library/gllvmTMB. This validates the runnable documentation against that installation; it is not a new compiled-source or platform certificate. The campaign remains bound to the separate source/binary hashes in provenance.json.

The initial single-article command omitted the articles/ prefix and reported "Can't find article"; using the nested article name corrected it. The final run exited zero. Only the final render log is retained here. No simulation campaign was repeated.

Protected paths: R/gllvmTMB.R is in active PR 1567, and docs/dev-log/check-log.md is in PR 1561. Neither was edited. The control-help text already correctly describes the unchanged opt-in behaviour. This new verification record and the after-task report provide the dated command log for this slice. No PR, push, merge or live-site deployment was performed.
