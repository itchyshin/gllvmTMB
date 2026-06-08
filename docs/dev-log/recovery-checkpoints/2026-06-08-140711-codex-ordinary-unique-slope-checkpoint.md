# Recovery Checkpoint: Ordinary Unique Slope Follow-On

**Branch**: `codex/status-random-regression-article-2026-06-08`  
**Date**: `2026-06-08 14:07:11`  
**Agent**: `Codex`

## Git Status

```text
 M NEWS.md
 M R/brms-sugar.R
 M R/extract-sigma.R
 M R/fit-multi.R
 M R/normalise-level.R
 M README.md
 M ROADMAP.md
 M _pkgdown.yml
 M docs/design/01-formula-grammar.md
 M docs/design/03-likelihoods.md
 M docs/design/04-random-effects.md
 M docs/design/05-testing-strategy.md
 M docs/design/35-validation-debt-register.md
 M docs/design/61-capability-status.md
 M docs/dev-log/audits/2026-05-20-article-gate-matrix.md
 M docs/dev-log/check-log.md
 M man/add_utm_columns.Rd
 M man/extract_Sigma.Rd
 M man/extract_correlations.Rd
 M man/make_mesh.Rd
 M man/reexports.Rd
 M src/gllvmTMB.cpp
 M tests/testthat/test-augmented-lhs-guard.R
 M vignettes/articles/random-regression-reaction-norms.Rmd
 M vignettes/articles/random-slopes-nongaussian.Rmd
?? docs/dev-log/after-task/2026-06-08-ordinary-latent-reaction-norm.md
?? docs/dev-log/after-task/2026-06-08-random-slope-article-status-sync.md
?? docs/dev-log/recovery-checkpoints/2026-06-08-131130-codex-latent-slope-checkpoint.md
?? tests/testthat/test-ordinary-latent-random-regression.R
```

## Diff Stat

```text
 NEWS.md                                            |  37 ++
 R/brms-sugar.R                                     |  38 +-
 R/extract-sigma.R                                  |  60 ++
 R/fit-multi.R                                      | 137 ++++-
 R/normalise-level.R                                |  12 +-
 README.md                                          |  42 +-
 ROADMAP.md                                         |  47 +-
 _pkgdown.yml                                       |   8 +-
 docs/design/01-formula-grammar.md                  |  15 +-
 docs/design/03-likelihoods.md                      |  32 +-
 docs/design/04-random-effects.md                   | 181 +++---
 docs/design/05-testing-strategy.md                 |  26 +-
 docs/design/35-validation-debt-register.md         |   1 +
 docs/design/61-capability-status.md                | 268 ++++-----
 .../audits/2026-05-20-article-gate-matrix.md       |   7 +-
 docs/dev-log/check-log.md                          | 307 ++++++++++
 man/add_utm_columns.Rd                             |   2 +-
 man/extract_Sigma.Rd                               |  10 +-
 man/extract_correlations.Rd                        |   2 +-
 man/make_mesh.Rd                                   |   6 +-
 man/reexports.Rd                                   |   2 +-
 src/gllvmTMB.cpp                                   |  61 ++
 tests/testthat/test-augmented-lhs-guard.R          |  42 +-
 .../articles/random-regression-reaction-norms.Rmd  | 660 +++++++--------------
 vignettes/articles/random-slopes-nongaussian.Rmd   |  75 ++-
 25 files changed, 1247 insertions(+), 831 deletions(-)
```

## Commands Already Run

- `gh pr list --state open --json number,title,headRefName,baseRefName,author,updatedAt --limit 20` -> `[]`.
- `git log --all --oneline --since="6 hours ago"` -> no output.
- Latent slice evidence already recorded in `docs/dev-log/check-log.md`:
  focused ordinary latent test `29 passed`, full `devtools::test()`
  `FAIL 0`, `WARN 0`, `SKIP 704`, `PASS 2576`, article renders clean,
  `pkgdown::check_pkgdown()` clean, and
  `devtools::check(args = "--no-manual")` with `0 errors`, `1 warning`,
  `2 notes`.

## Commands Still Needed

- Implement ordinary augmented `unique(1 + x | unit)` / long-form
  `unique(0 + trait + (0 + trait):x | unit)` for the Gaussian reaction-norm
  lane.
- Add parser acceptance and rejection tests.
- Add TMB smoke / recovery tests for `latent + unique` and standalone
  augmented `unique()`.
- Update extractor, design/status docs, articles, check-log, and after-task
  report.
- Rerun focused tests, article render, `pkgdown::check_pkgdown()`, and broader
  package tests as time permits.

## Next Safest Action

Work from the existing latent implementation and add a separate B-tier
augmented unique diagonal vector over the same `2T` coefficient ordering. Keep
claims Gaussian-first until recovery evidence justifies wider advertising.

## Blocking Question

None. Maintainer priority is clear: ordinary Gaussian random-slope models with
both latent and unique components.
