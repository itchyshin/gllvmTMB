# Open Issue Local Reconciliation

**Branch**: `codex/r-bridge-grouped-dispersion`
**Head**: `0b95b1a6`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Fisher / Curie / Rose / Shannon`

## 1. Goal

Stop the completion arc from chasing stale GitHub issue state by reconciling a
sample of remote-open issues against the current local branch.

## 2. Implemented

- Added a durable audit at
  `docs/dev-log/audits/2026-07-05-open-issue-local-reconciliation.md`.
- Recorded that several remote-open issues are fixed locally with direct code,
  test, validation-register, check-log, and after-task evidence.
- Preserved the claim boundary: local fix evidence is not the same thing as
  closing GitHub issues, pushing a branch, opening a PR, or proving interval
  calibration.

## 3. Files Changed

- `docs/dev-log/audits/2026-07-05-open-issue-local-reconciliation.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-open-issue-local-reconciliation.md`

## 3a. Decisions And Rejected Alternatives

Decision: write a reconciliation audit instead of starting another code repair.

Rationale: every issue inspected in this continuation was already fixed
locally. More code hunting from the raw GitHub-open list would risk duplicating
repairs and widening an already large branch.

Rejected alternative: close or comment on GitHub issues immediately. This branch
has not been pushed or packaged as a PR in this slice, so remote issue actions
would outpace the available review surface.

## 4. Checks Run

```sh
git status --short --branch
git rev-parse --short HEAD
gh issue list --repo itchyshin/gllvmTMB --state open --limit 80 --json number,title,labels,updatedAt --jq '.[] | "#\(.number) \(.title) [\([.labels[].name] | join(","))]"'
gh pr list --repo itchyshin/gllvmTMB --state open --limit 30 --json number,title,headRefName,isDraft,updatedAt --jq '.[] | "#\(.number) \(.headRefName) draft=\(.isDraft) \(.title)"'
git log --all --oneline --since='6 hours ago' --decorate
gh issue view 606 --repo itchyshin/gllvmTMB --json number,title,body,comments
gh issue view 702 --repo itchyshin/gllvmTMB --json number,title,body,comments
gh issue view 696 --repo itchyshin/gllvmTMB --json number,title,body,comments
gh issue view 684 --repo itchyshin/gllvmTMB --json number,title,body
gh issue view 685 --repo itchyshin/gllvmTMB --json number,title,body
gh issue view 686 --repo itchyshin/gllvmTMB --json number,title,body
gh issue view 683 --repo itchyshin/gllvmTMB --json number,title,body
gh issue view 642 --repo itchyshin/gllvmTMB --json number,title,body
gh issue view 668 --repo itchyshin/gllvmTMB --json number,title,body
rg -n "#620|#621|Sigma Wald|residual/Psi-only|latent.*Sigma.*Wald|confint_sigma_wald|total-Sigma" R/z-confint-gllvmTMB.R tests/testthat docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task
rg -n "#606|Profile-to-bootstrap|nsim.*seed|bootstrap fallback|Falling back to.*bootstrap|user-supplied nsim|confint_sigma_profile" docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task tests/testthat R/z-confint-gllvmTMB.R
rg -n "#642|#668|duplicate.*trait.*unit|duplicate.*unit.*trait|silently collapsed|response pivot|cli_abort.*hint|named.*\"i\"|hint bullet|long rows|duplicated\\(" R tests/testthat docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/after-task
git diff --check
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-sigma-profile-bootstrap-controls.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-route-matrix.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-confint-lambda.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-extractors-extra.R", reporter = "summary")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-sigma-profile-bootstrap-controls.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
```

Results:

- Branch clean at `0b95b1a6`, ahead of origin by 192 commits at audit start.
- No open PR rows returned.
- The inspected issues were locally fixed already; see the audit table.
- `git diff --check`: passed.
- `test-sigma-profile-bootstrap-controls.R`: default run skipped the heavy row
  as designed; heavy run passed 4 checks.
- `test-profile-route-matrix.R`: passed.
- `test-confint-lambda.R`: non-heavy checks passed; heavy rows skipped as
  designed.
- `test-extractors-extra.R`: passed, with the expected residual-floor
  informational message.
- `test-julia-bridge.R`: default R-side checks passed; 13 live-GLLVM rows
  skipped because `GLLVM_JL_PATH` was not configured.

## 5. Tests Of The Tests

The first focused regression pack was run immediately after the audit note. It
does not replace a full package check, but it verifies the highest-value local
issue repairs and the bridge guard surface in default mode.

## 6. Consistency Audit

The audit reconciles remote-open issue state against local evidence and does
not update capability claims. It deliberately separates:

- fixed locally versus closed remotely;
- route/test evidence versus coverage calibration;
- R-first gllvmTMB completion versus deferred Julia parity.

## 7. Roadmap Tick

No validation-debt row changed. The rows inspected already carried local fix
evidence or explicit partial boundaries.

## 7a. GitHub Issue Ledger

No GitHub issues were closed or commented. The audit identifies several
candidate issue comments/closures for a later PR/package review step.

## 8. What Did Not Go Smoothly

The raw open issue list is now misleading for this branch because it lags behind
local fixes. Continuing to pick tasks directly from GitHub issue state would
waste time.

## 9. Team Learning

Ada: the next best work is review packaging and focused validation, not broad
new capability.

Fisher: interval-calibration gaps remain real even when profile/bootstrap route
bugs are fixed.

Curie: local regression files exist for many issue repairs; run them as a pack
before any public claim update.

Rose: every "fixed locally" phrase must stay paired with "GitHub still open"
until remote state changes.

Shannon: keep future staging explicit by filename; this branch is too large for
casual add-all or more opportunistic feature work.

## 10. Known Limitations And Next Actions

- This audit is not a full issue closure pass.
- The next validation pack should run focused tests for the reconciled issues.
- After the focused pack is green, move to documentation/pkgdown/check gates or
  prepare a review package.
- Do not start Totoro/DRAC compute until the review package has a frozen
  denominator manifest.
