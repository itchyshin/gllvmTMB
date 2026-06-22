# After Task: screen_gllvmTMB Pre-Fit Response Screening

## Goal

Add a formula-aware pre-fit response screen that helps users inspect candidate
binary/binomial traits, items, or indicators before fitting a stacked-trait
GLLVM. The function should support Ayumi's systematic-map workflow without
claiming automatic variable selection or fitted-model validation.

## Implemented

- Added exported `screen_control()`, `screen_gllvmTMB()`, `screen_table()`, and
  `print.gllvmTMB_screen`.
- Added a `gllvmTMB_screen` S3 object with `summary`, `traits`, `pairs`,
  `units`, `design`, `recommendations`, and `settings` tables.
- Reused the package formula/data preparation path for wide `traits(...)`,
  long `trait =`, response-missing dropping, weights, fixed-effect design
  matrices, covariance-term parsing, and requested latent rank.
- Implemented binary/binomial v1 support for Bernoulli/logical responses,
  `cbind(success, failure)`, and flat successes with `weights = n_trials`.
- Added denominator-aware prevalence, minority-count, `info_fraction`,
  duplicate/complement, near-duplicate, high phi/Jaccard, unit support,
  fixed-effect rank, one-level unit, and `d >= n_traits` checks.
- Added `vignettes/articles/pre-fit-response-screening.Rmd`, design note
  `docs/design/2026-06-22-pre-fit-response-screening.md`, validation-register
  row `DIA-14`, NEWS entry, and pkgdown navigation/reference entries.
- Posted the separate maintainer-approved accessible reply to Ayumi at
  `https://github.com/Ayumi-495/urbanisation_map/issues/1#issuecomment-4773564655`.

## Mathematical Contract

No TMB likelihood, optimizer, or fitted-model machinery changed. The screen is
pre-fit and advisory.

For each binary/binomial trait, the screen reports:

- `prevalence = n_success / total_trials`;
- `minority_count = min(n_success, n_failure)`;
- `minority_rate = min(prevalence, 1 - prevalence)`;
- `info_fraction = 4 * prevalence * (1 - prevalence)`.

The count-first rule is deliberate: 5% prevalence with 20 Bernoulli rows is not
the same evidence as 5% prevalence with 100000 trials. Pairwise Bernoulli checks
use paired rows only and report exact duplicates, exact complements, discordant
counts, normalized Hamming distance, phi, and Jaccard co-presence. Multi-trial
binomial rows are screened at the trait level; pairwise duplicate/complement
screening is `NOT_CHECKED` for those modes.

## Files Changed

- `R/screen-gllvmTMB.R`
- `tests/testthat/test-screen-gllvmTMB.R`
- `man/screen_control.Rd`
- `man/screen_gllvmTMB.Rd`
- `man/screen_table.Rd`
- `NAMESPACE`
- `_pkgdown.yml`
- `NEWS.md`
- `vignettes/articles/pre-fit-response-screening.Rmd`
- `docs/design/2026-06-22-pre-fit-response-screening.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-22-pre-fit-response-screening.md`

No `src/`, TMB, parser grammar, family, or optimizer files changed.

## Checks Run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS; generated the three new Rd topics.
- `Rscript --vanilla -e 'devtools::test(filter = "screen")'`
  -> PASS: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 34 ]`.
- `Rscript --vanilla -e 'devtools::test()'`
  -> PASS: `[ FAIL 0 | WARN 10 | SKIP 745 | PASS 3479 ]`.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); rmarkdown::render("vignettes/articles/pre-fit-response-screening.Rmd", output_dir = tempfile("screen-article-"), quiet = FALSE)'`
  -> PASS.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS: `No problems found`.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", document = FALSE, quiet = FALSE, error_on = "never")'`
  -> `0 errors, 1 warning, 0 notes`; the warning is the known local Apple
  clang/R-header `-Wfixed-enum-extension` warning.
- `git diff --check`
  -> PASS.

Stale/prose scans recorded in `docs/dev-log/check-log.md` included exact
patterns for overclaiming, stale `gllvmTMB_wide()` wording, misspellings, and
screen registration. Matches were limited to existing `gllvmTMB_wide()`
soft-deprecation register/NEWS notes.

## Tests Of The Tests

The new test file covers boundary and malformed cases, not only happy paths:

- all-zero/all-one-like constants and rare binary indicators;
- invalid binomial support through the trait status path;
- duplicate and complement pairs;
- denominator-aware prevalence with `n = 20` versus `n = 100000`;
- strong pairwise association thresholds;
- `cbind(success, failure)` and `weights = n_trials`;
- long versus wide `traits(...)` parity;
- rank-deficient fixed-effect design;
- `d >= n_traits`;
- unsupported-family `NOT_CHECKED` output.

These tests would catch the main failure modes discussed in the plan: sparse
minority support, exact redundancy, complement coding, formula-design rank
problems, and overclaiming about unsupported families.

## Consistency Audit

Rose verdict: PASS with one expected limitation. The exported functions appear
in `NAMESPACE`, the pkgdown reference index, and the new article. `DIA-14`
backs the new user-facing claims. NEWS, roxygen, the article, and the design
note state the same scope boundary: binary/binomial v1 only; advisory pre-fit
screening; no automatic response selection, deletion, identifiability proof,
rank choice, separation solution, or convergence guarantee.

Pat/Darwin verdict: PASS for the first-reader path. The article uses a
systematic-map style example and explains that a `trait` may be a content item
or indicator.

Noether/Fisher verdict: PASS for v1 thresholds as evidence-informed
diagnostics. The article and design note distinguish pre-fit support screening
from post-fit 0.30 loading-salience/identification rules.

Grace verdict: PASS locally except for the known platform warning in
`devtools::check()`. `pkgdown::check_pkgdown()` passed and the article rendered
through `pkgload::load_all()`.

Shannon coordination: PASS/WARN. No open PRs were present before shared
dev-log edits. The branch is a focused diagnostic/docs PR and should be safe to
open as draft after commit/push.

## What Did Not Go Smoothly

`pkgdown::build_article("pre-fit-response-screening", ...)` initially used the
wrong slug, and direct article building then saw the installed package before
the new export existed. The successful render used `pkgload::load_all()` plus
`rmarkdown::render()`, and the full package check later rebuilt vignettes.

`devtools::document()` rewrote unrelated Rd link/format details because of the
local roxygen version. Those unrelated generated changes were restored so this
PR stays focused.

## Team Learning

Formula-aware is the important distinction for this API. A matrix-only screen
would miss the actual `gllvmTMB()` data path: wide `traits(...)`, long
`trait =`, missing response rows, weights/trials, fixed effects, unit grouping,
and requested latent rank. The first public message should stay simple:
inspect support and redundancy before fitting, then still run
`check_gllvmTMB()` after fitting.

## Known Limitations

- Only `module = "binomial"` is implemented.
- Pairwise duplicate/complement screening is Bernoulli-row only; multi-trial
  binomial pair checks are `NOT_CHECKED`.
- Non-binary modules are design-roadmap only: Gaussian, count, ordinal, and
  mixed-family screens remain planned.
- Optional comparator checks against `mirt::itemstats()` and
  `detectseparation` are not implemented.
- This screen is not a variable-selection or item-deletion method.

## Next Actions

- Commit, push, and open a draft PR.
- Let CI confirm the local results on GitHub runners.
- In a later PR, consider optional Suggests-only comparator checks and a
  broader simulation grid over sample size, prevalence, and pairwise
  dependence.
