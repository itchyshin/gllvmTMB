## TEST C -- does the q = 1 AGHQ result transfer to q = 2?
##
## dev/aghq-scope-accuracy-crux.md measured, at q = 1, n = 2000, T = 20:
##   Laplace (k=1) attenuation 0.8968 -> AGHQ (k=15) 0.9507, c_full ~ 1.0295
## and named this the biggest blocker on the AGHQ-Laplace proposal:
##
##   "TEST C -- the q = 2 transfer check (the one that closes my biggest
##    blocker). Prediction: c_full in the 1.02-1.04 band, as at q = 1.
##    KILL RULE: if q = 2 c_full < 1.01, the headline does not transfer and
##    the proposal is dead regardless of TEST A/B."
##
## Ayumi's cell is q = 2, so a q = 1-only result cannot carry the claim.
##
## Self-contained by design: AGHQ is compared against its OWN k = 1 special
## case, which IS exactly Laplace, on identical data.
##
## FULLY VECTORISED at q = 2. The first version (archived as
## aghq-crux-q2-transfer-v1-slow.R) looped over units in R for both the Newton
## solve and the node accumulation -- 2n small matrix operations per objective
## call, times ~60 evaluations per BFGS gradient step over 59 parameters. It did
## not finish. At q = 2 every per-unit 2x2 operation has a closed form, so the
## only remaining loop is over the k^2 nodes:
##   H = [[h11,h12],[h12,h22]],  h11 = 1 + W %*% lam1^2, etc.
##   2x2 inverse via det
##   chol R upper: r11 = sqrt(h11), r12 = h12/r11, r22 = sqrt(h22 - r12^2)
##   R^{-1}x by back-substitution: z2 = x2/r22, z1 = (x1 - r12 z2)/r11

Q  <- 2L
TT <- 20L
NN <- as.integer(Sys.getenv("NN", "2000"))
KK <- as.integer(Sys.getenv("KK", "9"))
SEEDS <- as.integer(strsplit(Sys.getenv("SEEDS", "11,12,13,14,15"), ",")[[1]])
LAMBDA_SD <- 0.7 / sqrt(Q)   # match Lambda'Lambda per axis to the q=1 run
OUT <- Sys.getenv("OUTCSV", "dev/aghq-crux-q2-transfer.csv")

gh_rule <- function(k) {
  if (k == 1L) return(list(x = 0, w = sqrt(pi)))
  J <- matrix(0, k, k)
  off <- sqrt(seq_len(k - 1L) / 2)
  J[cbind(seq_len(k - 1L), 2:k)] <- off
  J[cbind(2:k, seq_len(k - 1L))] <- off
  e <- eigen(J, symmetric = TRUE); o <- order(e$values)
  list(x = e$values[o], w = sqrt(pi) * (e$vectors[1, o])^2)
}
gh_tensor <- function(k) {
  r <- gh_rule(k)
  g <- expand.grid(a = seq_along(r$x), b = seq_along(r$x))
  list(x1 = r$x[g$a], x2 = r$x[g$b], lw = log(r$w[g$a]) + log(r$w[g$b]))
}

lam_index <- which(row(matrix(0, TT, Q)) >= col(matrix(0, TT, Q)))
unpack <- function(par) {
  Lam <- matrix(0, TT, Q); Lam[lam_index] <- par[TT + seq_along(lam_index)]
  list(bet = par[seq_len(TT)], Lam = Lam)
}

simulate_cell <- function(seed) {
  set.seed(seed)
  Lam <- matrix(0, TT, Q)
  Lam[lam_index] <- rnorm(length(lam_index), sd = LAMBDA_SD)
  bet <- rnorm(TT, sd = 0.3)
  U <- matrix(rnorm(NN * Q), NN, Q)
  eta <- sweep(U %*% t(Lam), 2, bet, "+")
  list(Y = matrix(rbinom(NN * TT, 1L, plogis(eta)), NN, TT),
       Lam = Lam, bet = bet)
}

softplus <- function(e) log1p(exp(pmin(e, 30))) + pmax(e - 30, 0)

nll <- function(par, Y, grid, newton_it = 12L) {
  pu <- unpack(par); bet <- pu$bet; Lam <- pu$Lam
  n <- nrow(Y); l1 <- Lam[, 1]; l2 <- Lam[, 2]
  U1 <- numeric(n); U2 <- numeric(n)

  for (it in seq_len(newton_it)) {
    e <- sweep(outer(U1, l1) + outer(U2, l2), 2, bet, "+")
    p <- plogis(e); W <- p * (1 - p); Rs <- Y - p
    g1 <- U1 - as.vector(Rs %*% l1); g2 <- U2 - as.vector(Rs %*% l2)
    h11 <- as.vector(1 + W %*% (l1 * l1))
    h12 <- as.vector(W %*% (l1 * l2))
    h22 <- as.vector(1 + W %*% (l2 * l2))
    dt <- h11 * h22 - h12 * h12
    U1 <- U1 - (h22 * g1 - h12 * g2) / dt
    U2 <- U2 - (h11 * g2 - h12 * g1) / dt
  }

  e <- sweep(outer(U1, l1) + outer(U2, l2), 2, bet, "+")
  p <- plogis(e); W <- p * (1 - p)
  h11 <- as.vector(1 + W %*% (l1 * l1))
  h12 <- as.vector(W %*% (l1 * l2))
  h22 <- as.vector(1 + W %*% (l2 * l2))
  r11 <- sqrt(h11); r12 <- h12 / r11
  r22 <- sqrt(pmax(h22 - r12 * r12, 1e-12))
  logdetR <- log(r11) + log(r22)

  hfun <- function(u1, u2) {
    ee <- sweep(outer(u1, l1) + outer(u2, l2), 2, bet, "+")
    0.5 * (u1 * u1 + u2 * u2) - rowSums(Y * ee - softplus(ee))
  }
  h0 <- hfun(U1, U2)

  nn <- length(grid$x1)
  acc <- matrix(0, n, nn)
  for (j in seq_len(nn)) {
    z2 <- grid$x2[j] / r22
    z1 <- (grid$x1[j] - r12 * z2) / r11
    acc[, j] <- grid$lw[j] + grid$x1[j]^2 + grid$x2[j]^2 -
      (hfun(U1 + sqrt(2) * z1, U2 + sqrt(2) * z2) - h0)
  }
  m <- apply(acc, 1L, max)
  ls <- m + log(rowSums(exp(acc - m)))
  -sum(-logdetR - (Q / 2) * log(pi) + ls - h0)
}

fit_arm <- function(Y, k, start, maxit = 300L) {
  optim(start, nll, Y = Y, grid = gh_tensor(k), method = "BFGS",
        control = list(maxit = maxit, reltol = 1e-10))
}
atten <- function(Lh, Lt) sum(Lh * Lh) / sum(Lt * Lt)

cat(sprintf("TEST C: q=%d n=%d T=%d k=%d (%d nodes) seeds=%s\n\n",
            Q, NN, TT, KK, KK^2, paste(SEEDS, collapse = ",")))

rows <- list()
for (sd_i in SEEDS) {
  cell <- simulate_cell(sd_i)
  start <- c(rep(0, TT), rep(0.3, length(lam_index)))

  t0 <- proc.time()[["elapsed"]]
  fLA <- fit_arm(cell$Y, 1L, start); t_la <- proc.time()[["elapsed"]] - t0
  t0 <- proc.time()[["elapsed"]]
  fAG <- fit_arm(cell$Y, KK, fLA$par); t_ag <- proc.time()[["elapsed"]] - t0

  aLA <- atten(unpack(fLA$par)$Lam, cell$Lam)
  aAG <- atten(unpack(fAG$par)$Lam, cell$Lam)
  cf <- sqrt(aAG / aLA)

  rows[[length(rows) + 1L]] <- data.frame(
    seed = sd_i, atten_LA = aLA, atten_AGHQ = aAG, c_full = cf,
    obj_LA = fLA$value, obj_AGHQ = fAG$value,
    t_la = round(t_la, 1), t_ag = round(t_ag, 1),
    cost_ratio = round(t_ag / t_la, 2))
  utils::write.csv(do.call(rbind, rows), OUT, row.names = FALSE)
  cat(sprintf("seed %d  atten LA=%.4f AGHQ=%.4f  c_full=%.4f  %.0fs/%.0fs=%.2fx\n",
              sd_i, aLA, aAG, cf, t_la, t_ag, t_ag / t_la)); flush(stdout())
}

d <- do.call(rbind, rows)
cat("\n================= TEST C VERDICT =================\n")
cat(sprintf("mean atten LA   : %.4f\n", mean(d$atten_LA)))
cat(sprintf("mean atten AGHQ : %.4f\n", mean(d$atten_AGHQ)))
cat(sprintf("mean c_full     : %.4f   (q=1 reference 1.0295)\n", mean(d$c_full)))
cat(sprintf("median cost     : %.2fx  (q=1 reference 1.67x)\n", median(d$cost_ratio)))
cat(sprintf("seeds c_full > 1: %d/%d\n", sum(d$c_full > 1), nrow(d)))
cat("\nKILL RULE: mean c_full < 1.01 => the headline does NOT transfer.\n")
cat(sprintf("VERDICT: %s\n",
  if (mean(d$c_full) < 1.01) "DEAD -- does not transfer to q=2" else
  if (mean(d$c_full) <= 1.04) "TRANSFERS -- inside the predicted 1.02-1.04 band" else
  "TRANSFERS, stronger than predicted"))
