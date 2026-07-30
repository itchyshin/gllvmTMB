## dev/phylo-multinomial-harness-DRAFT.R — Tier-2a validation harness (Design 84, slice S4a/S4b)
##
## DRAFT — target the FRESH arc branch (off main), NOT claude/release-0.5.0. Move it there
## when the branch exists; do not commit on the release branch.
##
## Generalises the validated feasibility spike (dev/phylo-multinomial-spike.R) into a
## POWER-CALIBRATED CONSISTENCY LADDER, which is the load-bearing recovery gate for the arc:
## the spike recovered rho=0.6 as 0.45 at N=800. A single-N "within +/-0.25" pass CANNOT tell
## finite-sample under-power (estimate climbs toward truth with N) from asymptotic bias / scale
## mismatch (estimate plateaus below truth). This harness runs the ladder to distinguish them.
##
## Identification (Design 84 S3, PINNED): the latent-scale residual is FIXED, not estimated, to
##   R = (1/K) * (I + J)  on the (K-1) category contrasts   [MCMCglmm categorical convention].
## gllvmTMB's phylo-factor build must adopt the IDENTICAL residual so its reported V/rho lives on
## the same scale as this MCMCglmm reference (see S0(b) scale reconciliation in the ultra-plan).
##
## COMPUTE: Totoro (or DRAC) — NOT GitHub Actions (D-50). Pin OPENBLAS_NUM_THREADS=1 and cap
## parallelism (<= 96 cores on Totoro). SMOKE FIRST: run one (N=800, one seed) and confirm a
## non-NA, in-range rho_hat before launching the full ladder.
##
## Usage:
##   Rscript dev/phylo-multinomial-harness-DRAFT.R                 # smoke: N=800, 1 seed
##   Rscript dev/phylo-multinomial-harness-DRAFT.R 800,1600,3200 20 60000   # full ladder, 20 seeds

Sys.setenv(OPENBLAS_NUM_THREADS = "1")

.args   <- commandArgs(trailingOnly = TRUE)
N_LADDER <- if (length(.args) >= 1L) as.integer(strsplit(.args[[1]], ",")[[1]]) else 800L
N_SEED   <- if (length(.args) >= 2L) as.integer(.args[[2]]) else 1L
NITT     <- if (length(.args) >= 3L) as.integer(.args[[3]]) else 60000L
N_CORES  <- min(96L, max(1L, as.integer(Sys.getenv("HARNESS_CORES", "8"))))

ok_pkgs <- all(vapply(c("ape", "MCMCglmm", "MASS"), requireNamespace, logical(1), quietly = TRUE))
if (!ok_pkgs) {
  cat("SKIP: need ape + MCMCglmm + MASS. install.packages(c('ape','MCMCglmm'))\n")
  quit(save = "no", status = 0)
}
suppressMessages({library(ape); library(MCMCglmm)})

## ---- fixed truth (matches the spike) --------------------------------------
K        <- 3L
RHO_TRUE <- 0.6
SD_TRUE  <- c(1.0, 1.0)
V_TRUE   <- diag(SD_TRUE) %*% matrix(c(1, RHO_TRUE, RHO_TRUE, 1), 2) %*% diag(SD_TRUE)
B0_TRUE  <- c(0.2, -0.3)

## ---- one replicate: simulate a phylo multinomial, recover V via MCMCglmm ---
## Byte-faithful to dev/phylo-multinomial-spike.R except: seed and N are arguments, and we
## return the estimate rather than printing a verdict.
run_one <- function(N, seed, nitt = NITT) {
  set.seed(seed)
  tree <- rcoal(N); tree$tip.label <- paste0("sp", seq_len(N))
  A    <- vcv(tree, corr = TRUE)
  G    <- kronecker(V_TRUE, A)
  a    <- MASS::mvrnorm(1, mu = rep(0, (K - 1L) * N), Sigma = G)
  Amat <- matrix(a, nrow = N, ncol = K - 1L)
  eta  <- cbind(0, sweep(Amat, 2, B0_TRUE, `+`))
  P    <- exp(eta - apply(eta, 1, max)); P <- P / rowSums(P)
  y    <- vapply(seq_len(N), function(i) sample.int(K, 1, prob = P[i, ]), integer(1))
  df   <- data.frame(species = factor(tree$tip.label, levels = tree$tip.label), y = factor(y))
  Ainv <- inverseA(tree)$Ainv
  I <- diag(K - 1L); J <- matrix(1, K - 1L, K - 1L)
  prior <- list(
    R = list(V = (1 / K) * (I + J), fix = 1),                    # FIXED residual (identification)
    G = list(G1 = list(V = diag(K - 1L), nu = K - 1L,
                       alpha.mu = rep(0, K - 1L),
                       alpha.V = diag(K - 1L) * 25^2))
  )
  m <- tryCatch(
    MCMCglmm(y ~ trait - 1, random = ~ us(trait):species, rcov = ~ us(trait):units,
             family = "categorical", ginverse = list(species = Ainv), prior = prior,
             data = df, nitt = nitt, burnin = as.integer(nitt * 0.25),
             thin = max(25L, as.integer(nitt / 2000)), verbose = FALSE),
    error = function(e) NULL)
  if (is.null(m)) return(c(N = N, seed = seed, rho_hat = NA_real_, v11 = NA_real_, v22 = NA_real_))
  Gcols <- grep("^traity.*:traity.*\\.species$", colnames(m$VCV))
  Gpost <- matrix(colMeans(m$VCV[, Gcols, drop = FALSE]), K - 1L, K - 1L)
  c(N = N, seed = seed, rho_hat = Gpost[1, 2] / sqrt(Gpost[1, 1] * Gpost[2, 2]),
    v11 = Gpost[1, 1], v22 = Gpost[2, 2])
}

## ---- run the ladder (seeds in parallel, capped) ---------------------------
grid <- expand.grid(N = N_LADDER, seed = seq_len(N_SEED) + 84L)
cat(sprintf("LADDER N=%s x %d seeds, nitt=%d, cores=%d\n",
            paste(N_LADDER, collapse = "/"), N_SEED, NITT, N_CORES))
res <- parallel::mclapply(seq_len(nrow(grid)),
                          function(i) run_one(grid$N[i], grid$seed[i]),
                          mc.cores = N_CORES)
res <- as.data.frame(do.call(rbind, res))

## ---- aggregate: bias +/- MCSE per rung, and the ladder verdict ------------
mcse <- function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))
agg <- do.call(rbind, lapply(sort(unique(res$N)), function(n) {
  r <- res$rho_hat[res$N == n]
  data.frame(N = n, n_ok = sum(!is.na(r)), rho_mean = mean(r, na.rm = TRUE),
             mcse = mcse(r), bias = mean(r, na.rm = TRUE) - RHO_TRUE)
}))
cat("\n===== CONSISTENCY LADDER =====\n"); print(round(agg, 4))

## Verdict rule: does rho_mean climb toward RHO_TRUE as N grows (under-power, acceptable with a
## sample-size fence) or plateau below it (asymptotic bias -> STOP, revisit estimand/scale in S0)?
if (nrow(agg) >= 2L) {
  climbs <- all(diff(agg$rho_mean) > 2 * agg$mcse[-1])          # monotone rise beyond noise
  top_bias <- abs(agg$bias[nrow(agg)])
  cat(sprintf("\nrho_mean by N: %s\n", paste(round(agg$rho_mean, 3), collapse = " -> ")))
  if (climbs && top_bias < 0.10) {
    cat("VERDICT: UNDER-POWER (estimate climbs toward truth) -> acceptable; carry a sample-size fence.\n")
  } else if (top_bias >= 0.10 && (nrow(agg) < 2L || abs(diff(range(agg$rho_mean))) < 2 * max(agg$mcse))) {
    cat("VERDICT: ASYMPTOTIC BIAS / PLATEAU -> STOP; revisit estimand/scale (S0) before a covered claim.\n")
  } else {
    cat("VERDICT: MIXED -> extend the ladder (more N, more seeds) before deciding.\n")
  }
} else {
  cat("Single rung only (smoke). Extend to >=2 rungs for the consistency verdict.\n")
}

## ---- TODO for S4b (Codex, live) -------------------------------------------
## - Add the brms categorical + gr(cov=A) reference on a SHARED toy dataset, but VERIFY the scale
##   first (brms' implicit categorical residual differs from R=(1/K)(I+J)); rescale before comparing.
## - Add the gllvmTMB phylo-factor fit once S2a lands, and compare its extract_Sigma() V to V_TRUE
##   AND to the MCMCglmm posterior on the SAME (1/K)(I+J) scale.
## - Report per-parameter bias +/- 2*MCSE and a Wilson CI on the pass proportion (repo MCSE convention).
