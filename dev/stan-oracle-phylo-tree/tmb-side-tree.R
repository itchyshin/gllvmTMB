## Stan-oracle fixed-parameter likelihood check -- TMB side, PHYLOGENETIC arc,
## `tree =` AUGMENTED-SPARSE route (Arc 2, Gauss).
##
## Adapted from dev/stan-oracle-phylo/tmb-side-phylo.R (Arc 1, already merged,
## dense/legacy `vcv = A` route -- do NOT modify that file or its outputs).
## Arc 1 validated the joint log-density when n_aug_phy == n_species and
## species_aug_id is the identity (no augmentation). This script targets the
## CANONICAL `tree = tree` route instead: the engine builds A^-1 over TIPS +
## INTERNAL NODES (Stage 40, R/phylo-tree-precision.R), so the latent block is
## strictly larger than n_species and species_aug_id is a genuine (non-identity)
## map. Everything below is MEASURED from a live fit, not assumed -- see
## tmb-side-tree.md for the measurements (a)-(g) with file:line citations.
##
## Target model: ordinary Gaussian, long format, ONE grouping level = species,
## a reduced-rank PHYLOGENETIC latent term at rank d = 1, loadings-only
## (unique = FALSE, the default), tree-augmented precision:
##   value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree)
## i.e. eta(o) = alpha[trait(o)] + Lambda_phy[trait(o), 1] * g_phy[species_aug_id(o), 1],
##      g_phy[, 1] ~ N(0, A_aug)  (A_aug = the AUGMENTED tips+internal-nodes
##      phylogenetic precision inverse, built by .gllvm_phylo_tree_precision()
##      -- R/phylo-tree-precision.R -- not MCMCglmm, see provenance header there).
##
## SAME 8-tip rcoal fixture and seed as Arc 1, for direct comparability: the
## tree-building and data-simulation code below (steps 1-2) is verbatim
## unchanged from tmb-side-phylo.R, in the same order, so the RNG stream -- and
## hence the tree and the simulated dataset -- are bit-identical to Arc 1's.
## Only the FIT call (step 3 onward) actually changes: `tree = tree` instead of
## `vcv = A`.
##
## This script:
##   1. Builds the same small ultrametric coalescent tree (ape::rcoal, fixed
##      seed), 8 tips, dense tip-level correlation A = ape::vcv(tree, corr=TRUE)
##      (kept only to simulate the dataset via its Cholesky; the ENGINE never
##      sees this dense A on the tree= route -- it rebuilds its own augmented
##      precision straight from the tree topology and branch lengths).
##   2. Simulates the same tiny fixed-seed dataset as Arc 1 (identical rows).
##   3. Fits it with gllvmTMB() using phylo_latent(species, d = 1, tree = tree)
##      -- convergence quality does not matter, this run exists only to obtain
##      a valid TMB object with the right (augmented) data/parameter/map
##      structure.
##   4. Rebuilds a JOINT (non-integrated) TMB::MakeADFun() object from that
##      fit's own tmb_data / tmb_params / tmb_map, with random = NULL -- same
##      move as Arc 0 and Arc 1.
##   5. MEASURES (a)-(g) from the task brief: n_aug_phy and its arithmetic,
##      node ordering of the augmented precision, the species_aug_id map,
##      log_det_A_phy_rr and its sign, presence/absence of a ridge, the full
##      tree structure the Stan side needs, and the use_* flag vector.
##   6. Evaluates the joint negative log-density at ONE explicit, hand-chosen
##      theta (not the fitted optimum) of length n_aug_phy for g_phy (NOT
##      n_species, unlike Arc 1) -- the tip-level 8 entries reuse Arc 1's exact
##      g_phy values (same positions in tip_order) so the tip-score behaviour
##      is directly comparable across arcs; 6 NEW internal-node entries pad
##      the rest.
##   7. Verifies: two evaluations at theta are bitwise identical; perturbing
##      theta_rr_phy (loadings) changes the value; perturbing g_phy at a TIP
##      position changes the value (same check as Arc 1); perturbing g_phy at
##      an INTERNAL-NODE position ALSO changes the value -- this last check is
##      NEW and specific to the augmented route: it confirms internal-node
##      scores are not a structural no-op, i.e. they are genuinely integrated
##      into the joint density even though they never appear in eta directly.
##   8. Writes theta, the data, the augmented tree/precision structure, and the
##      resulting log-density to tmb-fixture-tree.rds and .json.

pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-phylo-tree"
stopifnot(file.exists(file.path(pkg_root, "DESCRIPTION")))
devtools::load_all(pkg_root, quiet = TRUE)

out_dir <- file.path(pkg_root, "dev", "stan-oracle-phylo-tree")
stopifnot(dir.exists(out_dir))

## ---- 1. Build a small ultrametric tree + its dense correlation matrix -----
## Verbatim from tmb-side-phylo.R (Arc 1) -- same seed, same RNG draw, so the
## SAME tree. A itself is kept only to simulate the dataset (step 2); the
## engine on the tree= route never consumes this dense object (it rebuilds its
## own augmented precision directly from `tree`, see R/fit-multi.R:3157-3182).
set.seed(20260803L)
n_tip <- 8L
tree <- ape::rcoal(n_tip)
tree$tip.label <- paste0("sp", seq_len(n_tip))
stopifnot(ape::is.ultrametric(tree))

A <- ape::vcv(tree, corr = TRUE)                 # dense n_tip x n_tip correlation matrix
stopifnot(identical(rownames(A), tree$tip.label), identical(colnames(A), tree$tip.label))
stopifnot(all(diag(A) == 1))                      # unit diagonal -- confirms CORRELATION, not covariance
tip_order <- tree$tip.label                        # canonical species order used throughout

## ---- 2. Simulate a tiny fixed-seed dataset (verbatim RNG order as Arc 1) --
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

## ---- 3. Fit with gllvmTMB() using the tree= route -------------------------
## `tree = tree` (an ape::phylo object) inside phylo_latent() is harvested by
## the Phase-L loop (R/fit-multi.R:2871-2889) into the top-level `phylo_tree`,
## which routes to the Stage-40 augmented sparse-A^-1 builder
## (R/fit-multi.R:3157-3182), NOT the legacy dense path Arc 1 used.
fit <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree),
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

## ---- 5a. MEASURE n_aug_phy and its arithmetic (task (a)) ------------------
## Read straight off the engine's own tmb_data, not recomputed independently.
n_aug_phy <- as.integer(fit$tmb_data$n_aug_phy)     # R/fit-multi.R:3175 -- nrow(Ainv_phy_rr)
n_node    <- tree$Nnode                             # ape internal-node count (root included)
n_total   <- n_tip + n_node
expect_2Sminus2 <- 2L * n_species - 2L
expect_2Sminus1 <- 2L * n_species - 1L
cat(sprintf(
  "n_tip=%d  tree$Nnode=%d  n_total=n_tip+Nnode=%d  n_aug_phy(measured)=%d  2S-2=%d  2S-1=%d\n",
  n_tip, n_node, n_total, n_aug_phy, expect_2Sminus2, expect_2Sminus1
))
## Arithmetic per R/phylo-tree-precision.R:203-207: included_nodes = internal
## nodes EXCLUDING the root (n_node - 1 of them) + all n_tip tips, so
## n_aug = (n_node - 1) + n_tip = n_total - 1 (root is the only excluded node).
stopifnot(n_aug_phy == n_total - 1L)

## ---- 5b. MEASURE node ordering (task (b)) ---------------------------------
Ainv_phy_rr_sparse <- fit$tmb_data$Ainv_phy_rr            # sparse dgCMatrix, as stored
node_labels_engine <- rownames(Ainv_phy_rr_sparse)
n_internal <- n_aug_phy - n_species
cat("rownames(Ainv_phy_rr) [engine, full]:\n")
print(node_labels_engine)
is_internal_first <- all(grepl("^node[0-9]+$", node_labels_engine[seq_len(n_internal)]))
is_tips_last       <- identical(node_labels_engine[(n_internal + 1L):n_aug_phy], tip_order)
cat(sprintf("internal-first block (n=%d) all match '^node[0-9]+$': %s\n", n_internal, is_internal_first))
cat(sprintf("tips-last block (n=%d) equals tip_order exactly: %s\n", n_species, is_tips_last))
stopifnot(is_internal_first, is_tips_last)

## ---- 5c. MEASURE species_aug_id (task (c)) --------------------------------
species_aug_id_engine <- as.integer(fit$tmb_data$species_aug_id)   # 0-indexed, length n_obs
species_id_engine     <- as.integer(fit$tmb_data$species_id)       # 0-indexed, length n_obs
## One representative row per species -> its augmented position (0-indexed).
species_to_aug <- vapply(seq_len(n_species) - 1L, function(s) {
  species_aug_id_engine[match(s, species_id_engine)]
}, integer(1))
names(species_to_aug) <- tip_order
cat("species -> augmented position (0-indexed), i.e. species_aug_id map:\n")
print(species_to_aug)
cat("species -> augmented position (1-indexed) -> node label at that position:\n")
print(setNames(node_labels_engine[species_to_aug + 1L], tip_order))
species_aug_id_is_identity <- identical(species_aug_id_engine, species_id_engine)
cat(sprintf("species_aug_id identical to species_id (dense-path identity)?: %s\n", species_aug_id_is_identity))
stopifnot(!species_aug_id_is_identity)   # tree route MUST NOT be the identity map
## Every species must land in the tips-last block, at n_internal + (0..n_species-1).
stopifnot(identical(sort(unname(species_to_aug)), n_internal + (0:(n_species - 1L))))

## ---- 5d. MEASURE log_det_A_phy_rr and its sign (task (d)) -----------------
log_det_A_phy_rr_engine <- fit$tmb_data$log_det_A_phy_rr   # R/fit-multi.R:3174
## Independent check against determinant() of the engine's OWN precision
## (n_aug_phy is tiny -- 14 here -- so a dense determinant is exact and simple).
log_det_precision_direct <- as.numeric(
  determinant(as.matrix(Ainv_phy_rr_sparse), logarithm = TRUE)$modulus
)
cat(sprintf("log_det_A_phy_rr (engine, tmb_data)      = %.17g\n", log_det_A_phy_rr_engine))
cat(sprintf("determinant(Ainv_phy_rr) [= log det A^-1] = %.17g\n", log_det_precision_direct))
cat(sprintf("-determinant(Ainv_phy_rr) [= +log det A]  = %.17g\n", -log_det_precision_direct))
cat(sprintf("difference (engine - (-det(precision)))   = %.3e\n",
            log_det_A_phy_rr_engine - (-log_det_precision_direct)))
## Sign convention per R/fit-multi.R:3174: log_det_A_phy_rr <- -phy_prec$log_det_precision,
## i.e. the engine stores +log det(A), the COVARIANCE's log-det, not the precision's.
stopifnot(abs(log_det_A_phy_rr_engine - (-log_det_precision_direct)) < 1e-8)

## ---- 5e. MEASURE ridge/jitter presence (task (e)) -------------------------
## Direct recomputation from the SAME tree, via the exact function the engine
## calls (R/fit-multi.R:3172): if the tree route added a ridge, this would NOT
## be bit-identical to the engine's stored Ainv_phy_rr (Arc 1's dense/legacy
## path added `+ diag(1e-8, ...)` at R/fit-multi.R:3224, so its own comparison
## only matched solve(A + 1e-8*I) to < 1e-6, never exactly).
phy_prec <- .gllvm_phylo_tree_precision(tree, correlation = TRUE)
Ainv_phy_rr_direct <- phy_prec$precision
ridge_free_exact_identical <- identical(Ainv_phy_rr_sparse, Ainv_phy_rr_direct)
ridge_free_max_abs_diff <- max(abs(as.matrix(Ainv_phy_rr_sparse) - as.matrix(Ainv_phy_rr_direct)))
cat(sprintf("Ainv_phy_rr engine vs .gllvm_phylo_tree_precision(tree)$precision: identical()=%s, max|diff|=%.3e\n",
            ridge_free_exact_identical, ridge_free_max_abs_diff))
stopifnot(ridge_free_exact_identical, ridge_free_max_abs_diff == 0)

## ---- 5f. Save the tree structure the Stan side needs (task (f)) ----------
tree_struct <- list(
  n_tip = n_tip, n_node = n_node, n_total = n_total, n_aug_phy = n_aug_phy,
  edge = tree$edge,                       # n_edge x 2 (parent, child), ape 1-indexed node ids
  edge_length = tree$edge.length,         # length n_edge, matches edge rows
  root = phy_prec$root,                   # ape node id of the root (excluded from augmentation)
  height = phy_prec$height,               # root-to-tip height (the `scale` used when correlation=TRUE)
  node_labels = phy_prec$node_labels,     # length n_aug_phy, augmented-position order (internal-first, tips-last)
  node_index = phy_prec$node_index,       # length n_total: ape node id -> 1-indexed augmented position, 0 for root
  tip_node_index = phy_prec$tip_node_index, # named by tip label -> 1-indexed augmented position
  tip_label = tree$tip.label
)
cat("tree structure for Stan side:\n")
cat(sprintf("  root (ape node id) = %d\n", tree_struct$root))
cat(sprintf("  height (root-to-tip) = %.17g\n", tree_struct$height))
cat("  tip_node_index (tip label -> 1-indexed augmented position):\n")
print(tree_struct$tip_node_index)

## ---- 5g. MEASURE use_* flags (task (g)) -----------------------------------
use_flag_names <- grep("^use_", names(fit$tmb_data), value = TRUE)
use_flags <- vapply(use_flag_names, function(nm) as.integer(fit$tmb_data[[nm]]), integer(1))
cat("All use_* flags in fit$tmb_data:\n")
print(use_flags)
stopifnot("use_phylo_rr" %in% names(use_flags), use_flags[["use_phylo_rr"]] == 1L)
other_flags <- use_flags[names(use_flags) != "use_phylo_rr"]
stopifnot(all(other_flags == 0L))
cat(sprintf("use_phylo_rr == 1 and all %d other use_* flags == 0: TRUE\n", length(other_flags)))

## ---- 6. theta_names / theta_counts using n_aug_phy (NOT n_species) --------
theta_counts <- as.integer(table(theta_names)[c("b_fix", "log_sigma_eps",
                                                 "theta_rr_phy", "g_phy")])
stopifnot(identical(
  theta_counts,
  c(3L, 1L, 3L, n_aug_phy)
))
stopifnot(length(joint_obj$par) == 3L + 1L + 3L + n_aug_phy)  # 3+1+3+14 = 21

## Confirm the phylo term is actually LIVE, not mapped off.
stopifnot("theta_rr_phy" %in% theta_names, "g_phy" %in% theta_names)
## Confirm no ordinary (non-phylo) latent/diag blocks, AND no other phylo
## sub-blocks (diag/slope/mi-covariate) snuck in -- broader than Arc 1's check
## because the tree route shares machinery with several other use_* blocks
## (5g above measures the DATA-side flags; this measures the PARAMETER-side
## consequence of those flags all being 0 except use_phylo_rr).
stopifnot(!any(theta_names %in% c(
  "theta_rr_B", "z_B", "theta_diag_B", "s_B",
  "g_x", "log_sd_phy_diag", "g_phy_diag",
  "b_phy_slope", "log_sigma_slope", "b_phy_aug",
  "theta_rr_phy_slope", "g_phy_slope"
)))

## ---- 7. One explicit, hand-chosen theta (NOT the fitted optimum) ----------
## Same discipline as Arc 0 / Arc 1: fixed literals, not recomputed per run.
## g_phy is now length n_aug_phy = n_internal + n_species, in augmented order
## (internal-first, tips-last per 5b). The TIP block (last n_species entries)
## reuses Arc 1's exact 8 g_phy values, in the SAME tip_order, so the
## tip-level scores are directly comparable across the two arcs; the
## INTERNAL block (first n_internal entries) is 6 NEW hand-picked values
## (there is no Arc-1 analogue -- internal nodes do not exist on the dense
## route).
b_fix_theta          <- c(0.4, -0.2, 0.3)                # natural scale
log_sigma_eps_theta  <- log(0.3)                         # log-SD
theta_rr_phy_theta   <- c(0.9, 0.5, -0.6)                # unconstrained Lambda_phy[,1]
g_phy_internal_theta <- c(-0.512, 0.847, -1.126, 0.389, -0.275, 0.664)      # length n_internal = 6
g_phy_tip_theta      <- c(
  0.732, -1.084, 0.221, 0.917, -0.348, 1.204, -0.663, 0.056
)                                                          # length n_species = 8, SAME as Arc 1, in tip_order
stopifnot(length(g_phy_internal_theta) == n_internal, length(g_phy_tip_theta) == n_species)
g_phy_theta <- c(g_phy_internal_theta, g_phy_tip_theta)   # length n_aug_phy, augmented order
stopifnot(length(g_phy_theta) == n_aug_phy)

theta <- numeric(length(joint_obj$par))
theta[theta_names == "b_fix"]         <- b_fix_theta
theta[theta_names == "log_sigma_eps"] <- log_sigma_eps_theta
theta[theta_names == "theta_rr_phy"]  <- theta_rr_phy_theta
theta[theta_names == "g_phy"]         <- g_phy_theta
stopifnot(all(is.finite(theta)), length(theta) == length(joint_obj$par))

## ---- 8. Verify: reproducible + phylo term genuinely live (incl. internal) -
nll_1 <- joint_obj$fn(theta)
nll_2 <- joint_obj$fn(theta)
stopifnot(identical(nll_1, nll_2))               # bitwise identical

## Perturb a PHYLO-SPECIFIC parameter (theta_rr_phy[1], the reduced-rank
## loading) -- same check as Arc 1.
theta_perturbed_lambda <- theta
theta_perturbed_lambda[theta_names == "theta_rr_phy"][1] <-
  theta_perturbed_lambda[theta_names == "theta_rr_phy"][1] + 0.15
nll_perturbed_lambda <- joint_obj$fn(theta_perturbed_lambda)
stopifnot(is.finite(nll_perturbed_lambda), !identical(nll_perturbed_lambda, nll_1))

## Perturb a TIP-position g_phy entry (last block, index n_internal + 1 =
## species sp1's score) -- direct analogue of Arc 1's g_phy[1] perturbation,
## confirms the tip score is live both in eta AND in the augmented prior.
theta_perturbed_g_tip <- theta
g_phy_idx <- which(theta_names == "g_phy")
tip_pos_in_g_phy <- n_internal + 1L
theta_perturbed_g_tip[g_phy_idx[tip_pos_in_g_phy]] <-
  theta_perturbed_g_tip[g_phy_idx[tip_pos_in_g_phy]] + 0.5
nll_perturbed_g_tip <- joint_obj$fn(theta_perturbed_g_tip)
stopifnot(is.finite(nll_perturbed_g_tip), !identical(nll_perturbed_g_tip, nll_1))

## Perturb an INTERNAL-NODE g_phy entry (first block, index 1) -- NEW check,
## specific to the augmented route: an internal node's score never appears in
## eta (only tips do, via species_aug_id), so this ISOLATES whether the
## internal-node block of the joint density is actually live (via the A^-1
## quadratic form / prior) or a structural no-op.
theta_perturbed_g_internal <- theta
theta_perturbed_g_internal[g_phy_idx[1]] <-
  theta_perturbed_g_internal[g_phy_idx[1]] + 0.5
nll_perturbed_g_internal <- joint_obj$fn(theta_perturbed_g_internal)
stopifnot(is.finite(nll_perturbed_g_internal), !identical(nll_perturbed_g_internal, nll_1))

cat(sprintf("joint nll(theta)                       = %.17g\n", nll_1))
cat(sprintf("joint nll(theta) [repeat]               = %.17g\n", nll_2))
cat(sprintf("identical repeat?                       = %s\n", identical(nll_1, nll_2)))
cat(sprintf("nll(theta_rr_phy[1] + 0.15)              = %.17g   (diff = %.17g)\n",
            nll_perturbed_lambda, nll_perturbed_lambda - nll_1))
cat(sprintf("nll(g_phy[tip sp1] + 0.5)                = %.17g   (diff = %.17g)\n",
            nll_perturbed_g_tip, nll_perturbed_g_tip - nll_1))
cat(sprintf("nll(g_phy[internal node 1] + 0.5)        = %.17g   (diff = %.17g)\n",
            nll_perturbed_g_internal, nll_perturbed_g_internal - nll_1))

## ---- 9. Write theta, data, tree structure, and the resulting log-density -
fixture <- list(
  meta = list(
    formula   = "value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree)",
    family    = "gaussian",
    n_traits  = n_traits,
    n_species = n_species,
    n_aug_phy = n_aug_phy,
    n_internal = n_internal,
    reps      = reps,
    d_phy     = 1L,
    trait_names = trait_names,
    tip_order   = tip_order,
    dll       = "gllvmTMB",
    random    = NULL,   # joint density: no random-effect block integrated out
    seed      = 20260803L,
    ridge_added_to_A = 0,   # tree route: NO ridge (measured 5e -- exact identical() match)
    package_version = as.character(utils::packageVersion("gllvmTMB"))
  ),
  data = df,
  tree_newick = ape::write.tree(tree),
  tree_struct = tree_struct,             # edge, edge_length, root, height, node maps (task f)
  A = A[tip_order, tip_order],           # dense tip-level correlation matrix (simulation input only;
                                          # NOT consumed by the engine on this route)
  A_chol_upper = R_A,                    # upper Cholesky factor, A = R'R
  Ainv_phy_rr_dense = as.matrix(Ainv_phy_rr_sparse),  # engine's augmented precision, dense for portability
  node_labels = node_labels_engine,
  species_aug_id_map = species_to_aug,   # species (tip_order) -> augmented position, 0-indexed
  theta = list(
    names  = theta_names,
    values = theta,
    blocks = list(
      b_fix          = b_fix_theta,
      log_sigma_eps  = log_sigma_eps_theta,
      theta_rr_phy   = theta_rr_phy_theta,
      g_phy          = g_phy_theta,
      g_phy_internal = g_phy_internal_theta,
      g_phy_tip      = g_phy_tip_theta
    )
  ),
  joint_neg_log_density = nll_1,
  checks = list(
    repeat_identical              = identical(nll_1, nll_2),
    perturbed_lambda_value        = nll_perturbed_lambda,
    perturbed_lambda_differs      = !identical(nll_perturbed_lambda, nll_1),
    perturbed_g_tip_value         = nll_perturbed_g_tip,
    perturbed_g_tip_differs       = !identical(nll_perturbed_g_tip, nll_1),
    perturbed_g_internal_value    = nll_perturbed_g_internal,
    perturbed_g_internal_differs  = !identical(nll_perturbed_g_internal, nll_1),
    n_aug_phy_equals_2Sminus2     = (n_aug_phy == expect_2Sminus2),
    n_aug_phy_equals_2Sminus1     = (n_aug_phy == expect_2Sminus1),
    species_aug_id_is_identity    = species_aug_id_is_identity,
    node_order_internal_first_tips_last = (is_internal_first && is_tips_last),
    ridge_free_exact_identical    = ridge_free_exact_identical,
    ridge_free_max_abs_diff       = ridge_free_max_abs_diff,
    log_det_A_phy_rr              = log_det_A_phy_rr_engine,
    log_det_A_phy_rr_sign_check_diff = log_det_A_phy_rr_engine - (-log_det_precision_direct),
    use_phylo_rr_is_1_all_others_0 = (use_flags[["use_phylo_rr"]] == 1L && all(other_flags == 0L))
  )
)

saveRDS(fixture, file.path(out_dir, "tmb-fixture-tree.rds"))

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("jsonlite is required to write tmb-fixture-tree.json.", call. = FALSE)
}
jsonlite::write_json(
  fixture, file.path(out_dir, "tmb-fixture-tree.json"),
  auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null"
)

cat("Wrote:\n  ", file.path(out_dir, "tmb-fixture-tree.rds"), "\n  ",
    file.path(out_dir, "tmb-fixture-tree.json"), "\n")
