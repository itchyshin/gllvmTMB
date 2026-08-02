## Design 108 recovery campaign: DATA-GENERATING PROCESS for a two-tier
## binomial-probit multivariate GLLVM.
##
##   Tier 1 (ordinary species latent, unique = TRUE): trait covariance
##     Sigma_1 = Lambda_1 Lambda_1' + diag(psi_1), species-iid factor scores.
##   Tier 2 (phylogenetic latent, unique = TRUE): trait covariance
##     Sigma_2 = Lambda_2 Lambda_2' + diag(psi_2), but the FACTOR SCORES are
##     correlated across species through the sparse augmented phylogenetic
##     precision A^{-1} built by `.va_r3_phylo_structure()` (R/va-r3-proto.R),
##     which itself wraps `.gllvm_phylo_tree_precision(correlation = TRUE)`
##     (R/phylo-tree-precision.R). That builder's node ordering is
##     INTERNAL-NODES-FIRST, TIPS-LAST, and `node_of_species` is 0-BASED --
##     both facts are read off the machinery here, never hard-coded.
##
## `phylo_scale` is a single scalar multiplying BOTH Lambda_2 and psi_2 (the
## whole tier-2 trait covariance scales as phylo_scale^2, and the realized
## tier-2 contribution to the linear predictor scales as phylo_scale^1) so
## that phylo_scale -> 0 collapses tier 2 out of the model EXACTLY, including
## at the level of realized values (not just their second moments). This is
## the anchor structure exercised in dgp-selfcheck.R.
##
## Family: binomial-probit, long format (one row per unit x trait).

## Simulate a k-column matrix whose columns are iid draws from N(0, prec^-1)
## for a sparse SPD precision `prec`, via a sparse Cholesky (never a dense
## solve of `prec`, so this scales to the augmented node count of a large
## tree). Standard recipe: prec = P' L L' P (Matrix::Cholesky with a
## fill-reducing permutation P); z ~ N(0, I); y = solve(L', z) so that
## Cov(y) = P prec^-1 P'; x = solve(P', y) undoes the permutation, leaving
## Cov(x) = prec^-1.
.d108_simulate_gmrf <- function(prec, k) {
  n <- nrow(prec)
  ch <- Matrix::Cholesky(prec, LDL = FALSE, perm = TRUE)
  z <- matrix(stats::rnorm(n * k), n, k)
  y <- as.matrix(Matrix::solve(ch, z, system = "Lt"))
  as.matrix(Matrix::solve(ch, y, system = "Pt"))
}

#' Relative Frobenius error between an estimated and a true matrix
#'
#' `norm(Sigma_hat - Sigma_true, "F") / norm(Sigma_true, "F")`.
#'
#' @keywords internal
#' @noRd
rel_frob <- function(Sigma_hat, Sigma_true) {
  Sigma_hat <- as.matrix(Sigma_hat)
  Sigma_true <- as.matrix(Sigma_true)
  num <- sqrt(sum((Sigma_hat - Sigma_true)^2))
  den <- sqrt(sum(Sigma_true^2))
  num / den
}

#' Simulate a two-tier (ordinary + phylogenetic) binomial-probit GLLVM
#'
#' @param N number of species (tips).
#' @param T number of traits.
#' @param q latent dimension shared by both tiers.
#' @param seed RNG seed; the whole draw sequence (tree included, unless
#'   `tree` is supplied) is deterministic given `seed`.
#' @param phylo_scale scalar multiplier on tier 2's loadings and psi
#'   (Sigma_2 scales as phylo_scale^2, the realized tier-2 contribution to
#'   the linear predictor scales as phylo_scale^1). `phylo_scale = 0`
#'   reduces the model to the one-tier model exactly.
#' @param n_trials binomial trial count (default 1L: Bernoulli).
#' @param lambda_sd sd used to draw both tiers' base loadings.
#' @param psi_range `c(min, max)` uniform range for both tiers' base psi.
#' @param beta0_sd sd of the trait-intercept draw.
#' @param tree optional pre-built `ape::phylo` with `N` tips; if `NULL` a
#'   random ultrametric coalescent tree (`ape::rcoal(N)`) is simulated.
#' @param obs_seed optional second seed reseeding only the OBSERVATION-level
#'   draws (the tier-1/tier-2 latent scores, the psi-noise, and the response)
#'   after the tree and both tiers' loadings/psi have been drawn under
#'   `seed`. Leaving it `NULL` continues the single `seed`-controlled stream
#'   (the default, fully reproducible from `seed` alone). Supplying it lets
#'   a caller redraw independent observation-level replicates for the SAME
#'   tree and the SAME truth loadings -- e.g. to Monte Carlo check that a
#'   tier's `Sigma_B` is recovered despite phylogenetically correlated rows
#'   (dgp-selfcheck.R Check C).
#' @return A list with `data` (long-format data frame), `tree`, `Ainv`
#'   (sparse augmented phylogenetic precision), `node_of_species` (0-based,
#'   length `N`, into the rows/cols of `Ainv`), and `truth`.
#' @keywords internal
#' @noRd
simulate_two_tier <- function(N, T, q = 2L, seed,
                              phylo_scale = 1,
                              n_trials = 1L,
                              lambda_sd = 0.7,
                              psi_range = c(0.3, 1.0),
                              beta0_sd = 0.5,
                              tree = NULL,
                              obs_seed = NULL) {
  if (!requireNamespace("ape", quietly = TRUE)) {
    stop("Package 'ape' is required.", call. = FALSE)
  }
  N <- as.integer(N); T <- as.integer(T); q <- as.integer(q)
  set.seed(seed)

  if (is.null(tree)) {
    tree <- ape::rcoal(N)
  } else if (ape::Ntip(tree) != N) {
    stop("`tree` must have exactly N tips.", call. = FALSE)
  }
  species_levels <- tree$tip.label

  ## Tree machinery: read n_aug off Ainv, never compute 2N-1/2N-2 by hand;
  ## node_of_species is 0-based and tips are NOT the first n_tip nodes.
  struct <- .va_r3_phylo_structure(tree, species_levels)
  Ainv <- struct$structured$Ainv
  node_of_species <- struct$node_of_species        # 0-based, length N
  tip_row <- node_of_species + 1L                    # 1-based row into Ainv

  ## --- Both tiers' loadings/psi ("truth", not yet the observation draw) ---
  beta0 <- stats::rnorm(T, 0, beta0_sd)
  Lambda1 <- matrix(stats::rnorm(T * q, 0, lambda_sd), T, q)
  psi1 <- stats::runif(T, psi_range[1], psi_range[2])
  Lambda2_base <- matrix(stats::rnorm(T * q, 0, lambda_sd), T, q)
  psi2_base <- stats::runif(T, psi_range[1], psi_range[2])

  if (!is.null(obs_seed)) set.seed(obs_seed)

  ## --- Tier 1: ordinary, species-iid factor scores ------------------------
  U1 <- matrix(stats::rnorm(N * q), N, q)               # N x q, iid N(0, I_q) rows
  Z1 <- matrix(stats::rnorm(N * T), N, T)
  B1 <- sweep(Z1, 2, sqrt(psi1), `*`)                    # N x T
  F1 <- U1 %*% t(Lambda1) + B1                           # N x T realized tier-1 field
  Sigma1 <- Lambda1 %*% t(Lambda1) + diag(psi1, T)

  ## --- Tier 2: phylogenetic factor scores ----------------------------------
  ## One phylo GMRF field per latent dimension, over ALL augmented nodes,
  ## then restrict to the tip rows for this species set (0-based -> 1-based).
  U2_aug <- .d108_simulate_gmrf(Ainv, q)                 # n_aug x q
  U2 <- U2_aug[tip_row, , drop = FALSE]                  # N x q, unit marginal var
  Z2 <- matrix(stats::rnorm(N * T), N, T)
  F2_base <- U2 %*% t(Lambda2_base) + sweep(Z2, 2, sqrt(psi2_base), `*`)  # N x T

  Lambda2 <- phylo_scale * Lambda2_base
  psi2 <- (phylo_scale^2) * psi2_base
  Sigma2_base <- Lambda2_base %*% t(Lambda2_base) + diag(psi2_base, T)
  Sigma2 <- (phylo_scale^2) * Sigma2_base
  F2 <- phylo_scale * F2_base                            # N x T realized tier-2 field

  ## --- Linear predictor / response -----------------------------------------
  eta <- matrix(beta0, N, T, byrow = TRUE) + F1 + F2      # N x T
  p <- stats::pnorm(eta)
  Y <- matrix(stats::rbinom(N * T, n_trials, as.vector(p)), N, T)

  unit <- rep(seq_len(N), times = T)
  trait <- rep(seq_len(T), each = N)
  long <- data.frame(
    unit = unit,
    species = species_levels[unit],
    trait = trait,
    y = as.vector(Y),
    n_trials = n_trials,
    eta_true = as.vector(eta),
    p_true = as.vector(p)
  )
  long <- long[order(long$unit, long$trait), ]
  rownames(long) <- NULL

  truth <- list(
    beta0 = beta0,
    tier1 = list(Lambda = Lambda1, psi = psi1, Sigma_B = Sigma1,
                U = U1, B = B1, realized = F1),
    tier2 = list(Lambda = Lambda2, psi = psi2, Sigma_B = Sigma2,
                Lambda_base = Lambda2_base, psi_base = psi2_base,
                Sigma_B_base = Sigma2_base, phylo_scale = phylo_scale,
                U = U2, U_aug = U2_aug, B = phylo_scale * sweep(Z2, 2, sqrt(psi2_base), `*`),
                realized = F2, realized_base = F2_base),
    eta = eta, p = p
  )

  list(
    data = long,
    tree = tree,
    Ainv = Ainv,
    node_of_species = node_of_species,
    species_levels = species_levels,
    N = N, T = T, q = q,
    truth = truth
  )
}
