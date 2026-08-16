## dev/multinomial-structured/dgp-multinomial-structured.R
##
## Seed-controlled data-generating process for the Slice-1 recovery campaign
## (multinomial structured random effects: animal_latent / kernel_latent).
##
## Model: K unordered categories, reference category 1, K-1 baseline-contrast
## pseudo-traits. n_sp species on a random tree (ape::rcoal or ape::rphylo
## pure-birth). Contrast liabilities:
##   eta_ij = X_i beta_j + a_ij,   a_i ~ MVN(0, V (x) A_corr),  j = 1..K-1
## where V is the (K-1)x(K-1) among-category covariance (the estimand), X beta
## is the per-category intercept (0 + trait design, matching the package's
## trait-dummy fixed-effect block), and A_corr is the phylogenetic correlation
## matrix (ape::vcv(tree, corr = TRUE)). One categorical draw per species
## (softmax over eta_i, cbind(0, eta_contrasts)).
##
## Data-layout and coefficient-packing conventions are matched EXACTLY to the
## existing admitted phylo_latent multinomial route so that name-keyed
## recovery does not silently break (Design 83 Section 4.5 warning):
##   - tests/testthat/test-multinomial.R  .make_multinomial()
##   - dev/phylo-multinomial-recovery-harness-reps.R  run_one()
## i.e. ONE row per species, data.frame(species = <factor>, trait =
## factor("morph"), value = factor(y)), fit with
##   gllvmTMB(value ~ 0 + trait + <keyword>(species, ...),
##            data = df, family = multinomial(), trait = "trait",
##            unit = "species")
## (cluster defaults to "species" in gllvmTMB(), so no explicit cluster= is
## needed here either, matching the phylo harness.)

#' Simulate one multinomial-structured-random-effect dataset
#'
#' @param n_sp Integer number of species (= number of rows; one categorical
#'   draw per species).
#' @param seed Integer seed (fully determines the tree and the draw).
#' @param K Integer number of categories (default 3L -> K-1 = 2 contrasts).
#' @param sd_true Length K-1 numeric vector of true among-category contrast
#'   SDs (default c(0.8, 0.8)).
#' @param rho_true True among-category contrast correlation (default 0.6).
#' @param b0 Length K-1 numeric vector of true per-category intercepts
#'   (the fixed-effect "X beta" block; X is the 0 + trait contrast design,
#'   i.e. intercept-only per Design-83/84 convention -- matches the existing
#'   phylo harness, which carries no continuous covariate).
#' @param tree_type One of "coalescent" (ape::rcoal, default) or "pb"
#'   (pure-birth via ape::rphylo(birth = 1, death = 0)).
#' @return A list with:
#'   \item{data}{data.frame(species, trait, value) ready for gllvmTMB()}
#'   \item{tree}{the ape phylo object}
#'   \item{A_corr}{the (n_sp x n_sp) phylogenetic correlation matrix}
#'   \item{V_true}{the (K-1)x(K-1) true among-category covariance}
#'   \item{rho_true, sd_true, b0_true, K, n_sp, seed}{echoed inputs}
dgp_multinomial_structured <- function(n_sp, seed, K = 3L,
                                        sd_true = c(0.8, 0.8),
                                        rho_true = 0.6,
                                        b0 = c(0.2, -0.3),
                                        tree_type = c("coalescent", "pb")) {
  tree_type <- match.arg(tree_type)
  stopifnot(K >= 3L, length(sd_true) == K - 1L, length(b0) == K - 1L)
  if (!requireNamespace("ape", quietly = TRUE)) {
    stop("dgp_multinomial_structured() needs the 'ape' package.")
  }
  if (!requireNamespace("MASS", quietly = TRUE)) {
    stop("dgp_multinomial_structured() needs the 'MASS' package.")
  }

  set.seed(seed)
  tree <- switch(tree_type,
    coalescent = ape::rcoal(n_sp),
    pb         = ape::rphylo(n_sp, birth = 1, death = 0)
  )
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  A_corr <- ape::vcv(tree, corr = TRUE)
  ## Align dimnames to the species factor levels used below (belt-and-braces;
  ## ape::vcv() already carries tip.label dimnames, but kernel_latent()
  ## requires rownames(K) aligned to the grouping levels -- Design 65 C1).
  dimnames(A_corr) <- list(tree$tip.label, tree$tip.label)

  V_true <- diag(sd_true) %*%
    matrix(c(1, rho_true, rho_true, 1), 2, 2) %*%
    diag(sd_true)

  G <- kronecker(V_true, A_corr)
  a <- MASS::mvrnorm(1, mu = rep(0, (K - 1L) * n_sp), Sigma = G)
  Amat <- matrix(a, nrow = n_sp, ncol = K - 1L)      # contrast liability per species
  eta <- cbind(0, sweep(Amat, 2, b0, `+`))            # reference category pinned at 0
  P <- exp(eta - apply(eta, 1L, max))
  P <- P / rowSums(P)
  y <- vapply(seq_len(n_sp), function(i) sample.int(K, 1L, prob = P[i, ]), integer(1))

  sp <- factor(tree$tip.label, levels = tree$tip.label)
  dat <- data.frame(species = sp, trait = factor("morph"), value = factor(y))

  list(
    data = dat, tree = tree, A_corr = A_corr, V_true = V_true,
    rho_true = rho_true, sd_true = sd_true, b0_true = b0,
    K = K, n_sp = n_sp, seed = seed, tree_type = tree_type
  )
}

## ---- pure-R self-check (no gllvmTMB load) ---------------------------------
## Rscript dev/multinomial-structured/dgp-multinomial-structured.R

.run_dgp_check <- function() {
  dgp <- dgp_multinomial_structured(n_sp = 40L, seed = 1L)
  d <- dgp$data
  cat("== dgp_multinomial_structured() one-seed check (n_sp = 40, seed = 1) ==\n")
  cat("nrow(data):", nrow(d), " (expect 40)\n")
  cat("colnames(data):", paste(colnames(d), collapse = ", "), "\n")
  cat("class(value):", class(d$value), " levels:", paste(levels(d$value), collapse = ","), "\n")
  tab <- table(d$value)
  cat("category counts:\n"); print(tab)
  cat("all K categories observed:", length(tab) == dgp$K, "\n")
  cat("dim(A_corr):", paste(dim(dgp$A_corr), collapse = " x "), " (expect 40 x 40)\n")
  cat("A_corr diag all 1:", isTRUE(all.equal(unname(diag(dgp$A_corr)), rep(1, 40),
                                              tolerance = 1e-8)), "\n")
  cat("Ntip(tree):", ape::Ntip(dgp$tree), " (expect 40)\n")
  cat("V_true:\n"); print(dgp$V_true)
  cat("any NA in data:", anyNA(d), "\n")
  invisible(dgp)
}

if (sys.nframe() == 0L) {
  .run_dgp_check()
}
