## profile_cross_rho() must not pick best_rho from a refit that did not
## converge or has a non-PD Hessian (#1358).

.cross_rho_health_inputs <- function() {
  A_H <- diag(2)
  A_P <- diag(2)
  rownames(A_H) <- colnames(A_H) <- c("H1", "H2")
  rownames(A_P) <- colnames(A_P) <- c("P1", "P2")
  W <- matrix(c(1, 0.2, 0.2, 1), 2, 2,
              dimnames = list(rownames(A_H), rownames(A_P)))
  list(A_H = A_H, A_P = A_P, W = W)
}

## Fake fit with a controlled logLik and health flags.
.cross_rho_fake_fit <- function(ll, convergence = 0L, pd = TRUE) {
  structure(
    list(ll = ll, opt = list(convergence = convergence),
         fit_health = list(pd_hessian = pd)),
    class = "fake_cross_rho_fit"
  )
}
logLik.fake_cross_rho_fit <- function(object, ...) object$ll

test_that("profile_cross_rho ignores a non-converged grid point when picking best_rho", {
  registerS3method("logLik", "fake_cross_rho_fit", logLik.fake_cross_rho_fit)
  x <- .cross_rho_health_inputs()
  ll <- c(`0` = -10, `0.25` = -8, `0.5` = -3) # highest logLik is the bad fit
  prof <- gllvmTMB::profile_cross_rho(
    x$A_H, x$A_P, x$W, rho = c(0, 0.25, 0.5),
    refit = function(K, rho) {
      .cross_rho_fake_fit(ll[[as.character(rho)]],
                          convergence = if (rho == 0.5) 1L else 0L)
    }
  )
  expect_equal(attr(prof, "best_rho"), 0.25)
  expect_equal(prof$is_best, c(FALSE, TRUE, FALSE))
  expect_equal(prof$status, c("ok", "ok", "unhealthy_fit"))
  expect_true(is.na(prof$delta_deviance[3]))
  expect_equal(prof$delta_deviance[1:2], c(4, 0))
})

test_that("profile_cross_rho ignores a non-PD Hessian grid point", {
  registerS3method("logLik", "fake_cross_rho_fit", logLik.fake_cross_rho_fit)
  x <- .cross_rho_health_inputs()
  ll <- c(`0` = -10, `0.25` = -3, `0.5` = -8)
  prof <- gllvmTMB::profile_cross_rho(
    x$A_H, x$A_P, x$W, rho = c(0, 0.25, 0.5),
    refit = function(K, rho) {
      .cross_rho_fake_fit(ll[[as.character(rho)]], pd = rho != 0.25)
    }
  )
  expect_equal(attr(prof, "best_rho"), 0.5)
  expect_equal(prof$is_best, c(FALSE, FALSE, TRUE))
})

test_that("profile_cross_rho warns and falls back when no grid point is healthy", {
  registerS3method("logLik", "fake_cross_rho_fit", logLik.fake_cross_rho_fit)
  x <- .cross_rho_health_inputs()
  ll <- c(`0` = -10, `0.5` = -3)
  expect_warning(
    prof <- gllvmTMB::profile_cross_rho(
      x$A_H, x$A_P, x$W, rho = c(0, 0.5),
      refit = function(K, rho) {
        .cross_rho_fake_fit(ll[[as.character(rho)]], convergence = 1L)
      }
    ),
    "positive-definite Hessian"
  )
  expect_equal(attr(prof, "best_rho"), 0.5)
})
