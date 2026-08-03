#!/usr/bin/env Rscript
## gauss-reconcile.R -- Gauss (numerical reviewer) reconciliation driver.
##
## Runs BOTH sides in one session and compares them at SEVERAL parameter
## points and on TWO datasets (balanced + ragged).
##
## Differences from stan-side.R:
##   * The internal->natural transport is NOT selected by matching the TMB
##     number.  It is fixed up front from src/gllvmTMB.cpp (see MAPPING below)
##     and then held constant for every point.  Agreement at points that were
##     not used to pick the mapping is therefore out-of-sample evidence.
##   * A third, pure-R implementation of model-spec.md sec.7.1 is evaluated as
##     an arithmetic cross-check and to decompose the total into its three
##     terms and its 2*pi constant.
##
## MAPPING (each line verified against src/gllvmTMB.cpp, quoted in
## reconciliation.md; NOT inferred from the fixture's value):
##   mu        = b_fix                            # eta_fix = X_fix * b_fix, X_fix = model.matrix(~ 0 + trait)
##   sigma_eps = exp(log_sigma_eps)               # cpp:2103  Type sigma_eps = exp(log_sigma_eps);
##   Lambda    = matrix(theta_rr_B, n_t, K)       # cpp:902/909  lam_diag = theta_rr_B.head(rank); Lambda_B(j,j) = lam_diag(j)  -- NO exp()
##   psi       = exp(2 * theta_diag_B)            # cpp:1009/1018  sd_B = exp(theta_diag_B); dnorm(s_B, 0, sd_B)  -> exp() is an SD
##   z[l, k]   = z_B[k, l]                        # cpp:612  PARAMETER_MATRIX(z_B) is d_B x n_sites (column-major flatten)
##   q[l, t]   = s_B[t, l]                        # cpp:623  PARAMETER_MATRIX(s_B) is n_traits x n_sites (column-major flatten)

suppressPackageStartupMessages({
  library(jsonlite)
  library(rstan)
})
rstan_options(auto_write = TRUE)

pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-oracle"
here     <- file.path(pkg_root, "dev", "stan-oracle")
stopifnot(file.exists(file.path(pkg_root, "DESCRIPTION")))
devtools::load_all(pkg_root, quiet = TRUE)

n_traits <- 3L; n_unit <- 15L; K <- 1L
trait_names <- c("a", "b", "c")

## ---------------------------------------------------------------------------
## 0. Datasets.  Fixture A = exactly tmb-side.R's balanced data.
##    Fixture B = the same data made RAGGED (missing cells, uneven reps) to
##    exercise the per-row index maps t(i), l(i) rather than a balanced grid.
## ---------------------------------------------------------------------------
make_df <- function() {
  set.seed(20260803L)
  alpha_true <- c(0.5, -0.3, 0.2)
  Lambda_true <- matrix(c(0.8, 0.6, -0.4), nrow = n_traits, ncol = 1L)
  psi_true <- c(0.3, 0.25, 0.35)
  sigma_eps_true <- 0.2
  f_unit <- rnorm(n_unit)
  delta <- matrix(rnorm(n_unit * n_traits, sd = rep(psi_true, each = n_unit)),
                  n_unit, n_traits)
  eta <- outer(rep(1, n_unit), alpha_true) +
    outer(as.numeric(f_unit), as.numeric(Lambda_true)) + delta
  rows <- vector("list", n_unit * n_traits * 2L); k <- 1L
  for (u in seq_len(n_unit)) for (t in seq_len(n_traits)) for (r in 1:2) {
    rows[[k]] <- data.frame(unit = u, trait = trait_names[t],
                            value = eta[u, t] + rnorm(1, sd = sigma_eps_true))
    k <- k + 1L
  }
  df <- do.call(rbind, rows)
  df$trait <- factor(df$trait, levels = trait_names)
  df
}

df_A <- make_df()
stopifnot(nrow(df_A) == 90L)

## Ragged: cell (unit 3, trait "b") and (unit 11, trait "c") removed entirely;
## eight further cells reduced to a single replicate.
set.seed(99L)
key <- paste(df_A$unit, as.character(df_A$trait), sep = ":")
drop_cells <- c("3:b", "11:c")
rep_index  <- ave(seq_len(nrow(df_A)), key, FUN = seq_along)
thin_cells <- c("1:a", "2:c", "4:b", "6:a", "8:c", "9:b", "12:a", "14:b")
keep <- !(key %in% drop_cells) & !(key %in% thin_cells & rep_index == 2L)
df_B <- df_A[keep, , drop = FALSE]
rownames(df_B) <- NULL
stopifnot(nrow(df_B) == 90L - 4L - 8L)

## ---------------------------------------------------------------------------
## 1. TMB side: fit once per dataset only to get a valid data/param/map triple,
##    then rebuild the JOINT objective with random = NULL.
## ---------------------------------------------------------------------------
build_tmb <- function(df) {
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1) + unique(0 + trait | unit),
    data = df, unit = "unit", family = gaussian(),
    control = gllvmTMBcontrol(optArgs = list(control = list(iter.max = 30, eval.max = 40)))
  )))
  obj <- TMB::MakeADFun(data = fit$tmb_data, parameters = fit$tmb_params,
                        map = fit$tmb_map, random = NULL, DLL = "gllvmTMB",
                        silent = TRUE)
  list(fit = fit, obj = obj, nm = names(obj$par), df = df)
}

## Element-by-element alignment audit (failure mode 4).
audit <- function(tm) {
  d <- tm$fit$tmb_data; df <- tm$df
  X_ref <- model.matrix(~ 0 + trait, data = df)
  list(
    n_rows                 = nrow(df),
    theta_len              = length(tm$obj$par),
    block_counts           = as.list(table(tm$nm)[c("b_fix", "log_sigma_eps",
                                                    "theta_rr_B", "z_B",
                                                    "theta_diag_B", "s_B")]),
    X_fix_colnames         = colnames(d$X_fix),
    X_fix_is_trait_indicator = isTRUE(all.equal(unname(as.matrix(d$X_fix)),
                                                unname(X_ref), check.attributes = FALSE)),
    trait_id_matches_R     = identical(as.integer(d$trait_id),
                                       as.integer(match(as.character(df$trait), trait_names) - 1L)),
    site_id_matches_unit   = identical(as.integer(d$site_id), as.integer(df$unit) - 1L),
    n_sites                = as.integer(d$n_sites),
    n_traits               = as.integer(d$n_traits),
    d_B                    = as.integer(d$d_B),
    use_flags_on           = names(which(vapply(d[grep("^use_", names(d))],
                                                function(z) isTRUE(as.integer(z[1]) == 1L), logical(1)))),
    diag_B_skip            = as.integer(d$diag_B_skip),
    all_family_gaussian    = all(as.integer(d$family_id_vec) == 0L),
    all_link_identity      = all(as.integer(d$link_id_vec) == 0L),
    mapped_off_blocks      = names(tm$fit$tmb_map)
  )
}

tm_A <- build_tmb(df_A)
tm_B <- build_tmb(df_B)
aud_A <- audit(tm_A); aud_B <- audit(tm_B)
stopifnot("log_sigma_eps" %in% tm_A$nm, "log_sigma_eps" %in% tm_B$nm)

## ---------------------------------------------------------------------------
## 2. Parameter points.  P1 is the published fixture's theta (the ONLY point
##    stan-side.R used to pick its mapping).  P2..P5 are fresh and were never
##    used to select anything.  P3 deliberately puts a NEGATIVE value in the
##    leading "diagonal" slot of theta_rr_B, which an exp()-reading of that
##    slot could not distinguish from a positive one by magnitude alone.
## ---------------------------------------------------------------------------
theta_P1 <- list(
  b_fix = c(0.5, -0.3, 0.2),
  log_sigma_eps = log(0.25),
  theta_rr_B = c(0.8, 0.6, -0.4),
  z_B = c(1.097, -0.452, 0.291, 0.506, 0.323, -0.085, 1.209, -0.076, 1.615,
          -0.05, 1.044, 1.829, -1.111, -0.223, -0.107),
  theta_diag_B = log(c(0.3, 0.25, 0.35)),
  s_B = c(-0.011, -0.472, -0.146, 0.14, -0.271, -0.083, 0.116, -0.018, -0.206,
          -0.572, 0.541, -0.29, -0.106, 0.332, 0.17, 0.619, 0.441, -0.495, 0.061,
          -0.216, -0.048, 0.22, -0.109, -0.003, 0.175, -0.088, -0.418, -0.026,
          -0.206, -0.233, 0.523, 0.137, -0.035, 0.503, -0.348, -0.012, 0.327,
          0.454, 0.266, 0.094, 0.565, -0.124, -0.274, 0.165, -0.243)
)

set.seed(20260804L)
rand_theta <- function(rr, lse, dg) {
  list(b_fix = round(rnorm(n_traits, 0, 1.5), 4),
       log_sigma_eps = lse,
       theta_rr_B = rr,
       z_B = round(rnorm(n_unit), 4),
       theta_diag_B = dg,
       s_B = round(rnorm(n_unit * n_traits, 0, 0.6), 4))
}
theta_P2 <- rand_theta(rr = c(1.3, -0.75, 0.42), lse = log(0.9),
                       dg = log(c(0.7, 0.15, 1.2)))
theta_P3 <- rand_theta(rr = c(-1.6, 2.4, 0.05), lse = log(0.05),
                       dg = log(c(1.9, 0.4, 0.08)))   # NEGATIVE leading entry
theta_P4 <- rand_theta(rr = c(0.35, 0.9, -1.15), lse = log(0.6),
                       dg = log(c(0.22, 1.1, 0.6)))
theta_P5 <- rand_theta(rr = c(-0.2, -1.4, 0.8), lse = log(0.33),
                       dg = log(c(0.9, 0.55, 0.13)))

flatten_theta <- function(blocks, nm) {
  th <- numeric(length(nm))
  for (b in names(blocks)) th[nm == b] <- blocks[[b]]
  stopifnot(all(is.finite(th)))
  th
}

## ---------------------------------------------------------------------------
## 3. Transport: internal -> natural.  FIXED from src/, never re-selected.
## ---------------------------------------------------------------------------
transport <- function(blocks) {
  list(
    mu        = as.numeric(blocks$b_fix),
    Lambda    = matrix(as.numeric(blocks$theta_rr_B), nrow = n_traits, ncol = K),
    psi       = exp(2 * as.numeric(blocks$theta_diag_B)),
    sigma_eps = exp(as.numeric(blocks$log_sigma_eps)),
    z         = matrix(as.numeric(blocks$z_B), nrow = n_unit, ncol = K),
    q         = matrix(as.numeric(blocks$s_B), nrow = n_unit, ncol = n_traits,
                       byrow = TRUE)
  )
}

## ---------------------------------------------------------------------------
## 4. Pure-R implementation of model-spec.md sec.7.1 (arithmetic cross-check,
##    and the term/constant decomposition).
## ---------------------------------------------------------------------------
spec_lp <- function(p, y, tt, uu) {
  eta <- p$mu[tt] +
    rowSums(p$Lambda[tt, , drop = FALSE] * p$z[uu, , drop = FALSE]) +
    p$q[cbind(uu, tt)]
  D <- sum(dnorm(y, eta, p$sigma_eps, log = TRUE))
  Z <- sum(dnorm(as.vector(p$z), 0, 1, log = TRUE))
  Q <- sum(dnorm(as.vector(p$q), 0,
                 rep(sqrt(p$psi), each = nrow(p$q)), log = TRUE))
  n_terms <- length(y) + length(p$z) + length(p$q)
  list(total = D + Z + Q, D = D, Z = Z, Q = Q,
       n_density_terms = n_terms,
       constant_2pi = -0.5 * n_terms * log(2 * pi),
       total_without_2pi_constants = D + Z + Q + 0.5 * n_terms * log(2 * pi))
}

## ---------------------------------------------------------------------------
## 5. Stan side.  One compile; one shell per dataset.  adjust_transform = FALSE.
## ---------------------------------------------------------------------------
sm <- rstan::stan_model(file.path(here, "gllvm_ordinary.stan"))

make_shell <- function(df) {
  sd_list <- list(N = nrow(df), n_t = n_traits, n_u = n_unit, K = K,
                  tt = match(as.character(df$trait), trait_names),
                  uu = as.integer(df$unit), y = as.numeric(df$value))
  list(data = sd_list,
       fit0 = suppressMessages(rstan::sampling(sm, data = sd_list, chains = 0)))
}
sh_A <- make_shell(df_A); sh_B <- make_shell(df_B)

stan_lp <- function(shell, p, adjust = FALSE) {
  up <- rstan::unconstrain_pars(shell$fit0, p)
  as.numeric(rstan::log_prob(shell$fit0, up, adjust_transform = adjust,
                             gradient = FALSE))
}

## ---------------------------------------------------------------------------
## 6. Compare
## ---------------------------------------------------------------------------
compare <- function(label, tm, shell, blocks) {
  th   <- flatten_theta(blocks, tm$nm)
  nll  <- tm$obj$fn(th)                       # TMB: NEGATIVE log-density
  p    <- transport(blocks)
  stan <- stan_lp(shell, p, adjust = FALSE)   # Stan: LOG-density
  spec <- spec_lp(p, shell$data$y, shell$data$tt, shell$data$uu)
  jac  <- stan_lp(shell, p, adjust = TRUE) - stan
  list(point = label,
       tmb_nll = nll, tmb_log_density = -nll,
       stan_log_density = stan,
       r_spec_log_density = spec$total,
       abs_diff_stan_vs_tmb = abs(stan - (-nll)),
       rel_diff_stan_vs_tmb = abs(stan - (-nll)) / abs(nll),
       abs_diff_rspec_vs_tmb = abs(spec$total - (-nll)),
       terms = list(D = spec$D, Z = spec$Z, Q = spec$Q,
                    n_density_terms = spec$n_density_terms,
                    constant_2pi = spec$constant_2pi,
                    tmb_minus_constant_free = (-nll) - spec$total_without_2pi_constants),
       stan_jacobian_if_enabled = jac,
       jacobian_expected = sum(log(p$psi)) + log(p$sigma_eps))
}

res <- list(
  compare("A/P1 (published fixture theta)", tm_A, sh_A, theta_P1),
  compare("A/P2 (fresh)",                   tm_A, sh_A, theta_P2),
  compare("A/P3 (fresh; Lambda[1,1] < 0)",  tm_A, sh_A, theta_P3),
  compare("A/P4 (fresh)",                   tm_A, sh_A, theta_P4),
  compare("B/P1 (ragged data)",             tm_B, sh_B, theta_P1),
  compare("B/P5 (ragged data; fresh)",      tm_B, sh_B, theta_P5)
)

tab <- data.frame(
  point    = vapply(res, `[[`, "", "point"),
  tmb_nll  = vapply(res, `[[`, 0, "tmb_nll"),
  stan_lp  = vapply(res, `[[`, 0, "stan_log_density"),
  r_spec   = vapply(res, `[[`, 0, "r_spec_log_density"),
  abs_diff = vapply(res, `[[`, 0, "abs_diff_stan_vs_tmb"),
  rel_diff = vapply(res, `[[`, 0, "rel_diff_stan_vs_tmb"),
  stringsAsFactors = FALSE
)
cat("\n=== TMB vs Stan, fixed mapping, several points ===\n")
print(tab, row.names = FALSE, digits = 15)

## Exact (round-trippable) printing -- the JSON writer is NOT bitwise exact,
## so quote THESE figures, not the ones in the .json.
cat("\n--- exact (%.17g) ---\n")
for (r in res)
  cat(sprintf("%-32s tmb_nll=%.17g  stan_lp=%.17g  abs=%.3e  rel=%.3e\n",
              r$point, r$tmb_nll, r$stan_log_density,
              r$abs_diff_stan_vs_tmb, r$rel_diff_stan_vs_tmb))

## Difference-of-differences (model-spec.md sec.7.3): constant-free comparison.
dod <- function(i, j) {
  (res[[i]]$tmb_log_density - res[[j]]$tmb_log_density) -
    (res[[i]]$stan_log_density - res[[j]]$stan_log_density)
}
cat("\ndifference-of-differences (should be 0):\n")
cat(sprintf("  A/P2 - A/P1 : %.3e\n", dod(2, 1)))
cat(sprintf("  A/P3 - A/P1 : %.3e\n", dod(3, 1)))
cat(sprintf("  A/P4 - A/P2 : %.3e\n", dod(4, 2)))
cat(sprintf("  B/P5 - B/P1 : %.3e\n", dod(6, 5)))

cat("\nconstant accounting at A/P1 (TMB minus a constant-free target):\n")
k_gap <- res[[1]]$terms$tmb_minus_constant_free / (0.5 * log(2 * pi))
cat(sprintf("  n density terms = %d ; 0.5*log(2pi)*k gap => k = %.10f\n",
            res[[1]]$terms$n_density_terms, k_gap))

cat("\nJacobian check (Stan adjust_transform TRUE - FALSE vs sum(log psi)+log sigma_eps):\n")
for (r in res) cat(sprintf("  %-32s %.12f  vs  %.12f\n", r$point,
                           r$stan_jacobian_if_enabled, r$jacobian_expected))

out <- list(
  generated = as.character(Sys.time()),
  mapping_used = list(
    mu = "b_fix (identity)",
    sigma_eps = "exp(log_sigma_eps)",
    Lambda = "matrix(theta_rr_B, n_t, K) -- IDENTITY, no exp on the leading diagonal",
    psi = "exp(2 * theta_diag_B) -- exp(theta_diag_B) is an SD",
    z = "z[l,k] = z_B[k,l] (d_B x n_sites, column-major)",
    q = "q[l,t] = s_B[t,l] (n_traits x n_sites, column-major)",
    how = "READ OFF src/gllvmTMB.cpp; fixed before any comparison; identical for all points"
  ),
  audit_balanced = aud_A,
  audit_ragged   = aud_B,
  points = res,
  difference_of_differences = list(`A/P2-A/P1` = dod(2, 1), `A/P3-A/P1` = dod(3, 1),
                                   `A/P4-A/P2` = dod(4, 2), `B/P5-B/P1` = dod(6, 5)),
  theta_points = list(P1 = theta_P1, P2 = theta_P2, P3 = theta_P3,
                      P4 = theta_P4, P5 = theta_P5),
  ragged_dropped_cells = drop_cells, ragged_thinned_cells = thin_cells
)
writeLines(jsonlite::toJSON(out, auto_unbox = TRUE, digits = NA, pretty = TRUE),
           file.path(here, "gauss-reconcile.json"))
cat("\nwrote ", file.path(here, "gauss-reconcile.json"), "\n", sep = "")

cat("\n=== alignment audit (balanced) ===\n"); str(aud_A)
cat("\n=== alignment audit (ragged) ===\n");   str(aud_B)
