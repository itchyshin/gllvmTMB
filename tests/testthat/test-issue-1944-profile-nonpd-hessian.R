## refs #1944 — profile confint must not return finite bounds when pdHess is FALSE.

.issue_1944_fit <- function() {
  set.seed(53L)
  Tn <- 3L
  n <- 30L
  Lam <- matrix(stats::rnorm(Tn * 2L, 0.4), Tn, 2L)
  U <- matrix(stats::rnorm(n * Tn), n, Tn) %*%
    t(chol(Lam %*% t(Lam) + diag(0.25, Tn)))
  df <- expand.grid(trait_idx = seq_len(Tn), unit = seq_len(n))
  df$site <- factor(df$unit)
  df$trait <- factor(
    paste0("t", df$trait_idx),
    levels = paste0("t", seq_len(Tn))
  )
  df$value <- stats::rpois(
    nrow(df),
    lambda = exp(0.3 + U[cbind(df$unit, df$trait_idx)])
  )
  suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = df,
    unit = "site",
    family = stats::poisson()
  ))
}

test_that("profile confint is NA when pdHess is FALSE", {
  skip_on_cran()
  fit <- .issue_1944_fit()
  expect_equal(fit$opt$convergence, 0L)
  expect_false(isTRUE(fit$sd_report$pdHess))
  wald <- confint(fit, method = "wald")
  expect_true(all(is.na(wald)))
  expect_warning(
    prof <- confint(fit, method = "profile", parm = "traitt1"),
    class = "gllvmTMB_profile_nonpd_hessian"
  )
  expect_true(all(is.na(prof)))
})