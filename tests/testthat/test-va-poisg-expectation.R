## Tests for eval_method = "poisg" (inst/tmb/gllvmTMB_va_r3.cpp,
## va_r3_cloglog_poisg_expectation): truncated-Poisson / PoisG closed-form
## cloglog VA matching gllvm 2.0.13 src/gllvm.cpp ~3303-3311.
##
## Public auto stays GH; poisg is opt-in and internal (like ac/ac2).

skip_on_cran()

## R mirror of gllvm's cloglog VA contribution (without log_choose), with
## cQ = v/2 and mu_pois = exp(eta + cQ):
##   y*log1p(-exp(-mu_pois*exp(-cQ))) - (N-y)*mu_pois
##     + mu_pois*(exp(-cQ)-1)
.poisg_gllvm_value <- function(mu, v, y, n = 1) {
  cQ <- v / 2
  mu_pois <- exp(mu + cQ)
  y * log1p(-exp(-mu_pois * exp(-cQ))) -
    (n - y) * mu_pois +
    mu_pois * (exp(-cQ) - 1)
}

## Algebraic simplification used in C++:
##   y * cloglog_logp(mu) + exp(mu) - (n - y + 1) * exp(mu + v/2)
.poisg_ours_value <- function(mu, v, y, n = 1) {
  cloglog_logp <- function(eta) {
    ## Match va_r3_cloglog_logp: clamp large eta.
    if (eta > 35) return(0)
    log1p(-exp(-exp(eta)))
  }
  y * cloglog_logp(mu) + exp(mu) - (n - y + 1) * exp(mu + v / 2)
}

.poisg_grid <- expand.grid(
  mu = c(-2, -1, -0.5, 0, 0.5, 1, 2),
  v  = c(0.01, 0.2, 0.5, 1.0),
  y  = c(0, 1, 2),
  n  = c(1, 3, 5)
)
.poisg_grid <- subset(.poisg_grid, y <= n)

test_that("poisg R mirror matches gllvm formula on a grid", {
  gllvm_v <- mapply(.poisg_gllvm_value,
                    .poisg_grid$mu, .poisg_grid$v,
                    .poisg_grid$y, .poisg_grid$n)
  ours_v <- mapply(.poisg_ours_value,
                   .poisg_grid$mu, .poisg_grid$v,
                   .poisg_grid$y, .poisg_grid$n)
  expect_equal(ours_v, gllvm_v, tolerance = 1e-10)
})

test_that("poisg recovers cloglog loglik as v -> 0", {
  mu <- c(-1.2, 0.3, 1.5)
  for (m in mu) {
    for (y in 0:2) {
      n <- 2L
      if (y > n) next
      truth <- y * log1p(-exp(-exp(m))) - (n - y) * exp(m)
      expect_equal(.poisg_ours_value(m, 1e-16, y, n), truth, tolerance = 1e-8)
    }
  }
})

test_that("eval_method = \"poisg\" is wired for cloglog only", {
  expect_identical(gllvmTMB:::.va_r3_resolve_eval_method("auto", 1L, 2L), "gh")
  expect_identical(gllvmTMB:::.va_r3_resolve_eval_method("poisg", 1L, 2L), "poisg")
  expect_identical(gllvmTMB:::.va_r3_eval_method_code("poisg", 1L, 2L), 4L)
  expect_identical(gllvmTMB:::.va_r3_objective_type("poisg"), "ELBO_POISG")

  expect_error(
    gllvmTMB:::.va_r3_resolve_eval_method("poisg", 1L, 0L),
    "not implemented for the binomial"
  )
  expect_error(
    gllvmTMB:::.va_r3_resolve_eval_method("poisg", 1L, 1L),
    "not implemented for the binomial_probit"
  )
  expect_error(
    gllvmTMB:::.va_r3_resolve_eval_method("poisg", c(1L, 1L), c(2L, 0L)),
    "only defined for pure binomial-cloglog"
  )

  entry <- gllvmTMB:::.va_r3_family_entry(1L, 2L)
  expect_identical(entry$default_tier, "gh")
  expect_true("poisg" %in% entry$tiers)
  expect_true("gh" %in% entry$tiers)
})

test_that("compiled poisg expectation matches the gllvm formula", {
  skip_if_not(requireNamespace("TMB", quietly = TRUE))
  set.seed(20260807)
  n <- 8L
  p <- 3L
  Y <- matrix(rbinom(n * p, 1L, 0.45), n, p)
  dat <- data.frame(
    y = as.vector(Y),
    unit = rep(seq_len(n), times = p),
    trait = rep(seq_len(p), each = n)
  )
  vd <- gllvmTMB:::.va_r3_validate_data(
    y = dat$y,
    n_trials = rep(1, nrow(dat)),
    X = unname(model.matrix(~ 0 + factor(dat$trait, levels = seq_len(p)))),
    unit_id = dat$unit,
    trait_id = dat$trait,
    q = 1L,
    family = "binomial_cloglog"
  )
  obj <- gllvmTMB:::.va_r3_make_objective(
    vd, H = 7L, eval_method = "poisg", rebuild = TRUE, silent = TRUE
  )
  par0 <- obj$par
  expect_true(is.finite(obj$fn(par0)))
  expect_true(all(is.finite(obj$gr(par0))))
  rep <- obj$report(par0)
  ## Bernoulli => log_choose = 0; compiled ell must match the gllvm formula.
  mirror <- mapply(.poisg_ours_value, rep$mu_by_obs, rep$v_by_obs, vd$y, vd$n_trials)
  expect_lt(max(abs(rep$expected_loglik_by_obs - mirror)), 1e-10)

  ## Dispatch sanity: poisg must not silently alias to gh.
  obj_gh <- gllvmTMB:::.va_r3_make_objective(
    vd, H = 7L, eval_method = "gh", rebuild = FALSE, silent = TRUE
  )
  expect_false(isTRUE(all.equal(obj$fn(par0), obj_gh$fn(par0))))
})

test_that("poisg smoke fit converges on a small cloglog DGP", {
  skip_if_not(requireNamespace("TMB", quietly = TRUE))
  set.seed(42)
  n <- 40L
  p <- 4L
  q <- 1L
  Lambda <- matrix(c(0.7, 0.5, 0.4, 0.3), p, q)
  scores <- matrix(rnorm(n * q), n, q)
  beta <- c(-0.2, 0, 0.1, 0.2)
  eta <- sweep(scores %*% t(Lambda), 2L, beta, "+")
  prob <- 1 - exp(-exp(eta))
  Y <- matrix(rbinom(n * p, 1L, prob), n, p)
  dat <- data.frame(
    y = as.vector(Y),
    unit = rep(seq_len(n), times = p),
    trait = rep(seq_len(p), each = n)
  )
  fit <- gllvmTMB:::.va_r3_fit(
    y = dat$y,
    n_trials = rep(1, nrow(dat)),
    X = unname(model.matrix(~ 0 + factor(dat$trait, levels = seq_len(p)))),
    unit_id = dat$unit,
    trait_id = dat$trait,
    q = q,
    family = "binomial_cloglog",
    H = 7L,
    eval_method = "poisg",
    n_starts = 1L,
    rebuild = FALSE,
    silent = TRUE
  )
  expect_identical(fit$eval_method, "poisg")
  expect_identical(fit$objective_type, "ELBO_POISG")
  expect_true(is.finite(fit$report$elbo))
  expect_true(is.finite(fit$best$objective))
})

test_that("compiled template refuses poisg on non-cloglog data", {
  skip_if_not(requireNamespace("TMB", quietly = TRUE))
  set.seed(1)
  n <- 6L
  p <- 2L
  Y <- matrix(rbinom(n * p, 1L, 0.4), n, p)
  dat <- data.frame(
    y = as.vector(Y),
    unit = rep(seq_len(n), times = p),
    trait = rep(seq_len(p), each = n)
  )
  expect_error(
    gllvmTMB:::.va_r3_make_objective(
      gllvmTMB:::.va_r3_validate_data(
        y = dat$y,
        n_trials = rep(1, nrow(dat)),
        X = unname(model.matrix(~ 0 + factor(dat$trait, levels = seq_len(p)))),
        unit_id = dat$unit,
        trait_id = dat$trait,
        q = 1L,
        family = "binomial"
      ),
      H = 7L, eval_method = "poisg"
    ),
    "not implemented for the binomial"
  )
})
