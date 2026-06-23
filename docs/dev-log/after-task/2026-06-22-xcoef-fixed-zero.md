# After Task: Xcoef Fixed-Zero Coefficients

**Branch**: `codex/xcoef-fixed-zero-20260622`
**Date**: `2026-06-22`
**Roles (engaged)**: Ada, Boole, Emmy, Noether, Fisher, Curie, Grace, Rose

## 1. Goal

Add a narrow, reviewable route for setting selected fixed-effect
coefficients to exactly zero after the ordinary fixed-effect design
matrix has been built. The motivating user wording was "fix beta to
zero"; the implemented public API is `Xcoef_fixed`, because the package
already names the expanded fixed-effect coefficient vector `b_fix` /
`X_fix_names`.

## 2. Implemented

- `gllvmTMB(..., Xcoef_fixed = c("expanded_column" = 0))` now accepts a
  named numeric vector for native ML fits.
- Names are checked against `fit$X_fix_names`; unknown, duplicate,
  unnamed, non-finite, and non-zero entries fail loudly.
- Fixed rows are pinned to zero in the starting vector, mapped out of
  the free TMB parameter vector, retained in coefficient tables, and
  labelled `status = "fixed"`.
- `tidy(fit, "fixed")` reports fixed rows with `estimate = 0`,
  `std.error = NA`, and `status = "fixed"`; Wald/profile CI rows keep
  `NA` bounds for fixed coefficients.
- The wide `traits(...)` route passes `Xcoef_fixed` through to the same
  expanded-column check.
- `REML = TRUE`, non-zero fixed values, and `engine = "julia"` remain
  explicit stops.

## 3. Mathematical Contract

Let `X` be the fixed-effect design matrix produced by the existing
`model.matrix()` path and let `b_fix` be the fixed-effect coefficient
vector. This slice does not change the likelihood, link functions,
family code, formula grammar, or TMB objective. It constrains selected
entries of `b_fix`:

```text
eta = X b_fix + random-effect terms
b_fix[j] = 0 for j in names(Xcoef_fixed)
```

The constraint is implemented through TMB's parameter `map`, so fixed
entries are not counted as free parameters. This is not a response mask,
not a `lambda_constraint`, not a loading constraint, and not a Julia
bridge admission.

## 4. Files Changed

Implementation:

- `R/gllvmTMB.R`
- `R/fit-multi.R`
- `R/xcoef-fixed.R`
- `R/methods-gllvmTMB.R`
- `R/z-confint-gllvmTMB.R`

Tests:

- `tests/testthat/test-xcoef-fixed.R`

Documentation and status inventory:

- `man/gllvmTMB.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-22-xcoef-fixed-zero.md`

## 4a. Decisions and Rejected Alternatives

Decision: use `Xcoef_fixed` rather than `beta_fixed`.

Rationale: the constraint is applied to the expanded fixed-effect
design columns, not to a formula-level term name. `Xcoef_fixed` points
the user to `fit$X_fix_names` and avoids promising a formula grammar
feature.

Rejected alternative: allowing non-zero fixed values in the first
slice.

Rationale: zero masks answer the immediate "fix beta to zero" request
and are easy to validate with df and omitted-block equivalence. Non-zero
fixed values need a separate design pass so reporting, profiles, and
Julia parity do not overclaim.

## 5. Checks Run

- `gh run view 27998401037 --repo itchyshin/gllvmTMB --json status,conclusion,url,jobs`
  -> PASS; post-merge #535 Ubuntu check succeeded.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS; regenerated `man/gllvmTMB.Rd`.
- `air format R/xcoef-fixed.R tests/testthat/test-xcoef-fixed.R R/gllvmTMB.R R/fit-multi.R R/methods-gllvmTMB.R R/z-confint-gllvmTMB.R`
  -> PASS, but it reformatted large legacy files; that churn was
  reverted before closeout.
- `Rscript --vanilla -e 'devtools::test(filter = "xcoef-fixed", reporter = "summary", stop_on_failure = TRUE)'`
  -> PASS: `xcoef-fixed: ................`.
- `Rscript --vanilla -e 'devtools::test(filter = "xcoef-fixed|profile-targets|tidy|confint", reporter = "summary", stop_on_failure = TRUE)'`
  -> PASS; no failures. Existing heavy-profile tests skipped under
  their normal gate.
- `Rscript --vanilla -e 'devtools::test(reporter = "summary", stop_on_failure = TRUE)'`
  -> PASS; no failures. The run reported 10 known warnings: one Julia
  bridge default-Psi warning and nine multi-trial binomial `NaNs
  produced` warnings.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS: `No problems found.`
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", document = FALSE, check_dir = "/private/tmp/gllvmtmb-xcoef-fixed-zero-check", error_on = "never", quiet = FALSE)'`
  -> PASS with known local Apple-clang/R-header warning:
  `0 errors, 1 warning, 0 notes`.
- Direct profile-CI smoke:
  `Rscript --vanilla - <<'RS' ... confint(fit, method = 'profile') ... RS`
  -> PASS; fixed `traitb:x` row kept `NA` bounds.
- `git diff --check`
  -> PASS.

## 6. Tests Of The Tests

The new tests satisfy all three audit rules.

- Failure-before-fix: before this slice, `gllvmTMB()` had no
  `Xcoef_fixed` argument and could not pin an expanded fixed-effect
  coefficient.
- Boundary cases: tests cover unknown names, non-zero values,
  `REML = TRUE`, and `engine = "julia"` rejection.
- Feature combination: tests cover both long-format data and the wide
  `traits(...)` route, plus the all-zero covariate-block equivalence to
  omitting that block.

The tests also check the free-parameter count drops by one for one
fixed coefficient and that fixed rows keep visible output rather than
disappearing from the coefficient table.

## 7. Consistency Audit

- `rg -n "Xcoef_fixed|structural-zero|non-zero fixed|engine = \"julia\" structural-zero|Julia twin|guarantee|guarantees|automatic coefficient|beta to zero|fix beta|fixed-effect coefficients" NEWS.md R man tests docs/design/35-validation-debt-register.md`
  -> PASS; hits were the intended implementation and guarded
  documentation, plus unrelated existing uses of "guarantee" in already
  validated contexts.
- `rg -n "Xcoef_fixed.*covered|covered.*Xcoef_fixed|Julia.*covered|engine = \"julia\".*covered|non-zero fixed values.*implemented|guarantees convergence|proves identifiability|automatic deletion|selects variables" NEWS.md R man tests docs/design/35-validation-debt-register.md || true`
  -> PASS; hits were the intended `MIS-34` native-covered / partial
  boundary and the existing `screen_gllvmTMB()` overclaim guard, not a
  stale Julia or non-zero fixed-value claim.

Rendered Rd spot-check: `R CMD check` passed Rd usage, contents,
cross-reference, and code/documentation mismatch checks. No new
`@keywords` or tag rearrangement was added after long roxygen prose.

## 8. Roadmap Tick

N/A. No `ROADMAP.md` status chip or progress bar changed in this PR.
This is recorded through `NEWS.md` and validation row `MIS-34` instead.

## 8a. GitHub Issue Ledger

- `gh issue list --repo itchyshin/gllvmTMB --state open --search "Xcoef_fixed OR structural-zero OR beta zero OR coefficient zero" --json number,title,url,state,updatedAt --limit 20`
  -> no dedicated zero-coefficient issue was found.
- `gh issue view 488 --repo itchyshin/gllvmTMB --json number,title,url,state,body,comments`
  -> inspected because this slice adds a deliberate `engine = "julia"`
  gate. The PR does not close #488. It should be followed by a paired
  GLLVM.jl coefficient-mask slice, then the R gate can be relaxed with
  evidence.

No issue was closed or created in this slice.

## 9. What Did Not Go Smoothly

`air format` reformatted thousands of lines in legacy files. That would
have made a small behavioural PR look like a style rewrite, so the
existing-file formatting churn was reverted and the functional patches
were reapplied by hand. The useful lesson is to avoid broad formatting
commands on legacy files unless the PR is explicitly a formatting PR.

The direct profile-CI smoke initially sourced the test file to reuse the
fixture helper, which also printed testthat messages and one unrelated
latent-default warning. The useful result was still valid, but future
manual smokes should define tiny local fixtures instead of sourcing a
whole test file.

## 10. Team Learning

Ada kept the lane narrow: one R API argument, one helper file, one
focused test file, one validation row. The Julia twin was kept as a
real follow-up rather than being silently claimed.

Boole and Emmy pushed the naming toward `Xcoef_fixed`, because this is
expanded-design-matrix aware, not formula-term aware. That name makes
the user check `fit$X_fix_names` before constraining.

Noether and Fisher checked the parameter-count logic. The TMB map is
the right mechanism because fixed entries drop from the free parameter
vector, and the all-zero covariate-block test checks equivalence to an
omitted block.

Curie anchored the test suite on acceptance, rejection, and a
feature-combination case. The wide `traits(...)` test is important
because public tutorials teach both long and wide entry points.

Grace kept the release gates in place: `devtools::document()`,
focused tests, full tests, `pkgdown::check_pkgdown()`,
`devtools::check(args = "--no-manual")`, and `git diff --check`.

Rose caught the scope boundary. The `NEWS.md` and `MIS-34` language
say native ML zero constraints are covered, while REML, non-zero fixed
values, and Julia masks are partial / gated.

## 11. Known Limitations And Next Actions

- `Xcoef_fixed` currently supports only zero values.
- `REML = TRUE` is deliberately rejected.
- `engine = "julia"` is deliberately rejected until GLLVM.jl has a
  paired coefficient-mask implementation and bridge evidence.
- This is not a formula-level selector and does not choose variables,
  drop predictors, or alter the response screen.
- Next slice: implement the Julia twin coefficient mask, then relax the
  R bridge gate with live GLLVM.jl tests and update #488 / `MIS-34`.
