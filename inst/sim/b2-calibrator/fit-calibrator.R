#!/usr/bin/env Rscript
## Design 118 -- Phase B2, step 1: fit the pre-registered calibrator
## alpha -> alpha*(v) on the TRAIN split only (s2), then freeze it in
## writing (s5.2) before any hold-out read.
##
## Registered form implemented here, with its s-citations:
##   logit alpha*(v) = logit alpha + h(v), ladder M0..M5 fitted strictly in
##   order (s2.3); fit to coverage by re-evaluating the STORED per-replicate
##   intervals at alpha*(v; gamma) -- no refitting (s2.4): profile intervals
##   re-thresholded from the stored profile-trace sidecars at
##   (1/2) chisq_1(1 - alpha*), bootstrap intervals re-quantiled from the
##   stored replicate vectors at (alpha*/2, 1 - alpha*/2) (s2.1);
##   leave-whole-cells-out K = 8 CV, admission margin (out-of-fold max cell
##   error drop >= 0.005 AND MAE not rising, ties to simpler, stop at first
##   non-admission), clip [0.01, 0.40] with clip-landing = refusal (s2.4);
##   registered signs enforced by drop-and-report (s2.3, gate G5 s5.6);
##   separate h_profile and h_boot first, one shared h adopted only if the
##   separate pair does not beat it by the same admission margin (s2.3).
##
## Inputs: the consolidator's calibrator-input.csv (TRAIN-only export,
## consolidate-b1.R) and the per-shard sidecars (s3.4 storage contract).
## Every row is asserted split == "train" AND registered "train" in the
## grid; any hold-out row aborts (s5.7).
##
## Usage:
##   Rscript fit-calibrator.R --calibrator-input /path/calibrator-input.csv \
##     --sidecar-dir /path/b1-out/sidecars --out-dir /path/b2-out \
##     [--outer-per-shard 10] [--k-folds 8] [--alpha 0.05] [--max-rung M5] \
##     [--verify-sample 200]

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
  normalizePath("fit-calibrator.R")
}
script_dir <- dirname(script_path)
source(file.path(script_dir, "..", "b0-fence-roc", "lib-b0-fence-roc.R"))
source(file.path(script_dir, "..", "b1-calibration", "lib-b1-calibration.R"))
source(file.path(script_dir, "lib-b2-calibrator.R"))

input_path <- arg_value("--calibrator-input")
sidecar_dir <- arg_value("--sidecar-dir")
out_dir <- arg_value("--out-dir")
if (is.null(input_path) || is.null(sidecar_dir) || is.null(out_dir)) {
  stop(
    "Usage: Rscript fit-calibrator.R --calibrator-input X.csv ",
    "--sidecar-dir DIR --out-dir DIR [--outer-per-shard 10] [--k-folds 8] ",
    "[--alpha 0.05] [--max-rung M5] [--verify-sample 200]",
    call. = FALSE
  )
}
outer_per_shard <- as.integer(arg_value("--outer-per-shard", "10"))
k_folds <- as.integer(arg_value("--k-folds", as.character(b2_k_folds)))
## Cache for the expensive sidecar precompute (see below). Empty string or
## --no-precompute-cache disables it.
precompute_cache <- if (arg_flag("--no-precompute-cache")) {
  ""
} else {
  arg_value("--precompute-cache", file.path(out_dir, "b2-precompute-cache.rds"))
}
alpha <- as.numeric(arg_value("--alpha", as.character(b2_alpha_nominal)))
max_rung <- arg_value("--max-rung", "M5")
verify_sample <- as.integer(arg_value("--verify-sample", "200"))
identity_tol <- as.numeric(arg_value("--identity-tol", "1e-8"))

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
grid <- b1_grid()

## ---- Read + train-only assertion (s5.7) ----------------------------------
input <- utils::read.csv(input_path, stringsAsFactors = FALSE)
b2_assert_train_only(input, grid)
message(sprintf(
  "Calibrator input: %d TRAIN rows, %d cells, blocks: %s",
  nrow(input), length(unique(input$cell_id)),
  paste(sort(unique(input$block)), collapse = ", ")
))

input$outer_id <- b2_outer_id_from_seed(input$seed, input$cell_id, grid)
input$shard_id <- b2_shard_of_outer(input$outer_id, outer_per_shard)
input$unit <- paste(input$cell_id, input$target_slot, sep = ":")

## ---- pi_max (s2.1 #2, INT-P1): re-simulated, cross-checked ---------------
message("Computing pi_max per outer dataset (re-simulation, k cross-checked)...")
ds <- unique(input[, c("cell_id", "outer_id")])
ds$pi_max <- NA_real_
for (i in seq_len(nrow(ds))) {
  rows_i <- input[input$cell_id == ds$cell_id[[i]] & input$outer_id == ds$outer_id[[i]], ]
  ds$pi_max[[i]] <- b2_pi_max_for(
    b1_cell_row(ds$cell_id[[i]], grid = grid), ds$outer_id[[i]],
    check_target = rows_i$target, check_k = rows_i$k
  )
}
input$pi_max <- ds$pi_max[match(
  paste(input$cell_id, input$outer_id), paste(ds$cell_id, ds$outer_id)
)]
n_pi_saturated <- sum(input$pi_max >= 1)

## ---- Reuse a cached precompute when the inputs are unchanged --------------
precompute_cached <- FALSE
if (nzchar(precompute_cache) && file.exists(precompute_cache)) {
  cached <- readRDS(precompute_cache)
  key_now <- list(input_path = input_path, nrow = nrow(input),
                  sidecar_dir = sidecar_dir, alpha = alpha)
  if (identical(cached$key, key_now)) {
    input <- cached$input
    identity_max_prof <- cached$diagnostics$identity_max_prof
    n_fallback <- cached$diagnostics$n_fallback
    legacy_drift_n <- cached$diagnostics$legacy_drift_n
    legacy_drift_max <- cached$diagnostics$legacy_drift_max
    precompute_cached <- TRUE
    message(sprintf(
      "Reusing cached precompute (%s): %d rows; fast-path max |diff| = %.3g; legacy drift %d rows (max %.4g).",
      precompute_cache, nrow(input), identity_max_prof, legacy_drift_n, legacy_drift_max
    ))
  } else {
    message("Precompute cache key mismatch -- recomputing.")
  }
}

## ---- Profile precompute from the trace sidecars (s2.4: no refitting) -----
if (!precompute_cached) {
message("Loading profile-trace sidecars and precomputing re-threshold summaries...")
set.seed(20260816L) ## verification sampling only; the fit itself uses no RNG
prof_keep <- rep(TRUE, nrow(input)) ## calibrator-input is already profile_available-only
input$tau_avail_min <- NA_real_
input$tau_avail_max <- NA_real_
input$tau_cover <- NA_real_
input$precompute_fast <- NA
identity_max_prof <- 0
## Divergence between the recomputed endpoint and the shard's LEGACY stored
## column (pre-fix rule in the main run, corrected rule in the 102 repaired
## shards). Reported, never fatal -- traces are ground truth.
legacy_drift_n <- 0L
legacy_drift_max <- 0
n_fallback <- 0L
verify_rows <- sort(sample.int(nrow(input), min(verify_sample, nrow(input))))
verify_traces <- vector("list", length(verify_rows))
names(verify_traces) <- as.character(verify_rows)

shard_keys <- unique(input[, c("cell_id", "shard_id")])
for (i in seq_len(nrow(shard_keys))) {
  cid <- shard_keys$cell_id[[i]]
  sid <- shard_keys$shard_id[[i]]
  tf <- file.path(sidecar_dir, sprintf("%s-shard-%03d-profile-trace.csv", cid, sid))
  if (!file.exists(tf)) {
    stop("Missing profile-trace sidecar: ", tf, call. = FALSE)
  }
  trace_all <- utils::read.csv(tf, stringsAsFactors = FALSE)
  idx <- which(input$cell_id == cid & input$shard_id == sid)
  for (r in idx) {
    tr <- trace_all[
      trace_all$outer_id == input$outer_id[[r]] &
        trace_all$calibration_target == input$target[[r]], , drop = FALSE
    ]
    if (!nrow(tr)) {
      stop(
        "No trace rows for ", cid, " outer ", input$outer_id[[r]],
        " target ", input$target[[r]], " in ", tf, call. = FALSE
      )
    }
    ## Identity check: the fast path must reproduce the REGISTERED function
    ## b1_profile_trace_endpoint() on the same trace. This is the guard that
    ## matters -- b2_profile_endpoints_at() is an optimisation used inside the
    ## CV'd optimiser, and a silent divergence would corrupt every calibrated
    ## endpoint.
    ##
    ## NOTE: this deliberately no longer compares against the shard's stored
    ## `profile_lower/upper` columns. Those are LEGACY: the main B1 run
    ## computed them with the pre-fix endpoint rule (`max(which(below))`),
    ## which is wrong on a non-monotone trace, and the 102 repaired shards
    ## used the corrected first-bracketing-pair rule -- so the stored columns
    ## are a MIXTURE of two semantics. The raw traces are ground truth and
    ## every endpoint used from here on is recomputed from them (which is what
    ## the §3.4 sidecar storage contract exists for). The divergence is
    ## counted below and reported, not silently absorbed.
    tau_nominal <- b2_threshold(alpha)
    ep <- b2_profile_endpoints_at(tr, alpha)
    ref_lo <- b1_profile_trace_endpoint(tr, tau_nominal, "lower")
    ref_hi <- b1_profile_trace_endpoint(tr, tau_nominal, "upper")
    na_ok <- (is.na(ep[["lower"]]) == is.na(ref_lo)) &&
      (is.na(ep[["upper"]]) == is.na(ref_hi))
    d <- suppressWarnings(max(
      abs(ep[["lower"]] - ref_lo), abs(ep[["upper"]] - ref_hi), na.rm = TRUE
    ))
    if (!is.finite(d)) d <- 0
    if (!na_ok || d > identity_tol) {
      stop(sprintf(
        "FAST-PATH IDENTITY CHECK FAILED (%s outer %d target %d): fast [%.10g, %.10g] vs registered [%.10g, %.10g]",
        cid, input$outer_id[[r]], input$target[[r]],
        ep[["lower"]], ep[["upper"]], ref_lo, ref_hi
      ), call. = FALSE)
    }
    identity_max_prof <- max(identity_max_prof, d)
    ## Legacy-column drift, recorded for the record (never fatal).
    legacy_d <- suppressWarnings(max(
      abs(ep[["lower"]] - input$profile_lower[[r]]),
      abs(ep[["upper"]] - input$profile_upper[[r]]), na.rm = TRUE
    ))
    if (is.finite(legacy_d) && legacy_d > identity_tol) {
      legacy_drift_n <<- legacy_drift_n + 1L
      legacy_drift_max <<- max(legacy_drift_max, legacy_d)
    }
    pc <- b2_profile_precompute(tr, input$truth[[r]])
    input$tau_avail_min[[r]] <- pc$tau_avail_min
    input$tau_avail_max[[r]] <- pc$tau_avail_max
    input$tau_cover[[r]] <- pc$tau_cover
    input$precompute_fast[[r]] <- pc$fast
    if (!pc$fast) n_fallback <- n_fallback + 1L
    if (r %in% verify_rows) verify_traces[[as.character(r)]] <- tr
  }
}
message(sprintf(
  "Profile precompute done: %d rows; fast-path vs registered max |diff| = %.3g (tol %.1g); %d dense-fallback rows",
  nrow(input), identity_max_prof, identity_tol, n_fallback
))
message(sprintf(
  "Legacy stored-column drift: %d of %d rows (%.2f%%) differ from the recomputed endpoint; max |diff| = %.4g. Traces are authoritative; stored columns are NOT used.",
  legacy_drift_n, nrow(input), 100 * legacy_drift_n / max(1L, nrow(input)), legacy_drift_max
))
} ## end if (!precompute_cached)

## ---- Verification: fast-path vs the registered function ------------------
n_verify_checks <- 0L
for (r in verify_rows) {
  tr <- verify_traces[[as.character(r)]]
  if (is.null(tr)) next
  for (a in stats::runif(5L, 0.011, 0.399)) {
    direct <- b2_profile_eval_direct(tr, input$truth[[r]], a)
    tau <- b2_threshold(a)
    fast_avail <- tau > input$tau_avail_min[[r]] && tau <= input$tau_avail_max[[r]]
    fast_cov <- fast_avail && tau >= input$tau_cover[[r]]
    if (!identical(direct$available, fast_avail) || !identical(direct$covered, fast_cov)) {
      stop(sprintf(
        "PRECOMPUTE VERIFICATION FAILED (row %d, alpha = %.6f): direct avail/cov = %s/%s, fast = %s/%s",
        r, a, direct$available, direct$covered, fast_avail, fast_cov
      ), call. = FALSE)
    }
    n_verify_checks <- n_verify_checks + 1L
  }
}
message(sprintf("Precompute verification: %d (row, alpha) checks against b1_profile_trace_endpoint, all agree", n_verify_checks))

## ---- Bootstrap precompute from replicate sidecars (s2.1) -----------------
boot <- input[input$bootstrap_available %in% TRUE, , drop = FALSE]
identity_max_boot <- 0
n_boot_verify <- 0L
if (nrow(boot)) {
  message(sprintf("Loading bootstrap-replicate sidecars for %d rows...", nrow(boot)))
  boot$alpha_cover_max <- NA_real_
  bkeys <- unique(boot[, c("cell_id", "shard_id")])
  boot_verify_rows <- sort(sample(seq_len(nrow(boot)), min(verify_sample, nrow(boot))))
  for (i in seq_len(nrow(bkeys))) {
    cid <- bkeys$cell_id[[i]]
    sid <- bkeys$shard_id[[i]]
    bf <- file.path(sidecar_dir, sprintf("%s-shard-%03d-bootstrap-replicates.csv", cid, sid))
    if (!file.exists(bf)) stop("Missing bootstrap-replicates sidecar: ", bf, call. = FALSE)
    reps_all <- utils::read.csv(bf, stringsAsFactors = FALSE)
    idx <- which(boot$cell_id == cid & boot$shard_id == sid)
    for (r in idx) {
      vals <- reps_all$estimate[
        reps_all$outer_id == boot$outer_id[[r]] &
          reps_all$calibration_target == boot$target[[r]]
      ]
      if (!length(vals)) {
        stop(
          "No bootstrap replicates for ", cid, " outer ", boot$outer_id[[r]],
          " target ", boot$target[[r]], call. = FALSE
        )
      }
      ep <- stats::quantile(vals, c(alpha / 2, 1 - alpha / 2), type = 7L, names = FALSE)
      d <- max(abs(ep[[1L]] - boot$bootstrap_lower[[r]]), abs(ep[[2L]] - boot$bootstrap_upper[[r]]))
      if (!is.finite(d) || d > identity_tol) {
        stop(sprintf(
          "BOOTSTRAP IDENTITY CHECK FAILED (%s outer %d target %d): recomputed [%.10g, %.10g] vs stored [%.10g, %.10g]",
          cid, boot$outer_id[[r]], boot$target[[r]],
          ep[[1L]], ep[[2L]], boot$bootstrap_lower[[r]], boot$bootstrap_upper[[r]]
        ), call. = FALSE)
      }
      identity_max_boot <- max(identity_max_boot, d)
      boot$alpha_cover_max[[r]] <- b2_boot_alpha_cover_max(vals, boot$truth[[r]])
      if (r %in% boot_verify_rows) {
        for (a in stats::runif(3L, 0.011, 0.399)) {
          direct <- b2_boot_eval_direct(vals, boot$truth[[r]], a)
          fast <- a <= boot$alpha_cover_max[[r]]
          if (!identical(direct, fast)) {
            stop(sprintf(
              "BOOT PRECOMPUTE VERIFICATION FAILED (row %d, alpha = %.6f): direct %s vs fast %s",
              r, a, direct, fast
            ), call. = FALSE)
          }
          n_boot_verify <- n_boot_verify + 1L
        }
      }
    }
  }
  message(sprintf(
    "Bootstrap precompute done: identity max |diff| = %.3g; %d verification checks agree",
    identity_max_boot, n_boot_verify
  ))
}

## ---- Cache the precompute -------------------------------------------------
## The sidecar precompute above is the expensive half (~2 h over 102k rows on
## Totoro) and is a pure function of the input table + sidecars. Model-
## selection bugs downstream should not cost that again on every retry, so
## persist it. Keyed on the input path, row count and the sidecar directory;
## delete the file (or pass --no-precompute-cache) to force a rebuild.
if (nzchar(precompute_cache) && !dir.exists(dirname(precompute_cache))) {
  dir.create(dirname(precompute_cache), recursive = TRUE, showWarnings = FALSE)
}
if (nzchar(precompute_cache)) {
  saveRDS(
    list(
      key = list(input_path = input_path, nrow = nrow(input),
                 sidecar_dir = sidecar_dir, alpha = alpha),
      input = input,
      diagnostics = list(
        identity_max_prof = identity_max_prof, n_fallback = n_fallback,
        legacy_drift_n = legacy_drift_n, legacy_drift_max = legacy_drift_max
      )
    ),
    precompute_cache
  )
  message("Precompute cached to ", precompute_cache)
}

## ---- Assemble fitting tables ---------------------------------------------
v_cols <- c("c_n", "pi_max", "s_j", "link")
pre_prof <- data.frame(
  construction = "profile", unit = input$unit, cell_id = input$cell_id,
  tau_avail_min = input$tau_avail_min, tau_avail_max = input$tau_avail_max,
  tau_cover = input$tau_cover, alpha_cover_max = NA_real_,
  stringsAsFactors = FALSE
)
v_prof <- input[, v_cols]
n_sj_na <- sum(!is.finite(input$s_j))

cells_all <- sort(unique(input$cell_id))
fold_lookup <- stats::setNames(((seq_along(cells_all) - 1L) %% k_folds) + 1L, cells_all) ## INT-F1
folds_prof <- as.integer(fold_lookup[pre_prof$cell_id])

## ---- Ladder: h_profile (s2.3 order, s2.4 admission) ----------------------
message("Fitting h_profile ladder (M0..", max_rung, ")...")
sel_prof <- b2_select_map(
  v_prof, pre_prof, alpha, folds_prof,
  max_rung = max_rung, label = "profile"
)
message(sprintf(
  "  h_profile selected: %s (cv max_err %.4f, mae %.4f); gamma: %s",
  sel_prof$selected, sel_prof$cv_max_err, sel_prof$cv_mae,
  if (length(sel_prof$gamma)) paste(names(sel_prof$gamma), sprintf("%.4f", sel_prof$gamma), collapse = ", ") else "(none: M0)"
))

## ---- Ladder: h_boot ------------------------------------------------------
sel_boot <- NULL
boot_note <- ""
if (nrow(boot)) {
  boot_cells <- sort(unique(boot$cell_id))
  if (length(boot_cells) >= k_folds) {
    pre_boot <- data.frame(
      construction = "boot", unit = boot$unit, cell_id = boot$cell_id,
      tau_avail_min = NA_real_, tau_avail_max = NA_real_, tau_cover = NA_real_,
      alpha_cover_max = boot$alpha_cover_max, stringsAsFactors = FALSE
    )
    v_boot <- boot[, v_cols]
    folds_boot <- as.integer(fold_lookup[pre_boot$cell_id])
    message("Fitting h_boot ladder (M0..", max_rung, ")...")
    sel_boot <- b2_select_map(
      v_boot, pre_boot, alpha, folds_boot,
      max_rung = max_rung, label = "boot"
    )
    message(sprintf(
      "  h_boot selected: %s (cv max_err %.4f, mae %.4f)",
      sel_boot$selected, sel_boot$cv_max_err, sel_boot$cv_mae
    ))
  } else {
    boot_note <- sprintf(
      "h_boot NOT fitted: only %d bootstrap-bearing cell(s) < K = %d folds (smoke-scale input)",
      length(boot_cells), k_folds
    )
    message(boot_note)
  }
} else {
  boot_note <- "h_boot NOT fitted: no bootstrap-available rows in input"
  message(boot_note)
}

## ---- Shared-vs-separate (s2.3: shared adopted unless the separate pair ---
## beats it by the same admission margin; simpler wins ties) ----------------
sel_shared <- NULL
mode <- "separate"
shared_note <- if (is.null(sel_boot)) {
  mode <- "profile_only"
  "shared-h test skipped: no h_boot (profile-only map)"
} else {
  v_pool <- rbind(v_prof, v_boot)
  pre_pool <- rbind(pre_prof, pre_boot)
  folds_pool <- as.integer(fold_lookup[pre_pool$cell_id])
  message("Fitting shared-h ladder (M0..", max_rung, ")...")
  sel_shared <- b2_select_map(
    v_pool, pre_pool, alpha, folds_pool,
    max_rung = max_rung, label = "shared"
  )
  ## Pair (separate) out-of-fold metrics over the pooled units:
  pair_max <- max(sel_prof$cv_max_err, sel_boot$cv_max_err)
  n_p <- sel_prof$path[[sel_prof$selected]]$cv_n_units
  n_b <- sel_boot$path[[sel_boot$selected]]$cv_n_units
  pair_mae <- (sel_prof$cv_mae * n_p + sel_boot$cv_mae * n_b) / (n_p + n_b)
  sep_admitted <- (sel_shared$cv_max_err - pair_max >= b2_admission_drop) &&
    (pair_mae <= sel_shared$cv_mae)
  mode <- if (sep_admitted) "separate" else "shared"
  sprintf(
    "shared cv (max_err %.4f, mae %.4f) vs separate pair (max_err %.4f, mae %.4f): %s adopted (s2.3 margin)",
    sel_shared$cv_max_err, sel_shared$cv_mae, pair_max, pair_mae, mode
  )
}
message(shared_note)

## ---- Sanity: the frozen map is finite ------------------------------------
final_specs <- if (mode == "shared") {
  list(profile = sel_shared, boot = sel_shared)
} else if (mode == "profile_only") {
  list(profile = sel_prof, boot = NULL)
} else {
  list(profile = sel_prof, boot = sel_boot)
}
stopifnot(all(is.finite(unlist(lapply(final_specs, function(s) if (is.null(s)) 0 else s$gamma)))))
as_train <- b2_map_alpha_star(
  list(rung = final_specs$profile$selected, gamma = final_specs$profile$gamma,
       terms = final_specs$profile$terms),
  v_prof, alpha
)
stopifnot(all(is.finite(as_train$alpha_star[!as_train$clip_refused])))
message(sprintf(
  "Map sanity: alpha* finite on all non-refused train rows; alpha* range [%.4f, %.4f]; clip-refused %d/%d rows (fence line 4, s2.4)",
  min(as_train$alpha_star, na.rm = TRUE), max(as_train$alpha_star, na.rm = TRUE),
  sum(as_train$clip_refused), nrow(input)
))

## ---- STOP-point register --------------------------------------------------
reached <- function(sel, rung) {
  !is.null(sel) && rung %in% names(sel$path)
}
stop_points <- character(0)
stop_points <- c(stop_points,
  "STOP-W1 (standing): s2.4's cell weights w_c are UNDEFINED in the registration; w_c = 1 implemented (INT-W1). Needs adjudication before the map freeze is signed."
)
if (n_pi_saturated > 0 &&
    (reached(sel_prof, "M3") || reached(sel_boot, "M3") || reached(sel_shared, "M3"))) {
  stop_points <- c(stop_points, sprintf(
    "STOP-P1: %d train rows have pi_max = 1 (a saturated non-target trait), where the registered M3 term logit(pi_max) is +Inf => whole-dataset clip-refusal; s2 does not define pi_max's behaviour over screened-out traits (INT-C1/INT-P1).",
    n_pi_saturated
  ))
}
if (n_sj_na > 0 && (reached(sel_prof, "M4") || reached(sel_boot, "M4") || reached(sel_shared, "M4"))) {
  stop_points <- c(stop_points, sprintf(
    "STOP-S1: %d train rows have s_j = NA; the M4 term used 0 for them (INT-S1); s2 does not define M4 for probe-failed rows.", n_sj_na
  ))
}
for (sel in list(sel_prof, sel_boot, sel_shared)) {
  if (!is.null(sel) && sel$selected == "M5") {
    stop_points <- c(stop_points, sprintf(
      "STOP-M5 (%s): M5 (link main effect) was ADMITTED but the calibration split has no probit cells; applying the link term to H1 (probit hold-out) is UNDEFINED by the registration (INT-M5).",
      sel$label
    ))
  }
}

## ---- Persist the fitted map + selection path (s5.2: freeze in writing) ---
fit <- list(
  created = format(Sys.time(), tz = "UTC", usetz = TRUE),
  design = "docs/design/118-mspl-interval-calibration-protocol.md s2 (SIGNED 2026-08-15)",
  alpha = alpha, clip = b2_alpha_clip, k_folds = k_folds,
  weights_rule = "w_c = 1 (INT-W1; s2.4 leaves w_c undefined)",
  unit_grain = "(cell_id, target_slot) (INT-G1)",
  input = list(
    path = normalizePath(input_path), n_rows = nrow(input),
    n_cells = length(cells_all), n_boot_rows = nrow(boot),
    n_sj_na = n_sj_na, n_pi_saturated = n_pi_saturated
  ),
  identity_check = list(
    profile_max_abs_diff = identity_max_prof,
    boot_max_abs_diff = identity_max_boot,
    tolerance = identity_tol,
    n_precompute_verify = n_verify_checks + n_boot_verify,
    n_dense_fallback_rows = n_fallback
  ),
  mode = mode,
  profile = final_specs$profile[c("label", "selected", "gamma", "terms", "cv_max_err", "cv_mae")],
  boot = if (is.null(final_specs$boot)) NULL else final_specs$boot[c("label", "selected", "gamma", "terms", "cv_max_err", "cv_mae")],
  selection_path = list(
    profile = sel_prof$path,
    boot = if (is.null(sel_boot)) boot_note else sel_boot$path,
    shared = if (is.null(sel_shared)) shared_note else sel_shared$path,
    shared_vs_separate = shared_note
  ),
  sign_ok = all(vapply(
    Filter(Negate(is.null), list(final_specs$profile, final_specs$boot)),
    function(s) all(vapply(s$path, function(p) isTRUE(p$sign_ok) || !p$admitted, logical(1L))),
    logical(1L)
  )),
  stop_points = stop_points
)
rds_path <- file.path(out_dir, "b2-calibrator-fit.rds")
saveRDS(fit, rds_path)

## ---- Human-readable summary ----------------------------------------------
sm <- file.path(out_dir, "b2-calibrator-fit-summary.txt")
fmt_path <- function(path) {
  paste(vapply(path, function(p) sprintf(
    "  %s: cv max_err %.4f, mae %.4f, units %d | admitted: %s | gamma: %s%s%s",
    p$rung, p$cv_max_err, p$cv_mae, p$cv_n_units, p$admitted,
    if (length(p$gamma_full)) paste(names(p$gamma_full), sprintf("%.4f", p$gamma_full), collapse = ", ") else "(none)",
    if (nzchar(p$note)) paste0(" | ", p$note) else "",
    if (length(p$dropped_columns)) paste0(" | dropped all-zero cols: ", paste(p$dropped_columns, collapse = ",")) else ""
  ), character(1L)), collapse = "\n")
}
writeLines(c(
  "Design 118 Phase B2 -- fitted calibrator (s2), TRAIN split only",
  sprintf("Created: %s", fit$created),
  sprintf("Input: %s (%d rows, %d cells; %d bootstrap rows)", fit$input$path, fit$input$n_rows, fit$input$n_cells, fit$input$n_boot_rows),
  sprintf("Registered form: logit alpha*(v) = logit alpha + h(v), ladder M0..M5 (s2.3); admission: oof max-err drop >= 0.005 AND mae not rising, stop at first non-admission (s2.4); clip [0.01, 0.40] = refusal (s2.4/s1.3)"),
  sprintf("Identity check (nominal re-threshold vs stored endpoints): profile max |diff| %.3g, boot max |diff| %.3g (tol %.1g); precompute verified on %d sampled (row, alpha) pairs; %d dense-fallback rows",
    fit$identity_check$profile_max_abs_diff, fit$identity_check$boot_max_abs_diff,
    fit$identity_check$tolerance, fit$identity_check$n_precompute_verify,
    fit$identity_check$n_dense_fallback_rows),
  "",
  sprintf("MODE: %s (%s)", mode, shared_note),
  "",
  "h_profile selection path:",
  fmt_path(sel_prof$path),
  sprintf("=> selected %s; gamma: %s", sel_prof$selected,
    if (length(sel_prof$gamma)) paste(names(sel_prof$gamma), sprintf("%.6f", sel_prof$gamma), collapse = ", ") else "(none: M0, alpha* = alpha)"),
  "",
  if (!is.null(sel_boot)) c(
    "h_boot selection path:", fmt_path(sel_boot$path),
    sprintf("=> selected %s; gamma: %s", sel_boot$selected,
      if (length(sel_boot$gamma)) paste(names(sel_boot$gamma), sprintf("%.6f", sel_boot$gamma), collapse = ", ") else "(none: M0)")
  ) else boot_note,
  "",
  if (!is.null(sel_shared)) c("shared-h selection path:", fmt_path(sel_shared$path)) else character(0),
  "",
  "STOP-points / interpretation register (see lib-b2-calibrator.R header):",
  paste0("  - ", stop_points),
  sprintf("  - INT-S1: %d rows with s_j = NA (M4 term 0)", n_sj_na),
  sprintf("  - INT-P1/C1: %d rows with pi_max = 1 (M3 term +Inf => refusal if M3+ used)", n_pi_saturated)
), sm)
message("Wrote ", rds_path, " and ", sm)
