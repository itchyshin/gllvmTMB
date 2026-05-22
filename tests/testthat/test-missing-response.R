test_that("long-format response NA rows are dropped before fitting", {
  set.seed(71)
  long <- gllvmTMB::simulate_site_trait(
    n_sites = 24,
    n_species = 1,
    n_traits = 3,
    mean_species_per_site = 1,
    seed = 71
  )$data
  missing_rows <- c(2L, 17L, 55L)
  long$value[missing_rows] <- NA_real_
  weights <- seq(1, 2, length.out = nrow(long))

  msgs <- character()
  withCallingHandlers(
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site),
      data = long,
      weights = weights,
      control = gllvmTMBcontrol(se = FALSE)
    )),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  keep <- !is.na(long$value)
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(nrow(fit$data), sum(keep))
  expect_false(anyNA(fit$tmb_data$y))
  expect_equal(fit$tmb_data$weights_i, weights[keep], tolerance = 1e-12)
  expect_true(
    any(grepl("\\b3\\b", msgs) & grepl("(?i)dropp", msgs, perl = TRUE)),
    info = paste(msgs, collapse = " | ")
  )
})

test_that("cbind binomial response rows are dropped when either component is NA", {
  set.seed(72)
  n <- 60
  dat <- data.frame(
    site = factor(rep(seq_len(20), each = 3)),
    trait = factor(rep(paste0("trait_", seq_len(3)), times = 20)),
    succ = stats::rbinom(n, size = 6, prob = 0.45)
  )
  dat$fail <- 6L - dat$succ
  dat$succ[4L] <- NA_integer_
  dat$fail[29L] <- NA_integer_

  msgs <- character()
  withCallingHandlers(
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      cbind(succ, fail) ~ 0 +
        trait +
        latent(0 + trait | site, d = 1) +
        unique(0 + trait | site),
      data = dat,
      family = binomial(),
      control = gllvmTMBcontrol(se = FALSE)
    )),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )

  keep <- stats::complete.cases(dat[, c("succ", "fail")])
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(nrow(fit$data), sum(keep))
  expect_false(anyNA(fit$tmb_data$y))
  expect_equal(fit$tmb_data$n_trials, rep(6, sum(keep)))
  expect_true(
    any(grepl("\\b2\\b", msgs) & grepl("(?i)dropp", msgs, perl = TRUE)),
    info = paste(msgs, collapse = " | ")
  )
})
