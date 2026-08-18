# After Task: `slope_sd_ci()` -- Slice 1 (diagonal route only)

**Branch**: `claude/slope-sd-ci-20260818`
**Date**: `2026-08-18`
**Roles (engaged)**: Curie (implementation), Fable (design,
`dev/fable-extractor-recommendation.md`)

## 1. Goal

Build the new export `slope_sd_ci(fit, level = 0.95, scale = c("sd",
"variance"))` -- a per-trait Wald confidence interval on augmented
random-slope standard deviations -- for exactly the Slice 1 scope Curie
approved: the ordinary augmented diagonal route (`theta_diag_B_slope`),
sibling of `loading_ci()`. The phylogenetic Cholesky route
(`theta_dep_chol`) and the loadings-only route (`theta_rr_B_slope` alone)
must refuse loudly rather than approximate, because both need a
multivariate delta method against a TMB packing convention that a first
pass already got wrong once this session
(`dev/slope-interval-feasibility-RESULTS.md`).

## 2. Implemented

- `R/slope-sd-ci.R`: `slope_sd_ci()` (exported) and
  `print.gllvmTMB_slope_ci()` (exported S3 method).
  - Reads `theta_diag_B_slope` from `fit$opt$par` / `fit$sd_report$cov.fixed`
    (the established house pattern, e.g. `R/profile-derived.R:1317-1318`,
    `R/confint-inspect.R:275`), filters to the SLOPE-coordinate entries
    (the even positions in the trait-major `(intercept, slope)` interleaving
    -- verified against `R/fit-multi.R` ~4116-4121's `base = 2 * trait_id`
    and `R/extract-sigma.R`'s `aug_names` convention
    `intercept.<trait>, slope.<x>.<trait>`).
  - `sd_hat = exp(theta)`, `se(sd_hat) = sd_hat * se(theta)` (delta method);
    bounds `exp(theta +/- z*se(theta))` on the log scale, back-transformed;
    `scale = "variance"` squares both sides of the same computation.
  - **Kill-switch guard** (built and tested first, per the brief): per-row
    `status` in `{"ok", "no_pd_hessian", "se_nonfinite", "boundary"}`.
    `lower`/`upper` are `NA` for any non-`"ok"` row; the point estimate
    (`estimate`, `theta`) is always returned. `cli::cli_warn()` fires once
    per triggered guard class per call.
  - **Deferred-route refusal**: `fit$use$phylo_dep_slope` TRUE aborts
    (`theta_dep_chol`, class `gllvmTMB_slope_sd_ci_unsupported_route`);
    `fit$use$diag_B_slope` FALSE + `fit$use$rr_B_slope` TRUE aborts
    (loadings-only, same class); `fit$use$diag_B_slope` FALSE + no slope
    term at all aborts with a plain "nothing to summarise" message.
  - Returned object: `data.frame` of class `gllvmTMB_slope_ci`, columns
    `trait`, `term`, `estimate`, `lower`, `upper`, `theta`, `se_theta`,
    `method` (`"wald_log_scale"`), `interval_status`
    (`"wald_uncalibrated"`, every row), `status`, `scale`; attributes
    `calibrated = FALSE` (hard-coded), `level`, `rr_B_slope_present`.
  - Print method leads with the fence line and, when the fit also carries
    a shared loadings block, an explicit caveat that `estimate` is the
    unique (Psi) component only.
- `tests/testthat/test-slope-sd-ci.R`: see Section 5.
- `docs/design/35-validation-debt-register.md`: register rows CI-14
  (`partial`, diagonal route) and CI-15 (`blocked`, deferred routes).
- `docs/dev-log/check-log.md`: dated entry for this lane.

## 3. Files Changed

- `R/slope-sd-ci.R` (new)
- `tests/testthat/test-slope-sd-ci.R` (new)
- `NAMESPACE` (regenerated: `export(slope_sd_ci)`,
  `S3method(print, gllvmTMB_slope_ci)`)
- `man/slope_sd_ci.Rd` (regenerated)
- `docs/design/35-validation-debt-register.md` (CI-14, CI-15 rows)
- `docs/dev-log/check-log.md` (dated entry)
- `docs/dev-log/after-task/2026-08-18-slope-sd-ci-slice1.md` (this file)

No `src/`, `DESCRIPTION`, `NEWS.md`, or vignette/article changes, per the
brief's constraints (D-113: do not bump version/NEWS until the programme
is authorised; slice-2 ADREPORT work stays out of `src/`).

## 3a. Decisions and Rejected Alternatives

- **Decision:** compute the interval whenever `diag_B_slope` is TRUE,
  regardless of whether `rr_B_slope` is also TRUE, rather than refusing
  per the design doc's literal "diag_B_slope AND NOT rr_B_slope" scope
  bullet.
  **Rationale:** the design doc's own cited verification numbers
  (`theta_hat = -1.993085`, `true 0.2`) come from the Route B fixture in
  `dev/slope-interval-feasibility-RESULTS.md`, which has BOTH flags TRUE
  (the default `latent()` combination folds in the diagonal Psi companion
  by default). Refusing that exact case would contradict the brief's own
  "Verified this session" citation. `theta_diag_B_slope`'s parameterisation
  (`sd = exp(theta)`, `src/gllvmTMB.cpp:1606`) is unaffected by whether
  `theta_rr_B_slope` also exists -- it is still a genuine univariate log-SD
  of the unique/idiosyncratic component. What changes is the *meaning* of
  the returned number when a shared loadings block is also present: it is
  the Psi-only component of slope variance, not the total marginal
  `Var(Lambda_B_slope z + psi)`.
  **Rejected alternative:** refuse whenever `rr_B_slope` is TRUE (the
  design doc's literal text). Rejected because it would refuse the
  demonstrated, verified, in-scope case, and because refusing a
  well-defined, honestly-labelled sub-quantity is a different failure mode
  than the one Guard G2 was written to prevent (silently returning the
  wrong number for a claim the fit cannot support).
  **Mitigation:** the print method and roxygen both surface the caveat
  explicitly whenever `rr_B_slope` is also TRUE, and register row CI-14
  documents the resolution. **Confidence:** medium-high on the mechanics
  (`theta_diag_B_slope` is unambiguously a per-coordinate univariate log-SD
  by construction); lower on whether this is the precise scope Curie or
  Fable intended -- flagged for review rather than merged silently.
- **Decision:** filter `theta_diag_B_slope` to the slope-coordinate
  entries only (one row per trait), not all `2 * n_traits` entries
  (intercept + slope).
  **Rationale:** the design doc's "Shape" section states the return is
  "one row per slope SD (trait x slope term)"; the intercept-augmented
  entries are a different, already-nameable quantity
  (`extract_Sigma(level = "unit_slope")`'s `intercept.<trait>` rows) and
  are out of scope for a function literally named `slope_sd_ci()`.
  **Rejected alternative:** return all `2 * n_traits` rows with a
  `term \in {"intercept", slope_col}` column. Rejected as scope creep
  beyond what was asked, and because the intercept-companion SD is not
  the estimand this extractor was commissioned for.
- **Decision:** `interval_status` is a constant `"wald_uncalibrated"` on
  every returned row (never `"unavailable"` for suppressed rows), with the
  per-row availability carried by `status` instead.
  **Rationale:** the task brief states this literally ("a per-row
  `interval_status = \"wald_uncalibrated\"`"), which differs from the
  design doc's proposal (`"unavailable"` for suppressed rows). The brief is
  the more immediate, explicit instruction; `status` already carries the
  per-row availability information the design doc wanted `interval_status`
  to carry for suppressed rows.

## 4. Checks Run

- `Rscript -e 'devtools::document()'` -- clean; wrote `NAMESPACE` and
  `man/slope_sd_ci.Rd`. Pre-existing unrelated warnings only (`anova` /
  `BIC` / `AIC.gllvmTMB_multi` missing `@export`/`@exportS3Method` tags --
  not touched by this change).
- `NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-slope-sd-ci.R")'`
  -- **49 pass, 0 fail, 0 warn, 0 skip.**
- `Rscript -e 'testthat::test_file(...)'` without `NOT_CRAN=true` -- 28
  pass, 0 fail, 1 skip (the `skip_on_cran()`-guarded real-fit happy-path
  test; confirms the skip guard itself works as intended).
- `NOT_CRAN=true Rscript -e 'devtools::test()'` (full package) -- launched
  in background; see Section 10 for its disposition (this session did not
  block on the full multi-hundred-file suite finishing, per the DoD's "at
  least your new file plus anything touching NAMESPACE" bar -- the NAMESPACE
  delta here is purely additive: one new export, one new S3 method under a
  novel class name, touching no existing symbol).
- `rg -n "^\| CI-14 \|" docs/design/35-validation-debt-register.md` and
  `rg -n "^\| CI-15 \|"` -- one match each, confirmed unique IDs (also
  checked against 513 remote branches for a pre-existing `CI-14` row before
  writing -- none found).

## 5. Tests of the Tests

- **Happy path** (`test-slope-sd-ci.R`, "recovers a known-truth slope SD"):
  refits the verified `dev/slope-interval-feasibility-RESULTS.md` Route B
  fixture (`n_ind = 50`, `n_rep = 6`, 3 traits, `latent(0 + trait + (0 +
  trait):temperature | individual, d = 2)`); asserts `pdHess = TRUE`, 3
  rows, all `status == "ok"`, finite intervals, `lower < estimate < upper`,
  `interval_status`/`method`/`calibrated` values, estimates in
  `(0.05, 0.5)` with the true `psi_sd = 0.2` inside every CI, `scale =
  "sd"`/`"variance"` numeric consistency, and that `print()` emits both the
  fence text and the `rr_B_slope` caveat (this fixture legitimately has
  both `theta_diag_B_slope` and `theta_rr_B_slope`).
- **Kill-switch guards, each proven to fire, not assumed** -- per
  deterministic `mock_slope_ci_fit()` fixtures (no TMB call, exact
  `cov.fixed`/`opt$par`, the house pattern from `test-loading-ci.R`'s
  `mock_loading_delta_fit()`):
  - **non-PD Hessian**: before asserting the guard, the test computes the
    naive `exp(theta -/+ z*se)` from the SAME `se_theta` values and shows
    it IS finite -- i.e. the guard is the only thing standing between this
    input and a plausible-looking published interval. Then confirms
    `slope_sd_ci()` warns "not positive-definite", every row's `status ==
    "no_pd_hessian"`, every interval is `NA`, and every point estimate is
    still finite.
  - **non-finite `se_theta`**: uses `se_theta = NaN` on one trait's slope
    coordinate (embedded via the mock's interleaved packing, exercising the
    SAME extraction path a real fit uses); confirms the naive computation
    propagates `NaN` (not silently resolved), then confirms the guard
    catches exactly that row (`status = "se_nonfinite"`) while leaving the
    other trait's row `"ok"`.
  - **boundary collapse** (`se_theta > 10`): uses values in the ballpark of
    the task brief's cited observed degenerate fit
    (`theta = -13.548, se = 61883.69`); confirms the naive interval would
    be a finite-but-astronomically-wide (or exactly-zero-lower) numeric
    range -- the "plausible-looking garbage" failure mode named in the
    brief -- then confirms the guard suppresses it (`status = "boundary"`)
    while the healthy row stays `"ok"`.
  All three guard tests are genuine failure-before-fix demonstrations: each
  first shows what the ungated computation would produce from the exact
  same inputs, then shows the shipped guard intercepts it. None is a
  fixture that would pass "for the wrong reason" -- each degenerate value
  is chosen so the naive path visibly misbehaves.
- **Deferred routes error, not approximate**: one test per deferred route
  (`phylo_dep_slope = TRUE`; `diag_B_slope = FALSE` + `rr_B_slope = TRUE`),
  asserting both the error class `gllvmTMB_slope_sd_ci_unsupported_route`
  and message content naming the deferred route. A third test confirms a
  fit with neither flag TRUE gets the plain "nothing to summarise" message
  (a different, non-deferral error).
- **Scale consistency**: `scale = "variance"` is checked numerically
  identical to `scale = "sd"` squared (estimate, lower, upper) on the same
  real fit, at `tolerance = 1e-10` -- both are derived from the identical
  `theta`/`se_theta`, so this is an algebra check, not new evidence.
- **Argument validation**: non-`gllvmTMB_multi` input, and out-of-range /
  non-scalar `level`.

## 6. Consistency Audit

- `rg -n "theta_diag_B_slope|theta_rr_B_slope|theta_dep_chol" R/slope-sd-ci.R`
  -- confirms the file only reads/refuses these three blocks by name, no
  hand-rolled indexing beyond the documented `slope_pos <- seq(2, 2*n_traits,
  by = 2)` filter (verified against `R/fit-multi.R` and
  `R/extract-sigma.R`'s independently-established ordering, not re-derived
  from scratch).
- `rg -n "calibrated" R/slope-sd-ci.R` -- one assignment
  (`attr(out, "calibrated") <- FALSE`), never read as an argument or
  conditionally set -- matches the `R/va-intervals.R` house convention.
- `rg -n "interval_status" R/slope-sd-ci.R` -- literal constant
  `"wald_uncalibrated"` on every row, matching the task brief's literal
  spec (see Section 3a for the resolved tension against the design doc's
  alternative proposal).
- `rg -n "ADREPORT|src/" R/slope-sd-ci.R tests/testthat/test-slope-sd-ci.R`
  -- no match beyond comments citing the deferred slice; confirms no `src/`
  edits and no ADREPORT machinery was built in this slice.

## 7. Roadmap Tick

N/A -- no `ROADMAP.md` row targets this capability; tracked via the
validation-debt register (CI-14/CI-15) instead.

## 7a. GitHub Issue Ledger

No relevant open issue found for this capability; no new issue created --
the work was commissioned directly by Curie's brief against Fable's design
doc, not tracked via a GitHub issue.

## 8. What Did Not Go Smoothly

- The design doc's own "Slice-1 scope" bullet ("diag_B_slope AND NOT
  rr_B_slope") contradicts its own cited verification numbers, which come
  from a fixture with both flags TRUE. Resolved by following the task
  brief's literal framing and the brief's own "Verified this session"
  citation over the design doc's stricter bullet; documented in Section 3a
  and in the CI-14 register row rather than silently picking one reading.
- Two `cli::cli_warn()` calls initially used `{n}` + `{?s}` pluralisation
  glue syntax incorrectly (`cli`'s auto-pluralisation needs an explicit
  `cli::qty()`), which errored inside `expect_warning()` rather than
  producing the wrong plural. Fixed by dropping the pluralisation magic in
  favour of plain "N of M slope(s)" text.
- An early version of the guard tests set `theta`/`se_theta` as flat
  length-`2*n_traits` vectors under a wrong assumption about which
  positions the real function would select as slope coordinates, so the
  first test run failed on which row's `status` was affected. Fixed by
  rewriting the mock helper to take `slope_theta`/`slope_se` (length
  `n_traits`) directly and interleave them internally at the SAME
  positions `slope_sd_ci()` reads from a real fit -- this also makes the
  guard tests read more directly as "what should row t's theta/se be",
  rather than requiring the test author to hand-compute packing positions.
- A scratch script (`/tmp/time_fit.R`) written to time the Route B fixture
  saved a stray `dev/fitB_cache.rds` inside the worktree; `rm` on it was
  denied by the sandbox permission system in this session, so the file
  remains untracked in the worktree (not staged, not part of any commit).

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Curie (implementation):** the single most valuable check in this task
was re-deriving the `theta_diag_B_slope` interleaving from
`R/fit-multi.R`'s `Z_B_diag` construction and cross-checking it against
`R/extract-sigma.R`'s independently-built `aug_names` convention, rather
than trusting either the design doc's prose description or my own first
guess. Both sources agreed (`intercept.t1, slope.t1, intercept.t2, ...`),
and the live-fit smoke test (`Rscript` against the real Route B fixture)
then reproduced the exact `theta`/`se` numbers documented in
`dev/slope-interval-feasibility-RESULTS.md`'s table at positions 2/4/6 --
strong independent confirmation before any test was written against it.

**Fable (design, via `dev/fable-extractor-recommendation.md`):** the
design doc's guard vocabulary (`interval_status`, hard-coded `calibrated`,
fence-first print, register rows) transferred cleanly and needed no
rework. The one place the design and the task brief diverged (the
rr_B_slope scope bullet, and the `interval_status` value for suppressed
rows) is recorded rather than silently resolved in either document's
favour.

## 10. Known Limitations And Next Actions

**What this does NOT cover** (do not read a green PR here as covering any
of this):

- **No repeated-sampling coverage evidence.** The happy-path test is a
  single seed; `interval_status = "wald_uncalibrated"` and register row
  CI-14 (`partial`) say this plainly. Gated by CI-08/CI-10 same as every
  other Wald route in the package.
- **No multivariate slice.** `theta_dep_chol` (phylogenetic Cholesky
  augmented slopes) and `theta_rr_B_slope` alone (loadings-only augmented
  slopes) remain `blocked` (CI-15) by explicit refusal. Unblocking needs
  an `ADREPORT()`-based slice 2 in `src/gllvmTMB.cpp`, which this task
  deliberately did not touch.
- **Non-Gaussian families untested.** The feasibility probe and this
  slice's tests are Gaussian-only; the diagonal Psi companion for
  augmented slopes is itself Gaussian-gated by default elsewhere in the
  codebase (`R/fit-multi.R` ~2203-2209), so this is consistent with
  existing scope, not a new gap -- but it means no non-Gaussian recovery
  evidence exists for this extractor either.
- **The `rr_B_slope`-present caveat is a documentation/print-method
  mitigation, not a numeric correction.** When both blocks are active,
  `estimate` genuinely excludes the shared loadings contribution to
  marginal slope variance; nothing here computes or bounds that omitted
  contribution.
- **This is an ADDED PUBLIC EXPORT.** Per `CLAUDE.md`'s merge rules this is
  a high-risk API change requiring explicit maintainer sign-off before
  merge. The PR is opened as **DRAFT** for exactly this reason; do not
  merge without Shinichi's go-ahead.
- **Full-package `devtools::test()` was launched but this session did not
  block on its multi-hundred-file completion**, per the DoD's "at least
  your new file plus anything touching NAMESPACE" bar and the additive
  nature of the NAMESPACE delta (one new export, one new S3 method under a
  novel class, no existing symbol touched). If that run surfaces any
  unrelated failure, it is not attributable to this change by construction
  (no existing file was edited), but it has not been independently
  re-confirmed pass/fail in this report.

Next slice (not started, not scoped in this task): the `ADREPORT()` route
for `theta_dep_chol` / `theta_rr_B_slope`, with the cross-check test G3
calls for (an independently-built `L L'` / `Lambda Lambda'` compared
against the ADREPORTed marginal SD on a fixture) before any register row
there moves off `blocked`.
