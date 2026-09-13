## Verify retained nine-cell curvature-scaled temporal dep-kernel qualification.
## This reads retained receipts only; it never simulates or refits a production model.

.args <- commandArgs(trailingOnly = TRUE)
.plan <- expand.grid(phi = c(-.4, 0, .6), seed = 2609371:2609373,
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
.plan <- .plan[order(.plan$phi, .plan$seed), , drop = FALSE]
.truth <- list(beta = c(.2, -.3, .1),
  temporal_loading = rbind(c(.55, 0, 0), c(.12, .50, 0), c(-.08, .10, .48)),
  kernel_sd = c(.35, .28, .40))

.key <- function(x) paste(sprintf("%.17g", x$phi), as.integer(x$seed), sep = "/")
.unpack_loading <- function(theta) {
  if (!is.numeric(theta) || length(theta) != 6L || any(!is.finite(theta)))
    stop("temporal loading block must contain six finite values", call. = FALSE)
  out <- matrix(0, 3L, 3L); cursor <- 1L
  for (j in 1:3) { out[j, j] <- theta[[cursor]]; cursor <- cursor + 1L }
  for (j in 1:2) for (i in (j + 1):3) { out[i, j] <- theta[[cursor]]; cursor <- cursor + 1L }
  out
}
.endpoint_ok <- function(x, passes, require_gradient = FALSE) {
  is.list(x) && is.list(x$endpoint) && is.list(x$oracle) &&
    is.data.frame(x$endpoint$optimizer_pass_history) &&
    nrow(x$endpoint$optimizer_pass_history) == passes &&
    identical(x$endpoint$optimizer_pass_history$pass, seq_len(passes)) &&
    all(x$endpoint$optimizer_pass_history$accepted) &&
    identical(x$endpoint$convergence, 0L) && is.finite(x$endpoint$objective) &&
    is.finite(x$endpoint$max_gradient) && (!require_gradient || x$endpoint$max_gradient <= 1e-3) &&
    is.finite(x$oracle$nll_absolute_error) && x$oracle$nll_absolute_error <= 1e-6 &&
    is.numeric(x$oracle$gradient_absolute_error) &&
    length(x$oracle$gradient_absolute_error) > 0L &&
    all(is.finite(x$oracle$gradient_absolute_error)) &&
    max(x$oracle$gradient_absolute_error) <= 1e-4
}
.receipt_row <- function(path) {
  x <- readRDS(path)
  if (!is.list(x) || !identical(x$schema, "temporal-dep-kernel-curvature-scaled-bfgs-v1") ||
      !identical(x$terminal, "success") || !is.list(x$target) ||
      !identical(x$contract, "One-cell curvature-scaled BFGS diagnostic only; no recovery, optimizer, coverage, or admission claim.") ||
      !isTRUE(x$adjudication$accepted) || !identical(x$adjudication$reasons, character()) ||
      !.endpoint_ok(x$baseline, 2L) || !.endpoint_ok(x$candidate, 1L, require_gradient = TRUE) ||
      x$candidate$endpoint$objective > x$baseline$endpoint$objective + 1e-8) {
    stop("invalid or failed retained curvature-scaled qualification receipt: ", basename(path), call. = FALSE)
  }
  par <- x$candidate$endpoint$parameter_blocks
  if (!is.list(par) || !is.numeric(par$theta_temporal_time) || length(par$theta_temporal_time) != 1L ||
      !is.numeric(par$theta_rr_phy) || length(par$theta_rr_phy) < 3L ||
      !is.numeric(par$b_fix) || length(par$b_fix) != 3L) {
    stop("receipt lacks the required fitted parameter blocks: ", basename(path), call. = FALSE)
  }
  loading <- .unpack_loading(par$theta_temporal_rr)
  data.frame(phi = x$target$phi, seed = x$target$seed,
    phi_estimate = (1 - 1e-6) * tanh(par$theta_temporal_time),
    temporal_frobenius_relative_error = sqrt(sum((tcrossprod(loading) - tcrossprod(.truth$temporal_loading))^2)) /
      sqrt(sum(tcrossprod(.truth$temporal_loading)^2)),
    kernel_1 = par$theta_rr_phy[[1L]]^2, kernel_2 = par$theta_rr_phy[[2L]]^2,
    kernel_3 = par$theta_rr_phy[[3L]]^2,
    beta_1 = par$b_fix[[1L]], beta_2 = par$b_fix[[2L]], beta_3 = par$b_fix[[3L]],
    stringsAsFactors = FALSE)
}
.summarise <- function(result) {
  for (j in 1:3)
    result[[paste0("kernel_relative_error_", j)]] <- abs(result[[paste0("kernel_", j)]] - .truth$kernel_sd[[j]]^2) / .truth$kernel_sd[[j]]^2
  result$phi_absolute_error <- abs(result$phi_estimate - result$phi)
  result$fixed_effect_mean_absolute_error <- rowMeans(abs(sweep(as.matrix(result[paste0("beta_", 1:3)]), 2L, .truth$beta, "-")))
  summary <- do.call(rbind, lapply(split(result, result$phi), function(x) data.frame(
    phi = x$phi[[1L]], attempts = nrow(x),
    mean_phi_absolute_error = mean(x$phi_absolute_error),
    median_phi_absolute_error = stats::median(x$phi_absolute_error),
    median_temporal_frobenius_relative_error = stats::median(x$temporal_frobenius_relative_error),
    median_kernel_1_relative_error = stats::median(x$kernel_relative_error_1),
    median_kernel_2_relative_error = stats::median(x$kernel_relative_error_2),
    median_kernel_3_relative_error = stats::median(x$kernel_relative_error_3),
    mean_fixed_effect_error = mean(x$fixed_effect_mean_absolute_error), stringsAsFactors = FALSE)))
  summary$passes <- with(summary, attempts == 3L & mean_phi_absolute_error <= .15 &
    median_phi_absolute_error <= .20 & median_temporal_frobenius_relative_error <= .30 &
    median_kernel_1_relative_error <= .35 & median_kernel_2_relative_error <= .35 &
    median_kernel_3_relative_error <= .35 & mean_fixed_effect_error <= .25)
  list(result = result, summary = summary)
}
.verify <- function(dir) {
  files <- sort(list.files(dir, pattern = "[.]rds$", full.names = TRUE))
  if (length(files) != 9L) stop("qualification requires exactly nine retained RDS receipts", call. = FALSE)
  result <- do.call(rbind, lapply(files, .receipt_row))
  if (anyDuplicated(.key(result)) || !setequal(.key(result), .key(.plan)))
    stop("retained receipt identities do not equal the frozen nine-cell plan", call. = FALSE)
  out <- .summarise(result)
  if (!all(out$summary$passes)) stop("retained qualification violates one or more frozen recovery thresholds", call. = FALSE)
  print(out$summary, row.names = FALSE)
  cat("TEMPORAL_DEP_KERNEL_SCALED_QUALIFICATION_RECEIPT_PASS\n")
}
.self_test <- function() {
  if (nrow(.plan) != 9L || anyDuplicated(.key(.plan)) ||
      !identical(sort(unique(.plan$phi)), c(-.4, 0, .6)) ||
      !identical(sort(unique(.plan$seed)), 2609371:2609373))
    stop("frozen qualification plan is malformed", call. = FALSE)
  L <- .unpack_loading(c(.55, .50, .48, .12, -.08, .10))
  if (!isTRUE(all.equal(L, .truth$temporal_loading))) stop("loading unpacking is malformed", call. = FALSE)
  cat("TEMPORAL_DEP_KERNEL_SCALED_QUALIFICATION_VERIFY_SELF_TEST_PASS\n")
}

verify_arg <- grep("^--verify=", .args, value = TRUE)
if (identical(.args, "--self-test")) .self_test() else if (length(verify_arg) == 1L && length(.args) == 1L) {
  .verify(sub("^--verify=", "", verify_arg))
} else stop("usage: verify-dep-kernel-curvature-scaled-qualification.R --self-test | --verify=DIR", call. = FALSE)
