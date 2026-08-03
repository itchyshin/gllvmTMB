## =====================================================================
## Gauss reconciliation -- PHYLOGENETIC arc, dataset B:
##   a SECOND, LARGER tree; T = 4 traits; d_phy = 2 (RANK 2);
##   tip labels deliberately ordered so that levels(factor(species))
##   DIFFERS from tree$tip.label; and a RAGGED design (two (species,trait)
##   cells removed entirely, several cells thinned to one replicate).
##
## This is the phylo analogue of Arc 0's dataset C.  It is the only place
## where the following stop being degenerate and become live:
##   * the Kronecker / layout question -- is g_phy flattened SPECIES-major
##     or AXIS-major?                                    (moot at d_phy = 1)
##   * the Lambda_phy packing order and the forced upper-triangular ZEROS
##                                                       (moot at d_phy = 1)
##   * the species -> A-row permutation                  (moot when the tip
##     order already equals the factor sort order, as in dataset A)
##   * per-row index maps t(i), s(i) on a non-rectangular design
##
## Same discipline as gauss-reconcile-phylo.R: transport DERIVED from
## src/gllvmTMB.cpp + R/fit-multi.R and fixed before any comparison; both
## engines in one session; gllvm_phylo.stan compiled and called, NEVER
## edited.
## =====================================================================

pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-phylo"
here     <- file.path(pkg_root, "dev", "stan-oracle-phylo")
suppressMessages(devtools::load_all(pkg_root, quiet = TRUE))
suppressMessages(library(rstan))
rstan::rstan_options(auto_write = TRUE)

fmt <- function(x) sprintf("%.17g", x)
say <- function(...) cat(..., "\n", sep = "")
RIDGE <- 1e-8

## =====================================================================
## 1.  Dataset B -- second tree, permuted tip labels, ragged, T = 4
## =====================================================================
set.seed(77201L)
n_tip <- 10L
tree2 <- ape::rcoal(n_tip)
## Tip labels whose ALPHABETICAL sort order differs from the tree's own
## tip order -- this is what makes the A[levs, levs] permutation live.
tree2$tip.label <- c("t10","t3","t7","t1","t9","t2","t5","t8","t4","t6")
A2 <- ape::vcv(tree2, corr = TRUE)
stopifnot(all(abs(diag(A2) - 1) < 1e-12))

n_traits <- 4L; n_species <- n_tip; K <- 2L
trait_names <- c("w", "x", "y", "z")
reps <- 3L

alpha_true <- c(0.6, -0.4, 0.1, 1.2)
Lam_true <- matrix(c(1.1, 0.7, -0.5, 0.3,      ## col 1
                     0.0, 0.9,  0.4, -0.8),    ## col 2, upper-tri zero at [1,2]
                   nrow = n_traits, ncol = K)
sigma_eps_true <- 0.4
R2 <- chol(A2); L2 <- t(R2)
G_true <- cbind(as.numeric(L2 %*% rnorm(n_species)),
                as.numeric(L2 %*% rnorm(n_species)))
rownames(G_true) <- rownames(A2)

rows <- list(); k <- 1L
for (sp in rownames(A2)) for (ti in seq_len(n_traits)) {
  eta_st <- alpha_true[ti] + sum(Lam_true[ti, ] * G_true[sp, ])
  for (r in seq_len(reps)) {
    rows[[k]] <- data.frame(species = sp, trait = trait_names[ti],
                            value = eta_st + rnorm(1, sd = sigma_eps_true))
    k <- k + 1L
  }
}
df2 <- do.call(rbind, rows)

## ---- make it RAGGED: two cells removed outright, several thinned ------
drop_cell <- function(d, sp, tr) d[!(d$species == sp & d$trait == tr), , drop = FALSE]
df2 <- drop_cell(df2, "t3", "y")     ## (species t3, trait y) has NO data at all
df2 <- drop_cell(df2, "t9", "w")     ## ditto
set.seed(4242L)
thin <- function(d, sp, tr) {
  idx <- which(d$species == sp & d$trait == tr)
  if (length(idx) <= 1) return(d)
  d[-idx[-1], , drop = FALSE]
}
for (pr in list(c("t1","x"), c("t5","z"), c("t10","w"), c("t6","y"), c("t2","z"))) {
  df2 <- thin(df2, pr[1], pr[2])
}
df2$species <- factor(df2$species)                       ## ALPHABETICAL levels, NOT tree order
df2$trait   <- factor(df2$trait, levels = trait_names)
rownames(df2) <- NULL
levs2 <- levels(df2$species)
say("dataset B: N = ", nrow(df2), " rows, S = ", n_species, ", T = ", n_traits, ", K = ", K)
say("tree tip order : ", paste(rownames(A2), collapse = ","))
say("factor levels  : ", paste(levs2, collapse = ","))
say("permutation is live (levels != tip order): ",
    !identical(levs2, rownames(A2)))
say("cells with zero data: ",
    sum(table(df2$species, df2$trait) == 0), " of ", n_species * n_traits)

## =====================================================================
## 2.  TMB joint objective
## =====================================================================
fit2 <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + phylo_latent(species, d = 2, vcv = A2),
  data = df2, trait = "trait", unit = "species", cluster = "species",
  family = gaussian(),
  control = gllvmTMBcontrol(optArgs = list(control = list(iter.max = 20, eval.max = 30)))
)))
obj2 <- TMB::MakeADFun(data = fit2$tmb_data, parameters = fit2$tmb_params,
                       map = fit2$tmb_map, random = NULL,
                       DLL = "gllvmTMB", silent = TRUE)
tn2 <- names(obj2$par)
n_rr <- n_traits * K - K * (K - 1L) / 2L          ## cpp:1148 expected_nt = 7

A2_eng    <- A2[levs2, levs2, drop = FALSE]        ## R/fit-multi.R:3223
A2_ridged <- A2_eng + diag(RIDGE, n_species)       ## R/fit-multi.R:3224

audit2 <- list(
  N = nrow(df2), n_par = length(obj2$par),
  expected_n_par = n_traits + 1L + n_rr + n_species * K,
  block_counts = as.list(table(tn2)),
  n_rr_expected = n_rr,
  n_aug_equals_n_species = fit2$tmb_data$n_aug_phy == n_species,
  species_aug_id_identity = identical(as.integer(fit2$tmb_data$species_aug_id),
                                      as.integer(fit2$tmb_data$species_id)),
  species_id_matches_levels = identical(as.integer(fit2$tmb_data$species_id),
                                        as.integer(df2$species) - 1L),
  levels_differ_from_tip_order = !identical(levs2, rownames(A2)),
  Ainv_matches_solve_ridged_in_LEVELS_order =
    max(abs(as.matrix(fit2$tmb_data$Ainv_phy_rr) - solve(A2_ridged))),
  Ainv_vs_solve_ridged_in_TIP_order =
    max(abs(as.matrix(fit2$tmb_data$Ainv_phy_rr) - solve(A2 + diag(RIDGE, n_species)))),
  log_det_engine = fit2$tmb_data$log_det_A_phy_rr,
  log_det_A2_ridged = as.numeric(determinant(A2_ridged, logarithm = TRUE)$modulus),
  A2_min_eig = min(eigen(A2_eng, symmetric = TRUE, only.values = TRUE)$values),
  A2_condition = kappa(A2_eng, exact = TRUE),
  ridge_relative_to_min_eig = RIDGE / min(eigen(A2_eng, symmetric = TRUE, only.values = TRUE)$values)
)
say("\n== ALIGNMENT AUDIT (dataset B) =="); str(audit2, max.level = 1)

## =====================================================================
## 3.  Stan shell (same compiled program, new dimensions)
## =====================================================================
stan_file <- file.path(here, "gllvm_phylo.stan")
mtime0 <- file.mtime(stan_file)
sm <- rstan::stan_model(stan_file)
mk_shell <- function(dat) suppressMessages(rstan::sampling(sm, data = dat, chains = 0))

stan_data_B <- list(
  N = nrow(df2), n_t = n_traits, S = n_species, K = K,
  tt = as.integer(df2$trait), ss = as.integer(df2$species),   ## index into LEVELS
  y = df2$value, L_A = t(chol(A2_ridged))
)
shell_B <- mk_shell(stan_data_B)

## ---- the DERIVED transport, verbatim from cpp:1144-1163 + cpp:694 -----
pack_Lambda <- function(trr, p, rank) {
  lam_diag <- trr[seq_len(rank)]; lam_lower <- trr[-seq_len(rank)]
  L <- matrix(0, p, rank)
  for (j in seq_len(rank)) for (i in seq_len(p)) {
    if (j > i) L[i, j] <- 0
    else if (i == j) L[i, j] <- lam_diag[j]
    else L[i, j] <- lam_lower[(j - 1) * p - (j - 1) * j / 2 + (i - 1) - 1 - (j - 1) + 1]
  }
  L
}
to_stan <- function(th) list(
  mu = th[tn2 == "b_fix"],
  Lambda = pack_Lambda(th[tn2 == "theta_rr_phy"], n_traits, K),
  sigma_eps = exp(th[tn2 == "log_sigma_eps"]),
  G = matrix(th[tn2 == "g_phy"], nrow = n_species, ncol = K)   ## SPECIES-fastest
)
slp <- function(shell, pars, adjust = FALSE)
  as.numeric(rstan::log_prob(shell, rstan::unconstrain_pars(shell, pars),
                             adjust_transform = adjust, gradient = FALSE))

mk_theta <- function(b, lse, trr, g) {
  th <- numeric(length(tn2))
  th[tn2 == "b_fix"] <- b; th[tn2 == "log_sigma_eps"] <- lse
  th[tn2 == "theta_rr_phy"] <- trr; th[tn2 == "g_phy"] <- g
  th
}
set.seed(9091L)
points_B <- list(
  `B/Q1` = mk_theta(c(0.6,-0.4,0.1,1.2), log(0.4),
                    c(1.1, 0.9, 0.7, -0.5, 0.3, 0.4, -0.8),
                    round(rnorm(n_species * K), 3)),
  `B/Q2` = mk_theta(c(-2.2, 1.7, 0.05, -0.9), log(1.35),
                    c(-1.6, 2.4, 0.15, -2.05, 1.33, -0.44, 0.98),
                    round(rnorm(n_species * K, sd = 1.4), 3)),
  `B/Q3` = mk_theta(c(0.0, 0.0, 0.0, 0.0), log(0.12),
                    c(3.3, -2.9, 1.05, 0.6, -1.8, 2.2, -0.35),
                    round(rnorm(n_species * K, sd = 0.6), 3))
)

resB <- list()
for (nm in names(points_B)) {
  th <- points_B[[nm]]
  tmb <- obj2$fn(th); pars <- to_stan(th)
  lpF <- slp(shell_B, pars, FALSE); lpT <- slp(shell_B, pars, TRUE)
  resB[[nm]] <- list(tmb_nll = tmb, stan_lp = lpF,
                     abs_diff = abs(-tmb - lpF), rel_diff = abs(-tmb - lpF)/abs(lpF),
                     jac_measured = lpT - lpF, jac_predicted = log(pars$sigma_eps))
}
say("\n== DATASET B: 3 points (T=4, K=2, ragged, permuted tips) ==")
for (nm in names(resB)) {
  r <- resB[[nm]]
  say(sprintf("%-6s tmb=%s  stan=%s  |d|=%.3e  rel=%.3e   jac d=%.2e",
              nm, fmt(r$tmb_nll), fmt(r$stan_lp), r$abs_diff, r$rel_diff,
              abs(r$jac_measured - r$jac_predicted)))
}

## =====================================================================
## 4.  CONTROLS that are only live at K >= 2 / permuted tips / ragged
## =====================================================================
th1 <- points_B[[1]]; p1 <- to_stan(th1); base <- slp(shell_B, p1, FALSE)
ctlB <- list()
## (a) break the forced upper-triangular ZERO
pz <- p1; pz$Lambda[1, 2] <- 0.85
ctlB$break_triangular_zero <- slp(shell_B, pz, FALSE) - base
## (b) read g_phy AXIS-fastest instead of species-fastest (Kronecker order)
pg <- p1; pg$G <- matrix(th1[tn2 == "g_phy"], nrow = n_species, ncol = K, byrow = TRUE)
ctlB$G_axis_major <- slp(shell_B, pg, FALSE) - base
## (c) read the Lambda packing ROW-major into the lower triangle
pl <- p1; Lalt <- matrix(0, n_traits, K)
trr <- th1[tn2 == "theta_rr_phy"]; ii <- 1L
for (i in seq_len(n_traits)) for (j in seq_len(K)) if (j <= i) { Lalt[i, j] <- trr[ii]; ii <- ii + 1L }
pl$Lambda <- Lalt
ctlB$Lambda_packed_row_major <- slp(shell_B, pl, FALSE) - base
## (d) use A in TREE-TIP order rather than FACTOR-LEVEL order
ctlB$A_in_tip_order_not_level_order <-
  slp(mk_shell(modifyList(stan_data_B, list(L_A = t(chol(A2 + diag(RIDGE, n_species)))))), p1, FALSE) - base
## (e) drop the engine's ridge
ctlB$no_ridge <-
  slp(mk_shell(modifyList(stan_data_B, list(L_A = t(chol(A2_eng))))), p1, FALSE) - base
## (f) treat A as a precision
ctlB$A_as_precision <-
  slp(mk_shell(modifyList(stan_data_B, list(L_A = t(chol(solve(A2_ridged)))))), p1, FALSE) - base
## (g) exp() the loadings diagonal
pe <- p1; diag(pe$Lambda) <- exp(diag(p1$Lambda)[seq_len(K)])
ctlB$exp_lambda_diag <- slp(shell_B, pe, FALSE) - base
## (h) drop / sign-flip the log|A| term  (K = 2, so it enters twice)
ctlB$drop_logdetA_term <- 0.5 * audit2$log_det_A2_ridged * K
ctlB$logdet_sign_flip  <- -audit2$log_det_A2_ridged * K

say("\n== CONTROLS at B/Q1 (shift in the Stan log-density) ==")
for (nm in names(ctlB)) say(sprintf("  %-34s : %+.10g", nm, ctlB[[nm]]))

dodB <- c("Q2 - Q1" = (-resB[[2]]$tmb_nll + resB[[1]]$tmb_nll) - (resB[[2]]$stan_lp - resB[[1]]$stan_lp),
          "Q3 - Q1" = (-resB[[3]]$tmb_nll + resB[[1]]$tmb_nll) - (resB[[3]]$stan_lp - resB[[1]]$stan_lp))
say("\n== DIFFERENCE-OF-DIFFERENCES =="); print(dodB)

stopifnot(identical(mtime0, file.mtime(stan_file)))
say("\n[gllvm_phylo.stan mtime unchanged -- the Stan density was not modified]")

saveRDS(list(audit = audit2, results = resB, controls = ctlB, dod = dodB),
        file.path(here, "gauss-reconcile-phylo-k2.rds"))
jsonlite::write_json(list(audit = audit2, results = resB, controls = ctlB, dod = as.list(dodB)),
                     file.path(here, "gauss-reconcile-phylo-k2.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
say("Wrote gauss-reconcile-phylo-k2.{rds,json}")
