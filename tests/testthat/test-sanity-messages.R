test_that("sanity status messages can be suppressed without losing flags", {
  ## An objective-only fixture exercises diagnostics without a compiled fit.
  sanity <- sanity_multi
  fixture_env <- new.env(parent = environment(sanity))
  fixture_env$.gllvmTMB_is_mspl <- function(x) FALSE
  fixture_env$.gllvmTMB_penalised_gradient <- function(...) c(0, 0)
  fixture_env$.gllvmTMB_b_fix_se <- function(x) c(0.1, 0.2)
  environment(sanity) <- fixture_env
  fit <- structure(list(
    opt = list(convergence = 0L, par = c(0, 0)),
    tmb_obj = list(), aghq = list(),
    sd_report = list(pdHess = TRUE),
    use = list(rr_B = FALSE, rr_W = FALSE)
  ), class = "gllvmTMB_multi")

  messages <- character()
  stdout <- capture.output(flags <- withCallingHandlers(
    sanity(fit), message = function(cnd) {
      messages <<- c(messages, conditionMessage(cnd))
      invokeRestart("muffleMessage")
    }
  ))
  expect_length(stdout, 0L)
  expect_match(paste(messages, collapse = ""), "Optimiser convergence")
  expect_match(paste(messages, collapse = ""), "Hessian positive-definite")
  expect_true(flags$converged)
  expect_true(flags$pd_hessian)
  expect_equal(flags$max_se, 0.2)
  expect_output(quiet <- suppressMessages(sanity(fit)), NA)
  expect_identical(quiet, flags)
})
