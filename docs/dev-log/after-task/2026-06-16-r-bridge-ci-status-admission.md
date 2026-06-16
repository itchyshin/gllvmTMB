# After Task: R Bridge Direct CI/Status Admission

## Goal

Close the bridge gate-vs-engine drift for no-X confidence-interval payloads:
the paired Julia engine already routes CI fields for scalar-CI bridge rows, but
the R wrapper had no way to request or read them.

## Implemented

`gllvm_julia_fit()` now accepts:

- `ci_method = c("none", "wald", "profile", "bootstrap")`;
- `ci_level`;
- `ci_nboot`;
- `ci_seed`.

For admitted no-X Gaussian, Poisson, and Bernoulli binomial rows, these options
are passed through the existing `GLLVM.bridge_fit(..., options = ...)`
contract. The returned flat CI payload is normalised into named R vectors with
`ci_status`, `ci_method`, `ci_level`, and `ci_note` fields.

`confint.gllvmTMB_julia()` now reads stored Julia CI payloads and returns a
standard two-column CI matrix. It does not refit or recompute CIs: if the fit was
not created with a CI payload, or the requested level differs from the stored
level, it fails loudly.

The lane keeps explicit gates for mixed-family vectors, grouped-dispersion rows,
per-trait ordinal rows, response-mask fits, and fixed-effect-X fits.

## Evidence

- Pure-R tests cover CI payload normalisation, stored-payload `confint()`,
  level mismatch failures, missing-payload failures, and unsupported CI gates
  before Julia setup.
- Live R-to-Julia tests request Wald CI payloads through `gllvm_julia_fit()` for
  Gaussian, Poisson, and Bernoulli binomial rows and verify `confint()` plus
  `summary()` status.
- The paired Julia runtime test `test_bridge_ci.jl` verifies the engine-side
  Wald/profile/bootstrap CI payload contract against native GLLVM.jl CI engines.

## Checks Run

- Pre-edit coordination:
  `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,updatedAt,url`
  -> `[]`.
- Recent hot-file scan:
  `git log --all --oneline --since="6 hours ago" -- NEWS.md NAMESPACE R/julia-bridge.R tests/testthat/test-julia-bridge.R docs/design/35-validation-debt-register.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task man/gllvmTMB_julia-methods.Rd man/gllvm_julia_fit.Rd`
  -> current local Codex programme commits only.
- R-to-Julia options transport probe:
  R named lists arrive in Julia as `OrderedDict{Symbol, Any}`, compatible with
  the existing `_bridge_get()` option reader.
- Formatter:
  `air format R/julia-bridge.R tests/testthat/test-julia-bridge.R`
  -> completed quietly.
- Roxygen/Rd:
  `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `NAMESPACE`, `man/gllvm_julia_fit.Rd`, and
  `man/gllvmTMB_julia-methods.Rd`.
- No-Julia R bridge test:
  `Rscript --vanilla -e 'devtools::test(filter = "julia-bridge")'`
  -> `101` pass, `10` expected Julia-runtime skips, `0` fail.
- Live R bridge test:
  `Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = "/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration"); devtools::test(filter = "julia-bridge")'`
  -> `479` pass, `0` skip, `0` fail.
- Julia CI contract anchor:
  `julia --project=/Users/z3437171/Dropbox/Github\ Local/GLLVM.jl-integration /Users/z3437171/Dropbox/Github\ Local/GLLVM.jl-integration/test/test_bridge_ci.jl`
  -> `64/64 pass`.
- Capability ledger guard:
  `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); print(caps[, c("family", "ci_no_x_wald", "ci_no_x_profile", "ci_no_x_bootstrap", "postfit_coef", "postfit_summary", "postfit_predict", "status", "notes")], row.names = FALSE); stopifnot(identical(caps$family[caps$ci_no_x_wald], gllvmTMB:::.GLLVM_JULIA_CI_NO_X_FAMILIES)); stopifnot(identical(caps$family[caps$ci_no_x_profile], gllvmTMB:::.GLLVM_JULIA_CI_NO_X_FAMILIES)); stopifnot(identical(caps$family[caps$ci_no_x_bootstrap], gllvmTMB:::.GLLVM_JULIA_CI_NO_X_FAMILIES)); stopifnot(any(grepl("direct gllvm_julia_fit() no-X Wald/profile/bootstrap CI payloads", caps$notes, fixed = TRUE))); stopifnot(any(grepl("confint() remains gated until CI endpoints are admitted", caps$notes, fixed = TRUE)))'`
  -> scalar no-X CI flags are true only for Gaussian, Poisson, and Bernoulli
  binomial; grouped-dispersion and ordinal notes keep `confint()` gated.
- Stale wording scan:
  `rg -n 'CI/status, masked CI/status|NB1 still needs CI/status|confidence intervals.*gated|confidence intervals.*planned|point-estimate .*coef.*summary.* only|coef\(\) and summary\(\) are routed|main .*CI control|direct gllvm_julia_fit\(\).*CI|stored-payload confint\(\)|grouped-dispersion CIs|per-trait ordinal CIs|X-row CIs' R NEWS.md tests/testthat docs/design docs/dev-log man/gllvm_julia_fit.Rd man/gllvmTMB_julia-methods.Rd`
  -> remaining hits are current scoped gates or historical after-task/check-log
  commands.
- S3/Rd registration scan:
  `rg -n "S3method\\(confint,gllvmTMB_julia\\)|confint.gllvmTMB_julia|ci_method = c\\(\"none\", \"wald\", \"profile\", \"bootstrap\"\\)|ci_no_x_wald|ci_no_x_profile|ci_no_x_bootstrap" NAMESPACE R/julia-bridge.R man/gllvm_julia_fit.Rd man/gllvmTMB_julia-methods.Rd tests/testthat/test-julia-bridge.R`
  -> `confint.gllvmTMB_julia` is registered/documented and CI method arguments
  are present in source, tests, and Rd.
- Dashboard smoke:
  `curl -fsS 'http://127.0.0.1:8770/?v=ci-status-pending' | rg -n 'Updated: 2026-06-16 11:28 MDT|direct no-X CI/status|Source commit pending|Julia CI contract|64/64|main-dispatch CI controls|Local source commit pending'`
  -> local widget reflects the pending direct CI/status slice.
- Whitespace:
  `git diff --check` -> clean.

## Scope Boundary

`JUL-01` remains `partial`. This slice admits direct `gllvm_julia_fit()` CI
payloads and stored-payload `confint()` only for no-X Gaussian, Poisson, and
Bernoulli binomial rows. It does not implement main `gllvmTMB(..., engine =
"julia")` CI controls, grouped-dispersion CI endpoints, per-trait ordinal CI
endpoints, masked CIs, mixed-family CIs, X-row CIs, prediction, residuals,
simulation, extractor parity, broad native-vs-Julia parity, structured
dependence, simulation recovery, or speed claims.

## Team Learning

- Hopper: R named lists already cross JuliaCall as an `AbstractDict`, so the R
  wrapper can use the existing Julia bridge option contract directly.
- Fisher: CIs should remain stored-payload reads on this lane; recomputation
  belongs in a later fitted-object retention/control design.
- Rose: capability notes must say "direct wrapper CI payload" and not imply the
  main `gllvmTMB()` engine route has a CI control surface.
