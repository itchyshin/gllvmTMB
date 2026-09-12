## Frozen per-cell runner for the curvature-scaled BFGS qualification.

args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) stop("Run from the repository root.", call. = FALSE)
source(file.path(root, "dev", "temporal-program", "diagnose-dep-kernel-curvature-scaled-bfgs.R"), local = FALSE)

.scaled_qualification_plan <- function() {
  out <- expand.grid(phi = c(-.4, 0, .6), seed = 2609371:2609373, KEEP.OUT.ATTRS = FALSE)
  out <- out[order(out$phi, out$seed), , drop = FALSE]
  out$n_series <- 80L; out$n_time <- 32L
  out
}

.scaled_qualification_key <- function(phi, seed) {
  plan <- .scaled_qualification_plan()
  hit <- plan[plan$phi == phi & plan$seed == seed, , drop = FALSE]
  if (nrow(hit) != 1L) stop("phi and seed are not one frozen curvature-scaled qualification cell", call. = FALSE)
  .scaled_target(hit$phi[[1L]], hit$seed[[1L]])
}

.scaled_qualification_self_test <- function() {
  plan <- .scaled_qualification_plan()
  if (nrow(plan) != 9L || anyDuplicated(paste(plan$phi, plan$seed)) ||
      !identical(sort(unique(plan$phi)), c(-.4, 0, .6)) ||
      !identical(sort(unique(plan$seed)), 2609371:2609373)) {
    stop("scaled qualification plan is not the frozen nine-cell grid", call. = FALSE)
  }
  .scaled_qualification_key(.6, 2609372L)
  cat("TEMPORAL_DEP_KERNEL_SCALED_QUALIFICATION_SELF_TEST_PASS\n")
}

phi_arg <- grep("^--phi=", args, value = TRUE)
seed_arg <- grep("^--seed=", args, value = TRUE)
output_arg <- grep("^--output=", args, value = TRUE)
if (identical(args, "--self-test")) {
  .scaled_qualification_self_test()
} else if (length(phi_arg) == 1L && length(seed_arg) == 1L && length(output_arg) == 1L && length(args) == 3L) {
  target <- .scaled_qualification_key(as.numeric(sub("^--phi=", "", phi_arg)),
    as.integer(sub("^--seed=", "", seed_arg)))
  output <- sub("^--output=", "", output_arg)
  .scaled_run(output, target)
  receipt <- readRDS(output)
  if (!identical(receipt$target, target)) stop("retained scaled qualification receipt has wrong cell identity", call. = FALSE)
  cat(if (identical(receipt$terminal, "success")) "TEMPORAL_DEP_KERNEL_SCALED_QUALIFICATION_CELL_RETAINED\n" else "TEMPORAL_DEP_KERNEL_SCALED_QUALIFICATION_CELL_ERROR_RETAINED\n")
} else {
  stop("usage: run-dep-kernel-curvature-scaled-qualification.R --self-test | --phi=VALUE --seed=INTEGER --output=PATH", call. = FALSE)
}
