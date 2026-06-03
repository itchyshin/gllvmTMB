# After Task: Missing-Data Docs And API Scope Split

**Branch**: `codex/missing-data-docs-api`
**Date**: `2026-06-03`
**Roles (engaged)**: `Ada / Pat / Rose / Grace`

## 1. Goal

Split the missing-data documentation and API-surface alignment from the dirty coevolution article worktree into a focused branch. The branch should publish what the shipped v1 missing-data layer actually supports, point each public claim to validation-debt rows, and avoid carrying unrelated binary-JSDM citation, coevolution article, or slope-grid status edits.

## 2. Implemented

- Updated the roxygen prose for `gllvmTMB()`, `miss_control()`, `impute_model()`, and `predict_missing()` so the docs describe the shipped response-mask and modelled-predictor layer rather than the older Phase-2a-only wording.
- Regenerated the matching Rd topics: `man/gllvmTMB.Rd`, `man/impute_model.Rd`, `man/miss_control.Rd`, and `man/predict_missing.Rd`.
- Promoted the missing-data article navigation text from draft skeleton to worked missing-data article for the shipped v1 slices.
- Updated `README.md`, `NEWS.md`, `vignettes/gllvmTMB.Rmd`, and `vignettes/articles/missing-data.Rmd` with explicit scope boundaries and row IDs.
- Added validation-register rows MIS-23 through MIS-32 and revised MIS-21 to reflect response masking plus the modelled `mi()` exceptions.

No TMB likelihood, parser grammar, formula keyword, or implementation path changed in this branch.

## 3. Files Changed

Roxygen/API prose:

- `R/gllvmTMB.R`
- `R/methods-gllvmTMB.R`
- `R/missing-predictor.R`

Public docs and navigation:

- `README.md`
- `NEWS.md`
- `_pkgdown.yml`
- `vignettes/gllvmTMB.Rmd`
- `vignettes/articles/missing-data.Rmd`

Generated Rd:

- `man/gllvmTMB.Rd`
- `man/impute_model.Rd`
- `man/miss_control.Rd`
- `man/predict_missing.Rd`

Scope ledger and closeout:

- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-03-missing-data-docs-api-split.md`
- `docs/dev-log/recovery-checkpoints/2026-06-03-045707-codex-checkpoint.md`

## 3a. Decisions and Rejected Alternatives

**Decision**: Keep this branch documentation/API-facing only.
**Rationale**: The shipped missing-data implementation and tests already exist; the current task is to make the package dump/pkgdown story match those verified routes.
**Rejected alternative**: Mix in the binary-JSDM package citation or coevolution article cleanup from the source dirty tree. Those are separate branches.
**Confidence**: high.

**Decision**: Advertise missing-data support through MIS-21 and MIS-23..MIS-32 row IDs instead of phase labels alone.
**Rationale**: AGENTS.md requires every advertised capability to map to a `covered`, `partial`, or `blocked` validation-debt row.
**Rejected alternative**: Leave the article's phase labels as the only scope boundary. That is harder to audit after future phases ship.
**Confidence**: high.

**Decision**: Keep `vignettes/articles/missing-data.Rmd` as Tier 1.
**Rationale**: The article answers a user-shaped question: what to do when response or predictor values are missing, with runnable examples for the shipped routes and explicit failure boundaries.
**Rejected alternative**: Demote it to Tier 2 or hide it from the navbar. That would make the missing-data feature less discoverable while the public README advertises it.
**Confidence**: medium-high.

## 4. Checks Run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  Outcome: completed; regenerated the touched Rd files. Unrelated generated Rd churn in `man/add_utm_columns.Rd`, `man/extract_correlations.Rd`, `man/make_mesh.Rd`, `man/reexports.Rd`, and `man/gllvmTMB-package.Rd` was restored out of this branch.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  Outcome: `No problems found.`
- `Rscript --vanilla -e 'devtools::test(filter = "missing")'`
  Outcome: `[ FAIL 0 | WARN 0 | SKIP 80 | PASS 69 ]` in 4.6s; skips are heavy recovery / matrix tests gated by `GLLVMTMB_HEAVY_TESTS=1`.
- `Rscript --vanilla -e 'pkgdown::build_article("gllvmTMB", lazy = FALSE, quiet = FALSE)'`
  Outcome: completed; wrote `pkgdown-site/articles/gllvmTMB.html`.
- `Rscript --vanilla -e 'pkgdown::build_article("missing-data", lazy = FALSE, quiet = FALSE)'`
  Outcome: failed with `Can't find article 'missing-data'`; this was the wrong pkgdown article key.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/missing-data", lazy = FALSE, quiet = FALSE)'`
  Outcome: completed; wrote `pkgdown-site/articles/missing-data.html`.
- `git diff --check`
  Outcome: clean after the closeout report and check-log entry were staged.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  Outcome: final rerun after the closeout report was added: `No problems found.`
- `for f in man/gllvmTMB.Rd man/impute_model.Rd man/miss_control.Rd man/predict_missing.Rd; do printf '%s ' "$f"; grep -c '^\\keyword' "$f"; done`
  Outcome: all four changed Rd files reported `0`.
- `for f in man/gllvmTMB.Rd man/impute_model.Rd man/miss_control.Rd man/predict_missing.Rd; do printf '\n== %s ==\n' "$f"; tail -5 "$f"; done`
  Outcome: normal Rd tails; no malformed keyword spill.
- `git rebase origin/main` on 2026-06-03 after #420 / #434
  Outcome: conflicts in `_pkgdown.yml` and `docs/dev-log/check-log.md`; resolved by preserving main's public Data handling article placement, preserving VA / Track A / binary-citation check-log entries, and keeping this missing-data entry.
- `git diff --check` after the post-rebase whitespace cleanup
  Outcome: clean.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` after rebase onto `ebf4ff0`
  Outcome: `No problems found.`
- `Rscript --vanilla -e 'devtools::test(filter = "missing")'` after rebase onto `ebf4ff0`
  Outcome: `[ FAIL 0 | WARN 0 | SKIP 80 | PASS 69 ]` in 4.6s; skips are heavy recovery / matrix tests gated by `GLLVMTMB_HEAVY_TESTS=1`.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/missing-data", lazy = FALSE, quiet = FALSE)'` after rebase onto `ebf4ff0`
  Outcome: completed; wrote `pkgdown-site/articles/missing-data.html`.
- `Rscript --vanilla -e 'pkgdown::build_article("gllvmTMB", lazy = FALSE, quiet = FALSE)'` after rebase onto `ebf4ff0`
  Outcome: completed; wrote `pkgdown-site/articles/gllvmTMB.html`.
- `gh run list --repo itchyshin/gllvmTMB --branch main --limit 8 --json ...` after waiting on #434
  Outcome: #434 `R-CMD-check` run `26879590698` succeeded, and #434 `pkgdown` run `26880113798` completed successfully at `2026-06-03T11:23:02Z`.
- `git push -u origin codex/missing-data-docs-api`
  Outcome: uploaded branch `codex/missing-data-docs-api`; this did not trigger R-CMD-check because the workflow runs on `pull_request` and pushes to `main` / `master`, not plain feature-branch pushes.

## 5. Tests of the Tests

No new tests were added. The branch ties public claims to existing missing-data tests:

- Response-missing cells and response masking: `test-missing-response.R`, `test-missing-response-gaussian.R`, `test-missing-response-traits.R`, `test-wide-weights-matrix.R`.
- Missing-data policy and fail-loud boundaries: `test-miss-control.R`, `test-missing-data-robustness.R`, `test-missing-data-robustfix.R`.
- Modelled predictors: `test-missing-predictor-gaussian.R`, `test-missing-predictor-binary.R`, `test-missing-predictor-ordered.R`, `test-missing-predictor-categorical.R`, and `test-missing-predictor-phylo.R`.

These tests cover acceptance routes plus unsupported-engine / unsupported-family / malformed-input boundaries; the branch does not widen the implementation claim beyond those tests.

## 6. Consistency Audit

- `rg -n "gllvmTMB\\(" R vignettes README.md NEWS.md docs/design`
  Verdict: broad enumeration only. Touched long-format examples in `README.md` and `vignettes/gllvmTMB.Rmd` include explicit `trait =`; touched wide `traits(...)` examples correctly omit it.
- `rg -n "gllvmTMB_wide|meta_known_V|\\bphylo_rr\\b|block_V\\(|\\bS_B\\b|\\bS_W\\b|\\\\bf S|in prep|in preparation" README.md NEWS.md R man vignettes docs/design/35-validation-debt-register.md`
  Verdict: expected legacy alias hits in existing alias docs, compatibility prose, and engine-internal comments. No new missing-data prose uses deprecated aliases as primary syntax.
- `rg -n "MIS-21|MIS-23|MIS-24|MIS-25|MIS-26|MIS-27|MIS-28|MIS-29|MIS-30|MIS-31|MIS-32" README.md NEWS.md R/gllvmTMB.R R/methods-gllvmTMB.R R/missing-predictor.R man/gllvmTMB.Rd man/impute_model.Rd man/miss_control.Rd man/predict_missing.Rd vignettes/articles/missing-data.Rmd vignettes/gllvmTMB.Rmd docs/design/35-validation-debt-register.md`
  Verdict: touched public claims map to MIS-21 and MIS-23..MIS-32.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. The scope tick is in `docs/design/35-validation-debt-register.md`: MIS-23..MIS-31 are `covered`, and MIS-32 records the deferred missing-data extensions as `blocked`.

## 7a. GitHub Issue Ledger

Relevant issue handles are #332 and #365. No issue was closed in this branch preparation step; the PR should reference both, and closure should wait for CI plus main pkgdown deployment.

## 8. What Did Not Go Smoothly

- The first targeted article render used `pkgdown::build_article("missing-data", ...)`, which is the wrong key for a nested article. The correct key is `articles/missing-data`, and that render passed.
- Rendering `vignettes/gllvmTMB.Rmd` created untracked vignette PNGs in the temporary worktree. They were generated artifacts and were removed before staging.
- The source dirty tree carried an unrelated NEWS/slope-grid line and unrelated generated Rd churn. Those were excluded from this split branch.
- The rebase onto `ebf4ff0` exposed trailing Markdown hard-break spaces in this report. They were removed before the post-rebase `git diff --check` rerun.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: Keep the branch bounded. This branch publishes the missing-data scope already supported by tests; it does not claim a new likelihood or parser surface.

Pat: The article now names what a user can try first: default complete-case handling, response masking with `predict_missing()`, and one explicitly modelled `mi()` predictor in the covered v1 slices.

Rose: The public claims now map to validation rows. Expected legacy alias hits remain in alias docs and engine-internal comments, not in the new missing-data prose.

Grace: Local pkgdown checks and the targeted article renders pass. The wrong-key render failure was command syntax, not site content.

## 10. Known Limitations And Next Actions

MIS-32 remains blocked: multiple simultaneous `mi()` terms, EM/profile/REML engines, simulated imputations, MI pooling, structured discrete predictor models, non-phylo structured covariate models, joint response-covariate fields, bounded/count/lognormal/Gamma missing-predictor families, dense known sampling-covariance matrices with partial multivariate response rows, MNAR sensitivity, and bootstrap-SE cross-checks are not implemented.

Next actions are to open the uploaded branch as a PR, let PR CI decide whether it can merge, and then verify the resulting main pkgdown deployment before treating the public missing-data docs/API scope as fully closed.
