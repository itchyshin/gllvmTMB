## dev/isdm-bias-campaign.R
##
## Phase C campaign runner: builds the configuration tables for G1..G6 (plus
## the pilot) exactly as specified in dev/isdm-phase-c-design.md's grid
## table, and drives them through dev/isdm-bias-harness.R's run_grid_c().
##
## PER THE TASK BRIEF: THIS FILE DOES NOT AUTO-RUN THE CAMPAIGN. Sourcing it
## only defines config-builder functions and a dispatcher; nothing executes
## at top level. To actually run a block, call e.g.
##   Rscript dev/isdm-bias-campaign.R pilot
## which requires an EXPLICIT stage name on the command line (unlike
## dev/isdm-gate-campaign.R, whose default is "all stages" -- deliberately
## not mirrored here, since the task brief says stop after building).
##
## Lane rule: Lane C branch only. No PR, no merge, no main, no src/ changes.

source("dev/isdm-bias-harness.R")

REF <- list(
  kappa = 1, rho = 0.6, omega = 0.5,
  phi_x = 0.15, phi_bias = 0.15,
  n = 400, T_sp = 8, d_fit = 2, k = 3, beta0_shift = 0
)

## A "null" row shares every geometry parameter with its paired block but
## always has kappa = 0 (which collapses rho/omega/phi -- D4/the grid table
## note -- so their values here are inert and kept at REF's for bookkeeping
## only).
.null_row <- function(overrides = list()) {
  base <- REF; base$kappa <- 0
  base[names(overrides)] <- overrides
  base
}

.mk_config <- function(rows, block, stage = "campaign") {
  df <- do.call(rbind, lapply(rows, as.data.frame))
  df$stage <- stage
  df$block <- block
  required <- c(
    "stage", "block", "seed", "kappa", "rho", "omega", "phi_x",
    "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift"
  )
  df[, required, drop = FALSE]
}

## =========================================================================
## G1 -- main grid: kappa x rho x omega, n=400, T=8, d_fit=2, k=3
##   1 null + 4*2*3 = 25 configs; x seeds x 6 arms (arms handled inside
##   run_dataset_c(), not expanded here) -> 25 * seeds dataset rows.
## =========================================================================
build_config_g1 <- function(seeds, stage = "campaign", beta0_shift = 0) {
  ref <- REF; ref$beta0_shift <- beta0_shift
  rows <- list()
  for (s in seeds) {
    rows[[length(rows) + 1]] <- modifyList(ref, list(kappa = 0, seed = s))
  }
  for (kappa in c(0.25, 0.5, 1, 2)) {
    for (rho in c(0, 0.6)) {
      for (omega in c(1, 0.5, 0)) {
        for (s in seeds) {
          rows[[length(rows) + 1]] <- modifyList(
            ref, list(kappa = kappa, rho = rho, omega = omega, seed = s)
          )
        }
      }
    }
  }
  .mk_config(rows, "G1", stage)
}

## =========================================================================
## G2 -- n-ladder: n in {100, 1600} (400 is in G1); null + REF, per n
## =========================================================================
build_config_g2 <- function(seeds, stage = "campaign", beta0_shift = 0) {
  ref <- REF; ref$beta0_shift <- beta0_shift
  rows <- list()
  for (n in c(100, 1600)) {
    for (s in seeds) {
      rows[[length(rows) + 1]] <- modifyList(ref, list(kappa = 0, n = n, seed = s))
      rows[[length(rows) + 1]] <- modifyList(ref, list(n = n, seed = s))
    }
  }
  .mk_config(rows, "G2", stage)
}

## =========================================================================
## G3 -- species-ladder: T_sp in {6, 12} (8 is in G1); null + REF, per T_sp
## =========================================================================
build_config_g3 <- function(seeds, stage = "campaign", beta0_shift = 0) {
  ref <- REF; ref$beta0_shift <- beta0_shift
  rows <- list()
  for (T_sp in c(6, 12)) {
    for (s in seeds) {
      rows[[length(rows) + 1]] <- modifyList(ref, list(kappa = 0, T_sp = T_sp, seed = s))
      rows[[length(rows) + 1]] <- modifyList(ref, list(T_sp = T_sp, seed = s))
    }
  }
  .mk_config(rows, "G3", stage)
}

## =========================================================================
## G4 -- d_fit sensitivity: d_fit in {1, 3} (truth stays d = 2); null + REF
## =========================================================================
build_config_g4 <- function(seeds, stage = "campaign", beta0_shift = 0) {
  ref <- REF; ref$beta0_shift <- beta0_shift
  rows <- list()
  for (d_fit in c(1, 3)) {
    for (s in seeds) {
      rows[[length(rows) + 1]] <- modifyList(ref, list(kappa = 0, d_fit = d_fit, seed = s))
      rows[[length(rows) + 1]] <- modifyList(ref, list(d_fit = d_fit, seed = s))
    }
  }
  .mk_config(rows, "G4", stage)
}

## =========================================================================
## G5 -- k = 1 sensitivity (retriggers the theta_diag_B skip for A2 alone,
## D6); null + REF at k = 1
## =========================================================================
build_config_g5 <- function(seeds, stage = "campaign", beta0_shift = 0) {
  ref <- REF; ref$beta0_shift <- beta0_shift
  rows <- list()
  for (s in seeds) {
    rows[[length(rows) + 1]] <- modifyList(ref, list(kappa = 0, k = 1, seed = s))
    rows[[length(rows) + 1]] <- modifyList(ref, list(k = 1, seed = s))
  }
  .mk_config(rows, "G5", stage)
}

## =========================================================================
## G6 -- bias smoothness: phi_bias in {0, 0.4} at the REF bias setting only,
## while phi_x remains frozen at 0.15. The exact campaign G1 null is reused.
## rho=0.6, omega=0.5); reuses G1's null (kappa=0) as the paired baseline --
## i.e. G6 contributes ONLY the two REF-bias-setting phi rows, not a second
## null (per the design doc's fit-count table: "1 (REF), reusing G1's null").
## =========================================================================
build_config_g6 <- function(seeds, stage = "campaign", beta0_shift = 0) {
  ref <- REF; ref$beta0_shift <- beta0_shift
  rows <- list()
  for (phi_bias in c(0, 0.4)) {
    for (s in seeds) {
      rows[[length(rows) + 1]] <- modifyList(ref, list(phi_bias = phi_bias, seed = s))
    }
  }
  .mk_config(rows, "G6", stage)
}

## =========================================================================
## Pilot -- G1's 25 configs at S = 10 seeds (1,500 fits: 25*10*6)
## =========================================================================
build_config_pilot <- function(seeds = 1:10, beta0_shift = 0) {
  build_config_g1(seeds, stage = "pilot_v2", beta0_shift = beta0_shift)
}

## =========================================================================
## Fit-count sanity check (no simulation, no fitting -- just arithmetic)
## =========================================================================
expected_fit_counts <- function() {
  c(
    G1     = nrow(build_config_g1(1:100))    * length(ARMS),
    G2     = nrow(build_config_g2(1:50))     * length(ARMS),
    G3     = nrow(build_config_g3(1:50))     * length(ARMS),
    G4     = nrow(build_config_g4(1:50))     * length(ARMS),
    G5     = nrow(build_config_g5(1:50))     * length(ARMS),
    G6     = nrow(build_config_g6(1:50))     * length(ARMS),
    pilot  = nrow(build_config_pilot(1:10))  * length(ARMS)
  )
}

## =========================================================================
## Pre-flight gates (P0-1 .. P0-6), followed by the handover's paired
## low/high-bias smoke. Call these explicitly; neither runs on source().
## =========================================================================
`%||%` <- function(a, b) if (is.null(a)) b else a

.detect_cores_c <- function(cap = 18L) {
  detected <- suppressWarnings(parallel::detectCores())
  if (length(detected) != 1L || !is.finite(detected)) return(1L)
  max(1L, min(as.integer(cap), as.integer(detected) - 2L))
}

run_preflight_gates <- function(n_cores = 1L) {
  if (length(n_cores) != 1L || !is.finite(n_cores) || n_cores < 1L) n_cores <- 1L
  n_cores <- as.integer(n_cores)
  hr <- function(x) cat("\n", strrep("=", 12), " ", x, " ", strrep("=", 12), "\n", sep = "")
  truth <- species_truth(8, REF$beta0_shift)

  hr("P0-1/P0-2/P0-3/P0-6: one REF dataset, all six arms")
  df <- sim_phase_c(
    seed = 1, n = REF$n, T_sp = REF$T_sp,
    phi_x = REF$phi_x, phi_bias = REF$phi_bias,
    kappa = REF$kappa, rho = REF$rho, omega = REF$omega, k = REF$k,
    beta0_shift = REF$beta0_shift, truth = truth
  )
  stopifnot(nrow(df) == REF$n * REF$T_sp * 2)
  cat("P0-1 nrow OK:", nrow(df), "\n")

  cfg <- as.list(REF); cfg$seed <- 1; cfg$stage <- "preflight"; cfg$block <- "preflight"
  fits <- setNames(vector("list", length(ARMS)), ARMS)
  scores <- setNames(vector("list", length(ARMS)), ARMS)
  for (a in ARMS) {
    fit <- tryCatch(fit_arm(df, arm = a, d_fit = REF$d_fit), error = function(e) e)
    if (inherits(fit, "condition")) {
      stop(sprintf("P0-6 FAIL [%s]: %s", a, conditionMessage(fit)), call. = FALSE)
    }
    fits[[a]] <- fit
    scores[[a]] <- score_phase_c(
      fit, a, cfg, truth,
      realised_prevalence = attr(df, "realised_prevalence"),
      bias_sharing = attr(df, "bias_sharing")
    )
  }

  a5 <- fits$A5
  source_chr <- as.character(a5$data$source)
  family_by_source <- split(a5$tmb_data$family_id_vec, source_chr)
  clean_family_map <- length(family_by_source) == 2L &&
    all(vapply(family_by_source, function(x) length(unique(x)) == 1L, logical(1))) &&
    length(unique(vapply(family_by_source, function(x) unique(x)[1], integer(1)))) == 2L
  if (!clean_family_map) stop("P0-1 FAIL: family_id_vec does not map cleanly to source", call. = FALSE)
  cat("P0-1 family_id_vec x source:\n")
  print(table(a5$tmb_data$family_id_vec, source_chr))

  dbs <- sum(a5$tmb_data$diag_B_skip %||% 0)
  cat("P0-1 diag_B_skip (A5, expect 0):", dbs, "\n")
  if (dbs != 0L) stop("P0-1 FAIL: A5 diag_B_skip is non-zero", call. = FALSE)

  Sres <- tryCatch(
    extract_Sigma(a5, level = "unit", part = "total", link_residual = "none"),
    error = function(e) e
  )
  if (inherits(Sres, "condition")) {
    stop("P0-2 FAIL: ", conditionMessage(Sres), call. = FALSE)
  }
  R <- Sres$R
  max_off <- max(abs(R[upper.tri(R)]))
  cat(sprintf("P0-2 A5 R: dim=%s max|off-diag|=%.4f any NA=%s\n",
              paste(dim(R), collapse = "x"), max_off, anyNA(R)))
  if (!all(dim(R) == c(REF$T_sp, REF$T_sp)) || anyNA(R) || max_off >= 0.999) {
    stop("P0-2 FAIL: A5 returned a missing or degenerate correlation matrix", call. = FALSE)
  }

  trials_by_source <- split(a5$tmb_data$n_trials, source_chr)
  expected_trials <- c(po = 1, pa = REF$k)
  clean_trials <- all(names(expected_trials) %in% names(trials_by_source)) &&
    all(vapply(names(expected_trials), function(src) {
      identical(unique(as.numeric(trials_by_source[[src]])), expected_trials[[src]])
    }, logical(1)))
  cat("P0-3 n_trials x source:\n")
  print(table(a5$tmb_data$n_trials, source_chr))
  if (!clean_trials) {
    stop("P0-3 FAIL: multi-trial binomial counts did not survive family_var dispatch", call. = FALSE)
  }

  nb <- sum(grepl(":bstar$", fits$A6$X_fix_names))
  cat("P0-6 A6 trait:bstar columns (expect T=8):", nb, "\n")
  if (nb != REF$T_sp) stop("P0-6 FAIL: A6 bias columns do not match T", call. = FALSE)

  hr("Amendment contracts: exact streams, separated phi, collapsed A6 null")
  stream_0 <- sim_phase_c(
    seed = 7, n = 100, T_sp = 8, phi_x = 0.15, phi_bias = 0,
    kappa = 1, rho = 0.6, omega = 0.5, k = 3,
    beta0_shift = REF$beta0_shift, retain_streams = TRUE
  )
  stream_4 <- sim_phase_c(
    seed = 7, n = 100, T_sp = 8, phi_x = 0.15, phi_bias = 0.4,
    kappa = 1, rho = 0.6, omega = 0.5, k = 3,
    beta0_shift = REF$beta0_shift, retain_streams = TRUE
  )
  if (!identical(attr(stream_0, "design_streams"), attr(stream_4, "design_streams"))) {
    stop("AMENDMENT FAIL: phi_bias changed a design RNG stream", call. = FALSE)
  }
  if (identical(attr(stream_0, "bias_streams"), attr(stream_4, "bias_streams"))) {
    stop("AMENDMENT FAIL: phi_bias did not change the bias fields", call. = FALSE)
  }
  cat("Exact design-stream identity across phi_bias={0,0.4}: PASS\n")

  null_probe <- sim_phase_c(
    seed = 11, n = 100, T_sp = 8, phi_x = 0.15, phi_bias = 0.15,
    kappa = 0, rho = 0.6, omega = 0.5, k = 3,
    beta0_shift = REF$beta0_shift
  )
  set.seed(500011L)
  null_a5 <- fit_arm(null_probe, "A5", d_fit = 2)
  set.seed(500011L)
  null_a6 <- fit_arm(null_probe, "A6", d_fit = 2)
  if (!isTRUE(attr(null_a6, "oracle_collapsed")) ||
      !identical(null_a5$X_fix_names, null_a6$X_fix_names) ||
      !isTRUE(all.equal(null_a5$opt$par, null_a6$opt$par, tolerance = 0))) {
    stop("AMENDMENT FAIL: A6 null did not collapse exactly to A5", call. = FALSE)
  }
  cat("A5/A6 exact null collapse: PASS\n")

  hr("P0-4/P0-5: 10-seed A5 null recovery and timing")
  run_null_seed <- function(seed) {
    null_cfg <- as.list(REF)
    null_cfg$kappa <- 0
    null_cfg$seed <- seed
    null_cfg$stage <- "preflight"
    null_cfg$block <- "preflight-null"
    null_df <- sim_phase_c(
      seed = seed, n = null_cfg$n, T_sp = null_cfg$T_sp,
      phi_x = null_cfg$phi_x, phi_bias = null_cfg$phi_bias,
      kappa = 0, rho = null_cfg$rho, omega = null_cfg$omega, k = null_cfg$k,
      beta0_shift = null_cfg$beta0_shift, truth = truth
    )
    t0 <- Sys.time()
    fit <- tryCatch(fit_arm(null_df, arm = "A5", d_fit = null_cfg$d_fit), error = function(e) e)
    elapsed <- as.numeric(Sys.time() - t0, units = "secs")
    score_phase_c(
      fit, "A5", null_cfg, truth, elapsed_sec = elapsed,
      realised_prevalence = attr(null_df, "realised_prevalence"),
      bias_sharing = attr(null_df, "bias_sharing")
    )
  }
  seeds <- 1:10
  null_rows <- if (n_cores > 1L && .Platform$OS.type != "windows") {
    parallel::mclapply(seeds, run_null_seed, mc.cores = min(as.integer(n_cores), length(seeds)))
  } else {
    lapply(seeds, run_null_seed)
  }
  null_res <- do.call(rbind, null_rows)
  if (any(!is.na(null_res$fit_error))) {
    stop("P0-4 FAIL: null recovery fit error: ",
         paste(unique(stats::na.omit(null_res$fit_error)), collapse = "; "), call. = FALSE)
  }
  required <- c("D_rmse", "D_bias", "realised_prevalence", "elapsed_sec")
  if (any(!vapply(null_res[required], function(x) all(is.finite(x)), logical(1)))) {
    stop("P0-4 FAIL: null recovery returned a non-finite required metric", call. = FALSE)
  }
  mean_rmse <- mean(null_res$D_rmse)
  mean_bias <- mean(null_res$D_bias)
  bias_mcse <- .mcse_mean(null_res$D_bias)
  pooled_prev <- mean(null_res$realised_prevalence)
  mean_sec <- mean(null_res$elapsed_sec)
  cat(sprintf(
    "P0-4 A5 null: mean D_rmse=%.4f; mean D_bias=%.4f (MCSE=%.4f; 3 MCSE=%.4f); pooled prevalence=%.4f\n",
    mean_rmse, mean_bias, bias_mcse, 3 * bias_mcse, pooled_prev
  ))
  if (mean_rmse >= 0.15 || abs(mean_bias) > 3 * bias_mcse ||
      pooled_prev < 0.25 || pooled_prev > 0.50) {
    stop("P0-4 FAIL: correctly specified A5 null did not clear frozen recovery bounds", call. = FALSE)
  }
  route <- if (mean_sec > 10) "totoro" else "local"
  cat(sprintf("P0-5 timing: mean %.3f s/fit -> route %s\n", mean_sec, route))

  list(
    ref_scores = do.call(rbind, scores),
    null_scores = null_res,
    timing_route = route
  )
}

run_low_high_smoke <- function(seed = 42L, n = 100L, T_sp = 6L) {
  rows <- list(
    modifyList(REF, list(kappa = 0, rho = 0, omega = 1, n = n, T_sp = T_sp, seed = seed)),
    modifyList(REF, list(kappa = 2, rho = 0, omega = 1, n = n, T_sp = T_sp, seed = seed))
  )
  cfg <- .mk_config(rows, "smoke-low-high", stage = "preflight")
  res <- run_grid_c(cfg, n_cores = 1L, backend = "serial")
  if (nrow(res) != 2L * length(ARMS) || any(!is.na(res$fit_error)) ||
      any(!is.finite(res$D_bias)) || any(!is.finite(res$D_rmse))) {
    stop("SMOKE FAIL: empty, errored, or non-finite result", call. = FALSE)
  }
  paired <- reshape(
    res[, c("kappa", "seed", "arm", "D_bias")],
    idvar = c("seed", "arm"), timevar = "kappa", direction = "wide"
  )
  paired$dD_bias <- paired$D_bias.2 - paired$D_bias.0
  primary_delta <- paired$dD_bias[paired$arm == "A1"]
  if (length(primary_delta) != 1L || !is.finite(primary_delta)) {
    stop("SMOKE FAIL: A1 diagnostic delta is missing or non-finite", call. = FALSE)
  }
  cat("Paired high-minus-low D_bias (diagnostic only; one seed):\n")
  print(paired[, c("seed", "arm", "D_bias.0", "D_bias.2", "dD_bias")], row.names = FALSE)
  list(results = res, paired = paired)
}

## =========================================================================
## Receipt and dispatch helpers. Sourcing remains side-effect free.
## =========================================================================
.phase_c_files <- c(
  "dev/isdm-bias-harness.R",
  "dev/isdm-bias-campaign.R",
  "dev/isdm-phase-c-analyse-official.R",
  "dev/isdm-phase-c-pilot-decision.R",
  "dev/isdm-phase-c-amendment-2026-08-08.md"
)

.instrument_id_c <- function(files = .phase_c_files) {
  if (any(!file.exists(files))) stop("Missing instrument file: ", paste(files[!file.exists(files)], collapse = ", "))
  hashes <- system2("git", c("hash-object", files), stdout = TRUE)
  if (length(hashes) != length(files)) stop("Could not hash the Phase C instrument")
  paste(hashes, collapse = ":")
}

.git_sha_c <- function() {
  out <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
  if (length(out) != 1L) stop("Could not resolve source SHA")
  out
}

.git_branch_c <- function() {
  out <- system2("git", c("branch", "--show-current"), stdout = TRUE)
  if (length(out) != 1L || !nzchar(out)) stop("Could not resolve branch")
  out
}

.git_dirty_c <- function() {
  length(system2("git", c("status", "--porcelain"), stdout = TRUE)) > 0L
}

.sha256_c <- function(path) {
  if (!file.exists(path)) stop("Cannot hash missing path: ", path)
  if (nzchar(Sys.which("sha256sum"))) {
    out <- system2("sha256sum", path, stdout = TRUE)
  } else if (nzchar(Sys.which("shasum"))) {
    out <- system2("shasum", c("-a", "256", path), stdout = TRUE)
  } else stop("Neither sha256sum nor shasum is available")
  strsplit(out[[1]], "[[:space:]]+")[[1]][1]
}

.object_sha256_c <- function(object) {
  path <- tempfile("phase-c-hash-", fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(object, path, version = 3)
  .sha256_c(path)
}

.write_receipt_c <- function(path, fields) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  values <- vapply(fields, function(x) paste(x, collapse = ","), character(1))
  if (any(grepl("[\r\n]", values))) stop("Receipt fields must be single-line")
  writeLines(sprintf("%s=%s", names(values), values), path)
  invisible(path)
}

.read_receipt_c <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) stop("Required receipt is missing: ", path)
  lines <- readLines(path, warn = FALSE)
  at <- regexpr("=", lines, fixed = TRUE)
  if (!length(lines) || any(at < 2L)) stop("Malformed receipt: ", path)
  keys <- substring(lines, 1L, at - 1L)
  values <- substring(lines, at + 1L)
  if (anyDuplicated(keys)) stop("Duplicate receipt field: ", path)
  as.list(stats::setNames(values, keys))
}

.require_receipt_c <- function(path, receipt_type, instrument_id = .instrument_id_c()) {
  x <- .read_receipt_c(path)
  if (!identical(x$receipt_type, receipt_type) || !identical(x$status, "PASS")) {
    stop("Receipt is not a PASS ", receipt_type, ": ", path)
  }
  if (!identical(x$instrument_id, instrument_id)) {
    stop("Receipt instrument does not match the current Phase C files: ", path)
  }
  x
}

.parse_cli_c <- function(args) {
  if (!length(args)) return(list(stage = NULL))
  if (grepl("^--", args[[1]])) stop("First argument must be one explicit stage")
  out <- list(stage = tolower(args[[1]]))
  for (arg in args[-1]) {
    if (!grepl("^--[^=]+=", arg)) stop("Options must use --name=value: ", arg)
    kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1]]
    out[[gsub("-", "_", kv[[1]])]] <- paste(kv[-1], collapse = "=")
  }
  out
}

.assert_unique_results_c <- function(res, expected_rows, stage) {
  if (nrow(res) != expected_rows) stop(stage, " row-count mismatch: expected ", expected_rows, ", got ", nrow(res))
  key <- c("stage", "block", "kappa", "rho", "omega", "phi_x", "phi_bias",
           "n", "T_sp", "d_fit", "k", "beta0_shift", "seed", "arm")
  if (!all(key %in% names(res))) stop(stage, " missing result key columns")
  if (anyDuplicated(res[key])) stop(stage, " contains duplicate result keys")
  completed <- is.na(res$fit_error)
  total_rows <- completed & res$estimand == "total_sigma"
  rank_rows <- completed & res$estimand == "loadings_only_rank_d"
  if (any(total_rows & (!is.finite(res$D_bias) | !is.finite(res$D_rmse)))) {
    stop(stage, " contains an unlabelled non-finite total-Sigma result")
  }
  if (any(rank_rows & (!is.finite(res$rank_d_D_bias) | !is.finite(res$rank_d_D_rmse)))) {
    stop(stage, " contains an unlabelled non-finite rank-d result")
  }
  invisible(TRUE)
}

.dataset_key_c <- function(x) {
  key <- c("stage", "block", "kappa", "rho", "omega", "phi_x", "phi_bias",
           "n", "T_sp", "d_fit", "k", "beta0_shift", "seed")
  do.call(paste, c(x[key], sep = "|"))
}

run_grid_c_resumable <- function(config_df, output, n_cores, chunk_size = n_cores,
                                 control = NULL) {
  parts_dir <- paste0(output, ".parts")
  dir.create(parts_dir, recursive = TRUE, showWarnings = FALSE)
  instrument_id <- .instrument_id_c()
  config_sha256 <- .object_sha256_c(config_df)
  part_paths <- sort(list.files(parts_dir, pattern = "[.]rds$", full.names = TRUE))
  parts <- lapply(part_paths, function(path) {
    x <- readRDS(path)
    if (!is.list(x) || !identical(x$instrument_id, instrument_id) ||
        !identical(x$config_sha256, config_sha256) || !is.data.frame(x$results)) {
      stop("Incompatible or malformed resume part: ", path)
    }
    if (nrow(x$results) %% length(ARMS) != 0L) stop("Partial dataset in resume part: ", path)
    x$results
  })
  done <- if (length(parts)) unique(.dataset_key_c(do.call(rbind, parts))) else character()
  cfg_key <- .dataset_key_c(config_df)
  remaining <- config_df[!cfg_key %in% done, , drop = FALSE]
  if (nrow(remaining)) {
    chunks <- split(seq_len(nrow(remaining)), ceiling(seq_len(nrow(remaining)) / max(1L, chunk_size)))
    next_id <- length(part_paths)
    for (idx in chunks) {
      next_id <- next_id + 1L
      chunk <- remaining[idx, , drop = FALSE]
      results <- run_grid_c(
        chunk, control = control, n_cores = n_cores,
        backend = if (.Platform$OS.type == "windows" || n_cores == 1L) "serial" else "mclapply"
      )
      expected <- nrow(chunk) * length(ARMS)
      .assert_unique_results_c(results, expected, "resume-part")
      part_path <- file.path(parts_dir, sprintf("part-%05d.rds", next_id))
      if (file.exists(part_path)) stop("Refusing to overwrite resume part: ", part_path)
      saveRDS(list(
        instrument_id = instrument_id, config_sha256 = config_sha256,
        created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE), results = results
      ), part_path)
      parts[[length(parts) + 1L]] <- results
    }
  }
  if (!length(parts)) stop("No result parts were produced")
  res <- do.call(rbind, parts)
  .assert_unique_results_c(res, nrow(config_df) * length(ARMS), "resumed-block")
  res
}

.write_compute_receipt_c <- function(path, stage, output, expected_rows, actual_rows,
                                     cores, started, ended, status = "PASS",
                                     config = NULL, results = NULL,
                                     predecessor_hashes = "", g1_seeds = "") {
  info <- file.info(output)
  parts_dir <- paste0(output, ".parts")
  part_paths <- sort(list.files(parts_dir, pattern = "[.]rds$", full.names = TRUE))
  part_hashes <- if (length(part_paths)) {
    paste(sprintf("%s:%s", basename(part_paths), vapply(part_paths, .sha256_c, character(1))), collapse = ";")
  } else ""
  fields <- list(
    receipt_type = paste0(stage, "_compute"), status = status,
    stage = stage, source_sha = .git_sha_c(), source_branch = .git_branch_c(),
    source_dirty = .git_dirty_c(), instrument_id = .instrument_id_c(),
    command = paste(commandArgs(), collapse = " "), host = Sys.info()[["nodename"]],
    r_version = R.version.string, cores = cores,
    backend = if (.Platform$OS.type == "windows" || cores == 1L) "serial" else "mclapply",
    started_utc = format(started, tz = "UTC", usetz = TRUE),
    ended_utc = format(ended, tz = "UTC", usetz = TRUE),
    expected_rows = expected_rows, actual_rows = actual_rows,
    expected_logical_rows = expected_rows, expected_optimizer_calls = expected_rows,
    output_path = normalizePath(output), output_bytes = info$size,
    output_sha256 = .sha256_c(output),
    resume_parts_dir = if (dir.exists(parts_dir)) normalizePath(parts_dir) else "",
    resume_part_count = length(part_paths), resume_part_hashes = part_hashes,
    predecessor_receipt_hashes = predecessor_hashes, g1_seeds = g1_seeds
  )
  if (!is.null(config)) {
    fields$config_sha256 <- .object_sha256_c(config)
    fields$seed_min <- min(config$seed); fields$seed_max <- max(config$seed)
    fields$seed_count <- length(unique(config$seed))
    fields$phi_x <- paste(sort(unique(config$phi_x)), collapse = ",")
    fields$phi_bias <- paste(sort(unique(config$phi_bias)), collapse = ",")
    fields$beta0_shift <- paste(unique(config$beta0_shift), collapse = ",")
    fields$arms <- paste(ARMS, collapse = ",")
    fields$null_dataset_rows <- sum(config$kappa == 0)
  }
  if (!is.null(results)) {
    fields$unique_key_verdict <- if (anyDuplicated(results[c(
      "stage", "block", "kappa", "rho", "omega", "phi_x", "phi_bias",
      "n", "T_sp", "d_fit", "k", "beta0_shift", "seed", "arm"
    )])) "FAIL" else "PASS"
    fields$a6_null_collapsed_rows <- sum(results$kappa == 0 & results$arm == "A6" & results$oracle_collapsed, na.rm = TRUE)
    fields$fit_error_rows <- sum(!is.na(results$fit_error))
    fields$unlabelled_nonfinite_rows <- sum(
      is.na(results$fit_error) & results$estimand == "total_sigma" &
        (!is.finite(results$D_bias) | !is.finite(results$D_rmse))
    )
  }
  .write_receipt_c(path, fields)
}

calibrate_beta0_shift <- function(seeds = 1:10, target = 0.375,
                                  tolerance = 0.005, lower = -8, upper = 8,
                                  max_iter = 30L) {
  prevalence <- function(delta) {
    mean(vapply(seeds, function(seed) {
      df <- sim_phase_c(
        seed = seed, n = REF$n, T_sp = REF$T_sp,
        phi_x = REF$phi_x, phi_bias = REF$phi_bias,
        kappa = 0, rho = REF$rho, omega = REF$omega, k = REF$k,
        beta0_shift = delta
      )
      attr(df, "realised_prevalence")
    }, numeric(1)))
  }
  lo_p <- prevalence(lower); hi_p <- prevalence(upper)
  expansions <- 0L
  while (!(lo_p <= target && hi_p >= target) && expansions < 10L) {
    lower <- lower * 2; upper <- upper * 2; expansions <- expansions + 1L
    lo_p <- prevalence(lower); hi_p <- prevalence(upper)
  }
  if (!(lo_p <= target && hi_p >= target)) stop("BETA0 bisection bracket does not contain the target")
  mid <- 0; mid_p <- prevalence(mid)
  iterations <- 0L
  for (i in seq_len(max_iter)) {
    iterations <- i
    if (abs(mid_p - target) <= tolerance) break
    if (mid_p < target) lower <- mid else upper <- mid
    mid <- (lower + upper) / 2
    mid_p <- prevalence(mid)
  }
  if (abs(mid_p - target) > tolerance) stop("BETA0 calibration did not meet the frozen tolerance")
  list(
    beta0_shift = mid, prevalence = mid_p, target = target,
    tolerance = tolerance, lower = lower, upper = upper,
    iterations = iterations, expansions = expansions
  )
}

## =========================================================================
## Dispatch (Rscript-only; one explicit stage per invocation)
## =========================================================================
if (sys.nframe() == 0L) {
  opt <- .parse_cli_c(commandArgs(trailingOnly = TRUE))
  if (is.null(opt$stage)) {
    cat("No stage given; nothing executed.\n")
    cat("Stages: counts, preflight, pilot, g1, g2, g3, g4, g5, g6\n")
    cat("Use explicit --output= and --receipt= paths for every compute stage.\n")
    quit(status = 0)
  }
  stage <- opt$stage
  if (stage == "counts") {
    print(expected_fit_counts())
    quit(status = 0)
  }
  cores <- as.integer(opt$cores %||% .detect_cores_c())
  if (!is.finite(cores) || cores < 1L || cores > 150L) stop("cores must be in 1..150")
  output <- opt$output %||% stop("--output= is required")
  receipt <- opt$receipt %||% stop("--receipt= is required")
  if (file.exists(output)) stop("Refusing to overwrite existing output: ", output)
  if (file.exists(receipt)) stop("Refusing to overwrite existing receipt: ", receipt)
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  beta0_shift <- 0
  predecessor_hashes <- ""
  chosen_g1_seeds <- ""

  if (stage == "preflight") {
    started <- Sys.time()
    gates <- run_preflight_gates(n_cores = min(4L, cores))
    smoke <- run_low_high_smoke()
    payload <- list(gates = gates, smoke = smoke)
    saveRDS(payload, output)
    ended <- Sys.time()
    .write_compute_receipt_c(receipt, "preflight", output, 1L, 1L, cores, started, ended)
    quit(status = 0)
  }

  .require_receipt_c(opt$preflight_receipt, "preflight_compute")
  if (stage == "pilot") {
    predecessor_hashes <- paste0("preflight:", .sha256_c(opt$preflight_receipt))
    if (!is.null(opt$calibration_receipt)) {
      calibration <- .require_receipt_c(opt$calibration_receipt, "pilot_calibration")
      beta0_shift <- as.numeric(calibration$beta0_shift)
      predecessor_hashes <- paste(
        predecessor_hashes,
        paste0("calibration:", .sha256_c(opt$calibration_receipt)), sep = ";"
      )
    } else if (!is.null(opt$beta0_shift) && as.numeric(opt$beta0_shift) != 0) {
      stop("A non-zero pilot beta0 shift requires --calibration-receipt=")
    }
    cfg <- build_config_pilot(beta0_shift = beta0_shift)
  } else if (stage %in% paste0("g", 1:6)) {
    decision <- .require_receipt_c(opt$pilot_receipt, "pilot_decision")
    beta0_shift <- as.numeric(decision$beta0_shift)
    if (!is.null(opt$beta0_shift) &&
        !isTRUE(all.equal(as.numeric(opt$beta0_shift), beta0_shift, tolerance = 0))) {
      stop("--beta0-shift does not match the frozen pilot decision")
    }
    predecessor_hashes <- paste0(
      "preflight:", .sha256_c(opt$preflight_receipt),
      ";pilot_decision:", .sha256_c(opt$pilot_receipt)
    )
    if (stage == "g1") {
      g1_seeds <- as.integer(opt$g1_seeds %||% stop("--g1-seeds= is required"))
      if (!g1_seeds %in% c(100L, 200L) || g1_seeds != as.integer(decision$g1_seeds)) {
        stop("G1 seed count does not match the frozen pilot decision")
      }
      chosen_g1_seeds <- g1_seeds
      cfg <- build_config_g1(seq_len(g1_seeds), beta0_shift = beta0_shift)
    } else {
      if (stage == "g6") {
        .require_receipt_c(opt$g1_receipt, "g1_compute")
        predecessor_hashes <- paste(
          predecessor_hashes, paste0("g1:", .sha256_c(opt$g1_receipt)), sep = ";"
        )
      }
      cfg <- get(paste0("build_config_", stage))(1:50, beta0_shift = beta0_shift)
    }
  } else stop("Unknown stage: ", stage)

  expected_rows <- nrow(cfg) * length(ARMS)
  cat(sprintf("%s: %d dataset rows x %d arms = %d result rows\n",
              stage, nrow(cfg), length(ARMS), expected_rows))
  started <- Sys.time()
  res <- run_grid_c_resumable(cfg, output = output, n_cores = cores,
                              chunk_size = as.integer(opt$chunk_size %||% cores))
  .assert_unique_results_c(res, expected_rows, stage)
  saveRDS(res, output)
  ended <- Sys.time()
  .write_compute_receipt_c(
    receipt, stage, output, expected_rows, nrow(res), cores, started, ended,
    config = cfg, results = res, predecessor_hashes = predecessor_hashes,
    g1_seeds = chosen_g1_seeds
  )
}
