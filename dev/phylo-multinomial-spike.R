## dev/phylo-multinomial-spike.R — feasibility spike for Design 84 (Tier 2a)
##
## Question: is the among-category evolutionary covariance V of a PHYLOGENETIC
## multinomial recoverable at all, and is the identification (FIX the latent-scale
## residual) actually necessary/sufficient? This proves the *estimand* and gives a
## reference (MCMCglmm) the future gllvmTMB phylo-factor-multinomial build must match.
##
## Model (Design 84): y_i in {1..K} (unordered), baseline category 1 pinned at 0,
##   eta_ij = b0_j + a_ij   (j = 2..K),  a_i ~ MVN(0, V (x) A),   softmax draw,
## where V is the (K-1)x(K-1) among-category covariance and A the phylo correlation.
## We simulate a KNOWN V (correlation rho between the two category liabilities) and
## recover it with MCMCglmm family="categorical" (+ sparse ginverse A^-1, fixed R).
##
## Toy scale, ~minutes. Not a package test — a design-time proof. Run locally.

set.seed(84)
## optional args: N (species) and nitt (MCMC iterations). Bigger = better recovery.
.args <- commandArgs(trailingOnly = TRUE)
N     <- if (length(.args) >= 1L) as.integer(.args[[1]]) else 250L
NITT  <- if (length(.args) >= 2L) as.integer(.args[[2]]) else 60000L
ok_pkgs <- all(vapply(c("ape", "MCMCglmm", "MASS"), requireNamespace, logical(1),
                      quietly = TRUE))
if (!ok_pkgs) {
  cat("SKIP: need ape + MCMCglmm + MASS installed. Install with:\n",
      "  install.packages(c('ape','MCMCglmm'))\n")
  quit(save = "no", status = 0)
}
suppressMessages({library(ape); library(MCMCglmm)})

## --- 1. toy tree + phylo correlation A -------------------------------------
## (N comes from the optional first arg, default 250 — see top.)
tree <- rcoal(N)                       # ultrametric coalescent tree
tree$tip.label <- paste0("sp", seq_len(N))
A    <- vcv(tree, corr = TRUE)         # NxN phylogenetic correlation

## --- 2. TRUE among-category covariance V (K = 3 -> 2x2) ---------------------
K       <- 3L
rho_true <- 0.6                        # <<< the correlation we must recover
sd_true  <- c(1.0, 1.0)
V_true   <- diag(sd_true) %*% matrix(c(1, rho_true, rho_true, 1), 2) %*% diag(sd_true)
b0_true  <- c(0.2, -0.3)               # per-category intercepts (cat 2, 3 vs 1)

## --- 3. simulate phylo random effects a ~ MVN(0, V (x) A) -------------------
## kronecker(V, A) orders as [cat-block] x [species]: a[1:N]=cat2, a[N+1:2N]=cat3.
G   <- kronecker(V_true, A)
a   <- MASS::mvrnorm(1, mu = rep(0, (K - 1L) * N), Sigma = G)
Amat <- matrix(a, nrow = N, ncol = K - 1L)      # N x (K-1) liabilities

## --- 4. softmax draw of the categorical response ---------------------------
eta  <- cbind(0, sweep(Amat, 2, b0_true, `+`))  # N x K, baseline col = 0
P    <- exp(eta - apply(eta, 1, max)); P <- P / rowSums(P)
y    <- vapply(seq_len(N), function(i) sample.int(K, 1, prob = P[i, ]), integer(1))
df   <- data.frame(species = factor(tree$tip.label, levels = tree$tip.label),
                   y = factor(y))
cat(sprintf("simulated: N=%d, K=%d, category counts = %s\n",
            N, K, paste(table(df$y), collapse = "/")))

## --- 5. MCMCglmm phylo multinomial: recover V ------------------------------
Ainv <- inverseA(tree)$Ainv            # sparse A^-1 for ginverse
I <- diag(K - 1L); J <- matrix(1, K - 1L, K - 1L)
## IDENTIFICATION: residual (R-structure) FIXED (latent scale not identified).
prior <- list(
  R = list(V = (1 / K) * (I + J), fix = 1),                       # fixed residual
  G = list(G1 = list(V = diag(K - 1L), nu = K - 1L,
                     alpha.mu = rep(0, K - 1L),
                     alpha.V = diag(K - 1L) * 25^2))               # parameter-expanded
)
cat("fitting MCMCglmm (family=categorical, us(trait):species, fixed R)...\n")
m <- MCMCglmm(y ~ trait - 1,
              random  = ~ us(trait):species,
              rcov    = ~ us(trait):units,
              family  = "categorical",
              ginverse = list(species = Ainv),
              prior   = prior, data = df,
              nitt = NITT, burnin = as.integer(NITT * 0.25),
              thin = max(25L, as.integer(NITT / 2000)),
              verbose = FALSE)

## --- 6. read off recovered V + correlation ---------------------------------
Gcols  <- grep("^traity.*:traity.*\\.species$", colnames(m$VCV))
Gpost  <- matrix(colMeans(m$VCV[, Gcols, drop = FALSE]), K - 1L, K - 1L)
rho_hat <- Gpost[1, 2] / sqrt(Gpost[1, 1] * Gpost[2, 2])
cat("\n===== RESULT =====\n")
cat("true  V:\n"); print(round(V_true, 3))
cat("est   V (posterior mean, us(trait):species):\n"); print(round(Gpost, 3))
cat(sprintf("true rho = %.3f  |  recovered rho = %.3f\n", rho_true, rho_hat))
cat(sprintf("VERDICT: %s (among-category phylo correlation %s recovered)\n",
            if (abs(rho_hat - rho_true) < 0.25) "PASS" else "CHECK",
            if (abs(rho_hat - rho_true) < 0.25) "IS" else "NOT clearly"))
cat("\nInterpretation: this is the (K-1)x(K-1) V that Design 84's phylo-factor\n",
    "route (Sigma = Lambda Lambda^T + diag(psi) under phylo_latent) must reproduce.\n")
