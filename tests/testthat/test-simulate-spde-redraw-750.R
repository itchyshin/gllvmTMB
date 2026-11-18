## #750: unconditional redraw of the SPDE spatial tiers in simulate().
##
## `spatial_indep()` / `spatial_scalar()` (one GMRF field per trait) and
## `spatial_latent()` (K shared fields mapped through Lambda_spde, optionally
## plus a per-trait unique field) used to fall back to CONDITIONAL simulation:
## the fitted field was reused, so simulate-based intervals collapsed.
## Oracle: the marginal variance of a redrawn response is
##   Var(y_o) = sum_k L(t,k)^2 * (A Q^-1 A')_oo [+ tau_t^-2 (A Q^-1 A')_oo]
##              + sigma_eps^2,
## with Q = kappa^4 M0 + 2 kappa^2 M1 + M2, which a conditional draw cannot hit.

skip_on_cran()

.spde750_fixture <- function(n_site = 40L, n_trait = 3L) {
  set.seed(750)
  lon <- stats::runif(n_site)
  lat <- stats::runif(n_site)
  df <- expand.grid(site = seq_len(n_site), trait_id = seq_len(n_trait),
                    KEEP.OUT.ATTRS = FALSE)
  df$trait <- factor(paste0("t", df$trait_id))
  df$lon <- lon[df$site]
  df$lat <- lat[df$site]
  df$value <- 0.5 * df$trait_id +
    0.7 * (sin(3 * df$lon + df$trait_id) + cos(2 * df$lat)) +
    stats::rnorm(nrow(df), sd = 0.3)
  list(data = df, mesh = make_mesh(df, c("lon", "lat"), cutoff = 0.15))
}

.spde750_fit <- function(fx, term) {
  suppressMessages(suppressWarnings(gllvmTMB(
    stats::as.formula(paste("value ~ 0 + trait +", term)),
    data = fx$data, mesh = fx$mesh, silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

## Mean over rows of the oracle marginal variance of y.
.spde750_oracle_var <- function(fit) {
  td <- fit$tmb_data
  kappa <- as.numeric(fit$report$kappa)
  Q <- kappa^4 * as.matrix(td$spde_M0) + 2 * kappa^2 * as.matrix(td$spde_M1) +
    as.matrix(td$spde_M2)
  A <- as.matrix(td$A_proj)
  base <- rowSums((A %*% solve(Q)) * A)        # (A Q^-1 A')_oo
  trait <- td$trait_id + 1L
  v <- numeric(length(base))
  if (as.integer(td$spde_lv_k) >= 1L) {
    L <- fit$report$Lambda_spde
    v <- v + rowSums(L[trait, , drop = FALSE]^2) * base
  }
  if (as.integer(td$spde_lv_k) == 0L || as.integer(td$spde_lv_unique) == 1L) {
    tau <- exp(as.numeric(fit$tmb_obj$env$parList(fit$opt$par)$log_tau_spde))
    v <- v + base / tau[trait]^2
  }
  mean(v) + gllvmTMB:::.gllvmTMB_sigma_eps(fit)^2
}

.spde750_check <- function(term, nsim = 1500L) {
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")
  fit <- .spde750_fit(.spde750_fixture(), term)
  expect_true(gllvmTMB:::.check_simulate_unconditional(fit)$can_redraw)
  ## No fallback warning: the tier is redrawn, not reused.
  expect_no_warning(y <- simulate(fit, nsim = nsim, seed = 1L))
  expect_equal(dim(y), c(nrow(fit$data), nsim))
  oracle <- .spde750_oracle_var(fit)
  emp <- mean(apply(y, 1L, stats::var))
  expect_equal(emp, oracle, tolerance = 0.1)
  ## A conditional draw only carries the residual noise, far below the oracle.
  y_cond <- simulate(fit, nsim = 200L, seed = 1L, condition_on_RE = TRUE)
  expect_lt(mean(apply(y_cond, 1L, stats::var)), 0.8 * oracle)
  invisible(fit)
}

test_that("simulate() redraws the per-trait SPDE field of spatial_indep() (#750)", {
  .spde750_check("spatial_indep(0 + trait | coords)")
})

test_that("simulate() redraws the shared SPDE field of spatial_scalar() (#750)", {
  .spde750_check("spatial_scalar(0 + trait | coords)")
})

test_that("simulate() redraws the low-rank SPDE fields of spatial_latent() (#750)", {
  .spde750_check("spatial_latent(0 + trait | coords, d = 1)")
})

test_that("slope-augmented SPDE fits are still not claimed redrawable (#750)", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("fmesher")
  fx <- .spde750_fixture()
  fx$data$x <- stats::rnorm(nrow(fx$data))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + spatial_indep(1 + x | coords),
    data = fx$data, mesh = fx$mesh, silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_identical(as.integer(fit$tmb_data$use_spde_slope), 1L)
  ok <- gllvmTMB:::.check_simulate_unconditional(fit)
  expect_false(ok$can_redraw)
})
