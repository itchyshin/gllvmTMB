## Tier-2 pilot: GBIF effort ladder on the sealed Paper 1 truth.
## Maintainer-authorized diagnostic. No sealed root is written. Fresh data are
## simulated FROM the retained truth; only GBIF effort (offset) changes.
suppressMessages({library(TMB); library(Matrix)})
setwd("/private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde")

V3 <- "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3"
V2 <- "dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V2"
s  <- readRDS(file.path(V3, "v2-materialized-state.rds"))
fx <- readRDS(file.path(V2, "fixture.rds"))
d  <- s$data
tr <- fx$truth
rows <- fx$rows

cat("=== PART 0: byte gate -- rebuild y from the retained truth ===\n")
gbif   <- rows$source == "gbif"
cellIx <- match(rows$cell,  tr$cells)
spIx   <- match(rows$trait, tr$species)
eta_e  <- tr$eta_ecological[cbind(cellIx, spIx)]
eta_b  <- tr$eta_gbif_field[cbind(cellIx, spIx)]
gamma_true <- tr$constants$gbif_fixed_bias
fixed_bias <- tr$b[cellIx] * unname(gamma_true[rows$trait])
mu_gbif    <- rows$support * exp(eta_e + fixed_bias + eta_b)
p_pa       <- -expm1(-rows$support * exp(eta_e))

set.seed(tr$draw_seeds[["gbif_response"]])
y_re <- rows$value
y_re[gbif] <- rpois(sum(gbif), mu_gbif[gbif])
set.seed(tr$draw_seeds[["survey_response"]])
y_re[!gbif] <- rbinom(sum(!gbif), 1L, p_pa[!gbif])

cat("  rebuilt vs fixture rows$value identical:", identical(as.double(y_re), as.double(rows$value)), "\n")
cat("  fixture rows$value vs sealed d$y identical:", identical(as.double(rows$value), as.double(d$y)), "\n")
if (!identical(as.double(y_re), as.double(rows$value)) ||
    !identical(as.double(rows$value), as.double(d$y))) stop("BYTE GATE FAILED -- do not proceed")
cat("  BYTE GATE PASSED: the DGP reconstruction is exact.\n\n")

## consistency: GBIF rows in d are Z_spde_lat[,2]==1 and must align with rows$source
stopifnot(identical(which(gbif), which(d$Z_spde_lat[, 2] == 1)))
lam_bias_true <- unname(tr$lambda_bias)
q_true <- unname(tr$q)
cat(sprintf("truth: ||lambda_bias|| = %.4f, q = log kappa = %.4f, gamma = (%s)\n\n",
            sqrt(sum(lam_bias_true^2)), q_true,
            paste(format(unname(gamma_true), digits = 4), collapse = ", ")))

dyn.load("src/gllvmTMB.so")
X <- d$X_fix

fit_one <- function(E, seed) {
  dE <- d
  set.seed(seed)
  dE$y[gbif] <- as.double(rpois(sum(gbif), E * mu_gbif[gbif]))
  dE$offset_vec[gbif] <- d$offset_vec[gbif] + log(E)
  obj <- MakeADFun(data = dE, parameters = s$parameters, map = s$map,
                   random = s$random, DLL = "gllvmTMB", silent = TRUE)
  t0  <- proc.time()[3]
  opt <- nlminb(obj$par, obj$fn, obj$gr,
                control = list(iter.max = 500, eval.max = 1000))
  el  <- proc.time()[3] - t0
  th  <- opt$par
  g   <- as.vector(obj$gr(th))
  ## FD Hessian on the 22 fixed params for pdHess + slope-block spectrum
  hs <- .Machine$double.eps^(1/3) * pmax(1, abs(th))
  H  <- matrix(0, 22, 22)
  for (j in 1:22) {
    tp <- th; tp[j] <- tp[j] + hs[j]; tm <- th; tm[j] <- tm[j] - hs[j]
    H[, j] <- (as.vector(obj$gr(tp)) - as.vector(obj$gr(tm))) / (2 * hs[j])
  }
  H <- (H + t(H)) / 2
  ev  <- eigen(H, symmetric = TRUE, only.values = TRUE)$values
  evS <- eigen(H[20:22, 20:22], symmetric = TRUE, only.values = TRUE)$values
  lam <- th[20:22]
  ## sign orbit: report the representative aligned with the truth
  if (sum(lam * lam_bias_true) < 0) lam <- -lam
  gam_hat <- th[10:12]
  list(E = E, conv = opt$convergence, obj = opt$objective, sec = el,
       maxg = max(abs(g)), min_ev = min(ev), min_ev_slope = min(evS),
       pd = all(ev > 0),
       lam_norm = sqrt(sum(lam^2)),
       cos_truth = sum(lam * lam_bias_true) /
         (sqrt(sum(lam^2)) * sqrt(sum(lam_bias_true^2))),
       q_hat = th[16], gam_hat = gam_hat,
       counts = sum(dE$y[gbif]))
}

cat("=== PART 1: effort ladder (truth fixed; fresh Poisson noise per rung) ===\n")
res <- list()
for (E in c(1, 4, 16, 64)) {
  r <- fit_one(E, seed = 20260815 + E)
  res[[as.character(E)]] <- r
  cat(sprintf(
    "E=%3d | counts %6d | conv %d | %5.1fs | max|g| %.1e | pd %s | min_ev %+.2e (slope %+.2e) | ||lam|| %7.3f | cos %.3f | q %.4f\n",
    r$E, r$counts, r$conv, r$sec, r$maxg,
    if (r$pd) "T" else "F", r$min_ev, r$min_ev_slope,
    r$lam_norm, r$cos_truth, r$q_hat))
}
cat(sprintf("\ntruth               ||lam|| %7.3f |           | q %.4f\n",
            sqrt(sum(lam_bias_true^2)), q_true))
cat("gamma_hat by rung (truth ", paste(format(unname(gamma_true), digits=3), collapse=", "), "):\n")
for (r in res) cat(sprintf("  E=%3d: %s\n", r$E, paste(format(r$gam_hat, digits = 4), collapse = ", ")))
saveRDS(res, "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/5175b5d1-4ea3-4ee8-92c1-a3642cba0648/scratchpad/tier2-results.rds")
