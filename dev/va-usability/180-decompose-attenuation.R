## WHERE does the attenuation live: in Lambda, in the variational covariance S, or in the means?
##
## eta_hat = m_hat %*% t(Lambda_hat), and v_ij = lambda_j' S_i lambda_j.
## An unfollowed lead from earlier today: ac's max_v = 0.153 vs gh's 2.217 -- a 14x gap.
## Lambda alone explains only ~2.3x of that (trace 0.600 vs 1.356). So S must ALSO be
## collapsing, by roughly 6x. If true, the attenuation is not "Lambda is shrunk" but
## "the whole variational posterior is collapsed", which is a different mechanism and
## points at the KL term rather than the data term -- consistent with today's proof that
## the data term is NOT the cause.
##
## Decomposition reported per tier:
##   trace_ratio   sum(rowSums(Lam^2)) / sum(sigma_jj_true)      -- is Lambda shrunk?
##   sd_m          mean per-axis SD of the posterior MEANS       -- are the scores shrunk?
##   post_sd       mean posterior SD (sqrt of S diagonal)        -- is S collapsed?
##   mean_v/max_v  the projected variance lambda' S lambda       -- the composite
##   v_from_Lam    max_v rescaled by (trace ratio) -- what max_v WOULD be if only
##                 Lambda differed and S were identical to gh's. The gap between this
##                 and the observed max_v is S's own contribution.
##   eta_var       convention-free recovery of the linear predictor
##
## Usage: Rscript 180-decompose-attenuation.R

LANE <- Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-ac-curvature")
setwd(LANE)
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")
T0 <<- 20L
stopifnot(identical(T0, 20L))
N0 <- 150L
b <- sim_cell(20261901L, "binomial_probit", N0)
stopifnot(nrow(b$d) == N0 * T0)
X <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d))

rows <- list()
for (em in c("ac", "gh")) {
  f <- tryCatch(gllvmTMB:::.va_r3_fit(
        y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = X,
        unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
        q = Q0, family = "binomial_probit", link = "probit",
        unique = FALSE, psi = FALSE, n_starts = 4L, eval_method = em,
        control = list(eval.max = 2000L, iter.max = 2000L)),
      error = function(e) NULL)
  if (is.null(f) || is.null(f$best$par)) { cat(em, ": FIT FAILED\n"); next }
  par <- f$best$par
  Lam <- gllvmTMB:::.va_r3_unpack_theta_rr(unname(par[names(par) == "theta_rr"]), T0, Q0)
  M   <- as.matrix(f$latent$scores)
  SE  <- tryCatch(as.matrix(f$latent$se), error = function(e) NULL)
  vv  <- tryCatch(f$report$v_by_obs, error = function(e) NULL)
  rows[[em]] <- list(
    status  = f$status,
    trace   = sum(rowSums(Lam^2)) / sum(b$sigma_jj_true),
    sd_m    = mean(apply(M, 2L, stats::sd)),
    post_sd = if (is.null(SE)) NA_real_ else mean(SE),
    mean_v  = if (is.null(vv)) NA_real_ else mean(vv),
    max_v   = if (is.null(vv)) NA_real_ else max(vv),
    eta_var = stats::var(as.numeric(M %*% t(Lam))) /
              stats::var(as.numeric(b$z_true %*% t(b$Lambda_true))))
}

cat("\n======== WHERE DOES THE ATTENUATION LIVE? (probit n=150 p=20 q=2, seed 20261901) ========\n\n")
cat(sprintf("%-5s %-22s %8s %8s %9s %9s %9s %9s\n",
            "tier", "status", "trace", "sd(m)", "post_sd", "mean_v", "max_v", "eta_var"))
for (em in names(rows)) with(rows[[em]],
  cat(sprintf("%-5s %-22s %8.3f %8.3f %9.4f %9.4f %9.4f %9.3f\n",
              em, status, trace, sd_m, post_sd, mean_v, max_v, eta_var)))

if (all(c("ac", "gh") %in% names(rows))) {
  a <- rows[["ac"]]; g <- rows[["gh"]]
  cat("\n-- DECOMPOSITION: ac relative to gh --\n")
  r_trace <- a$trace / g$trace
  r_v     <- a$max_v / g$max_v
  cat(sprintf("  Lambda^2 ratio (trace)          : %.4f\n", r_trace))
  cat(sprintf("  observed v ratio                : %.4f\n", r_v))
  cat(sprintf("  v ratio EXPLAINED by Lambda only: %.4f\n", r_trace))
  cat(sprintf("  RESIDUAL, attributable to S     : %.4f   <- if << 1, S is collapsing too\n",
              r_v / r_trace))
  cat(sprintf("  posterior SD ratio (direct)     : %.4f\n", a$post_sd / g$post_sd))
  cat("\nREAD: if the residual and the posterior-SD ratio are both well below 1, the\n")
  cat("      variational COVARIANCE is collapsing independently of Lambda. That moves the\n")
  cat("      suspect from the data term (already eliminated today) to the KL/entropy term.\n")
  cat("      If the residual is ~1, S is fine and only Lambda is shrunk.\n")
}
cat(sprintf("\n== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
