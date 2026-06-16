# After Task: R Bridge Grouped-Dispersion Payload

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: `Ada / Shannon / Hopper / Karpinski / Gauss / Noether / Curie / Rose / Grace`

## 1. Goal

Make the lean R `engine = "julia"` bridge consume the grouped-dispersion payload now emitted by the paired `GLLVM.jl-integration` branch for NB2, NB1, Beta, and Gamma no-X reduced-rank fits, while keeping public wording honest about the still-partial bridge.

## 2. Implemented

- `gllvm_julia_fit()` now maps NB2 aliases to the Julia key `negbinomial`, rejects unsupported `lognormal`, passes trait/unit labels to Julia, and normalises grouped-dispersion payloads on return.
- Grouped-dispersion results keep Julia engine-native `dispersion` values and add R-facing fields: `dispersion_group`, `dispersion_group_id`, `dispersion_engine`, `dispersion_group_engine`, `dispersion_public`, `dispersion_group_public`, `dispersion_public_parameter`, and NB2 `dispersion_gllvm_phi`.
- `gllvm_julia_capabilities()` is exported as a conservative R-side ledger. Grouped-dispersion rows are `partial` and no-X CI columns are `FALSE` for NB2, NB1, Beta, and Gamma.
- NEWS now points the Julia bridge claim to `JUL-01` and removes the stale lognormal bridge claim.
- `_pkgdown.yml` now indexes the Julia bridge reference topics.
- `docs/design/35-validation-debt-register.md` now has `JUL-01` for the lean Julia bridge surface.

## 3. Files Changed

- Bridge code: `R/julia-bridge.R`
- Tests: `tests/testthat/test-julia-bridge.R`
- Generated docs/exports: `NAMESPACE`, `man/gllvm_julia_capabilities.Rd`, `man/extract_correlations.Rd`
- Public/reference docs: `NEWS.md`, `_pkgdown.yml`
- Validation/dev log: `docs/design/35-validation-debt-register.md`, `docs/dev-log/check-log.md`, `docs/dev-log/after-task/2026-06-16-r-bridge-grouped-dispersion.md`

## 3a. Decisions and Rejected Alternatives

- Decision: keep `dispersion` on the Julia engine-native scale and add public-scale companion fields. Rationale: this avoids accidentally feeding transformed sigma values back into engine-native simulation or likelihood code later.
- Decision: keep mixed-family components to gaussian/poisson/binomial in the R bridge. Rationale: mixed-family dispersion promotion needs its own parity row; this slice only fixes one-part grouped-dispersion payload decoding.
- Decision: report the R capability ledger conservatively rather than mirroring every low-level Julia engine flag. Rationale: the main `gllvmTMB()` dispatch still rejects masks and non-Gaussian X, and the ledger should describe admitted R-user rows.

## 4. Checks Run

- `git status --short --branch` -> clean on `codex/r-bridge-grouped-dispersion` before edits.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,isDraft,updatedAt,url` -> `[]`.
- `gh run list --repo itchyshin/gllvmTMB --limit 12 --json databaseId,workflowName,headBranch,status,conclusion,createdAt,url` -> `main` had a `Power pilot sweep` in progress; latest `full-check` was successful.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> loaded `gllvmTMB`; wrote `NAMESPACE`, `extract_correlations.Rd`, and `gllvm_julia_capabilities.Rd`.
- `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge")'` -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 95` in 26.8 s.
- `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge")'` -> `FAIL 0 | WARN 0 | SKIP 2 | PASS 48`.
- First `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> failed because `gllvm_julia_capabilities`, `gllvm_julia_fit`, and `gllvm_julia_setup` were exported but missing from `_pkgdown.yml`.
- Second `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); stopifnot(!"lognormal" %in% caps$family); stopifnot(!any(caps$ci_no_x_wald[caps$family %in% c("negbinomial", "nb1", "beta", "gamma")])); print(caps[, c("family", "fit_no_x", "fixed_effect_X", "ci_no_x_wald", "status")], row.names = FALSE)'` -> grouped-dispersion CI rows printed as `FALSE`; all rows `partial`.
- `git diff --check` -> clean.

## 5. Tests of the Tests

- Boundary tests now fail loudly for `lognormal` in the Julia bridge family mapper and for mixed-family dispersion components.
- Synthetic grouped-payload tests verify trait labels, group ids, engine-native values, NB2 `phi = 1/r`, and public-scale conversions before the live Julia call.
- The live Julia test verifies that the paired `GLLVM.jl-integration` checkout returns grouped-dispersion payloads for NB2, NB1, Beta, and Gamma with exact `df = 6` for a 2-trait, rank-1, per-trait-grouped fit.
- The no-Julia test run verifies the `Suggests` dependency path: pure-R guards pass and live round trips skip cleanly.

## 6. Consistency Audit

- `rg -n "lognormal|full native parity|full parity|complete bridge|CRAN-ready bridge|covered.*Julia|ci_no_x.*negbinomial|ci_no_x.*nb1|ci_no_x.*beta|ci_no_x.*gamma" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md docs/design/35-validation-debt-register.md man/gllvm_julia_capabilities.Rd _pkgdown.yml`
  -> expected hits only: explicit lognormal rejection tests, non-bridge historical lognormal rows, and the negative NEWS guard "not a full native parity claim"; no grouped-dispersion CI overclaim.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. This is the implementation companion to the 2026-06-16 per-trait dispersion spec and should feed `gllvmTMB#488`.

## 7a. GitHub Issue Ledger

No issue was commented on or closed. `gllvmTMB#488` remains the relevant bridge gate-vs-engine drift umbrella, but issue action needs a live `gh issue view`, linked local evidence, and Shannon/Rose signoff.

## 8. What Did Not Go Smoothly

`pkgdown::check_pkgdown()` caught that the Julia bridge exports were absent from `_pkgdown.yml`. The fix was small and is included in this branch. Roxygen also regenerated a whitespace-only change in `man/extract_correlations.Rd`; it is generated output from the local roxygen run, not a source-prose change.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- Ada: kept the slice narrow to bridge payload decoding and public truth, not native parity admission.
- Shannon: pre-edit state was clean with no open PRs; `main` had a `Power pilot sweep` in progress, so this branch was kept local.
- Hopper: R bridge now understands the grouped nuisance payload and maps family aliases to the paired Julia keys.
- Karpinski: paired Julia branch `5cb7ea5` is the runtime truth for grouped-dispersion defaults.
- Gauss / Noether: scale fields separate engine-native nuisance values from public-scale checks; no TMB likelihood changed.
- Curie: tests cover pure-R guards, synthetic payload conversion, live Julia grouped-dispersion payloads, and no-Julia skips.
- Rose: NEWS, validation row `JUL-01`, capability ledger, and stale-wording scan all keep the bridge partial.
- Grace: roxygen and pkgdown passed after the reference index fix; full package check remains a later gate.

## 10. Known Limitations And Next Actions

- No native `gllvmTMB` vs Julia parity promotion yet for NB2, NB1, Beta, or Gamma logLik/estimates.
- No grouped-dispersion Wald/profile/bootstrap CI route yet.
- Ordinal still needs per-trait cutpoints on the Julia side before a native parity claim.
- Mixed-family dispersion rows, NB1-X, masks+X,
  structured covariance terms, prediction, residuals, simulation, extractor parity,
  and CIs remain planned/gated. Point-estimate `coef()` and `summary()` were
  admitted later in the 2026-06-16 bridge-method slice. Complete-response
  fixed-effect-X rows for NB2, Beta, and Gamma were admitted later in the
  2026-06-16 fixed-X bridge slice.
