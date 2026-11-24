test_that("gllvmTMBcontrol consumers use declared or intentional fields", {
  r_dir <- gllvmTMB_pkg_file("R")

  files <- list.files(r_dir, pattern = "[.]R$", full.names = TRUE)
  ## These files use separate, local control objects rather than the public
  ## gllvmTMBcontrol() contract.
  files <- files[!basename(files) %in% c(
    "screen-gllvmTMB.R",
    ## screen-separation.R consumes the same screen_control() object as
    ## screen-gllvmTMB.R (its `control$separation_tolerance` is a documented
    ## screen_control() formal, not a gllvmTMBcontrol() field); the file was
    ## split out by 0d992c61 without joining this exclusion.
    "screen-separation.R",
    "va-r3-proto.R"
  )]
  source_text <- unlist(lapply(files, readLines, warn = FALSE))
  matches <- unlist(regmatches(
    source_text,
    gregexpr("control[$][A-Za-z_.][A-Za-z0-9_.]*", source_text)
  ))
  used <- unique(sub("^control[$]", "", matches))

  declared <- names(formals(gllvmTMBcontrol))
  ## These are deliberately derived/private fields populated by the fitting
  ## pipeline, not user arguments to gllvmTMBcontrol(). Keep the list explicit
  ## so a new undeclared public-control read fails this test.
  internal <- c(
    ".internal_continuation",
    "aghq_explicit",
    "aghq_ridge_explicit",
    "n_init_explicit",
    ## set by gllvmTMB() from missing(optimizer); consumed by va-routing.R
    "optimizer_explicit",
    ## developer-only, opt-in qualification hook (R/fit-multi.R, see the
    ## comment above `optimizer_diagnostics`); deliberately not a formal
    "optimizer_diagnostics",
    ## Parsed from the public `priors` table and carried internally to the
    ## Gaussian residual-scale objective; not a separate control argument.
    "residual_sd_prior",
    ## Set by gllvmTMBcontrol() while adapting the public `priors` argument;
    ## these are pipeline metadata, not separate user-facing control formals.
    "prior_table",
    "prior_table_resolved",
    ## Prevents a resolved table from being adapted a second time in one fit.
    "prior_table_adapted_from",
    ## Distinguishes an explicitly supplied loading_ridge alias from the
    ## historical aghq_ridge default during route admission.
    "loading_ridge_explicit",
    "svd_start_explicit",
    "aghq_start_par",
    "vgh_warm_start",
    "vgh_warm_start_fixed",
    "vgh_warm_start_maxit",
    "vgh_warm_start_z"
  )

  expect_setequal(setdiff(used, internal), intersect(used, declared))
  expect_true(all(internal %in% used))
})
