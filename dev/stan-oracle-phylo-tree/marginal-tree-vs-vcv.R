## =====================================================================
## The MARGINAL (Laplace) comparison between the `tree =` and `vcv =` routes.
##
## Shipped because the adversarial review correctly objected that the numbers
## quoted in reconciliation-tree.md sec.9 were produced by an ad-hoc call and
## were not reproducible from anything in the repo. Either ship the script or
## drop the digits. This is the script.
##
## CLAIM UNDER TEST: the augmented (`tree =`) and tips-only (`vcv =`)
## representations are the SAME model on different sample spaces. Their JOINT
## densities are not comparable (different latent dimension). Their LAPLACE
## MARGINALS should agree, up to the dense route's undocumented 1e-8 ridge.
##
## NOTE this is a coarser instrument than the joint-density oracle: it compares
## two gllvmTMB fits to each other, not gllvmTMB to an independent engine. It
## corroborates the marginalisation identity; it is not itself an oracle.
## =====================================================================

suppressMessages({ library(ape); devtools::load_all(
  "/Users/z3437171/local-scratch/worktrees/stan-phylo-tree", quiet = TRUE) })
f17 <- function(x) sprintf("%.17g", x)

set.seed(20260803L)                    # <- the seed, stated
n_sp <- 30L; T_ <- 3L; R <- 3L
tr <- rcoal(n_sp); tr$tip.label <- paste0("sp", seq_len(n_sp))
A  <- vcv(tr, corr = TRUE)
L  <- t(chol(A))
Lam <- matrix(c(1.0, 0.6, -0.4), nrow = T_, ncol = 1)
g  <- as.numeric(L %*% rnorm(n_sp))

df <- expand.grid(rep = seq_len(R), trait = factor(paste0("t", seq_len(T_))),
                  species = factor(tr$tip.label, levels = tr$tip.label))
df$value <- rnorm(nrow(df), sd = 0.5) +
  as.numeric(Lam[as.integer(df$trait), 1]) * g[as.integer(df$species)]
df$site <- factor(seq_len(nrow(df)))

ctl <- list(trait = "trait", species = "species", site = "site", family = gaussian())
ft <- suppressWarnings(suppressMessages(do.call(gllvmTMB, c(list(
  formula = value ~ 0 + trait + phylo_latent(species, d = 1, tree = tr), data = df), ctl))))
fv <- suppressWarnings(suppressMessages(do.call(gllvmTMB, c(list(
  formula = value ~ 0 + trait + phylo_latent(species, d = 1, vcv  = A),  data = df), ctl))))

cat("latent dimension   tree= :", ft$tmb_data$n_aug_phy,
    "   vcv= :", fv$tmb_data$n_aug_phy, "\n")
cat("convergence        :", ft$opt$convergence, fv$opt$convergence, "\n\n")
cat("MARGINAL (Laplace) objective AT THE OPTIMUM -- each route at its OWN optimum\n")
cat("  tree= :", f17(ft$opt$objective), "\n")
cat("  vcv=  :", f17(fv$opt$objective), "\n")
cat("  |diff|:", f17(abs(ft$opt$objective - fv$opt$objective)), "\n")
cat("  rel   :", f17(abs(ft$opt$objective - fv$opt$objective) / abs(fv$opt$objective)), "\n\n")
cat("Sigma_phy max|diff|:", f17(max(abs(ft$report$Sigma_phy - fv$report$Sigma_phy))), "\n")

## The residual should be the order of the dense route's 1e-8 ridge, which the
## tree route does not apply. Arc 1 sec.8 bounds its effect at ~6.6e-07 for
## rcoal(8) and ~3.5e-06 for rcoal(25).
cat("\nridge on tree= route:", if (is.null(ft$tmb_data$ridge)) "none (by construction)" else "present", "\n")
