## =============================================================================
## 31 -- Posthoc transparent-fallback sensitivity for #847
## =============================================================================
## Usage:
##   INPUT=/path/29-tau-cap-selection.csv \
##     OUTPUT=docs/dev-log/artifacts/aghq-tau-847/31-transparent-fallback \
##     Rscript dev/aghq-evidence/31-tau-transparent-fallback.R
##
## This is deliberately NOT the preregistered cap-selection analysis. It asks a
## narrower implementation question after the strict selection gate returned
## NO_CAP_PASSED_SELECTION: what happens if cap 6 is used only when its final
## AGHQ fit is valid, with an independent shipped-style tau=2 fit returned
## otherwise? Failed/nonconverged fits remain adverse; they are never dropped.

INPUT <- Sys.getenv("INPUT", "")
OUTPUT <- Sys.getenv("OUTPUT", "")
B <- as.integer(Sys.getenv("BOOT_REPS", "5000"))
EXPECTED_INPUT_MD5 <- "3399541e3b944c858e7d7b7c9f836f00"
EXPECTED_PACKAGE_SHA <- "54d6f366e972643c663be9645ed598aa98e81869"
if (!nzchar(INPUT) || !file.exists(INPUT)) stop("INPUT must name the selection CSV")
if (!nzchar(OUTPUT)) stop("OUTPUT must name the output prefix")
if (!is.finite(B) || B < 999L) stop("BOOT_REPS must be at least 999")

dat <- utils::read.csv(INPUT, stringsAsFactors = FALSE)
input_md5 <- unname(tools::md5sum(INPUT))
if (!identical(input_md5, EXPECTED_INPUT_MD5)) {
  stop("INPUT bytes do not match the locked selection campaign")
}
need <- c(
  "phase", "n", "p", "q", "lam_sd", "task", "seed", "arm", "ok",
  "converged", "aghq_used", "frob_rat", "rho_mae", "loading_log_error",
  "package_sha"
)
if (length(setdiff(need, names(dat)))) stop("selection CSV is missing required columns")
if (!all(dat$phase == "selection") || any(dat$p != 6L) || any(dat$q != 2L)) {
  stop("input is not the preregistered selection grid")
}
if (length(unique(dat$package_sha)) != 1L || anyNA(dat$package_sha) ||
    !identical(unique(dat$package_sha), EXPECTED_PACKAGE_SHA)) {
  stop("package SHA is absent or inconsistent")
}

## Re-run the preregistered analyser on THESE EXACT BYTES before reading any
## posthoc policy result. Script 30 validates every arm/key count, installed
## package provenance, pilot k/multi-start/unpenalised status, tau source, cap,
## clipping identity, and fixed2 comparator contract. Requiring its strict
## NO_CAP verdict binds this sensitivity to the already reported campaign while
## preserving the negative primary conclusion.
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_arg) != 1L) stop("cannot locate this analyser")
script_path <- normalizePath(sub("^--file=", "", file_arg), mustWork = TRUE)
strict_analyser <- file.path(dirname(script_path), "30-tau-cap-analyse.R")
if (!file.exists(strict_analyser)) stop("strict selection analyser is absent")
strict_prefix <- tempfile("tau31-strict-selection-")
strict <- system2(
  file.path(R.home("bin"), "Rscript"),
  c("--vanilla", shQuote(strict_analyser)),
  env = c(
    "PHASE=selection", paste0("INPUT=", INPUT),
    paste0("OUTPUT=", strict_prefix), paste0("BOOT_REPS=", B)
  ),
  stdout = TRUE, stderr = TRUE
)
strict_status <- attr(strict, "status")
if ((!is.null(strict_status) && strict_status != 0L) ||
    !any(trimws(strict) == "NO_CAP_PASSED_SELECTION")) {
  stop("strict selection revalidation failed: ", paste(strict, collapse = " | "))
}
arms <- c("fixed2_shipped", "auto_cap6")
x <- dat[dat$arm %in% arms, ]
counts <- aggregate(task ~ arm + n + lam_sd, x, length)
if (!setequal(unique(x$arm), arms) || nrow(counts) != 12L ||
    any(counts$task != 100L) ||
    anyDuplicated(x[c("n", "lam_sd", "task", "seed", "arm")])) {
  stop("input does not contain complete paired shipped/cap6 rows")
}

key <- c("n", "lam_sd", "task", "seed")
shipped <- x[x$arm == "fixed2_shipped", ]
auto <- x[x$arm == "auto_cap6", ]
z <- merge(auto, shipped, by = key, suffixes = c("_auto", "_shipped"), all = FALSE)
if (nrow(z) != 600L) stop("paired policy table must contain exactly 600 replicates")

is_failure <- function(ok, converged, aghq_used, frob_rat) {
  !as.logical(ok) | !as.logical(converged) | !as.logical(aghq_used) |
    !is.finite(frob_rat)
}
z$failure_auto <- with(z, is_failure(ok_auto, converged_auto, aghq_used_auto,
                                    frob_rat_auto))
z$failure_shipped <- with(z, is_failure(ok_shipped, converged_shipped,
                                       aghq_used_shipped, frob_rat_shipped))
z$auto_used <- !z$failure_auto
z$failure_policy <- ifelse(z$auto_used, z$failure_auto, z$failure_shipped)
z$runaway_policy <- z$failure_policy | ifelse(
  z$auto_used, z$frob_rat_auto, z$frob_rat_shipped
) > 2
z$runaway_shipped <- z$failure_shipped | z$frob_rat_shipped > 2
z$rho_policy <- ifelse(z$auto_used, z$rho_mae_auto, z$rho_mae_shipped)
z$loading_policy <- ifelse(
  z$auto_used, z$loading_log_error_auto, z$loading_log_error_shipped
)
z$failure_delta <- as.numeric(z$failure_policy) - as.numeric(z$failure_shipped)
z$runaway_delta <- as.numeric(z$runaway_policy) - as.numeric(z$runaway_shipped)
z$rho_delta <- z$rho_policy - z$rho_mae_shipped
z$loading_delta <- z$loading_policy - z$loading_log_error_shipped
z$rho_delta[z$failure_policy | z$failure_shipped] <- NA_real_
z$loading_delta[z$failure_policy | z$failure_shipped] <- NA_real_

upper95 <- function(delta, seed) {
  delta <- delta[is.finite(delta)]
  if (!length(delta)) return(NA_real_)
  set.seed(seed)
  draws <- replicate(B, mean(sample(delta, length(delta), replace = TRUE)))
  as.numeric(stats::quantile(draws, 0.95, names = FALSE, type = 8))
}

cells <- unique(z[c("n", "lam_sd")])
cells <- cells[order(cells$lam_sd, cells$n), ]
rows <- lapply(seq_len(nrow(cells)), function(i) {
  zz <- z[z$n == cells$n[i] & z$lam_sd == cells$lam_sd[i], ]
  data.frame(
    n = cells$n[i], lam_sd = cells$lam_sd[i], pairs = nrow(zz),
    auto_used = sum(zz$auto_used),
    failure_diff = mean(zz$failure_delta),
    failure_upper95 = upper95(zz$failure_delta, 1100L + i),
    runaway_diff = mean(zz$runaway_delta),
    runaway_upper95 = upper95(zz$runaway_delta, 2100L + i),
    rho_mae_diff = mean(zz$rho_delta, na.rm = TRUE),
    rho_mae_upper95 = upper95(zz$rho_delta, 3100L + i),
    loading_error_diff = mean(zz$loading_delta, na.rm = TRUE),
    loading_error_upper95 = upper95(zz$loading_delta, 4100L + i),
    loading_noninferior_0.02 =
      upper95(zz$loading_delta, 4100L + i) <= 0.02,
    stringsAsFactors = FALSE
  )
})
summary <- do.call(rbind, rows)
utils::write.csv(summary, paste0(OUTPUT, "-summary.csv"), row.names = FALSE)

## Macro-average the six equally weighted design cells. Pooling successful rows
## would overweight cells where the pilot is easiest to validate, exactly the
## selection effect this sensitivity is meant to keep visible.
overall_loading <- mean(summary$loading_error_diff)
lines <- c(
  "# Posthoc transparent-fallback sensitivity", "",
  paste0("- Input MD5: `", input_md5, "` (locked in the analyser)"),
  paste0("- Package SHA: `", unique(dat$package_sha), "`"),
  "- Strict analyser recheck on the same bytes: **NO_CAP_PASSED_SELECTION**.",
  paste0("- Bootstrap replicates: ", B),
  "- Policy: use `auto_cap6` only when its final fit is valid; otherwise return the independently started `fixed2_shipped` fit.",
  "- Status: **POSTHOC SENSITIVITY, NOT THE PREREGISTERED DEFAULT GATE**.",
  paste0("- Auto result used: ", sum(z$auto_used), "/600."),
  sprintf("- Six-cell macro-mean paired loading-error difference: %+.9f.", overall_loading),
  "",
  "This supports a narrow explicit runaway/failure-avoidance capability. It does not support changing the package default or claiming broad loading accuracy. Failed and nonconverged fits count as adverse; no replicate is filtered from those denominators."
)
writeLines(lines, paste0(OUTPUT, "-verdict.md"))
print(summary, row.names = FALSE)
