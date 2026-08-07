#!/usr/bin/env Rscript
# Absolute-first scientific ledger for S0b exact-route export (local evidence).
# Does NOT call Design 110 adjudicate mode and does NOT rewrite Arc-2 labels.

suppressPackageStartupMessages({
  args <- commandArgs(trailingOnly = TRUE)
})

get_flag <- function(name, default = NULL) {
  hit <- grepl(paste0("^--", name, "="), args)
  if (!any(hit)) return(default)
  sub(paste0("^--", name, "="), "", args[hit][[1L]])
}

export_path <- get_flag("export")
out_csv <- get_flag("out-csv")
out_md <- get_flag("out-md")
cells_arg <- get_flag("cells", "poisson_log,lognormal_log,gamma_log")
arc2_csv <- get_flag(
  "arc2-csv",
  "/private/tmp/va-gh-h7-final-evidence/totoro/adjudication/va-gh-h7-adjudication-totoro-022b4eab.csv"
)
beta_cap_default <- as.numeric(get_flag("beta-cap", "0.35"))
sigma_cap_default <- as.numeric(get_flag("sigma-cap", "0.50"))
beta_cap_alt <- get_flag("beta-cap-alt", NA_character_)
sigma_cap_alt <- get_flag("sigma-cap-alt", NA_character_)
avail_floor <- as.numeric(get_flag("avail-floor", "0.90"))

if (is.null(export_path) || is.null(out_csv) || is.null(out_md)) {
  stop("Usage: --export= --out-csv= --out-md= [--cells=] [--arc2-csv=]")
}

wanted <- strsplit(cells_arg, ",", fixed = TRUE)[[1L]]
wanted <- trimws(wanted)

wilson_upper <- function(k, n, z = 1.959963984540054) {
  if (n <= 0) return(NA_real_)
  p <- k / n
  den <- 1 + z^2 / n
  centre <- p + z^2 / (2 * n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))
  (centre + half) / den
}

wilson_lower <- function(k, n, z = 1.959963984540054) {
  if (n <= 0) return(NA_real_)
  p <- k / n
  den <- 1 + z^2 / n
  centre <- p + z^2 / (2 * n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))
  (centre - half) / den
}

score_caps <- function(beta_rmse, sigma_frob, avail, beta_cap, sigma_cap) {
  if (is.na(avail) || avail < avail_floor) return("SCIENTIFIC_INCONCLUSIVE")
  if (is.na(beta_rmse) || is.na(sigma_frob)) return("SCIENTIFIC_INCONCLUSIVE")
  if (beta_rmse <= beta_cap && sigma_frob <= sigma_cap) return("SCIENTIFIC_PASS")
  "SCIENTIFIC_FAIL"
}

ex <- read.csv(export_path, stringsAsFactors = FALSE)
stopifnot(all(c("cell", "q", "seed", "estimator", "status") %in% names(ex)))
ex <- ex[ex$cell %in% wanted, , drop = FALSE]
missing_cells <- setdiff(wanted, unique(ex$cell))
if (length(missing_cells)) {
  stop("export missing cells: ", paste(missing_cells, collapse = ","))
}

arc2 <- read.csv(arc2_csv, stringsAsFactors = FALSE)

rows <- list()
for (cc in wanted) {
  for (qq in sort(unique(ex$q[ex$cell == cc]))) {
    sub <- ex[ex$cell == cc & ex$q == qq, , drop = FALSE]
    va <- sub[sub$estimator == "va", , drop = FALSE]
    la <- sub[sub$estimator == "laplace", , drop = FALSE]
    n_va <- nrow(va)
    n_la <- nrow(la)

    if (!"healthy" %in% names(va)) {
      va_fail <- sum(va$status != "completed", na.rm = TRUE)
    } else {
      va_fail <- sum(!(va$status == "completed" & as.logical(va$healthy)), na.rm = TRUE)
    }
    la_completed <- if (!"healthy" %in% names(la)) {
      sum(la$status == "completed", na.rm = TRUE)
    } else {
      sum(la$status == "completed" & as.logical(la$healthy), na.rm = TRUE)
    }

    beta_col <- if ("beta_rmse" %in% names(va)) "beta_rmse" else "beta_squared_error_mean"
    if (beta_col == "beta_squared_error_mean") {
      beta_vals <- sqrt(as.numeric(va[[beta_col]]))
    } else {
      beta_vals <- as.numeric(va[[beta_col]])
    }
    sigma_vals <- as.numeric(va$sigma_rel_frob)
    finite_mask <- is.finite(beta_vals) & is.finite(sigma_vals)
    avail <- if (n_va) mean(finite_mask) else NA_real_
    beta_rmse <- if (any(finite_mask)) mean(beta_vals[finite_mask]) else NA_real_
    sigma_frob <- if (any(finite_mask)) mean(sigma_vals[finite_mask]) else NA_real_

    if (n_va && n_la) {
      keys <- intersect(va$seed, la$seed)
      paired_ok <- 0L
      for (s in keys) {
        vr <- va[va$seed == s, , drop = FALSE][1L, ]
        lr <- la[la$seed == s, , drop = FALSE][1L, ]
        v_ok <- identical(vr$status, "completed")
        l_ok <- identical(lr$status, "completed")
        if ("healthy" %in% names(va)) {
          v_ok <- v_ok && isTRUE(as.logical(vr$healthy))
          l_ok <- l_ok && isTRUE(as.logical(lr$healthy))
        }
        vb <- if (beta_col == "beta_squared_error_mean") {
          sqrt(as.numeric(vr[[beta_col]]))
        } else {
          as.numeric(vr[[beta_col]])
        }
        lb <- if (beta_col == "beta_squared_error_mean") {
          sqrt(as.numeric(lr[[beta_col]]))
        } else {
          as.numeric(lr[[beta_col]])
        }
        vs <- as.numeric(vr$sigma_rel_frob)
        ls <- as.numeric(lr$sigma_rel_frob)
        if (v_ok && l_ok && is.finite(vb) && is.finite(lb) && is.finite(vs) && is.finite(ls)) {
          paired_ok <- paired_ok + 1L
        }
      }
      paired_elig <- paired_ok / n_va
    } else {
      paired_elig <- NA_real_
    }

    fail_rate <- if (n_va) va_fail / n_va else NA_real_
    w_u <- wilson_upper(va_fail, n_va)
    w_l <- wilson_lower(va_fail, n_va)
    if (is.na(w_u)) {
      rel <- "INCONCLUSIVE"
    } else if (w_u <= 0.10) {
      rel <- "PASS"
    } else if (!is.na(w_l) && w_l > 0.10) {
      rel <- "FAIL"
    } else {
      rel <- "INCONCLUSIVE"
    }

    sci_default <- score_caps(beta_rmse, sigma_frob, avail, beta_cap_default, sigma_cap_default)
    if (identical(rel, "FAIL") && identical(sci_default, "SCIENTIFIC_PASS")) {
      sci_default <- "SCIENTIFIC_FAIL"
    }
    if (identical(rel, "INCONCLUSIVE") && identical(sci_default, "SCIENTIFIC_PASS")) {
      sci_default <- "SCIENTIFIC_INCONCLUSIVE"
    }

    sci_alt <- NA_character_
    beta_alt_n <- if (is.na(beta_cap_alt)) NA_real_ else as.numeric(beta_cap_alt)
    sigma_alt_n <- if (is.na(sigma_cap_alt)) NA_real_ else as.numeric(sigma_cap_alt)
    if (!is.na(beta_alt_n) && !is.na(sigma_alt_n)) {
      sci_alt <- score_caps(beta_rmse, sigma_frob, avail, beta_alt_n, sigma_alt_n)
      if (identical(rel, "FAIL") && identical(sci_alt, "SCIENTIFIC_PASS")) sci_alt <- "SCIENTIFIC_FAIL"
      if (identical(rel, "INCONCLUSIVE") && identical(sci_alt, "SCIENTIFIC_PASS")) {
        sci_alt <- "SCIENTIFIC_INCONCLUSIVE"
      }
    }

    ratio_note <- if (!is.na(paired_elig) && paired_elig >= 0.90) {
      "RATIO_ELIGIBLE_SECONDARY"
    } else {
      sprintf(
        "RATIO_NOT_ELIGIBLE (paired_elig=%.3f; la_completed=%d/%d)",
        paired_elig, la_completed, n_la
      )
    }

    arc2_row <- arc2[arc2$cell == cc & arc2$q == qq, , drop = FALSE]
    frozen <- if (nrow(arc2_row)) arc2_row$overall_point_route_verdict[[1L]] else NA_character_
    if (is.na(frozen) || !nzchar(frozen)) frozen <- "UNKNOWN"

    rows[[length(rows) + 1L]] <- data.frame(
      cell = cc,
      q = qq,
      n_seeds_planned_va = n_va,
      n_seeds_planned_la = n_la,
      reliability_verdict = rel,
      reliability_fail_rate = fail_rate,
      reliability_wilson_upper = w_u,
      abs_availability = avail,
      beta_rmse_va = beta_rmse,
      sigma_rel_frob_va = sigma_frob,
      beta_cap_default = beta_cap_default,
      sigma_cap_default = sigma_cap_default,
      scientific_verdict_default = sci_default,
      beta_cap_alternate = beta_alt_n,
      sigma_cap_alternate = sigma_alt_n,
      scientific_verdict_alternate = sci_alt,
      la_completed = la_completed,
      paired_eligibility = paired_elig,
      ratio_secondary = ratio_note,
      frozen_arc2_overall_point_route_verdict = frozen,
      stringsAsFactors = FALSE
    )
  }
}

ledger <- do.call(rbind, rows)
dir.create(dirname(out_csv), recursive = TRUE, showWarnings = FALSE)
write.csv(ledger, out_csv, row.names = FALSE)

md <- c(
  "# S0b exact-route absolute-first scientific ledger",
  "",
  sprintf("Generated: %s UTC", format(Sys.time(), tz = "UTC")),
  sprintf("Export: `%s`", export_path),
  sprintf("Cells: %s", paste(wanted, collapse = ", ")),
  sprintf("Arc-2 frozen CSV: `%s`", arc2_csv),
  "",
  "## Caps",
  sprintf("- Default: β RMSE ≤ %.2f ; Σ rel Frob ≤ %.2f", beta_cap_default, sigma_cap_default),
  sprintf("- Abs-availability floor: %.2f", avail_floor),
  if (!is.na(beta_alt_n) && !is.na(sigma_alt_n)) {
    sprintf("- Alternate: β RMSE ≤ %.2f ; Σ rel Frob ≤ %.2f", beta_alt_n, sigma_alt_n)
  } else {
    "- Alternate: not proposed"
  },
  "",
  "## Verdicts",
  "",
  paste(c(
    "cell", "q", "scientific", "β RMSE", "Σ rel Frob", "abs avail",
    "reliability", "LA done", "frozen Arc-2"
  ), collapse = " | "),
  paste(rep("---", 9L), collapse = " | ")
)
for (i in seq_len(nrow(ledger))) {
  md <- c(md, paste(c(
    ledger$cell[i], ledger$q[i], ledger$scientific_verdict_default[i],
    sprintf("%.4f", ledger$beta_rmse_va[i]),
    sprintf("%.4f", ledger$sigma_rel_frob_va[i]),
    sprintf("%.3f", ledger$abs_availability[i]),
    ledger$reliability_verdict[i],
    sprintf("%d/%d", ledger$la_completed[i], ledger$n_seeds_planned_la[i]),
    ledger$frozen_arc2_overall_point_route_verdict[i]
  ), collapse = " | "))
}
md <- c(
  md,
  "",
  "## Frozen Arc-2 labels",
  "Each cell×q reprints Arc-2 `overall_point_route_verdict` unchanged.",
  "This ledger does **not** soft-PASS or mutate those labels.",
  "",
  "## Secondary Laplace diagnostics",
  "Paired ratios are non-blocking for SCIENTIFIC_PASS. See CSV `ratio_secondary`."
)
writeLines(md, out_md)
message("Wrote ", out_csv, " and ", out_md)
print(ledger[, c(
  "cell", "q", "scientific_verdict_default", "beta_rmse_va", "sigma_rel_frob_va",
  "abs_availability", "reliability_verdict", "frozen_arc2_overall_point_route_verdict"
)])
