## Detector-S2b calibration campaign staging for the ordinal loading
## degeneracy row (.gllvmTMB_ordinal_degeneracy_row(), component
## "ordinal_liability_loading", R/diagnose.R). Pre-registered arms, grid,
## seed counts, and targets: pass-criteria-ordinal.md (STATUS: DRAFT,
## pending sign-off). Read it before running anything beyond
## --mode timing or --mode smoke.
##
## DGP reuse (do not fork): the `degenerate` and `healthy` arms call
## sim_ordinal(), relfrob(), and the TAUS/Q_FACTORS/P_TRAITS/DEGEN_RF
## constants loaded DIRECTLY from probe-mechanism.R by .load_probe_defs()
## below -- parsing the file and eval()-ing only the named definitions into
## a private environment, never hand-copying them, and never source()-ing
## the whole script (which would immediately execute its own 60-fit grid
## as a side effect). The `transport` and `mixed` arms extend the identical
## probit-threshold generative step; each is documented against the
## sim_ordinal() step it is derived from -- never a second, competing DGP.
##
## Usage:
##   Rscript dev/ordinal-degeneracy/campaign-ordinal-calibration.R --mode timing
##   Rscript dev/ordinal-degeneracy/campaign-ordinal-calibration.R --mode smoke
##   Rscript dev/ordinal-degeneracy/campaign-ordinal-calibration.R --mode full
##     (refuses unless GLLVMTMB_ORDINAL_FULL_CAMPAIGN_CONFIRMED=yes is set --
##      see the D-139 gate at the bottom of this file)

suppressPackageStartupMessages({
  library(gllvmTMB)
})

ARGS <- commandArgs(trailingOnly = TRUE)
mode_idx <- which(ARGS == "--mode")
MODE <- if (length(mode_idx) == 1L && length(ARGS) > mode_idx) {
  ARGS[[mode_idx + 1L]]
} else {
  "timing"
}
if (!MODE %in% c("timing", "smoke", "full")) {
  stop("--mode must be one of: timing, smoke, full")
}

OUTDIR <- file.path("dev", "ordinal-degeneracy", "results")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

## --------------------------------------------------- reuse the S1 DGP ---
## Parses probe-mechanism.R and evaluates ONLY the named function/constant
## definitions listed in `wanted`, skipping every other top-level
## expression (the grid construction, the run loop, the cat()s) -- so
## loading this file never executes the probe's own campaign.
.load_probe_defs <- function(
  path = file.path("dev", "ordinal-degeneracy", "probe-mechanism.R"),
  wanted = c(
    "P_TRAITS", "Q_FACTORS", "K_CATS", "TAUS", "UNDERFLOW", "DEGEN_RF",
    "relfrob", "sim_ordinal", "fit_ordinal", "fit_binomial_dichot"
  )
) {
  exprs <- parse(path)
  env <- new.env(parent = globalenv())
  found <- character(0)
  for (e in exprs) {
    if (
      is.call(e) && length(e) >= 2L &&
        identical(as.character(e[[1L]]), "<-") &&
        is.name(e[[2L]])
    ) {
      nm <- as.character(e[[2L]])
      if (nm %in% wanted) {
        eval(e, envir = env)
        found <- c(found, nm)
      }
    }
  }
  missing <- setdiff(wanted, found)
  if (length(missing) > 0L) {
    stop(
      "probe-mechanism.R no longer defines: ", paste(missing, collapse = ", "),
      " -- the reused DGP has drifted; update `wanted` or investigate before",
      " trusting this campaign's arms."
    )
  }
  env
}

probe <- .load_probe_defs()

## ------------------------------------------------------- transport arm ---
## Extends probe$sim_ordinal()'s generative step (Lambda %*% Z + noise,
## thresholded per trait) to a PER-TRAIT loading scale and a PER-TRAIT
## cutpoint span, instead of one shared scalar sigma_lambda and one shared
## TAUS. Setting every trait's scale equal and every cutpoint span
## multiplier equal reduces this exactly to probe$sim_ordinal().
sim_ordinal_transport <- function(
  n, p, q, seed, scale_lo = 0.5, scale_hi = 9
) {
  set.seed(seed * 9173L + n + 777L)
  ## Log-uniform per-trait scale: scale_hi / scale_lo = 18x by default,
  ## inside the pre-registered 10-30x band.
  trait_sigma <- exp(stats::runif(p, log(scale_lo), log(scale_hi)))
  Lam <- matrix(stats::rnorm(p * q), p, q) * trait_sigma
  Z <- matrix(stats::rnorm(n * q), n, q)
  Sig_true <- Lam %*% t(Lam)
  eta <- Z %*% t(Lam)
  alpha <- stats::rnorm(p, 0, 0.3)
  lp <- eta + matrix(alpha, n, p, byrow = TRUE)
  ystar <- as.numeric(t(lp)) + stats::rnorm(n * p)
  ## Heterogeneous cutpoint spans: each trait gets its own multiple of the
  ## shared TAUS shape, from tight (0.3x) to wide (2.5x).
  span_mult <- seq(0.3, 2.5, length.out = p)
  taus_by_trait <- lapply(span_mult, function(m) probe$TAUS * m)
  yv <- integer(n * p)
  idx <- 1L
  for (i in seq_len(n)) {
    for (j in seq_len(p)) {
      yv[idx] <- 1L + sum(ystar[idx] > taus_by_trait[[j]])
      idx <- idx + 1L
    }
  }
  dat <- data.frame(
    trait = factor(rep(seq_len(p), times = n)),
    site  = factor(rep(seq_len(n), each = p))
  )
  dat$value <- yv
  list(
    data = dat, Lam = Lam, Sig_true = Sig_true,
    trait_sigma = trait_sigma, span_mult = span_mult
  )
}

fit_ordinal_transport <- function(dat, q) {
  gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE),
    data = dat, unit = "site", family = gllvmTMB::ordinal_probit()
  )
}

## ----------------------------------------------------------- mixed arm ---
## Same probit-threshold step as probe$sim_ordinal() for the ordinal
## traits, plus a plain gaussian(loading %*% Z + noise) step for the
## gaussian traits, sharing one latent factor -- the smallest extension
## that puts a second family in the same fit. Tests the Psi-drop asymmetry
## documented in .gllvmTMB_ordinal_degeneracy_row()'s roxygen (R/diagnose.R):
## a pure-ordinal fit has auto_unique_off_family == TRUE (fit-multi.R, fids
## 12/13/14) and so no report$sd_B at all; mixing in a gaussian trait turns
## that OFF, so this fit carries a Psi block alongside the loading arms
## under test. `unique = FALSE` is therefore NOT passed to latent() here
## (unlike the pure-ordinal fits above) -- forcing it off would silently
## erase the very asymmetry this arm exists to exercise.
sim_ordinal_mixed <- function(
  n, q, seed, sigma_lambda = 0.7, p_ord = 2L, p_gau = 2L
) {
  set.seed(seed * 9173L + n + 555L)
  p <- p_ord + p_gau
  Lam <- matrix(stats::rnorm(p * q, 0, sigma_lambda), p, q)
  Z <- matrix(stats::rnorm(n * q), n, q)
  Sig_true <- Lam %*% t(Lam)
  eta <- Z %*% t(Lam)
  alpha <- stats::rnorm(p, 0, 0.3)
  lp <- eta + matrix(alpha, n, p, byrow = TRUE)
  ystar <- as.numeric(t(lp)) + stats::rnorm(n * p)

  trait_lab <- c(paste0("ord", seq_len(p_ord)), paste0("g", seq_len(p_gau)))
  family_lab <- c(rep("ord", p_ord), rep("gau", p_gau))
  dat <- data.frame(
    trait  = factor(rep(trait_lab, times = n), levels = trait_lab),
    site   = factor(rep(seq_len(n), each = p)),
    family = factor(rep(family_lab, times = n), levels = c("ord", "gau"))
  )
  is_ord <- dat$family == "ord"
  value <- numeric(n * p)
  value[is_ord] <- 1L +
    (ystar[is_ord] > probe$TAUS[1]) +
    (ystar[is_ord] > probe$TAUS[2]) +
    (ystar[is_ord] > probe$TAUS[3])
  value[!is_ord] <- ystar[!is_ord]
  dat$value <- value
  list(data = dat, Lam = Lam, Sig_true = Sig_true)
}

fit_ordinal_mixed <- function(dat, q) {
  family_list <- list(gllvmTMB::ordinal_probit(), stats::gaussian())
  attr(family_list, "family_var") <- "family"
  gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = q),
    data = dat, unit = "site", family = family_list
  )
}

## -------------------------------------------------------- one-fit runner ---
## Fits one cell of one arm and reports whether O1/O2 fired at a GIVEN
## threshold pair, plus rel_frob against that cell's own generating truth
## (unavailable for `mixed`, whose Lam mixes ordinal and gaussian rows on
## one shared factor and is not usable for the SAME rel_frob comparison the
## ordinal-only arms use -- recorded as NA rather than a mismatched number).
run_one <- function(arm, n, seed, q = probe$Q_FACTORS, p = probe$P_TRAITS,
                     runaway_thresh = 25, absolute_thresh = 6) {
  t0 <- proc.time()[["elapsed"]]
  sim <- switch(
    arm,
    degenerate = probe$sim_ordinal(n, p, q, 3.0, seed),
    healthy    = probe$sim_ordinal(n, p, q, 0.7, seed),
    transport  = sim_ordinal_transport(n, p, q, seed),
    mixed      = sim_ordinal_mixed(n, q, seed)
  )
  fit <- tryCatch(
    withCallingHandlers(
      switch(
        arm,
        degenerate = ,
        healthy    = probe$fit_ordinal(sim$data),
        transport  = fit_ordinal_transport(sim$data, q),
        mixed      = fit_ordinal_mixed(sim$data, q)
      ),
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "cell_error")
  )
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(fit, "cell_error")) {
    return(data.frame(
      arm = arm, n = n, seed = seed, seconds = secs, status = "ERROR",
      rel_frob = NA_real_, degenerate_label = NA, o1 = NA, o2 = NA,
      status_row = NA_character_, note = fit$msg, stringsAsFactors = FALSE
    ))
  }
  chk <- tryCatch(
    gllvmTMB::check_gllvmTMB(
      fit,
      ordinal_loading_runaway_thresh = runaway_thresh,
      ordinal_loading_absolute_thresh = absolute_thresh
    ),
    error = function(e) NULL
  )
  row <- if (!is.null(chk)) {
    chk[chk$component == "ordinal_liability_loading", , drop = FALSE]
  } else {
    NULL
  }
  status_row <- if (!is.null(row) && nrow(row) > 0L) row$status[[1L]] else NA_character_
  ## The row's PASS-branch message text always mentions "O1"/"O2" generically
  ## (it is a description of the screen, not an arms-fired list) -- only the
  ## WARN branch's message states which arm(s) actually fired
  ## ("... arms: O1,O2)"), so o1/o2 must only be read on a WARN row.
  is_warn <- !is.null(row) && nrow(row) > 0L && identical(status_row, "WARN")
  o1 <- is_warn && grepl("O1", row$message[[1L]])
  o2 <- is_warn && grepl("O2", row$message[[1L]])

  rel_frob <- NA_real_
  degenerate_label <- NA
  if (arm %in% c("degenerate", "healthy", "transport")) {
    Lam_hat <- tryCatch(fit$report$Lambda_B, error = function(e) NULL)
    if (!is.null(Lam_hat) && all(is.finite(Lam_hat))) {
      rel_frob <- probe$relfrob(tcrossprod(Lam_hat), sim$Sig_true)
      degenerate_label <- isTRUE(rel_frob > probe$DEGEN_RF)
    }
  }

  ## Record the RAW statistics, not just the boolean verdicts at one
  ## threshold pair: a calibration that stores only "fired / did not fire"
  ## cannot choose a threshold afterwards, which is the whole purpose of the
  ## campaign. `max_loading_unit` drives O2, `relative_loading` drives O1.
  ord_ids <- tryCatch({
    td <- fit$tmb_data
    sort(unique(td$trait_id[td$family_id_vec == 14L]))
  }, error = function(e) NULL)
  stats <- tryCatch(
    gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit, reference_traits = ord_ids),
    error = function(e) NULL
  )
  max_loading_unit <- if (!is.null(stats) && "max_loading_unit" %in% names(stats)) {
    suppressWarnings(max(stats$max_loading_unit, na.rm = TRUE))
  } else NA_real_
  relative_loading <- if (!is.null(stats) && "relative_loading" %in% names(stats)) {
    suppressWarnings(max(stats$relative_loading, na.rm = TRUE))
  } else NA_real_

  data.frame(
    arm = arm, n = n, seed = seed, seconds = secs, status = "OK",
    rel_frob = rel_frob, degenerate_label = degenerate_label,
    o1 = o1, o2 = o2, status_row = status_row,
    max_loading_unit = max_loading_unit, relative_loading = relative_loading,
    note = "", stringsAsFactors = FALSE
  )
}

ARMS <- c("degenerate", "healthy", "transport", "mixed")

## ------------------------------------------------------------- --mode timing ---
if (identical(MODE, "timing")) {
  cat("=== timing pilot: 1 fit per arm, n = 100, seed = 1 ===\n")
  rows <- lapply(ARMS, function(a) run_one(a, n = 100L, seed = 1L))
  out <- do.call(rbind, rows)
  print(out[, c("arm", "n", "seconds", "status", "rel_frob", "degenerate_label")])

  ## Pre-registered full-grid fit counts (pass-criteria-ordinal.md).
  planned_n <- c(100L, 400L, 1600L)
  planned_seeds <- c(degenerate = 40L, healthy = 60L, transport = 60L, mixed = 50L)
  per_arm_secs <- stats::setNames(out$seconds, out$arm)
  ## n = 100 is measured; n = 400/1600 are PROJECTED by assuming timing
  ## scales linearly in n (a conservative over-estimate for a Laplace fit,
  ## whose per-iteration cost grows faster than linearly, but the S1
  ## probe's own n=100 vs n=400 pairs were NOT monotonic in n at fixed
  ## sigma_lambda, so no sub-linear scaling is assumed here either).
  scale_factor <- planned_n / 100
  total_secs <- 0
  cat("\nProjected full-grid time (n=400/1600 UNMEASURED, linear-in-n projection):\n")
  for (a in ARMS) {
    arm_secs <- sum(per_arm_secs[[a]] * scale_factor) * planned_seeds[[a]] / length(planned_n)
    ## Distribute seeds evenly across the 3 n values for the projection.
    arm_secs <- sum(per_arm_secs[[a]] * scale_factor * (planned_seeds[[a]] / length(planned_n)))
    total_secs <- total_secs + arm_secs
    cat(sprintf(
      "  %-11s seed@n=100: %.1fs -> projected %d fits: %.1fs (%.1f min)\n",
      a, per_arm_secs[[a]], planned_seeds[[a]], arm_secs, arm_secs / 60
    ))
  }
  cat(sprintf(
    "\nTOTAL projected: %.1fs = %.1f min = %.2f h (630 fits pre-registered)\n",
    total_secs, total_secs / 60, total_secs / 3600
  ))
  if (total_secs > 30 * 60) {
    cat(
      "\n*** D-139 GATE: projected full run exceeds 30 minutes. Do NOT run",
      "--mode full without a pre-run test at the actual planned n values",
      "and Shinichi's explicit approval; consider routing to Totoro. ***\n"
    )
  }
  write.csv(
    out, file.path(OUTDIR, "campaign-timing-pilot.csv"), row.names = FALSE
  )
}

## ------------------------------------------------------------- --mode smoke ---
if (identical(MODE, "smoke")) {
  cat("=== smoke check: 2 seeds per arm, n = 100 ===\n")
  grid <- expand.grid(arm = ARMS, seed = 1:2, stringsAsFactors = FALSE)
  rows <- vector("list", nrow(grid))
  for (i in seq_len(nrow(grid))) {
    rows[[i]] <- run_one(grid$arm[i], n = 100L, seed = grid$seed[i])
    r <- rows[[i]]
    cat(sprintf(
      "[%d/%d] arm=%-11s seed=%d status=%s row_status=%s o1=%s o2=%s rel_frob=%s (%.1fs)\n",
      i, nrow(grid), r$arm, r$seed, r$status, r$status_row, r$o1, r$o2,
      format(r$rel_frob, digits = 3), r$seconds
    ))
  }
  out <- do.call(rbind, rows)
  write.csv(
    out, file.path(OUTDIR, "campaign-smoke-2seed.csv"), row.names = FALSE
  )
  cat("\nstatus counts (fit-level):\n")
  print(table(out$arm, out$status))
  n_err <- sum(out$status == "ERROR")
  if (n_err > 0L) {
    cat(sprintf(
      "\n*** %d/%d smoke fits ERRORED -- fix the arm DGP/fit code before",
      n_err, nrow(out)
    ), "staging a real run. ***\n")
    print(out[out$status == "ERROR", c("arm", "n", "seed", "note")])
  } else {
    cat("\nAll smoke fits ran to completion (no functional correctness claim\n")
    cat("at 2 seeds -- this only proves the arms' DGP/fit/check plumbing works).\n")
  }
}

## -------------------------------------------------------------- --mode full ---
if (identical(MODE, "full")) {
  if (!identical(Sys.getenv("GLLVMTMB_ORDINAL_FULL_CAMPAIGN_CONFIRMED"), "yes")) {
    stop(
      "--mode full refuses to run without explicit sign-off.\n",
      "Per D-139 (see pass-criteria-ordinal.md), this is a 630-fit campaign;",
      " run --mode timing first, read its projection, get Shinichi's",
      " approval, then set\n",
      "  GLLVMTMB_ORDINAL_FULL_CAMPAIGN_CONFIRMED=yes\n",
      "before re-running with --mode full. NOT run in this session."
    )
  }
  stop(
    "--mode full is staged but not implemented in this session -- the grid",
    " loop, sensitivity/FP aggregation, and the cutpoint_span-vs-degeneracy",
    " correlation precondition (pass-criteria-ordinal.md) still need to be",
    " written once sign-off is granted."
  )
}
