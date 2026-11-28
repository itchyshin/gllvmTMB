## Unreplicated two-kernel coevolution with a fixed Gaussian observation SD.
## This is a small construction/objective oracle, not a recovery simulation.

.two_lineage_known_error_fixture <- function(identical_kernels = FALSE,
                                            cross_block_only = FALSE) {
  n_side <- 8L
  species <- c(paste0("H", seq_len(n_side)), paste0("P", seq_len(n_side)))
  A <- 0.6 ^ abs(outer(seq_len(n_side), seq_len(n_side), `-`))
  I <- diag(n_side)
  K_phy <- rbind(cbind(A, 0.55 * A), cbind(0.55 * A, A))
  K_tip <- rbind(cbind(I, 0.55 * I), cbind(0.55 * I, I))
  if (identical_kernels) K_tip <- K_phy
  if (cross_block_only) {
    K_phy <- rbind(cbind(A, 0.2 * A), cbind(0.2 * A, A))
    K_tip <- rbind(cbind(A, 0.1 * I), cbind(0.1 * I, A))
  }
  dimnames(K_phy) <- dimnames(K_tip) <- list(species, species)

  dat <- data.frame(
    species = factor(species, levels = species),
    row_id = factor(species, levels = species),
    H1 = c(sin(seq_len(n_side)), rep(NA_real_, n_side)),
    H2 = c(cos(seq_len(n_side)), rep(NA_real_, n_side)),
    P1 = c(rep(NA_real_, n_side), sin(seq_len(n_side) + 0.3)),
    P2 = c(rep(NA_real_, n_side), cos(seq_len(n_side) + 0.3))
  )
  list(data = dat, K_phy = K_phy, K_tip = K_tip, species = species)
}

.capture_two_lineage_known_error_tmb <- function(args) {
  captured <- NULL
  testthat::local_mocked_bindings(
    MakeADFun = function(data, parameters, ...) {
      captured <<- c(list(data = data, parameters = parameters), list(...))
      stop("TWO_LINEAGE_KNOWN_ERROR_CAPTURE", call. = FALSE)
    },
    .package = "TMB"
  )
  err <- tryCatch({
    suppressWarnings(do.call(gllvmTMB, args))
    NULL
  }, error = conditionMessage)
  list(error = err, captured = captured)
}

.two_lineage_known_error_args <- function(fixture, known_sigma_eps = NULL) {
  K_phy <- fixture$K_phy
  K_tip <- fixture$K_tip
  formula <- stats::as.formula(
    "traits(H1, H2, P1, P2) ~ 1 + kernel_latent(species, K = K_phy, d = 1, name = 'phy', unique = TRUE) + kernel_latent(species, K = K_tip, d = 1, name = 'tip', unique = TRUE)",
    env = environment()
  )
  args <- list(
    formula = formula,
    data = fixture$data,
    family = gaussian(),
    unit = "row_id",
    cluster = "species",
    missing = miss_control(response = "include"),
    control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  )
  if (!is.null(known_sigma_eps)) args$known_sigma_eps <- known_sigma_eps
  args
}

test_that("fixed known error retains both kernel Psi and the fixed intercept", {
  skip_on_cran()
  sigma_known <- sqrt(0.04 / 3)
  fixture <- .two_lineage_known_error_fixture()
  captured <- .capture_two_lineage_known_error_tmb(
    .two_lineage_known_error_args(fixture, known_sigma_eps = sigma_known)
  )

  if (is.null(captured$captured)) stop(captured$error)
  expect_identical(captured$error, "TWO_LINEAGE_KNOWN_ERROR_CAPTURE")
  z <- captured$captured
  expect_identical(as.integer(z$data$kernel_has_diag), c(1L, 1L))
  expect_length(z$parameters$log_sd_kernel_diag, 8L)
  expect_true(all(is.na(z$map$log_sigma_eps)))
  expect_equal(unname(z$parameters$log_sigma_eps), log(sigma_known),
               tolerance = 1e-14)
  expect_equal(z$data$use_equalto, 0L)
  expect_equal(ncol(z$data$X_fix), 4L)
  expect_equal(length(z$parameters$b_fix), 4L)
  expect_equal(sum(z$data$is_y_observed == 1L), 32L)
  expect_equal(sum(z$data$is_y_observed == 0L), 32L)

  ## Construct the compiled objective without optimizing a fit. For Gaussian
  ## latent effects, its Laplace objective must equal the dense marginal NLL.
  obj <- TMB::MakeADFun(
    data = z$data, parameters = z$parameters, map = z$map,
    random = z$random, DLL = z$DLL, silent = TRUE
  )
  value <- obj$fn(obj$par)
  gradient <- obj$gr(obj$par)
  report <- obj$report(obj$env$last.par.best)
  expect_true(is.finite(value))
  expect_true(all(is.finite(gradient)))

  dat <- z$data
  observed <- which(dat$is_y_observed == 1L)
  n <- length(observed)
  trait_id <- dat$trait_id[observed] + 1L
  species_id <- dat$kernel_group_id[observed] + 1L
  kernel_precision <- dat$Ainv_kernel
  kernel <- lapply(seq_len(dim(kernel_precision)[1L]), function(r) {
    solve(kernel_precision[r, , ])
  })
  sigma <- as.numeric(report$sigma_eps)[1L]
  S <- report$Sigma_kernel
  sd_psi <- report$sd_kernel_diag
  V <- matrix(0, n, n)
  for (i in seq_len(n)) for (j in seq_len(n)) {
    for (r in seq_along(kernel)) {
      kval <- kernel[[r]][species_id[i], species_id[j]]
      V[i, j] <- V[i, j] + S[trait_id[i], trait_id[j], r] * kval
      if (trait_id[i] == trait_id[j]) {
        V[i, j] <- V[i, j] + sd_psi[trait_id[i], r]^2 * kval
      }
    }
  }
  diag(V) <- diag(V) + sigma^2
  beta <- as.numeric(z$parameters$b_fix)
  residual <- as.numeric(dat$y[observed] - dat$X_fix[observed, , drop = FALSE] %*% beta)
  R <- chol(V)
  dense_nll <- 0.5 * (n * log(2 * pi) + 2 * sum(log(diag(R))) +
                        sum(backsolve(R, residual, transpose = TRUE)^2))
  cat(sprintf(
    "KNOWN_ERROR_OBJECTIVE value=%.15g dense_nll=%.15g abs_gap=%.3g n_observed=%d sigma_eps=%.15g active_psi=%s fixed_effects=%d\n",
    as.numeric(value), dense_nll, abs(as.numeric(value) - dense_nll), n,
    sigma, paste(as.integer(z$data$kernel_has_diag), collapse = ","),
    length(beta)
  ))
  expect_equal(as.numeric(value), as.numeric(dense_nll), tolerance = 2e-5,
               info = paste("objective", value, "dense", dense_nll,
                            "sigma", sigma, "beta", paste(beta, collapse = ","),
                            "dimensions", paste(dim(V), collapse = "x")))

  ## This objective owns TMB external pointers. Release it before the next
  ## test file recompiles and loads a separate TMB fixture DLL.
  rm(obj)
  invisible(gc())
})

test_that("two requested uniqueness terms are rejected for inseparable kernels", {
  skip_on_cran()
  for (fixture in list(
    .two_lineage_known_error_fixture(identical_kernels = TRUE),
    .two_lineage_known_error_fixture(cross_block_only = TRUE)
  )) {
    captured <- .capture_two_lineage_known_error_tmb(
      .two_lineage_known_error_args(fixture, known_sigma_eps = sqrt(0.04 / 3))
    )
    expect_null(captured$captured)
    expect_type(captured$error, "character")
    expect_match(captured$error, "multi-kernel uniqueness")
  }
})

test_that("kernel separation uses the ridged species covariances", {
  skip_on_cran()
  fixture <- .two_lineage_known_error_fixture()
  fixture$K_phy <- 1e-8 * fixture$K_phy

  ## After the 1e-8 species-level ridge, these kernels are proportional.
  fixture$K_tip <- 2 * fixture$K_phy + diag(1e-8, nrow(fixture$K_phy))
  captured <- .capture_two_lineage_known_error_tmb(
    .two_lineage_known_error_args(fixture, known_sigma_eps = 0.1)
  )
  expect_null(captured$captured)
  expect_match(captured$error, "multi-kernel uniqueness")

  ## Replicates of a species share its source-level ridge contribution.
  repeated <- fixture
  repeated$data <- fixture$data[rep(seq_len(nrow(fixture$data)), each = 2L), ]
  repeated$data$row_id <- factor(paste0("obs", seq_len(nrow(repeated$data))))
  captured <- .capture_two_lineage_known_error_tmb(
    .two_lineage_known_error_args(repeated, known_sigma_eps = 0.1)
  )
  expect_null(captured$captured)
  expect_match(captured$error, "multi-kernel uniqueness")

  ## Raw kernels are proportional, but their ridged versions are not.
  fixture$K_tip <- 2 * fixture$K_phy
  captured <- .capture_two_lineage_known_error_tmb(
    .two_lineage_known_error_args(fixture, known_sigma_eps = 0.1)
  )
  expect_identical(captured$error, "TWO_LINEAGE_KNOWN_ERROR_CAPTURE")
  expect_identical(as.integer(captured$captured$data$kernel_has_diag), c(1L, 1L))
  repeated$K_tip <- 2 * repeated$K_phy
  captured <- .capture_two_lineage_known_error_tmb(
    .two_lineage_known_error_args(repeated, known_sigma_eps = 0.1)
  )
  expect_identical(captured$error, "TWO_LINEAGE_KNOWN_ERROR_CAPTURE")

  ## Tolerated antisymmetry is removed before the engine applies the ridge.
  skew <- matrix(0, nrow(fixture$K_phy), ncol(fixture$K_phy))
  skew[1, 2] <- skew[9, 10] <- 1
  skew[2, 1] <- skew[10, 9] <- -1
  fixture$K_tip <- fixture$K_phy + 2e-9 * skew
  captured <- .capture_two_lineage_known_error_tmb(
    .two_lineage_known_error_args(fixture, known_sigma_eps = 0.1)
  )
  expect_null(captured$captured)
  expect_match(captured$error, "multi-kernel uniqueness")

  ## Column order is aligned by species names before symmetrization.
  fixture$K_tip <- fixture$K_phy[, rev(seq_len(ncol(fixture$K_phy))), drop = FALSE]
  captured <- .capture_two_lineage_known_error_tmb(
    .two_lineage_known_error_args(fixture, known_sigma_eps = 0.1)
  )
  expect_null(captured$captured)
  expect_match(captured$error, "multi-kernel uniqueness")
  fixture$K_tip <- (2 * fixture$K_phy)[, rev(seq_len(ncol(fixture$K_phy))), drop = FALSE]
  captured <- .capture_two_lineage_known_error_tmb(
    .two_lineage_known_error_args(fixture, known_sigma_eps = 0.1)
  )
  expect_identical(captured$error, "TWO_LINEAGE_KNOWN_ERROR_CAPTURE")
})

test_that("every requested trait must have separable observed kernel patterns", {
  skip_on_cran()
  fixture <- .two_lineage_known_error_fixture()
  args <- .two_lineage_known_error_args(fixture, known_sigma_eps = 0.1)
  args$formula <- stats::as.formula(
    "traits(H1, H2, P1, P2) ~ 0 + kernel_latent(species, K = K_phy, d = 1, name = 'phy', unique = TRUE) + kernel_latent(species, K = K_tip, d = 1, name = 'tip', unique = TRUE)",
    env = environment(args$formula)
  )
  for (response_mode in c("include", "drop")) {
    args$missing <- miss_control(response = response_mode)
    args$data <- fixture$data
    positive <- .capture_two_lineage_known_error_tmb(args)
    expect_identical(positive$error, "TWO_LINEAGE_KNOWN_ERROR_CAPTURE")
    expect_identical(as.integer(positive$captured$data$kernel_has_diag), c(1L, 1L))

    for (n_observed in c(0L, 1L)) {
      args$data$H2[] <- NA_real_
      if (n_observed == 1L) args$data$H2[1L] <- 0.2
      captured <- .capture_two_lineage_known_error_tmb(args)
      expect_null(captured$captured)
      expect_match(captured$error, "multi-kernel uniqueness|no rows")
    }
  }

  trait_names <- c("H1", "H2", "P1", "P2")
  long <- do.call(rbind, lapply(trait_names, function(tr) {
    data.frame(species = fixture$data$species, row_id = fixture$data$row_id,
               trait = tr, value = fixture$data[[tr]])
  }))
  long$trait <- factor(long$trait, levels = trait_names)
  args$formula <- stats::as.formula(
    "value ~ 0 + kernel_latent(species, K = K_phy, d = 1, name = 'phy', unique = TRUE) + kernel_latent(species, K = K_tip, d = 1, name = 'tip', unique = TRUE)",
    env = environment(args$formula)
  )
  for (trait_type in c("factor", "character")) {
    for (response_mode in c("include", "drop")) {
      args$missing <- miss_control(response = response_mode)
      args$data <- long
      if (trait_type == "character") args$data$trait <- as.character(args$data$trait)
      positive <- .capture_two_lineage_known_error_tmb(args)
      expect_identical(positive$error, "TWO_LINEAGE_KNOWN_ERROR_CAPTURE")
      expect_identical(as.integer(positive$captured$data$kernel_has_diag), c(1L, 1L))

      h2 <- which(args$data$trait == "H2")
      for (n_observed in c(0L, 1L)) {
        args$data$value[h2] <- NA_real_
        if (n_observed == 1L) args$data$value[h2[1L]] <- 0.2
        captured <- .capture_two_lineage_known_error_tmb(args)
        expect_null(captured$captured)
        expect_match(captured$error, "multi-kernel uniqueness|no rows")
      }
    }
  }

  args$data <- long
  args$data$trait <- factor(args$data$trait, levels = c(trait_names, "ghost"))
  args$missing <- miss_control(response = "include")
  expect_error(suppressWarnings(do.call(gllvmTMB, args)), "ghost",
               class = "gllvmTMB_empty_trait_level")
})

test_that("unreplicated two-kernel uniqueness is not silently dropped with free error", {
  skip_on_cran()
  fixture <- .two_lineage_known_error_fixture()
  captured <- .capture_two_lineage_known_error_tmb(
    .two_lineage_known_error_args(fixture)
  )
  expect_null(captured$captured)
  expect_type(captured$error, "character")
  expect_match(captured$error, "multi-kernel uniqueness")
})

test_that("known observation SD rejects invalid values", {
  fixture <- .two_lineage_known_error_fixture()
  for (bad in list(-1, Inf, NA_real_, c(0.1, 0.2))) {
    args <- .two_lineage_known_error_args(fixture)
    args$known_sigma_eps <- bad
    expect_error(do.call(gllvmTMB, args))
  }
})

test_that("known observation error does not admit mixed-family uniqueness", {
  skip_on_cran()
  fixture <- .two_lineage_known_error_fixture()
  observed <- !is.na(fixture$data$P2)
  fixture$data$P2[observed] <- as.numeric(fixture$data$P2[observed] > 0)
  args <- .two_lineage_known_error_args(fixture, known_sigma_eps = 0.1)
  args$family <- list(H1 = gaussian(), H2 = gaussian(), P1 = gaussian(),
                      P2 = binomial())
  captured <- .capture_two_lineage_known_error_tmb(args)
  expect_null(captured$captured)
  expect_type(captured$error, "character")
  expect_match(captured$error, "[Gg]aussian")
})

test_that("a single requested kernel uniqueness is rejected, not dropped", {
  skip_on_cran()
  fixture <- .two_lineage_known_error_fixture()
  args <- .two_lineage_known_error_args(fixture, known_sigma_eps = 0.1)
  args$formula <- stats::as.formula(
    "traits(H1, H2, P1, P2) ~ 1 + kernel_latent(species, K = K_phy, d = 1, name = 'phy', unique = TRUE) + kernel_latent(species, K = K_tip, d = 1, name = 'tip', unique = FALSE)",
    env = environment(args$formula)
  )
  captured <- .capture_two_lineage_known_error_tmb(args)
  expect_null(captured$captured)
  expect_match(captured$error, "multi-kernel uniqueness")
})

test_that("two shared-only kernels retain both shared terms", {
  skip_on_cran()
  fixture <- .two_lineage_known_error_fixture()
  args <- .two_lineage_known_error_args(fixture)
  args$formula <- stats::as.formula(
    "traits(H1, H2, P1, P2) ~ 1 + kernel_latent(species, K = K_phy, d = 1, name = 'phy', unique = FALSE) + kernel_latent(species, K = K_tip, d = 1, name = 'tip', unique = FALSE)",
    env = environment(args$formula)
  )
  captured <- .capture_two_lineage_known_error_tmb(args)
  expect_identical(captured$error, "TWO_LINEAGE_KNOWN_ERROR_CAPTURE")
  expect_identical(as.integer(captured$captured$data$kernel_has_diag), c(0L, 0L))
})

test_that("zero-weight observations do not establish kernel separation", {
  skip_on_cran()
  fixture <- .two_lineage_known_error_fixture()
  args <- .two_lineage_known_error_args(fixture, known_sigma_eps = 0.1)
  args$weights <- as.numeric(seq_len(nrow(fixture$data)) %in% c(1L, 9L))
  captured <- .capture_two_lineage_known_error_tmb(args)
  expect_null(captured$captured)
  expect_match(captured$error, "multi-kernel uniqueness")
})

test_that("bootstrap refit arguments retain a fixed observation SD", {
  fit <- list(known_sigma_eps = 0.1, use = list(), missing_data = list(),
              control = gllvmTMBcontrol(se = FALSE))
  args <- gllvmTMB:::.bootstrap_refit_arg_table(fit)
  expect_identical(args$known_sigma_eps, 0.1)
})

test_that("unconditional simulation refuses undrawn multi-kernel effects", {
  object <- structure(list(tmb_data = list(n_kernel_tiers = 2L)),
                      class = "gllvmTMB_multi")
  expect_error(stats::simulate(object),
               class = "gllvmTMB_multi_kernel_simulation_unsupported")
  expect_error(stats::simulate(object, newdata = data.frame(x = 1)),
               class = "gllvmTMB_multi_kernel_simulation_newdata_unsupported")
  expect_error(stats::simulate(object, newdata = data.frame(x = 1),
                               condition_on_RE = TRUE),
               class = "gllvmTMB_multi_kernel_simulation_newdata_unsupported")
  expect_error(stats::predict(object, newdata = data.frame(x = 1)),
               class = "gllvmTMB_multi_kernel_predict_newdata_unsupported")
})

test_that("long input retains both kernel uniqueness terms and fixed error", {
  skip_on_cran()
  fixture <- .two_lineage_known_error_fixture()
  traits <- c("H1", "H2", "P1", "P2")
  long <- do.call(rbind, lapply(traits, function(tr) {
    data.frame(species = fixture$data$species, row_id = fixture$data$row_id,
               trait = tr, value = fixture$data[[tr]])
  }))
  long$trait <- factor(long$trait, levels = traits)
  K_phy <- fixture$K_phy
  K_tip <- fixture$K_tip
  args <- list(
    formula = value ~ 0 + trait +
      kernel_latent(species, K = K_phy, d = 1, name = "phy", unique = TRUE) +
      kernel_latent(species, K = K_tip, d = 1, name = "tip", unique = TRUE),
    data = long, family = gaussian(), unit = "row_id", cluster = "species",
    known_sigma_eps = 0.1, missing = miss_control(response = "include"),
    control = gllvmTMBcontrol(se = FALSE), silent = TRUE
  )
  captured <- .capture_two_lineage_known_error_tmb(args)
  expect_identical(captured$error, "TWO_LINEAGE_KNOWN_ERROR_CAPTURE")
  expect_identical(as.integer(captured$captured$data$kernel_has_diag), c(1L, 1L))
  expect_true(all(is.na(captured$captured$map$log_sigma_eps)))
  expect_equal(sum(captured$captured$data$is_y_observed == 1L), 32L)
})
