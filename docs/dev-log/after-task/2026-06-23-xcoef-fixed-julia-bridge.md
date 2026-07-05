# After Task: Xcoef_fixed Julia Bridge And Article

**Branch**: `codex/xcoef-fixed-julia-bridge-20260623`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada / Boole / Emmy / Noether / Fisher / Pat / Darwin / Curie / Rose / Grace`

## 1. Goal

Finish the fixed-zero coefficient lane after the native TMB slice by routing
`Xcoef_fixed` to admitted GLLVM.jl fixed-effect-X fits, preserving the R-side
user API, and explaining the intended use case: some predictors are meaningful
for some responses but should be structurally zero for others.

## 2. Implemented

- Merged paired GLLVM.jl PR #114 before changing the R bridge.
- Removed the temporary `engine = "julia"` stop for `Xcoef_fixed` when the
  Julia bridge has an admitted fixed-effect covariate design.
- Added `coef_fixed` to `gllvm_julia_fit()` and transport it as an
  index-to-zero dictionary through `options$coef_fixed`, avoiding JuliaCall's
  scalar conversion for length-1 logical vectors.
- Normalised named R-side `Xcoef_fixed` values inside
  `.gllvmTMB_julia_dispatch()` after fixed-effect design expansion.
- Preserved `X_fix_names`, `Xcoef_fixed`, `gamma_status`, and
  `mean_coef_status` on Julia-backed fit objects where available.
- Added a Concepts article, "Fix predictor effects at zero", with copyable
  long and wide `traits(...)` examples and explicit boundaries against
  variable screening, response selection, and loading constraints.

## 3. Files Changed

Implementation:

- `R/gllvmTMB.R`
- `R/julia-bridge.R`

Tests:

- `tests/testthat/test-julia-bridge.R`
- `tests/testthat/test-xcoef-fixed.R`

Documentation and pkgdown:

- `man/gllvmTMB.Rd`
- `man/gllvm_julia_fit.Rd`
- `vignettes/articles/fixed-effect-zero-constraints.Rmd`
- `_pkgdown.yml`
- `NEWS.md`

Validation and logs:

- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-xcoef-fixed-julia-bridge.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep `Xcoef_fixed` as the public R API and expose `coef_fixed` only
as the lower-level Julia bridge argument.

Rationale: users think in expanded fixed-effect names such as `traitb:x`; the
Julia bridge needs positional mask information after model-matrix expansion.

Rejected alternative: export a new `fix_beta()` or response-predictor formula
mini-language in this PR. That would be a formula/API design change. The
current slice keeps the established named-vector contract.

Decision: pass fixed Julia coefficients through an index-to-zero dictionary
rather than a logical vector.

Rationale: JuliaCall simplifies length-1 R logical vectors to scalar `Bool`,
which broke the one-column case. GLLVM.jl PR #114 accepts dictionary-style
index constraints.

Rejected alternative: special-case length-1 masks only. The dictionary route is
stable for one or many fixed coefficients.

## 4. Checks Run

- `gh pr merge 114 --repo itchyshin/GLLVM.jl --merge --delete-branch`
  -> PASS; merged paired GLLVM.jl PR #114.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,author,updatedAt`
  -> PASS; no open PRs.
- `git log --all --oneline --since="6 hours ago"`
  -> PASS; no competing gllvmTMB shared-file edits detected.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE)'`
  -> PASS.
- `air format R/gllvmTMB.R R/julia-bridge.R tests/testthat/test-xcoef-fixed.R tests/testthat/test-julia-bridge.R`
  -> PASS; unrelated formatting churn was trimmed back.
- `Rscript --vanilla -e 'devtools::test(filter = "xcoef-fixed|julia-bridge")'`
  -> PASS: `FAIL 0 | WARN 1 | SKIP 16 | PASS 414`. The warning is the
  pre-existing Julia default-Psi bridge warning.
- `GLLVM_JL_PATH=/private/tmp/gllvmjl-xcoef-fixed-zero-20260622 Rscript --vanilla -e "devtools::load_all(quiet = TRUE); testthat::test_file('tests/testthat/test-julia-bridge.R', desc = \"engine = 'julia' main dispatch routes Xcoef_fixed to live GLLVM.jl\")"`
  -> PASS: `FAIL 0 | WARN 0 | SKIP 0 | PASS 5`.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS; relevant Rd files regenerated.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/fixed-effect-zero-constraints", lazy = FALSE, new_process = FALSE)'`
  -> PASS; new article rendered.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS: `No problems found.`
- `Rscript --vanilla -e 'devtools::test()'`
  -> PASS: `FAIL 0 | WARN 10 | SKIP 746 | PASS 3515`.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> `0 errors, 1 warning, 1 note`; devtools exited non-zero because warnings
  are errors by default. The warning and note are local-environment issues:
  Apple-clang/RcppEigen/R-header install warnings and `unable to verify current
  time`.
- `R CMD INSTALL -l "$tmp_lib" --preclean .`
  -> PASS; reproduced the same local compiler warning stack.
- `git diff --check`
  -> PASS.

## 5. Tests of the Tests

The pure-R bridge test asserts that a named `Xcoef_fixed` vector becomes a
positional mask with exactly the intended expanded fixed-effect column fixed.
It also checks that the returned R object preserves the fixed status and zero
estimate.

The live Julia smoke uses the merged GLLVM.jl PR #114 path and catches the
transport bug that originally turned a length-1 mask into scalar `Bool`. That
test failed before the dictionary transport fix and passes afterward.

The native `test-xcoef-fixed.R` validation remains in place for TMB: exact zero
pinning, df reduction, all-zero-block equivalence, validation failures, and
REML rejection.

## 6. Consistency Audit

- `rg -n "engine = \"julia\".*Xcoef_fixed|Xcoef_fixed.*engine = \"julia\".*stop|not yet available for .*engine = \"julia\"|structural-zero coefficient masks remain follow-up|selects variables|automatic deletion|guarantees convergence|proves identifiability|validated item selection|separation solved" R tests vignettes NEWS.md docs/design man _pkgdown.yml`
  -> PASS; no stale Julia-gate or overclaim wording.
- `rg -n "beta = 0|fixed predictor effects|Fix predictor effects|Xcoef_fixed|coef_fixed|gamma_status|mean_coef_status" R tests vignettes NEWS.md docs/design man _pkgdown.yml`
  -> PASS; intended hits only, apart from unrelated pre-existing `beta`
  comments in old tests.

## 7. Roadmap Tick

No `ROADMAP.md` edit in this slice. Validation-debt row `MIS-34` now records
native ML zero constraints as covered and admitted Julia fixed-effect-X zero
masks as covered, with REML, non-zero values, per-trait intercept pinning, and
unsupported Julia X families still partial or gated.

## 7a. GitHub Issue Ledger

- GLLVM.jl PR #114 was merged and used as the Julia-side dependency.
- No new gllvmTMB issue was created. This PR continues the already logged
  `MIS-34` fixed-zero coefficient lane.

## 8. What Did Not Go Smoothly

`pkgdown::build_article()` in a fresh process first picked up the older
installed user-library `gllvmTMB`, whose `gllvmTMB()` did not yet have
`Xcoef_fixed`. Rendering with `devtools::load_all()` and `new_process = FALSE`
confirmed the source article. The installed-package warning from
`devtools::check()` was local Apple-clang/R-header noise and was reproduced
with a temp-library `R CMD INSTALL`.

The live full `test-julia-bridge.R` under `GLLVM_JL_PATH` is not claimed green
here; older bridge parity failures remain outside this fixed-zero smoke.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: kept the slice narrow: one R API already existed, one Julia bridge
transport route, one article, and one validation-register update.

Boole and Emmy: the named-vector public API remains stable while the internal
bridge uses positional masks. The object now carries status fields back to R.

Noether and Fisher: this constrains the mean-structure coefficient vector, not
`Lambda`, `Psi`, latent rank, or response inclusion. The validation language
keeps that boundary explicit.

Pat and Darwin: the article leads with the practical reason: some predictors
belong to some response means and not others. It avoids making users interpret
this as automated variable selection.

Curie: tests cover both native TMB behavior and bridge routing. The live Julia
smoke specifically protects the one-fixed-coefficient edge case.

Rose: stale scans checked old Julia-gate language and overclaims such as
automatic deletion, guaranteed convergence, and variable selection.

Grace: pkgdown check passed; full tests passed; R CMD check has only known
local toolchain warning/note, not a package regression.

## 10. Known Limitations And Next Actions

- `Xcoef_fixed` still supports exact zero values only.
- `REML = TRUE` remains gated.
- Julia per-trait intercept pinning remains on the native TMB path for now.
- Unsupported Julia fixed-effect-X families remain gated.
- Full live Julia bridge parity still has older failures outside this slice;
  this PR claims only the new fixed-zero smoke.
