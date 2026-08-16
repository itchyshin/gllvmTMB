## Design 121 pre-run test (D-139): 2 seeds x 8 cells x 3 primary arms = 48 fits.
##
## Cells: family in {binomial, ordinal_probit} x T in {4, 8} traits x
##        n in {100, 200} sites.
## Arms:  A = Laplace-ML (defaults)
##        B = Laplace + Cox-Reid (REML = TRUE, allow_nongaussian_reml = TRUE)
##        C = AGHQ-ML (aghq = 7)
## Ridge pinned OFF in every arm: aghq_ridge = Inf explicit in every control.
## CORRECTION vs the task brief and Design 121 Section 2's own text (both say
## "aghq_ridge = 0"): the package's live validator
## (.gllvmTMB_normalize_aghq_ridge, R/aghq-auto-ridge.R:8-20) requires a
## POSITIVE number, Inf, or "auto" -- 0 is rejected outright (confirmed by
## the smoke test's first failed attempt). Inf is the package's actual
## "ridge off" sentinel and is exactly what
## tests/testthat/helper-aghq-golden.R's `.golden_aghq_control()` uses to run
## quadrature unpenalised. Inf is used throughout below instead of 0.
##
## Formula and DGP conventions matched to existing package usage rather than
## invented fresh, per the task brief:
##   - dev/aghq-evidence/06-three-arm.R establishes the estimand convention:
##     ratio = norm(Lambda_hat, "F") / norm(Lambda_true, "F").
##   - tests/testthat/helper-aghq-golden.R's `.golden_formula_q1`:
##       y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
##     is the exact loadings-only ordinary-latent() pattern used across the
##     AGHQ test suite. unique = FALSE (loadings only, no diagonal Psi) is used
##     here rather than the task text's literal `latent(0 + trait | site, d = 1)`
##     (which would default to unique = TRUE per the package's Psi-by-default
##     rule) because the DGP below has no idiosyncratic per-trait noise beyond
##     the response family's own -- fitting a Psi the DGP does not contain
##     invites Heywood cases unrelated to the Cox-Reid question this pre-run
##     is testing. This deviation is noted here and in RESULTS.md.
##   - tests/testthat/test-ordinal-probit.R gives the ordinal_probit() call
##     shape and Wright/Falconer/Hadfield threshold DGP (y* = eta + N(0,1),
##     tau_1 = 0 fixed).
##   - REML is a top-level gllvmTMB() argument, not a gllvmTMBcontrol() field
##     (R/gllvmTMB.R:526); allow_nongaussian_reml and aghq/aghq_ridge live in
##     gllvmTMBcontrol().

devtools::load_all("/private/tmp/gllvmtmb-doc-lane-20260816", quiet = TRUE)

set.seed(1)

## ---------------------------------------------------------------------------
## DGP
## ---------------------------------------------------------------------------

## Simulate one dataset: n sites, T traits, one latent axis.
##   u_i ~ N(0, 1)                              (site latent score)
##   eta_ti = beta0_t + lambda_t * u_i           (t = 1..T, i = 1..n)
## binomial:       y_ti ~ Bernoulli(plogis(eta_ti))
## ordinal_probit: y*_ti = eta_ti + N(0, 1); y_ti = 1 + sum(y*_ti > tau_k)
##                 tau = c(0, 0.8, 1.6)  (Hadfield convention, tau_1 = 0 fixed)
simulate_cell <- function(family, Tn, n, seed) {
  set.seed(seed)
  beta0 <- seq(-0.5, 0.5, length.out = Tn)
  lambda_true <- seq(0.6, 1.4, length.out = Tn)
  u <- rnorm(n)
  eta <- outer(u, lambda_true) + matrix(beta0, n, Tn, byrow = TRUE) # n x T

  if (family == "binomial") {
    y <- matrix(rbinom(n * Tn, size = 1, prob = plogis(eta)), n, Tn)
  } else if (family == "ordinal_probit") {
    tau <- c(0, 0.8, 1.6)
    ystar <- eta + matrix(rnorm(n * Tn), n, Tn)
    y <- matrix(1L, n, Tn)
    for (k in tau) y <- y + (ystar > k) * 1L
    storage.mode(y) <- "integer"
  } else {
    stop("unknown family: ", family)
  }

  trait_names <- paste0("t", seq_len(Tn))
  df <- data.frame(
    site  = factor(rep(seq_len(n), each = Tn)),
    trait = factor(rep(trait_names, n), levels = trait_names),
    value = as.vector(t(y))
  )
  list(df = df, lambda_true = lambda_true)
}

## ---------------------------------------------------------------------------
## Fit one arm on one dataset
## ---------------------------------------------------------------------------

fit_arm <- function(df, family, arm) {
  fam_obj <- switch(family,
    binomial       = binomial(),
    ordinal_probit = ordinal_probit()
  )
  form <- value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)

  ctrl_args <- list(aghq_ridge = Inf)
  reml <- FALSE
  if (arm == "A") {
    ## defaults, ridge off
  } else if (arm == "B") {
    reml <- TRUE
    ctrl_args$allow_nongaussian_reml <- TRUE
  } else if (arm == "C") {
    ctrl_args$aghq <- 7
  } else {
    stop("unknown arm: ", arm)
  }
  ctrl <- do.call(gllvmTMBcontrol, ctrl_args)

  t0 <- Sys.time()
  cond <- list(warning = NULL, error = NULL)
  fit <- withCallingHandlers(
    tryCatch(
      gllvmTMB(
        form,
        data    = df,
        unit    = "site",
        family  = fam_obj,
        REML    = reml,
        control = ctrl
      ),
      error = function(e) {
        cond$error <<- conditionMessage(e)
        NULL
      }
    ),
    warning = function(w) {
      cond$warning <<- paste(unique(c(cond$warning, conditionMessage(w))), collapse = " | ")
      invokeRestart("muffleWarning")
    }
  )
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  list(fit = fit, wall = wall, warning = cond$warning, error = cond$error)
}

norm_ratio_from_fit <- function(fit, lambda_true) {
  Lambda_hat <- tryCatch(extract_loadings(fit, level = "unit"), error = function(e) NULL)
  if (is.null(Lambda_hat)) return(NA_real_)
  norm(as.matrix(Lambda_hat), "F") / norm(matrix(lambda_true, ncol = 1), "F")
}

converged_flag <- function(fit) {
  if (is.null(fit)) return(FALSE)
  conv <- isTRUE(fit$opt$convergence == 0L)
  pdh <- if (!is.null(fit$sd_report$pdHess)) isTRUE(fit$sd_report$pdHess) else TRUE
  isTRUE(conv) && isTRUE(pdh)
}

run_one <- function(family, Tn, n, arm, seed) {
  sim <- simulate_cell(family, Tn, n, seed)
  res <- fit_arm(sim$df, family, arm)
  ratio <- if (is.null(res$fit)) NA_real_ else norm_ratio_from_fit(res$fit, sim$lambda_true)
  conv <- converged_flag(res$fit)
  data.frame(
    family = family, T = Tn, n = n, arm = arm, seed = seed,
    converged = conv, wall_time_s = res$wall, norm_ratio = ratio,
    bias_pct = if (is.na(ratio)) NA_real_ else 100 * (ratio - 1),
    warning = if (is.null(res$warning)) "" else res$warning,
    error = if (is.null(res$error)) "" else res$error,
    stringsAsFactors = FALSE
  )
}

## ---------------------------------------------------------------------------
## Smoke test (D-139): ONE fit before the full 48.
## ---------------------------------------------------------------------------

cat("=== SMOKE TEST: binomial, T=4, n=100, arm A, seed 1 ===\n")
smoke_t0 <- Sys.time()
smoke_row <- run_one("binomial", 4L, 100L, "A", 1L)
smoke_wall <- as.numeric(difftime(Sys.time(), smoke_t0, units = "secs"))
print(smoke_row)
cat(sprintf("Smoke wall time: %.2f s\n", smoke_wall))

if (!is.finite(smoke_row$norm_ratio)) {
  stop("SMOKE FAILED: norm_ratio is not finite. STOPPING per D-139 -- see printed row above.")
}

cat("Smoke passed: norm_ratio is finite. Proceeding to full 48-fit grid.\n\n")

## ---------------------------------------------------------------------------
## Full grid: 2 seeds x 8 cells x 3 arms = 48 fits
## ---------------------------------------------------------------------------

grid <- expand.grid(
  family = c("binomial", "ordinal_probit"),
  T      = c(4L, 8L),
  n      = c(100L, 200L),
  arm    = c("A", "B", "C"),
  seed   = c(1L, 2L),
  stringsAsFactors = FALSE
)

## Re-use the smoke fit's row instead of refitting it.
smoke_key <- with(smoke_row, paste(family, T, n, arm, seed))
grid_key  <- with(grid, paste(family, T, n, arm, seed))

results <- vector("list", nrow(grid))
run_t0 <- Sys.time()
for (i in seq_len(nrow(grid))) {
  g <- grid[i, ]
  key <- grid_key[i]
  if (key == smoke_key) {
    results[[i]] <- smoke_row
  } else {
    results[[i]] <- run_one(g$family, g$T, g$n, g$arm, g$seed)
  }
  cat(sprintf(
    "[%2d/%2d] %s T=%d n=%d arm=%s seed=%d -> converged=%s ratio=%.4f wall=%.1fs\n",
    i, nrow(grid), g$family, g$T, g$n, g$arm, g$seed,
    results[[i]]$converged, results[[i]]$norm_ratio, results[[i]]$wall_time_s
  ))
  ## Incremental write, in case of a kill mid-run.
  out <- do.call(rbind, results[seq_len(i)])
  write.csv(out, "/private/tmp/gllvmtmb-doc-lane-20260816/dev/coxreid-prerun/prerun-results.csv",
            row.names = FALSE)

  elapsed_min <- as.numeric(difftime(Sys.time(), run_t0, units = "mins"))
  if (elapsed_min > 25) {
    cat(sprintf("\n*** STOPPING EARLY: elapsed %.1f min exceeds 25 min budget after %d/%d rows. ***\n",
                elapsed_min, i, nrow(grid)))
    break
  }
}

total_wall <- as.numeric(difftime(Sys.time(), run_t0, units = "secs"))
cat(sprintf("\n=== TOTAL WALL TIME (full grid loop): %.1f s (%.2f min) ===\n",
            total_wall, total_wall / 60))

final <- do.call(rbind, results[!vapply(results, is.null, logical(1))])
write.csv(final, "/private/tmp/gllvmtmb-doc-lane-20260816/dev/coxreid-prerun/prerun-results.csv",
          row.names = FALSE)
cat(sprintf("Rows completed: %d / %d\n", nrow(final), nrow(grid)))
saveRDS(list(final = final, smoke_wall = smoke_wall, total_wall = total_wall),
        "/private/tmp/gllvmtmb-doc-lane-20260816/dev/coxreid-prerun/prerun-state.rds")
