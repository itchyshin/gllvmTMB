# After Task: Confint Parm Fail Loud

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Fisher / Hopper / Curie / Rose / Shannon`

## 1. Goal

Fix the robustness bug where mistyped `confint(..., parm = ...)` values could
silently produce NA or empty interval rows instead of an informative error.
This addresses the failure mode described in GitHub issue #660 and applies the
same guard to the TMB and Julia-bridge `confint()` methods.

## 2. Implemented

- Added `.confint_resolve_parm()` to validate numeric and character `parm`
  selectors against the available term labels.
- Routed the fixed-effect TMB `confint.gllvmTMB_multi()` path through the
  resolver.
- Routed `confint.gllvmTMB_julia()` stored CI payload selection through the
  same resolver.
- Tightened direct-target helpers so derived-only `profile_targets()` labels
  such as bare `communality` error with an extractor pointer instead of warning
  and returning an empty matrix.
- Added fixed-effect, derived-target, profile-target, and Julia-bridge
  regressions.

## 3. Files Changed

- `R/z-confint-gllvmTMB.R`
- `R/julia-bridge.R`
- `tests/testthat/test-confint-bootstrap.R`
- `tests/testthat/test-confint-derived.R`
- `tests/testthat/test-julia-bridge.R`
- `tests/testthat/test-profile-targets.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-confint-parm-fail-loud.md`

## 3a. Decisions and Rejected Alternatives

Decision: use one resolver for TMB and Julia-bridge CI payloads.

Rejected alternative: patch only `confint.gllvmTMB_julia()` where #660 was
filed.

Reason rejected: the same `match()`-to-NA pattern existed in the live TMB
fixed-effect path, so a single shared guard is safer.

Decision: derived-only profile targets now error.

Reason: warning plus empty matrix is another form of non-evidence. The message
points users to the matching `extract_*()` route instead.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); invisible(parse("R/julia-bridge.R")); invisible(parse("tests/testthat/test-confint-bootstrap.R")); invisible(parse("tests/testthat/test-confint-derived.R")); invisible(parse("tests/testthat/test-julia-bridge.R")); invisible(parse("tests/testthat/test-profile-targets.R")); cat("parse-ok\n")'
```

Outcome: passed.

```sh
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); cat("load-ok\n")'
```

Outcome: passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-bootstrap.R", reporter = "summary")'
```

Outcome: passed; `confint-bootstrap` completed with no failures.

```sh
NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
```

Outcome: passed for pure bridge tests; live GLLVM.jl tests skipped because no
`GLLVM_JL_PATH` was configured.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-profile-targets.R", reporter = "summary")'
```

Outcome: passed; `profile-targets: ...............................`.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-confint-derived.R", reporter = "summary")'
```

First run outcome: failed after the new bare-`communality` test exposed that
the profile-target route warned and returned an empty matrix.

Fix: derived-only profile targets now error for profile and Wald routes.

Second run outcome: passed; `confint-derived` completed with no failures.

```sh
rg -n "payload\\[idx|match\\(parm, payload\\$term\\)|match\\(parm, td\\$term\\)|all-NA row|returns empty|emits a warning and returns empty" R/z-confint-gllvmTMB.R R/julia-bridge.R tests/testthat/test-confint-bootstrap.R tests/testthat/test-confint-derived.R tests/testthat/test-julia-bridge.R tests/testthat/test-profile-targets.R
```

Outcome: no stale implementation or test-comment hits.

```sh
git diff --check
```

Outcome: passed.

## 5. Tests of the Tests

The regressions cover:

- unmatched fixed-effect name;
- out-of-range fixed-effect index;
- derived-only target label;
- unmatched Julia CI payload name;
- out-of-range Julia CI payload index.

## 6. Consistency Audit

The TMB and Julia-bridge CI paths now share the same selector semantics. A bad
selector stops with available terms instead of manufacturing NA/empty interval
evidence.

## 7. Roadmap Tick

Inference safety gate: one robustness blocker closed locally.

## 7a. GitHub Issue Ledger

Local code addresses issue #660's failure mode. The issue was not closed or
commented because this branch has not been pushed.

## 8. What Did Not Go Smoothly

The first derived dispatcher rerun revealed a sibling empty-matrix behavior for
derived profile-target labels. That was tightened in the same slice.

## 9. Team Learning

When `parm` dispatch has multiple inventories, check both unmatched values and
known-but-not-supported targets. Both can otherwise masquerade as valid
interval output.

## 10. Known Limitations And Next Actions

- Live GLLVM.jl bridge tests were not run because `GLLVM_JL_PATH` is not
  configured in this local session.
- No public claim or validation-debt status changed.
