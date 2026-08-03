## Stan-oracle fixed-parameter likelihood check -- TMB side, PHYLOGENETIC arc (Curie).
##
## Target model: ordinary Gaussian, long format, ONE grouping level = species,
## a reduced-rank PHYLOGENETIC latent term at rank d = 1, loadings-only
## (unique = FALSE, the default):
##   value ~ 0 + trait + phylo_latent(species, d = 1, vcv = A)
## i.e. eta(o) = alpha[trait(o)] + Lambda_phy[trait(o), 1] * g_phy[species(o)],
##      g_phy[, 1] ~ N(0, A)  (A = tip-level phylogenetic correlation matrix,
##      passed via the dense/legacy `vcv =` path -- see tmb-side-phylo.md sec (a)).
##
## Mirrors dev/stan-oracle/tmb-side.R (Arc 0, ordinary Gaussian latent + unique)
## as closely as the different covariance structure allows. Read
## dev/stan-oracle/reconciliation.md FIRST -- inherited adjustments: sign flip
## (TMB minimises, Stan maximises), adjust_transform = FALSE on the Stan side,
## and a scale/layout parameter transport read off src/gllvmTMB.cpp, not
## guessed from documentation (docs/design/04-random-effects.md is known to
## misdescribe the loadings diagonal -- see reconciliation.md sec 6.1).
##
## This script:
##   1. Builds a small ultrametric coalescent tree (ape::rcoal, fixed seed),
##      8 tips, and derives the DENSE tip-level phylogenetic correlation
##      matrix A = ape::vcv(tree, corr = TRUE).
##   2. Simulates a tiny fixed-seed dataset: 8 species x 3 traits x 2 reps,
##      with species scores drawn from N(0, A) so the simulated data actually
##      carries phylogenetic signal (not required for the check's validity,
##      but makes the fixture non-degenerate).
##   3. Fits it with gllvmTMB() using phylo_latent(species, d = 1, vcv = A)
##      -- convergence quality does not matter, this run exists only to
##      obtain a valid TMB object with the right data/parameter/map structure.
##   4. Rebuilds a JOINT (non-integrated) TMB::MakeADFun() object from that
##      fit's own tmb_data / tmb_params / tmb_map, with random = NULL -- the
##      same move Arc 0 / R/eva-proto.R's .eva_make_objective() uses.
##   5. Evaluates the joint negative log-density at ONE explicit, hand-chosen
##      theta (not the fitted optimum).
##   6. Verifies: two evaluations at theta are bitwise identical; a theta
##      perturbed in a PHYLO-SPECIFIC parameter (theta_rr_phy) gives a
##      different value (proves the phylo term is actually live, not
##      silently dropped/mapped off).
##   7. Writes theta, the data, A (dense) and its Cholesky, the tree in
##      Newick, and the resulting log-density to tmb-fixture-phylo.rds and
##      .json.
##
## See tmb-side-phylo.md for the full parameter dictionary and the answers to
## (a)-(f) in the task brief.

pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-phylo"
stopifnot(file.exists(file.path(pkg_root, "DESCRIPTION")))
devtools::load_all(pkg_root, quiet = TRUE)

out_dir <- file.path(pkg_root, "dev", "stan-oracle-phylo")
stopifnot(dir.exists(out_dir))

## ---- 1. Build a small ultrametric tree + its dense correlation matrix -----
set.seed(20260803L)
n_tip <- 8L
tree <- ape::rcoal(n_tip)
tree$tip.label <- paste0("sp", seq_len(n_tip))
stopifnot(ape::is.ultrametric(tree))

A <- ape::vcv(tree, corr = TRUE)                 # dense n_tip x n_tip correlation matrix
stopifnot(identical(rownames(A), tree$tip.label), identical(colnames(A), tree$tip.label))
stopifnot(all(diag(A) == 1))                      # unit diagonal -- confirms CORRELATION, not covariance
tip_order <- tree$tip.label                        # canonical species order used throughout

## ---- 2. Simulate a tiny fixed-seed dataset --------------------------------
n_traits <- 3L
n_species <- n_tip
reps <- 2L
trait_names <- c("a", "b", "c")

alpha_true      <- c(0.4, -0.2, 0.3)                             # trait intercepts
Lambda_phy_true <- matrix(c(0.9, 0.5, -0.6), nrow = n_traits, ncol = 1L)  # d_phy = 1
sigma_eps_true  <- 0.25                                          # residual SD

## g_species ~ MVN(0, A): A = R'R (R upper Cholesky), so L = t(R) gives
## cov(L %*% z) = L L' = R'R = A for z ~ N(0, I).
R_A <- chol(A[tip_order, tip_order])
L_A <- t(R_A)
g_species_true <- as.numeric(L_A %*% rnorm(n_species))
names(g_species_true) <- tip_order

eta <- outer(rep(1, n_species), alpha_true) +
  outer(g_species_true, as.numeric(Lambda_phy_true))
rownames(eta) <- tip_order

rows <- vector("list", n_species * n_traits * reps)
k <- 1L
for (sp in tip_order) {
  for (t in seq_len(n_traits)) {
    for (r in seq_len(reps)) {
      rows[[k]] <- data.frame(
        species = sp,
        trait   = trait_names[t],
        value   = eta[sp, t] + rnorm(1, sd = sigma_eps_true)
      )
      k <- k + 1L
    }
  }
}
df <- do.call(rbind, rows)
df$species <- factor(df$species, levels = tip_order)
df$trait   <- factor(df$trait, levels = trait_names)
stopifnot(nrow(df) == n_species * n_traits * reps)

## ---- 3. Fit with gllvmTMB() to obtain a valid TMB object ------------------
## Convergence quality does not matter -- only the resulting tmb_data /
## tmb_params / tmb_map structure is used below. `vcv = A` (a plain dense
## `matrix`, not a sparseMatrix) routes through the LEGACY DENSE phylo path
## in R/fit-multi.R (n_aug_phy == n_species, species_aug_id == species_id,
## no augmented internal-node latent variables) -- see tmb-side-phylo.md (a).
fit <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + phylo_latent(species, d = 1, vcv = A),
  data    = df,
  trait   = "trait",
  unit    = "species",
  cluster = "species",
  family  = gaussian(),
  control = gllvmTMBcontrol(optArgs = list(control = list(iter.max = 30, eval.max = 40)))
)))
stopifnot(!is.null(fit$tmb_obj))

## ---- 4. Rebuild the JOINT objective: random = NULL ------------------------
joint_obj <- TMB::MakeADFun(
  data       = fit$tmb_data,
  parameters = fit$tmb_params,
  map        = fit$tmb_map,
  random     = NULL,
  DLL        = "gllvmTMB",
  silent     = TRUE
)

theta_names <- names(joint_obj$par)
theta_counts <- as.integer(table(theta_names)[c("b_fix", "log_sigma_eps",
                                                 "theta_rr_phy", "g_phy")])
stopifnot(identical(
  theta_counts,
  c(3L, 1L, 3L, n_species)
))
stopifnot(length(joint_obj$par) == 3L + 1L + 3L + n_species)  # 15

## Confirm the phylo term is actually LIVE, not mapped off: theta_rr_phy and
## g_phy must both appear in theta_names (not silently absent because they
## were `map`-fixed to NA and dropped from joint_obj$par).
stopifnot("theta_rr_phy" %in% theta_names, "g_phy" %in% theta_names)
## Confirm no ordinary (non-phylo) latent/diag blocks snuck in -- this
## formula has no plain latent()/unique() term.
stopifnot(!any(theta_names %in% c("theta_rr_B", "z_B", "theta_diag_B", "s_B")))

## Confirm the DATA-side objects agree with the vcv()-supplied A and with the
## legacy dense-path convention documented in tmb-side-phylo.md (a)/(b):
##   n_aug_phy == n_species, species_aug_id == species_id (identity map).
stopifnot(fit$tmb_data$n_aug_phy == n_species)
stopifnot(identical(as.integer(fit$tmb_data$species_aug_id),
                     as.integer(fit$tmb_data$species_id)))
Ainv_phy_rr_engine <- as.matrix(fit$tmb_data$Ainv_phy_rr)
## The engine adds a 1e-8 ridge to A before inverting (R/fit-multi.R, legacy
## dense path) -- see tmb-side-phylo.md (b). Confirm the engine's Ainv is the
## inverse of A + 1e-8*I in species order, not of the raw vcv() output.
A_ridged <- A[tip_order, tip_order] + diag(1e-8, n_species)
stopifnot(max(abs(Ainv_phy_rr_engine - solve(A_ridged))) < 1e-6)

## ---- 5. One explicit, hand-chosen theta (NOT the fitted optimum) ----------
## Values below were generated once with fixed seeds + rnorm() and then
## hardcoded as literals (same discipline as Arc 0's tmb-side.R), so theta is
## a fixed, written-down vector, not something recomputed on every run.
b_fix_theta          <- c(0.4, -0.2, 0.3)                # natural scale
log_sigma_eps_theta  <- log(0.3)                         # log-SD
theta_rr_phy_theta   <- c(0.9, 0.5, -0.6)                # unconstrained Lambda_phy[,1]
g_phy_theta <- c(
  0.732, -1.084, 0.221, 0.917, -0.348, 1.204, -0.663, 0.056
)                                                          # length n_species = 8

theta <- numeric(length(joint_obj$par))
theta[theta_names == "b_fix"]         <- b_fix_theta
theta[theta_names == "log_sigma_eps"] <- log_sigma_eps_theta
theta[theta_names == "theta_rr_phy"]  <- theta_rr_phy_theta
theta[theta_names == "g_phy"]         <- g_phy_theta
stopifnot(all(is.finite(theta)), length(theta) == length(joint_obj$par))

## ---- 6. Verify: reproducible + phylo term genuinely live ------------------
nll_1 <- joint_obj$fn(theta)
nll_2 <- joint_obj$fn(theta)
stopifnot(identical(nll_1, nll_2))               # bitwise identical

## Perturb a PHYLO-SPECIFIC parameter (theta_rr_phy[1], the reduced-rank
## loading, not just b_fix) -- this is the load-bearing check that the phylo
## term is not silently dropped from the objective.
theta_perturbed_lambda <- theta
theta_perturbed_lambda[theta_names == "theta_rr_phy"][1] <-
  theta_perturbed_lambda[theta_names == "theta_rr_phy"][1] + 0.15
nll_perturbed_lambda <- joint_obj$fn(theta_perturbed_lambda)
stopifnot(is.finite(nll_perturbed_lambda), !identical(nll_perturbed_lambda, nll_1))

## Also perturb a phylo species-score entry (g_phy) -- confirms the A^{-1}
## quadratic form (not just Lambda_phy) is live.
theta_perturbed_g <- theta
theta_perturbed_g[theta_names == "g_phy"][1] <-
  theta_perturbed_g[theta_names == "g_phy"][1] + 0.5
nll_perturbed_g <- joint_obj$fn(theta_perturbed_g)
stopifnot(is.finite(nll_perturbed_g), !identical(nll_perturbed_g, nll_1))

cat(sprintf(
  "joint nll(theta) = %.10f   (identical repeat: %s; Lambda-perturbed differs by %.6f; g_phy-perturbed differs by %.6f)\n",
  nll_1, identical(nll_1, nll_2), nll_perturbed_lambda - nll_1, nll_perturbed_g - nll_1
))

## ---- 7. Write theta, data, A (dense + Cholesky), tree, and the log-density
fixture <- list(
  meta = list(
    formula   = "value ~ 0 + trait + phylo_latent(species, d = 1, vcv = A)",
    family    = "gaussian",
    n_traits  = n_traits,
    n_species = n_species,
    reps      = reps,
    d_phy     = 1L,
    trait_names = trait_names,
    tip_order   = tip_order,
    dll       = "gllvmTMB",
    random    = NULL,   # joint density: no random-effect block integrated out
    seed      = 20260803L,
    ridge_added_to_A = 1e-8,
    package_version = as.character(utils::packageVersion("gllvmTMB"))
  ),
  data = df,
  tree_newick = ape::write.tree(tree),
  A = A[tip_order, tip_order],           # dense tip-level correlation matrix
  A_chol_upper = R_A,                    # upper Cholesky factor, A = R'R
  theta = list(
    names  = theta_names,
    values = theta,
    blocks = list(
      b_fix         = b_fix_theta,
      log_sigma_eps = log_sigma_eps_theta,
      theta_rr_phy  = theta_rr_phy_theta,
      g_phy         = g_phy_theta
    )
  ),
  joint_neg_log_density = nll_1,
  checks = list(
    repeat_identical           = identical(nll_1, nll_2),
    perturbed_lambda_value     = nll_perturbed_lambda,
    perturbed_lambda_differs   = !identical(nll_perturbed_lambda, nll_1),
    perturbed_g_value          = nll_perturbed_g,
    perturbed_g_differs        = !identical(nll_perturbed_g, nll_1),
    n_aug_phy_equals_n_species = (fit$tmb_data$n_aug_phy == n_species),
    species_aug_id_is_identity = identical(as.integer(fit$tmb_data$species_aug_id),
                                            as.integer(fit$tmb_data$species_id)),
    log_det_A_phy_rr           = fit$tmb_data$log_det_A_phy_rr
  )
)

saveRDS(fixture, file.path(out_dir, "tmb-fixture-phylo.rds"))

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("jsonlite is required to write tmb-fixture-phylo.json.", call. = FALSE)
}
jsonlite::write_json(
  fixture, file.path(out_dir, "tmb-fixture-phylo.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null"
)

cat("Wrote:\n  ", file.path(out_dir, "tmb-fixture-phylo.rds"), "\n  ",
    file.path(out_dir, "tmb-fixture-phylo.json"), "\n")
