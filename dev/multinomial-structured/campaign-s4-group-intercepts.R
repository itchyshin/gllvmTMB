## dev/multinomial-structured/campaign-s4-group-intercepts.R
##
## Slice-4 recovery campaign: multinomial() (family_id 16) with a generic
## `(1 | group)` random intercept, fitting against the KNOWN truth simulated
## by `dgp_multinomial_grouped()` (dgp-multinomial-structured.R). Mirrors
## campaign-s1/s2's mode/timing/results conventions.
##
## `(1 | group)`'s semantics are BASELINE-VS-REST, not per-category (see
## R/multinomial-fence.R and docs/design/122-multinomial-structured-
## surface.md's Slice 4 section): the engine adds ONE draw per group level to
## EVERY one of a multinomial observation's K-1 baseline-contrast rows, so
## `sigma_re` is a single scalar per fit (not per-contrast) and is what this
## campaign recovers.
##
## Modes:
##   --mode timing   1 seed, 1 fit                       -> elapsed time (D-139 timing fit)
##   --mode smoke    2 seeds, small G                     -> str() of results (smoke gate)
##   --mode full     20 seeds, G = 60, n_per_g = 15       -> the campaign
##
## Usage:
##   Rscript campaign-s4-group-intercepts.R --mode timing
##   Rscript campaign-s4-group-intercepts.R --mode smoke
##   OPENBLAS_NUM_THREADS=1 CAMPAIGN_CORES=20 \
##     Rscript campaign-s4-group-intercepts.R --mode full
##
## `--mode full` is NOT run as part of this task (D-139 + Design 122: gated on
## dev/multinomial-structured/pass-criteria-s4.md's DRAFT status, pending
## Shinichi's sign-off -- see that file).

Sys.setenv(OPENBLAS_NUM_THREADS = "1")

.here <- tryCatch(
  dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "."
)
if (length(.here) == 0L || !nzchar(.here)) .here <- "."
source(file.path(.here, "dgp-multinomial-structured.R"))

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

`%||%` <- function(a, b) if (is.null(a)) b else a

## ---- one fit: seed -> result -----------------------------------------------
.fit_one <- function(G, n_per_g, seed, K = 3L, sigma_re_true = 0.6) {
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_grouped(G = G, n_per_g = n_per_g, seed = seed, K = K,
                                    sigma_re = sigma_re_true)
    df  <- dgp$data

    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + (1 | group), data = df, family = multinomial(),
      trait = "trait", unit = "unit"
    )))

    conv   <- fit$opt$convergence
    pdhess <- isTRUE(fit$sd_report$pdHess)
    sigma_hat <- tryCatch(exp(fit$report$log_sigma_re_int)[1], error = function(e) NA_real_)

    list(G = G, n_per_g = n_per_g, seed = seed, K = K,
         convergence = conv, pdHess = pdhess,
         sigma_hat = sigma_hat, sigma_true = sigma_re_true,
         error = NA_character_)
  }, error = function(e) {
    list(G = G, n_per_g = n_per_g, seed = seed, K = K,
         convergence = NA_integer_, pdHess = NA,
         sigma_hat = NA_real_, sigma_true = sigma_re_true,
         error = conditionMessage(e))
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

## ---- results -> one summary CSV row ---------------------------------------
.row_from_result <- function(r) {
  data.frame(
    G = r$G, n_per_g = r$n_per_g, seed = r$seed, K = r$K,
    convergence = r$convergence %||% NA_integer_, pdHess = isTRUE(r$pdHess),
    sigma_hat = r$sigma_hat, sigma_true = r$sigma_true,
    ratio = r$sigma_hat / r$sigma_true,
    elapsed_sec = r$elapsed_sec, error = r$error %||% NA_character_,
    stringsAsFactors = FALSE
  )
}

## =============================================================================
if (MODE == "timing") {
  cat("MODE: timing -- 1 seed, 1 fit (G = 60, n_per_g = 15, seed = 1)\n")
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  r <- .fit_one(G = 60L, n_per_g = 15L, seed = 1L)
  cat(sprintf("elapsed: %.2f sec | convergence=%s pdHess=%s sigma_hat=%s error=%s\n",
              r$elapsed_sec, r$convergence, r$pdHess,
              format(r$sigma_hat, digits = 3), r$error %||% "none"))
  cat("D-139: if this fit is representative, projected full run (20 fits) ~= ",
      round(r$elapsed_sec * 20 / 60, 1), " min. >30 min -> pre-run test + approval before --mode full.\n")

} else if (MODE == "smoke") {
  cat("MODE: smoke -- 2 seeds (G = 20, n_per_g = 5)\n")
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  res <- lapply(c(1L, 2L), function(s) .fit_one(G = 20L, n_per_g = 5L, seed = s))
  for (r in res) { cat("---\n"); str(r, max.level = 1) }

} else if (MODE == "full") {
  N_SEED <- 20L
  G <- 60L; N_PER_G <- 15L
  cat(sprintf("MODE: full -- %d seeds, G=%d, n_per_g=%d, cores=%d\n",
              N_SEED, G, N_PER_G, N_CORES))
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  seeds <- seq_len(N_SEED) + 200L
  res <- parallel::mclapply(seeds, function(s) {
    .fit_one(G = G, n_per_g = N_PER_G, seed = s)
  }, mc.cores = N_CORES)

  if (!dir.exists(RESULTS_DIR)) dir.create(RESULTS_DIR, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  saveRDS(res, file.path(RESULTS_DIR, sprintf("s4-results-%s.rds", stamp)))

  summ <- do.call(rbind, lapply(res, .row_from_result))
  write.csv(summ, file.path(RESULTS_DIR, sprintf("s4-summary-%s.csv", stamp)),
            row.names = FALSE)
  cat("wrote:\n  ", file.path(RESULTS_DIR, sprintf("s4-results-%s.rds", stamp)), "\n  ",
      file.path(RESULTS_DIR, sprintf("s4-summary-%s.csv", stamp)), "\n")
  print(summ)
}
