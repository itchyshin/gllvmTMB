# After Task: Surface the Existing Runaway-Loading Diagnostic at Fit Time (#877)

**Branch**: `codex/pr877-integration-20260801` (pushed to
`claude/runaway-user-guidance-20260731`)
**Date**: 2026-08-01
**Roles (engaged)**: Ada, Grace, Rose, Curie, Pat, Shannon

## 1. Goal

Give default-grammar binomial latent-variable users an actionable signal when a
fit trips the package's existing runaway-loading diagnostic. This PR warns; it
does not claim to repair the estimator. It also preserves the staged AGHQ
campaign extensions handed over from the estimator lane.

## 2. Implemented

- `gllvmTMBcontrol(warn_runaway = TRUE)` is a real, documented control. A fit
  whose existing binomial prevalence/loading diagnostic returns `WARN` emits an
  actionable once-per-session warning.
- `warn_runaway = FALSE` suppresses only the fit-time warning. The diagnostic
  remains available through `gllvmTMB_diagnose()`.
- The warning reuses the diagnostic's existing message and action, avoiding a
  second scale-dependent rule or a second copy of the remedy wording.
- The test resets cli/rlang once-per-session warning state before expectations,
  so it behaves the same under `test_file()` and the one-session package check.
- The handed-over stage-2/stage-3 campaign scripts retain the
  `laplace_ridge_ms` arm and the extended task/seed ranges together.
- During integration with current `main`, the VA result-call attachment was
  restored. The warning runs after that attachment and returns the same fit.

## 3. Mathematical Contract

No likelihood, parameter transform, formula grammar, covariance structure,
family, or estimator changed. The fit-time condition is exactly the package's
pre-existing diagnostic predicate; the new behavior is notification only.
`aghq_ridge = 2` remains a penalised MAP fit and is not represented as a broad
accuracy fix. The campaign result remains a runaway-avoidance signal, not an
answer to the estimator question.

## 4. Files Touched

- `R/gllvmTMB.R`: fit-time warning, `warn_runaway` control, roxygen, and
  preservation of current-main VA call attachment.
- `man/gllvmTMBcontrol.Rd`: generated documentation for `warn_runaway`.
- `tests/testthat/test-runaway-warning.R`: default, suppression, diagnostic
  persistence, healthy-fit boundary, and once-per-session reset tests.
- `dev/aghq-evidence/27-drac-one-replicate.R`: handed-over campaign arm/task
  extension.
- `dev/aghq-evidence/27-drac-submit.sh`: handed-over campaign array extension.
- `docs/dev-log/2026-07-31-DRAFT-runaway-user-guidance.md`: explicitly draft
  maintainer-facing wording; it is not shipped public guidance.
- `docs/dev-log/handover/2026-07-31-codex-handover.md`: authoritative lane
  handover and claim boundary.
- `docs/dev-log/check-log.md`: verification receipt.
- `docs/dev-log/after-task/2026-08-01-runaway-fit-warning-877.md`: this report.

`CLAUDE.md` and `docs/dev-log/decisions.md` conflicted with current `main` during
integration. Both were restored exactly to `origin/main` and are absent from the
final net diff. No README, NEWS, ROADMAP, vignette, `_pkgdown.yml`, NAMESPACE,
formula-grammar document, likelihood document, or validation-debt row changed.

## 3a. Decisions and Rejected Alternatives

**Decision:** surface the existing diagnostic rather than inventing another
absolute threshold. **Rationale:** a second threshold would recreate the
scale-dependent-constant defect tracked by #857 and could drift from
`gllvmTMB_diagnose()`. **Rejected:** silently apply `aghq_ridge = 2`; the shipped
campaign shows that fixed penalty still has a large failure regime and changes
the estimand. **Confidence:** high for notification behavior; deliberately no
claim about estimator accuracy.

## 5. Checks Run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` — PASS; generated
  Rd includes `warn_runaway`.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE);
  testthat::test_file("tests/testthat/test-runaway-warning.R",
  reporter = "summary", stop_on_failure = TRUE)'` — PASS, 10 assertions.
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::load_all(quiet = TRUE);
  testthat::test_file("tests/testthat/test-va-routing-oracle.R",
  reporter = "summary", stop_on_failure = TRUE)'` — PASS, 31 assertions.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` — PASS, `No problems
  found.`
- `NOT_CRAN=true Rscript --vanilla -e 'devtools::test()'` — 8,324 passes,
  785 skips, 2 warnings, 2 failures. Neither failure touches this PR: the known
  spatial recovery fixture did not converge and the local vdiffr correlation
  ellipse differed. The two warnings are from an optional `gllvm` comparator
  receiving all-zero rows.
- Focused retry of `test-funcphylo-spatial-recovery.R` — FAIL at line 54 because
  `fit$fit_health$converged` remained false. This is recorded as a current-main
  residual, not called a passing or resolved test.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual",
  error_on = "warning")'` — FAIL after 11m35s: 1 error, 4 warnings, 4 notes.
  The test error is the same local vdiffr correlation-ellipse mismatch (8,042
  passes, 822 skips, 2 comparator warnings); the spatial recovery fixture passed
  in this run. Three namespace warnings and two code-analysis notes arise from
  the pre-existing `S3method(weights,gllvmTMB_va)` registration without
  `importFrom(stats, weights)`. The other warning is the sandboxed dependency
  index probe; notes include clock verification and `xcrun_db` detritus. These
  adjacent repairs are intentionally excluded from #877.

## 6. Tests of the Tests

The warning test is not a mock: it constructs a deterministic high-loading
Bernoulli cell, fits through the public `gllvmTMB()` entry point, and asserts the
user-visible warning. Its suppression test counts only matching runaway
warnings, then calls the internal diagnostic to prove detection survives. The
healthy cell guards the opposite boundary. Resetting
`gllvmTMB-loading-runaway` before each warning expectation specifically tests
the order-dependence that failed under one-session `R CMD check`.

## 8. Consistency Audit

- `rg -n 'warn_runaway|gllvmTMB_diagnose|runaway trait loading'
  R/gllvmTMB.R man/gllvmTMBcontrol.Rd tests/testthat/test-runaway-warning.R
  docs/dev-log/2026-07-31-DRAFT-runaway-user-guidance.md` — implementation,
  generated help, tests, and draft wording use the same control and diagnostic.
- `rg -n 'warn_runaway\\s*=|aghq_ridge\\s*=' R/gllvmTMB.R` — confirms both are
  explicit control arguments and stored in the returned control list.
- `rg -n 'runaway|AGHQ|aghq_ridge' README.md NEWS.md ROADMAP.md
  docs/dev-log/known-limitations.md docs/design/35-validation-debt-register.md`
  — existing public AGHQ/runaway wording remains untouched; no new broad claim
  was introduced.
- `rg -n '\\bS_B\\b|\\bS_W\\b|\\\\bf S' R/gllvmTMB.R
  man/gllvmTMBcontrol.Rd docs/dev-log/2026-07-31-DRAFT-runaway-user-guidance.md`
  — no legacy covariance notation in the changed user-facing surfaces.
- `rg -n '\\bphylo\\(|\\bgr\\(|\\bmeta\\(|block_V\\(|phylo_rr\\('
  docs/dev-log/2026-07-31-DRAFT-runaway-user-guidance.md` — no deprecated
  formula aliases.
- `rg -n 'meta_known_V|gllvmTMB_wide'
  docs/dev-log/2026-07-31-DRAFT-runaway-user-guidance.md` — no stale primary API.

Rose pre-publish verdict: **PASS with an explicit scope boundary**. The control
default, implementation, generated Rd, and tests agree. The only prose file is
named `DRAFT` and says the warning is not a repair. No method list, family list,
formula keyword, exported function, pkgdown navigation, or article changed.

## 8. Roadmap Tick

N/A. This PR surfaces an existing diagnostic and does not complete a ROADMAP
capability row.

## 7a. Issue Ledger

- #847 inspected; remains open and is the next scale-aware penalty lane. This PR
  does not close or implement it.
- #857 (merged PR) inspected through the handover/design rationale; the warning
  deliberately avoids adding another scale-dependent constant.
- #877 is the PR landed by this report.
- #881 is a foreign documentation/handover lane and was not modified or merged.

## 9. What Did Not Go Smoothly

The handed-over branch had drifted far behind `main`. Its two campaign conflicts
were resolved by retaining the PR-side stage-2/stage-3 extensions as a pair, but
an automatic merge also preserved stale copies of `CLAUDE.md` and the decisions
log and displaced the recently merged VA call attachment. Reviewing the net diff
against `origin/main`, rather than trusting a clean merge, caught all three.

The full suite also generated an untracked local vdiffr `.new.svg`; it is a check
artifact and is excluded. The strict local check exposed the pre-existing VA
`weights` namespace registration warning. Neither adjacent defect is folded into
this focused warning PR.

## 11. Team Learning

**Ada:** Integration review caught that mergeability and correctness were
different questions: the branch could merge while silently regressing a newer
VA behavior. The reusable check is the two-dot net diff against current main.

**Grace:** Focused checks are clean, while the broad local gate has honestly
recorded unrelated residuals. GitHub's three-OS checks remain the merge authority;
the PR is not called ready until those checks are green.

**Rose:** The warning reuses the existing diagnostic and keeps the negative
scientific headline visible. It does not promote the draft guidance or imply
that a fixed ridge solves the estimator problem.

**Curie:** The test exercises both sides of the diagnostic boundary and the
once-per-session behavior that differs between isolated `test_file()` and
package-check ordering.

**Pat:** The user sees what failed, why the fit is unusable, how to inspect it,
the penalised remedy's MAP cost, and how to silence only the notification.

**Shannon:** PR #881 and the original dirty checkout were treated as foreign
lanes. Work occurred in an isolated integration worktree and only the #877
branch is updated.

## 10. Known Residuals

- This is a binomial diagnostic warning, not a broad family-independent detector.
- `converged = TRUE` still cannot filter runaway fits; the campaign therefore
  measures the AGHQ package, not the estimator.
- The broad accuracy question remains unanswered. At `n = 400`,
  `sigma_lambda = 1`, the median paired difference is `+0.00014` and exactly half
  of replicates favor each arm.
- After #877 is green and merged, resume #847. Arc 0 must first prove the
  pure-single-trial-Bernoulli default-Psi/loadings-only objective equivalence and
  calibrate any scale-aware tau against unpenalised multi-start AGHQ, never plain
  Laplace.

## 12. Cross-Product Coverage

This PR covers only `gllvmTMB`'s existing binomial runaway diagnostic and its
fit-time notification. It **does NOT cover** `GLLVM.jl`, `gllvm`, `glmmTMB`,
another family, another covariance tier, penalty calibration, or estimator
accuracy. No cross-package behavioral equivalence is claimed. The next #847
evidence compares penalty calibration within `gllvmTMB` against the unpenalised
multi-start AGHQ yardstick.
