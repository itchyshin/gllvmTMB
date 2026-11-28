test_that("unified prior tables resolve named unique-variance Gamma rows", {
  psi <- data.frame(
    prior = "gamma(2,3.6)",
    class = "unique_variance",
    trait = "t2",
    kernel = "pine",
    scale = "natural_sd",
    stringsAsFactors = FALSE
  )

  rows <- .gllvmTMB_parse_prior_table(psi)
  expect_identical(rows[[1L]]$class, "unique_variance")
  expect_identical(rows[[1L]]$trait, "t2")
  expect_identical(rows[[1L]]$kernel, "pine")
  expect_identical(rows[[1L]]$scale, "natural_sd")
  expect_equal(rows[[1L]]$args, c(2, 3.6))

  adapted <- .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors = psi))
  expect_equal(adapted$kernel_psi_sd_prior,
               data.frame(kernel = "pine", trait = "t2", shape = 3.6,
                          rate = 1.8, stringsAsFactors = FALSE))
  expect_identical(adapted$prior_table_resolved, rows)
})

test_that("one table adapts fixed-effect and unique-variance rows together", {
  table <- data.frame(
    prior = c("normal(0,2)", "gamma(2,3.6)"),
    class = c("fixef", "unique_variance"),
    coef = c("traita:x", ""),
    dpar = c("mu", ""),
    trait = c("", "t2"),
    kernel = c("", "pine"),
    scale = c("link", "natural_sd"),
    stringsAsFactors = FALSE
  )

  adapted <- .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors = table))
  expect_equal(adapted$fixed_effect_priors$coefficient, "traita:x")
  expect_equal(adapted$kernel_psi_sd_prior$rate, 1.8)
  expect_length(adapted$prior_table_resolved, 2L)
  expect_identical(.gllvmTMB_adapt_prior_table(adapted), adapted)
})

test_that("a fixed-effect and unique-variance table composes in a kernel fit", {
  skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  n <- 8L
  species <- paste0("s", seq_len(n))
  K <- 0.5^abs(outer(seq_len(n), seq_len(n), "-"))
  dimnames(K) <- list(species, species)
  dat <- data.frame(
    species = factor(species, levels = species),
    row_id = factor(species, levels = species),
    y1 = sin(seq_len(n) / 2),
    y2 = cos(seq_len(n) / 3)
  )
  table <- data.frame(
    prior = c("normal(0,2)", "gamma(2,3.6)", "gamma(1.5,2)"),
    class = c("fixef", "unique_variance", "residual_sd"),
    coef = c("traity1", "", "(Intercept)"), dpar = c("mu", "", "sigma"),
    trait = c("", "y1", ""), kernel = c("", "k", ""),
    scale = c("link", "natural_sd", "natural_sd"), stringsAsFactors = FALSE
  )
  fit_warnings <- character()
  fit <- withCallingHandlers(
    gllvmTMB(
      traits(y1, y2) ~ 1 + kernel_latent(
        species, K = K, d = 1, name = "k", unique = TRUE
      ),
      data = dat, family = gaussian(), unit = "row_id", cluster = "species",
      control = gllvmTMBcontrol(priors = table, se = FALSE), silent = TRUE
    ),
    warning = function(w) {
      fit_warnings <<- c(fit_warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  expect_true(any(grepl("Kernel Psi SD priors produce penalized MAP estimates",
                        fit_warnings, fixed = TRUE)))
  expect_identical(fit$estimator, "MAP")
  expect_true(fit$penalised)
  expect_identical(fit$se_type, "penalised")
  expect_equal(fit$objective, fit$logLik + fit$log_prior, tolerance = 1e-8)
  expect_equal(
    fit$objective_components$optimization_nll,
    fit$objective_components$likelihood_nll +
      fit$objective_components$fixed_effect_prior_nll +
      fit$objective_components$kernel_psi_sd_prior_nll +
      fit$objective_components$residual_sd_prior_nll,
    tolerance = 1e-8
  )
  expect_equal(
    as.numeric(fit$tmb_obj$fn(fit$opt$par)),
    fit$objective_components$optimization_nll,
    tolerance = 1e-7
  )
  par <- fit$opt$par
  fd_gradient <- vapply(seq_along(par), function(j) {
    step <- numeric(length(par))
    step[j] <- 1e-5 * max(1, abs(par[j]))
    (fit$tmb_obj$fn(par + step) - fit$tmb_obj$fn(par - step)) /
      (2 * step[j])
  }, numeric(1))
  expect_equal(as.numeric(fit$tmb_obj$gr(par)), fd_gradient,
               tolerance = 2e-5)
  replay_call <- update(fit, data = dat, evaluate = FALSE)
  expect_identical(replay_call$control$prior_table, table)
  replayed <- suppressWarnings(update(fit, data = dat))
  expect_identical(replayed$prior_table_resolved, fit$prior_table_resolved)
  expect_equal(replayed$objective_components$optimization_nll,
               fit$objective_components$optimization_nll, tolerance = 1e-7)
})

test_that("unique-variance rows reject invalid distribution and target fields", {
  base <- data.frame(
    prior = "gamma(2,3.6)", class = "unique_variance",
    trait = "t2", kernel = "pine", scale = "natural_sd",
    stringsAsFactors = FALSE
  )
  expect_error(.gllvmTMB_parse_prior_table(transform(base, prior = "normal(0,1)")),
               "unique_variance.*Gamma")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, prior = "gamma(2,1)")),
               "unique-variance Gamma mean.*shape")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, trait = "")),
               "nonempty trait")
  expect_error(.gllvmTMB_parse_prior_table(transform(base, scale = "link")),
               "natural_sd")
  expect_error(.gllvmTMB_parse_prior_table(rbind(base, base)),
               "duplicate unique-variance")
})

test_that("Gamma table rows attach a normalized natural-SD penalty to the named Psi", {
  table <- data.frame(
    prior = "gamma(2,3.6)", class = "unique_variance",
    trait = "t2", kernel = "", scale = "natural_sd",
    stringsAsFactors = FALSE
  )
  control <- .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors = table))
  resolved <- .gllvmTMB_resolve_kernel_psi_sd_prior(
    control$kernel_psi_sd_prior,
    kernel_names = "pine", kernel_has_psi = 1L,
    trait_names = c("t1", "t2"), multi_kernel = FALSE
  )
  expect_identical(resolved$kernel, "pine")
  expect_equal(resolved$shape, 3.6)
  expect_equal(resolved$rate, 1.8)
  expect_identical(resolved$parameter_index, 2L)

  par <- setNames(c(0.1, log(0.4), log(0.8)),
                  c("b_fix", "log_sd_phy_diag", "log_sd_phy_diag"))
  obj <- list(
    par = par,
    env = list(random = integer()),
    fn = function(p = par, ...) sum(p^2) / 2,
    gr = function(p = par, ...) p,
    he = function(p = par, ...) diag(length(p))
  )
  penalized <- .gllvmTMB_attach_kernel_psi_sd_prior(obj, resolved)
  eta <- par[[3L]]
  expected <- 1.8 * exp(eta) - (3.6 - 1) * eta -
    3.6 * log(1.8) + lgamma(3.6)
  expect_equal(penalized$kernel_psi_sd_prior$penalty(par), expected,
               tolerance = 1e-12)
  expect_equal(penalized$fn(par) - obj$fn(par), expected,
               tolerance = 1e-12)
  expect_equal(penalized$gr(par)[[3L]] - par[[3L]],
               1.8 * exp(eta) - (3.6 - 1), tolerance = 1e-12)
  expect_equal(penalized$he(par)[3L, 3L] - 1, 1.8 * exp(eta),
               tolerance = 1e-12)
  expect_identical(penalized$kernel_psi_sd_prior$jacobian, FALSE)
})

test_that("Gamma unique-variance rows remain unsupported on the MSPL route", {
  psi <- data.frame(
    prior = "gamma(2,3.6)", class = "unique_variance", trait = "t2",
    kernel = "pine", scale = "natural_sd", stringsAsFactors = FALSE
  )
  control <- .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors = psi))
  expect_error(
    .gllvmTMB_kernel_psi_sd_prior_route(
      control$kernel_psi_sd_prior, engine = "tmb", estimator = "mspl",
      REML = FALSE, control = control
    ),
    class = "gllvmTMB_kernel_psi_prior_unsupported"
  )
})
