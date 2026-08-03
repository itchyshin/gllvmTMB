## =====================================================================
## Arc 2 reconciliation — TMB `tree =` augmented-sparse joint log-density
## versus an independent Stan oracle built FROM THE TREE.
##
## Dataset A: seed 20260803, ape::rcoal(8), T = 3, K = 1, 2 reps, N = 48.
##
## The two sides reach the same number by genuinely different routes:
##   TMB  : -1/2 * (n_aug*log(2pi) + log_det_A_phy_rr + g' Ainv g), from an
##          assembled sparse precision.
##   Stan : sum over branches of normal_lpdf(a_v | a_parent(v), sqrt(b_v)),
##          from a parent map and branch lengths. It never sees A, A^-1, or
##          any Cholesky factor.
##
## TRANSPORT is declared in transport-tree.md and was committed BEFORE this
## driver ran. The one binding this file performs is the NODE PERMUTATION:
## the engine orders internal-first/tips-last; the Stan model (written by a
## fence-clean author who could not see the engine) orders tips-first.
##
## Both engines run in ONE R session with data regenerated in-session, so no
## value crosses a JSON boundary before being compared (Arc 1 s.9.3).
## =====================================================================

suppressMessages({
  library(ape); library(Matrix); library(TMB); library(rstan)
})
rstan_options(auto_write = TRUE)

pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-phylo-tree"
stopifnot(file.exists(file.path(pkg_root, "DESCRIPTION")))
suppressMessages(devtools::load_all(pkg_root, quiet = TRUE))

here     <- file.path(pkg_root, "dev", "stan-oracle-phylo-tree")
stan_f   <- file.path(here, "gllvm_phylo_tree.stan")
stan_mt0 <- file.mtime(stan_f)

f17 <- function(x) sprintf("%.17g", x)
hdr <- function(s) cat("\n", strrep("=", 68), "\n", s, "\n", strrep("=", 68), "\n", sep = "")

## ---------------------------------------------------------------------
## 1. Regenerate dataset A in-session (identical to tmb-side-tree.R)
## ---------------------------------------------------------------------
set.seed(20260803L)
n_tip <- 8L; T_ <- 3L; K <- 1L; R <- 2L
tree <- rcoal(n_tip); tree$tip.label <- paste0("sp", seq_len(n_tip))
A     <- vcv(tree, corr = TRUE)
L_A   <- t(chol(A))
g_true <- as.numeric(L_A %*% rnorm(n_tip))
Lam_true <- matrix(c(1.0, 0.6, -0.4), nrow = T_, ncol = K)

df <- expand.grid(rep = seq_len(R), trait = factor(paste0("t", seq_len(T_))),
                  species = factor(tree$tip.label, levels = tree$tip.label))
df$value <- rnorm(nrow(df), sd = 0.3) +
  as.numeric(Lam_true[as.integer(df$trait), 1]) * g_true[as.integer(df$species)]
df$site <- factor(seq_len(nrow(df)))
N <- nrow(df)
stopifnot(N == 48L)

fit <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + phylo_latent(species, d = K, tree = tree),
  data = df, family = gaussian(),
  trait = "trait", species = "species", site = "site")))

td <- fit$tmb_data
n_aug <- td$n_aug_phy
hdr("STRUCTURE (measured)")
cat("n_tip", n_tip, " Nnode", tree$Nnode, " edges", nrow(tree$edge), " n_aug_phy", n_aug, "\n")
cat("2S-2 =", 2*n_tip-2, "   2S-1 =", 2*n_tip-1, "\n")
cat("species_aug_id (0-idx):", paste(sort(unique(td$species_aug_id)), collapse = ","), "\n")
cat("log_det_A_phy_rr:", f17(td$log_det_A_phy_rr), "\n")

## joint objective: every random effect a free coordinate
joint_obj <- TMB::MakeADFun(data = td, parameters = fit$tmb_params,
                            map = fit$tmb_map, random = NULL,
                            DLL = "gllvmTMB", silent = TRUE)

## ---------------------------------------------------------------------
## 2. Transport: engine augmented order -> Stan node order
##    engine: [internal (root excluded, ape order)] then [tips]
##    Stan  : [tips 1..S] then [internal S+1..n_node]
## ---------------------------------------------------------------------
prec  <- gllvmTMB:::.gllvm_phylo_tree_precision(tree, correlation = TRUE)
lab   <- rownames(prec$precision)                 # engine order
tip_e <- prec$tip_node_index                      # engine position of each tip (1-idx)
int_e <- setdiff(seq_len(n_aug), tip_e)           # engine positions of internal nodes

eng_of_stan <- c(tip_e, int_e)                    # stan row i  <- engine position
stan_of_eng <- integer(n_aug)
stan_of_eng[eng_of_stan] <- seq_len(n_aug)        # engine position -> stan row
stopifnot(!any(stan_of_eng == 0L))

## parent map + scaled branch lengths, in STAN row order
node_index <- prec$node_index                     # ape id -> engine position
root_ape   <- prec$root
height     <- prec$height
parent_stan <- integer(n_aug); branch_stan <- numeric(n_aug)
for (e in seq_len(nrow(tree$edge))) {
  p_ape <- tree$edge[e, 1]; c_ape <- tree$edge[e, 2]
  v <- stan_of_eng[node_index[c_ape]]
  parent_stan[v] <- if (p_ape == root_ape) 0L else stan_of_eng[node_index[p_ape]]
  branch_stan[v] <- tree$edge.length[e] / height  # correlation = TRUE rescaling
}
stopifnot(all(branch_stan > 0))
cat("root-to-tip depth (should be 1):",
    f17(sum(branch_stan[c(1, which(parent_stan == 0)[1])][1])), "(spot check below)\n")

## ---------------------------------------------------------------------
## 3. theta, and its transport into Stan's parameter list
## ---------------------------------------------------------------------
theta <- joint_obj$par
nm    <- names(theta)
b_fix   <- unname(theta[nm == "b_fix"])
lsig    <- unname(theta[nm == "log_sigma_eps"])
th_rr   <- unname(theta[nm == "theta_rr_phy"])
g_eng   <- unname(theta[nm == "g_phy"])
stopifnot(length(g_eng) == n_aug)

## deterministic, reproducible non-zero point (not the all-zero init)
set.seed(11L)
b_fix <- c(0.4, -0.2, 0.3)
lsig  <- log(0.3)
th_rr <- c(0.9, 0.5, -0.6)
g_eng <- c(-0.512, 0.847, -1.126, 0.389, -0.275, 0.664,        # internal (engine 1-6)
           0.732, -1.084, 0.221, 0.917, -0.348, 1.204, -0.663, 0.056)  # tips (engine 7-14)
theta[nm == "b_fix"]         <- b_fix
theta[nm == "log_sigma_eps"] <- lsig
theta[nm == "theta_rr_phy"]  <- th_rr
theta[nm == "g_phy"]         <- g_eng

tmb_nll <- joint_obj$fn(theta)

## Lambda: K = 1, so diag-first packing is Lambda = th_rr (T x 1), no exp()
Lambda <- matrix(th_rr, nrow = T_, ncol = K)
a_node <- matrix(g_eng[eng_of_stan], nrow = n_aug, ncol = K)   # <- THE PERMUTATION

stan_data <- list(
  N = N, n_t = T_, S = n_tip, K = K,
  tt = as.integer(df$trait), ss = as.integer(df$species), y = df$value,
  n_node = n_aug, parent = parent_stan, branch_len = branch_stan)

stan_pars <- list(mu = b_fix, Lambda = Lambda, sigma_eps = exp(lsig), a_node = a_node)

hdr("COMPILING STAN MODEL")
sm  <- stan_model(stan_f, auto_write = TRUE)
fit0 <- sampling(sm, data = stan_data, chains = 0, refresh = 0)
up  <- unconstrain_pars(fit0, stan_pars)
lp_adjF <- log_prob(fit0, up, adjust_transform = FALSE, gradient = FALSE)
lp_adjT <- log_prob(fit0, up, adjust_transform = TRUE,  gradient = FALSE)

hdr("HEADLINE — dataset A, point P1")
cat("TMB  joint fn(theta)        :", f17(tmb_nll), "\n")
cat("Stan log_prob(adjust=FALSE) :", f17(lp_adjF), "\n")
cat("|difference|                :", f17(abs((-tmb_nll) - lp_adjF)), "\n")
cat("relative difference         :", f17(abs((-tmb_nll) - lp_adjF)/abs(lp_adjF)), "\n")
cat("\nJacobian audit: log_prob(TRUE) - log_prob(FALSE) =", f17(lp_adjT - lp_adjF),
    " vs log(sigma_eps) =", f17(lsig), " |diff| =", f17(abs((lp_adjT-lp_adjF) - lsig)), "\n")

## ---------------------------------------------------------------------
## 4. Out-of-sample points (transport frozen; only theta changes)
## ---------------------------------------------------------------------
eval_pair <- function(bf, ls, tr_, ge, label) {
  th <- theta
  th[nm == "b_fix"] <- bf; th[nm == "log_sigma_eps"] <- ls
  th[nm == "theta_rr_phy"] <- tr_; th[nm == "g_phy"] <- ge
  tn <- joint_obj$fn(th)
  sp <- list(mu = bf, Lambda = matrix(tr_, T_, K), sigma_eps = exp(ls),
             a_node = matrix(ge[eng_of_stan], n_aug, K))
  lp <- log_prob(fit0, unconstrain_pars(fit0, sp), adjust_transform = FALSE, gradient = FALSE)
  cat(sprintf("%-6s TMB %-22s Stan %-24s |diff| %-12s rel %s\n",
              label, f17(tn), f17(lp), f17(abs((-tn) - lp)), f17(abs((-tn)-lp)/abs(lp))))
  c(tmb = tn, stan = lp, diff = abs((-tn) - lp))
}
hdr("OUT-OF-SAMPLE POINTS (transport frozen)")
set.seed(99L)
P1 <- c(tmb = tmb_nll, stan = lp_adjF, diff = abs((-tmb_nll) - lp_adjF))
cat(sprintf("%-6s TMB %-22s Stan %-24s |diff| %-12s rel %s\n", "A/P1",
            f17(tmb_nll), f17(lp_adjF), f17(P1["diff"]), f17(P1["diff"]/abs(lp_adjF))))
P2 <- eval_pair(c(-0.8,1.3,0.05), log(1.4), c(-1.1,0.35,0.9),  rnorm(n_aug), "A/P2")
P3 <- eval_pair(c(0.1,0.1,0.1),   log(0.05), c(2.2,-1.7,0.4),  rnorm(n_aug), "A/P3")
P4 <- eval_pair(c(3.0,-2.5,1.2),  log(2.4), c(0.05,-0.02,0.01), rnorm(n_aug), "A/P4")

## ---------------------------------------------------------------------
## 5. CONTROLS — each breaks exactly ONE rule. All must move the density
##    far above the agreement floor, or the comparison is not a check.
## ---------------------------------------------------------------------
ctrl <- function(sp, label) {
  lp <- tryCatch(log_prob(fit0, unconstrain_pars(fit0, sp),
                          adjust_transform = FALSE, gradient = FALSE),
                 error = function(e) NA_real_)
  cat(sprintf("  %-46s shift %s\n", label, f17(lp - lp_adjF)))
  lp
}
base_sp <- stan_pars
hdr("CONTROLS (shift in the Stan log-density vs the agreed value)")

## C1 VACUITY: perturb ONLY an internal node -- eta never reads it.
i_int <- n_tip + 1L
sp <- base_sp; sp$a_node[i_int, 1] <- sp$a_node[i_int, 1] + 1.0
ctrl(sp, "C1 internal-node perturbed by +1 (eta blind)")

## C2 node ORDERING: feed engine order directly, skipping the permutation
sp <- base_sp; sp$a_node <- matrix(g_eng, n_aug, K)
ctrl(sp, "C2 engine order fed directly (no permutation)")

## C3 SCALE: unscaled branch lengths (drop correlation = TRUE rescaling)
sd_unscaled <- stan_data; sd_unscaled$branch_len <- branch_stan * height
f_un <- sampling(sm, data = sd_unscaled, chains = 0, refresh = 0)
lp_un <- log_prob(f_un, unconstrain_pars(f_un, base_sp), adjust_transform = FALSE, gradient = FALSE)
cat(sprintf("  %-46s shift %s\n", "C3 branch lengths unscaled (no /height)", f17(lp_un - lp_adjF)))

## C4 ROOT: attach the root as an extra node instead of pinning it at 0
sd_root <- stan_data
sd_root$n_node <- n_aug + 1L
sd_root$parent <- c(ifelse(parent_stan == 0L, n_aug + 1L, parent_stan), 0L)
sd_root$branch_len <- c(branch_stan, 1.0)
sp_root <- base_sp; sp_root$a_node <- rbind(base_sp$a_node, 0)
f_root <- sampling(sm, data = sd_root, chains = 0, refresh = 0)
lp_root <- log_prob(f_root, unconstrain_pars(f_root, sp_root), adjust_transform = FALSE, gradient = FALSE)
cat(sprintf("  %-46s shift %s\n", "C4 root added as a 15th node (2S-1)", f17(lp_root - lp_adjF)))

## C5 TIP MAP: tips in tree order rather than factor-level order
sp <- base_sp
perm <- c(2:n_tip, 1L)                       # a rotation of the tip block
sp$a_node[seq_len(n_tip), 1] <- base_sp$a_node[perm, 1]
ctrl(sp, "C5 tip block permuted (wrong species map)")

## C6 VARIANCE-vs-SD: read branch_len as an SD instead of a variance
sd_sd <- stan_data; sd_sd$branch_len <- branch_stan^2
f_sd <- sampling(sm, data = sd_sd, chains = 0, refresh = 0)
lp_sd <- log_prob(f_sd, unconstrain_pars(f_sd, base_sp), adjust_transform = FALSE, gradient = FALSE)
cat(sprintf("  %-46s shift %s\n", "C6 branch_len read as SD not variance", f17(lp_sd - lp_adjF)))

## ---------------------------------------------------------------------
## 6. STAR PHYLOGENY — the vacuity control proper.
##    A star tree has NO internal nodes: n_aug collapses to S and A = I.
##    Both sides must still agree, AND the density must differ from the
##    real tree, or neither side is tracking the phylogeny.
## ---------------------------------------------------------------------
hdr("STAR-PHYLOGENY CONTROL")
star <- stree(n_tip, type = "star"); star$edge.length <- rep(1, n_tip)
star$tip.label <- tree$tip.label
fit_s <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + phylo_latent(species, d = K, tree = star),
  data = df, family = gaussian(), trait = "trait", species = "species", site = "site")))
n_aug_s <- fit_s$tmb_data$n_aug_phy
cat("star n_aug_phy:", n_aug_s, " (real tree:", n_aug, ")   2S-2 would be", 2*n_tip-2, "\n")
jo_s <- TMB::MakeADFun(data = fit_s$tmb_data, parameters = fit_s$tmb_params,
                       map = fit_s$tmb_map, random = NULL, DLL = "gllvmTMB", silent = TRUE)
th_s <- jo_s$par; nm_s <- names(th_s)
th_s[nm_s == "b_fix"] <- b_fix; th_s[nm_s == "log_sigma_eps"] <- lsig
th_s[nm_s == "theta_rr_phy"] <- th_rr
th_s[nm_s == "g_phy"] <- g_eng[7:14]           # tips only on a star
tmb_s <- jo_s$fn(th_s)

prec_s <- gllvmTMB:::.gllvm_phylo_tree_precision(star, correlation = TRUE)
tip_es <- prec_s$tip_node_index
sd_star <- list(N = N, n_t = T_, S = n_tip, K = K,
                tt = as.integer(df$trait), ss = as.integer(df$species), y = df$value,
                n_node = n_aug_s, parent = rep(0L, n_aug_s),
                branch_len = rep(1, n_aug_s))
sp_star <- list(mu = b_fix, Lambda = Lambda, sigma_eps = exp(lsig),
                a_node = matrix(g_eng[6 + tip_es], n_aug_s, K))
f_star <- sampling(sm, data = sd_star, chains = 0, refresh = 0)
lp_star <- log_prob(f_star, unconstrain_pars(f_star, sp_star), adjust_transform = FALSE, gradient = FALSE)
cat("TMB (star) :", f17(tmb_s), "\n")
cat("Stan (star):", f17(lp_star), "\n")
cat("|diff|     :", f17(abs((-tmb_s) - lp_star)), "\n")
cat("star vs real-tree TMB objective differs by:", f17(tmb_s - tmb_nll), "\n")

## ---------------------------------------------------------------------
hdr("INTEGRITY")
cat("gllvm_phylo_tree.stan mtime unchanged:", identical(stan_mt0, file.mtime(stan_f)), "\n")
cat("difference-of-differences (constant-free):\n")
cat("  (P2-P1):", f17(((-P2["tmb"]) - P2["stan"]) - ((-P1["tmb"]) - P1["stan"])), "\n")
cat("  (P3-P1):", f17(((-P3["tmb"]) - P3["stan"]) - ((-P1["tmb"]) - P1["stan"])), "\n")
cat("  (P4-P1):", f17(((-P4["tmb"]) - P4["stan"]) - ((-P1["tmb"]) - P1["stan"])), "\n")
cat("\nmax |difference| over 4 points:",
    f17(max(P1["diff"], P2["diff"], P3["diff"], P4["diff"])), "\n")
