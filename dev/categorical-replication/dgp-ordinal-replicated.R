## dev/categorical-replication/dgp-ordinal-replicated.R
##
## Replicated-design DGP for the PA4 ordinal cell (Design 123 "Paper
## alignment", eq 38-46 combined-effects row for ordinal_probit): the
## liability for trait t of species s carries BOTH a phylogenetic species
## effect a_{t,s} (A-structured, per-trait diagonal variance sigma_a^2) AND
## a non-phylogenetic species effect s_{t,s} (I-structured, per-trait
## variance sigma_s^2), shared across n_rep replicate observations of that
## species; each replicate then adds its own probit link residual (variance
## fixed at 1 by the ordinal_probit liability convention) implicitly via
## the cumulative-probit categorical draw.
##
##   l_{t,s,r} = b0_t + a_{t,s} + s_{t,s} + e_{t,s,r},  e ~ N(0, 1)
##   a_t ~ N(0, sigma_a^2 A_corr)  independently per trait (DIAGONAL truth,
##                                  matching the phylo_indep() fit target)
##   s_t ~ N(0, sigma_s^2 I)       independently per trait
##   y = k  iff  tau_{k-1} < l <= tau_k,  tau = (-Inf, 0, tau2, tau3, Inf)
##
## Pure R (ape only), no gllvmTMB dependency. Mirrors
## dev/multinomial-structured/dgp-multinomial-replicated.R's layout: long
## data.frame with one row per (species, rep, trait):
##   species — factor, n_sp levels (cluster/phylo column)
##   obs     — factor, n_sp * n_rep levels (unit column: unit = "obs")
##   trait   — factor, T levels
##   value   — ordered integer categories 1..K (as factor)

dgp_ordinal_replicated <- function(n_sp, n_rep, seed, T_tr = 2L, K = 4L,
                                   sigma_a = 0.8, sigma_s = 0.6,
                                   b0 = c(0.9, 0.9),
                                   tau_free = c(0.9, 1.8)) {
  stopifnot(K == 4L, length(b0) == T_tr, length(tau_free) == K - 2L)
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- sprintf("sp%03d", seq_len(n_sp))
  A <- ape::vcv(tree, corr = TRUE)
  A <- A[tree$tip.label, tree$tip.label]
  cA <- chol(A)

  ## a: T_tr x n_sp, row t ~ N(0, sigma_a^2 A) independently (diagonal truth)
  a <- sigma_a * (matrix(rnorm(T_tr * n_sp), T_tr, n_sp) %*% cA)
  ## s: T_tr x n_sp, iid N(0, sigma_s^2)
  s <- matrix(rnorm(T_tr * n_sp, sd = sigma_s), T_tr, n_sp)
  eta <- sweep(a + s, 1L, b0, `+`)          # T_tr x n_sp, shared by reps

  tau <- c(-Inf, 0, tau_free, Inf)          # tau_1 = 0 fixed (Hadfield 2015)

  sp_idx <- rep(seq_len(n_sp), each = n_rep)
  n_obs <- length(sp_idx)
  rows <- vector("list", T_tr)
  for (t in seq_len(T_tr)) {
    l <- eta[t, sp_idx] + rnorm(n_obs)      # add probit link residual
    y <- findInterval(l, tau)               # category 1..K
    rows[[t]] <- data.frame(
      species = factor(tree$tip.label[sp_idx], levels = tree$tip.label),
      obs     = factor(sprintf("obs%05d", seq_len(n_obs)),
                       levels = sprintf("obs%05d", seq_len(n_obs))),
      trait   = sprintf("tr%d", t),
      value   = y
    )
  }
  data <- do.call(rbind, rows)
  data$trait <- factor(data$trait, levels = sprintf("tr%d", seq_len(T_tr)))
  data$value <- factor(data$value, levels = as.character(seq_len(K)))
  rownames(data) <- NULL

  list(data = data, tree = tree, A_corr = A,
       sigma_a = sigma_a, sigma_s = sigma_s, b0 = b0,
       tau_true = c(0, tau_free), T_tr = T_tr, K = K,
       n_sp = n_sp, n_rep = n_rep, seed = seed)
}

## Self-check when run directly: one seed, structural sanity only.
if (identical(environment(), globalenv()) && !length(sys.calls())) {
  d <- dgp_ordinal_replicated(n_sp = 40L, n_rep = 3L, seed = 1L)
  stopifnot(nrow(d$data) == 40L * 3L * 2L,
            nlevels(d$data$species) == 40L,
            nlevels(d$data$obs) == 120L,
            nlevels(d$data$trait) == 2L,
            length(unique(d$data$value)) >= 3L,
            !anyNA(d$data))
  cat("dgp_ordinal_replicated self-check OK:",
      nrow(d$data), "rows; category table:\n")
  print(table(d$data$trait, d$data$value))
}
