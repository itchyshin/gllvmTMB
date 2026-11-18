## Design 119 wave-3 (R3 parametric bootstrap) — CORRECTNESS pre-run.
##
## The COST half is already measured on Totoro (outer fit 1.81 s, inner
## refit se = FALSE 0.41 s, so 83.6 s per campaign fit at B = 200 and
## ~37 core-hours for the 1,600-fit grid). This checks the half a timing
## run cannot: that the pivot construction returns finite, ORDERED,
## properly nested, sanely-scaled intervals with a full bootstrap sample,
## on the campaign's own fixture — before 37 core-hours are committed.
##
## Reuses the driver's own DGP calls verbatim (simulate_wide_data /
## make_mask / apply_mask / mask_cells / fit_wide_model) so the pre-run
## cannot drift from what the campaign actually runs.
##
##   OPENBLAS_NUM_THREADS=1 R_LIBS=... COV119_REPO_ROOT=... \
##     Rscript cov119-prerun-boot.R

suppressMessages(library(gllvmTMB))
source("cov119-dgp.R")

COV119_FAMILY   <- "gaussian"
COV119_N_UNITS  <- 50L
COV119_P_TRAITS <- 25L
COV119_Q_TRUE   <- 2L
N_BOOT <- as.integer(Sys.getenv("COV119_PRERUN_NBOOT", "200"))
REPS   <- 2L
MECHS  <- c("mcar05", "mcar20", "trait_clustered", "unit_clustered")

fit_wide_model <- function(wide, trait_names, unit_col = "site") {
  form <- stats::as.formula(paste0(
    "traits(", paste(trait_names, collapse = ", "), ") ~ 1 + latent(1 | ",
    unit_col, ", d = ", COV119_Q_TRUE, ", unique = FALSE)"
  ))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form, data = wide, unit = unit_col, family = gaussian(),
    missing = gllvmTMB::miss_control(response = "include")
  )))
}

cat(sprintf("=== wave-3 correctness pre-run: %d reps x %d cells, n_boot = %d, 1 core ===\n",
            REPS, length(MECHS), N_BOOT))
cat(sprintf("gllvmTMB %s | %s\n\n", packageVersion("gllvmTMB"), R.version.string))

fails <- 0L
for (mi in seq_along(MECHS)) {
  for (rep in seq_len(REPS)) {
    mech <- MECHS[[mi]]
    seed <- cov119_seed(mi, rep)
    t0 <- proc.time()[[3]]
    out <- tryCatch({
      sim   <- simulate_wide_data(family = COV119_FAMILY,
                                  n_units = COV119_N_UNITS,
                                  p_traits = COV119_P_TRAITS,
                                  q_true = COV119_Q_TRUE, seed = seed)
      mask  <- make_mask(mech, COV119_N_UNITS, COV119_P_TRAITS, seed = seed)
      wm    <- apply_mask(sim$wide, sim$trait_names, mask)
      desg  <- mask_cells(mask, sim$trait_names)
      fit   <- fit_wide_model(wm, sim$trait_names)
      pm    <- gllvmTMB::predict_missing(fit, type = "link", se = TRUE,
                                         se_route = "boot", n_boot = N_BOOT,
                                         boot_seed = seed)
      list(pm = pm, truth = truth_at_cells(sim, desg), n_designed = nrow(desg),
           ok = TRUE)
    }, error = function(e) list(ok = FALSE, msg = conditionMessage(e)))
    el <- proc.time()[[3]] - t0

    if (!isTRUE(out$ok)) {
      fails <- fails + 1L
      cat(sprintf("%-16s rep=%d seed=%-7d %7.1fs  ERROR: %s\n",
                  mech, rep, seed, el, out$msg))
      next
    }

    pm <- out$pm
    finite_se  <- all(is.finite(pm$se_confidence)) && all(pm$se_confidence > 0) &&
                  all(is.finite(pm$se_prediction)) && all(pm$se_prediction > 0)
    ordered    <- all(pm$q_lo_conf < pm$q_hi_conf) &&
                  all(pm$q_lo_pred < pm$q_hi_pred) &&
                  all(pm$q_lo_conf90 < pm$q_hi_conf90) &&
                  all(pm$q_lo_pred90 < pm$q_hi_pred90)
    nested     <- all(pm$q_lo_conf <= pm$q_lo_conf90 + 1e-12) &&
                  all(pm$q_hi_conf90 <= pm$q_hi_conf + 1e-12)
    pred_wider <- all(pm$se_prediction > pm$se_confidence)
    join_ok    <- nrow(pm) == out$n_designed
    n_ok <- if (!is.null(pm$n_boot_ok)) min(pm$n_boot_ok) else
            suppressWarnings(as.integer(attr(pm, "n_boot_ok")))
    boot_full <- isTRUE(!is.na(n_ok) && n_ok >= 0.9 * N_BOOT)
    ## Direction-of-travel only, NOT a verdict: 8 fits cannot measure
    ## coverage. The KEY JOIN is mandatory: predict_missing() row order is
    ## not the designed-mask order, and comparing the two positionally
    ## reported ~0.25 coverage for intervals that are actually at 0.952 --
    ## a fake six-fold failure that nearly got the route blamed. The driver
    ## joins with match() on (original_row, trait); so must this.
    tru <- out$truth
    m <- match(paste(pm$original_row, pm$trait),
               paste(tru$original_row, tru$trait))
    stopifnot("truth join lost cells" = !anyNA(m))
    eta_true <- tru$eta_true[m]
    cov95 <- mean(eta_true >= pm$q_lo_conf & eta_true <= pm$q_hi_conf)

    all_ok <- finite_se && ordered && nested && pred_wider && join_ok && boot_full
    fails <- fails + !all_ok
    cat(sprintf(
      "%-16s rep=%d %7.1fs cells=%3d se=%-5s ord=%-5s nest=%-5s pred>conf=%-5s join=%-5s n_boot_ok=%-4s raw_cov95=%.3f  %s\n",
      mech, rep, el, nrow(pm), finite_se, ordered, nested, pred_wider,
      join_ok, ifelse(is.na(n_ok), "?", n_ok), cov95,
      if (all_ok) "OK" else "*** FAILED ***"))
  }
}

cat(sprintf("\nfailed cells: %d of %d\n", fails, REPS * length(MECHS)))
cat("raw_cov95 is 8 fits of direction only — the verdict needs the 400-rep grid.\n")
cat("STOP: release the full grid only if every cell reads OK.\n")
