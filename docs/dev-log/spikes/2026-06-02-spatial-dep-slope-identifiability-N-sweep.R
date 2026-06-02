## Identifiability of the non-Gaussian spatial_dep(1 + x | coords) augmented
## slope across sample size N (n_sites), for the reserved core families.
## Spike for SPA-10 per docs/design/35-validation-debt-register.md and the
## phylo analogue spike docs/dev-log/spikes/
## 2026-06-01-phylo-dep-slope-identifiability-N-sweep.R (GAP-B1 / PHY-18).
##
## QUESTION: every non-Gaussian spatial_dep slope fit returns conv != 0 /
## non-PD Hessian at the matrix fixtures' n_sites (SPA-10). Is that genuine
## non-identifiability of the full unstructured 2T x 2T field covariance
## Sigma_field, or just finite-sample power? This sweeps n_sites and reports
## whether conv == 0 + pdHess == TRUE + recovery-within-band is reached, per
## family.
##
## METHOD (REAL public API; depends on a THROWAWAY guard relaxation):
## unlike the phylo spike (which used a MakeADFun tmb_data override), this
## spike calls the REAL gllvmTMB(value ~ 0 + trait + spatial_dep(1 + x | coords))
## API. That requires the use_spde_dep_slope family guard in R/fit-multi.R to
## admit the swept families; the companion commit relaxes that guard to the
## sweep allowlist behind GLLVMTMB_SPDE_DEP_SWEEP=1 (clearly-marked,
## throwaway). The DGP reuses the validated Gaussian recovery harness in
## tests/testthat/test-spatial-dep-slope-gaussian.R (test #2): a matrix-normal
## draw vec(Omega) ~ N(0, Sf (x) A) on the engine's own SPDE precision, with a
## known PD unstructured Sigma_field, projected through A_st onto the
## interleaved (intercept, slope) fields, then passed through each family's
## inverse link. Recovery is read from extract_Sigma(fit, level = "spatial")
## (the SPA-08/SPA-10 channel: $Sigma is the reported Sigma_field, $R its
## correlation matrix).
##
## REQUIRES an R environment with the package compiled (devtools::load_all)
## and fmesher. Authored in a container WITHOUT R; NOT executed there. Run
## locally or via the spatial-dep-identifiability-sweep GitHub Actions
## workflow (on: pull_request + workflow_dispatch).
##
## Env knobs (all optional; the workflow sets them):
##   GLLVMTMB_SWEEP_FAMILIES  comma list (default reserved cores + gaussian control)
##   GLLVMTMB_SWEEP_NGRID     comma list of n_sites (default 100,200,400,800)
##   GLLVMTMB_SWEEP_SEEDS     comma list of seeds (default 101,202,303)
##   GLLVMTMB_SWEEP_CUTOFF    mesh cutoff (default 0.05)
##   GLLVMTMB_SWEEP_OUT       CSV output path
##   GLLVMTMB_SPDE_DEP_SWEEP  must be 1 for the relaxed guard to admit families
##
## Run:  GLLVMTMB_SPDE_DEP_SWEEP=1 Rscript docs/dev-log/spikes/2026-06-02-spatial-dep-slope-identifiability-N-sweep.R

suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(TMB))

Sys.setenv(GLLVMTMB_SPDE_DEP_SWEEP = Sys.getenv("GLLVMTMB_SPDE_DEP_SWEEP", "1"))

T_tr <- 2L            # traits; C = 2T = 4 (intercept + slope per trait, interleaved)
C <- 2L * T_tr

## KNOWN PD unstructured 2T x 2T Sigma_field on the MARGINAL field scale,
## taken from the validated Gaussian recovery test (test #2 of
## test-spatial-dep-slope-gaussian.R): marginal field SDs (interleaved
## a_t0, b_t0, a_t1, b_t1) plus two intercept-slope and one cross-trait
## correlation. The engine's reported Sigma_field is on the SPDE
## parameterisation scale, so we recover MARGINAL SDs = sqrt(diag(Sigma)) /
## sf_norm and compare to `marg`.
range_true <- 0.3
kappa_true <- sqrt(8) / range_true
sf_norm    <- sqrt(4 * pi) * kappa_true
marg       <- c(0.8, 0.5, 0.6, 0.4)               # marginal field SDs
Rtrue <- diag(C)
Rtrue[1, 2] <- Rtrue[2, 1] <- -0.4                # intercept-slope (trait 0)
Rtrue[3, 4] <- Rtrue[4, 3] <-  0.3                # intercept-slope (trait 1)
Rtrue[1, 3] <- Rtrue[3, 1] <-  0.2                # cross-trait intercept-intercept
slope_var_idx <- c(2L, 4L)                        # interleaved slope-field positions

## Per-family link-scale fixed intercepts (modest so non-Gaussian means stay
## in the family's stable range), family object, dispersion truth. Mirrors the
## phylo spike .fam_spec.
.fam_spec <- function(fam) {
  switch(fam,
    gaussian = list(obj = gaussian(),               mu = c(0.0,  0.0), disp = NA, ord = FALSE),
    poisson  = list(obj = poisson(link = "log"),    mu = c(1.0,  0.7), disp = NA, ord = FALSE),
    nbinom2  = list(obj = gllvmTMB::nbinom2(),       mu = c(0.7,  0.7), disp = 3,  ord = FALSE),
    Gamma    = list(obj = Gamma(link = "log"),       mu = c(1.0,  0.5), disp = 2,  ord = FALSE),
    Beta     = list(obj = gllvmTMB::Beta(),          mu = c(0.3, -0.3), disp = 5,  ord = FALSE),
    binomial = list(obj = binomial(link = "logit"),  mu = c(0.2, -0.2), disp = NA, ord = FALSE),
    ordinal_probit = list(obj = gllvmTMB::ordinal_probit(), mu = c(0.0, 0.0), disp = NA, ord = TRUE,
                          taus = c(0, 0.7, 1.4)),
    stop("unsupported family ", fam)
  )
}

BINOM_TRIALS <- as.integer(Sys.getenv("GLLVMTMB_BINOM_TRIALS", "12"))

## Build the spatial dep fixture for one (family, n_sites, seed): matrix-normal
## field draw on the engine's own SPDE precision, projected through A_st, then
## family inverse link. Returns the long df + mesh + family object + weights.
.make_fixture <- function(fam, n_sites, seed, cutoff) {
  set.seed(seed)
  sp <- .fam_spec(fam)
  sdp <- marg * sf_norm
  Sf  <- diag(sdp) %*% Rtrue %*% diag(sdp)

  coords <- cbind(lon = stats::runif(n_sites), lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites), trait_id = seq_len(T_tr))
  df$species      <- 1L
  df$site_species <- paste0(df$site, "_1")
  df$trait <- factor(paste0("trait_", df$trait_id),
                     levels = paste0("trait_", seq_len(T_tr)))
  df$lon <- coords[df$site, 1L]
  df$lat <- coords[df$site, 2L]
  df$x   <- stats::rnorm(nrow(df))

  mesh <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = cutoff)
  n_mesh <- ncol(mesh$A_st)
  M0 <- as.matrix(mesh$spde$c0); M1 <- as.matrix(mesh$spde$g1); M2 <- as.matrix(mesh$spde$g2)
  Q <- kappa_true^4 * M0 + 2 * kappa_true^2 * M1 + M2
  ## Draw the GMRF field directly from the precision via its Cholesky:
  ## Omega ~ N(0, Q^{-1}) per column as backsolve(R, z) where R = chol(Q)
  ## (upper, R^T R = Q) so cov(R^{-1} z) = (R^T R)^{-1} = Q^{-1}. This avoids
  ## densely inverting the ill-conditioned SPDE precision -- solve(Q) hit
  ## rcond ~1e-17 at fine meshes (every cell errored / produced all-NA eta).
  Rq <- chol(Q + 1e-6 * diag(n_mesh))
  Omega <- backsolve(Rq, matrix(stats::rnorm(n_mesh * C), n_mesh, C)) %*% chol(Sf)
  A_full <- as.matrix(mesh$A_st)
  proj <- A_full %*% Omega                          # n_obs x C
  eta <- numeric(nrow(df))
  for (o in seq_len(nrow(df))) {
    t0 <- df$trait_id[o] - 1L
    eta[o] <- sp$mu[df$trait_id[o]] +
      proj[o, 2L * t0 + 1L] + df$x[o] * proj[o, 2L * t0 + 2L]
  }

  wts <- NULL
  df$value <- switch(fam,
    gaussian = eta + stats::rnorm(nrow(df), sd = 0.3),
    poisson  = stats::rpois(nrow(df), exp(eta)),
    nbinom2  = stats::rnbinom(nrow(df), mu = exp(eta), size = sp$disp),
    Gamma    = stats::rgamma(nrow(df), shape = sp$disp, scale = exp(eta) / sp$disp),
    Beta     = {
      mu <- stats::plogis(eta)
      pmin(pmax(stats::rbeta(nrow(df), mu * sp$disp, (1 - mu) * sp$disp), 1e-6), 1 - 1e-6)
    },
    binomial = {
      wts <- rep(BINOM_TRIALS, nrow(df))
      stats::rbinom(nrow(df), size = BINOM_TRIALS, prob = stats::plogis(eta))
    },
    ordinal_probit = {
      z <- eta + stats::rnorm(nrow(df))
      ordered(findInterval(z, sp$taus) + 1L, levels = seq_len(length(sp$taus) + 1L))
    },
    stop("add DGP for family ", fam)
  )
  df$site         <- factor(df$site, levels = seq_len(n_sites))
  df$species      <- factor(df$species, levels = 1L)
  df$site_species <- factor(df$site_species)
  list(df = df, mesh = mesh, fam_obj = sp$obj, weights = wts)
}

.fail_row <- function(fam, n_sites, seed, note) {
  data.frame(family = fam, n_sites = n_sites, seed = seed, conv = NA_integer_, pdHess = NA,
             max_marg_diff = NA_real_, slope_marg_ratio_1 = NA_real_,
             slope_marg_ratio_2 = NA_real_, note = note, stringsAsFactors = FALSE)
}

## Fit ONE spatial_dep slope cell via the REAL API; read recovery from
## extract_Sigma(level = "spatial"). Every stage wrapped so one bad cell yields
## a noted row, never a crash.
run_cell <- function(fam, n_sites, seed, cutoff) {
  fx <- tryCatch(.make_fixture(fam, n_sites, seed, cutoff), error = function(e) e)
  if (inherits(fx, "error")) return(.fail_row(fam, n_sites, seed, paste("fixture:", conditionMessage(fx))))

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_dep(1 + x | coords),
      data = fx$df, mesh = fx$mesh, family = fx$fam_obj,
      weights = fx$weights, silent = TRUE))),
    error = function(e) e)
  if (inherits(fit, "error")) return(.fail_row(fam, n_sites, seed, paste("fit:", conditionMessage(fit))))
  if (!inherits(fit, "gllvmTMB_multi")) return(.fail_row(fam, n_sites, seed, "non-gllvmTMB return"))

  conv   <- tryCatch(fit$opt$convergence, error = function(e) NA_integer_)
  pdHess <- tryCatch(isTRUE(fit$fit_health$pd_hessian), error = function(e) NA)

  s <- tryCatch(gllvmTMB::extract_Sigma(fit, level = "spatial"), error = function(e) e)
  if (inherits(s, "error")) return(.fail_row(fam, n_sites, seed, paste("extract_Sigma:", conditionMessage(s))))
  marg_hat <- sqrt(diag(s$Sigma)) / sf_norm
  ratios <- marg_hat[slope_var_idx] / marg[slope_var_idx]

  data.frame(family = fam, n_sites = n_sites, seed = seed, conv = conv, pdHess = pdHess,
             max_marg_diff = round(max(abs(marg_hat - marg)), 4),
             slope_marg_ratio_1 = round(ratios[1], 3), slope_marg_ratio_2 = round(ratios[2], 3),
             note = "", stringsAsFactors = FALSE)
}

## ----- configurable grid -------------------------------------------------
.env_list <- function(key, default) {
  v <- Sys.getenv(key, "")
  if (!nzchar(v)) return(default)
  trimws(strsplit(v, ",")[[1]])
}
families <- .env_list("GLLVMTMB_SWEEP_FAMILIES",
                      c("gaussian", "poisson", "nbinom2", "Gamma", "Beta", "binomial", "ordinal_probit"))
n_grid   <- as.integer(.env_list("GLLVMTMB_SWEEP_NGRID", c("100", "200", "400", "800")))
seeds    <- as.integer(.env_list("GLLVMTMB_SWEEP_SEEDS", c("101", "202", "303")))
cutoff   <- as.numeric(Sys.getenv("GLLVMTMB_SWEEP_CUTOFF", "0.1"))
out_csv  <- Sys.getenv("GLLVMTMB_SWEEP_OUT", "spatial-dep-identifiability-sweep-results.csv")

## gaussian is the CONTROL: it should pass (conv 0 + pdHess) at every N. A
## "covered" verdict for a non-Gaussian family at some N = conv 0 + pdHess +
## slope marginal-SD ratios within roughly [1/2, 2] (the validated Gaussian band).
grid <- expand.grid(family = families, n_sites = n_grid, seed = seeds, stringsAsFactors = FALSE)
cat(sprintf("Running %d cells (%d families x %d N x %d seeds), cutoff=%.3f.\n",
            nrow(grid), length(families), length(n_grid), length(seeds), cutoff))
cat("True marginal slope-field SDs:", marg[slope_var_idx], "\n\n")

results <- do.call(rbind, Map(function(f, n, s) {
  cat(sprintf("  [%-14s n_sites=%5d seed=%d] ...\n", f, n, s))
  r <- run_cell(f, n_sites = n, seed = s, cutoff = cutoff)
  cat(sprintf("      -> conv=%s pdHess=%s maxdiff=%s ratios=%s/%s %s\n",
              r$conv, r$pdHess, r$max_marg_diff, r$slope_marg_ratio_1, r$slope_marg_ratio_2,
              if (nzchar(r$note)) paste0("[", r$note, "]") else ""))
  r
}, grid$family, grid$n_sites, grid$seed))

cat("\n===== SPATIAL_DEP IDENTIFIABILITY SWEEP RESULTS =====\n")
print(results, row.names = FALSE)
write.csv(results, out_csv, row.names = FALSE)
cat(sprintf("\nWrote %s\n", out_csv))

## Per-(family, N) verdict: fraction of seeds that converged PD.
res2 <- transform(results, pd = as.integer(conv == 0 & pdHess == TRUE))
if (any(!is.na(res2$pd))) {
  agg <- aggregate(pd ~ family + n_sites, data = res2,
                   FUN = function(z) mean(z, na.rm = TRUE), na.action = stats::na.pass)
  cat("\n===== FRACTION conv==0 & pdHess across seeds =====\n")
  print(agg[order(agg$family, agg$n_sites), ], row.names = FALSE)
} else {
  cat("\nNo cell produced a finite conv/pdHess result -- see the `note` column above for per-cell failure reasons.\n")
}
cat("\nSPATIAL_DEP_IDENTIFIABILITY_SWEEP_DONE\n")
