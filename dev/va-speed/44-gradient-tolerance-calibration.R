## OWED step 3 (handover 2026-08-03-claude-handover-va-lane2): coverage blocker 1.
##
## The health gate uses a FIXED ABSOLUTE bar, max|gradient| < 1e-4, on a quantity
## that is EXTENSIVE -- the gradient of an NLL summed over n_obs = N*T rows. The
## pilot showed the consequence: 0/30 healthy at BOTH primary cells (n=150, n=400)
## while the out-of-regime n=50 cell gave 23/30, with all four starts converging to
## objectives agreeing to 6+ significant figures and max|gradient| in [1e-4, 7e-4].
##
## This script does NOT assume a replacement constant. It MEASURES the separation:
##   POSITIVE control -- fits run to convergence (the starts the gate should admit)
##   NEGATIVE control -- the same cells deliberately truncated (eval.max/iter.max
##                       tiny), i.e. genuinely un-converged starts the gate MUST
##                       still reject.
## A candidate rule is only defensible if it admits every positive and rejects
## every negative across the whole n range. Both classes are written to disk so the
## calibration can be re-derived rather than taken on trust.
##
## Usage: Rscript 44-gradient-tolerance-calibration.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

`%||%` <- function(a, b) if (is.null(a)) b else a
LANE <- Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2")
setwd(LANE)
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())

T0 <- 8L; Q0 <- 2L; PSI_LO <- 0.3; PSI_HI <- 0.5
N_GRID <- c(50L, 150L, 400L)
SEEDS  <- c(20260801L, 20260802L, 20260803L)

## Same DGP as 41-va-health-diag.R (the script that produced the pilot's numbers).
mk <- function(N0, SEED) {
  set.seed(SEED)
  Lambda <- matrix(0, T0, Q0)
  for (k in seq_len(Q0)) Lambda[k, k] <- stats::runif(1, 0.7, 1.3)
  for (k in 1:(Q0 - 1)) for (kk in (k + 1):Q0) Lambda[kk, k] <- stats::runif(1, -0.5, 0.5)
  for (t in (Q0 + 1):T0) Lambda[t, ] <- stats::rnorm(Q0, 0, 0.7)
  psi_true <- stats::runif(T0, PSI_LO, PSI_HI)
  beta_true <- stats::rnorm(T0, 0, 0.5)
  z <- matrix(stats::rnorm(N0 * Q0), N0, Q0)
  x <- stats::rnorm(N0)
  eta <- outer(x, beta_true) + z %*% t(Lambda)
  y <- eta + matrix(stats::rnorm(N0 * T0, 0, sqrt(rep(psi_true, each = N0))), N0, T0)
  data.frame(y = as.numeric(t(y)), trait = factor(rep(seq_len(T0), times = N0)),
             unit = factor(rep(seq_len(N0), each = T0)), x = rep(x, each = T0))
}

fit_cell <- function(N0, SEED, ctrl) {
  d <- mk(N0, SEED)
  Xva <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = d))
  do.call(gllvmTMB:::.va_r3_fit, list(
    y = d$y, n_trials = rep(1L, nrow(d)), X = Xva,
    unit_id = as.integer(d$unit), trait_id = as.integer(d$trait),
    q = Q0, family = "gaussian_anchor", link = "identity",
    unique = FALSE, psi = FALSE, estimate_gaussian_sd = TRUE,
    n_starts = 4L, control = ctrl
  ))
}

CONVERGED <- list(eval.max = 2000L, iter.max = 2000L)
TRUNCATED <- list(eval.max = 12L,   iter.max = 6L)

rows <- list()
for (N0 in N_GRID) for (SEED in SEEDS) for (cls in c("converged", "truncated")) {
  ctrl <- if (cls == "converged") CONVERGED else TRUNCATED
  t0 <- proc.time()[["elapsed"]]
  f <- try(fit_cell(N0, SEED, ctrl), silent = TRUE)
  el <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "try-error")) {
    cat(sprintf("N=%d seed=%d %s ERROR: %s\n", N0, SEED, cls,
                conditionMessage(attr(f, "condition")))); flush.console()
    next
  }
  for (k in seq_along(f$starts)) {
    fk <- f$starts[[k]]
    rows[[length(rows) + 1L]] <- data.frame(
      N = N0, seed = SEED, class = cls, start = k,
      n_obs = N0 * T0,
      objective = fk$objective %||% NA_real_,
      max_abs_gradient = fk$max_abs_gradient %||% NA_real_,
      convergence = fk$convergence %||% NA_integer_,
      healthy_under_1e4 = isTRUE(fk$healthy),
      secs = el, stringsAsFactors = FALSE
    )
  }
  best_obj <- min(vapply(f$starts, function(z) z$objective %||% NA_real_, numeric(1)), na.rm = TRUE)
  cat(sprintf("N=%4d seed=%d %-9s  best_obj=%.6f  grads=[%s]  healthy=%d/4  %.1fs\n",
              N0, SEED, cls, best_obj,
              paste(sprintf("%.3g", vapply(f$starts, function(z) z$max_abs_gradient %||% NA_real_, numeric(1))),
                    collapse = ", "),
              sum(vapply(f$starts, function(z) isTRUE(z$healthy), logical(1))), el))
  flush.console()
}

res <- do.call(rbind, rows)
saveRDS(res, "dev/va-speed/44-gradient-calibration.rds")

cat("\n================ CALIBRATION ================\n")
pos <- res[res$class == "converged" & is.finite(res$max_abs_gradient), ]
neg <- res[res$class == "truncated" & is.finite(res$max_abs_gradient), ]
cat(sprintf("positives (converged starts): n=%d  max|g| range [%.3g, %.3g]\n",
            nrow(pos), min(pos$max_abs_gradient), max(pos$max_abs_gradient)))
cat(sprintf("negatives (truncated starts): n=%d  max|g| range [%.3g, %.3g]\n",
            nrow(neg), min(neg$max_abs_gradient), max(neg$max_abs_gradient)))

## Candidate rules, scored on BOTH controls. A rule is only usable if it admits
## 100% of positives AND rejects 100% of negatives.
score <- function(label, thr_pos, thr_neg) {
  data.frame(rule = label,
             pos_admitted = sprintf("%d/%d", sum(pos$max_abs_gradient < thr_pos), nrow(pos)),
             neg_rejected = sprintf("%d/%d", sum(neg$max_abs_gradient >= thr_neg), nrow(neg)),
             stringsAsFactors = FALSE)
}
cands <- rbind(
  score("absolute 1e-4 (current)", 1e-4, 1e-4),
  score("1e-6 * (1 + |f|)", 1e-6 * (1 + abs(pos$objective)), 1e-6 * (1 + abs(neg$objective))),
  score("1e-5 * (1 + |f|)", 1e-5 * (1 + abs(pos$objective)), 1e-5 * (1 + abs(neg$objective))),
  score("1e-7 * n_obs",     1e-7 * pos$n_obs,               1e-7 * neg$n_obs),
  score("1e-6 * n_obs",     1e-6 * pos$n_obs,               1e-6 * neg$n_obs),
  score("1e-4 * sqrt(n_obs/400)", 1e-4 * sqrt(pos$n_obs / 400), 1e-4 * sqrt(neg$n_obs / 400))
)
print(cands, row.names = FALSE)
cat("\nper-cell detail:\n")
print(res[, c("N", "seed", "class", "start", "n_obs", "objective",
              "max_abs_gradient", "healthy_under_1e4")], row.names = FALSE, digits = 6)
cat("\n== calibration DONE ==\n")
