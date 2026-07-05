local_reset_lifecycle_cache <- function(env = parent.frame()) {
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

test_that("unique-family formula keywords emit soft lifecycle warnings", {
  withr::local_options(lifecycle_verbosity = "warning")
  local_reset_lifecycle_cache()

  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + unique(0 + trait | site)
    ),
    regexp = "deprecated|compatibility syntax"
  )
  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + phylo_unique(species)
    ),
    regexp = "deprecated|compatibility syntax"
  )
  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + animal_unique(id, A = A)
    ),
    regexp = "deprecated|compatibility syntax"
  )
  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + spatial_unique(0 + trait | coords)
    ),
    regexp = "deprecated|compatibility syntax"
  )
  expect_warning(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + kernel_unique(unit, K = K, name = "known")
    ),
    regexp = "deprecated|compatibility syntax"
  )
})

test_that("unique-family soft deprecation keeps compatibility rewrites", {
  withr::local_options(lifecycle_verbosity = "quiet")

  f_unique <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + unique(0 + trait | site)
  )
  expect_match(paste(deparse(f_unique), collapse = " "), "diag")

  f_phy <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + phylo_unique(species)
  )
  f_phy_txt <- paste(deparse(f_phy), collapse = " ")
  expect_match(f_phy_txt, "phylo_rr")
  expect_match(f_phy_txt, ".phylo_unique", fixed = TRUE)

  f_kernel <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + kernel_unique(unit, K = K, name = "known")
  )
  f_kernel_txt <- paste(deparse(f_kernel), collapse = " ")
  expect_match(f_kernel_txt, "phylo_rr")
  expect_match(f_kernel_txt, ".kernel_mode = \"unique\"", fixed = TRUE)
})

test_that("ordinary latent auto-emits Psi unless unique is FALSE", {
  withr::local_options(lifecycle_verbosity = "quiet")

  f_fold <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + latent(0 + trait | site, d = 2)
  )
  p_fold <- gllvmTMB:::parse_multi_formula(f_fold)
  expect_equal(
    vapply(p_fold$covstructs, `[[`, character(1), "kind"),
    c("rr", "diag")
  )
  expect_true(isTRUE(p_fold$covstructs[[2L]]$extra$.latent_psi))

  f_no_resid <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE)
  )
  p_no_resid <- gllvmTMB:::parse_multi_formula(f_no_resid)
  expect_equal(
    vapply(p_no_resid$covstructs, `[[`, character(1), "kind"),
    "rr"
  )
  expect_false("residual" %in% names(p_no_resid$covstructs[[1L]]$extra))
  expect_false("unique" %in% names(p_no_resid$covstructs[[1L]]$extra))
})

## The residual= -> unique= deprecation warning is asserted once in
## test-ordinary-latent-random-regression.R (the shared resolver
## .gllvmTMB_resolve_latent_unique). lifecycle throttles the warning once per
## session per id, so a second assertion elsewhere would be order-dependent;
## here we only check the alias maps to the no-Psi behaviour (warning silenced).
test_that("ordinary latent residual= alias maps to the unique = FALSE no-Psi fold", {
  withr::local_options(lifecycle_verbosity = "quiet")

  p_alias <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + latent(0 + trait | site, d = 2, residual = FALSE)
    )
  )
  expect_equal(
    vapply(p_alias$covstructs, `[[`, character(1), "kind"),
    "rr"
  )
})

test_that("ordinary latent Psi fold matches the explicit compatibility pair", {
  withr::local_options(lifecycle_verbosity = "quiet")
  df <- gllvmTMB::simulate_site_trait(
    n_sites = 25,
    n_species = 4,
    n_traits = 3,
    mean_species_per_site = 4,
    seed = 1715
  )$data

  fit_fold <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = df
  ))
  fit_pair <- suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data = df
  )))

  expect_equal(fit_fold$opt$convergence, 0L)
  expect_equal(fit_pair$opt$convergence, 0L)
  expect_true(fit_fold$use$rr_B)
  expect_true(fit_fold$use$diag_B)
  expect_equal(
    as.numeric(stats::logLik(fit_fold)),
    as.numeric(stats::logLik(fit_pair)),
    tolerance = 1e-8
  )
})
