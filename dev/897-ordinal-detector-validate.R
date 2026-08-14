## Apply the development-frozen #897 rule to an independent receipt.  This
## script deliberately never searches thresholds.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) stop("Usage: validate.R <cells.csv> <selected-rule.csv> <out-dir>")
x <- utils::read.csv(args[[1L]], check.names = FALSE, stringsAsFactors = FALSE)
rule <- utils::read.csv(args[[2L]], check.names = FALSE, stringsAsFactors = FALSE)
out_dir <- args[[3L]]
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (nrow(rule) != 1L || !isTRUE(rule$development_pass)) stop("Rule is not a single development-pass rule")

route_ok <- with(x,
  status == "OK" & family_id_14 & rr_B & !diag_B & unique_false &
    theta_diag_B_mapped & s_B_mapped & categories_match & random_blocks == "z_B"
)
x$truth <- "unusable"
x$truth[route_ok & is.finite(x$rel_frob) & x$rel_frob <= 0.1] <- "healthy"
x$truth[route_ok & is.finite(x$rel_frob) & x$rel_frob > 10 &
          x$convergence == 0 & x$pd_hess] <- "degenerate"
x$truth[route_ok & x$truth == "unusable"] <- "ambiguous"
x$flagged <- with(x,
  max_relative_row_norm >= rule$relative_loading |
    saturation_share >= rule$saturation |
    min_cutpoint_spacing <= rule$cutpoint_spacing |
    min_observed_category_share <= rule$rare_category
)
eligible <- x$truth %in% c("healthy", "degenerate")
tp <- sum(x$flagged & x$truth == "degenerate")
fn <- sum(!x$flagged & x$truth == "degenerate")
fp <- sum(x$flagged & x$truth == "healthy")
tn <- sum(!x$flagged & x$truth == "healthy")
summary <- data.frame(
  tp = tp, fn = fn, fp = fp, tn = tn,
  sensitivity = if (tp + fn) tp / (tp + fn) else NA_real_,
  specificity = if (tn + fp) tn / (tn + fp) else NA_real_,
  pass = (tp + fn) > 0L && (tn + fp) > 0L && tp / (tp + fn) >= .95 && tn / (tn + fp) >= .95,
  stringsAsFactors = FALSE
)
utils::write.csv(summary, file.path(out_dir, "holdout-summary.csv"), row.names = FALSE)
utils::write.csv(x, file.path(out_dir, "holdout-cell-classification.csv"), row.names = FALSE)
utils::write.csv(as.data.frame(table(status = x$status, truth = x$truth), stringsAsFactors = FALSE),
                 file.path(out_dir, "holdout-denominators.csv"), row.names = FALSE)
cat(sprintf("hold-out: sensitivity=%.3f specificity=%.3f pass=%s\\n",
            summary$sensitivity, summary$specificity, summary$pass))
if (!isTRUE(summary$pass)) quit(save = "no", status = 3L)
