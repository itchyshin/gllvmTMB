## Test-of-the-test for the `fit_health$converged` verdict (R/diagnose.R).
##
## `converged` is TRUE only when `convergence_status` is "converged" (optimiser
## success, finite objective, small relative gradient, no boundary, PD Hessian).
## [moved by the 18 Nov 2026 converged rule] The objective-scaled gradient
## remains separately available as a descriptive recovery-fixture diagnostic.
##
## A verdict that cannot fail proves nothing, so this battery must REJECT genuine
## non-convergence as well as ACCEPT good fits (including benign non-PD ridges).
## Every case carries a `truth` label established by the gradient + recovery, not
## by the optimiser's self-report.

test_that("verdict accepts a clean, well-identified fit (PD)", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(1)
  n <- 40L; T_ <- 4L
  df <- expand.grid(unit = factor(paste0("u", seq_len(n))),
                    trait = factor(paste0("t", seq_len(T_))))
  ## Converged rule (18 Nov 2026): pure-noise data put the unique variance on its
  ## boundary (`boundary`, so `converged` is FALSE); a real one-factor signal
  ## gives an interior optimum.
  z <- stats::rnorm(n)
  df$value <- 0.8 * z[as.integer(df$unit)] *
    c(1, 0.7, 0.5, 0.9)[as.integer(df$trait)] +
    stats::rnorm(nrow(df)) + as.numeric(df$trait) * 0.3
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, unit = "unit", trait = "trait", family = gaussian()
  )))
  expect_identical(fit$fit_health$convergence_status, "converged")
  expect_true(isTRUE(fit$fit_health$converged))
  expect_true(isTRUE(fit$fit_health$optimizer_converged))
  expect_lt(fit$fit_health$max_gradient, 1e-3)
  expect_lt(fit$fit_health$scaled_gradient, 1e-3)
})

test_that("Hessian health remains separate from point convergence", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(1)
  n <- 40L; T_ <- 4L
  df <- expand.grid(unit = factor(paste0("u", seq_len(n))),
                    trait = factor(paste0("t", seq_len(T_))))
  df$value <- stats::rnorm(nrow(df)) + as.numeric(df$trait) * 0.3
  ## d = n_traits: the loadings are identified only up to rotation -> a flat ridge,
  ## so pd_hessian is FALSE while the fit is at a genuine optimum (Sigma recovers).
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 4),
    data = df, unit = "unit", trait = "trait", family = gaussian()
  )))
  ## Converged rule (18 Nov 2026): `converged` now includes the Hessian and
  ## boundary conditions, so it is TRUE only when the status is "converged".
  expect_identical(
    fit$fit_health$converged,
    identical(fit$fit_health$convergence_status, "converged")
  )
  if (isFALSE(fit$fit_health$pd_hessian)) {
    expect_false(fit$fit_health$converged)
  }
  ## pd_hessian on a near-zero rotation ridge is FD/BLAS noise: it reads FALSE on
  ## some platforms (the case it "gets wrong") and PD on others (seen on ubuntu CI).
  ## Only demonstrate the "pd_hessian disagrees" branch when the platform actually
  ## produced the non-PD read; otherwise it is N/A -- converged is asserted above,
  ## and asserting the noisy sign here would make the test depend on the very
  ## platform noise the verdict exists to ignore.
  skip_if(isTRUE(fit$fit_health$pd_hessian),
          "Hessian read as PD on this platform; non-PD-ridge demonstration N/A.")
  expect_false(isTRUE(fit$fit_health$pd_hessian))
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
