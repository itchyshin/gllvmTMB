## dev/phylo-multinomial-recovery-harness.R — Tier-2b item 3 recovery campaign
##
## Compares TWO estimators of the (K-1)x(K-1) among-category phylogenetic covariance V of a
## multinomial trait, against a KNOWN true V, from ONE categorical draw per species:
##   (M-gllvm) gllvmTMB phylo_latent reduced-rank MLE   -> extract_Sigma(level="phy") latent V
##   (M-gold ) MCMCglmm parameter-expanded us(trait):species -> posterior-MEAN G
## The headline target is the CORRELATION rho = V12/sqrt(V11*V22), which is INVARIANT to the
## residual/link-scale convention (item 1's (pi^2/6)(I+J) vs MCMCglmm's (1/K)(I+J)) -- so the two
## estimators are directly comparable on rho without a scale reconciliation. (Variances are also
## reported for the record; those DO carry the scale convention.)
##
## Extends dev/phylo-multinomial-harness-DRAFT.R (prior session, MCMCglmm-only) per its own S4b TODO.
## COMPUTE: local smoke first, then Totoro (D-50: never GitHub Actions). Multi-seed always.
##
## Usage:
##   Rscript dev/phylo-multinomial-recovery-harness.R                       # smoke: N=150, 3 seeds, nitt=12000
##   Rscript dev/phylo-multinomial-recovery-harness.R 150,400,1000 40 60000 # ladder, 40 seeds

Sys.setenv(OPENBLAS_NUM_THREADS = "1")
.args    <- commandArgs(trailingOnly = TRUE)
N_LADDER <- if (length(.args) >= 1L) as.integer(strsplit(.args[[1]], ",")[[1]]) else 150L
N_SEED   <- if (length(.args) >= 2L) as.integer(.args[[2]]) else 3L
NITT     <- if (length(.args) >= 3L) as.integer(.args[[3]]) else 12000L
M_REPS   <- if (length(.args) >= 4L) as.integer(.args[[4]]) else 1L   # draws per species (replication arm)
N_CORES  <- min(96L, max(1L, as.integer(Sys.getenv("HARNESS_CORES", "4"))))
PKG_DIR  <- Sys.getenv("GLLVMTMB_DIR", ".")

ok_pkgs <- all(vapply(c("ape", "MCMCglmm", "MASS"), requireNamespace, logical(1), quietly = TRUE))
if (!ok_pkgs) { cat("SKIP: need ape + MCMCglmm + MASS.\n"); quit(save = "no", status = 0) }
suppressMessages({ library(ape); library(MCMCglmm); devtools::load_all(PKG_DIR, quiet = TRUE) })

## ---- fixed truth ----------------------------------------------------------
K        <- 3L
RHO_TRUE <- 0.6
SD_TRUE  <- c(1.0, 1.0)
V_TRUE   <- diag(SD_TRUE) %*% matrix(c(1, RHO_TRUE, RHO_TRUE, 1), 2) %*% diag(SD_TRUE)
B0_TRUE  <- c(0.2, -0.3)

.getS <- function(x) if (is.matrix(x)) x else if (!is.null(x$Sigma)) x$Sigma else x[[1L]]
.rho  <- function(V) if (is.matrix(V) && all(is.finite(V)) && V[1,1] > 0 && V[2,2] > 0)
  V[1,2] / sqrt(V[1,1] * V[2,2]) else NA_real_

## ---- one replicate: simulate once, recover V with BOTH estimators ---------
run_one <- function(N, seed, nitt = NITT, m = M_REPS) {
  set.seed(seed)
  tree <- rcoal(N); tree$tip.label <- paste0("sp", seq_len(N))
  A    <- vcv(tree, corr = TRUE)
  G    <- kronecker(V_TRUE, A)
  a    <- MASS::mvrnorm(1, mu = rep(0, (K - 1L) * N), Sigma = G)
  Amat <- matrix(a, nrow = N, ncol = K - 1L)
  eta  <- cbind(0, sweep(Amat, 2, B0_TRUE, `+`))
  P    <- exp(eta - apply(eta, 1, max)); P <- P / rowSums(P)
  ## m categorical draws per species (replication arm): each species keeps its
  ## latent a_i; the m observations are i.i.d. softmax(eta_i). m = 1 is the
  ## one-per-species regime; m > 1 is the information-rich control.
  sp_idx <- rep(seq_len(N), each = m)
  y    <- vapply(sp_idx, function(i) sample.int(K, 1, prob = P[i, ]), integer(1))
  sp   <- factor(tree$tip.label[sp_idx], levels = tree$tip.label)

  ## (M-gold) MCMCglmm parameter-expanded posterior mean
  Ainv <- inverseA(tree)$Ainv
  I <- diag(K - 1L); J <- matrix(1, K - 1L, K - 1L)
  prior <- list(
    R = list(V = (1 / K) * (I + J), fix = 1),
    G = list(G1 = list(V = diag(K - 1L), nu = K - 1L,
                       alpha.mu = rep(0, K - 1L), alpha.V = diag(K - 1L) * 25^2)))
  df_mc <- data.frame(species = sp, y = factor(y))
  rho_mcmc <- tryCatch({
    ## NB: name this `fit_mc`, NOT `m` -- `tryCatch` evaluates in the caller's
    ## frame, so `m <- MCMCglmm(...)` would clobber the `m` draws-per-species
    ## argument (the return row carries `m = m`), flattening the fit object into
    ## the result and failing every row's numeric sanity check.
    fit_mc <- MCMCglmm(y ~ trait - 1, random = ~ us(trait):species, rcov = ~ us(trait):units,
                  family = "categorical", ginverse = list(species = Ainv), prior = prior,
                  data = df_mc, nitt = nitt, burnin = as.integer(nitt * 0.25),
                  thin = max(25L, as.integer(nitt / 2000)), verbose = FALSE)
    Gcols <- grep("^traity.*:traity.*\\.species$", colnames(fit_mc$VCV))
    Gpost <- matrix(colMeans(fit_mc$VCV[, Gcols, drop = FALSE]), K - 1L, K - 1L)
    .rho(Gpost)
  }, error = function(e) NA_real_)

  ## (M-gllvm) gllvmTMB phylo_latent reduced-rank MLE, latent V (link_residual = "none")
  df_g <- data.frame(species = sp, trait = factor("morph"), value = factor(y))
  rho_gllvm <- tryCatch({
    fit <- suppressWarnings(suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = K - 1L, tree = tree),
      data = df_g, family = multinomial(), trait = "trait", unit = "species")))
    Vg <- .getS(extract_Sigma(fit, level = "phy", link_residual = "none"))
    .rho(Vg)
  }, error = function(e) NA_real_)

  ## Coerce every field to a length-1 numeric so a single odd leg return
  ## (NULL / empty / non-scalar) cannot corrupt the row (mixed-type c() would
  ## silently coerce the whole vector to character, or a NULL would shorten it).
  num1 <- function(x) { x <- suppressWarnings(as.numeric(x)); if (length(x) == 1L) x else NA_real_ }
  rg <- num1(rho_gllvm); rm_ <- num1(rho_mcmc)
  c(N = N, m = m, seed = seed, rho_gllvm = rg, rho_mcmc = rm_,
    railed_gllvm = as.numeric(is.finite(rg) && abs(rg) > 0.99))
}

## ---- run the ladder -------------------------------------------------------
grid <- expand.grid(N = N_LADDER, seed = seq_len(N_SEED) + 84L)
cat(sprintf("RECOVERY N=%s x %d seeds, m=%d draws/species, nitt=%d, cores=%d, rho_true=%.2f\n",
            paste(N_LADDER, collapse = "/"), N_SEED, M_REPS, NITT, N_CORES, RHO_TRUE))
res <- parallel::mclapply(seq_len(nrow(grid)),
                          function(i) run_one(grid$N[i], grid$seed[i]),
                          mc.cores = N_CORES)
## Robustness: mclapply returns a condition object if a worker throws an
## uncaught error (or is killed). Keep only well-formed length-6 numeric rows;
## report and drop the rest rather than crashing the whole ladder.
ok <- vapply(res, function(x) is.numeric(x) && length(x) == 6L, logical(1))
if (any(!ok)) {
  cat(sprintf("WARN: %d/%d workers failed and were dropped:\n", sum(!ok), length(ok)))
  for (i in which(!ok)) cat("  cell", i, ":", paste(utils::head(as.character(res[[i]]), 1), collapse=" "), "\n")
}
res <- as.data.frame(do.call(rbind, res[ok]))
saveRDS(res, file.path(PKG_DIR, "dev",
        sprintf("recovery-raw-%s-m%d.rds", paste(N_LADDER, collapse = "_"), M_REPS)))

## ---- aggregate: bias +/- MCSE per estimator per rung ----------------------
mcse <- function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))
agg <- do.call(rbind, lapply(sort(unique(res$N)), function(n) {
  rg <- res$rho_gllvm[res$N == n]; rm_ <- res$rho_mcmc[res$N == n]
  data.frame(N = n, n_ok_g = sum(!is.na(rg)), n_ok_m = sum(!is.na(rm_)),
             rho_gllvm = mean(rg, na.rm = TRUE), mcse_g = mcse(rg),
             bias_gllvm = mean(rg, na.rm = TRUE) - RHO_TRUE,
             rail_rate_g = mean(res$railed_gllvm[res$N == n], na.rm = TRUE),
             rho_mcmc = mean(rm_, na.rm = TRUE), mcse_m = mcse(rm_),
             bias_mcmc = mean(rm_, na.rm = TRUE) - RHO_TRUE)
}))
cat("\n===== RECOVERY LADDER (rho_true =", RHO_TRUE, ") =====\n"); print(round(agg, 4))
cat("\nInterpretation: rho is scale-invariant, so rho_gllvm vs rho_mcmc is a fair cross-check.\n")
cat("Watch: gllvmTMB rail_rate (|rho|>0.99) at low N is the one-per-species collapse; does it fall with N?\n")
