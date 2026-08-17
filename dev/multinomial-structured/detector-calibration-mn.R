## dev/multinomial-structured/detector-calibration-mn.R
##
## Detector S3 calibration for `.gllvmTMB_multinomial_degeneracy_row()`
## (component "multinomial_contrast_degeneracy", R/diagnose.R, arms
## M1/contrast_variance_collapse, M2/contrast_rail, M3/spatial_range_collapse).
## Pre-registered criteria: pass-criteria-detector-mn.md (frozen BEFORE this
## script ran).
##
## Refits every labeled cell with the IDENTICAL seeds/DGP calls already used
## to establish the Arc-1 labels (pass-criteria-s2.md/s3.md), then calls
## check_gllvmTMB() on the ACTUAL fit object and parses the
## multinomial_contrast_degeneracy row's status/message text for the "arms:"
## list -- this is evidence about the detector, not a re-derivation of the
## committed summary-CSV numbers (see pass-criteria-detector-mn.md's "Why
## refit" section).
##
## Modes:
##   --mode timing   4 fits, one per family of cell -> elapsed time (D-139)
##   --mode full     all cells/seeds, parallel::mclapply
##
## Usage:
##   Rscript detector-calibration-mn.R --mode timing
##   OPENBLAS_NUM_THREADS=1 CAMPAIGN_CORES=8 \
##     Rscript detector-calibration-mn.R --mode full

Sys.setenv(OPENBLAS_NUM_THREADS = "1")

.here <- tryCatch(
  dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "."
)
if (length(.here) == 0L || !nzchar(.here)) .here <- "."
source(file.path(.here, "dgp-multinomial-structured.R"))
source(file.path(.here, "dgp-multinomial-replicated.R"))

PKG_DIR  <- Sys.getenv("GLLVMTMB_DIR", file.path(.here, "..", ".."))
N_CORES  <- min(96L, max(1L, as.integer(Sys.getenv("CAMPAIGN_CORES", "8"))))
RESULTS_DIR <- file.path(.here, "results")

`%||%` <- function(a, b) if (is.null(a)) b else a

.args <- commandArgs(trailingOnly = TRUE)
.mode_idx <- which(.args == "--mode")
MODE <- if (length(.mode_idx) == 1L && length(.args) > .mode_idx) {
  .args[[.mode_idx + 1L]]
} else {
  "timing"
}
if (!MODE %in% c("timing", "full")) {
  stop("--mode must be one of: timing, full (got '", MODE, "')")
}

## ---- DGP duplicated from campaign-s3-spatial.R -----------------------------
## campaign-s3-spatial.R has no sys.nframe()==0 guard around its MODE
## dispatch block (unlike dgp-multinomial-structured.R/dgp-multinomial-
## replicated.R), so sourcing it directly would execute its own --mode smoke
## default as a side effect. This is a verbatim copy of its
## dgp_multinomial_spatial() (lines 71-117 at commit 8f233231's tree) so this
## script can call the SAME DGP without that side effect.
dgp_multinomial_spatial <- function(n_site, seed, K = 3L,
                                     range_true = 0.3, sigma_field = 0.8,
                                     b0 = c(0.2, -0.3), cutoff = 0.1) {
  set.seed(seed)
  L <- K - 1L
  kappa_true <- sqrt(8) / range_true

  df <- data.frame(
    site = factor(seq_len(n_site)),
    x = stats::runif(n_site), y = stats::runif(n_site)
  )
  idx <- rep(seq_len(n_site), each = L)
  mesh <- gllvmTMB::make_mesh(df[idx, , drop = FALSE], c("x", "y"), cutoff = cutoff)
  n_mesh <- ncol(mesh$A_st)

  M0 <- mesh$spde$c0; M1 <- mesh$spde$g1; M2 <- mesh$spde$g2
  Q_base <- as.matrix(kappa_true^4 * M0 + 2 * kappa_true^2 * M1 + M2)
  Sigma_base <- solve(Q_base)
  scale_om <- 1 / sqrt(mean(diag(Sigma_base)))
  chol_S <- chol(Sigma_base + 1e-8 * diag(n_mesh))
  omega_true <- scale_om * as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))

  A_site <- as.matrix(mesh$A_st)[seq(1L, n_site * L, by = L), , drop = FALSE]
  omega_per_site <- as.numeric(A_site %*% omega_true)

  Lambda_true <- matrix(sigma_field * c(1, 0.7)[seq_len(L)], nrow = L, ncol = 1L)
  eta_field <- outer(omega_per_site, Lambda_true[, 1L])

  eta <- cbind(0, sweep(eta_field, 2, b0, `+`))
  P <- exp(eta - apply(eta, 1L, max)); P <- P / rowSums(P)
  y <- vapply(seq_len(n_site), function(i) sample.int(K, 1L, prob = P[i, ]), integer(1))

  df$trait <- factor("cat")
  df$value <- factor(y)

  list(data = df, mesh = mesh, kappa_true = kappa_true, range_true = range_true,
       sigma_field = sigma_field, Lambda_true = Lambda_true, K = K, L = L,
       n_site = n_site, seed = seed)
}

## ---- parse the multinomial_contrast_degeneracy row -------------------------
.mn_verdict <- function(fit) {
  chk <- tryCatch(check_gllvmTMB(fit), error = function(e) NULL)
  if (is.null(chk)) {
    return(list(present = FALSE, status = NA_character_,
                m1 = FALSE, m2 = FALSE, m3 = FALSE, message = NA_character_))
  }
  row <- chk[chk$component == "multinomial_contrast_degeneracy", , drop = FALSE]
  if (nrow(row) == 0L) {
    return(list(present = FALSE, status = NA_character_,
                m1 = FALSE, m2 = FALSE, m3 = FALSE, message = NA_character_))
  }
  msg <- row$message[[1L]]
  list(
    present = TRUE, status = row$status[[1L]],
    m1 = grepl("\\bM1\\b", msg), m2 = grepl("\\bM2\\b", msg), m3 = grepl("\\bM3\\b", msg),
    message = msg
  )
}

.result_row <- function(cell, seed, fit, labeled_degenerate, extra = list()) {
  v <- .mn_verdict(fit)
  base <- data.frame(
    cell = cell, seed = seed,
    convergence = fit$opt$convergence %||% NA_integer_,
    pdHess = isTRUE(fit$sd_report$pdHess),
    labeled_degenerate = labeled_degenerate,
    det_present = v$present, det_status = v$status %||% NA_character_,
    det_m1 = isTRUE(v$m1), det_m2 = isTRUE(v$m2), det_m3 = isTRUE(v$m3),
    det_message = v$message %||% NA_character_,
    stringsAsFactors = FALSE
  )
  if (length(extra) > 0L) base <- cbind(base, as.data.frame(extra, stringsAsFactors = FALSE))
  base
}

## ---- per-cell fit functions -------------------------------------------------

fit_deg_m1 <- function(seed) {
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_structured(n_sp = 800L, seed = seed, K = 3L,
                                       rho_true = 0, sd_true = c(0.8, 0.5))
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species, tree = dgp$tree),
      data = dgp$data, family = multinomial(), trait = "trait", unit = "species"
    )))
    Vh <- tryCatch({
      s <- extract_Sigma(fit, level = "phy", part = "shared", link_residual = "none")
      if (is.matrix(s)) s else s$Sigma
    }, error = function(e) matrix(NA_real_, 2L, 2L))
    labeled <- all(is.finite(diag(Vh))) && min(diag(Vh)) < 1e-6
    r <- .result_row("deg_m1_phylo_indep", seed, fit, labeled,
                      extra = list(min_var_hat = if (all(is.finite(diag(Vh)))) min(diag(Vh)) else NA_real_))
    r
  }, error = function(e) {
    data.frame(cell = "deg_m1_phylo_indep", seed = seed, convergence = NA_integer_,
               pdHess = NA, labeled_degenerate = NA, det_present = FALSE,
               det_status = NA_character_, det_m1 = FALSE, det_m2 = FALSE, det_m3 = FALSE,
               det_message = conditionMessage(e), min_var_hat = NA_real_, stringsAsFactors = FALSE)
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

fit_deg_m2 <- function(seed) {
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_structured(n_sp = 800L, seed = seed, K = 3L)
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_dep(0 + trait | species, tree = dgp$tree),
      data = dgp$data, family = multinomial(), trait = "trait", unit = "species"
    )))
    Vh <- tryCatch({
      s <- extract_Sigma(fit, level = "phy", part = "shared", link_residual = "none")
      if (is.matrix(s)) s else s$Sigma
    }, error = function(e) matrix(NA_real_, 2L, 2L))
    rho_hat <- if (all(is.finite(Vh)) && Vh[1, 1] > 0 && Vh[2, 2] > 0) {
      Vh[1, 2] / sqrt(Vh[1, 1] * Vh[2, 2])
    } else NA_real_
    labeled <- is.finite(rho_hat) && abs(rho_hat) >= 0.99
    .result_row("deg_m2_phylo_dep", seed, fit, labeled, extra = list(rho_hat = rho_hat))
  }, error = function(e) {
    data.frame(cell = "deg_m2_phylo_dep", seed = seed, convergence = NA_integer_,
               pdHess = NA, labeled_degenerate = NA, det_present = FALSE,
               det_status = NA_character_, det_m1 = FALSE, det_m2 = FALSE, det_m3 = FALSE,
               det_message = conditionMessage(e), rho_hat = NA_real_, stringsAsFactors = FALSE)
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

fit_deg_m3 <- function(seed) {
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_spatial(n_site = 300L, seed = seed, K = 3L)
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + spatial_indep(0 + trait | coords),
      data = dgp$data, family = multinomial(), trait = "trait", mesh = dgp$mesh
    )))
    pdhess <- isTRUE(fit$sd_report$pdHess)
    kappa_hat <- tryCatch(as.numeric(fit$report$kappa), error = function(e) NA_real_)
    range_hat <- if (is.finite(kappa_hat) && kappa_hat > 0) sqrt(8) / kappa_hat else NA_real_
    labeled <- isTRUE(pdhess) && is.finite(range_hat) && range_hat < 0.02
    .result_row("deg_m3_spatial_indep", seed, fit, labeled, extra = list(range_hat = range_hat))
  }, error = function(e) {
    data.frame(cell = "deg_m3_spatial_indep", seed = seed, convergence = NA_integer_,
               pdHess = NA, labeled_degenerate = NA, det_present = FALSE,
               det_status = NA_character_, det_m1 = FALSE, det_m2 = FALSE, det_m3 = FALSE,
               det_message = conditionMessage(e), range_hat = NA_real_, stringsAsFactors = FALSE)
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

fit_healthy_s4 <- function(seed) {
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_grouped(G = 60L, n_per_g = 15L, seed = seed, K = 3L, sigma_re = 0.6)
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + (1 | group), data = dgp$data, family = multinomial(),
      trait = "trait", unit = "unit"
    )))
    .result_row("healthy_s4_re_int", seed, fit, FALSE)
  }, error = function(e) {
    data.frame(cell = "healthy_s4_re_int", seed = seed, convergence = NA_integer_,
               pdHess = NA, labeled_degenerate = FALSE, det_present = FALSE,
               det_status = NA_character_, det_m1 = FALSE, det_m2 = FALSE, det_m3 = FALSE,
               det_message = conditionMessage(e), stringsAsFactors = FALSE)
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

fit_healthy_s1b <- function(seed) {
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_replicated(n_sp = 300L, n_rep = 5L, seed = seed, K = 3L)
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 2, tree = dgp$tree),
      data = dgp$data, family = multinomial(), trait = "trait",
      unit = "obs", cluster = "species"
    )))
    .result_row("healthy_s1b_phylo_latent_rep", seed, fit, FALSE)
  }, error = function(e) {
    data.frame(cell = "healthy_s1b_phylo_latent_rep", seed = seed, convergence = NA_integer_,
               pdHess = NA, labeled_degenerate = FALSE, det_present = FALSE,
               det_status = NA_character_, det_m1 = FALSE, det_m2 = FALSE, det_m3 = FALSE,
               det_message = conditionMessage(e), stringsAsFactors = FALSE)
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

fit_healthy_d1 <- function(seed) {
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_structured(n_sp = 800L, seed = seed, K = 3L)
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1, tree = dgp$tree),
      data = dgp$data, family = multinomial(), trait = "trait", unit = "species"
    )))
    .result_row("healthy_d1_phylo_latent", seed, fit, FALSE)
  }, error = function(e) {
    data.frame(cell = "healthy_d1_phylo_latent", seed = seed, convergence = NA_integer_,
               pdHess = NA, labeled_degenerate = FALSE, det_present = FALSE,
               det_status = NA_character_, det_m1 = FALSE, det_m2 = FALSE, det_m3 = FALSE,
               det_message = conditionMessage(e), stringsAsFactors = FALSE)
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

fit_null_dgp <- function(seed) {
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_structured(n_sp = 200L, seed = seed, K = 3L,
                                       rho_true = 0, sd_true = c(0, 0))
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_indep(0 + trait | species, tree = dgp$tree),
      data = dgp$data, family = multinomial(), trait = "trait", unit = "species"
    )))
    ## True variance is exactly zero -- M1 firing is BY DESIGN, so
    ## labeled_degenerate = TRUE for bookkeeping symmetry with the other
    ## tables, but this cell is reported SEPARATELY, never folded into the
    ## N=60 healthy-cell specificity bound (pass-criteria-detector-mn.md).
    .result_row("null_phylo_indep", seed, fit, TRUE)
  }, error = function(e) {
    data.frame(cell = "null_phylo_indep", seed = seed, convergence = NA_integer_,
               pdHess = NA, labeled_degenerate = TRUE, det_present = FALSE,
               det_status = NA_character_, det_m1 = FALSE, det_m2 = FALSE, det_m3 = FALSE,
               det_message = conditionMessage(e), stringsAsFactors = FALSE)
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

## =============================================================================
if (MODE == "timing") {
  cat("MODE: timing -- 4 fits, one per cell family (D-139 pilot)\n")
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  pilot <- list(
    m1 = fit_deg_m1(201L),
    m2 = fit_deg_m2(201L),
    m3 = fit_deg_m3(301L),
    s4 = fit_healthy_s4(201L)
  )
  for (nm in names(pilot)) {
    r <- pilot[[nm]]
    cat(sprintf("%s: elapsed=%.2fs conv=%s pdHess=%s det_status=%s\n",
                nm, r$elapsed_sec, r$convergence, r$pdHess, r$det_status))
  }
  total_fits <- 20L + 20L + 20L + 20L + 20L + 20L + 8L  # 128
  blended <- mean(vapply(pilot, function(r) r$elapsed_sec, numeric(1)))
  cat(sprintf(
    "\nD-139: blended pilot rate %.2f sec/fit x %d total fits = %.1f sec sequential (%.1f min).\n",
    blended, total_fits, blended * total_fits, blended * total_fits / 60
  ))
  cat("If <30 min, --mode full may run directly (see pass-criteria-detector-mn.md).\n")

} else if (MODE == "full") {
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  cat(sprintf("MODE: full -- 128 fits total, cores=%d\n", N_CORES))

  run_cell <- function(fn, seeds, label) {
    cat(sprintf("  running %s (%d seeds)...\n", label, length(seeds)))
    res <- parallel::mclapply(seeds, fn, mc.cores = N_CORES)
    do.call(rbind, lapply(res, function(r) {
      ## Coerce to a common column set across cells (extra columns absent ->
      ## NA) so rbind works even though each cell's .result_row() adds
      ## different `extra` diagnostic columns.
      r
    }))
  }
  ## rbind with differing columns: use a helper that unions columns.
  .bind_rows <- function(dfs) {
    all_cols <- unique(unlist(lapply(dfs, names)))
    dfs2 <- lapply(dfs, function(d) {
      missing <- setdiff(all_cols, names(d))
      for (m in missing) d[[m]] <- NA
      d[all_cols]
    })
    do.call(rbind, dfs2)
  }

  cells <- list(
    list(fn = fit_deg_m1,      seeds = 201:220, label = "deg_m1_phylo_indep"),
    list(fn = fit_deg_m2,      seeds = 201:220, label = "deg_m2_phylo_dep"),
    list(fn = fit_deg_m3,      seeds = 301:320, label = "deg_m3_spatial_indep"),
    list(fn = fit_healthy_s4,  seeds = 201:220, label = "healthy_s4_re_int"),
    list(fn = fit_healthy_s1b, seeds = 301:320, label = "healthy_s1b_phylo_latent_rep"),
    list(fn = fit_healthy_d1,  seeds = 401:420, label = "healthy_d1_phylo_latent"),
    list(fn = fit_null_dgp,    seeds = 601:608, label = "null_phylo_indep")
  )

  all_results <- lapply(cells, function(c) {
    res <- parallel::mclapply(c$seeds, c$fn, mc.cores = N_CORES)
    .bind_rows(res)
  })
  summ <- .bind_rows(all_results)

  if (!dir.exists(RESULTS_DIR)) dir.create(RESULTS_DIR, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  out_csv <- file.path(RESULTS_DIR, sprintf("detector-calibration-mn-%s.csv", stamp))
  write.csv(summ, out_csv, row.names = FALSE)
  cat("wrote:\n  ", out_csv, "\n")
  cat(sprintf("total elapsed (sum): %.1f sec\n", sum(summ$elapsed_sec, na.rm = TRUE)))
  print(table(summ$cell, summ$det_status, useNA = "ifany"))
}
