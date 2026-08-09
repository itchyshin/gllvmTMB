# Codex recovery checkpoint — CRAN 0.7 source-truth programme

Date: 2026-08-08 08:51:50 MDT

## Current lane

- Worktree: `/private/tmp/gllvmtmb-cran-0.7-20260807`
- Branch: `cursor/cran-0.7-20260807`
- Upstream: `origin/cursor/cran-0.7-20260807`
- No commit, push, version bump, candidate freeze, Totoro campaign, or upload has occurred in this task.

## Working-tree status

```text
## cursor/cran-0.7-20260807...origin/cursor/cran-0.7-20260807
 M CONTRIBUTING.md
 M DESCRIPTION
 M NEWS.md
 M R/aghq-auto-ridge.R
 M R/brms-sugar.R
 M R/coverage-study.R
 M R/cv-internal.R
 M R/cv-metrics.R
 M R/gllvmTMB.R
 M R/zzz.R
 M README.md
 M _pkgdown.yml
 M cran-comments.md
 M docs/design/00-vision.md
 M docs/design/04-sister-package-scope.md
 M docs/design/14-known-relatedness-keywords.md
 M docs/design/35-validation-debt-register.md
 M docs/dev-log/known-limitations.md
 M inst/COPYRIGHTS
 M man/gllvmTMB-package.Rd
 M man/gllvmTMB.Rd
 M man/gllvmTMBcontrol.Rd
 M tests/testthat/test-aghq-auto-ridge.R
 M tests/testthat/test-loading-ci-bootstrap.R
 M tests/testthat/test-spatial-dep-slope-gaussian.R
 M tests/testthat/test-spde-slope-base-engine.R
 M vignettes/articles/profile-likelihood-ci.Rmd
 M vignettes/gllvmTMB.Rmd
?? docs/dev-log/plan-actual/2026-08-08-gllvmtmb-cran-0.7.md
?? docs/dev-log/release/
?? docs/dev-log/simulation-artifacts/
?? inst/sim/
?? tests/testthat/test-release-core-sentinels.R
?? vignettes/articles/current-limits.Rmd
```

Tracked diff stat: 28 files changed, 247 insertions, 184 deletions. The untracked release, campaign, sentinel, and limits-page files are additional to that stat.

`git diff --check` passed at 2026-08-08 08:51 MDT.

## Work completed in this task

- Added the canonical 0.7 release claim matrix and reconciled public claims around ordinary Laplace point estimation, interval exceptions, VA, AGHQ, NB2, and the covariance grid.
- Added `vignettes/articles/current-limits.Rmd` as the second Getting Started page and linked it from the README, package landing help, introductory vignette, and pkgdown sidebar. `ROADMAP.md` remains internal.
- Diagnosed and repaired the seven historical heavy-suite failures without changing the public API, likelihood, validator, or TMB implementation. The six SPDE failures were brittle `fmesher` fixture cutoffs; the bootstrap comparator retained its 0.30 threshold and increased draws from 40 to 60.
- Added frozen v2 core-recovery, silent-failure, and robustness campaign specifications plus fail-closed local runners, attempt ledgers, summaries, detector/truth separation, Binomial(10) trial checks, immutable registry hashes, and tests-of-tests.
- Updated the always-on release sentinels to the v2 schema.
- Regenerated affected Rd files and removed new internal-link documentation warnings.

## Commands already run

1. Focused historical SPDE heavy tests: PASS, exit 0.
2. Focused loading-bootstrap heavy test: PASS, exit 0. Expected refit-rejection warnings only; 46/60 comparator survivors and maximum discrepancy 0.2758533 under the unchanged 0.30 threshold.
3. Corrected release sentinel test:
   `Rscript --vanilla -e 'devtools::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-release-core-sentinels.R", reporter = "summary", stop_on_failure = TRUE)'`
   PASS, exit 0; 51 expectations, 0 failures/errors/skips.
4. Campaign pure-logic tests: parse, self-test, exact campaign mapping, registry/path/hash mismatch rejection, copied-registry rejection, old-ID rejection, denominator arithmetic, zero-SD fail-closed behavior, and all SHA256 manifests: PASS.
5. Local corrected binomial probe: PASS; seed 271900001 was usable, detector false, catastrophic false, all health flags true, `n_trials` 10:10, and `diag_B_skip` 0 for all traits.
6. Stable ordinary suite after all edits:
   `Rscript --vanilla -e 'devtools::test(reporter = "fail", stop_on_failure = TRUE)'`
   PASS, exit 0.
7. `devtools::document(quiet = TRUE)`: completed; only the pre-existing intentional dynamic AIC/BIC S3-registration warnings remained.
8. `pkgdown::check_pkgdown()`: PASS after rebuilding the new limits page.
9. `git diff --check`: PASS.

## Live command deliberately left running

The exact all-heavy local suite is still running and has not emitted a failure report:

```sh
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(reporter = "fail", stop_on_failure = TRUE)'
```

- Unified execution session ID: `34811`
- Resume with an empty `write_stdin` poll against session `34811` and wait for its authoritative exit code.
- Last visible progress included the pilot-audit mini-run, pilot chunk runner, and a 17.3-second binomial-probit recovery fit. Subsequent polling remained active with no failure output.
- Do not infer PASS from silence and do not start a duplicate heavy suite while this session remains live.

## Commands still required before G1 can pass

1. Obtain and record the exact heavy-suite exit status. Diagnose any failure rather than weakening thresholds.
2. Run the frozen stale-claim scan and adjudicate every match.
3. Re-run `devtools::document(quiet = TRUE)` and `pkgdown::check_pkgdown()` after any repair.
4. Build the complete pkgdown site with `pkgdown::build_site(lazy = FALSE, new_process = FALSE)` and inspect the rendered reader path.
5. Obtain a fresh Rose/Pat source-truth and four-scenario reader audit.
6. Update `docs/dev-log/check-log.md`, the plan-versus-actual record, and create the required 11-section after-task report.
7. Run final `git status --short`, `git diff --check`, and scoped inventory checks before deciding G1 PASS/HOLD.

## Next safest action

Start a fresh task in this exact worktree, read this checkpoint, poll session `34811` to completion, and finish the remaining G1 source-truth gates. Only after a documented G1 PASS should the local production-shaped smoke and Totoro 20-attempt pilot begin.

## Blocking question

None. A failing or nonterminating heavy suite is evidence to adjudicate, not a reason to broaden scope or relax a gate.
