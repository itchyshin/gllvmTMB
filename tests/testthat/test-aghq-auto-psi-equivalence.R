## #847 Arc 0: ordinary latent() carries an automatic B-tier Psi by grammar,
## but pure single-trial Bernoulli maps every Psi coordinate off. Prove that
## this is the same statistical model as the explicit loadings-only mirror
## before admitting the default grammar to AGHQ Stage 1a.

.tau_eq_cell <- function(link = "logit", q = 2L, seed = 2003L,
                         n = 40L, p = 4L) {
  set.seed(seed)
  Lt <- matrix(stats::rnorm(p * q), p, q)
  u <- matrix(stats::rnorm(n * q), n, q)
  b <- stats::rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  inv <- stats::make.link(link)$linkinv
  Y <- matrix(stats::rbinom(n * p, 1, inv(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y)
  df$site <- factor(seq_len(n))
  lhs <- paste(colnames(Y), collapse = ", ")
  list(
    data = df,
    family = stats::binomial(link = link),
    auto = stats::as.formula(sprintf(
      "traits(%s) ~ 1 + latent(1 | site, d = %d)", lhs, q)),
    mirror = stats::as.formula(sprintf(
      "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)", lhs, q))
  )
}

.tau_eq_fit <- function(formula, cell, control) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    formula, data = cell$data, family = cell$family, control = control
  )))
}

test_that("all-skipped Bernoulli auto-Psi is exactly loadings-only", {
  skip_on_cran()
  ctl <- gllvmTMB::gllvmTMBcontrol(
    aghq = FALSE, n_init = 1L, init_jitter = 0,
    se = FALSE, warn_runaway = FALSE
  )

  for (link in c("logit", "probit", "cloglog")) {
    for (q in 1:2) {
      cell <- .tau_eq_cell(link = link, q = q, seed = 2000L + q)
      auto <- .tau_eq_fit(cell$auto, cell, ctl)
      mirror <- .tau_eq_fit(cell$mirror, cell, ctl)

      expect_true(all(auto$tmb_data$diag_B_skip == 1L),
                  info = paste(link, "q", q))
      expect_identical(auto$random, "z_B", info = paste(link, "q", q))
      expect_identical(mirror$random, "z_B", info = paste(link, "q", q))
      expect_identical(names(auto$opt$par), names(mirror$opt$par),
                       info = paste(link, "q", q))
      expect_equal(auto$opt$par, mirror$opt$par, tolerance = 0,
                   info = paste(link, "q", q))

      p0 <- mirror$opt$par
      probes <- list(
        p0,
        p0 + 1e-4,
        p0 + seq_along(p0) * 1e-6,
        p0 - seq_along(p0) * 1e-6
      )
      for (probe in probes) {
        expect_equal(auto$tmb_obj$fn(probe), mirror$tmb_obj$fn(probe),
                     tolerance = 1e-12, info = paste(link, "q", q, "fn"))
        expect_equal(auto$tmb_obj$gr(probe), mirror$tmb_obj$gr(probe),
                     tolerance = 1e-10, info = paste(link, "q", q, "gr"))
      }
    }
  }
})

test_that("default Bernoulli grammar reaches the same unpenalised AGHQ fit", {
  skip_on_cran()
  cell <- .tau_eq_cell(link = "logit", q = 1L, seed = 11L,
                       n = 30L, p = 3L)
  ctl <- gllvmTMB::gllvmTMBcontrol(
    aghq = 5L, aghq_ridge = Inf, aghq_multistart = TRUE,
    se = FALSE, warn_runaway = FALSE
  )
  auto <- .tau_eq_fit(cell$auto, cell, ctl)
  mirror <- .tau_eq_fit(cell$mirror, cell, ctl)

  expect_true(isTRUE(auto$aghq$used))
  expect_true(isTRUE(mirror$aghq$used))
  expect_identical(auto$aghq$n_starts, 2L)
  expect_identical(mirror$aghq$n_starts, 2L)
  expect_identical(auto$aghq$ridge_tau, Inf)
  expect_identical(mirror$aghq$ridge_tau, Inf)
  expect_equal(auto$opt$objective, mirror$opt$objective, tolerance = 1e-10)
  expect_equal(auto$opt$par, mirror$opt$par, tolerance = 1e-9)
})

test_that("a free automatic Psi remains outside AGHQ Stage 1a", {
  skip_on_cran()
  set.seed(19L)
  n <- 30L
  Y <- matrix(stats::rpois(n * 3L, 1.5), n, 3L)
  colnames(Y) <- paste0("sp", 1:3)
  df <- as.data.frame(Y)
  df$site <- factor(seq_len(n))
  fml <- traits(sp1, sp2, sp3) ~ 1 + latent(1 | site, d = 1)

  rlang::reset_warning_verbosity("gllvmTMB-aghq-ineligible")
  expect_warning(
    fit <- gllvmTMB::gllvmTMB(
      fml, data = df, family = stats::poisson(),
      control = gllvmTMB::gllvmTMBcontrol(
        aghq = 5L, aghq_ridge = Inf, se = FALSE, warn_runaway = FALSE
      )
    ),
    "AGHQ did not run"
  )
  expect_false(isTRUE(fit$aghq$used))
  expect_true("s_B" %in% fit$random)
  expect_true(any(fit$tmb_data$diag_B_skip == 0L))
})
