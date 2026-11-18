# Inspect the actual bootstrap call, then run real refits against a manual oracle.
test_that("bootstrap preserves cbind trial totals in its actual refit calls", {
  set.seed(1496)
  dat <- expand.grid(unit = factor(1:15), trait = factor(letters[1:3]))
  dat$n <- rep(c(2, 7, 11), length.out = nrow(dat))
  dat$s <- rbinom(nrow(dat), dat$n, .4)
  dat$f <- dat$n - dat$s
  fit <- suppressWarnings(gllvmTMB(
    cbind(s, f) ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = dat,
    family = binomial(),
    unit = "unit",
    trait = "trait",
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  ))
  seen <- list()
  with_mocked_bindings(
    gllvmTMB = function(...) {
      seen[[length(seen) + 1L]] <<- list(...)
      fit
    },
    .package = "gllvmTMB",
    suppressWarnings(bootstrap_Sigma(
      fit,
      n_boot = 3,
      seed = 1496,
      level = "unit",
      what = "Sigma",
      progress = FALSE
    ))
  )
  expect_length(seen, 3)
  for (a in seen) {
    yy <- eval(a$formula[[2L]], a$data, environment(a$formula))
    expect_equal(as.numeric(rowSums(yy)), fit$tmb_data$n_trials)
  }
})

.bootstrap_binomial_fixture <- function(
  lhs = quote(cbind(s, f)),
  family = binomial(),
  policy = "drop"
) {
  set.seed(1496)
  d <- expand.grid(unit = factor(1:18), trait = factor(letters[1:3]))
  d <- d[sample(nrow(d)), ] # deliberate non-sorted model rows
  d$n <- rep(c(2, 7, 11), length.out = nrow(d))
  d$s <- rbinom(nrow(d), d$n, .4)
  d$s[1:2] <- c(0, d$n[2])
  d$f <- d$n - d$s
  d$s[4] <- d$f[4] <- NA_real_
  f <- cbind(s, f) ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE)
  f[[2L]] <- lhs
  suppressMessages(suppressWarnings(gllvmTMB(
    f,
    data = d,
    family = family,
    unit = "unit",
    trait = "trait",
    missing = miss_control(response = policy),
    weights = if (identical(lhs, quote(s))) d$n else NULL,
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  )))
}

test_that("response refits match a manual simulate/refit with fixed trial totals", {
  for (family in list(binomial(), betabinomial(), zi_binomial())) {
    for (policy in c("drop", "include")) {
      fit <- .bootstrap_binomial_fixture(quote(cbind(s, n - s)), family, policy)
      r <- .bootstrap_response_setup(fit)
      draws <- simulate(fit, nsim = 2, seed = 1496)
      y <- draws[, 1]
      observed <- fit$tmb_data$is_y_observed == 1L
      y[!observed] <- NA_real_
      manual <- fit$data
      manual$manual_s <- y
      manual$manual_f <- ifelse(observed, fit$tmb_data$n_trials - y, NA_real_)
      mf <- .reconstruct_multi_formula(fit)
      mf[[2]] <- quote(cbind(manual_s, manual_f))
      run <- function(formula, data, weights = NULL) {
        suppressMessages(suppressWarnings(
          gllvmTMB(
            formula,
            data = data,
            family = family,
            unit = "unit",
            trait = "trait",
            weights = weights,
            missing = miss_control(response = policy),
            control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
          )
        ))
      }
      actual <- run(
        r$formula,
        .bootstrap_response_data(r, draws[, 1]),
        r$weights
      )
      reference <- run(mf, manual)
      expect_equal(actual$tmb_data$y, reference$tmb_data$y)
      expect_equal(actual$tmb_data$n_trials, fit$tmb_data$n_trials)
      expect_equal(actual$tmb_data$is_y_observed, fit$tmb_data$is_y_observed)
      expect_equal(actual$tmb_data$weights_i, reference$tmb_data$weights_i)
      expect_equal(
        actual$opt$objective,
        reference$opt$objective,
        tolerance = 1e-7
      )
      expect_identical(actual$data$n, fit$data$n)
      # Explicit endpoint draws exercise zero and all successes, irrespective of RNG.
      edge <- ifelse(seq_along(y) %% 2, 0, fit$tmb_data$n_trials)
      ed <- .bootstrap_response_data(r, edge)[[r$name]]
      expect_equal(rowSums(ed)[observed], fit$tmb_data$n_trials[observed])
      expect_true(all(ed[observed, ] >= 0))
      expect_error(.bootstrap_response_data(r, edge[-1]), "row count")
    }
  }
})

test_that("single-column trial weights and Bernoulli encodings survive refits", {
  fit <- .bootstrap_binomial_fixture(quote(s))
  r <- .bootstrap_response_setup(fit)
  expect_equal(r$weights, fit$tmb_data$n_trials)
  y <- simulate(fit, nsim = 1, seed = 1496)[, 1]
  out <- suppressWarnings(gllvmTMB(
    r$formula,
    data = .bootstrap_response_data(r, y),
    family = binomial(),
    unit = "unit",
    trait = "trait",
    weights = r$weights,
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  ))
  expect_equal(out$tmb_data$n_trials, fit$tmb_data$n_trials)
  seen <- list()
  with_mocked_bindings(
    gllvmTMB = function(...) {
      seen[[length(seen) + 1L]] <<- list(...)
      fit
    },
    .package = "gllvmTMB",
    suppressWarnings(bootstrap_Sigma(
      fit,
      n_boot = 3,
      seed = 1496,
      level = "unit",
      what = "Sigma",
      progress = FALSE
    ))
  )
  for (args in seen) {
    expect_equal(args$weights, fit$tmb_data$n_trials)
  }
  binary <- fit$data
  binary$s <- as.numeric(binary$s > 0)
  bernoulli <- suppressMessages(suppressWarnings(gllvmTMB(
    .reconstruct_multi_formula(fit),
    data = binary,
    family = binomial(),
    unit = "unit",
    trait = "trait",
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  )))
  r <- .bootstrap_response_setup(bernoulli)
  expect_null(r$weights)
})

test_that("wide mixed cbind draws preserve family-specific response metadata", {
  set.seed(1496)
  d <- data.frame(id = factor(1:24), n = rep(c(3, 8), 12), mass = rnorm(24))
  d$s <- rbinom(24, d$n, .4)
  d$f <- d$n - d$s
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(cbind(s, f), mass) ~ 1 + latent(1 | id, d = 1, unique = FALSE),
    data = d,
    unit = "id",
    family = list(s = binomial(), mass = gaussian()),
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  )))
  r <- .bootstrap_response_setup(fit)
  y <- simulate(fit, nsim = 1, seed = 1496)[, 1]
  out <- suppressMessages(suppressWarnings(gllvmTMB(
    r$formula,
    data = .bootstrap_response_data(r, y),
    trait = fit$trait_col,
    unit = fit$unit_col,
    family = fit$family_input,
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L)
  )))
  expect_equal(out$tmb_data$n_trials, fit$tmb_data$n_trials)
  expect_equal(out$tmb_data$y, y)
  expect_equal(out$tmb_data$family_id_vec, fit$tmb_data$family_id_vec)
})

test_that("bootstrap draws equal an explicit manual simulate/refit loop", {
  fit <- .bootstrap_binomial_fixture(quote(cbind(s, f)))
  seed <- 1496L
  y <- simulate(fit, nsim = 3, seed = seed)
  ref <- lapply(seq_len(ncol(y)), function(b) {
    d <- fit$data
    d$s <- y[, b]
    d$f <- fit$tmb_data$n_trials - y[, b]
    z <- suppressMessages(suppressWarnings(gllvmTMB(
      .reconstruct_multi_formula(fit),
      data = d,
      family = binomial(),
      trait = "trait",
      unit = "unit",
      control = .bootstrap_refit_control(fit)
    )))
    if (!isTRUE(z$opt$convergence == 0L)) {
      return(.na_summaries(
        .extract_summaries(fit, level = "B", what = "Sigma")
      ))
    }
    .extract_summaries(z, level = "B", what = "Sigma")
  })
  actual <- suppressWarnings(bootstrap_Sigma(
    fit,
    n_boot = 3,
    seed = seed,
    level = "unit",
    what = "Sigma",
    keep_draws = TRUE,
    progress = FALSE
  ))
  expect_equal(actual$draws, ref, tolerance = 1e-7)
})

test_that("response preparation distinguishes trial and likelihood weights", {
  fit <- structure(
    list(
      formula = y ~ 1,
      covstructs = list(),
      data = data.frame(y = c(0, 1, 2)),
      tmb_data = list(
        family_id_vec = c(1L, 8L, 19L),
        n_trials = c(3, 5, 1),
        weights_i = c(1, 1, 2),
        is_y_observed = rep(1L, 3)
      ),
      likelihood_weights = list(active = TRUE)
    ),
    class = "gllvmTMB_multi"
  )
  expect_equal(.bootstrap_response_setup(fit)$weights, c(3, 5, 2))
})
