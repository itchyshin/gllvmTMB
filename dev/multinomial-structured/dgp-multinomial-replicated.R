## dev/multinomial-structured/dgp-multinomial-replicated.R
##
## Replicated-design DGP for the s1b replication-rescue cell
## (pass-criteria-s1b.md). Extends dgp-multinomial-structured.R WITHOUT
## modifying it: n_rep independent categorical draws per species from ONE
## shared species-level liability, so the phylogenetic random effect is
## drawn once per species and the replicates are conditionally iid softmax
## draws. Pure R (ape only), no gllvmTMB dependency.
##
## Layout: long data.frame with one row per (species, rep):
##   species — factor, n_sp levels, each repeated n_rep times (the phylo
##             grouping column; gllvmTMB's unit is the OBSERVATION here)
##   obs     — factor, n_sp * n_rep levels (unit column: unit = "obs")
##   trait   — factor, single level "morph"
##   value   — factor, categories 1..K
##
## The liability construction mirrors dgp_multinomial_structured():
## a = chol(V) z chol(A_corr)^T at the (contrast x species) level, i.e.
## vec(a) ~ MVN(0, V %x% A_corr); eta_s = b0 + a[, s] shared by all reps.

dgp_multinomial_replicated <- function(n_sp, n_rep, seed, K = 3L,
                                       sd_true = c(0.8, 0.8),
                                       rho_true = 0.6,
                                       b0 = c(0.2, -0.3)) {
  stopifnot(K == 3L, length(sd_true) == K - 1L, length(b0) == K - 1L)
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- sprintf("sp%03d", seq_len(n_sp))
  A <- ape::vcv(tree, corr = TRUE)
  A <- A[tree$tip.label, tree$tip.label]

  R <- matrix(c(1, rho_true, rho_true, 1), 2, 2)
  V <- diag(sd_true) %*% R %*% diag(sd_true)

  ## a: (K-1) x n_sp, vec(a) ~ MVN(0, V %x% A)
  Z <- matrix(rnorm((K - 1L) * n_sp), K - 1L, n_sp)
  a <- t(chol(V)) %*% Z %*% chol(A)

  eta <- sweep(a, 1L, b0, `+`)              # (K-1) x n_sp, shared by reps
  P <- apply(eta, 2L, function(e) {
    u <- exp(c(0, e))                        # baseline pinned at 0
    u / sum(u)
  })                                         # K x n_sp

  sp_idx <- rep(seq_len(n_sp), each = n_rep)
  y <- vapply(sp_idx, function(s) sample.int(K, 1L, prob = P[, s]), 1L)

  data <- data.frame(
    species = factor(tree$tip.label[sp_idx], levels = tree$tip.label),
    obs     = factor(sprintf("obs%05d", seq_along(sp_idx))),
    trait   = factor("morph"),
    value   = factor(y, levels = as.character(seq_len(K)))
  )

  list(data = data, tree = tree, A_corr = A, V_true = V,
       rho_true = rho_true, sd_true = sd_true, b0_true = b0,
       K = K, n_sp = n_sp, n_rep = n_rep, seed = seed)
}

## Self-check when run directly: one seed, structural sanity only.
if (identical(environment(), globalenv()) && !length(sys.calls())) {
  d <- dgp_multinomial_replicated(n_sp = 50L, n_rep = 5L, seed = 1L)
  stopifnot(nrow(d$data) == 250L,
            nlevels(d$data$species) == 50L,
            nlevels(d$data$obs) == 250L,
            all(table(d$data$species) == 5L),
            length(unique(d$data$value)) == 3L,
            !anyNA(d$data))
  cat("dgp_multinomial_replicated self-check OK:",
      nrow(d$data), "rows,", nlevels(d$data$species), "species x 5 reps\n")
}
