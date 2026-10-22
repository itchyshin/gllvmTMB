## Independent raw-record scorer. It deliberately does not call diagnostic scoring helpers.

isdm_respinfo_raw_surface_error <- function(estimate, truth, trait) {
  estimate <- as.numeric(estimate); truth <- as.numeric(truth); trait <- as.character(trait)
  if (!length(estimate) || length(estimate) != length(truth) || length(trait) != length(truth) ||
      any(!is.finite(c(estimate, truth)))) stop("raw surface vectors are invalid", call. = FALSE)
  values <- vapply(unique(trait), function(level) {
    take <- trait == level; e <- estimate[take] - mean(estimate[take]); t <- truth[take] - mean(truth[take])
    scale <- stats::sd(t)
    if (!is.finite(scale) || scale <= 0) return(NA_real_)
    sqrt(mean(((e - t) / scale)^2))
  }, numeric(1L))
  if (!any(is.finite(values))) stop("raw surface has no finite trait score", call. = FALSE)
  stats::median(values[is.finite(values)])
}

isdm_respinfo_relative_frobenius_raw <- function(estimate, truth) {
  if (!identical(dim(estimate), dim(truth)) || any(!is.finite(c(estimate, truth)))) stop("raw covariance is invalid", call. = FALSE)
  sqrt(sum((estimate - truth)^2)) / sqrt(sum(truth^2))
}

isdm_respinfo_recompute_raw <- function(raw) {
  required <- c("surfaces", "trait", "truth_surfaces", "Sigma", "truth_Sigma", "Psi", "truth_Psi", "fixed", "fixed_truth")
  if (!is.list(raw) || !all(required %in% names(raw)) || !all(c("shared", "full") %in% names(raw$surfaces)) ||
      !all(c("shared", "full") %in% names(raw$truth_surfaces))) stop("raw record is incomplete", call. = FALSE)
  source_terms <- grep("^isdm_source:", intersect(names(raw$fixed), names(raw$fixed_truth)), value = TRUE)
  list(
    shared_error = isdm_respinfo_raw_surface_error(raw$surfaces$shared, raw$truth_surfaces$shared, raw$trait),
    full_error = isdm_respinfo_raw_surface_error(raw$surfaces$full, raw$truth_surfaces$full, raw$trait),
    psi_error = diag(abs(raw$Psi - raw$truth_Psi) / diag(raw$truth_Psi)),
    sigma_error = isdm_respinfo_relative_frobenius_raw(raw$Sigma, raw$truth_Sigma),
    source_coefficient_rmse = if (length(source_terms)) sqrt(mean((raw$fixed[source_terms] - raw$fixed_truth[source_terms])^2)) else NA_real_
  )
}
