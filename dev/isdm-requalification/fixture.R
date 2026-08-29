## Frozen public-route DGP helpers. Sourceable under testthat after gllvmTMB is
## loaded; no function starts a fit.

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

isdm_pack_covariance <- function(lambda, psi) {
  lambda <- as.matrix(lambda)
  psi <- as.numeric(psi)
  if (nrow(lambda) != length(psi) || any(!is.finite(c(lambda, psi))) ||
      any(psi < 0)) {
    stop("lambda and psi must define one finite non-negative trait covariance")
  }
  Psi <- diag(psi, nrow = length(psi), ncol = length(psi))
  trait_names <- names(psi) %||% rownames(lambda) %||%
    paste0("trait", seq_along(psi))
  dimnames(Psi) <- list(trait_names, trait_names)
  Sigma <- tcrossprod(lambda) + Psi
  dimnames(Sigma) <- list(trait_names, trait_names)
  list(Sigma = Sigma, Psi = Psi)
}

isdm_inverse_link <- function(eta, law = c("poisson", "cloglog"),
                              log_support = 0) {
  law <- match.arg(law)
  linear <- eta + log_support
  if (law == "poisson") exp(linear) else -expm1(-exp(linear))
}

.isdm_condition <- function(message, class) {
  structure(list(message = message, call = NULL),
            class = c(class, "error", "condition"))
}

isdm_assert_observed_source_completeness <- function(
    data, response = "value", source = "isdm_source", trait = "trait") {
  required <- c(response, source, trait)
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("missing completeness column: ", missing[[1L]])
  declared <- function(x) {
    if (is.factor(x)) levels(x) else unique(as.character(x))
  }
  source_levels <- declared(data[[source]])
  trait_levels <- declared(data[[trait]])
  arms <- expand.grid(source = source_levels, trait = trait_levels,
                      KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  observed <- vapply(seq_len(nrow(arms)), function(i) {
    rows <- as.character(data[[source]]) == arms$source[[i]] &
      as.character(data[[trait]]) == arms$trait[[i]]
    any(rows & !is.na(data[[response]]))
  }, logical(1L))
  names(observed) <- paste(arms$source, arms$trait, sep = ".")
  if (!length(observed) || any(!observed)) {
    bad <- names(observed)[!observed]
    stop(.isdm_condition(
      paste0("Every declared source-trait arm must contain an observed response; ",
             "all-NA arm", if (length(bad) == 1L) " " else "s ",
             paste(bad, collapse = ", "), "."),
      "gllvmTMB_isdm_observed_source_incomplete"
    ))
  }
  invisible(data)
}

.isdm_source_cells <- function(n_cells, n_sources, overlap) {
  ids <- seq_len(n_cells)
  if (overlap == "full") return(rep(list(ids), n_sources))
  if (overlap == "disconnected") {
    return(split(ids, cut(ids, breaks = n_sources, labels = FALSE)))
  }
  if (overlap != "weak") stop("unknown overlap regime: ", overlap)
  ## Narrow source windows plus a common central bridge. Every source shares
  ## the bridge, so the support graph is connected by construction.
  width <- max(3L, floor(0.08 * n_cells))
  bridge <- seq.int(max(1L, floor(n_cells / 2) - width),
                    min(n_cells, floor(n_cells / 2) + width))
  blocks <- split(ids, cut(ids, breaks = n_sources, labels = FALSE))
  lapply(blocks, function(block) sort(unique(c(block, bridge))))
}

isdm_source_support_connected <- function(data) {
  sources <- unique(as.character(data$isdm_source))
  cells <- split(as.character(data$cell_id), as.character(data$isdm_source))
  adjacency <- outer(sources, sources, Vectorize(function(a, b) {
    length(intersect(cells[[a]], cells[[b]])) > 0L
  }))
  reached <- 1L
  repeat {
    next_reached <- sort(unique(c(reached, which(colSums(adjacency[reached, ,
                                                             drop = FALSE]) > 0L))))
    if (identical(next_reached, reached)) break
    reached <- next_reached
  }
  length(reached) == length(sources)
}

isdm_nonspatial_fixture <- function(seed, n_sources = 2L,
                                    overlap = c("full", "weak", "disconnected"),
                                    n_cells = 150L, observation_seed = seed) {
  overlap <- match.arg(overlap)
  n_sources <- as.integer(n_sources)
  n_cells <- as.integer(n_cells)
  if (!n_sources %in% c(2L, 3L)) stop("n_sources must be 2 or 3")
  if (n_cells < 12L) stop("n_cells must be at least 12")
  set.seed(seed)

  traits <- paste0("sp", 1:3)
  cells <- sprintf("cell%04d", seq_len(n_cells))
  sources <- paste0("source", seq_len(n_sources))
  env <- as.numeric(scale(stats::rnorm(n_cells)))
  alpha <- c(-0.35, 0.05, 0.30)
  beta <- c(0.55, -0.35, 0.25)
  lambda <- matrix(c(0.75, -0.50, 0.60), ncol = 1L,
                   dimnames = list(traits, "axis1"))
  psi <- setNames(c(0.20, 0.30, 0.25), traits)
  u <- stats::rnorm(n_cells)
  e <- matrix(stats::rnorm(n_cells * 3L, sd = rep(sqrt(psi), each = n_cells)),
              nrow = n_cells, ncol = 3L,
              dimnames = list(cells, traits))
  eta <- sweep(outer(env, beta), 2L, alpha, "+") +
    tcrossprod(u, as.numeric(lambda)) + e
  dimnames(eta) <- list(cells, traits)
  gamma <- setNames(seq(0, 0.20, length.out = n_sources), sources)
  delta <- setNames(seq(0.25, 0.55, length.out = n_sources), sources)
  laws <- c(rep("poisson", n_sources - 1L), "cloglog")
  source_cells <- .isdm_source_cells(n_cells, n_sources, overlap)
  bias_values <- lapply(seq_len(n_sources), function(d) {
    as.numeric(scale(stats::rnorm(n_cells)))
  })
  set.seed(observation_seed)

  rows <- lapply(seq_len(n_sources), function(d) {
    cell_index <- source_cells[[d]]
    grid <- expand.grid(cell_index = cell_index, trait_index = seq_along(traits),
                        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
    bias <- bias_values[[d]][grid$cell_index]
    ecological <- eta[cbind(grid$cell_index, grid$trait_index)]
    linear <- ecological + gamma[[d]] + delta[[d]] * bias
    fixed_truth <- alpha[grid$trait_index] + beta[grid$trait_index] *
      env[grid$cell_index] + gamma[[d]] + delta[[d]] * bias
    support <- if (laws[[d]] == "poisson") 1.5 else 0.9
    value <- if (laws[[d]] == "poisson") {
      stats::rpois(nrow(grid), isdm_inverse_link(linear, "poisson", log(support)))
    } else {
      stats::rbinom(nrow(grid), 1L,
                    isdm_inverse_link(linear, "cloglog", log(support)))
    }
    data.frame(
      value = value,
      trait = traits[grid$trait_index],
      cell_id = cells[grid$cell_index],
      isdm_source = sources[[d]],
      env = env[grid$cell_index],
      bias_x = bias,
      truth_fixed = fixed_truth,
      support = support,
      log_support = log(support),
      stringsAsFactors = FALSE
    )
  })
  data <- do.call(rbind, rows)
  data$trait <- factor(data$trait, levels = traits)
  data$cell_id <- factor(data$cell_id, levels = cells)
  data$isdm_source <- factor(data$isdm_source, levels = sources)

  scoring_grid <- expand.grid(cell_index = seq_len(n_cells),
                              trait_index = seq_along(traits),
                              KEEP.OUT.ATTRS = FALSE,
                              stringsAsFactors = FALSE)
  scoring <- data.frame(
    value = NA_real_, trait = traits[scoring_grid$trait_index],
    cell_id = cells[scoring_grid$cell_index], isdm_source = sources[[1L]],
    env = env[scoring_grid$cell_index], bias_x = 0,
    support = 1, log_support = 0, stringsAsFactors = FALSE
  )
  scoring$trait <- factor(scoring$trait, levels = traits)
  scoring$cell_id <- factor(scoring$cell_id, levels = cells)
  scoring$isdm_source <- factor(scoring$isdm_source, levels = sources)
  scoring_truth <- eta[cbind(scoring_grid$cell_index, scoring_grid$trait_index)]

  declarations <- lapply(seq_len(n_sources), function(d) {
    family <- if (laws[[d]] == "poisson") stats::poisson() else
      stats::binomial(link = "cloglog")
    gllvmTMB::isdm_source(family, observation = ~ bias_x)
  })
  names(declarations) <- sources
  families <- do.call(gllvmTMB::isdm_sources, declarations)
  covariance <- isdm_pack_covariance(lambda, psi)
  list(
    data = data,
    scoring = scoring,
    families = families,
    truth = list(
      alpha = setNames(alpha, traits), beta = setNames(beta, traits),
      gamma = gamma, delta = delta, lambda = lambda, psi = psi,
      eta_ecological = eta, surface = scoring_truth,
      surface_trait = as.character(scoring$trait),
      Sigma = covariance$Sigma, Psi = covariance$Psi
    ),
    design = list(seed = observation_seed, structure_seed = seed,
                  n_sources = n_sources, overlap = overlap,
                  n_cells = n_cells, laws = setNames(laws, sources))
  )
}

isdm_spatial_geometry <- function(n_cells = 810L, seed) {
  n_cells <- as.integer(n_cells)
  side <- ceiling(sqrt(n_cells))
  grid <- expand.grid(x = seq(0, 1, length.out = side),
                      y = seq(0, 1, length.out = side),
                      KEEP.OUT.ATTRS = FALSE)
  grid <- grid[seq_len(n_cells), , drop = FALSE]
  interior <- which(grid$x > min(grid$x) & grid$x < max(grid$x) &
                    grid$y > min(grid$y) & grid$y < max(grid$y))
  n_hold <- floor(0.20 * n_cells)
  if (length(interior) < n_hold) stop("not enough interior cells to withhold")
  set.seed(seed)
  held <- sample(interior, n_hold, replace = FALSE)
  grid$cell_id <- sprintf("cell%04d", seq_len(n_cells))
  grid$held_out <- seq_len(n_cells) %in% held
  grid[c("cell_id", "x", "y", "held_out")]
}

isdm_spatial_fixture <- function(seed, n_sources = 2L,
                                 overlap = c("full", "weak"),
                                 n_cells = 810L, cutoff = 0.08,
                                 kappa = 5) {
  overlap <- match.arg(overlap)
  if (!requireNamespace("fmesher", quietly = TRUE) ||
      !requireNamespace("Matrix", quietly = TRUE)) {
    stop(.isdm_condition("fmesher and Matrix are required for the spatial fixture",
                         "isdm_spatial_environment_unavailable"))
  }
  n_sources <- as.integer(n_sources)
  geometry <- isdm_spatial_geometry(n_cells, seed)
  traits <- paste0("sp", 1:3)
  sources <- paste0("source", seq_len(n_sources))
  laws <- c(rep("poisson", n_sources - 1L), "cloglog")
  source_cells <- .isdm_source_cells(n_cells, n_sources, overlap)

  skeleton <- do.call(rbind, lapply(seq_len(n_sources), function(d) {
    available <- setdiff(source_cells[[d]], which(geometry$held_out))
    grid <- expand.grid(cell_index = available, trait_index = seq_along(traits),
                        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
    data.frame(
      cell_index = grid$cell_index,
      trait = traits[grid$trait_index],
      cell_id = geometry$cell_id[grid$cell_index],
      isdm_source = sources[[d]],
      x = geometry$x[grid$cell_index],
      y = geometry$y[grid$cell_index],
      stringsAsFactors = FALSE
    )
  }))
  mesh <- gllvmTMB::make_mesh(skeleton, c("x", "y"), cutoff = cutoff)
  Q <- kappa^4 * mesh$spde$c0 + 2 * kappa^2 * mesh$spde$g1 + mesh$spde$g2
  Q_dense <- as.matrix(Q)
  Q_dense <- (Q_dense + t(Q_dense)) / 2 + diag(1e-8, nrow(Q_dense))
  set.seed(seed + 1L)
  omega <- backsolve(chol(Q_dense), stats::rnorm(nrow(Q_dense)))
  A_full <- fmesher::fm_basis(mesh$mesh, loc = as.matrix(geometry[c("x", "y")]))
  field <- as.numeric(A_full %*% omega)

  env <- as.numeric(scale(geometry$x - 0.5 * geometry$y))
  alpha <- c(-0.35, 0.05, 0.30)
  beta <- c(0.55, -0.35, 0.25)
  lambda <- setNames(c(0.85, -0.55, 0.65), traits)
  gamma <- setNames(seq(0, 0.20, length.out = n_sources), sources)
  delta <- setNames(seq(0.25, 0.55, length.out = n_sources), sources)
  bias_surface <- lapply(seq_len(n_sources), function(d) {
    as.numeric(scale(sin(2 * pi * geometry$x + d / 3) +
                       cos(2 * pi * geometry$y - d / 4)))
  })

  build_rows <- function(d, cell_index, include_response) {
    grid <- expand.grid(cell_index = cell_index, trait_index = seq_along(traits),
                        KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
    bias <- bias_surface[[d]][grid$cell_index]
    ecological <- alpha[grid$trait_index] + beta[grid$trait_index] *
      env[grid$cell_index] + lambda[grid$trait_index] * field[grid$cell_index]
    linear <- ecological + gamma[[d]] + delta[[d]] * bias
    fixed_truth <- alpha[grid$trait_index] + beta[grid$trait_index] *
      env[grid$cell_index] + gamma[[d]] + delta[[d]] * bias
    support <- if (include_response) {
      if (laws[[d]] == "poisson") 1.5 else 0.9
    } else 1
    value <- if (!include_response) {
      rep(NA_real_, nrow(grid))
    } else if (laws[[d]] == "poisson") {
      stats::rpois(nrow(grid), isdm_inverse_link(linear, "poisson", log(support)))
    } else {
      stats::rbinom(nrow(grid), 1L,
                    isdm_inverse_link(linear, "cloglog", log(support)))
    }
    data.frame(
      value = value, trait = traits[grid$trait_index],
      cell_id = geometry$cell_id[grid$cell_index],
      isdm_source = sources[[d]], env = env[grid$cell_index],
      bias_x = bias, support = support, log_support = log(support),
      truth_fixed = fixed_truth,
      x = geometry$x[grid$cell_index], y = geometry$y[grid$cell_index],
      truth_eta_ecological = ecological, stringsAsFactors = FALSE
    )
  }
  set.seed(seed + 2L)
  training <- do.call(rbind, lapply(seq_len(n_sources), function(d) {
    build_rows(d, setdiff(source_cells[[d]], which(geometry$held_out)), TRUE)
  }))
  heldout <- do.call(rbind, lapply(seq_len(n_sources), function(d) {
    build_rows(d, which(geometry$held_out), FALSE)
  }))
  map_grid <- expand.grid(cell_index = which(geometry$held_out),
                          trait_index = seq_along(traits),
                          KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  map_truth <- alpha[map_grid$trait_index] + beta[map_grid$trait_index] *
    env[map_grid$cell_index] + lambda[map_grid$trait_index] * field[map_grid$cell_index]
  map_newdata <- data.frame(
    value = NA_real_, trait = traits[map_grid$trait_index],
    cell_id = geometry$cell_id[map_grid$cell_index],
    isdm_source = sources[[1L]], env = env[map_grid$cell_index],
    bias_x = 0, support = 1, log_support = 0,
    truth_fixed = alpha[map_grid$trait_index] +
      beta[map_grid$trait_index] * env[map_grid$cell_index],
    x = geometry$x[map_grid$cell_index], y = geometry$y[map_grid$cell_index],
    truth_eta_ecological = map_truth, stringsAsFactors = FALSE
  )
  factorize <- function(data) {
    data$trait <- factor(data$trait, levels = traits)
    data$cell_id <- factor(data$cell_id, levels = geometry$cell_id)
    data$isdm_source <- factor(data$isdm_source, levels = sources)
    data
  }
  training <- factorize(training)
  heldout <- factorize(heldout)
  map_newdata <- factorize(map_newdata)
  ## make_mesh() is observation-aligned. It was built on the skeleton, whose
  ## ordering is exactly the training row ordering constructed above.
  stopifnot(nrow(mesh$A_st) == nrow(training),
            identical(as.character(skeleton$cell_id),
                      as.character(training$cell_id)))

  declarations <- lapply(seq_len(n_sources), function(d) {
    family <- if (laws[[d]] == "poisson") stats::poisson() else
      stats::binomial(link = "cloglog")
    gllvmTMB::isdm_source(family, observation = ~ bias_x)
  })
  names(declarations) <- sources
  list(
    data = training,
    heldout = heldout,
    map_newdata = map_newdata,
    mesh = mesh,
    families = do.call(gllvmTMB::isdm_sources, declarations),
    truth = list(alpha = setNames(alpha, traits), beta = setNames(beta, traits),
                 gamma = gamma, delta = delta, lambda = lambda,
                 omega = omega, kappa = kappa, field = field,
                 heldout_surface = map_newdata$truth_eta_ecological,
                 heldout_trait = as.character(map_newdata$trait),
                 heldout_group = as.character(map_newdata$trait)),
    design = list(seed = seed, n_sources = n_sources, overlap = overlap,
                  n_cells = n_cells, holdout = "all rows at 20% interior coordinates",
                  mesh_domain = "training coordinates only",
                  laws = setNames(laws, sources))
  )
}
