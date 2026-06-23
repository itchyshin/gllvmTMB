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
  expect_equal(any(duplicated(manifest$result_path)), FALSE)
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
