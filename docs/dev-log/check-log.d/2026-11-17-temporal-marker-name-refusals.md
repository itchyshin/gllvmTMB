# Check-log: temporal parser marker_name refusals (refs #TBD)

**Goal:** Confirm two-trait `temporal_indep()` / `temporal_dep()` refusals name the marker that was used, and that `temporal_latent()` wording is unchanged.

**Commands:**

```sh
# origin/main fc80be9ee232692a64dfef7f8570ce7a1528b861, installed package:
Rscript --vanilla -e '... two-trait temporal_indep gllvmTMB() ...'

R_LIBS_USER="$HOME/R/library" Rscript --vanilla -e 'pkgload::load_all(".", compile = FALSE); testthat::test_file("tests/testthat/test-temporal-marker-name-refusals.R")'
R_LIBS_USER="$HOME/R/library" Rscript --vanilla -e 'pkgload::load_all(".", compile = FALSE); testthat::test_file("tests/testthat/test-temporal-ar1-parser.R")'
NOT_CRAN=true R_LIBS_USER="$HOME/R/library" Rscript --vanilla -e 'pkgload::load_all(".", compile = FALSE); ...'
# files: test-temporal-ar1-methods.R, test-temporal-sixth-source-api.R,
# test-temporal-sixth-source-regressions.R, test-temporal-refusal-classes.R,
# test-1392-temporal-help-preconditions.R

rg -n '\{[.]fn temporal_latent\}|\{[.]fn \{marker_name\}\}' R/temporal.R
rg -n 'requires at least three traits' R tests NEWS.md
rg -n 'Fixes |Closes |Resolves ' NEWS.md docs/dev-log/after-task/2026-11-17-temporal-marker-name-refusals.md docs/dev-log/check-log.d/2026-11-17-temporal-marker-name-refusals.md
rg -n 'nocov' R/temporal.R tests/testthat/test-temporal-marker-name-refusals.R
```

**Results:**

- origin/main `fc80be9e`, two-trait `temporal_indep(0 + trait | series, time = occasion)` `gllvmTMB()` abort:
  `` `temporal_latent()` requires at least three traits. ``
  plus the default action pointing at `?temporal_latent`.
- After the fix, the same call's first line is
  `` `temporal_indep()` requires at least three traits. ``
  The matching `temporal_latent()` two-trait first line remains
  `` `temporal_latent()` requires at least three traits. ``
- `test-temporal-marker-name-refusals.R`: FAIL 0 / SKIP 0 / PASS 32
- `test-temporal-ar1-parser.R`: FAIL 0 / SKIP 0 / PASS 12
- `test-temporal-ar1-methods.R`: FAIL 0 / SKIP 0 / PASS 20
- `test-temporal-sixth-source-api.R`: FAIL 0 / SKIP 0 / PASS 14
- `test-temporal-sixth-source-regressions.R`: FAIL 0 / SKIP 0 / PASS 7
- `test-temporal-refusal-classes.R` with `NOT_CRAN=true`: FAIL 0 / SKIP 0 / PASS 30
- `test-1392-temporal-help-preconditions.R`: FAIL 0 / SKIP 0 / PASS 16
- `rg` `{.fn temporal_latent}` in `R/temporal.R`: constructor `d != 1` (line 24) and method-not-available (line 468) only. Parser refusals use `{.fn {marker_name}}`.
- `rg` closing keywords on this slice's NEWS/after-task/check-log: none (`NEWS.md:1460` is an older "Fixes include:" sentence).
- `rg` nocov on the touched R/test files: no matches.

**Not run:** `devtools::check()`, `pkgdown::check_pkgdown()`, and `GLLVMTMB_TEST_SHARD=3/4` (the new file lands in shard 3 of 4 among 789 test files). The VM lacked several Suggests (`tidyr`, `devtools`, `ape`); two pre-existing files failed here for those reasons (`test-temporal-ar1-regressions.R` traits() rewrite, `test-temporal-ar1-verify-runner.R` loadNamespace('devtools')), not because of this slice. Heavy temporal program/oracle/engine files were not run.

**Claim boundary:** This is an error-text change in `.parse_temporal_latent_formula()`. It does not admit two-trait temporal models, does not change the likelihood, and does not change GLLVModels.jl. The default `.temporal_abort()` action still names `temporal_latent()` help. Later `gllvmTMB()` temporal gates in `R/gllvmTMB.R` still hard-code `temporal_latent()`.
