.pvt02_packet_contract_path <- testthat::test_path(
  "..", "..", "dev", "pvt02", "pvt02-contract.R"
)
.pvt02_packet_contract_available <- file.exists(.pvt02_packet_contract_path)

if (.pvt02_packet_contract_available) {
  source(.pvt02_packet_contract_path)

pvt02_test_sha <- "0123456789abcdef"
pvt02_test_cell <- function() {
  list(
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
}

pvt02_test_outer <- function(manifest_row, trait2_covered = TRUE) {
  targets <- do.call(
    rbind,
    list(
      pvt02_target_payload(1L, truth = 2, estimate = 2, lower = 1, upper = 3),
      pvt02_target_payload(
        2L,
        truth = if (trait2_covered) 2 else 4,
        estimate = 2,
        lower = 1,
        upper = 3
      )
    )
  )
  pvt02_outer_attempt_row(manifest_row, fit_converged = TRUE, targets = targets)
}

test_that("PVT-02 fit health requires convergence and a positive Hessian", {
  healthy <- structure(
    list(
      opt = list(convergence = 0L),
      fit_health = list(converged = TRUE),
      sd_report = structure(list(pdHess = TRUE), class = "sdreport")
    ),
    class = "gllvmTMB_multi"
  )
  expect_true(pvt02_fit_is_healthy(healthy))
  healthy$sd_report$pdHess <- FALSE
  expect_false(pvt02_fit_is_healthy(healthy))

  manifest <- pvt02_campaign_manifest(
    pvt02_test_cell(),
    pvt02_test_sha,
    reps = 50001L
  )
  wrong_status <- pvt02_test_outer(manifest)
  wrong_status$targets[[1L]]$interval_status <- "certified-0.94"
  expect_error(
    pvt02_validate_outer_payload(wrong_status),
    "route-only public status"
  )

  smoke_text <- readLines(testthat::test_path(
    "..",
    "..",
    "dev",
    "pvt02",
    "pvt02-smoke.R"
  ))
  expect_true(any(grepl(
    "gllvmTMB::profile_ci_total_variance(",
    smoke_text,
    fixed = TRUE
  )))
  expect_false(any(grepl(
    "gllvmTMB:::.profile_ci_total_variance(",
    smoke_text,
    fixed = TRUE
  )))
})

test_that("exact PVT-02 manifest has one outer identity and two nested targets", {
  manifest <- pvt02_campaign_manifest(
    pvt02_test_cell(),
    pvt02_test_sha,
    reps = 50001:50003
  )
  expect_equal(nrow(manifest), 3L)
  expect_identical(manifest$rep, 50001:50003)
  expect_identical(manifest$seed, pvt02_campaign_seed(manifest$rep))
  expect_identical(manifest$attempt_id, sprintf("pvt02-r%d-a1", manifest$rep))
  expect_identical(manifest$target_traits, c("1,2", "1,2", "1,2"))
  full_manifest <- pvt02_campaign_manifest(pvt02_test_cell(), pvt02_test_sha)
  expect_equal(nrow(full_manifest), 5000L)
  expect_equal(
    length(strsplit(full_manifest$target_traits[[1L]], ",", fixed = TRUE)[[
      1L
    ]]),
    2L
  )
  expect_error(
    pvt02_campaign_manifest(
      modifyList(pvt02_test_cell(), list(n_traits = 2L)),
      pvt02_test_sha
    ),
    "frozen n_traits = 3"
  )
  expect_error(
    pvt02_campaign_manifest(pvt02_test_cell(), ""),
    "nonempty source_sha"
  )
})

test_that("PVT-02 realised seed reservation avoids the historical LV-effects band", {
  reps <- 50001:55000
  legacy <- pvt02_m3_seed(reps, d = 2L)
  lv_effects_history <- pvt02_seed_window(150001L, 10000L)
  expect_false(pvt02_windows_disjoint(legacy, lv_effects_history))
  reserved <- pvt02_campaign_seed(reps)
  expect_equal(range(reserved), c(800050001L, 800055000L))
  expect_true(pvt02_windows_disjoint(
    reserved,
    pvt02_seed_window(1L, 40000L),
    lv_effects_history
  ))
})

test_that("outer receipts retain fit state and exactly two target payloads", {
  manifest <- pvt02_campaign_manifest(
    pvt02_test_cell(),
    pvt02_test_sha,
    reps = 50001:50002
  )
  canonical <- do.call(
    rbind,
    lapply(seq_len(nrow(manifest)), function(i) pvt02_test_outer(manifest[i, ]))
  )
  retry <- pvt02_operational_retry_row(
    manifest[1, ],
    2L,
    "SLURM node failure",
    "fit"
  )
  receipt <- pvt02_batch_receipt(manifest, canonical, retry)
  expect_silent(pvt02_validate_batch_receipt(receipt, manifest))
  bad_retry_seed <- receipt
  bad_retry_seed$operational_history$seed[[1L]] <-
    bad_retry_seed$operational_history$seed[[1L]] + 1L
  expect_error(
    pvt02_validate_batch_receipt(bad_retry_seed, manifest),
    "operational retry identity"
  )
  bad_retry_id <- receipt
  bad_retry_id$operational_history$attempt_id[[1L]] <- "pvt02-r999-a2"
  expect_error(
    pvt02_validate_batch_receipt(bad_retry_id, manifest),
    "operational retry identity"
  )
  tampered <- receipt
  tampered$manifest_fingerprint <- "not-the-manifest"
  expect_error(pvt02_validate_batch_receipt(tampered, manifest), "fingerprint")
  merged <- pvt02_merge_batch_receipts(manifest, list(receipt))
  expect_equal(nrow(merged$canonical), 2L)
  expect_equal(nrow(merged$canonical$targets[[1L]]), 2L)

  missing_target <- receipt
  missing_target$canonical$targets[[1L]] <- missing_target$canonical$targets[[
    1L
  ]][1L, ]
  expect_error(
    pvt02_validate_batch_receipt(missing_target, manifest),
    "incomplete target payload"
  )
  duplicate_outer <- receipt
  duplicate_outer$canonical <- rbind(
    duplicate_outer$canonical,
    duplicate_outer$canonical[1L, ]
  )
  expect_error(
    pvt02_validate_batch_receipt(duplicate_outer, manifest),
    "duplicate canonical"
  )
  conflicting <- receipt
  conflicting$canonical$targets[[1L]]$upper[[1L]] <- 4
  expect_error(
    pvt02_merge_batch_receipts(manifest, list(receipt, conflicting)),
    "duplicate/conflicting"
  )
  bad_seed <- receipt
  bad_seed$canonical$seed[[1L]] <- bad_seed$canonical$seed[[1L]] + 1L
  expect_error(
    pvt02_validate_batch_receipt(bad_seed, manifest),
    "conflicts with manifest"
  )

  failed <- pvt02_outer_attempt_row(
    manifest[1, ],
    fit_converged = FALSE,
    targets = NULL,
    endpoint_reason = "fit_failed"
  )
  expect_silent(pvt02_validate_outer_payload(failed[1, ]))
  failed$targets[[1L]] <- pvt02_target_payload(1L, 2, 2, 1, 3)
  expect_error(pvt02_validate_outer_payload(failed[1, ]), "fit failure cannot")

  failed_pair <- do.call(
    rbind,
    lapply(seq_len(nrow(manifest)), function(i) {
      pvt02_outer_attempt_row(manifest[i, ], FALSE, NULL, "fit_failed")
    })
  )
  failed_summary <- pvt02_summarise_campaign(
    pvt02_merge_batch_receipts(
      manifest,
      list(pvt02_batch_receipt(manifest, failed_pair))
    ),
    manifest
  )
  expect_equal(failed_summary$n_fit_failed_outer, 2L)
  expect_true(all(is.na(failed_summary$coverage)))
})

test_that("summary expands targets only after outer validation and promotion is outer-count based", {
  manifest <- pvt02_campaign_manifest(
    pvt02_test_cell(),
    pvt02_test_sha,
    reps = 50001:50003
  )
  canonical <- do.call(
    rbind,
    lapply(seq_len(nrow(manifest)), function(i) {
      pvt02_test_outer(manifest[i, ], trait2_covered = FALSE)
    })
  )
  summary <- pvt02_summarise_campaign(
    pvt02_merge_batch_receipts(
      manifest,
      list(pvt02_batch_receipt(manifest, canonical))
    ),
    manifest
  )
  expect_equal(summary$n_outer, 3L)
  expect_equal(summary$coverage, c(`1` = 1, `2` = 0))
  expect_equal(pvt02_availability_report(summary)$n_outer, 3L)
  expect_false(
    pvt02_campaign_promotion_verdict(
      pvt02_test_cell(),
      manifest,
      pvt02_merge_batch_receipts(
        manifest,
        list(pvt02_batch_receipt(manifest, canonical))
      ),
      TRUE,
      5000L
    )$promote
  )
})

test_that("only a complete validated 5000-outer ledger can promote", {
  manifest <- pvt02_campaign_manifest(pvt02_test_cell(), pvt02_test_sha)
  canonical <- do.call(
    rbind,
    lapply(seq_len(nrow(manifest)), function(i) pvt02_test_outer(manifest[i, ]))
  )
  merged <- pvt02_merge_batch_receipts(
    manifest,
    list(pvt02_batch_receipt(manifest, canonical))
  )
  expect_true(
    pvt02_campaign_promotion_verdict(
      pvt02_test_cell(),
      manifest,
      merged,
      TRUE
    )$promote
  )
  bad <- canonical
  for (i in seq_len(400L)) {
    bad$targets[[i]]$truth[[2L]] <- 4
    bad$targets[[i]]$covered[[2L]] <- FALSE
  }
  bad_merged <- pvt02_merge_batch_receipts(
    manifest,
    list(pvt02_batch_receipt(manifest, bad))
  )
  expect_false(
    pvt02_campaign_promotion_verdict(
      pvt02_test_cell(),
      manifest,
      bad_merged,
      TRUE
    )$promote
  )
})

test_that("PVT-02 smoke retains timing and provenance under the ignored results root", {
  smoke <- testthat::test_path("..", "..", "dev", "pvt02", "pvt02-smoke.R")
  expect_silent(parse(smoke))
  text <- paste(readLines(smoke, warn = FALSE), collapse = "\n")
  expect_match(text, "dev.*pvt02.*results")
  expect_match(text, "elapsed_seconds", fixed = TRUE)
  expect_match(text, "manifest_fingerprint", fixed = TRUE)
  expect_match(text, "PVT02_SOURCE_SHA", fixed = TRUE)
})

test_that("PVT-02 remote runner reuses the frozen one-replicate function body", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  env <- new.env(parent = globalenv())
  interval_extract_assignment(
    testthat::test_path("..", "..", "dev", "pvt02", "pvt02-smoke.R"),
    "pvt02_smoke_one",
    env
  )
  expect_true(is.function(env$pvt02_smoke_one))
  expect_match(
    paste(deparse(body(env$pvt02_smoke_one)), collapse = " "),
    "profile_ci_total_variance",
    fixed = TRUE
  )
})
} else {
  test_that("PVT-02 packet checks are source-checkout only", {
    skip("dev/pvt02 is absent from the built package")
  })
}
