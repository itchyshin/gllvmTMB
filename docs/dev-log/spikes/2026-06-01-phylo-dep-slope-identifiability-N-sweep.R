## Identifiability of the non-Gaussian phylo_dep(1 + x | sp) augmented slope
## across sample size N. Spike for GAP-B1 (PHY-18) per
## docs/dev-log/audits/2026-06-01-slopes-dependence-family-completeness.md.
##
## QUESTION: every non-Gaussian phylo_dep slope fit returns conv != 0 /
## non-PD Hessian at n_sp <= 100 (PHY-18). Is that genuine non-
## identifiability, or just finite-sample power? This sweeps n_sp and reports
## whether conv == 0 + pdHess == TRUE + recovery-within-band is reached.
##
## METHOD (no engine change): the R family guard at R/fit-multi.R:849 holds
## gaussian-only. We bypass it the same way the validated Gaussian recovery
## harness does (docs/dev-log/spikes/2026-05-30-phylo-dep-slope-recovery-
## harness.R): build a scaffold fit under the TARGET family with the family-
## general correlated-unique augmented slope `phylo_unique(1 + x | species)`
## (which sets up family_id_vec, link_id_vec, the augmented Z / b_phy_aug
## arrays, and all family-specific params correctly and is NOT behind the dep
## guard), then override the harvested tmb_data to the DEP path
## (use_phylo_dep_slope = 1L, full unstructured C x C Sigma_b via
## theta_dep_chol) and refit via TMB::MakeADFun. The C++ accumulates the dep
## slope into eta BEFORE the family dispatch, so the poisson/etc. likelihood
## is exercised with the dep covariance. This is a RESEARCH SPIKE, not a
## gating test and not an engine change.
##
## REQUIRES an R environment with the package compiled (devtools::load_all).
## This file was authored in a container WITHOUT R and has NOT been executed;
## run it locally or via CI and record the table it prints.
##
## Run:  Rscript docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R

suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(ape))
suppressMessages(library(TMB))

T_tr <- 2L            # traits; C = 2T = 4 (intercept + slope per trait, interleaved)
C <- 2L * T_tr

## KNOWN PD unstructured 2T x 2T Sigma_b (column-major lower-tri incl diag),
## identical to the validated Gaussian recovery harness / test fixture.
.dep_Ltrue <- function() {
  L <- matrix(0, C, C)
  L[lower.tri(L, diag = TRUE)] <- c(
    0.8, 0.2, -0.1, 0.15,   # col 1 (rows 1..4)
         0.6,  0.1, -0.05,  # col 2 (rows 2..4)
               0.5,  0.1,   # col 3 (rows 3..4)
                     0.45   # col 4 (row 4)
  )
  L
}
Sigma_b_true <- .dep_Ltrue() %*% t(.dep_Ltrue())
slope_var_idx <- c(2L, 4L)          # diagonal positions of the per-trait slope variances

## Per-family intercepts on the LINK scale, kept modest so non-Gaussian means
## are well inside the family's stable range (e.g. poisson counts ~ exp(eta)).
.link_intercepts <- function(family_name) {
  switch(family_name,
    gaussian = c(1.0, -0.5),
    poisson  = c(1.0,  0.8),   # exp -> ~2.7 / 2.2 counts
    nbinom2  = c(1.0,  0.8),
    stop("add intercepts for family ", family_name)
  )
}

.make_family <- function(family_name) {
  switch(family_name,
    gaussian = gaussian(),
    poisson  = poisson(),
    nbinom2  = glmmTMB::nbinom2(),
    stop("unsupported family ", family_name)
  )
}

## Draw response on the link scale from B ~ MN(0, A_phy, Sigma_b), then apply
## the family. Returns the long data frame + tree.
.make_fixture <- function(family_name, n_sp, n_rep, seed) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(Cphy + diag(1e-8, n_sp)))
  B <- LA %*% matrix(rnorm(n_sp * C), n_sp, C) %*% chol(Sigma_b_true)  # interleaved (a_t, b_t)
  rownames(B) <- tree$tip.label

  sr <- expand.grid(species = factor(tree$tip.label, levels = tree$tip.label),
                    rep = seq_len(n_rep))
  sr$x <- rnorm(nrow(sr))
  trait_levels <- paste0("t", seq_len(T_tr))
  df <- merge(sr, data.frame(trait = factor(trait_levels, levels = trait_levels)), all = TRUE)
  df <- df[order(df$species, df$rep, df$trait), ]
  ti <- as.integer(df$trait)
  si <- match(as.character(df$species), tree$tip.label)
  mu_t  <- .link_intercepts(family_name)[ti]
  alpha <- B[cbind(si, 2L * (ti - 1L) + 1L)]
  beta  <- B[cbind(si, 2L * (ti - 1L) + 2L)]
  eta   <- mu_t + alpha + beta * df$x
  df$value <- switch(family_name,
    gaussian = eta + rnorm(nrow(df), sd = 0.3),
    poisson  = rpois(nrow(df), exp(eta)),
    nbinom2  = rnbinom(nrow(df), mu = exp(eta), size = 5),
    stop("add DGP for family ", family_name)
  )
  list(df = df, tree = tree)
}

## Fit ONE dep-slope cell: scaffold under the target family, override to dep,
## refit, sdreport. Returns a one-row result.
run_cell <- function(family_name, n_sp, n_rep = 10L, seed = 1L) {
  fx <- tryCatch(.make_fixture(family_name, n_sp, n_rep, seed), error = function(e) e)
  if (inherits(fx, "error"))
    return(data.frame(family = family_name, n_sp = n_sp, seed = seed,
                      conv = NA_integer_, pdHess = NA, max_sigma_diff = NA_real_,
                      slope_var_ratio_1 = NA_real_, slope_var_ratio_2 = NA_real_,
                      note = paste("fixture error:", conditionMessage(fx))))
  df <- fx$df; tree <- fx$tree

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  base <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_unique(1 + x | species),
      data = df, phylo_tree = tree, unit = "species",
      family = .make_family(family_name), control = ctl))),
    error = function(e) e)
  if (inherits(base, "error"))
    return(data.frame(family = family_name, n_sp = n_sp, seed = seed,
                      conv = NA_integer_, pdHess = NA, max_sigma_diff = NA_real_,
                      slope_var_ratio_1 = NA_real_, slope_var_ratio_2 = NA_real_,
                      note = paste("scaffold error:", conditionMessage(base))))

  dat <- base$tmb_data; par <- base$tmb_params; map <- base$tmb_map
  n_aug <- dat$n_aug_phy; n_obs <- length(dat$y)

  ## Override harvested scaffold to the DEP path (full unstructured C x C).
  dat$use_phylo_dep_slope <- 1L
  dat$n_lhs_cols <- C
  trid <- dat$trait_id                     # 0-indexed trait
  xvec <- dat$x_phy_slope
  Z <- array(0.0, dim = c(n_obs, C, 1L))
  for (o in seq_len(n_obs)) {
    t0 <- trid[o]
    Z[o, 2L * t0 + 1L, 1L] <- 1.0          # intercept column
    Z[o, 2L * t0 + 2L, 1L] <- xvec[o]      # slope column
  }
  dat$Z_phy_aug <- Z

  par$b_phy_aug <- array(0.0, dim = c(n_aug, C, 1L))
  par$theta_dep_chol <- numeric(C * (C + 1L) / 2L)
  par$theta_dep_chol[seq_len(C)] <- log(0.5)
  map$b_phy_aug <- NULL
  map$log_sd_b  <- factor(rep(NA, length(par$log_sd_b)))
  if (length(par$atanh_cor_b) > 0) map$atanh_cor_b <- factor(rep(NA, length(par$atanh_cor_b)))
  map$theta_dep_chol <- NULL

  obj <- tryCatch(TMB::MakeADFun(data = dat, parameters = par, map = map,
                                 random = "b_phy_aug", DLL = "gllvmTMB", silent = TRUE),
                  error = function(e) e)
  if (inherits(obj, "error"))
    return(data.frame(family = family_name, n_sp = n_sp, seed = seed,
                      conv = NA_integer_, pdHess = NA, max_sigma_diff = NA_real_,
                      slope_var_ratio_1 = NA_real_, slope_var_ratio_2 = NA_real_,
                      note = paste("MakeADFun error:", conditionMessage(obj))))

  fit <- tryCatch(nlminb(obj$par, obj$fn, obj$gr,
                         control = list(iter.max = 3000, eval.max = 4000)),
                  error = function(e) e)
  if (inherits(fit, "error"))
    return(data.frame(family = family_name, n_sp = n_sp, seed = seed,
                      conv = NA_integer_, pdHess = NA, max_sigma_diff = NA_real_,
                      slope_var_ratio_1 = NA_real_, slope_var_ratio_2 = NA_real_,
                      note = paste("nlminb error:", conditionMessage(fit))))

  sdr <- tryCatch(TMB::sdreport(obj), error = function(e) e)
  pdHess <- if (inherits(sdr, "error")) NA else isTRUE(sdr$pdHess)
  rep <- obj$report()
  Sigma_hat <- rep$Sigma_b_dep
  max_diff <- max(abs(Sigma_hat - Sigma_b_true))
  ratios <- diag(Sigma_hat)[slope_var_idx] / diag(Sigma_b_true)[slope_var_idx]

  data.frame(family = family_name, n_sp = n_sp, seed = seed,
             conv = fit$convergence, pdHess = pdHess,
             max_sigma_diff = round(max_diff, 4),
             slope_var_ratio_1 = round(ratios[1], 3),
             slope_var_ratio_2 = round(ratios[2], 3),
             note = if (inherits(sdr, "error")) "sdreport failed" else "")
}

## ----- sweep -------------------------------------------------------------
## gaussian is the CONTROL: it should pass (conv 0 + pdHess) at every N. If it
## does not, the harness itself is broken, not the identifiability question.
## A "covered" verdict for a non-Gaussian family at some N = conv 0 + pdHess +
## slope-var ratios within roughly [1/2, 2] (the validated Gaussian band).
families <- c("gaussian", "poisson")    # add "nbinom2" once poisson is understood
n_grid   <- c(80L, 150L, 300L, 600L, 1200L)
seeds    <- c(101L, 202L, 303L)         # replicate seeds per cell

grid <- expand.grid(family = families, n_sp = n_grid, seed = seeds,
                    stringsAsFactors = FALSE)
cat("Running", nrow(grid), "cells. True slope variances:",
    round(diag(Sigma_b_true)[slope_var_idx], 3), "\n\n")

results <- do.call(rbind, Map(function(f, n, s) {
  cat(sprintf("  [%s n_sp=%d seed=%d] ...\n", f, n, s))
  run_cell(f, n_sp = n, seed = s)
}, grid$family, grid$n_sp, grid$seed))

cat("\n===== IDENTIFIABILITY SWEEP RESULTS =====\n")
print(results, row.names = FALSE)

## Per-(family, N) verdict: fraction of seeds that converged PD.
agg <- aggregate(cbind(pd = as.integer(conv == 0 & pdHess == TRUE)) ~ family + n_sp,
                 data = results, FUN = function(z) mean(z, na.rm = TRUE))
cat("\n===== FRACTION conv==0 & pdHess across seeds =====\n")
print(agg[order(agg$family, agg$n_sp), ], row.names = FALSE)
cat("\nIDENTIFIABILITY_SWEEP_DONE\n")
