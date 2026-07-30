## B0 — degeneracy-REACHABILITY pilot, Laplace only.
##
## Slice B asks: does gaussian VGH show the loading runaway at Laplace's rate?
## That test is VACUOUS unless gaussian *Laplace* degenerates in the chosen
## regime -- otherwise "VGH has no protection" is indistinguishable from "there
## is no pathology here to be protected from".  The handover's own lesson:
## "Design the DGP so the gated quantity can reach its threshold."
##
## So: find a gaussian regime where Laplace demonstrably degenerates, BEFORE
## comparing engines.  Laplace-only -- no dependency on dev/vgh/vgh-engine.R.
suppressPackageStartupMessages(library(gllvmTMB))

REPO <- "/private/tmp/gllvmtmb-vgh-pluralism"
OUT  <- file.path(REPO, "dev", "vgh", "gaussian-degeneracy-reachability.csv")

## Degeneracy definitions, BOTH reported (they disagree; see A4 in the plan).
##   rel_frob > 10                      -- Totoro grid / brain note / binomial half
##   atten_F outside [0.2, 2]           -- dev/vgh/phase0-matched-recovery.R:88-100
metrics <- function(Sigma_hat, Sigma_true) {
  atr <- sum(diag(Sigma_hat)) / sum(diag(Sigma_true))
  aF  <- sqrt(max(atr, 0))
  rf  <- norm(Sigma_hat - Sigma_true, "F") / norm(Sigma_true, "F")
  list(rel_frob = rf, atten_F = aF,
       degen_relfrob = isTRUE(rf > 10),
       degen_atten   = isTRUE(aF > 2 || aF < 0.2))
}

sim <- function(n, T, d_true, seed, lam_sd, sigma_eps) {
  set.seed(20260730L + 1000L * seed)
  Lam <- matrix(rnorm(T * d_true, 0, lam_sd), T, d_true)
  b0  <- rnorm(T, 0, 0.3)
  U   <- matrix(rnorm(n * d_true), n, d_true)
  Y   <- matrix(b0, n, T, byrow = TRUE) + U %*% t(Lam) +
    matrix(rnorm(n * T, 0, sigma_eps), n, T)
  list(Y = Y, Sigma_true = tcrossprod(Lam), Lambda = Lam)
}

fit_la <- function(Y, d_fit) {
  tn <- paste0("t", seq_len(ncol(Y)))
  df <- as.data.frame(Y); names(df) <- tn
  df$site <- factor(seq_len(nrow(Y)))
  fo <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(0 + trait | site, d = %d, unique = FALSE)",
    paste(tn, collapse = ", "), d_fit))
  suppressWarnings(gllvmTMB(fo, data = df, family = stats::gaussian()))
}

## Regimes chosen to VARY the things that drive a Heywood runaway: little data
## per parameter (small n, large T), an over-specified rank, and weak true
## signal (small lam_sd) relative to noise.
REGIMES <- list(
  list(tag = "heywood-analogue",  n =  60, T =  6, d_true = 2, d_fit = 2, lam_sd = 0.8, sigma_eps = 1),
  list(tag = "wide-small-n",      n =  40, T = 20, d_true = 2, d_fit = 2, lam_sd = 0.8, sigma_eps = 1),
  list(tag = "rank-overspec",     n =  60, T =  6, d_true = 1, d_fit = 3, lam_sd = 0.8, sigma_eps = 1),
  list(tag = "weak-signal",       n =  60, T =  8, d_true = 2, d_fit = 2, lam_sd = 0.15, sigma_eps = 1),
  list(tag = "weak+overspec",     n =  50, T = 12, d_true = 1, d_fit = 4, lam_sd = 0.15, sigma_eps = 1),
  list(tag = "tiny-n-wide",       n =  30, T = 15, d_true = 2, d_fit = 3, lam_sd = 0.5, sigma_eps = 1)
)
SEEDS <- 1:6

rows <- list()
for (rg in REGIMES) for (s in SEEDS) {
  D <- sim(rg$n, rg$T, rg$d_true, s, rg$lam_sd, rg$sigma_eps)
  t0 <- proc.time()[["elapsed"]]
  fit <- try(fit_la(D$Y, rg$d_fit), silent = TRUE)
  el <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "try-error")) {
    rows[[length(rows) + 1L]] <- data.frame(
      tag = rg$tag, n = rg$n, T = rg$T, d_true = rg$d_true, d_fit = rg$d_fit,
      lam_sd = rg$lam_sd, seed = s, status = "fit_error",
      rel_frob = NA_real_, atten_F = NA_real_, max_abs_loading = NA_real_,
      conv = NA_integer_, sec = el, stringsAsFactors = FALSE)
    next
  }
  S <- try(as.matrix(gllvmTMB::extract_Sigma_B(fit)$Sigma_B), silent = TRUE)
  if (inherits(S, "try-error")) { S <- NULL }
  m <- if (is.null(S)) list(rel_frob = NA_real_, atten_F = NA_real_) else
    metrics(S, D$Sigma_true)
  L <- tryCatch(as.matrix(fit$report$Lambda_B), error = function(e) NULL)
  rows[[length(rows) + 1L]] <- data.frame(
    tag = rg$tag, n = rg$n, T = rg$T, d_true = rg$d_true, d_fit = rg$d_fit,
    lam_sd = rg$lam_sd, seed = s, status = "ok",
    rel_frob = m$rel_frob, atten_F = m$atten_F,
    max_abs_loading = if (is.null(L)) NA_real_ else max(abs(L)),
    conv = tryCatch(as.integer(fit$opt$convergence), error = function(e) NA_integer_),
    sec = el, stringsAsFactors = FALSE)
  cat(sprintf("%-16s n=%3d T=%2d d=%d->%d seed=%d  rel_frob=%9.3f  atten_F=%7.3f  maxL=%9.2f  %5.1fs\n",
              rg$tag, rg$n, rg$T, rg$d_true, rg$d_fit, s,
              m$rel_frob, m$atten_F,
              if (is.null(L)) NA_real_ else max(abs(L)), el))
}

res <- do.call(rbind, rows)
write.csv(res, OUT, row.names = FALSE)

cat("\n================ REACHABILITY SUMMARY ================\n")
agg <- do.call(rbind, lapply(split(res, res$tag), function(d) data.frame(
  tag = d$tag[1], fits = nrow(d),
  median_rel_frob = round(median(d$rel_frob, na.rm = TRUE), 3),
  max_rel_frob    = round(max(d$rel_frob, na.rm = TRUE), 2),
  n_degen_relfrob = sum(d$rel_frob > 10, na.rm = TRUE),
  n_degen_atten   = sum(d$atten_F > 2 | d$atten_F < 0.2, na.rm = TRUE),
  max_abs_loading = round(max(d$max_abs_loading, na.rm = TRUE), 1),
  n_nonconv       = sum(d$conv != 0, na.rm = TRUE),
  stringsAsFactors = FALSE)))
print(agg, row.names = FALSE)
cat("\nTOTAL degenerate (rel_frob>10):", sum(res$rel_frob > 10, na.rm = TRUE),
    "of", sum(res$status == "ok"), "\n")
cat("TOTAL degenerate (atten_F out of [0.2,2]):",
    sum(res$atten_F > 2 | res$atten_F < 0.2, na.rm = TRUE),
    "of", sum(res$status == "ok"), "\n")
cat("\nVERDICT: if BOTH totals are 0, slice B's regime is NOT reachable as designed\n")
cat("and the comparison would be vacuous -- B needs a harsher regime before it runs.\n")
cat("wrote:", OUT, "\n")
