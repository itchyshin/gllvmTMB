## DOES psi ABSORB THE ATTENUATION? — the untested consequence, and possibly the worst.
##
## THE QUESTION. Every measurement in this arc ran `psi = FALSE`, i.e.
## Sigma = Lambda Lambda' with no trait-specific variance term. But ORDINARY
## `latent()` carries a diagonal companion by default: Sigma = Lambda Lambda' + diag(psi).
##
## If Lambda Lambda' is attenuated ~2x and psi is FREE, the optimiser has somewhere
## to put the missing variance. Two possibilities, with very different consequences:
##
##   (a) psi INFLATES to absorb the shortfall. Then total Sigma is roughly right,
##       but the SPLIT is wrong -- shared latent structure is reattributed to
##       trait-specific noise, and traits look MORE INDEPENDENT THAN THEY ARE.
##       For a JSDM that is the worst possible failure: it erases exactly the
##       species associations the model exists to estimate.
##
##   (b) psi is unaffected. Then the attenuation shows up as a deficit in TOTAL
##       variance instead, which is the already-known ICC/R^2 problem and nothing new.
##
## Nobody has looked. (a) would substantially raise the severity of the whole finding.
##
## DESIGN. Paired, same seeds/data, psi = TRUE, ac vs gh (the biased and unbiased
## tiers). Report per tier:
##   trace_LL   trace(Lambda Lambda') / trace(Sigma_true)   -- the latent share
##   mean_psi   mean of the fitted trait-specific variances
##   trace_tot  (trace(Lambda Lambda') + sum(psi)) / trace(Sigma_true)  -- the TOTAL
##   psi_share  sum(psi) / (trace(Lambda Lambda') + sum(psi))           -- the SPLIT
##
## READ: if ac's psi_share is much larger than gh's, absorption is real -> (a).
## If psi_share is similar and ac's trace_tot is low, no absorption -> (b).
##
## NOTE the DGP plants NO trait-specific variance: Sigma_true = Lambda Lambda'
## exactly (attenuation-lib.R:88). So the TRUE psi is 0 and the TRUE psi_share is 0.
## Any psi > 0 is the model inventing trait-specific noise that does not exist.
##
## Usage: N_SEED=10 CORES=6 Rscript 230-psi-absorption.R

LANE <- Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-ac-curvature")
OUT  <- Sys.getenv("OUT_DIR", "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/b5967370-047b-4f8b-8b81-36a661400ebc/scratchpad")
setwd(LANE)
cat(sprintf("== PSI ABSORPTION start %s ==\n", format(Sys.time(), "%H:%M:%S"))); flush.console()
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")
T0 <<- 20L; stopifnot(identical(T0, 20L))
N0     <- as.integer(Sys.getenv("N0", "150"))
N_SEED <- as.integer(Sys.getenv("N_SEED", "10"))
CORES  <- as.integer(Sys.getenv("CORES", "6"))
HQ     <- as.integer(Sys.getenv("H", "7"))
ARMS   <- c("ac", "gh")

one <- function(s) {
  b <- sim_cell(s, "binomial_probit", N0)
  stopifnot(nrow(b$d) == N0 * T0)
  X <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d))
  out <- list(seed = s)
  for (em in ARMS) {
    f <- tryCatch(gllvmTMB:::.va_r3_fit(
           y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = X,
           unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
           q = Q0, family = "binomial_probit", link = "probit",
           unique = TRUE, psi = TRUE,          # <-- THE POINT: psi is FREE here
           n_starts = 4L, eval_method = em, H = HQ,
           control = list(eval.max = 2000L, iter.max = 2000L)), error = function(e) NULL)
    if (is.null(f) || is.null(f$best$par)) next
    par <- f$best$par
    Lam <- gllvmTMB:::.va_r3_unpack_theta_rr(
             unname(par[names(par) == "theta_rr"]), T0, Q0)
    ## psi is stored on a log scale in the engine's parameter vector; find it.
    lp <- par[grepl("psi|log_sd_tier|log_sigma", names(par))]
    psi <- if (length(lp)) exp(2 * as.numeric(lp)) else rep(NA_real_, T0)
    tLL <- sum(rowSums(Lam^2)); sP <- sum(psi, na.rm = TRUE)
    out[[em]] <- list(
      status    = f$status,
      trace_LL  = tLL / sum(b$sigma_jj_true),
      mean_psi  = mean(psi, na.rm = TRUE),
      n_psi     = sum(is.finite(psi)),
      trace_tot = (tLL + sP) / sum(b$sigma_jj_true),
      psi_share = if ((tLL + sP) > 0) sP / (tLL + sP) else NA_real_,
      par_names = paste(unique(names(par)), collapse = ","))
  }
  out
}

res <- Filter(function(x) length(x) > 1L,
              mclapply(20261900L + seq_len(N_SEED),
                       function(s) tryCatch(one(s), error = function(e) NULL),
                       mc.cores = CORES, mc.preschedule = FALSE))
saveRDS(res, file.path(OUT, "230-psi-absorption.rds"))

cat(sprintf("\n======== psi ABSORPTION — probit n=%d p=%d q=%d, psi FREE, H=%d, %d seeds ========\n\n",
            N0, T0, Q0, HQ, length(res)))
cat("TRUE psi = 0 and TRUE psi_share = 0: the DGP plants Sigma_true = Lambda Lambda' exactly.\n\n")
cat(sprintf("%-5s %6s %11s %11s %11s %11s  %s\n",
            "arm", "n", "trace_LL", "mean_psi", "trace_tot", "psi_share", "status"))
tab <- list()
for (a in ARMS) {
  g <- Filter(function(x) !is.null(x[[a]]), res)
  if (!length(g)) { cat(sprintf("%-5s %6d  no fits\n", a, 0L)); next }
  m <- function(f) mean(vapply(g, function(x) x[[a]][[f]], numeric(1)), na.rm = TRUE)
  st <- paste(unique(vapply(g, function(x) x[[a]]$status, character(1))), collapse = ",")
  tab[[a]] <- c(trace_LL = m("trace_LL"), mean_psi = m("mean_psi"),
                trace_tot = m("trace_tot"), psi_share = m("psi_share"), n = length(g))
  cat(sprintf("%-5s %6d %11.4f %11.4f %11.4f %11.4f  %s\n",
              a, length(g), m("trace_LL"), m("mean_psi"), m("trace_tot"), m("psi_share"), st))
}
if (length(res)) cat(sprintf("\nparameters present: %s\n", res[[1]][[ARMS[1]]]$par_names %||% "?"))

if (!is.null(tab$ac) && !is.null(tab$gh)) {
  gp <- Filter(function(x) !is.null(x$ac) && !is.null(x$gh), res)
  d <- vapply(gp, function(x) x$ac$psi_share - x$gh$psi_share, numeric(1))
  md <- mean(d, na.rm = TRUE); ss <- 2 * stats::sd(d, na.rm = TRUE) / sqrt(sum(is.finite(d)))
  cat("\n-- PAIRED psi_share: ac - gh --\n")
  cat(sprintf("  %+.4f [%+.4f, %+.4f]  n=%d\n", md, md - ss, md + ss, sum(is.finite(d))))
  cat("\n-- VERDICT --\n")
  if (is.finite(md) && (md - ss) > 0)
    cat("  (a) ABSORPTION IS REAL: ac pushes significantly more variance into psi than gh.\n",
        " Shared latent structure is being reattributed to trait-specific noise, which\n",
        " makes traits look MORE INDEPENDENT than they are. This RAISES the severity of\n",
        " the attenuation finding beyond the ICC/R^2 effect.\n")
  else
    cat("  (b) NO DETECTABLE ABSORPTION: psi_share is not higher under ac. The attenuation\n",
        " shows up as a TOTAL variance deficit, which is the already-known ICC/R^2\n",
        " problem and nothing new. Severity unchanged.\n")
}
cat(sprintf("\n== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
