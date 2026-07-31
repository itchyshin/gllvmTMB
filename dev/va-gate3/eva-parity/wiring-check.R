#!/usr/bin/env Rscript
## Design 86/VA-in-06 EVA parity -- Gate-1 fixture wiring/mapping verification.
##
## Purpose: confirm the long-format (.eva_fit) <-> wide-format (gllvm::gllvm)
## data crosswalk is byte-correct on the package's OWN sealed Gate-1 fixtures,
## and record what happens when both engines actually attempt to fit them.
## These fixtures (N=2 units) are too small for a meaningful truth-recovery
## comparison -- see the notes emitted below -- so this script is a mapping
## and "does it even run" check, not the primary recovery deliverable (that is
## simulate-ladder.R).

suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-va-in-06", quiet = TRUE))
suppressMessages(library(gllvm))

out_dir <- "/private/tmp/gllvmtmb-va-in-06/dev/va-gate3/eva-parity/results"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
log_con <- file(file.path(out_dir, "wiring-check-log.txt"), open = "wt")
sink(log_con, split = TRUE)

check_fixture <- function(name) {
  cat("\n==============================\n")
  cat("Fixture:", name, "\n")
  cat("==============================\n")
  x <- .eva_fixture(name)
  N <- x$N; T <- x$T; q <- x$q
  cat("N =", N, " T =", T, " q =", q, "\n")
  cat("y (long, in unit-then-trait order as stored):", x$y, "\n")
  cat("unit_id (0-based):", x$unit_id, "\n")
  cat("trait_id (0-based):", x$trait_id, "\n")

  ## ---- reshape long -> wide, using the SAME 0-based unit_id/trait_id the
  ## fixture stores, and verify byte-for-byte against the long form ----
  Y <- matrix(NA_real_, N, T)
  Y[cbind(x$unit_id + 1L, x$trait_id + 1L)] <- x$y
  stopifnot(all(is.finite(Y)))  # every cell filled -> complete design confirmed
  colnames(Y) <- paste0("sp", seq_len(T))

  ## reconstruct long from wide the OTHER way and diff against the original
  lg <- expand.grid(unit = seq_len(N), trait = seq_len(T))
  lg <- lg[order(lg$unit, lg$trait), ]
  yv_from_wide <- as.vector(t(Y))
  yv_original_reordered <- x$y[order(x$unit_id, x$trait_id)]
  mapping_identical <- isTRUE(all.equal(yv_from_wide, yv_original_reordered))
  same_total <- identical(sum(x$y), sum(Y))
  same_dims <- identical(length(x$y), N * T) && identical(dim(Y), c(N, T))

  cat("\nWide reconstruction:\n"); print(Y)
  cat("sum(y long) =", sum(x$y), "  sum(Y wide) =", sum(Y), "  equal:", same_total, "\n")
  cat("dims: N*T =", N * T, " length(y) =", length(x$y),
      " dim(Y) =", paste(dim(Y), collapse = "x"), "  equal:", same_dims, "\n")
  cat("long-from-wide reconstruction identical to original (reordered) long vector:",
      mapping_identical, "\n")
  cat("VERDICT mapping_ok:", same_total && same_dims && mapping_identical, "\n")

  ## ---- is the frozen (beta, theta_rr) coordinate close to a stationary
  ## point of OUR OWN objective on this exact data, or is it an arbitrary
  ## Gate-1 probe coordinate unrelated to any fit?  This matters for whether
  ## "beta"/"theta_rr" in the JSON can be read as ground truth. ----
  obj <- .eva_make_objective(name, silent = TRUE)
  par0 <- obj$par
  grad0 <- tryCatch(obj$gr(par0), error = function(e) NA_real_)
  cat("\nGradient norm at the frozen Gate-1 coordinate (beta, theta_rr, a, log_A_diag, A_off):",
      if (all(is.finite(grad0))) sqrt(sum(grad0^2)) else NA, "\n")
  cat("(A near-zero norm would suggest the frozen point is close to a stationary point;",
      "a large norm confirms it is a fixed VALUE-validation probe, not a converged fit.)\n")

  ## ---- X structure note: the fixture uses a single shared intercept
  ## (ncol(X) == 1), not gllvm's default per-species intercept (beta0, one per
  ## trait/species). This is a genuine parameterization mismatch: even if both
  ## engines are fed the same Y, they are not fitting directly comparable
  ## fixed-effect structures unless X is changed. Recorded, not silently
  ## worked around, since changing X changes what "beta" is estimating. ----
  cat("\nX has", ncol(x$X), "column(s): fixture uses",
      if (ncol(x$X) == 1) "a SINGLE shared intercept across all traits" else "a per-trait design",
      "-- gllvm's default binomial fit instead estimates ONE INTERCEPT PER SPECIES",
      "(params$beta0, length T). beta is therefore not directly comparable between",
      "engines on this fixture without changing what each model estimates.\n")

  ## ---- attempt a genuine fit on both engines from DEFAULT (data-driven)
  ## starts -- not merely evaluating at the frozen coordinate -- and record
  ## status honestly. N is tiny (2 units), so a degenerate/failed outcome is
  ## expected and is itself the informative result. ----
  cat("\n--- ours: .eva_fit() from default start ---\n")
  t0 <- proc.time()[["elapsed"]]
  ours <- tryCatch(
    .eva_fit(y = x$y, n_trials = rep(1, length(x$y)), X = x$X,
             unit_id = x$unit_id, trait_id = x$trait_id, q = q,
             N = N, T = T, family = "binomial", link = "logit"),
    error = function(e) structure(list(message = conditionMessage(e)), class = "eva_r_error")
  )
  secs_ours <- proc.time()[["elapsed"]] - t0
  if (inherits(ours, "eva_r_error")) {
    cat("STATUS: r_error --", ours$message, "\n")
  } else {
    cat("STATUS:", ours$status, " healthy:", ours$best$healthy,
        " max_abs_gradient:", ours$best$max_abs_gradient, " secs:", secs_ours, "\n")
    beta_hat <- unname(ours$best$par[names(ours$best$par) == "beta"])
    cat("beta_hat:", beta_hat, " (frozen fixture beta was:", x$beta, ")\n")
  }

  cat("\n--- gllvm::gllvm(method = 'EVA', family = binomial(link = 'logit')) from default start ---\n")
  t0 <- proc.time()[["elapsed"]]
  g <- tryCatch(
    withCallingHandlers(
      gllvm::gllvm(y = Y, family = binomial(link = "logit"), num.lv = q, method = "EVA", seed = 1),
      warning = function(w) { cat("  [gllvm warning]:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") }
    ),
    error = function(e) structure(list(message = conditionMessage(e)), class = "gllvm_r_error")
  )
  secs_g <- proc.time()[["elapsed"]] - t0
  if (inherits(g, "gllvm_r_error")) {
    cat("STATUS: r_error --", g$message, "\n")
  } else {
    cat("STATUS: convergence =", g$convergence, " logL:", g$logL, " secs:", secs_g, "\n")
    cat("beta0:", g$params$beta0, "\n")
  }

  invisible(list(name = name, N = N, T = T, q = q, Y = Y,
                 mapping_ok = same_total && same_dims && mapping_identical,
                 grad_norm_at_frozen = if (all(is.finite(grad0))) sqrt(sum(grad0^2)) else NA,
                 ours = ours, gllvm = g,
                 secs_ours = secs_ours, secs_gllvm = secs_g))
}

res_bernoulli   <- check_fixture("bernoulli")
res_bernoulli_q2 <- check_fixture("bernoulli_q2")

saveRDS(list(bernoulli = res_bernoulli, bernoulli_q2 = res_bernoulli_q2),
        file.path(out_dir, "wiring-check-results.rds"))

cat("\n\nDONE.\n")
sink()
close(log_con)
cat("Wrote", file.path(out_dir, "wiring-check-log.txt"), "\n")
