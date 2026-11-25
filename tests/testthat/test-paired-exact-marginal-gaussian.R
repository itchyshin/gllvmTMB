.paired_exact_fixture <- function(n_side = 6L) {
  species <- c(paste0("H", seq_len(n_side)), paste0("P", seq_len(n_side)))
  A <- 0.55 ^ abs(outer(seq_len(n_side), seq_len(n_side), `-`))
  I <- diag(n_side)
  K_phy <- rbind(cbind(A, 0.4 * A), cbind(0.4 * A, A))
  K_tip <- rbind(cbind(I, 0.3 * I), cbind(0.3 * I, I))
  dimnames(K_phy) <- dimnames(K_tip) <- list(species, species)
  data <- data.frame(
    species = factor(species, levels = species),
    H1 = c(sin(seq_len(n_side)), rep(NA_real_, n_side)),
    H2 = c(cos(seq_len(n_side)), rep(NA_real_, n_side)),
    P1 = c(rep(NA_real_, n_side), sin(seq_len(n_side) + 0.2)),
    P2 = c(rep(NA_real_, n_side), cos(seq_len(n_side) + 0.2))
  )
  list(data = data, K_phy = K_phy, K_tip = K_tip, species = species)
}

.paired_exact_args <- function(fixture, known_V = NULL, rank = 1L) {
  K_phy <- fixture$K_phy
  K_tip <- fixture$K_tip
  V <- known_V
  known_term <- if (is.null(known_V)) "" else "+ meta_V(V = V, type = 'exact')"
  list(
    formula = stats::as.formula(
      paste0(
        "traits(H1, H2, P1, P2) ~ 1 + kernel_latent(species, K = K_phy, d = ",
        as.integer(rank), ", name = 'phy', unique = TRUE) + kernel_latent(species, K = K_tip, d = ",
        as.integer(rank), ", name = 'tip', unique = TRUE) ",
        known_term
      ),
      env = environment()
    ),
    data = fixture$data,
    family = gaussian(),
    unit = "species",
    cluster = "species",
    missing = miss_control(response = "include"),
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE,
    known_sigma_eps = 0,
    known_V = known_V
  )
}

.capture_paired_exact_tmb <- function(args) {
  captured <- NULL
  testthat::local_mocked_bindings(
    MakeADFun = function(data, parameters, ...) {
      captured <<- c(list(data = data, parameters = parameters), list(...))
      stop("PAIRED_EXACT_GAUSSIAN_CAPTURE", call. = FALSE)
    },
    .package = "TMB"
  )
  error <- tryCatch({
    suppressWarnings(do.call(gllvmTMB, args))
    NULL
  }, error = conditionMessage)
  list(error = error, captured = captured)
}

.paired_exact_unpack_loadings <- function(theta, n_trait, rank) {
  stopifnot(length(theta) == n_trait * rank - rank * (rank - 1L) / 2L)
  Lambda <- matrix(0, nrow = n_trait, ncol = rank)
  cursor <- 1L
  for (column in seq_len(rank)) {
    Lambda[column, column] <- theta[cursor]
    cursor <- cursor + 1L
  }
  for (column in seq_len(rank)) {
    if (column < n_trait) {
      for (row in seq.int(column + 1L, n_trait)) {
        Lambda[row, column] <- theta[cursor]
        cursor <- cursor + 1L
      }
    }
  }
  Lambda
}

.paired_exact_oracle_value <- function(input, parameters) {
  data <- input$data
  n_trait <- max(data$exact_trait_id) + 1L
  n_tier <- 2L
  Sigma <- vector("list", n_tier)
  theta_cursor <- 1L
  for (r in seq_len(n_tier)) {
    idx <- ((r - 1L) * n_trait + 1L):(r * n_trait)
    rank <- data$kernel_rank[r]
    n_packed <- n_trait * rank - rank * (rank - 1L) / 2L
    theta_idx <- theta_cursor:(theta_cursor + n_packed - 1L)
    Lambda <- .paired_exact_unpack_loadings(
      parameters$theta_rr_kernel[theta_idx], n_trait, rank
    )
    theta_cursor <- theta_cursor + n_packed
    Sigma[[r]] <- tcrossprod(Lambda) + diag(parameters$psi_kernel_variance[idx])
  }
  rows <- data$exact_eta_index + 1L
  mean <- drop(data$X_fix[rows, , drop = FALSE] %*% parameters$b_fix) +
    data$offset_vec[rows]
  .paper2_marginal_gaussian(
    y = data$exact_y,
    unit_id = data$exact_unit_id + 1L,
    trait_id = data$exact_trait_id + 1L,
    K_phy = data$K_kernel_raw[1L, , ],
    K_tip = data$K_kernel_raw[2L, , ],
    Sigma_phy = Sigma[[1L]],
    Sigma_tip = Sigma[[2L]],
    V_known = data$V_known_marginal,
    mean = mean
  )$nll
}

test_that("zero known observation SD selects the exact paired-kernel route", {
  skip_on_cran()
  fixture <- .paired_exact_fixture()
  captured <- .capture_paired_exact_tmb(.paired_exact_args(fixture))
  expect_identical(captured$error, "PAIRED_EXACT_GAUSSIAN_CAPTURE")
  expect_true(is.list(captured$captured))
  expect_identical(captured$captured$data$use_exact_pair_marginal, 1L)
  expect_equal(unname(captured$captured$data$K_kernel_raw[1L, , ]),
               unname(fixture$K_phy))
  expect_equal(unname(captured$captured$data$K_kernel_raw[2L, , ]),
               unname(fixture$K_tip))
  expected_cells <- expand.grid(
    trait_id = 0:3,
    unit_id = 0:(length(fixture$species) - 1L)
  )
  observed <- expected_cells$unit_id < length(fixture$species) / 2 &
    expected_cells$trait_id < 2L |
    expected_cells$unit_id >= length(fixture$species) / 2 &
      expected_cells$trait_id >= 2L
  expect_setequal(
    paste(captured$captured$data$exact_unit_id,
          captured$captured$data$exact_trait_id),
    paste(expected_cells$unit_id[observed], expected_cells$trait_id[observed])
  )
  observed_eta <- captured$captured$data$exact_eta_index + 1L
  observed_trait <- captured$captured$data$exact_trait_id + 1L
  X_observed <- captured$captured$data$X_fix[observed_eta, , drop = FALSE]
  expect_equal(ncol(X_observed), 4L)
  expect_equal(max.col(X_observed, ties.method = "first"), observed_trait)
  expect_equal(unname(rowSums(X_observed)), rep(1, length(observed_trait)))
  expect_length(captured$captured$parameters$psi_kernel_variance, 8L)
})

test_that("the exact marginal objective and gradient match the dense oracle", {
  fixture <- .paired_exact_fixture()
  captured <- .capture_paired_exact_tmb(.paired_exact_args(fixture))
  expect_identical(captured$error, "PAIRED_EXACT_GAUSSIAN_CAPTURE")
  input <- captured$captured
  obj <- do.call(TMB::MakeADFun, input)
  oracle_fn <- function(par) {
    .paired_exact_oracle_value(input, obj$env$parList(par))
  }
  par <- obj$par
  native_nll <- obj$fn(par)
  oracle_nll <- oracle_fn(par)
  native_gradient <- obj$gr(par)
  oracle_gradient <- vapply(seq_along(par), function(i) {
    step <- 1e-5 * max(1, abs(par[i]))
    plus <- minus <- par
    plus[i] <- plus[i] + step
    minus[i] <- minus[i] - step
    (oracle_fn(plus) - oracle_fn(minus)) / (2 * step)
  }, numeric(1L))
  expect_equal(native_nll, oracle_nll, tolerance = 1e-9)
  expect_true(max(abs(native_gradient - oracle_gradient)) < 2e-5)

  psi_idx <- grep("^psi_kernel_variance", names(par))
  boundary_par <- par
  boundary_par[psi_idx[1L]] <- 0
  expect_true(is.finite(obj$fn(boundary_par)))
  expect_equal(obj$fn(boundary_par), oracle_fn(boundary_par), tolerance = 1e-9)
})

test_that("the fast tape routes a valid joint-zero Psi boundary to dense", {
  fixture <- .paired_exact_fixture()
  captured <- .capture_paired_exact_tmb(.paired_exact_args(fixture))
  expect_identical(captured$error, "PAIRED_EXACT_GAUSSIAN_CAPTURE")
  input <- captured$captured
  expect_identical(input$data$exact_use_woodbury, 1L)
  fast_obj <- do.call(TMB::MakeADFun, input)
  dense_input <- input
  dense_input$data$exact_use_woodbury <- 0L
  dense_builds <- 0L
  routed <- .gllvmTMB_route_exact_pair_objective(
    fast_obj = fast_obj,
    make_dense_obj = function() {
      dense_builds <<- dense_builds + 1L
      do.call(TMB::MakeADFun, dense_input)
    },
    n_traits = 4L,
    n_tiers = 2L
  )
  expect_equal(routed$fn(fast_obj$par), fast_obj$fn(fast_obj$par), tolerance = 1e-10)
  expect_identical(dense_builds, 0L)

  boundary_par <- fast_obj$par
  psi_idx <- grep("^psi_kernel_variance", names(boundary_par))
  boundary_par[psi_idx[c(1L, 5L)]] <- 0
  oracle <- .paired_exact_oracle_value(input, fast_obj$env$parList(boundary_par))
  expect_silent(chol(.paper2_observed_covariance(
    unit_id = input$data$exact_unit_id + 1L,
    trait_id = input$data$exact_trait_id + 1L,
    K_phy = input$data$K_kernel_raw[1L, , ],
    K_tip = input$data$K_kernel_raw[2L, , ],
    Sigma_phy = {
      p <- fast_obj$env$parList(boundary_par)
      L <- .paired_exact_unpack_loadings(p$theta_rr_kernel[1:4], 4L, 1L)
      tcrossprod(L) + diag(p$psi_kernel_variance[1:4])
    },
    Sigma_tip = {
      p <- fast_obj$env$parList(boundary_par)
      L <- .paired_exact_unpack_loadings(p$theta_rr_kernel[5:8], 4L, 1L)
      tcrossprod(L) + diag(p$psi_kernel_variance[5:8])
    }
  )))
  expect_equal(routed$fn(boundary_par), oracle, tolerance = 1e-9)
  dense_oracle_fn <- function(par) {
    .paired_exact_oracle_value(input, fast_obj$env$parList(par))
  }
  boundary_indices <- psi_idx[c(1L, 5L)]
  oracle_gradient <- vapply(seq_along(boundary_par), function(i) {
    step <- if (i %in% boundary_indices) 1e-6 else
      1e-5 * max(1, abs(boundary_par[i]))
    plus <- minus <- boundary_par
    plus[i] <- plus[i] + step
    if (i %in% boundary_indices) {
      (dense_oracle_fn(plus) - dense_oracle_fn(boundary_par)) / step
    } else {
      minus[i] <- minus[i] - step
      (dense_oracle_fn(plus) - dense_oracle_fn(minus)) / (2 * step)
    }
  }, numeric(1L))
  expect_true(max(abs(routed$gr(boundary_par) - oracle_gradient)) < 3e-5)
  expect_identical(dense_builds, 1L)

  # The fitted object must retain value-based routing. Choosing the backend
  # once at the interior optimum makes later boundary curvature calls wrong.
  returned_obj <- .gllvmTMB_exact_pair_backend(routed, fast_obj$par)
  expect_false(is.null(attr(returned_obj, "gllvmTMB_exact_pair_router")))
  expect_equal(returned_obj$fn(boundary_par), oracle, tolerance = 1e-9)
  expect_true(max(abs(returned_obj$gr(boundary_par) - oracle_gradient)) < 3e-5)

  near_boundary_par <- boundary_par
  near_boundary_par[boundary_indices] <- 1e-4
  dense_obj <- attr(returned_obj, "gllvmTMB_exact_pair_router")$dense
  expect_true(is.function(returned_obj$he))
  expect_true(is.function(dense_obj$he))
  expect_equal(
    returned_obj$he(near_boundary_par), dense_obj$he(near_boundary_par),
    tolerance = 1e-8
  )

  below_switch_par <- boundary_par
  below_switch_par[boundary_indices] <- 4e-4
  above_switch_par <- boundary_par
  above_switch_par[boundary_indices] <- 6e-4
  for (par in list(below_switch_par, above_switch_par)) {
    expect_equal(returned_obj$fn(par), dense_obj$fn(par), tolerance = 1e-8)
    expect_equal(returned_obj$gr(par), dense_obj$gr(par), tolerance = 1e-7)
    expect_equal(returned_obj$he(par), dense_obj$he(par), tolerance = 1e-6)
  }
})

test_that("declared meta_V covariance enters the observed-record likelihood", {
  fixture <- .paired_exact_fixture()
  known_V <- diag(rep(0.025, 4L * length(fixture$species)))
  captured <- .capture_paired_exact_tmb(
    .paired_exact_args(fixture, known_V = known_V)
  )
  expect_identical(captured$error, "PAIRED_EXACT_GAUSSIAN_CAPTURE")
  rows <- captured$captured$data$exact_eta_index + 1L
  expect_identical(captured$captured$data$exact_has_known_V, 1L)
  expect_equal(
    captured$captured$data$V_known_marginal,
    known_V[rows, rows, drop = FALSE]
  )
  obj <- do.call(TMB::MakeADFun, captured$captured)
  expect_equal(
    obj$fn(obj$par),
    .paired_exact_oracle_value(captured$captured, obj$env$parList(obj$par)),
    tolerance = 1e-9
  )
})

test_that("near-identity observed kernel blocks use the raw dense likelihood", {
  fixture <- .paired_exact_fixture()
  fixture$K_tip <- fixture$K_tip + diag(5e-11, nrow(fixture$K_tip))
  captured <- .capture_paired_exact_tmb(.paired_exact_args(fixture))
  expect_identical(captured$error, "PAIRED_EXACT_GAUSSIAN_CAPTURE")
  input <- captured$captured
  expect_identical(input$data$exact_use_woodbury, 0L)
  expect_identical(input$data$exact_use_eigenmodes, 0L)
  expect_equal(
    unname(input$data$K_kernel_raw[2L, , ]),
    unname(fixture$K_tip),
    tolerance = 0
  )
  obj <- do.call(TMB::MakeADFun, input)
  expect_equal(
    obj$fn(obj$par),
    .paired_exact_oracle_value(input, obj$env$parList(obj$par)),
    tolerance = 1e-9
  )
})

test_that("the exact route matches the full-mask Paper 1 A plus I mapping", {
  fixture <- .paired_exact_fixture()
  n <- length(fixture$species)
  fixture$K_phy <- 0.55 ^ abs(outer(seq_len(n), seq_len(n), `-`))
  fixture$K_tip <- diag(n)
  dimnames(fixture$K_phy) <- dimnames(fixture$K_tip) <-
    list(fixture$species, fixture$species)
  for (j in seq_len(ncol(fixture$data) - 1L)) {
    fixture$data[[j + 1L]] <- sin(seq_len(n) * (0.12 + j / 10))
  }
  captured <- .capture_paired_exact_tmb(.paired_exact_args(fixture))
  expect_identical(captured$error, "PAIRED_EXACT_GAUSSIAN_CAPTURE")
  expect_length(captured$captured$data$exact_y, n * 4L)

  input <- captured$captured
  expect_identical(input$data$exact_use_eigenmodes, 1L)
  expect_identical(input$data$exact_use_woodbury, 0L)
  obj <- do.call(TMB::MakeADFun, input)
  oracle_fn <- function(par) {
    .paired_exact_oracle_value(input, obj$env$parList(par))
  }
  expect_equal(
    obj$fn(obj$par),
    oracle_fn(obj$par),
    tolerance = 1e-9
  )
  oracle_gradient <- vapply(seq_along(obj$par), function(i) {
    step <- 1e-5 * max(1, abs(obj$par[i]))
    plus <- minus <- obj$par
    plus[i] <- plus[i] + step
    minus[i] <- minus[i] - step
    (oracle_fn(plus) - oracle_fn(minus)) / (2 * step)
  }, numeric(1L))
  expect_true(max(abs(obj$gr(obj$par) - oracle_gradient)) < 2e-5)

  # The spectral blocks remain nonsingular when both Psi terms vanish for a
  # trait but its shared covariance keeps the complete Gaussian model PD.
  boundary_par <- obj$par
  psi_idx <- grep("^psi_kernel_variance", names(boundary_par))
  boundary_par[psi_idx[c(1L, 5L)]] <- 0
  expect_equal(obj$fn(boundary_par), oracle_fn(boundary_par), tolerance = 1e-9)
  expect_true(all(is.finite(obj$gr(boundary_par))))
})

test_that("exact route rejects invalid known sampling covariance", {
  fixture <- .paired_exact_fixture()
  V <- diag(nrow(fixture$data) * 4L)
  diag(V)[1L] <- NA_real_
  expect_error(
    do.call(gllvmTMB, .paired_exact_args(fixture, known_V = V)),
    class = "gllvmTMB_exact_gaussian_invalid_known_V"
  )
  V <- diag(nrow(fixture$data) * 4L)
  V[1L, 2L] <- 1
  expect_error(
    do.call(gllvmTMB, .paired_exact_args(fixture, known_V = V)),
    class = "gllvmTMB_exact_gaussian_invalid_known_V"
  )
  V <- diag(nrow(fixture$data) * 4L)
  V[1L, 1L] <- -1
  expect_error(
    do.call(gllvmTMB, .paired_exact_args(fixture, known_V = V)),
    class = "gllvmTMB_exact_gaussian_invalid_known_V"
  )
})

test_that("exact paired-kernel fits preserve named covariance extractors", {
  fixture <- .paired_exact_fixture()
  args <- .paired_exact_args(fixture)
  args$control <- gllvmTMBcontrol(se = TRUE)
  fit <- do.call(gllvmTMB, args)
  expect_identical(as.integer(fit$fit$convergence), 0L)
  expect_true(inherits(fit$sd_report, "sdreport"))
  expect_false(is.null(attr(fit$tmb_obj, "gllvmTMB_exact_pair_router")))
  expect_equal(as.numeric(fit$report$sigma_eps), 0)
  expect_true(any(fit$report$sd_kernel_diag == 0))
  expect_identical(fit$kernel_levels$name, c("phy", "tip"))
  expect_identical(names(fit$kernel_matrices), c("phy", "tip"))
  for (name in c("phy", "tip")) {
    expect_identical(rownames(fit$kernel_matrices[[name]]), fixture$species)
    expect_identical(colnames(fit$kernel_matrices[[name]]), fixture$species)
  }
  expected_traits <- c("H1", "H2", "P1", "P2")
  for (name in c("phy", "tip")) {
    shared <- extract_Sigma(fit, level = name, part = "shared")$Sigma
    unique <- extract_Sigma(fit, level = name, part = "unique")$s
    total <- extract_Sigma(fit, level = name, part = "total")$Sigma
    expect_identical(rownames(shared), expected_traits)
    expect_identical(colnames(shared), expected_traits)
    expect_equal(total, shared + diag(unique), tolerance = 1e-8)
    gamma <- extract_Gamma(
      fit, level = name, row_traits = c("H1", "H2"),
      col_traits = c("P1", "P2")
    )
    expect_identical(rownames(gamma), c("H1", "H2"))
    expect_identical(colnames(gamma), c("P1", "P2"))
    expect_equal(
      gamma,
      shared[c("H1", "H2"), c("P1", "P2"), drop = FALSE],
      tolerance = 1e-8
    )
  }

  # Exercise the object returned by gllvmTMB() after optimization selected its
  # backend. At a joint-zero Psi boundary, objective, gradient, and curvature
  # must all use the dense tape, including later calls through the fit object.
  boundary_par <- fit$opt$par
  psi_idx <- grep("^psi_kernel_variance", names(boundary_par))
  boundary_indices <- psi_idx[c(1L, 5L)]
  boundary_par[boundary_indices] <- 0
  boundary_nll <- fit$tmb_obj$fn(boundary_par)
  boundary_gradient <- fit$tmb_obj$gr(boundary_par)
  boundary_hessian <- fit$tmb_obj$he(boundary_par)
  router <- attr(fit$tmb_obj, "gllvmTMB_exact_pair_router")
  expect_true(is.finite(boundary_nll))
  expect_true(all(is.finite(boundary_gradient)))
  expect_true(all(is.finite(boundary_hessian)))
  expect_equal(boundary_nll, router$dense$fn(boundary_par), tolerance = 1e-10)
  expect_equal(boundary_gradient, router$dense$gr(boundary_par), tolerance = 1e-8)
  expect_equal(boundary_hessian, router$dense$he(boundary_par), tolerance = 1e-8)
  boundary_sdreport <- TMB::sdreport(fit$tmb_obj, par.fixed = boundary_par)
  dense_sdreport <- TMB::sdreport(router$dense, par.fixed = boundary_par)
  expect_equal(boundary_sdreport$pdHess, dense_sdreport$pdHess)
  expect_equal(
    boundary_sdreport$cov.fixed, dense_sdreport$cov.fixed,
    tolerance = 1e-8
  )

  profile_fit <- fit
  profile_fit$opt$par <- boundary_par
  profile_fit$opt$objective <- boundary_nll
  fit$tmb_obj$fn(boundary_par)
  fit$tmb_obj$env$last.par.best <- fit$tmb_obj$env$last.par
  backend_before_profile <- router$backend
  profile_dense_pars <- list()
  router$dense <- NULL
  router$backend <- function(par) {
    backend <- backend_before_profile(par)
    if (identical(backend, router$dense)) {
      profile_dense_pars[[length(profile_dense_pars) + 1L]] <<- as.numeric(par)
    }
    backend
  }
  psi_profile <- tmbprofile_wrapper(
    profile_fit, name = "psi_kernel_variance", which = 1L,
    ytol = 1, parm.range = c(0, Inf)
  )
  expect_true(is.finite(psi_profile[["estimate"]]))
  expect_true(length(profile_dense_pars) > 0L)
  expect_true(any(vapply(profile_dense_pars, function(p) {
    all(p[boundary_indices] == 0)
  }, logical(1L))))
})

test_that("dense fallback dispatch is exact at the Psi-sum threshold", {
  fixture <- .paired_exact_fixture()
  captured <- .capture_paired_exact_tmb(.paired_exact_args(fixture))
  expect_identical(captured$error, "PAIRED_EXACT_GAUSSIAN_CAPTURE")
  input <- captured$captured
  fast_obj <- do.call(TMB::MakeADFun, input)
  dense_input <- input
  dense_input$data$exact_use_woodbury <- 0L
  dense_obj <- do.call(TMB::MakeADFun, dense_input)
  routed <- .gllvmTMB_route_exact_pair_objective(
    fast_obj = fast_obj,
    make_dense_obj = function() dense_obj,
    n_traits = 4L,
    n_tiers = 2L
  )
  router <- attr(routed, "gllvmTMB_exact_pair_router")
  psi_idx <- grep("^psi_kernel_variance", names(fast_obj$par))
  deltas <- c(0, 0.0005, 0.001, 0.0011, 0.01)
  expect_identical(2 * 0.0005, 0.001)

  selected_dense <- logical(length(deltas))
  for (i in seq_along(deltas)) {
    par <- fast_obj$par
    # The first trait has two Psi entries; all other traits retain their
    # interior starts so only this one trait controls the dispatch boundary.
    par[psi_idx[c(1L, 5L)]] <- deltas[i] / 2
    backend <- router$backend(par)
    selected_dense[i] <- identical(backend, router$dense)
    expect_equal(
      routed$fn(par),
      if (selected_dense[i]) dense_obj$fn(par) else fast_obj$fn(par),
      tolerance = 1e-10
    )
    expect_equal(
      routed$gr(par),
      if (selected_dense[i]) dense_obj$gr(par) else fast_obj$gr(par),
      tolerance = 1e-9
    )
    expect_equal(
      routed$he(par),
      if (selected_dense[i]) dense_obj$he(par) else fast_obj$he(par),
      tolerance = 1e-8
    )
  }
  expect_identical(selected_dense, c(TRUE, TRUE, TRUE, FALSE, FALSE))
})

test_that("rank-two exact marginal likelihood matches the dense oracle", {
  fixture <- .paired_exact_fixture()
  captured <- .capture_paired_exact_tmb(
    .paired_exact_args(fixture, rank = 2L)
  )
  expect_identical(captured$error, "PAIRED_EXACT_GAUSSIAN_CAPTURE")
  input <- captured$captured
  expect_identical(as.integer(input$data$kernel_rank), c(2L, 2L))
  obj <- do.call(TMB::MakeADFun, input)
  oracle_fn <- function(par) {
    .paired_exact_oracle_value(input, obj$env$parList(par))
  }
  expect_equal(obj$fn(obj$par), oracle_fn(obj$par), tolerance = 1e-9)
  oracle_gradient <- vapply(seq_along(obj$par), function(i) {
    step <- 1e-5 * max(1, abs(obj$par[i]))
    plus <- minus <- obj$par
    plus[i] <- plus[i] + step
    minus[i] <- minus[i] - step
    (oracle_fn(plus) - oracle_fn(minus)) / (2 * step)
  }, numeric(1L))
  expect_true(max(abs(obj$gr(obj$par) - oracle_gradient)) < 2e-5)
})

test_that("the exact Gaussian likelihood matches a trait-specific fixed slope oracle", {
  fixture <- .paired_exact_fixture()
  captured <- .capture_paired_exact_tmb(.paired_exact_args(fixture))
  expect_identical(captured$error, "PAIRED_EXACT_GAUSSIAN_CAPTURE")

  input <- captured$captured
  data <- input$data
  unit_size <- seq(-1, 1, length.out = length(fixture$species))
  slope <- numeric(nrow(data$X_fix))
  use_slope <- data$exact_trait_id == 0L
  slope[data$exact_eta_index[use_slope] + 1L] <-
    unit_size[data$exact_unit_id[use_slope] + 1L]
  input$data$X_fix <- cbind(data$X_fix, size_slope_H1 = slope)
  input$parameters$b_fix <- c(input$parameters$b_fix, 0.35)

  obj <- do.call(TMB::MakeADFun, input)
  oracle_fn <- function(par) {
    .paired_exact_oracle_value(input, obj$env$parList(par))
  }
  expect_equal(obj$fn(obj$par), oracle_fn(obj$par), tolerance = 1e-9)
  oracle_gradient <- vapply(seq_along(obj$par), function(i) {
    step <- 1e-5 * max(1, abs(obj$par[i]))
    plus <- minus <- obj$par
    plus[i] <- plus[i] + step
    minus[i] <- minus[i] - step
    (oracle_fn(plus) - oracle_fn(minus)) / (2 * step)
  }, numeric(1L))
  expect_true(max(abs(obj$gr(obj$par) - oracle_gradient)) < 2e-5)
})

test_that("zero known observation SD remains outside a single-kernel route", {
  skip_on_cran()
  fixture <- .paired_exact_fixture()
  args <- .paired_exact_args(fixture)
  args$formula <- stats::as.formula(
    "traits(H1, H2, P1, P2) ~ 1 + kernel_latent(species, K = K_phy, d = 1, name = 'phy', unique = TRUE)",
    env = environment(args$formula)
  )
  expect_error(do.call(gllvmTMB, args))
})

test_that("exact marginal route rejects duplicate observed unit-trait cells", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_unique_marginal_cells(
      unit_id = c(0L, 0L, 1L),
      trait_id = c(0L, 0L, 1L)
    ),
    class = "gllvmTMB_exact_gaussian_duplicate_cell"
  )
  fixture <- .paired_exact_fixture(n_side = 3L)
  long <- data.frame(
    species = rep(fixture$species, times = 4L),
    trait = rep(c("H1", "H2", "P1", "P2"), each = length(fixture$species)),
    value = unlist(fixture$data[,-1L], use.names = FALSE)
  )
  long <- long[!is.na(long$value), , drop = FALSE]
  long <- rbind(long, long[1L, , drop = FALSE])
  K_phy <- fixture$K_phy
  K_tip <- fixture$K_tip
  formula <- value ~ 1 +
    kernel_latent(species, K = K_phy, d = 1, name = "phy", unique = TRUE) +
    kernel_latent(species, K = K_tip, d = 1, name = "tip", unique = TRUE)
  expect_error(
    gllvmTMB(
      formula, data = long, trait = "trait", family = gaussian(),
      unit = "species", cluster = "species",
      control = gllvmTMBcontrol(se = FALSE), known_sigma_eps = 0,
      silent = TRUE
    ),
    class = "gllvmTMB_exact_gaussian_duplicate_cell"
  )
})

test_that("exact marginal route accepts unique observed unit-trait cells", {
  expect_invisible(
    gllvmTMB:::.gllvmTMB_check_unique_marginal_cells(
      unit_id = c(0L, 0L, 1L),
      trait_id = c(0L, 1L, 1L)
    )
  )
})

test_that("exact marginal route rejects duplicated observed records before TMB", {
  fixture <- .paired_exact_fixture()
  fixture$data <- rbind(fixture$data, fixture$data[1L, , drop = FALSE])
  expect_error(
    do.call(gllvmTMB, .paired_exact_args(fixture)),
    class = "gllvmTMB_exact_gaussian_duplicate_cell"
  )
})
