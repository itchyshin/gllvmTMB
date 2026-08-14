## #897 calibration/hold-out analysis.  This never changes package behaviour.
## A prospective warning must be a simple conjunction/OR of quantities that a
## fitted ordinary ordinal-probit model can expose without simulation truth.

args <- commandArgs(trailingOnly = TRUE)
input <- args[[1L]]
out_dir <- if (length(args) >= 2L) args[[2L]] else dirname(input)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

x <- utils::read.csv(input, check.names = FALSE, stringsAsFactors = FALSE)
required <- c(
  "cell_id", "status", "rel_frob", "convergence", "pd_hess",
  "max_relative_row_norm", "saturation_share", "min_cutpoint_spacing",
  "min_observed_category_share", "family_id_14", "rr_B", "diag_B",
  "unique_false", "theta_diag_B_mapped", "s_B_mapped", "categories_match",
  "random_blocks", "n", "p", "q", "categories", "missing", "loading_shape"
)
missing <- setdiff(required, names(x))
if (length(missing)) stop("Missing required receipt columns: ", paste(missing, collapse = ", "))

route_ok <- with(x,
  status == "OK" & family_id_14 & rr_B & !diag_B & unique_false &
    theta_diag_B_mapped & s_B_mapped & categories_match & random_blocks == "z_B"
)
x$truth <- "unusable"
x$truth[route_ok & is.finite(x$rel_frob) & x$rel_frob <= 0.1] <- "healthy"
x$truth[route_ok & is.finite(x$rel_frob) & x$rel_frob > 10 &
          x$convergence == 0 & x$pd_hess] <- "degenerate"
x$truth[route_ok & x$truth == "unusable"] <- "ambiguous"

eligible <- x$truth %in% c("healthy", "degenerate")
if (!any(x$truth == "healthy") || !any(x$truth == "degenerate")) {
  stop("Development receipt has no eligible healthy and degenerate truth-labelled rows")
}

thresholds <- expand.grid(
  relative_loading = c(2, 4, 8, 16, 32),
  saturation = c(0.02, 0.05, 0.1, 0.2, 0.4),
  cutpoint_spacing = c(0.01, 0.03, 0.1, 0.3),
  rare_category = c(0.005, 0.01, 0.02, 0.05),
  stringsAsFactors = FALSE
)

score_rule <- function(rule, data) {
  flagged <- with(data,
    max_relative_row_norm >= rule$relative_loading |
      saturation_share >= rule$saturation |
      min_cutpoint_spacing <= rule$cutpoint_spacing |
      min_observed_category_share <= rule$rare_category
  )
  truth <- data$truth
  tp <- sum(flagged & truth == "degenerate")
  fn <- sum(!flagged & truth == "degenerate")
  fp <- sum(flagged & truth == "healthy")
  tn <- sum(!flagged & truth == "healthy")
  data.frame(
    rule,
    tp = tp, fn = fn, fp = fp, tn = tn,
    sensitivity = tp / (tp + fn), specificity = tn / (tn + fp),
    stringsAsFactors = FALSE
  )
}

scored <- do.call(rbind, lapply(seq_len(nrow(thresholds)), function(i) {
  score_rule(thresholds[i, , drop = FALSE], x[eligible, , drop = FALSE])
}))
scored$development_pass <- with(scored, sensitivity >= .95 & specificity >= .95)
scored <- scored[order(!scored$development_pass, -scored$specificity, -scored$sensitivity,
                       scored$fp, scored$fn), , drop = FALSE]
utils::write.csv(scored, file.path(out_dir, "development-rule-grid.csv"), row.names = FALSE)

best <- scored[1L, , drop = FALSE]
utils::write.csv(best, file.path(out_dir, "development-selected-rule.csv"), row.names = FALSE)
utils::write.csv(
  as.data.frame(table(status = x$status, truth = x$truth), stringsAsFactors = FALSE),
  file.path(out_dir, "development-denominators.csv"), row.names = FALSE
)
cat(sprintf("best rule: sensitivity=%.3f specificity=%.3f pass=%s\\n",
            best$sensitivity, best$specificity, best$development_pass))
if (!isTRUE(best$development_pass)) quit(save = "no", status = 3L)
