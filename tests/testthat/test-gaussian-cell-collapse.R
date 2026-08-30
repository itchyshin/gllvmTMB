# No outer optimization: intercept the wrapper before tape construction, then
# evaluate the compiled model at declared parameters. These checks exercise the
# actual package DLL, not a second implementation of the convolution alone.
.cell_collapse_data <- function() {
  x <- expand.grid(trait = factor(c("a", "b", "c")),
                   site = factor(paste0("s", seq_len(6))))
  x$species <- factor("sp1")
  x$value <- sin(seq_len(nrow(x))) + rep(c(-.4, .2, .6), 6)
  x
}

.cell_collapse_capture <- function(data = .cell_collapse_data(), ...) {
  captured <- NULL
  optimizer_entries <- 0L
  testthat::local_mocked_bindings(
    MakeADFun = function(data, parameters, map, random, ...) {
      captured <<- list(data = data, parameters = parameters,
                        map = map, random = random)
      stop("cell-collapse-payload-captured", call. = FALSE)
    }, .package = "TMB")
  testthat::local_mocked_bindings(
    .gllvmTMB_run_nlminb = function(...) {
      optimizer_entries <<- optimizer_entries + 1L
      stop("No outer optimizer is permitted in this test")
    }, .package = "gllvmTMB")
  args <- utils::modifyList(list(
    formula = value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = TRUE),
    data = data, family = gaussian(),
    control = gllvmTMBcontrol(se = FALSE, n_init = 1L,
      start_method = list(method = NULL, jitter.sd = 0)), silent = TRUE
  ), list(...))
  err <- tryCatch(suppressWarnings(suppressMessages(do.call(gllvmTMB, args))),
                  error = identity)
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "cell-collapse-payload-captured", fixed = TRUE)
  expect_identical(optimizer_entries, 0L)
  expect_type(captured, "list")
  captured
}

test_that("Gaussian cell integration admits complete cells and keeps fallback cases", {
  a <- .cell_collapse_capture()
  expect_identical(a$data$integrate_gaussian_diag_B, 1L)
  expect_false("s_B" %in% a$random)
  expect_true(all(is.na(a$map$s_B)))
  eligible <- getFromNamespace(".gllvmTMB_gaussian_diag_B_eligible", "gllvmTMB")
  free_map <- a$map
  free_map$s_B <- NULL
  # An inactive slope map is always present. Dollar partial matching must not
  # confuse s_B_slope with an explicit map for s_B itself.
  expect_true("s_B_slope" %in% names(free_map))
  admission <- function(mp) eligible(a$data, mp, a$parameters, REML = FALSE,
    estimator = "ml", control = list(integration = "laplace", aghq = FALSE))
  expect_true(admission(free_map))
  fixed_map <- free_map
  fixed_map$s_B <- factor(rep(NA_integer_, length(a$parameters$s_B)))
  expect_false(admission(fixed_map))
  tied_map <- free_map
  tied_map$s_B <- factor(rep(1L, length(a$parameters$s_B)))
  expect_false(admission(tied_map))

  d <- .cell_collapse_data()
  repeated <- .cell_collapse_capture(rbind(d, d[1, ]))
  weighted <- .cell_collapse_capture(d, weights = rep(2, nrow(d)))
  d$value[2] <- NA_real_
  missing <- .cell_collapse_capture(d, missing = miss_control(response = "include"))
  d <- .cell_collapse_data()
  d$value <- as.numeric(seq_len(nrow(d)) %% 4)
  counts <- .cell_collapse_capture(d, family = poisson())
  for (payload in list(repeated, weighted, missing, counts)) {
    expect_identical(payload$data$integrate_gaussian_diag_B, 0L)
    expect_true("s_B" %in% payload$random)
  }
})

test_that("compiled Gaussian convolution preserves value, scores and cell uncertainty", {
  payload <- .cell_collapse_capture()
  td <- payload$data
  tp <- payload$parameters
  p <- 3L
  ns <- 6L
  lambda <- c(.4, -.25, .3)
  psi <- c(.03, .3, 1.2)
  eps <- .2
  tp$theta_rr_B <- lambda
  tp$theta_diag_B <- .5 * log(psi)
  tp$log_sigma_eps[] <- log(eps)
  tp$s_B[] <- 0
  tp$z_B[] <- 0
  # Only the three trait means remain fixed-effect parameters. Their exact
  # Gaussian covariance is V / n_sites; no optimizer is needed to obtain it.
  tp$b_fix <- vapply(seq_len(p), function(t) mean(td$y[td$trait_id == t - 1L]), numeric(1))
  maps <- lapply(tp, function(x) factor(rep(NA_integer_, length(x))))
  maps$b_fix <- NULL
  maps$z_B <- NULL
  make <- function(collapsed) {
    dat <- td
    dat$integrate_gaussian_diag_B <- as.integer(collapsed)
    mp <- maps
    if (!collapsed) mp$s_B <- NULL
    TMB::MakeADFun(dat, tp, map = mp,
      random = if (collapsed) "z_B" else c("z_B", "s_B"),
      DLL = "gllvmTMB", silent = TRUE)
  }
  old <- make(FALSE)
  new <- make(TRUE)
  on.exit({ TMB::FreeADFun(old); TMB::FreeADFun(new) }, add = TRUE)
  b <- old$par
  expect_identical(names(b), names(new$par))
  expect_equal(new$fn(b), old$fn(b), tolerance = 1e-9)
  expect_equal(as.numeric(new$gr(b)), as.numeric(old$gr(b)), tolerance = 1e-8)
  ro <- old$report(old$env$last.par)
  rn <- new$report(new$env$last.par)
  expect_equal(rn$eta, ro$eta, tolerance = 1e-8)
  full <- old$env$last.par
  mode <- matrix(full[names(full) == "s_B"], p, ns)
  expect_equal(rn$s_B_conditional_mean, mode, tolerance = 1e-8)
  expect_equal(rn$s_B_conditional_variance,
    matrix(psi * eps^2 / (psi + eps^2), p, ns), tolerance = 1e-10)
  V <- tcrossprod(lambda) + diag(psi + eps^2)
  Vi <- solve(V)
  S <- diag(psi)
  # Total posterior uncertainty, including the estimated trait means. This
  # catches omission of either residual conditional variance or delta variance.
  expected <- diag(S - S %*% Vi %*% S + S %*% Vi %*% (V / ns) %*% Vi %*% S)
  so <- TMB::sdreport(old, par.fixed = b)
  sn <- TMB::sdreport(new, par.fixed = b, getReportCovariance = FALSE)
  expect_true(so$pdHess)
  expect_true(sn$pdHess)
  skeleton <- structure(list(use = list(diag_B = TRUE), n_traits = p,
    n_sites = ns, unit_col = "site", estimator = "ML"), class = "gllvmTMB_multi")
  fo <- skeleton
  fo$sd_report <- so
  fo$report <- ro
  fo$integrated_gaussian_diag_B <- FALSE
  fn <- skeleton
  fn$sd_report <- sn
  fn$report <- rn
  fn$integrated_gaussian_diag_B <- TRUE
  expect_equal(getREsd(fo, "diag_unit")^2, matrix(expected, p, ns), tolerance = 1e-7)
  expect_equal(getREsd(fn, "diag_unit")^2, matrix(expected, p, ns), tolerance = 1e-7)
  expect_equal(getREsd(fn, "diag_unit"), getREsd(fo, "diag_unit"), tolerance = 1e-7)
})

test_that("integrated cell uncertainty includes estimated unique variances", {
  payload <- .cell_collapse_capture()
  td <- payload$data
  tp <- payload$parameters
  p <- 3L
  ns <- 6L
  eps <- .2
  Y <- matrix(NA_real_, p, ns)
  Y[cbind(td$trait_id + 1L, td$site_id + 1L)] <- td$y
  means <- rowMeans(Y)
  E <- Y - means
  total_variance <- rowMeans(E^2)
  psi <- total_variance - eps^2
  expect_true(all(psi > 0))
  # Independent traits allow an exact interior ML endpoint without invoking
  # an optimizer. The latent block remains present, with zero fixed loadings.
  tp$b_fix <- means
  tp$theta_rr_B[] <- 0
  tp$theta_diag_B <- .5 * log(psi)
  tp$log_sigma_eps[] <- log(eps)
  tp$s_B[] <- 0
  tp$z_B[] <- 0
  maps <- lapply(tp, function(x) factor(rep(NA_integer_, length(x))))
  maps$b_fix <- NULL
  maps$theta_diag_B <- NULL
  maps$z_B <- NULL
  make <- function(collapsed) {
    dat <- td
    dat$integrate_gaussian_diag_B <- as.integer(collapsed)
    mp <- maps
    if (!collapsed) mp$s_B <- NULL
    TMB::MakeADFun(dat, tp, map = mp,
      random = if (collapsed) "z_B" else c("z_B", "s_B"),
      DLL = "gllvmTMB", silent = TRUE)
  }
  old <- make(FALSE)
  new <- make(TRUE)
  on.exit({ TMB::FreeADFun(old); TMB::FreeADFun(new) }, add = TRUE)
  par <- old$par
  expect_identical(names(par), names(new$par))
  expect_equal(new$fn(par), old$fn(par), tolerance = 1e-9)
  expect_lt(max(abs(new$gr(par))), 1e-8)
  expect_equal(as.numeric(new$gr(par)), as.numeric(old$gr(par)), tolerance = 1e-8)
  # Match production: sdreport's numerical fixed-effect Hessian can leave
  # last.par at a perturbation. Preserve reports at the declared endpoint
  # before requesting uncertainty, rather than rereading mutable tape state.
  ro <- old$report(old$env$last.par)
  rn <- new$report(new$env$last.par)
  so <- TMB::sdreport(old, par.fixed = par)
  sn <- TMB::sdreport(new, par.fixed = par, getReportCovariance = FALSE)
  expect_true(so$pdHess)
  expect_true(sn$pdHess)
  weight <- psi / total_variance
  conditional <- matrix(psi * eps^2 / total_variance, p, ns)
  mean_delta <- matrix(weight^2 * total_variance / ns, p, ns)
  # d E[s|y] / d theta = 2 psi eps^2 (y - b) / V^2,
  # theta = log SD, Cov(theta) = V^2 / (2 n psi^2) at this endpoint.
  # Omitting the derivative of the shrinkage weight loses this positive term.
  theta_delta <- (2 * psi * eps^2 / total_variance^2 * E)^2 *
    (total_variance^2 / (2 * ns * psi^2))
  expected <- conditional + mean_delta + theta_delta
  expect_gt(max(theta_delta), 1e-5)
  idx <- which(names(sn$value) == "s_B_conditional_mean")
  expect_length(idx, p * ns)
  expect_equal(matrix(sn$sd[idx]^2, p, ns), mean_delta + theta_delta,
               tolerance = 1e-7)
  expect_gt(max(abs(matrix(sn$sd[idx]^2, p, ns) - expected)), 1e-3)
  skeleton <- structure(list(use = list(diag_B = TRUE), n_traits = p,
    n_sites = ns, unit_col = "site", estimator = "ml"), class = "gllvmTMB_multi")
  fo <- skeleton
  fo$sd_report <- so
  fo$report <- ro
  fo$integrated_gaussian_diag_B <- FALSE
  fn <- skeleton
  fn$sd_report <- sn
  fn$report <- rn
  fn$integrated_gaussian_diag_B <- TRUE
  expect_equal(getREsd(fo, "diag_unit")^2, expected, tolerance = 1e-7)
  expect_equal(getREsd(fn, "diag_unit")^2, expected, tolerance = 1e-7)
  expect_equal(getREsd(fn, "diag_unit"), getREsd(fo, "diag_unit"), tolerance = 1e-7)
})
