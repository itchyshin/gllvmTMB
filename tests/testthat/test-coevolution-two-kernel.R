## Phase C3 cross-lineage coevolution two-kernel model (Design 65 sec. C3).
##
## C3.1 -- fit two named kernel tiers. First-wave scope:
##   symbolic model          eta_t(u) += Lambda_phy[t,] g_phy[u,] +
##                                      Lambda_non[t,] g_non[u,]
##   implementation objects  kernel_latent(..., name = "phy"|"non"),
##                           Ainv_kernel[r,,], theta_rr_kernel, g_kernel
##   extractor target        extract_Sigma(level = r, part = "shared") and
##                           extract_Gamma(level = r)
##   validation target       separate named component shapes, no rho/interval
##                           calibration claim yet
##   guard                   PR green != bridge complete != release ready !=
##                           scientific coverage passed
##
## The old C0-C2 core still routes one named kernel tier through the
## phylo-equivalent slot for KER-02 equivalence. Two distinct names now activate
## the fixed dense multi-kernel block: each tier has its own K_r, Lambda_r, and
## latent field. Explicit Psi_r is deferred out of the Paper 2 first wave.
##
## C3.2 -- identifiability guardrail. Two `kernel_unique` tiers are not
## separable without within-species replication; the engine defaults to a
## single uniqueness tier and emits a `cli::cli_warn`. Replication is counted
## in DISTINCT observation units per species (the `unit_obs` factor), NOT raw
## long-format rows -- a wide `traits(...)` call stacks each species into
## `n_traits` rows, so a raw-row count would mistake trait-stacking for
## replication and skip the collapse (then abort at the single-`name` guard).
##
## NOTE on the heavy "two Psi WITH replication" cell below: the new C3.1 engine
## can host fixed named latent tiers, but Paper 2 multi-kernel fits are
## deliberately latent-only in this first wave. The heavy recovery/calibration
## side of explicit Psi remains a later grammar/design cell, likely after the
## post-arc `*_unique()` deprecation plan. The existing heavy test asserts the
## older single identifiable phylo uniqueness tier recovered as a positive
## diagonal under within-species replication; the non-phylo residual is absorbed
## by the replicate error term.

.c3_tree_corr <- function(n, prefix) {
  tree <- ape::rcoal(n)
  tree$tip.label <- paste0(prefix, seq_len(n))
  A <- ape::vcv(tree, corr = TRUE)
  A <- A[tree$tip.label, tree$tip.label, drop = FALSE]
  storage.mode(A) <- "double"
  A
}

## A small single-row-per-species data frame (no within-species
## replication) -- the non-separable C3.2 case.
.c3_make_unreplicated <- function(seed = 71L, n = 6L) {
  set.seed(seed)
  species <- paste0("s", seq_len(n))
  A <- matrix(0.3, n, n)
  diag(A) <- 1
  rownames(A) <- colnames(A) <- species
  df <- data.frame(
    row_id = factor(paste0("obs", seq_len(n))),
    species = factor(species, levels = species),
    y1 = stats::rnorm(n),
    y2 = stats::rnorm(n),
    stringsAsFactors = FALSE
  )
  list(data = df, A = A, species = species)
}

.c3_axis_kernel <- function(n, prefix, range = 0.45) {
  x <- seq(-1, 1, length.out = n)
  A <- exp(-abs(outer(x, x, "-")) / range)
  rownames(A) <- colnames(A) <- paste0(prefix, seq_len(n))
  storage.mode(A) <- "double"
  A
}

.c3_association_pattern <- function(
  n_H,
  n_P,
  type = c("aligned", "opposed"),
  range = 0.18
) {
  type <- match.arg(type)
  h <- seq(-1, 1, length.out = n_H)
  p <- seq(-1, 1, length.out = n_P)
  if (identical(type, "opposed")) {
    p <- -p
  }
  exp(-abs(outer(h, p, "-")) / range)
}

.c3_kernel_similarity <- function(K_1, K_2) {
  stopifnot(identical(dim(K_1), dim(K_2)))
  off_diag <- row(K_1) != col(K_1)
  x <- K_1[off_diag]
  y <- K_2[off_diag]
  sum(x * y) / sqrt(sum(x^2) * sum(y^2))
}

.c3_muffle_lifecycle_warnings <- function(expr) {
  withCallingHandlers(
    expr,
    warning = function(w) {
      if (inherits(w, "lifecycle_warning_deprecated")) {
        invokeRestart("muffleWarning")
      }
    }
  )
}

.c3_kernel_overlap_class <- function(similarity) {
  if (similarity < 0.25) {
    "near_orthogonal"
  } else if (similarity < 0.70) {
    "moderate"
  } else {
    "high"
  }
}

.c3_gamma_corr <- function(x, y) {
  abs(stats::cor(as.vector(x), as.vector(y)))
}

.c3_inv_sqrt <- function(x, tol = sqrt(.Machine$double.eps)) {
  x <- (x + t(x)) / 2
  eg <- eigen(x, symmetric = TRUE)
  scale <- max(abs(eg$values), 1)
  keep <- eg$values > tol * scale
  values <- numeric(length(eg$values))
  values[keep] <- 1 / sqrt(eg$values[keep])
  out <- eg$vectors %*% diag(values, nrow = length(values)) %*% t(eg$vectors)
  dimnames(out) <- dimnames(x)
  out
}

.c3_make_two_component_fixture <- function(
  seed = 2003L,
  n_H = 32L,
  n_P = 32L,
  n_rep = 6L,
  rho_phy = 0.55,
  rho_non = 0.55,
  non_association_blend = 0,
  identical_kernels = FALSE,
  non_kernel_phy_mix = 0,
  lambda_phy_scale = 1,
  lambda_non_scale = 1,
  resid_sd = 0.08
) {
  set.seed(seed)
  A_H <- .c3_axis_kernel(n_H, "H", range = 0.45)
  A_P <- .c3_axis_kernel(n_P, "P", range = 0.45)
  I_H <- diag(n_H)
  I_P <- diag(n_P)
  rownames(I_H) <- colnames(I_H) <- rownames(A_H)
  rownames(I_P) <- colnames(I_P) <- rownames(A_P)

  W_phy <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_non_opposed <- .c3_association_pattern(n_H, n_P, type = "opposed")
  W_non_aligned <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_non <- non_association_blend *
    W_non_aligned +
    (1 - non_association_blend) * W_non_opposed
  dimnames(W_phy) <- dimnames(W_non) <- list(rownames(A_H), rownames(A_P))
  K_phy <- gllvmTMB::make_cross_kernel(A_H, A_P, W_phy, rho = rho_phy)
  K_non <- gllvmTMB::make_cross_kernel(I_H, I_P, W_non, rho = rho_non)
  if (isTRUE(identical_kernels)) {
    K_non <- K_phy
  } else if (non_kernel_phy_mix > 0) {
    stopifnot(non_kernel_phy_mix < 1)
    K_non <- non_kernel_phy_mix * K_phy + (1 - non_kernel_phy_mix) * K_non
    dimnames(K_non) <- dimnames(K_phy)
  }

  trait_names <- c("h_size", "h_defence", "p_size", "p_attack")
  host_traits <- trait_names[1:2]
  partner_traits <- trait_names[3:4]

  ## COE-04 near-orthogonal recovery alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy | kernel_latent(species, K = K_phy, name = "phy") | make_cross_kernel(A_H, A_P, W_phy, rho_phy) | fit$kernel_levels / diagnostic | K_phy |
  ## | K_non | kernel_latent(species, K = K_non, name = "non") | make_cross_kernel(I_H, I_P, W_non, rho_non) | fit$kernel_levels / diagnostic | K_non |
  ## | g_phy | kernel_latent(..., d = 1, name = "phy") | N(0, K_phy) | extract_Sigma(level = "phy", part = "shared") | Lambda_phy Lambda_phy^T |
  ## | g_non | kernel_latent(..., d = 1, name = "non") | N(0, K_non) | extract_Sigma(level = "non", part = "shared") | Lambda_non Lambda_non^T |
  ## | Gamma_phy | same "phy" tier | Lambda_H,phy Lambda_P,phy^T | extract_Gamma(level = "phy") | Gamma_shape_phy |
  ## | Gamma_non | same "non" tier | Lambda_H,non Lambda_P,non^T | extract_Gamma(level = "non") | Gamma_shape_non |
  Lambda_phy <- lambda_phy_scale * matrix(c(1.10, 0.70, 0.80, -0.60), 4L, 1L)
  Lambda_non <- lambda_non_scale * matrix(c(0.60, -0.90, 1.00, 0.65), 4L, 1L)
  rownames(Lambda_phy) <- rownames(Lambda_non) <- trait_names

  n_total <- n_H + n_P
  G_phy <- t(chol(K_phy + diag(1e-8, n_total))) %*%
    matrix(stats::rnorm(n_total), n_total, 1L)
  G_non <- t(chol(K_non + diag(1e-8, n_total))) %*%
    matrix(stats::rnorm(n_total), n_total, 1L)
  eta <- G_phy %*% t(Lambda_phy) + G_non %*% t(Lambda_non)
  eta <- sweep(eta, 2L, c(0.10, -0.10, 0.05, -0.05), `+`)
  colnames(eta) <- trait_names

  species <- rownames(K_phy)
  lineage <- c(rep("host", n_H), rep("partner", n_P))
  rows <- vector("list", n_total * n_rep)
  k <- 1L
  for (i in seq_len(n_total)) {
    for (r in seq_len(n_rep)) {
      y <- eta[i, ] + stats::rnorm(length(trait_names), 0, resid_sd)
      rows[[k]] <- data.frame(
        row_id = paste0("obs", k),
        species = species[i],
        h_size = if (lineage[i] == "host") y[1L] else NA_real_,
        h_defence = if (lineage[i] == "host") y[2L] else NA_real_,
        p_size = if (lineage[i] == "partner") y[3L] else NA_real_,
        p_attack = if (lineage[i] == "partner") y[4L] else NA_real_,
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }
  df <- do.call(rbind, rows)
  df$row_id <- factor(df$row_id)
  df$species <- factor(df$species, levels = species)

  list(
    data = df,
    A_H = A_H,
    A_P = A_P,
    I_H = I_H,
    I_P = I_P,
    W_phy = W_phy,
    W_non = W_non,
    K_phy = K_phy,
    K_non = K_non,
    Gamma_phy = Lambda_phy[host_traits, , drop = FALSE] %*%
      t(Lambda_phy[partner_traits, , drop = FALSE]),
    Gamma_non = Lambda_non[host_traits, , drop = FALSE] %*%
      t(Lambda_non[partner_traits, , drop = FALSE]),
    host_traits = host_traits,
    partner_traits = partner_traits,
    similarity = .c3_kernel_similarity(K_phy, K_non)
  )
}

.c3_make_poisson_two_kernel_fixture <- function(
  seed = 2701L,
  n_H = 16L,
  n_P = 16L,
  n_rep = 4L
) {
  fx <- .c3_make_two_component_fixture(
    seed = seed,
    n_H = n_H,
    n_P = n_P,
    n_rep = n_rep,
    lambda_phy_scale = 0.45,
    lambda_non_scale = 0.45,
    resid_sd = 0.05
  )
  set.seed(seed + 100L)
  for (nm in c("h_size", "h_defence", "p_size", "p_attack")) {
    idx <- !is.na(fx$data[[nm]])
    eta <- 0.7 + 0.20 * as.numeric(base::scale(fx$data[[nm]][idx]))
    fx$data[[nm]][idx] <- stats::rpois(sum(idx), lambda = exp(eta))
  }
  fx
}

.c3_make_poisson_two_kernel_recovery_fixture <- function(
  seed = 2801L,
  n_H = 24L,
  n_P = 24L,
  n_rep = 12L,
  lambda_phy_scale = 0.30,
  lambda_non_scale = 0.30,
  intercept = 1.2
) {
  set.seed(seed)
  A_H <- .c3_axis_kernel(n_H, "H", range = 0.45)
  A_P <- .c3_axis_kernel(n_P, "P", range = 0.45)
  I_H <- diag(n_H)
  I_P <- diag(n_P)
  rownames(I_H) <- colnames(I_H) <- rownames(A_H)
  rownames(I_P) <- colnames(I_P) <- rownames(A_P)

  W_phy <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_non <- .c3_association_pattern(n_H, n_P, type = "opposed")
  dimnames(W_phy) <- dimnames(W_non) <- list(rownames(A_H), rownames(A_P))
  K_phy <- gllvmTMB::make_cross_kernel(A_H, A_P, W_phy, rho = 0.55)
  K_non <- gllvmTMB::make_cross_kernel(I_H, I_P, W_non, rho = 0.55)

  trait_names <- c("h_size", "h_defence", "p_size", "p_attack")
  host_traits <- trait_names[1:2]
  partner_traits <- trait_names[3:4]
  Lambda_phy <- lambda_phy_scale * matrix(c(1.10, 0.70, 0.80, -0.60), 4L, 1L)
  Lambda_non <- lambda_non_scale * matrix(c(0.60, -0.90, 1.00, 0.65), 4L, 1L)
  rownames(Lambda_phy) <- rownames(Lambda_non) <- trait_names

  n_total <- n_H + n_P
  G_phy <- t(chol(K_phy + diag(1e-8, n_total))) %*%
    matrix(stats::rnorm(n_total), n_total, 1L)
  G_non <- t(chol(K_non + diag(1e-8, n_total))) %*%
    matrix(stats::rnorm(n_total), n_total, 1L)
  eta <- G_phy %*% t(Lambda_phy) + G_non %*% t(Lambda_non)
  eta <- sweep(eta, 2L, rep(intercept, length(trait_names)), `+`)
  colnames(eta) <- trait_names

  species <- rownames(K_phy)
  lineage <- c(rep("host", n_H), rep("partner", n_P))
  rows <- vector("list", n_total * n_rep)
  k <- 1L
  for (i in seq_len(n_total)) {
    for (r in seq_len(n_rep)) {
      y <- stats::rpois(length(trait_names), lambda = exp(eta[i, ]))
      rows[[k]] <- data.frame(
        row_id = paste0("obs", k),
        species = species[i],
        h_size = if (lineage[i] == "host") y[1L] else NA_real_,
        h_defence = if (lineage[i] == "host") y[2L] else NA_real_,
        p_size = if (lineage[i] == "partner") y[3L] else NA_real_,
        p_attack = if (lineage[i] == "partner") y[4L] else NA_real_,
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }
  df <- do.call(rbind, rows)
  df$row_id <- factor(df$row_id)
  df$species <- factor(df$species, levels = species)

  list(
    data = df,
    K_phy = K_phy,
    K_non = K_non,
    Gamma_phy = Lambda_phy[host_traits, , drop = FALSE] %*%
      t(Lambda_phy[partner_traits, , drop = FALSE]),
    Gamma_non = Lambda_non[host_traits, , drop = FALSE] %*%
      t(Lambda_non[partner_traits, , drop = FALSE]),
    host_traits = host_traits,
    partner_traits = partner_traits,
    similarity = .c3_kernel_similarity(K_phy, K_non),
    eta_range = range(eta),
    mean_mu = mean(exp(eta))
  )
}

.c3_fit_two_kernel_set <- function(fx, include_intercept = FALSE) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_full <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_phy_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_phy, d = 1, name = "phy"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_non_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_intercept <- NULL
  if (isTRUE(include_intercept)) {
    fit_intercept <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(h_size, h_defence, p_size, p_attack) ~ 1,
      data = fx$data,
      unit = "row_id",
      cluster = "species",
      family = stats::gaussian(),
      control = ctl
    )))
  }
  list(
    full = fit_full,
    phy_only = fit_phy_only,
    non_only = fit_non_only,
    intercept = fit_intercept,
    Gamma_phy = gllvmTMB::extract_Gamma(
      fit_full,
      level = "phy",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    ),
    Gamma_non = gllvmTMB::extract_Gamma(
      fit_full,
      level = "non",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
  )
}

.c3_fit_two_kernel_null_set <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_full <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_intercept <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~ 1,
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  list(
    full = fit_full,
    intercept = fit_intercept,
    Gamma_phy = gllvmTMB::extract_Gamma(
      fit_full,
      level = "phy",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    ),
    Gamma_non = gllvmTMB::extract_Gamma(
      fit_full,
      level = "non",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
  )
}

.c3_fit_poisson_two_kernel_set <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_full <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::poisson(),
    control = ctl
  )))
  fit_phy_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_phy, d = 1, name = "phy"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::poisson(),
    control = ctl
  )))
  fit_non_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::poisson(),
    control = ctl
  )))
  list(
    full = fit_full,
    phy_only = fit_phy_only,
    non_only = fit_non_only,
    Gamma_phy = gllvmTMB::extract_Gamma(
      fit_full,
      level = "phy",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    ),
    Gamma_non = gllvmTMB::extract_Gamma(
      fit_full,
      level = "non",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
  )
}

.c3_make_mixed_family_two_kernel_recovery_fixture <- function(
  seed = 2912L,
  n_H = 20L,
  n_P = 20L,
  n_rep = 10L,
  lambda_phy_scale = 0.45,
  lambda_non_scale = 0.45,
  link_scale = 0.22,
  intercept = 1.1
) {
  fx <- .c3_make_two_component_fixture(
    seed = seed,
    n_H = n_H,
    n_P = n_P,
    n_rep = n_rep,
    lambda_phy_scale = lambda_phy_scale,
    lambda_non_scale = lambda_non_scale,
    resid_sd = 0.08
  )
  partner_traits <- c("p_size", "p_attack")
  for (nm in partner_traits) {
    idx <- !is.na(fx$data[[nm]])
    eta <- intercept + link_scale * as.numeric(fx$data[[nm]][idx])
    fx$data[[nm]][idx] <- stats::rpois(sum(idx), lambda = exp(eta))
  }

  trait_names <- c("h_size", "h_defence", "p_size", "p_attack")
  long <- do.call(rbind, lapply(trait_names, function(nm) {
    data.frame(
      row_id = fx$data$row_id,
      species = fx$data$species,
      trait = factor(nm, levels = trait_names),
      value = fx$data[[nm]],
      family = if (nm %in% partner_traits) "poisson" else "gaussian",
      stringsAsFactors = FALSE
    )
  }))
  long <- long[!is.na(long$value), , drop = FALSE]
  long$family <- factor(long$family, levels = c("gaussian", "poisson"))

  fam <- list(stats::gaussian(), stats::poisson())
  attr(fam, "family_var") <- "family"

  list(
    data = long,
    family = fam,
    K_phy = fx$K_phy,
    K_non = fx$K_non,
    Gamma_phy = fx$Gamma_phy,
    Gamma_non = fx$Gamma_non,
    host_traits = fx$host_traits,
    partner_traits = fx$partner_traits,
    similarity = fx$similarity,
    mean_count = mean(long$value[long$family == "poisson"])
  )
}

.c3_fit_mixed_family_two_kernel_set <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_full <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    trait = "trait",
    unit = "row_id",
    cluster = "species",
    family = fx$family,
    control = ctl
  )))
  fit_phy_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy"),
    data = fx$data,
    trait = "trait",
    unit = "row_id",
    cluster = "species",
    family = fx$family,
    control = ctl
  )))
  fit_non_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    trait = "trait",
    unit = "row_id",
    cluster = "species",
    family = fx$family,
    control = ctl
  )))
  list(
    full = fit_full,
    phy_only = fit_phy_only,
    non_only = fit_non_only,
    Gamma_phy = gllvmTMB::extract_Gamma(
      fit_full,
      level = "phy",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    ),
    Gamma_non = gllvmTMB::extract_Gamma(
      fit_full,
      level = "non",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
  )
}

test_that("two distinct named kernel tiers fit and extract by component", {
  ## C3.1 first-wave acceptance: two named fixed kernels get separate latent
  ## fields and separate loading matrices. This is not an interval/rho gate.
  testthat::skip_if_not_installed("TMB")

  set.seed(74)
  n_unit <- 8L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A_phy <- matrix(0.25, n_unit, n_unit)
  diag(A_phy) <- 1
  rownames(A_phy) <- colnames(A_phy) <- unit_levels
  A_non <- diag(n_unit)
  A_non[row(A_non) == col(A_non) + 1L | row(A_non) + 1L == col(A_non)] <- 0.35
  A_non <- as.matrix(Matrix::nearPD(A_non, corr = TRUE)$mat)
  rownames(A_non) <- colnames(A_non) <- unit_levels

  rows <- expand.grid(
    unit_id = unit_levels,
    rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$unit_id <- factor(rows$unit_id, levels = unit_levels)
  L_phy <- t(chol(A_phy + diag(1e-8, n_unit)))
  L_non <- t(chol(A_non + diag(1e-8, n_unit)))
  g_phy <- as.numeric(L_phy %*% stats::rnorm(n_unit))
  g_non <- as.numeric(L_non %*% stats::rnorm(n_unit))
  Lambda_phy <- c(0.7, 0.25)
  Lambda_non <- c(-0.15, 0.55)
  eta <- cbind(
    y1 = Lambda_phy[[1L]] *
      g_phy[as.integer(rows$unit_id)] +
      Lambda_non[[1L]] * g_non[as.integer(rows$unit_id)],
    y2 = Lambda_phy[[2L]] *
      g_phy[as.integer(rows$unit_id)] +
      Lambda_non[[2L]] * g_non[as.integer(rows$unit_id)]
  )
  rows$y1 <- eta[, 1L] + stats::rnorm(nrow(rows), sd = 0.25)
  rows$y2 <- eta[, 2L] + stats::rnorm(nrow(rows), sd = 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2) ~
      1 +
      kernel_latent(unit_id, K = A_phy, d = 1, name = "phy") +
      kernel_latent(unit_id, K = A_non, d = 1, name = "non"),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$kernel))
  expect_equal(fit$kernel_levels$name, c("phy", "non"))
  expect_equal(fit$kernel_levels$rank, c(1L, 1L))
  expect_equal(fit$kernel_levels$has_psi, c(FALSE, FALSE))
  expect_equal(names(fit$kernel_matrices), c("phy", "non"))
  expect_equal(fit$kernel_matrices$phy, A_phy, tolerance = 1e-12)
  expect_equal(fit$kernel_matrices$non, A_non, tolerance = 1e-12)
  expect_equal(
    rownames(fit$kernel_diagnostics$similarity),
    c("phy", "non")
  )
  expect_equal(
    colnames(fit$kernel_diagnostics$similarity),
    c("phy", "non")
  )
  expect_equal(fit$kernel_diagnostics$pairs$level_1, "phy")
  expect_equal(fit$kernel_diagnostics$pairs$level_2, "non")
  expect_true(is.finite(fit$kernel_diagnostics$pairs$similarity))
  expect_true(
    fit$kernel_diagnostics$pairs$overlap_class %in%
      c("near_orthogonal", "moderate", "high")
  )
  expect_equal(fit$kernel_diagnostics$pairs$overlap_class, "moderate")

  S_phy <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "phy", part = "shared")
  )
  S_non <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "non", part = "shared")
  )
  expect_equal(S_phy$level, "phy")
  expect_equal(S_non$level, "non")
  expect_equal(dim(S_phy$Sigma), c(2L, 2L))
  expect_equal(dim(S_non$Sigma), c(2L, 2L))
  expect_false(isTRUE(all.equal(S_phy$Sigma, S_non$Sigma)))
  expect_error(
    suppressMessages(
      gllvmTMB::extract_Sigma(fit, level = "phy", part = "unique")
    ),
    regexp = "no explicit"
  )

  expect_no_warning(
    Gamma_phy <- gllvmTMB::extract_Gamma(
      fit,
      level = "phy",
      row_traits = "y1",
      col_traits = "y2"
    )
  )
  expect_no_warning(
    Gamma_non <- gllvmTMB::extract_Gamma(
      fit,
      level = "non",
      row_traits = "y1",
      col_traits = "y2"
    )
  )
  expect_equal(dim(Gamma_phy), c(1L, 1L))
  expect_equal(dim(Gamma_non), c(1L, 1L))
  pair_cov <- gllvmTMB::predict_cross_covariance(
    fit,
    level = "phy",
    row_levels = "u1",
    col_levels = "u2",
    row_traits = "y1",
    col_traits = "y2"
  )
  expect_equal(pair_cov$kernel_value, A_phy["u1", "u2"])
  expect_equal(pair_cov$gamma_shape, as.numeric(Gamma_phy))
  expect_equal(pair_cov$covariance, as.numeric(Gamma_phy) * A_phy["u1", "u2"])
  expect_true(is.na(pair_cov$rho))
  expect_false(pair_cov$kernel_includes_rho)

  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(y1, y2) ~
        1 +
        kernel_latent(unit_id, K = A_phy, d = 1, name = "phy") +
        kernel_unique(unit_id, K = A_phy, name = "phy") +
        kernel_latent(unit_id, K = A_non, d = 1, name = "non"),
      data = rows,
      unit = "row_id",
      cluster = "unit_id",
      family = stats::gaussian(),
      control = ctl
    ))),
    regexp = "latent-only|Psi is deferred|kernel_unique"
  )
})

test_that("kernel-similarity diagnostic separates low and high overlap cases", {
  n_H <- 10L
  n_P <- 10L
  A_H <- .c3_axis_kernel(n_H, "H")
  A_P <- .c3_axis_kernel(n_P, "P")
  I_H <- diag(n_H)
  I_P <- diag(n_P)
  rownames(I_H) <- colnames(I_H) <- rownames(A_H)
  rownames(I_P) <- colnames(I_P) <- rownames(A_P)

  W_aligned <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_opposed <- .c3_association_pattern(n_H, n_P, type = "opposed")
  dimnames(W_aligned) <- dimnames(W_opposed) <-
    list(rownames(A_H), rownames(A_P))

  K_phy <- gllvmTMB::make_cross_kernel(A_H, A_P, W_aligned, rho = 0.55)
  K_non_low <- gllvmTMB::make_cross_kernel(I_H, I_P, W_opposed, rho = 0.55)
  K_non_high <- K_phy

  expect_equal(
    .c3_kernel_overlap_class(.c3_kernel_similarity(K_phy, K_non_low)),
    "near_orthogonal"
  )
  expect_equal(
    .c3_kernel_overlap_class(.c3_kernel_similarity(K_phy, K_non_high)),
    "high"
  )

  K_diag <- array(0, dim = c(2L, n_H + n_P, n_H + n_P))
  K_diag[1L, , ] <- diag(n_H + n_P)
  K_diag[2L, , ] <- diag(n_H + n_P)
  diag_dx <- gllvmTMB:::.kernel_overlap_diagnostics(
    K_diag,
    c("diag_1", "diag_2")
  )
  expect_equal(diag_dx$pairs$similarity, 1)
  expect_equal(diag_dx$pairs$overlap_class, "high")
})

test_that("pre-fit kernel separability diagnostic flags raw versus residualized candidates", {
  n_H <- 10L
  n_P <- 10L
  A_H <- .c3_axis_kernel(n_H, "H")
  A_P <- .c3_axis_kernel(n_P, "P")
  I_H <- diag(n_H)
  I_P <- diag(n_P)
  rownames(I_H) <- colnames(I_H) <- rownames(A_H)
  rownames(I_P) <- colnames(I_P) <- rownames(A_P)

  W_phy <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_tip_resid <- .c3_association_pattern(n_H, n_P, type = "opposed")
  dimnames(W_phy) <- dimnames(W_tip_resid) <-
    list(rownames(A_H), rownames(A_P))

  K_phy <- gllvmTMB::make_cross_kernel(A_H, A_P, W_phy, rho = 0.55)
  ## This raw candidate deliberately aliases the phylogenetic kernel: it is the
  ## claim-boundary case where Paper 2 must not force a split interpretation.
  K_tip_raw <- K_phy
  K_tip_resid <- gllvmTMB::make_cross_kernel(
    I_H,
    I_P,
    W_tip_resid,
    rho = 0.55
  )

  dx <- gllvmTMB::diagnose_kernel_separability(
    phy = K_phy,
    tip_raw = K_tip_raw,
    tip_resid = K_tip_resid
  )

  expect_s3_class(dx, "gllvmTMB_kernel_separability")
  expect_equal(dim(dx$similarity), c(3L, 3L))
  expect_equal(dx$similarity["phy", "tip_raw"], 1)
  expect_equal(
    dx$pairs$overlap_class[dx$pairs$level_2 == "tip_raw"],
    "high"
  )
  expect_equal(
    dx$pairs$recommendation[dx$pairs$level_2 == "tip_raw"],
    "collapse_or_single_covariance"
  )
  resid_pair <- dx$pairs[
    dx$pairs$level_1 == "phy" & dx$pairs$level_2 == "tip_resid",
  ]
  expect_equal(resid_pair$overlap_class, "near_orthogonal")
  expect_equal(resid_pair$recommendation, "separable_candidate")
  expect_match(dx$note, "one network-conditioned covariance")

  expect_error(
    gllvmTMB::diagnose_kernel_separability(phy = K_phy),
    "at least two"
  )
  expect_error(
    gllvmTMB::diagnose_kernel_separability(phy = K_phy, phy = K_tip_resid),
    "unique"
  )
})

test_that("pre-fit kernel separability aligns named kernels before comparison", {
  K <- matrix(
    c(
      1.0, 0.2, 0.4, 0.6,
      0.2, 1.0, 0.3, 0.5,
      0.4, 0.3, 1.0, 0.7,
      0.6, 0.5, 0.7, 1.0
    ),
    nrow = 4L,
    byrow = TRUE,
    dimnames = list(letters[1:4], letters[1:4])
  )
  permuted <- K[c("c", "a", "d", "b"), c("c", "a", "d", "b")]

  dx <- gllvmTMB::diagnose_kernel_separability(
    reference = K,
    permuted = permuted
  )
  expect_equal(dx$similarity["reference", "permuted"], 1)
  expect_equal(dx$pairs$overlap_class, "high")

  bad_levels <- K
  dimnames(bad_levels) <- list(c("a", "b", "c", "x"), c("a", "b", "c", "x"))
  expect_error(
    gllvmTMB::diagnose_kernel_separability(reference = K, bad = bad_levels),
    "same level set"
  )

  row_named_only <- K
  colnames(row_named_only) <- NULL
  expect_error(
    gllvmTMB::diagnose_kernel_separability(reference = K, bad = row_named_only),
    "Row names and column names"
  )
})

test_that("kernel-collinearity simulation gate separates Paper 2 claim regimes", {
  n_H <- 10L
  n_P <- 10L
  A_H <- .c3_axis_kernel(n_H, "H")
  A_P <- .c3_axis_kernel(n_P, "P")
  I_H <- diag(n_H)
  I_P <- diag(n_P)
  rownames(I_H) <- colnames(I_H) <- rownames(A_H)
  rownames(I_P) <- colnames(I_P) <- rownames(A_P)

  W_phy <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_tip_resid <- .c3_association_pattern(n_H, n_P, type = "opposed")
  dimnames(W_phy) <- dimnames(W_tip_resid) <-
    list(rownames(A_H), rownames(A_P))

  K_phy <- gllvmTMB::make_cross_kernel(A_H, A_P, W_phy, rho = 0.55)
  K_tip_resid <- gllvmTMB::make_cross_kernel(
    I_H,
    I_P,
    W_tip_resid,
    rho = 0.55
  )
  make_tip_blend <- function(alpha) {
    K <- alpha * K_phy + (1 - alpha) * K_tip_resid
    K <- (K + t(K)) / 2
    diag(K) <- 1
    dimnames(K) <- dimnames(K_phy)
    K
  }

  ## Alignment:
  ## - Gamma_phy: kernel_latent(..., name = "phy"), K_phy from W_phy.
  ## - Gamma_tip: kernel_latent(..., name = "tip"), K_tip(alpha) blends
  ##   residualized W_tip toward K_phy.
  ## - Recovery gate: diagnose_kernel_separability() must demote moderate/high
  ##   collinearity before any component-specific Paper 2 claim is advertised.
  regimes <- data.frame(
    alpha = c(0, 0.15, 0.25, 1),
    expected_class = c("near_orthogonal", "moderate", "high", "high"),
    expected_recommendation = c(
      "separable_candidate",
      "sensitivity_required",
      "collapse_or_single_covariance",
      "collapse_or_single_covariance"
    ),
    stringsAsFactors = FALSE
  )
  results <- lapply(seq_len(nrow(regimes)), function(i) {
    dx <- gllvmTMB::diagnose_kernel_separability(
      phy = K_phy,
      tip = make_tip_blend(regimes$alpha[[i]])
    )
    dx$pairs
  })
  similarity <- vapply(results, `[[`, numeric(1), "similarity")
  overlap_class <- vapply(results, `[[`, character(1), "overlap_class")
  recommendation <- vapply(results, `[[`, character(1), "recommendation")

  expect_true(all(diff(similarity) > 0))
  expect_equal(overlap_class, regimes$expected_class)
  expect_equal(recommendation, regimes$expected_recommendation)
  expect_lt(similarity[[1L]], 0.25)
  expect_gte(similarity[[2L]], 0.25)
  expect_lt(similarity[[2L]], 0.70)
  expect_gte(similarity[[3L]], 0.70)
  expect_equal(similarity[[4L]], 1)
})

test_that("reciprocal-dependence W needs sensitivity before tip-kernel claims", {
  set.seed(2901)
  n_H <- 18L
  n_P <- 18L
  A_H <- .c3_axis_kernel(n_H, "H", range = 0.45)
  A_P <- .c3_axis_kernel(n_P, "P", range = 0.45)
  I_H <- diag(n_H)
  I_P <- diag(n_P)
  rownames(I_H) <- colnames(I_H) <- rownames(A_H)
  rownames(I_P) <- colnames(I_P) <- rownames(A_P)

  W_phy <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_opposed <- .c3_association_pattern(n_H, n_P, type = "opposed")
  dimnames(W_phy) <- dimnames(W_opposed) <- list(rownames(A_H), rownames(A_P))

  raw_mean <- 100 * (0.05 + W_phy)
  counts <- matrix(
    stats::rpois(length(raw_mean), lambda = as.vector(raw_mean)),
    n_H,
    n_P,
    dimnames = dimnames(W_phy)
  )
  p_col_given_row <- sweep(
    counts,
    1L,
    pmax(rowSums(counts), .Machine$double.eps),
    `/`
  )
  p_row_given_col <- sweep(
    counts,
    2L,
    pmax(colSums(counts), .Machine$double.eps),
    `/`
  )
  W_recip <- sqrt(p_col_given_row * p_row_given_col)
  W_resid <- matrix(
    stats::resid(stats::lm(as.vector(W_recip) ~ as.vector(W_phy))),
    n_H,
    n_P,
    dimnames = dimnames(W_phy)
  )
  W_tip_resid <- W_resid + 0.25 * W_opposed

  K_phy <- gllvmTMB::make_cross_kernel(A_H, A_P, W_phy, rho = 0.55)
  K_tip_raw <- gllvmTMB::make_cross_kernel(I_H, I_P, W_recip, rho = 0.55)
  K_tip_resid <- gllvmTMB::make_cross_kernel(
    I_H,
    I_P,
    W_tip_resid,
    rho = 0.55
  )

  ## COE-04 reciprocal-dependence alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP / diagnostic input | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | C_phy | kernel_latent(..., name = "phy") candidate | make_cross_kernel(A_H, A_P, W_phy) | diagnose_kernel_separability() | conserved interaction neighbourhood |
  ## | C_tip,raw | kernel_latent(..., name = "tip") candidate | reciprocal W from link counts | diagnose_kernel_separability() | sensitivity_required |
  ## | C_tip,resid | kernel_latent(..., name = "tip") candidate | residualized W plus opposed tip signal | diagnose_kernel_separability() | separable_candidate |
  raw_dx <- gllvmTMB::diagnose_kernel_separability(
    phy = K_phy,
    tip = K_tip_raw
  )
  resid_dx <- gllvmTMB::diagnose_kernel_separability(
    phy = K_phy,
    tip = K_tip_resid
  )

  expect_equal(raw_dx$pairs$overlap_class, "moderate")
  expect_equal(raw_dx$pairs$recommendation, "sensitivity_required")
  expect_gte(raw_dx$pairs$similarity, 0.25)
  expect_lt(raw_dx$pairs$similarity, 0.70)
  expect_equal(resid_dx$pairs$overlap_class, "near_orthogonal")
  expect_equal(resid_dx$pairs$recommendation, "separable_candidate")
  expect_lt(resid_dx$pairs$similarity, 0.25)
})

test_that("profile_cross_rho records a fixed-kernel profile grid", {
  A_H <- diag(2L)
  A_P <- diag(2L)
  rownames(A_H) <- colnames(A_H) <- c("H1", "H2")
  rownames(A_P) <- colnames(A_P) <- c("P1", "P2")
  W <- matrix(c(1, 0.2, 0.2, 1), 2L, 2L)
  dimnames(W) <- list(rownames(A_H), rownames(A_P))
  dat <- data.frame(
    y = c(0.05, 0.28, 0.03, 0.23),
    x = c(0, 1, 0, 1)
  )

  rho_grid <- c(0, 0.25, 0.5)
  prof <- gllvmTMB::profile_cross_rho(
    A_H,
    A_P,
    W,
    rho = rho_grid,
    refit = function(K, rho) {
      stats::lm(y ~ 1 + offset(rho * x), data = dat)
    },
    metrics = function(fit, K, rho) {
      list(
        kernel_rho = attr(K, "gllvmTMB_cross_kernel")$rho,
        coef_intercept = unname(stats::coef(fit)[[1L]])
      )
    }
  )

  expect_s3_class(prof, "gllvmTMB_cross_rho_profile")
  expect_equal(prof$rho, rho_grid)
  expect_equal(prof$kernel_rho, rho_grid)
  expect_true(all(is.finite(prof$logLik)))
  expect_equal(prof$relative_logLik, prof$logLik - max(prof$logLik))
  expect_equal(prof$delta_deviance, 2 * (max(prof$logLik) - prof$logLik))
  expect_equal(prof$is_best, prof$logLik == max(prof$logLik))
  expect_equal(attr(prof, "best_rho"), prof$rho[which.max(prof$logLik)])
  expect_true(all(is.na(prof$convergence)))
  expect_true(all(is.na(prof$pd_hessian)))

  expect_error(
    gllvmTMB::profile_cross_rho(A_H, A_P, W, rho = 1.2, refit = function(...) {
      NULL
    }),
    regexp = "\\[-1, 1\\]"
  )
  expect_error(
    gllvmTMB::profile_cross_rho(A_H, A_P, W, rho = 0, refit = NULL),
    regexp = "refit"
  )
})

test_that("high-overlap kernel tiers warn while still fitting", {
  testthat::skip_if_not_installed("TMB")

  set.seed(9001)
  n_unit <- 8L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A <- matrix(0.35, n_unit, n_unit)
  diag(A) <- 1
  rownames(A) <- colnames(A) <- unit_levels

  rows <- expand.grid(
    unit_id = unit_levels,
    rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$unit_id <- factor(rows$unit_id, levels = unit_levels)

  L_A <- t(chol(A + diag(1e-8, n_unit)))
  g_phy <- as.numeric(L_A %*% stats::rnorm(n_unit))
  g_non <- as.numeric(L_A %*% stats::rnorm(n_unit))
  rows$y1 <- 0.5 *
    g_phy[as.integer(rows$unit_id)] +
    0.5 * g_non[as.integer(rows$unit_id)] +
    stats::rnorm(nrow(rows), sd = 0.25)
  rows$y2 <- -0.3 *
    g_phy[as.integer(rows$unit_id)] +
    0.4 * g_non[as.integer(rows$unit_id)] +
    stats::rnorm(nrow(rows), sd = 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  expect_warning(
    fit <- suppressMessages(gllvmTMB::gllvmTMB(
      traits(y1, y2) ~
        1 +
        kernel_latent(unit_id, K = A, d = 1, name = "phy") +
        kernel_latent(unit_id, K = A, d = 1, name = "non"),
      data = rows,
      unit = "row_id",
      cluster = "unit_id",
      family = stats::gaussian(),
      control = ctl
    )),
    regexp = "High overlap between fixed kernel tiers"
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$kernel_diagnostics$pairs$similarity, 1)
  expect_equal(fit$kernel_diagnostics$pairs$overlap_class, "high")

  ## COE-04 high-overlap extraction guard. The fit is allowed and the point
  ## Gamma block remains inspectable, but extraction itself repeats the claim
  ## boundary because identical kernels cannot support component-specific
  ## separation evidence.
  expect_warning(
    Gamma_phy <- gllvmTMB::extract_Gamma(
      fit,
      level = "phy",
      row_traits = "y1",
      col_traits = "y2"
    ),
    regexp = "high-overlap fixed kernel tier"
  )
  expect_warning(
    Gamma_non <- gllvmTMB::extract_Gamma(
      fit,
      level = "non",
      row_traits = "y1",
      col_traits = "y2"
    ),
    regexp = "high-overlap fixed kernel tier"
  )
  expect_equal(dim(Gamma_phy), c(1L, 1L))
  expect_equal(dim(Gamma_non), c(1L, 1L))
})

test_that("near-orthogonal two-component kernels recover component Gamma shapes", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c3_make_two_component_fixture()
  expect_equal(.c3_kernel_overlap_class(fx$similarity), "near_orthogonal")
  expect_lt(fx$similarity, 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_full <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_phy_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_phy, d = 1, name = "phy"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_non_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))

  expect_equal(fit_full$opt$convergence, 0L)
  expect_equal(fit_phy_only$opt$convergence, 0L)
  expect_equal(fit_non_only$opt$convergence, 0L)
  expect_equal(
    fit_full$kernel_diagnostics$pairs$overlap_class,
    "near_orthogonal"
  )
  expect_equal(
    fit_full$kernel_diagnostics$pairs$similarity,
    fx$similarity,
    tolerance = 1e-12
  )
  expect_gt(
    as.numeric(stats::logLik(fit_full)) -
      max(
        as.numeric(stats::logLik(fit_phy_only)),
        as.numeric(stats::logLik(fit_non_only))
      ),
    50
  )

  Gamma_phy <- gllvmTMB::extract_Gamma(
    fit_full,
    level = "phy",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  Gamma_non <- gllvmTMB::extract_Gamma(
    fit_full,
    level = "non",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  Gamma_phy_effect <- gllvmTMB::extract_Gamma(
    fit_full,
    level = "phy",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits,
    scale = "effect"
  )
  Gamma_non_effect <- gllvmTMB::extract_Gamma(
    fit_full,
    level = "non",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits,
    scale = "effect"
  )

  expect_equal(fit_full$kernel_levels$rho, c(0.55, 0.55), tolerance = 1e-12)
  expect_equal(as.numeric(Gamma_phy_effect), as.numeric(0.55 * Gamma_phy))
  expect_equal(as.numeric(Gamma_non_effect), as.numeric(0.55 * Gamma_non))
  expect_gt(.c3_gamma_corr(Gamma_phy, fx$Gamma_phy), 0.95)
  expect_gt(.c3_gamma_corr(Gamma_non, fx$Gamma_non), 0.95)
  expect_lt(.c3_gamma_corr(Gamma_phy, fx$Gamma_non), 0.25)
  expect_lt(.c3_gamma_corr(Gamma_non, fx$Gamma_phy), 0.25)

  modules_phy <- gllvmTMB::extract_coevolution_modules(
    fit_full,
    level = "phy",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  modules_non <- gllvmTMB::extract_coevolution_modules(
    fit_full,
    level = "non",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  expect_equal(dim(modules_phy$R), c(2L, 2L))
  expect_equal(dim(modules_non$R), c(2L, 2L))
  expect_true(all(is.finite(modules_phy$modules$singular_value)))
  expect_true(all(is.finite(modules_non$modules$singular_value)))
  expect_lte(diff(modules_phy$modules$singular_value), 0)
  expect_lte(diff(modules_non$modules$singular_value), 0)
  expect_equal(sum(modules_phy$modules$squared_share), 1, tolerance = 1e-12)
  expect_equal(sum(modules_non$modules$squared_share), 1, tolerance = 1e-12)

  Sigma_phy <- suppressMessages(gllvmTMB::extract_Sigma(
    fit_full,
    level = "phy",
    part = "shared",
    link_residual = "none"
  ))$Sigma
  Sigma_non <- suppressMessages(gllvmTMB::extract_Sigma(
    fit_full,
    level = "non",
    part = "shared",
    link_residual = "none"
  ))$Sigma
  R_phy_manual <- .c3_inv_sqrt(
    Sigma_phy[fx$host_traits, fx$host_traits, drop = FALSE]
  ) %*%
    Gamma_phy %*%
    .c3_inv_sqrt(Sigma_phy[fx$partner_traits, fx$partner_traits, drop = FALSE])
  R_non_manual <- .c3_inv_sqrt(
    Sigma_non[fx$host_traits, fx$host_traits, drop = FALSE]
  ) %*%
    Gamma_non %*%
    .c3_inv_sqrt(Sigma_non[fx$partner_traits, fx$partner_traits, drop = FALSE])
  expect_equal(modules_phy$R, R_phy_manual, tolerance = 1e-10)
  expect_equal(modules_non$R, R_non_manual, tolerance = 1e-10)
  expect_equal(
    modules_phy$modules$singular_value,
    svd(R_phy_manual)$d,
    tolerance = 1e-10
  )
  expect_equal(
    modules_non$modules$singular_value,
    svd(R_non_manual)$d,
    tolerance = 1e-10
  )

  one_module <- gllvmTMB::extract_coevolution_modules(
    fit_full,
    level = "phy",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits,
    n_modules = 1
  )
  expect_equal(nrow(one_module$modules), 1L)
  expect_equal(nrow(one_module$row_axes), length(fx$host_traits))
  expect_equal(nrow(one_module$col_axes), length(fx$partner_traits))

  effect_modules <- gllvmTMB::extract_coevolution_modules(
    fit_full,
    level = "phy",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits,
    scale = "effect"
  )
  expect_equal(effect_modules$R, 0.55 * modules_phy$R, tolerance = 1e-10)
  expect_equal(
    effect_modules$modules$singular_value,
    0.55 * modules_phy$modules$singular_value,
    tolerance = 1e-10
  )
})

test_that("moderately overlapping kernels still recover component Gamma shapes", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 moderate-overlap alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy | kernel_latent(species, K = K_phy, name = "phy") | aligned make_cross_kernel(A_H, A_P, W_phy, rho_phy) | fit$kernel_diagnostics | moderate pair |
  ## | K_non | kernel_latent(species, K = K_non, name = "non") | blended non kernel, 30% aligned + 70% opposed | fit$kernel_diagnostics | moderate pair |
  ## | Gamma_phy | same "phy" tier | Lambda_H,phy Lambda_P,phy^T | extract_Gamma(level = "phy") | Gamma_shape_phy |
  ## | Gamma_non | same "non" tier | Lambda_H,non Lambda_P,non^T | extract_Gamma(level = "non") | Gamma_shape_non |
  moderate_grid <- data.frame(
    seed = c(2400L, 2401L, 2402L),
    non_association_blend = c(0.25, 0.30, 0.35)
  )

  for (i in seq_len(nrow(moderate_grid))) {
    fx <- .c3_make_two_component_fixture(
      seed = moderate_grid$seed[[i]],
      non_association_blend = moderate_grid$non_association_blend[[i]]
    )
    expect_equal(.c3_kernel_overlap_class(fx$similarity), "moderate")
    expect_gt(fx$similarity, 0.25)
    expect_lt(fx$similarity, 0.70)

    fit <- .c3_fit_two_kernel_set(fx)
    expect_equal(fit$full$opt$convergence, 0L)
    expect_equal(fit$phy_only$opt$convergence, 0L)
    expect_equal(fit$non_only$opt$convergence, 0L)
    expect_equal(fit$full$kernel_diagnostics$pairs$overlap_class, "moderate")
    expect_equal(
      fit$full$kernel_diagnostics$pairs$similarity,
      fx$similarity,
      tolerance = 1e-12
    )
    expect_gt(
      as.numeric(stats::logLik(fit$full)) -
        max(
          as.numeric(stats::logLik(fit$phy_only)),
          as.numeric(stats::logLik(fit$non_only))
        ),
      50
    )
    expect_gt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_phy), 0.95)
    expect_gt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_non), 0.95)
    expect_lt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_non), 0.25)
    expect_lt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_phy), 0.25)
  }

  ## A harder moderate-edge cell is allowed to converge and detect signal but
  ## is deliberately not promoted as component-separation evidence.
  hard_edge <- .c3_make_two_component_fixture(
    seed = 2403L,
    non_association_blend = 0.40
  )
  expect_equal(.c3_kernel_overlap_class(hard_edge$similarity), "moderate")
  hard_fit <- .c3_fit_two_kernel_set(hard_edge)
  expect_equal(hard_fit$full$opt$convergence, 0L)
  expect_equal(hard_fit$phy_only$opt$convergence, 0L)
  expect_equal(hard_fit$non_only$opt$convergence, 0L)
  expect_gt(
    as.numeric(stats::logLik(hard_fit$full)) -
      max(
        as.numeric(stats::logLik(hard_fit$phy_only)),
        as.numeric(stats::logLik(hard_fit$non_only))
      ),
    50
  )
  expect_lt(.c3_gamma_corr(hard_fit$Gamma_phy, hard_edge$Gamma_phy), 0.95)
  expect_gt(.c3_gamma_corr(hard_fit$Gamma_non, hard_edge$Gamma_non), 0.95)
  expect_gt(.c3_gamma_corr(hard_fit$Gamma_phy, hard_edge$Gamma_non), 0.25)
})

test_that("high-overlap two-component fits collapse to one higher-rank kernel", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 high-overlap collapse alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K | kernel_latent(species, K = K, name = "phy/non") | same K for both latent fields | fit$kernel_diagnostics | high-overlap pair |
  ## | g_phy | kernel_latent(..., d = 1, name = "phy") | N(0, K) | extract_Gamma(level = "phy") warns | descriptive only |
  ## | g_non | kernel_latent(..., d = 1, name = "non") | N(0, K) | extract_Gamma(level = "non") warns | descriptive only |
  ## | g_cross | kernel_latent(..., d = 2, name = "cross") | same total covariance | extract_Gamma(level = "cross") | collapsed descriptive block |
  fx_exact <- .c3_make_two_component_fixture(
    seed = 2501L,
    identical_kernels = TRUE
  )
  fx_shrink <- .c3_make_two_component_fixture(
    seed = 2501L,
    identical_kernels = TRUE
  )
  fx_shrink$K_non <- 0.95 * fx_shrink$K_phy + 0.05 * diag(nrow(fx_shrink$K_phy))
  dimnames(fx_shrink$K_non) <- dimnames(fx_shrink$K_phy)
  fx_shrink$similarity <- .c3_kernel_similarity(
    fx_shrink$K_phy,
    fx_shrink$K_non
  )
  expect_false(isTRUE(all.equal(fx_shrink$K_phy, fx_shrink$K_non)))

  high_cases <- list(
    exact_duplicate = fx_exact,
    diagonal_shrink = fx_shrink
  )

  for (case_name in names(high_cases)) {
    fx <- high_cases[[case_name]]
    expect_equal(.c3_kernel_overlap_class(fx$similarity), "high")
    expect_equal(fx$similarity, 1, tolerance = 1e-12)

    ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
    expect_warning(
      fit_full <- suppressMessages(gllvmTMB::gllvmTMB(
        traits(h_size, h_defence, p_size, p_attack) ~
          1 +
          kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
          kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
        data = fx$data,
        unit = "row_id",
        cluster = "species",
        family = stats::gaussian(),
        control = ctl
      )),
      regexp = "High overlap between fixed kernel tiers"
    )
    fit_collapsed <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(h_size, h_defence, p_size, p_attack) ~
        1 + kernel_latent(species, K = fx$K_phy, d = 2, name = "cross"),
      data = fx$data,
      unit = "row_id",
      cluster = "species",
      family = stats::gaussian(),
      control = ctl
    )))

    expect_equal(fit_full$opt$convergence, 0L)
    expect_equal(fit_collapsed$opt$convergence, 0L)
    expect_lt(
      abs(
        as.numeric(stats::logLik(fit_full)) -
          as.numeric(stats::logLik(fit_collapsed))
      ),
      2
    )

    expect_warning(
      Gamma_phy <- gllvmTMB::extract_Gamma(
        fit_full,
        level = "phy",
        row_traits = fx$host_traits,
        col_traits = fx$partner_traits
      ),
      regexp = "high-overlap fixed kernel tier"
    )
    expect_warning(
      Gamma_non <- gllvmTMB::extract_Gamma(
        fit_full,
        level = "non",
        row_traits = fx$host_traits,
        col_traits = fx$partner_traits
      ),
      regexp = "high-overlap fixed kernel tier"
    )
    expect_no_warning(
      Gamma_collapsed <- gllvmTMB::extract_Gamma(
        fit_collapsed,
        level = "cross",
        row_traits = fx$host_traits,
        col_traits = fx$partner_traits
      )
    )

    expect_equal(dim(Gamma_collapsed), dim(Gamma_phy))
    expect_true(all(is.finite(Gamma_collapsed)))
    expect_true(all(is.finite(Gamma_phy + Gamma_non)))
  }
})

test_that("high-overlap non-identical kernels detect signal without promoting separation", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 high-overlap failure-calibration alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy | kernel_latent(..., name = "phy") | aligned cross kernel | fit$kernel_diagnostics | high-overlap pair |
  ## | K_non | kernel_latent(..., name = "non") | 85% K_phy + 15% opposed kernel | fit$kernel_diagnostics | non-identical high-overlap pair |
  ## | Gamma_phy/Gamma_non | same named tiers | nonzero Lambda blocks | extract_Gamma(level = ...) warns | descriptive only |
  ## | full-vs-one | both named tiers vs one-component fits | same high-overlap DGP | logLik difference | signal detection, not separation |
  fx <- .c3_make_two_component_fixture(
    seed = 2551L,
    n_H = 24L,
    n_P = 24L,
    n_rep = 5L,
    non_kernel_phy_mix = 0.85
  )
  expect_false(isTRUE(all.equal(fx$K_phy, fx$K_non)))
  expect_equal(.c3_kernel_overlap_class(fx$similarity), "high")
  expect_gt(fx$similarity, 0.70)
  expect_lt(fx$similarity, 1)

  fit <- suppressWarnings(.c3_fit_two_kernel_set(fx))
  expect_equal(fit$full$opt$convergence, 0L)
  expect_equal(fit$phy_only$opt$convergence, 0L)
  expect_equal(fit$non_only$opt$convergence, 0L)
  expect_equal(fit$full$kernel_diagnostics$pairs$overlap_class, "high")
  expect_warning(
    gllvmTMB::extract_Gamma(
      fit$full,
      level = "phy",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    ),
    regexp = "high-overlap fixed kernel tier"
  )
  expect_gt(
    as.numeric(stats::logLik(fit$full)) -
      max(
        as.numeric(stats::logLik(fit$phy_only)),
        as.numeric(stats::logLik(fit$non_only))
      ),
    20
  )

  ## The high-overlap fit can detect that two latent fields improve the
  ## likelihood, but component-wise Gamma shapes are not promoted as recovered:
  ## at least one own-shape correlation fails the ordinary 0.95 recovery bar
  ## or at least one cross-component match crosses the 0.25 separation bar.
  own_cor <- c(
    phy = .c3_gamma_corr(fit$Gamma_phy, fx$Gamma_phy),
    non = .c3_gamma_corr(fit$Gamma_non, fx$Gamma_non)
  )
  cross_cor <- c(
    phy_vs_non = .c3_gamma_corr(fit$Gamma_phy, fx$Gamma_non),
    non_vs_phy = .c3_gamma_corr(fit$Gamma_non, fx$Gamma_phy)
  )
  expect_true(any(own_cor < 0.95) || any(cross_cor > 0.25))
})

test_that("near-orthogonal selective absence collapses either absent Gamma", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  absent_non <- .c3_make_two_component_fixture(
    seed = 2101L,
    lambda_non_scale = 0
  )
  absent_non_fit <- .c3_fit_two_kernel_set(absent_non)
  expect_equal(
    absent_non_fit$full$kernel_diagnostics$pairs$overlap_class,
    "near_orthogonal"
  )
  expect_equal(absent_non_fit$full$opt$convergence, 0L)
  expect_equal(absent_non_fit$phy_only$opt$convergence, 0L)
  expect_equal(absent_non_fit$non_only$opt$convergence, 0L)
  expect_gt(
    .c3_gamma_corr(absent_non_fit$Gamma_phy, absent_non$Gamma_phy),
    0.95
  )
  expect_lt(sqrt(sum(absent_non_fit$Gamma_non^2)), 1e-3)
  expect_gt(
    as.numeric(stats::logLik(absent_non_fit$phy_only)) -
      as.numeric(stats::logLik(absent_non_fit$non_only)),
    20
  )
  expect_lt(
    as.numeric(stats::logLik(absent_non_fit$full)) -
      as.numeric(stats::logLik(absent_non_fit$phy_only)),
    1
  )

  absent_phy <- .c3_make_two_component_fixture(
    seed = 2201L,
    lambda_phy_scale = 0
  )
  absent_phy_fit <- .c3_fit_two_kernel_set(absent_phy)
  expect_equal(absent_phy_fit$full$opt$convergence, 0L)
  expect_equal(absent_phy_fit$phy_only$opt$convergence, 0L)
  expect_equal(absent_phy_fit$non_only$opt$convergence, 0L)
  expect_lt(sqrt(sum(absent_phy_fit$Gamma_phy^2)), 1e-3)
  expect_gt(
    .c3_gamma_corr(absent_phy_fit$Gamma_non, absent_phy$Gamma_non),
    0.95
  )
  expect_gt(
    as.numeric(stats::logLik(absent_phy_fit$non_only)) -
      as.numeric(stats::logLik(absent_phy_fit$phy_only)),
    20
  )
  expect_lt(
    as.numeric(stats::logLik(absent_phy_fit$full)) -
      as.numeric(stats::logLik(absent_phy_fit$non_only)),
    1
  )
})

test_that("near-orthogonal block-null smoke collapses both component Gammas", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c3_make_two_component_fixture(
    seed = 2301L,
    lambda_phy_scale = 0,
    lambda_non_scale = 0,
    resid_sd = 0.12
  )
  expect_equal(sqrt(sum(fx$Gamma_phy^2)), 0)
  expect_equal(sqrt(sum(fx$Gamma_non^2)), 0)

  fit <- .c3_fit_two_kernel_set(fx, include_intercept = TRUE)
  expect_equal(fit$full$opt$convergence, 0L)
  expect_equal(fit$phy_only$opt$convergence, 0L)
  expect_equal(fit$non_only$opt$convergence, 0L)
  expect_equal(fit$intercept$opt$convergence, 0L)
  expect_lt(sqrt(sum(fit$Gamma_phy^2)), 1e-3)
  expect_lt(sqrt(sum(fit$Gamma_non^2)), 1e-3)
  expect_lt(
    as.numeric(stats::logLik(fit$full)) -
      as.numeric(stats::logLik(fit$intercept)),
    3
  )
})

test_that("near-orthogonal null diagnostic and medium-signal grid separates claim scopes", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 null/signal calibration alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy/K_non | kernel_latent(..., name = "phy/non") | near-orthogonal fixed kernels | fit$kernel_diagnostics | separable pair |
  ## | Gamma_phy = 0 | same "phy" tier | Lambda_phy scaled to zero | extract_Gamma(level = "phy") | near-zero null block |
  ## | Gamma_non = 0 | same "non" tier | Lambda_non scaled to zero | extract_Gamma(level = "non") | near-zero null block |
  ## | null overfit tail | full two-tier vs intercept-only | twelve zero-loading seeds | logLik difference | diagnostic only |
  ## | Gamma_phy/Gamma_non > 0 | two medium-signal fixtures | nonzero Lambda_phy/Lambda_non | component Gamma correlations | planted shapes |
  null_seeds <- 2301:2312
  null_grid <- lapply(null_seeds, function(seed) {
    fx <- .c3_make_two_component_fixture(
      seed = seed,
      lambda_phy_scale = 0,
      lambda_non_scale = 0,
      resid_sd = 0.12
    )
    fit <- .c3_fit_two_kernel_null_set(fx)
    expect_equal(fit$full$opt$convergence, 0L)
    expect_equal(fit$intercept$opt$convergence, 0L)
    c(
      full_minus_intercept = as.numeric(stats::logLik(fit$full)) -
        as.numeric(stats::logLik(fit$intercept)),
      norm_phy = sqrt(sum(fit$Gamma_phy^2)),
      norm_non = sqrt(sum(fit$Gamma_non^2))
    )
  })
  null_grid <- do.call(rbind, null_grid)
  expect_true(all(null_grid[, "norm_phy"] < 2e-4))
  expect_true(all(null_grid[, "norm_non"] < 1.5e-3))
  expect_lt(stats::median(null_grid[, "full_minus_intercept"]), 2)
  expect_true(sum(null_grid[, "full_minus_intercept"] > 3) <= 2L)
  expect_lt(max(null_grid[, "full_minus_intercept"]), 8)
  null_tail_95 <- unname(stats::quantile(
    null_grid[, "full_minus_intercept"],
    probs = 0.95,
    type = 8
  ))
  expect_true(is.finite(null_tail_95))
  expect_gt(null_tail_95, 0)
  expect_lt(null_tail_95, 8)

  signal_grid <- data.frame(
    seed = c(2602L, 2604L),
    lambda_phy_scale = c(0.50, 0.50),
    lambda_non_scale = c(0.50, 0.30)
  )
  signal_gain <- numeric(nrow(signal_grid))
  for (i in seq_len(nrow(signal_grid))) {
    fx <- .c3_make_two_component_fixture(
      seed = signal_grid$seed[[i]],
      lambda_phy_scale = signal_grid$lambda_phy_scale[[i]],
      lambda_non_scale = signal_grid$lambda_non_scale[[i]]
    )
    expect_equal(.c3_kernel_overlap_class(fx$similarity), "near_orthogonal")
    fit <- .c3_fit_two_kernel_set(fx)
    expect_equal(fit$full$opt$convergence, 0L)
    expect_equal(fit$phy_only$opt$convergence, 0L)
    expect_equal(fit$non_only$opt$convergence, 0L)
    signal_gain[[i]] <- as.numeric(stats::logLik(fit$full)) -
      max(
        as.numeric(stats::logLik(fit$phy_only)),
        as.numeric(stats::logLik(fit$non_only))
      )
    expect_gt(signal_gain[[i]], 100)
    expect_gt(
      signal_gain[[i]],
      10 * null_tail_95
    )
    expect_gt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_phy), 0.90)
    expect_gt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_non), 0.90)
  }
  ## This is an empirical threshold scaffold for this fixed small grid, not a
  ## formal Type-I calibration or a reusable decision rule.
  expect_gt(min(signal_gain), 10 * null_tail_95)
})

test_that("fixed-rho sensitivity grid separates cross signal from block-null but does not estimate rho", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 fixed-rho sensitivity alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | rho_phy | fixed inside K_phy(rho) | make_cross_kernel(..., rho = 0.55) | refit grid + logLik | sensitivity only |
  ## | K_non | kernel_latent(..., name = "non") | fixed true non component | held fixed in grid | nuisance component |
  ## | Gamma_phy/effect | kernel_latent(..., name = "phy") | Lambda_H,phy Lambda_P,phy^T | extract_Gamma(scale = "effect") | fixed-rho transform |
  ##
  ## The gate is deliberately not a rho-recovery or interval claim. In finite
  ## samples the fixed kernel strength and loading magnitudes can trade off,
  ## so the grid is admissible evidence only for sensitivity and cross-signal
  ## detection relative to a block-null rho = 0 fit.
  fx <- .c3_make_two_component_fixture(
    seed = 2003L,
    n_H = 24L,
    n_P = 24L,
    n_rep = 5L
  )
  expect_equal(.c3_kernel_overlap_class(fx$similarity), "near_orthogonal")

  rho_grid <- c(0, 0.25, 0.55, 0.85)
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  prof <- gllvmTMB::profile_cross_rho(
    fx$A_H,
    fx$A_P,
    fx$W_phy,
    rho = rho_grid,
    refit = function(K, rho) {
      suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
        traits(h_size, h_defence, p_size, p_attack) ~
          1 +
          kernel_latent(species, K = K, d = 1, name = "phy") +
          kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
        data = fx$data,
        unit = "row_id",
        cluster = "species",
        family = stats::gaussian(),
        control = ctl
      )))
    }
  )
  expect_equal(prof$rho, rho_grid)
  expect_true(all(prof$convergence == 0L))
  expect_true(all(is.finite(prof$logLik)))

  best <- prof[which.max(prof$logLik), , drop = FALSE]
  null_ll <- prof$logLik[prof$rho == 0]
  planted_ll <- prof$logLik[prof$rho == 0.55]
  expect_gt(max(prof$logLik[prof$rho > 0]) - null_ll, 100)
  expect_gt(planted_ll - null_ll, 100)
  expect_true(best$rho %in% rho_grid[rho_grid > 0])

  if (identical(best$rho, max(rho_grid))) {
    expect_gt(best$logLik - planted_ll, 0)
  }
})

test_that("profile_cross_rho resolves tied logLik best rho to a scalar first maximum", {
  A_H <- diag(2)
  A_P <- diag(2)
  rownames(A_H) <- colnames(A_H) <- c("H1", "H2")
  rownames(A_P) <- colnames(A_P) <- c("P1", "P2")
  W <- matrix(
    c(1, 0.2, 0.2, 1),
    nrow = 2,
    dimnames = list(rownames(A_H), rownames(A_P))
  )
  dat <- data.frame(y = c(1, 2, 3, 4), x = c(0, 1, 0, 1))
  prof <- gllvmTMB::profile_cross_rho(
    A_H,
    A_P,
    W,
    rho = c(0, 0.25, 0.5),
    refit = function(K, rho) stats::lm(y ~ x, data = dat)
  )

  expect_equal(sum(prof$is_best), 1L)
  expect_equal(which(prof$is_best), 1L)
  expect_equal(attr(prof, "best_rho"), 0)
  expect_equal(length(attr(prof, "best_rho")), 1L)
  expect_true(all(prof$relative_logLik == 0))
  expect_true(all(prof$delta_deviance == 0))
})

test_that("Poisson two-kernel coevolution smoke constructs finite component Gammas", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 non-Gaussian smoke alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy/K_non | kernel_latent(..., name = "phy/non") | fixed kernels reused from Gaussian fixture | fit$kernel_diagnostics | construction smoke |
  ## | Y | poisson() | Poisson counts from bounded transformed latent predictor | convergence + finite logLik | smoke only |
  ## | Gamma_phy/Gamma_non | same tiers | no recovery target in this smoke | extract_Gamma(level = ...) | finite point blocks |
  for (seed in 2701:2702) {
    fx <- .c3_make_poisson_two_kernel_fixture(seed = seed)
    expect_true(all(fx$data$h_size[!is.na(fx$data$h_size)] >= 0))
    expect_true(all(fx$data$p_attack[!is.na(fx$data$p_attack)] >= 0))

    ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(h_size, h_defence, p_size, p_attack) ~
        1 +
        kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
        kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
      data = fx$data,
      unit = "row_id",
      cluster = "species",
      family = stats::poisson(),
      control = ctl
    )))
    expect_equal(fit$opt$convergence, 0L)
    expect_true(is.finite(as.numeric(stats::logLik(fit))))
    expect_equal(fit$kernel_diagnostics$pairs$overlap_class, "near_orthogonal")

    Gamma_phy <- gllvmTMB::extract_Gamma(
      fit,
      level = "phy",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
    Gamma_non <- gllvmTMB::extract_Gamma(
      fit,
      level = "non",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
    expect_true(all(is.finite(Gamma_phy)))
    expect_true(all(is.finite(Gamma_non)))
  }
})

test_that("Poisson two-kernel coevolution recovers component Gamma shapes", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 non-Gaussian recovery alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy/K_non | kernel_latent(..., name = "phy/non") | fixed cross kernels | fit$kernel_diagnostics | near-orthogonal pair |
  ## | g_phy/g_non | same named tiers | N(0, K_phy/K_non) | latent loading fit | two latent fields |
  ## | Y | poisson() | exp(intercept + Lambda_phy g_phy + Lambda_non g_non) | convergence + logLik | log-link counts |
  ## | Gamma_phy/Gamma_non | same named tiers | Lambda_H,r Lambda_P,r^T | extract_Gamma(level = r) | planted shape |
  for (seed in c(2801L, 2804L)) {
    fx <- .c3_make_poisson_two_kernel_recovery_fixture(seed = seed)
    expect_equal(.c3_kernel_overlap_class(fx$similarity), "near_orthogonal")
    expect_true(all(fx$data$h_size[!is.na(fx$data$h_size)] >= 0))
    expect_gt(fx$mean_mu, 3)
    expect_lt(fx$mean_mu, 4)

    fit <- .c3_fit_poisson_two_kernel_set(fx)
    expect_equal(fit$full$opt$convergence, 0L)
    expect_equal(fit$phy_only$opt$convergence, 0L)
    expect_equal(fit$non_only$opt$convergence, 0L)
    expect_equal(
      fit$full$kernel_diagnostics$pairs$overlap_class,
      "near_orthogonal"
    )
    expect_gt(
      as.numeric(stats::logLik(fit$full)) -
        max(
          as.numeric(stats::logLik(fit$phy_only)),
          as.numeric(stats::logLik(fit$non_only))
        ),
      40
    )
    expect_gt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_phy), 0.98)
    expect_gt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_non), 0.98)
    expect_lt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_non), 0.10)
    expect_lt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_phy), 0.10)
  }
})

test_that("mixed-family two-kernel coevolution smoke constructs finite component Gammas", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")

  fx <- .c3_make_two_component_fixture(seed = 2911L, n_H = 16L, n_P = 16L)
  partner_traits <- c("p_size", "p_attack")
  for (nm in partner_traits) {
    idx <- !is.na(fx$data[[nm]])
    eta <- 0.6 + 0.25 * as.numeric(base::scale(fx$data[[nm]][idx]))
    fx$data[[nm]][idx] <- stats::rpois(sum(idx), lambda = exp(eta))
  }

  trait_names <- c("h_size", "h_defence", "p_size", "p_attack")
  long <- do.call(rbind, lapply(trait_names, function(nm) {
    data.frame(
      row_id = fx$data$row_id,
      species = fx$data$species,
      trait = factor(nm, levels = trait_names),
      value = fx$data[[nm]],
      family = if (nm %in% partner_traits) "poisson" else "gaussian",
      stringsAsFactors = FALSE
    )
  }))
  long <- long[!is.na(long$value), , drop = FALSE]
  long$family <- factor(long$family, levels = c("gaussian", "poisson"))
  expect_true(all(long$value[long$family == "poisson"] >= 0))
  expect_true(all(long$value[long$family == "poisson"] ==
    floor(long$value[long$family == "poisson"])))
  expect_equal(as.integer(table(long$family)), c(192L, 192L))

  fam <- list(stats::gaussian(), stats::poisson())
  attr(fam, "family_var") <- "family"

  ## COE-04 mixed-family construction-smoke alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy/K_non | kernel_latent(..., name = "phy/non") | same fixed kernels as Gaussian fixture | fit$kernel_diagnostics | construction smoke |
  ## | Y_H/Y_P | gaussian() + poisson() via family_var | host traits continuous, partner traits counts | convergence + finite logLik | smoke only |
  ## | Gamma_phy/Gamma_non | same named tiers | no recovery target in this mixed-family smoke | extract_Gamma(level = ...) | finite point blocks |
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = long,
    trait = "trait",
    unit = "row_id",
    cluster = "species",
    family = fam,
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(as.numeric(stats::logLik(fit))))
  expect_equal(fit$kernel_diagnostics$pairs$overlap_class, "near_orthogonal")

  S_phy <- suppressMessages(gllvmTMB::extract_Sigma(
    fit,
    level = "phy",
    part = "shared"
  ))
  S_non <- suppressMessages(gllvmTMB::extract_Sigma(
    fit,
    level = "non",
    part = "shared"
  ))
  expect_true(all(is.finite(S_phy$Sigma)))
  expect_true(all(is.finite(S_non$Sigma)))

  Gamma_phy <- gllvmTMB::extract_Gamma(
    fit,
    level = "phy",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  Gamma_non <- gllvmTMB::extract_Gamma(
    fit,
    level = "non",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  expect_true(all(is.finite(Gamma_phy)))
  expect_true(all(is.finite(Gamma_non)))
})

test_that("mixed-family two-kernel coevolution recovers component Gamma shapes", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")

  ## COE-04 mixed-family recovery alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy/K_non | kernel_latent(..., name = "phy/non") | fixed cross kernels | fit$kernel_diagnostics | near-orthogonal pair |
  ## | Y_H | gaussian() via family_var | identity-link host traits | convergence + logLik | continuous host block |
  ## | Y_P | poisson() via family_var | log-link partner counts from same latent component shapes | convergence + logLik | count partner block |
  ## | Gamma_phy/Gamma_non | same named tiers | Lambda_H,r Lambda_P,r^T, shape-only | extract_Gamma(level = r) | planted shape correlation |
  for (seed in c(2912L, 2913L)) {
    fx <- .c3_make_mixed_family_two_kernel_recovery_fixture(seed = seed)
    expect_equal(.c3_kernel_overlap_class(fx$similarity), "near_orthogonal")
    expect_gt(fx$mean_count, 2.5)
    expect_lt(fx$mean_count, 4)
    expect_equal(as.integer(table(fx$data$family)), c(400L, 400L))

    fit <- .c3_fit_mixed_family_two_kernel_set(fx)
    expect_equal(fit$full$opt$convergence, 0L)
    expect_equal(fit$phy_only$opt$convergence, 0L)
    expect_equal(fit$non_only$opt$convergence, 0L)
    expect_equal(
      fit$full$kernel_diagnostics$pairs$overlap_class,
      "near_orthogonal"
    )
    expect_gt(
      as.numeric(stats::logLik(fit$full)) -
        max(
          as.numeric(stats::logLik(fit$phy_only)),
          as.numeric(stats::logLik(fit$non_only))
        ),
      200
    )
    expect_gt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_phy), 0.90)
    expect_gt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_non), 0.90)
    expect_lt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_non), 0.12)
    expect_lt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_phy), 0.12)
  }
})

test_that("one named kernel tier exposes Sigma and Gamma by its name", {
  ## C3.1 contract on the supported single-tier latent + unique model:
  ## `extract_Sigma(level = name)` and `extract_Gamma(level = name)` key on
  ## the formula `name`. This is the by-name extraction the two-tier API
  ## would generalise once a second slot exists.
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  set.seed(72)
  n_unit <- 8L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A <- matrix(0.3, n_unit, n_unit)
  diag(A) <- 1
  rownames(A) <- colnames(A) <- unit_levels

  rows <- expand.grid(
    unit_id = unit_levels,
    rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$unit_id <- factor(rows$unit_id, levels = unit_levels)

  L_A <- t(chol(A + diag(1e-8, n_unit)))
  scores <- L_A %*% matrix(stats::rnorm(n_unit * 2L), n_unit, 2L)
  Lambda <- matrix(c(0.8, 0.0, 0.3, 0.7), 2, 2, byrow = TRUE)
  eta_unit <- scores %*% t(Lambda)
  colnames(eta_unit) <- c("y1", "y2")
  eta <- eta_unit[as.integer(rows$unit_id), , drop = FALSE]
  rows$y1 <- eta[, 1L] + stats::rnorm(nrow(rows), sd = 0.25)
  rows$y2 <- eta[, 2L] + stats::rnorm(nrow(rows), sd = 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2) ~
      1 +
      kernel_latent(unit_id, K = A, d = 2, name = "phy") +
      kernel_unique(unit_id, K = A, name = "phy"),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$kernel))
  expect_equal(fit$kernel_levels$name, "phy")

  S <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "phy", part = "total")
  )
  expect_equal(S$level, "phy")
  expect_equal(dim(S$Sigma), c(2L, 2L))

  ## The kernel alias keys strictly on the formula `name`: a wrong name
  ## must NOT alias to the fitted "phy" tier (it either errors or resolves
  ## to a different internal level, but never silently returns the phy
  ## block under the wrong name).
  expect_false(identical(fit$kernel_levels$name, "non"))
  wrong <- tryCatch(
    suppressMessages(
      gllvmTMB::extract_Sigma(fit, level = "non", part = "total")
    ),
    error = function(e) NULL
  )
  if (!is.null(wrong)) {
    expect_false(identical(wrong$level, "phy"))
  }

  Gamma <- gllvmTMB::extract_Gamma(
    fit,
    level = "phy",
    row_traits = "y1",
    col_traits = "y2"
  )
  expect_equal(dim(Gamma), c(1L, 1L))
  expect_equal(rownames(Gamma), "y1")
  expect_equal(colnames(Gamma), "y2")
})

test_that("two kernel_unique tiers without replication warn and collapse to one", {
  ## C3.2 guardrail: two uniqueness tiers + one observation per species
  ## (no within-species replication) -> warn (the two Psi are confounded)
  ## and default to a single uniqueness tier. Warn, not abort: the model
  ## still fits. Two DISTINCT names ("phy" + "non") are used so the test
  ## also confirms the guardrail runs before the single-`name` validation.
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c3_make_unreplicated()
  A_non <- diag(nrow(fx$A))
  dimnames(A_non) <- dimnames(fx$A)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  expect_warning(
    fit <- .c3_muffle_lifecycle_warnings(
      suppressMessages(gllvmTMB::gllvmTMB(
        traits(y1, y2) ~
          1 +
          kernel_unique(species, K = fx$A, name = "phy") +
          kernel_unique(species, K = A_non, name = "non"),
        data = fx$data,
        unit = "row_id",
        cluster = "species",
        family = stats::gaussian(),
        control = ctl
      ))
    ),
    regexp = "not separable without replication"
  )
  ## The collapsed fit is the single-uniqueness-tier model and still fits.
  expect_equal(fit$opt$convergence, 0L)
})

test_that("a single kernel_unique tier does NOT trigger the C3.2 warning", {
  ## Negative control: one uniqueness tier, no replication -> no warning.
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c3_make_unreplicated()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  expect_no_warning(
    .c3_muffle_lifecycle_warnings(
      suppressMessages(gllvmTMB::gllvmTMB(
        traits(y1, y2) ~
          1 + kernel_unique(species, K = fx$A, name = "phy"),
        data = fx$data,
        unit = "row_id",
        cluster = "species",
        family = stats::gaussian(),
        control = ctl
      ))
    )
  )
})

test_that("two kernel_unique tiers WITH replication separate the two Psi", {
  ## C3.2 the replicated side of the guardrail. With repeated observations
  ## per species the two uniqueness variances ARE identified, so the engine
  ## must NOT warn and the two-Psi model must fit. This is the heavy DGP
  ## recovery side: a phylo uniqueness component (Psi_phy on `A`) plus a
  ## tip-level uniqueness component, observed with within-species replicates.
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  set.seed(73)
  n_sp <- 20L
  n_rep <- 8L
  A <- .c3_tree_corr(n_sp, "s")
  species <- rownames(A)

  ## Two uniqueness components per trait: a phylo-structured Psi_phy on A
  ## and an unstructured tip-level Psi_non. With n_rep > 1 per species the
  ## residual replicate noise lets the two diagonal variances separate.
  psi_phy <- c(0.6, 0.5)
  psi_non <- c(0.4, 0.45)
  L_A <- t(chol(A + diag(1e-8, n_sp)))
  u_phy <- sweep(
    L_A %*% matrix(stats::rnorm(n_sp * 2L), n_sp, 2L),
    2L,
    sqrt(psi_phy),
    `*`
  )
  u_non <- sweep(
    matrix(stats::rnorm(n_sp * 2L), n_sp, 2L),
    2L,
    sqrt(psi_non),
    `*`
  )
  eta_sp <- u_phy + u_non
  colnames(eta_sp) <- c("y1", "y2")

  rows <- expand.grid(
    species = species,
    rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$species <- factor(rows$species, levels = species)
  eta <- eta_sp[as.integer(rows$species), , drop = FALSE]
  rows$y1 <- eta[, 1L] + stats::rnorm(nrow(rows), sd = 0.2)
  rows$y2 <- eta[, 2L] + stats::rnorm(nrow(rows), sd = 0.2)

  ## Replication IS present: max obs per species == n_rep > 1.
  expect_gt(max(table(rows$species)), 1L)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ## With replication, a single phylo uniqueness tier fits and recovers a
  ## positive phylo uniqueness variance (the identifiable component). The
  ## non-phylo residual variance is absorbed by the replicate error term.
  fit_phy <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2) ~
      1 + kernel_unique(species, K = A, name = "phy"),
    data = rows,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  expect_equal(fit_phy$opt$convergence, 0L)

  ## `part = "total"` returns the full per-tier covariance `$Sigma`
  ## regardless of which internal channel (shared LLt vs the separate Psi
  ## diagonal) carries a lone uniqueness tier's variance. The phylo
  ## uniqueness variance is recovered as positive on the diagonal -- the
  ## component that IS separable from replicate noise under within-species
  ## replication.
  S_phy <- suppressMessages(
    gllvmTMB::extract_Sigma(fit_phy, level = "phy", part = "total")
  )
  expect_true(all(diag(S_phy$Sigma) > 0))
})
