.temporal_dep_phylo_lifecycle_fixture <- function() {
  data <- expand.grid(series = paste0("sp", 1:4), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  data$value <- with(data, as.numeric(factor(trait)) + .08 * occasion +
    c(sp1 = -.2, sp2 = .1, sp3 = .25, sp4 = -.05)[series] +
    c(m1 = -.03, m2 = .03)[measurement])
  Cphy <- matrix(c(1, .35, .15, .10, .35, 1, .25, .20,
    .15, .25, 1, .40, .10, .20, .40, 1), 4L, 4L, byrow = TRUE,
    dimnames = list(paste0("sp", 1:4), paste0("sp", 1:4)))
  list(data = data, Cphy = Cphy)
}

.temporal_dep_phylo_lifecycle_fit <- function(fx) {
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion,
      replicate = measurement) + phylo_indep(0 + trait | series, vcv = fx$Cphy),
    data = fx$data, unit = "series", cluster = "series", family = gaussian(),
    silent = TRUE, control = gllvmTMBcontrol(se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L)
  ))
}

test_that("temporal_dep-phylo bootstrap retains deterministic refit attempts", {
  skip_if_not_installed("TMB")
  fit <- .temporal_dep_phylo_lifecycle_fit(.temporal_dep_phylo_lifecycle_fixture())
  first <- bootstrap_temporal(fit, n_boot = 2L, seed = 260943L)
  second <- bootstrap_temporal(fit, n_boot = 2L, seed = 260943L)
  expect_identical(first, second)
  expect_identical(first$replicate, 1:2)
  expect_true(all(is.finite(first$seed)))
  expect_true(all(is.finite(first$objective) | nzchar(first$error)))
})

test_that("temporal_dep-phylo profile targets persistence and rejects iid lincomb", {
  skip_if_not_installed("TMB")
  fit <- .temporal_dep_phylo_lifecycle_fit(.temporal_dep_phylo_lifecycle_fixture())
  theta <- fit$opt$par[[match("theta_temporal_time", names(fit$opt$par))]]
  profiled <- profile_temporal(fit, ystep = .1, ytol = 1,
    parm.range = theta + c(-.01, .01))
  estimate <- (1 - 1e-6) * tanh(fit$tmb_obj$env$parList(fit$opt$par)$theta_temporal_time)
  expect_equal(profiled[["estimate"]], estimate, tolerance = 1e-10)
  expect_error(profile_temporal(fit, lincomb = c(1, rep(0, length(fit$opt$par) - 1L))),
    "lincomb.*not supported")
})
