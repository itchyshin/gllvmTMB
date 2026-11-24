test_that("Gamma kernel Psi SD priors use normalized natural-SD densities", {
  prior <- data.frame(kernel = c("oak", "pine"), trait = c("t1", "t2"),
                      shape = c(2.7, 3.6), rate = c(3.1, 1.8))
  resolve <- function(x, kernels = c("oak", "pine")) {
    .gllvmTMB_resolve_kernel_psi_sd_prior(
      x, kernels, c(1L, 1L), c("t1", "t2", "t3"), TRUE
    )
  }
  registry <- resolve(prior)
  expect_equal(registry$parameter_index, c(1L, 5L))
  p <- setNames(c(0.3, 0.7, -0.2, 0.5, 0.6, -0.3,
                  log(c(0.15, 0.4, 0.22, 0.3, 0.25, 0.5))),
                c(rep("theta_rr_kernel", 6L), rep("log_sd_kernel_diag", 6L)))
  obj <- list(par = p, fn = function(p) sum(p^2) / 2,
              gr = function(p) p, he = function(p) diag(length(p)))
  fit <- .gllvmTMB_attach_kernel_psi_sd_prior(obj, registry)
  idx <- c(7L, 11L)
  sd <- exp(p[idx])
  expected <- -sum(stats::dgamma(sd, shape = prior$shape,
                                 rate = prior$rate, log = TRUE))
  expect_equal(fit$kernel_psi_sd_prior$penalty(p), unname(expected),
               tolerance = 1e-12)
  expect_equal(unname(fit$gr(p)[idx] - obj$gr(p)[idx]),
               unname(prior$rate * sd - (prior$shape - 1)), tolerance = 1e-12)
  increment <- fit$he(p) - obj$he(p)
  expect_equal(unname(diag(increment)[idx]), unname(prior$rate * sd),
               tolerance = 1e-12)
  diag(increment)[idx] <- 0
  expect_equal(increment, matrix(0, length(p), length(p)))
  expect_identical(fit$kernel_psi_sd_prior$density, "gamma")
  expect_identical(fit$kernel_psi_sd_prior$target_names, c("oak:t1", "pine:t2"))
  expect_identical(fit$kernel_psi_sd_prior$jacobian, FALSE)
  expect_identical(fit$kernel_psi_sd_prior$likelihood_he, obj$he)
  expect_identical(fit$kernel_psi_sd_prior$likelihood_fn, obj$fn)

  # Names, rather than term order or prior-row order, select each SD.
  reversed <- .gllvmTMB_attach_kernel_psi_sd_prior(
    obj, resolve(prior[2:1, ], c("pine", "oak"))
  )
  p_reverse <- p[c(4:6, 1:3, 10:12, 7:9)]
  expect_equal(reversed$kernel_psi_sd_prior$penalty(p_reverse),
               fit$kernel_psi_sd_prior$penalty(p), tolerance = 1e-12)
  single <- .gllvmTMB_resolve_kernel_psi_sd_prior(
    prior[1L, ], "oak", 1L, c("t1", "t2", "t3"), FALSE
  )
  expect_identical(single$parameter_name, "log_sd_phy_diag")
  expect_equal(single$parameter_index, 1L)
})

test_that("Gamma kernel Psi prior schema rejects ambiguous and invalid inputs", {
  resolve <- function(x) .gllvmTMB_resolve_kernel_psi_sd_prior(
    x, c("oak", "pine"), c(1L, 0L), c("t1", "t2", "t3"), TRUE
  )
  prior <- data.frame(kernel = "oak", trait = "t1", shape = 2.7, rate = 3.1)
  invalid <- list(transform(prior, shape = 1), transform(prior, shape = Inf),
                  transform(prior, shape = NA_real_), transform(prior, rate = 0),
                  transform(prior, rate = Inf), transform(prior, rate = "3.1"),
                  transform(prior, scale = 1), prior[setdiff(names(prior), "rate")],
                  rbind(prior, prior), prior[FALSE, ])
  for (x in invalid) expect_error(resolve(x),
                                  class = "gllvmTMB_kernel_psi_prior_invalid")
  duplicate_names <- prior
  names(duplicate_names)[4L] <- "shape"
  expect_error(resolve(duplicate_names), class = "gllvmTMB_kernel_psi_prior_invalid")
  expect_error(resolve(transform(prior, kernel = "absent")),
               class = "gllvmTMB_kernel_psi_prior_target_unknown")
  expect_error(resolve(transform(prior, kernel = "pine")),
               class = "gllvmTMB_kernel_psi_prior_without_psi")
})

test_that("kernel Psi SD priors target natural SDs with exact derivatives", {
  registry <- .gllvmTMB_resolve_kernel_psi_sd_prior(
    data.frame(kernel = "k2", trait = "b", scale = 0.5),
    kernel_names = c("k1", "k2"),
    kernel_has_psi = c(1L, 1L),
    trait_names = c("a", "b"),
    multi_kernel = TRUE
  )
  expect_equal(registry$parameter_index, 4L)
  expect_identical(registry$parameter_name, "log_sd_kernel_diag")
  later_kernel <- .gllvmTMB_resolve_kernel_psi_sd_prior(
    data.frame(kernel = "k2", trait = "b", scale = 0.5),
    kernel_names = c("k1", "k2"),
    kernel_has_psi = c(0L, 1L),
    trait_names = c("a", "b"),
    multi_kernel = TRUE
  )
  expect_equal(later_kernel$parameter_index, 2L)
  expect_identical(later_kernel$parameter_name, "log_sd_kernel_diag")
  single <- .gllvmTMB_resolve_kernel_psi_sd_prior(
    data.frame(kernel = "only", trait = "b", scale = 0.5),
    kernel_names = "only",
    kernel_has_psi = 1L,
    trait_names = c("a", "b"),
    multi_kernel = FALSE
  )
  expect_equal(single$parameter_index, 2L)
  expect_identical(single$parameter_name, "log_sd_phy_diag")

  nm <- c("b_fix", rep("log_sd_kernel_diag", 4L))
  par <- setNames(c(0.1, log(0.4), log(0.6), log(0.3), log(1e-12)), nm)
  obj <- list(
    par = par,
    fn = function(p = par, ...) sum(p^2) / 2,
    gr = function(p = par, ...) p,
    he = function(p = par, ...) diag(length(p))
  )
  expect_identical(.gllvmTMB_attach_kernel_psi_sd_prior(obj, NULL), obj)
  penalised <- .gllvmTMB_attach_kernel_psi_sd_prior(obj, registry)
  idx <- penalised$kernel_psi_sd_prior$indices
  sigma <- exp(par[idx])
  expected <- -stats::dnorm(sigma, 0, 0.5, log = TRUE) - log(2)
  expect_equal(unname(penalised$kernel_psi_sd_prior$penalty(par)), unname(expected),
               tolerance = 1e-12)
  expect_true(is.finite(penalised$fn(par)))
  expect_equal(penalised$gr(par)[idx] - par[idx],
               sigma^2 / 0.5^2, tolerance = 1e-12)
  expect_equal(unname(penalised$he(par)[idx, idx] - 1),
               unname(2 * sigma^2 / 0.5^2), tolerance = 1e-12)

  for (log_sd in c(-12, log(0.7))) {
    p <- par
    p[idx] <- log_sd
    h <- 1e-5
    p_hi <- p_lo <- p
    p_hi[idx] <- p_hi[idx] + h
    p_lo[idx] <- p_lo[idx] - h
    numeric_gradient <- (penalised$fn(p_hi) - penalised$fn(p_lo)) / (2 * h)
    expect_equal(numeric_gradient, unname(penalised$gr(p)[idx]),
                 tolerance = 1e-7)
  }
})

test_that("kernel Psi prior target validation fails closed", {
  resolve <- function(prior) .gllvmTMB_resolve_kernel_psi_sd_prior(
    prior, c("k1", "k2"), c(1L, 0L), c("a", "b"), TRUE
  )
  expect_error(resolve(data.frame(kernel = "k3", trait = "a", scale = 1)),
               class = "gllvmTMB_kernel_psi_prior_target_unknown")
  expect_error(resolve(data.frame(kernel = "k2", trait = "a", scale = 1)),
               class = "gllvmTMB_kernel_psi_prior_without_psi")
  expect_error(resolve(data.frame(kernel = "k1", trait = "a", scale = 0)),
               class = "gllvmTMB_kernel_psi_prior_invalid")
  expect_error(resolve(data.frame(kernel = c("k1", "k1"),
                                  trait = c("a", "a"), scale = c(1, 2))),
               class = "gllvmTMB_kernel_psi_prior_invalid")
  expect_error(.gllvmTMB_resolve_kernel_psi_sd_prior(
    data.frame(kernel = "k1", trait = "absent", scale = 1),
    c("k1", "k2"), c(1L, 0L), c("a", "b"), TRUE
  ), class = "gllvmTMB_kernel_psi_prior_target_unknown")
})

test_that("kernel Psi priors are opt-in and restricted to the documented route", {
  expect_null(gllvmTMBcontrol()$kernel_psi_sd_prior)
  prior <- data.frame(kernel = "k1", trait = "a", scale = 1)
  expect_invisible(.gllvmTMB_kernel_psi_sd_prior_route(
    NULL, "julia", "ml", FALSE, gllvmTMBcontrol()
  ))
  expect_error(.gllvmTMB_kernel_psi_sd_prior_route(
    prior, "julia", "ml", FALSE, gllvmTMBcontrol()
  ), class = "gllvmTMB_kernel_psi_prior_unsupported")
  expect_error(.gllvmTMB_kernel_psi_sd_prior_route(
    prior, "tmb", "ml", FALSE,
    gllvmTMBcontrol(loading_ridge = 1)
  ), class = "gllvmTMB_kernel_psi_prior_penalty_conflict")
  expect_invisible(.gllvmTMB_kernel_psi_sd_prior_route(
    prior, "tmb", "ml", FALSE,
    gllvmTMBcontrol(fixed_effect_priors = data.frame(
      coefficient = "x", mean = 0, sd = 1
    ))
  ))
})

test_that("two-kernel prior fit reports the separate MAP objective", {
  skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  n <- 8L
  sp <- c(paste0("H", seq_len(n)), paste0("P", seq_len(n)))
  A <- 0.6^abs(outer(seq_len(n), seq_len(n), "-"))
  I <- diag(n)
  K_phy <- rbind(cbind(A, 0.55 * A), cbind(0.55 * A, A))
  K_tip <- rbind(cbind(I, 0.55 * I), cbind(0.55 * I, I))
  dimnames(K_phy) <- dimnames(K_tip) <- list(sp, sp)
  dat <- data.frame(
    species = factor(sp, levels = sp),
    row_id = factor(sp, levels = sp),
    H1 = c(sin(seq_len(n)), rep(NA_real_, n)),
    H2 = c(cos(seq_len(n)), rep(NA_real_, n)),
    P1 = c(rep(NA_real_, n), sin(seq_len(n) + 0.3)),
    P2 = c(rep(NA_real_, n), cos(seq_len(n)))
  )
  prior <- data.frame(kernel = "phy", trait = "H1", scale = 0.5)
  fit <- suppressWarnings(gllvmTMB(
    traits(H1, H2, P1, P2) ~ 1 +
      kernel_latent(species, K = K_phy, d = 1, name = "phy", unique = TRUE) +
      kernel_latent(species, K = K_tip, d = 1, name = "tip", unique = TRUE),
    data = dat,
    family = gaussian(),
    unit = "row_id",
    cluster = "species",
    missing = miss_control(response = "include"),
    known_sigma_eps = 0.12,
    control = gllvmTMBcontrol(se = FALSE, kernel_psi_sd_prior = prior),
    silent = TRUE
  ))
  expect_identical(fit$estimator, "MAP")
  expect_true(fit$estimator_provenance$kernel_psi_sd_prior_applied)
  expect_false(fit$estimator_provenance$fixed_effect_prior_applied)
  expect_identical(fit$kernel_psi_sd_prior$target_class, "unique_variance")
  expect_identical(fit$kernel_psi_sd_prior$measure, "natural_sd")
  expect_identical(fit$kernel_psi_sd_prior$density_scale,
                   "natural_standard_deviation")
  expect_equal(fit$objective_components$optimization_nll,
               fit$objective_components$likelihood_nll +
                 fit$objective_components$kernel_psi_sd_prior_nll,
               tolerance = 1e-8)
  expect_equal(
    fit$objective_components$kernel_psi_sd_prior_nll,
    fit$tmb_obj$kernel_psi_sd_prior$penalty(fit$opt$par),
    tolerance = 1e-8
  )
  expect_equal(
    as.numeric(fit$tmb_obj$fn(fit$opt$par)),
    as.numeric(fit$objective_components$optimization_nll),
    tolerance = 1e-7
  )
  ## AIC warns before delegating to base, and logLik warns when AIC evaluates
  ## the unpenalised likelihood at this penalised MAP point. Capture both
  ## distinct warnings so the test documents the reader-facing behavior.
  expect_warning(
    expect_warning(AIC(fit), "ordinary likelihood-based interpretation is unsupported"),
    "unpenalised likelihood evaluated at a penalised MAP point"
  )
  expect_error(confint(fit), class = "gllvmTMB_fixed_prior_inference_unsupported")
})

# Symbolic alignment for the selected named-kernel tier:
# | Symbol | Covstruct | DGP draw | Fit check | Truth |
# | trait intercept | 0 + trait | alpha = 0 | coef(fit) | 0 |
# | shared factor | kernel_latent(..., d = 1) | no shared draw | Sigma_total - diag(Psi) | Lambda Lambda' = 0 |
# | unique term | kernel_latent(..., unique = TRUE) | simulate_site_trait(Cphy=K, sigma2_phy=psi2) | part='psi' | diag(psi2) |
# | observation error | known_sigma_eps | sigma2_eps = 0.01 in simulator | fixed input | 0.01 |
.fit_kernel_psi_prior_simulation <- function(psi2_truth) {
  n <- 10L
  n_sites <- 12L
  species <- paste0("s", seq_len(n))
  K <- 0.45^abs(outer(seq_len(n), seq_len(n), "-"))
  dimnames(K) <- list(species, species)
  sim <- simulate_site_trait(
    n_sites = n_sites,
    n_species = n,
    n_traits = 3L,
    mean_species_per_site = 100,
    n_predictors = 1L,
    alpha = rep(0, 3L),
    beta = matrix(0, nrow = 3L, ncol = 1L),
    sigma2_eps = 0.01,
    sigma2_phy = psi2_truth,
    Cphy = K,
    seed = 20261119
  )
  dat <- sim$data
  dat$species <- factor(paste0("s", dat$species), levels = species)
  dat$row_id <- interaction(dat$site, dat$species, drop = TRUE)
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
      kernel_latent(species, K = K, d = 1, name = "phy", unique = TRUE),
    data = dat,
    family = gaussian(),
    unit = "row_id",
    cluster = "species",
    known_sigma_eps = 0.1,
    control = gllvmTMBcontrol(
      se = FALSE,
      kernel_psi_sd_prior = data.frame(
        kernel = "phy", trait = "trait_2", scale = 2
      )
    ),
    silent = TRUE
  ))
  psi_variance <- suppressMessages(extract_Sigma(
    fit, level = "phy", part = "psi"
  ))$s
  total <- suppressMessages(extract_Sigma(
    fit, level = "phy", part = "total"
  ))$Sigma
  list(
    fit = fit,
    psi_variance = psi_variance,
    shared = total - diag(psi_variance),
    intercepts = unname(coef(fit))
  )
}

test_that("named-kernel Psi SD prior fits an interior simulated target", {
  skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  result <- .fit_kernel_psi_prior_simulation(c(0.16, 0.36, 0.64))
  fit <- result$fit

  expect_equal(length(result$psi_variance), 3L)
  expect_identical(as.integer(fit$opt$convergence), 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(all(is.finite(result$intercepts)))
  expect_true(all(is.finite(result$shared)))
  expect_true(all(is.finite(result$psi_variance)))
  expect_gt(sqrt(unname(result$psi_variance[["trait_2"]])), 1e-4)
  expect_identical(fit$estimator, "MAP")
  expect_true(fit$estimator_provenance$kernel_psi_sd_prior_applied)
})

test_that("named-kernel Psi SD prior fits and diagnoses a zero-boundary target", {
  skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  result <- .fit_kernel_psi_prior_simulation(c(0.16, 0, 0.64))
  fit <- result$fit

  expect_identical(as.integer(fit$opt$convergence), 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(all(is.finite(result$psi_variance)))
  expect_lt(sqrt(unname(result$psi_variance[["trait_2"]])), 1e-4)
  expect_true("near_zero_sd_phy_diag" %in% .gllvmTMB_boundary_flags(fit))
  expect_true(fit$estimator_provenance$kernel_psi_sd_prior_applied)
})
