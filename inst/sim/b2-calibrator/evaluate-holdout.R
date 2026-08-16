#!/usr/bin/env Rscript
## Design 118 -- Phase B2, step 2: evaluate the HOLD-OUT gate (s5.6) at the
## frozen calibrated level alpha*(v).
##
## For every hold-out cell (H1/H2/H3, s5.1): interval endpoints are
## RECOMPUTED at alpha*(v) from the STORED per-shard profile-trace sidecars
## via b1_profile_trace_endpoint -- no refitting, s2.4/s3.4 -- with the
## F-AMD fence semantics applied first (s8 DEV-3: refused = screen OR
## attractor-proximity OR root-NA, read off the shard rows; refused
## coordinates are excluded from every denominator per s5.6 "after the
## fence removes refused fits", refusal rates reported per cell; DEV-4:
## the near-saturated band is measured through these per-cell gates). A
## clip-landing alpha* is a refusal, not a clipped interval (s2.4, fence
## line 4 s1.3). Verdicts are s2.5's three-way rule with the one-shot
## escalation for INDETERMINATE hold-out cells; gates are s5.6 G1..G5.
##
## DEV-10 (s8): the 5 H3 cloglog n_site = 192 cells hit pre-existing issue
## #1020; they are reported in a SEPARATE attributed table and never enter
## a pass/fail denominator.
##
## s5.7 rule 1 ("hold-out blocks are read once"): running this script IS
## the hold-out read. --smoke-identity-only runs the plumbing on named
## cells but suppresses every coverage/verdict number (prints only the
## identity-check evidence and row-count plumbing), so an engineering smoke
## does not consume the gate.
##
## Usage:
##   Rscript evaluate-holdout.R --out /path/b1-out --fit /path/b2-calibrator-fit.rds \
##     --out-dir /path/b2-out [--cells B089,B090] [--outer-per-shard 10] \
##     [--reps 600] [--identity-tol 1e-8] [--smoke-identity-only]

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")

args <- commandArgs(trailingOnly = FALSE)
cli_args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name, default = NULL) {
  hit <- match(name, cli_args)
  if (is.na(hit)) return(default)
  if (hit == length(cli_args)) stop("Missing value for ", name, call. = FALSE)
  cli_args[[hit + 1L]]
}
arg_flag <- function(name) name %in% cli_args

file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) {
  normalizePath(sub("^--file=", "", file_arg[[1L]]))
} else {
  normalizePath("evaluate-holdout.R")
}
script_dir <- dirname(script_path)
source(file.path(script_dir, "..", "b0-fence-roc", "lib-b0-fence-roc.R"))
source(file.path(script_dir, "..", "b1-calibration", "lib-b1-calibration.R"))
source(file.path(script_dir, "lib-b2-calibrator.R"))

out_root <- arg_value("--out")
fit_path <- arg_value("--fit")
out_dir <- arg_value("--out-dir")
if (is.null(out_root) || is.null(fit_path) || is.null(out_dir)) {
  stop(
    "Usage: Rscript evaluate-holdout.R --out B1_ROOT --fit b2-calibrator-fit.rds ",
    "--out-dir DIR [--cells B089,...] [--outer-per-shard 10] [--reps 600] ",
    "[--identity-tol 1e-8] [--smoke-identity-only]",
    call. = FALSE
  )
}
outer_per_shard <- as.integer(arg_value("--outer-per-shard", "10"))
reps <- as.integer(arg_value("--reps", "600"))
identity_tol <- as.numeric(arg_value("--identity-tol", "1e-8"))
smoke_only <- arg_flag("--smoke-identity-only")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

grid <- b1_grid()
cells_arg <- arg_value("--cells")
cells <- if (is.null(cells_arg)) {
  grid$cell_id[grid$split == "holdout"]
} else {
  strsplit(cells_arg, ",")[[1L]]
}
## Split assertion (s5.7): a TRAIN cell handed to the hold-out gate aborts.
b2_assert_holdout_cells(cells, grid)

fit <- readRDS(fit_path)
alpha <- fit$alpha
spec <- list(
  rung = fit$profile$selected, gamma = fit$profile$gamma, terms = fit$profile$terms
)
message(sprintf(
  "Frozen map: mode = %s, profile rung = %s, gamma: %s (alpha = %.3f; clip [%.2f, %.2f] = refusal)",
  fit$mode, spec$rung,
  if (length(spec$gamma)) paste(names(spec$gamma), sprintf("%.6f", spec$gamma), collapse = ", ") else "(none: alpha* = alpha)",
  alpha, b2_alpha_clip[[1L]], b2_alpha_clip[[2L]]
))

dev10 <- b2_dev10_cells(grid)
shard_dir <- file.path(out_root, "shards")
sidecar_dir <- file.path(out_root, "sidecars")
shards_per_cell <- b1_shards_per_cell(outer_per_shard, reps)

## ---- Completeness (mirrors consolidate-b1.R fix 6): a silently short ----
## hold-out cell must never look like a valid gate result ------------------
problems <- character(0)
for (cid in cells) {
  for (sid in seq_len(shards_per_cell)) {
    fname <- sprintf("%s-shard-%03d.csv", cid, sid)
    fpath <- file.path(shard_dir, fname)
    if (!file.exists(fpath)) {
      problems <- c(problems, sprintf("MISSING: %s", fname))
      next
    }
    first_outer <- (sid - 1L) * outer_per_shard + 1L
    last_outer <- min(sid * outer_per_shard, reps)
    expected_rows <- (last_outer - first_outer + 1L) * 3L
    n_rows <- tryCatch(
      nrow(utils::read.csv(fpath, stringsAsFactors = FALSE)),
      error = function(e) NA_integer_
    )
    if (is.na(n_rows) || n_rows != expected_rows) {
      problems <- c(problems, sprintf(
        "SHORT: %s (%s rows, expected %d)", fname,
        if (is.na(n_rows)) "unreadable" else n_rows, expected_rows
      ))
    }
  }
}
if (length(problems)) {
  cat("COMPLETENESS FAILED for the requested hold-out cells:\n")
  cat(paste(" -", problems, collapse = "\n"), "\n")
  cat("Refusing to evaluate the gate on incomplete data.\n")
  quit(save = "no", status = 1L)
}
message(sprintf("Completeness OK: %d cell(s) x %d shards.", length(cells), shards_per_cell))

## ---- Per-cell evaluation --------------------------------------------------
identity_max <- 0
identity_n <- 0L
identity_avail_mismatch <- 0L
cell_target_rows <- list()
cell_rows <- list()

for (cid in cells) {
  crow <- b1_cell_row(cid, grid = grid)
  if (crow$n_trait[[1L]] != 3L) {
    stop(
      "Hold-out cell ", cid, " has n_trait != 3; pi_max-from-target-rows is ",
      "only exact when the 3 calibration targets are ALL traits (DEV-7).",
      call. = FALSE
    )
  }
  rows <- do.call(rbind, lapply(seq_len(shards_per_cell), function(sid) {
    utils::read.csv(
      file.path(shard_dir, sprintf("%s-shard-%03d.csv", cid, sid)),
      stringsAsFactors = FALSE
    )
  }))
  if (!all(rows$split %in% "holdout")) {
    stop("SPLIT VIOLATION: cell ", cid, " carries non-holdout rows in its shards.", call. = FALSE)
  }
  n_total <- nrow(rows)
  ok <- rows$status %in% "ok"
  rows_ok <- rows[ok, , drop = FALSE]

  ## s2.1 #2: pi_max over all traits, exact from the 3 target rows (T = 3).
  key <- paste(rows_ok$outer_id)
  agg <- tapply(pmax(rows_ok$k / rows_ok$n_obs, 1 - rows_ok$k / rows_ok$n_obs), key, max)
  rows_ok$pi_max <- as.numeric(agg[paste(rows_ok$outer_id)])

  ## F-AMD fence (s8 DEV-3): refusal read off the shard rows.
  refused <- rows_ok$refused %in% TRUE
  adm <- rows_ok[!refused, , drop = FALSE]

  ## Calibrated level per admitted coordinate; clip = refusal (fence line 4).
  as_ <- b2_map_alpha_star(spec, adm[, c("c_n", "pi_max", "s_j", "link")], alpha)
  adm$alpha_star <- as_$alpha_star
  adm$clip_refused <- as_$clip_refused

  ## Recompute endpoints at alpha*(v) from the stored traces (s2.4: no
  ## refitting). The nominal-level identity check runs on every admitted
  ## row: re-thresholding the SAME stored trace at alpha must reproduce the
  ## shard's stored endpoints exactly (availability pattern included).
  adm$cal_lower <- NA_real_
  adm$cal_upper <- NA_real_
  adm$cal_available <- FALSE
  adm$cal_covered <- NA
  trace_cache_sid <- -1L
  trace_all <- NULL
  o <- order(adm$shard_id, adm$outer_id, adm$target)
  for (r in o[!adm$clip_refused[o]]) {
    sid <- adm$shard_id[[r]]
    if (sid != trace_cache_sid) {
      tf <- file.path(sidecar_dir, sprintf("%s-shard-%03d-profile-trace.csv", cid, sid))
      trace_all <- if (file.exists(tf)) utils::read.csv(tf, stringsAsFactors = FALSE) else NULL
      trace_cache_sid <- sid
    }
    tr <- if (is.null(trace_all)) NULL else trace_all[
      trace_all$outer_id == adm$outer_id[[r]] &
        trace_all$calibration_target == adm$target[[r]], , drop = FALSE
    ]
    if (is.null(tr) || !nrow(tr)) next ## profile never produced a trace -> unavailable
    ## Identity check at the nominal level.
    ep0 <- b2_profile_endpoints_at(tr, alpha)
    stored <- c(adm$profile_lower[[r]], adm$profile_upper[[r]])
    if (is.finite(stored[[1L]]) && is.finite(stored[[2L]])) {
      d <- max(abs(ep0[["lower"]] - stored[[1L]]), abs(ep0[["upper"]] - stored[[2L]]))
      if (!is.finite(d) || d > identity_tol) {
        stop(sprintf(
          "IDENTITY CHECK FAILED (%s outer %d target %d): nominal re-threshold [%.10g, %.10g] vs stored [%.10g, %.10g]",
          cid, adm$outer_id[[r]], adm$target[[r]], ep0[["lower"]], ep0[["upper"]],
          stored[[1L]], stored[[2L]]
        ), call. = FALSE)
      }
      identity_max <- max(identity_max, d)
      identity_n <- identity_n + 1L
    } else if (is.finite(ep0[["lower"]]) && is.finite(ep0[["upper"]])) {
      identity_avail_mismatch <- identity_avail_mismatch + 1L
    }
    ## The calibrated endpoints (the gate's own numbers).
    ep <- b2_profile_endpoints_at(tr, adm$alpha_star[[r]])
    adm$cal_lower[[r]] <- ep[["lower"]]
    adm$cal_upper[[r]] <- ep[["upper"]]
    adm$cal_available[[r]] <- is.finite(ep[["lower"]]) && is.finite(ep[["upper"]])
    if (adm$cal_available[[r]]) {
      adm$cal_covered[[r]] <- adm$truth[[r]] >= ep[["lower"]] && adm$truth[[r]] <= ep[["upper"]]
    }
  }

  ## Per-(cell, target) summary (s2.5 grain, INT-G1).
  for (slot in unique(rows_ok$target_slot)) {
    ro <- rows_ok[rows_ok$target_slot == slot, , drop = FALSE]
    ad <- adm[adm$target_slot == slot, , drop = FALSE]
    n_reps <- nrow(ro)
    n_fence_refused <- sum(ro$refused %in% TRUE)
    n_clip_refused <- sum(ad$clip_refused %in% TRUE)
    n_refused <- n_fence_refused + n_clip_refused
    admitted <- ad[!ad$clip_refused, , drop = FALSE]
    n_admitted <- nrow(admitted)
    n_avail <- sum(admitted$cal_available %in% TRUE)
    n_cov <- sum(admitted$cal_covered %in% TRUE)
    phat <- if (n_avail) n_cov / n_avail else NA_real_
    ci <- b2_wilson_ci(n_cov, n_avail)
    v0 <- b2_verdict(phat, ci)
    esc <- b2_apply_escalation(v0, n_reps)
    ## Chain-availability supplement: the s3.5 fallback chain's availability
    ## is level-independent for the bootstrap (usable-count floor), so it is
    ## measurable exactly on the 1-in-3 subset from the shard flags.
    sub <- admitted[admitted$in_bootstrap_subset %in% TRUE, , drop = FALSE]
    chain_avail <- if (nrow(sub)) {
      mean(sub$cal_available %in% TRUE | sub$bootstrap_available %in% TRUE)
    } else {
      NA_real_
    }
    cell_target_rows[[paste(cid, slot)]] <- data.frame(
      cell_id = cid, block = crow$block[[1L]], link = crow$link[[1L]],
      pi_target = crow$pi_target[[1L]], n_site = crow$n_site[[1L]],
      q = crow$q[[1L]], target_slot = slot,
      attributed_1020 = cid %in% dev10, gate_eligible = !(cid %in% dev10),
      n_rows_total = sum(rows$target_slot == slot), n_reps_ok = n_reps,
      n_fence_refused = n_fence_refused, n_clip_refused = n_clip_refused,
      refusal_rate = if (n_reps) n_refused / n_reps else NA_real_,
      n_refused_screen = sum(ro$refusal_reason %in% "screen"),
      n_refused_proximity = sum(ro$refusal_reason %in% "proximity"),
      n_refused_root_na = sum(ro$refusal_reason %in% "root_na"),
      alpha_star_median = stats::median(ad$alpha_star, na.rm = TRUE),
      n_admitted = n_admitted, n_available = n_avail,
      availability = if (n_admitted) n_avail / n_admitted else NA_real_,
      chain_availability_subset = chain_avail,
      n_covered = n_cov, coverage = phat,
      wilson_lo = ci[[1L]], wilson_hi = ci[[2L]],
      verdict = esc$verdict, escalate_to_2000 = esc$escalate_to_2000,
      stringsAsFactors = FALSE
    )
  }

  ## Per-cell availability (s5.6 G3 is per hold-out cell) + refusal rate.
  admitted_all <- adm[!adm$clip_refused, , drop = FALSE]
  cell_rows[[cid]] <- data.frame(
    cell_id = cid, block = crow$block[[1L]], link = crow$link[[1L]],
    pi_target = crow$pi_target[[1L]], n_site = crow$n_site[[1L]], q = crow$q[[1L]],
    attributed_1020 = cid %in% dev10, gate_eligible = !(cid %in% dev10),
    n_rows_total = n_total, n_ok = nrow(rows_ok), n_not_ok = n_total - nrow(rows_ok),
    n_refused = sum(refused) + sum(adm$clip_refused %in% TRUE),
    refusal_rate = if (nrow(rows_ok)) {
      (sum(refused) + sum(adm$clip_refused %in% TRUE)) / nrow(rows_ok)
    } else {
      NA_real_
    },
    availability = if (nrow(admitted_all)) {
      mean(admitted_all$cal_available %in% TRUE)
    } else {
      NA_real_
    },
    stringsAsFactors = FALSE
  )
  message(sprintf(
    "  %s (%s %s pi=%.2f n_site=%d q=%d)%s: %d rows, %d ok%s",
    cid, crow$block[[1L]], crow$link[[1L]], crow$pi_target[[1L]],
    crow$n_site[[1L]], crow$q[[1L]],
    if (cid %in% dev10) " [DEV-10 ATTRIBUTED #1020]" else "",
    n_total, nrow(rows_ok),
    if (smoke_only) "" else sprintf(
      ", refusal %.3f, availability %.3f",
      cell_rows[[cid]]$refusal_rate, cell_rows[[cid]]$availability
    )
  ))
}

summary_all <- do.call(rbind, cell_target_rows)
cells_all <- do.call(rbind, cell_rows)
rownames(summary_all) <- rownames(cells_all) <- NULL

cat(sprintf(
  "\nIDENTITY CHECK (s2.4 re-thresholding, alpha* = alpha): %d rows compared; max |recomputed - stored| = %.3g (tol %.1g); availability-pattern mismatches: %d\n",
  identity_n, identity_max, identity_tol, identity_avail_mismatch
))
if (identity_avail_mismatch > 0) {
  stop("Nominal availability-pattern mismatch: trace re-threshold and stored endpoints disagree on availability.", call. = FALSE)
}

if (smoke_only) {
  cat("\n--smoke-identity-only: coverage, verdicts, and gates are SUPPRESSED (s5.7 rule 1: the hold-out gate is read once, after the map freeze).\n")
  cat(sprintf(
    "Plumbing exercised: %d cell(s), %d (cell,target) summaries, %d per-cell rows computed and discarded.\n",
    length(cells), nrow(summary_all), nrow(cells_all)
  ))
  quit(save = "no", status = 0L)
}

## ---- Gate evaluation (s5.6), DEV-10 excluded from every denominator ------
eligible <- summary_all[summary_all$gate_eligible, , drop = FALSE]
attributed <- summary_all[summary_all$attributed_1020, , drop = FALSE]
cells_eligible <- cells_all[cells_all$gate_eligible, , drop = FALSE]
cells_attributed <- cells_all[cells_all$attributed_1020, , drop = FALSE]

## G4 anchors (s5.6: "well-identified anchors (pi = 0.50, largest n_site)"):
## pi_target = 0.50 cells at the largest n_site within their (block, q)
## among gate-eligible hold-out cells. INTERPRETATION (flagged): s5.6 does
## not say largest-overall vs largest-per-block; per-block keeps every
## hold-out block's anchor in view.
anch <- cells_eligible[cells_eligible$pi_target == 0.50, , drop = FALSE]
if (nrow(anch)) {
  key <- paste(anch$block, anch$q)
  keep <- unlist(lapply(split(seq_len(nrow(anch)), key), function(ix) {
    ix[anch$n_site[ix] == max(anch$n_site[ix])]
  }))
  anch <- anch[sort(keep), , drop = FALSE]
}

g <- b2_gates(
  summary = eligible, cell_avail = cells_eligible, anchors = anch,
  sign_ok = isTRUE(fit$sign_ok)
)

## ---- Outputs --------------------------------------------------------------
verdict_path <- file.path(out_dir, "b2-holdout-verdict.csv")
utils::write.csv(eligible, verdict_path, row.names = FALSE, na = "NA")
attr_path <- file.path(out_dir, "b2-holdout-attributed-1020.csv")
utils::write.csv(
  merge(cells_attributed, attributed, all = TRUE,
    by = c("cell_id", "block", "link", "pi_target", "n_site", "q", "attributed_1020", "gate_eligible")),
  attr_path, row.names = FALSE, na = "NA"
)

summarize <- c(
  "==== Design 118 s5.6 HOLD-OUT GATE VERDICT (gate-eligible cells only; DEV-10 attributed separately) ====",
  sprintf("Cells evaluated: %d eligible + %d DEV-10-attributed (#1020); (cell,target) verdict rows: %d",
    nrow(cells_eligible), nrow(cells_attributed), nrow(eligible)),
  sprintf("Verdicts: PASS %d | FAIL %d | INDETERMINATE %d | NO_DATA %d",
    sum(eligible$verdict == "PASS"), sum(eligible$verdict == "FAIL"),
    sum(eligible$verdict == "INDETERMINATE"), sum(eligible$verdict == "NO_DATA")),
  sprintf("G1 (>= 90%% of hold-out (cell,target) rows PASS, s5.6): %.1f%% -> %s%s",
    100 * g$g1_frac_pass, if (g$g1_ok) "MEETS G1" else "FAILS G1",
    if (g$pending_escalation) " [PROVISIONAL: escalation pending]" else ""),
  sprintf("G2 (no hold-out coverage < 0.90, s5.6): %s",
    if (g$g2_ok) "MEETS G2" else "FAILS G2 -- C011-class guard tripped"),
  sprintf("G3 (availability >= 0.95 per hold-out cell among non-refused fits, s5.6): %s (min cell availability %.4f)",
    if (g$g3_ok) "MEETS G3" else "FAILS G3", suppressWarnings(min(cells_eligible$availability, na.rm = TRUE))),
  sprintf("G4 (refusal rate <= 0.10 in anchors [%s], s5.6): %s",
    paste(anch$cell_id, collapse = ", "), if (g$g4_ok) "MEETS G4" else "FAILS G4"),
  sprintf("G5 (every fitted gamma_k carries its registered sign, s2.3/s5.6): %s",
    if (g$g5_ok) "MEETS G5" else "FAILS G5"),
  if (any(eligible$escalate_to_2000)) {
    sprintf("ESCALATE (s2.5 one-shot, n -> 2000) for hold-out (cell,target): %s",
      paste(unique(eligible$cell_id[eligible$escalate_to_2000]), collapse = ", "))
  } else {
    "No INDETERMINATE cells: no escalation needed."
  },
  sprintf("DEV-10 attributed cells (issue #1020; never in the denominators): %s -> %s",
    paste(dev10, collapse = ", "), attr_path),
  sprintf("Identity check: %d rows, max |diff| %.3g", identity_n, identity_max),
  sprintf("Wrote %s", verdict_path)
)
cat(paste(summarize, collapse = "\n"), "\n")
writeLines(summarize, file.path(out_dir, "b2-holdout-summary.txt"))
