## =====================================================================
## THE STRONGEST EVIDENCE IN ARC 2 — does the Stan side reconstruct the
## engine's PRECISION MATRIX STRUCTURE without ever seeing it?
##
## Origin: this test was constructed by the adversarial vacuity reviewer, not
## by the arc's author, and it is preserved here because it is a better
## instrument than any control the arc designed for itself. Without it the
## document's designated vacuity control (a one-sided perturbation of one
## internal node) was a near-cancellation understating the true curvature 27x.
##
## THE IDEA. Both sides are quadratic in the augmented scores, so:
##
##   second difference   lp(a_v + h) + lp(a_v - h) - 2 lp(a_v)  ->  -h^2 * P_vv
##   mixed difference    d^2 lp / da_u da_v                     ->  -P_uv
##
## The Stan model receives ONLY a parent map and branch lengths. If its mixed
## second differences reproduce the engine's sparse precision entry-for-entry
## -- nonzero exactly on parent-child pairs, exactly zero elsewhere -- then it
## has reconstructed the TOPOLOGY of the tree, not merely its dimension.
##
## A one-sided shift cannot show this. A dimension check cannot show this.
## =====================================================================

suppressMessages({ library(ape); library(Matrix); library(TMB); library(rstan) })
rstan_options(auto_write = TRUE)

pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-phylo-tree"
suppressMessages(devtools::load_all(pkg_root, quiet = TRUE))
here   <- file.path(pkg_root, "dev", "stan-oracle-phylo-tree")
stan_f <- file.path(here, "gllvm_phylo_tree.stan")
stan_mt0 <- file.mtime(stan_f)
f17 <- function(x) sprintf("%.17g", x)

## ---- rebuild dataset A exactly as gauss-reconcile-tree.R does -------------
set.seed(20260803L)
n_tip <- 8L; T_ <- 3L; K <- 1L; R <- 2L
tree <- rcoal(n_tip); tree$tip.label <- paste0("sp", seq_len(n_tip))
A <- vcv(tree, corr = TRUE); L_A <- t(chol(A))
g_true <- as.numeric(L_A %*% rnorm(n_tip))
Lam_true <- matrix(c(1.0, 0.6, -0.4), nrow = T_, ncol = K)
df <- expand.grid(rep = seq_len(R), trait = factor(paste0("t", seq_len(T_))),
                  species = factor(tree$tip.label, levels = tree$tip.label))
df$value <- rnorm(nrow(df), sd = 0.3) +
  as.numeric(Lam_true[as.integer(df$trait), 1]) * g_true[as.integer(df$species)]
df$site <- factor(seq_len(nrow(df)))
N <- nrow(df)

fit <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + phylo_latent(species, d = K, tree = tree),
  data = df, family = gaussian(), trait = "trait", species = "species", site = "site")))
td <- fit$tmb_data; n_aug <- td$n_aug_phy
joint_obj <- TMB::MakeADFun(data = td, parameters = fit$tmb_params, map = fit$tmb_map,
                            random = NULL, DLL = "gllvmTMB", silent = TRUE)

prec  <- gllvmTMB:::.gllvm_phylo_tree_precision(tree, correlation = TRUE)
P     <- as.matrix(prec$precision)
tip_e <- unname(prec$tip_node_index); int_e <- setdiff(seq_len(n_aug), tip_e)
eng_of_stan <- c(tip_e, int_e)
stan_of_eng <- integer(n_aug); stan_of_eng[eng_of_stan] <- seq_len(n_aug)

parent_stan <- integer(n_aug); branch_stan <- numeric(n_aug)
for (e in seq_len(nrow(tree$edge))) {
  p <- tree$edge[e,1]; ch <- tree$edge[e,2]
  v <- stan_of_eng[prec$node_index[ch]]
  parent_stan[v] <- if (p == prec$root) 0L else stan_of_eng[prec$node_index[p]]
  branch_stan[v] <- tree$edge.length[e] / prec$height
}

b_fix <- c(0.4, -0.2, 0.3); lsig <- log(0.3); th_rr <- c(0.9, 0.5, -0.6)
g_eng <- c(-0.512, 0.847, -1.126, 0.389, -0.275, 0.664,
           0.732, -1.084, 0.221, 0.917, -0.348, 1.204, -0.663, 0.056)
theta <- joint_obj$par; nm <- names(theta)
theta[nm=="b_fix"] <- b_fix; theta[nm=="log_sigma_eps"] <- lsig
theta[nm=="theta_rr_phy"] <- th_rr; theta[nm=="g_phy"] <- g_eng

sm   <- stan_model(stan_f, auto_write = TRUE)
sdat <- list(N=N, n_t=T_, S=n_tip, K=K, tt=as.integer(df$trait),
             ss=as.integer(df$species), y=df$value,
             n_node=n_aug, parent=parent_stan, branch_len=branch_stan)
fit0 <- sampling(sm, data = sdat, chains = 0, refresh = 0)
spars <- function(a) list(mu=b_fix, Lambda=matrix(th_rr,T_,K),
                          sigma_eps=exp(lsig), a_node=matrix(a,n_aug,K))
lp_stan <- function(a_stan) log_prob(fit0, unconstrain_pars(fit0, spars(a_stan)),
                                     adjust_transform = FALSE, gradient = FALSE)
lp_tmb  <- function(a_eng) { th <- theta; th[nm=="g_phy"] <- a_eng; -joint_obj$fn(th) }

a0_stan <- g_eng[eng_of_stan]; a0_eng <- g_eng
h <- 1

## ---- 1. second differences: is every internal node LIVE, on BOTH sides? ----
cat("\n=== SECOND DIFFERENCES -- curvature at each INTERNAL node ===\n")
cat("(eta never reads these rows; they can only enter through the prior)\n\n")
cat(sprintf("%-9s %-9s %-24s %-24s %-24s\n","stan row","eng idx","Stan 2nd-diff","-P_vv (engine)","TMB 2nd-diff"))
for (v in (n_tip+1L):n_aug) {
  ev <- eng_of_stan[v]
  as_p <- a0_stan; as_p[v] <- as_p[v] + h
  as_m <- a0_stan; as_m[v] <- as_m[v] - h
  s2 <- lp_stan(as_p) + lp_stan(as_m) - 2*lp_stan(a0_stan)
  ae_p <- a0_eng; ae_p[ev] <- ae_p[ev] + h
  ae_m <- a0_eng; ae_m[ev] <- ae_m[ev] - h
  t2 <- lp_tmb(ae_p) + lp_tmb(ae_m) - 2*lp_tmb(a0_eng)
  cat(sprintf("%-9d %-9d %-24s %-24s %-24s\n", v, ev, f17(s2), f17(-P[ev,ev]), f17(t2)))
}

## ---- 2. mixed differences: does Stan recover the SPARSITY PATTERN? --------
mixed <- function(fn, a, i, j) {
  ap <- a; ap[i] <- ap[i]+h; ap[j] <- ap[j]+h
  am <- a; am[i] <- am[i]-h; am[j] <- am[j]-h
  bi <- a; bi[i] <- bi[i]+h; bi[j] <- bi[j]-h
  bj <- a; bj[i] <- bj[i]-h; bj[j] <- bj[j]+h
  (fn(ap) + fn(am) - fn(bi) - fn(bj)) / 4
}
cat("\n=== MIXED SECOND DIFFERENCES -- the sparsity PATTERN ===\n")
cat("nonzeros in the engine's precision:", sum(P != 0), "of", length(P), "\n\n")
cat(sprintf("%-12s %-14s %-24s %-24s %-24s\n","stan pair","parent-child?","Stan","TMB","-P_uv"))
pairs <- list(c(10,9), c(11,9), c(13,10), c(14,12), c(9,14), c(1,2))
for (pr in pairs) {
  u <- pr[1]; v <- pr[2]; eu <- eng_of_stan[u]; ev <- eng_of_stan[v]
  adj <- (parent_stan[u] == v) || (parent_stan[v] == u)
  cat(sprintf("(%2d,%2d)      %-14s %-24s %-24s %-24s\n", u, v,
              if (adj) "yes" else "NO",
              f17(mixed(lp_stan, a0_stan, u, v)),
              f17(mixed(lp_tmb,  a0_eng,  eu, ev)),
              f17(-P[eu,ev])))
}

## ---- 3. exhaustive: EVERY pair, classified -------------------------------
cat("\n=== EXHAUSTIVE PAIR SWEEP ===\n")
bad_adj <- 0; bad_non <- 0; max_adj_err <- 0; max_non_abs <- 0
for (u in 1:(n_aug-1)) for (v in (u+1):n_aug) {
  eu <- eng_of_stan[u]; ev <- eng_of_stan[v]
  m <- mixed(lp_stan, a0_stan, u, v)
  adj <- (parent_stan[u] == v) || (parent_stan[v] == u)
  if (adj) { e <- abs(m - (-P[eu,ev])); max_adj_err <- max(max_adj_err, e)
             if (e > 1e-8) bad_adj <- bad_adj + 1
  } else   { max_non_abs <- max(max_non_abs, abs(m))
             if (abs(m) > 1e-8) bad_non <- bad_non + 1 }
}
cat("adjacent pairs disagreeing with -P_uv (tol 1e-8):", bad_adj, "  max err:", f17(max_adj_err), "\n")
cat("non-adjacent pairs with nonzero mixed derivative :", bad_non, "  max |val|:", f17(max_non_abs), "\n")
cat("\nStan model mtime unchanged:", identical(stan_mt0, file.mtime(stan_f)), "\n")
cat("\nIf both counts are 0, the Stan side reconstructed the engine's precision\n")
cat("STRUCTURE from a parent map and branch lengths alone.\n")
