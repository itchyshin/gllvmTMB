source_power_pilot_manifest <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- list(
    root = ".",
    package = file.path("..", ".."),
    workspace = workspace
  )
  roots <- unique(unlist(candidates, use.names = FALSE))
  roots <- roots[nzchar(roots)]
  roots <- roots[dir.exists(roots)]
  files <- lapply(roots, function(root) {
    file.path(
      root,
      "dev",
      c(
        "m3-grid.R",
        "m3-pilot-launch.R"
      )
    )
  })
  hit <- files[vapply(
    files,
    function(paths) all(file.exists(paths)),
    logical(1)
  )]
  testthat::skip_if(
    !length(hit),
    "dev power-pilot helpers are unavailable in this source-tarball context"
  )
  paths <- hit[[1]]
  assign(
    "power_pilot_root",
    normalizePath(dirname(dirname(paths[1])), mustWork = TRUE),
    envir = parent.frame()
  )
  source(paths[1], local = parent.frame())
  source(paths[2], local = parent.frame())
}

two_chunk_manifest <- function(results_dir, seed_base = 158L) {
  env <- parent.frame()
  pilot_grid <- get("pilot_grid", envir = env)
  pilot_build_manifest <- get("pilot_build_manifest", envir = env)
  pilot_manifest_seed_range <- get("pilot_manifest_seed_range", envir = env)
  pilot_assert_manifest <- get("pilot_assert_manifest", envir = env)
  pilot_chunk_path <- get("pilot_chunk_path", envir = env)
  PILOT_CHUNK_DIR <- get("PILOT_CHUNK_DIR", envir = env)

  cid <- pilot_grid()$cell_id[1]
  first <- pilot_build_manifest(
    cell_ids = cid,
    n_sim_step = 2L,
    n_sim_cap = 10L,
    seed_base = seed_base,
    results_dir = results_dir,
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L,
    output_mode = "chunk"
  )
  second <- first
  second$n_before <- 2L
  second$rep_start <- 3L
  second$rep_end <- 4L
  second$batch_seed_base <- as.integer(second$batch_seed_base + 100L)
  seed_range <- pilot_manifest_seed_range(
    second$batch_seed_base,
    second$harness_family,
    second$d,
    second$n_reps_planned
  )
  second$rep_seed_min <- as.integer(seed_range[["min"]])
  second$rep_seed_max <- as.integer(seed_range[["max"]])
  second$chunk_id <- paste0(first$chunk_id, "-next")
  second$chunk_file <- file.path(
    PILOT_CHUNK_DIR,
    second$campaign_id,
    second$cell_id,
    paste0(second$chunk_id, ".rds")
  )
  second$chunk_path <- pilot_chunk_path(
    results_dir,
    second$campaign_id,
    second$cell_id,
    second$chunk_id
  )
  second$result_file <- second$chunk_file
  second$result_path <- second$chunk_path
  out <- rbind(first, second)
  pilot_assert_manifest(out, require_unique_result_path = FALSE)
  out
}

write_fake_chunk <- function(row, reps, duplicate = FALSE) {
  chunk <- expand.grid(
    rep = as.integer(reps),
    trait_id = seq_len(2L),
    KEEP.OUT.ATTRS = FALSE
  )
  chunk$target <- "Sigma_unit_diag"
  chunk$estimate <- seq_len(nrow(chunk))
  chunk$pilot_campaign_id <- row$campaign_id
  chunk$pilot_chunk_id <- row$chunk_id
  chunk$pilot_cell_id <- row$cell_id
  chunk$pilot_rep_start <- as.integer(row$rep_start)
  chunk$pilot_rep_end <- as.integer(row$rep_end)
  if (isTRUE(duplicate)) {
    chunk <- rbind(chunk, chunk[1L, , drop = FALSE])
  }
  dir.create(dirname(row$chunk_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(chunk, row$chunk_path)
  invisible(row$chunk_path)
}

test_that("power pilot manifest records disjoint planned chunks", {
  source_power_pilot_manifest()

  results_dir <- tempfile("pilot-manifest-")
  dir.create(results_dir)
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  cells <- utils::head(pilot_grid()$cell_id, 4L)
  manifest <- pilot_build_manifest(
    cell_ids = cells,
    n_sim_step = 25L,
    n_sim_cap = 200L,
    seed_base = 144L,
    results_dir = results_dir,
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L,
    source_sha = "abc123",
    workflow_run_id = "run-1",
    workflow_run_number = "144"
  )

  expect_equal(nrow(manifest), 4L)
  expect_equal(manifest$n_reps_planned, rep(25L, 4L))
  expect_equal(manifest$action, rep("advance", 4L))
  expect_equal(manifest$source_sha, rep("abc123", 4L))
  expect_equal(manifest$workflow_run_id, rep("run-1", 4L))
  expect_equal(manifest$workflow_run_number, rep("144", 4L))
  expect_true("lambda_scale" %in% names(manifest))
  expect_true(all(is.finite(manifest$lambda_scale)))
  expect_equal(manifest$output_mode, rep("accumulate", 4L))
  expect_equal(manifest$result_file, manifest$store_file)
  expect_equal(manifest$result_path, manifest$store_path)
  expect_true(all(nzchar(manifest$chunk_path)))
  expect_equal(basename(manifest$chunk_path), paste0(manifest$chunk_id, ".rds"))
  expect_equal(any(duplicated(manifest$result_path)), FALSE)
  expect_equal(any(duplicated(manifest$chunk_path)), FALSE)
  expect_equal(any(duplicated(manifest$chunk_id)), FALSE)
  expect_equal(
    any(manifest$rep_seed_min[-1L] <= manifest$rep_seed_max[-4L]),
    FALSE
  )
  expect_equal(pilot_assert_manifest(manifest), TRUE)

  path <- pilot_write_manifest(manifest, results_dir, shard = 1L)
  expect_true(file.exists(path))
  roundtrip <- pilot_read_manifests(results_dir)
  expect_equal(nrow(roundtrip), 4L)
  expect_equal(roundtrip$cell_id, manifest$cell_id)
  expect_equal(pilot_assert_manifest(roundtrip), TRUE)
})

test_that("power pilot chunk manifests point at immutable chunk files", {
  source_power_pilot_manifest()

  manifest <- pilot_build_manifest(
    cell_ids = utils::head(pilot_grid()$cell_id, 2L),
    n_sim_step = 2L,
    n_sim_cap = 10L,
    seed_base = 148L,
    results_dir = tempfile("pilot-manifest-chunk-"),
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L,
    output_mode = "chunk"
  )

  expect_equal(manifest$output_mode, rep("chunk", 2L))
  expect_equal(manifest$result_file, manifest$chunk_file)
  expect_equal(manifest$result_path, manifest$chunk_path)
  expect_false(any(manifest$result_path == manifest$store_path))
  expect_match(manifest$chunk_file[1], "^_chunks/power-pilot-seed-148/")
  expect_equal(
    pilot_assert_manifest(manifest, require_unique_result_path = FALSE),
    TRUE
  )

  bad <- manifest
  bad$chunk_path[2L] <- bad$chunk_path[1L]
  bad$result_path[2L] <- bad$result_path[1L]
  err <- tryCatch(
    {
      pilot_assert_manifest(bad, require_unique_result_path = FALSE)
      NULL
    },
    error = function(e) e
  )
  expect_equal(inherits(err, "error"), TRUE)
  expect_match(conditionMessage(err), "Duplicate pilot chunk paths")
})

test_that("power pilot audit-mini manifest names representative cells", {
  source_power_pilot_manifest()

  mini <- pilot_audit_mini_grid()

  expect_equal(nrow(mini), 4L)
  expect_equal(
    mini$family_label,
    c("gaussian", "nbinom2", "binomial_probit", "ordinal_probit")
  )
  expect_equal(mini$d, rep(1L, 4L))
  expect_equal(mini$n_units, rep(50L, 4L))
  expect_equal(mini$signal, rep(0.2, 4L))
  expect_equal(
    mini$evidence_family,
    c("gaussian", "nbinom2", "binomial_logit_harness", "ordinal_probit")
  )
  expect_equal(pilot_audit_mini_cell_ids(), mini$cell_id)

  manifest <- pilot_build_audit_mini_manifest(
    seed_base = 150L,
    results_dir = tempfile("pilot-audit-mini-")
  )
  expect_equal(nrow(manifest), 4L)
  expect_equal(manifest$cell_id, mini$cell_id)
  expect_equal(manifest$output_mode, rep("chunk", 4L))
  expect_equal(manifest$n_reps_planned, rep(2L, 4L))
  expect_equal(manifest$n_boot, rep(0L, 4L))
  expect_equal(
    pilot_assert_manifest(manifest, require_unique_result_path = FALSE),
    TRUE
  )
})

test_that("power pilot manifest validator catches overlapping replicate windows", {
  source_power_pilot_manifest()

  manifest <- pilot_build_manifest(
    cell_ids = utils::head(pilot_grid()$cell_id, 2L),
    n_sim_step = 2L,
    n_sim_cap = 10L,
    seed_base = 151L,
    results_dir = tempfile("pilot-manifest-window-"),
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L,
    output_mode = "chunk"
  )
  bad <- manifest
  bad$cell_id[2L] <- bad$cell_id[1L]
  bad$rep_start[2L] <- bad$rep_start[1L]
  bad$rep_end[2L] <- bad$rep_end[1L]
  err <- tryCatch(
    {
      pilot_assert_manifest(bad, require_unique_result_path = FALSE)
      NULL
    },
    error = function(e) e
  )
  expect_equal(inherits(err, "error"), TRUE)
  expect_match(conditionMessage(err), "Overlapping pilot replicate windows")
})

test_that("power pilot chunk output audit requires planned chunk files", {
  source_power_pilot_manifest()

  manifest <- pilot_build_manifest(
    cell_ids = utils::head(pilot_grid()$cell_id, 2L),
    n_sim_step = 2L,
    n_sim_cap = 10L,
    seed_base = 152L,
    results_dir = tempfile("pilot-chunk-audit-"),
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L,
    output_mode = "chunk"
  )
  for (path in manifest$chunk_path) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(data.frame(rep = seq_len(2L)), path)
  }
  on.exit(
    unlink(
      dirname(dirname(dirname(manifest$chunk_path[1L]))),
      recursive = TRUE,
      force = TRUE
    ),
    add = TRUE
  )

  audit <- pilot_assert_chunk_outputs(manifest)
  expect_equal(nrow(audit), 2L)
  expect_true(all(audit$exists))
  expect_true(all(audit$size_bytes > 0))

  unlink(manifest$chunk_path[2L])
  err <- tryCatch(
    {
      pilot_assert_chunk_outputs(manifest)
      NULL
    },
    error = function(e) e
  )
  expect_equal(inherits(err, "error"), TRUE)
  expect_match(conditionMessage(err), "Missing pilot chunk output")

  file.create(manifest$chunk_path[2L])
  err <- tryCatch(
    {
      pilot_assert_chunk_outputs(manifest)
      NULL
    },
    error = function(e) e
  )
  expect_equal(inherits(err, "error"), TRUE)
  expect_match(conditionMessage(err), "Empty pilot chunk output")
})

test_that("power pilot chunk runner writes immutable chunk files", {
  source_power_pilot_manifest()

  results_dir <- tempfile("pilot-chunk-runner-")
  dir.create(results_dir)
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  cid <- pilot_grid()$cell_id[1]
  prior <- data.frame(rep = 1:3, rep_seed = 1001:1003)
  saveRDS(prior, file.path(results_dir, paste0(cid, ".rds")))

  manifest <- pilot_build_manifest(
    cell_ids = cid,
    n_sim_step = 2L,
    n_sim_cap = 10L,
    seed_base = 155L,
    results_dir = results_dir,
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L,
    output_mode = "chunk"
  )
  expect_equal(manifest$n_before, 3L)
  expect_equal(manifest$rep_start, 4L)
  expect_equal(manifest$rep_end, 5L)

  calls <- list()
  fake_runner <- function(
    family,
    d,
    n_reps,
    seed_base,
    n_units,
    n_traits,
    lambda_scale,
    targets,
    n_boot,
    ci_level,
    verbose
  ) {
    calls[[length(calls) + 1L]] <<- list(
      family = family,
      d = d,
      n_reps = n_reps,
      seed_base = seed_base,
      n_units = n_units,
      n_traits = n_traits,
      lambda_scale = lambda_scale,
      targets = targets,
      n_boot = n_boot,
      ci_level = ci_level,
      verbose = verbose
    )
    data.frame(
      rep = seq_len(n_reps),
      rep_seed = seed_base + seq_len(n_reps),
      ok = TRUE
    )
  }

  report <- pilot_run_chunk_manifest(
    manifest,
    runner = fake_runner,
    verbose = TRUE
  )
  expect_equal(nrow(report), 1L)
  expect_equal(report$status, "written")
  expect_equal(report$n_reps, 2L)
  expect_true(file.exists(manifest$chunk_path))
  expect_true(report$size_bytes > 0)
  audit <- pilot_assert_chunk_outputs(manifest)
  expect_equal(nrow(audit), 1L)
  expect_true(audit$exists)

  chunk <- readRDS(manifest$chunk_path)
  expect_equal(chunk$rep, 4:5)
  expect_equal(unique(chunk$pilot_campaign_id), manifest$campaign_id)
  expect_equal(unique(chunk$pilot_chunk_id), manifest$chunk_id)
  expect_equal(unique(chunk$pilot_cell_id), manifest$cell_id)
  expect_equal(unique(chunk$pilot_rep_start), 4L)
  expect_equal(unique(chunk$pilot_rep_end), 5L)

  expect_equal(length(calls), 1L)
  expect_equal(calls[[1]]$family, manifest$harness_family)
  expect_equal(calls[[1]]$n_reps, manifest$n_reps_planned)
  expect_equal(calls[[1]]$seed_base, manifest$batch_seed_base)
  expect_equal(calls[[1]]$n_units, manifest$n_units)
  expect_equal(calls[[1]]$lambda_scale, manifest$lambda_scale)
  expect_equal(calls[[1]]$targets, "Sigma_unit_diag")
  expect_equal(calls[[1]]$n_boot, 0L)
})

test_that("power pilot chunk runner rejects accumulated manifests", {
  source_power_pilot_manifest()

  manifest <- pilot_build_manifest(
    cell_ids = pilot_grid()$cell_id[1],
    n_sim_step = 2L,
    n_sim_cap = 10L,
    seed_base = 156L,
    results_dir = tempfile("pilot-chunk-runner-bad-"),
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L,
    output_mode = "accumulate"
  )
  err <- tryCatch(
    {
      pilot_run_chunk_manifest(manifest, runner = function(...) data.frame())
      NULL
    },
    error = function(e) e
  )
  expect_equal(inherits(err, "error"), TRUE)
  expect_match(conditionMessage(err), "requires output_mode = 'chunk'")
})

test_that("power pilot chunk aggregator writes per-cell aggregate files", {
  source_power_pilot_manifest()

  results_dir <- tempfile("pilot-chunk-aggregate-")
  dir.create(results_dir)
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  manifest <- two_chunk_manifest(results_dir, seed_base = 158L)
  write_fake_chunk(manifest[1L, , drop = FALSE], reps = 1:2)
  write_fake_chunk(manifest[2L, , drop = FALSE], reps = 3:4)

  aggregate_dir <- file.path(results_dir, "aggregate")
  aggregate <- pilot_aggregate_chunk_outputs(
    manifest,
    aggregate_dir = aggregate_dir,
    write = TRUE
  )

  expect_equal(nrow(aggregate$report), 1L)
  expect_equal(aggregate$report$n_chunks, 2L)
  expect_equal(aggregate$report$n_rows, 8L)
  expect_equal(aggregate$report$n_reps, 4L)
  expect_equal(aggregate$report$rep_min, 1L)
  expect_equal(aggregate$report$rep_max, 4L)
  expect_true(file.exists(aggregate$report$aggregate_path))
  expect_true(aggregate$report$size_bytes > 0)

  combined <- readRDS(aggregate$report$aggregate_path)
  expect_equal(nrow(combined), 8L)
  expect_equal(sort(unique(combined$rep)), 1:4)
  expect_equal(unique(combined$pilot_cell_id), manifest$cell_id[1L])
  expect_equal(
    sort(unique(combined$pilot_chunk_id)),
    sort(manifest$chunk_id)
  )
  expect_equal(nrow(aggregate$cells[[manifest$cell_id[1L]]]), 8L)
})

test_that("power pilot chunk aggregator validates chunk content windows", {
  source_power_pilot_manifest()

  results_dir <- tempfile("pilot-chunk-window-")
  dir.create(results_dir)
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  manifest <- two_chunk_manifest(results_dir, seed_base = 159L)
  write_fake_chunk(manifest[1L, , drop = FALSE], reps = 2:3)
  write_fake_chunk(manifest[2L, , drop = FALSE], reps = 3:4)

  err <- tryCatch(
    {
      pilot_aggregate_chunk_outputs(manifest)
      NULL
    },
    error = function(e) e
  )
  expect_equal(inherits(err, "error"), TRUE)
  expect_match(conditionMessage(err), "do not match manifest replicate window")
})

test_that("power pilot chunk aggregator rejects duplicate aggregate rows", {
  source_power_pilot_manifest()

  results_dir <- tempfile("pilot-chunk-duplicates-")
  dir.create(results_dir)
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  manifest <- two_chunk_manifest(results_dir, seed_base = 160L)
  write_fake_chunk(manifest[1L, , drop = FALSE], reps = 1:2, duplicate = TRUE)
  write_fake_chunk(manifest[2L, , drop = FALSE], reps = 3:4)

  err <- tryCatch(
    {
      pilot_aggregate_chunk_outputs(manifest)
      NULL
    },
    error = function(e) e
  )
  expect_equal(inherits(err, "error"), TRUE)
  expect_match(conditionMessage(err), "Duplicate pilot chunk aggregate rows")
})

test_that("power pilot manifest seed audit covers the full 48-cell grid", {
  source_power_pilot_manifest()

  manifest <- pilot_build_manifest(
    n_sim_step = 200L,
    n_sim_cap = 2000L,
    seed_base = 144L,
    results_dir = tempfile("pilot-manifest-full-"),
    n_boot = 0L,
    shard = 1L,
    n_shards = 1L,
    source_sha = "abc123"
  )

  expect_equal(nrow(manifest), 48L)
  expect_equal(any(duplicated(manifest$result_path)), FALSE)
  expect_equal(any(duplicated(manifest$chunk_id)), FALSE)
  expect_equal(pilot_assert_manifest(manifest), TRUE)
})

test_that("power pilot manifest validator catches duplicate paths", {
  source_power_pilot_manifest()

  manifest <- pilot_build_manifest(
    cell_ids = utils::head(pilot_grid()$cell_id, 2L),
    n_sim_step = 2L,
    n_sim_cap = 10L,
    seed_base = 145L,
    results_dir = tempfile("pilot-manifest-"),
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L
  )
  manifest$result_path[2L] <- manifest$result_path[1L]
  err <- tryCatch(
    {
      pilot_assert_manifest(manifest)
      NULL
    },
    error = function(e) e
  )
  expect_equal(inherits(err, "error"), TRUE)
  expect_match(conditionMessage(err), "Duplicate pilot output paths")
})

test_that("power pilot manifest validator catches overlapping seed ranges", {
  source_power_pilot_manifest()

  manifest <- pilot_build_manifest(
    cell_ids = utils::head(pilot_grid()$cell_id, 2L),
    n_sim_step = 2L,
    n_sim_cap = 10L,
    seed_base = 146L,
    results_dir = tempfile("pilot-manifest-"),
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L
  )
  manifest$rep_seed_min[2L] <- manifest$rep_seed_min[1L]
  manifest$rep_seed_max[2L] <- manifest$rep_seed_max[1L]
  err <- tryCatch(
    {
      pilot_assert_manifest(manifest)
      NULL
    },
    error = function(e) e
  )
  expect_equal(inherits(err, "error"), TRUE)
  expect_match(conditionMessage(err), "Overlapping pilot seed ranges")
})

test_that("power pilot preflight writes a chunk manifest without fits", {
  source_power_pilot_manifest()
  testthat::skip_if_not(
    file.exists(file.path(power_pilot_root, "dev", "power-pilot-run.R"))
  )

  results_dir <- tempfile("pilot-preflight-")
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  old_wd <- setwd(power_pilot_root)
  on.exit(setwd(old_wd), add = TRUE)

  rscript <- file.path(R.home("bin"), "Rscript")
  out <- system2(
    rscript,
    c(
      "--vanilla",
      file.path("dev", "power-pilot-run.R"),
      "--mode=preflight",
      "--shard=1",
      "--n-shards=48",
      "--n-sim-step=2",
      "--n-sim-cap=10",
      "--seed-base=149",
      paste0("--results-dir=", results_dir),
      "--n-boot=0",
      "--output-mode=chunk"
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_match(paste(out, collapse = "\n"), "preflight shard 1/48")

  manifest_path <- file.path(results_dir, "_manifests", "shard-1.csv")
  expect_true(file.exists(manifest_path))
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
  expect_equal(nrow(manifest), 1L)
  expect_equal(manifest$output_mode, "chunk")
  expect_equal(manifest$result_path, manifest$chunk_path)
  expect_equal(
    length(list.files(results_dir, pattern = "[.]rds$", full.names = TRUE)),
    0L
  )
})

test_that("power pilot audit-mini CLI writes a manifest without fits", {
  source_power_pilot_manifest()
  testthat::skip_if_not(
    file.exists(file.path(power_pilot_root, "dev", "power-pilot-run.R"))
  )

  results_dir <- tempfile("pilot-audit-mini-cli-")
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  old_wd <- setwd(power_pilot_root)
  on.exit(setwd(old_wd), add = TRUE)

  rscript <- file.path(R.home("bin"), "Rscript")
  out <- system2(
    rscript,
    c(
      "--vanilla",
      file.path("dev", "power-pilot-run.R"),
      "--mode=audit-mini",
      "--seed-base=150",
      paste0("--results-dir=", results_dir)
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  out <- paste(out, collapse = "\n")
  expect_match(out, "audit_mini_rows=4")
  expect_match(out, "audit_mini_active_chunks=4")
  expect_match(out, "audit-mini manifest: wrote 4 row")

  manifest_path <- file.path(results_dir, "_manifests", "shard-1.csv")
  expect_true(file.exists(manifest_path))
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE)
  expect_equal(nrow(manifest), 4L)
  expect_equal(manifest$output_mode, rep("chunk", 4L))
  expect_equal(manifest$n_boot, rep(0L, 4L))
  expect_equal(
    manifest$family_label,
    c("gaussian", "nbinom2", "binomial_probit", "ordinal_probit")
  )
  expect_equal(
    length(list.files(results_dir, pattern = "[.]rds$", full.names = TRUE)),
    0L
  )
})

test_that("power pilot chunk-audit CLI validates prewritten chunk outputs", {
  source_power_pilot_manifest()
  testthat::skip_if_not(
    file.exists(file.path(power_pilot_root, "dev", "power-pilot-run.R"))
  )

  results_dir <- tempfile("pilot-chunk-audit-cli-")
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  manifest <- pilot_build_manifest(
    cell_ids = utils::head(pilot_grid()$cell_id, 2L),
    n_sim_step = 2L,
    n_sim_cap = 10L,
    seed_base = 153L,
    results_dir = results_dir,
    n_boot = 0L,
    shard = 1L,
    n_shards = 48L,
    output_mode = "chunk"
  )
  pilot_write_manifest(manifest, results_dir, shard = 1L)
  for (path in manifest$chunk_path) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    saveRDS(data.frame(rep = seq_len(2L)), path)
  }

  old_wd <- setwd(power_pilot_root)
  on.exit(setwd(old_wd), add = TRUE)

  rscript <- file.path(R.home("bin"), "Rscript")
  out <- suppressWarnings(
    system2(
      rscript,
      c(
        "--vanilla",
        file.path("dev", "power-pilot-run.R"),
        "--mode=chunk-audit",
        paste0("--results-dir=", results_dir)
      ),
      stdout = TRUE,
      stderr = TRUE
    )
  )
  out <- paste(out, collapse = "\n")
  expect_match(out, "chunk_outputs_ok=true")
  expect_match(out, "chunk_output_rows=2")
  expect_match(out, "chunk audit: validated 2 planned chunk output")
})

test_that("power pilot chunk-audit CLI rejects missing manifests", {
  source_power_pilot_manifest()
  testthat::skip_if_not(
    file.exists(file.path(power_pilot_root, "dev", "power-pilot-run.R"))
  )

  results_dir <- tempfile("pilot-chunk-audit-empty-")
  dir.create(results_dir)
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  old_wd <- setwd(power_pilot_root)
  on.exit(setwd(old_wd), add = TRUE)

  rscript <- file.path(R.home("bin"), "Rscript")
  out <- suppressWarnings(
    system2(
      rscript,
      c(
        "--vanilla",
        file.path("dev", "power-pilot-run.R"),
        "--mode=chunk-audit",
        paste0("--results-dir=", results_dir)
      ),
      stdout = TRUE,
      stderr = TRUE
    )
  )
  expect_equal(attr(out, "status"), 1L)
  out <- paste(out, collapse = "\n")
  expect_match(out, "chunk_outputs_ok=false")
  expect_match(out, "found no manifest rows")
})

test_that("power pilot chunk-aggregate CLI writes per-cell aggregate files", {
  source_power_pilot_manifest()
  testthat::skip_if_not(
    file.exists(file.path(power_pilot_root, "dev", "power-pilot-run.R"))
  )

  results_dir <- tempfile("pilot-chunk-aggregate-cli-")
  aggregate_dir <- file.path(results_dir, "aggregate")
  dir.create(results_dir)
  on.exit(unlink(results_dir, recursive = TRUE, force = TRUE), add = TRUE)

  manifest <- two_chunk_manifest(results_dir, seed_base = 161L)
  pilot_write_manifest(manifest, results_dir, shard = 1L)
  write_fake_chunk(manifest[1L, , drop = FALSE], reps = 1:2)
  write_fake_chunk(manifest[2L, , drop = FALSE], reps = 3:4)

  old_wd <- setwd(power_pilot_root)
  on.exit(setwd(old_wd), add = TRUE)

  rscript <- file.path(R.home("bin"), "Rscript")
  out <- system2(
    rscript,
    c(
      "--vanilla",
      file.path("dev", "power-pilot-run.R"),
      "--mode=chunk-aggregate",
      paste0("--results-dir=", results_dir),
      paste0("--aggregate-dir=", aggregate_dir)
    ),
    stdout = TRUE,
    stderr = TRUE
  )
  out <- paste(out, collapse = "\n")
  expect_match(out, "chunk_aggregate_ok=true")
  expect_match(out, "chunk_aggregate_cells=1")
  expect_match(out, "chunk_aggregate_rows=8")
  expect_match(out, "chunk aggregate: wrote 1 cell aggregate")
  expect_true(file.exists(file.path(
    aggregate_dir,
    paste0(manifest$cell_id[1L], ".rds")
  )))
})
