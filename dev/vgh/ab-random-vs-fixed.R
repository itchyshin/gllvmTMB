## ---------------------------------------------------------------------------
## ab-random-vs-fixed.R -- A/B on how the per-unit variational block is handled
## by TMB for the Design-85 VA objective (inst/tmb/gllvmTMB_va_r3.cpp).
##
##   ARM A  random = NULL                              (current .va_r3 behaviour)
##   ARM B  random = c("m","log_L_diag","L_off")        (proposed fix: Laplace)
##   ARM C  profile = c("m","log_L_diag","L_off")       (extra: TMB's inner
##                                                       maximisation WITHOUT
##                                                       the log-determinant)
##
## No package file is edited.  The TMB objective is constructed here directly
## from TMB::MakeADFun, replicating the data / parameters / map that
## .va_r3_make_objective() builds (R/va-r3-proto.R:1006-1066).
##
## IMPORTANT INTERPRETATION NOTE.  With random=, TMB returns the LAPLACE-
## marginalised objective, not the raw ELBO, so arm A and arm B objective
## VALUES are not comparable.  Only the fixed-parameter estimates are.  And
## because Lambda is identified only up to a sign flip of each column,
## theta_rr itself is not comparable either -- Sigma_B = Lambda Lambda' is the
## invariant, so that is what is compared.
##
## Usage
##   Rscript dev/vgh/ab-random-vs-fixed.R              # driver: runs the grid
##   Rscript dev/vgh/ab-random-vs-fixed.R A 400        # one worker fit
## ---------------------------------------------------------------------------

repo      <- "/private/tmp/gllvmtmb-vgh"
BUILD_DIR <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/faeb944c-5ca6-48e0-a5c5-11966357d7d8/scratchpad/va-r3-build"
RUN_DIR   <- file.path(repo, "dev", "vgh", "ab-runs")
SCRIPT    <- file.path(repo, "dev", "vgh", "ab-random-vs-fixed.R")

## The coordinator suggested 900 s.  Raised to 1800 s because the headline
## question here is SCALING, and a cap that bites inside the grid truncates the
## very measurement being made; 1800 s still serves the stated purpose (one
## hanging arm cannot kill the run).  Reported as such.
TIMEOUT_SEC <- 1800
GRID_N      <- c(200L, 400L, 800L, 1600L, 3200L)
T_TRAITS    <- 20L
Q_LATENT    <- 2L
H_ORDER     <- 15L
N_PER_CELL  <- 5L


## --- shared: DLL, data, parameters, objective -------------------------------

build_dll <- function() {
  src <- file.path(repo, "inst", "tmb", "gllvmTMB_va_r3.cpp")
  dir.create(BUILD_DIR, recursive = TRUE, showWarnings = FALSE)
  cpp <- file.path(BUILD_DIR, "gllvmTMB_va_r3.cpp")
  if (!file.exists(cpp) ||
      !identical(unname(tools::md5sum(src)), unname(tools::md5sum(cpp)))) {
    stopifnot(file.copy(src, cpp, overwrite = TRUE))
    unlink(TMB::dynlib(tools::file_path_sans_ext(cpp)))
  }
  dll <- TMB::dynlib(tools::file_path_sans_ext(cpp))
  if (!file.exists(dll)) {
    owd <- setwd(BUILD_DIR); on.exit(setwd(owd), add = TRUE)
    st <- TMB::compile(basename(cpp), flags = "-O2")
    if (!identical(as.integer(st), 0L) || !file.exists(dll)) {
      stop("TMB compilation of gllvmTMB_va_r3.cpp failed.", call. = FALSE)
    }
  }
  dyn.load(dll)
  "gllvmTMB_va_r3"
}

## Physicists' Gauss-Hermite rule, byte-identical to .va_r3_gh_rule().
gh_rule <- function(H) {
  H <- as.integer(H)
  stopifnot(H %in% c(15L, 25L, 61L))
  J <- matrix(0, H, H)
  off <- sqrt(seq_len(H - 1L) / 2)
  J[cbind(seq_len(H - 1L), 2:H)] <- off
  J[cbind(2:H, seq_len(H - 1L))] <- off
  ee <- eigen(J, symmetric = TRUE)
  nodes <- unname(ee$values[order(ee$values)])
  hm2 <- rep(1, H); hm1 <- 2 * nodes
  for (k in 2:(H - 1L)) { hk <- 2 * nodes * hm1 - 2 * (k - 1) * hm2; hm2 <- hm1; hm1 <- hk }
  w <- 2^(H - 1L) * gamma(H + 1) * sqrt(pi) / (H^2 * hm1^2)
  list(nodes = nodes, weights = unname(w * sqrt(pi) / sum(w)))
}

theta_len <- function(T, q) as.integer(T * q - q * (q - 1L) / 2L)

## Simulate a genuine binomial-logit GLLVM (so the optimum is meaningful).
sim_data <- function(N, T, q, n_per_cell, seed = 20260729L) {
  set.seed(seed + N)
  n_obs    <- N * T
  unit_id  <- rep(seq_len(N), each = T)
  trait_id <- rep(seq_len(T), times = N)
  Xd <- matrix(0, n_obs, T)
  Xd[cbind(seq_len(n_obs), trait_id)] <- 1
  X <- cbind(Xd, rnorm(n_obs))              # T trait intercepts + 1 covariate
  beta_true <- c(rnorm(T, -0.2, 0.5), 0.4)
  Lambda_true <- matrix(0, T, q)
  Lambda_true[cbind(seq_len(q), seq_len(q))] <- c(0.9, 0.7, 0.6)[seq_len(q)]
  for (j in seq_len(q)) if (j < T) Lambda_true[seq.int(j + 1L, T), j] <- rnorm(T - j, 0, 0.55)
  U <- matrix(rnorm(N * q), N, q)
  eta <- as.vector(X %*% beta_true) +
    rowSums(U[unit_id, , drop = FALSE] * Lambda_true[trait_id, , drop = FALSE])
  n_trials <- rep(as.integer(n_per_cell), n_obs)
  list(y = as.numeric(rbinom(n_obs, n_trials, plogis(eta))),
       n_trials = n_trials, X = X,
       unit_id = unit_id - 1L, trait_id = trait_id - 1L,   # cpp wants 0-based
       N = N, T = T, q = q,
       beta_true = beta_true, Lambda_true = Lambda_true)
}

## Deterministic start -- IDENTICAL for every arm.
make_start <- function(d) {
  p <- ncol(d$X)
  prop <- (d$y + 0.5) / (d$n_trials + 1)
  beta <- tryCatch(unname(stats::lm.fit(d$X, stats::qlogis(prop))$coefficients),
                   error = function(e) rep(0, p))
  if (length(beta) != p || any(!is.finite(beta))) beta <- rep(0, p)
  th <- rep(0.05, theta_len(d$T, d$q))
  th[seq_len(d$q)] <- 0.5
  list(beta = beta, theta_rr = th,
       m          = matrix(0, d$N, d$q),
       log_L_diag = matrix(0, d$N, d$q),
       L_off      = matrix(0, d$N, d$q * (d$q - 1L) / 2L),
       log_phi    = rep(0, d$T))
}

## Exactly the data/map contract of .va_r3_make_objective() for family 1.
make_obj <- function(d, params, arm, dll, H) {
  rule <- gh_rule(H)
  tmb_data <- list(
    y = d$y, n_trials = as.integer(d$n_trials), X = unname(d$X),
    unit_id = as.integer(d$unit_id), trait_id = as.integer(d$trait_id),
    N = as.integer(d$N), T = as.integer(d$T), q = as.integer(d$q),
    gh_nodes = rule$nodes, gh_weights = rule$weights,
    family = 1L, gaussian_sd = 1, eval_method = 0L)          # eval_method = gh
  ## log_phi is inert for family != 3 and is mapped off, exactly as the package does
  map <- list(log_phi = factor(rep(NA_integer_, length(params$log_phi))))
  vblocks <- c("m", "log_L_diag", "L_off")
  args <- list(data = tmb_data, parameters = params, map = map,
               DLL = dll, silent = TRUE)
  if (arm == "A") args$random  <- NULL
  if (arm == "B") args$random  <- vblocks
  if (arm == "C") args$profile <- vblocks
  do.call(TMB::MakeADFun, args)
}

## Sigma_B = Lambda Lambda' -- the sign-flip-invariant summary of theta_rr.
sigma_B <- function(theta, T, q) {
  Lambda <- matrix(0, T, q)
  Lambda[cbind(seq_len(q), seq_len(q))] <- theta[seq_len(q)]
  cur <- q + 1L
  for (j in seq_len(q)) if (j < T) {
    rows <- seq.int(j + 1L, T)
    Lambda[rows, j] <- theta[seq.int(cur, length.out = length(rows))]
    cur <- cur + length(rows)
  }
  tcrossprod(Lambda)
}


## --- WORKER: one (arm, N) fit ----------------------------------------------

run_one <- function(arm, N) {
  suppressWarnings(suppressMessages(library(TMB)))
  dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)
  tag  <- sprintf("%s-%d", arm, N)
  csv  <- file.path(RUN_DIR, paste0(tag, ".csv"))
  rds  <- file.path(RUN_DIR, paste0(tag, ".rds"))

  row <- data.frame(arm = arm, N = N, T = T_TRAITS, q = Q_LATENT, H = H_ORDER,
                    n_obs = NA_integer_, n_outer_par = NA_integer_,
                    n_inner_par = NA_integer_,
                    setup_sec = NA_real_, optim_sec = NA_real_,
                    total_sec = NA_real_, objective = NA_real_,
                    iterations = NA_integer_, evaluations = NA_integer_,
                    convergence = NA_integer_, peak_mb = NA_real_,
                    status = "error", message = "", stringsAsFactors = FALSE)

  res <- try({
    dll <- build_dll()
    d   <- sim_data(N, T_TRAITS, Q_LATENT, N_PER_CELL)
    st  <- make_start(d)
    row$n_obs <- length(d$y)

    obj <- make_obj(d, st, arm, dll, H_ORDER)
    row$n_outer_par <- length(obj$par)
    row$n_inner_par <- if (is.null(obj$env$random)) 0L else length(obj$env$random)

    gc(reset = TRUE)
    ## WARM-UP (untimed as "optimisation"): first fn/gr builds the AD tape and,
    ## for arms B/C, the sparse inner structure.  Reported separately.
    t0 <- proc.time()[["elapsed"]]
    v0 <- obj$fn(obj$par); g0 <- obj$gr(obj$par)
    row$setup_sec <- proc.time()[["elapsed"]] - t0
    stopifnot(is.finite(v0), all(is.finite(g0)))

    t1 <- proc.time()[["elapsed"]]
    fit <- stats::nlminb(obj$par, obj$fn, obj$gr,
                         control = list(iter.max = 1000L, eval.max = 2000L))
    row$optim_sec   <- proc.time()[["elapsed"]] - t1
    row$total_sec   <- row$setup_sec + row$optim_sec
    row$objective   <- fit$objective
    row$iterations  <- fit$iterations
    row$evaluations <- unname(fit$evaluations[1])
    row$convergence <- fit$convergence
    row$message     <- fit$message
    gcm <- gc()                       # last column is Mb of "max used"
    row$peak_mb     <- sum(gcm[, ncol(gcm)])
    row$status      <- "ok"

    est <- fit$par
    saveRDS(list(arm = arm, N = N,
                 beta = unname(est[names(est) == "beta"]),
                 theta_rr = unname(est[names(est) == "theta_rr"]),
                 Sigma_B = sigma_B(unname(est[names(est) == "theta_rr"]),
                                   T_TRAITS, Q_LATENT),
                 beta_true = d$beta_true,
                 Sigma_B_true = tcrossprod(d$Lambda_true),
                 objective = fit$objective), rds)
    TRUE
  }, silent = TRUE)

  if (inherits(res, "try-error")) {
    row$status  <- "error"
    row$message <- gsub("[\r\n]+", " ", as.character(res))
  }
  write.csv(row, csv, row.names = FALSE)
  cat(sprintf("[%s] status=%s total=%.1fs outer=%s inner=%s obj=%s\n",
              tag, row$status, row$total_sec %||% NA,
              row$n_outer_par, row$n_inner_par, row$objective))
  invisible(row)
}

`%||%` <- function(a, b) if (is.null(a) || (length(a) == 1L && is.na(a))) b else a


## --- DRIVER -----------------------------------------------------------------

run_driver <- function() {
  dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)
  ## Compile once up front so no worker pays for it.
  suppressWarnings(suppressMessages(library(TMB)))
  build_dll()

  arms <- c("A", "B", "C")
  dead <- character(0)          # arms that have already failed at a smaller N
  rows <- list()

  for (N in GRID_N) {
    for (arm in arms) {
      tag <- sprintf("%s-%d", arm, N)
      csv <- file.path(RUN_DIR, paste0(tag, ".csv"))
      if (arm %in% dead) {
        rows[[tag]] <- data.frame(
          arm = arm, N = N, T = T_TRAITS, q = Q_LATENT, H = H_ORDER,
          n_obs = N * T_TRAITS, n_outer_par = NA_integer_, n_inner_par = NA_integer_,
          setup_sec = NA_real_, optim_sec = NA_real_, total_sec = NA_real_,
          objective = NA_real_, iterations = NA_integer_, evaluations = NA_integer_,
          convergence = NA_integer_, peak_mb = NA_real_,
          status = "not_attempted",
          message = "skipped: this arm already failed at a smaller N",
          stringsAsFactors = FALSE)
        next
      }
      if (file.exists(csv)) {
        prev <- try(read.csv(csv, stringsAsFactors = FALSE), silent = TRUE)
        if (!inherits(prev, "try-error") && identical(prev$status, "ok")) {
          message(sprintf("=== reusing completed arm %s, N = %d ===", arm, N))
          prev$wall_sec <- NA_real_
          rows[[tag]] <- prev
          next
        }
        unlink(csv)
      }
      message(sprintf("=== running arm %s, N = %d (timeout %ds) ===", arm, N, TIMEOUT_SEC))
      t0 <- proc.time()[["elapsed"]]
      st <- suppressWarnings(system2("Rscript", c(shQuote(SCRIPT), arm, N),
                                     stdout = "", stderr = "",
                                     timeout = TIMEOUT_SEC))
      wall <- proc.time()[["elapsed"]] - t0

      if (file.exists(csv)) {
        r <- read.csv(csv, stringsAsFactors = FALSE)
      } else {
        r <- data.frame(
          arm = arm, N = N, T = T_TRAITS, q = Q_LATENT, H = H_ORDER,
          n_obs = N * T_TRAITS, n_outer_par = NA_integer_, n_inner_par = NA_integer_,
          setup_sec = NA_real_, optim_sec = NA_real_, total_sec = NA_real_,
          objective = NA_real_, iterations = NA_integer_, evaluations = NA_integer_,
          convergence = NA_integer_, peak_mb = NA_real_,
          status = if (identical(as.integer(st), 124L)) "timeout" else "crash",
          message = sprintf("subprocess exit status %s after %.0f s wall", st, wall),
          stringsAsFactors = FALSE)
      }
      r$wall_sec <- wall
      rows[[tag]] <- r
      if (!identical(r$status, "ok")) {
        dead <- c(dead, arm)
        message(sprintf("    arm %s marked dead from N = %d onward (%s)", arm, N, r$status))
      }
    }
  }

  out <- do.call(rbind, lapply(rows, function(z) {
    if (is.null(z$wall_sec)) z$wall_sec <- NA_real_; z
  }))
  rownames(out) <- NULL
  write.csv(out, file.path(repo, "dev", "vgh", "ab-random-vs-fixed.csv"),
            row.names = FALSE)
  report(out)
}


## --- REPORT -----------------------------------------------------------------

report <- function(out) {
  cat("\n================ A/B: variational block fixed vs random ================\n")
  cat(sprintf("family = binomial(logit)  q = %d  T = %d  H = %d  n_trials = %d\n",
              Q_LATENT, T_TRAITS, H_ORDER, N_PER_CELL))
  cat(sprintf("timeout = %d s per fit\n\n", TIMEOUT_SEC))

  p <- out[, c("arm", "N", "n_obs", "n_outer_par", "n_inner_par",
               "setup_sec", "optim_sec", "total_sec", "iterations",
               "convergence", "peak_mb", "status")]
  p$setup_sec <- round(p$setup_sec, 2)
  p$optim_sec <- round(p$optim_sec, 2)
  p$total_sec <- round(p$total_sec, 2)
  p$peak_mb   <- round(p$peak_mb, 0)
  print(p, row.names = FALSE)

  ## --- scaling exponents ---
  cat("\n---------------- scaling: slope of log(total_sec) vs log(N) ----------------\n")
  cat("1.0 = linear, 2.0 = quadratic\n\n")
  for (a in sort(unique(out$arm))) {
    s <- out[out$arm == a & out$status == "ok" & is.finite(out$total_sec), ]
    if (nrow(s) < 3L) {
      cat(sprintf("arm %s: only %d completed point(s) -- no slope fitted\n", a, nrow(s)))
      next
    }
    fm <- stats::lm(log(total_sec) ~ log(N), data = s)
    ci <- stats::confint(fm, "log(N)", level = 0.95)
    cat(sprintf("arm %s: slope = %.3f   95%% CI [%.3f, %.3f]   (n = %d points, R^2 = %.4f)\n",
                a, unname(coef(fm)["log(N)"]), ci[1], ci[2], nrow(s),
                summary(fm)$r.squared))
  }

  ## --- estimate agreement between arms ---
  cat("\n---------------- fixed-parameter agreement between arms ----------------\n")
  cat("Objective VALUES are NOT comparable across arms (see header).\n")
  cat("beta is directly comparable; theta_rr is not (column sign flips), so\n")
  cat("Sigma_B = Lambda Lambda' is compared instead.\n\n")
  ok <- out[out$status == "ok", ]
  for (N in sort(unique(ok$N))) {
    fs <- lapply(c("A", "B", "C"), function(a) {
      f <- file.path(RUN_DIR, sprintf("%s-%d.rds", a, N))
      if (file.exists(f)) readRDS(f) else NULL
    })
    names(fs) <- c("A", "B", "C")
    if (is.null(fs$A)) next
    for (a in c("B", "C")) {
      if (is.null(fs[[a]])) next
      cat(sprintf("N = %-5d  A vs %s :  max|dbeta| = %.3e   max|dSigma_B| = %.3e   |dObj| = %.4f\n",
                  N, a,
                  max(abs(fs$A$beta - fs[[a]]$beta)),
                  max(abs(fs$A$Sigma_B - fs[[a]]$Sigma_B)),
                  abs(fs$A$objective - fs[[a]]$objective)))
    }
  }

  ## --- recovery sanity: are these real optima at all? ---
  cat("\n---------------- recovery vs the simulation truth ----------------\n")
  for (N in sort(unique(ok$N))) {
    for (a in c("A", "B", "C")) {
      f <- file.path(RUN_DIR, sprintf("%s-%d.rds", a, N))
      if (!file.exists(f)) next
      z <- readRDS(f)
      cat(sprintf("arm %s N = %-5d  max|beta - beta_true| = %.4f   max|Sigma_B - Sigma_B_true| = %.4f\n",
                  a, N, max(abs(z$beta - z$beta_true)),
                  max(abs(z$Sigma_B - z$Sigma_B_true))))
    }
  }

  cat("\nwritten: dev/vgh/ab-random-vs-fixed.csv\n")
}


## --- entry point ------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) >= 2L) {
  run_one(args[1], as.integer(args[2]))
} else {
  run_driver()
}
