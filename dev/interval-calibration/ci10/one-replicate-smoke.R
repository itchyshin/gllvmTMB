#!/usr/bin/env Rscript
## Deliberately unexecuted CI-10 timing/preflight rehearsal.
## Calling ci10_smoke_one_replicate() runs exactly one outer replicate.  It is
## not a campaign and needs the caller's recorded timing approval.

.ci10_kernel_path <- "dev/interval-calibration/ci10/ci10-kernels.R"
.ci10_xfc_path <- "dev/cross-family-coverage.R"
if (!file.exists(.ci10_kernel_path)) {
  .ci10_kernel_path <- "ci10-kernels.R"
}
if (!file.exists(.ci10_xfc_path)) {
  .ci10_xfc_path <- "../../cross-family-coverage.R"
}
source(.ci10_kernel_path)
source(.ci10_xfc_path)

ci10_smoke_cell <- function(
  partner = "gaussian",
  N = 50L,
  target_multiple_r = 0.2
) {
  spec <- ci10_campaign_spec()
  cell <- spec$cells[
    spec$cells$partner == partner &
      spec$cells$N == as.integer(N) &
      abs(spec$cells$target_multiple_r - as.numeric(target_multiple_r)) < 1e-12,
    ,
    drop = FALSE
  ]
  if (nrow(cell) != 1L) {
    stop("CI-10 smoke must use one frozen promotional cell", call. = FALSE)
  }
  cell
}

.ci10_smoke_target_outcomes <- function(xfc_result) {
  outcomes <- c(
    multiple_r = "ci_failed",
    `contrast_r:cat:2` = "ci_failed",
    `contrast_r:cat:3` = "ci_failed"
  )
  if (!is.null(xfc_result$multiple_r) && nrow(xfc_result$multiple_r) == 1L) {
    outcomes[["multiple_r"]] <- if (
      isTRUE(xfc_result$multiple_r$ci_failed[1L])
    ) {
      "ci_failed"
    } else if (isTRUE(xfc_result$multiple_r$covered[1L])) {
      "covered"
    } else {
      "miss"
    }
  }
  if (!is.null(xfc_result$contrast_r)) {
    for (contrast in c("cat:2", "cat:3")) {
      hit <- xfc_result$contrast_r[
        xfc_result$contrast_r$contrast == contrast,
        ,
        drop = FALSE
      ]
      if (nrow(hit) == 1L) {
        outcomes[[paste0("contrast_r:", contrast)]] <- if (
          isTRUE(hit$ci_failed[1L])
        ) {
          "ci_failed"
        } else if (isTRUE(hit$covered[1L])) {
          "covered"
        } else {
          "miss"
        }
      }
    }
  }
  outcomes
}

## Uses .xfc_build_truth() and .xfc_one_rep() unchanged.  Consequently the
## partner family/link rows and interval split remain frozen: multiple_r uses
## the bootstrap route and contrast_r uses the profile route.
ci10_smoke_one_replicate <- function(
  partner = "gaussian",
  N = 50L,
  target_multiple_r = 0.2,
  rep = 1L,
  n_boot = 8L,
  reps = 5L,
  source_sha,
  out_dir
) {
  if (
    !is.character(source_sha) || length(source_sha) != 1L || !nzchar(source_sha)
  ) {
    stop("source_sha is required for a CI-10 smoke", call. = FALSE)
  }
  if (
    missing(out_dir) ||
      !is.character(out_dir) ||
      length(out_dir) != 1L ||
      !nzchar(out_dir)
  ) {
    stop("out_dir is required for a CI-10 smoke receipt", call. = FALSE)
  }
  n_boot <- as.integer(n_boot)
  reps <- as.integer(reps)
  rep <- as.integer(rep)
  if (n_boot < 1L || reps < 1L) {
    stop("n_boot and reps must be positive", call. = FALSE)
  }
  cell <- ci10_smoke_cell(partner, N, target_multiple_r)
  manifest <- ci10_attempt_manifest(
    ci10_campaign_spec(),
    cell_ids = cell$cell_id,
    rep_ids = rep,
    source_sha = source_sha
  )
  started <- proc.time()[["elapsed"]]
  xfc_result <- tryCatch(
    {
      truth <- .xfc_build_truth(cell$target_multiple_r, cell$partner)
      .xfc_one_rep(
        truth,
        N = cell$N,
        reps = reps,
        seed = ci10_rep_seed(manifest$seed_base, cell$cell_id, rep),
        n_boot = n_boot,
        estimands = c("multiple_r", "contrast_r")
      )
    },
    error = identity
  )
  elapsed <- proc.time()[["elapsed"]] - started
  attempt <- if (inherits(xfc_result, "error")) {
    ci10_outer_attempt(manifest, cell$cell_id, rep, "scientific_base_failure")
  } else if (!isTRUE(xfc_result$converged)) {
    ci10_outer_attempt(manifest, cell$cell_id, rep, "base_fit_failed")
  } else {
    ci10_outer_attempt(
      manifest,
      cell$cell_id,
      rep,
      "eligible",
      ci10_target_results(manifest, .ci10_smoke_target_outcomes(xfc_result))
    )
  }
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  runtime <- list(
    schema = "CI10_ONE_REPLICATE_RUNTIME_V1",
    elapsed_seconds = elapsed,
    n_boot = n_boot,
    reps = reps,
    completed_at = Sys.time()
  )
  provenance <- list(
    schema = "CI10_ONE_REPLICATE_PROVENANCE_V1",
    source_sha = source_sha,
    manifest_fingerprint = manifest$fingerprint,
    seed = attempt$seed,
    cell = cell,
    xfc_contract = ".xfc_one_rep: bootstrap multiple_r; profile contrast_r",
    historical_seed_exception = manifest$historical_seed_exception,
    error = if (inherits(xfc_result, "error")) {
      conditionMessage(xfc_result)
    } else {
      NULL
    }
  )
  saveRDS(attempt, file.path(out_dir, "outer-attempt.rds"))
  saveRDS(runtime, file.path(out_dir, "runtime.rds"))
  saveRDS(provenance, file.path(out_dir, "provenance.rds"))
  invisible(list(
    attempt = attempt,
    runtime = runtime,
    provenance = provenance,
    receipt_paths = file.path(
      out_dir,
      c("outer-attempt.rds", "runtime.rds", "provenance.rds")
    )
  ))
}
