## Regression tests for issue #1188.
##
## `.assert_no_augmented_lhs()` (R/brms-sugar.R) decided whether a bare
## covstruct keyword's LHS was the supported per-trait-intercept form
## `0 + trait | g` by comparing the LHS symbol against the STRING LITERAL
## `"trait"` -- never consulting the resolved `trait =` argument. A user
## who named their trait column something other than `"trait"` (e.g.
## `trait = "variable"`) could not write the CORRECT long-format spec
## `latent(0 + variable | unit, d = K)`; the guard misclassified it as an
## unsupported augmented LHS. See the issue for the external user this
## caused a wrong published analysis for (terrapin systematic map,
## https://github.com/itchyshin/gllvmTMB/issues/1188, reported by
## @iwogross).
##
## The fix threads the resolved `trait_col` through
## `desugar_brms_sugar()` -> `rewrite_canonical_aliases()` ->
## `.assert_no_augmented_lhs()`, which now accepts EITHER the resolved
## trait column name OR the literal `"trait"` (so existing code and every
## other fixture in the suite keep working). This file exercises three of
## the six call sites that share the fix (`latent`, `indep`, `scalar`).

## Fixture with the trait column renamed away from the literal "trait" --
## exactly the shape #1188 is about. Reuses simulate_site_trait()'s
## standard sites x species x traits cube.
make_renamed_trait_fixture <- function(seed = 1188L) {
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 3,
    mean_species_per_site = 4, seed = seed
  )
  df <- sim$data
  names(df)[names(df) == "trait"] <- "variable"
  df$temp <- stats::rnorm(nrow(df))
  df
}

## ---- 1. THE regression: a non-"trait" trait column must fit -------------

test_that("latent(0 + <user trait col> | unit, d = 1) fits when trait != \"trait\" (#1188)", {
  skip_on_cran()
  df <- make_renamed_trait_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + variable + latent(0 + variable | site, d = 1),
    data = df, unit = "site", trait = "variable"
  )))
  expect_s3_class(fit, "gllvmTMB")
  expect_equal(fit$opt$convergence, 0L)
})

## ---- 2. Literal "trait" spelling keeps working (no regression) ----------

test_that("the literal \"trait\" spelling still parses when trait = \"trait\" (#1188 no-regression)", {
  expect_no_error(gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + indep(0 + trait | site),
    trait_col = "trait"
  ))
})

## ---- 3. Genuinely unsupported augmented LHS still aborts (gate not widened) ----

test_that("indep() augmented-slope LHS still aborts for a non-literal trait column (#1188 does not widen the gate)", {
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + variable +
        indep(0 + variable + (0 + variable):temp | site),
      trait_col = "variable"
    ),
    regexp = "augmented LHS"
  )
})

## ---- 4. The abort message names the user's OWN trait column -------------
##
## The "you wrote ..." bullet always echoes the user's own call verbatim
## (via `deparse(bar)`), so it would mention "variable" even without the
## fix. The real regression is the "accepts only ..." bullet, which used
## to hardcode the literal "trait" -- assert on ITS interpolated text
## specifically (`0 + variable | g`), not just any occurrence of the
## trait name in the message.

test_that("the augmented-LHS abort's 'accepts only' bullet names the user's own trait column (#1188)", {
  err <- tryCatch(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + variable +
        indep(0 + variable + (0 + variable):temp | site),
      trait_col = "variable"
    ),
    error = function(e) e
  )
  expect_s3_class(err, "rlang_error")
  expect_match(
    conditionMessage(err),
    "0 + variable | g",
    fixed = TRUE
  )
  expect_no_match(
    conditionMessage(err),
    "0 + trait | g",
    fixed = TRUE
  )
})

## ---- 5. Third call site: scalar() also honours the resolved trait col ---

test_that("scalar(0 + <user trait col> | g) does not trip the augmented-LHS guard (#1188, third call site)", {
  expect_no_error(suppressWarnings(gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + variable + scalar(0 + variable | site),
    trait_col = "variable"
  )))
})
