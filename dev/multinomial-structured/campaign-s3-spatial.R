## dev/multinomial-structured/campaign-s3-spatial.R
##
## Slice-3 recovery campaign: multinomial() (family_id 16) with
## spatial_latent()/spatial_indep()/spatial_dep() structured random effects
## (the SPDE mode axis), fitting against a KNOWN Matern-field truth.
##
## DGP: n_site points in the unit square, a small fmesher mesh, a TRUE
## Matern field drawn on the engine's own SPDE precision (Q_base = kappa^4 M0
## + 2 kappa^2 M1 + M2, mirroring test-matrix-ordinal-spatial.R's
## `make_ordinal_spatial_paired_fixture()`), loaded onto the K-1
## category-contrast pseudo-traits via a small Lambda_true, softmax-drawn
## response (mirrors dgp-multinomial-structured.R's liability-to-response
## conversion). ONE categorical draw per site.
##
## GATE CHECK (dev/multinomial-structured/gate-check-a-proj.R, run BEFORE
## this campaign / the admission itself): the mesh MUST be built on a
## coordinate frame pre-expanded with the SAME `rep(seq_len(n), each = K-1)`
## convention `expand_multinomial_response()` uses internally -- this DGP
## does that pre-expansion itself (`.build_mesh_for_multinomial()` below).
##
## spatial_dep() is VERIFIED (R/brms-sugar.R desugar + test-matrix-
## multinomial-spatial.R's equivalence test) to be spatial_latent(d =
## n_traits) under a documentary keyword -- same engine slot, not a separate
## one.
##
## Modes:
##   --mode timing   1 seed, 1 fit  (spatial_latent only) -> elapsed time  (D-139 timing fit)
##   --mode smoke     2 seeds x 3 keywords -> str() of results             (smoke gate)
##   --mode full      20 seeds x 3 keywords, parallel::mclapply            (the campaign)
##
## Usage:
##   Rscript campaign-s3-spatial.R --mode timing
##   Rscript campaign-s3-spatial.R --mode smoke
##   OPENBLAS_NUM_THREADS=1 CAMPAIGN_CORES=20 \
##     Rscript campaign-s3-spatial.R --mode full
##
## `--mode full` is NOT run as part of this task (D-139 + Design 122: gated
## on dev/multinomial-structured/pass-criteria-s3.md's DRAFT status, pending
## Shinichi's sign-off -- see that file). This environment has fmesher but
## NOT INLA; both `make_mesh()` and the base SPDE engine are verified to need
## only fmesher, so timing/smoke below ARE run here (not skipped).

Sys.setenv(OPENBLAS_NUM_THREADS = "1")

.here <- tryCatch(
  dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "."
)
if (length(.here) == 0L || !nzchar(.here)) .here <- "."

PKG_DIR  <- Sys.getenv("GLLVMTMB_DIR", ".")
N_CORES  <- min(96L, max(1L, as.integer(Sys.getenv("CAMPAIGN_CORES", "4"))))
RESULTS_DIR <- file.path(.here, "results")

.args <- commandArgs(trailingOnly = TRUE)
.mode_idx <- which(.args == "--mode")
MODE <- if (length(.mode_idx) == 1L && length(.args) > .mode_idx) {
  .args[[.mode_idx + 1L]]
} else {
  "smoke"
}
if (!MODE %in% c("timing", "smoke", "full")) {
  stop("--mode must be one of: timing, smoke, full (got '", MODE, "')")
}

KEYWORDS <- c("spatial_latent", "spatial_indep", "spatial_dep")

`%||%` <- function(a, b) if (is.null(a)) b else a

## ---- DGP: n_site points, a true Matern field, softmax-drawn response -----
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
  ## Mesh MUST be built on the POST-expansion coordinate frame (gate check):
  ## each site's coordinates repeated L times, consecutive blocks, matching
  ## expand_multinomial_response()'s own rep(seq_len(n), each = L).
  idx <- rep(seq_len(n_site), each = L)
  mesh <- gllvmTMB::make_mesh(df[idx, , drop = FALSE], c("x", "y"), cutoff = cutoff)
  n_mesh <- ncol(mesh$A_st)

  M0 <- mesh$spde$c0; M1 <- mesh$spde$g1; M2 <- mesh$spde$g2
  Q_base <- as.matrix(kappa_true^4 * M0 + 2 * kappa_true^2 * M1 + M2)
  Sigma_base <- solve(Q_base)
  scale_om <- 1 / sqrt(mean(diag(Sigma_base)))
  chol_S <- chol(Sigma_base + 1e-8 * diag(n_mesh))
  omega_true <- scale_om * as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))

  ## Site-level field values (one per site, NOT per expanded row): use the
  ## first row of each L-row block of the (pre-expanded) mesh projector,
  ## since every row in a block shares the same site coordinates.
  A_site <- as.matrix(mesh$A_st)[seq(1L, n_site * L, by = L), , drop = FALSE]
  omega_per_site <- as.numeric(A_site %*% omega_true)

  ## Loadings: one shared field, moderate same-sign loadings on both
  ## contrasts (a non-trivial cross-contrast field correlation).
  Lambda_true <- matrix(sigma_field * c(1, 0.7)[seq_len(L)], nrow = L, ncol = 1L)
  eta_field <- outer(omega_per_site, Lambda_true[, 1L])   # n_site x L

  eta <- cbind(0, sweep(eta_field, 2, b0, `+`))
  P <- exp(eta - apply(eta, 1L, max)); P <- P / rowSums(P)
  y <- vapply(seq_len(n_site), function(i) sample.int(K, 1L, prob = P[i, ]), integer(1))

  df$trait <- factor("cat")
  df$value <- factor(y)

  list(data = df, mesh = mesh, kappa_true = kappa_true, range_true = range_true,
       sigma_field = sigma_field, Lambda_true = Lambda_true, K = K, L = L,
       n_site = n_site, seed = seed)
}

## ---- one fit: keyword x seed -----------------------------------------------
.fit_one <- function(keyword, n_site, seed, K = 3L, d = NULL) {
  d <- if (is.null(d)) K - 1L else d
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_spatial(n_site = n_site, seed = seed, K = K)
    df <- dgp$data

    form <- switch(keyword,
      spatial_latent = value ~ 0 + trait + spatial_latent(0 + trait | coords, d = d),
      spatial_indep  = value ~ 0 + trait + spatial_indep(0 + trait | coords),
      spatial_dep    = value ~ 0 + trait + spatial_dep(0 + trait | coords),
      stop("unknown keyword: ", keyword)
    )

    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      form, data = df, family = multinomial(), trait = "trait", mesh = dgp$mesh
    )))

    conv   <- fit$opt$convergence
    pdhess <- isTRUE(fit$sd_report$pdHess)
    kappa_hat <- tryCatch(as.numeric(fit$report$kappa), error = function(e) NA_real_)
    range_hat <- if (is.finite(kappa_hat) && kappa_hat > 0) sqrt(8) / kappa_hat else NA_real_

    list(keyword = keyword, n_site = n_site, seed = seed, K = K, d = d,
         convergence = conv, pdHess = pdhess,
         kappa_hat = kappa_hat, range_hat = range_hat, range_true = dgp$range_true,
         error = NA_character_)
  }, error = function(e) {
    list(keyword = keyword, n_site = n_site, seed = seed, K = K, d = d,
         convergence = NA_integer_, pdHess = NA,
         kappa_hat = NA_real_, range_hat = NA_real_, range_true = NA_real_,
         error = conditionMessage(e))
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

.row_from_result <- function(r) {
  data.frame(
    keyword = r$keyword, n_site = r$n_site, seed = r$seed, K = r$K, d = r$d,
    convergence = r$convergence %||% NA_integer_, pdHess = isTRUE(r$pdHess),
    kappa_hat = r$kappa_hat, range_hat = r$range_hat, range_true = r$range_true,
    range_ratio = r$range_hat / r$range_true,
    elapsed_sec = r$elapsed_sec, error = r$error %||% NA_character_,
    stringsAsFactors = FALSE
  )
}

## =============================================================================
if (MODE == "timing") {
  cat("MODE: timing -- 1 seed, 1 fit (spatial_latent, n_site = 300, seed = 1)\n")
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  r <- .fit_one("spatial_latent", n_site = 300L, seed = 1L)
  cat(sprintf("elapsed: %.2f sec | convergence=%s pdHess=%s range_hat=%s error=%s\n",
              r$elapsed_sec, r$convergence, r$pdHess,
              format(r$range_hat, digits = 3), r$error %||% "none"))
  cat("D-139: if this fit is representative, projected full run (60 fits) ~= ",
      round(r$elapsed_sec * 60 / 60, 1), " min. >30 min -> pre-run test + approval before --mode full.\n")

} else if (MODE == "smoke") {
  cat("MODE: smoke -- 2 seeds x 3 keywords (n_site = 100)\n")
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  grid <- expand.grid(keyword = KEYWORDS, seed = c(1L, 2L), stringsAsFactors = FALSE)
  res <- lapply(seq_len(nrow(grid)), function(i) {
    .fit_one(grid$keyword[i], n_site = 100L, seed = grid$seed[i])
  })
  for (r in res) { cat("---\n"); str(r, max.level = 1) }

} else if (MODE == "full") {
  N_SEED <- 20L
  ## n_site = 300, unit square, small mesh (task brief). Not calibrated
  ## against a prior spike (unlike S1/S2's n_sp = 800); --mode full is
  ## explicitly NOT run in this task, so this is a starting point, not a
  ## validated band -- see pass-criteria-s3.md.
  N_SITE <- 300L
  cat(sprintf("MODE: full -- %d seeds x %d keywords, n_site=%d, cores=%d\n",
              N_SEED, length(KEYWORDS), N_SITE, N_CORES))
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  grid <- expand.grid(keyword = KEYWORDS, seed = seq_len(N_SEED) + 300L,
                       stringsAsFactors = FALSE)
  res <- parallel::mclapply(seq_len(nrow(grid)), function(i) {
    .fit_one(grid$keyword[i], n_site = N_SITE, seed = grid$seed[i])
  }, mc.cores = N_CORES)

  if (!dir.exists(RESULTS_DIR)) dir.create(RESULTS_DIR, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  saveRDS(res, file.path(RESULTS_DIR, sprintf("s3-results-%s.rds", stamp)))

  summ <- do.call(rbind, lapply(res, .row_from_result))
  write.csv(summ, file.path(RESULTS_DIR, sprintf("s3-summary-%s.csv", stamp)),
            row.names = FALSE)
  cat("wrote:\n  ", file.path(RESULTS_DIR, sprintf("s3-results-%s.rds", stamp)), "\n  ",
      file.path(RESULTS_DIR, sprintf("s3-summary-%s.csv", stamp)), "\n")
  print(summ)
}
