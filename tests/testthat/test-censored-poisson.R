## censored_poisson() (Arc E, issue #1244). See
## dev/gapclose/arcE/alignment-censored-poisson.md for the density
## derivation these tests check against, and the D-204 "parity both ways"
## reasoning this arc closes.
##
## Scope of THIS file: density exactness, gradient correctness, admission
## (cbind(y, censored) LHS, plain-y fallback, validation refusals),
## VA/AGHQ decline, and one known-DGP recovery test.

.cp_fd_grad <- function(fn, par, eps = 1e-6) {
  g <- numeric(length(par))
  for (i in seq_along(par)) {
    pp <- par; pm <- par
    pp[i] <- pp[i] + eps
    pm[i] <- pm[i] - eps
    g[i] <- (fn(pp) - fn(pm)) / (2 * eps)
  }
  g
}

## ---------------------------------------------------------------------
## Density exactness: TMB objective == hand-computed density, on a tiny
## fixed-effect-only fit (no latent()/random effects, so tmb_obj$fn() is
## the exact negative log-likelihood, not a Laplace approximation).
## ---------------------------------------------------------------------

test_that("censored_poisson: TMB objective matches hand-computed density to 1e-10", {
  skip_on_cran()
  set.seed(1)
  n_site <- 10L
  C <- 4
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site))
  )
  mu_true <- c(3, 5)
  y_true <- c(stats::rpois(n_site, mu_true[1]), stats::rpois(n_site, mu_true[2]))
  censored <- as.integer(y_true >= C)
  dat$y <- ifelse(censored == 1, C, y_true)
  dat$censored <- censored
  expect_gt(sum(censored), 0) # fixture actually exercises the censored branch

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(y, censored) ~ 0 + trait,
    data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$tmb_data$family_id_vec[1], 20L)

  par <- fit$tmb_obj$par
  nll_tmb <- as.numeric(fit$tmb_obj$fn(par))

  pn <- names(par)
  b_fix <- par[pn == "b_fix"]
  trait_id <- fit$tmb_data$trait_id
  y <- fit$tmb_data$y
  cens_limit <- fit$tmb_data$cens_limit
  eta <- b_fix[trait_id + 1L]
  mu <- exp(eta)
  ll <- ifelse(
    cens_limit >= 1,
    log(stats::pgamma(mu, shape = cens_limit, rate = 1)),
    stats::dpois(y, mu, log = TRUE)
  )
  expect_equal(nll_tmb, -sum(ll), tolerance = 1e-10)
})

test_that("censored_poisson: an all-uncensored fit matches plain poisson() exactly", {
  skip_on_cran()
  set.seed(2)
  n_site <- 12L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(stats::rpois(n_site, 3), stats::rpois(n_site, 5))
  )
  fit_cp <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait, data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  fit_pois <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait, data = dat, family = poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(unname(fit_cp$tmb_data$cens_limit), rep(0, nrow(dat)))
  expect_equal(as.numeric(fit_cp$opt$objective), as.numeric(fit_pois$opt$objective),
               tolerance = 1e-8)
  expect_equal(unname(fit_cp$opt$par), unname(fit_pois$opt$par), tolerance = 1e-6)
})

## ---------------------------------------------------------------------
## Gradient: TMB analytic gradient matches central finite differences, at
## GENUINE pre-optimisation starting values (b_fix = 0 -- censored_poisson
## has no other parameter).
## ---------------------------------------------------------------------

test_that("censored_poisson: gradient matches finite differences at the starting values", {
  skip_on_cran()
  set.seed(1)
  n_site <- 10L
  C <- 4
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site))
  )
  mu_true <- c(3, 5)
  y_true <- c(stats::rpois(n_site, mu_true[1]), stats::rpois(n_site, mu_true[2]))
  censored <- as.integer(y_true >= C)
  dat$y <- ifelse(censored == 1, C, y_true)
  dat$censored <- censored

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(y, censored) ~ 0 + trait,
    data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  obj <- fit$tmb_obj
  par0 <- obj$par
  par0[names(par0) == "b_fix"] <- 0

  g_fd <- .cp_fd_grad(obj$fn, par0)
  g_an <- as.numeric(obj$gr(par0))
  rel <- abs(g_fd - g_an) / pmax(abs(g_fd), 1e-8)
  expect_lt(max(rel), 1e-4)
})

## ---------------------------------------------------------------------
## Admission / parser
## ---------------------------------------------------------------------

test_that("censored_poisson() parses cbind(y, censored) and a plain y column", {
  skip_on_cran()
  set.seed(3)
  n_site <- 15L
  dat <- data.frame(
    site     = factor(seq_len(n_site)),
    trait    = factor(rep("t1", n_site)),
    y        = c(0:9, rep(4, 5)),
    censored = c(rep(0L, 10), rep(1L, 5))
  )
  fit_cbind <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(y, censored) ~ 1, data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit_cbind$tmb_data$family_id_vec[1], 20L)
  expect_equal(sum(fit_cbind$tmb_data$cens_limit > 0), 5L)

  dat_plain <- data.frame(site = factor(seq_len(10)), trait = factor("t1"), y = 0:9)
  fit_plain <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 1, data = dat_plain, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(unname(fit_plain$tmb_data$cens_limit), rep(0, 10))
})

test_that("censored_poisson() refuses a non-{0,1} censored indicator", {
  skip_on_cran()
  dat <- data.frame(
    site = factor(1:5), trait = factor("t1"),
    y = c(1, 2, 3, 4, 5), censored = c(0, 1, 2, 0, 1)
  )
  expect_error(
    gllvmTMB(cbind(y, censored) ~ 1, data = dat, family = censored_poisson(), unit = "site"),
    "strict"
  )
})

test_that("censored_poisson() refuses a right-censored row with limit C = 0", {
  skip_on_cran()
  dat <- data.frame(
    site = factor(1:5), trait = factor("t1"),
    y = c(1, 0, 3, 4, 5), censored = c(0, 1, 0, 0, 1)
  )
  expect_error(
    gllvmTMB(cbind(y, censored) ~ 1, data = dat, family = censored_poisson(), unit = "site"),
    "censoring limit"
  )
})

test_that("censored_poisson() refuses a negative or non-integer uncensored y", {
  skip_on_cran()
  dat <- data.frame(
    site = factor(1:5), trait = factor("t1"),
    y = c(1.5, 2, 3, 4, 5), censored = c(0, 0, 0, 0, 0)
  )
  expect_error(
    gllvmTMB(cbind(y, censored) ~ 1, data = dat, family = censored_poisson(), unit = "site"),
    "non-negative integer"
  )
})

test_that("censored_poisson: only the log link is currently supported", {
  dat <- data.frame(site = factor(1:5), trait = factor("t1"),
                     y = c(1, 2, 3, 4, 5), censored = 0L)
  expect_error(
    gllvmTMB(cbind(y, censored) ~ 1, data = dat,
             family = censored_poisson(link = "identity"), unit = "site"),
    "log link"
  )
})

## ---------------------------------------------------------------------
## VA refuses; AGHQ declines (does not error), matching the zi_* precedent.
## ---------------------------------------------------------------------

test_that("integration = \"va\" refuses censored_poisson", {
  skip_on_cran()
  set.seed(4)
  n_site <- 20L
  dat <- data.frame(
    site  = factor(seq_len(n_site)), trait = factor("t1"),
    y     = stats::rpois(n_site, 3), censored = 0L
  )
  expect_error(
    gllvmTMB(
      cbind(y, censored) ~ 1 + latent(1 | site, d = 1, unique = FALSE),
      data = dat, family = censored_poisson(), unit = "site",
      control = gllvmTMBcontrol(integration = "va")
    ),
    "does not admit this model"
  )
})

test_that("aghq DECLINES (does not error) for censored_poisson", {
  skip_on_cran()
  set.seed(5)
  n_site <- 20L
  dat <- data.frame(
    site  = factor(seq_len(n_site)), trait = factor("t1"),
    y     = stats::rpois(n_site, 3), censored = 0L
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(y, censored) ~ 1 + latent(1 | site, d = 1, unique = FALSE),
    data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(aghq = 5, se = FALSE)
  )))
  expect_match(fit$aghq$reason, "censored_poisson")
})

## ---------------------------------------------------------------------
## fitted() / simulate() / residuals() / extract_Sigma() slots
## ---------------------------------------------------------------------

test_that("fitted() reports exp(eta) (the underlying uncensored-process mean)", {
  skip_on_cran()
  set.seed(6)
  n_site <- 30L
  C <- 5
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site))
  )
  y_true <- c(stats::rpois(n_site, 3), stats::rpois(n_site, 5))
  censored <- as.integer(y_true >= C)
  dat$y <- ifelse(censored == 1, C, y_true)
  dat$censored <- censored

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(y, censored) ~ 0 + trait,
    data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  f <- fitted(fit)
  expect_equal(f$est, exp(fit$report$eta), tolerance = 1e-10)
})

test_that("simulate() draws the latent Poisson and re-applies each row's own censoring limit", {
  skip_on_cran()
  set.seed(7)
  n_site <- 40L
  C <- 3
  dat <- data.frame(
    site  = factor(seq_len(n_site)), trait = factor("t1")
  )
  y_true <- stats::rpois(n_site, 6) # large mean so most rows are censored
  censored <- as.integer(y_true >= C)
  dat$y <- ifelse(censored == 1, C, y_true)
  dat$censored <- censored

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(y, censored) ~ 1,
    data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  sim <- simulate(fit, nsim = 1, seed = 11)
  sim_vec <- as.numeric(sim[, 1L])
  expect_length(sim_vec, n_site)
  ## Rows the ORIGINAL data marked censored (cens_limit > 0) can never draw
  ## a simulated value above their own limit -- that is the whole point of
  ## re-applying the row's censoring design.
  cl <- fit$tmb_data$cens_limit
  expect_true(all(sim_vec[cl > 0] <= cl[cl > 0]))
})

test_that("residuals(type = \"randomized_quantile\") runs without error and covers censored rows", {
  skip_on_cran()
  set.seed(8)
  n_site <- 40L
  C <- 3
  dat <- data.frame(site = factor(seq_len(n_site)), trait = factor("t1"))
  y_true <- stats::rpois(n_site, 6)
  censored <- as.integer(y_true >= C)
  dat$y <- ifelse(censored == 1, C, y_true)
  dat$censored <- censored

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(y, censored) ~ 1,
    data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  res <- residuals(fit, type = "randomized_quantile", seed = 9)
  expect_s3_class(res, "data.frame")
  expect_true(all(res$status[dat$censored == 1] == "ok"))
})

test_that("extract_Sigma() reports a finite censored_poisson link residual, reusing the plain-Poisson rule", {
  skip_on_cran()
  set.seed(10)
  ## extract_Sigma() needs an actual latent()/covariance block to report --
  ## an intercept-only single-trait fit has no Sigma at all, so this uses
  ## the same 2-trait rank-1 latent() shape as the density-identity fixture.
  n_site <- 30L
  C <- 5
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site))
  )
  y_true <- c(stats::rpois(n_site, 3), stats::rpois(n_site, 5))
  censored <- as.integer(y_true >= C)
  dat$y <- ifelse(censored == 1, C, y_true)
  dat$censored <- censored

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(y, censored) ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  Sig <- extract_Sigma(fit, link_residual = "auto")
  expect_true(all(is.finite(diag(Sig$Sigma))))
})

## ---------------------------------------------------------------------
## Known-DGP recovery. DGP: 6 traits, rank-1 latent(0 + trait | site, d =
## 1, unique = FALSE), censoring limit C = 6 (~26% of cells censored),
## same intercept/loading magnitudes as the zi_poisson recovery DGP.
## Confirmed at n_site = 200 across seeds 101/202/303/404 (see
## dev/gapclose/arcE -- these are the numbers that motivated the choice):
##   seed 101: conv=0, frac_cens=0.260, max|intercept err|=0.0507, rel.Frob=0.1552
##   seed 202: conv=0, frac_cens=0.258, max|intercept err|=0.1159, rel.Frob=0.0686
##   seed 303: conv=0, frac_cens=0.269, max|intercept err|=0.0899, rel.Frob=0.0653
##   seed 404: conv=0, frac_cens=0.268, max|intercept err|=0.0663, rel.Frob=0.1675
## Bars below (0.15 intercepts, 0.25 rel. Frobenius) hold at ALL FOUR
## seeds -- a REGRESSION GUARD confirmed on 4 seeds, not a certified size
## (only one seed ships as the test, matching the zi_* precedent).
## ---------------------------------------------------------------------

test_that("censored_poisson recovers intercepts and loadings from a known DGP", {
  skip_on_cran()
  set.seed(101)
  n_site <- 200L
  n_trait <- 6L
  beta_true <- c(1.4, 1.1, 1.7, 1.2, 1.5, 1.0)
  lambda_true <- c(0.5, -0.4, 0.35, -0.3, 0.4, -0.35)
  C <- 6

  u <- rnorm(n_site)
  eta <- outer(u, lambda_true) + matrix(beta_true, n_site, n_trait, byrow = TRUE)
  mu <- exp(eta)
  Y_true <- matrix(stats::rpois(n_site * n_trait, mu), n_site, n_trait)
  censored <- Y_true >= C
  Y_obs <- ifelse(censored, C, Y_true)

  dat <- data.frame(
    site     = factor(rep(seq_len(n_site), n_trait)),
    trait    = factor(rep(seq_len(n_trait), each = n_site)),
    y        = as.vector(Y_obs),
    censored = as.integer(as.vector(censored))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(y, censored) ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat, family = censored_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)

  par <- fit$tmb_obj$env$last.par.best
  bfix <- par[names(par) == "b_fix"]
  expect_lt(max(abs(bfix - beta_true)), 0.15) # predeclared, confirmed across 4 seeds

  L <- extract_ordination(fit, level = "unit")$loadings
  proc <- compare_loadings(L, matrix(lambda_true, ncol = 1))
  rel_frob <- proc$frobenius / sqrt(sum(lambda_true^2))
  expect_lt(rel_frob, 0.25) # predeclared, confirmed across 4 seeds
})
