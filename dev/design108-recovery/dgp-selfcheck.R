## Design 108 recovery campaign: self-check for the two-tier DGP (dgp.R).
##
## Run with:
##   cd /private/tmp/gllvmtmb-d108-recovery && NOT_CRAN=true \
##     Rscript --vanilla -e 'devtools::load_all(quiet=TRUE); source("dev/design108-recovery/dgp-selfcheck.R")'
##
## Three checks, in order of how directly they test the DGP:
##
##  A. STRUCTURAL: on a small tree, the tier-2 GMRF sampler's empirical
##     tip-level covariance (over many independent replicate draws) matches
##     the DENSE solve(Ainv) tip submatrix. This is the direct proof that
##     `.d108_simulate_gmrf()` + the 0-based `node_of_species` map from
##     `.va_r3_phylo_structure()` really do attach correlated levels to the
##     right species -- the exact bug the CRITICAL correctness facts warn
##     about (tips are NOT the first n_tip augmented nodes).
##
##  B. ANCHOR: as `phylo_scale -> 0`, the two-tier model reduces to the
##     one-tier model. Because `simulate_two_tier()` only lets phylo_scale
##     enter as a post-hoc multiplier on already-drawn tier-2 quantities,
##     this is checked as an EXACT algebraic identity (not a fuzzy limit):
##     the tier-2 contribution to eta is exactly phylo_scale * F2_base for
##     every value of phylo_scale, and phylo_scale = 0 gives an EXACT zero
##     tier-2 contribution (Sigma_2 = 0 matrix, eta contribution = 0
##     matrix), bit for bit.
##
##  C. LARGE-N CONVERGENCE: at large N, the empirical across-species
##     covariance of each tier's realized trait-space field converges to
##     that tier's stated Sigma_B -- i.e. `truth` really is the truth.

stopifnot(requireNamespace("ape", quietly = TRUE))
source("dev/design108-recovery/dgp.R")

cat("\n== CHECK A: structural (GMRF sampler honors the 0-based tip map) ==\n")

set.seed(1)
tree_small <- ape::rcoal(8L)
sp <- sort(tree_small$tip.label)
struct_small <- .va_r3_phylo_structure(tree_small, sp)
Ainv_small <- struct_small$structured$Ainv
tip_row_small <- struct_small$node_of_species + 1L
stopifnot(all(struct_small$node_of_species >= 0L))
## Tips must NOT be the first n_tip rows (internal-first ordering) -- if this
## fails, a 1-vs-0 sniff would silently look plausible while being wrong.
stopifnot(!identical(sort(tip_row_small), seq_len(8L)))

A_small_dense <- as.matrix(Matrix::solve(Ainv_small))
A_tip_true <- A_small_dense[tip_row_small, tip_row_small]
stopifnot(all(is.finite(A_tip_true)))
cat(sprintf("  mean diag(A_tip) (should be ~1, correlation scaling): %.4f\n",
            mean(diag(A_tip_true))))

n_rep <- 6000L
U_aug_reps <- .d108_simulate_gmrf(Ainv_small, n_rep)      # n_aug x n_rep
U_tip_reps <- U_aug_reps[tip_row_small, , drop = FALSE]   # 8 x n_rep
A_tip_hat <- stats::cov(t(U_tip_reps))
err_A <- rel_frob(A_tip_hat, A_tip_true)
cat(sprintf("  rel_frob(empirical tip covariance, dense solve(Ainv) tip block) = %.4f (n_rep=%d)\n",
            err_A, n_rep))
stopifnot(is.finite(err_A), err_A < 0.10)
cat("  CHECK A: PASS\n")

cat("\n== CHECK B: anchor -- phylo_scale -> 0 reduces exactly to one-tier ==\n")

set.seed(2)
tree_anchor <- ape::rcoal(15L)
scales <- c(1, 0.1, 0.01, 1e-4, 0)
sims <- lapply(scales, function(s) {
  simulate_two_tier(N = 15L, T = 6L, q = 2L, seed = 42L,
                    phylo_scale = s, tree = tree_anchor)
})
names(sims) <- as.character(scales)

## (1) Sigma_2 truth scales exactly as phylo_scale^2.
Sigma2_base <- sims[["1"]]$truth$tier2$Sigma_B_base
for (i in seq_along(scales)) {
  s <- scales[i]
  Sigma2_expected <- (s^2) * Sigma2_base
  d <- max(abs(sims[[i]]$truth$tier2$Sigma_B - Sigma2_expected))
  cat(sprintf("  phylo_scale=%-8g  max|Sigma2 - s^2*Sigma2_base| = %.3e\n", s, d))
  stopifnot(d < 1e-10)
}

## (2) The tier-2 contribution to eta is EXACTLY phylo_scale * F2_base, and
## the tier-1 contribution (and beta0, X) is IDENTICAL across scales because
## the RNG draw order never depends on phylo_scale.
F2_base_ref <- sims[["1"]]$truth$tier2$realized_base
eta1_plus_beta0_ref <- sims[["1"]]$truth$eta - sims[["1"]]$truth$tier2$realized
for (i in seq_along(scales)) {
  s <- scales[i]
  same_base <- max(abs(sims[[i]]$truth$tier2$realized_base - F2_base_ref))
  stopifnot(same_base < 1e-12)
  tier1_unchanged <- max(abs((sims[[i]]$truth$eta - sims[[i]]$truth$tier2$realized) -
                                eta1_plus_beta0_ref))
  stopifnot(tier1_unchanged < 1e-12)
  linear_err <- max(abs(sims[[i]]$truth$tier2$realized - s * F2_base_ref))
  cat(sprintf("  phylo_scale=%-8g  max|F2 - s*F2_base| = %.3e\n", s, linear_err))
  stopifnot(linear_err < 1e-10)
}

## (3) At phylo_scale = 0 the tier-2 contribution is EXACTLY zero and the
## model IS the one-tier model.
zero_sim <- sims[["0"]]
stopifnot(identical(sum(abs(zero_sim$truth$tier2$Lambda)), 0))
stopifnot(identical(sum(abs(zero_sim$truth$tier2$psi)), 0))
stopifnot(all(zero_sim$truth$tier2$realized == 0))
stopifnot(all(zero_sim$truth$tier2$Sigma_B == 0))
eta_one_tier <- matrix(zero_sim$truth$beta0, zero_sim$N, zero_sim$T, byrow = TRUE) +
  zero_sim$truth$tier1$realized
stopifnot(max(abs(zero_sim$truth$eta - eta_one_tier)) < 1e-12)
cat("  phylo_scale=0: tier-2 Lambda/psi/realized/Sigma_B all exactly zero;\n")
cat("  eta == beta0 + tier-1 field exactly -- the two-tier model reduces to the one-tier model.\n")
cat("  CHECK B: PASS\n")

cat("\n== CHECK C: covariance convergence to the stated Sigma_B ==\n")

## Smoke first: one plain large-N two-tier dataset, inspected before trusting
## anything downstream.
N_big <- 600L; T_big <- 24L
sim_big <- simulate_two_tier(N = N_big, T = T_big, q = 2L, seed = 7L, phylo_scale = 1)
str(sim_big$data)
stopifnot(nrow(sim_big$data) == N_big * T_big,
          !anyNA(sim_big$data$y),
          all(sim_big$data$y %in% c(0, 1)),
          all(is.finite(sim_big$data$eta_true)))

## Tier 1's factor scores are species-IID, so the plain (demeaned) sample
## covariance of the realized N x T field converges to Sigma_1 directly.
Sigma1_hat_plain <- stats::cov(sim_big$truth$tier1$realized)
err1_plain <- rel_frob(Sigma1_hat_plain, sim_big$truth$tier1$Sigma_B)
cat(sprintf("  tier 1 (species-iid), N=%d T=%d: rel_frob(cov(realized), Sigma_B) = %.4f\n",
            N_big, T_big, err1_plain))
stopifnot(is.finite(err1_plain), err1_plain < 0.15)

## Tier 2's factor scores are NOT exchangeable across species -- they are
## phylogenetically correlated (rows of `realized` are dependent). A naive
## demeaned sample covariance of a SINGLE tier-2 draw is a poor estimator of
## Sigma_2: a coalescent tree has many near-duplicate close relatives, so a
## handful of deep splits dominate and the empirical mean absorbs a large
## shared low-rank mode, systematically SHRINKING cov() relative to Sigma_2
## even as N grows into the thousands (checked empirically while building
## this self-check: rel_frob stayed in 0.3-0.7 out to N=4000, non-monotone).
## This is expected under phylogenetic non-independence (the same reason PCM
## methods use GLS rather than the sample mean/covariance), not a DGP bug.
##
## The valid Monte Carlo check redraws the OBSERVATION-level noise for the
## SAME tree and the SAME truth loadings (`obs_seed`, holding `seed` and
## `tree` fixed) and uses the UNCENTERED second moment -- correct because
## E[realized row] = 0 exactly by construction, so no demeaning is needed.
## Each (species, replicate) outer product is individually unbiased for
## Sigma_2 regardless of the cross-species correlation (that correlation
## only affects the estimator's variance, not its bias), so averaging over
## many independent replicates must converge -- and does, below.
N2 <- 300L; T2 <- 24L; R <- 150L
truth_seed <- 555L
set.seed(9001L)
tree2 <- ape::rcoal(N2)
Sigma2_truth <- NULL
acc1 <- matrix(0, T2, T2); acc2 <- matrix(0, T2, T2)
for (r in seq_len(R)) {
  sr <- simulate_two_tier(N = N2, T = T2, q = 2L, seed = truth_seed, phylo_scale = 1,
                          tree = tree2, obs_seed = 10000L + r)
  if (is.null(Sigma2_truth)) Sigma2_truth <- sr$truth$tier2$Sigma_B
  stopifnot(max(abs(sr$truth$tier2$Sigma_B - Sigma2_truth)) < 1e-10)  # same truth every rep
  acc1 <- acc1 + crossprod(sr$truth$tier1$realized)
  acc2 <- acc2 + crossprod(sr$truth$tier2$realized)
}
Sigma1_hat_gls <- acc1 / (N2 * R)
Sigma2_hat_gls <- acc2 / (N2 * R)
err1_rep <- rel_frob(Sigma1_hat_gls, sr$truth$tier1$Sigma_B)
err2_rep <- rel_frob(Sigma2_hat_gls, Sigma2_truth)
cat(sprintf("  tier 1 (uncentered, %d reps x N=%d): rel_frob = %.4f\n", R, N2, err1_rep))
cat(sprintf("  tier 2 (uncentered, %d reps x N=%d): rel_frob = %.4f\n", R, N2, err2_rep))
stopifnot(is.finite(err1_rep), err1_rep < 0.10)
stopifnot(is.finite(err2_rep), err2_rep < 0.10)
cat("  CHECK C: PASS\n")

cat("\nALL CHECKS PASSED.\n")
