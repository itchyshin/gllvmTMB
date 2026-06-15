# After Task: Native Mixed-Family confint rho Evidence

**Branch**: `engine-julia`
**Date**: `2026-06-15`
**Roles (engaged)**: `Ada / Fisher / Hopper / Rose`

## 1. Goal

Close the next R-first inference evidence gap after mixed-family point-fit
admission: prove the public `confint()` route, not only the lower-level
`extract_correlations()` route, for native mixed-family latent-correlation
intervals.

## 2. Implemented

- `confint(fit, parm = "rho:<tier>:i,j", method = "fisher-z" | "wald" | "bootstrap")`
  now forwards an explicit `link_residual = "auto"` or `"none"` argument to
  `extract_correlations()`.
- The Stage 37 mixed-family oracle now checks
  `confint(fit, parm = "rho:unit:1,2", method = "fisher-z", link_residual = "none")`
  and the `wald` alias on the same fitted object.
- The regression asserts matrix shape, row name, finite bounds, bounds inside
  `[-1, 1]`, and equality between the Wald alias and Fisher-z interval.
- The help page now documents the `link_residual` pass-through for non-profile
  rho intervals.

## 3. Files Changed

Implementation:

- `R/z-confint-gllvmTMB.R`

Tests:

- `tests/testthat/test-stage37-mixed-family.R`

Docs and ledger:

- `man/confint.gllvmTMB_multi.Rd`
- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-native-mixed-family-confint-rho.md`

## 3a. Decisions and Rejected Alternatives

Decision: forward only `link_residual` from `...` into `extract_correlations()`.

Rationale: this gives users explicit control over the mixed-family correlation
scale without creating a loose dots pipe for unrelated arguments.

Rejected alternative: pass all `...` through to `extract_correlations()`. That
would be more permissive but would also make the `confint()` rho branch harder
to reason about and test.

Confidence: high for the non-profile rho branch. Profile rho still follows
`profile_ci_correlation()` and is not promoted here.

## 4. Checks Run

- `Rscript -e 'devtools::load_all(".", quiet=TRUE); fit <- gllvmTMB:::fit_mixed_family_fixture(3L); ci_f <- suppressWarnings(suppressMessages(confint(fit, parm="rho:unit:1,2", method="fisher-z"))); ci_w <- suppressWarnings(suppressMessages(confint(fit, parm="rho:unit:1,2", method="wald"))); print(ci_f); print(ci_w); stopifnot(is.matrix(ci_f), nrow(ci_f)==1L, all.equal(ci_f, ci_w, tolerance=1e-8) == TRUE)'`
  - passed; both intervals were `[-0.06185684, 0.4278576]`.
- `Rscript -e 'devtools::test(filter="stage37-mixed-family")'`
  - `PASS 40`, `SKIP 0`, `FAIL 0`, `WARN 0` in `3.1s`.
- `Rscript -e 'devtools::test(filter="stage37-mixed-family|confint-derived|m1-4-extract-correlations-mixed-family")'`
  - `PASS 40`, `SKIP 39`, `FAIL 0`, `WARN 0` in `3.6s`.
- `Rscript -e 'devtools::document()'`
  - regenerated `man/confint.gllvmTMB_multi.Rd`; unrelated roxygen Rd churn was
    reverted. Pre-existing unresolved-link roxygen warnings remain.
- `Rscript -e 'devtools::test()'`
  - `PASS 2950`, `SKIP 722`, `FAIL 0`, `WARN 3` in `132.6s`.
  - Warnings were the existing `nadiv::makeAinv()` selfing warning and the
    existing `glmmTMB`/`TMB` version warning in the NB1 cross-package check.
- `Rscript -e 'pkgdown::check_pkgdown()'`
  - no problems found.
- `git diff --check`
  - clean.

## 5. Tests of the Tests

This is a prophylactic public-route regression. Before this slice, mixed-family
correlation evidence lived in `extract_correlations()` and heavy-gated
extractor tests; the exported `confint()` token route did not have native
mixed-family evidence in the Stage 37 oracle. The new assertions are tied to
the same fitted mixed-family object that already checks selector metadata,
prediction, and simulation.

## 6. Consistency Audit

- `git diff -- man/add_utm_columns.Rd man/extract_correlations.Rd man/gllvmTMB-package.Rd man/make_mesh.Rd`
  - empty after manually reverting unrelated roxygen churn.
- `gh issue view 340 --json number,title,state,url`
  - #340 is open and remains the capability/status-board umbrella.
- `gh issue view 341 --json number,title,state,url`
  - #341 is open and remains the broader random-slope completion umbrella.
- `gh issue view 488 --json number,title,state,url`
  - #488 is open and remains the bridge-gate drift umbrella.
- `gh issue view 361 --json number,title,state,url`
  - #361 is open and remains the kernel/co-evolution umbrella.

## 7. Roadmap Tick

R-first mixed-family inference moves one small row forward: native R/TMB
mixed-family `confint(..., parm = "rho:unit:i,j")` has public-route Fisher-z/Wald
evidence. It is still `partial`, not `covered`, because profile/bootstrap
promotion and coverage studies are separate gates.

## 7a. GitHub Issue Ledger

Relevant issues inspected but not mutated:

- #340: capability matrix / live status board.
- #341: random-slope completion.
- #488: Julia bridge-gate drift.
- #361: kernel/co-evolution roadmap.

No issue comments were posted in this local slice because the branch is still in
no-push/local-evidence mode.

## 8. What Did Not Go Smoothly

`devtools::document()` rewrote unrelated Rd links and package author output.
Those generated hunks were manually reverted so this slice carries only the
`confint()` documentation change. The Stage 37 test still prints existing
mixed-family Sigma/link-residual notes; they are messages, not warnings, and
they were already part of the mixed-family summary/extractor path.

## 9. Team Learning

Ada: R-first is the safer sequence here; native functionality should define
the target before Julia acceleration catches up.

Fisher: the interval claim is deliberately narrow. Fisher-z/Wald boundedness is
now evidenced through `confint()`, but calibrated coverage and profile/bootstrap
behavior are still future validation gates.

Hopper: forwarding only `link_residual` keeps the R API predictable while
matching the lower-level extractor semantics.

Rose: verdict is `partial`. The claim is covered for the public non-profile rho
route on the native mixed-family oracle, but not for Julia CIs or calibrated
mixed-family correlation inference.

## 10. Known Limitations And Next Actions

- Mixed-family profile/bootstrap rho endpoints still need their own promotion
  evidence and coverage language.
- Julia mixed-family CI endpoints remain unsupported.
- The next R-first slice should harden the capability/status ledger (#340) or
  promote another native mixed-family inference route before widening the Julia
  bridge.
