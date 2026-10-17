test_that("nested fits restore the outer spatial notice context", {
  skip_if_not_installed("fmesher")
  withr::local_options(gllvmTMB.quiet_grammar_notes = FALSE)
  state <- getNamespace("gllvmTMB")$.gllvmTMB_spatial_token_consumed
  previous <- state$token
  withr::defer(state$token <- previous)
  state$token <- "enclosing-fit"

  tracker <- getNamespace("gllvmTMB")$.gllvmTMB_deprecation_seen
  key <- "spatial-grouping-token-spatial_latent"
  existed <- exists(key, envir = tracker, inherits = FALSE)
  old_notice <- if (existed) get(key, envir = tracker) else NULL
  withr::defer({
    if (existed) assign(key, old_notice, envir = tracker)
    else if (exists(key, envir = tracker, inherits = FALSE))
      rm(list = key, envir = tracker)
  })
  if (existed) rm(list = key, envir = tracker)

  fx <- .rho_spatial_fixture()
  mesh <- fx$mesh
  original <- getFromNamespace("desugar_brms_sugar", "gllvmTMB")
  nested <- FALSE
  observed <- list()
  local_mocked_bindings(desugar_brms_sugar = function(...) {
    if (!nested) {
      nested <<- TRUE
      observed$before <<- state$token
      # Exercise a real nested public entry call. The payload helper stops
      # before optimization and unwinds through the inner on.exit handlers.
      .rho_capture_payload(y ~ 0 + trait + indep(0 + trait | group), fx$data)
      observed$after <<- state$token
    }
    original(...)
  }, .package = "gllvmTMB")

  expect_no_warning(
    .rho_capture_payload(
      y ~ 0 + trait + spatial_latent(0 + trait | group, mesh = mesh,
                                    d = 1, unique = TRUE, rho = NULL),
      fx$data
    ),
    message = "grouping token is ignored"
  )
  expect_true(nested)
  expect_identical(observed$before, "group")
  expect_identical(observed$after, "group")
  expect_identical(state$token, "enclosing-fit")
})

test_that("an observed coords column is a valid spatial rho location identifier", {
  skip_if_not_installed("fmesher")
  withr::local_options(gllvmTMB.quiet_grammar_notes = FALSE)
  fx <- .rho_spatial_fixture()
  fx$data$coords <- fx$data$group
  mesh <- fx$mesh
  for (rho in c("0.5", "NULL")) {
    reference <- .rho_capture_payload(as.formula(paste0(
      "y ~ 0 + trait + spatial_latent(0 + trait | group, mesh = mesh, ",
      "d = 1, unique = TRUE, rho = ", rho, ")"
    )), fx$data)
    expect_warning(
      actual <- .rho_capture_payload(as.formula(paste0(
        "y ~ 0 + trait + spatial_latent(0 + trait | coords, mesh = mesh, ",
        "d = 1, unique = TRUE, rho = ", rho, ")"
      )), fx$data),
      regexp = "Unused optional grouping argument"
    )
    expect_identical(actual$data$spatial_rho_group_id,
                     reference$data$spatial_rho_group_id)
  }
})
