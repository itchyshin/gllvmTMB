## Fixed-parameter native-versus-dense diagnostic for temporal_dep() +
## kernel_indep().  This is a validation-only calculation: it constructs a
## small deterministic Gaussian panel itself, evaluates the package's native
## objective, and separately evaluates the fully normalised dense marginal
## likelihood.  It neither changes an optimiser nor scores recovery.

.temporal_dep_kernel_native_dense_fixture <- function() {
  data <- expand.grid(
    series = paste0("s", 1:3), occasion = 1:4,
    measurement = c("m1", "m2"), trait = paste0("t", 1:3),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  g <- match(data$series, paste0("s", 1:3))
  tt <- data$occasion
  j <- match(data$trait, paste0("t", 1:3))
  r <- match(data$measurement, c("m1", "m2"))
  ## Deliberately deterministic: this is not a package simulator or a
  ## recovery fixture.  The non-additive terms keep the fitted residual scale
  ## away from an exact-zero boundary.
  data$value <- c(.20, -.35, .12)[j] + c(-.16, .07, .21)[g] +
    .09 * tt + c(-.025, .025)[r] + .021 * (g * tt) +
    .013 * (j * tt) - .017 * (g * j) + .008 * (r * j * tt)
  K <- matrix(c(1, .38, .17, .38, 1, .29, .17, .29, 1), 3L, 3L,
    byrow = TRUE, dimnames = list(paste0("s", 1:3), paste0("s", 1:3)))
  list(data = data, K = K)
}

.temporal_dep_kernel_native_dense_has_helpers <- function() {
  namespace <- asNamespace("gllvmTMB")
  all(vapply(c("temporal_dep", "kernel_indep"), exists,
    logical(1), envir = namespace, inherits = FALSE
  ))
}

.temporal_dep_kernel_native_dense_helper <- function(name) {
  namespace <- asNamespace("gllvmTMB")
  if (!exists(name, envir = namespace, inherits = FALSE)) {
    stop(sprintf("gllvmTMB namespace does not contain %s", sQuote(name)), call. = FALSE)
  }
  ## Do not rely on the attached search path or the export table.  Installed
  ## checks may load helpers as namespace internals while source checks load
  ## the current development namespace.
  getFromNamespace(name, "gllvmTMB")
}

.temporal_dep_kernel_native_dense_fit <- function(fixture) {
  ## Formula helpers must be in the formula environment for model.frame() as
  ## well as in the parser; keeping local aliases avoids attaching the package
  ## in this executable diagnostic.
  temporal_dep <- .temporal_dep_kernel_native_dense_helper("temporal_dep")
  kernel_indep <- .temporal_dep_kernel_native_dense_helper("kernel_indep")
  suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      temporal_dep(0 + trait | series, time = occasion,
        replicate = measurement) +
      kernel_indep(series, K = fixture$K, name = "native_dense_K"),
    data = fixture$data, unit = "series", cluster = "series",
    family = stats::gaussian(), silent = TRUE,
    control = gllvmTMB::gllvmTMBcontrol(
      se = FALSE, optimizer = "optim",
      optArgs = list(method = "BFGS", control = list(maxit = 1000L, reltol = 1e-12)),
      optimizer_passes = 2L
    )
  ))
}

.temporal_dep_kernel_native_dense_unpack <- function(theta, n_trait) {
  if (length(theta) != n_trait * (n_trait + 1L) / 2L) {
    stop("packed temporal Cholesky coordinates have the wrong length", call. = FALSE)
  }
  loading <- matrix(0, n_trait, n_trait)
  cursor <- 1L
  for (column in seq_len(n_trait)) {
    loading[column, column] <- theta[[cursor]]
    cursor <- cursor + 1L
  }
  for (column in seq_len(n_trait - 1L)) for (row in (column + 1L):n_trait) {
    loading[row, column] <- theta[[cursor]]
    cursor <- cursor + 1L
  }
  loading
}

.temporal_dep_kernel_native_dense_nll <- function(fit, fixed, K,
                                                   product_control = FALSE) {
  parameter <- fit$tmb_obj$env$parList(fixed)
  data <- fit$tmb_data
  state <- data$temporal_state_id + 1L
  trait <- data$trait_id + 1L
  source <- data$species_id + 1L
  pair <- fit$temporal$pair_table

  phi <- (1 - 1e-6) * tanh(parameter$theta_temporal_time[[1L]])
  lag <- abs(outer(pair$time, pair$time, `-`))
  same_series <- outer(pair$series, pair$series, `==`)
  R_time <- phi^lag
  R_time[!same_series] <- 0

  L_time <- .temporal_dep_kernel_native_dense_unpack(
    parameter$theta_temporal_rr, data$n_traits
  )
  Sigma_time <- tcrossprod(L_time)
  ## kernel_indep uses the existing diagonal source loading parameterization.
  Sigma_kernel <- diag(parameter$theta_rr_phy^2, nrow = data$n_traits)
  if (isTRUE(product_control)) {
    ## Deliberately wrong: a source-by-time product field, rather than the
    ## stipulated sum of a within-series temporal and a static kernel field.
    V <- phi^lag[state, state] * K[source, source] * Sigma_time[trait, trait]
  } else {
    V <- R_time[state, state] * Sigma_time[trait, trait] +
      K[source, source] * Sigma_kernel[trait, trait]
  }
  diag(V) <- diag(V) + exp(2 * parameter$log_sigma_eps[[1L]])
  residual <- data$y - drop(data$X_fix %*% parameter$b_fix)
  chol_V <- chol(V)
  .5 * (length(residual) * log(2 * pi) + 2 * sum(log(diag(chol_V))) +
    sum(backsolve(chol_V, residual, transpose = TRUE)^2))
}

.temporal_dep_kernel_native_dense_labels <- function(fixed) {
  occurrence <- ave(seq_along(fixed), names(fixed), FUN = seq_along)
  paste0(names(fixed), "[", occurrence, "]")
}

.temporal_dep_kernel_native_dense_central_gradient <- function(fit, fixed, K,
                                                                step = 1e-5) {
  if (!is.numeric(step) || length(step) != 1L || !is.finite(step) || step <= 0) {
    stop("step must be one finite positive number", call. = FALSE)
  }
  result <- numeric(length(fixed))
  for (i in seq_along(fixed)) {
    h <- step * max(1, abs(fixed[[i]]))
    plus <- minus <- fixed
    plus[[i]] <- plus[[i]] + h
    minus[[i]] <- minus[[i]] - h
    result[[i]] <- (
      .temporal_dep_kernel_native_dense_nll(fit, plus, K) -
        .temporal_dep_kernel_native_dense_nll(fit, minus, K)
    ) / (2 * h)
  }
  stats::setNames(result, .temporal_dep_kernel_native_dense_labels(fixed))
}

.temporal_dep_kernel_native_dense_points <- function(fit) {
  fitted <- fit$opt$par
  kernel <- which(names(fitted) == "theta_rr_phy")
  if (length(kernel) != 3L) {
    stop("expected exactly three active kernel loading coordinates", call. = FALSE)
  }
  points <- list(fitted = fitted)
  for (j in seq_along(kernel)) {
    perturbed <- fitted
    ## A bounded positive coordinate displacement, applied one kernel
    ## direction at a time.  No optimisation follows these evaluations.
    perturbed[[kernel[[j]]]] <- perturbed[[kernel[[j]]]] + .075
    points[[paste0("kernel_", j, "_plus_0.075")]] <- perturbed
  }
  points
}

temporal_dep_kernel_native_dense_diagnostic <- function() {
  fixture <- .temporal_dep_kernel_native_dense_fixture()
  fit <- .temporal_dep_kernel_native_dense_fit(fixture)
  points <- .temporal_dep_kernel_native_dense_points(fit)
  records <- lapply(names(points), function(label) {
    fixed <- points[[label]]
    native <- as.numeric(fit$tmb_obj$fn(fixed))
    dense <- .temporal_dep_kernel_native_dense_nll(fit, fixed, fixture$K)
    native_gradient <- fit$tmb_obj$gr(fixed)
    dense_gradient <- .temporal_dep_kernel_native_dense_central_gradient(
      fit, fixed, fixture$K
    )
    names(native_gradient) <- names(dense_gradient)
    list(
      point = label,
      fixed = fixed,
      labels = names(dense_gradient),
      native_nll = native,
      dense_nll = dense,
      nll_error = abs(native - dense),
      native_gradient = native_gradient,
      dense_gradient = dense_gradient,
      gradient_error = abs(native_gradient - dense_gradient),
      product_control_nll = .temporal_dep_kernel_native_dense_nll(
        fit, fixed, fixture$K, product_control = TRUE
      )
    )
  })
  names(records) <- names(points)
  list(
    fixture = fixture,
    fit = fit,
    records = records,
    contract = "fixed-parameter dense agreement only; no solver or recovery claim"
  )
}
