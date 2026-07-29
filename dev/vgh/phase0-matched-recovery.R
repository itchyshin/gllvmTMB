## ---------------------------------------------------------------------------
## phase0-matched-recovery.R -- MATCHED-DATA recovery comparison.
##
## Every previous VGH-vs-va_r3 recovery comparison in this repo was CROSS-DGP
## (different simulations, trait counts, seeds), so the numbers could not be
## compared.  Here each (family, n, seed) cell simulates ONCE and every arm is
## fitted on that identical dataset, which makes the comparison PAIRED.
##
## ARMS
##   vgh        dev/vgh/vgh-engine.R :: vgh_fit()                (Q = 15)
##   va_r3_gh   R/va-r3-proto.R      :: .va_r3_fit(eval_method = "gh")  (H = 15)
##   va_r3_jj   R/va-r3-proto.R      :: .va_r3_fit(eval_method = "jj")  (binomial only)
##   laplace    gllvmTMB() public entry point, latent(1|site, d=2, unique=FALSE)
##
## METRICS (all rotation-invariant)
##   rel_frob  = ||Sigma_hat - Sigma_true||_F / ||Sigma_true||_F
##   atten_F   = ||L_hat||_F / ||L_true||_F     <- the coordinator's definition
##   atten_tr  = trace(Sigma_hat) / trace(Sigma_true)
##   Because ||L||_F^2 = trace(L L') = trace(Sigma), atten_tr = atten_F^2 exactly.
##   BOTH are reported because the loose numbers in circulation use DIFFERENT
##   ones: dev/three-engine-demo.md reports trace ratios (0.668, 0.892) while
##   the VGH prototype probe reported ~0.99 on the ||L||_F scale.  0.668 on the
##   trace scale is 0.817 on the ||L||_F scale -- they were never comparable.
##
## Usage
##   Rscript dev/vgh/phase0-matched-recovery.R                 # driver (full grid)
##   Rscript dev/vgh/phase0-matched-recovery.R smoke           # one tiny cell
##   Rscript dev/vgh/phase0-matched-recovery.R binomial 200 1  # one worker cell
## ---------------------------------------------------------------------------

repo    <- "/private/tmp/gllvmtmb-vgh"
RUN_DIR <- file.path(repo, "dev", "vgh", "phase0-runs")
SCRIPT  <- file.path(repo, "dev", "vgh", "phase0-matched-recovery.R")

T_TRAITS   <- 20L
Q_LATENT   <- 2L
H_ORDER    <- 15L     # va_r3 quadrature order AND vgh_fit's Q
N_GRID     <- c(200L, 400L, 800L)
FAMILIES   <- c("binomial", "poisson")
SEEDS      <- 1:12    # >= 10 required; 12 used
BASE_SEED  <- 20260729L
N_STARTS   <- 4L      # va_r3 production default; see the note in the report
ARM_LIMIT  <- 900     # per-ARM elapsed limit (seconds)
WORKER_CAP <- 3600    # per-WORKER subprocess backstop (seconds)
## 6 (not 20): the A/B scaling grid is still finishing in this worktree, so the
## box is shared.  Recovery metrics are unaffected by CPU contention; the
## `seconds` column is therefore INDICATIVE ONLY and is not a clean benchmark.
N_WORKERS  <- 6L

suppressWarnings(suppressMessages({
  library(TMB)
}))


## --- DGP: one dataset, exposed in every shape the arms need ----------------
simulate_cell <- function(family, n, seed) {
  set.seed(BASE_SEED + 1000L * seed +
             switch(family, binomial = 0L, poisson = 500000L))
  T <- T_TRAITS; q <- Q_LATENT
  Lambda_true <- matrix(rnorm(T * q, 0, 0.7), T, q)
  beta_true   <- if (family == "binomial") rnorm(T, 0, 0.3) else rnorm(T, 0.4, 0.3)
  U <- matrix(rnorm(n * q), n, q)
  eta <- matrix(beta_true, n, T, byrow = TRUE) + U %*% t(Lambda_true)
  Y <- if (family == "binomial") {
    matrix(rbinom(n * T, 1L, plogis(eta)), n, T)
  } else {
    matrix(rpois(n * T, exp(pmin(eta, 8))), n, T)
  }
  ## long format, unit-major, 1-based ids; X = T trait dummies (per-trait
  ## intercepts, matching the DGP and matching vgh_fit's per-response Beta).
  unit_id  <- rep(seq_len(n), each = T)
  trait_id <- rep(seq_len(T), times = n)
  Xl <- matrix(0, n * T, T)
  Xl[cbind(seq_len(n * T), trait_id)] <- 1
  ## wide data.frame for the public gllvmTMB() entry point
  df <- as.data.frame(Y); names(df) <- paste0("t", seq_len(T))
  df$site <- factor(seq_len(n))
  list(family = family, n = n, seed = seed, T = T, q = q,
       Y = Y, y_long = as.numeric(t(Y)),      # unit-major matches unit_id/trait_id
       X_long = Xl, unit_id = unit_id, trait_id = trait_id,
       n_trials = rep(1L, n * T), df = df,
       Lambda_true = Lambda_true, Sigma_true = tcrossprod(Lambda_true),
       beta_true = beta_true)
}


## --- metrics ---------------------------------------------------------------
metrics <- function(Sigma_hat, Sigma_true) {
  if (is.null(Sigma_hat) || !is.matrix(Sigma_hat) ||
      any(dim(Sigma_hat) != dim(Sigma_true)) || any(!is.finite(Sigma_hat))) {
    return(list(rel_frob = NA_real_, atten_F = NA_real_, atten_tr = NA_real_,
                degenerate = NA))
  }
  tr_h <- sum(diag(Sigma_hat)); tr_t <- sum(diag(Sigma_true))
  atr  <- tr_h / tr_t
  aF   <- sqrt(max(atr, 0))
  list(rel_frob = norm(Sigma_hat - Sigma_true, "F") / norm(Sigma_true, "F"),
       atten_F = aF, atten_tr = atr,
       degenerate = (aF > 2) || (aF < 0.2))
}

blank_row <- function(d, arm) {
  data.frame(family = d$family, n = d$n, seed = d$seed, T = d$T, q = d$q,
             H = H_ORDER, arm = arm, seconds = NA_real_,
             rel_frob = NA_real_, atten_F = NA_real_, atten_tr = NA_real_,
             degenerate = NA, status = "error", conv = NA_integer_,
             health = NA_character_, message = "", stringsAsFactors = FALSE)
}

## Run one arm under an elapsed limit; never let it kill the worker.
run_arm <- function(d, arm, fn) {
  row <- blank_row(d, arm)
  t0 <- proc.time()[["elapsed"]]
  res <- tryCatch({
    setTimeLimit(elapsed = ARM_LIMIT, transient = TRUE)
    on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)
    fn(d)
  }, error = function(e) structure(conditionMessage(e), class = "arm_error"))
  row$seconds <- proc.time()[["elapsed"]] - t0
  if (inherits(res, "arm_error")) {
    msg <- as.character(res)
    row$status  <- if (grepl("reached elapsed time limit|reached CPU time limit", msg))
      "timeout" else "error"
    row$message <- gsub("[\r\n]+", " ", msg)
    return(row)
  }
  m <- metrics(res$Sigma_hat, d$Sigma_true)
  row$rel_frob   <- m$rel_frob
  row$atten_F    <- m$atten_F
  row$atten_tr   <- m$atten_tr
  row$degenerate <- m$degenerate
  row$status     <- if (is.na(m$rel_frob)) "no_estimate" else "ok"
  row$conv       <- res$conv %||% NA_integer_
  row$health     <- res$health %||% NA_character_
  row$message    <- res$message %||% ""
  row
}
`%||%` <- function(a, b) if (is.null(a)) b else a


## --- arms ------------------------------------------------------------------
arm_vgh <- function(d) {
  fam <- if (d$family == "binomial") "binomial" else "poisson"
  fit <- vgh_fit(d$Y, X = matrix(1, nrow(d$Y), 1L), d = Q_LATENT,
                 family = fam, Q = H_ORDER, maxit = 200L, tol = 1e-8)
  list(Sigma_hat = tcrossprod(fit$Lambda),
       conv = NA_integer_,
       health = paste0("sweeps=", fit$sweeps),
       message = sprintf("elbo=%.4f", fit$elbo))
}

arm_va_r3 <- function(d, eval_method) {
  fam <- if (d$family == "binomial") "binomial" else "poisson"
  lnk <- if (d$family == "binomial") "logit" else "log"
  fit <- .va_r3_fit(y = d$y_long, n_trials = d$n_trials, X = d$X_long,
                    unit_id = d$unit_id, trait_id = d$trait_id, q = Q_LATENT,
                    N = d$n, T = d$T, family = fam, link = lnk,
                    H = H_ORDER, eval_method = eval_method,
                    n_starts = N_STARTS, silent = TRUE)
  S <- if (is.list(fit$report) && is.matrix(fit$report$Sigma_B))
    fit$report$Sigma_B else NULL
  list(Sigma_hat = S,
       conv = tryCatch(as.integer(fit$best$convergence), error = function(e) NA_integer_),
       health = paste0(fit$status, "/healthy=", fit$health$healthy_starts,
                       "of", fit$health$attempted_starts),
       message = sprintf("tier=%s maxgrad=%.2e", fit$eval_method,
                         tryCatch(fit$best$max_abs_gradient, error = function(e) NA_real_)))
}

arm_laplace <- function(d) {
  f <- stats::reformulate(
    c("1", sprintf("latent(1 | site, d = %d, unique = FALSE)", Q_LATENT)),
    response = sprintf("traits(%s)",
                       paste0("t", seq_len(d$T), collapse = ", ")))
  fam <- if (d$family == "binomial") stats::binomial() else stats::poisson()
  fit <- gllvmTMB::gllvmTMB(f, data = d$df, family = fam)
  S <- tryCatch(gllvmTMB::extract_Sigma_B(fit)$Sigma_B, error = function(e) NULL)
  list(Sigma_hat = if (is.null(S)) NULL else as.matrix(S),
       conv = tryCatch(as.integer(fit$opt$convergence), error = function(e) NA_integer_),
       health = tryCatch(paste(unlist(fit$fit_health)[1:2], collapse = "/"),
                         error = function(e) NA_character_),
       message = tryCatch(as.character(fit$opt$message)[1], error = function(e) ""))
}


## .va_r3_load_dll() builds into file.path(tempdir(), "gllvmTMB-va-r3-<md5>"),
## and tempdir() is session-specific, so every worker subprocess would recompile
## the template (~25 s each).  Pre-populate that directory from the cached build
## the A/B script already produced, so .va_r3_load_dll() finds the .so and skips
## compilation.  Nothing in the package is modified.
BUILD_CACHE <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/faeb944c-5ca6-48e0-a5c5-11966357d7d8/scratchpad/va-r3-build"

prime_va_r3_dll <- function() {
  src   <- file.path(repo, "inst", "tmb", "gllvmTMB_va_r3.cpp")
  stamp <- unname(tools::md5sum(src))
  ext   <- .Platform$dynlib.ext
  cache_cpp <- file.path(BUILD_CACHE, "gllvmTMB_va_r3.cpp")
  cache_so  <- file.path(BUILD_CACHE, paste0("gllvmTMB_va_r3", ext))
  if (!file.exists(cache_so) ||
      !identical(unname(tools::md5sum(cache_cpp)), stamp)) return(invisible(FALSE))
  bdir <- file.path(tempdir(), paste0("gllvmTMB-va-r3-", stamp))
  dir.create(bdir, recursive = TRUE, showWarnings = FALSE)
  file.copy(src, file.path(bdir, "gllvmTMB_va_r3.cpp"), overwrite = TRUE)
  file.copy(cache_so, file.path(bdir, paste0("gllvmTMB_va_r3", ext)), overwrite = TRUE)
  invisible(TRUE)
}


## --- worker: one (family, n, seed) cell, ALL arms on the SAME data ---------
run_cell <- function(family, n, seed, out_csv = NULL) {
  Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1",
             VECLIB_MAXIMUM_THREADS = "1")
  source(file.path(repo, "dev", "vgh", "vgh-engine.R"), local = FALSE)
  source(file.path(repo, "R", "va-r3-proto.R"), local = FALSE)
  prime_va_r3_dll()
  suppressMessages(requireNamespace("gllvmTMB", quietly = TRUE))

  d <- simulate_cell(family, n, seed)
  rows <- list(
    run_arm(d, "vgh",      arm_vgh),
    run_arm(d, "va_r3_gh", function(dd) arm_va_r3(dd, "gh")),
    run_arm(d, "laplace",  arm_laplace))
  if (family == "binomial") {
    rows[[length(rows) + 1L]] <-
      run_arm(d, "va_r3_jj", function(dd) arm_va_r3(dd, "jj"))
  }
  out <- do.call(rbind, rows)
  if (!is.null(out_csv)) write.csv(out, out_csv, row.names = FALSE)
  out
}


## --- driver ----------------------------------------------------------------
run_driver <- function() {
  dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)
  jobs <- expand.grid(seed = SEEDS, n = N_GRID, family = FAMILIES,
                      stringsAsFactors = FALSE)
  ## largest cells first so the long pole starts early
  jobs <- jobs[order(-jobs$n, jobs$family, jobs$seed), ]
  todo <- jobs[!file.exists(file.path(RUN_DIR, sprintf("%s-%d-%d.csv",
                                                       jobs$family, jobs$n, jobs$seed))), ]
  message(sprintf("phase0: %d cells total, %d to run, %d workers",
                  nrow(jobs), nrow(todo), N_WORKERS))

  if (nrow(todo)) {
    parallel::mclapply(seq_len(nrow(todo)), function(i) {
      j <- todo[i, ]
      csv <- file.path(RUN_DIR, sprintf("%s-%d-%d.csv", j$family, j$n, j$seed))
      st <- suppressWarnings(system2("Rscript",
        c(shQuote(SCRIPT), j$family, j$n, j$seed),
        stdout = FALSE, stderr = FALSE, timeout = WORKER_CAP))
      if (!file.exists(csv)) {
        write.csv(transform(blank_row(list(family = j$family, n = j$n,
                                           seed = j$seed, T = T_TRAITS, q = Q_LATENT),
                                      "ALL"),
                            status = "worker_timeout_or_crash",
                            message = paste("exit", st)), csv, row.names = FALSE)
      }
      NULL
    }, mc.cores = N_WORKERS, mc.preschedule = FALSE)
  }

  f <- list.files(RUN_DIR, "[.]csv$", full.names = TRUE)
  out <- do.call(rbind, lapply(f, read.csv, stringsAsFactors = FALSE))
  out <- out[order(out$family, out$n, out$seed, out$arm), ]
  write.csv(out, file.path(repo, "dev", "vgh", "phase0-matched-recovery.csv"),
            row.names = FALSE)
  analyse(out)
}


## --- aggregation, paired tests, markdown ------------------------------------
analyse <- function(out) {
  md <- c("# Phase 0 -- matched-data recovery: VGH vs va_r3 vs Laplace", "",
    sprintf("Generated %s.  T = %d traits, q = d = %d, H = Q = %d, seeds = %d per cell.",
            format(Sys.Date()), T_TRAITS, Q_LATENT, H_ORDER, length(SEEDS)),
    sprintf("va_r3 ran with its production `n_starts = %d` health gate; VGH and Laplace are single-start.",
            N_STARTS),
    "", "Every arm in a cell is fitted on the SAME simulated dataset (same seed),",
    "so all comparisons below are PAIRED.", "",
    "`atten_F` = ||L_hat||_F/||L_true||_F.  `atten_tr` = trace(Sigma_hat)/trace(Sigma_true) = atten_F^2.",
    "A value BELOW 1 means Sigma_B is UNDER-estimated (shrinkage); ABOVE 1 means INFLATED.",
    "")

  ok <- out[out$status == "ok" & !is.na(out$rel_frob), ]

  ## ---- per-cell aggregates ----
  md <- c(md, "## Per-cell aggregates (median [IQR])", "",
          "| family | n | arm | fits ok | rel. Frobenius | atten_F | atten_tr | median s | degenerate |",
          "|---|---:|---|---:|---|---|---|---:|---:|")
  agg <- list()
  for (fm in FAMILIES) for (nn in N_GRID) for (a in c("vgh","va_r3_gh","va_r3_jj","laplace")) {
    s <- ok[ok$family == fm & ok$n == nn & ok$arm == a, ]
    all_s <- out[out$family == fm & out$n == nn & out$arm == a, ]
    if (!nrow(all_s)) next
    q1 <- function(z) stats::quantile(z, c(.25,.5,.75), na.rm = TRUE, names = FALSE)
    if (nrow(s)) {
      rf <- q1(s$rel_frob); af <- q1(s$atten_F); at <- q1(s$atten_tr)
      md <- c(md, sprintf("| %s | %d | %s | %d/%d | %.3f [%.3f, %.3f] | %.3f [%.3f, %.3f] | %.3f [%.3f, %.3f] | %.1f | %d |",
        fm, nn, a, nrow(s), nrow(all_s), rf[2], rf[1], rf[3], af[2], af[1], af[3],
        at[2], at[1], at[3], stats::median(s$seconds, na.rm = TRUE),
        sum(s$degenerate, na.rm = TRUE)))
      agg[[length(agg)+1L]] <- data.frame(family=fm, n=nn, arm=a, n_ok=nrow(s),
        rel_frob_med=rf[2], atten_F_med=af[2], atten_tr_med=at[2],
        sec_med=stats::median(s$seconds, na.rm=TRUE), stringsAsFactors=FALSE)
    } else {
      md <- c(md, sprintf("| %s | %d | %s | 0/%d | -- | -- | -- | -- | -- |",
                          fm, nn, a, nrow(all_s)))
    }
  }

  ## ---- failure ledger ----
  bad <- out[out$status != "ok", ]
  md <- c(md, "", "## Non-ok fits", "")
  if (!nrow(bad)) md <- c(md, "None -- every arm returned an estimate in every cell.", "")
  else {
    md <- c(md, "| family | n | arm | status | n |", "|---|---:|---|---|---:|")
    tb <- as.data.frame(table(bad$family, bad$n, bad$arm, bad$status))
    tb <- tb[tb$Freq > 0, ]
    for (i in seq_len(nrow(tb))) md <- c(md, sprintf("| %s | %s | %s | %s | %d |",
      tb$Var1[i], tb$Var2[i], tb$Var3[i], tb$Var4[i], tb$Freq[i]))
    md <- c(md, "")
  }

  ## ---- PAIRED comparisons ----
  md <- c(md, "", "## Paired comparisons (same seed, same data)", "",
    "Per-seed difference `d = metric(VGH) - metric(va_r3_gh)`.  For rel. Frobenius,",
    "d < 0 means VGH is CLOSER to the truth.  Sign test is exact binomial on sign(d).", "",
    "| family | n | pairs | median d(rel.Frob) | 95% CI (Wilcoxon) | VGH better / worse | sign-test p |",
    "|---|---:|---:|---:|---|---|---:|")
  paired <- list()
  for (fm in FAMILIES) for (nn in N_GRID) {
    a <- ok[ok$family==fm & ok$n==nn & ok$arm=="vgh", ]
    b <- ok[ok$family==fm & ok$n==nn & ok$arm=="va_r3_gh", ]
    m <- merge(a[,c("seed","rel_frob","atten_F")], b[,c("seed","rel_frob","atten_F")],
               by="seed", suffixes=c("_vgh","_gh"))
    if (nrow(m) < 2L) { md <- c(md, sprintf("| %s | %d | %d | -- | -- | -- | -- |", fm, nn, nrow(m))); next }
    dd <- m$rel_frob_vgh - m$rel_frob_gh
    better <- sum(dd < 0); worse <- sum(dd > 0)
    bt <- if (better + worse > 0L) stats::binom.test(better, better + worse) else
      list(p.value = NA_real_)
    ci <- tryCatch({
      w <- stats::wilcox.test(dd, conf.int = TRUE, exact = FALSE)
      sprintf("[%.4f, %.4f]", w$conf.int[1], w$conf.int[2])
    }, error = function(e) "--")
    md <- c(md, sprintf("| %s | %d | %d | %+.4f | %s | %d / %d | %.4g |",
                        fm, nn, nrow(m), stats::median(dd), ci, better, worse, bt$p.value))
    paired[[length(paired)+1L]] <- data.frame(family=fm, n=nn, pairs=nrow(m),
      med_d_relfrob=stats::median(dd), better=better, worse=worse,
      p=bt$p.value, stringsAsFactors=FALSE)
  }

  ## ---- the sign question ----
  md <- c(md, "", "## The attenuation SIGN question", "",
    "`docs/design/109-bound-tightness-vs-recovery.md` (sec. ~309-318, tagged AGENT-INFERRED)",
    "argues the Gaussian-VA channel should make exact-GH **over-estimate** Sigma_B,",
    "i.e. `atten_F > 1`.  Matched data, per family and n:", "",
    "| family | n | arm | median atten_F | 95% CI (Wilcoxon) | # above 1 / total | sign-test p vs 1 |",
    "|---|---:|---|---:|---|---|---:|")
  for (fm in FAMILIES) for (nn in N_GRID) for (a in c("vgh","va_r3_gh","va_r3_jj","laplace")) {
    s <- ok[ok$family==fm & ok$n==nn & ok$arm==a, ]
    if (nrow(s) < 2L) next
    above <- sum(s$atten_F > 1); tot <- sum(s$atten_F != 1)
    bt <- if (tot > 0L) stats::binom.test(above, tot) else list(p.value = NA_real_)
    ci <- tryCatch({
      w <- stats::wilcox.test(s$atten_F - 1, conf.int = TRUE, exact = FALSE)
      sprintf("[%.4f, %.4f]", 1 + w$conf.int[1], 1 + w$conf.int[2])
    }, error = function(e) "--")
    md <- c(md, sprintf("| %s | %d | %s | %.4f | %s | %d / %d | %.4g |",
                        fm, nn, a, stats::median(s$atten_F), ci, above, tot, bt$p.value))
  }

  writeLines(md, file.path(repo, "dev", "vgh", "phase0-matched-recovery.md"))
  cat(paste(md, collapse = "\n"), "\n")
  cat("\nwritten: dev/vgh/phase0-matched-recovery.csv and .md\n")
  invisible(list(agg = do.call(rbind, agg), paired = do.call(rbind, paired)))
}


## --- entry point ------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 1L && args[1] == "smoke") {
  dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)
  T_TRAITS <- 8L; N_STARTS <- 1L
  r <- run_cell("binomial", 60L, 1L)
  print(r[, c("arm","seconds","rel_frob","atten_F","atten_tr","status","conv","health","message")])
  r2 <- run_cell("poisson", 60L, 1L)
  print(r2[, c("arm","seconds","rel_frob","atten_F","atten_tr","status","conv","health","message")])
} else if (length(args) >= 3L) {
  dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)
  csv <- file.path(RUN_DIR, sprintf("%s-%s-%s.csv", args[1], args[2], args[3]))
  run_cell(args[1], as.integer(args[2]), as.integer(args[3]), out_csv = csv)
} else if (length(args) == 1L && args[1] == "analyse") {
  f <- list.files(RUN_DIR, "[.]csv$", full.names = TRUE)
  analyse(do.call(rbind, lapply(f, read.csv, stringsAsFactors = FALSE)))
} else {
  run_driver()
}
