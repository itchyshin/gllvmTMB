## Design 119 §4 coverage campaign — DGP layer (gaussian wave 1).
##
## This file does NOT define its own DGP. It sources the Arc0 generators
## (dev/missing-accuracy-dgp.R on branch claude/predict-missing-se-20260815)
## so the coverage campaign runs on EXACTLY the DGP whose point-accuracy
## behaviour is already on record (MIS-37 / Arc0): gaussian, n_units = 50,
## p_traits = 25, q_true = 2, ANISOTROPIC per-trait residual sd
## sigma_j ~ lognormal(log(0.5), 0.3), fitted with loadings-only latent()
## (the deliberate DGP/fit anisotropy mismatch is inherited and stays
## called out — it is part of what the coverage gate must survive).
##
## Repo root resolution: env COV119_REPO_ROOT, else the current directory.
## On Totoro that is the rsync'd checkout of claude/predict-missing-se-20260815.

cov119_repo_root <- Sys.getenv("COV119_REPO_ROOT", unset = ".")
cov119_dgp_path <- file.path(cov119_repo_root, "dev", "missing-accuracy-dgp.R")
if (!file.exists(cov119_dgp_path)) {
  stop("Arc0 DGP not found at ", cov119_dgp_path,
       " — set COV119_REPO_ROOT to the gllvmTMB checkout ",
       "(branch claude/predict-missing-se-20260815).")
}
source(cov119_dgp_path)
## Provides: simulate_wide_data(), make_mask(), apply_mask(), mask_cells().

## ---- campaign constants (frozen; Design 119 §4) -----------------------

COV119_FAMILY   <- "gaussian"   # wave 1 is gaussian ONLY (interface contract)
COV119_N_UNITS  <- 50L
COV119_P_TRAITS <- 25L
COV119_Q_TRUE   <- 2L
COV119_MECHS    <- c("mcar05", "mcar20", "trait_clustered", "unit_clustered")
COV119_N_REPS   <- 400L        # Design 119 §4: >= 400 replicates per cell

## Pre-registered critical values (stated in the campaign brief; NOT qnorm
## recomputed at run time, so the indicator definition cannot drift).
COV119_Z95 <- 1.96
COV119_Z90 <- 1.6449

## Seed scheme: disjoint from Arc0's 1000*fam + 100*mech + rep block.
cov119_seed <- function(mech_idx, rep) 119000L + 1000L * mech_idx + rep

## ---- truth helpers ------------------------------------------------------

#' The true linear predictor matrix for a gaussian simulate_wide_data() draw.
#'
#' Gaussian branch of the Arc0 DGP: eta = 1 b0' + U Lambda', and with the
#' identity link mu = eta. simulate_wide_data() returns Lambda, U, b0, so
#' eta_true is reconstructable exactly. (Poisson solves b0 differently —
#' this helper is gaussian-only, matching wave 1.)
eta_true_matrix <- function(sim) {
  n <- nrow(sim$U)
  outer(rep(1, n), sim$b0) + sim$U %*% t(sim$Lambda)
}

#' Per-masked-cell truth lookup: returns a data frame keyed like the
#' predict_missing() output (original_row, trait) carrying eta_true and
#' y_true for the designed mask cells.
truth_at_cells <- function(sim, designed) {
  eta <- eta_true_matrix(sim)
  j <- match(designed$trait, sim$trait_names)
  data.frame(
    original_row = designed$original_row,
    trait = designed$trait,
    eta_true = eta[cbind(designed$original_row, j)],
    y_true = mapply(function(r, tr) sim$wide[[tr]][r],
                    designed$original_row, designed$trait),
    stringsAsFactors = FALSE
  )
}
