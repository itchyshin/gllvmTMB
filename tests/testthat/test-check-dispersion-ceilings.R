## check_gllvmTMB() ceiling rows for truncated_nbinom2 phi, nbinom1 phi,
## Student df and beta-binomial phi (#1486). The NB2 and Gamma rows already
## existed; these four families converged with the dispersion / df at its
## limit and every boundary row still read PASS.

dispersion_fixture <- function(kind, n = 80L, Tn = 3L) {
  set.seed(1486)
  trait_names <- letters[seq_len(Tn)]
  mu <- c(1.2, 1.6, 2.0)[seq_len(Tn)]
  z <- stats::rnorm(n)
  lam <- c(0.4, -0.3, 0.3)[seq_len(Tn)]
  eta <- outer(z, lam) + matrix(mu, n, Tn, byrow = TRUE)
  long <- data.frame(
    unit = factor(rep(seq_len(n), each = Tn)),
    trait = factor(rep(trait_names, n), levels = trait_names)
  )
  yv <- function(m) as.vector(t(m))
  switch(kind,
    truncnb2 = {
      y <- matrix(0L, n, Tn)
      for (j in seq_len(Tn)) {
        for (i in seq_len(n)) {
          v <- 0L
          while (v < 1L) v <- stats::rnbinom(1L, mu = exp(eta[i, j]), size = 2)
          y[i, j] <- v
        }
      }
      long$value <- yv(y)
      list(data = long, family = truncated_nbinom2(), fid = 11L,
           report = "phi_truncnb2", prefix = "boundary_phi_truncnb2_",
           arg = "phi_truncnb2_ceiling_thresh",
           formula = value ~ 0 + trait + latent(0 + trait | unit, d = 1))
    },
    nbinom1 = {
      y <- matrix(0L, n, Tn)
      for (j in seq_len(Tn)) {
        m <- exp(eta[, j])
        y[, j] <- stats::rnbinom(n, mu = m, size = m / 1.5)
      }
      long$value <- yv(y)
      list(data = long, family = nbinom1(), fid = 15L,
           report = "phi_nbinom1", prefix = "boundary_phi_nbinom1_",
           arg = "phi_nbinom1_ceiling_thresh",
           formula = value ~ 0 + trait + latent(0 + trait | unit, d = 1))
    },
    student = {
      y <- eta + matrix(stats::rt(n * Tn, df = 4), n, Tn)
      long$value <- yv(y)
      list(data = long, family = student(), fid = 9L,
           report = "df_student", prefix = "boundary_df_student_",
           arg = "df_student_ceiling_thresh",
           formula = value ~ 0 + trait + latent(0 + trait | unit, d = 1))
    },
    betabinom = {
      succ <- matrix(0L, n, Tn)
      for (j in seq_len(Tn)) {
        p <- stats::plogis(eta[, j] - 1.5)
        pr <- stats::rbeta(n, p * 4, (1 - p) * 4)
        succ[, j] <- stats::rbinom(n, 10L, pr)
      }
      long$succ <- yv(succ)
      long$fail <- 10L - long$succ
      list(data = long, family = betabinomial(), fid = 8L,
           report = "phi_betabinom", prefix = "boundary_phi_betabinom_",
           arg = "phi_betabinom_ceiling_thresh",
           formula = cbind(succ, fail) ~ 0 + trait +
             latent(0 + trait | unit, d = 1))
    }
  )
}

test_that("check_gllvmTMB() has a ceiling row per trait for truncnb2 / nbinom1 phi, Student df and beta-binomial phi (#1486)", {
  skip_on_cran()
  for (kind in c("truncnb2", "nbinom1", "student", "betabinom")) {
    fx <- dispersion_fixture(kind)
    fit <- suppressMessages(suppressWarnings(gllvmTMB(
      fx$formula, data = fx$data, unit = "unit", family = fx$family,
      control = gllvmTMBcontrol(se = FALSE)
    )))
    expect_true(all(fit$tmb_data$family_id_vec == fx$fid), info = kind)

    ## Move the estimate to a moderate interior value: every row is PASS.
    fit$report[[fx$report]][] <- 5
    chk <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
    rows <- chk[startsWith(chk$component, fx$prefix), ]
    expect_identical(rows$component, paste0(fx$prefix, letters[1:3]), info = kind)
    expect_true(all(rows$status == "PASS"), info = kind)

    ## Push one trait onto the ceiling: exactly that row WARNs.
    fit$report[[fx$report]][2L] <- 1e9
    chk2 <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
    st <- stats::setNames(chk2$status, chk2$component)
    expect_identical(unname(st[paste0(fx$prefix, "b")]), "WARN", info = kind)
    expect_identical(unname(st[paste0(fx$prefix, "a")]), "PASS", info = kind)
    expect_identical(unname(st[paste0(fx$prefix, "c")]), "PASS", info = kind)

    ## A non-finite estimate also WARNs.
    fit$report[[fx$report]][2L] <- NaN
    chk3 <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
    expect_identical(chk3$status[chk3$component == paste0(fx$prefix, "b")],
                     "WARN", info = kind)

    ## The threshold is the caller's: an interior value flips with it.
    fit$report[[fx$report]][2L] <- 50
    chk5 <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
    expect_identical(chk5$status[chk5$component == paste0(fx$prefix, "b")],
                     "PASS", info = kind)
    args <- list(object = fit, laplace_accuracy = FALSE)
    args[[fx$arg]] <- 10
    chk4 <- do.call(check_gllvmTMB, args)
    expect_identical(chk4$status[chk4$component == paste0(fx$prefix, "b")],
                     "WARN", info = kind)
  }
})

test_that("a plain Poisson-family fit gets none of the new ceiling rows (#1486)", {
  skip_on_cran()
  set.seed(1486)
  n <- 60L
  d <- data.frame(
    unit = factor(rep(seq_len(n), each = 3L)),
    trait = factor(rep(letters[1:3], n)),
    value = stats::rpois(n * 3L, 3)
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = d, unit = "unit", family = poisson(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  chk <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
  expect_false(any(grepl(
    "^boundary_(phi_truncnb2|phi_nbinom1|df_student|phi_betabinom)_",
    chk$component)))
})

test_that("boundary_flags is not PASS while a boundary_phi_* row WARNs (#1351)", {
  skip_on_cran()
  ## (fixture kind, family used for the fit, report slot, row prefix). The NB2
  ## case fits the nbinom1 data with nbinom2(): only the family id matters.
  cases <- list(
    list(kind = "nbinom1", family = nbinom2(), report = "phi_nbinom2",
         prefix = "boundary_phi_nbinom2_"),
    list(kind = "truncnb2", family = NULL, report = "phi_truncnb2",
         prefix = "boundary_phi_truncnb2_"),
    list(kind = "nbinom1", family = NULL, report = "phi_nbinom1",
         prefix = "boundary_phi_nbinom1_"),
    list(kind = "betabinom", family = NULL, report = "phi_betabinom",
         prefix = "boundary_phi_betabinom_")
  )
  for (cs in cases) {
    fx <- dispersion_fixture(cs$kind)
    fit <- suppressMessages(suppressWarnings(gllvmTMB(
      fx$formula, data = fx$data, unit = "unit",
      family = cs$family %||% fx$family,
      control = gllvmTMBcontrol(se = FALSE)
    )))
    ## Interior estimate: no phi row WARNs, so boundary_flags names no phi row.
    fit$fit_health$boundary_flags <- character(0)
    fit$report[[cs$report]][] <- 5
    chk <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
    expect_false(any(startsWith(chk$component, "boundary_phi_") &
                       chk$status == "WARN"), info = cs$prefix)
    expect_identical(chk$status[chk$component == "boundary_flags"], "PASS",
                     info = cs$prefix)

    ## One trait on the ceiling: its row WARNs, so boundary_flags must too.
    fit$report[[cs$report]][2L] <- 1e9
    chk2 <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
    expect_identical(chk2$status[chk2$component == paste0(cs$prefix, "b")],
                     "WARN", info = cs$prefix)
    bf <- chk2[chk2$component == "boundary_flags", ]
    expect_true(nrow(bf) >= 1L && all(bf$status == "WARN"), info = cs$prefix)
    expect_match(paste(bf$value, collapse = " "), paste0(cs$prefix, "b"),
                 fixed = TRUE, info = cs$prefix)
  }
})
