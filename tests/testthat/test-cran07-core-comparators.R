## CRAN 0.7 ordinary-core comparator recertification.
##
## These are deterministic, same-parameterisation fits against glmmTMB.  They
## are deliberately separate from test-comparator-gllvm.R: those two existing
## gllvm rows remain supplemental loadings-only checks because gllvm's bare
## num.lv model has no separate diagonal Psi.

.cran07_cmp_manifest <- data.frame(
  cell_id = c(
    "cmp07-gaussian-indep-n240",
    "cmp07-gaussian-dep-n240",
    "cmp07-gaussian-latent-n240",
    "cmp07-poisson-latent-n300",
    "cmp07-nb2-latent-n300",
    "cmp07-binomial-latent-n300"
  ),
  family = c(
    "gaussian",
    "gaussian",
    "gaussian",
    "poisson",
    "nbinom2",
    "binomial"
  ),
  mode = c("indep", "dep", "latent", "latent", "latent", "latent"),
  n_units = c(240L, 240L, 240L, 300L, 300L, 300L),
  n_rep = c(2L, 2L, 2L, 2L, 2L, 4L),
  rank = c(NA_integer_, NA_integer_, 1L, 1L, 1L, 1L),
  seed = c(
    381000001L,
    381100001L,
    381200001L,
    381300001L,
    381400001L,
    381500001L
  ),
  link = c("identity", "identity", "identity", "log", "log", "logit"),
  n_trials = c(
    NA_integer_,
    NA_integer_,
    NA_integer_,
    NA_integer_,
    NA_integer_,
    10L
  ),
  response_scale = c(
    "continuous",
    "continuous",
    "continuous",
    "count",
    "count",
    "success_proportion"
  ),
  stringsAsFactors = FALSE
)

.cran07_cmp_supplemental <- data.frame(
  family = c("poisson", "bernoulli"),
  source_file = rep("tests/testthat/test-comparator-gllvm.R", 2L),
  model = rep("latent(unique = FALSE) versus gllvm(num.lv = 2)", 2L),
  boundary = c(
    "factor skeleton only; not Psi",
    "orientation check only; not Binomial(10)+Psi"
  ),
  stringsAsFactors = FALSE
)

.cran07_cmp_skip <- function() {
  testthat::skip_if(
    identical(Sys.getenv("GLLVMTMB_CRAN07_RECERTIFY"), "true"),
    "The fail-closed release runner owns exact rows in recertification mode."
  )
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("glmmTMB")
}

.cran07_cmp_fixture <- function(
  family_name,
  mode,
  n_units,
  n_rep,
  rank,
  seed,
  link,
  n_trials
) {
  stopifnot(
    family_name %in% c("gaussian", "poisson", "nbinom2", "binomial"),
    mode %in% c("indep", "dep", "latent"),
    n_units > 1L,
    n_rep > 1L,
    length(link) == 1L,
    !is.na(link),
    identical(
      link,
      c(
        gaussian = "identity",
        poisson = "log",
        nbinom2 = "log",
        binomial = "logit"
      )[[family_name]]
    ),
    if (identical(mode, "latent")) {
      length(rank) == 1L && !is.na(rank) && rank == 1L
    } else {
      length(rank) == 1L && is.na(rank)
    },
    if (identical(family_name, "binomial")) {
      length(n_trials) == 1L && !is.na(n_trials) && n_trials == 10L
    } else {
      length(n_trials) == 1L && is.na(n_trials)
    }
  )
  set.seed(seed)
  trait_names <- paste0("t", seq_len(3L))
  beta0 <- stats::setNames(c(0.15, -0.20, 0.30), trait_names)
  beta1 <- stats::setNames(c(0.30, -0.25, 0.20), trait_names)
  x_unit <- stats::rnorm(n_units)

  if (identical(mode, "indep")) {
    Sigma_shared <- matrix(0, 3L, 3L)
    Psi <- diag(c(0.55, 0.45, 0.65))
  } else if (identical(mode, "dep")) {
    chol_lower <- matrix(
      c(0.80, 0.00, 0.00, 0.25, 0.70, 0.00, -0.20, 0.20, 0.65),
      nrow = 3L,
      byrow = TRUE
    )
    Sigma_shared <- chol_lower %*% t(chol_lower)
    Psi <- matrix(0, 3L, 3L)
  } else {
    Lambda <- matrix(c(0.85, -0.65, 0.55), ncol = 1L)
    Sigma_shared <- tcrossprod(Lambda)
    Psi <- diag(c(0.35, 0.30, 0.40))
  }
  Sigma_total <- Sigma_shared + Psi
  random_unit <- matrix(stats::rnorm(n_units * 3L), n_units, 3L) %*%
    chol(Sigma_total)

  dat <- expand.grid(
    rep = seq_len(n_rep),
    unit = seq_len(n_units),
    trait = trait_names,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$unit <- factor(dat$unit, levels = seq_len(n_units))
  dat$trait <- factor(dat$trait, levels = trait_names)
  dat$x <- x_unit[as.integer(dat$unit)]
  trait_index <- as.integer(dat$trait)
  unit_index <- as.integer(dat$unit)
  eta <- beta0[trait_index] +
    beta1[trait_index] * dat$x +
    random_unit[cbind(unit_index, trait_index)]

  trial_weights <- if (identical(family_name, "binomial")) {
    rep.int(as.integer(n_trials), nrow(dat))
  } else {
    NULL
  }
  response <- switch(
    family_name,
    gaussian = eta + stats::rnorm(nrow(dat), sd = 0.45),
    poisson = stats::rpois(nrow(dat), lambda = exp(eta)),
    nbinom2 = stats::rnbinom(nrow(dat), mu = exp(eta), size = 1),
    binomial = stats::rbinom(
      nrow(dat),
      size = trial_weights,
      prob = stats::plogis(eta)
    )
  )
  if (identical(family_name, "binomial")) {
    dat$successes <- as.integer(response)
    dat$value <- dat$successes / trial_weights
  } else {
    dat$value <- response
  }

  gllvm_formula <- switch(
    mode,
    indep = value ~ 0 + trait + trait:x + indep(0 + trait | unit),
    dep = value ~ 0 + trait + trait:x + dep(0 + trait | unit),
    latent = stats::as.formula(sprintf(
      "value ~ 0 + trait + trait:x + latent(0 + trait | unit, d = %d, unique = TRUE)",
      rank
    ))
  )
  glmm_formula <- switch(
    mode,
    indep = value ~ 0 + trait + trait:x + diag(0 + trait | unit),
    dep = value ~ 0 + trait + trait:x + us(0 + trait | unit),
    latent = stats::as.formula(sprintf(
      "value ~ 0 + trait + trait:x + rr(0 + trait | unit, d = %d) + diag(0 + trait | unit)",
      rank
    ))
  )

  list(
    data = dat,
    family_name = family_name,
    mode = mode,
    rank = rank,
    link = link,
    trait_names = trait_names,
    gllvm_formula = gllvm_formula,
    glmm_formula = glmm_formula,
    weights = trial_weights,
    n_trials = n_trials,
    Sigma_shared = Sigma_shared,
    Psi = Psi,
    Sigma_total = Sigma_total,
    phi = if (identical(family_name, "nbinom2")) rep(1, 3L) else NULL
  )
}

.cran07_cmp_fit_gllvm <- function(fixture) {
  family <- switch(
    fixture$family_name,
    gaussian = stats::gaussian(link = fixture$link),
    poisson = stats::poisson(link = fixture$link),
    nbinom2 = gllvmTMB::nbinom2(link = fixture$link),
    binomial = stats::binomial(link = fixture$link)
  )
  stopifnot(identical(family$link, fixture$link))
  fit_data <- fixture$data
  if (identical(fixture$family_name, "binomial")) {
    ## gllvmTMB's weights API accepts integer successes plus n_trials.
    fit_data$value <- fit_data$successes
  }
  gllvmTMB::gllvmTMB(
    fixture$gllvm_formula,
    data = fit_data,
    unit = "unit",
    trait = "trait",
    family = family,
    weights = fixture$weights
  )
}

.cran07_cmp_fit_glmm <- function(fixture) {
  family <- switch(
    fixture$family_name,
    gaussian = stats::gaussian(link = fixture$link),
    poisson = stats::poisson(link = fixture$link),
    nbinom2 = glmmTMB::nbinom2(link = fixture$link),
    binomial = stats::binomial(link = fixture$link)
  )
  stopifnot(identical(family$link, fixture$link))
  dispersion <- if (identical(fixture$family_name, "nbinom2")) {
    ~ 0 + trait
  } else {
    ~1
  }
  glmmTMB::glmmTMB(
    fixture$glmm_formula,
    data = fixture$data,
    family = family,
    weights = fixture$weights,
    dispformula = dispersion,
    REML = FALSE
  )
}

.cran07_cmp_gllvm_beta <- function(fit) {
  use <- names(fit$opt$par) == "b_fix"
  out <- as.numeric(fit$opt$par[use])
  names(out) <- fit$X_fix_names
  out
}

.cran07_cmp_trait_index <- function(actual, trait_names, context) {
  if (
    is.null(actual) ||
      length(actual) != length(trait_names) ||
      anyNA(actual) ||
      anyDuplicated(actual)
  ) {
    stop(
      context,
      " must have one unique, non-missing name per frozen trait.",
      call. = FALSE
    )
  }
  accepted <- list(trait_names, paste0("trait", trait_names))
  hit <- which(vapply(
    accepted,
    function(expected) {
      setequal(actual, expected)
    },
    logical(1L)
  ))
  if (length(hit) != 1L) {
    stop(
      context,
      " names do not exactly match the frozen traits: ",
      paste(actual, collapse = ", "),
      call. = FALSE
    )
  }
  match(accepted[[hit]], actual)
}

.cran07_cmp_reorder_covariance <- function(x, trait_names, context) {
  x <- as.matrix(x)
  if (!identical(dim(x), rep.int(length(trait_names), 2L))) {
    stop(
      context,
      " must be a square frozen-trait covariance matrix.",
      call. = FALSE
    )
  }
  row_index <- .cran07_cmp_trait_index(
    rownames(x),
    trait_names,
    paste(context, "row")
  )
  col_index <- .cran07_cmp_trait_index(
    colnames(x),
    trait_names,
    paste(context, "column")
  )
  out <- x[row_index, col_index, drop = FALSE]
  rownames(out) <- colnames(out) <- trait_names
  out
}

.cran07_cmp_reorder_trait_vector <- function(x, trait_names, context) {
  index <- .cran07_cmp_trait_index(names(x), trait_names, context)
  out <- as.numeric(x[index])
  names(out) <- trait_names
  out
}

.cran07_cmp_glmm_covariance <- function(fit, trait_names) {
  blocks <- glmmTMB::VarCorr(fit)$cond
  component_types <- vapply(
    blocks,
    function(block) {
      code <- attr(block, "blockCode")
      class_type <- sub(
        "^vcmat_",
        "",
        grep("^vcmat_", class(block), value = TRUE)[1L]
      )
      code_type <- if (length(code) == 1L && length(names(code)) == 1L) {
        names(code)
      } else {
        NA_character_
      }
      if (
        length(class_type) != 1L ||
          is.na(class_type) ||
          !nzchar(class_type) ||
          !identical(class_type, code_type)
      ) {
        NA_character_
      } else {
        class_type
      }
    },
    character(1L)
  )
  matrices <- lapply(seq_along(blocks), function(i) {
    .cran07_cmp_reorder_covariance(
      blocks[[i]],
      trait_names,
      paste0("glmmTMB covariance block ", i)
    )
  })
  if (!length(matrices)) {
    stop(
      "glmmTMB did not report a conditional covariance block.",
      call. = FALSE
    )
  }
  offdiag_max <- vapply(
    matrices,
    function(x) {
      max(abs(x[row(x) != col(x)]))
    },
    numeric(1L)
  )
  list(
    components = matrices,
    component_types = unname(component_types),
    total = Reduce(`+`, matrices),
    diagonal = matrices[offdiag_max <= 1e-10]
  )
}

.cran07_cmp_glmm_boundary_assessment <- function(
  covariance,
  mode,
  family_name,
  residual_sd = NULL,
  phi = NULL,
  sd_threshold = 1e-4,
  relative_variance_threshold = 1e-6
) {
  flags <- character(0)
  unassessed <- character(0)
  expected_types <- switch(
    mode,
    indep = "diag",
    dep = "us",
    latent = c("rr", "diag"),
    character(0)
  )
  types <- covariance$component_types
  components <- covariance$components
  if (
    !length(expected_types) ||
      length(types) != length(expected_types) ||
      anyNA(types) ||
      !setequal(types, expected_types) ||
      length(components) != length(expected_types)
  ) {
    unassessed <- c(unassessed, "covariance component types")
  }

  component_rows <- lapply(seq_along(components), function(i) {
    component <- as.matrix(components[[i]])
    type <- if (length(types) >= i) types[[i]] else NA_character_
    assessed <- identical(dim(component), c(3L, 3L)) &&
      all(is.finite(component)) &&
      isTRUE(all.equal(component, t(component), tolerance = 1e-10)) &&
      !is.na(type) &&
      type %in% c("diag", "us", "rr")
    if (!assessed) {
      unassessed <<- c(unassessed, paste0("covariance component ", i))
      return(data.frame(
        component = i,
        type = type,
        min_variance = NA_real_,
        max_variance = NA_real_,
        relative_variance = NA_real_,
        assessed = FALSE,
        stringsAsFactors = FALSE
      ))
    }
    variances <- diag(component)
    max_variance <- max(variances)
    min_variance <- min(variances)
    relative_variance <- if (max_variance > 0) {
      min_variance / max_variance
    } else {
      0
    }
    prefix <- paste0(type, " component ", i)
    if (any(variances <= sd_threshold^2)) {
      flags <<- c(flags, paste(prefix, "has a collapsed trait SD"))
    }
    if (relative_variance <= relative_variance_threshold) {
      flags <<- c(
        flags,
        paste(prefix, "has a relatively collapsed trait scale")
      )
    }
    if (identical(type, "us")) {
      eigenvalues <- eigen(
        component,
        symmetric = TRUE,
        only.values = TRUE
      )$values
      if (
        max(eigenvalues) <= 0 ||
          min(eigenvalues) / max(eigenvalues) <= relative_variance_threshold
      ) {
        flags <<- c(flags, paste(prefix, "is near singular"))
      }
    }
    data.frame(
      component = i,
      type = type,
      min_variance = min_variance,
      max_variance = max_variance,
      relative_variance = relative_variance,
      assessed = TRUE,
      stringsAsFactors = FALSE
    )
  })

  if (identical(family_name, "gaussian")) {
    if (
      length(residual_sd) != 1L ||
        !is.finite(residual_sd) ||
        residual_sd <= 0 ||
        is.null(covariance$total) ||
        any(!is.finite(diag(covariance$total)))
    ) {
      unassessed <- c(unassessed, "Gaussian residual SD")
    } else {
      relative_residual_variance <- residual_sd^2 / max(diag(covariance$total))
      if (residual_sd <= sd_threshold) {
        flags <- c(flags, "Gaussian residual SD is collapsed")
      }
      if (relative_residual_variance <= relative_variance_threshold) {
        flags <- c(flags, "Gaussian residual SD is relatively collapsed")
      }
    }
  }

  if (identical(family_name, "nbinom2")) {
    if (!length(phi) || any(!is.finite(phi)) || any(phi <= 0)) {
      unassessed <- c(unassessed, "NB2 dispersion")
    } else {
      if (any(phi <= 1e-6)) {
        flags <- c(flags, "NB2 dispersion is near zero")
      }
      if (any(phi >= 1e6)) {
        flags <- c(flags, "NB2 dispersion is effectively Poisson")
      }
    }
  }

  unassessed <- unique(unassessed)
  flags <- unique(flags)
  list(
    assessed = length(unassessed) == 0L,
    pass = length(unassessed) == 0L && length(flags) == 0L,
    flags = flags,
    unassessed = unassessed,
    expected_component_types = expected_types,
    observed_component_types = types,
    component_scales = do.call(rbind, component_rows),
    residual_sd = residual_sd,
    phi = phi,
    thresholds = c(
      sd = sd_threshold,
      relative_variance = relative_variance_threshold,
      phi_lower = 1e-6,
      phi_upper = 1e6
    )
  )
}

.cran07_cmp_expect_covariance_healthy <- function(Sigma, label) {
  expect_equal(dim(Sigma), c(3L, 3L), info = label)
  expect_equal(Sigma, t(Sigma), tolerance = 1e-10, info = label)
  expect_true(all(is.finite(Sigma)), label = paste(label, "is finite"))
  variances <- diag(Sigma)
  expect_gt(
    min(variances),
    1e-8,
    label = paste(label, "variances are interior")
  )
  expect_gt(
    min(variances) / max(variances),
    1e-6,
    label = paste(label, "variances are not relatively collapsed")
  )
  eigenvalues <- eigen(Sigma, symmetric = TRUE, only.values = TRUE)$values
  expect_gt(
    min(eigenvalues) / max(eigenvalues),
    1e-6,
    label = paste(label, "is not near singular")
  )
}

.cran07_cmp_expect_gllvm_health <- function(fit, cell_id) {
  health <- fit$fit_health
  if (is.null(health)) {
    health <- gllvmTMB:::.gllvmTMB_build_fit_health(fit)
  }
  expect_equal(fit$opt$convergence, 0L, info = cell_id)
  expect_identical(health$optimizer_converged, TRUE, info = cell_id)
  expect_true(
    is.finite(health$objective),
    label = paste(cell_id, "gllvmTMB objective is finite")
  )
  expect_lt(
    health$max_gradient,
    1e-2,
    label = paste(cell_id, "gllvmTMB max gradient")
  )
  expect_identical(health$pd_hessian, TRUE, info = cell_id)
  expect_equal(length(health$boundary_flags), 0L, info = cell_id)

  history <- fit$restart_history
  expect_true(
    inherits(history, "data.frame"),
    label = paste(cell_id, "restart history is a data frame")
  )
  expect_gte(
    nrow(history),
    1L,
    label = paste(cell_id, "restart provenance rows")
  )
  expect_equal(sum(history$selected), 1L, info = cell_id)

  provenance <- fit$warm_restart_provenance
  required <- c(
    "warm_restart_attempted",
    "warm_restart_accepted",
    "objective_before_restart",
    "objective_after_restart",
    "max_gradient_before_restart",
    "max_gradient_after_restart"
  )
  expect_true(
    setequal(intersect(names(provenance), required), required),
    label = paste(cell_id, "warm-restart provenance fields are complete")
  )
  expect_identical(
    typeof(provenance$warm_restart_attempted),
    "logical",
    label = paste(cell_id, "warm-restart attempted flag type")
  )
  expect_identical(
    typeof(provenance$warm_restart_accepted),
    "logical",
    label = paste(cell_id, "warm-restart accepted flag type")
  )
  invisible(health)
}

.cran07_cmp_expect_glmm_health <- function(fit, covariance, fixture, cell_id) {
  expect_equal(fit$fit$convergence, 0, info = cell_id)
  expect_true(
    is.finite(fit$fit$objective),
    label = paste(cell_id, "glmmTMB objective is finite")
  )
  expect_identical(fit$sdr$pdHess, TRUE, info = cell_id)
  gradient <- fit$obj$gr(fit$fit$par)
  expect_true(
    all(is.finite(gradient)),
    label = paste(cell_id, "glmmTMB gradient is finite")
  )
  expect_lt(
    max(abs(gradient)),
    1e-2,
    label = paste(cell_id, "glmmTMB max gradient")
  )
  expect_true(
    is.finite(as.numeric(stats::logLik(fit))),
    label = paste(cell_id, "glmmTMB log-likelihood is finite")
  )
  .cran07_cmp_expect_covariance_healthy(
    covariance$total,
    paste(cell_id, "glmmTMB total covariance")
  )
  residual_sd <- if (identical(fixture$family_name, "gaussian")) {
    as.numeric(stats::sigma(fit))
  } else {
    NULL
  }
  phi <- if (identical(fixture$family_name, "nbinom2")) {
    exp(glmmTMB::fixef(fit)$disp)
  } else {
    NULL
  }
  boundary <- .cran07_cmp_glmm_boundary_assessment(
    covariance = covariance,
    mode = fixture$mode,
    family_name = fixture$family_name,
    residual_sd = residual_sd,
    phi = phi
  )
  expect_identical(boundary$assessed, TRUE, info = cell_id)
  expect_equal(length(boundary$unassessed), 0L, info = cell_id)
  expect_identical(boundary$pass, TRUE, info = cell_id)
  expect_equal(length(boundary$flags), 0L, info = cell_id)
  list(
    package = "glmmTMB",
    package_version = as.character(utils::packageVersion("glmmTMB")),
    optimizer_convergence = fit$fit$convergence,
    optimizer_message = fit$fit$message,
    optimizer_iterations = fit$fit$iterations,
    optimizer_evaluations = fit$fit$evaluations,
    objective = fit$fit$objective,
    max_gradient = max(abs(gradient)),
    pd_hessian = fit$sdr$pdHess,
    boundary_assessed = boundary$assessed,
    boundary_flags = boundary$flags,
    boundary_unassessed = boundary$unassessed,
    component_boundary_diagnostics = boundary$component_scales,
    boundary_diagnostics = boundary,
    call = deparse(fit$call),
    warm_restart_provenance = list(
      applicable = FALSE,
      attempted = FALSE,
      accepted = FALSE,
      reason = "glmmTMB reference fit uses its own default optimizer route"
    )
  )
}

.cran07_cmp_run_exact <- function(cell_id) {
  row <- .cran07_cmp_manifest[
    .cran07_cmp_manifest$cell_id == cell_id,
    ,
    drop = FALSE
  ]
  stopifnot(nrow(row) == 1L)
  fixture <- .cran07_cmp_fixture(
    family_name = row$family,
    mode = row$mode,
    n_units = row$n_units,
    n_rep = row$n_rep,
    rank = row$rank,
    seed = row$seed,
    link = row$link,
    n_trials = row$n_trials
  )
  fit_g <- .cran07_cmp_fit_gllvm(fixture)
  fit_t <- .cran07_cmp_fit_glmm(fixture)
  expect_identical(
    levels(fit_g$data[[fit_g$trait_col]]),
    fixture$trait_names,
    info = cell_id
  )
  if (identical(row$mode, "latent")) {
    expect_equal(fit_g$d_B, row$rank, info = cell_id)
    expect_match(
      paste(deparse(fixture$gllvm_formula), collapse = " "),
      paste0("d = ", row$rank),
      fixed = TRUE
    )
    expect_match(
      paste(deparse(fixture$glmm_formula), collapse = " "),
      paste0("d = ", row$rank),
      fixed = TRUE
    )
  }
  if (identical(row$family, "binomial")) {
    expect_equal(fit_g$tmb_data$y, fixture$data$successes, info = cell_id)
    expect_equal(fit_g$tmb_data$n_trials, fixture$weights, info = cell_id)
    expect_equal(
      as.numeric(stats::model.response(fit_t$frame)),
      fixture$data$value,
      info = cell_id
    )
    expect_equal(
      as.numeric(stats::model.weights(fit_t$frame)),
      fixture$weights,
      info = cell_id
    )
  }

  health_g <- .cran07_cmp_expect_gllvm_health(fit_g, cell_id)
  covariance_t <- .cran07_cmp_glmm_covariance(fit_t, fixture$trait_names)
  health_t <- .cran07_cmp_expect_glmm_health(
    fit_t,
    covariance_t,
    fixture,
    cell_id
  )

  Sigma_g <- suppressMessages(
    gllvmTMB::extract_Sigma(
      fit_g,
      level = "unit",
      part = "total",
      link_residual = "none"
    )$Sigma
  )
  Sigma_g <- .cran07_cmp_reorder_covariance(
    Sigma_g,
    fixture$trait_names,
    "gllvmTMB total covariance"
  )
  .cran07_cmp_expect_covariance_healthy(
    Sigma_g,
    paste(cell_id, "gllvmTMB total covariance")
  )

  beta_g <- .cran07_cmp_gllvm_beta(fit_g)
  beta_t <- glmmTMB::fixef(fit_t)$cond
  expect_true(
    setequal(names(beta_g), names(beta_t)),
    label = paste(cell_id, "fixed-effect names align")
  )
  beta_t <- beta_t[names(beta_g)]

  ll_g <- -fit_g$opt$objective
  ll_t <- as.numeric(stats::logLik(fit_t))
  loglik_abs_diff <- abs(ll_g - ll_t)
  beta_max_abs_diff <- max(abs(beta_g - beta_t))
  covariance_max_abs_diff <- max(abs(Sigma_g - covariance_t$total))
  expect_lte(
    loglik_abs_diff,
    1e-4,
    label = paste(cell_id, "absolute log-likelihood difference")
  )
  expect_lte(
    beta_max_abs_diff,
    0.05,
    label = paste(cell_id, "maximum fixed-effect difference")
  )
  expect_lte(
    covariance_max_abs_diff,
    0.10,
    label = paste(cell_id, "maximum covariance difference")
  )

  psi_g <- psi_t <- psi_max_abs_diff <- NULL
  if (identical(row$mode, "latent")) {
    expect_equal(length(covariance_t$diagonal), 1L, info = cell_id)
    psi_g <- suppressMessages(
      gllvmTMB::extract_Sigma(
        fit_g,
        level = "unit",
        part = "unique",
        link_residual = "none"
      )$s
    )
    psi_g <- .cran07_cmp_reorder_trait_vector(
      psi_g,
      fixture$trait_names,
      "gllvmTMB Psi variance"
    )
    psi_t <- .cran07_cmp_reorder_trait_vector(
      diag(covariance_t$diagonal[[1L]]),
      fixture$trait_names,
      "glmmTMB Psi variance"
    )
    expect_true(
      all(is.finite(psi_g)),
      label = paste(cell_id, "gllvmTMB Psi is finite")
    )
    expect_true(
      all(is.finite(psi_t)),
      label = paste(cell_id, "glmmTMB Psi is finite")
    )
    expect_gt(
      min(psi_g),
      1e-8,
      label = paste(cell_id, "gllvmTMB Psi is interior")
    )
    expect_gt(
      min(psi_t),
      1e-8,
      label = paste(cell_id, "glmmTMB Psi is interior")
    )
    psi_max_abs_diff <- max(abs(psi_g - psi_t))
    expect_lte(
      psi_max_abs_diff,
      0.10,
      label = paste(cell_id, "traitwise Psi-variance difference")
    )
  }

  phi_g <- phi_t <- phi_relative_diff <- NULL
  if (identical(row$family, "nbinom2")) {
    phi_g <- as.numeric(fit_g$report$phi_nbinom2)
    names(phi_g) <- levels(fit_g$data[[fit_g$trait_col]])
    phi_g <- .cran07_cmp_reorder_trait_vector(
      phi_g,
      fixture$trait_names,
      "gllvmTMB NB2 phi"
    )
    phi_t <- exp(glmmTMB::fixef(fit_t)$disp)
    phi_t <- .cran07_cmp_reorder_trait_vector(
      phi_t,
      fixture$trait_names,
      "glmmTMB NB2 phi"
    )
    expect_equal(length(phi_g), 3L, info = cell_id)
    expect_equal(length(phi_t), 3L, info = cell_id)
    expect_true(
      all(is.finite(phi_g) & phi_g > 0),
      label = paste(cell_id, "gllvmTMB NB2 phi is finite and positive")
    )
    expect_true(
      all(is.finite(phi_t) & phi_t > 0),
      label = paste(cell_id, "glmmTMB NB2 phi is finite and positive")
    )
    phi_relative_diff <- abs(phi_g - phi_t) / phi_t
    expect_true(
      all(phi_relative_diff <= 0.25),
      label = paste(cell_id, "traitwise NB2 phi relative difference <= 0.25")
    )
  }

  sigma_eps <- NULL
  if (identical(row$family, "gaussian")) {
    sigma_eps <- c(
      gllvmTMB = as.numeric(fit_g$report$sigma_eps),
      glmmTMB = as.numeric(stats::sigma(fit_t))
    )
    expect_equal(length(sigma_eps), 2L, info = cell_id)
    expect_true(
      all(is.finite(sigma_eps) & sigma_eps > 0),
      label = paste(cell_id, "Gaussian residual SDs are finite and positive")
    )
    expect_lte(
      abs(sigma_eps[["gllvmTMB"]] - sigma_eps[["glmmTMB"]]),
      0.05,
      label = paste(cell_id, "Gaussian sigma_eps SD-scale difference")
    )
  }

  list(
    cell_id = cell_id,
    objective_definition = "marginal Laplace log-likelihood with constants",
    trait_order = fixture$trait_names,
    formula_gllvmTMB = deparse(fixture$gllvm_formula),
    formula_glmmTMB = deparse(fixture$glmm_formula),
    rank = row$rank,
    link = row$link,
    n_trials = row$n_trials,
    gllvmTMB_health = health_g,
    gllvmTMB_warm_restart = fit_g$warm_restart_provenance,
    glmmTMB_health = health_t,
    objective = c(
      gllvmTMB = fit_g$opt$objective,
      glmmTMB = fit_t$fit$objective
    ),
    loglik = c(gllvmTMB = ll_g, glmmTMB = ll_t),
    beta = list(gllvmTMB = beta_g, glmmTMB = beta_t),
    Sigma = list(gllvmTMB = Sigma_g, glmmTMB = covariance_t$total),
    Psi = list(
      gllvmTMB = psi_g,
      glmmTMB = psi_t,
      max_abs_difference = psi_max_abs_diff
    ),
    sigma_eps_sd = sigma_eps,
    phi_nbinom2 = list(
      gllvmTMB = phi_g,
      glmmTMB = phi_t,
      relative_difference = phi_relative_diff
    )
  )
}

.cran07_cmp_release_result_ok <- function(result, manifest_row) {
  tryCatch(
    {
      trait_names <- paste0("t", seq_len(3L))
      g_health <- result$gllvmTMB_health
      t_health <- result$glmmTMB_health
      warm <- result$gllvmTMB_warm_restart
      required_g_health <- c(
        "optimizer",
        "convergence",
        "message",
        "objective",
        "max_gradient",
        "scaled_gradient",
        "stationary_by_scaled_gradient",
        "stationary_by_gradient",
        "optimizer_converged",
        "converged",
        "pd_hessian",
        "sdreport_ok",
        "sdreport_error",
        "max_fixed_se",
        "boundary_flags",
        "start_provenance",
        "selected_restart"
      )
      required_t_health <- c(
        "package",
        "package_version",
        "optimizer_convergence",
        "optimizer_message",
        "optimizer_iterations",
        "optimizer_evaluations",
        "objective",
        "max_gradient",
        "pd_hessian",
        "boundary_assessed",
        "boundary_flags",
        "boundary_unassessed",
        "component_boundary_diagnostics",
        "boundary_diagnostics",
        "call",
        "warm_restart_provenance"
      )
      required_warm <- c(
        "warm_restart_attempted",
        "warm_restart_accepted",
        "objective_before_restart",
        "objective_after_restart",
        "max_gradient_before_restart",
        "max_gradient_after_restart"
      )
      stopifnot(
        identical(result$cell_id, manifest_row$cell_id[[1L]]),
        identical(result$trait_order, trait_names),
        identical(result$rank, manifest_row$rank[[1L]]),
        identical(result$link, manifest_row$link[[1L]]),
        identical(result$n_trials, manifest_row$n_trials[[1L]]),
        all(required_g_health %in% names(g_health)),
        all(required_t_health %in% names(t_health)),
        all(required_warm %in% names(warm)),
        identical(g_health$convergence, 0L),
        isTRUE(g_health$optimizer_converged),
        isTRUE(g_health$converged),
        isTRUE(g_health$pd_hessian),
        length(g_health$boundary_flags) == 0L,
        is.finite(g_health$objective),
        is.finite(g_health$max_gradient),
        g_health$max_gradient < 1e-2,
        identical(t_health$package, "glmmTMB"),
        nzchar(t_health$package_version),
        identical(t_health$optimizer_convergence, 0L),
        isTRUE(t_health$pd_hessian),
        isTRUE(t_health$boundary_assessed),
        length(t_health$boundary_flags) == 0L,
        length(t_health$boundary_unassessed) == 0L,
        isTRUE(t_health$boundary_diagnostics$assessed),
        isTRUE(t_health$boundary_diagnostics$pass),
        is.finite(t_health$objective),
        is.finite(t_health$max_gradient),
        t_health$max_gradient < 1e-2,
        isFALSE(t_health$warm_restart_provenance$applicable),
        isFALSE(t_health$warm_restart_provenance$attempted),
        all(is.finite(result$objective)),
        all(is.finite(result$loglik)),
        abs(diff(result$loglik)) <= 1e-4,
        identical(names(result$beta$gllvmTMB), names(result$beta$glmmTMB)),
        max(abs(result$beta$gllvmTMB - result$beta$glmmTMB)) <= 0.05,
        identical(rownames(result$Sigma$gllvmTMB), trait_names),
        identical(colnames(result$Sigma$gllvmTMB), trait_names),
        identical(rownames(result$Sigma$glmmTMB), trait_names),
        identical(colnames(result$Sigma$glmmTMB), trait_names),
        max(abs(result$Sigma$gllvmTMB - result$Sigma$glmmTMB)) <= 0.10
      )
      if (identical(manifest_row$mode[[1L]], "latent")) {
        stopifnot(
          identical(names(result$Psi$gllvmTMB), trait_names),
          identical(names(result$Psi$glmmTMB), trait_names),
          is.finite(result$Psi$max_abs_difference),
          result$Psi$max_abs_difference <= 0.10
        )
      }
      if (identical(manifest_row$family[[1L]], "gaussian")) {
        stopifnot(
          identical(names(result$sigma_eps_sd), c("gllvmTMB", "glmmTMB")),
          all(is.finite(result$sigma_eps_sd) & result$sigma_eps_sd > 0),
          abs(diff(result$sigma_eps_sd)) <= 0.05
        )
      }
      if (identical(manifest_row$family[[1L]], "nbinom2")) {
        stopifnot(
          identical(names(result$phi_nbinom2$gllvmTMB), trait_names),
          identical(names(result$phi_nbinom2$glmmTMB), trait_names),
          all(is.finite(result$phi_nbinom2$relative_difference)),
          all(result$phi_nbinom2$relative_difference <= 0.25)
        )
      }
      TRUE
    },
    error = function(e) FALSE
  )
}

.cran07_cmp_release_recertify <- function(
  execute = FALSE,
  dependency_available = requireNamespace("glmmTMB", quietly = TRUE),
  exact_runner = .cran07_cmp_run_exact,
  manifest = .cran07_cmp_manifest
) {
  ledger <- data.frame(
    cell_id = manifest$cell_id,
    attempted = FALSE,
    status = "HOLD",
    reason = "row not executed",
    stringsAsFactors = FALSE
  )
  if (!isTRUE(execute)) {
    return(ledger)
  }
  if (!isTRUE(dependency_available)) {
    ledger$reason <- "glmmTMB is unavailable in fail-closed recertification mode"
    return(ledger)
  }

  required_result_fields <- c(
    "cell_id",
    "objective_definition",
    "trait_order",
    "rank",
    "link",
    "n_trials",
    "gllvmTMB_health",
    "gllvmTMB_warm_restart",
    "glmmTMB_health",
    "objective",
    "loglik",
    "beta",
    "Sigma",
    "Psi",
    "sigma_eps_sd",
    "phi_nbinom2"
  )
  for (i in seq_len(nrow(ledger))) {
    ledger$attempted[[i]] <- TRUE
    result <- tryCatch(
      exact_runner(ledger$cell_id[[i]]),
      skip = function(e) {
        structure(
          list(message = conditionMessage(e)),
          class = "cran07_comparator_skip"
        )
      },
      error = function(e) e
    )
    if (inherits(result, "cran07_comparator_skip")) {
      ledger$reason[[i]] <- paste("runner skipped:", result$message)
      next
    }
    if (inherits(result, "error")) {
      ledger$reason[[i]] <- conditionMessage(result)
      next
    }
    complete <- is.list(result) &&
      identical(result$cell_id, ledger$cell_id[[i]]) &&
      all(required_result_fields %in% names(result)) &&
      .cran07_cmp_release_result_ok(result, manifest[i, , drop = FALSE])
    if (!isTRUE(complete)) {
      ledger$reason[[i]] <- "runner returned an incomplete/mislabelled result"
      next
    }
    ledger$status[[i]] <- "PASS"
    ledger$reason[[i]] <- "all frozen exact gates passed"
  }
  ledger
}

.cran07_cmp_assert_release_pass <- function(ledger) {
  expected <- .cran07_cmp_manifest$cell_id
  complete <- is.data.frame(ledger) &&
    identical(ledger$cell_id, expected) &&
    nrow(ledger) == length(expected) &&
    all(ledger$attempted) &&
    all(ledger$status == "PASS")
  if (!isTRUE(complete)) {
    hold <- if (is.data.frame(ledger)) {
      paste(
        paste0(
          ledger$cell_id[ledger$status != "PASS"],
          ": ",
          ledger$reason[ledger$status != "PASS"]
        ),
        collapse = "; "
      )
    } else {
      "invalid recertification ledger"
    }
    stop("CRAN 0.7 comparator recertification HOLD: ", hold, call. = FALSE)
  }
  invisible(ledger)
}

test_that("CRAN 0.7 exact comparator manifest is frozen before fits", {
  expect_equal(nrow(.cran07_cmp_manifest), 6L)
  expect_setequal(
    .cran07_cmp_manifest$mode,
    c("indep", "dep", "latent")
  )
  expect_equal(sum(.cran07_cmp_manifest$mode == "latent"), 4L)
  expect_equal(
    .cran07_cmp_manifest$n_trials[.cran07_cmp_manifest$family == "binomial"],
    10L
  )
  expect_equal(length(unique(.cran07_cmp_manifest$seed)), 6L)
  expect_gt(min(.cran07_cmp_manifest$n_rep), 1L)
  expect_equal(
    .cran07_cmp_manifest$rank[.cran07_cmp_manifest$mode == "latent"],
    rep(1L, 4L)
  )
  expect_true(all(is.na(
    .cran07_cmp_manifest$rank[.cran07_cmp_manifest$mode != "latent"]
  )))
  expect_equal(
    .cran07_cmp_manifest$link,
    c("identity", "identity", "identity", "log", "log", "logit")
  )
  expect_identical(
    .cran07_cmp_manifest$response_scale[
      .cran07_cmp_manifest$family == "binomial"
    ],
    "success_proportion"
  )
  expect_equal(nrow(.cran07_cmp_supplemental), 2L)
  expect_setequal(.cran07_cmp_supplemental$family, c("poisson", "bernoulli"))
})

test_that("CRAN 0.7 Binomial(10) fixture preserves successes and fit scale", {
  row <- .cran07_cmp_manifest[
    .cran07_cmp_manifest$family == "binomial",
    ,
    drop = FALSE
  ]
  fixture <- .cran07_cmp_fixture(
    family_name = row$family,
    mode = row$mode,
    n_units = row$n_units,
    n_rep = row$n_rep,
    rank = row$rank,
    seed = row$seed,
    link = row$link,
    n_trials = row$n_trials
  )
  expect_type(fixture$data$successes, "integer")
  expect_equal(fixture$weights, rep.int(10L, nrow(fixture$data)))
  expect_equal(fixture$data$value, fixture$data$successes / fixture$weights)
  expect_gte(min(fixture$data$successes), 0L)
  expect_lte(max(fixture$data$successes), 10L)
  expect_gte(min(fixture$data$value), 0)
  expect_lte(max(fixture$data$value), 1)

  expect_error(
    .cran07_cmp_fixture(
      family_name = row$family,
      mode = row$mode,
      n_units = row$n_units,
      n_rep = row$n_rep,
      rank = 2L,
      seed = row$seed,
      link = row$link,
      n_trials = row$n_trials
    )
  )
  expect_error(
    .cran07_cmp_fixture(
      family_name = row$family,
      mode = row$mode,
      n_units = row$n_units,
      n_rep = row$n_rep,
      rank = row$rank,
      seed = row$seed,
      link = "probit",
      n_trials = row$n_trials
    )
  )
  expect_error(
    .cran07_cmp_fixture(
      family_name = row$family,
      mode = row$mode,
      n_units = row$n_units,
      n_rep = row$n_rep,
      rank = row$rank,
      seed = row$seed,
      link = row$link,
      n_trials = 9L
    )
  )
})

test_that("CRAN 0.7 named estimands reject missing or duplicate traits", {
  bad <- tryCatch(
    .cran07_cmp_trait_index(
      c("t1", "t1", "t3"),
      c("t1", "t2", "t3"),
      "adversarial vector"
    ),
    error = function(e) e
  )
  expect_s3_class(bad, "error")
  expect_match(conditionMessage(bad), "unique, non-missing")

  scrambled <- matrix(
    seq_len(9L),
    3L,
    dimnames = list(
      c("traitt3", "traitt1", "traitt2"),
      c("traitt2", "traitt3", "traitt1")
    )
  )
  reordered <- .cran07_cmp_reorder_covariance(
    scrambled,
    c("t1", "t2", "t3"),
    "adversarial covariance"
  )
  expect_identical(rownames(reordered), c("t1", "t2", "t3"))
  expect_identical(colnames(reordered), c("t1", "t2", "t3"))
  expect_equal(
    unname(reordered),
    unname(scrambled[c(2L, 3L, 1L), c(3L, 1L, 2L)])
  )
})

test_that("CRAN 0.7 glmmTMB boundary assessment fails closed", {
  loading <- c(0.8, -0.6, 0.4)
  healthy <- list(
    components = list(tcrossprod(loading), diag(c(0.30, 0.25, 0.35))),
    component_types = c("rr", "diag")
  )
  healthy$total <- Reduce(`+`, healthy$components)
  assessed <- .cran07_cmp_glmm_boundary_assessment(
    healthy,
    mode = "latent",
    family_name = "gaussian",
    residual_sd = 0.4
  )
  expect_identical(assessed$assessed, TRUE)
  expect_identical(assessed$pass, TRUE)
  expect_length(assessed$flags, 0L)
  expect_length(assessed$unassessed, 0L)

  collapsed_loading <- healthy
  collapsed_loading$components[[1L]] <- tcrossprod(c(0.8, 1e-8, 0.4))
  collapsed_loading$total <- Reduce(`+`, collapsed_loading$components)
  loading_result <- .cran07_cmp_glmm_boundary_assessment(
    collapsed_loading,
    mode = "latent",
    family_name = "gaussian",
    residual_sd = 0.4
  )
  expect_identical(loading_result$pass, FALSE)
  expect_match(paste(loading_result$flags, collapse = "; "), "rr component")

  collapsed_psi <- healthy
  collapsed_psi$components[[2L]] <- diag(c(0.30, 1e-12, 0.35))
  collapsed_psi$total <- Reduce(`+`, collapsed_psi$components)
  psi_result <- .cran07_cmp_glmm_boundary_assessment(
    collapsed_psi,
    mode = "latent",
    family_name = "gaussian",
    residual_sd = 0.4
  )
  expect_identical(psi_result$pass, FALSE)
  expect_match(paste(psi_result$flags, collapse = "; "), "diag component")

  collapsed_residual <- .cran07_cmp_glmm_boundary_assessment(
    healthy,
    mode = "latent",
    family_name = "gaussian",
    residual_sd = 1e-8
  )
  expect_identical(collapsed_residual$pass, FALSE)
  expect_match(
    paste(collapsed_residual$flags, collapse = "; "),
    "residual SD"
  )

  unknown <- healthy
  unknown$component_types[[1L]] <- NA_character_
  unknown_result <- .cran07_cmp_glmm_boundary_assessment(
    unknown,
    mode = "latent",
    family_name = "gaussian",
    residual_sd = 0.4
  )
  expect_identical(unknown_result$assessed, FALSE)
  expect_identical(unknown_result$pass, FALSE)
  expect_match(
    paste(unknown_result$unassessed, collapse = "; "),
    "component"
  )
})

test_that("CRAN 0.7 release ledger treats skips and omissions as HOLD", {
  not_run <- .cran07_cmp_release_recertify(execute = FALSE)
  expect_equal(not_run$status, rep("HOLD", 6L))
  expect_equal(not_run$attempted, rep(FALSE, 6L))

  missing_dependency <- .cran07_cmp_release_recertify(
    execute = TRUE,
    dependency_available = FALSE
  )
  expect_equal(missing_dependency$status, rep("HOLD", 6L))
  expect_equal(missing_dependency$attempted, rep(FALSE, 6L))

  incomplete_runner <- function(cell_id) list(cell_id = cell_id)
  incomplete <- .cran07_cmp_release_recertify(
    execute = TRUE,
    dependency_available = TRUE,
    exact_runner = incomplete_runner
  )
  expect_equal(incomplete$status, rep("HOLD", 6L))
  expect_equal(incomplete$attempted, rep(TRUE, 6L))

  nested_skip_runner <- function(cell_id) {
    nested <- function() testthat::skip(paste("nested skip", cell_id))
    nested()
  }
  skipped <- .cran07_cmp_release_recertify(
    execute = TRUE,
    dependency_available = TRUE,
    exact_runner = nested_skip_runner
  )
  expect_equal(skipped$status, rep("HOLD", 6L))
  expect_equal(skipped$attempted, rep(TRUE, 6L))
  expect_equal(
    grepl("runner skipped:.*nested skip", skipped$reason),
    rep(TRUE, 6L)
  )
})

test_that("CRAN 0.7 Stan drivers retain the fixed nine-point fail-closed gate", {
  drivers <- testthat::test_path(
    "..",
    "..",
    "dev",
    "stan-oracle",
    c("gauss-reconcile.R", "gauss-reconcile-k2.R")
  )
  if (all(file.exists(drivers))) {
    text <- lapply(drivers, function(path) {
      paste(readLines(path, warn = FALSE), collapse = "\n")
    })
    expect_gt(length(parse(file = drivers[[1L]])), 0L)
    expect_gt(length(parse(file = drivers[[2L]])), 0L)
    expect_match(
      text[[1L]],
      "latent(0 + trait | unit, d = 1, unique = FALSE)",
      fixed = TRUE
    )
    expect_match(
      text[[2L]],
      "latent(0 + trait | unit, d = 2, unique = FALSE)",
      fixed = TRUE
    )
    expect_match(text[[1L]], "length(res) == 6L", fixed = TRUE)
    expect_match(text[[2L]], "length(res) == 3L", fixed = TRUE)
    expect_match(
      text[[2L]],
      "length(k1$points) + length(res) == 9L",
      fixed = TRUE
    )
    expect_match(text[[1L]], "max(tab$rel_diff) <= 1e-12", fixed = TRUE)
    expect_match(text[[2L]], "max(tab$rel_diff) <= 1e-12", fixed = TRUE)
    expect_match(
      text[[1L]],
      "GLLVMTMB_STAN_ORACLE_RUN_TOKEN",
      fixed = TRUE
    )
    expect_match(
      text[[2L]],
      "identical(k1$provenance$run_token, run_token)",
      fixed = TRUE
    )
    expect_match(text[[1L]], "tools::md5sum(provenance_files)", fixed = TRUE)
    expect_match(
      text[[2L]],
      "identical(as.character(k1_hashes), as.character(current_hashes))",
      fixed = TRUE
    )
    expect_match(text[[2L]], "k1_output_hash", fixed = TRUE)
    expect_false(any(grepl(
      "local-scratch/worktrees/stan-oracle",
      text,
      fixed = TRUE
    )))
  } else {
    testthat::succeed(
      "Stan development drivers are excluded from this source tree."
    )
  }
})

test_that("CRAN 0.7 Gaussian indep matches glmmTMB diag exactly", {
  .cran07_cmp_skip()
  .cran07_cmp_run_exact("cmp07-gaussian-indep-n240")
})

test_that("CRAN 0.7 Gaussian dep matches glmmTMB us exactly", {
  .cran07_cmp_skip()
  .cran07_cmp_run_exact("cmp07-gaussian-dep-n240")
})

test_that("CRAN 0.7 Gaussian latent plus Psi matches glmmTMB rr plus diag", {
  .cran07_cmp_skip()
  .cran07_cmp_run_exact("cmp07-gaussian-latent-n240")
})

test_that("CRAN 0.7 Poisson latent plus Psi matches glmmTMB rr plus diag", {
  .cran07_cmp_skip()
  .cran07_cmp_run_exact("cmp07-poisson-latent-n300")
})

test_that("CRAN 0.7 NB2 latent plus Psi matches reconciled glmmTMB rr plus diag", {
  .cran07_cmp_skip()
  .cran07_cmp_run_exact("cmp07-nb2-latent-n300")
})

test_that("CRAN 0.7 Binomial(10) latent plus Psi matches glmmTMB rr plus diag", {
  .cran07_cmp_skip()
  .cran07_cmp_run_exact("cmp07-binomial-latent-n300")
})

test_that("CRAN 0.7 fail-closed release recertification executes every exact row", {
  testthat::skip_if_not(
    identical(Sys.getenv("GLLVMTMB_CRAN07_RECERTIFY"), "true"),
    "Set GLLVMTMB_CRAN07_RECERTIFY=true for the release evidence run."
  )
  ledger <- .cran07_cmp_release_recertify(execute = TRUE)
  expect_identical(ledger$cell_id, .cran07_cmp_manifest$cell_id)
  .cran07_cmp_assert_release_pass(ledger)
})
