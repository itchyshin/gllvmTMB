## =====================================================================
## Gauss reconciliation -- PHYLOGENETIC arc (Arc 1), dataset A.
##
## Reconciles the TMB joint negative log-density against the independent
## Stan oracle `gllvm_phylo.stan`, for
##
##     value ~ 0 + trait + phylo_latent(species, d = 1, vcv = A)
##
## METHOD.  The fence is lifted, so the parameter transport is DERIVED by
## reading src/gllvmTMB.cpp and R/fit-multi.R and FIXED BEFORE any
## comparison is made -- it is never searched over a grid.  Every rule in
## `transport_rules` below carries a source citation.
##
## Both engines run in a SINGLE R session and the data are regenerated
## in-session from the same seed, so no value crosses a JSON boundary
## before being compared (Arc 0 reconciliation.md sec 6.2).
##
## NEITHER density is modified.  `gllvm_phylo.stan` is read, compiled and
## called; it is never edited.
##
## Failure modes are worked in the Arc 0 order:
##   1 SIGN  ->  2 CONSTANT TERMS  ->  3 JACOBIANS  ->
##   4 PARAMETER ORDER/SCALE  ->  5 MODEL DIFFERENCE
## plus the phylo-specific traps: A vs A^{-1}; the log|A| term; Kronecker
## ordering; correlation-vs-covariance and scaling; the phylo variance
## transform.
## =====================================================================

pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-phylo"
here     <- file.path(pkg_root, "dev", "stan-oracle-phylo")
stopifnot(file.exists(file.path(pkg_root, "DESCRIPTION")), dir.exists(here))

suppressMessages(devtools::load_all(pkg_root, quiet = TRUE))
suppressMessages(library(rstan))
rstan::rstan_options(auto_write = TRUE)

fmt <- function(x) sprintf("%.17g", x)
say <- function(...) cat(..., "\n", sep = "")

RIDGE <- 1e-8   ## R/fit-multi.R:3224  `Aphy <- Aphy + diag(1e-8, nrow = nrow(Aphy))`

## =====================================================================
## 0.  THE DERIVED TRANSPORT  (fixed here, before any number is computed)
## =====================================================================
## Each row is a source citation, not an inference.
transport_rules <- data.frame(
  stan_quantity = c("mu", "sigma_eps", "Lambda", "G", "A (role)",
                    "A (ridge)", "log|A|", "species index"),
  fixture_block = c("b_fix", "log_sigma_eps", "theta_rr_phy", "g_phy",
                    "Ainv_phy_rr", "Ainv_phy_rr / log_det_A_phy_rr",
                    "log_det_A_phy_rr", "species_aug_id"),
  rule = c(
    "identity; trait order = levels(df$trait)",
    "exp(log_sigma_eps)  -- an SD, not a variance",
    "identity, NO exp() on the diagonal; packed diag-first then strict lower tri col-major, upper tri exactly 0",
    "G[s,k] = g_phy[s,k]; PARAMETER_MATRIX(n_aug_phy x d_phy), flatten col-major = SPECIES-fastest",
    "A is the COVARIANCE (here a correlation, unit diag) of g[,k]; engine stores its INVERSE",
    "engine evaluates at A + 1e-8*I, not at the user's A",
    "+log det(A + 1e-8 I), i.e. the covariance's log-det (NOT the precision's), added to nll",
    "species_aug_id == species_id == match(species, levels(df$species)) - 1  (dense/legacy path, no augmented nodes)"
  ),
  authority = c(
    "cpp:793 eta_fix = X_fix * b_fix",
    "cpp:2103 Type sigma_eps = exp(log_sigma_eps);",
    "cpp:1144-1163 (lam_diag = theta_rr_phy.head(rank); Lambda_phy(i,j)=lam_diag(j) -- no exp)",
    "cpp:694 PARAMETER_MATRIX(g_phy); cpp:2043 g_phy(species_aug_id(o), k)",
    "R/fit-multi.R:3225 Ainv_phy_rr <- solve(Aphy); cpp:1172 quad = g' Ainv g",
    "R/fit-multi.R:3224 Aphy <- Aphy + diag(1e-8, nrow(Aphy))",
    "R/fit-multi.R:3226 determinant(Aphy)$modulus; cpp:1170-1171 nll += 0.5*(n log2pi + log_det_A + quad)",
    "R/fit-multi.R:3227-3228 n_aug_phy <- n_species; species_aug_id <- species_id"
  ),
  stringsAsFactors = FALSE
)
say("== DERIVED TRANSPORT (fixed a priori from source) ==")
print(transport_rules[, c("stan_quantity", "rule")], right = FALSE)

## =====================================================================
## 1.  Dataset A -- regenerated in-session, identical to tmb-side-phylo.R
## =====================================================================
set.seed(20260803L)
n_tip <- 8L
tree  <- ape::rcoal(n_tip)
tree$tip.label <- paste0("sp", seq_len(n_tip))
A <- ape::vcv(tree, corr = TRUE)
tip_order <- tree$tip.label

n_traits <- 3L; n_species <- n_tip; reps <- 2L
trait_names <- c("a", "b", "c")
alpha_true <- c(0.4, -0.2, 0.3)
Lambda_phy_true <- matrix(c(0.9, 0.5, -0.6), nrow = n_traits, ncol = 1L)
sigma_eps_true <- 0.25
R_A <- chol(A[tip_order, tip_order]); L_A_true <- t(R_A)
g_species_true <- as.numeric(L_A_true %*% rnorm(n_species))
names(g_species_true) <- tip_order
eta_true <- outer(rep(1, n_species), alpha_true) +
  outer(g_species_true, as.numeric(Lambda_phy_true))
rownames(eta_true) <- tip_order
rows <- vector("list", n_species * n_traits * reps); k <- 1L
for (sp in tip_order) for (t in seq_len(n_traits)) for (r in seq_len(reps)) {
  rows[[k]] <- data.frame(species = sp, trait = trait_names[t],
                          value = eta_true[sp, t] + rnorm(1, sd = sigma_eps_true))
  k <- k + 1L
}
df <- do.call(rbind, rows)
df$species <- factor(df$species, levels = tip_order)
df$trait   <- factor(df$trait, levels = trait_names)

## =====================================================================
## 2.  TMB side: fit once for structure, then the JOINT objective
## =====================================================================
fit <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + phylo_latent(species, d = 1, vcv = A),
  data = df, trait = "trait", unit = "species", cluster = "species",
  family = gaussian(),
  control = gllvmTMBcontrol(optArgs = list(control = list(iter.max = 30, eval.max = 40)))
)))
joint_obj <- TMB::MakeADFun(data = fit$tmb_data, parameters = fit$tmb_params,
                            map = fit$tmb_map, random = NULL,
                            DLL = "gllvmTMB", silent = TRUE)
tn <- names(joint_obj$par)

## ---- ALIGNMENT AUDIT (failure mode 4, structural half) ---------------
levs <- levels(df$species)
A_eng    <- A[levs, levs, drop = FALSE]
A_ridged <- A_eng + diag(RIDGE, n_species)
audit <- list(
  block_counts_ok = identical(as.integer(table(tn)[c("b_fix","g_phy","log_sigma_eps","theta_rr_phy")]),
                              c(3L, 8L, 1L, 3L)),
  n_par = length(joint_obj$par),
  phylo_blocks_live = all(c("theta_rr_phy","g_phy") %in% tn),
  no_ordinary_blocks = !any(tn %in% c("theta_rr_B","z_B","theta_diag_B","s_B")),
  use_phylo_rr = fit$tmb_data$use_phylo_rr,
  use_phylo_diag = fit$tmb_data$use_phylo_diag,
  other_use_flags_zero = all(unlist(fit$tmb_data[grep("^use_", names(fit$tmb_data))])[
    setdiff(grep("^use_", names(fit$tmb_data), value = TRUE), "use_phylo_rr")] == 0),
  n_aug_phy = fit$tmb_data$n_aug_phy,
  n_aug_equals_n_species = fit$tmb_data$n_aug_phy == n_species,
  species_aug_id_identity = identical(as.integer(fit$tmb_data$species_aug_id),
                                      as.integer(fit$tmb_data$species_id)),
  species_id_matches_levels = identical(as.integer(fit$tmb_data$species_id),
                                        as.integer(df$species) - 1L),
  trait_id_matches_levels = identical(as.integer(fit$tmb_data$trait_id),
                                      as.integer(df$trait) - 1L),
  X_fix_is_trait_indicator = isTRUE(all.equal(unname(as.matrix(fit$tmb_data$X_fix)),
                                              unname(model.matrix(~ 0 + trait, df)),
                                              check.attributes = FALSE)),
  ## ---- PHYLO TRAP: A vs A^{-1}.  The engine stores the INVERSE of the
  ## RIDGED A.  Confirm against both candidates.
  max_abs_Ainv_minus_solve_ridged = max(abs(as.matrix(fit$tmb_data$Ainv_phy_rr) - solve(A_ridged))),
  max_abs_Ainv_minus_A_itself     = max(abs(as.matrix(fit$tmb_data$Ainv_phy_rr) - A_eng)),
  ## ---- PHYLO TRAP: the log-determinant term, its sign and its argument.
  log_det_engine        = fit$tmb_data$log_det_A_phy_rr,
  log_det_A_ridged      = as.numeric(determinant(A_ridged, logarithm = TRUE)$modulus),
  log_det_A_raw         = as.numeric(determinant(A_eng,   logarithm = TRUE)$modulus),
  log_det_Ainv_ridged   = as.numeric(determinant(solve(A_ridged), logarithm = TRUE)$modulus),
  A_unit_diagonal       = max(abs(diag(A_eng) - 1)),
  A_symmetric           = max(abs(A_eng - t(A_eng))),
  A_min_eigenvalue      = min(eigen(A_eng, symmetric = TRUE, only.values = TRUE)$values),
  A_condition_number    = kappa(A_eng, exact = TRUE)
)
say("\n== ALIGNMENT AUDIT (dataset A) ==")
str(audit, max.level = 1, give.attr = FALSE)

## =====================================================================
## 3.  Stan side -- the oracle program, UNMODIFIED
## =====================================================================
stan_file <- file.path(here, "gllvm_phylo.stan")
stan_mtime_before <- file.mtime(stan_file)
sm <- rstan::stan_model(stan_file)

make_shell <- function(dat) suppressMessages(rstan::sampling(sm, data = dat, chains = 0))

stan_data_A <- list(
  N = nrow(df), n_t = n_traits, S = n_species, K = 1L,
  tt = as.integer(df$trait), ss = as.integer(df$species),
  y = df$value, L_A = t(chol(A_ridged))
)
shell_A <- make_shell(stan_data_A)

## The transport, as a function.  Derived above; NEVER searched.
to_stan_pars <- function(theta, tn, n_traits, n_species, K) {
  b   <- theta[tn == "b_fix"]
  lse <- theta[tn == "log_sigma_eps"]
  trr <- theta[tn == "theta_rr_phy"]
  g   <- theta[tn == "g_phy"]
  ## cpp:1144-1163 packing, replicated exactly (identity, no exp, upper tri = 0)
  p <- n_traits; rank <- K
  lam_diag <- trr[seq_len(rank)]; lam_lower <- trr[-seq_len(rank)]
  Lam <- matrix(0, p, rank)
  for (j in seq_len(rank)) for (i in seq_len(p)) {
    if (j > i) Lam[i, j] <- 0
    else if (i == j) Lam[i, j] <- lam_diag[j]
    else Lam[i, j] <- lam_lower[(j - 1) * p - (j - 1) * j / 2 + (i - 1) - 1 - (j - 1) + 1]
  }
  ## g_phy flattens column-major, species-fastest (cpp:694)
  G <- matrix(g, nrow = n_species, ncol = rank)
  list(mu = b, Lambda = Lam, sigma_eps = exp(lse), G = G)
}

stan_lp <- function(shell, pars, adjust = FALSE) {
  up <- rstan::unconstrain_pars(shell, pars)
  as.numeric(rstan::log_prob(shell, up, adjust_transform = adjust, gradient = FALSE))
}

## =====================================================================
## 4.  A THIRD, pure-R implementation of the spec density (for FM2, constants)
## =====================================================================
spec_lp <- function(pars, y, tt, ss, Acov, keep_constants = TRUE) {
  S <- nrow(Acov); K <- ncol(pars$G)
  eta <- pars$mu[tt] + rowSums(pars$Lambda[tt, , drop = FALSE] * pars$G[ss, , drop = FALSE])
  ## (D) data term
  lp_D <- sum(dnorm(y, eta, pars$sigma_eps, log = TRUE))
  ## (G) phylo term, one MVN(0, A) per axis
  ch <- chol(Acov); logdetA <- 2 * sum(log(diag(ch)))
  quad <- sapply(seq_len(K), function(k) {
    v <- backsolve(ch, pars$G[, k], transpose = TRUE); sum(v^2)
  })
  lp_G <- sum(-0.5 * (S * log(2 * pi) + logdetA + quad))
  n_const <- length(y) + S * K              ## number of -0.5*log(2pi) factors
  out <- lp_D + lp_G
  if (!keep_constants) out <- out + n_const * 0.5 * log(2 * pi)
  list(total = out, lp_D = lp_D, lp_G = lp_G, n_const = n_const,
       C = -0.5 * n_const * log(2 * pi), logdetA = logdetA, quad = quad)
}

## =====================================================================
## 5.  The parameter points.  P1 is the published fixture theta; P2-P4 are
##     fresh and OUT OF SAMPLE (nothing was ever selected using them).
## =====================================================================
mk_theta <- function(b, lse, trr, g) {
  th <- numeric(length(tn))
  th[tn == "b_fix"] <- b; th[tn == "log_sigma_eps"] <- lse
  th[tn == "theta_rr_phy"] <- trr; th[tn == "g_phy"] <- g
  th
}
points_A <- list(
  `A/P1 (published fixture)` = mk_theta(
    c(0.4, -0.2, 0.3), log(0.3), c(0.9, 0.5, -0.6),
    c(0.732, -1.084, 0.221, 0.917, -0.348, 1.204, -0.663, 0.056)),
  `A/P2 (fresh)` = mk_theta(
    c(-1.15, 0.62, 2.03), log(0.85), c(-1.40, 0.27, 1.11),
    c(-0.51, 0.34, 1.62, -1.28, 0.09, -0.77, 2.11, 0.45)),
  `A/P3 (fresh, near-degenerate sigma)` = mk_theta(
    c(0.05, 0.05, -0.05), log(0.05), c(0.31, -0.31, 0.02),
    c(1.9, -1.9, 0.4, -0.4, 0.8, -0.8, 0.15, -0.15)),
  `A/P4 (fresh, large loadings)` = mk_theta(
    c(3.3, -2.7, 0.9), log(2.4), c(2.8, -3.5, 4.1),
    c(0.03, 0.41, -0.92, 1.55, -2.30, 0.77, -1.11, 0.68))
)

res <- list()
for (nm in names(points_A)) {
  th <- points_A[[nm]]
  tmb_nll <- joint_obj$fn(th)
  pars <- to_stan_pars(th, tn, n_traits, n_species, 1L)
  lp_F <- stan_lp(shell_A, pars, adjust = FALSE)
  lp_T <- stan_lp(shell_A, pars, adjust = TRUE)
  sp   <- spec_lp(pars, df$value, as.integer(df$trait), as.integer(df$species), A_ridged)
  res[[nm]] <- list(
    tmb_nll = tmb_nll, neg_tmb = -tmb_nll, stan_lp = lp_F,
    abs_diff = abs(-tmb_nll - lp_F), rel_diff = abs(-tmb_nll - lp_F) / abs(lp_F),
    ## FM3 JACOBIAN: the only constrained Stan parameter is sigma_eps<lower=0>
    jac_measured = lp_T - lp_F, jac_predicted = log(pars$sigma_eps),
    ## FM2 CONSTANTS: k = (-tmb) - (constant-free spec total), in units of terms
    spec_total = sp$total, spec_D = sp$lp_D, spec_G = sp$lp_G,
    spec_constfree = spec_lp(pars, df$value, as.integer(df$trait),
                             as.integer(df$species), A_ridged, keep_constants = FALSE)$total,
    C = sp$C, n_const = sp$n_const,
    spec_vs_tmb = abs(-tmb_nll - sp$total)
  )
}

say("\n== DATASET A: 4 points ==")
for (nm in names(res)) {
  r <- res[[nm]]
  say(sprintf("%-38s  tmb=%s  stan=%s  |d|=%.3e  rel=%.3e",
              nm, fmt(r$tmb_nll), fmt(r$stan_lp), r$abs_diff, r$rel_diff))
  say(sprintf("%-38s  jac: measured=%.15g predicted=%.15g  (diff %.3e)",
              "", r$jac_measured, r$jac_predicted, abs(r$jac_measured - r$jac_predicted)))
  say(sprintf("%-38s  spec(3rd impl)=%s |d vs tmb|=%.3e ; k=%.10f terms ; D=%s G=%s",
              "", fmt(r$spec_total), r$spec_vs_tmb,
              (( -r$tmb_nll) - r$spec_constfree) / (0.5 * log(2 * pi)),
              fmt(r$spec_D), fmt(r$spec_G)))
}

## =====================================================================
## 6.  DISCRIMINATING CONTROLS -- prove the comparison CAN fail.
##     Each control breaks one derived transport rule at A/P1.
## =====================================================================
th1  <- points_A[[1]]
pars1 <- to_stan_pars(th1, tn, n_traits, n_species, 1L)
base <- stan_lp(shell_A, pars1, FALSE)

ctl <- list()
## (i) drop the engine's 1e-8 ridge  -> different A, different log|A| AND quad
ctl$no_ridge <- stan_lp(make_shell(modifyList(stan_data_A,
                        list(L_A = t(chol(A_eng))))), pars1, FALSE) - base
## (ii) treat A as a PRECISION (Cov = A^{-1})
ctl$A_as_precision <- stan_lp(make_shell(modifyList(stan_data_A,
                        list(L_A = t(chol(solve(A_ridged)))))), pars1, FALSE) - base
## (iii) exp() the loadings diagonal (the doc's claim, per Arc 0 sec 6.1)
p_exp <- pars1; p_exp$Lambda[1, 1] <- exp(p_exp$Lambda[1, 1])
ctl$exp_lambda_diag <- stan_lp(shell_A, p_exp, FALSE) - base
## (iv) read log_sigma_eps as a log-VARIANCE
p_var <- pars1; p_var$sigma_eps <- sqrt(exp(th1[tn == "log_sigma_eps"]))
ctl$sigma_as_log_variance <- stan_lp(shell_A, p_var, FALSE) - base
## (v) permute the species -> A rows (the phylo alignment trap)
set.seed(11L); perm <- sample(n_species)
ctl$species_permuted <- stan_lp(make_shell(modifyList(stan_data_A,
                        list(L_A = t(chol(A_ridged[perm, perm]))))), pars1, FALSE) - base
## (vi) omit the log|A| term entirely (the "parameter-free constant" trap)
ctl$drop_logdetA_term <- 0.5 * audit$log_det_A_ridged * stan_data_A$K
## (vii) use log|A^{-1}| instead of log|A| (a sign error on the log-det)
ctl$logdet_sign_flip <- -audit$log_det_A_ridged * stan_data_A$K

say("\n== DISCRIMINATING CONTROLS at A/P1 (shift in the Stan log-density) ==")
for (nm in names(ctl)) say(sprintf("  %-24s : %+.10g", nm, ctl[[nm]]))

## =====================================================================
## 7.  A-vs-A^{-1} NUMERICAL ROUTE: how much of the residual is the two
##     sides taking different linear-algebra routes to the same quantity?
## =====================================================================
g1 <- pars1$G[, 1]
Ainv_eng   <- as.matrix(fit$tmb_data$Ainv_phy_rr)          ## R solve(), stored sparse
quad_eng   <- as.numeric(t(g1) %*% Ainv_eng %*% g1)        ## the engine's route (cpp:1172)
ch         <- chol(A_ridged)
quad_chol  <- sum(backsolve(ch, g1, transpose = TRUE)^2)   ## Stan's route
route <- list(
  quad_via_engine_Ainv = quad_eng, quad_via_cholesky = quad_chol,
  abs_diff = abs(quad_eng - quad_chol),
  half_abs_diff_in_logdensity = 0.5 * abs(quad_eng - quad_chol),
  logdet_engine = audit$log_det_engine,
  logdet_via_cholesky = 2 * sum(log(diag(ch))),
  logdet_abs_diff = abs(audit$log_det_engine - 2 * sum(log(diag(ch))))
)
say("\n== A vs A^{-1}: the two numerical routes to the same math ==")
str(route)

## =====================================================================
## 8.  Difference-of-differences (constant-free comparison)
## =====================================================================
dod <- c(
  "P2 - P1" = ( -res[[2]]$tmb_nll - -res[[1]]$tmb_nll) - (res[[2]]$stan_lp - res[[1]]$stan_lp),
  "P3 - P1" = ( -res[[3]]$tmb_nll - -res[[1]]$tmb_nll) - (res[[3]]$stan_lp - res[[1]]$stan_lp),
  "P4 - P2" = ( -res[[4]]$tmb_nll - -res[[2]]$tmb_nll) - (res[[4]]$stan_lp - res[[2]]$stan_lp)
)
say("\n== DIFFERENCE-OF-DIFFERENCES ==")
print(dod)

stopifnot(identical(stan_mtime_before, file.mtime(stan_file)))  ## the .stan was NOT touched
say("\n[gllvm_phylo.stan mtime unchanged -- the Stan density was not modified]")

saveRDS(list(transport = transport_rules, audit = audit, results = res,
             controls = ctl, route = route, dod = dod),
        file.path(here, "gauss-reconcile-phylo.rds"))
jsonlite::write_json(list(transport = transport_rules, audit = audit, results = res,
                          controls = ctl, route = route, dod = as.list(dod)),
                     file.path(here, "gauss-reconcile-phylo.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
say("\nWrote gauss-reconcile-phylo.{rds,json}")
