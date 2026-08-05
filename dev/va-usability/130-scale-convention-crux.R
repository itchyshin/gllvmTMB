## THE CRUX: is the ~0.5 loading attenuation REAL, or a scale-convention artifact?
##
## Why this gates everything. A literature check (120-LITERATURE-VA-ATTENUATION.md)
## found no report of non-vanishing POINT-ESTIMATE attenuation in Lambda/Sigma for
## binary GLLVMs — VB point-estimate consistency is the standard theoretical claim.
## Before treating that absence as a finding, the obvious alternative must die:
## that OUR SCORING applies a wrong scale convention. The suspicious fact is that
## our `ac` tier and CRAN gllvm agree at trace 0.508 to three decimals — which is
## equally consistent with "same estimator, same real bias" and with "same scoring
## error applied to both".
##
## THE TEST. In a GLLVM the linear predictor contribution `eta_lat = z %*% t(Lambda)`
## is INVARIANT to how scale is split between z and Lambda: (z*k) %*% t(Lambda/k) is
## the same model. So:
##
##   * Lambda shrunk ~sqrt(2)x AND sd(z_hat) inflated ~sqrt(2)x  -> CONVENTION artifact,
##     because eta_lat is recovered correctly and nothing is actually wrong.
##   * Lambda shrunk AND sd(z_hat) ~ 1 (the planted scale)       -> the bias is REAL.
##
## Our existing latent-r statistic CANNOT distinguish these: it is a CORRELATION,
## hence scale-free, so it reads ~0.86 under either. That is exactly why this was
## invisible until now.
##
## Reported per arm:
##   sd_z_hat        — SD of recovered scores per axis; planted truth is 1.
##   trace_ratio     — sum(Sigma_hat_jj)/sum(Sigma_true_jj); the statistic under suspicion.
##   eta_var_ratio   — var(eta_lat_hat)/var(eta_lat_true), CONVENTION-FREE. The verdict.
##   recon_ratio     — trace_ratio * mean(sd_z_hat^2): what the trace ratio becomes once
##                     the score scale is folded back in. ~1 => pure convention.
##
## Usage: Rscript dev/va-usability/130-scale-convention-crux.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== SCALE-CONVENTION CRUX start %s ==\n", format(Sys.time(), "%H:%M:%S"))); flush.console()
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
have_gllvm <- requireNamespace("gllvm", quietly = TRUE)
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

N0 <- 150L; T0 <<- 20L; N_SEED <- 10L
CORES <- as.integer(Sys.getenv("PILOT_CORES", "5"))

## Scale-free summary of one (Lambda_hat, z_hat) pair against planted truth.
score_scale <- function(Lam, Z, b) {
  eta_hat  <- Z %*% t(Lam)
  eta_true <- b$z_true %*% t(b$Lambda_true)
  list(sd_z        = mean(apply(Z, 2L, stats::sd)),
       trace_ratio = sum(rowSums(Lam^2)) / sum(b$sigma_jj_true),
       eta_var     = stats::var(as.numeric(eta_hat)) / stats::var(as.numeric(eta_true)))
}

one <- function(s) {
  b <- sim_cell(s, "binomial_probit", N0)
  out <- list(seed = s)
  for (em in c("ac", "gh")) {
    f <- tryCatch(gllvmTMB:::.va_r3_fit(
           y = b$d$y, n_trials = rep(1L, nrow(b$d)),
           X = unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d)),
           unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
           q = Q0, family = "binomial_probit", link = "probit",
           unique = FALSE, psi = FALSE, n_starts = 4L, eval_method = em,
           control = list(eval.max = 2000L, iter.max = 2000L)),
         error = function(e) NULL)
    if (is.null(f) || !identical(f$status, "healthy")) next
    par <- f$best$par
    Lam <- gllvmTMB:::.va_r3_unpack_theta_rr(unname(par[names(par) == "theta_rr"]), T0, Q0)
    Z   <- tryCatch(as.matrix(f$latent$scores), error = function(e) NULL)
    if (is.null(Z)) next
    out[[em]] <- score_scale(Lam, Z, b)
  }
  if (have_gllvm) {
    Y <- matrix(b$d$y, nrow = N0, ncol = T0, byrow = TRUE)
    X <- data.frame(x = b$d$x[seq(1L, nrow(b$d), by = T0)])
    g <- tryCatch(gllvm::gllvm(y = Y, X = X, formula = ~ x,
                               family = binomial(link = "probit"),
                               num.lv = Q0, method = "VA", trace = FALSE),
                  error = function(e) NULL)
    if (!is.null(g)) {
      th <- as.matrix(g$params$theta)
      sg <- tryCatch(g$params$sigma.lv, error = function(e) NULL)
      ## BOTH conventions recorded: gllvm splits scale between `theta` and `sigma.lv`.
      out$gllvm_scaled <- score_scale(if (!is.null(sg)) sweep(th, 2L, sg, "*") else th,
                                      as.matrix(g$lvs), b)
      out$gllvm_raw    <- score_scale(th, as.matrix(g$lvs), b)
      out$sigma_lv     <- if (is.null(sg)) NA_real_ else mean(sg)
    }
  }
  out
}

res <- Filter(function(x) length(x) > 1L,
              mclapply(20261900L + seq_len(N_SEED), function(s)
                tryCatch(one(s), error = function(e) NULL),
                mc.cores = CORES, mc.preschedule = FALSE))
saveRDS(res, "dev/va-usability/raw/A2-scale-crux.rds")

cat(sprintf("\n== SCALE-CONVENTION CRUX — probit n=%d p=%d q=%d, %d seeds ==\n\n", N0, T0, Q0, length(res)))
cat(sprintf("%-14s %8s %12s %14s %13s\n", "arm", "sd(z_hat)", "trace_ratio", "eta_var_ratio", "recon_ratio"))
cat(sprintf("%-14s %8s %12s %14s %13s\n", "", "(truth 1)", "(target 1)", "(target 1)", "(target 1)"))
for (a in c("ac", "gh", "gllvm_scaled", "gllvm_raw")) {
  g <- Filter(function(x) !is.null(x[[a]]), res)
  if (!length(g)) next
  sdz <- mean(vapply(g, function(x) x[[a]]$sd_z, numeric(1)))
  tr  <- mean(vapply(g, function(x) x[[a]]$trace_ratio, numeric(1)))
  ev  <- mean(vapply(g, function(x) x[[a]]$eta_var, numeric(1)))
  cat(sprintf("%-14s %8.3f %12.3f %14.3f %13.3f\n", a, sdz, tr, ev, tr * sdz^2))
}
sl <- unlist(lapply(res, function(x) x$sigma_lv)); sl <- sl[is.finite(sl)]
if (length(sl)) cat(sprintf("\ngllvm mean sigma.lv = %.3f\n", mean(sl)))

cat("\nVERDICT KEY\n")
cat("  sd(z_hat) ~ 1 AND trace ~ 0.5 AND eta_var ~ 0.5  -> the bias is REAL.\n")
cat("  sd(z_hat) ~ 1.4 AND trace ~ 0.5 AND eta_var ~ 1  -> pure SCALE CONVENTION; nothing is wrong.\n")
cat("  eta_var is the convention-free arbiter: it is what the model actually predicts.\n")
cat(sprintf("\n== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
