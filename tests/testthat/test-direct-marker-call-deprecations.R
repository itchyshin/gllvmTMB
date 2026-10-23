## `meta_known_V()` and `kernel_unique()` are formula MARKERS: their bodies
## are never evaluated when the keyword appears inside a `~` formula (the
## formula parser recognises the call by name and desugars it directly).
## Both carry a `lifecycle::badge("deprecated")` in their roxygen, but their
## function bodies used to be silent -- calling either directly (outside a
## formula, e.g. a script or a test) returned `invisible(NULL)` with no
## warning at all. This file asserts the fix: each now fires
## `lifecycle::deprecate_soft()` once per session on a direct call, gated by
## the package's own `.gllvmTMB_deprecation_seen` one-shot tracker (the same
## pattern `.gllvmTMB_warn_scalar_family_deprecated()` and
## `.gllvmTMB_warn_latent_residual_alias()` use in R/brms-sugar.R).
##
## `kernel_unique()` used INSIDE a formula already warns via a separate,
## unrelated mechanism (`.gllvmTMB_warn_unique_family_deprecated()`, a
## cli_warn-based parser-time notice covered by
## test-unique-family-deprecation.R). That path is untouched here; this file
## covers only the direct-call path the parser cannot reach.

local_reset_lifecycle_cache <- function(env = parent.frame()) {
  ## Clear gllvmTMB's own env-based one-shot tracker so the direct-call
  ## notices added here can re-fire across tests / repeated file runs.
  seen <- tryCatch(
    get(".gllvmTMB_deprecation_seen", envir = asNamespace("gllvmTMB")),
    error = function(e) NULL
  )
  if (is.environment(seen)) {
    saved_seen <- as.list(seen, all.names = TRUE)
    withr::defer(
      {
        rlang::env_unbind(seen, rlang::env_names(seen))
        rlang::env_bind(seen, !!!saved_seen)
      },
      envir = env
    )
    rlang::env_unbind(seen, rlang::env_names(seen))
  }

  ## Also clear lifecycle's own internal per-session "already signalled"
  ## cache so deprecate_soft() treats the next call as fresh.
  dep_env <- tryCatch(
    get("deprecation_env", envir = asNamespace("lifecycle")),
    error = function(e) NULL
  )
  if (is.null(dep_env) || !is.environment(dep_env)) {
    return(invisible(NULL))
  }
  saved <- as.list(dep_env, all.names = TRUE)
  withr::defer(
    {
      rlang::env_unbind(dep_env, rlang::env_names(dep_env))
      rlang::env_bind(dep_env, !!!saved)
    },
    envir = env
  )
  rlang::env_unbind(dep_env, rlang::env_names(dep_env))
  invisible(NULL)
}

test_that("meta_known_V() warns once per session on a direct call", {
  withr::local_options(lifecycle_verbosity = "warning",
                       gllvmTMB.quiet_grammar_notes = FALSE)
  local_reset_lifecycle_cache()

  ## Fires on first direct use ...
  expect_warning(
    out1 <- gllvmTMB::meta_known_V(V = diag(3)),
    regexp = "deprecated|meta_V"
  )
  ## ... and is a one-shot, so a second direct call in the same session
  ## is silent.
  expect_no_warning(
    out2 <- gllvmTMB::meta_known_V(V = diag(3))
  )
  ## Do not change what the function returns.
  expect_null(out1)
  expect_null(out2)
})

test_that("kernel_unique() warns once per session on a direct call", {
  withr::local_options(lifecycle_verbosity = "warning",
                       gllvmTMB.quiet_grammar_notes = FALSE)
  local_reset_lifecycle_cache()

  K <- diag(3)
  expect_warning(
    out1 <- gllvmTMB::kernel_unique(unit, K = K, name = "known"),
    regexp = "deprecated|kernel_indep"
  )
  expect_no_warning(
    out2 <- gllvmTMB::kernel_unique(unit, K = K, name = "known")
  )
  expect_null(out1)
  expect_null(out2)
})

test_that("the direct-call marker deprecations respect the grammar-notes mute", {
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)
  local_reset_lifecycle_cache()

  expect_no_warning(gllvmTMB::meta_known_V(V = diag(3)))
  expect_no_warning(gllvmTMB::kernel_unique(unit, K = diag(3), name = "known"))
})
