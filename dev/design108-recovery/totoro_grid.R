## D108 campaign grid on Totoro. Results stay LOCAL (D-50) -- never committed,
## never a GitHub artifact. Closes two gaps the single 3-seed local run left:
## no MCSE, and no compute-discipline compliance.
setwd(Sys.getenv("D108_ROOT"))
suppressPackageStartupMessages(devtools::load_all(Sys.getenv("D108_PKG"), quiet = TRUE))
source("dev/design108-recovery/dgp.R"); source("dev/design108-recovery/harness.R")
library(parallel)
GRID <- expand.grid(N = c(500L, 1000L), q = c(1L, 2L), seed = 1:20,
                    KEEP.OUT.ATTRS = FALSE)
T0 <- 10L
one <- function(i) {
  g <- GRID[i, ]
  out <- tryCatch({
    sim <- simulate_two_tier(N=g$N, T=T0, q=g$q, seed=g$seed, phylo_scale=1, n_trials=6L)
    yv <- as.numeric(scale(sim$data$y)); d <- sim$data
    X <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels=seq_len(T0))))
    phy <- .d108_va_phylo_tiers("augmented", sim$tree, sim$species_levels, d$unit, T0, g$q)
    t1t <- sim$truth$tier1$Sigma_B_loadings; t2t <- sim$truth$tier2$Sigma_B_loadings
    va <- tryCatch(gllvmTMB:::.va_r3_fit(y=yv, n_trials=d$n_trials, X=X, unit_id=d$unit,
            trait_id=d$trait, q=g$q, family="gaussian_anchor", link="identity", unique=TRUE,
            structured=phy$structured, extra_tiers=phy$extra_tiers,
            profile_variational=TRUE, n_starts=1L, H=15L,
            control=list(eval.max=600L, iter.max=300L)), error=function(e) NULL)
    va1 <- va2 <- NA_real_
    if (!is.null(va)) {
      lay <- tryCatch(gllvmTMB:::.va_r3_validate_data(y=yv, n_trials=d$n_trials, X=X,
               unit_id=d$unit, trait_id=d$trait, q=g$q, family="gaussian_anchor",
               link="identity", unique=TRUE, structured=phy$structured,
               extra_tiers=phy$extra_tiers)$tier_layout, error=function(e) NULL)
      if (!is.null(lay)) {
        s1 <- tryCatch(.d108_va_tier_sigma(va$best$par, lay, 1L, 2L, T0), error=function(e) NULL)
        s2 <- tryCatch(.d108_va_tier_sigma(va$best$par, lay, 3L, 4L, T0), error=function(e) NULL)
        if (!is.null(s1)) va1 <- rel_frob(s1$Sigma_B_loadings, t1t)
        if (!is.null(s2)) va2 <- rel_frob(s2$Sigma_B_loadings, t2t)
      }
    }
    lap <- .d108_fit_laplace(sim, g$q)
    l1 <- if (is.null(lap$Sigma1_load)) NA_real_ else rel_frob(lap$Sigma1_load, t1t)
    l2 <- if (is.null(lap$Sigma2_load)) NA_real_ else rel_frob(lap$Sigma2_load, t2t)
    data.frame(N=g$N, q=g$q, seed=g$seed, va_t1=va1, va_t2=va2, lap_t1=l1, lap_t2=l2)
  }, error=function(e) data.frame(N=g$N,q=g$q,seed=g$seed,va_t1=NA,va_t2=NA,lap_t1=NA,lap_t2=NA))
  out
}
res <- do.call(rbind, mclapply(seq_len(nrow(GRID)), one, mc.cores = 40L))
saveRDS(res, "~/gllvm_work/d108-recovery/campaign_grid.rds")
write.csv(res, "~/gllvm_work/d108-recovery/campaign_grid.csv", row.names = FALSE)
cat("cells:", nrow(res), " VA t2 non-NA:", sum(!is.na(res$va_t2)), "\n")
cat("TOTORO_GRID_DONE\n")
