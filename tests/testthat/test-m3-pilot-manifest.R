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
