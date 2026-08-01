## =============================================================================
## 30 -- Paired non-inferiority gates for #847's scale-aware tau campaign
## =============================================================================
## Usage:
##   PHASE=selection INPUT=/path/29-tau-cap-selection.csv \
##     OUTPUT=/path/30-selection Rscript dev/aghq-evidence/30-tau-cap-analyse.R
##   PHASE=confirm INPUT=/path/29-tau-cap-confirm.csv LOCKED_CAP=6 \
##     OUTPUT=/path/30-confirm Rscript dev/aghq-evidence/30-tau-cap-analyse.R
##
## The tau-only comparator is fixed2_pilot: it shares the unpenalised AGHQ pilot
## and warm start with every candidate. fixed2_shipped is retained as a separate
## operational comparator, but cannot identify the effect of tau by itself.

PHASE <- Sys.getenv("PHASE", "selection")
INPUT <- Sys.getenv("INPUT", "")
OUTPUT <- Sys.getenv("OUTPUT", file.path(dirname(INPUT), paste0("30-", PHASE)))
LOCKED_CAP <- suppressWarnings(as.numeric(Sys.getenv("LOCKED_CAP", "NA")))
B <- as.integer(Sys.getenv("BOOT_REPS", "5000"))
EXPECTED_NSIM <- if (PHASE == "selection") 100L else 200L
SELECTION_INPUT <- Sys.getenv("SELECTION_INPUT", "")
SELECTION_VERDICT <- Sys.getenv("SELECTION_VERDICT", "")

if (!PHASE %in% c("selection", "confirm")) stop("PHASE must be selection or confirm")
if (!nzchar(INPUT) || !file.exists(INPUT)) stop("INPUT must name a campaign CSV")
if (PHASE == "confirm" && (!is.finite(LOCKED_CAP) || LOCKED_CAP <= 0)) {
  stop("confirmation requires a positive finite LOCKED_CAP")
}
if (!is.finite(B) || B < 999L) stop("BOOT_REPS must be at least 999")

dat <- utils::read.csv(INPUT, stringsAsFactors = FALSE)
need <- c(
  "phase", "n", "p", "q", "lam_sd", "task", "seed", "arm", "ok",
  "converged", "aghq_used", "n_starts", "tau_raw", "tau_used", "tau_cap",
  "tau_clipped", "tau_source", "pilot_ok", "pilot_converged", "pilot_k",
  "pilot_n_starts", "rho_mae", "frob_rat", "loading_log_error",
  "package_sha", "package_path", "package_version", "package_built"
)
missing_cols <- setdiff(need, names(dat))
if (length(missing_cols)) stop("campaign CSV is missing: ", paste(missing_cols, collapse = ", "))
if (!all(dat$phase == PHASE)) stop("INPUT contains rows from the wrong phase")

key <- c("phase", "n", "lam_sd", "task", "seed")
pair_key <- c("n", "lam_sd", "task", "seed")
expected_cells <- expand.grid(
  n = c(100L, 400L, 1600L), lam_sd = c(1, 3),
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)
expected_arms <- if (PHASE == "selection") {
  c(
    "fixed2_shipped", "pilot_unpenalised", "fixed2_pilot",
    "auto_uncapped", "auto_cap5", "auto_cap6", "auto_cap8"
  )
} else {
  c(
    "fixed2_shipped", "pilot_unpenalised", "fixed2_pilot",
    paste0("auto_cap", format(LOCKED_CAP, trim = TRUE))
  )
}
if (!setequal(unique(dat$arm), expected_arms)) {
  stop("INPUT arm set does not exactly match the preregistered phase")
}
if (anyDuplicated(dat[c(key, "arm")]) ||
    anyDuplicated(dat[c("arm", "n", "lam_sd", "seed")])) {
  stop("duplicate arm/key or arm/cell/seed rows in INPUT")
}
observed_cells <- unique(dat[c("n", "lam_sd")])
if (nrow(observed_cells) != nrow(expected_cells) ||
    nrow(merge(expected_cells, observed_cells, by = c("n", "lam_sd"))) != 6L) {
  stop("INPUT does not contain exactly the six preregistered cells")
}
counts <- aggregate(task ~ arm + n + lam_sd, dat, length)
if (nrow(counts) != length(expected_arms) * 6L ||
    any(counts$task != EXPECTED_NSIM)) {
  stop("INPUT does not contain the expected arm x cell replicate counts")
}
key_sets <- lapply(expected_arms, function(a) {
  x <- dat[dat$arm == a, pair_key]
  do.call(paste, c(x, sep = "|"))
})
if (!all(vapply(key_sets[-1L], setequal, logical(1), key_sets[[1L]]))) {
  stop("arms do not share complete paired keys")
}

validate_tau_contract <- function(x, label) {
  if (any(x$p != 6L) || any(x$q != 2L)) stop(label, ": p/q contract changed")
  shas <- unique(x$package_sha)
  if (length(shas) != 1L || is.na(shas) || !nzchar(shas)) {
    stop(label, ": package SHA is absent or inconsistent")
  }
  if (length(unique(x$package_path)) != 1L || anyNA(x$package_path) ||
      !nzchar(unique(x$package_path)) || length(unique(x$package_version)) != 1L ||
      anyNA(x$package_version) || length(unique(x$package_built)) != 1L ||
      anyNA(x$package_built)) {
    stop(label, ": installed package provenance is inconsistent")
  }
  source_expected <- ifelse(
    x$arm == "pilot_unpenalised", "unpenalised_multistart_aghq",
    ifelse(x$arm == "fixed2_shipped", "fixed2_shipped_start",
           ifelse(x$arm == "fixed2_pilot", "fixed2_pilot_start",
                  "pilot_unpenalised_multistart_aghq"))
  )
  if (anyNA(x$tau_source) || any(x$tau_source != source_expected)) {
    stop(label, ": tau source mismatch")
  }

  pilot_rows <- x[x$arm == "pilot_unpenalised", ]
  pilot_rows$pilot_valid <- with(
    pilot_rows,
    as.logical(ok) & as.logical(converged) & as.logical(aghq_used) &
      is.finite(n_starts) & n_starts >= 2L & is.infinite(tau_used) &
      is.infinite(tau_cap) & as.logical(pilot_ok) &
      as.logical(pilot_converged) & pilot_k == 9L & pilot_n_starts >= 2L
  )
  pilot_contract <- pilot_rows[c(key, "pilot_valid", "tau_raw")]
  names(pilot_contract)[(length(key) + 1L):ncol(pilot_contract)] <-
    c("pilot_valid_contract", "pilot_tau_raw_contract")
  finals <- merge(x[x$arm != "pilot_unpenalised", ], pilot_contract,
                  by = key, all.x = TRUE)
  if (anyNA(finals$pilot_valid_contract)) stop(label, ": pilot pairing failed")

  shipped <- finals$arm == "fixed2_shipped"
  if (any(finals$tau_used[shipped] != 2 | finals$tau_cap[shipped] != 2,
          na.rm = TRUE) || anyNA(finals$tau_used[shipped])) {
    stop(label, ": shipped tau=2 contract changed")
  }
  dependent <- !shipped
  invalid <- dependent & !finals$pilot_valid_contract
  if (any(as.logical(finals$ok[invalid]), na.rm = TRUE) ||
      any(is.finite(finals$tau_used[invalid])) || any(is.finite(finals$tau_raw[invalid]))) {
    stop(label, ": a final arm used an invalid pilot")
  }
  valid <- dependent & finals$pilot_valid_contract
  if (anyNA(finals$pilot_ok[valid]) || anyNA(finals$pilot_converged[valid]) ||
      anyNA(finals$pilot_k[valid]) || anyNA(finals$pilot_n_starts[valid]) ||
      anyNA(finals$tau_raw[valid]) ||
      any(!as.logical(finals$pilot_ok[valid])) ||
      any(!as.logical(finals$pilot_converged[valid])) ||
      any(finals$pilot_k[valid] != 9L) || any(finals$pilot_n_starts[valid] < 2L) ||
      any(abs(finals$tau_raw[valid] - finals$pilot_tau_raw_contract[valid]) > 1e-12)) {
    stop(label, ": final-arm pilot provenance mismatch")
  }
  fixed <- valid & finals$arm == "fixed2_pilot"
  if (any(finals$tau_used[fixed] != 2 | finals$tau_cap[fixed] != 2)) {
    stop(label, ": fixed2_pilot tau contract changed")
  }
  auto <- valid & grepl("^auto_", finals$arm)
  expected_auto_tau <- pmin(finals$tau_cap[auto], finals$tau_raw[auto])
  if (any(abs(finals$tau_used[auto] - expected_auto_tau) > 1e-12) ||
      any(as.logical(finals$tau_clipped[auto]) !=
            (is.finite(finals$tau_cap[auto]) &
               finals$tau_raw[auto] > finals$tau_cap[auto]))) {
    stop(label, ": scale-aware tau identity changed")
  }
  invisible(shas[[1L]])
}

validate_tau_contract(dat, "INPUT")

is_failure <- function(x) {
  !as.logical(x$ok) | !as.logical(x$converged) | !as.logical(x$aghq_used) |
    !is.finite(x$frob_rat)
}
paired_boot <- function(delta, probs = c(0.05, 0.95), seed = 1L) {
  delta <- delta[is.finite(delta)]
  if (!length(delta)) return(rep(NA_real_, length(probs)))
  set.seed(seed)
  draws <- replicate(B, mean(sample(delta, length(delta), replace = TRUE)))
  as.numeric(stats::quantile(draws, probs = probs, names = FALSE, type = 8))
}
stratified_boot <- function(delta, strata, probs = c(0.025, 0.975), seed = 1L) {
  keep <- is.finite(delta) & !is.na(strata)
  delta <- delta[keep]
  strata <- strata[keep]
  levels <- sort(unique(strata))
  if (!length(levels) || any(!levels %in% c(100L, 400L, 1600L))) {
    return(rep(NA_real_, length(probs)))
  }
  split_delta <- split(delta, strata)
  if (!all(as.character(c(100L, 400L, 1600L)) %in% names(split_delta))) {
    return(rep(NA_real_, length(probs)))
  }
  set.seed(seed)
  draws <- replicate(B, mean(vapply(split_delta, function(z) {
    mean(sample(z, length(z), replace = TRUE))
  }, numeric(1))))
  as.numeric(stats::quantile(draws, probs = probs, names = FALSE, type = 8))
}

selection_md5 <- NA_character_
selection_verdict_md5 <- NA_character_
if (PHASE == "confirm") {
  if (!nzchar(SELECTION_INPUT) || !file.exists(SELECTION_INPUT) ||
      !nzchar(SELECTION_VERDICT) || !file.exists(SELECTION_VERDICT)) {
    stop("confirmation requires SELECTION_INPUT and SELECTION_VERDICT receipts")
  }
  verdict_text <- paste(readLines(SELECTION_VERDICT, warn = FALSE), collapse = "\n")
  locked_arm <- paste0("auto_cap", format(LOCKED_CAP, trim = TRUE))
  if (!grepl(paste0("Decision: \\*\\*LOCK_", locked_arm, "\\*\\*"), verdict_text)) {
    stop("LOCKED_CAP does not match the selection verdict")
  }
  selection_dat <- utils::read.csv(SELECTION_INPUT, stringsAsFactors = FALSE)
  selection_arms <- c(
    "fixed2_shipped", "pilot_unpenalised", "fixed2_pilot",
    "auto_uncapped", "auto_cap5", "auto_cap6", "auto_cap8"
  )
  if (!all(need %in% names(selection_dat)) ||
      !all(selection_dat$phase == "selection") ||
      !setequal(unique(selection_dat$arm), selection_arms) ||
      anyDuplicated(selection_dat[c("phase", "n", "lam_sd", "task", "seed", "arm")]) ||
      anyDuplicated(selection_dat[c("arm", "n", "lam_sd", "seed")])) {
    stop("selection campaign receipt is malformed")
  }
  selection_counts <- aggregate(task ~ arm + n + lam_sd, selection_dat, length)
  if (nrow(selection_counts) != length(selection_arms) * 6L ||
      any(selection_counts$task != 100L)) {
    stop("selection campaign receipt is incomplete")
  }
  selection_cells <- unique(selection_dat[c("n", "lam_sd")])
  if (nrow(selection_cells) != 6L ||
      nrow(merge(expected_cells, selection_cells, by = c("n", "lam_sd"))) != 6L) {
    stop("selection campaign receipt has the wrong cell grid")
  }
  selection_key_sets <- lapply(selection_arms, function(a) {
    x <- selection_dat[selection_dat$arm == a, pair_key]
    do.call(paste, c(x, sep = "|"))
  })
  if (!all(vapply(selection_key_sets[-1L], setequal, logical(1),
                  selection_key_sets[[1L]]))) {
    stop("selection campaign receipt is not completely paired")
  }
  selection_sha <- validate_tau_contract(selection_dat, "SELECTION_INPUT")
  if (!identical(selection_sha, unique(dat$package_sha))) {
    stop("selection and confirmation used different installed package SHAs")
  }
  selection_keys <- unique(selection_dat[selection_dat$arm == "pilot_unpenalised", c("n", "lam_sd", "seed")])
  confirm_keys <- unique(dat[dat$arm == "pilot_unpenalised", c("n", "lam_sd", "seed")])
  overlap <- merge(selection_keys, confirm_keys, by = c("n", "lam_sd", "seed"))
  if (nrow(overlap)) stop("confirmation seeds overlap selection seeds")

  ## Do not trust editable verdict prose as the cap lock. Re-run the selection
  ## analyser deterministically from the sealed campaign CSV and require it to
  ## choose the same cap before any confirmation calculation is inspected.
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) != 1L) stop("cannot locate this analyser for selection recheck")
  script_path <- normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE)
  recheck_prefix <- tempfile("tau-selection-recheck-")
  recheck <- system2(
    file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(script_path)),
    env = c(
      "PHASE=selection",
      paste0("INPUT=", SELECTION_INPUT),
      paste0("OUTPUT=", recheck_prefix),
      paste0("BOOT_REPS=", B)
    ),
    stdout = TRUE, stderr = TRUE
  )
  recheck_status <- attr(recheck, "status")
  if (!is.null(recheck_status) && recheck_status != 0L) {
    stop("deterministic selection recheck failed: ", paste(recheck, collapse = " | "))
  }
  recheck_decision <- grep(
    "^(LOCK_auto_cap[0-9.]+|NO_CAP_PASSED_SELECTION)$",
    trimws(recheck), value = TRUE
  )
  if (length(recheck_decision) != 1L ||
      !identical(trimws(recheck_decision), paste0("LOCK_", locked_arm))) {
    stop("LOCKED_CAP does not match deterministic selection recheck")
  }
  selection_md5 <- unname(tools::md5sum(SELECTION_INPUT))
  selection_verdict_md5 <- unname(tools::md5sum(SELECTION_VERDICT))
}

baseline <- dat[dat$arm == "fixed2_pilot", ]
operational <- dat[dat$arm == "fixed2_shipped", c(
  key, "ok", "converged", "aghq_used", "frob_rat"
)]
names(operational)[(length(key) + 1L):ncol(operational)] <- paste0(
  c("ok", "converged", "aghq_used", "frob_rat"), "_operational"
)
pilot <- dat[dat$arm == "pilot_unpenalised", c(key, "ok", "converged", "frob_rat")]
names(pilot)[(length(key) + 1L):ncol(pilot)] <- c(
  "pilot_ok_row", "pilot_converged_row", "pilot_frob_rat"
)
if (!nrow(baseline)) stop("fixed2_pilot comparator is absent")

candidate_arms <- if (PHASE == "selection") {
  c("auto_cap5", "auto_cap6", "auto_cap8", "auto_uncapped")
} else {
  target <- paste0("auto_cap", format(LOCKED_CAP, trim = TRUE))
  if (!target %in% dat$arm) stop("locked confirmation arm is absent: ", target)
  target
}

rows <- list()
pair_cache <- list()
for (a_idx in seq_along(candidate_arms)) {
  arm <- candidate_arms[a_idx]
  cand <- dat[dat$arm == arm, ]
  z <- merge(
    cand, baseline,
    by = key, suffixes = c("_candidate", "_baseline"), all = FALSE
  )
  z <- merge(z, operational, by = key, all = FALSE)
  z <- merge(z, pilot, by = key, all.x = TRUE)
  if (!nrow(z)) next
  z$failure_candidate <- is_failure(data.frame(
    ok = z$ok_candidate, converged = z$converged_candidate,
    aghq_used = z$aghq_used_candidate, frob_rat = z$frob_rat_candidate
  ))
  z$failure_baseline <- is_failure(data.frame(
    ok = z$ok_baseline, converged = z$converged_baseline,
    aghq_used = z$aghq_used_baseline, frob_rat = z$frob_rat_baseline
  ))
  z$failure_operational <- is_failure(data.frame(
    ok = z$ok_operational, converged = z$converged_operational,
    aghq_used = z$aghq_used_operational, frob_rat = z$frob_rat_operational
  ))
  ## A failed/nonconverged fit is adverse, not silently absent from the runaway
  ## denominator. rho MAE remains a successful-pair estimand; its usable pair
  ## count is reported and the separate failure gate prevents attrition hiding.
  z$runaway_candidate <- z$failure_candidate | z$frob_rat_candidate > 2
  z$runaway_operational <- z$failure_operational | z$frob_rat_operational > 2
  z$rho_delta <- z$rho_mae_candidate - z$rho_mae_baseline
  z$rho_delta[z$failure_candidate | z$failure_baseline] <- NA_real_
  z$loading_delta <- z$loading_log_error_candidate - z$loading_log_error_baseline
  z$loading_delta[z$failure_candidate | z$failure_baseline] <- NA_real_
  pair_cache[[arm]] <- z

  for (cell_idx in seq_len(nrow(unique(z[c("n", "lam_sd")])))) {
    cell <- unique(z[c("n", "lam_sd")])[cell_idx, ]
    zz <- z[z$n == cell$n & z$lam_sd == cell$lam_sd, ]
    run_delta <- as.numeric(zz$runaway_candidate) - as.numeric(zz$runaway_operational)
    fail_delta <- as.numeric(zz$failure_candidate) - as.numeric(zz$failure_operational)
    run_ci <- paired_boot(run_delta, seed = 1000L + 100L * a_idx + cell_idx)
    fail_ci <- paired_boot(fail_delta, seed = 2000L + 100L * a_idx + cell_idx)
    rho_ci <- paired_boot(zz$rho_delta, seed = 3000L + 100L * a_idx + cell_idx)
    nonrun_pilot <- as.logical(zz$pilot_ok_row) & as.logical(zz$pilot_converged_row) &
      is.finite(zz$pilot_frob_rat) & zz$pilot_frob_rat <= 2
    clip_rate <- if (any(nonrun_pilot)) {
      mean(as.logical(zz$tau_clipped_candidate[nonrun_pilot]))
    } else NA_real_
    rows[[length(rows) + 1L]] <- data.frame(
      arm = arm, n = cell$n, lam_sd = cell$lam_sd,
      pairs = nrow(zz), rho_pairs = sum(is.finite(zz$rho_delta)),
      runaway_diff = mean(run_delta), runaway_upper95 = run_ci[2L],
      failure_diff = mean(fail_delta), failure_upper95 = fail_ci[2L],
      rho_mae_diff = mean(zz$rho_delta, na.rm = TRUE), rho_mae_upper95 = rho_ci[2L],
      nonrun_pilots = sum(nonrun_pilot), clip_rate = clip_rate,
      loading_error_diff = mean(zz$loading_delta, na.rm = TRUE),
      pass_runaway = is.finite(run_ci[2L]) && run_ci[2L] <= 0.02,
      pass_failure = is.finite(fail_ci[2L]) && fail_ci[2L] <= 0.01,
      pass_rho = is.finite(rho_ci[2L]) && rho_ci[2L] <= 0.02,
      pass_clip = is.finite(clip_rate) && clip_rate <= 0.05,
      stringsAsFactors = FALSE
    )
  }
}

gates <- do.call(rbind, rows)
if (is.null(gates) || !nrow(gates)) stop("no paired candidate rows were found")
gates$eligible_cell <- with(gates, pass_runaway & pass_failure & pass_rho & pass_clip)
utils::write.csv(gates, paste0(OUTPUT, "-gates.csv"), row.names = FALSE)

selectable <- setdiff(candidate_arms, "auto_uncapped")
complete_sets <- lapply(selectable, function(arm) {
  z <- pair_cache[[arm]]
  z <- z[is.finite(z$loading_delta), pair_key, drop = FALSE]
  do.call(paste, c(z, sep = "|"))
})
common_loading_keys <- if (length(complete_sets)) Reduce(intersect, complete_sets) else character(0)
summary_rows <- lapply(selectable, function(arm) {
  z <- pair_cache[[arm]]
  g <- gates[gates$arm == arm, ]
  z$key_id <- do.call(paste, c(z[pair_key], sep = "|"))
  common <- z$key_id %in% common_loading_keys
  data.frame(
    arm = arm,
    all_cells_eligible = nrow(g) > 0L && all(g$eligible_cell),
    successful_loading_pairs = sum(is.finite(z$loading_delta)),
    common_loading_pairs = sum(common),
    mean_candidate_loading_error = mean(
      z$loading_log_error_candidate[common], na.rm = TRUE
    ),
    mean_paired_loading_delta = mean(z$loading_delta[common], na.rm = TRUE),
    stringsAsFactors = FALSE
  )
})
summary_tab <- do.call(rbind, summary_rows)
selected <- NA_character_
if (PHASE == "selection") {
  eligible <- summary_tab[
    summary_tab$all_cells_eligible & is.finite(summary_tab$mean_candidate_loading_error),
  ]
  if (nrow(eligible)) {
    selected <- eligible$arm[which.min(eligible$mean_candidate_loading_error)]
  }
} else {
  selected <- candidate_arms[[1L]]
}

confirmation <- NULL
decision <- if (PHASE == "selection") {
  if (is.na(selected)) "NO_CAP_PASSED_SELECTION" else paste0("LOCK_", selected)
} else {
  z <- pair_cache[[selected]]
  sigma3 <- z[z$lam_sd == 3, ]
  improve_ci <- stratified_boot(
    sigma3$loading_delta, sigma3$n, c(0.025, 0.975), seed = 9001L
  )
  n_levels <- sort(unique(sigma3$n))
  n_ci <- do.call(rbind, lapply(seq_along(n_levels), function(i) {
    zz <- sigma3[sigma3$n == n_levels[i], ]
    ci <- paired_boot(zz$loading_delta, c(0.025, 0.975), seed = 9100L + i)
    data.frame(n = n_levels[i], loading_delta = mean(zz$loading_delta, na.rm = TRUE),
               lower95 = ci[1L], upper95 = ci[2L])
  }))
  confirmation <- list(improve_ci = improve_ci, n_ci = n_ci)
  gates_again <- all(gates$eligible_cell)
  improves <- all(is.finite(improve_ci)) && improve_ci[2L] < 0
  no_supported_harm <- all(is.finite(n_ci$lower95)) &&
    all(is.finite(n_ci$upper95)) && all(n_ci$lower95 <= 0)
  if (gates_again && improves && no_supported_harm) "CONFIRMED_FOR_DEFAULT" else
    "CONFIRMATION_FAILED_KEEP_FIXED2"
}

utils::write.csv(summary_tab, paste0(OUTPUT, "-summary.csv"), row.names = FALSE)
lines <- c(
  paste0("# Tau cap ", PHASE, " verdict"), "",
  paste0("- Input: `", normalizePath(INPUT), "`"),
  paste0("- Bootstrap replicates: ", B),
  paste0("- Operational failure/runaway comparator: `fixed2_shipped`"),
  paste0("- Tau-only accuracy comparator: `fixed2_pilot` (same pilot and warm start)"),
  if (PHASE == "confirm") paste0("- Selection CSV MD5: `", selection_md5, "`") else NULL,
  if (PHASE == "confirm") paste0("- Selection verdict MD5: `", selection_verdict_md5, "`") else NULL,
  paste0("- Decision: **", decision, "**"), "",
  "Failed/nonconverged fits count as adverse in both failure and runaway rates. ",
  "Correlation MAE and loading error use successful pairs, with the retained ",
  "pair count reported beside the separate all-fit failure gate. `auto_uncapped` ",
  "is a safety control and is never selectable."
)
if (!is.null(confirmation)) {
  lines <- c(lines, "", sprintf(
    "Sigma-lambda=3 paired loading-error difference 95%% CI: [%.6f, %.6f].",
    confirmation$improve_ci[1L], confirmation$improve_ci[2L]
  ), "", "Per-n confirmation intervals:", "",
  paste(capture.output(print(confirmation$n_ci, row.names = FALSE)), collapse = "\n"))
}
writeLines(lines, paste0(OUTPUT, "-verdict.md"))
cat(decision, "\n")
