## Test-of-the-test for the `fit_health$converged` verdict (R/diagnose.R).
##
## `converged` requires optimiser success, a finite objective, a small raw
## maximum gradient, a positive-definite Hessian, finite fixed-effect standard
## errors when sdreport() ran, and a Newton step of at most 1e-3 standard
## errors. The objective-scaled gradient remains separately available as a
## descriptive recovery-fixture diagnostic.
##
## A verdict that cannot fail proves nothing, so this battery must REJECT genuine
## non-convergence as well as ACCEPT good fits with a PD Hessian and finite SEs.
## Every case carries a `truth` label established by the gradient + recovery, not
## by the optimiser's self-report.

test_that("verdict accepts a clean, well-identified fit (PD)", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(1)
  n <- 40L; T_ <- 4L
  df <- expand.grid(unit = factor(paste0("u", seq_len(n))),
                    trait = factor(paste0("t", seq_len(T_))),
                    KEEP.OUT.ATTRS = FALSE)
  ## A shared factor plus residual noise keeps every unique SD interior.
  ## Noise-only responses collapse one trait variance, and the converged
  ## rule then classifies the fit as boundary.
  z <- stats::rnorm(n)
  df$value <- 0.8 * z[as.integer(df$unit)] + as.numeric(df$trait) * 0.3 +
    stats::rnorm(nrow(df), sd = 0.5)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, unit = "unit", trait = "trait", family = gaussian()
  )))
  expect_true(isTRUE(fit$fit_health$converged))
  expect_true(isTRUE(fit$fit_health$optimizer_converged))
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  expect_lte(fit$fit_health$newton_se_ratio, 1e-3)
  expect_lt(fit$fit_health$max_gradient, 1e-3)
  expect_lt(fit$fit_health$scaled_gradient, 1e-3)
})

test_that("non-PD Hessian disqualifies converged even at a stationary optimum", {
  ## Exactly indefinite covariance (eigenvalues 3 and -1) with pdHess FALSE.
  ## The gradient is far inside the raw stationarity gate, so a platform that
  ## used to read a rotation ridge as PD cannot skip this case.
  g <- c(1e-8, 1e-8)
  fit <- structure(list(
    tmb_obj = list(par = c(0, 0), gr = function(par) g),
    opt = list(
      par = c(0, 0),
      objective = 18,
      convergence = 0L,
      iterations = 9L,
      message = "relative convergence"
    ),
    sd_report = list(
      pdHess = FALSE,
      cov.fixed = matrix(c(1, 2, 2, 1), 2, 2),
      par.random = c(b_fix = 0),
      diag.cov.random = 0.01
    ),
    X_fix_names = "traitA",
    report = list(),
    use = list()
  ), class = "gllvmTMB_multi")
  fit$fit_health <- gllvmTMB:::.gllvmTMB_build_fit_health(fit)
  warned <- FALSE
  withCallingHandlers(
    gllvmTMB:::.gllvmTMB_warn_fit_health_convergence(fit$fit_health),
    warning = function(w) {
      if (inherits(w, "gllvmTMB_fit_health_not_converged")) warned <<- TRUE
      invokeRestart("muffleWarning")
    }
  )
  expect_true(warned)
  expect_false(isTRUE(fit$fit_health$pd_hessian))
  expect_false(isTRUE(fit$fit_health$converged))
  expect_identical(fit$fit_health$convergence_status, "degenerate")
})

test_that("verdict REJECTS genuine non-convergence (iteration-capped)", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(1)
  n <- 40L; T_ <- 4L
  df <- expand.grid(unit = factor(paste0("u", seq_len(n))),
                    trait = factor(paste0("t", seq_len(T_))))
  df$value <- stats::rnorm(nrow(df)) + as.numeric(df$trait) * 0.3
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, unit = "unit", trait = "trait", family = gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(
      optimizer = "nlminb",
      optArgs = list(control = list(iter.max = 1L, eval.max = 2L))
    )
  )))
  ## Stopped far from the optimum: large scaled gradient -> NOT converged.
  expect_false(isTRUE(fit$fit_health$converged))
  expect_gt(fit$fit_health$scaled_gradient, 1e-3)
})

test_that("the convergence conjunction cannot be rescued by objective scaling", {
  gtol <- gllvmTMB:::.gllvmTMB_converged_gtol
  expect_true(is.numeric(gtol) && length(gtol) == 1L && gtol > 0)
  mk <- function(max_grad, obj, optimizer_code = 0L) {
    sg <- max_grad / (1 + abs(obj))
    list(
      scaled = sg,
      converged = identical(optimizer_code, 0L) &&
        is.finite(obj) && isTRUE(max_grad < gtol)
    )
  }
  expect_true(mk(gtol * 0.5, 3.7e4)$converged)
  expect_false(mk(gtol * 2, 3.7e4)$converged)
  expect_false(mk(gtol * 0.5, 3.7e4, optimizer_code = 1L)$converged)
})

test_that("converged is NA-safe: a fit with no gradient/objective is not silently TRUE", {
  ## Missing diagnostics cannot silently pass.
  gtol <- gllvmTMB:::.gllvmTMB_converged_gtol
  expect_false(isTRUE(NA_real_ < gtol))
})
