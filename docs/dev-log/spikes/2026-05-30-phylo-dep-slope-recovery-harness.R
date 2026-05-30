suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(ape)); suppressMessages(library(TMB))
set.seed(20260530)

T_tr <- 2L                 # number of traits (C = 2T = 4)
C <- 2L * T_tr
n_sp <- 80L
n_rep <- 8L

## --- phylogeny + A (use the SAME sparse Ainv path gllvmTMB builds) -------
tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))

## --- KNOWN unstructured 2T x 2T Sigma_b (PD by construction) -------------
Ltrue <- matrix(0, C, C)
Ltrue[lower.tri(Ltrue, diag = TRUE)] <- c(
  # column-major lower-tri incl diag, chosen to give a well-conditioned Sigma
  0.8,  0.2, -0.1, 0.15,   # col 1 (rows 1..4)
        0.6,  0.1, -0.05,  # col 2 (rows 2..4)
              0.5,  0.1,   # col 3 (rows 3..4)
                    0.45   # col 4 (row 4)
)
Sigma_b_true <- Ltrue %*% t(Ltrue)
cat("True Sigma_b:\n"); print(round(Sigma_b_true, 3))
cat("True SDs:", round(sqrt(diag(Sigma_b_true)), 3), "\n")

## --- draw B ~ MN(0, A, Sigma_b): B = chol(A)' Z chol(Sigma_b) ------------
Cphy <- ape::vcv(tree, corr = TRUE)
LA <- t(chol(Cphy + diag(1e-8, n_sp)))      # n_sp x n_sp, lower
Zraw <- matrix(rnorm(n_sp * C), n_sp, C)
B <- LA %*% Zraw %*% chol(Sigma_b_true)     # n_sp x C; cols interleaved (a_t, b_t)
rownames(B) <- tree$tip.label

## --- long data frame; x identical across traits within (sp,rep) cell -----
sr <- expand.grid(species = factor(tree$tip.label, levels = tree$tip.label), rep = seq_len(n_rep))
sr$x <- rnorm(nrow(sr))
trait_levels <- paste0("t", seq_len(T_tr))
df <- merge(sr, data.frame(trait = factor(trait_levels, levels = trait_levels)), all = TRUE)
df <- df[order(df$species, df$rep, df$trait), ]
ti <- as.integer(df$trait)                  # 1..T
si_int <- match(as.character(df$species), tree$tip.label)
mu_t <- c(1.0, -0.5)[ti]
alpha <- B[cbind(si_int, 2L*(ti-1L) + 1L)]   # intercept col for trait t
beta  <- B[cbind(si_int, 2L*(ti-1L) + 2L)]   # slope col for trait t
df$value <- mu_t + alpha + beta * df$x + rnorm(nrow(df), sd = 0.3)

## --- get a scaffold fit (phylo_unique slope) to harvest tmb_data/params --
ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
base <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  value ~ 0 + trait + phylo_unique(1 + x | species),
  data = df, phylo_tree = tree, unit = "species", family = gaussian(), control = ctl)))
cat("scaffold conv:", base$opt$convergence, " n_aug_phy:", base$tmb_data$n_aug_phy, "\n")

dat <- base$tmb_data
par <- base$tmb_params
map <- base$tmb_map
n_aug <- dat$n_aug_phy
n_obs <- length(dat$y)

## --- override to DEP path: C columns, per-trait active Z ------------------
dat$use_phylo_dep_slope <- 1L
dat$n_lhs_cols <- C
# species_aug_id is 0-indexed row into b_phy_aug; trait_id is 0-indexed
saug <- dat$species_aug_id
trid <- dat$trait_id            # 0-indexed trait
Z <- array(0.0, dim = c(n_obs, C, 1L))
xvec <- dat$x_phy_slope         # the x covariate (set by scaffold)
for (o in seq_len(n_obs)) {
  t0 <- trid[o]                 # 0-indexed
  Z[o, 2L*t0 + 1L, 1L] <- 1.0       # intercept col (1-indexed in R array)
  Z[o, 2L*t0 + 2L, 1L] <- xvec[o]   # slope col
}
dat$Z_phy_aug <- Z

par$b_phy_aug <- array(0.0, dim = c(n_aug, C, 1L))
par$theta_dep_chol <- numeric(C * (C + 1L) / 2L)
# init diagonal of L at log(0.5) so exp = 0.5 (sane start), offdiag 0
par$theta_dep_chol[seq_len(C)] <- log(0.5)
# drop closed-form aug params from map influence: keep b_phy_aug random; map off log_sd_b/atanh_cor_b
map$b_phy_aug <- NULL
map$log_sd_b  <- factor(rep(NA, length(par$log_sd_b)))
if (length(par$atanh_cor_b) > 0) map$atanh_cor_b <- factor(rep(NA, length(par$atanh_cor_b)))
map$theta_dep_chol <- NULL

obj <- TMB::MakeADFun(data = dat, parameters = par, map = map,
                      random = "b_phy_aug", DLL = "gllvmTMB", silent = TRUE)
fit <- nlminb(obj$par, obj$fn, obj$gr, control = list(iter.max = 2000, eval.max = 3000))
cat("\nDEP fit convergence:", fit$convergence, " objective:", round(fit$objective,3), "\n")
rep <- obj$report()
cat("\nEstimated Sigma_b:\n"); print(round(rep$Sigma_b_dep, 3))
cat("\nTrue Sigma_b:\n"); print(round(Sigma_b_true, 3))
cat("\nEstimated SDs:", round(rep$sd_b, 3), "\n")
cat("True SDs:     ", round(sqrt(diag(Sigma_b_true)), 3), "\n")
cat("\nmax abs elementwise diff (Sigma):", round(max(abs(rep$Sigma_b_dep - Sigma_b_true)), 4), "\n")
cat("\nEstimated cor matrix:\n"); print(round(rep$cor_b_mat, 3))
cat("\nTrue cor matrix:\n"); print(round(cov2cor(Sigma_b_true), 3))
cat("\nDEP_RECOVERY_DONE\n")
