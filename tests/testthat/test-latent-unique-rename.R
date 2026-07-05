## Tests for the latent() `residual` -> `unique` argument rename (PR A).
##
## `unique = TRUE/FALSE` is the canonical argument (matches
## extract_Sigma(part = "unique")); `residual =` is retained as a one-shot
## soft-deprecated alias. The internal auto-companion marker is `.auto_unique`
## (was `.auto_residual`). Semantics are unchanged:
##   unique = TRUE  -> Sigma_level = Lambda Lambda^T + Psi (auto diag companion)
##   unique = FALSE -> Lambda Lambda^T only (rank-deficient, rotation-invariant)

## Minimal reset of gllvmTMB's own one-shot warning tracker so the
## soft-deprecation alias warning re-fires within this session. (The alias
## warning uses the package env tracker + cli_warn, not lifecycle::deprecate_soft.)
reset_gllvmTMB_dep_seen <- function(env = parent.frame()) {
  seen <- tryCatch(
    get(".gllvmTMB_deprecation_seen", envir = asNamespace("gllvmTMB")),
    error = function(e) NULL
  )
  if (is.environment(seen)) {
    saved <- as.list(seen, all.names = TRUE)
    withr::defer(
      {
        rlang::env_unbind(seen, rlang::env_names(seen))
        rlang::env_bind(seen, !!!saved)
      },
      envir = env
    )
    rlang::env_unbind(seen, rlang::env_names(seen))
  }
  invisible(NULL)
}

test_that("latent(unique = FALSE) desugars to loadings-only (no auto-Psi)", {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  f <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE)
  )
  p <- gllvmTMB:::parse_multi_formula(f)
  expect_equal(
    vapply(p$covstructs, `[[`, character(1), "kind"),
    "rr"
  )
})

test_that("latent(unique = TRUE) auto-emits the Psi companion marked .auto_unique", {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  f <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = TRUE)
  )
  p <- gllvmTMB:::parse_multi_formula(f)
  expect_equal(
    vapply(p$covstructs, `[[`, character(1), "kind"),
    c("rr", "diag")
  )
  expect_true(isTRUE(p$covstructs[[2L]]$extra$.auto_unique))
})

test_that("latent(residual = ) is a soft-deprecated alias: warns once and still works", {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = FALSE,
    lifecycle_verbosity = "warning"
  )
  reset_gllvmTMB_dep_seen()
  expect_warning(
    f <- gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + latent(0 + trait | site, d = 2, residual = FALSE)
    ),
    regexp = "renamed|soft-deprecated alias"
  )
  ## residual = FALSE remains an alias of unique = FALSE -> loadings-only.
  p <- gllvmTMB:::parse_multi_formula(f)
  expect_equal(
    vapply(p$covstructs, `[[`, character(1), "kind"),
    "rr"
  )
})

test_that("latent() errors when both unique= and residual= are supplied", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  expect_error(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait +
        latent(0 + trait | site, d = 1, unique = TRUE, residual = TRUE)
    ),
    regexp = "both|conflict|only one"
  )
})
