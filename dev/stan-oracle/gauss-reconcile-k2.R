#!/usr/bin/env Rscript
## gauss-reconcile-k2.R -- Gauss: the K >= 2 case.
##
## stan-side.md sec.7 lists "K = 1 only" as its first residual limitation: with
## rank 1 the loadings PACKING order and the z_B layout are never exercised,
## and neither are the triangular zeros of the rotation convention.  This
## script closes that gap with T = 4 traits, K = 2, n_u = 12 units, 2 reps.
##
## The Stan MODEL is untouched (it takes a plain T x K matrix).  Only the
## DRIVER-side transport gains the packing, read off src/gllvmTMB.cpp:902-911:
##
##   lam_diag  = theta_rr_B.head(rank)
##   lam_lower = theta_rr_B.tail(nt - rank)
##   Lambda(i,j) = 0                                      if j > i
##               = lam_diag(j)                            if i == j
##               = lam_lower(j*p - (j+1)*j/2 + i - 1 - j) otherwise      [0-indexed]
##
## and z_B is PARAMETER_MATRIX(z_B), d_B x n_sites, so the flattened order is
## axis-fastest within unit:  z[l, k] = z_B_matrix[k, l].

suppressPackageStartupMessages({ library(jsonlite); library(rstan) })
rstan_options(auto_write = TRUE)

pkg_root <- "/Users/z3437171/local-scratch/worktrees/stan-oracle"
here     <- file.path(pkg_root, "dev", "stan-oracle")
devtools::load_all(pkg_root, quiet = TRUE)

n_traits <- 4L; n_unit <- 12L; K <- 2L
trait_names <- c("a", "b", "c", "d")

## ---- data -----------------------------------------------------------------
set.seed(4242L)
Lam_true <- matrix(c(1.0, 0.7, -0.5, 0.3,
                     0.0, 0.9,  0.4, -0.6), nrow = n_traits, ncol = K)
psi_true <- c(0.30, 0.25, 0.35, 0.20)
f <- matrix(rnorm(n_unit * K), n_unit, K)
delta <- matrix(rnorm(n_unit * n_traits, sd = rep(psi_true, each = n_unit)),
                n_unit, n_traits)
eta <- outer(rep(1, n_unit), c(0.5, -0.3, 0.2, 0.1)) + f %*% t(Lam_true) + delta
rows <- list(); k <- 1L
for (u in seq_len(n_unit)) for (t in seq_len(n_traits)) for (r in 1:2) {
  rows[[k]] <- data.frame(unit = u, trait = trait_names[t],
                          value = eta[u, t] + rnorm(1, sd = 0.2)); k <- k + 1L
}
df <- do.call(rbind, rows)
df$trait <- factor(df$trait, levels = trait_names)

## ---- TMB joint objective --------------------------------------------------
fit <- suppressWarnings(suppressMessages(gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = 2) + unique(0 + trait | unit),
  data = df, unit = "unit", family = gaussian(),
  control = gllvmTMBcontrol(optArgs = list(control = list(iter.max = 20, eval.max = 30)))
)))
obj <- TMB::MakeADFun(data = fit$tmb_data, parameters = fit$tmb_params,
                      map = fit$tmb_map, random = NULL, DLL = "gllvmTMB",
                      silent = TRUE)
nm <- names(obj$par)
nt_rr <- n_traits * K - K * (K - 1L) / 2L         # 7
stopifnot(sum(nm == "theta_rr_B") == nt_rr,
          sum(nm == "z_B") == n_unit * K,
          sum(nm == "s_B") == n_unit * n_traits,
          "log_sigma_eps" %in% nm)

## ---- transport (src-derived; identical rules as K = 1, plus the packing) ---
unpack_lambda <- function(th, p, rank) {
  lam_diag <- th[seq_len(rank)]
  lam_lower <- th[(rank + 1L):length(th)]
  L <- matrix(0, p, rank)
  for (j in seq_len(rank) - 1L) for (i in seq_len(p) - 1L) {
    if (j > i) next
    else if (i == j) L[i + 1L, j + 1L] <- lam_diag[j + 1L]
    else L[i + 1L, j + 1L] <- lam_lower[j * p - (j + 1L) * j / 2L + i - 1L - j + 1L]
  }
  L
}
transport <- function(b) list(
  mu        = as.numeric(b$b_fix),
  Lambda    = unpack_lambda(as.numeric(b$theta_rr_B), n_traits, K),
  psi       = exp(2 * as.numeric(b$theta_diag_B)),
  sigma_eps = exp(as.numeric(b$log_sigma_eps)),
  z         = t(matrix(as.numeric(b$z_B), nrow = K,        ncol = n_unit)),
  q         = t(matrix(as.numeric(b$s_B), nrow = n_traits, ncol = n_unit))
)

## ---- parameter points -----------------------------------------------------
set.seed(20260805L)
mk <- function(rr, lse, dg) list(
  b_fix = round(rnorm(n_traits, 0, 1.2), 4), log_sigma_eps = lse,
  theta_rr_B = rr, z_B = round(rnorm(n_unit * K), 4), theta_diag_B = dg,
  s_B = round(rnorm(n_unit * n_traits, 0, 0.6), 4))
## lam_diag = first 2 entries; lam_lower = remaining 5 = (L21,L31,L41,L32,L42)
P <- list(
  Q1 = mk(c( 1.1, 0.85, 0.7, -0.5, 0.3, 0.4, -0.6), log(0.30), log(c(0.30, 0.25, 0.35, 0.20))),
  Q2 = mk(c(-0.9, 1.60, -1.2, 0.25, 1.05, -0.35, 0.8), log(0.75), log(c(0.9, 0.12, 0.5, 1.4))),
  Q3 = mk(c( 0.4, -0.7, 2.0, -1.5, 0.05, 0.95, -0.2), log(0.12), log(c(0.15, 0.8, 1.1, 0.33)))
)

flat <- function(b) { th <- numeric(length(nm))
  for (n_ in names(b)) th[nm == n_] <- b[[n_]]; th }

## ---- Stan -----------------------------------------------------------------
sm <- rstan::stan_model(file.path(here, "gllvm_ordinary.stan"))
sd_list <- list(N = nrow(df), n_t = n_traits, n_u = n_unit, K = K,
                tt = match(as.character(df$trait), trait_names),
                uu = as.integer(df$unit), y = as.numeric(df$value))
fit0 <- suppressMessages(rstan::sampling(sm, data = sd_list, chains = 0))

res <- lapply(names(P), function(lab) {
  b <- P[[lab]]
  nll <- obj$fn(flat(b))
  p <- transport(b)
  lp <- as.numeric(rstan::log_prob(fit0, rstan::unconstrain_pars(fit0, p),
                                   adjust_transform = FALSE, gradient = FALSE))
  ## the same value with the Lambda TRANSPOSE-ish error, to show the point is
  ## discriminating and not accidentally invariant
  p_bad <- p; p_bad$Lambda[1, 2] <- p_bad$Lambda[2, 1]   # break the triangular zero
  lp_bad <- as.numeric(rstan::log_prob(fit0, rstan::unconstrain_pars(fit0, p_bad),
                                       adjust_transform = FALSE, gradient = FALSE))
  list(point = lab, tmb_nll = nll, stan_log_density = lp,
       abs_diff = abs(lp - (-nll)), rel_diff = abs(lp - (-nll)) / abs(nll),
       stan_with_broken_triangular_zero = lp_bad,
       shift_if_zero_broken = lp_bad - lp,
       Lambda = p$Lambda)
})

tab <- data.frame(point = vapply(res, `[[`, "", "point"),
                  tmb_nll = vapply(res, `[[`, 0, "tmb_nll"),
                  stan_lp = vapply(res, `[[`, 0, "stan_log_density"),
                  abs_diff = vapply(res, `[[`, 0, "abs_diff"),
                  rel_diff = vapply(res, `[[`, 0, "rel_diff"),
                  shift_if_zero_broken = vapply(res, `[[`, 0, "shift_if_zero_broken"))
cat("\n=== K = 2, T = 4, n_u = 12, N = ", nrow(df), " ===\n", sep = "")
print(tab, row.names = FALSE, digits = 15)
cat("\n--- exact (%.17g) ---\n")
for (r in res)
  cat(sprintf("%-4s tmb_nll=%.17g  stan_lp=%.17g  abs=%.3e  rel=%.3e\n",
              r$point, r$tmb_nll, r$stan_log_density, r$abs_diff, r$rel_diff))
cat("\nLambda at Q1 (unpacked from theta_rr_B by the src packing rule):\n")
print(res[[1]]$Lambda)

writeLines(jsonlite::toJSON(list(dims = sd_list[c("N", "n_t", "n_u", "K")],
                                 points = res, theta_points = P),
                            auto_unbox = TRUE, digits = NA, pretty = TRUE),
           file.path(here, "gauss-reconcile-k2.json"))
cat("\nwrote ", file.path(here, "gauss-reconcile-k2.json"), "\n", sep = "")
