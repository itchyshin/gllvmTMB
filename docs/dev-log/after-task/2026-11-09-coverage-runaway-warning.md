# After Task: Coverage job, runaway-warning capture

**Branch**: `cursor/fix-coverage-runaway-warning-fbbb`
**Date**: `2026-11-09`
**Roles (engaged)**: Curie, Grace

## 1. Goal

The main coverage run
[42653382670](https://github.com/itchyshin/gllvmTMB/actions/runs/42653382670)
failed on shard 3/4. The other three shards passed. This change makes that
test assert the runaway warning it names, and leaves the coverage job
fail-closed when any test fails.

## 2. Implemented

No likelihood, formula, family, or control default changed.

`tests/testthat/test-runaway-warning.R` used an exiting
`tryCatch(warning = )` on a second, default-control fit. That handler
returns the first warning and stops the fit. On this cell
(`seed = 2003`, `lam = 3`, `n = 100`, `p = 6`, `q = 2`, binomial logit,
`latent(..., d = 2, unique = FALSE)`) the default control is
Laplace-optimistic and auto-refits with `aghq = 9` and the default
loading ridge `tau = 2` (`R/gllvmTMB.R` `.gllvmTMB_laplace_auto_refit`).

At `-O2` that refit converged (`aghq$converged = TRUE`) and emitted no
warning, so the three `expect_match()` calls were skipped. covr compiles
TMB at `-O0`. The same refit then stalls with
`stalled (no honest descent at cap 1 after backtracking)` and signals
`gllvmTMB_aghq_not_converged` (`R/fit-multi.R`). That text was what lines
63-65 compared with `loading_ridge`, `MAP|penalised`, and `warn_runaway`.

The first expectation in the same test, which turns the auto-refit off
with `laplace_warn_thresh = FALSE`, already passed in that covr run. The
runaway warning from that fit contains all three phrases. The test now
records every warning from that fit and applies the same three regexps to
the runaway message. It fails if that message is absent. It does not skip
on covr, and it does not change `tools/run-covr-coverage.R`.

## 3. Files Changed

- `tests/testthat/test-runaway-warning.R`
- `docs/dev-log/check-log.d/2026-11-09-coverage-runaway-warning.md`
- this after-task note

Not changed: `R/`, `src/`, `.github/workflows/test-coverage.yaml`,
`tools/run-covr-coverage.R`, `NEWS.md`, `README.md`, `ROADMAP.md`,
`docs/dev-log/check-log.md` (open PR #1065 already edits that file).

## 3a. Decisions and Rejected Alternatives

- **Decision:** move the three regexps onto the runaway warning from the
  fit that already disables Laplace auto-refit.
  **Rationale:** that is the warning the test name describes, and it is
  the warning shard 3 already observed under covr. The default-control
  refit is a different estimand (penalised AGHQ). When it converges it
  does not warn; when covr's `-O0` build stalls, its first warning is
  the stall, not the remedy text.
  **Rejected:** `stop_on_failure = FALSE`, `skip_on_covr()`, a `nocov`
  tag, a Codecov ignore, or a looser regexp. Also rejected: a stronger
  loading scale. The Laplace fit already runs away (`max_loading = 42`
  on this seed at `-O2`); a larger scale would not stop the default
  refit from warning first under `-O0`.
  **Confidence:** high for the capture bug. Local R 4.3.3, both the default
  `-O2` install and a `PKG_CXXFLAGS=-O0` reinstall:
  `FAIL 0 | WARN 1 | SKIP 0 | PASS 19` on this file. The link step still
  had `-flto=auto`, so the pull request's covr job is the real `-O0
  --coverage` check.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-09-coverage-runaway-warning.md`.

## 5. Tests of the Tests

The old second call did not fail at `-O2`, because no warning was
signalled and the `if (!is.null(w))` guard skipped the regexps. The same
call failed under covr because the stall warning was first. After the
edit the regexps are unconditional on the runaway message. A message
that lacks `loading_ridge`, `MAP` or `penalised`, or `warn_runaway`
fails. A stall message fails `expect_false(grepl("AGHQ did not converge"))`.

## 6. Consistency Audit

```
rg -n "stop_on_failure|nocov|covrignore|skip_on_covr" tests/testthat/test-runaway-warning.R .github/workflows/test-coverage.yaml tools/run-covr-coverage.R
```

No matches in the test. The workflow and runner still require `FAIL 0`
before writing `cobertura.xml`. Upload steps stay on `success()`.

## 7. Roadmap Tick

N/A. No roadmap row.

## 7a. GitHub Issue Ledger

No issue opened or commented. The red run is a test-capture failure, not
a new likelihood defect. Open PRs left untouched: #1283 (`codex/…`),
#1506 (draft Tweedie clamp), #1700, #1065, #981.

## 8. What Did Not Go Smoothly

The second call looked like a content check of the default fit. At `-O2`
it was skipped. Only the covr stall made the guard run, and then against
the wrong warning.

## 9. Team Learning

Curie: an exiting warning handler tests warning order, not warning
content. The content assertions have to name the condition they mean,
or a later warning from an `-O0` optimiser path replaces them.

Grace: the coverage producer from #1742 is doing what it should. Shard
3 failed closed and did not upload `cobertura.xml`. Do not put
`stop_on_failure = FALSE` back, and do not upload on `always()`.

## 10. Known Limitations And Next Actions

Package line coverage for this head is the pull request's
`test-coverage` artifacts (`coverage-percent.txt` per shard). Codecov
merges the four shards only after a green main upload. This pull request
does not upload.

The default-control AGHQ stall under `-O0` is still real. It is a
numerical path of the auto-refit, not a missed runaway warning on the
Laplace fit. No separate source change is proposed.
