## Identifiability of the non-Gaussian phylo_dep(1 + x | sp) augmented slope
## across sample size N, for ALL reserved core families. Spike for GAP-B1
## (PHY-18) per
## docs/dev-log/audits/2026-06-01-slopes-dependence-family-completeness.md.
##
## QUESTION: every non-Gaussian phylo_dep slope fit returns conv != 0 /
## non-PD Hessian at n_sp <= 100 (PHY-18, SPA-10). Is that genuine non-
## identifiability, or just finite-sample power? This sweeps n_sp and reports
## whether conv == 0 + pdHess == TRUE + recovery-within-band is reached, per
## family.
##
## METHOD (no engine change): the R family guard at R/fit-multi.R:849 holds
## gaussian-only. We bypass it the same way the validated Gaussian recovery
## harness does (docs/dev-log/spikes/2026-05-30-phylo-dep-slope-recovery-
## harness.R): build a scaffold fit under the TARGET family with the family-
## general correlated-unique augmented slope `phylo_unique(1 + x | species)`
## (NOT behind the dep guard; sets up family_id_vec, link_id_vec, the
## augmented Z / b_phy_aug arrays and every family-specific dispersion param
## correctly), then override the harvested tmb_data to the DEP path
## (use_phylo_dep_slope = 1L, full unstructured C x C Sigma_b via
## theta_dep_chol) and refit via TMB::MakeADFun. The C++ accumulates the dep
## slope into eta BEFORE the family dispatch, so each family's likelihood is
## exercised with the dep covariance. RESEARCH SPIKE -- not a gating test and
## not an engine change.
##
## REQUIRES an R environment with the package compiled (devtools::load_all).
## Authored in a container WITHOUT R; NOT executed there. Run locally or via
## the `dep-slope-identifiability-sweep` GitHub Actions dispatch workflow.
##
## Env knobs (all optional; the dispatch workflow sets them):
##   GLLVMTMB_SWEEP_FAMILIES  comma list (default all reserved cores + gaussian control)
##   GLLVMTMB_SWEEP_NGRID     comma list of n_sp (default 80,150,300,600,1200)
##   GLLVMTMB_SWEEP_SEEDS     comma list of seeds (default 101,202,303)
##   GLLVMTMB_SWEEP_NREP      reps per (species,trait) cell (default 10)
##   GLLVMTMB_SWEEP_OUT       CSV output path (default dep-identifiability-sweep-results.csv)
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

## Binomial trials per row. Default 12 (multi-trial, matching test-matrix-
## slope-binomial-logit.R) routed through the `weights = n_trials` engine API;
## set GLLVMTMB_BINOM_TRIALS=1 for the low-information Bernoulli case.
BINOM_TRIALS <- as.integer(Sys.getenv("GLLVMTMB_BINOM_TRIALS", "12"))

## Per-family link-scale intercepts (modest so non-Gaussian means stay in the
## family's stable range), the family object, and dispersion truth. Borrowed
## from the validated per-family slope tests (test-matrix-slope-*.R).
.fam_spec <- function(fam) {
  switch(fam,
    gaussian = list(obj = gaussian(),                 mu = c(1.0, -0.5), disp = NA,  ord = FALSE),
    poisson  = list(obj = poisson(link = "log"),      mu = c(1.0,  0.7), disp = NA,  ord = FALSE),
    nbinom2  = list(obj = gllvmTMB::nbinom2(),         mu = c(0.7,  0.7), disp = 2,   ord = FALSE),
    Gamma    = list(obj = Gamma(link = "log"),         mu = c(1.0,  0.5), disp = 2,   ord = FALSE),
    Beta     = list(obj = gllvmTMB::Beta(),            mu = c(0.3, -0.3), disp = 5,   ord = FALSE),
    binomial = list(obj = binomial(link = "logit"),    mu = c(0.2, -0.2), disp = NA,  ord = FALSE),
    ordinal_probit = list(obj = ordinal_probit(),      mu = c(0.0,  0.0), disp = NA,  ord = TRUE,
                          taus = c(0, 0.7, 1.4)),      # K = 4 (3 cutpoints), latent residual sd = 1
    stop("unsupported family ", fam)
  )
}

## Draw the augmented effects + response on the link scale, then apply the
## family. Returns the long data frame + tree.
.make_fixture <- function(fam, n_sp, n_rep, seed) {
  set.seed(seed)
  sp <- .fam_spec(fam)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  LA <- t(chol(Cphy + diag(1e-8, n_sp)))
  B <- LA %*% matrix(rnorm(n_sp * C), n_sp, C) %*% chol(Sigma_b_true)   # interleaved (a_t, b_t)
  rownames(B) <- tree$tip.label

  sr <- expand.grid(species = factor(tree$tip.label, levels = tree$tip.label),
                    rep = seq_len(n_rep))
  sr$x <- rnorm(nrow(sr))
  trait_levels <- paste0("t", seq_len(T_tr))
  df <- merge(sr, data.frame(trait = factor(trait_levels, levels = trait_levels)), all = TRUE)
  df <- df[order(df$species, df$rep, df$trait), ]
  ti <- as.integer(df$trait)
  si <- match(as.character(df$species), tree$tip.label)
  eta <- sp$mu[ti] + B[cbind(si, 2L * (ti - 1L) + 1L)] + B[cbind(si, 2L * (ti - 1L) + 2L)] * df$x

  wts <- NULL
  df$value <- switch(fam,
    gaussian = eta + rnorm(nrow(df), sd = 0.3),
    poisson  = rpois(nrow(df), exp(eta)),
    nbinom2  = rnbinom(nrow(df), mu = exp(eta), size = sp$disp),
    Gamma    = rgamma(nrow(df), shape = sp$disp, scale = exp(eta) / sp$disp),
    Beta     = {                                                              # clamp exact 0/1 (Beta support is open)
      mu <- plogis(eta)
      pmin(pmax(rbeta(nrow(df), mu * sp$disp, (1 - mu) * sp$disp), 1e-6), 1 - 1e-6)
    },
    binomial = {                                                             # multi-trial via weights = n_trials API
      wts <- rep(BINOM_TRIALS, nrow(df))
      rbinom(nrow(df), size = BINOM_TRIALS, prob = plogis(eta))
    },
    ordinal_probit = {
      z <- eta + rnorm(nrow(df))                                              # latent, residual sd = 1
      ordered(findInterval(z, sp$taus) + 1L, levels = seq_len(length(sp$taus) + 1L))
    },
    stop("add DGP for family ", fam)
  )
  list(df = df, tree = tree, fam_obj = sp$obj, weights = wts)
}

.fail_row <- function(fam, n_sp, seed, note) {
  data.frame(family = fam, n_sp = n_sp, seed = seed, conv = NA_integer_, pdHess = NA,
             max_sigma_diff = NA_real_, slope_var_ratio_1 = NA_real_,
             slope_var_ratio_2 = NA_real_, note = note, stringsAsFactors = FALSE)
}

## Fit ONE dep-slope cell: scaffold under the target family, override to dep,
## refit, sdreport. Returns a one-row result. Every stage is wrapped so one
## bad cell yields a noted row, never a crash, and the sweep continues.
run_cell <- function(fam, n_sp, n_rep = 10L, seed = 1L) {
  fx <- tryCatch(.make_fixture(fam, n_sp, n_rep, seed), error = function(e) e)
  if (inherits(fx, "error")) return(.fail_row(fam, n_sp, seed, paste("fixture:", conditionMessage(fx))))

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  base <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_unique(1 + x | species),
      data = fx$df, phylo_tree = fx$tree, unit = "species",
      family = fx$fam_obj, weights = fx$weights, control = ctl))),
    error = function(e) e)
  if (inherits(base, "error")) return(.fail_row(fam, n_sp, seed, paste("scaffold:", conditionMessage(base))))

  dat <- base$tmb_data; par <- base$tmb_params; map <- base$tmb_map
  n_aug <- dat$n_aug_phy; n_obs <- length(dat$y)

  ## Override harvested scaffold to the DEP path (full unstructured C x C).
  dat$use_phylo_dep_slope <- 1L
  dat$n_lhs_cols <- C
  trid <- dat$trait_id; xvec <- dat$x_phy_slope
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
  if (inherits(obj, "error")) return(.fail_row(fam, n_sp, seed, paste("MakeADFun:", conditionMessage(obj))))

  fit <- tryCatch(nlminb(obj$par, obj$fn, obj$gr, control = list(iter.max = 3000, eval.max = 4000)),
                  error = function(e) e)
  if (inherits(fit, "error")) return(.fail_row(fam, n_sp, seed, paste("nlminb:", conditionMessage(fit))))

  sdr <- tryCatch(TMB::sdreport(obj), error = function(e) e)
  pdHess <- if (inherits(sdr, "error")) NA else isTRUE(sdr$pdHess)
  Sigma_hat <- tryCatch(obj$report()$Sigma_b_dep, error = function(e) NULL)
  if (is.null(Sigma_hat)) return(.fail_row(fam, n_sp, seed, "report() lacked Sigma_b_dep"))
  ratios <- diag(Sigma_hat)[slope_var_idx] / diag(Sigma_b_true)[slope_var_idx]

  data.frame(family = fam, n_sp = n_sp, seed = seed, conv = fit$convergence, pdHess = pdHess,
             max_sigma_diff = round(max(abs(Sigma_hat - Sigma_b_true)), 4),
             slope_var_ratio_1 = round(ratios[1], 3), slope_var_ratio_2 = round(ratios[2], 3),
             note = if (inherits(sdr, "error")) "sdreport failed" else "", stringsAsFactors = FALSE)
}

## ----- configurable grid -------------------------------------------------
.env_list <- function(key, default) {
  v <- Sys.getenv(key, "")
  if (!nzchar(v)) return(default)
  trimws(strsplit(v, ",")[[1]])
}
families <- .env_list("GLLVMTMB_SWEEP_FAMILIES",
                      c("gaussian", "poisson", "nbinom2", "Gamma", "Beta", "binomial", "ordinal_probit"))
n_grid   <- as.integer(.env_list("GLLVMTMB_SWEEP_NGRID", c("80", "150", "300", "600", "1200")))
seeds    <- as.integer(.env_list("GLLVMTMB_SWEEP_SEEDS", c("101", "202", "303")))
n_rep    <- as.integer(Sys.getenv("GLLVMTMB_SWEEP_NREP", "10"))
out_csv  <- Sys.getenv("GLLVMTMB_SWEEP_OUT", "dep-identifiability-sweep-results.csv")

## gaussian is the CONTROL: it should pass (conv 0 + pdHess) at every N. If it
## does NOT, the harness itself is broken, not the identifiability question.
## A "covered" verdict for a non-Gaussian family at some N = conv 0 + pdHess +
## slope-var ratios within roughly [1/2, 2] (the validated Gaussian band).
grid <- expand.grid(family = families, n_sp = n_grid, seed = seeds, stringsAsFactors = FALSE)
cat(sprintf("Running %d cells (%d families x %d N x %d seeds), n_rep=%d.\n",
            nrow(grid), length(families), length(n_grid), length(seeds), n_rep))
cat("True slope variances:", round(diag(Sigma_b_true)[slope_var_idx], 3), "\n\n")

results <- do.call(rbind, Map(function(f, n, s) {
  cat(sprintf("  [%-14s n_sp=%5d seed=%d] ...\n", f, n, s))
  r <- run_cell(f, n_sp = n, n_rep = n_rep, seed = s)
  cat(sprintf("      -> conv=%s pdHess=%s maxdiff=%s ratios=%s/%s %s\n",
              r$conv, r$pdHess, r$max_sigma_diff, r$slope_var_ratio_1, r$slope_var_ratio_2,
              if (nzchar(r$note)) paste0("[", r$note, "]") else ""))
  r
}, grid$family, grid$n_sp, grid$seed))

cat("\n===== IDENTIFIABILITY SWEEP RESULTS (this run's fresh seeds) =====\n")
print(results, row.names = FALSE)

## Accumulation: when a durable store is supplied (GLLVMTMB_SWEEP_STORE), prepend
## the prior rows so the written CSV + aggregate are CUMULATIVE across the
## campaign's runs. The workflow derives FRESH seeds from the run number each
## run, so rows never collide and the per-cell seed count grows through the week
## -- tightening the seed-sensitive cells (nbinom2 / ordinal_probit).
store <- Sys.getenv("GLLVMTMB_SWEEP_STORE", "")
if (nzchar(store) && file.exists(store)) {
  prev <- tryCatch(utils::read.csv(store, stringsAsFactors = FALSE), error = function(e) NULL)
  if (!is.null(prev) && nrow(prev) > 0L) {
    results <- rbind(prev[, names(results), drop = FALSE], results)
    cat(sprintf("Accumulated with %d prior rows from %s -> %d total rows.\n",
                nrow(prev), store, nrow(results)))
  }
}
write.csv(results, out_csv, row.names = FALSE)
cat(sprintf("\nWrote %s (%d rows)\n", out_csv, nrow(results)))

## Per-(family, N) verdict over ALL accumulated seeds: PD-fraction + seed count.
res2 <- transform(results, pd = as.integer(conv == 0 & pdHess == TRUE))
agg_f <- aggregate(pd ~ family + n_sp, res2,
                   FUN = function(z) round(mean(z, na.rm = TRUE), 3), na.action = stats::na.pass)
agg_n <- aggregate(pd ~ family + n_sp, res2,
                   FUN = function(z) sum(!is.na(z)), na.action = stats::na.pass)
agg <- merge(agg_f, agg_n, by = c("family", "n_sp"))
names(agg)[3:4] <- c("pd_frac", "n_seeds")
cat("\n===== CUMULATIVE FRACTION conv==0 & pdHess (accumulated seed count) =====\n")
print(agg[order(agg$family, agg$n_sp), ], row.names = FALSE)
cat("\nIDENTIFIABILITY_SWEEP_DONE\n")
