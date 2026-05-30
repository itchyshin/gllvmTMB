suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(ape)); suppressMessages(library(TMB))
set.seed(7)
T_tr <- 2L; C <- 2L*T_tr; n_sp <- 12L; n_rep <- 3L
tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
sr <- expand.grid(species = factor(tree$tip.label, levels=tree$tip.label), rep=seq_len(n_rep))
sr$x <- rnorm(nrow(sr))
trait_levels <- paste0("t", seq_len(T_tr))
df <- merge(sr, data.frame(trait=factor(trait_levels, levels=trait_levels)), all=TRUE)
df <- df[order(df$species, df$rep, df$trait),]; df$value <- rnorm(nrow(df))
ctl <- gllvmTMB::gllvmTMBcontrol(se=FALSE)
base <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  value ~ 0 + trait + phylo_unique(1 + x | species),
  data=df, phylo_tree=tree, unit="species", family=gaussian(), control=ctl)))
dat <- base$tmb_data; par <- base$tmb_params; map <- base$tmb_map
n_aug <- dat$n_aug_phy; n_obs <- length(dat$y)

dat$use_phylo_dep_slope <- 1L; dat$n_lhs_cols <- C
trid <- dat$trait_id; xvec <- dat$x_phy_slope
Z <- array(0.0, dim=c(n_obs, C, 1L))
for (o in seq_len(n_obs)) { t0<-trid[o]; Z[o,2L*t0+1L,1L]<-1.0; Z[o,2L*t0+2L,1L]<-xvec[o] }
dat$Z_phy_aug <- Z

## Fix a KNOWN L (chol), KNOWN B, evaluate density two ways.
Ltrue <- matrix(0,C,C)
Ltrue[lower.tri(Ltrue,diag=TRUE)] <- c(0.9,0.3,-0.2,0.1, 0.7,0.15,-0.1, 0.6,0.2, 0.5)
theta <- numeric(C*(C+1L)/2L)
# pack: diag as log(L_jj), then strictly-lower col-major (matches C++)
idx<-1; for(j in 1:C){ theta[idx]<-log(Ltrue[j,j]); idx<-idx+1 }
for(j in 1:(C-1L)) for(i in (j+1L):C){ theta[idx]<-Ltrue[i,j]; idx<-idx+1 }
Sigma_b <- Ltrue %*% t(Ltrue)

set.seed(99)
Bfix <- matrix(rnorm(n_aug*C), n_aug, C)   # arbitrary fixed B

par$b_phy_aug <- array(Bfix, dim=c(n_aug,C,1L))
par$theta_dep_chol <- theta
map$b_phy_aug <- NULL; map$theta_dep_chol <- NULL
map$log_sd_b <- factor(rep(NA,length(par$log_sd_b)))
if(length(par$atanh_cor_b)>0) map$atanh_cor_b <- factor(rep(NA,length(par$atanh_cor_b)))

## Zero out ALL other random/likelihood contributions is hard; instead
## evaluate the FULL obj at this B, then again with B scaled, and compare
## the DIFFERENCE in nll to the analytic prior difference. Cleaner: compute
## the analytic prior nll for b_phy_aug and compare to obj difference vs B=0.
obj <- TMB::MakeADFun(data=dat, parameters=par, map=map, DLL="gllvmTMB", silent=TRUE)
## obj$fn() at current par includes data likelihood + ALL priors. To isolate
## the b_phy_aug prior, take the difference obj(B=Bfix) - obj(B=0) holding
## everything else fixed -- but B also enters eta (data lik). So instead set
## the residual sd huge so data-lik is ~flat? Not robust.
## Decisive route: use obj$report() ... but nll isn't reported.
## Instead: build a MINIMAL pure-prior check by setting use_phylo_dep_slope
## path is the ONLY random term and y has near-zero weight via large sigma.
## Simplest rigorous check: compare TMB's marginal of b_phy_aug prior by
## evaluating the joint nll with b_phy_aug FIXED (not random) and subtracting
## the data-likelihood + fixed-effect part computed in R for Gaussian.

## --- Analytic matrix-normal prior nll for vec(B) ~ N(0, Sigma_b (x) A) ---
## A from the sparse Ainv the engine uses:
Ainv <- as.matrix(dat$Ainv_phy_rr)
logdetA <- dat$log_det_A_phy_rr
Q <- t(Bfix) %*% Ainv %*% Bfix                 # C x C
Sinv <- solve(Sigma_b)
quad <- sum(diag(Sinv %*% Q))
nll_prior_R <- 0.5*( n_aug*C*log(2*pi) + n_aug*log(det(Sigma_b)) + C*logdetA + quad )
cat("Analytic prior nll (R):", sprintf("%.6f", nll_prior_R), "\n")

## --- TMB: evaluate joint nll with b_phy_aug as FIXED param (not random),
## and compute the data-lik + fixed part analytically for Gaussian, subtract.
obj2 <- TMB::MakeADFun(data=dat, parameters=par, map=map, DLL="gllvmTMB", silent=TRUE)
nll_total <- obj2$fn(obj2$par)
## Gaussian data-lik: need eta and sigma_eps. Reconstruct eta:
## eta = X_fix %*% beta_fix + sum over dep contribution. Fixed effects:
betafix <- par$b_fix
Xf <- dat$X_fix
eta <- as.numeric(Xf %*% betafix)
for(o in seq_len(n_obs)){ t0<-trid[o]; s<-dat$species_aug_id[o]+1L
  eta[o] <- eta[o] + Bfix[s,2L*t0+1L]*1.0 + Bfix[s,2L*t0+2L]*xvec[o] }
sigma_eps <- exp(par$log_sigma_eps)
yv <- dat$y
nll_data_R <- -sum(dnorm(yv, eta, sigma_eps, log=TRUE))
## Are there OTHER active priors? In this scaffold only phylo augmented is on.
## Check: any other use_* flags set?
flags <- grep("^use_", names(dat), value=TRUE)
on <- flags[sapply(flags, function(f) isTRUE(as.integer(dat[[f]])==1L))]
cat("Active use_ flags:", paste(on, collapse=", "), "\n")
cat("TMB total nll:", sprintf("%.6f", nll_total), "\n")
cat("R data-lik nll:", sprintf("%.6f", nll_data_R), "\n")
cat("TMB - data =", sprintf("%.6f", nll_total - nll_data_R), " (should equal analytic prior)\n")
cat("Analytic prior:", sprintf("%.6f", nll_prior_R), "\n")
cat("DIFFERENCE:", sprintf("%.3e", (nll_total - nll_data_R) - nll_prior_R), "\n")
cat("DENSITY_CHECK_DONE\n")
