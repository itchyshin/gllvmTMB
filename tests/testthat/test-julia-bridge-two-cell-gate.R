gate_lib <- file.path("dev", "julia-bridge-gate", "two-cell-gate-lib.R")
if (!file.exists(gate_lib)) {
  gate_lib <- testthat::test_path("..", "..", "dev", "julia-bridge-gate", "two-cell-gate-lib.R")
}
source(gate_lib, local = TRUE)

test_that("two-cell specification freezes exact pins, four records, and thresholds", {
  spec <- bridge_gate_spec()

  expect_identical(
    spec$gllvmtmb_sha,
    "86e95fff170767b23980152b7d6fce9bb2207718"
  )
  expect_identical(
    spec$gllvmjl_sha,
    "00a2d7b7024b21f55cb124bee2d2e4cf8a546b40"
  )
  expect_identical(spec$gllvmtmb_tree, "4393be7730b306e310843c7621b4517cc3ad86fb")
  expect_identical(spec$gllvmjl_tree, "8a243605516a0d660d703135acb0b1bd9a0e4f15")
  expect_identical(spec$gllvmtmb_archive_sha256, "03053140ff39ef0945c51577acd74a1cfd87e5733cf697c7f231fb420a67d594")
  expect_identical(spec$gllvmjl_archive_sha256, "515ae818a0c66b2dddda4306ade9643310e7531c504183e352ac598b8d1bd4b7")
  expect_identical(spec$gllvmjl_project_sha256, "bd85aa8977102a28872fa34b019dce1ad96e50171ad52907f2f34f37d06f0128")
  expect_identical(spec$planned_ids, c(
    "gaussian-tmb", "gaussian-julia", "poisson-tmb", "poisson-julia"
  ))
  expect_identical(spec$planned_n, 4L)
  expect_identical(spec$stop_seconds, 30 * 60)
  expect_identical(spec$threads, 1L)
  expect_identical(spec$thresholds$gaussian, c(
    logLik_abs = 1e-4,
    covariance_relative_frobenius = 1e-5,
    correlation_max_abs = 1e-5,
    fitted_mean_max_relative = 1e-4
  ))
  expect_identical(spec$thresholds$poisson, c(
    logLik_abs = 1e-3,
    covariance_relative_frobenius = 1e-2,
    correlation_max_abs = 1e-2,
    fitted_mean_max_relative = 1e-2
  ))
})

test_that("fixtures are deterministic, complete, balanced, and loadings-only", {
  a <- bridge_gate_fixtures()
  b <- bridge_gate_fixtures()

  expect_identical(a, b)
  expect_identical(names(a), c("gaussian", "poisson"))
  for (fixture in a) {
    expect_equal(nrow(fixture$data), 40L * 3L)
    expect_false(anyNA(fixture$data$value))
    expect_equal(as.integer(table(fixture$data$unit)), rep(3L, 40L))
    expect_equal(as.integer(table(fixture$data$trait)), rep(40L, 3L))
    expect_identical(fixture$rank, 1L)
    expect_identical(fixture$unique, FALSE)
    expect_match(fixture$formula_text, "unique = FALSE", fixed = TRUE)
  }
  expect_true(all(a$poisson$data$value >= 0))
  expect_true(all(a$poisson$data$value == floor(a$poisson$data$value)))
})

test_that("a pre-fit terminal outcome preserves all four denominator records", {
  records <- bridge_gate_terminal_records(
    code = "NO_RUN_SOURCE_CONTRACT",
    reason = "capability mismatch"
  )

  expect_equal(nrow(records), 4L)
  expect_identical(records$attempt_id, bridge_gate_spec()$planned_ids)
  expect_true(all(records$status == "unavailable"))
  expect_true(all(records$terminal_code == "NO_RUN_SOURCE_CONTRACT"))
  expect_true(all(records$reason == "capability mismatch"))
  expect_false(any(records$started))
})

test_that("pair verdict uses only frozen invariant targets", {
  native <- list(
    logLik = -100,
    Sigma = matrix(c(1, 0.2, 0.2, 0.5), 2),
    R = matrix(c(1, 0.3, 0.3, 1), 2),
    fitted_mean = c(1, 2)
  )
  julia <- native

  pass <- bridge_gate_assess_pair(native, julia, family = "gaussian")
  expect_true(pass$passed)
  expect_identical(
    names(pass$metrics),
    c("logLik_abs", "covariance_relative_frobenius", "correlation_max_abs", "fitted_mean_max_relative")
  )

  julia$Sigma[1, 1] <- julia$Sigma[1, 1] + 0.1
  fail <- bridge_gate_assess_pair(native, julia, family = "gaussian")
  expect_false(fail$passed)
  expect_false(fail$checks[["covariance_relative_frobenius"]])
})

test_that("manifest writer uses standard two-space SHA-256 records", {
  root <- withr::local_tempdir()
  writeLines("alpha", file.path(root, "a.txt"))
  writeLines("beta", file.path(root, "b.txt"))

  manifest <- bridge_gate_write_manifest(root, c("a.txt", "b.txt"))
  lines <- readLines(manifest, warn = FALSE)

  expect_length(lines, 2L)
  expect_true(all(grepl("^[0-9a-f]{64}  [^/].*$", lines)))
})

test_that("source validator accepts exact eligible pins and explicit Manifest absence", {
  contract <- list(
    status = "eligible",
    gllvmtmb_sha = bridge_gate_spec()$gllvmtmb_sha,
    gllvmtmb_tree = bridge_gate_spec()$gllvmtmb_tree,
    gllvmjl_sha = bridge_gate_spec()$gllvmjl_sha,
    gllvmjl_tree = bridge_gate_spec()$gllvmjl_tree,
    gllvmtmb_archive_sha256 = bridge_gate_spec()$gllvmtmb_archive_sha256,
    gllvmjl_archive_sha256 = bridge_gate_spec()$gllvmjl_archive_sha256,
    project_sha256 = bridge_gate_spec()$gllvmjl_project_sha256,
    manifest_status = "absent_in_source_generated_at_runtime",
    resolved_manifest_sha256 = paste(rep("b", 64L), collapse = ""),
    installed_dll_sha256 = paste(rep("c", 64L), collapse = ""),
    capability_status = "eligible_static_and_runtime"
  )

  expect_identical(bridge_gate_validate_source_contract(contract), "eligible")
  contract$gllvmjl_sha <- sub("^0", "1", contract$gllvmjl_sha)
  expect_error(bridge_gate_validate_source_contract(contract), "GLLVM.jl SHA")
})

test_that("source validator admits an exact pre-fit terminal runtime receipt", {
  spec <- bridge_gate_spec()
  contract <- list(
    status = "terminal",
    terminal_code = "NO_RUN_SOURCE_CONTRACT",
    fit_started = FALSE,
    reason = "JuliaCall embedding exited 139 before fitting",
    gllvmtmb_sha = spec$gllvmtmb_sha,
    gllvmtmb_tree = spec$gllvmtmb_tree,
    gllvmjl_sha = spec$gllvmjl_sha,
    gllvmjl_tree = spec$gllvmjl_tree,
    gllvmtmb_archive_sha256 = spec$gllvmtmb_archive_sha256,
    gllvmjl_archive_sha256 = spec$gllvmjl_archive_sha256,
    project_sha256 = spec$gllvmjl_project_sha256,
    manifest_status = "absent_in_source_generated_at_runtime",
    resolved_manifest_sha256 = paste(rep("b", 64L), collapse = ""),
    installed_dll_sha256 = paste(rep("c", 64L), collapse = ""),
    capability_status = "eligible_static_runtime_embedding_failed"
    ,julia_embedding_exit = c(`1.12.6` = 139L, `1.10.10` = 139L)
    ,qualification_receipts = c(
      `1.12.6` = "process/julia-1_12_6.receipt",
      `1.10.10` = "process/julia-1_10_10.receipt"
    )
    ,qualification_receipt_sha256 = c(
      `1.12.6` = paste(rep("d", 64L), collapse = ""),
      `1.10.10` = paste(rep("e", 64L), collapse = "")
    )
    ,runtime_manifest_files = c(
      `1.12.6` = "GLLVM-Manifest-julia-1.12.6.toml",
      `1.10.10` = "GLLVM-Manifest-julia-1.10.10.toml"
    )
    ,runtime_manifest_sha256 = c(
      `1.12.6` = paste(rep("f", 64L), collapse = ""),
      `1.10.10` = paste(rep("a", 64L), collapse = "")
    )
  )
  expect_identical(bridge_gate_validate_source_contract(contract), "terminal")
  contract$fit_started <- TRUE
  expect_error(bridge_gate_validate_source_contract(contract), "fit-start")
})

test_that("terminal process receipts prove direct eligibility and bridge failure", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "process"))
  versions <- c("1.12.6", "1.10.10")
  paths <- c("process/julia-1_12_6.receipt", "process/julia-1_10_10.receipt")
  for (i in seq_along(versions)) {
    prefix <- sub("\\.receipt$", "", paths[[i]])
    logs <- paste0(prefix, c("-direct.stdout.log", "-direct.stderr.log", "-bridge.stdout.log", "-bridge.stderr.log"))
    writeLines(paste0("JULIA_VERSION=", versions[[i]], "\ngaussian poisson"), file.path(root, logs[[1L]]))
    for (path in logs[-1L]) writeLines(character(), file.path(root, path))
    writeLines(c(
      "schema=bridge-source-qualification-v1",
      paste0("version=", versions[[i]]),
      "julia_home=/qualified/bin",
      "julia_depot=/qualified/depot",
      "gllvm_path=/qualified/GLLVM.jl",
      "started_at=2026-08-28T00:00:00Z",
      "finished_at=2026-08-28T00:00:01Z",
      "direct_command=direct",
      paste0("direct_stdout=", logs[[1L]]),
      paste0("direct_stderr=", logs[[2L]]),
      "direct_exit_status=0",
      "bridge_command=bridge",
      paste0("bridge_stdout=", logs[[3L]]),
      paste0("bridge_stderr=", logs[[4L]]),
      "bridge_exit_status=139",
      "fit_started=false"
    ), file.path(root, paths[[i]]))
  }
  contract <- list(qualification_receipts = stats::setNames(paths, versions))
  expect_true(bridge_gate_validate_process_receipts(root, contract))
  bad <- readLines(file.path(root, paths[[1L]]))
  writeLines(sub("bridge_exit_status=139", "bridge_exit_status=1", bad, fixed = TRUE), file.path(root, paths[[1L]]))
  expect_error(bridge_gate_validate_process_receipts(root, contract), "does not prove")
})

test_that("denominator validator accepts exactly four final records and rejects replacements", {
  records <- bridge_gate_terminal_records("NO_RUN_SOURCE_CONTRACT", "test")
  expect_true(bridge_gate_validate_denominator(records))

  expect_error(
    bridge_gate_validate_denominator(records[-1, ]),
    "exactly four"
  )
  duplicate <- rbind(records, records[1, ])
  expect_error(bridge_gate_validate_denominator(duplicate), "exactly four")
  records$attempt_id[4] <- "poisson-replacement"
  expect_error(bridge_gate_validate_denominator(records), "planned attempt IDs")
})

test_that("verdict validator distinguishes paired evidence from terminal no-run", {
  terminal <- list(
    outcome = "NO_RUN_SOURCE_CONTRACT",
    fit_started = FALSE,
    thresholds_frozen = TRUE,
    replacement_attempts = 0L
  )
  expect_identical(bridge_gate_validate_verdict(terminal), "terminal")

  paired <- list(
    outcome = "BRIDGE_GATE_PASS",
    fit_started = TRUE,
    thresholds_frozen = TRUE,
    replacement_attempts = 0L,
    families = c("gaussian", "poisson"),
    invariant_only = TRUE
  )
  expect_identical(bridge_gate_validate_verdict(paired), "paired")
  paired$invariant_only <- FALSE
  expect_error(bridge_gate_validate_verdict(paired), "rotation-invariant")
})

test_that("attempt executor retains every passed and failed planned record", {
  root <- withr::local_tempdir()
  fit_one <- function(attempt_id, fixture) {
    if (identical(attempt_id, "poisson-julia")) {
      stop("synthetic engine failure")
    }
    list(
      logLik = -10,
      Sigma = diag(3),
      R = diag(3),
      fitted_mean = rep(1, nrow(fixture$data)),
      termination = "converged"
    )
  }

  records <- bridge_gate_execute_plan(root, fit_one = fit_one)

  expect_true(bridge_gate_validate_denominator(records))
  expect_identical(records$status, c("passed", "passed", "passed", "failed"))
  expect_true(all(file.exists(file.path(root, "started", paste0(records$attempt_id, ".rds")))))
  expect_true(all(file.exists(file.path(root, "attempts", paste0(records$attempt_id, ".rds")))))
  expect_match(records$reason[4], "synthetic engine failure", fixed = TRUE)
})

test_that("attempt executor retains unstarted denominator records after timeout", {
  root <- withr::local_tempdir()
  tick <- 0L
  clock <- function() {
    tick <<- tick + 1L
    as.POSIXct(tick * 1000, origin = "1970-01-01", tz = "UTC")
  }
  fit_one <- function(attempt_id, fixture) {
    list(
      logLik = -10,
      Sigma = diag(3),
      R = diag(3),
      fitted_mean = rep(1, nrow(fixture$data)),
      termination = "converged"
    )
  }

  records <- bridge_gate_execute_plan(
    root,
    fit_one = fit_one,
    clock = clock,
    stop_seconds = 1500
  )

  expect_true(bridge_gate_validate_denominator(records))
  expect_identical(records$status, c(
    "passed", "not_started_after_abort", "not_started_after_abort", "not_started_after_abort"
  ))
  expect_identical(records$started, c(TRUE, FALSE, FALSE, FALSE))
  expect_true(all(file.exists(file.path(root, "attempts", paste0(records$attempt_id, ".rds")))))
})

test_that("fitted values are aligned by trait and unit across engine shapes", {
  fixture <- bridge_gate_fixtures()$gaussian
  keyed <- transform(fixture$data[c("unit", "trait")], est = seq_len(nrow(fixture$data)))
  matrix_form <- matrix(
    keyed$est[order(keyed$trait, keyed$unit)],
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(levels(fixture$data$trait), levels(fixture$data$unit))
  )

  expect_identical(
    bridge_gate_align_fitted(keyed, fixture$data),
    as.numeric(seq_len(nrow(fixture$data)))
  )
  expect_identical(
    bridge_gate_align_fitted(matrix_form, fixture$data),
    as.numeric(seq_len(nrow(fixture$data)))
  )
})

test_that("target extraction retains only finite invariant evidence and convergence", {
  fixture <- bridge_gate_fixtures()$gaussian
  keyed <- transform(fixture$data[c("unit", "trait")], est = rep(1, nrow(fixture$data)))
  fit <- structure(list(
    ll = -12,
    sigma = diag(3),
    correlation = diag(3),
    fitted = keyed,
    converged = TRUE
  ), class = "fake_gate_fit")
  api <- list(
    logLik = function(x) x$ll,
    extract_sigma = function(x) list(Sigma = x$sigma, R = x$correlation),
    fitted = function(x) x$fitted,
    convergence = function(x, engine) isTRUE(x$converged)
  )

  out <- bridge_gate_extract_targets(fit, fixture, "tmb", api)
  expect_identical(names(out), c("logLik", "Sigma", "R", "fitted_mean", "converged"))
  expect_true(out$converged)
  expect_true(all(vapply(out[1:4], function(x) all(is.finite(x)), logical(1))))

  fit$ll <- Inf
  expect_error(
    bridge_gate_extract_targets(fit, fixture, "tmb", api),
    "non-finite invariant"
  )
})

test_that("artifact verifier accepts a complete synthetic terminal receipt", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "attempts"))
  contract <- list(
    status = "eligible",
    gllvmtmb_sha = bridge_gate_spec()$gllvmtmb_sha,
    gllvmtmb_tree = bridge_gate_spec()$gllvmtmb_tree,
    gllvmjl_sha = bridge_gate_spec()$gllvmjl_sha,
    gllvmjl_tree = bridge_gate_spec()$gllvmjl_tree,
    gllvmtmb_archive_sha256 = bridge_gate_spec()$gllvmtmb_archive_sha256,
    gllvmjl_archive_sha256 = bridge_gate_spec()$gllvmjl_archive_sha256,
    project_sha256 = bridge_gate_spec()$gllvmjl_project_sha256,
    manifest_status = "absent_in_source_generated_at_runtime",
    resolved_manifest_sha256 = paste(rep("b", 64L), collapse = ""),
    installed_dll_sha256 = paste(rep("c", 64L), collapse = ""),
    capability_status = "eligible_static_and_runtime"
  )
  saveRDS(contract, file.path(root, "source-contract.rds"))
  records <- bridge_gate_terminal_records("STOP_30_MINUTES", "synthetic")
  utils::write.csv(records, file.path(root, "records.csv"), row.names = FALSE)
  verdict <- list(
    outcome = "STOP_30_MINUTES", fit_started = FALSE,
    thresholds_frozen = TRUE, replacement_attempts = 0L
  )
  saveRDS(verdict, file.path(root, "verdict.rds"))
  for (id in records$attempt_id) {
    saveRDS(list(record = records[records$attempt_id == id, ], result = NULL),
            file.path(root, "attempts", paste0(id, ".rds")))
  }
  members <- c("source-contract.rds", "records.csv", "verdict.rds",
               file.path("attempts", paste0(records$attempt_id, ".rds")))
  bridge_gate_write_manifest(root, members)

  expect_identical(bridge_gate_verify_artifacts(root, "source"), "G2_SOURCE_CONTRACT_OK")
  expect_identical(bridge_gate_verify_artifacts(root, "denominator"), "G3_DENOMINATOR_OK")
  expect_identical(bridge_gate_verify_artifacts(root, "verdict"), "G4_VERDICT_OK")
  expect_identical(bridge_gate_verify_artifacts(root, "manifest"), "G5_MANIFEST_OK")
})
