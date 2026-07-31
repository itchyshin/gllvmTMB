#!/usr/bin/env Rscript
## Design 86/VA-in-06 EVA parity -- simulated ladder, same-link (logit) comparison.
##
## Blocking precheck established that gllvm::gllvm(family = binomial(link =
## "logit"), method = "EVA") IS genuine logit-link EVA (verified against an
## independent glm() anchor) -- see precheck-log.txt. This makes a genuine
## same-link, same-data recovery-vs-truth comparison possible, which is what
## this script runs.
##
## Grid: n in {60, 150}, p in {8, 20}, q in {1, 2}, 10 seeds, Bernoulli logit.
## DGP mirrors dev/totoro-grid/run-grid.R's established recipe for continuity
## with this repo's other VA/EVA comparisons (not modified here -- read only).
##
## Every attempted fit is one row; failures are rows with a status, never a
## dropped hole. Status matching is exact (==, isTRUE, identical), never
## grepl. Each engine's own convergence flag is recorded but never used to
## filter rows -- an independent, engine-neutral "beta_exploded" flag
## (max|beta_hat| > BETA_EXPLODE_THRESHOLD) is computed the same way for both
## arms and used only for a side-by-side robust-vs-all summary, not to drop
## rows from the primary table.

suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-va-in-06", quiet = TRUE))
suppressMessages(library(gllvm))

out_dir <- "/private/tmp/gllvmtmb-va-in-06/dev/va-gate3/eva-parity/results"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
csv_path <- file.path(out_dir, "ladder-results.csv")
lambda_csv_path <- file.path(out_dir, "ladder-lambda-comparison.csv")
log_path <- file.path(out_dir, "ladder-log.txt")
log_con <- file(log_path, open = "wt")

BETA_EXPLODE_THRESHOLD <- 15  # logit-scale plausibility cutoff; true betas are ~N(0.3,0.3)

relfrob <- function(S, St) norm(S - St, "F") / norm(St, "F")

## Orthogonal Procrustes with optional isotropic scale: minimise
## || A - c B R ||_F over rotation/reflection R (q x q orthogonal) and
## optional scalar c, for B, A both T x q. Closed-form SVD solution
## (Schonemann 1966; scale extension e.g. Gower & Dijksterhuis 2004).
procrustes_fit <- function(B, A, scale = TRUE) {
  if (!is.matrix(B) || !is.matrix(A) || !identical(dim(B), dim(A)) ||
      !all(is.finite(B)) || !all(is.finite(A)) || !all(dim(B) > 0)) {
    return(list(c = NA_real_, rel_disagreement = NA_real_))
  }
  M <- crossprod(B, A)
  sv <- svd(M)
  R <- sv$u %*% t(sv$v)
  c <- if (isTRUE(scale)) sum(sv$d) / sum(B^2) else 1
  Bfit <- c * (B %*% R)
  resid <- A - Bfit
  list(c = c, rss = sum(resid^2),
       rel_disagreement = sqrt(sum(resid^2)) / sqrt(sum(A^2)))
}

grid <- expand.grid(n = c(60L, 150L), p = c(8L, 20L), q = c(1L, 2L), seed = 1:10,
                     stringsAsFactors = FALSE)
grid <- grid[grid$q < grid$p, ]
if (isTRUE(as.logical(Sys.getenv("LADDER_SMOKE", "FALSE")))) {
  grid <- grid[grid$seed <= 2, ]
}
cat(sprintf("Grid has %d cells (x2 engines = %d fit attempts)\n", nrow(grid), 2 * nrow(grid)))

rows <- vector("list", nrow(grid) * 2L)
lambda_rows <- vector("list", nrow(grid))
ri <- 0L; li <- 0L

t_start_all <- proc.time()[["elapsed"]]

for (i in seq_len(nrow(grid))) {
  cell <- grid[i, ]
  n <- cell$n; p <- cell$p; q <- cell$q; seed <- cell$seed
  cat(sprintf("[%d/%d] n=%d p=%d q=%d seed=%d ... ", i, nrow(grid), n, p, q, seed))
  flush.console()

  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- rnorm(p, 0.3, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  Sig_true <- Lt %*% t(Lt)

  lg <- expand.grid(unit = seq_len(n), trait = seq_len(p))
  lg <- lg[order(lg$unit, lg$trait), ]
  yv <- as.vector(t(Y))
  X <- model.matrix(~ 0 + factor(lg$trait))

  ## mapping verification, every cell
  Y_recon <- matrix(NA_real_, n, p)
  Y_recon[cbind(lg$unit, lg$trait)] <- yv
  mapping_ok <- isTRUE(all.equal(unname(Y_recon), matrix(as.numeric(unname(Y)), n, p))) &&
    identical(as.numeric(sum(yv)), as.numeric(sum(Y)))

  ## any near/complete-separation species? (diagnostic flag only, not a filter)
  colsum_frac <- colSums(Y) / n
  any_extreme_species <- any(colsum_frac <= 0.02 | colsum_frac >= 0.98)

  ## ---------------- ours ----------------
  t0 <- proc.time()[["elapsed"]]
  ours <- tryCatch(
    .eva_fit(y = yv, n_trials = rep(1, length(yv)), X = X,
             unit_id = lg$unit, trait_id = lg$trait, q = q,
             family = "binomial", link = "logit"),
    error = function(e) structure(list(message = conditionMessage(e)), class = "r_error")
  )
  secs_ours <- proc.time()[["elapsed"]] - t0

  Lambda_ours <- NULL
  if (inherits(ours, "r_error")) {
    ri <- ri + 1L
    rows[[ri]] <- data.frame(
      n = n, p = p, q = q, seed = seed, engine = "ours",
      status = "r_error", seconds = secs_ours,
      rel_frob = NA_real_, kappa = NA_real_, beta_rmse = NA_real_, beta_maxabs = NA_real_,
      beta_exploded = NA, reported_convergence = NA, reported_healthy = NA,
      max_abs_gradient = NA_real_, mapping_ok = mapping_ok,
      any_extreme_species = any_extreme_species, note = ours$message,
      stringsAsFactors = FALSE)
  } else {
    beta_hat <- unname(ours$best$par[names(ours$best$par) == "beta"])
    Lambda_ours <- ours$report$Lambda
    beta_exploded <- if (length(beta_hat) && all(is.finite(beta_hat))) {
      max(abs(beta_hat)) > BETA_EXPLODE_THRESHOLD
    } else NA
    if (is.matrix(Lambda_ours) && all(is.finite(Lambda_ours))) {
      Sh <- Lambda_ours %*% t(Lambda_ours)
      rf <- relfrob(Sh, Sig_true); kp <- sum(diag(Sh)) / sum(diag(Sig_true))
    } else { rf <- NA_real_; kp <- NA_real_ }
    ri <- ri + 1L
    rows[[ri]] <- data.frame(
      n = n, p = p, q = q, seed = seed, engine = "ours",
      status = ours$status, seconds = secs_ours,
      rel_frob = rf, kappa = kp,
      beta_rmse = if (length(beta_hat) && all(is.finite(beta_hat))) sqrt(mean((beta_hat - b)^2)) else NA_real_,
      beta_maxabs = if (length(beta_hat) && all(is.finite(beta_hat))) max(abs(beta_hat - b)) else NA_real_,
      beta_exploded = beta_exploded,
      reported_convergence = NA, reported_healthy = isTRUE(ours$best$healthy),
      max_abs_gradient = ours$best$max_abs_gradient, mapping_ok = mapping_ok,
      any_extreme_species = any_extreme_species, note = "",
      stringsAsFactors = FALSE)
  }

  ## ---------------- gllvm ----------------
  t0 <- proc.time()[["elapsed"]]
  g <- tryCatch(
    withCallingHandlers(
      gllvm::gllvm(y = Y, family = binomial(link = "logit"), num.lv = q, method = "EVA", seed = seed),
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) structure(list(message = conditionMessage(e)), class = "r_error")
  )
  secs_g <- proc.time()[["elapsed"]] - t0

  Lam_g <- NULL
  if (inherits(g, "r_error")) {
    ri <- ri + 1L
    rows[[ri]] <- data.frame(
      n = n, p = p, q = q, seed = seed, engine = "gllvm",
      status = "r_error", seconds = secs_g,
      rel_frob = NA_real_, kappa = NA_real_, beta_rmse = NA_real_, beta_maxabs = NA_real_,
      beta_exploded = NA, reported_convergence = NA, reported_healthy = NA,
      max_abs_gradient = NA_real_, mapping_ok = mapping_ok,
      any_extreme_species = any_extreme_species, note = g$message,
      stringsAsFactors = FALSE)
  } else {
    beta0 <- unname(g$params$beta0)
    Lam_g <- tryCatch(as.matrix(g$params$theta) %*% diag(g$params$sigma.lv, q, q),
                       error = function(e) NULL)
    beta_exploded_g <- if (length(beta0) && all(is.finite(beta0))) {
      max(abs(beta0)) > BETA_EXPLODE_THRESHOLD
    } else NA
    if (is.matrix(Lam_g) && all(is.finite(Lam_g))) {
      Sh <- Lam_g %*% t(Lam_g)
      rf <- relfrob(Sh, Sig_true); kp <- sum(diag(Sh)) / sum(diag(Sig_true))
    } else { rf <- NA_real_; kp <- NA_real_ }
    conv <- g$convergence
    status_g <- if (identical(conv, TRUE)) "converged" else if (identical(conv, FALSE)) "not_converged" else "convergence_unreported"
    ri <- ri + 1L
    rows[[ri]] <- data.frame(
      n = n, p = p, q = q, seed = seed, engine = "gllvm",
      status = status_g, seconds = secs_g,
      rel_frob = rf, kappa = kp,
      beta_rmse = if (length(beta0) && all(is.finite(beta0))) sqrt(mean((beta0 - b)^2)) else NA_real_,
      beta_maxabs = if (length(beta0) && all(is.finite(beta0))) max(abs(beta0 - b)) else NA_real_,
      beta_exploded = beta_exploded_g,
      reported_convergence = identical(conv, TRUE), reported_healthy = NA,
      max_abs_gradient = NA_real_, mapping_ok = mapping_ok,
      any_extreme_species = any_extreme_species, note = "",
      stringsAsFactors = FALSE)
  }

  ## ---------------- direct Lambda-vs-Lambda (rotation/scale aligned) ----------------
  if (is.matrix(Lambda_ours) && all(is.finite(Lambda_ours)) &&
      is.matrix(Lam_g) && all(is.finite(Lam_g)) && identical(dim(Lambda_ours), dim(Lam_g))) {
    pr_rot <- procrustes_fit(Lambda_ours, Lam_g, scale = FALSE)
    pr_scl <- procrustes_fit(Lambda_ours, Lam_g, scale = TRUE)
    li <- li + 1L
    lambda_rows[[li]] <- data.frame(
      n = n, p = p, q = q, seed = seed,
      rel_disagreement_rotation_only = pr_rot$rel_disagreement,
      rel_disagreement_scaled = pr_scl$rel_disagreement,
      fitted_scale = pr_scl$c,
      both_beta_exploded = isTRUE(rows[[ri - 1L]]$beta_exploded) || isTRUE(rows[[ri]]$beta_exploded),
      stringsAsFactors = FALSE)
  }

  cat(sprintf("ours=%s(%.1fs) gllvm=%s(%.1fs)\n",
              rows[[ri - 1L]]$status, secs_ours, rows[[ri]]$status, secs_g))

  ## periodic checkpoint save
  if (i %% 5 == 0 || i == nrow(grid)) {
    write.csv(do.call(rbind, rows[seq_len(ri)]), csv_path, row.names = FALSE)
    if (li > 0) write.csv(do.call(rbind, lambda_rows[seq_len(li)]), lambda_csv_path, row.names = FALSE)
  }
}

elapsed_all <- proc.time()[["elapsed"]] - t_start_all
cat(sprintf("\nTotal elapsed: %.1f s (%.1f min)\n", elapsed_all, elapsed_all / 60))

results <- do.call(rbind, rows[seq_len(ri)])
lambda_results <- if (li > 0) do.call(rbind, lambda_rows[seq_len(li)]) else NULL
write.csv(results, csv_path, row.names = FALSE)
if (!is.null(lambda_results)) write.csv(lambda_results, lambda_csv_path, row.names = FALSE)
saveRDS(list(results = results, lambda_results = lambda_results, elapsed = elapsed_all),
        file.path(out_dir, "ladder-results.rds"))

cat("\nWrote", csv_path, "\n")
cat("Wrote", lambda_csv_path, "\n")
