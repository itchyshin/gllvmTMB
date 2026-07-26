#!/usr/bin/env Rscript
## dev/va-bernoulli-VERIFY.R -- INDEPENDENT verification of the Bernoulli claim.
##
## Scratch script, NOT a test file.  Written by a fresh verifier who did not
## write the implementation.  Own seed, own dimensions, own true parameters,
## own brute-force ground-truth implementation, own Laplace implementation.
##
## The single load-bearing question: at the SAME parameter point, measured
## against the SAME brute-force integral, is the ELBO closer to the truth than
## the Laplace approximation is?  Laplace is never used as a yardstick.

options(warn = 1)
scratch_dir <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/ed064c95-cada-4788-83e8-ac5c0503c042/scratchpad"
dir.create(scratch_dir, showWarnings = FALSE, recursive = TRUE)

suppressPackageStartupMessages(library(devtools))
devtools::load_all(".", quiet = TRUE)
stopifnot(requireNamespace("statmod", quietly = TRUE))
proto_source <- normalizePath(file.path("inst", "tmb", "gllvmTMB_va_r3.cpp"),
                              mustWork = TRUE)

softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

# ===========================================================================
# A. MY brute-force TRUE marginal log-likelihood.
#
#    log p(y; beta, Lambda) = sum_i log INT prod_t Bern(y_it | logit^-1(eta_it))
#                                          N(u; 0, I_q) du,      q = 2.
#
#    Implementation is structurally different from the implementer's: the
#    (grid x trait) linear-predictor matrix is built ONCE and the per-unit
#    reduction is a single matrix-vector product, so no nested R loop over
#    quadrature nodes ever runs.  log C(1, y) = 0 exactly, so it is omitted
#    and that omission is asserted below.
# ===========================================================================
make_truth_fun <- function(Xrow_by_trait, y_mat, n_k) {
  ## y_mat is T x N (column i = unit i's responses).
  function(beta_v, Lambda_m, H) {
    gh <- statmod::gauss.quad(H, kind = "hermite")
    u <- sqrt(2) * gh$nodes
    lw <- log(gh$weights / sqrt(pi))
    grid <- expand.grid(a = seq_len(H), b = seq_len(H))
    U <- cbind(u[grid$a], u[grid$b])            # G x 2 latent draws
    logw <- lw[grid$a] + lw[grid$b]             # G   log product weights
    lin <- drop(Xrow_by_trait %*% beta_v)       # T   fixed part
    A <- sweep(U %*% t(Lambda_m), 2L, lin, "+") # G x T linear predictors
    sp_row <- rowSums(softplus(A)) * n_k        # G   trait-summed softplus
    Lmat <- A %*% y_mat                         # G x N   sum_t y_it eta_gt
    Lmat <- Lmat - sp_row + logw                # add -sum softplus and log w
    mx <- apply(Lmat, 2L, max)
    sum(mx + log(colSums(exp(sweep(Lmat, 2L, mx, "-")))))
  }
}

truth_ladder <- function(truth_fun, beta_v, Lambda_m, label,
                         H_ladder = c(21L, 41L, 61L, 101L, 151L)) {
  vals <- vapply(H_ladder, function(H) {
    v <- truth_fun(beta_v, Lambda_m, H)
    cat(sprintf("  [%s] H=%3d : log p(y) = %.12f\n", label, H, v))
    v
  }, numeric(1))
  names(vals) <- paste0("H", H_ladder)
  top <- vals[H_ladder >= 61L]
  spread <- max(top) - min(top)
  cat(sprintf("  [%s] ladder spread over H >= 61 : %.3e  -> %s\n", label,
              spread, if (spread < 1e-6) "STABLE" else "NOT STABLE"))
  list(value = unname(vals[length(vals)]), ladder = vals, spread = spread,
       stable = spread < 1e-6)
}

## Fully independent cross-check of the truth for ONE unit, by nested adaptive
## quadrature (stats::integrate), sharing no code with the GH route.
truth_one_unit_adaptive <- function(Xrow_by_trait, y_i, n_k, beta_v, Lambda_m) {
  lin <- drop(Xrow_by_trait %*% beta_v)
  inner <- function(u2) {
    vapply(u2, function(b) {
      f <- function(a) {
        vapply(a, function(aa) {
          eta <- lin + drop(Lambda_m %*% c(aa, b))
          exp(sum(y_i * eta - n_k * softplus(eta))) * stats::dnorm(aa)
        }, numeric(1))
      }
      stats::integrate(f, -12, 12, rel.tol = 1e-12,
                       subdivisions = 4000L)$value * stats::dnorm(b)
    }, numeric(1))
  }
  log(stats::integrate(inner, -12, 12, rel.tol = 1e-12,
                       subdivisions = 4000L)$value)
}

# ===========================================================================
# B. MY Laplace approximation at an ARBITRARY (beta, Lambda).
#
#    Needed because gllvmTMB only reports Laplace at its OWN optimum; to ask
#    "who is closer to truth at the SAME theta" I must be able to evaluate
#    Laplace at theta_VA too.
# ===========================================================================
laplace_loglik <- function(Xrow_by_trait, y_mat, n_k, beta_v, Lambda_m) {
  q <- ncol(Lambda_m)
  lin <- drop(Xrow_by_trait %*% beta_v)
  N <- ncol(y_mat)
  total <- 0
  for (i in seq_len(N)) {
    y_i <- y_mat[, i]
    uh <- rep(0, q)
    for (it in 1:200) {
      eta <- lin + drop(Lambda_m %*% uh)
      p <- stats::plogis(eta)
      W <- n_k * p * (1 - p)
      g <- drop(crossprod(Lambda_m, y_i - n_k * p)) - uh
      Hm <- crossprod(Lambda_m * W, Lambda_m) + diag(q)
      step <- solve(Hm, g)
      uh <- uh + step
      if (max(abs(step)) < 1e-12) break
    }
    eta <- lin + drop(Lambda_m %*% uh)
    p <- stats::plogis(eta)
    W <- n_k * p * (1 - p)
    Hm <- crossprod(Lambda_m * W, Lambda_m) + diag(q)
    total <- total + sum(y_i * eta - n_k * softplus(eta)) -
      0.5 * sum(uh^2) - 0.5 * determinant(Hm, logarithm = TRUE)$modulus
  }
  as.numeric(total)
}

# ===========================================================================
# C. MY independent recomputation of the ELBO from the reported variational
#    parameters, so the TMB objective is never taken on trust.
# ===========================================================================
elbo_from_report <- function(Xrow_by_trait, y_mat, n_k, beta_v, Lambda_m,
                             m_mat, L_flat, H = 121L) {
  q <- ncol(Lambda_m); T <- nrow(Lambda_m); N <- ncol(y_mat)
  gh <- statmod::gauss.quad(H, kind = "hermite")
  z <- sqrt(2) * gh$nodes; w <- gh$weights / sqrt(pi)
  lin <- drop(Xrow_by_trait %*% beta_v)
  ell <- 0; kl <- 0
  for (i in seq_len(N)) {
    Li <- matrix(L_flat[i, ], nrow = q, ncol = q, byrow = TRUE)
    Si <- Li %*% t(Li)
    mu <- lin + drop(Lambda_m %*% m_mat[i, ])
    v <- rowSums((Lambda_m %*% Si) * Lambda_m)
    Esp <- vapply(seq_len(T), function(t)
      sum(w * softplus(mu[t] + sqrt(v[t]) * z)), numeric(1))
    ell <- ell + sum(y_mat[, i] * mu - n_k * Esp)
    kl <- kl + 0.5 * (sum(diag(Si)) + sum(m_mat[i, ]^2) -
                        determinant(Si, logarithm = TRUE)$modulus - q)
  }
  as.numeric(ell - kl)
}

# ===========================================================================
# D. One complete measured cell.
# ===========================================================================
run_cell <- function(label, seed, N, Tt, q, beta_true, Lambda_true) {
  cat("\n\n#############################################################\n")
  cat(sprintf("## CELL: %s   (seed=%d, N=%d, T=%d, q=%d, Bernoulli)\n",
              label, seed, N, Tt, q))
  cat("#############################################################\n")
  set.seed(seed)
  n_k <- 1L
  unit_idx <- rep(seq_len(N), each = Tt)
  trait_idx <- rep(seq_len(Tt), N)
  X <- stats::model.matrix(~ 0 + factor(trait_idx, levels = seq_len(Tt)))
  score <- matrix(stats::rnorm(N * q), N, q)
  eta <- drop(X %*% beta_true) +
    rowSums(Lambda_true[trait_idx, , drop = FALSE] * score[unit_idx, , drop = FALSE])
  y <- stats::rbinom(N * Tt, n_k, stats::plogis(eta))
  n_trials <- rep.int(n_k, N * Tt)
  cat(sprintf("y: %d ones / %d cells  (p-bar = %.4f)\n",
              sum(y), length(y), mean(y)))

  Xrow <- X[1:Tt, , drop = FALSE]
  stopifnot(all(vapply(seq_len(N), function(i)
    all(X[((i - 1L) * Tt + 1L):(i * Tt), ] == Xrow), logical(1))))
  y_mat <- matrix(y, nrow = Tt, ncol = N)          # T x N, unit-major long data
  stopifnot(identical(as.integer(as.vector(y_mat)), as.integer(y)))
  stopifnot(max(abs(lgamma(n_k + 1) - lgamma(y + 1) - lgamma(n_k - y + 1))) < 1e-12)
  truth_fun <- make_truth_fun(Xrow, y_mat, n_k)

  df <- data.frame(y = y,
                   trait = factor(sprintf("t%02d", trait_idx)),
                   unit  = factor(sprintf("u%03d", unit_idx)))

  ## ---- 1. VA fit -----------------------------------------------------
  cat("\n-- VA prototype fit (H = 61) --\n")
  va <- try(.va_r3_fit(y = y, n_trials = n_trials, X = X,
                       unit_id = unit_idx, trait_id = trait_idx, q = q,
                       N = N, T = Tt, family = "binomial", link = "logit",
                       H = 61L, rank_source = "fixed_fixture",
                       source = proto_source,
                       control = list(eval.max = 3000L, iter.max = 3000L)),
            silent = TRUE)
  if (inherits(va, "try-error")) {
    cat("VA FIT ERRORED:", conditionMessage(attr(va, "condition")), "\n")
    return(list(label = label, va_error = conditionMessage(attr(va, "condition"))))
  }
  cat("VA status:", va$status, "| healthy starts:", va$health$healthy_starts,
      "/", va$health$attempted_starts,
      "| best-3 range:", format(va$health$best_three_objective_range, digits = 3),
      "| max proj var:", format(va$health$max_projected_variance, digits = 4), "\n")
  elbo_va <- -va$best$objective
  beta_va <- unname(va$best$par[names(va$best$par) == "beta"])
  Lambda_va <- va$report$Lambda
  cat(sprintf("ELBO at theta_VA (TMB)          = %.10f\n", elbo_va))
  elbo_va_R <- elbo_from_report(Xrow, y_mat, n_k, beta_va, Lambda_va,
                                va$report$m, va$report$L_flat)
  cat(sprintf("ELBO at theta_VA (my own R code)= %.10f   [diff %.3e]\n",
              elbo_va_R, elbo_va_R - elbo_va))

  ## ---- 2. gllvmTMB Laplace ------------------------------------------
  cat("\n-- gllvmTMB Laplace fit --\n")
  fit_l <- gllvmTMB(
    stats::as.formula(paste0(
      "y ~ 0 + trait + latent(0 + trait | unit, d = ", q, ", unique = FALSE)")),
    data = df, family = stats::binomial(), unit = "unit",
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE))
  ll_lap_pkg <- -fit_l$opt$objective
  beta_lap <- unname(fit_l$opt$par[names(fit_l$opt$par) == "b_fix"])
  Lambda_lap <- fit_l$report$Lambda_B
  Lambda_lap[row(Lambda_lap) < col(Lambda_lap)] <- 0
  cat(sprintf("gllvmTMB Laplace logLik = %.10f (convergence %d)\n",
              ll_lap_pkg, fit_l$opt$convergence))
  ll_lap_mine <- laplace_loglik(Xrow, y_mat, n_k, beta_lap, Lambda_lap)
  cat(sprintf("MY Laplace at theta_Laplace = %.10f   [diff %.3e]\n",
              ll_lap_mine, ll_lap_mine - ll_lap_pkg))

  ## ---- 3. ELBO at the FIXED Laplace theta ---------------------------
  cat("\n-- ELBO at the fixed Laplace theta --\n")
  va_fx <- .va_r3_fit(y = y, n_trials = n_trials, X = X,
                      unit_id = unit_idx, trait_id = trait_idx, q = q,
                      N = N, T = Tt, family = "binomial", link = "logit",
                      H = 61L, rank_source = "fixed_fixture",
                      source = proto_source,
                      fixed_global = list(
                        beta = beta_lap,
                        theta_rr = .va_r3_pack_theta_rr(Lambda_lap, q)),
                      control = list(eval.max = 3000L, iter.max = 3000L))
  elbo_at_lap <- -va_fx$best$objective
  cat("fixed-theta VA status:", va_fx$status, "\n")
  cat(sprintf("ELBO at theta_Laplace = %.10f\n", elbo_at_lap))

  ## ---- 4. Laplace at theta_VA (same-point, other direction) ---------
  ll_lap_at_va <- laplace_loglik(Xrow, y_mat, n_k, beta_va, Lambda_va)
  cat(sprintf("MY Laplace at theta_VA = %.10f\n", ll_lap_at_va))

  ## ---- 5. Ground truth with H-ladder --------------------------------
  cat("\n-- BRUTE-FORCE TRUTH, H-ladder --\n")
  t_va  <- truth_ladder(truth_fun, beta_va,  Lambda_va,  "theta_VA")
  t_lap <- truth_ladder(truth_fun, beta_lap, Lambda_lap, "theta_Lap")

  cat("\n-- Independent cross-check of the truth (nested adaptive integrate) --\n")
  ad <- vapply(1:3, function(i)
    truth_one_unit_adaptive(Xrow, y_mat[, i], n_k, beta_va, Lambda_va),
    numeric(1))
  gh_units <- local({
    H <- 151L
    gh <- statmod::gauss.quad(H, kind = "hermite")
    u <- sqrt(2) * gh$nodes; lw <- log(gh$weights / sqrt(pi))
    g <- expand.grid(a = seq_len(H), b = seq_len(H))
    U <- cbind(u[g$a], u[g$b]); logw <- lw[g$a] + lw[g$b]
    A <- sweep(U %*% t(Lambda_va), 2L, drop(Xrow %*% beta_va), "+")
    sp <- rowSums(softplus(A))
    vapply(1:3, function(i) {
      lv <- drop(A %*% y_mat[, i]) - sp + logw
      mx <- max(lv); mx + log(sum(exp(lv - mx)))
    }, numeric(1))
  })
  for (i in 1:3)
    cat(sprintf("  unit %d: GH(151) = %.12f | adaptive = %.12f | diff = %.3e\n",
                i, gh_units[i], ad[i], gh_units[i] - ad[i]))

  ## ---- 6. Scoreboard -------------------------------------------------
  cat("\n================ SCOREBOARD:", label, "================\n")
  cat(sprintf("AT theta_VA        TRUTH   = %.10f\n", t_va$value))
  cat(sprintf("                   ELBO    = %.10f   gap = %+.10f\n",
              elbo_va, elbo_va - t_va$value))
  cat(sprintf("                   LAPLACE = %.10f   gap = %+.10f\n",
              ll_lap_at_va, ll_lap_at_va - t_va$value))
  cat(sprintf("AT theta_Laplace   TRUTH   = %.10f\n", t_lap$value))
  cat(sprintf("                   ELBO    = %.10f   gap = %+.10f\n",
              elbo_at_lap, elbo_at_lap - t_lap$value))
  cat(sprintf("                   LAPLACE = %.10f   gap = %+.10f\n",
              ll_lap_pkg, ll_lap_pkg - t_lap$value))
  cat(sprintf("bound valid (both ELBO gaps <= 0)? %s\n",
              (elbo_va - t_va$value <= 0) && (elbo_at_lap - t_lap$value <= 0)))
  cat("=========================================================\n")

  list(label = label, seed = seed, N = N, Tt = Tt, q = q, pbar = mean(y),
       va_status = va$status, va_health = va$health,
       elbo_va = elbo_va, elbo_va_R = elbo_va_R,
       beta_va = beta_va, Lambda_va = Lambda_va,
       truth_va = t_va, truth_lap = t_lap,
       ll_lap_pkg = ll_lap_pkg, ll_lap_mine = ll_lap_mine,
       ll_lap_at_va = ll_lap_at_va, elbo_at_lap = elbo_at_lap,
       fixed_status = va_fx$status,
       adaptive_check = max(abs(gh_units - ad)))
}

# ===========================================================================
# E. My fixtures -- own seed, own dimensions, own truth.
# ===========================================================================
res <- list()

## Cell 1: balanced-ish Bernoulli.  N = 45, T = 6, q = 2, seed 6021977.
q1 <- 2L; T1 <- 6L
L1 <- matrix(0, T1, q1)
L1[, 1] <- c(1.05, 0.62, -0.48, 0.91, -0.35, 0.70)
L1[, 2] <- c(0.00, 0.88, 0.41, -0.66, 0.55, -0.29)
res$balanced <- run_cell("BALANCED", 6021977L, 45L, T1, q1,
                         beta_true = c(0.30, -0.60, 0.15, 0.45, -0.25, 0.05),
                         Lambda_true = L1)

## Cell 2: SPARSE binary -- the regime the whole VA programme is motivated by.
q2 <- 2L; T2 <- 6L
L2 <- matrix(0, T2, q2)
L2[, 1] <- c(0.95, 0.70, -0.55, 0.80, -0.40, 0.60)
L2[, 2] <- c(0.00, 0.75, 0.50, -0.60, 0.45, -0.35)
res$sparse <- run_cell("SPARSE (low p-bar)", 31415927L, 60L, T2, q2,
                       beta_true = rep(-2.6, T2) + c(0, .2, -.2, .1, -.1, .15),
                       Lambda_true = L2)

saveRDS(res, file.path(scratch_dir, "va-bernoulli-VERIFY.rds"))
cat("\n\nDONE.\n")
