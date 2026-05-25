## dev/jason-binomial-scout.R
## ==========================
## Jason cross-package scout, 2026-05-25. Reproduces the m3-grid
## binomial × d=1 DGP and fits gllvmTMB, gllvm, glmmTMB. Compares
## median estimate/truth ratio on Sigma_unit[tt].
##
## Repro:  Rscript dev/jason-binomial-scout.R
## Output: /tmp/jason-scout-perrep.csv  (per-rep × trait raw)
##         /tmp/jason-scout-summary.csv (per-package median + IQR)
##         + console summary table.
##
## Question: is the binomial Sigma_unit[tt] under-estimate the M3
## sim pilot surfaced (median ratio 0.24-0.42 on gllvmTMB, run
## 26404672871) gllvmTMB-specific, or does it appear in `gllvm`
## (Niku 2019) and a full-unstructured `glmmTMB` fit on the same
## DGP?
##
## See `docs/dev-log/audits/2026-05-25-jason-cross-package-binomial-sigma-scout.md`
## for interpretive memo.
##
## Read-only audit; no edit to any R/ source.

suppressPackageStartupMessages({
  if (requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all(".", quiet = TRUE)
  } else {
    library(gllvmTMB)
  }
  library(gllvm)
  library(glmmTMB)
})

source("dev/m3-grid.R")  # m3_sample_truth, m3_simulate_response

N_REPS   <- 10L
SEED_BASE <- 20260525L  # fresh seed (avoid pilot collision at 20260524)
N_UNITS  <- 60L
N_TRAITS <- 5L
D        <- 1L

## --- DGP reps ----------------------------------------------------------

rep_results <- vector("list", N_REPS)
for (r in seq_len(N_REPS)) {
  rep_seed <- SEED_BASE + 1000L * D + 100000L * 2L + r  # family idx 2 = binomial
  cat(sprintf("[rep %d/%d, seed %d]\n", r, N_REPS, rep_seed))

  truth <- m3_sample_truth(
    family = "binomial", d = D, n_traits = N_TRAITS,
    n_units = N_UNITS, seed = rep_seed
  )
  sim <- m3_simulate_response(truth)
  df  <- sim$data

  ## Wide-format Y for gllvm / matrix-input packages
  Y_wide <- matrix(
    df$value,
    nrow = N_UNITS, ncol = N_TRAITS, byrow = TRUE,
    dimnames = list(NULL, paste0("t", seq_len(N_TRAITS)))
  )
  storage.mode(Y_wide) <- "integer"

  ## Truth diagonal of Sigma_unit on the latent (logit) scale
  truth_diag <- truth$diag_Sigma

  ## --- gllvmTMB fit ---------------------------------------------------
  t0 <- Sys.time()
  fit_gTMB <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = D) +
                          unique(0 + trait | unit),
      data = df, family = binomial(), unit = "unit"
    ))),
    error = function(e) NULL
  )
  gTMB_diag <- if (!is.null(fit_gTMB) && fit_gTMB$opt$convergence == 0L) {
    sig <- tryCatch(
      gllvmTMB::extract_Sigma(fit_gTMB, level = "unit", link_residual = "none"),
      error = function(e) NULL
    )
    if (!is.null(sig) && !is.null(sig$Sigma)) {
      diag(sig$Sigma)
    } else {
      rep(NA_real_, N_TRAITS)
    }
  } else {
    rep(NA_real_, N_TRAITS)
  }
  t_gTMB <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  ## --- gllvm fit ------------------------------------------------------
  ## gllvm parameterises as eta = X*beta + LV*theta^T. No separate
  ## `psi`; column-specific intercepts absorb the trait mean. Implied
  ## Sigma_unit[tt] (rotation-invariant variance on latent scale per
  ## trait) = theta_t %*% theta_t^T (LV contribution only) + Bernoulli
  ## link-residual = pi^2/3 if logit. We compare BOTH:
  ##   gllvm_LV_only:    diag(theta %*% t(theta))
  ##   gllvm_plus_link:  + pi^2/3
  ## against truth on the LATENT scale.
  t0 <- Sys.time()
  fit_gllvm <- tryCatch(
    suppressMessages(suppressWarnings(gllvm::gllvm(
      y = Y_wide, num.lv = D, family = "binomial",
      seed = rep_seed, n.init = 1L, trace = FALSE
    ))),
    error = function(e) NULL
  )
  gllvm_LV_only <- gllvm_plus_link <- rep(NA_real_, N_TRAITS)
  if (!is.null(fit_gllvm)) {
    theta <- fit_gllvm$params$theta  # n_traits x num.lv
    if (!is.null(theta)) {
      lv_var <- rowSums(theta * theta)  # diag(theta %*% t(theta))
      gllvm_LV_only   <- lv_var
      gllvm_plus_link <- lv_var + pi^2 / 3
    }
  }
  t_gllvm <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  ## --- glmmTMB fit ----------------------------------------------------
  ## Full unstructured Sigma_unit via (0 + trait | unit). Direct
  ## extraction of the diagonal of the random-effect VCV is the
  ## apples-to-apples comparison against truth.
  t0 <- Sys.time()
  fit_glmmTMB <- tryCatch(
    suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
      value ~ 0 + trait + (0 + trait | unit),
      data = df, family = binomial()
    ))),
    error = function(e) NULL
  )
  glmmTMB_diag <- if (!is.null(fit_glmmTMB)) {
    vc <- glmmTMB::VarCorr(fit_glmmTMB)$cond
    if (!is.null(vc) && length(vc) > 0L) {
      diag(vc[[1L]])
    } else {
      rep(NA_real_, N_TRAITS)
    }
  } else {
    rep(NA_real_, N_TRAITS)
  }
  t_glmmTMB <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  rep_results[[r]] <- data.frame(
    rep = r,
    trait_id = seq_len(N_TRAITS),
    truth_diag = truth_diag,
    gTMB_diag = gTMB_diag,
    gllvm_LV_only = gllvm_LV_only,
    gllvm_plus_link = gllvm_plus_link,
    glmmTMB_diag = glmmTMB_diag,
    t_gTMB = t_gTMB, t_gllvm = t_gllvm, t_glmmTMB = t_glmmTMB,
    stringsAsFactors = FALSE
  )
}

results <- do.call(rbind, rep_results)
results$ratio_gTMB    <- results$gTMB_diag       / results$truth_diag
results$ratio_gllvm_LV <- results$gllvm_LV_only  / results$truth_diag
results$ratio_gllvm_link <- results$gllvm_plus_link / results$truth_diag
results$ratio_glmmTMB <- results$glmmTMB_diag    / results$truth_diag

## --- Summary -----------------------------------------------------------

cat("\n=== Per-rep × trait raw ratios (head 10) ===\n")
print(head(results[, c("rep", "trait_id", "truth_diag", "gTMB_diag",
                       "gllvm_LV_only", "gllvm_plus_link", "glmmTMB_diag",
                       "ratio_gTMB", "ratio_gllvm_LV",
                       "ratio_gllvm_link", "ratio_glmmTMB")], 10),
      row.names = FALSE)

cat("\n=== Median estimate/truth ratio by package ===\n")
summary_pkg <- data.frame(
  package = c("gllvmTMB (latent+unique)", "gllvm (LV only)",
              "gllvm (LV + pi^2/3 link)", "glmmTMB (unstructured)"),
  median_ratio = c(
    median(results$ratio_gTMB,       na.rm = TRUE),
    median(results$ratio_gllvm_LV,   na.rm = TRUE),
    median(results$ratio_gllvm_link, na.rm = TRUE),
    median(results$ratio_glmmTMB,    na.rm = TRUE)
  ),
  iqr_lo = c(
    quantile(results$ratio_gTMB,       0.25, na.rm = TRUE),
    quantile(results$ratio_gllvm_LV,   0.25, na.rm = TRUE),
    quantile(results$ratio_gllvm_link, 0.25, na.rm = TRUE),
    quantile(results$ratio_glmmTMB,    0.25, na.rm = TRUE)
  ),
  iqr_hi = c(
    quantile(results$ratio_gTMB,       0.75, na.rm = TRUE),
    quantile(results$ratio_gllvm_LV,   0.75, na.rm = TRUE),
    quantile(results$ratio_gllvm_link, 0.75, na.rm = TRUE),
    quantile(results$ratio_glmmTMB,    0.75, na.rm = TRUE)
  ),
  n_converged = c(
    sum(!is.na(results$gTMB_diag)),
    sum(!is.na(results$gllvm_LV_only)),
    sum(!is.na(results$gllvm_plus_link)),
    sum(!is.na(results$glmmTMB_diag))
  ),
  median_runtime_s = c(
    median(results$t_gTMB,    na.rm = TRUE),
    median(results$t_gllvm,   na.rm = TRUE),
    median(results$t_gllvm,   na.rm = TRUE),  # same fit
    median(results$t_glmmTMB, na.rm = TRUE)
  ),
  stringsAsFactors = FALSE
)
print(summary_pkg, row.names = FALSE)

write.csv(results,    "/tmp/jason-scout-perrep.csv",  row.names = FALSE)
write.csv(summary_pkg,"/tmp/jason-scout-summary.csv", row.names = FALSE)

cat(sprintf(
  "\n[jason-scout] DGP: binomial, d=%d, n_units=%d, n_traits=%d, n_reps=%d, seed_base=%d\n",
  D, N_UNITS, N_TRAITS, N_REPS, SEED_BASE
))
cat(sprintf("[jason-scout] saved -> /tmp/jason-scout-perrep.csv + /tmp/jason-scout-summary.csv\n"))
