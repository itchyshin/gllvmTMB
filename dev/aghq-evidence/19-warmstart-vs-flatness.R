## IS THE AGHQ SMALL-n FAILURE A WARM-START PROBLEM, OR A FLAT-LIKELIHOOD PROBLEM?
##
## WHY. The shipped-engine campaign (18-shipped-inc.csv) shows AGHQ failing at n = 100 in
## TWO distinguishable ways, and they have different fixes:
##
##   (a) INHERITANCE. seeds 2003, 2004: Laplace ran away (frob 29.700, 35.994) and AGHQ
##       returned a BYTE-IDENTICAL answer -- 15 significant figures, aghq_used = TRUE. The
##       quadrature moved nothing. That is the warm start: AGHQ begins at the Laplace
##       optimum and, in a runaway basin, never leaves.
##
##   (b) DEGRADATION. seeds 2001, 2005, 2006: Laplace was FINE (1.125, 0.850, 1.125) and
##       AGHQ moved AWAY to worse (1.794, 3.037, 1.522), 3 of 3 reporting convergence = 1.
##       A warm start cannot explain this. It started from a good point and left.
##
## (b) is the more damaging finding and it has an independent, already-recorded mechanism:
## the likelihood is FLAT in the direction that matters. Sweeping k = 5/9/15/21 at a
## converged optimum moves the objective < 0.01 nll while the argmin's ||Sigma_B||_F wanders
## 13.3 / 45.5 / 119.3 / 38.6. A MORE ACCURATE OBJECTIVE ON A FLAT DIRECTION BUYS NOTHING
## AND COSTS OPTIMISER STABILITY.
##
## WHAT THIS SCRIPT CAN TEST. The restart arms below vary the upstream Laplace
## multi-start route that supplies AGHQ's adaptation point. They do not start
## AGHQ itself from an independent cold point. A change between these arms can
## therefore show that Laplace restart selection propagates into AGHQ, but an
## unchanged or degraded result cannot distinguish cold-start AGHQ behaviour
## from a flat likelihood surface. The historical warm-start-versus-flatness
## interpretation is retracted; settling that question needs a genuinely
## independent AGHQ start construction.
##
## The 4th arm -- LAPLACE + RIDGE -- is included because it became reachable only at
## 4dc351ed. It is the fair control: if the ridge alone matches AGHQ + ridge, the credit for
## the small-n gain belongs to the PENALTY, not the QUADRATURE.
suppressWarnings(suppressMessages(library(parallel)))
LIB <- Sys.getenv("AGHQ_LIB", "")
if (nzchar(LIB)) .libPaths(c(LIB, .libPaths()))
suppressMessages(library(gllvmTMB))

OUT   <- Sys.getenv("WS_OUT", "19-warmstart-inc.csv")
CORES <- as.integer(Sys.getenv("WS_CORES", "12"))
if (file.exists(OUT)) file.remove(OUT)

## DGP byte-identical to 18-shipped-engine-campaign.R so the rows are comparable.
mk <- function(n, p, q, lam_sd, seed) {
  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y  <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
                            paste(colnames(Y), collapse = ", "), q))
  list(df = df, fml = fml, Lt = Lt)
}
corr_of <- function(S) { d <- sqrt(diag(S)); d[d <= 0] <- NA; S / outer(d, d) }

## Six seeds: the three DEGRADED (2001, 2005, 2006) and the two INHERITED (2003, 2004),
## plus 2002 (Laplace already runaway) so both regimes are represented.
SEEDS <- c(2001L, 2002L, 2003L, 2004L, 2005L, 2006L)
ARMS <- c("laplace", "laplace_ridge", "aghq", "aghq_ridge",
          "aghq_laplace_restart", "aghq_ridge_laplace_restart")
ctl_for <- function(arm) switch(arm,
  laplace         = gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE),
  ## reachable only since 4dc351ed -- naming aghq_ridge is what arms it on the Laplace path
  laplace_ridge   = gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE, aghq_ridge = 2),
  aghq            = gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE,
                                    aghq = 9, aghq_ridge = Inf),
  aghq_ridge      = gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE, aghq = 9),
  ## These arms vary the Laplace multi-start/restart route that supplies AGHQ.
  ## They are not cold-start AGHQ fits and must not be interpreted that way.
  aghq_laplace_restart = gllvmTMBcontrol(
    n_init = 5, init_jitter = 0.5, se = FALSE,
    aghq = 9, aghq_ridge = Inf, aghq_multistart = TRUE
  ),
  aghq_ridge_laplace_restart = gllvmTMBcontrol(
    n_init = 5, init_jitter = 0.5, se = FALSE,
    aghq = 9, aghq_multistart = TRUE
  ))

P <- 6L; Q <- 2L; N <- 100L
jobs <- expand.grid(seed = SEEDS, arm = ARMS, stringsAsFactors = FALSE)
cat(sprintf("warm-start vs flatness: %d fits on %d cores\n", nrow(jobs), CORES)); flush(stdout())

invisible(mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i, ]
  d  <- mk(N, P, Q, 1.0, jb$seed)
  St <- d$Lt %*% t(d$Lt); Rt <- corr_of(St); sg_t <- sqrt(diag(St)); off <- upper.tri(Rt)
  t0 <- Sys.time()
  f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(),
                                          control = ctl_for(jb$arm))),
                error = function(e) NULL)
  if (is.null(f)) return(NULL)
  L  <- f$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
  Sh <- L %*% t(L); Rh <- corr_of(Sh)
  row <- data.frame(
    seed = jb$seed, arm = jb$arm,
    aghq_used = isTRUE(f$aghq$used),
    frob_rat  = norm(L, "F") / norm(d$Lt, "F"),
    sigma_rat = median(sqrt(diag(Sh)) / sg_t),
    rho_absd  = mean(abs(Rh[off] - Rt[off]), na.rm = TRUE),
    obj       = tryCatch(f$opt$objective, error = function(e) NA_real_),
    conv      = tryCatch(f$opt$convergence, error = function(e) NA_integer_),
    elapsed_s = as.numeric(Sys.time() - t0, units = "secs"),
    stringsAsFactors = FALSE)
  utils::write.table(row, OUT, sep = ",", append = file.exists(OUT),
                     col.names = !file.exists(OUT), row.names = FALSE)
  row
}, mc.cores = CORES, mc.preschedule = FALSE))

r <- read.csv(OUT)
cat("\n=== frob_rat by seed x arm (1.000 = unbiased) ===\n")
w <- reshape(r[, c("seed", "arm", "frob_rat")], idvar = "seed",
             timevar = "arm", direction = "wide")
print(w, row.names = FALSE, digits = 4)
cat("\n=== non-convergence count by arm ===\n")
print(tapply(r$conv, r$arm, function(x) sum(x != 0, na.rm = TRUE)))
cat("\n=== median |frob-1| by arm (smaller better) ===\n")
print(round(sort(tapply(abs(r$frob_rat - 1), r$arm, median, na.rm = TRUE)), 4))
cat("\nDONE\n")
