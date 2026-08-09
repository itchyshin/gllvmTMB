## Prospective Phase C prediction-evidence supplement.
##
## Consumes only the fixed outputs of dev/isdm-phase-c-analyse-official.R.
## It never discovers or opens raw campaign, C-lite, smoke, preflight, or pilot
## result paths recorded in the copied manifest.
##
## Usage:
##   Rscript dev/isdm-phase-c-analysis-supplement.R \
##     --official-dir=/path/to/official-analysis \
##     --out-dir=/external/path/to/supplement
##   Rscript dev/isdm-phase-c-analysis-supplement.R --self-test

.stopf <- function(fmt, ...) stop(sprintf(fmt, ...), call. = FALSE)
.near <- function(x, y, tol = 1e-10) is.finite(x) & abs(x - y) <= tol

.piece <- function(x) {
  if (is.numeric(x)) ifelse(is.na(x), "<NA>", sprintf("%.17g", x)) else {
    z <- as.character(x); ifelse(is.na(z), "<NA>", z)
  }
}

.key <- function(x, cols) {
  miss <- setdiff(cols, names(x))
  if (length(miss)) .stopf("Key columns missing: %s", paste(miss, collapse = ", "))
  do.call(paste, c(lapply(x[cols], .piece), sep = "\r"))
}

.stats <- function(x) {
  x <- x[is.finite(x)]; n <- length(x)
  if (!n) return(c(n = 0, mean = NA, sd = NA, mcse = NA))
  sx <- if (n > 1L) stats::sd(x) else NA_real_
  c(n = n, mean = mean(x), sd = sx, mcse = if (n > 1L) sx / sqrt(n) else NA)
}

.rbind_rows <- function(xs) {
  xs <- Filter(function(x) !is.null(x) && nrow(x), xs)
  if (!length(xs)) return(data.frame())
  cols <- unique(unlist(lapply(xs, names), use.names = FALSE))
  xs <- lapply(xs, function(x) {
    for (nm in setdiff(cols, names(x))) x[[nm]] <- NA
    x[cols]
  })
  out <- do.call(rbind, xs); rownames(out) <- NULL; out
}

.required_files <- c(
  primary = "01-primary-endpoint.csv",
  paired_summary = "02-paired-headline-summary.csv",
  c1c2 = "03-c1-c2-verdicts.csv",
  a5a6 = "04-c3-a5-a6-summary.csv",
  ladders = "06-g2-g6-ladder-vs-ref.csv",
  status = "09-fit-status-by-cell.csv",
  paired = "10-paired-fit-level.rds",
  manifest = "11-input-manifest.csv"
)

.output_files <- c(
  "00-p-primary-receipt-copy.csv",
  "01-p-dose-evidence.csv",
  "02-p-structure-evidence.csv",
  "03-p-integration-evidence.csv",
  "04-p-separation-evidence.csv",
  "05-p-rank-evidence.csv",
  "06-claim-verdict-ledger.csv",
  "07-supplement-input-receipt.csv",
  "08-official-input-manifest-copy.csv",
  "figure-ddbias-curves.pdf", "figure-ddbias-curves.png",
  "figure-beta-separation.pdf", "figure-beta-separation.png",
  "figure-ladders-rank.pdf", "figure-ladders-rank.png"
)

.parse_cli <- function(args) {
  if (identical(args, "--help")) {
    cat("Usage: Rscript dev/isdm-phase-c-analysis-supplement.R ",
        "--official-dir=DIR --out-dir=DIR\n",
        "       Rscript dev/isdm-phase-c-analysis-supplement.R --self-test\n", sep = "")
    return(list(help = TRUE))
  }
  if (identical(args, "--self-test")) return(list(help = FALSE, self_test = TRUE))
  out <- list(help = FALSE, self_test = FALSE)
  for (arg in args) {
    if (!grepl("^--[^=]+=.+$", arg)) .stopf("Options must use --name=value: %s", arg)
    kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1]]
    nm <- gsub("-", "_", kv[[1]]); val <- paste(kv[-1], collapse = "=")
    if (!is.null(out[[nm]])) .stopf("Option supplied twice: --%s", kv[[1]])
    out[[nm]] <- val
  }
  if (is.null(out$official_dir) || is.null(out$out_dir)) {
    .stopf("--official-dir and --out-dir are required")
  }
  unknown <- setdiff(names(out), c("help", "self_test", "official_dir", "out_dir"))
  if (length(unknown)) .stopf("Unknown option(s): %s", paste(unknown, collapse = ", "))
  out
}

.reject_path <- function(path, label) {
  bad <- "(^|[-_.])(c-?lite|lite|old|smoke|preflight)([-_.]|$)"
  if (grepl(bad, tolower(path), perl = TRUE)) .stopf("Rejected %s path: %s", label, path)
}

.require_cols <- function(x, cols, label) {
  miss <- setdiff(cols, names(x))
  if (length(miss)) .stopf("%s missing columns: %s", label, paste(miss, collapse = ", "))
}

.validate_stage_blocks <- function(x, blocks, label) {
  .require_cols(x, c("stage", "block"), label)
  if (!nrow(x) || any(as.character(x$stage) != "campaign")) {
    .stopf("%s must contain campaign rows only", label)
  }
  got <- sort(unique(as.character(x$block)))
  if (!identical(got, sort(blocks))) {
    .stopf("%s block schema mismatch: expected %s; got %s", label,
           paste(sort(blocks), collapse = ","), paste(got, collapse = ","))
  }
}

.load_official <- function(dir) {
  .reject_path(dir, "official-analysis")
  if (!dir.exists(dir)) .stopf("Official analysis directory does not exist: %s", dir)
  dir <- normalizePath(dir, mustWork = TRUE)
  paths <- file.path(dir, .required_files)
  names(paths) <- names(.required_files)
  if (any(!file.exists(paths))) {
    .stopf("Official output(s) missing: %s", paste(basename(paths[!file.exists(paths)]), collapse = ", "))
  }
  manifest <- utils::read.csv(paths[["manifest"]], stringsAsFactors = FALSE,
                              check.names = FALSE)
  .require_cols(manifest, c("stage", "block", "input", "rows"), "official manifest")
  expected <- data.frame(stage = c("pilot_v2", rep("campaign", 6)),
                         block = c("G1", paste0("G", 1:6)))
  observed <- unique(manifest[c("stage", "block")])
  observed <- observed[order(observed$stage, observed$block), , drop = FALSE]
  expected <- expected[order(expected$stage, expected$block), , drop = FALSE]
  rownames(observed) <- rownames(expected) <- NULL
  if (!identical(observed, expected)) .stopf("Official manifest stage/block schema failed")
  if (anyDuplicated(manifest[c("stage", "block")])) .stopf("Official manifest has stage/block collisions")
  if (any(grepl("(^|[-_.])(c-?lite|lite|old|smoke|preflight)([-_.]|$)",
                tolower(basename(manifest$input)), perl = TRUE))) {
    .stopf("Official manifest records a forbidden C-lite/old/smoke/preflight input")
  }

  out <- list(
    primary = utils::read.csv(paths[["primary"]], stringsAsFactors = FALSE),
    paired_summary = utils::read.csv(paths[["paired_summary"]], stringsAsFactors = FALSE),
    c1c2 = utils::read.csv(paths[["c1c2"]], stringsAsFactors = FALSE),
    a5a6 = utils::read.csv(paths[["a5a6"]], stringsAsFactors = FALSE),
    ladders = utils::read.csv(paths[["ladders"]], stringsAsFactors = FALSE),
    status = utils::read.csv(paths[["status"]], stringsAsFactors = FALSE),
    paired = readRDS(paths[["paired"]]), manifest = manifest, paths = paths
  )
  if (!is.data.frame(out$paired)) .stopf("10-paired-fit-level.rds is not a data.frame")
  .validate_stage_blocks(out$primary, "G1", "primary endpoint")
  .validate_stage_blocks(out$paired_summary, paste0("G", 1:6), "paired summary")
  .validate_stage_blocks(out$c1c2, paste0("G", 1:6), "C1/C2 table")
  .validate_stage_blocks(out$a5a6, paste0("G", 1:6), "A5/A6 table")
  .validate_stage_blocks(out$ladders, paste0("G", 2:6), "ladder table")
  .validate_stage_blocks(out$status, paste0("G", 1:6), "fit-status table")
  .validate_stage_blocks(out$paired, paste0("G", 1:6), "paired fit-level data")

  req_paired <- c(
    "stage", "block", "seed", "arm", "kappa", "rho", "omega", "phi_x",
    "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift", "estimand",
    "completed_pair", "both_pdHess", "dD_bias", "dsignflip", "ddiag_rmse",
    "dpsi_rmse", "dbeta_bias", "headline_eligible"
  )
  .require_cols(out$paired, req_paired, "paired fit-level data")
  if (any(!.near(out$paired$phi_x, 0.15))) .stopf("Paired data violate phi_x=0.15")
  key_cols <- c("stage", "block", "seed", "arm", "kappa", "rho", "omega",
                "phi_x", "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  if (anyDuplicated(.key(out$paired, key_cols))) .stopf("Paired fit-level full-key collision")
  core <- c("dD_bias", "dsignflip", "ddiag_rmse", "dpsi_rmse", "dbeta_bias")
  total <- out$paired$completed_pair & out$paired$estimand == "total_sigma"
  for (nm in core) if (any(total & !is.finite(out$paired[[nm]]))) {
    .stopf("Completed total-Sigma pairs contain non-finite %s", nm)
  }
  if (any(out$paired$block == "G5" & out$paired$arm == "A2" &
          out$paired$headline_eligible)) .stopf("G5/A2 leaked into headline-eligible rows")
  out
}

.summarise <- function(x, group_cols, value, complete = "completed_pair",
                       pd = "both_pdHess") {
  if (!nrow(x)) return(data.frame())
  groups <- split(seq_len(nrow(x)), .key(x, group_cols))
  rows <- lapply(groups, function(ii) {
    z <- x[ii, , drop = FALSE]; row <- z[1L, group_cols, drop = FALSE]
    sa <- .stats(z[[value]][z[[complete]]]); sp <- .stats(z[[value]][z[[pd]]])
    row$n_all <- sa[["n"]]; row$estimate_all <- sa[["mean"]]; row$mcse_all <- sa[["mcse"]]
    row$n_both_pdHess <- sp[["n"]]; row$estimate_both_pdHess <- sp[["mean"]]
    row$mcse_both_pdHess <- sp[["mcse"]]; row$metric <- value; row
  })
  out <- do.call(rbind, rows); rownames(out) <- NULL; out
}

.matched <- function(x, left, right, match_cols, value, contrast_name) {
  a <- x[left, , drop = FALSE]; b <- x[right, , drop = FALSE]
  kb <- .key(b, match_cols)
  if (anyDuplicated(kb)) .stopf("%s right-hand match is not unique", contrast_name)
  idx <- match(.key(a, match_cols), kb)
  if (!nrow(a) || anyNA(idx)) .stopf("%s lacks a complete same-seed match", contrast_name)
  out <- a
  out[[contrast_name]] <- ifelse(a$completed_pair & b$completed_pair[idx],
                                 a[[value]] - b[[value]][idx], NA_real_)
  out$contrast_complete <- a$completed_pair & b$completed_pair[idx]
  out$contrast_both_pdHess <- a$both_pdHess & b$both_pdHess[idx]
  out
}

.seed_fixed_trend <- function(x, group_cols, value) {
  groups <- split(seq_len(nrow(x)), .key(x, group_cols))
  rows <- lapply(groups, function(ii) {
    z <- x[ii, , drop = FALSE]; row <- z[1L, group_cols, drop = FALSE]
    levels_k <- sort(unique(z$kappa))
    by_seed <- split(z, z$seed)
    by_seed <- Filter(function(s) all(levels_k %in% s$kappa) && all(s$completed_pair), by_seed)
    if (!length(by_seed)) .stopf("Trend group lacks complete same-seed kappa ladders")
    zz <- do.call(rbind, by_seed)
    fit <- stats::lm(zz[[value]] ~ zz$kappa + factor(zz$seed))
    co <- summary(fit)$coefficients
    slope <- unname(co[2L, 1L]); se <- unname(co[2L, 2L])
    seed_slopes <- vapply(by_seed, function(s) coef(stats::lm(s[[value]] ~ s$kappa))[2], numeric(1))
    seed_rho <- vapply(by_seed, function(s) stats::cor(s$kappa, s[[value]], method = "spearman"), numeric(1))
    row$n_complete_seeds <- length(by_seed)
    row$seed_fixed_ols_slope <- slope; row$seed_fixed_ols_se <- se
    row$positive_at_3se <- is.finite(se) && slope >= 3 * se
    row$mean_seed_slope <- mean(seed_slopes); row$mcse_seed_slope <- .stats(seed_slopes)[["mcse"]]
    row$mean_seed_spearman <- mean(seed_rho)
    row$n_seed_spearman_positive <- sum(seed_rho > 0)
    row$all_seed_spearman_positive <- all(seed_rho > 0)
    row
  })
  out <- do.call(rbind, rows); rownames(out) <- NULL; out
}

.ledger_row <- function(prediction, component, rule_class, rule, verdict,
                        estimate = NA, mcse = NA, source, note = "") {
  data.frame(prediction, component, rule_class, frozen_rule = rule, verdict,
             estimate, mcse, source, note, stringsAsFactors = FALSE)
}

.prediction_evidence <- function(o) {
  p <- o$paired[o$paired$stage == "campaign" & o$paired$headline_eligible, ]
  g1 <- p[p$block == "G1", ]
  led <- list()

  ## P-primary: preserve the official receipt rather than recalculating it.
  primary <- o$primary
  .require_cols(primary, c("primary_clears_all", "dD_bias_mean_all", "dD_bias_mcse_all"),
                "primary endpoint")
  led[[length(led) + 1L]] <- .ledger_row(
    "P-primary", "A1 frozen endpoint", "FROZEN_PASS_FAIL",
    "mean dD_bias >= 0.10 and >= 3 MCSE",
    ifelse(primary$primary_clears_all, "PASS", "FAIL"),
    primary$dD_bias_mean_all, primary$dD_bias_mcse_all, "01-primary-endpoint.csv")

  ## P-dose.
  dose_raw <- g1[g1$arm %in% c("A1", "A3"), ]
  dose <- .seed_fixed_trend(dose_raw, c("stage", "block", "arm", "rho", "omega"), "dD_bias")
  dose_c1 <- o$c1c2[o$c1c2$block == "G1" & o$c1c2$arm %in% c("A1", "A3"), ]
  .require_cols(dose_c1, c("arm", "rho", "omega", "kappa", "C1_all"), "P-dose C1 table")
  c1_groups <- split(seq_len(nrow(dose_c1)), .key(dose_c1, c("arm", "rho", "omega")))
  first_cross <- do.call(rbind, lapply(c1_groups, function(ii) {
    z <- dose_c1[ii, ]; hit <- z$kappa[!is.na(z$C1_all) & z$C1_all]
    data.frame(arm=z$arm[1],rho=z$rho[1],omega=z$omega[1],
               first_C1_kappa=if(length(hit))min(hit) else NA_real_)
  }))
  dose <- merge(dose, first_cross, by = c("arm", "rho", "omega"), all.x = TRUE, sort = FALSE)
  dose$C1_by_kappa_1 <- is.finite(dose$first_C1_kappa) & dose$first_C1_kappa <= 1
  dose$rule <- paste0("positive seed-fixed OLS slope at >=3 SE; every seed Spearman > 0; ",
                      "first C1 crossing at kappa <= 1")
  dose$verdict <- ifelse(dose$positive_at_3se & dose$all_seed_spearman_positive &
                           dose$C1_by_kappa_1, "PASS", "FAIL")
  for (i in seq_len(nrow(dose))) led[[length(led) + 1L]] <- .ledger_row(
    "P-dose", paste(dose$arm[i], "rho", dose$rho[i], "omega", dose$omega[i]),
    "FROZEN_PASS_FAIL", dose$rule[i], dose$verdict[i], dose$seed_fixed_ols_slope[i],
    dose$seed_fixed_ols_se[i], "01-p-dose-evidence.csv",
    sprintf("%d/%d seed Spearman correlations positive", dose$n_seed_spearman_positive[i],
            dose$n_complete_seeds[i]))

  ## P-structure: exact same-seed omega gaps; omega=0 diagonal response stays descriptive.
  match_omega <- c("stage", "block", "seed", "arm", "kappa", "rho", "phi_x",
                   "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  om10 <- .matched(g1, .near(g1$omega, 1), .near(g1$omega, 0.5), match_omega,
                   "dD_bias", "omega_1_minus_0_5")
  om50 <- .matched(g1, .near(g1$omega, 0.5), .near(g1$omega, 0), match_omega,
                   "dD_bias", "omega_0_5_minus_0")
  structure <- .rbind_rows(list(
    .summarise(om10, c("stage", "block", "arm", "kappa", "rho"),
               "omega_1_minus_0_5", "contrast_complete", "contrast_both_pdHess"),
    .summarise(om50, c("stage", "block", "arm", "kappa", "rho"),
               "omega_0_5_minus_0", "contrast_complete", "contrast_both_pdHess"),
    .summarise(g1[.near(g1$omega, 0) & .near(g1$rho, 0), ],
               c("stage", "block", "arm", "kappa", "rho", "omega"), "ddiag_rmse"),
    .summarise(g1[.near(g1$omega, 0) & .near(g1$rho, 0), ],
               c("stage", "block", "arm", "kappa", "rho", "omega"), "dpsi_rmse")
  ))
  structure$rule_class <- ifelse(grepl("omega_", structure$metric),
                                 "FROZEN_PASS_FAIL", "DESCRIPTIVE_UNRESOLVED")
  structure$verdict <- ifelse(
    structure$rule_class == "FROZEN_PASS_FAIL",
    ifelse(structure$estimate_all >= 3 * structure$mcse_all, "PASS", "FAIL"),
    "NO_FROZEN_DIAGONAL_THRESHOLD")
  for (i in seq_len(nrow(structure))) led[[length(led) + 1L]] <- .ledger_row(
    "P-structure", structure$metric[i], structure$rule_class[i],
    ifelse(structure$rule_class[i] == "FROZEN_PASS_FAIL", "matched gap >= 3 MCSE",
           "report diagonal metric; no adaptive threshold"), structure$verdict[i],
    structure$estimate_all[i], structure$mcse_all[i], "02-p-structure-evidence.csv")

  ## P-integration: matched A1-A5 and A5 C1 at kappa=2.
  match_arm <- c("stage", "block", "seed", "kappa", "rho", "omega", "phi_x",
                 "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift")
  a1a5 <- .matched(g1, g1$arm == "A1", g1$arm == "A5", match_arm,
                   "dD_bias", "A1_minus_A5_dD_bias")
  integration <- .summarise(a1a5,
    c("stage", "block", "kappa", "rho", "omega"), "A1_minus_A5_dD_bias",
    "contrast_complete", "contrast_both_pdHess")
  integration$component <- "A1_minus_A5"
  c1a5 <- o$c1c2[o$c1c2$arm == "A5" & .near(o$c1c2$kappa, 2), ]
  .require_cols(c1a5, c("C1_all", "dD_bias_mean_all", "dD_bias_mcse_all"), "A5 C1")
  c1extra <- data.frame(stage = c1a5$stage, block = c1a5$block, kappa = c1a5$kappa,
                        rho = c1a5$rho, omega = c1a5$omega,
                        estimate_all = c1a5$dD_bias_mean_all,
                        mcse_all = c1a5$dD_bias_mcse_all,
                        component = "A5_C1_at_kappa2", C1_all = c1a5$C1_all)
  for (i in seq_len(nrow(integration))) led[[length(led) + 1L]] <- .ledger_row(
    "P-integration", "A1 minus A5", "FROZEN_PASS_FAIL", "matched gap >= 3 MCSE",
    ifelse(integration$estimate_all[i] >= 3 * integration$mcse_all[i], "PASS", "FAIL"),
    integration$estimate_all[i], integration$mcse_all[i], "03-p-integration-evidence.csv")
  for (i in seq_len(nrow(c1extra))) led[[length(led) + 1L]] <- .ledger_row(
    "P-integration", "A5 corrupted at kappa=2", "FROZEN_PASS_FAIL", "A5 satisfies C1",
    ifelse(c1extra$C1_all[i], "PASS", "FAIL"), c1extra$estimate_all[i],
    c1extra$mcse_all[i], "03-p-integration-evidence.csv")
  integration <- .rbind_rows(list(integration, c1extra))

  ## P-separation: grid plus rho=.6 seed-fixed slopes. Within-3-MCSE is
  ## explicitly a diagnostic, not evidence of equivalence to zero.
  separation_grid <- .summarise(g1,
    c("stage", "block", "arm", "kappa", "rho", "omega"), "dbeta_bias")
  separation_grid$component <- "dBeta_bias_grid"
  sep_trend <- .seed_fixed_trend(g1[.near(g1$rho, 0.6), ],
    c("stage", "block", "arm", "rho", "omega"), "dbeta_bias")
  sep_trend$component <- "rho0.6_seed_fixed_slope"
  for (i in which(.near(separation_grid$rho, 0))) led[[length(led) + 1L]] <- .ledger_row(
    "P-separation", "rho=0 zero diagnostic", "FROZEN_DIAGNOSTIC_NOT_EQUIVALENCE",
    "abs(mean dBeta_bias) <= 3 MCSE; this is not an equivalence margin",
    ifelse(abs(separation_grid$estimate_all[i]) <= 3 * separation_grid$mcse_all[i],
           "WITHIN_3_MCSE", "OUTSIDE_3_MCSE"), separation_grid$estimate_all[i],
    separation_grid$mcse_all[i], "04-p-separation-evidence.csv")
  for (i in seq_len(nrow(sep_trend))) led[[length(led) + 1L]] <- .ledger_row(
    "P-separation", "rho=.6 kappa trend", "FROZEN_DIRECTION_AND_REPORTABILITY",
    "positive slope predicted; support is reportable only when slope >= 3 SE",
    ifelse(sep_trend$seed_fixed_ols_slope[i] <= 0, "DIRECTION_FAIL",
           ifelse(sep_trend$positive_at_3se[i], "SUPPORT_REPORTABLE", "POSITIVE_NOT_REPORTABLE")),
    sep_trend$seed_fixed_ols_slope[i], sep_trend$seed_fixed_ols_se[i],
    "04-p-separation-evidence.csv",
    paste("No separate magnitude margin was added; positive_at_3se=", sep_trend$positive_at_3se[i]))
  separation <- .rbind_rows(list(separation_grid, sep_trend))

  ## P-rank: matched G6 phi_bias=.4 minus 0. Direction is the magnitude
  ## criterion; the frozen 3-MCSE rule governs whether support is reportable.
  g6 <- p[p$block == "G6", ]
  match_phi <- c("stage", "block", "seed", "arm", "kappa", "rho", "omega",
                 "phi_x", "n", "T_sp", "d_fit", "k", "beta0_shift")
  rank_raw <- .matched(g6, .near(g6$phi_bias, 0.4), .near(g6$phi_bias, 0),
                       match_phi, "dD_bias", "phi_0_4_minus_0")
  rank <- .summarise(rank_raw, c("stage", "block", "arm"), "phi_0_4_minus_0",
                     "contrast_complete", "contrast_both_pdHess")
  rank$reportable_at_3mcse <- rank$estimate_all >= 3 * rank$mcse_all
  for (i in seq_len(nrow(rank))) led[[length(led) + 1L]] <- .ledger_row(
    "P-rank", paste("G6", rank$arm[i]), "FROZEN_DIRECTION_AND_REPORTABILITY",
    "matched phi_bias .4 minus 0 is positive; support is reportable only at >= 3 MCSE",
    ifelse(rank$estimate_all[i] <= 0, "DIRECTION_FAIL",
           ifelse(rank$reportable_at_3mcse[i], "SUPPORT_REPORTABLE", "POSITIVE_NOT_REPORTABLE")),
    rank$estimate_all[i], rank$mcse_all[i], "05-p-rank-evidence.csv",
    "No separate magnitude margin was added.")

  list(primary = primary, dose = dose, structure = structure,
       integration = integration, separation = separation, rank = rank,
       ledger = do.call(rbind, led))
}

.curve_summary <- function(p, value, arms) {
  z <- p[p$block == "G1" & p$arm %in% arms, ]
  .summarise(z, c("arm", "rho", "omega", "kappa"), value)
}

.draw_ddbias <- function(p) {
  s <- .curve_summary(p, "dD_bias", c("A1", "A3", "A5", "A6"))
  arms <- c("A1", "A3", "A5", "A6"); cols <- c("#B2182B", "#2166AC", "#1B7837", "#762A83")
  old <- par(mfrow = c(2, 3), mar = c(3.5, 3.8, 2.2, 1), oma = c(1, 1, 1, 0))
  on.exit(par(old), add = TRUE)
  for (rho in c(0, .6)) for (omega in c(1, .5, 0)) {
    z <- s[.near(s$rho, rho) & .near(s$omega, omega), ]
    ylim <- range(c(z$estimate_all - z$mcse_all, z$estimate_all + z$mcse_all), finite = TRUE)
    plot(range(z$kappa), ylim, type = "n", xlab = "Bias amplitude (kappa)", ylab = "Paired dD_bias",
         main = sprintf("rho=%g, omega=%g", rho, omega)); abline(h = 0, col = "grey70")
    for (j in seq_along(arms)) {
      q <- z[z$arm == arms[j], ]; q <- q[order(q$kappa), ]
      lines(q$kappa, q$estimate_all, type = "b", pch = 16, col = cols[j])
      arrows(q$kappa, q$estimate_all - q$mcse_all, q$kappa,
             q$estimate_all + q$mcse_all, angle = 90, code = 3, length = .03, col = cols[j])
    }
  }
  legend("top", legend = arms, col = cols, lty = 1, pch = 16, horiz = TRUE,
         xpd = NA, inset = c(0, -0.07), bty = "n")
}

.draw_beta <- function(p) {
  s <- .curve_summary(p, "dbeta_bias", c("A1", "A3", "A5"))
  arms <- c("A1", "A3", "A5"); cols <- c("#B2182B", "#2166AC", "#1B7837")
  old <- par(mfrow = c(2, 3), mar = c(3.5, 3.8, 2.2, 1)); on.exit(par(old), add = TRUE)
  for (rho in c(0, .6)) for (omega in c(1, .5, 0)) {
    z <- s[.near(s$rho, rho) & .near(s$omega, omega), ]
    ylim <- range(c(z$estimate_all - z$mcse_all, z$estimate_all + z$mcse_all), finite = TRUE)
    plot(range(z$kappa), ylim, type = "n", xlab = "kappa", ylab = "Paired dBeta_bias",
         main = sprintf("rho=%g, omega=%g", rho, omega)); abline(h = 0, col = "grey70")
    for (j in seq_along(arms)) {
      q <- z[z$arm == arms[j], ]; q <- q[order(q$kappa), ]
      lines(q$kappa, q$estimate_all, type = "b", pch = 16, col = cols[j])
    }
  }
}

.draw_ladders <- function(ladders) {
  mean_col <- "dD_bias_vs_REF_mean_all"
  mcse_col <- "dD_bias_vs_REF_mcse_all"
  .require_cols(ladders, c("block", "arm", mean_col, mcse_col, "n", "T_sp", "d_fit", "k", "phi_bias"),
                "ladder figure table")
  blocks <- paste0("G", 2:6); arms <- c("A1", "A3", "A5")
  cols <- c("#B2182B", "#2166AC", "#1B7837")
  old <- par(mfrow = c(2, 3), mar = c(4.5, 3.8, 2.2, 1)); on.exit(par(old), add = TRUE)
  for (b in blocks) {
    z <- ladders[ladders$block == b & ladders$arm %in% arms, ]
    lev <- switch(b, G2 = z$n, G3 = z$T_sp, G4 = z$d_fit, G5 = z$k, G6 = z$phi_bias)
    labels <- sort(unique(lev)); xx <- seq_along(labels)
    ylim <- range(c(z[[mean_col]] - z[[mcse_col]], z[[mean_col]] + z[[mcse_col]]), finite = TRUE)
    plot(range(xx), ylim, type = "n", xaxt = "n", xlab = b, ylab = "dD_bias minus REF",
         main = paste("Ladder", b)); axis(1, at = xx, labels = labels); abline(h = 0, col = "grey70")
    for (j in seq_along(arms)) {
      q <- z[z$arm == arms[j], ]; qlev <- switch(b, G2=q$n,G3=q$T_sp,G4=q$d_fit,G5=q$k,G6=q$phi_bias)
      ord <- order(qlev); lines(match(qlev[ord], labels), q[[mean_col]][ord], type = "b", pch = 16, col = cols[j])
    }
  }
  plot.new(); legend("center", legend = arms, col = cols, lty = 1, pch = 16, bty = "n")
}

.write_figure_pair <- function(pdf_path, png_path, draw) {
  grDevices::pdf(pdf_path, width = 12, height = 7); on.exit(grDevices::dev.off(), add = TRUE)
  draw(); grDevices::dev.off(); on.exit(NULL, add = FALSE)
  grDevices::png(png_path, width = 1800, height = 1100, res = 160)
  on.exit(grDevices::dev.off(), add = TRUE); draw(); grDevices::dev.off(); on.exit(NULL, add = FALSE)
}

.write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "NA")
  if (!file.exists(path) || file.info(path)$size <= 0) .stopf("Empty output: %s", path)
}

run_supplement <- function(official_dir, out_dir) {
  .reject_path(out_dir, "supplement output")
  o <- .load_official(official_dir)
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(out_dir)) .stopf("Cannot create output directory: %s", out_dir)
  out_dir <- normalizePath(out_dir, mustWork = TRUE)
  if (identical(normalizePath(official_dir, mustWork = TRUE), out_dir)) {
    .stopf("Supplement output directory must differ from official analysis directory")
  }
  targets <- file.path(out_dir, .output_files)
  if (any(file.exists(targets))) .stopf("Refusing to overwrite supplement output(s): %s",
                                       paste(basename(targets[file.exists(targets)]), collapse = ", "))
  ev <- .prediction_evidence(o)
  .write_csv(ev$primary, targets[1]); .write_csv(ev$dose, targets[2])
  .write_csv(ev$structure, targets[3]); .write_csv(ev$integration, targets[4])
  .write_csv(ev$separation, targets[5]); .write_csv(ev$rank, targets[6])
  .write_csv(ev$ledger, targets[7])
  receipt <- data.frame(
    file = basename(o$paths), bytes = file.info(o$paths)$size,
    sha256 = unname(tools::sha256sum(o$paths)), stringsAsFactors = FALSE)
  .write_csv(receipt, targets[8]); .write_csv(o$manifest, targets[9])
  .write_figure_pair(targets[10], targets[11], function() .draw_ddbias(o$paired))
  .write_figure_pair(targets[12], targets[13], function() .draw_beta(o$paired))
  .write_figure_pair(targets[14], targets[15], function() .draw_ladders(o$ladders))
  if (any(!file.exists(targets)) || any(file.info(targets)$size <= 0)) .stopf("Supplement output verification failed")
  invisible(targets)
}

.synthetic_official <- function(dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  arms <- paste0("A", 1:6); seeds <- 1:8
  make_rows <- function(block, grid) {
    z <- merge(expand.grid(seed = seeds, arm = arms, KEEP.OUT.ATTRS = FALSE,
                           stringsAsFactors = FALSE), grid)
    z$stage <- "campaign"; z$phi_x <- .15; z$n <- ifelse(is.na(z$n),400,z$n)
    z$T_sp <- ifelse(is.na(z$T_sp),8,z$T_sp); z$d_fit <- ifelse(is.na(z$d_fit),2,z$d_fit)
    z$k <- ifelse(is.na(z$k),3,z$k); z$beta0_shift <- 0; z$block <- block
    ai <- match(z$arm, arms)
    z$dD_bias <- .03 * z$kappa + .02 * z$omega + .01 * z$rho +
      .004 * ai + .002 * z$seed + .001 * sin(3 * z$seed * z$kappa) +
      ifelse(block=="G6", .05*z$phi_bias, 0)
    z$dsignflip <- pmax(0, z$dD_bias/4); z$ddiag_rmse <- .02*z$kappa
    z$dpsi_rmse <- .015*z$kappa
    z$dbeta_bias <- z$rho*.04*z$kappa + .001*z$seed + .0005*cos(2*z$seed*z$kappa)
    z$estimand <- ifelse(block=="G5" & z$arm=="A2", "loadings_only_rank_d", "total_sigma")
    z$completed_pair <- TRUE; z$both_pdHess <- z$seed != 8
    z$headline_eligible <- !(block=="G5" & z$arm=="A2"); z
  }
  g1grid <- expand.grid(kappa=c(.25,.5,1,2),rho=c(0,.6),omega=c(1,.5,0),phi_bias=.15,
                        n=NA,T_sp=NA,d_fit=NA,k=NA)
  paired <- make_rows("G1", g1grid)
  paired <- rbind(paired,
    make_rows("G2", data.frame(kappa=1,rho=.6,omega=.5,phi_bias=.15,n=c(100,1600),T_sp=NA,d_fit=NA,k=NA)),
    make_rows("G3", data.frame(kappa=1,rho=.6,omega=.5,phi_bias=.15,n=NA,T_sp=c(6,12),d_fit=NA,k=NA)),
    make_rows("G4", data.frame(kappa=1,rho=.6,omega=.5,phi_bias=.15,n=NA,T_sp=NA,d_fit=c(1,3),k=NA)),
    make_rows("G5", data.frame(kappa=1,rho=.6,omega=.5,phi_bias=.15,n=NA,T_sp=NA,d_fit=NA,k=1)),
    make_rows("G6", data.frame(kappa=1,rho=.6,omega=.5,phi_bias=c(0,.4),n=NA,T_sp=NA,d_fit=NA,k=NA)))
  saveRDS(paired, file.path(dir, .required_files[["paired"]]))
  summary <- .summarise(paired[paired$headline_eligible, ],
    c("stage","block","arm","kappa","rho","omega","phi_x","phi_bias","n","T_sp","d_fit","k","beta0_shift"), "dD_bias")
  summary$dD_bias_mean_all <- summary$estimate_all; summary$dD_bias_mcse_all <- summary$mcse_all
  summary$dsignflip_mean_all <- summary$estimate_all/4; summary$dsignflip_mcse_all <- summary$mcse_all/4
  utils::write.csv(summary, file.path(dir,.required_files[["paired_summary"]]), row.names=FALSE)
  c1 <- summary; c1$C1_all <- abs(c1$dD_bias_mean_all)>=.1 & abs(c1$dD_bias_mean_all)>=3*c1$dD_bias_mcse_all
  c1$C2_all <- FALSE
  utils::write.csv(c1, file.path(dir,.required_files[["c1c2"]]), row.names=FALSE)
  a56 <- summary[summary$arm=="A5", ]; a56$D_bias_A5_minus_A6_mean_all <- .03
  a56$D_bias_A5_minus_A6_mcse_all <- .005; a56$C3_all <- TRUE
  utils::write.csv(a56, file.path(dir,.required_files[["a5a6"]]), row.names=FALSE)
  ladd <- summary[summary$block %in% paste0("G",2:6), ]
  ladd$dD_bias_vs_REF_mean_all <- ladd$estimate_all-.05; ladd$dD_bias_vs_REF_mcse_all <- ladd$mcse_all
  utils::write.csv(ladd, file.path(dir,.required_files[["ladders"]]), row.names=FALSE)
  status <- unique(summary[c("stage","block","arm","kappa","rho","omega","phi_x","phi_bias","n","T_sp","d_fit","k","beta0_shift")])
  status$n_scheduled <- 8; status$n_completed <- 8; status$n_excluded <- 0
  utils::write.csv(status, file.path(dir,.required_files[["status"]]), row.names=FALSE)
  primary <- summary[summary$block=="G1" & summary$arm=="A1" & .near(summary$kappa,1) &
                       .near(summary$rho,0) & .near(summary$omega,1), ][1,]
  primary$primary_clears_all <- TRUE
  utils::write.csv(primary, file.path(dir,.required_files[["primary"]]), row.names=FALSE)
  manifest <- data.frame(stage=c("pilot_v2",rep("campaign",6)),block=c("G1",paste0("G",1:6)),
                         input=file.path("/synthetic/official",c("pilot-v2.rds",paste0("g",1:6,".rds"))),rows=1)
  utils::write.csv(manifest, file.path(dir,.required_files[["manifest"]]), row.names=FALSE)
}

self_test <- function() {
  root <- tempfile("isdm-phase-c-supplement-", tmpdir = "/private/tmp")
  official <- file.path(root, "official-analysis"); output <- file.path(root, "supplement")
  .synthetic_official(official)
  paths <- run_supplement(official, output)
  ledger <- utils::read.csv(file.path(output, "06-claim-verdict-ledger.csv"),
                            stringsAsFactors = FALSE)
  receipt <- utils::read.csv(file.path(output, "07-supplement-input-receipt.csv"),
                             stringsAsFactors = FALSE)
  stopifnot(length(paths) == length(.output_files), all(file.exists(paths)),
            all(file.info(paths)$size > 0),
            identical(names(receipt), c("file", "bytes", "sha256")),
            nrow(receipt) == length(.required_files),
            all(grepl("^[[:xdigit:]]{64}$", receipt$sha256)),
            all(c("FROZEN_PASS_FAIL", "FROZEN_DIRECTION_AND_REPORTABILITY",
                  "FROZEN_DIAGNOSTIC_NOT_EQUIVALENCE",
                  "DESCRIPTIVE_UNRESOLVED") %in% ledger$rule_class),
            inherits(try(run_supplement(official, output), silent = TRUE), "try-error"))
  bad <- file.path(root, "bad-manifest-analysis"); .synthetic_official(bad)
  bad_manifest <- utils::read.csv(file.path(bad, .required_files[["manifest"]]),
                                  stringsAsFactors = FALSE)
  bad_manifest$stage[1] <- "pilot"
  utils::write.csv(bad_manifest, file.path(bad, .required_files[["manifest"]]), row.names = FALSE)
  stopifnot(inherits(try(.load_official(bad), silent = TRUE), "try-error"))
  cat("SELF_TEST_PASS\nSynthetic artifacts retained under: ", root, "\n", sep = "")
  invisible(root)
}

if (sys.nframe() == 0L) {
  opt <- .parse_cli(commandArgs(trailingOnly = TRUE))
  if (!isTRUE(opt$help)) {
    if (isTRUE(opt$self_test)) self_test() else {
      paths <- run_supplement(opt$official_dir, opt$out_dir)
      cat("Phase C supplement wrote:\n", paste0("  ", paths, collapse="\n"), "\n", sep="")
    }
  }
}
