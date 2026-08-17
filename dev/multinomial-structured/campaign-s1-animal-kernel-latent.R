## dev/multinomial-structured/campaign-s1-animal-kernel-latent.R
##
## Slice-1 recovery campaign: multinomial() (family_id 16) with
## animal_latent() and kernel_latent() structured random effects, fitting the
## (K-1)x(K-1) among-category covariance V against the KNOWN truth simulated
## by dgp-multinomial-structured.R.
##
## animal_latent(species, A = A_corr, d = K-1) desugars (parser-level, see
## test-animal-latent-unique-fold.R) into phylo_rr(species, vcv = A_corr) --
## i.e. it is pure sugar over the already-admitted phylo_latent() engine, and
## its Sigma surfaces at the same extractor level: extract_Sigma(level="phy").
##
## kernel_latent(species, K = A_corr, d = K-1, name = "phy") routes through
## the SAME phylo_rr engine for a dense supplied covariance (Design 65 C1
## phylo-equivalence); passing name = "phy" makes its Sigma surface at the
## SAME extractor level as phylo_latent()/animal_latent() (fit$kernel_levels
## maps `name` -> `internal_level`, default "phy"). This lets both keywords
## share one extraction call:
##   extract_Sigma(fit, level = "phy", part = "shared", link_residual = "none")
## per Design 84 Section 4 (the canonical phylo_latent multinomial extraction).
##
## PRE-REGISTRATION NOTE (2026-08-16): at the time this script was written,
## R/fit-multi.R's Tier-2a fence for multinomial() admits ONLY fixed effects,
## phylo_latent(), and a shared cross-family latent() -- NOT animal_latent()
## or kernel_latent(). Fits below will error with
## "{.fn multinomial} supports fixed effects, {.fn phylo_latent}, and a
## shared {.fn latent} ordination in this release" until Slice 1's admission
## work lands (a separate, concurrent lane in this worktree). This script is
## written to be ready the moment that admission lands; it is NOT run to
## completion as part of this task (D-139: no full-fit campaign is committed
## here without a timing fit + Shinichi's approval, and the package itself is
## mid-edit).
##
## Modes:
##   --mode timing   1 seed, 1 fit  (animal_latent only) -> elapsed time      (D-139 timing fit)
##   --mode smoke     2 seeds x 2 keywords -> str() of results                (smoke gate)
##   --mode full      20 seeds x 2 keywords, parallel::mclapply               (the campaign)
##
## Usage:
##   Rscript campaign-s1-animal-kernel-latent.R --mode timing
##   Rscript campaign-s1-animal-kernel-latent.R --mode smoke
##   OPENBLAS_NUM_THREADS=1 CAMPAIGN_CORES=20 \
##     Rscript campaign-s1-animal-kernel-latent.R --mode full

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

KEYWORDS <- c("animal_latent", "kernel_latent")

## ---- one fit: keyword x seed -----------------------------------------------
## Returns a length-1 list-row (not a plain numeric vector, because V/rho/sd
## are matrix/vector-valued) so mclapply results stay well-formed even on a
## worker failure (mirrors dev/phylo-multinomial-recovery-harness-reps.R's
## robustness pattern: coerce to a fixed shape, never let one bad leg corrupt
## the whole grid).
.fit_one <- function(keyword, n_sp, seed, K = 3L, d = NULL) {
  d <- if (is.null(d)) K - 1L else d
  t0 <- Sys.time()
  out <- tryCatch({
    dgp <- dgp_multinomial_structured(n_sp = n_sp, seed = seed, K = K)
    df  <- dgp$data
    A_corr <- dgp$A_corr        # local name referenced (unevaluated) in the formula below
    Kcat   <- dgp$K

    form <- switch(keyword,
      animal_latent = value ~ 0 + trait +
        animal_latent(species, d = d, A = A_corr, unique = FALSE),
      kernel_latent = value ~ 0 + trait +
        kernel_latent(species, K = A_corr, d = d, name = "phy", unique = FALSE),
      stop("unknown keyword: ", keyword)
    )

    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      form, data = df, family = multinomial(),
      trait = "trait", unit = "species"
    )))

    conv   <- fit$opt$convergence
    pdhess <- isTRUE(fit$sd_report$pdHess)
    Vhat <- tryCatch({
      s <- extract_Sigma(fit, level = "phy", part = "shared", link_residual = "none")
      if (is.matrix(s)) s else s$Sigma
    }, error = function(e) matrix(NA_real_, 2L, 2L))

    rho_hat <- if (is.matrix(Vhat) && all(is.finite(Vhat)) &&
                   Vhat[1, 1] > 0 && Vhat[2, 2] > 0) {
      Vhat[1, 2] / sqrt(Vhat[1, 1] * Vhat[2, 2])
    } else NA_real_
    sd_hats <- if (is.matrix(Vhat)) sqrt(pmax(diag(Vhat), 0)) else c(NA_real_, NA_real_)

    list(keyword = keyword, n_sp = n_sp, seed = seed, K = K, d = d,
         convergence = conv, pdHess = pdhess,
         V_hat = Vhat, rho_hat = rho_hat, sd_hats = sd_hats,
         V_true = dgp$V_true, rho_true = dgp$rho_true, sd_true = dgp$sd_true,
         error = NA_character_)
  }, error = function(e) {
    list(keyword = keyword, n_sp = n_sp, seed = seed, K = K, d = d,
         convergence = NA_integer_, pdHess = NA,
         V_hat = matrix(NA_real_, 2L, 2L), rho_hat = NA_real_,
         sd_hats = c(NA_real_, NA_real_),
         V_true = NULL, rho_true = NA_real_, sd_true = c(NA_real_, NA_real_),
         error = conditionMessage(e))
  })
  out$elapsed_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out
}

## ---- results -> one summary CSV row ---------------------------------------
.row_from_result <- function(r) {
  data.frame(
    keyword = r$keyword, n_sp = r$n_sp, seed = r$seed, K = r$K, d = r$d,
    convergence = r$convergence %||% NA_integer_, pdHess = isTRUE(r$pdHess),
    V11_hat = r$V_hat[1, 1], V22_hat = r$V_hat[2, 2], V12_hat = r$V_hat[1, 2],
    rho_hat = r$rho_hat, sd1_hat = r$sd_hats[1], sd2_hat = r$sd_hats[2],
    rho_true = r$rho_true, sd1_true = r$sd_true[1], sd2_true = r$sd_true[2],
    elapsed_sec = r$elapsed_sec, error = r$error %||% NA_character_,
    stringsAsFactors = FALSE
  )
}
`%||%` <- function(a, b) if (is.null(a)) b else a

## =============================================================================
if (MODE == "timing") {
  cat("MODE: timing -- 1 seed, 1 fit (animal_latent, n_sp = 60, seed = 1)\n")
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  r <- .fit_one("animal_latent", n_sp = 60L, seed = 1L)
  cat(sprintf("elapsed: %.2f sec | convergence=%s pdHess=%s rho_hat=%s error=%s\n",
              r$elapsed_sec, r$convergence, r$pdHess,
              format(r$rho_hat, digits = 3), r$error %||% "none"))
  cat("D-139: if this fit is representative, projected full run (40 fits) ~= ",
      round(r$elapsed_sec * 40 / 60, 1), " min. >30 min -> pre-run test + approval before --mode full.\n")

} else if (MODE == "smoke") {
  cat("MODE: smoke -- 2 seeds x 2 keywords (n_sp = 60)\n")
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  grid <- expand.grid(keyword = KEYWORDS, seed = c(1L, 2L), stringsAsFactors = FALSE)
  res <- lapply(seq_len(nrow(grid)), function(i) {
    .fit_one(grid$keyword[i], n_sp = 60L, seed = grid$seed[i])
  })
  for (r in res) { cat("---\n"); str(r, max.level = 1) }

} else if (MODE == "full") {
  N_SEED <- 20L
  ## n_sp = 800 matches the pre-registered pass criteria, which are calibrated
  ## on the 2026-07-17 phylo-multinomial spike (N=800 recovers rho 0.6 -> ~0.45;
  ## N=250 was underpowered). Do not lower without recalibrating the bands.
  N_SP   <- 800L
  cat(sprintf("MODE: full -- %d seeds x %d keywords, n_sp=%d, cores=%d\n",
              N_SEED, length(KEYWORDS), N_SP, N_CORES))
  suppressMessages(devtools::load_all(PKG_DIR, quiet = TRUE))
  grid <- expand.grid(keyword = KEYWORDS, seed = seq_len(N_SEED) + 100L,
                       stringsAsFactors = FALSE)
  res <- parallel::mclapply(seq_len(nrow(grid)), function(i) {
    .fit_one(grid$keyword[i], n_sp = N_SP, seed = grid$seed[i])
  }, mc.cores = N_CORES)

  if (!dir.exists(RESULTS_DIR)) dir.create(RESULTS_DIR, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  saveRDS(res, file.path(RESULTS_DIR, sprintf("s1-results-%s.rds", stamp)))

  summ <- do.call(rbind, lapply(res, .row_from_result))
  write.csv(summ, file.path(RESULTS_DIR, sprintf("s1-summary-%s.csv", stamp)),
            row.names = FALSE)
  cat("wrote:\n  ", file.path(RESULTS_DIR, sprintf("s1-results-%s.rds", stamp)), "\n  ",
      file.path(RESULTS_DIR, sprintf("s1-summary-%s.csv", stamp)), "\n")
  print(summ)
}
