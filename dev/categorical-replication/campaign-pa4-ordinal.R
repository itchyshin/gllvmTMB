## dev/categorical-replication/campaign-pa4-ordinal.R
##
## PA4 Cell A recovery campaign: ordinal_probit() (family_id 14) with the
## paper's eq 38-46 COMBINED decomposition — phylogenetic species effect
## (phylo_indep, per-trait diagonal) AND non-phylogenetic species effect
## (indep at the cluster tier) in one fit — against the known truth of
## dgp_ordinal_replicated(). Pre-registered criteria:
## dev/categorical-replication/pass-criteria-pa4.md (Cell A).
## Mirrors dev/multinomial-structured/campaign-s4's mode/timing/results
## conventions.
##
## Modes:
##   --mode timing   1 seed, 1 fit at FULL design size  -> elapsed (D-139)
##   --mode smoke    2 seeds, reduced size              -> str() of results
##   --mode full     20 seeds, n_sp = 150, n_rep = 5    -> the campaign
##
## Usage:
##   Rscript campaign-pa4-ordinal.R --mode timing
##   Rscript campaign-pa4-ordinal.R --mode smoke
##   OPENBLAS_NUM_THREADS=1 CAMPAIGN_CORES=20 \
##     Rscript campaign-pa4-ordinal.R --mode full
##
## `--mode full` is NOT run as part of the PA4 build task (D-139 + Design
## 123: gated on pass-criteria-pa4.md's DRAFT status, pending Shinichi's
## sign-off).

Sys.setenv(OPENBLAS_NUM_THREADS = "1")

.here <- tryCatch(
  dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))),
  error = function(e) "."
)
if (length(.here) == 0L || !nzchar(.here)) .here <- "."
source(file.path(.here, "dgp-ordinal-replicated.R"))

PKG_DIR  <- Sys.getenv("GLLVMTMB_DIR", file.path(.here, "..", ".."))
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

## True variance components (pass-criteria-pa4.md Cell A)
VAR_A_TRUE <- 0.64   # per-trait phylogenetic variance (sigma_a = 0.8)
VAR_S_TRUE <- 0.36   # per-trait non-phylo species variance (sigma_s = 0.6)

## ---- one fit: seed -> result -----------------------------------------------
.fit_one <- function(n_sp, n_rep, seed) {
  t0 <- Sys.time()
  out <- tryCatch({
    dgp  <- dgp_ordinal_replicated(n_sp = n_sp, n_rep = n_rep, seed = seed)
    df   <- dgp$data
    tree <- dgp$tree

    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait +
        phylo_indep(0 + trait | species, tree = tree) +
        indep(0 + trait | species),
      data = df, family = ordinal_probit(),
      trait = "trait", unit = "obs", cluster = "species"
    )))

    conv   <- fit$opt$convergence
    pdhess <- isTRUE(fit$sd_report$pdHess)

    Sphy <- extract_Sigma(fit, level = "phy", part = "shared",
                          link_residual = "none")
    Sphy <- if (is.matrix(Sphy)) Sphy else Sphy$Sigma
    Sclu <- extract_Sigma(fit, level = "cluster", link_residual = "none")
    Sclu <- if (is.matrix(Sclu)) Sclu else Sclu$Sigma

    list(n_sp = n_sp, n_rep = n_rep, seed = seed,
         convergence = conv, pdHess = pdhess,
         var_phy1 = Sphy[1, 1], var_phy2 = Sphy[2, 2],
         var_sp1  = Sclu[1, 1], var_sp2  = Sclu[2, 2],
         error = NA_character_)
  }, error = function(e) {
    list(n_sp = n_sp, n_rep = n_rep, seed = seed,
         convergence = NA_integer_, pdHess = NA,
         var_phy1 = NA_real_, var_phy2 = NA_real_,
         var_sp1 = NA_real_, var_sp2 = NA_real_,
         error = conditionMessage(e))
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

## ---- results -> one summary CSV row ---------------------------------------
.row_from_result <- function(r) {
  data.frame(
    n_sp = r$n_sp, n_rep = r$n_rep, seed = r$seed,
    convergence = r$convergence %||% NA_integer_, pdHess = isTRUE(r$pdHess),
    var_phy1 = r$var_phy1, var_phy2 = r$var_phy2,
    var_sp1 = r$var_sp1, var_sp2 = r$var_sp2,
    ratio_phy1 = r$var_phy1 / VAR_A_TRUE, ratio_phy2 = r$var_phy2 / VAR_A_TRUE,
    ratio_sp1  = r$var_sp1 / VAR_S_TRUE,  ratio_sp2  = r$var_sp2 / VAR_S_TRUE,
    elapsed_sec = r$elapsed_sec, error = r$error %||% NA_character_,
    stringsAsFactors = FALSE
  )
}

## =============================================================================
if (MODE == "timing") {
  cat("MODE: timing -- 1 seed, 1 fit at FULL size (n_sp = 150, n_rep = 5, seed = 401)\n")
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  r <- .fit_one(n_sp = 150L, n_rep = 5L, seed = 401L)
  cat(sprintf("elapsed: %.1f sec | convergence=%s pdHess=%s | ratios phy=(%.2f, %.2f) sp=(%.2f, %.2f) | error=%s\n",
              r$elapsed_sec, r$convergence, r$pdHess,
              r$var_phy1 / VAR_A_TRUE, r$var_phy2 / VAR_A_TRUE,
              r$var_sp1 / VAR_S_TRUE, r$var_sp2 / VAR_S_TRUE,
              r$error %||% "none"))
  cat("D-139: if representative, projected full run (20 fits) ~= ",
      round(r$elapsed_sec * 20 / 60, 1), " min serial, ~",
      round(r$elapsed_sec / 60, 1),
      " min wall-clock at 20 cores. >30 min -> pre-run test + approval before --mode full.\n")

} else if (MODE == "smoke") {
  cat("MODE: smoke -- 2 seeds (n_sp = 60, n_rep = 3)\n")
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  res <- lapply(c(401L, 402L), function(s) .fit_one(n_sp = 60L, n_rep = 3L, seed = s))
  for (r in res) { cat("---\n"); str(r, max.level = 1) }

} else if (MODE == "full") {
  N_SEED <- 20L
  N_SP <- 150L; N_REP <- 5L
  cat(sprintf("MODE: full -- %d seeds, n_sp=%d, n_rep=%d, cores=%d\n",
              N_SEED, N_SP, N_REP, N_CORES))
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  seeds <- seq_len(N_SEED) + 400L
  res <- parallel::mclapply(seeds, function(s) {
    .fit_one(n_sp = N_SP, n_rep = N_REP, seed = s)
  }, mc.cores = N_CORES)

  if (!dir.exists(RESULTS_DIR)) dir.create(RESULTS_DIR, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  saveRDS(res, file.path(RESULTS_DIR, sprintf("pa4-ordinal-results-%s.rds", stamp)))

  summ <- do.call(rbind, lapply(res, .row_from_result))
  write.csv(summ, file.path(RESULTS_DIR, sprintf("pa4-ordinal-summary-%s.csv", stamp)),
            row.names = FALSE)

  ok <- summ$convergence == 0 & summ$pdHess
  ok[is.na(ok)] <- FALSE
  cat(sprintf("conv+PD: %d/20 (criterion 1: <10 -> INCONCLUSIVE)\n", sum(ok)))
  if (sum(ok) > 0L) {
    for (comp in c("ratio_phy1", "ratio_phy2", "ratio_sp1", "ratio_sp2")) {
      med <- median(summ[[comp]][ok])
      collapse_n <- sum(summ[[comp]][ok] < 1e-3, na.rm = TRUE)
      cat(sprintf("%s: median=%.3f (band 0.33-3.0: %s) | collapse(<1e-3)=%d\n",
                  comp, med, if (med >= 1/3 && med <= 3) "in" else "OUT", collapse_n))
    }
  }
  cat("wrote:\n  ", file.path(RESULTS_DIR, sprintf("pa4-ordinal-results-%s.rds", stamp)), "\n  ",
      file.path(RESULTS_DIR, sprintf("pa4-ordinal-summary-%s.csv", stamp)), "\n")
  print(summ)
}
