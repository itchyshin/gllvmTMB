## Bounded PVT-02 outer-receipt smoke.  This future pre-run fits once per
## replicate and retains both profile targets under that single outer row.

args <- commandArgs(trailingOnly = TRUE)
out_path <- if (length(args)) {
  args[[1L]]
} else {
  file.path(
    "dev",
    "pvt02",
    "results",
    "2026-08-25-pvt02-two-target-smoke-receipt.rds"
  )
}
if (length(args) > 1L) {
  stop("usage: Rscript dev/pvt02/pvt02-smoke.R [output.rds]")
}

source(file.path("dev", "pvt02", "pvt02-contract.R"))
source(file.path("dev", "m3-grid.R"))
source_sha <- Sys.getenv("PVT02_SOURCE_SHA", unset = "")
if (!nzchar(source_sha)) {
  stop("PVT02_SOURCE_SHA must be an explicit nonempty source SHA")
}
cell <- list(
  family = "gaussian",
  tier = "unit",
  mode = "latent",
  unique = TRUE,
  d = 2L,
  n_units = 400L,
  n_traits = 3L,
  target_scale = "log_V",
  level = 0.95
)

pvt02_smoke_one <- function(manifest_row) {
  seed <- manifest_row$seed[[1L]]
  truth <- m3_sample_truth(
    family = "gaussian",
    d = 2L,
    n_traits = 3L,
    n_units = 400L,
    seed = seed,
    lambda_scale = M3_DEFAULT_LAMBDA_SCALE,
    psi_scale = M3_DEFAULT_PSI_SCALE
  )
  sim <- m3_simulate_response(truth)
  fit_error <- NULL
  fit <- tryCatch(
    withCallingHandlers(
      gllvmTMB::gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = TRUE),
        data = sim$data,
        family = stats::gaussian(),
        unit = "unit",
        control = gllvmTMB::gllvmTMBcontrol(se = TRUE)
      ),
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) {
      fit_error <<- conditionMessage(e)
      NULL
    }
  )
  fit_converged <- pvt02_fit_is_healthy(fit)
  if (!fit_converged) {
    return(pvt02_outer_attempt_row(
      manifest_row,
      FALSE,
      NULL,
      endpoint_reason = if (is.null(fit_error)) {
        "fit_failed"
      } else {
        paste0("fit_error: ", fit_error)
      }
    ))
  }
  targets <- do.call(
    rbind,
    lapply(1:2, function(trait) {
      profile_error <- NULL
      ci <- tryCatch(
        gllvmTMB::profile_ci_total_variance(
          fit,
          tier = "unit",
          trait_idx = trait,
          level = 0.95
        ),
        error = function(e) {
          profile_error <<- conditionMessage(e)
          NULL
        }
      )
      pvt02_target_payload(
        trait,
        truth$diag_Sigma[[trait]],
        if (!is.null(ci) && nrow(ci) == 1L) ci$estimate[[1L]] else NA_real_,
        if (!is.null(ci) && nrow(ci) == 1L) ci$lower[[1L]] else NA_real_,
        if (!is.null(ci) && nrow(ci) == 1L) ci$upper[[1L]] else NA_real_,
        endpoint_reason = if (is.null(profile_error)) {
          "profile_endpoint_invalid"
        } else {
          paste0("profile_error: ", profile_error)
        },
        interval_status = if (!is.null(ci) && nrow(ci) == 1L) {
          ci$interval_status[[1L]]
        } else {
          "route-only"
        }
      )
    })
  )
  pvt02_outer_attempt_row(manifest_row, TRUE, targets)
}

manifest <- pvt02_campaign_manifest(
  cell,
  source_sha,
  reps = pvt02_seed_window(50001L, 2L)
)
smoke_results <- lapply(seq_len(nrow(manifest)), function(i) {
  started <- proc.time()[["elapsed"]]
  attempt <- pvt02_smoke_one(manifest[i, , drop = FALSE])
  list(
    attempt = attempt,
    elapsed_seconds = unname(proc.time()[["elapsed"]] - started)
  )
})
canonical <- do.call(rbind, lapply(smoke_results, `[[`, "attempt"))
runtime <- data.frame(
  rep = manifest$rep,
  seed = manifest$seed,
  elapsed_seconds = vapply(smoke_results, `[[`, numeric(1), "elapsed_seconds")
)
receipt <- pvt02_batch_receipt(manifest, canonical)
pvt02_validate_batch_receipt(receipt, manifest)
payload <- list(
  schema = "PVT02_TWO_TARGET_SMOKE_V1",
  receipt = receipt,
  runtime = runtime,
  provenance = list(
    source_sha = source_sha,
    manifest_fingerprint = receipt$manifest_fingerprint,
    estimand = "V_t = (Lambda Lambda^T)[t,t] + psi_t^2",
    interval = "two-sided 95% likelihood-ratio profile on log(V_t)",
    targets = 1:2,
    completed_at = Sys.time()
  )
)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
saveRDS(payload, out_path)
cat(sprintf(
  "PVT02_SMOKE_WROTE %s (%d retained outer rows)\n",
  out_path,
  nrow(canonical)
))
