## The A_i collapse: under Albert-Chib the variational covariance is
## data-independent, so every unit's A_i is the same matrix and the N per-unit
## blocks reduce to one. The closed form is PUBLISHED (dr25); implementing it is
## what is ours. See docs/design/ai-collapse-design.md.
##
## Two claims are tested, and the SECOND is the important one:
##   1. when admissible, the collapse reduces the free parameter count and
##      reaches the same optimum as the per-unit fit;
##   2. when NOT admissible, it REFUSES -- because `log_L_diag`/`L_off` are
##      shared by every eval_method, so collapsing them unconditionally would
##      silently change the publicly reachable "gh"/"jj" routes, where this
##      identity has never been derived.

.va_r3_ai_sim <- function(N = 60L, T = 8L, q = 1L, n_trials = 6L, seed = 4L) {
  set.seed(seed)
  lam <- matrix(stats::rnorm(T * q, 0, 0.8), T, q)
  lam[upper.tri(lam)] <- 0
  a <- matrix(stats::rnorm(N * q), N, q)
  eta <- sweep(a %*% t(lam), 2, stats::rnorm(T, 0, 0.3), "+")
  d <- data.frame(y = stats::rbinom(N * T, n_trials, stats::pnorm(as.vector(eta))),
                  unit = rep(seq_len(N), times = T),
                  trait = rep(seq_len(T), each = N))
  list(y = d$y, n_trials = rep(n_trials, nrow(d)),
       X = unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T)))),
       unit_id = d$unit, trait_id = d$trait, q = q,
       family = "binomial_probit", link = "probit")
}

.va_r3_ai_obj <- function(args, collapse, eval_method = "ac", ...) {
  extra <- list(...)
  vd <- do.call(gllvmTMB:::.va_r3_validate_data,
                c(args[intersect(names(args), names(formals(gllvmTMB:::.va_r3_validate_data)))],
                  extra))
  gllvmTMB:::.va_r3_make_objective(vd, H = 15L, eval_method = eval_method,
                                   collapse_variational_cov = collapse)
}

test_that("the collapse fires under AC and cuts the variational block to one shared value", {
  skip_on_cran()
  a <- .va_r3_ai_sim()
  plain <- .va_r3_ai_obj(a, collapse = FALSE)
  coll  <- .va_r3_ai_obj(a, collapse = TRUE)

  expect_false(attr(plain, "va_r3_collapsed"))
  expect_true(attr(coll, "va_r3_collapsed"))

  ## N per-unit log-diagonals become q. The parameter VECTOR keeps its length --
  ## only the number of FREE parameters drops -- which is why no downstream
  ## consumer of these names has to change.
  n_plain <- sum(names(plain$par) == "log_L_diag")
  n_coll  <- sum(names(coll$par)  == "log_L_diag")
  expect_equal(n_plain, 60L * 1L)
  expect_equal(n_coll, 1L)
  expect_lt(length(coll$par), length(plain$par))
})

test_that("the collapse REFUSES outside the regime it was derived for", {
  skip_on_cran()
  a <- .va_r3_ai_sim()

  ## (i) not Albert-Chib -- the publicly reachable routes must be untouched.
  gh <- .va_r3_ai_obj(a, collapse = TRUE, eval_method = "gh")
  expect_false(attr(gh, "va_r3_collapsed"))
  expect_match(attr(gh, "va_r3_collapse_note"), "Albert-Chib")

  ## (ii) n_trials not constant -- constancy across units fails.
  a2 <- a
  a2$n_trials[1L] <- a2$n_trials[1L] + 1L
  v2 <- .va_r3_ai_obj(a2, collapse = TRUE)
  expect_false(attr(v2, "va_r3_collapsed"))
  expect_match(attr(v2, "va_r3_collapse_note"), "n_trials")

  ## (iii) incomplete data -- A_i is then constant only within a missingness
  ## pattern, not across all units.
  obs <- rep(1L, length(a$y)); obs[c(3L, 17L)] <- 0L
  v3 <- .va_r3_ai_obj(a, collapse = TRUE, is_y_observed = obs)
  expect_false(attr(v3, "va_r3_collapsed"))
  expect_match(attr(v3, "va_r3_collapse_note"), "incomplete")
})

test_that("the collapse is opt-in: default leaves the per-unit block alone", {
  skip_on_cran()
  a <- .va_r3_ai_sim()
  default <- .va_r3_ai_obj(a, collapse = FALSE)
  expect_false(attr(default, "va_r3_collapsed"))
  expect_identical(attr(default, "va_r3_collapse_note"), "not requested")
})

test_that("the collapsed fit reaches the same optimum as the per-unit fit", {
  skip_on_cran()
  a <- .va_r3_ai_sim()
  ctl <- list(eval.max = 800L, iter.max = 400L)
  plain <- do.call(gllvmTMB:::.va_r3_fit,
    c(a, list(eval_method = "ac", n_starts = 1L, H = 15L, control = ctl)))
  coll <- do.call(gllvmTMB:::.va_r3_fit,
    c(a, list(eval_method = "ac", n_starts = 1L, H = 15L, control = ctl,
              collapse_variational_cov = TRUE)))

  ## The collapse enforces a structure the AC stationarity condition already
  ## implies, so it must not move the optimum.
  expect_equal(coll$best$objective, plain$best$objective, tolerance = 1e-4)
  expect_equal(
    gllvmTMB:::.va_r3_unpack_theta_rr(coll$best$par[names(coll$best$par) == "theta_rr"], 8L, 1L),
    gllvmTMB:::.va_r3_unpack_theta_rr(plain$best$par[names(plain$best$par) == "theta_rr"], 8L, 1L),
    tolerance = 1e-3)

  ## And the per-unit log-diagonals it produced really are all one value.
  ld <- coll$best$par[names(coll$best$par) == "log_L_diag"]
  expect_lt(diff(range(ld)), 1e-10)
})
