test_that("gllvmTMBcontrol consumers use declared or intentional fields", {
  r_dir <- testthat::test_path("..", "..", "R")
  skip_if_not(
    dir.exists(r_dir),
    "Repository source is unavailable after package installation"
  )

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
    "aghq_ridge_explicit",
    "aghq_start_par",
    "vgh_warm_start",
    "vgh_warm_start_fixed",
    "vgh_warm_start_maxit",
    "vgh_warm_start_z"
  )

  expect_setequal(setdiff(used, internal), intersect(used, declared))
  expect_true(all(internal %in% used))
})
