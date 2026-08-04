## Extend the VA->LA warm start (script 33) to also seed the RANDOM-EFFECT
## MODES (z_B), using VA's variational means `m` as the starting latent
## scores, and PROVE the seed is actually consumed by TMB rather than
## silently discarded.
##
## Builds directly on dev/va-speed/33-va-warmstart-la.R -- same monkeypatch
## strategy (swap `.vgh_build_warm_start`'s SOURCE only, restored on.exit),
## same matched model (binomial-probit, single B-tier, unique = FALSE), same
## "never trust a start without checking it landed" discipline. This script
## does NOT re-run the 33 timing campaign; it is the mode-seeding extension
## plus its own local correctness smoke, per the task brief.
##
## ---------------------------------------------------------------------------
## STEP 2 FINDING: the shipped engine DOES admit random-effect (z_B) starts.
##
## `control$vgh_warm_start_z = TRUE` is a real, wired, already-shipped path
## (R/fit-multi.R:4253-4321): when set, `tmb_params$z_B <- vgh_start$z` runs
## BEFORE `TMB::MakeADFun()` (R/fit-multi.R:5113), i.e. before the parameter
## list that fixes TMB's Laplace inner-solve starting values is frozen. So
## unlike the AC->GH route (which had no counterpart at all for some
## coordinates), z_B seeding is not a first-class blocker here -- it exists,
## it is reachable via the same monkeypatch used in script 33, and VGH's own
## measurement already found it *harmful* for VGH's coarse intercept-only
## internal solve (0.39x vs 4.43x, R/fit-multi.R:4279-4284). That prior
## finding is about VGH's source, not about z_B-seeding as a mechanism -- this
## script re-tests the mechanism with a materially better source (VA's own
## variational means for THIS exact model, not an intercept-only proxy).
##
## Shape/orientation, verified by direct code inspection (not assumed):
##   * shipped `z_B` is PARAMETER_MATRIX(z_B), d_B x n_sites
##     (src/gllvmTMB.cpp:667; tmb_params$z_B built as
##     matrix(0, nrow = max(d_B,1), ncol = n_sites), R/fit-multi.R:3884).
##   * VA's `m` is a flat, tier-major vector of length N*q. The TMB template
##     itself documents the reshape used everywhere downstream:
##     `m(g,c) = m_flat(m_offset[0] + c*N + g)` (inst/tmb/gllvmTMB_va_r3.cpp
##     :969-974) -- i.e. column-major N x q, unit-major. R's
##     `matrix(m_flat, N, q)` reproduces that exactly (R matrix() fills
##     column-major), so `t(matrix(m_flat, N, q))` gives the q x N orientation
##     z_B wants.
##   * site/unit ordering: shipped `site_id <- as.integer(data[[site]]) - 1L`
##     (R/fit-multi.R:2259) is 0-indexed factor-level order of `data[[unit]]`.
##     VA's `unit_id` in this driver is `as.integer(b$d$unit)`, 1-indexed
##     levels of the SAME factor built the SAME way in `mk()`. Same factor,
##     same level order => same unit-to-index map on both sides for this
##     script's DGP. (This is a property of how `mk()` builds `d$unit` as
##     `factor(rep(seq_len(N), times = T0))`, not a general engine guarantee
##     re-verified for arbitrary factor orderings.)
##   * `d_B` (shipped rank) == `q` (VA rank) == Q0 for this matched cell, so
##     no dimension mismatch is possible here; the script still asserts it.
##
## So: implemented = TRUE. The blocker the recon flagged as unresolved (the
## m-to-z_B orientation/ordering question, recon Sec 2 "m" row and Sec 4
## obstacle 2) is resolved by direct inspection above, not by assumption.
## ---------------------------------------------------------------------------
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

NTR <- 6L; T0 <- 20L; Q0 <- 2L
rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))

mk <- function(seed, N) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q0, 0, 0.8), T0, Q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q0), N, Q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  d <- data.frame(y = y, succ = y, fail = NTR - y,
                  unit = factor(rep(seq_len(N), times = T0)),
                  trait = factor(rep(seq_len(T0), each = N)))
  list(d = d, X = unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0)))),
       Sigma_true = lam %*% t(lam), N = N)
}

run_va <- function(b) gllvmTMB:::.va_r3_fit(
  y = b$d$y, n_trials = rep(NTR, nrow(b$d)), X = b$X,
  unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait), q = Q0,
  family = "binomial_probit", link = "probit",
  unique = FALSE, n_starts = 1L, H = 15L, eval_method = "ac",
  collapse_variational_cov = TRUE,
  control = list(eval.max = 800L, iter.max = 400L))

run_la_formula <- cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q0, unique = FALSE)
run_la_cold <- function(b) gllvmTMB::gllvmTMB(
  run_la_formula, data = b$d, family = binomial(link = "probit"), unit = "unit")

score_Sigma <- function(S, b) {
  rf <- rel_frob(S, b$Sigma_true)
  list(rf = rf, trace_hat = sum(diag(S)), trace_true = sum(diag(b$Sigma_true)))
}
score_la <- function(f, b) {
  out <- tryCatch(gllvmTMB::extract_Sigma(f, level = "unit", part = "total",
                                          link_residual = "none"),
                  error = function(e) NULL)
  if (is.null(out) || is.null(out$Sigma)) return(list(rf = NA_real_, trace_hat = NA_real_))
  S <- as.matrix(out$Sigma)
  if (!identical(dim(S), dim(b$Sigma_true))) return(list(rf = NA_real_, trace_hat = NA_real_))
  score_Sigma(S, b)
}

## ---------------------------------------------------------------------------
## Monkeypatch (identical strategy to script 33): swap `.vgh_build_warm_start`'s
## SOURCE for a VA-derived seed, restored via on.exit even on error.
ns <- asNamespace("gllvmTMB")
orig_vgh_build <- get(".vgh_build_warm_start", envir = ns)
va_seed_holder <- new.env()

mock_vgh_build_warm_start <- function(tmb_data, family_name, maxit = 3L, verbose = FALSE) {
  va_seed_holder$seed
}
patch_on <- function() {
  unlockBinding(".vgh_build_warm_start", ns)
  assign(".vgh_build_warm_start", mock_vgh_build_warm_start, envir = ns)
  lockBinding(".vgh_build_warm_start", ns)
}
patch_off <- function() {
  unlockBinding(".vgh_build_warm_start", ns)
  assign(".vgh_build_warm_start", orig_vgh_build, envir = ns)
  lockBinding(".vgh_build_warm_start", ns)
}

## VA-derived seed, now including the reshaped/transposed random-effect mode
## seed `z` alongside `theta_rr` (loadings) and `b_fix` (fixed effects).
## `log_sd_tier` stays dropped (RESET, not transferred) per the AC->GH scar
## tissue -- this matched cell has no active coordinate there (see script 33).
va_derived_seed <- function(fva, b) {
  nm <- names(fva$best$par)
  beta <- unname(fva$best$par[nm == "beta"])
  theta_rr <- unname(fva$best$par[nm == "theta_rr"])
  log_sd_tier <- unname(fva$best$par[nm == "log_sd_tier"])
  m_flat <- unname(fva$best$par[nm == "m"])
  N <- b$N
  stopifnot(length(m_flat) == N * Q0)
  z_seed <- t(matrix(m_flat, nrow = N, ncol = Q0))  ## -> d_B x n_sites = Q0 x N
  stopifnot(identical(dim(z_seed), c(Q0, N)))
  if (length(log_sd_tier) > 0L) {
    cat(sprintf("  [reset] VA log_sd_tier has length %d -- dropped, not transferred.\n", length(log_sd_tier)))
  } else {
    cat("  [reset] no active log-scale variance tier in this matched cell -- nothing to reset.\n")
  }
  cat(sprintf("  [mode-seed] z_B seed built: dim %s, from VA `m` (unit-major, N=%d,q=%d), transposed to (d_B, n_sites).\n",
              paste(dim(z_seed), collapse = " x "), N, Q0))
  list(theta_rr = theta_rr, b_fix = beta, z = z_seed, vgh_seconds = NA_real_, vgh_elbo = NA_real_)
}

run_hybrid_mode_seeded <- function(b, seed_z = TRUE) {
  fva <- run_va(b)
  seed <- va_derived_seed(fva, b)
  va_seed_holder$seed <- seed
  control <- gllvmTMB::gllvmTMBcontrol()
  control$vgh_warm_start <- TRUE
  control$vgh_warm_start_fixed <- TRUE
  control$vgh_warm_start_z <- seed_z    ## the extension under test: TRUE seeds z_B from VA's m
  fla <- gllvmTMB::gllvmTMB(run_la_formula, data = b$d, family = binomial(link = "probit"),
                            unit = "unit", control = control)
  list(fit = fla, fva = fva, seed = seed)
}

## ---------------------------------------------------------------------------
## STEP 3: verify the seed is actually used, two independent ways.
##
## (a) The package's own landed-check: `.vgh_assert_start_landed()` runs
##     inside `gllvmTMB()` BEFORE MakeADFun and hard-stops if
##     `tmb_params$z_B` does not equal the supplied seed bit-for-bit
##     (R/fit-multi.R:4308, R/vgh-warmstart.R:143-170). If `run_hybrid_
##     mode_seeded()` returns without error and
##     `fit$start_provenance$vgh_warm_start_z` is TRUE, that check passed.
##     This proves the seed reached the R-side parameter LIST.
##
## (b) STRONGER: trace `TMB::MakeADFun` itself and capture the actual
##     `parameters` argument passed to it -- the literal object TMB uses to
##     fix the Laplace inner-solve starting values, one call further downstream
##     than (a). This proves the seed reached the ADFun boundary, not just an
##     R list that could in principle have been overwritten or ignored between
##     the assignment and MakeADFun().
verify_seed_reaches_tmb <- function(b) {
  ## The tracer expression is evaluated in MakeADFun's own call frame (that is
  ## how base::trace works), so it cannot see a local `capture` via lexical
  ## scoping. Use a fixed name in .GlobalEnv instead -- ugly but reliable, and
  ## scoped to this verification call only (removed in on.exit below).
  assign(".zb_capture", new.env(), envir = .GlobalEnv)
  .zb_capture$calls <- list()
  invisible(trace(
    what = "MakeADFun", where = asNamespace("TMB"), print = FALSE,
    tracer = quote({
      .zb_capture$calls[[length(.zb_capture$calls) + 1L]] <- list(parameters = parameters, random = random)
    })
  ))
  on.exit({
    try(untrace(what = "MakeADFun", where = asNamespace("TMB")), silent = TRUE)
  }, add = TRUE)
  capture <- get(".zb_capture", envir = .GlobalEnv)
  on.exit(try(rm(".zb_capture", envir = .GlobalEnv), silent = TRUE), add = TRUE)

  out <- run_hybrid_mode_seeded(b, seed_z = TRUE)

  z_calls <- Filter(function(cc) !is.null(cc$random) && "z_B" %in% cc$random, capture$calls)
  cat(sprintf("  [trace] MakeADFun called %d time(s) total; %d with z_B in `random`.\n",
              length(capture$calls), length(z_calls)))
  if (!length(z_calls)) {
    cat("  [trace] FAIL: no MakeADFun call had z_B in `random` -- cannot verify.\n")
    return(list(ok = FALSE, out = out))
  }
  cc <- z_calls[[1L]]
  got_z <- cc$parameters$z_B
  want_z <- out$seed$z
  same <- identical(dim(got_z), dim(want_z)) &&
    isTRUE(all.equal(as.numeric(got_z), as.numeric(want_z), tolerance = 1e-10))
  cat(sprintf("  [trace] MakeADFun(parameters$z_B) dim %s vs constructed seed dim %s -- %s\n",
              paste(dim(got_z), collapse = "x"), paste(dim(want_z), collapse = "x"),
              if (same) "IDENTICAL (seed reaches TMB)" else "MISMATCH -- seed did NOT reach TMB"))
  list(ok = same, out = out)
}

## ---------------------------------------------------------------------------
## STEP 4: local smoke -- one small cell, confirm still lands on cold-LA optimum.
main <- function() {
  patch_on(); on.exit(patch_off(), add = TRUE)

  cat("== warm-up (untimed) ==\n"); flush.console()
  wu <- mk(999L, 40L)
  invisible(tryCatch(run_hybrid_mode_seeded(wu), error = function(e) cat("  warm-up error:", conditionMessage(e), "\n")))
  cat("== warm-up done ==\n\n"); flush.console()

  N0 <- 200L; SEED <- 1L
  b <- mk(SEED, N0)

  cat("== step 3: verify the mode seed actually reaches TMB::MakeADFun ==\n")
  v <- verify_seed_reaches_tmb(b)
  cat("\n")

  cat("== step 4: cold LA vs hybrid(mode-seeded) -- landed-on-optimum check ==\n")
  t0 <- proc.time()[["elapsed"]]; f_cold <- run_la_cold(b); t_cold <- proc.time()[["elapsed"]] - t0
  t0 <- proc.time()[["elapsed"]]; h <- run_hybrid_mode_seeded(b, seed_z = TRUE); t_hybrid <- proc.time()[["elapsed"]] - t0
  f_hybrid <- h$fit

  sc_cold <- score_la(f_cold, b)
  sc_hybrid <- score_la(f_hybrid, b)
  obj_cold <- f_cold$opt$objective
  obj_hybrid <- f_hybrid$opt$objective
  d_obj <- obj_hybrid - obj_cold
  d_rf <- sc_hybrid$rf - sc_cold$rf
  landed <- isTRUE(f_hybrid$start_provenance$vgh_warm_start) &&
    isTRUE(f_hybrid$start_provenance$vgh_warm_start_z)

  cat(sprintf("cold LA:              %6.2fs  rel_frob %.5f  obj %.3f\n", t_cold, sc_cold$rf, obj_cold))
  cat(sprintf("hybrid (mode-seeded): %6.2fs  rel_frob %.5f  obj %.3f  vgh_warm_start=%s vgh_warm_start_z=%s\n",
              t_hybrid, sc_hybrid$rf, obj_hybrid,
              f_hybrid$start_provenance$vgh_warm_start, f_hybrid$start_provenance$vgh_warm_start_z))
  cat(sprintf("delta_obj=%+.4f delta_rf=%+.5f -- %s\n", d_obj, d_rf,
              if (abs(d_obj) < 1e-2 && abs(d_rf) < 5e-3) "SAME OPTIMUM" else "DIFFERENT -- FLAG"))

  cat(sprintf("\nSEED-REACHES-TMB: %s\n", if (isTRUE(v$ok)) "CONFIRMED" else "NOT CONFIRMED"))
  cat(sprintf("LANDED-ON-OPTIMUM: %s\n", if (abs(d_obj) < 1e-2 && abs(d_rf) < 5e-3) "TRUE" else "FALSE"))
  cat("\nHYBRID_MODE_WARMSTART_SMOKE_DONE\n")

  list(seed_ok = v$ok, obj_cold = obj_cold, obj_hybrid = obj_hybrid, d_obj = d_obj,
       rf_cold = sc_cold$rf, rf_hybrid = sc_hybrid$rf, d_rf = d_rf, landed = landed,
       t_cold = t_cold, t_hybrid = t_hybrid)
}

result <- main()
saveRDS(result, "dev/va-speed/34-hybrid-mode-warmstart-result.rds")
