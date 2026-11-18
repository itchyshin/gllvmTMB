# After Task: Runnable help examples, part D (fit, diagnose, loadings, confint, profile)

**Branch**: `claude/b16-L9-runnable-examples-1346d` (PR #1567; red proof #1566)
**Date**: `2026-10-16`
**Roles (engaged)**: Pat (examples a first-time reader can follow), Curie (forcing test, fault behaviour on base), Grace (R CMD check, Suggests guards, timings), Fisher (identifiability and fit health of every example model), Rose (no internal codes; comments claim only what the output shows)

## 1. Goal

Issue #1346 found that 80 of 120 help pages wrapped their whole `\examples`
section in `\dontrun{}`, so `example()` ran nothing and `R CMD check` never
executed them. This lane (part D of 4) covers the 19 fit, diagnose, loadings,
confint and profile pages, including `?gllvmTMB` and `?check_gllvmTMB`.

## 2. Implemented

- The 19 pages now carry small, self-contained examples on simulated data.
  Each runs in a few seconds with no warning. No `\dontrun{}` and no
  `\donttest{}` remain on these pages: none needs Julia or an external
  resource, and none exceeds the 5 s budget.
- Every ordinary `latent()` states `unique =` explicitly. A bare `latent()`
  fires the once-per-session "Psi is now the default" warning, which would
  otherwise appear in `R CMD check` output for whichever page ran first.
- Every `gllvmTMB()` call names `trait =` and `unit =`. Suggests packages
  (`tidyr` for `traits()`, `ggplot2` for plots) sit behind
  `requireNamespace()`.
- Every example model is identified, and its fit converges with a
  positive-definite Hessian across alternative seeds. `check_gllvmTMB()` has
  no FAIL on any of them; the only WARN is the expected rotation advisory for
  unconstrained `d = 2` fits, which `?check_gllvmTMB` explains.
- `?loading_ci` stays binomial-probit (presence/absence of eight species), so
  the page's own "Interval calibration" prose ("The worked example below is
  binomial-probit") remains true.
- New forcing test `tests/testthat/test-examples-run-1346d.R`.

What the old examples got wrong, beyond being inert: undefined objects
(`dat`, `df`, `sim`, `fit`, `my_data`, `species_names`); unidentified models
(`d = 2` plus Psi on four traits: 11 parameters for 10 covariances); a
soft-deprecated `unique()` keyword and a global `options()` side effect
(`?slope_sd_ci`); a `confint(fit, parm = "Sigma_unit")` labelled "profile"
that on a `latent()` fit is a 500-refit bootstrap (`?confint.gllvmTMB_multi`);
pure-noise data with no seed (`?ridge_path`); and a first call that errors at
the current default `level` (`?flag_unreliable_loadings`).

## 3. Files Changed

Roxygen `@examples` lines only (a script confirmed that every changed line is
a `#'` line inside an `@examples` block, in both the old and new versions):

- `R/gllvmTMB.R`, `R/diagnose.R`, `R/check-consistency.R`,
  `R/rotate-loadings.R`, `R/ordination-uncertainty.R`, `R/loading-ci.R`,
  `R/loading-profile.R`, `R/plot-loadings-confidence-eye.R`,
  `R/suggest-lambda-constraint.R`, `R/ridge-path.R`,
  `R/z-confint-gllvmTMB.R`, `R/confint-inspect.R`, `R/profile-targets.R`,
  `R/slope-sd-ci.R`

Regenerated with roxygen2 8.0.0 (a script confirmed each diff lies only
inside `\examples{}`): the 19 `man/*.Rd` pages listed in section 1 of the PR.

New: `tests/testthat/test-examples-run-1346d.R`, this report.

Not touched: `NAMESPACE` (the `stats::sigma` drift that `devtools::document()`
produces predates this lane, #1558, and was reverted), `NEWS.md`, `src/`,
and the examples in `R/output-methods.R`, `R/extract-omega.R`,
`R/bootstrap-sigma.R`, `R/julia-bridge.R`.

## 3a. Decisions and Rejected Alternatives

- **Explicit `unique =` on every ordinary `latent()`.** Rationale: the
  fire-on-use Psi notice is a warning. Rejected: setting
  `gllvmTMB.quiet_grammar_notes` in examples (a global side effect that also
  hides real deprecations).
- **The forcing test runs examples with grammar notes ON** and rlang's
  once-per-session warnings in "verbose" mode, so deprecated syntax fails
  the test. It restores the package's own once-per-session tracker
  afterwards, and rlang's verbose mode records nothing, so later tests in
  the shard still see the first firing they assert. Rejected: the quieter
  harness (notes off), which would pass a page written in deprecated syntax.
- **A `\dontrun{}` block is accepted only with a comment naming Julia or an
  external resource.** This encodes the lane rule rather than banning
  `\dontrun` outright, so a later Julia example on `?gllvmTMB` stays possible.
- **`?confint.gllvmTMB_multi` drops the bootstrap.** `bootstrap_Sigma()` warns
  for any `n_boot < 999`, so no clean bootstrap fits a help-page budget; the
  example says so in a comment and shows profile intervals on an `indep()`
  fit, where they are computed directly.
- **`?loading_profile` and `?suggest_lambda_constraints` avoid paths that
  currently warn** (`loading_ci(method = "profile")`, `profile_retention`);
  those defects are filed (section 7a). They are mentioned in comments, not run.
- **`?gllvmTMB_check_consistency` runs, but the function cannot currently
  return a verdict** (see 7a). The example's comments describe the possible
  verdicts neutrally and claim nothing about the result.

## 4. Checks Run

- Forcing test on base (`aec24e16`): 39 blocks, 38 failing (19 static + 19
  dynamic), 76 failed expectations, 0 errors. CI on red proof #1566 and on
  #1567's test-only head: `FAIL 76`, all in this file.
- Forcing test on this branch: 39 blocks, 0 failures, 135 expectations, 0 skips.
- `devtools::document()` with roxygen2 8.0.0 on base reproduces `man/` byte
  for byte; on the branch it rewrites exactly the 19 pages.
- `R CMD check --as-cran --run-donttest --timings --no-manual --ignore-vignettes`
  (R 4.4.3): `checking examples ... [61s/61s] OK`, `Rd line widths ... OK`.
  The 19 pages take 0.2-2.4 s each (about 22 s together; table in the PR body)
  and print no warning. The three WARNINGs predate this branch or come from
  the environment (no `en_US.UTF-8` locale; `tools::sha256sum` is missing in
  R 4.4 and `TMB:::EvalADFunObject` is existing code; a duplicated `\argument`
  in `gllvmTMB_julia-methods.Rd`).
- Tests under `R CMD check`: `[ FAIL 15 | WARN 60 | SKIP 1248 | PASS 26380 ]`.
  Full `devtools::test()`: `[ FAIL 37 | WARN 170 | SKIP 890 | PASS 29451 ]`.
  Every failing file (16) was re-run on base `aec24e16` with the same harness
  and the same compiled library and gave identical per-file counts: EVA
  template, MSPL SHA-256 (R 4.4), vdiffr snapshots, the PROJ database,
  pkgdown/README source scans (#1563 class) and one VA tolerance. None
  involves this branch's files.
- Each example was also run through a harness matching the forcing test with
  the global seed and the example's own `set.seed()` changed to several other
  values: no warning or error on any.

## 5. Tests of the Tests

- Failure before the fix: shown on base, locally and in CI (section 4).
- The static check was validated on two pages that already run
  (`?gllvmTMBcontrol`, `?miss_control`): both are recognised as having code.
- The dynamic check reads Rd from `man/` under `devtools::test()` and from the
  installed Rd database under `R CMD check`; a page guarded by
  `requireNamespace()` is skipped, not passed, when that package is missing.

## 6. Consistency Audit

- `rg -n '\\dontrun|\\donttest' man/{19 pages}.Rd`: none.
- `git diff -U0 -- R | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE "^[+-]#'"`: empty.

## 7. Roadmap Tick

N/A (documentation hygiene; no capability row changes).

## 7a. GitHub Issue Ledger

- #1346 (part D of 4): refs only; parts A (#1561), B (#1553) and C (#1565)
  are other lanes.
- Filed while writing the examples (each reproduced by the drafting agent
  and again, independently, before filing; line numbers are for `main`):
  - #1582 `gllvmTMB_check_consistency()` can never reach a verdict: the TMB
    template has no `SIMULATE` block.
  - #1583 `flag_unreliable_loadings()` / `plot_loadings_confidence_eye()`
    error at their default `level`.
  - #1584 `loading_profile()` refits drop `unit_obs`, `control` and `REML`;
    a row-names warning per entry; alias notices; documented `"B"` rejected.
  - #1585 a loading diagonal pinned at 0 leaves its axis at zero with
    `convergence = 0`; `confirmatory_lambda()` / `suggest_lambda_constraints()`
    produce such pins; `+1` anchors restrict the model.
  - #1586 `gllvmTMB_diagnose()` correlations omit the link residual on
    non-Gaussian fits; `d=B` labels; truncated pair list.
  - #1587 `suggest_lambda_constraint()` `profile_retention` warns once per
    refit; formula-path `unit_obs` hard-coded to `site_species`.
  - #1588 `confint()` routes: `b_fix[k]` labels rejected, `rho` ignores
    `link_residual`, silent all-`NA` Wald `Sigma_unit`, and four smaller items.
  - #1589 `slope_sd_ci()` print, `scale = "variance"` and refusal messages.
  - #1590 help-text mismatches on `?gllvmTMB`, `?rotate_loadings`,
    `?compare_loadings`, `?ridge_path`.
  - #1591 the binomial Psi gate ignores replicate 0/1 rows per cell
    (maintainer decision: it changes which parameters are estimated).
  - Comment on #1576: `confint()`'s `nsim = 500` default has the same
    bootstrap warning.

## 8. What Did Not Go Smoothly

- CRAN is unreachable from the session, so R 4.4.3 and roxygen2 8.0.0 came
  from conda-forge. `sf` there cannot find its PROJ database unless
  `PROJ_DATA` is set, which stopped the first `R CMD check` example run at
  `?add_utm_columns` (not a lane page).
- Several functions documented on these pages have defects that a runnable
  example exposes immediately (a default argument that errors, warnings on
  every call, a check that can never return a verdict). The examples avoid
  those paths, so the defects are filed rather than hidden.

## 9. Team Learning

- **Pat:** the old examples read as plausible code but could not have run;
  running them is the only review that catches undefined objects.
- **Fisher:** three old designs were unidentified or sat on a boundary. A
  seed sweep is cheap and catches knife-edge designs a single seed hides.
- **Curie:** a forcing test that silences the package's own notes would have
  passed examples written in deprecated syntax.

## 10. Known Limitations And Next Actions

- Parts A–C of #1346 are other lanes; `?getLV`, `?getLoadings`,
  `?extract_Omega`, `?bootstrap_Sigma` and the Julia pages remain for a later
  wave.
- The filed defects (PR body) should be fixed before these examples can show
  `loading_ci(method = "profile")`, `profile_retention`, or a real
  consistency verdict.
