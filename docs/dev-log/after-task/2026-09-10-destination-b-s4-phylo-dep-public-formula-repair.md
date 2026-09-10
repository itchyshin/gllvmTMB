# After Task: Destination B S4 `phylo_dep` public-formula repair

**Branch:** `codex/destination-b-s4-phylo-dep-formula-20260910`  
**Date:** 2026-09-10  
**Roles:** Ada, Hopper, Noether, Rose

## 1. Goal

Repair the approved S4 public Gaussian Tree formula boundary without widening
the generic R-to-Julia engine route:

```r
traits(trait_1, trait_2) ~ 1 + phylo_dep(1 | species, tree = tree)
```

## 2. Implemented

`gllvm_julia_phylo_rr()` now accepts exactly the two-trait,
full-covariance `phylo_dep` Tree cell (`d_phy = n_traits = 2`) in addition to
the older rank-one Tree exception. The generic `gllvmTMB(..., engine =
"julia")` gate is unchanged.

Julia emits its seven interval targets in an internal order where the first
shared residual variance precedes the second phylogenetic covariance diagonal.
The R reader now validates the complete named payload and reorders it by name
to the public contract:

```text
beta[1], beta[2], phylo_cov[1,1], phylo_cov[2,1], phylo_cov[2,2],
residual_var_shared[1], residual_var_shared[2]
```

## 3. Mathematical and evidence check

The native TMB loading vector packs the two diagonal entries before the strict
lower-triangle entry: `L11, L22, L21`. An earlier ad hoc endpoint comparison
mistook that order for `L11, L21, L22`; it was therefore discarded. The live
test evaluates the native reported `Sigma_phy` transformation directly and
uses the native observed fixed-parameter covariance for the delta method. It
uses log-Wald intervals for positive covariance diagonals and the shared
residual variance, and identity-Wald intervals for coefficients and the signed
covariance off-diagonal.

The controlled 2-trait/3-tip/3-observation-per-tip Gaussian fixture passed:
native and Julia covariance entries agree within the documented `5e-6`
absolute paired tolerance, and all seven 90% transformed-Wald endpoints agree
within `1e-4`. The covariance threshold is based on the observed maximum
component difference of approximately `9e-7` between independent optimizers;
it is not a tolerance relaxation for a failed equality check.

## 4. Files changed

- `R/julia-bridge.R`
- `man/gllvm_julia_phylo_rr.Rd`
- `vignettes/articles/current-limits.Rmd`
- `_pkgdown.yml`
- `tests/testthat/test-julia-phylo-rr-bridge.R`
- `docs/dev-log/check-log.md`
- this report

## 5. Checks run

```sh
Rscript --vanilla -e \
  'devtools::test_active_file("tests/testthat/test-julia-phylo-rr-bridge.R", reporter = "summary")'
# focused source/mocked suite passed; five opt-in checks skipped

GLLVM_S4_LIVE_FORMULA_TESTS=1 \
GLLVM_DESTINATION_B_PROJECT=/private/tmp/destination-b-b1-integration-20260910 \
GLLVM_S4_JULIA_HOME=/Users/z3437171/.juliaup/bin \
Rscript --vanilla -e \
  'devtools::test_active_file("tests/testthat/test-julia-phylo-rr-bridge.R", reporter = "summary")'
# public formula paired test passed in 29.8 s; four unrelated S3b opt-in checks skipped

Rscript --vanilla -e \
  'devtools::document(quiet = TRUE); tools::parse_Rd("man/gllvm_julia_phylo_rr.Rd")'
# Rd parse: OK

git diff --check
# clean
```

`pkgdown::check_pkgdown()` initially failed because the already exported
`gllvm_julia_phylo_rr` topic was absent from the Experimental Julia bridge
reference index. Adding that one topic fixed the root cause; the rerun returned
`No problems found`. `pkgdown::build_article("articles/current-limits",
lazy = FALSE)` then rendered the updated limitations article successfully. The
full article batch was not used as evidence because it exceeded the short
interactive window before reaching this changed page.

## 6. Consistency audit and tests of the tests

The following exact searches were run:

```sh
rg -n 'gllvm_julia_phylo_rr|engine = "julia"|phylo_rr|0\\.7 parity|FRK' README.md ROADMAP.md NEWS.md docs/design docs/dev-log/known-limitations.md vignettes R
rg -n 'gllvm_julia_phylo_rr|phylo_dep\\(1 \\| species' README.md ROADMAP.md NEWS.md docs/design docs/dev-log/known-limitations.md vignettes R man
```

Verdict: the only user-facing prior wording that named the post-fit exception
was `current-limits.Rmd`; it now names both narrow Tree cells and preserves the
generic-engine, coverage, parity, and FRK exclusions. `README.md`,
`ROADMAP.md`, and `NEWS.md` make no conflicting promotion claim. The pkgdown
reference index now lists the exported bridge surface under Experimental Julia
bridge.

The tests are not happy-path-only. The initial rank-one public gate rejected
the new two-trait cell before the repair; the mocked regression checks the
interleaved interval order; hostile structured-term and exact-target tests
exercise rejection; and the direct generic-engine test verifies that the same
public `phylo_dep` formula remains refused outside the post-fit exception.

## 7. Review and team learning

**Ada:** kept formula repair, package-index repair, and landing-page deployment
separate. The local site can be rendered without implying publication.

**Hopper:** caught the native packed-loading convention (`L11, L22, L21`) and
replaced a guessed coordinate transform with the native reported covariance
transformation.

**Noether:** checked that the target remains full phylogenetic covariance plus
a shared residual variance, rather than a residual covariance or a generic
structured model.

**Rose:** independent review caught the stale `ci_param_names` alias and the
too-broad structural proxy before closure. Both now fail closed and have direct
regressions.

## 8. Roadmap and issue ledger

**Roadmap tick:** N/A. This repairs one explicitly bounded public interface; it
does not promote a Destination B or parity row.

**GitHub issue ledger:** no issue action. FRK remains parked at
`gllvmTMB#1275`; no new issue was necessary for the local formula/reader
repair.

## 9. Limitations and next action

This is an experimental, post-fit R-to-Julia bridge cell, not 0.7 parity. It
does not admit the generic engine, dense `vcv` or pedigree through this public
Tree route, other families, prediction, recovery, coverage, or FRK.

The local Julia environment still emits a `LogExpFunctions` extension-load
error before JuliaCall continues. The successful paired call does not make
that environment message acceptable for a release. Before promoting the S4
row, retain a fresh write-once receipt that binds this exact clean source,
frozen R binary, Julia commit, fixture hash, and all seven endpoints; resolve
or isolate that extension problem for the release environment.

No push, merge, release, registry action, or R/C++ likelihood change occurred.
