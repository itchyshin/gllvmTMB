## dev/m3-pilot-report.R
##
## Design 66 power study -- RESULTS + ISSUES recording and the
## coverage/power VISUALISATION layer for the Phase-1 pilot.
##
## This file is the reporting companion to dev/m3-pilot-launch.R (the
## accumulate engine) and dev/power-pilot-run.R (the CLI sweep wrapper).
## It reads the ACCUMULATED per-cell results (the GHA `power-pilot-results`
## orphan-branch store + any local store), folds them into one tidy
## per-cell table that carries BOTH the coverage / zero-exclusion diagnostics
## AND the issue columns (failed fits, non-PD Hessian, convergence failure
## rates, a flag), draws the drmTMB-style coverage-vs-nominal forest +
## per-family zero-exclusion diagnostic curves, and writes a durable markdown
## + RDS record with an
## explicit ISSUES section.
##
## drmTMB reuse note: drmTMB exposes no EXPORTED coverage/power simulation
## plotter (its NAMESPACE exports only plot_corpairs / plot_parameter_surface,
## which are parameter/correlation plots). The "really nice" coverage/power
## grammar lives INLINE in drmTMB's vignettes/simulation-plot-grammar.Rmd
## (faint replicate-block dots + aggregate proportion points + 95% binomial
## MCSE interval bars + a dotted reference line at the nominal target,
## faceted by surface, on a colour-blind-safe Okabe-Ito palette and a
## shared theme_sim_grammar()). Because there is nothing to source, the
## STYLE is replicated here, faithfully, in self-contained pilot_plot()
## helpers. See PR body for the exact path/grammar.
##
## This file is in `.Rbuildignore` (dev/) -- NOT shipped with the package.
##
## Usage (interactive):
##   source("dev/m3-grid.R")          # m3_summarise() + harness
##   source("dev/m3-pilot-report.R")
##   df  <- pilot_collect(results_dirs = c("dev/m3-pilot-results"))
##   ggs <- pilot_plot(df)            # writes PNGs to dev/m3-pilot-figures/
##   pilot_record(df)                 # writes dev/m3-pilot-summary.{md,rds}
##
## Usage (CLI, for the GHA summary job -- prints one ISSUES line to stdout):
##   Rscript dev/m3-pilot-report.R --emit-issues \
##     --results-dir=dev/m3-pilot-results

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

## ---- Guard: the harness must be sourced for m3_summarise() ------------

## pilot_collect() reuses m3_summarise() (the validated per-cell coverage
## aggregator) rather than re-deriving coverage. Source dev/m3-grid.R first.
if (!exists("m3_summarise", mode = "function")) {
  ## Best-effort auto-source when run as a script from the repo root.
  .m3_grid <- file.path("dev", "m3-grid.R")
  if (file.exists(.m3_grid)) {
    source(.m3_grid)
  }
}
if (!exists("pilot_grid", mode = "function")) {
  .m3_launch <- file.path("dev", "m3-pilot-launch.R")
  if (file.exists(.m3_launch) && exists("m3_run_cell", mode = "function")) {
    source(.m3_launch)
  }
}

## Default output locations (all under dev/, build-ignored).
PILOT_FIGURE_DIR_DEFAULT <- "dev/m3-pilot-figures"
PILOT_SUMMARY_MD_DEFAULT <- "dev/m3-pilot-summary.md"
PILOT_SUMMARY_RDS_DEFAULT <- "dev/m3-pilot-summary.rds"
if (!exists("PILOT_CHUNK_AGGREGATE_DIR", inherits = TRUE)) {
  PILOT_CHUNK_AGGREGATE_DIR <- "_chunk-aggregate"
}

## Gate thresholds (Design 66 locked: report BOTH the 94% audit gate and
## the stricter 95% gate). Mirrors pilot_accum_status().
PILOT_GATE_94 <- 0.94
PILOT_GATE_95 <- 0.95

## Default cells for the narrow scoring audit. These deliberately span one
## Gaussian undercoverage cell, one high-failure count cell, and one apparent
## binomial-probit pass.
PILOT_SCORING_AUDIT_CELLS_DEFAULT <- c(
  "gaussian-d1-n150-sig0p0",
  "nbinom2-d2-n50-sig0p0",
  "binomial_probit-d1-n50-sig0p2"
)

## Issue-flag thresholds: a cell is flagged when its fit-failure,
## non-PD-Hessian, or bootstrap-CI failure rate clears these. Tunable.
PILOT_FLAG_FIT_FAIL_RATE <- 0.10
PILOT_FLAG_NONPD_RATE <- 0.10
PILOT_FLAG_CONV_FAIL_RATE <- 0.10

## =====================================================================
## pilot_collect(): read + fold ALL accumulated per-cell results
## =====================================================================

## Read every per-cell `<cell>.rds` (the long per-replicate grid written
## by m3_run_cell / the accumulate engine) from each directory in
## `results_dirs`, COMBINE same-cell grids across directories (so the
## GHA-branch store and a local store add up), DEDUP replicates by their
## true per-draw key (`rep_seed`, falling back to `rep`), and reduce each
## combined cell to ONE tidy row carrying:
##   - cell metadata: cell_id, family (label), harness_family, d, n_units,
##     signal, lambda_scale  (joined from pilot_grid() when available)
##   - accumulated reps: n_sim (distinct draws kept after dedup)
##   - coverage: coverage_primary (from m3_summarise), and the both-gate
##     pass flags passes_94 / passes_95 + primary_gate_status, plus the
##     coverage-eligible row denominator and per-replicate binomial MCSE
##   - zero_exclusion_rate: fraction of primary Sigma_unit_diag CIs excluding
##     zero. This is diagnostic only for the Phase-1 pilot because
##     signal == 0 still has a positive variance target; it is not a valid
##     Type-I or power estimand.
##   - denominators + MCSEs: attempted fits, converged fits, PD-Hessian fits,
##     sdreport-usable fits, bootstrap attempts, coverage-eligible rows, and
##     MCSEs for the reported proportions.
##   - ISSUES: n_failed_fits, fit_failure_rate, n_nonPD, nonpd_rate,
##     n_conv_fail, conv_failure_rate, n_boot_failed, boot_fail_rate, flag
##
## Returns a tidy data.frame, one row per cell, ordered family/d/n/signal.
## Cells that exist only in an index (no `.rds` yet) are NOT invented here;
## this function reports cells with stored replicate data.
pilot_collect <- function(
  results_dirs = "dev/m3-pilot-results",
  index_file = "pilot-index.rds",
  gate_94 = PILOT_GATE_94,
  gate_95 = PILOT_GATE_95
) {
  stopifnot(length(results_dirs) >= 1L)
  if (!exists("m3_summarise", mode = "function")) {
    stop(
      "pilot_collect() needs m3_summarise(); source(\"dev/m3-grid.R\") first."
    )
  }
  results_dirs <- results_dirs[dir.exists(results_dirs)]
  if (!length(results_dirs)) {
    warning("pilot_collect(): no existing results_dirs; returning empty table.")
    return(pilot_collect_empty())
  }

  ## ---- gather per-cell grids keyed by cell id, across all dirs ----
  grids <- pilot_read_cell_grids(results_dirs, index_file = index_file)
  if (!length(grids)) {
    warning("pilot_collect(): no per-cell .rds found; returning empty table.")
    return(pilot_collect_empty())
  }

  ## ---- grid metadata (family/d/n/signal) when the harness is loaded ----
  meta <- if (exists("pilot_grid", mode = "function")) {
    pilot_grid()
  } else {
    NULL
  }

  rows <- lapply(names(grids), function(cid) {
    pilot_collect_cell(grids[[cid]], cid, meta, gate_94, gate_95)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  ord <- order(out$family, out$d, out$n_units, out$signal, na.last = TRUE)
  out[ord, , drop = FALSE]
}

## Resolve explicit immutable-chunk aggregate stores from their parent pilot
## result directories. The report layer does not auto-scan these subdirs from
## pilot_collect() because legacy accumulated stores can coexist with derived
## aggregate stores and must not be double-counted by accident.
pilot_chunk_aggregate_results_dirs <- function(
  results_dirs = "dev/m3-pilot-results",
  aggregate_subdir = PILOT_CHUNK_AGGREGATE_DIR
) {
  stopifnot(length(results_dirs) >= 1L)
  dirs <- file.path(results_dirs, aggregate_subdir)
  dirs[dir.exists(dirs)]
}

## Collect per-cell reports from immutable chunk aggregates written by
## pilot_aggregate_chunk_outputs(). This reuses the same MCSE, denominator,
## fit-health, and evidence-label reducer as pilot_collect(); the only
## difference is the explicit source directory.
pilot_collect_chunk_aggregates <- function(
  results_dirs = "dev/m3-pilot-results",
  aggregate_subdir = PILOT_CHUNK_AGGREGATE_DIR,
  index_file = "pilot-index.rds",
  gate_94 = PILOT_GATE_94,
  gate_95 = PILOT_GATE_95
) {
  aggregate_dirs <- pilot_chunk_aggregate_results_dirs(
    results_dirs = results_dirs,
    aggregate_subdir = aggregate_subdir
  )
  if (!length(aggregate_dirs)) {
    warning(
      "pilot_collect_chunk_aggregates(): no existing chunk aggregate dirs; ",
      "returning empty table."
    )
    return(pilot_collect_empty())
  }
  pilot_collect(
    results_dirs = aggregate_dirs,
    index_file = index_file,
    gate_94 = gate_94,
    gate_95 = gate_95
  )
}

## ---- Scale-gate: the calibrated PASS_TO_SCALE decision (A1a, 2026-07-13) ----
##
## Design 66's pilot gates whether the campaign may scale to the n_sim = 2000
## confirmatory grid. The live index / pilot_status() path stores only bare
## coverage_primary (no MCSE, no fit-health denominators), so the scale
## decision must be made from pilot_collect() -- the reducer that carries
## coverage_mcse, coverage_eligible_n, and the fit-health rates. This closes
## the "wiring gap": the certificate decision is calibrated by construction.
##
## Locked 2026-07-13 (0.5 -> 0.6 gap-closure ultra-plan; solo Claude):
##   * Confirmatory CORE = gaussian, nbinom2, binomial_probit. ordinal_probit
##     and mixed are EXCLUDED (ordinal has no primary bootstrap interval;
##     m3_bootstrap_supported() admits family_id 0:5 only) -- Repair #2.
##   * Repair #1: binomial cells must carry evidence_family == "binomial_probit"
##     (true-probit), never a *_logit_harness label.
##   * Repair #3: signal == 0 is a zero-exclusion diagnostic, not a coverage
##     cell -- only signal > 0 cells enter the gate.
PILOT_CORE_CONFIRMATORY <- c("gaussian", "nbinom2", "binomial_probit")

## Evaluate the scale gate on an ALREADY-collected pilot table (the output of
## pilot_collect()). Pure function of the data.frame -> unit-testable without
## fits. Returns list(verdict = "PASS_TO_SCALE" | "HOLD", cells, reasons).
pilot_scale_gate_eval <- function(
  collected,
  core_families = PILOT_CORE_CONFIRMATORY,
  gate_94 = 0.94,
  gate_95 = 0.95,
  max_fit_fail = 0.20,
  max_boot_fail = 0.20,
  max_ci_missing = 0.10,
  mcse_adjudication = 0.005
) {
  need <- c(
    "family", "evidence_family", "signal", "coverage_primary", "coverage_mcse",
    "coverage_eligible_n", "n_converged_fits", "fit_failure_rate",
    "boot_fail_rate"
  )
  miss <- setdiff(need, names(collected))
  if (length(miss)) {
    stop(
      "pilot_scale_gate_eval(): collected table missing columns: ",
      paste(miss, collapse = ", "),
      " -- pass the output of pilot_collect()."
    )
  }

  ## CORE coverage cells only (signal > 0).
  is_core <- collected$family %in% core_families |
    collected$evidence_family %in% core_families
  cov_cell <- !is.na(collected$signal) & collected$signal > 0
  core <- collected[is_core & cov_cell, , drop = FALSE]

  if (!nrow(core)) {
    return(list(
      verdict = "HOLD",
      cells = core,
      reasons = "no CORE coverage cells (signal > 0) present yet"
    ))
  }

  ## Repair #1 -- true-probit hygiene: no binomial CORE cell may be logit-harness.
  bino <- grepl("binomial", core$family) |
    grepl("binomial", core$evidence_family)
  logit_harness <- bino & grepl("logit", core$evidence_family)
  probit_ok <- !any(logit_harness)

  ## CI-missing rate = fraction of converged fits with no usable primary CI.
  denom <- ifelse(
    is.na(core$n_converged_fits) | core$n_converged_fits <= 0L,
    NA_real_,
    core$n_converged_fits
  )
  ci_missing <- 1 - (core$coverage_eligible_n / denom)
  mcse_f <- ifelse(is.na(core$coverage_mcse), 0.02, core$coverage_mcse)

  fit_ok <- is.na(core$fit_failure_rate) | core$fit_failure_rate <= max_fit_fail
  boot_ok <- is.na(core$boot_fail_rate) | core$boot_fail_rate <= max_boot_fail
  ci_ok <- is.na(ci_missing) | ci_missing <= max_ci_missing
  health_ok <- fit_ok & boot_ok & ci_ok
  ## Provisional coverage: within ~2 MCSE of the 0.94 gate at pilot noise.
  cov_provisional <- is.na(core$coverage_primary) |
    core$coverage_primary >= (gate_94 - 2 * pmax(mcse_f, 0.005))
  ## Adjudication-grade precision -- the pilot is a SMOKE instrument and is
  ## EXPECTED to miss this; scale to n_sim=2000 to adjudicate 0.94 vs 0.95.
  mcse_adjudicated <- !is.na(core$coverage_mcse) &
    core$coverage_mcse <= mcse_adjudication

  core$gate_passes_94 <- !is.na(core$coverage_primary) &
    core$coverage_primary >= gate_94
  core$ci_missing_rate <- ci_missing
  core$gate_fit_ok <- fit_ok
  core$gate_boot_ok <- boot_ok
  core$gate_ci_ok <- ci_ok
  core$gate_health_ok <- health_ok
  core$gate_cov_provisional <- cov_provisional
  core$gate_mcse_adjudicated <- mcse_adjudicated

  reasons <- character(0)
  if (!probit_ok) {
    reasons <- c(
      reasons,
      "HALT: a binomial CORE cell carries a *_logit_harness evidence_family (Repair #1 -- true-probit only)"
    )
  }
  if (sum(!health_ok)) {
    reasons <- c(reasons, sprintf(
      "%d CORE cell(s) fail a health gate (fit/boot/CI-missing)", sum(!health_ok)
    ))
  }
  if (sum(!cov_provisional)) {
    reasons <- c(reasons, sprintf(
      "%d CORE cell(s) below the provisional coverage floor", sum(!cov_provisional)
    ))
  }

  verdict <- if (probit_ok && all(health_ok) && all(cov_provisional)) {
    "PASS_TO_SCALE"
  } else {
    "HOLD"
  }
  if (verdict == "PASS_TO_SCALE" && !all(mcse_adjudicated)) {
    reasons <- c(
      reasons,
      "NOTE: pilot MCSE is smoke-grade; the n_sim=2000 grid is required to adjudicate 0.94 vs 0.95 (expected)"
    )
  }

  list(verdict = verdict, cells = core, reasons = reasons)
}

## Thin wrapper: collect from the result stores, then evaluate the gate.
pilot_scale_gate <- function(
  results_dirs = "dev/m3-pilot-results",
  index_file = "pilot-index.rds",
  ...
) {
  collected <- pilot_collect(
    results_dirs = results_dirs,
    index_file = index_file
  )
  pilot_scale_gate_eval(collected, ...)
}

## Read and combine the long per-replicate grids from one or more stores.
## This is the shared loading path for pilot_collect() and the scoring audit.
pilot_read_cell_grids <- function(
  results_dirs = "dev/m3-pilot-results",
  index_file = "pilot-index.rds",
  cell_ids = NULL
) {
  stopifnot(length(results_dirs) >= 1L)
  results_dirs <- results_dirs[dir.exists(results_dirs)]
  if (!length(results_dirs)) {
    return(list())
  }
  if (!is.null(cell_ids)) {
    cell_ids <- unique(as.character(cell_ids))
  }

  grids <- list() # cell_id -> combined long grid
  for (dir in results_dirs) {
    files <- list.files(dir, pattern = "\\.rds$", full.names = TRUE)
    files <- files[basename(files) != index_file]
    for (f in files) {
      cid <- sub("\\.rds$", "", basename(f))
      if (!is.null(cell_ids) && !cid %in% cell_ids) {
        next
      }
      g <- tryCatch(readRDS(f), error = function(e) NULL)
      if (is.null(g) || !is.data.frame(g) || nrow(g) == 0L) {
        next
      }
      grids[[cid]] <- pilot_rbind_cell(grids[[cid]], g)
    }
  }
  grids
}

## Combine two long per-rep grids for the SAME cell, then drop duplicate
## draws so reps summed across stores are not double-counted. The unique
## draw key is rep_seed (the true per-draw seed); fall back to rep, then
## to a row-identity de-dup. Renumbers `rep` to stay globally unique so
## m3_summarise()'s per-rep grouping is correct.
pilot_rbind_cell <- function(prev, new) {
  if (is.null(prev)) {
    combined <- new
  } else {
    common <- intersect(names(prev), names(new))
    combined <- rbind(prev[, common, drop = FALSE], new[, common, drop = FALSE])
  }
  ## Drop duplicate draws.
  if ("rep_seed" %in% names(combined)) {
    ## Keep all rows of each distinct (rep_seed) draw; a draw is a block of
    ## trait rows sharing one rep_seed. De-dup whole draws, not rows: a
    ## draw is duplicated if its rep_seed already appeared with identical
    ## per-row content. Use rep_seed + trait_id + target as the row key.
    key_cols <- intersect(
      c("rep_seed", "trait_id", "target", "ci_method"),
      names(combined)
    )
    combined <- combined[!duplicated(combined[, key_cols, drop = FALSE]), ]
    ## Renumber rep contiguously within each distinct rep_seed so grouping
    ## by `rep` matches grouping by draw.
    combined$rep <- match(combined$rep_seed, unique(combined$rep_seed))
  } else if ("rep" %in% names(combined)) {
    key_cols <- intersect(
      c("rep", "trait_id", "target", "ci_method"),
      names(combined)
    )
    combined <- combined[!duplicated(combined[, key_cols, drop = FALSE]), ]
  }
  combined
}

## Reduce ONE combined long grid to a single tidy per-cell row.
pilot_collect_cell <- function(g, cid, meta, gate_94, gate_95) {
  ## --- coverage via the validated aggregator (primary target row) ---
  cov_p <- NA_real_
  gate_status <- NA_character_
  pd_rate_summ <- NA_real_
  boot_fail_rate <- NA_real_
  s <- tryCatch(m3_summarise(g), error = function(e) NULL)
  if (!is.null(s)) {
    prim <- s[!is.na(s$coverage_primary), , drop = FALSE]
    if (nrow(prim)) {
      cov_p <- prim$coverage_primary[1]
      gate_status <- prim$primary_gate_status[1] %||% NA_character_
      if ("pd_hessian_rate" %in% names(prim)) {
        pd_rate_summ <- prim$pd_hessian_rate[1]
      }
      if ("boot_fail_rate" %in% names(prim)) {
        boot_fail_rate <- prim$boot_fail_rate[1]
      }
    }
  }

  ## --- per-rep issue + power accounting from the raw grid ---
  ## "Primary" rows: the rotation-invariant Sigma_unit_diag / bootstrap
  ## target -- the estimand the coverage claim is about.
  prim_rows <- pilot_primary_rows(g)
  rep_key <- if ("rep_seed" %in% names(g)) "rep_seed" else "rep"

  ## n_sim = distinct accumulated draws.
  n_sim <- if (rep_key %in% names(g)) {
    length(unique(g[[rep_key]]))
  } else {
    NA_integer_
  }

  ## Fit failures: a draw is a failed fit if its rows say so. Use
  ## fit_converged (preferred) else converged; FALSE => failed.
  fit_ok_col <- if ("fit_converged" %in% names(g)) {
    "fit_converged"
  } else if ("converged" %in% names(g)) {
    "converged"
  } else {
    NA_character_
  }
  n_failed_fits <- NA_integer_
  fit_failure_rate <- NA_real_
  n_converged_fits <- NA_integer_
  if (!is.na(fit_ok_col) && rep_key %in% names(g)) {
    per_draw_ok <- tapply(g[[fit_ok_col]], g[[rep_key]], function(x) {
      all(x %in% TRUE)
    })
    n_failed_fits <- sum(!per_draw_ok)
    n_converged_fits <- sum(per_draw_ok %in% TRUE)
    fit_failure_rate <- mean(!per_draw_ok)
  }
  fit_failure_mcse <- pilot_binomial_mcse(fit_failure_rate, n_sim)

  ## Non-PD Hessian: per-draw pd_hessian flag (from fit health). A draw
  ## is non-PD if its first row's pd_hessian is not TRUE.
  n_nonpd <- NA_integer_
  nonpd_rate <- NA_real_
  n_pd_hessian <- NA_integer_
  if ("pd_hessian" %in% names(g) && rep_key %in% names(g)) {
    per_draw_pd <- tapply(g$pd_hessian, g[[rep_key]], function(x) {
      any(x %in% TRUE)
    })
    n_nonpd <- sum(!(per_draw_pd %in% TRUE))
    n_pd_hessian <- sum(per_draw_pd %in% TRUE)
    nonpd_rate <- mean(!(per_draw_pd %in% TRUE))
  } else if (!is.na(pd_rate_summ)) {
    nonpd_rate <- 1 - pd_rate_summ
  }
  nonpd_mcse <- pilot_binomial_mcse(nonpd_rate, n_sim)

  n_sdreport_ok <- NA_integer_
  sdreport_ok_rate <- NA_real_
  if ("sdreport_ok" %in% names(g) && rep_key %in% names(g)) {
    per_draw_sd <- tapply(g$sdreport_ok, g[[rep_key]], function(x) {
      any(x %in% TRUE)
    })
    n_sdreport_ok <- sum(per_draw_sd %in% TRUE)
    sdreport_ok_rate <- mean(per_draw_sd %in% TRUE)
  }

  ## Convergence failure rate: the optimiser convergence code != 0 on a
  ## draw (distinct from fit_converged, which can also fold in CI health).
  n_conv_fail <- NA_integer_
  conv_failure_rate <- NA_real_
  n_optimizer_converged <- NA_integer_
  if ("fit_convergence_code" %in% names(g) && rep_key %in% names(g)) {
    per_draw_conv <- tapply(
      g$fit_convergence_code,
      g[[rep_key]],
      function(x) {
        x <- x[!is.na(x)]
        if (!length(x)) NA else all(x == 0L)
      }
    )
    n_conv_fail <- sum(per_draw_conv %in% FALSE)
    n_optimizer_converged <- sum(per_draw_conv %in% TRUE)
    conv_failure_rate <- mean(per_draw_conv %in% FALSE)
  } else if (!is.na(fit_failure_rate)) {
    ## Fall back to the fit-failure rate as the convergence proxy.
    conv_failure_rate <- fit_failure_rate
    n_conv_fail <- n_failed_fits
    n_optimizer_converged <- n_converged_fits
  }
  conv_failure_mcse <- pilot_binomial_mcse(conv_failure_rate, n_sim)

  ## Bootstrap-CI failure: fraction of attempted boot reps that failed
  ## (already aggregated by m3_summarise as boot_fail_rate). Keep counts.
  boot_counts <- pilot_boot_counts(prim_rows, rep_key)
  n_boot_failed <- boot_counts$failed
  n_boot_attempted <- boot_counts$attempted
  if (!is.na(n_boot_attempted) && n_boot_attempted > 0L) {
    boot_fail_rate <- n_boot_failed / n_boot_attempted
  }
  boot_fail_mcse <- pilot_binomial_mcse(boot_fail_rate, n_boot_attempted)

  coverage_eligible_n <- pilot_coverage_denominator(prim_rows)
  coverage_mcse <- pilot_binomial_mcse(cov_p, n_sim)

  ## --- zero-exclusion diagnostic on the primary target ---
  ## This is the fraction of (converged, CI-available) draws whose primary
  ## Sigma_unit_diag CI excludes zero. It is NOT a valid Type-I / power
  ## estimand for the current Phase-1 pilot because signal == 0 still leaves
  ## a positive variance target. Keep the legacy `power` alias so existing
  ## result stores / summaries remain readable while new text uses the
  ## target-aligned name.
  zero_summary <- pilot_rejection_summary(prim_rows)
  zero_exclusion_rate <- zero_summary$rate
  zero_exclusion_n <- zero_summary$n
  zero_exclusion_mcse <- pilot_binomial_mcse(
    zero_exclusion_rate,
    zero_exclusion_n
  )
  power <- zero_exclusion_rate

  ## --- flag ---
  flag <- pilot_make_flag(
    fit_failure_rate,
    nonpd_rate,
    conv_failure_rate,
    boot_fail_rate
  )

  ## --- metadata join ---
  m <- if (!is.null(meta)) meta[meta$cell_id == cid, , drop = FALSE] else NULL
  fam_label <- if (!is.null(m) && nrow(m)) {
    m$family_label[1]
  } else if ("family" %in% names(g)) {
    g$family[1]
  } else {
    NA_character_
  }

  data.frame(
    cell_id = cid,
    family = fam_label,
    evidence_family = if (
      !is.null(m) && nrow(m) && "evidence_family" %in% names(m)
    ) {
      m$evidence_family[1]
    } else {
      fam_label
    },
    harness_family = if (!is.null(m) && nrow(m)) {
      m$harness_family[1]
    } else {
      (if ("family" %in% names(g)) g$family[1] else NA_character_)
    },
    link_intended = if (
      !is.null(m) && nrow(m) && "link_intended" %in% names(m)
    ) {
      m$link_intended[1]
    } else {
      NA_character_
    },
    link_harness = if (!is.null(m) && nrow(m) && "link_harness" %in% names(m)) {
      m$link_harness[1]
    } else {
      NA_character_
    },
    d = if (!is.null(m) && nrow(m)) {
      m$d[1]
    } else {
      (if ("d" %in% names(g)) g$d[1] else NA_integer_)
    },
    n_units = if (!is.null(m) && nrow(m)) {
      m$n_units[1]
    } else {
      (if ("n_units" %in% names(g)) g$n_units[1] else NA_integer_)
    },
    signal = if (!is.null(m) && nrow(m)) m$signal[1] else NA_real_,
    lambda_scale = if (!is.null(m) && nrow(m)) {
      m$lambda_scale[1]
    } else {
      (if ("lambda_scale" %in% names(g)) g$lambda_scale[1] else NA_real_)
    },
    n_sim = as.integer(n_sim),
    n_attempted_fits = as.integer(n_sim),
    n_converged_fits = as.integer(n_converged_fits),
    n_optimizer_converged = as.integer(n_optimizer_converged),
    n_pd_hessian = as.integer(n_pd_hessian),
    n_sdreport_ok = as.integer(n_sdreport_ok),
    n_boot_attempted = as.integer(n_boot_attempted),
    coverage_eligible_n = as.integer(coverage_eligible_n),
    coverage_primary = cov_p,
    coverage_mcse = coverage_mcse,
    passes_94 = if (is.na(cov_p)) NA else cov_p >= gate_94,
    passes_95 = if (is.na(cov_p)) NA else cov_p >= gate_95,
    primary_gate_status = gate_status,
    zero_exclusion_rate = zero_exclusion_rate,
    zero_exclusion_n = as.integer(zero_exclusion_n),
    zero_exclusion_mcse = zero_exclusion_mcse,
    power = power,
    n_failed_fits = as.integer(n_failed_fits),
    fit_failure_rate = fit_failure_rate,
    fit_failure_mcse = fit_failure_mcse,
    n_nonPD = as.integer(n_nonpd),
    nonpd_rate = nonpd_rate,
    nonpd_mcse = nonpd_mcse,
    n_conv_fail = as.integer(n_conv_fail),
    conv_failure_rate = conv_failure_rate,
    conv_failure_mcse = conv_failure_mcse,
    n_boot_failed = as.integer(n_boot_failed),
    boot_fail_rate = boot_fail_rate,
    boot_fail_mcse = boot_fail_mcse,
    sdreport_ok_rate = sdreport_ok_rate,
    flag = flag,
    stringsAsFactors = FALSE
  )
}

## Subset of a long grid to the PRIMARY target rows (the rotation-
## invariant Sigma_unit_diag estimand under bootstrap CIs). Falls back to
## all rows if those columns are absent (legacy artifacts).
pilot_primary_rows <- function(g) {
  if (all(c("target", "ci_method") %in% names(g))) {
    sel <- g$target == "Sigma_unit_diag" & g$ci_method == "bootstrap"
    if (any(sel)) {
      return(g[sel, , drop = FALSE])
    }
  }
  g
}

pilot_coverage_denominator <- function(prim_rows) {
  if (is.null(prim_rows) || !nrow(prim_rows)) {
    return(0L)
  }
  ok <- rep(TRUE, nrow(prim_rows))
  if ("trait_id" %in% names(prim_rows)) {
    ok <- ok & !is.na(prim_rows$trait_id)
  }
  if ("fit_converged" %in% names(prim_rows)) {
    ok <- ok & (prim_rows$fit_converged %in% TRUE)
  }
  if ("ci_available" %in% names(prim_rows)) {
    ok <- ok & (prim_rows$ci_available %in% TRUE)
  }
  if ("covered" %in% names(prim_rows)) {
    ok <- ok & !is.na(prim_rows$covered)
  }
  sum(ok, na.rm = TRUE)
}

## Rejection rate = fraction of converged, CI-available primary rows whose
## CI excludes 0. NA when no usable interval rows.
pilot_rejection_summary <- function(prim_rows) {
  if (is.null(prim_rows) || !nrow(prim_rows)) {
    return(list(rate = NA_real_, n = 0L))
  }
  ok <- rep(TRUE, nrow(prim_rows))
  if ("trait_id" %in% names(prim_rows)) {
    ok <- ok & !is.na(prim_rows$trait_id)
  }
  if ("fit_converged" %in% names(prim_rows)) {
    ok <- ok & (prim_rows$fit_converged %in% TRUE)
  }
  if ("ci_available" %in% names(prim_rows)) {
    ok <- ok & (prim_rows$ci_available %in% TRUE)
  }
  lo <- prim_rows$ci_lo
  hi <- prim_rows$ci_hi
  ok <- ok & is.finite(lo) & is.finite(hi)
  if (!any(ok)) {
    return(list(rate = NA_real_, n = 0L))
  }
  lo <- lo[ok]
  hi <- hi[ok]
  ## Reject H0: theta = 0 when 0 is OUTSIDE [lo, hi].
  reject <- !(lo <= 0 & 0 <= hi)
  list(rate = mean(reject), n = length(reject))
}

pilot_rejection_rate <- function(prim_rows) {
  pilot_rejection_summary(prim_rows)$rate
}

pilot_boot_counts <- function(rows, rep_key) {
  if (
    is.null(rows) ||
      !nrow(rows) ||
      !"n_boot_failed" %in% names(rows) ||
      !"n_boot" %in% names(rows) ||
      !rep_key %in% names(rows)
  ) {
    return(list(failed = NA_integer_, attempted = NA_integer_))
  }
  by_rep <- split(rows, rows[[rep_key]], drop = TRUE)
  failed <- vapply(
    by_rep,
    function(rep_df) {
      x <- rep_df$n_boot_failed
      if (all(is.na(x))) 0 else max(x, na.rm = TRUE)
    },
    numeric(1)
  )
  attempted <- vapply(
    by_rep,
    function(rep_df) {
      x <- rep_df$n_boot
      if (all(is.na(x))) 0 else max(x, na.rm = TRUE)
    },
    numeric(1)
  )
  list(
    failed = as.integer(sum(failed, na.rm = TRUE)),
    attempted = as.integer(sum(attempted, na.rm = TRUE))
  )
}

pilot_binomial_mcse <- function(p, n) {
  if (is.na(p) || is.na(n) || n <= 0L) {
    return(NA_real_)
  }
  sqrt(p * (1 - p) / n)
}

## Build the per-cell issue flag string ("" when nothing tripped).
pilot_make_flag <- function(fit_fail, nonpd, conv_fail, boot_fail) {
  bits <- character(0)
  if (!is.na(fit_fail) && fit_fail >= PILOT_FLAG_FIT_FAIL_RATE) {
    bits <- c(bits, sprintf("fit-fail %.0f%%", 100 * fit_fail))
  }
  if (!is.na(nonpd) && nonpd >= PILOT_FLAG_NONPD_RATE) {
    bits <- c(bits, sprintf("nonPD %.0f%%", 100 * nonpd))
  }
  if (!is.na(conv_fail) && conv_fail >= PILOT_FLAG_CONV_FAIL_RATE) {
    bits <- c(bits, sprintf("conv-fail %.0f%%", 100 * conv_fail))
  }
  if (!is.na(boot_fail) && boot_fail >= PILOT_FLAG_FIT_FAIL_RATE) {
    bits <- c(bits, sprintf("boot-fail %.0f%%", 100 * boot_fail))
  }
  paste(bits, collapse = "; ")
}

pilot_collect_empty <- function() {
  data.frame(
    cell_id = character(0),
    family = character(0),
    evidence_family = character(0),
    harness_family = character(0),
    link_intended = character(0),
    link_harness = character(0),
    d = integer(0),
    n_units = integer(0),
    signal = numeric(0),
    lambda_scale = numeric(0),
    n_sim = integer(0),
    n_attempted_fits = integer(0),
    n_converged_fits = integer(0),
    n_optimizer_converged = integer(0),
    n_pd_hessian = integer(0),
    n_sdreport_ok = integer(0),
    n_boot_attempted = integer(0),
    coverage_eligible_n = integer(0),
    coverage_primary = numeric(0),
    coverage_mcse = numeric(0),
    passes_94 = logical(0),
    passes_95 = logical(0),
    primary_gate_status = character(0),
    zero_exclusion_rate = numeric(0),
    zero_exclusion_n = integer(0),
    zero_exclusion_mcse = numeric(0),
    power = numeric(0),
    n_failed_fits = integer(0),
    fit_failure_rate = numeric(0),
    fit_failure_mcse = numeric(0),
    n_nonPD = integer(0),
    nonpd_rate = numeric(0),
    nonpd_mcse = numeric(0),
    n_conv_fail = integer(0),
    conv_failure_rate = numeric(0),
    conv_failure_mcse = numeric(0),
    n_boot_failed = integer(0),
    boot_fail_rate = numeric(0),
    boot_fail_mcse = numeric(0),
    sdreport_ok_rate = numeric(0),
    flag = character(0),
    stringsAsFactors = FALSE
  )
}

## =====================================================================
## pilot_scoring_audit(): target / CI / miss-side diagnostic
## =====================================================================

## Build a narrow diagnostic table for selected cells. The audit checks
## whether the stored truth, estimate, and CI are aligned on the target scale;
## it also records miss direction and why the current CI-excludes-zero
## rejection-rate panel is not a Type-I error when signal == 0 but the
## variance target itself is positive.
pilot_scoring_audit <- function(
  results_dirs = "dev/m3-pilot-results",
  cell_ids = PILOT_SCORING_AUDIT_CELLS_DEFAULT,
  target = "Sigma_unit_diag",
  ci_method = "bootstrap",
  index_file = "pilot-index.rds"
) {
  grids <- pilot_read_cell_grids(
    results_dirs = results_dirs,
    index_file = index_file,
    cell_ids = cell_ids
  )
  missing_cells <- setdiff(cell_ids, names(grids))
  rows <- lapply(names(grids), function(cid) {
    pilot_scoring_audit_cell(grids[[cid]], cid, target, ci_method)
  })
  out <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    pilot_scoring_audit_empty()
  }
  if (length(missing_cells)) {
    missing_rows <- lapply(missing_cells, function(cid) {
      data.frame(
        cell_id = cid,
        family = NA_character_,
        d = NA_integer_,
        n_units = NA_integer_,
        signal = NA_real_,
        target = target,
        ci_method = ci_method,
        n_sim = 0L,
        n_rows = 0L,
        n_ci_rows = 0L,
        coverage = NA_real_,
        current_zero_rejection_rate = NA_real_,
        median_truth = NA_real_,
        median_estimate = NA_real_,
        median_bias = NA_real_,
        median_estimate_truth_ratio = NA_real_,
        median_ci_width = NA_real_,
        median_ci_width_truth_ratio = NA_real_,
        miss_below = 0L,
        miss_above = 0L,
        miss_total = 0L,
        one_sided_miss_share = NA_real_,
        ci_missing_rate = NA_real_,
        fit_failure_rate = NA_real_,
        nonpd_rate = NA_real_,
        conv_failure_rate = NA_real_,
        boot_fail_rate = NA_real_,
        diagnosis = "missing cell file",
        stringsAsFactors = FALSE
      )
    })
    out <- rbind(out, do.call(rbind, missing_rows))
  }
  rownames(out) <- NULL
  ord <- match(out$cell_id, cell_ids)
  out[order(ord, na.last = TRUE), , drop = FALSE]
}

pilot_scoring_audit_cell <- function(g, cid, target, ci_method) {
  rows <- g
  if (all(c("target", "ci_method") %in% names(rows))) {
    rows <- rows[
      rows$target == target & rows$ci_method == ci_method,
      ,
      drop = FALSE
    ]
  }
  rep_key <- if ("rep_seed" %in% names(g)) "rep_seed" else "rep"
  n_sim <- if (rep_key %in% names(g)) {
    length(unique(g[[rep_key]]))
  } else {
    NA_integer_
  }

  usable <- rep(TRUE, nrow(rows))
  if ("fit_converged" %in% names(rows)) {
    usable <- usable & rows$fit_converged %in% TRUE
  }
  if ("ci_available" %in% names(rows)) {
    usable <- usable & rows$ci_available %in% TRUE
  }
  usable <- usable &
    is.finite(rows$truth) &
    is.finite(rows$estimate) &
    is.finite(rows$ci_lo) &
    is.finite(rows$ci_hi)
  u <- rows[usable, , drop = FALSE]

  miss_side <- if ("miss_side" %in% names(u)) {
    u$miss_side
  } else if ("covered" %in% names(u)) {
    ifelse(u$covered %in% TRUE, "covered", "miss")
  } else {
    rep(NA_character_, nrow(u))
  }
  miss_below <- sum(miss_side == "truth_below_lower", na.rm = TRUE)
  miss_above <- sum(miss_side == "truth_above_upper", na.rm = TRUE)
  miss_total <- miss_below + miss_above
  one_sided <- if (miss_total > 0L) {
    max(miss_below, miss_above) / miss_total
  } else {
    NA_real_
  }

  fit_failure_rate <- pilot_draw_failure_rate(g, rep_key, "fit_converged", TRUE)
  if (is.na(fit_failure_rate)) {
    fit_failure_rate <- pilot_draw_failure_rate(g, rep_key, "converged", TRUE)
  }
  nonpd_rate <- 1 - pilot_draw_success_rate(g, rep_key, "pd_hessian", TRUE)
  conv_failure_rate <- pilot_draw_failure_rate(
    g,
    rep_key,
    "fit_convergence_code",
    0L
  )
  if (is.na(conv_failure_rate)) {
    conv_failure_rate <- fit_failure_rate
  }

  boot_fail_rate <- NA_real_
  if (all(c("n_boot_failed", "n_boot") %in% names(rows)) && nrow(rows)) {
    nb_fail <- suppressWarnings(max(rows$n_boot_failed, na.rm = TRUE))
    nb <- suppressWarnings(max(rows$n_boot, na.rm = TRUE))
    if (
      is.finite(nb_fail) &&
        is.finite(nb) &&
        nb > 0 &&
        is.finite(n_sim) &&
        n_sim > 0
    ) {
      boot_fail_rate <- nb_fail / (nb * n_sim)
    }
  }

  coverage <- if ("covered" %in% names(u) && nrow(u)) {
    mean(u$covered %in% TRUE)
  } else {
    NA_real_
  }
  zero_reject <- if (nrow(u)) {
    mean(!(u$ci_lo <= 0 & 0 <= u$ci_hi))
  } else {
    NA_real_
  }
  truth_med <- if (nrow(u)) stats::median(u$truth, na.rm = TRUE) else NA_real_
  est_med <- if (nrow(u)) stats::median(u$estimate, na.rm = TRUE) else NA_real_
  bias_med <- if (nrow(u)) {
    stats::median(u$estimate - u$truth, na.rm = TRUE)
  } else {
    NA_real_
  }
  ratio_med <- if (nrow(u)) {
    stats::median(u$estimate / u$truth, na.rm = TRUE)
  } else {
    NA_real_
  }
  width <- if (nrow(u)) u$ci_hi - u$ci_lo else numeric(0L)
  width_med <- if (length(width)) {
    stats::median(width, na.rm = TRUE)
  } else {
    NA_real_
  }
  width_truth_ratio <- if (nrow(u)) {
    stats::median(width / u$truth, na.rm = TRUE)
  } else {
    NA_real_
  }
  ci_missing_rate <- if (nrow(rows)) {
    mean(!usable)
  } else {
    NA_real_
  }

  data.frame(
    cell_id = cid,
    family = if ("family" %in% names(g)) g$family[1] else NA_character_,
    d = if ("d" %in% names(g)) g$d[1] else NA_integer_,
    n_units = if ("n_units" %in% names(g)) g$n_units[1] else NA_integer_,
    signal = pilot_cell_signal(cid),
    target = target,
    ci_method = ci_method,
    n_sim = as.integer(n_sim),
    n_rows = nrow(rows),
    n_ci_rows = nrow(u),
    coverage = coverage,
    current_zero_rejection_rate = zero_reject,
    median_truth = truth_med,
    median_estimate = est_med,
    median_bias = bias_med,
    median_estimate_truth_ratio = ratio_med,
    median_ci_width = width_med,
    median_ci_width_truth_ratio = width_truth_ratio,
    miss_below = as.integer(miss_below),
    miss_above = as.integer(miss_above),
    miss_total = as.integer(miss_total),
    one_sided_miss_share = one_sided,
    ci_missing_rate = ci_missing_rate,
    fit_failure_rate = fit_failure_rate,
    nonpd_rate = nonpd_rate,
    conv_failure_rate = conv_failure_rate,
    boot_fail_rate = boot_fail_rate,
    diagnosis = pilot_scoring_diagnosis(
      signal = pilot_cell_signal(cid),
      truth_med = truth_med,
      zero_reject = zero_reject,
      coverage = coverage,
      miss_total = miss_total,
      one_sided = one_sided,
      nonpd_rate = nonpd_rate
    ),
    stringsAsFactors = FALSE
  )
}

pilot_draw_success_rate <- function(g, rep_key, col, success_value) {
  if (!col %in% names(g) || !rep_key %in% names(g)) {
    return(NA_real_)
  }
  per_draw <- tapply(g[[col]], g[[rep_key]], function(x) {
    x <- x[!is.na(x)]
    if (!length(x)) {
      return(NA)
    }
    all(x %in% success_value)
  })
  mean(per_draw %in% TRUE)
}

pilot_draw_failure_rate <- function(g, rep_key, col, success_value) {
  rate <- pilot_draw_success_rate(g, rep_key, col, success_value)
  if (is.na(rate)) NA_real_ else 1 - rate
}

pilot_cell_signal <- function(cell_id) {
  hit <- regexpr("sig[0-9]+p[0-9]+", cell_id)
  if (hit < 0L) {
    return(NA_real_)
  }
  raw <- regmatches(cell_id, hit)
  as.numeric(sub("p", ".", sub("^sig", "", raw)))
}

pilot_scoring_diagnosis <- function(
  signal,
  truth_med,
  zero_reject,
  coverage,
  miss_total,
  one_sided,
  nonpd_rate
) {
  bits <- character(0)
  if (
    !is.na(signal) && signal == 0 && is.finite(truth_med) && truth_med > 1e-8
  ) {
    bits <- c(
      bits,
      "signal-zero cell has positive variance target; CI-excludes-zero is not Type-I error"
    )
  }
  if (!is.na(zero_reject) && zero_reject > 0.95) {
    bits <- c(bits, "current zero-rejection metric saturated")
  }
  if (!is.na(coverage) && coverage < PILOT_GATE_94) {
    bits <- c(bits, "coverage below 94pct gate")
  }
  if (miss_total > 0L && !is.na(one_sided) && one_sided >= 0.80) {
    bits <- c(bits, "misses mostly one-sided")
  }
  if (!is.na(nonpd_rate) && nonpd_rate >= PILOT_FLAG_NONPD_RATE) {
    bits <- c(bits, "high non-PD rate")
  }
  if (!length(bits)) {
    "no immediate scoring red flag"
  } else {
    paste(bits, collapse = "; ")
  }
}

pilot_scoring_audit_record <- function(
  audit,
  md_path = "dev/m3-pilot-scoring-audit.md",
  rds_path = "dev/m3-pilot-scoring-audit.rds"
) {
  saveRDS(audit, rds_path)
  writeLines(pilot_scoring_audit_lines(audit), md_path)
  cat(sprintf(
    "[pilot] wrote scoring audit:\n  %s\n  %s\n",
    md_path,
    rds_path
  ))
  invisible(c(md = md_path, rds = rds_path))
}

pilot_scoring_audit_lines <- function(audit) {
  fmt <- function(x, digits = 3) {
    ifelse(is.na(x), "-", formatC(x, format = "f", digits = digits))
  }
  pct <- function(x) ifelse(is.na(x), "-", sprintf("%.0f%%", 100 * x))
  miss_cell <- function(n, denom) {
    if (is.na(denom) || denom <= 0L) {
      return(sprintf("- (%d)", n))
    }
    sprintf("%s (%d)", pct(n / denom), n)
  }

  lines <- c(
    "# Design 66 power pilot -- scoring audit",
    "",
    sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S")),
    "",
    "## Purpose",
    "",
    paste(
      "This audit checks whether the stored truth, estimate, and interval",
      "are aligned for the primary `Sigma_unit_diag` bootstrap target before",
      "the pilot results are interpreted as power or coverage evidence."
    ),
    "",
    "## Audit Table",
    "",
    paste(
      "| cell | n_sim | coverage | zero-reject | median truth |",
      "median estimate | median est/truth | median CI width/truth |",
      "miss below | miss above | nonPD | diagnosis |"
    ),
    paste0(
      "|------|------:|---------:|------------:|-------------:|",
      "---------------:|-----------------:|----------------------:|",
      "-----------:|-----------:|------:|-----------|"
    )
  )
  for (i in seq_len(nrow(audit))) {
    lines <- c(
      lines,
      sprintf(
        "| %s | %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |",
        audit$cell_id[i],
        audit$n_sim[i],
        fmt(audit$coverage[i]),
        fmt(audit$current_zero_rejection_rate[i]),
        fmt(audit$median_truth[i]),
        fmt(audit$median_estimate[i]),
        fmt(audit$median_estimate_truth_ratio[i]),
        fmt(audit$median_ci_width_truth_ratio[i]),
        miss_cell(audit$miss_below[i], audit$n_ci_rows[i]),
        miss_cell(audit$miss_above[i], audit$n_ci_rows[i]),
        pct(audit$nonpd_rate[i]),
        audit$diagnosis[i]
      )
    )
  }
  c(
    lines,
    "",
    "## Interpretation",
    "",
    paste(
      "- `zero-reject` is the current CI-excludes-zero rate used by the pilot",
      "power plot. It is diagnostic only for `Sigma_unit_diag`: when",
      "`signal = 0` but the variance target is positive, this is not a",
      "valid Type-I error calculation."
    ),
    paste(
      "- One-sided misses identify whether poor coverage is mainly due to",
      "intervals sitting above or below the truth rather than random",
      "Monte Carlo scatter."
    ),
    paste(
      "- High non-PD rates are kept separate from target-scale mismatches;",
      "they indicate fit-health problems rather than a scoring definition",
      "by themselves."
    )
  )
}

pilot_scoring_audit_empty <- function() {
  data.frame(
    cell_id = character(0),
    family = character(0),
    d = integer(0),
    n_units = integer(0),
    signal = numeric(0),
    target = character(0),
    ci_method = character(0),
    n_sim = integer(0),
    n_rows = integer(0),
    n_ci_rows = integer(0),
    coverage = numeric(0),
    current_zero_rejection_rate = numeric(0),
    median_truth = numeric(0),
    median_estimate = numeric(0),
    median_bias = numeric(0),
    median_estimate_truth_ratio = numeric(0),
    median_ci_width = numeric(0),
    median_ci_width_truth_ratio = numeric(0),
    miss_below = integer(0),
    miss_above = integer(0),
    miss_total = integer(0),
    one_sided_miss_share = numeric(0),
    ci_missing_rate = numeric(0),
    fit_failure_rate = numeric(0),
    nonpd_rate = numeric(0),
    conv_failure_rate = numeric(0),
    boot_fail_rate = numeric(0),
    diagnosis = character(0),
    stringsAsFactors = FALSE
  )
}

## =====================================================================
## pilot_plot(): the drmTMB-style coverage + diagnostic figures
## =====================================================================

## Okabe-Ito colour-blind-safe palette by family, mirroring drmTMB's
## simulation-plot-grammar surface palette.
PILOT_FAMILY_PALETTE <- c(
  gaussian = "#0072B2",
  nbinom2 = "#D55E00",
  binomial_probit = "#009E73",
  ordinal_probit = "#CC79A7"
)

## Shared theme, replicating drmTMB's theme_sim_grammar().
pilot_theme_grammar <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(
        colour = "grey30",
        lineheight = 1.05
      ),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.position = "bottom",
      plot.margin = ggplot2::margin(6, 10, 12, 6)
    )
}

## Build BOTH pilot figures and (by default) save them as PNGs:
##   1. coverage-vs-nominal forest: per cell, coverage_primary point with a
##      95% binomial MCSE bar, faceted by family, with dotted reference
##      lines at the 94% and 95% gates (the drmTMB coverage grammar).
##   2. zero-exclusion curve: CI-excludes-zero rate vs signal {0, 0.2, 0.5}.
##      This is diagnostic only for the Phase-1 pilot and should not be read
##      as Type-I error / power for Sigma_unit_diag.
## Returns a named list of ggplot objects (invisibly when saving).
pilot_plot <- function(
  df,
  figure_dir = PILOT_FIGURE_DIR_DEFAULT,
  save = TRUE,
  width = 9,
  height = 6,
  dpi = 150
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("pilot_plot() requires the 'ggplot2' package.")
  }
  if (!nrow(df)) {
    stop("pilot_plot(): empty data.frame; run pilot_collect() first.")
  }
  plots <- list(
    coverage = pilot_plot_coverage(df),
    zero_exclusion = pilot_plot_zero_exclusion(df)
  )
  if (isTRUE(save)) {
    if (!dir.exists(figure_dir)) {
      dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
    }
    paths <- c(
      coverage = file.path(figure_dir, "pilot-coverage-vs-nominal.png"),
      zero_exclusion = file.path(
        figure_dir,
        "pilot-zero-exclusion-diagnostic.png"
      )
    )
    ggplot2::ggsave(
      paths[["coverage"]],
      plots$coverage,
      width = width,
      height = height,
      dpi = dpi
    )
    ggplot2::ggsave(
      paths[["zero_exclusion"]],
      plots$zero_exclusion,
      width = width,
      height = height,
      dpi = dpi
    )
    attr(plots, "paths") <- paths
    cat(sprintf(
      "[pilot] wrote figures:\n  %s\n",
      paste(paths, collapse = "\n  ")
    ))
    return(invisible(plots))
  }
  plots
}

## Coverage-vs-nominal forest (drmTMB coverage grammar).
pilot_plot_coverage <- function(df) {
  d <- df[!is.na(df$coverage_primary), , drop = FALSE]
  if (!nrow(d)) {
    return(pilot_empty_plot("No coverage_primary values yet"))
  }
  ## Conservative binomial MCSE on the coverage proportion, using the
  ## independent replicate denominator. `coverage_eligible_n` is reported
  ## separately because the coverage mean itself is computed over eligible
  ## primary interval rows.
  if ("coverage_mcse" %in% names(d)) {
    d$mcse <- d$coverage_mcse
  } else {
    n <- if ("coverage_eligible_n" %in% names(d)) {
      pmax(d$coverage_eligible_n, 1L)
    } else {
      pmax(d$n_sim, 1L)
    }
    d$mcse <- sqrt(d$coverage_primary * (1 - d$coverage_primary) / n)
  }
  d$lower <- pmax(0, d$coverage_primary - 1.96 * d$mcse)
  d$upper <- pmin(1, d$coverage_primary + 1.96 * d$mcse)
  ## A readable per-cell y label (n / d / signal); family is the facet.
  d$cell_label <- sprintf("n%d d%d sig%.1f", d$n_units, d$d, d$signal)
  d$cell_label <- factor(d$cell_label, levels = rev(unique(d$cell_label)))
  d$family <- factor(d$family, levels = names(PILOT_FAMILY_PALETTE))

  gate_lines <- data.frame(
    gate = c("94% audit gate", "95% gate"),
    x = c(PILOT_GATE_94, PILOT_GATE_95)
  )

  ggplot2::ggplot(
    d,
    ggplot2::aes(
      x = .data$coverage_primary,
      y = .data$cell_label,
      colour = .data$family
    )
  ) +
    ggplot2::geom_vline(
      data = gate_lines,
      ggplot2::aes(xintercept = .data$x, linetype = .data$gate),
      colour = "grey45",
      inherit.aes = FALSE
    ) +
    ggplot2::geom_segment(
      ggplot2::aes(
        x = .data$lower,
        xend = .data$upper,
        yend = .data$cell_label
      ),
      linewidth = 0.45,
      na.rm = TRUE
    ) +
    ggplot2::geom_point(size = 2.2, na.rm = TRUE) +
    ggplot2::facet_wrap(~family, scales = "free_y") +
    ggplot2::scale_colour_manual(
      values = PILOT_FAMILY_PALETTE,
      drop = FALSE,
      guide = "none"
    ) +
    ggplot2::scale_linetype_manual(
      values = c(
        "94% audit gate" = "dotted",
        "95% gate" = "dashed"
      )
    ) +
    ggplot2::coord_cartesian(xlim = c(min(0.80, min(d$lower)), 1)) +
    ggplot2::labs(
      title = "Interval coverage vs nominal gates need Monte Carlo uncertainty",
      subtitle = paste(
        "Points: accumulated coverage_primary (Sigma_unit_diag, bootstrap CI);",
        "bars: 95% replicate-level binomial MCSE. Lines: 94%/95% gates."
      ),
      x = "Empirical coverage",
      y = NULL,
      linetype = NULL
    ) +
    pilot_theme_grammar()
}

## Zero-exclusion diagnostic vs signal, one line per family, faceted by
## (n_units, d). Keep pilot_plot_power() as a compatibility wrapper below.
pilot_plot_zero_exclusion <- function(df) {
  if (!"zero_exclusion_rate" %in% names(df)) {
    df$zero_exclusion_rate <- df$power
  }
  d <- df[
    !is.na(df$zero_exclusion_rate) & !is.na(df$signal),
    ,
    drop = FALSE
  ]
  if (!nrow(d)) {
    return(pilot_empty_plot("No zero-exclusion diagnostic values yet"))
  }
  d$family <- factor(d$family, levels = names(PILOT_FAMILY_PALETTE))
  d$panel <- sprintf("n_units %d, d %d", d$n_units, d$d)

  ggplot2::ggplot(
    d,
    ggplot2::aes(
      x = .data$signal,
      y = .data$zero_exclusion_rate,
      colour = .data$family,
      group = .data$family
    )
  ) +
    ## A faint marker at signal == 0. This is not a Type-I reference for
    ## Sigma_unit_diag because the variance target remains positive.
    ggplot2::geom_vline(
      xintercept = 0,
      linetype = "dotted",
      colour = "grey70"
    ) +
    ggplot2::geom_line(linewidth = 0.6, na.rm = TRUE) +
    ggplot2::geom_point(size = 2.1, na.rm = TRUE) +
    ggplot2::facet_wrap(~panel) +
    ggplot2::scale_colour_manual(values = PILOT_FAMILY_PALETTE, drop = FALSE) +
    ggplot2::scale_x_continuous(breaks = c(0, 0.2, 0.5)) +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(
      title = "CI zero-exclusion rate vs signal is diagnostic, not power",
      subtitle = paste(
        "Fraction of primary Sigma_unit_diag CIs excluding zero.",
        "Signal 0 still has positive variance, so this is not Type-I error."
      ),
      x = "Signal (between-unit variance share)",
      y = "CI excludes zero",
      colour = "Family"
    ) +
    pilot_theme_grammar()
}

pilot_plot_power <- function(df) {
  pilot_plot_zero_exclusion(df)
}

pilot_empty_plot <- function(label) {
  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 0, label = label) +
    ggplot2::theme_void()
}

## =====================================================================
## pilot_record(): durable RESULTS + ISSUES record (markdown + RDS)
## =====================================================================

## Write a durable record of the pilot to `md_path` (an ASCII markdown
## report with a results table AND an explicit ISSUES section) and
## `rds_path` (the tidy data.frame, for programmatic reuse). Returns the
## paths invisibly. The ISSUES section lists every flagged cell with its
## failure / non-PD / convergence rates, plus any stuck cells (n_sim == 0)
## and cross-cell anomalies (e.g. coverage far from nominal).
pilot_record <- function(
  df,
  md_path = PILOT_SUMMARY_MD_DEFAULT,
  rds_path = PILOT_SUMMARY_RDS_DEFAULT,
  gate_94 = PILOT_GATE_94,
  gate_95 = PILOT_GATE_95
) {
  saveRDS(df, rds_path)
  lines <- pilot_record_lines(df, gate_94, gate_95)
  writeLines(lines, md_path)
  cat(sprintf(
    "[pilot] wrote record:\n  %s\n  %s\n",
    md_path,
    rds_path
  ))
  invisible(c(md = md_path, rds = rds_path))
}

## Build the markdown record as a character vector (ASCII only). Exposed
## so the GHA summary job can embed the same issues block.
pilot_record_lines <- function(
  df,
  gate_94 = PILOT_GATE_94,
  gate_95 = PILOT_GATE_95
) {
  fmt <- function(x, digits = 3) {
    ifelse(is.na(x), "-", formatC(x, format = "f", digits = digits))
  }
  pct <- function(x) ifelse(is.na(x), "-", sprintf("%.0f%%", 100 * x))
  ylab <- function(x) ifelse(is.na(x), "-", ifelse(x, "Y", "n"))

  n_cells <- nrow(df)
  n_reps <- sum(df$n_sim, na.rm = TRUE)
  cov_done <- df[!is.na(df$coverage_primary), , drop = FALSE]
  cov_signal <- cov_done[
    cov_done$signal > 0 & !is.na(cov_done$signal),
    ,
    drop = FALSE
  ]

  lines <- c(
    "# Design 66 power pilot -- results + issues record",
    "",
    sprintf("Generated: %s", format(Sys.time(), "%Y-%m-%dT%H:%M:%S")),
    "",
    "## Summary",
    "",
    sprintf("- Cells with stored data: %d", n_cells),
    sprintf("- Replicates accumulated (sum n_sim): %d", n_reps),
    if (nrow(cov_signal)) {
      sprintf(
        "- Coverage (signal>0, %d cells): mean=%s  mean MCSE=%s  >=94%%: %d/%d  >=95%%: %d/%d",
        nrow(cov_signal),
        fmt(mean(cov_signal$coverage_primary)),
        fmt(mean(cov_signal$coverage_mcse, na.rm = TRUE)),
        sum(cov_signal$passes_94, na.rm = TRUE),
        nrow(cov_signal),
        sum(cov_signal$passes_95, na.rm = TRUE),
        nrow(cov_signal)
      )
    } else {
      "- Coverage (signal>0): <no cells with coverage yet>"
    },
    ""
  )

  ## ---- results table ----
  lines <- c(
    lines,
    "## Results (per cell)",
    "",
    paste0(
      "| cell | evidence | d | n | signal | n_sim | ci_rows | coverage |",
      " cov_mcse | >=94% | >=95% | zero-excl | fit-fail | nonPD |",
      " sdreport | boot-fail |"
    ),
    paste0(
      "|------|----------|--:|--:|-------:|------:|--------:|---------:|",
      "---------:|:---:|:---:|----------:|--------:|------:|---------:|----------:|"
    )
  )
  for (i in seq_len(n_cells)) {
    lines <- c(
      lines,
      sprintf(
        paste0(
          "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |",
          " %s | %s | %s | %s | %s |"
        ),
        df$cell_id[i],
        if ("evidence_family" %in% names(df)) {
          df$evidence_family[i]
        } else {
          df$family[i]
        },
        ifelse(is.na(df$d[i]), "-", as.character(df$d[i])),
        ifelse(is.na(df$n_units[i]), "-", as.character(df$n_units[i])),
        fmt(df$signal[i], 1),
        as.character(df$n_sim[i]),
        if ("coverage_eligible_n" %in% names(df)) {
          as.character(df$coverage_eligible_n[i])
        } else {
          "-"
        },
        fmt(df$coverage_primary[i]),
        fmt(
          if ("coverage_mcse" %in% names(df)) df$coverage_mcse[i] else NA_real_
        ),
        ylab(df$passes_94[i]),
        ylab(df$passes_95[i]),
        fmt(
          if ("zero_exclusion_rate" %in% names(df)) {
            df$zero_exclusion_rate[i]
          } else {
            df$power[i]
          }
        ),
        pct(df$fit_failure_rate[i]),
        pct(df$nonpd_rate[i]),
        if ("sdreport_ok_rate" %in% names(df)) {
          pct(df$sdreport_ok_rate[i])
        } else {
          "-"
        },
        pct(df$boot_fail_rate[i])
      )
    )
  }
  lines <- c(lines, "")

  ## ---- ISSUES section ----
  lines <- c(lines, pilot_issue_lines(df))
  lines
}

## The ISSUES block as a character vector (ASCII). Reused by the record
## and by the GHA summary one-liner (pilot_issue_oneline()).
pilot_issue_lines <- function(df) {
  flagged <- df[nzchar(df$flag %||% ""), , drop = FALSE]
  flagged <- flagged[!is.na(flagged$cell_id), , drop = FALSE]
  stuck <- df[df$n_sim %in% 0L | is.na(df$n_sim), , drop = FALSE]
  ## Coverage anomalies: |coverage - 0.95| large despite enough reps.
  anom <- df[
    !is.na(df$coverage_primary) &
      df$n_sim >= 50L &
      abs(df$coverage_primary - 0.95) > 0.10,
    ,
    drop = FALSE
  ]

  out <- c("## ISSUES", "")
  if (!nrow(flagged) && !nrow(stuck) && !nrow(anom)) {
    out <- c(
      out,
      "No flagged cells: no fit/non-PD/convergence rate above threshold,",
      "no stuck cells, no large coverage anomalies.",
      ""
    )
    return(out)
  }

  if (nrow(flagged)) {
    out <- c(
      out,
      sprintf(
        "### Cells with high failure / non-PD / convergence rates (%d)",
        nrow(flagged)
      ),
      ""
    )
    for (i in seq_len(nrow(flagged))) {
      out <- c(
        out,
        sprintf(
          "- %s (family=%s, signal=%.1f, n_sim=%d): %s",
          flagged$cell_id[i],
          flagged$family[i],
          flagged$signal[i],
          flagged$n_sim[i],
          flagged$flag[i]
        )
      )
    }
    out <- c(out, "")
  }
  if (nrow(stuck)) {
    out <- c(
      out,
      sprintf("### Stuck cells (no accumulated reps) (%d)", nrow(stuck)),
      ""
    )
    for (i in seq_len(nrow(stuck))) {
      out <- c(
        out,
        sprintf(
          "- %s (family=%s, signal=%.1f)",
          stuck$cell_id[i],
          stuck$family[i],
          stuck$signal[i]
        )
      )
    }
    out <- c(out, "")
  }
  if (nrow(anom)) {
    out <- c(
      out,
      sprintf(
        "### Coverage anomalies (|coverage - 0.95| > 0.10, n_sim >= 50) (%d)",
        nrow(anom)
      ),
      ""
    )
    for (i in seq_len(nrow(anom))) {
      out <- c(
        out,
        sprintf(
          "- %s: coverage=%.3f (n_sim=%d)",
          anom$cell_id[i],
          anom$coverage_primary[i],
          anom$n_sim[i]
        )
      )
    }
    out <- c(out, "")
  }
  out
}

## One-line ASCII issues string for the GHA #340 board, e.g.:
##   "failures: nbinom2-d2-n50-sig0.0 conv-fail 22%; <cell> nonPD 14% (2 cells flagged)"
## Returns "none" when nothing is flagged.
pilot_issue_oneline <- function(df, max_cells = 4L) {
  flagged <- df[nzchar(df$flag %||% ""), , drop = FALSE]
  flagged <- flagged[!is.na(flagged$cell_id), , drop = FALSE]
  if (!nrow(flagged)) {
    return("none")
  }
  show <- utils::head(flagged, max_cells)
  bits <- sprintf("%s %s", show$cell_id, show$flag)
  extra <- if (nrow(flagged) > max_cells) {
    sprintf(" (+%d more)", nrow(flagged) - max_cells)
  } else {
    ""
  }
  sprintf(
    "%s (%d cell%s flagged)%s",
    paste(bits, collapse = "; "),
    nrow(flagged),
    if (nrow(flagged) == 1L) "" else "s",
    extra
  )
}

## =====================================================================
## CLI: print the one-line issues string (for the GHA summary job)
## =====================================================================

if (sys.nframe() == 0L && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  arg_value <- function(flag, default = NULL) {
    hit <- grep(paste0("^", flag, "="), args, value = TRUE)
    if (length(hit)) sub(paste0("^", flag, "="), "", hit[1]) else default
  }
  if ("--emit-issues" %in% args) {
    rdirs <- strsplit(
      arg_value("--results-dir", "dev/m3-pilot-results"),
      ",",
      fixed = TRUE
    )[[1]]
    df <- tryCatch(
      if ("--chunk-aggregate" %in% args) {
        pilot_collect_chunk_aggregates(results_dirs = rdirs)
      } else {
        pilot_collect(results_dirs = rdirs)
      },
      error = function(e) {
        ## Fail-soft: never break the summary job on a report error.
        cat("none\n")
        quit(save = "no", status = 0L)
      }
    )
    cat(pilot_issue_oneline(df), "\n", sep = "")
    quit(save = "no", status = 0L)
  }
  if ("--scoring-audit" %in% args) {
    rdirs <- strsplit(
      arg_value("--results-dir", "dev/m3-pilot-results"),
      ",",
      fixed = TRUE
    )[[1]]
    cells_arg <- arg_value(
      "--cells",
      paste(PILOT_SCORING_AUDIT_CELLS_DEFAULT, collapse = ",")
    )
    cells <- strsplit(cells_arg, ",", fixed = TRUE)[[1]]
    md_path <- arg_value("--audit-out", "dev/m3-pilot-scoring-audit.md")
    rds_path <- arg_value(
      "--audit-rds",
      sub("\\.md$", ".rds", md_path)
    )
    audit_dirs <- if ("--chunk-aggregate" %in% args) {
      pilot_chunk_aggregate_results_dirs(results_dirs = rdirs)
    } else {
      rdirs
    }
    audit <- pilot_scoring_audit(results_dirs = audit_dirs, cell_ids = cells)
    pilot_scoring_audit_record(audit, md_path = md_path, rds_path = rds_path)
    quit(save = "no", status = 0L)
  }
}
