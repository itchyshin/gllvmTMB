# Native Gaussian coefficient coordinates: B = U L', U ~ MN(0, K, I).
# The physical model remains Cov(vec(B)) = Sigma %x% K, Sigma = L L'.
# These tests construct tapes without entering an outer optimizer. In
# particular, the retained Windows coordinates are NOT accepted fitted models.

.column_standard_capture <- function(fx, formula, ...) {
  payload <- NULL
  testthat::local_mocked_bindings(
    MakeADFun = function(data, parameters, map, random, ...) {
      payload <<- list(data = data, parameters = parameters, map = map,
                      random = random)
      stop("column-standard-payload-captured", call. = FALSE)
    }, .package = "TMB")
  testthat::local_mocked_bindings(
    .gllvmTMB_run_nlminb = function(...) stop("Unexpected outer optimizer"),
    .package = "gllvmTMB")
  args <- utils::modifyList(list(
    formula = formula, data = fx$data, trait = "trait", unit = "unit",
    family = gaussian(), silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L,
      start_method = list(method = NULL, jitter.sd = 0))
  ), list(...))
  err <- tryCatch(suppressMessages(do.call(gllvmTMB, args)), error = identity)
  expect_s3_class(err, "error")
  expect_identical(conditionMessage(err), "column-standard-payload-captured")
  expect_type(payload, "list")
  payload
}

.column_standard_L <- function(theta) {
  matrix(c(exp(theta[1L]), theta[3L], 0, exp(theta[2L])), 2L)
}

# Independent dense Gaussian calculation, in native observation order but
# using the fixture's raw source matrix. G maps column-major physical B to y.
.column_standard_reference <- function(payload, parameters, K) {
  d <- payload$data
  L <- .column_standard_L(parameters$theta_dep_chol)
  Sigma <- tcrossprod(L)
  ids <- d$phylo_slope_aug_id + 1L
  Z <- d$Z_phy_aug[, , 1L]
  X <- as.matrix(d$X_fix)
  n <- length(d$y)
  ns <- nrow(K)
  G <- matrix(0, n, 2L * ns)
  for (j in 1:2) G[cbind(seq_len(n), ids + (j - 1L) * ns)] <- Z[, j]
  S <- kronecker(Sigma, K)
  sigma2 <- exp(2 * parameters$log_sigma_eps)
  V <- G %*% S %*% t(G) + diag(sigma2, n)
  ch <- chol(V)
  Vi <- chol2inv(ch)
  e <- d$y - drop(X %*% parameters$b_fix)
  alpha <- drop(Vi %*% e)
  W <- Vi - tcrossprod(alpha)
  a <- L[1L, 1L]
  b <- L[2L, 1L]
  cc <- L[2L, 2L]
  derivatives <- list(matrix(c(2*a*a, a*b, a*b, 0), 2L),
                      matrix(c(0, 0, 0, 2*cc*cc), 2L),
                      matrix(c(0, a, a, 2*b), 2L))
  score <- c(-drop(crossprod(X, alpha)), sigma2 * sum(diag(W)),
    vapply(derivatives, function(ds) {
      .5 * sum(W * (G %*% kronecker(ds, K) %*% t(G)))
    }, numeric(1)))
  list(value = .5 * (n*log(2*pi) + 2*sum(log(diag(ch))) + sum(e*alpha)),
       gradient = score, B = array(drop(S %*% crossprod(G, alpha)),
                                  c(ns, 2L, 1L)),
       V = V, Vi = Vi, S = S, G = G, X = X)
}

.column_standard_tape <- function(payload, standardized = TRUE,
                                   parameters = payload$parameters,
                                   map = payload$map,
                                   random = payload$random) {
  dat <- payload$data
  dat$standardize_column_coef <- as.integer(standardized)
  TMB::MakeADFun(dat, parameters, map = map, random = random,
                DLL = "gllvmTMB", silent = TRUE)
}

test_that("Gaussian coefficient admission preserves physical starts and map fences", {
  fx <- .make_animal_coef_fixture(seed = 13142L)
  formula <- value ~ 0 + trait + animal_coef(0 + x + z | trait, A = fx$A)
  p <- .column_standard_capture(fx, formula)
  expect_identical(p$data$standardize_column_coef, 1L)
  expect_identical(p$random, "b_phy_aug")
  theta <- c(log(.3), log(.5), .12)
  B <- array(seq(-.4, .5, length.out = 10L), c(5L, 2L, 1L))
  source_parameters <- p$parameters
  source_parameters$b_phy_aug <- B
  source_parameters$theta_dep_chol <- theta
  # The public entry point supplies starts through control$start_from; it has
  # no start/map arguments. A retained physical-coordinate source needs no fit.
  source_fit <- structure(list(opt = list(par = numeric(0)),
    tmb_obj = list(env = list(last.par.best = numeric(0),
      parList = function(...) source_parameters))), class = "gllvmTMB")
  seeded <- .column_standard_capture(fx, formula,
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L,
      start_method = list(method = NULL, jitter.sd = 0), start_from = source_fit))
  L <- .column_standard_L(theta)
  expect_equal(seeded$parameters$b_phy_aug[, , 1L] %*% t(L), B[, , 1L],
               tolerance = 1e-13)
  expect_identical(seeded$parameters$theta_dep_chol, theta)

  # An explicit physical-coordinate map, including an identity map, is not
  # silently reinterpreted as a constraint on standardized U coordinates.
  # These are internal admission inputs, not a new public map API.
  eligible <- gllvmTMB:::.gllvmTMB_gaussian_column_coef_eligible
  admit <- function(map) eligible(p$data, map, source_parameters,
    REML = FALSE, estimator = "ml",
    control = list(integration = "laplace", aghq = FALSE))
  expect_true(admit(p$map))
  for (mp in list(factor(rep(NA_integer_, 10L)), factor(rep(1L, 10L)),
                  factor(seq_len(10L)))) {
    mapped <- p$map
    mapped$b_phy_aug <- mp
    expect_false(admit(mapped))
    expect_equal(source_parameters$b_phy_aug, B)
  }
  diagonal <- .column_standard_capture(fx,
    value ~ 0 + trait + animal_coef(0 + x + z || trait, A = fx$A))
  expect_identical(diagonal$data$standardize_column_coef, 1L)
  expect_true(is.na(diagonal$map$theta_dep_chol[3L]))
  ordinary <- .column_standard_capture(fx,
    value ~ 0 + trait + indep(0 + trait | unit))
  expect_identical(ordinary$data$standardize_column_coef, 0L)
  expect_warning(
    weighted <- .column_standard_capture(fx, formula,
      weights = rep(2, nrow(fx$data))),
    "Non-unit likelihood weights", fixed = TRUE
  )
  expect_identical(weighted$data$standardize_column_coef, 0L)
})

test_that("saved failing Windows coordinates have the exact finite Gaussian likelihood", {
  fx <- .make_animal_coef_fixture(seed = 13142L)
  p <- .column_standard_capture(fx,
    value ~ 0 + trait + animal_coef(0 + x + z | trait, A = fx$A))
  # Retained from Windows run 33335896752: both original fits returned code 1.
  # Neither this trial nor that returned endpoint is claimed to be an optimum.
  points <- list(
    endpoint = c(.19606999234788, .292570121154014, .291790291009749,
      .520411637157738, .068230748463446, -.807474951103855,
      -2.72818260859478, -18.2551280354576, .103093194124248),
    trial = c(.196069931847525, .292569719712437, .291790247657287,
      .520410381192265, .0682316351688025, -.807527229701107,
      -2.72826837232887, -27.5954199925794, .105815559867905)
  )
  for (point in points) {
    obj <- .column_standard_tape(p)
    tryCatch({
      names(point) <- names(obj$par)
      expect_identical(names(point), c(rep("b_fix", 5L), "log_sigma_eps",
                                      rep("theta_dep_chol", 3L)))
      tp <- p$parameters
      tp$b_fix <- point[1:5]
      tp$log_sigma_eps <- point[6L]
      tp$theta_dep_chol <- point[7:9]
      ref <- .column_standard_reference(p, tp, fx$A + diag(1e-8, 5L))
      expect_no_warning(value <- obj$fn(point))
      expect_true(is.finite(value))
      expect_lt(abs(value - ref$value), 1e-7)
      expect_lt(max(abs(as.numeric(obj$gr(point)) - ref$gradient)), 1e-5)
      report <- obj$report(obj$env$last.par)
      expect_equal(report$b_phy_aug_physical, ref$B, tolerance = 1e-7)
      expect_equal(report$eta, as.numeric(ref$X %*% tp$b_fix +
        ref$G %*% as.numeric(ref$B)), tolerance = 1e-7)
    }, finally = TMB::FreeADFun(obj))
  }
})

test_that("interior standardization preserves marginal values modes and the Jacobian", {
  fx <- .make_animal_coef_fixture(seed = 13142L)
  p <- .column_standard_capture(fx,
    value ~ 0 + trait + animal_coef(0 + x + z | trait, A = fx$A))
  p$parameters$theta_dep_chol <- c(log(.25), log(.35), .08)
  p$parameters$log_sigma_eps <- log(.45)
  old <- .column_standard_tape(p, FALSE)
  new <- .column_standard_tape(p, TRUE)
  on.exit({TMB::FreeADFun(old); TMB::FreeADFun(new)}, add = TRUE)
  par <- old$par
  expect_identical(par, new$par)
  expect_equal(new$fn(par), old$fn(par), tolerance = 1e-9)
  expect_equal(as.numeric(new$gr(par)), as.numeric(old$gr(par)), tolerance = 1e-8)
  ro <- old$report(old$env$last.par)
  rn <- new$report(new$env$last.par)
  bo <- old$env$parList(par, par = old$env$last.par)$b_phy_aug
  expect_equal(rn$b_phy_aug_physical, bo, tolerance = 1e-8)
  expect_equal(rn$eta, ro$eta, tolerance = 1e-8)
  expect_equal(rn$Sigma_b_dep, ro$Sigma_b_dep, tolerance = 1e-12)

  # Compare JOINT densities at matching physical B: changing variables adds
  # log|dB/dU| = n_source log|L|. Marginal densities above need no adjustment.
  tp <- p$parameters
  tp$b_phy_aug[] <- seq(-.2, .3, length.out = length(tp$b_phy_aug))
  B <- tp$b_phy_aug
  mp <- lapply(tp, function(x) factor(rep(NA_integer_, length(x))))
  mp$b_phy_aug <- NULL
  jo <- .column_standard_tape(p, FALSE, tp, mp, random = NULL)
  L <- .column_standard_L(tp$theta_dep_chol)
  tp$b_phy_aug[, , 1L] <- t(forwardsolve(L, t(B[, , 1L])))
  jn <- .column_standard_tape(p, TRUE, tp, mp, random = NULL)
  on.exit({TMB::FreeADFun(jo); TMB::FreeADFun(jn)}, add = TRUE)
  expect_equal(jn$fn(jn$par), jo$fn(jo$par) - 5L*sum(log(diag(L))),
               tolerance = 1e-9)
})

test_that("physical coefficient uncertainty includes uncertainty in fixed means", {
  fx <- .make_animal_coef_fixture(seed = 13142L)
  p <- .column_standard_capture(fx,
    value ~ 0 + trait + animal_coef(0 + x + z | trait, A = fx$A))
  tp <- p$parameters
  tp$theta_dep_chol <- c(log(.25), log(.35), .08)
  tp$log_sigma_eps <- log(.45)
  K <- fx$A + diag(1e-8, 5L)
  ref <- .column_standard_reference(p, tp, K)
  cb <- solve(crossprod(ref$X, ref$Vi %*% ref$X))
  tp$b_fix <- drop(cb %*% crossprod(ref$X, ref$Vi %*% p$data$y))
  ref <- .column_standard_reference(p, tp, K)
  mp <- lapply(tp, function(x) factor(rep(NA_integer_, length(x))))
  mp$b_fix <- mp$b_phy_aug <- NULL
  obj <- .column_standard_tape(p, TRUE, tp, mp)
  on.exit(TMB::FreeADFun(obj), add = TRUE)
  invisible(obj$fn(obj$par))
  expect_lt(max(abs(obj$gr(obj$par))), 1e-8)
  report <- obj$report(obj$env$last.par)
  sd <- TMB::sdreport(obj, par.fixed = obj$par, getReportCovariance = FALSE)
  expect_true(sd$pdHess)
  idx <- which(names(sd$value) == "b_phy_aug_physical")
  expect_length(idx, 10L)
  M <- ref$S %*% crossprod(ref$G, ref$Vi)
  conditional <- ref$S - M %*% ref$G %*% ref$S
  fixed_delta <- M %*% ref$X %*% cb %*% t(ref$X) %*% t(M)
  expect_gt(max(diag(fixed_delta)), 1e-5)
  expect_equal(sd$sd[idx]^2, diag(conditional + fixed_delta), tolerance = 1e-7)
  expect_equal(report$b_phy_aug_physical, ref$B, tolerance = 1e-8)
})

test_that("physical coefficient uncertainty includes estimated covariance scales", {
  # Orthogonal repeated observations give an analytic interior ML log-SD.
  # All means and the second coefficient variance are fixed; no outer fit.
  data <- expand.grid(unit = factor(paste0("u", 1:4)),
                      trait = factor(paste0("t", 1:4)))
  data$x <- rep(c(-1, 1, -1, 1), 4L)
  bhat <- c(-.8, -.3, .2, .9)
  second <- c(.1, -.4, .3, -.2)
  data$value <- bhat[as.integer(data$trait)] +
    data$x*second[as.integer(data$trait)] + rep(c(.1, .1, -.1, -.1), 4L)
  p <- .column_standard_capture(list(data = data),
    value ~ 0 + column_coef(1 + x | trait))
  tp <- p$parameters
  eps <- .4
  observation_variance <- eps^2/4
  total <- mean(bhat^2)
  psi <- total - observation_variance
  expect_gt(psi, 0)
  tp$theta_dep_chol <- c(.5*log(psi), log(.6), 0)
  tp$log_sigma_eps <- log(eps)
  mp <- lapply(tp, function(x) factor(rep(NA_integer_, length(x))))
  mp$b_phy_aug <- NULL
  mp$theta_dep_chol <- factor(c(1L, NA_integer_, NA_integer_))
  obj <- .column_standard_tape(p, TRUE, tp, mp)
  on.exit(TMB::FreeADFun(obj), add = TRUE)
  invisible(obj$fn(obj$par))
  expect_lt(max(abs(obj$gr(obj$par))), 1e-8)
  sd <- TMB::sdreport(obj, par.fixed = obj$par, getReportCovariance = FALSE)
  expect_true(sd$pdHess)
  idx <- which(names(sd$value) == "b_phy_aug_physical")
  expect_length(idx, 8L)
  conditional <- psi * observation_variance/total
  derivative <- 2*psi*observation_variance*bhat/total^2
  variance_theta <- total^2/(2*4*psi^2)
  delta <- derivative^2 * variance_theta
  expect_gt(max(delta), 1e-5)
  expect_equal(sd$sd[idx[1:4]]^2, conditional + delta, tolerance = 1e-7)
  expect_equal(as.numeric(sd$cov.fixed), variance_theta, tolerance = 1e-7)
})

test_that("warm starts copy physical coefficients before target standardization", {
  B <- array(c(.2, -.3, .4, .1), c(2L, 2L, 1L))
  theta <- c(log(.3), log(.5), .12)
  L <- .column_standard_L(theta)
  U <- B
  U[, , 1L] <- t(forwardsolve(L, t(B[, , 1L])))
  source <- list(b_phy_aug = U, theta_dep_chol = theta)
  fit <- structure(list(standardized_column_coef = TRUE,
    report = list(b_phy_aug_physical = B), opt = list(par = numeric(0)),
    tmb_obj = list(env = list(last.par.best = numeric(0),
      parList = function(...) source))), class = "gllvmTMB")
  target <- list(b_phy_aug = B*0, theta_dep_chol = theta*0)
  warm <- gllvmTMB:::.gllvmTMB_apply_start_from(target, fit)
  expect_equal(warm$params$b_phy_aug, B)
  expect_equal(warm$params$theta_dep_chol, theta)
  standardize <- gllvmTMB:::.gllvmTMB_column_coef_standardize_start
  expect_equal(standardize(warm$params$b_phy_aug, warm$params$theta_dep_chol), U,
               tolerance = 1e-13)
  fit$standardized_column_coef <- FALSE
  legacy <- gllvmTMB:::.gllvmTMB_apply_start_from(target, fit)
  expect_equal(legacy$params$b_phy_aug, U)
  fit$standardized_column_coef <- TRUE
  target$b_phy_aug <- array(0, c(3L, 2L, 1L))
  mismatched <- gllvmTMB:::.gllvmTMB_apply_start_from(target, fit)
  expect_identical(mismatched$params$b_phy_aug, target$b_phy_aug)

  # The helper must respect column-major lower-triangle packing and every
  # array block, not just the two-coefficient single-block regression above.
  theta3 <- c(log(.3), log(.5), log(.7), .12, -.08, .2)
  L3 <- matrix(c(.3, .12, -.08, 0, .5, .2, 0, 0, .7), 3L)
  B3 <- array(seq(-.5, .6, length.out = 12L), c(2L, 3L, 2L))
  U3 <- standardize(B3, theta3)
  for (k in 1:2) {
    expect_equal(U3[, , k] %*% t(L3), B3[, , k], tolerance = 1e-13)
  }
})
