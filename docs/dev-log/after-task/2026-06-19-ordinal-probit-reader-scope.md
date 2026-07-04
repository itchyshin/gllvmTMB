# After-Task Report: ordinal-probit Reader Scope

Date: 2026-06-19 01:24 MDT
Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Finish article-council step 6 by aligning the internal `ordinal-probit`
technical draft with its current validation status.

## Files Touched

- `vignettes/articles/ordinal-probit.Rmd`
- `docs/dev-log/audits/2026-06-18-article-council-ledger.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-ordinal-probit-reader-scope.md`

## What Changed

- Demoted the stale Tier 2 YAML to Tier 3 while `FAM-14` remains partial.
- Added an internal article gate.
- Added a reader/scope bridge for family choice, long/wide syntax, cutpoints,
  latent-scale variance components, and guardrails.
- Updated standalone diagonal teaching from `phylo_unique()` / `unique()` to
  `phylo_indep()` / `indep()`.
- Kept `unique()` only as an observation-level residual guardrail: it is
  structurally unidentifiable for ordinal-probit traits.

## Verification

- Pre-edit lane check:
  - `gh pr list --state open` -> only draft PR #489 was open.
  - `git log --all --oneline --since="6 hours ago"` -> no recent commits.
- Article render:
  - `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); pkgdown::build_article("articles/ordinal-probit", pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'`
  - Result: rendered `pkgdown-site/articles/ordinal-probit.html`.
- Rendered HTML review:
  - `ordinal_rendered_reader_scope_review=PASS`.
  - Rendered HTML includes the internal gate, reader/scope bridge, `FAM-14`
    partial boundary, `phylo_indep()` / `indep()` standalone diagonal syntax,
    and the structural-unidentifiability guardrail.
- Figure assets:
  - None expected; all chunks remain `eval = FALSE` until a runnable ordinal
    worked example lands.

## Still Not Claimed

- No public promotion of `ordinal-probit`.
- No runnable ordinal worked example.
- No per-cell `FAM-14` validation promotion.
- No ordinal interval-coverage claim.
- No bridge completion, release readiness, or scientific coverage completion.

## Next Safest Action

Proceed to article-council step 7: capstones and validation articles stay last
unless the maintainer chooses to revisit browser/rendered review first.
