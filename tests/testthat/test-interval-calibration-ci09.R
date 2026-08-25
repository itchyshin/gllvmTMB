ci09_kernel <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "ci09",
  "ci09-kernels.R"
)
source(ci09_kernel, local = TRUE)

ci09_smoke <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "ci09",
  "smoke.R"
)
source(ci09_smoke, local = TRUE)

test_that("CI-09 smoke gives the parser an unqualified dep formula", {
  has_formula_helper <- exists("ci09_smoke_formula", mode = "function")
  expect_true(has_formula_helper)
  if (!has_formula_helper) {
    return(invisible())
  }
  smoke_formula <- ci09_smoke_formula()
  expect_false(grepl("::dep", paste(deparse(smoke_formula), collapse = " ")))
  parser <- getFromNamespace("parse_multi_formula", "gllvmTMB")
  expect_silent(parser(smoke_formula))
})

test_that("CI-09 smoke health requires convergence and a positive Hessian", {
  healthy <- structure(
    list(
      opt = list(convergence = 0L),
      fit_health = list(converged = TRUE),
      sd_report = structure(list(pdHess = TRUE), class = "sdreport")
    ),
    class = "gllvmTMB_multi"
  )
  expect_true(ci09_smoke_fit_healthy(healthy))
  healthy$sd_report$pdHess <- FALSE
  expect_false(ci09_smoke_fit_healthy(healthy))
})

test_that("CI-09 smoke records n_eff only for eligible fits", {
  has_n_eff_helper <- exists("ci09_smoke_n_eff", mode = "function")
  expect_true(has_n_eff_helper)
  if (!has_n_eff_helper) {
    return(invisible())
  }
  fit <- list(n_sites = 150L)
  expect_identical(ci09_smoke_n_eff(fit, fit_error = FALSE, converged = TRUE), 150L)
  expect_true(is.na(ci09_smoke_n_eff(fit, fit_error = FALSE, converged = FALSE)))
  expect_true(is.na(ci09_smoke_n_eff(NULL, fit_error = TRUE, converged = FALSE)))
})

test_that("CI-09 freezes six Gaussian Fisher-z cells and seed windows", {
  spec <- ci09_campaign_spec()
  expect_equal(nrow(spec$cells), 6L)
  expect_equal(spec$n_sim, 5000L)
  expect_equal(sort(unique(spec$cells$n_units)), c(150L, 400L))
  expect_equal(sort(unique(spec$cells$rho)), c(-0.5, 0, 0.5))
  expect_equal(ci09_rep_seed(1L, 1L), 90010001L)
  expect_equal(ci09_rep_seed(6L, 5000L), 90065000L)
  expect_false(ci09_seed_sets_intersect(1L, 1:2, 2L, 1:2))
  expect_error(ci09_attempt_manifest(), "source SHA")
  full_manifest <- ci09_attempt_manifest(source_sha = "0123456789abcdef")
  expect_equal(full_manifest$n_outer, 30000L)
  expect_length(full_manifest$expected, 30000L)
  tampered <- full_manifest
  tampered$source_sha <- "different-source"
  expect_error(ci09_validate_manifest(tampered), "modified after freezing")
})

test_that("CI-09 Fisher-z bounds retain realised n_eff and refuse unavailable intervals", {
  interval <- ci09_fisher_interval(rho = 0.5, n_eff = 150L)
  expect_equal(interval$n_eff, 150L)
  expect_true(interval$lower < 0.5)
  expect_true(interval$upper > 0.5)
  expect_true(is.na(ci09_fisher_interval(0.2, n_eff = NA_integer_)$lower))
  expect_true(is.na(ci09_fisher_interval(0.2, n_eff = 3L)$upper))
})

test_that("CI-09 retains all attempts but allows one canonical scientific row only", {
  manifest <- ci09_attempt_manifest(
    cell_ids = 1L,
    rep_ids = 1:2,
    source_sha = "test-attempts"
  )
  covered <- ci09_attempt(manifest, 1L, 1L, "rho_1_2", "covered", n_eff = 150L)
  missing_neff <- ci09_attempt(
    manifest,
    1L,
    2L,
    "rho_1_2",
    "interval_unavailable",
    n_eff = NA_integer_
  )
  merged <- ci09_merge_attempts(manifest, list(covered, missing_neff))
  expect_equal(nrow(merged$canonical), 2L)
  expect_equal(nrow(merged$operational), 2L)
  expect_equal(merged$canonical$outcome[2L], "interval_unavailable")
  interval_summary <- ci09_summarise(merged)$targets
  expect_equal(interval_summary$n_eligible, 2L)
  expect_equal(interval_summary$coverage, 0.5)
  expect_equal(interval_summary$interval_available_rate, 0.5)
  expect_error(
    ci09_merge_attempts(manifest, list(covered)),
    "missing canonical"
  )
  expect_error(
    ci09_merge_attempts(manifest, list(covered, covered, missing_neff)),
    "duplicate"
  )
  wrong_seed <- covered
  wrong_seed$seed <- wrong_seed$seed + 1L
  expect_error(
    ci09_merge_attempts(manifest, list(wrong_seed, missing_neff)),
    "seed collision"
  )
})

test_that("CI-09 treats eligible CI failure as a miss and promotes every target fail-closed", {
  manifest <- ci09_attempt_manifest(
    cell_ids = 1L,
    rep_ids = 1:100,
    source_sha = "test-promotion"
  )
  attempts <- lapply(manifest$expected, function(x) {
    ci09_attempt(
      manifest,
      x$cell_id,
      x$rep,
      x$target_id,
      "covered",
      n_eff = 150L
    )
  })
  for (i in seq_len(10L)) {
    attempts[[i]] <- ci09_attempt(
      manifest,
      1L,
      i,
      "rho_1_2",
      "ci_failed",
      n_eff = 150L
    )
  }
  summary <- ci09_summarise(ci09_merge_attempts(manifest, attempts))
  expect_equal(summary$targets$n_ci_failed, 10L)
  expect_equal(summary$targets$coverage, 0.9)
  expect_false(ci09_promote(summary)$promotion$promote)

  all_covered <- lapply(manifest$expected, function(x) {
    ci09_attempt(
      manifest,
      x$cell_id,
      x$rep,
      x$target_id,
      "covered",
      n_eff = 150L
    )
  })
  passing_summary <- ci09_summarise(ci09_merge_attempts(manifest, all_covered))
  expect_false(ci09_promote(passing_summary)$promotion$promote)
  expect_match(ci09_promote(passing_summary)$promotion$reason, "full")
  extra_target <- passing_summary$targets
  extra_target$target_id <- "second_required_target"
  extra_target$coverage <- 0.93
  extra_target$lower <- 0.93
  multi_target_summary <- passing_summary
  multi_target_summary$targets <- rbind(passing_summary$targets, extra_target)
  expect_false(ci09_promote(multi_target_summary)$promotion$promote)
})

test_that("CI-09 promotion is exact-cell rather than pooled across cells", {
  manifest <- ci09_attempt_manifest(
    cell_ids = 1:2,
    rep_ids = 1:100,
    source_sha = "test-cells"
  )
  attempts <- lapply(manifest$expected, function(x) {
    ci09_attempt(
      manifest,
      x$cell_id,
      x$rep,
      x$target_id,
      "covered",
      n_eff = 150L
    )
  })
  ## Cell 1 has 94% coverage and fails its lower-band gate. Pooled across both
  ## cells it would appear to pass, which is precisely the forbidden shortcut.
  for (i in seq_len(6L)) {
    attempts[[i]] <- ci09_attempt(
      manifest,
      1L,
      i,
      "rho_1_2",
      "ci_failed",
      n_eff = 150L
    )
  }
  summary <- ci09_summarise(ci09_merge_attempts(manifest, attempts))
  expect_equal(nrow(summary$targets), 2L)
  expect_equal(summary$targets$coverage[summary$targets$cell_id == 1L], 0.94)
  pooled_coverage <- mean(summary$canonical$outcome == "covered")
  pooled_mcse <- stats::sd(as.numeric(summary$canonical$outcome == "covered")) /
    sqrt(nrow(summary$canonical))
  expect_gt(pooled_coverage - 2 * pooled_mcse, 0.94)
  expect_false(ci09_promote(summary)$promotion$promote)
})

test_that("CI-09 retry history preserves infrastructure provenance and rejects scientific reruns", {
  manifest <- ci09_attempt_manifest(
    cell_ids = 1L,
    rep_ids = 1L,
    source_sha = "test-retry"
  )
  infra <- ci09_attempt(
    manifest,
    1L,
    1L,
    "rho_1_2",
    "infrastructure_failure",
    n_eff = NA_integer_
  )
  retry <- ci09_attempt(
    manifest,
    1L,
    1L,
    "rho_1_2",
    "covered",
    n_eff = 150L,
    attempt_version = 2L
  )
  expect_silent(ci09_merge_attempts(manifest, list(infra, retry)))
  science <- ci09_attempt(
    manifest,
    1L,
    1L,
    "rho_1_2",
    "scientific_failure",
    n_eff = NA_integer_
  )
  expect_identical(science$base_fit, "failed")
  expect_error(
    ci09_attempt(
      manifest,
      1L,
      1L,
      "rho_1_2",
      "scientific_failure",
      n_eff = 150L,
      base_fit = "eligible"
    ),
    "base-fit state"
  )
  expect_error(
    ci09_attempt(
      manifest,
      1L,
      1L,
      "rho_1_2",
      "base_fit_failed",
      n_eff = NA_integer_,
      base_fit = "unknown"
    ),
    "base-fit state"
  )
  expect_error(
    ci09_attempt(
      manifest,
      1L,
      1L,
      "rho_1_2",
      "scientific_failure",
      n_eff = 150L
    ),
    "n_eff"
  )
  expect_error(
    ci09_merge_attempts(manifest, list(science, retry)),
    "scientific failure is terminal"
  )

  unknown <- retry
  unknown$outcome <- "unknown_outcome"
  unknown$attempt_version <- 1L
  expect_error(
    ci09_merge_attempts(manifest, list(unknown)),
    "deserialised outcome"
  )
  mismatched_base <- retry
  mismatched_base$outcome <- "base_fit_failed"
  mismatched_base$attempt_version <- 1L
  expect_error(
    ci09_merge_attempts(manifest, list(mismatched_base)),
    "base-fit state"
  )
})

test_that("remote orchestration writes immutable shards and freezes exact task grids", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  remote_root <- normalizePath(remote_root)
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  source(file.path(remote_root, "build-task-manifests.R"), local = TRUE)

  path <- tempfile("interval-shard-", fileext = ".rds")
  payload <- list(schema = "test", value = 1L)
  expect_silent(interval_atomic_save_rds(payload, path))
  expect_identical(readRDS(path), payload)
  expect_error(interval_atomic_save_rds(payload, path), "refusing to overwrite")

  grids <- lapply(
    c("PVT02", "CI09", "CI13", "CI14", "CI15", "CI10_COST"),
    interval_build_task_manifest
  )
  expect_identical(
    unname(vapply(grids, nrow, integer(1))),
    c(5000L, 30000L, 20000L, 10000L, 20000L, 18L)
  )
  expect_true(all(grids[[6L]]$rep == 3L))
  expect_identical(grids[[6L]]$cell_id, 1:18)
  expect_identical(
    grids[[6L]]$seed,
    c(
      1060724L, 2060727L, 3060730L, 4060733L, 5060736L, 6060739L,
      7060742L, 8060745L, 9060748L, 10060751L, 11060754L, 12060757L,
      13060760L, 14060763L, 15060766L, 16060769L, 17060772L, 18060775L
    )
  )
  expect_identical(
    unique(grids[[6L]]$scientific_source_sha),
    "328d8abc9125ce1e7edbcdcdcb1a41f043488431"
  )
})

test_that("remote launchers enforce frozen sources, sequential-wave limits, and parse cleanly", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  repo_root <- normalizePath(file.path(remote_root, "..", "..", ".."))
  clean_root <- tempfile("interval-clean-checkout-")
  on.exit(unlink(clean_root, recursive = TRUE, force = TRUE), add = TRUE)
  clone_status <- system2(
    "git",
    c("clone", "--quiet", "--no-checkout", repo_root, clean_root),
    stdout = FALSE,
    stderr = FALSE
  )
  expect_identical(clone_status, 0L)
  checkout_status <- system2(
    "git",
    c(
      "-C", clean_root, "checkout", "--quiet",
      "822024b1bd31a90a9dbe211ad09e1b26b2030ac8"
    ),
    stdout = FALSE,
    stderr = FALSE
  )
  expect_identical(checkout_status, 0L)
  expect_silent(interval_assert_frozen_source(
    "822024b1bd31a90a9dbe211ad09e1b26b2030ac8",
    c(
      "R",
      "dev/interval-calibration/ci09/ci09-kernels.R",
      "dev/interval-calibration/ci09/smoke.R"
    ),
    source_root = clean_root
  ))
  writeLines("dirty", file.path(clean_root, "dirty-untracked-file"))
  expect_error(
    interval_assert_clean_checkout(clean_root),
    "orchestration checkout is not clean"
  )
  expect_silent(parse(file.path(remote_root, "run-shard.R")))
  expect_silent(parse(file.path(remote_root, "aggregate-campaign.R")))
  expect_silent(parse(file.path(remote_root, "write-session-receipt.R")))
  wave <- paste(
    readLines(file.path(remote_root, "run-totoro-wave.sh"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(wave, "xargs -n 4 -P 96", fixed = TRUE)
  expect_match(wave, "--kill-after=60s 2h", fixed = TRUE)
  expect_match(wave, "OPENBLAS_NUM_THREADS=1", fixed = TRUE)
  expect_match(
    wave,
    "INTERVAL_DEPENDENCY_LIBRARY_ROOT",
    fixed = TRUE
  )
  expect_match(
    wave,
    "R_LIBS_USER=$INTERVAL_LIBRARY_ROOT:$INTERVAL_DEPENDENCY_LIBRARY_ROOT",
    fixed = TRUE
  )
  expect_match(wave, "validate-task-manifest.R", fixed = TRUE)
  expect_match(wave, "write-session-receipt.R", fixed = TRUE)
  expect_match(wave, "record-wave-timeouts.R", fixed = TRUE)
  expect_match(wave, "finalize-campaign.sh", fixed = TRUE)

  deploy <- paste(
    readLines(
      file.path(remote_root, "deploy-approved-envelope.sh"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(
    deploy,
    "/Users/z3437171/.ssh/cm-snakagaw@totoro.biology.ualberta.ca:22",
    fixed = TRUE
  )
  expect_match(
    deploy,
    "/Users/z3437171/.ssh/cm-snakagaw@fir.alliancecan.ca:22",
    fixed = TRUE
  )
  expect_match(deploy, "ssh -S \"$socket\" -O check", fixed = TRUE)
  expect_match(deploy, "PreferredAuthentications=none", fixed = TRUE)
  expect_match(deploy, "PubkeyAuthentication=no", fixed = TRUE)
  expect_match(deploy, "remote-payload-checksums.sha256", fixed = TRUE)
  expect_match(deploy, "mkdir -p '$base'", fixed = TRUE)
  expect_match(deploy, "test ! -e '$deploy'", fixed = TRUE)
  expect_match(deploy, "prepare-ci10-cost-array.sh", fixed = TRUE)
  expect_match(deploy, "totoro-launch.log", fixed = TRUE)
  expect_match(deploy, "totoro-sequence.log", fixed = TRUE)
  expect_match(deploy, "totoro-sequence-lock", fixed = TRUE)
  expect_match(deploy, "prepare-totoro-retry", fixed = TRUE)
  expect_match(deploy, "launch-totoro-retry", fixed = TRUE)
  expect_match(
    deploy,
    "/home/snakagaw/gllvmTMB-interval-calibration/2026-08-25-r2/deployment",
    fixed = TRUE
  )
  expect_false(grepl("n_sim=5000.*CI10", deploy))

  prepare_host <- paste(
    readLines(file.path(remote_root, "prepare-remote-host.sh"), warn = FALSE),
    collapse = "\n"
  )
  install_library <- paste(
    readLines(
      file.path(remote_root, "install-packet-library.sh"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(prepare_host, "totoro:totoro.biology.ualberta.ca", fixed = TRUE)
  expect_match(
    prepare_host,
    "fir:login[0-9]*.int.fir.alliancecan.ca",
    fixed = TRUE
  )
  expect_match(prepare_host, "git ls-remote", fixed = TRUE)
  expect_match(
    prepare_host,
    'orchestrators/$expected_sha',
    fixed = TRUE
  )
  expect_match(prepare_host, "--detach", fixed = TRUE)
  expect_match(prepare_host, "install-packet-library.sh", fixed = TRUE)
  expect_match(
    prepare_host,
    "module load StdEnv/2023 gcc/12.3 r/4.5.0",
    fixed = TRUE
  )
  expect_match(
    prepare_host,
    "/cvmfs/soft.computecanada.ca/custom/software/lmod/lmod/init/bash",
    fixed = TRUE
  )
  expect_match(
    prepare_host,
    "/home/snakagaw/R/lane_b_4.5",
    fixed = TRUE
  )
  expect_match(prepare_host, "required <- c(", fixed = TRUE)
  expect_match(
    prepare_host,
    "/home/snakagaw/R/x86_64-pc-linux-gnu-library/4.5",
    fixed = TRUE
  )
  expect_match(
    prepare_host,
    "dependency_libraries=${R_LIBS_USER-}",
    fixed = TRUE
  )
  expect_match(
    install_library,
    "dependency_libraries=${R_LIBS_USER-}",
    fixed = TRUE
  )
  expect_match(
    install_library,
    "campaign_libraries=$library_root:$dependency_libraries",
    fixed = TRUE
  )
  expect_match(deploy, "bash '$deploy/prepare-remote-host.sh'", fixed = TRUE)
  expect_match(
    deploy,
    ". /cvmfs/soft.computecanada.ca/custom/software/lmod/lmod/init/bash; module load StdEnv/2023 gcc/12.3 r/4.5.0",
    fixed = TRUE
  )
  expect_match(
    deploy,
    "fir_orchestrator='$fir_base/orchestrators/'",
    fixed = TRUE
  )
  expect_match(
    deploy,
    "fir_dependency_library=/home/snakagaw/R/lane_b_4.5",
    fixed = TRUE
  )
  expect_match(deploy, "fir_libraries=", fixed = TRUE)

  sequence <- paste(
    readLines(
      file.path(remote_root, "run-approved-totoro-sequence.sh"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(sequence, "for packet in PVT02 CI09 CI13 CI14 CI15", fixed = TRUE)
  expect_match(
    sequence,
    "INTERVAL_DEPENDENCY_LIBRARY_ROOT",
    fixed = TRUE
  )
  expect_match(sequence, "mkdir \"$lock\"", fixed = TRUE)
  expect_match(sequence, "validate-post-guard-receipt.R", fixed = TRUE)
  expect_match(sequence, "INTERVAL_CALIBRATION_TOTORO_SEQUENCE_FAILED_V1", fixed = TRUE)
  wave <- paste(
    readLines(file.path(remote_root, "run-totoro-wave.sh"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(wave, "import-post-guard-receipt.R", fixed = TRUE)
  expect_match(wave, "remaining-task-manifest.tsv", fixed = TRUE)
})

test_that("runtime dependency preflight fails closed with exact missing packages", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  available <- function(package, quietly = TRUE) package != "assertthat"
  expect_error(
    interval_assert_runtime_dependencies(available = available),
    "missing campaign runtime dependencies: assertthat",
    fixed = TRUE
  )
  expect_silent(interval_assert_runtime_dependencies(
    required = c("cli", "rlang"),
    available = function(package, quietly = TRUE) TRUE,
    version = function(package) "test-version"
  ))
})

test_that("runtime dependency preflight covers package and phylogenetic requirements", {
  remote_root <- testthat::test_path(
    "..",
    "..",
    "dev",
    "interval-calibration",
    "remote"
  )
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  expect_true(all(c("Matrix", "ape") %in% interval_runtime_packages))
  available <- function(package, quietly = TRUE) package != "ape"
  expect_error(
    interval_assert_runtime_dependencies(available = available),
    "missing campaign runtime dependencies: ape",
    fixed = TRUE
  )
})

test_that("post-guard receipts bind the environment and canonical identity policy", {
  remote_root <- testthat::test_path(
    "..",
    "..",
    "dev",
    "interval-calibration",
    "remote"
  )
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  source(file.path(remote_root, "build-task-manifests.R"), local = TRUE)
  expect_true(exists("interval_validate_post_guard_receipt", mode = "function"))
  if (!exists("interval_validate_post_guard_receipt", mode = "function")) {
    return(invisible())
  }
  manifest <- interval_build_task_manifest("PVT02")
  shard_path <- tempfile("post-guard-shard-", fileext = ".rds")
  on.exit(unlink(shard_path), add = TRUE)
  shard <- list(
    schema = "INTERVAL_CALIBRATION_CANONICAL_SHARD_V1",
    packet = "PVT02",
    cell_id = 1L,
    rep = 50001L,
    seed = 800050001L,
    scientific_provenance = list(
      scientific_source_sha = interval_approved_source("PVT02")
    ),
    attempt = data.frame(endpoint_reason = "fit_failed"),
    runner_provenance = list()
  )
  saveRDS(shard, shard_path, version = 3L)
  receipt <- list(
    schema = "INTERVAL_CALIBRATION_POST_GUARD_RECEIPT_V2",
    packet = "PVT02",
    cell_id = 1L,
    rep = 50001L,
    seed = 800050001L,
    scientific_source_sha = interval_approved_source("PVT02"),
    environment_valid = TRUE,
    runtime_dependencies = stats::setNames(
      rep("test-version", length(interval_runtime_packages)),
      interval_runtime_packages
    ),
    scientific_outcome = "fit_failed",
    canonical_action = "import",
    shard_path = shard_path,
    shard_sha256 = interval_sha256_file(shard_path)
  )
  expect_silent(interval_validate_post_guard_receipt(receipt, manifest))

  mirrored_receipt <- receipt
  mirrored_receipt$shard_path <- "/remote/immutable/post-guard-shard.rds"
  expect_error(
    interval_validate_post_guard_receipt(mirrored_receipt, manifest),
    "readable SHA-256-bound shard",
    fixed = TRUE
  )
  expect_silent(
    interval_validate_post_guard_receipt(
      mirrored_receipt,
      manifest,
      shard_path_override = shard_path
    )
  )
  bad_hash <- receipt
  bad_hash$shard_sha256 <- paste(rep("0", 64L), collapse = "")
  expect_error(
    interval_validate_post_guard_receipt(bad_hash, manifest),
    "post-guard shard SHA-256 does not match",
    fixed = TRUE
  )
  expect_true(exists("interval_post_guard_import_plan", mode = "function"))
  if (exists("interval_post_guard_import_plan", mode = "function")) {
    plan <- interval_post_guard_import_plan(receipt, manifest)
    expect_identical(nrow(plan$remaining_tasks), 4999L)
    expect_identical(plan$imported_task$rep, 50001L)
    expect_false(any(plan$remaining_tasks$rep == 50001L))
  }
  receipt$canonical_action <- "preflight_only"
  expect_error(
    interval_validate_post_guard_receipt(receipt, manifest),
    "campaign identity must be imported",
    fixed = TRUE
  )
  receipt$rep <- 49999L
  receipt$seed <- 800049999L
  shard$rep <- receipt$rep
  shard$seed <- receipt$seed
  saveRDS(shard, shard_path, version = 3L)
  receipt$shard_sha256 <- interval_sha256_file(shard_path)
  expect_silent(interval_validate_post_guard_receipt(receipt, manifest))
  if (exists("interval_post_guard_import_plan", mode = "function")) {
    plan <- interval_post_guard_import_plan(receipt, manifest)
    expect_identical(nrow(plan$remaining_tasks), 5000L)
    expect_identical(nrow(plan$imported_task), 0L)
  }
})

test_that("post-guard import replaces the campaign duplicate before adjudication", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  expect_true(exists("interval_apply_post_guard_import", mode = "function"))
  if (!exists("interval_apply_post_guard_import", mode = "function")) {
    return(invisible())
  }
  canonical <- data.frame(
    packet = "PVT02",
    cell_id = 1L,
    rep = 50001L,
    seed = 800050001L,
    origin = "campaign",
    stringsAsFactors = FALSE
  )
  imported <- canonical
  imported$origin <- "post_guard"
  receipt <- list(
    packet = "PVT02",
    cell_id = 1L,
    rep = 50001L,
    seed = 800050001L,
    canonical_action = "import"
  )
  out <- interval_apply_post_guard_import(canonical, receipt, imported)
  expect_identical(nrow(out), 1L)
  expect_identical(out$origin, "post_guard")
})

test_that("post-guard import CLI copies the signed shard and removes its task", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  remote_root <- normalizePath(remote_root)
  repo_root <- normalizePath(file.path(remote_root, "..", "..", ".."))
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  source(file.path(remote_root, "build-task-manifests.R"), local = TRUE)
  scratch <- tempfile("post-guard-import-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  guard_root <- file.path(scratch, "guard")
  out_root <- file.path(scratch, "campaign")
  dir.create(file.path(guard_root, "canonical"), recursive = TRUE)
  dir.create(file.path(guard_root, "operations"))
  dir.create(file.path(out_root, "canonical"), recursive = TRUE)
  dir.create(file.path(out_root, "operations"))
  manifest <- interval_build_task_manifest("PVT02")[1L, , drop = FALSE]
  manifest_path <- file.path(scratch, "manifest.tsv")
  utils::write.table(
    manifest,
    manifest_path,
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )
  shard_path <- file.path(
    guard_root,
    "canonical",
    "pvt02-c01-r50001.rds"
  )
  shard <- list(
    schema = "INTERVAL_CALIBRATION_CANONICAL_SHARD_V1",
    packet = "PVT02",
    cell_id = 1L,
    rep = 50001L,
    seed = 800050001L,
    attempt_version = 1L,
    scientific_provenance = list(
      scientific_source_sha = interval_approved_source("PVT02")
    ),
    attempt = data.frame(endpoint_reason = "fit_failed"),
    runner_provenance = list(runtime_dependencies = character())
  )
  saveRDS(shard, shard_path, version = 3L)
  for (state in c("started", "completed")) {
    saveRDS(
      list(state = state),
      file.path(
        guard_root,
        "operations",
        sprintf("pvt02-c01-r50001-a01-%s.rds", state)
      ),
      version = 3L
    )
  }
  receipt <- list(
    schema = "INTERVAL_CALIBRATION_POST_GUARD_RECEIPT_V2",
    packet = "PVT02",
    cell_id = 1L,
    rep = 50001L,
    seed = 800050001L,
    scientific_source_sha = interval_approved_source("PVT02"),
    environment_valid = TRUE,
    runtime_dependencies = stats::setNames(
      rep("test", length(interval_runtime_packages)),
      interval_runtime_packages
    ),
    scientific_outcome = "fit_failed",
    canonical_action = "import",
    shard_path = shard_path,
    shard_sha256 = interval_sha256_file(shard_path)
  )
  receipt_path <- file.path(scratch, "receipt.rds")
  remaining_path <- file.path(out_root, "remaining.tsv")
  saveRDS(receipt, receipt_path, version = 3L)
  command <- c(
    "--vanilla",
    file.path(remote_root, "import-post-guard-receipt.R"),
    "PVT02",
    manifest_path,
    receipt_path,
    out_root,
    remaining_path
  )
  output <- withr::with_dir(
    repo_root,
    system2(
      file.path(R.home("bin"), "Rscript"),
      shQuote(command),
      stdout = TRUE,
      stderr = TRUE
    )
  )
  expect_null(attr(output, "status"))
  expect_match(output, "INTERVAL_POST_GUARD_IMPORT_READY", fixed = TRUE)
  expect_true(file.exists(file.path(out_root, "canonical", basename(shard_path))))
  expect_true(file.exists(file.path(out_root, "import", "post-guard-import.rds")))
  remaining <- utils::read.delim(remaining_path, stringsAsFactors = FALSE)
  expect_identical(nrow(remaining), 0L)
})

test_that("cross-root reconciliation retains attempts and chooses the first valid canonical row", {
  remote_root <- testthat::test_path(
    "..",
    "..",
    "dev",
    "interval-calibration",
    "remote"
  )
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  expect_true(exists(
    "interval_reconcile_cross_root_attempts",
    mode = "function"
  ))
  if (!exists("interval_reconcile_cross_root_attempts", mode = "function")) {
    return(invisible())
  }
  attempts <- data.frame(
    packet = rep("PVT02", 3L),
    cell_id = rep(1L, 3L),
    rep = rep(50001L, 3L),
    seed = rep(800050001L, 3L),
    root_class = c("invalid", "post_guard", "campaign"),
    environment_valid = c(FALSE, TRUE, TRUE),
    completed_at = as.POSIXct(
      c(
        "2026-08-25 16:00:00",
        "2026-08-25 16:30:00",
        "2026-08-25 16:45:00"
      ),
      tz = "UTC"
    ),
    stringsAsFactors = FALSE
  )
  reconciled <- interval_reconcile_cross_root_attempts(attempts)
  expect_identical(nrow(reconciled$operational), 3L)
  expect_identical(nrow(reconciled$canonical), 1L)
  expect_identical(reconciled$canonical$root_class, "post_guard")
  expect_identical(
    reconciled$operational$disposition,
    c("infrastructure_excluded", "canonical", "duplicate_excluded")
  )
})

test_that("terminal evidence retains every attempt and exact target disposition", {
  artifact_root <- testthat::test_path(
    "..", "..", "docs", "dev-log", "artifacts", "interval-calibration"
  )
  attempts <- utils::read.csv(
    gzfile(file.path(
      artifact_root,
      "2026-08-25-all-attempt-ledger.csv.gz"
    )),
    stringsAsFactors = FALSE
  )
  expect_identical(nrow(attempts), 150019L)
  expect_identical(sum(attempts$canonical), 55018L)
  expect_identical(
    sum(attempts$disposition == "infrastructure_excluded"),
    85000L
  )
  expect_identical(
    sum(attempts$disposition == "duplicate_excluded"),
    1L
  )
  expect_identical(
    sum(attempts$disposition == "blocked_provenance"),
    10000L
  )
  duplicate_identity <- attempts$packet == "PVT02" &
    attempts$cell_id == 1L &
    attempts$rep == 50001L &
    attempts$seed == 800050001L
  expect_identical(sum(duplicate_identity), 3L)
  expect_identical(sum(duplicate_identity & attempts$canonical), 1L)

  targets <- utils::read.csv(
    file.path(artifact_root, "2026-08-25-target-recomputation.csv"),
    stringsAsFactors = FALSE
  )
  expect_identical(nrow(targets), 18L)
  expect_true(all(targets$target_pass[targets$packet == "PVT02"]))
  expect_false(any(targets$target_pass[targets$packet == "CI09"]))
  expect_identical(
    sum(targets$target_pass[targets$packet == "CI13"]),
    8L
  )
})

test_that("task-manifest validator refuses a truncated or altered campaign", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  source(file.path(remote_root, "shard-io.R"), local = TRUE)
  source(file.path(remote_root, "build-task-manifests.R"), local = TRUE)
  source(file.path(remote_root, "validate-task-manifest.R"), local = TRUE)
  path <- tempfile("ci09-task-manifest-", fileext = ".tsv")
  full <- interval_build_task_manifest("CI09")
  utils::write.table(
    full[-nrow(full), ],
    path,
    sep = "\t",
    row.names = FALSE,
    quote = FALSE
  )
  expect_error(
    interval_validate_task_manifest("CI09", path),
    "complete frozen"
  )
})

test_that("production receipts bind package source, checksums, and operation pairs", {
  remote_root <- testthat::test_path(
    "..", "..", "dev", "interval-calibration", "remote"
  )
  io <- paste(
    readLines(file.path(remote_root, "shard-io.R"), warn = FALSE),
    collapse = "\n"
  )
  aggregate <- paste(
    readLines(file.path(remote_root, "aggregate-campaign.R"), warn = FALSE),
    collapse = "\n"
  )
  session <- paste(
    readLines(file.path(remote_root, "write-session-receipt.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(io, ".interval-scientific-source-sha", fixed = TRUE)
  expect_match(io, "canonical-checksums.sha256", fixed = TRUE)
  expect_match(aggregate, "started", fixed = TRUE)
  expect_match(aggregate, "completed", fixed = TRUE)
  expect_match(aggregate, "interval_validate_checksum_manifest", fixed = TRUE)
  expect_match(session, "installed_package", fixed = TRUE)
  expect_match(session, "thread_environment", fixed = TRUE)
  expect_match(session, "output_root", fixed = TRUE)
})
