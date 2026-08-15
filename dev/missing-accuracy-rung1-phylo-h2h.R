## Rung-1 P3CA/Rphylopars head-to-head harness -- pre-run test ONLY (D-139
## gate). Runs 3 replicates total; the full grid (6 cells x 10 seeds) needs
## separate maintainer approval and is NOT run by this script.
##
## Comparator provenance: mvMORPH's p3ca() is NOT publicly available (checked
## CRAN 1.2.1, GitHub master, and branch Paola-devel @ 321e6ea8 -- absent
## everywhere). The "p3ca_reimpl" arm below is a REIMPLEMENTATION from the
## paper's equations (Montoya et al. 2026, bioRxiv 2026.05.27.728209, eqs
## 6-13), never presented as the authors' code. Labelled "p3ca_reimpl" in
## every output.
##
## Uses the INSTALLED gllvmTMB (0.6.0) + phytools/ape/Rphylopars (0.3.10).

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(ape)
  library(phytools)
  library(Rphylopars)
})

dev_dir <- "dev"
source(file.path(dev_dir, "missing-accuracy-dgp.R"))  # make_mask(), apply_mask(), mask_cells()

## ===========================================================================
## Part 1: P3CA reimplementation core (paper eqs 6-13)
## ===========================================================================

#' Analytical complete-data ML solution (paper's eq 6).
#' Y: n x p, no missing. Cinv: n x n precision for the phylo covariance C_lambda.
p3ca_analytical <- function(Y, Cinv, q) {
  n <- nrow(Y); p <- ncol(Y)
  Rhat <- crossprod(Y, Cinv %*% Y) / n            # p x p,  Y^T Cinv Y / n
  eig <- eigen(Rhat, symmetric = TRUE)
  ord <- order(eig$values, decreasing = TRUE)
  vals <- eig$values[ord]; K <- eig$vectors[, ord, drop = FALSE]
  Kq <- K[, seq_len(q), drop = FALSE]
  dq <- vals[seq_len(q)]
  sigma2_ml <- mean(vals[(q + 1L):p])
  d_pos <- pmax(dq - sigma2_ml, 0)                  # guard tiny negative noise
  W_ml <- Kq %*% diag(sqrt(d_pos), nrow = q, ncol = q)
  list(W = W_ml, sigma2 = sigma2_ml, eigvals = vals)
}

#' Largest principal subspace angle (radians) between two p x q loading
#' matrices' column spaces.
subspace_angle <- function(W1, W2) {
  Q1 <- qr.Q(qr(W1)); Q2 <- qr.Q(qr(W2))
  sv <- svd(crossprod(Q1, Q2))$d
  sv <- pmin(pmax(sv, -1), 1)
  max(acos(sv))
}

#' One EM run at FIXED lambda (Cinv already built from C_lambda + ridge).
#' Y: n x p matrix, may contain NA. C: n x n phylo covariance at this lambda.
p3ca_em <- function(Y, C, Cinv, q, tol = 1e-6, maxit = 300L,
                     W_init = NULL, sigma2_init = NULL) {
  n <- nrow(Y); p <- ncol(Y)
  mask <- is.na(Y)
  any_missing <- any(mask)

  ## Per-trait missing/observed split, precomputed ONCE per lambda (the o/o,
  ## m/o blocks don't change across EM iterations at fixed C).
  ## vector("list", p) pre-fills every slot with NULL; do NOT assign NULL to
  ## trait_missing[[x]] below to "mark no missing" -- `l[[i]] <- NULL` DELETES
  ## that list element (shrinks the list, shifts later indices), which is
  ## exactly the bug that produced "subscript out of bounds" here. Leave the
  ## default NULL untouched instead.
  trait_missing <- vector("list", p)
  for (x in seq_len(p)) {
    m <- which(mask[, x]); o <- which(!mask[, x])
    if (length(m) == 0L) next
    Coo_inv <- solve(C[o, o, drop = FALSE])
    Cmo <- C[m, o, drop = FALSE]
    proj <- Cmo %*% Coo_inv                                   # m x o
    Cmm <- C[m, m, drop = FALSE]
    D_x <- Cmm - proj %*% C[o, m, drop = FALSE]                # m x m
    Cmm_inv <- solve(Cmm)
    trace_term_x <- sum(diag(Cmm_inv %*% D_x))
    trait_missing[[x]] <- list(m = m, o = o, proj = proj, trace_term = trace_term_x)
  }

  Yf <- Y
  if (any_missing) {
    for (x in seq_len(p)) {
      tm <- trait_missing[[x]]
      if (!is.null(tm)) Yf[tm$m, x] <- mean(Y[tm$o, x])
    }
  }

  if (is.null(W_init) || is.null(sigma2_init)) {
    Sc <- stats::cov(Yf) * (n - 1) / n
    eg <- eigen(Sc, symmetric = TRUE)
    ord <- order(eg$values, decreasing = TRUE)
    vals <- eg$values[ord]; vecs <- eg$vectors[, ord, drop = FALSE]
    s2 <- max(mean(vals[(q + 1L):p]), 1e-6)
    dpos <- pmax(vals[seq_len(q)] - s2, 1e-6)
    W <- vecs[, seq_len(q), drop = FALSE] %*% diag(sqrt(dpos), q, q)
    sigma2 <- s2
  } else {
    W <- W_init; sigma2 <- sigma2_init
  }

  converged <- FALSE
  it <- 0L
  for (it in seq_len(maxit)) {
    W_old <- W; sigma2_old <- sigma2

    ## ---- E-step ----
    M <- crossprod(W) + sigma2 * diag(q)                 # q x q
    Minv <- solve(M)
    Zhat <- Minv %*% t(W) %*% t(Yf)                       # q x n
    ZCZ <- n * sigma2 * Minv + Zhat %*% Cinv %*% t(Zhat)   # q x q

    if (any_missing) {
      Yhat_all <- t(Zhat) %*% t(W)                         # n x p, current fitted mean
      for (x in seq_len(p)) {
        tm <- trait_missing[[x]]
        if (is.null(tm)) next
        mu_m <- Yhat_all[tm$m, x]
        mu_o <- Yhat_all[tm$o, x]
        Yf[tm$m, x] <- mu_m + as.vector(tm$proj %*% (Y[tm$o, x] - mu_o))
      }
    }

    ## ---- M-step ----
    YtCinv <- crossprod(Yf, Cinv)                          # p x n,  Y^T Cinv
    ZCZ_inv <- solve(ZCZ)
    W_new <- (YtCinv %*% t(Zhat)) %*% ZCZ_inv              # p x q

    term1 <- sum(diag(YtCinv %*% Yf))                       # tr(Y^T Cinv Y)
    WZ <- W_new %*% Zhat                                    # p x n  (fitted Y^T)
    term2 <- 2 * sum(diag(YtCinv %*% t(WZ)))                 # tr(Y^T Cinv (W<Z>)^T)
    term3 <- sum(diag(W_new %*% ZCZ %*% t(W_new)))
    term4 <- if (any_missing) {
      sigma2_old * sum(vapply(trait_missing, function(tm) {
        if (is.null(tm)) 0 else tm$trace_term
      }, numeric(1)))
    } else 0
    sigma2_new <- max((term1 - term2 + term3 + term4) / (n * p), 1e-8)

    dW <- max(abs(W_new - W_old)) / max(1, max(abs(W_old)))
    dS <- abs(sigma2_new - sigma2_old) / max(sigma2_old, 1e-8)
    W <- W_new; sigma2 <- sigma2_new
    if (dW < tol && dS < tol) { converged <- TRUE; break }
  }

  Sigma_col <- tcrossprod(W) + sigma2 * diag(p)
  Sigma_col_inv <- solve(Sigma_col)
  ldetC <- as.numeric(determinant(C, logarithm = TRUE)$modulus)
  ldetS <- as.numeric(determinant(Sigma_col, logarithm = TRUE)$modulus)
  quad <- sum(diag(Sigma_col_inv %*% t(Yf) %*% Cinv %*% Yf))
  loglik_proxy <- -0.5 * (n * p * log(2 * pi) + p * ldetC + n * ldetS + quad)

  list(W = W, sigma2 = sigma2, Y_filled = Yf, n_iter = it,
       converged = converged, loglik_proxy = loglik_proxy)
}

#' Profile over a lambda grid, EM refit per lambda (warm-started from the
#' previous lambda's solution), pick the lambda maximising the observed-data
#' lower-bound proxy.
p3ca_reimpl_fit <- function(Y, C_base, q, lambda_grid = seq(0, 1, by = 0.05),
                             ridge = 1e-8, tol = 1e-6, maxit = 300L) {
  best <- NULL; best_ll <- -Inf; trace <- vector("list", length(lambda_grid))
  W_carry <- NULL; s2_carry <- NULL
  for (i in seq_along(lambda_grid)) {
    lam <- lambda_grid[i]
    C_lam <- lam * C_base + (1 - lam) * diag(diag(C_base))
    C_lam_r <- C_lam + ridge * diag(nrow(C_lam))
    Cinv <- solve(C_lam_r)
    fit <- p3ca_em(Y, C_lam_r, Cinv, q, tol = tol, maxit = maxit,
                    W_init = W_carry, sigma2_init = s2_carry)
    trace[[i]] <- list(lambda = lam, loglik_proxy = fit$loglik_proxy,
                        converged = fit$converged, n_iter = fit$n_iter)
    W_carry <- fit$W; s2_carry <- fit$sigma2
    if (fit$loglik_proxy > best_ll) {
      best_ll <- fit$loglik_proxy; best <- fit; best$lambda <- lam
    }
  }
  best$trace <- trace
  best
}

#' Fit p3ca_reimpl to a MASKED wide matrix: centre trait-wise on OBSERVED
#' cells only, run the lambda-profiled EM, return imputations on the
#' ORIGINAL (uncentred) scale for the masked cells.
p3ca_reimpl_predict_missing <- function(Y_masked, C_base, q,
                                         lambda_grid = seq(0, 1, by = 0.05)) {
  trait_means <- colMeans(Y_masked, na.rm = TRUE)
  Yc <- sweep(Y_masked, 2, trait_means, "-")
  fit <- p3ca_reimpl_fit(Yc, C_base, q, lambda_grid = lambda_grid)
  imputed <- sweep(fit$Y_filled, 2, trait_means, "+")
  list(fit = fit, imputed = imputed, trait_means = trait_means)
}

## ===========================================================================
## Part 2: DGPs
## ===========================================================================

#' Row-sum-of-squares scaling of iid N(0,1) loadings so the average per-trait
#' factor/residual variance ratio is approximately `target_ratio`, given the
#' residual columns are drawn at `resid_scale * (per-species variance)`.
scale_loadings <- function(p, q, target_ratio = 0.8, resid_scale = 0.5) {
  target_ss <- target_ratio / (1 - target_ratio) * resid_scale
  Wraw <- matrix(stats::rnorm(p * q), p, q)
  sf <- sqrt(target_ss / mean(rowSums(Wraw^2)))
  Wraw * sf
}

#' DGP-a (P3CA home): Y = Z* W_true^T + E, both Z* and E phylo-structured
#' (Z* at C_lambda, E at 0.5*C_lambda).
simulate_dgp_a <- function(tree, p = 25L, q_true = 3L, lambda_true, seed) {
  set.seed(seed)
  n <- length(tree$tip.label)
  C <- ape::vcv(tree)  # raw phylo vcv, rows/cols in tip.label order
  C_lam <- lambda_true * C + (1 - lambda_true) * diag(diag(C))
  C_lam_r <- C_lam + 1e-8 * diag(n)
  W_true <- scale_loadings(p, q_true, target_ratio = 0.8, resid_scale = 0.5)

  L_z <- t(chol(C_lam_r))
  Zstar <- matrix(0, n, q_true)
  for (k in seq_len(q_true)) Zstar[, k] <- as.vector(L_z %*% stats::rnorm(n))

  L_e <- t(chol(0.5 * C_lam_r))
  E <- matrix(0, n, p)
  for (j in seq_len(p)) E[, j] <- as.vector(L_e %*% stats::rnorm(n))

  Y <- Zstar %*% t(W_true) + E
  Y <- scale(Y, center = TRUE, scale = FALSE)  # exactly centred DGP
  dimnames(Y) <- list(tree$tip.label, paste0("t", seq_len(p)))
  list(Y = Y, C_base = C, lambda_true = lambda_true, W_true = W_true)
}

#' DGP-b (gllvmTMB native): factor scores phylo-correlated at fixed
#' lambda = 0.98; residual iid N(0, psi_j) -- anisotropic, NO phylo.
simulate_dgp_b <- function(tree, p = 25L, q_true = 3L, seed) {
  set.seed(seed)
  n <- length(tree$tip.label)
  C <- ape::vcv(tree)
  lambda_native <- 0.98
  C_lam <- lambda_native * C + (1 - lambda_native) * diag(diag(C))
  C_lam_r <- C_lam + 1e-8 * diag(n)
  W_true <- scale_loadings(p, q_true, target_ratio = 0.8, resid_scale = 0.5)

  L_z <- t(chol(C_lam_r))
  Zstar <- matrix(0, n, q_true)
  for (k in seq_len(q_true)) Zstar[, k] <- as.vector(L_z %*% stats::rnorm(n))

  psi_j <- stats::rlnorm(p, meanlog = log(0.5), sdlog = 0.5)
  E <- matrix(stats::rnorm(n * p), n, p) *
    matrix(sqrt(psi_j), n, p, byrow = TRUE)

  Y <- Zstar %*% t(W_true) + E
  Y <- scale(Y, center = TRUE, scale = FALSE)
  dimnames(Y) <- list(tree$tip.label, paste0("t", seq_len(p)))
  list(Y = Y, C_base = C, lambda_true = lambda_native, W_true = W_true, psi_j = psi_j)
}

## ===========================================================================
## Part 3: Missingness mechanisms
## ===========================================================================

#' MCAR mask via dev/missing-accuracy-dgp.R's make_mask(), guards overridden
#' to the brief's thresholds (>=10 obs/trait, >=5 obs/species).
mask_mcar05 <- function(n, p, seed) {
  make_mask(mechanism = "mcar05", n_units = n, p_traits = p, seed = seed,
             min_obs_trait = 10L, min_obs_unit = 5L)
}

#' Clade-clustered "structured MAR" mask: pick a clade of 10-15 tips via
#' ape::extract.clade, put 60% of a 10%-of-cells missing mass uniformly
#' inside it (rows = clade tips), the remaining 40% scattered (MCAR-like)
#' over the rest of the grid. Guards as above.
mask_clade <- function(tree, p, seed, min_tips = 10L, max_tips = 15L,
                        total_rate = 0.10, cluster_frac = 0.6,
                        min_obs_trait = 10L, min_obs_species = 5L,
                        max_attempts = 200L) {
  n <- length(tree$tip.label)
  candidates <- list()
  for (node in (n + 1L):(n + tree$Nnode)) {
    tl <- tryCatch(ape::extract.clade(tree, node)$tip.label, error = function(e) NULL)
    if (!is.null(tl) && length(tl) >= min_tips && length(tl) <= max_tips) {
      candidates[[length(candidates) + 1L]] <- tl
    }
  }
  if (length(candidates) == 0L) {
    stop("mask_clade: no clade of size [", min_tips, ",", max_tips, "] found.")
  }
  set.seed(seed)
  clade_tips <- candidates[[sample.int(length(candidates), 1L)]]
  clade_idx <- match(clade_tips, tree$tip.label)

  total <- n * p
  n_mask <- round(total_rate * total)
  n_cluster <- round(cluster_frac * n_mask)
  n_scatter <- n_mask - n_cluster

  for (attempt in seq_len(max_attempts)) {
    set.seed(seed * 97L + attempt)
    mask <- matrix(FALSE, n, p)
    cluster_pool <- which(as.vector(row(mask)) %in% clade_idx)
    cluster_cells <- sample(cluster_pool, min(n_cluster, length(cluster_pool)))
    remaining_pool <- setdiff(seq_len(total), cluster_cells)
    scatter_cells <- sample(remaining_pool, min(n_scatter, length(remaining_pool)))
    mask[c(cluster_cells, scatter_cells)] <- TRUE

    obs_per_trait <- n - colSums(mask)
    obs_per_species <- p - rowSums(mask)
    if (all(obs_per_trait >= min_obs_trait) && all(obs_per_species >= min_obs_species)) {
      attr(mask, "clade_tips") <- clade_tips
      attr(mask, "attempts") <- attempt
      return(mask)
    }
  }
  stop("mask_clade: could not satisfy guards after ", max_attempts, " attempts.")
}

## ===========================================================================
## Part 4: Arms
## ===========================================================================

#' Long-format data.frame from a wide (possibly NA-masked) matrix.
wide_to_long <- function(Y_masked, species_levels) {
  n <- nrow(Y_masked); p <- ncol(Y_masked)
  trait_names <- colnames(Y_masked)
  data.frame(
    species = factor(rep(rownames(Y_masked), times = p), levels = species_levels),
    trait   = factor(rep(trait_names, each = n), levels = trait_names),
    value   = as.vector(Y_masked),
    stringsAsFactors = FALSE
  )
}

#' Truth long table from the unmasked wide matrix.
wide_to_truth <- function(Y_true) {
  n <- nrow(Y_true); p <- ncol(Y_true)
  data.frame(
    species = rep(rownames(Y_true), times = p),
    trait   = rep(colnames(Y_true), each = n),
    truth   = as.vector(Y_true),
    stringsAsFactors = FALSE
  )
}

## Per-arm wall-clock cap. A timed-out arm records error = "timeout (>600s)"
## and stays in the denominator table (failure-inclusive accounting), never a
## bare NA with no reason.
ARM_TIMEOUT_S <- 600

#' Run `expr` under a hard wall-clock cap; on timeout, throw a condition whose
#' message is exactly "timeout (>Ns)" so callers can distinguish it from an
#' ordinary error.
with_arm_timeout <- function(expr, timeout_s = ARM_TIMEOUT_S) {
  R.utils::withTimeout(
    expr,
    timeout = timeout_s, onTimeout = "error"
  )
}

run_arm_gllvmTMB <- function(Y_masked, tree, unique_flag, mask, Y_true) {
  species_levels <- tree$tip.label
  df <- wide_to_long(Y_masked, species_levels)
  n_mask <- sum(mask)
  t0 <- Sys.time()
  out <- tryCatch({
    with_arm_timeout({
      ## phylo_latent(unique = ...) is parsed from the LITERAL formula text,
      ## not evaluated as an ordinary argument -- passing a variable (e.g.
      ## `unique = unique_flag`) fails with "must be a literal TRUE or
      ## FALSE". Build the formula text with the literal baked in instead.
      unique_lit <- if (isTRUE(unique_flag)) "TRUE" else "FALSE"
      form <- stats::as.formula(
        sprintf("value ~ 0 + trait + phylo_latent(species, d = 3, tree = tree, unique = %s)",
                unique_lit),
        env = environment()
      )
      fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
        form,
        data = df, family = gaussian(),
        trait = "trait", unit = "species",
        missing = miss_control(response = "include")
      )))
      pm <- predict_missing(fit, type = "response")
      pm$species <- as.character(pm$species)
      pm$trait <- as.character(pm$trait)
      truth <- wide_to_truth(Y_true)
      joined <- merge(pm, truth, by = c("species", "trait"))
      if (nrow(joined) != n_mask) {
        stop(sprintf("join count %d != designed mask size %d", nrow(joined), n_mask))
      }
      mse <- mean((joined$est - joined$truth)^2)
      list(mse = mse, error = NA_character_, n_joined = nrow(joined))
    })
  }, error = function(e) list(mse = NA_real_, error = conditionMessage(e), n_joined = NA_integer_))
  t1 <- Sys.time()
  out$wall_s <- as.numeric(t1 - t0, units = "secs")
  out
}

run_arm_p3ca <- function(Y_masked, C_base, mask, Y_true) {
  n_mask <- sum(mask)
  t0 <- Sys.time()
  out <- tryCatch({
    with_arm_timeout({
      res <- p3ca_reimpl_predict_missing(Y_masked, C_base, q = 3L)
      idx <- which(mask, arr.ind = TRUE)
      est <- res$imputed[idx]
      truth <- Y_true[idx]
      if (length(est) != n_mask) {
        stop(sprintf("imputed count %d != designed mask size %d", length(est), n_mask))
      }
      mse <- mean((est - truth)^2)
      list(mse = mse, error = NA_character_, n_joined = length(est),
           lambda_hat = res$fit$lambda)
    })
  }, error = function(e) list(mse = NA_real_, error = conditionMessage(e), n_joined = NA_integer_,
                               lambda_hat = NA_real_))
  t1 <- Sys.time()
  out$wall_s <- as.numeric(t1 - t0, units = "secs")
  out
}

run_arm_rphylopars <- function(Y_masked, tree, mask, Y_true) {
  n_mask <- sum(mask)
  t0 <- Sys.time()
  out <- tryCatch({
    with_arm_timeout({
      trait_data <- data.frame(species = rownames(Y_masked), Y_masked,
                                check.names = FALSE, stringsAsFactors = FALSE)
      fit <- Rphylopars::phylopars(trait_data = trait_data, tree = tree,
                                    model = "lambda", REML = FALSE)
      recon <- fit$anc_recon[rownames(Y_masked), colnames(Y_masked), drop = FALSE]
      idx <- which(mask, arr.ind = TRUE)
      est <- recon[idx]
      truth <- Y_true[idx]
      if (length(est) != n_mask) {
        stop(sprintf("recon count %d != designed mask size %d", length(est), n_mask))
      }
      mse <- mean((est - truth)^2)
      list(mse = mse, error = NA_character_, n_joined = length(est))
    })
  }, error = function(e) list(mse = NA_real_, error = conditionMessage(e), n_joined = NA_integer_))
  t1 <- Sys.time()
  out$wall_s <- as.numeric(t1 - t0, units = "secs")
  out
}

## ===========================================================================
## Part 5: Self-check (mandatory before any comparison)
## ===========================================================================

run_self_check <- function(seed = 101L) {
  n <- 50L; p <- 25L; q <- 3L
  tree <- phytools::pbtree(n = n, seed = seed)
  tree$tip.label <- paste0("sp", seq_len(n))
  dgp <- simulate_dgp_a(tree, p = p, q_true = q, lambda_true = 1, seed = seed)
  C1 <- dgp$C_base + 1e-8 * diag(n)
  Cinv1 <- solve(C1)

  fit <- p3ca_em(dgp$Y, C1, Cinv1, q, tol = 1e-6, maxit = 300L)
  ana <- p3ca_analytical(dgp$Y, Cinv1, q)
  angle <- subspace_angle(fit$W, ana$W)
  rel_sigma <- abs(fit$sigma2 - ana$sigma2) / ana$sigma2
  list(angle = angle, rel_sigma = rel_sigma,
       pass = angle < 1e-3 && rel_sigma < 1e-4,
       n_iter = fit$n_iter, converged = fit$converged)
}

## ===========================================================================
## Part 6: Pre-run test -- 3 replicates ONLY. Do NOT run the full grid here.
## ===========================================================================

if (identical(Sys.getenv("P3CA_RUN_PRERUN"), "1")) {

  cat("=== SELF-CHECK ===\n")
  sc <- run_self_check()
  cat(sprintf("angle=%.3e rel_sigma=%.3e n_iter=%d converged=%s PASS=%s\n",
              sc$angle, sc$rel_sigma, sc$n_iter, sc$converged, sc$pass))
  if (!isTRUE(sc$pass)) {
    stop("SELF-CHECK FAILED -- stopping before any comparison, per brief.")
  }

  cells <- list(
    list(label = "DGP-a lambda=0.98 MCAR5", dgp = "a", lambda = 0.98, mech = "mcar", seed = 201L),
    list(label = "DGP-a lambda=0.98 clade", dgp = "a", lambda = 0.98, mech = "clade", seed = 202L),
    list(label = "DGP-b clade",              dgp = "b", lambda = NA,   mech = "clade", seed = 203L)
  )

  n <- 50L; p <- 25L; q <- 3L
  results <- list()

  for (cell in cells) {
    cat("\n=== CELL:", cell$label, "===\n")
    tree <- phytools::pbtree(n = n, seed = cell$seed)
    tree$tip.label <- paste0("sp", seq_len(n))

    dgp <- if (cell$dgp == "a") {
      simulate_dgp_a(tree, p = p, q_true = q, lambda_true = cell$lambda, seed = cell$seed)
    } else {
      simulate_dgp_b(tree, p = p, q_true = q, seed = cell$seed)
    }
    Y_true <- dgp$Y

    mask <- if (cell$mech == "mcar") {
      mask_mcar05(n, p, seed = cell$seed)
    } else {
      mask_clade(tree, p, seed = cell$seed)
    }
    Y_masked <- Y_true
    Y_masked[mask] <- NA

    row_res <- list(cell = cell$label)

    cat("  arm: gllvmTMB-primary (unique=TRUE) ...\n")
    a1 <- run_arm_gllvmTMB(Y_masked, tree, unique_flag = TRUE, mask, Y_true)
    row_res$gllvmTMB_primary <- a1

    cat("  arm: gllvmTMB-lean (unique=FALSE) ...\n")
    a2 <- run_arm_gllvmTMB(Y_masked, tree, unique_flag = FALSE, mask, Y_true)
    row_res$gllvmTMB_lean <- a2

    cat("  arm: p3ca_reimpl ...\n")
    a3 <- run_arm_p3ca(Y_masked, dgp$C_base, mask, Y_true)
    row_res$p3ca_reimpl <- a3

    cat("  arm: Rphylopars ...\n")
    a4 <- run_arm_rphylopars(Y_masked, tree, mask, Y_true)
    row_res$Rphylopars <- a4

    results[[cell$label]] <- row_res
    cat(sprintf("  MSE: primary=%.4f lean=%.4f p3ca=%.4f rphylopars=%.4f\n",
                a1$mse, a2$mse, a3$mse, a4$mse))
    cat(sprintf("  wall_s: primary=%.2f lean=%.2f p3ca=%.2f rphylopars=%.2f\n",
                a1$wall_s, a2$wall_s, a3$wall_s, a4$wall_s))
  }

  saveRDS(list(self_check = sc, results = results),
          file.path(dev_dir, "missing-accuracy", "rung1-prerun-results.rds"))
  cat("\nSaved: dev/missing-accuracy/rung1-prerun-results.rds\n")
}
