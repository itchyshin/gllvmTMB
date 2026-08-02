## Design 108 / VA speed arc R3: the variational block moved out of the outer
## optimisation and into TMB's inner Newton solver via `profile=`.
##
## The switch is OPT-IN (`profile_variational = TRUE`). Everything here is
## therefore two claims at once: the new route reaches the SAME stationary
## point of the SAME objective, and the default route is untouched.

.va_r3_profile_sim <- function(N, T, q, family, seed = 11L) {
  set.seed(seed)
  beta <- seq(-0.35, 0.35, length.out = T)
  Lambda <- matrix(0, T, q)
  Lambda[row(Lambda) >= col(Lambda)] <-
    seq(0.7, -0.4, length.out = sum(row(Lambda) >= col(Lambda)))
  score <- matrix(stats::rnorm(N * q), N, q)
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  eta <- beta[trait] + rowSums(
    Lambda[trait, , drop = FALSE] * score[unit, , drop = FALSE]
  )
  trials <- rep(1L, N * T)
  y <- switch(
    family,
    gaussian_anchor = eta + stats::rnorm(N * T, 0, 0.5),
    poisson = stats::rpois(N * T, exp(eta)),
    binomial = {
      trials <- rep(12L, N * T)
      stats::rbinom(N * T, 12L, stats::plogis(eta))
    },
    nbinom2 = stats::rnbinom(N * T, mu = exp(eta), size = 3)
  )
  list(y = as.numeric(y), n_trials = as.integer(trials),
       X = unname(stats::model.matrix(~ 0 + factor(trait))),
       unit_id = as.integer(unit - 1L), trait_id = as.integer(trait - 1L),
       q = as.integer(q), family = family,
       link = switch(family, gaussian_anchor = "identity", poisson = "log",
                     binomial = "logit", nbinom2 = "log"))
}

.va_r3_profile_objects <- function(d, q, profile = FALSE, inner_control = NULL,
                                   H = 15L) {
  v <- .va_r3_validate_data(d$y, d$n_trials, d$X, d$unit_id, d$trait_id, q,
                            family = d$family, link = d$link)
  .va_r3_make_objective(v, H = H,
                        parameters = .va_r3_default_parameters(v, 1L),
                        profile_variational = profile,
                        inner_control = inner_control)
}

test_that("profile_variational is opt-in: the default objective is unchanged", {
  skip_on_cran()
  d <- .va_r3_profile_sim(40L, 5L, 2L, "poisson")
  default <- .va_r3_profile_objects(d, 2L)
  explicit <- .va_r3_profile_objects(d, 2L, profile = FALSE)
  expect_false(attr(default, "va_r3_profiled"))
  expect_identical(default$par, explicit$par)
  expect_identical(default$fn(default$par), explicit$fn(explicit$par))
  expect_identical(default$gr(default$par), explicit$gr(explicit$par))
  ## The variational block is still an ORDINARY outer parameter by default.
  expect_true(all(c("m", "log_L_diag", "L_off") %in% names(default$par)))
  expect_null(default$env$random)
})

test_that("profile= removes the variational block from the outer problem only", {
  skip_on_cran()
  d <- .va_r3_profile_sim(60L, 5L, 2L, "poisson")
  joint <- .va_r3_profile_objects(d, 2L)
  prof <- .va_r3_profile_objects(d, 2L, profile = TRUE)
  expect_true(attr(prof, "va_r3_profiled"))
  ## Outer par carries no variational coordinate; the FULL par vector still
  ## does, in the identical layout the joint object uses.
  expect_false(any(c("m", "log_L_diag", "L_off") %in% names(prof$par)))
  expect_lt(length(prof$par), length(joint$par))
  expect_identical(names(prof$env$par), names(joint$par))
  ## Laplace is DISABLED, so the profiled value is the exact inner minimum --
  ## never larger than the joint objective at the same variational start.
  expect_lte(prof$fn(prof$par), joint$fn(joint$par))
})

test_that("the inner Hessian is exactly block-diagonal and linear in N", {
  skip_on_cran()
  nnz <- vapply(c(40L, 80L, 160L), function(N) {
    d <- .va_r3_profile_sim(N, 5L, 2L, "poisson")
    o <- .va_r3_profile_objects(d, 2L, profile = TRUE)
    o$fn(o$par)
    sp <- o$env$spHess(random = TRUE)
    ## unit index of each variational coordinate: tier-major, then
    ## coordinate-slowest / level-fastest within a tier (Stage 6 layout).
    unit_of <- rep(rep(seq_len(N), times = 1L), 2L * 2L + 1L)
    ij <- Matrix::summary(methods::as(sp, "TsparseMatrix"))
    expect_identical(sum(unit_of[ij$i] != unit_of[ij$j]), 0L)
    nrow(ij)
  }, numeric(1))
  ## Exactly linear: doubling N doubles the stored entries.
  expect_equal(nnz[2] / nnz[1], 2, tolerance = 1e-12)
  expect_equal(nnz[3] / nnz[2], 2, tolerance = 1e-12)
})

test_that("the profiled fit reaches the same stationary point (L0-L3)", {
  skip_on_cran()
  hard <- list(eval.max = 100000L, iter.max = 100000L, rel.tol = 1e-15,
               x.tol = 1e-14, xf.tol = 1e-18, step.min = 1e-10)
  tight <- list(tol = 1e-14, tol10 = 1e-12, maxit = 5000L)
  for (family in c("gaussian_anchor", "poisson", "binomial")) {
    d <- .va_r3_profile_sim(80L, 6L, 2L, family)
    common <- list(y = d$y, n_trials = d$n_trials, X = d$X,
                   unit_id = d$unit_id, trait_id = d$trait_id, q = 2L,
                   family = family, link = d$link, H = 15L, n_starts = 1L,
                   optimizer = "nlminb", control = hard)
    joint <- do.call(.va_r3_fit, common)
    prof <- do.call(.va_r3_fit, c(common, list(profile_variational = TRUE,
                                               inner_control = tight)))
    expect_false(joint$profile_variational)
    expect_true(prof$profile_variational)
    pj <- joint$best$par
    pp <- prof$best$par
    ## `par` stays the FULL vector on both routes, so everything downstream
    ## (report(), the latent read-out) reads one layout.
    expect_identical(names(pj), names(pp))
    fixed <- names(pj) %in% c("beta", "theta_rr", "log_sigma", "log_phi")
    varia <- names(pj) %in% c("m", "log_L_diag", "L_off")

    ## L0: the ELBO at convergence.
    expect_lt(abs(joint$best$objective - prof$best$objective), 1e-6)
    ## L1 / L2: the parameters themselves, not just the objective.
    expect_lt(max(abs(pj[fixed] - pp[fixed])), 1e-3)
    expect_lt(max(abs(pj[varia] - pp[varia])), 1e-3)

    ## L3, the decisive test: feed the profiled solution's FULL parameter
    ## vector to the ORIGINAL joint objective (random = NULL) and require its
    ## gradient to vanish. Value agreement cannot establish this.
    obj0 <- .va_r3_profile_objects(d, 2L)
    expect_lt(max(abs(obj0$gr(pp))), 1e-4)

    ## The outer parameter count really did collapse.
    expect_lt(length(prof$best$outer_par), length(pj) / 5)
  }
})

test_that("L7 negative control: a deliberately crippled inner solve FAILS L3", {
  skip_on_cran()
  d <- .va_r3_profile_sim(80L, 6L, 2L, "poisson")
  common <- list(y = d$y, n_trials = d$n_trials, X = d$X,
                 unit_id = d$unit_id, trait_id = d$trait_id, q = 2L,
                 family = "poisson", link = "log", H = 15L, n_starts = 1L,
                 optimizer = "nlminb",
                 control = list(eval.max = 5000L, iter.max = 5000L))
  broken <- do.call(.va_r3_fit, c(common, list(
    profile_variational = TRUE,
    inner_control = list(tol = 1, tol10 = 1, maxit = 1L)
  )))
  obj0 <- .va_r3_profile_objects(d, 2L)
  ## If this passed, the L3 gate above would be measuring nothing.
  expect_gt(max(abs(obj0$gr(broken$best$par))), 1e-4)
})
