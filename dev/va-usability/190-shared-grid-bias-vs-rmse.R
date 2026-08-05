## THE SHARED GRID — score BIAS and TOTAL ERROR on the SAME cells, all arms.
##
## WHY. Two accuracy criteria currently disagree, and they were measured on
## different designs, so nobody can say which tier is "better":
##   * Gate 3 (2026-07-31, 54 cells, binomial-LOGIT) chose `jj` over `gh` on
##     Sigma_B RMSE: jj passes 50/50, gh 13/50, jj lower error in 52/54
##     (sign test p = 1.7e-13). That comment ALSO flags that 26 of gh's 35
##     apparent raw-rule passes rested on a Laplace comparator that was itself
##     degenerate -- so the criterion may be contaminated.
##   * This session (probit) measured LOADING SCALE: gh converges to 1
##     (1.135 -> 1.065 -> 1.025), ac/jj plateau at ~0.51.
## Unbiased-but-noisy loses to biased-but-tight on RMSE. Both can be true.
## Nobody has scored BOTH estimands on ONE grid. That is all this does.
##
## METRICS, per seed, all arms on IDENTICAL data:
##   trace   sum(rowSums(Lam^2)) / sum(diag(Sigma_true))   BIAS in the scale (target 1)
##   eta_var var(Lam z_hat) / var(Lam_true z_true)          convention-free (target 1)
##   relfrob ||Sigma_hat - Sigma_true||_F / ||Sigma_true||_F  TOTAL ERROR (target 0)
##           -- rotation-invariant, so no Procrustes needed; this is Gate 3's criterion
##   latent_r  ordination quality (target 1)
##   secs
##
## Reported per arm: mean +/- 2 MCSE for each, so "A beats B" is claimable or not.
##
## Usage: N_SEED=10 CORES=8 Rscript 190-shared-grid-bias-vs-rmse.R

`%||%` <- function(a, b) if (is.null(a)) b else a
LANE <- Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-ac-curvature")
OUT  <- Sys.getenv("OUT_DIR", "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/b5967370-047b-4f8b-8b81-36a661400ebc/scratchpad")
setwd(LANE)
cat(sprintf("== SHARED GRID start %s ==\n", format(Sys.time(), "%H:%M:%S"))); flush.console()
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

T0 <<- 20L                      # MUST be set before sim_cell; lib default is 8 (degenerate)
stopifnot(identical(T0, 20L))
N0     <- as.integer(Sys.getenv("N0", "150"))
N_SEED <- as.integer(Sys.getenv("N_SEED", "10"))
CORES  <- as.integer(Sys.getenv("CORES", "8"))
AC2_T  <- as.numeric(Sys.getenv("AC2_THRESHOLD", "1.0"))

rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))

score <- function(Lam, U, b, secs) {
  Sig_hat <- Lam %*% t(Lam)
  Sig_tru <- b$Lambda_true %*% t(b$Lambda_true)
  R  <- .procrustes_R(U, b$z_true); Ua <- U %*% R
  list(trace   = sum(rowSums(Lam^2)) / sum(b$sigma_jj_true),
       eta_var = stats::var(as.numeric(U %*% t(Lam))) /
                 stats::var(as.numeric(b$z_true %*% t(b$Lambda_true))),
       relfrob = rel_frob(Sig_hat, Sig_tru),
       latent_r = mean(abs(vapply(seq_len(Q0), function(k)
                     stats::cor(Ua[, k], b$z_true[, k]), numeric(1)))),
       secs = secs)
}

one <- function(s) {
  b <- sim_cell(s, "binomial_probit", N0)
  stopifnot(nrow(b$d) == N0 * T0)
  X <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d))
  out <- list(seed = s)

  ## --- our VA tiers: identical parameterisation/optimiser/starts, differing
  ## --- ONLY in the expectation functional. This is the controlled comparison.
  for (em in c("ac", "ac2", "gh")) {
    t0 <- Sys.time()
    f <- tryCatch(gllvmTMB:::.va_r3_fit(
           y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = X,
           unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
           q = Q0, family = "binomial_probit", link = "probit",
           unique = FALSE, psi = FALSE, n_starts = 4L, eval_method = em,
           ac2_threshold = AC2_T,
           control = list(eval.max = 2000L, iter.max = 2000L)),
         error = function(e) NULL)
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (is.null(f) || is.null(f$best$par)) next
    Lam <- gllvmTMB:::.va_r3_unpack_theta_rr(
             unname(f$best$par[names(f$best$par) == "theta_rr"]), T0, Q0)
    U <- tryCatch(as.matrix(f$latent$scores), error = function(e) NULL)
    if (is.null(U)) next
    sc <- score(Lam, U, b, el); sc$status <- f$status
    out[[em]] <- sc                      # scored even if a health gate refused it
  }

  ## --- Laplace, public route (stage-8's own call) ---
  t0 <- Sys.time()
  la <- tryCatch(gllvmTMB::gllvmTMB(
          y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = Q0, unique = FALSE),
          data = b$d, family = stats::binomial(link = "probit"),
          unit = "unit", silent = TRUE), error = function(e) NULL)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (!is.null(la) && isTRUE(la$sd_report$pdHess %||% FALSE)) {
    d  <- tryCatch(gllvmTMB:::.loading_delta_at_mle(fit = la, internal_level = "B",
                                                    loading_scale = "raw"), error = function(e) NULL)
    lv <- tryCatch(gllvmTMB::getLV(la), error = function(e) NULL)
    if (!is.null(d) && !is.null(lv)) {
      sc <- score(matrix(d$Lambda, T0, Q0), as.matrix(lv), b, el); sc$status <- "laplace"
      out$la <- sc
    }
  }

  ## --- gllvm (CRAN), CORRECTLY scaled: Lambda = theta %*% diag(sigma.lv).
  ## --- Settled 2026-08-05 against gllvm's own linear predictor (4.4e-16).
  t0 <- Sys.time()
  Y <- matrix(b$d$y, nrow = N0, ncol = T0, byrow = TRUE)
  Xd <- data.frame(x = b$d$x[seq(1L, nrow(b$d), by = T0)])
  g <- tryCatch(gllvm::gllvm(y = Y, X = Xd, formula = ~ x,
                             family = binomial(link = "probit"),
                             num.lv = Q0, method = "VA", trace = FALSE),
                error = function(e) NULL)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (!is.null(g)) {
    th <- as.matrix(g$params$theta); sg <- tryCatch(g$params$sigma.lv, error = function(e) NULL)
    L  <- if (!is.null(sg)) sweep(th, 2L, sg, "*") else th
    sc <- score(L, as.matrix(g$lvs), b, el); sc$status <- "gllvm"
    out$gllvm <- sc
  }
  out
}

seeds <- 20261900L + seq_len(N_SEED)
res <- Filter(function(x) length(x) > 1L,
              mclapply(seeds, function(s) tryCatch(one(s), error = function(e) NULL),
                       mc.cores = CORES, mc.preschedule = FALSE))
saveRDS(res, file.path(OUT, "190-shared-grid.rds"))

ARMS <- c("ac", "ac2", "gh", "la", "gllvm")
cat(sprintf("\n======== SHARED GRID — probit n=%d p=%d q=%d, %d/%d seeds, ac2_threshold=%.2f ========\n\n",
            N0, T0, Q0, length(res), N_SEED, AC2_T))
cat(sprintf("%-6s %5s | %-16s %-16s | %-16s %-14s %8s\n",
            "arm", "n", "trace (bias->1)", "eta_var (->1)", "relfrob (RMSE->0)", "latent_r", "secs"))
tab <- list()
for (a in ARMS) {
  g <- Filter(function(x) !is.null(x[[a]]), res)
  if (!length(g)) { cat(sprintf("%-6s %5d | %s\n", a, 0L, "no fits")); next }
  m  <- function(f) mean(vapply(g, function(x) x[[a]][[f]], numeric(1)))
  se <- function(f) 2 * stats::sd(vapply(g, function(x) x[[a]][[f]], numeric(1))) / sqrt(length(g))
  tab[[a]] <- list(n = length(g), trace = m("trace"), trace_se = se("trace"),
                   eta = m("eta_var"), eta_se = se("eta_var"),
                   rf = m("relfrob"), rf_se = se("relfrob"),
                   r = m("latent_r"), secs = m("secs"))
  with(tab[[a]], cat(sprintf("%-6s %5d | %7.3f +/-%.3f  %7.3f +/-%.3f | %7.3f +/-%.3f  %7.4f       %7.1f\n",
                             a, n, trace, trace_se, eta, eta_se, rf, rf_se, r, secs)))
}

cat("\n-- DO THE TWO CRITERIA AGREE ON A RANKING? --\n")
if (length(tab)) {
  by_bias <- names(sort(vapply(tab, function(z) abs(z$trace - 1), numeric(1))))
  by_rmse <- names(sort(vapply(tab, function(z) z$rf, numeric(1))))
  cat("  best -> worst by BIAS  |trace-1| :", paste(by_bias, collapse = " > "), "\n")
  cat("  best -> worst by TOTAL relfrob   :", paste(by_rmse, collapse = " > "), "\n")
  cat(if (identical(by_bias, by_rmse))
        "  => THE CRITERIA AGREE. One tier is simply better; no tradeoff.\n"
      else
        "  => THE CRITERIA DISAGREE. This is the bias-variance tradeoff, and it means\n     \"which tier is best\" has no answer without naming the estimand.\n")
}
cat("\n-- THE GOAL'S QUESTION: does exact curvature move eta_var off ac's ~0.44? --\n")
if (!is.null(tab$ac) && !is.null(tab$ac2)) {
  gp <- Filter(function(x) !is.null(x$ac) && !is.null(x$ac2), res)
  d  <- vapply(gp, function(x) x$ac2$eta_var - x$ac$eta_var, numeric(1))
  mm <- mean(d); ss <- 2 * stats::sd(d) / sqrt(length(d))
  cat(sprintf("  ac  eta_var = %.3f\n  ac2 eta_var = %.3f\n  PAIRED diff = %+.3f [%+.3f, %+.3f]  n=%d%s\n",
              tab$ac$eta, tab$ac2$eta, mm, mm - ss, mm + ss, length(d),
              if (mm - ss > 0) "  *separates from 0*" else ""))
}
cat(sprintf("\n== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
