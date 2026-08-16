## Design 118 B1 -- calibration-campaign harness pure-function tests.
## docs/design/118-mspl-interval-calibration-protocol.md s2, s3, s5, s6.2;
## fence line 2 is F-AMD per docs/dev-log/2026-08-15-b1-launch-spec.md
## (DEV-3, s8 deviations ledger).
##
## The harness (inst/sim/b1-calibration/) is a simulation runner, not
## exported package API; these tests exercise only its pure functions (the
## grid, seeds, task-id mapping, fence logic), which need no live MSPL fit
## and stay fast. No fitting happens in this file.

b0_lib_path <- system.file("sim/b0-fence-roc/lib-b0-fence-roc.R", package = "gllvmTMB")
b1_lib_path <- system.file("sim/b1-calibration/lib-b1-calibration.R", package = "gllvmTMB")

test_that("the B1 harness library is shipped and sources cleanly after B0's", {
  skip_if(!nzchar(b0_lib_path), "inst/sim/b0-fence-roc/lib-b0-fence-roc.R not found")
  skip_if(!nzchar(b1_lib_path), "inst/sim/b1-calibration/lib-b1-calibration.R not found")
  expect_true(file.exists(b0_lib_path))
  expect_true(file.exists(b1_lib_path))
  env <- new.env()
  expect_silent(source(b0_lib_path, local = env))
  expect_silent(source(b1_lib_path, local = env))
})

local({
  if (!nzchar(b0_lib_path) || !nzchar(b1_lib_path)) return(invisible())
  source(b0_lib_path, local = TRUE)
  source(b1_lib_path, local = TRUE)

  ## ---- Grid (Design 118 s5.1): row count and train/holdout flags --------
  test_that("b1_grid() has exactly 132 cells (Design 118 s5.1: 88 calibration + 44 hold-out)", {
    g <- b1_grid()
    expect_equal(nrow(g), 132L)
    expect_equal(sum(g$split == "train"), 88L)
    expect_equal(sum(g$split == "holdout"), 44L)
  })

  test_that("b1_grid() reproduces the Design 118 s5.1 calibration block sizes (C-core/C-q2/C-ID1/C-ID2)", {
    g <- b1_grid()
    expect_equal(sum(g$block == "C-core"), 40L)
    expect_equal(sum(g$block == "C-q2"), 12L)
    expect_equal(sum(g$block == "C-ID1"), 18L)
    expect_equal(sum(g$block == "C-ID2"), 18L)
    expect_true(all(g$split[g$block %in% c("C-core", "C-q2", "C-ID1", "C-ID2")] == "train"))
  })

  test_that("b1_grid() reproduces the Design 118 s5.1 hold-out block sizes (H1/H2/H3)", {
    g <- b1_grid()
    expect_equal(sum(g$block == "H1"), 18L)
    expect_equal(sum(g$block == "H2"), 16L)
    expect_equal(sum(g$block == "H3"), 10L)
    expect_true(all(g$split[g$block %in% c("H1", "H2", "H3")] == "holdout"))
  })

  test_that("H1 (Design 118 s5.1) is entirely probit -- the cross-link hold-out", {
    g <- b1_grid()
    h1 <- g[g$block == "H1", ]
    expect_true(all(h1$link == "probit"))
    expect_equal(sum(h1$q == 1L), 15L)
    expect_equal(sum(h1$q == 2L), 3L)
  })

  test_that("C-ID1/C-ID2 (Design 118 s5.1 de-confounding arms) carry no bootstrap (s6.1)", {
    g <- b1_grid()
    expect_true(all(!g$bootstrap_bearing[g$block %in% c("C-ID1", "C-ID2")]))
    expect_true(all(g$bootstrap_bearing[!g$block %in% c("C-ID1", "C-ID2")]))
  })

  test_that("C-ID1 fixes N_eff = n_site * n_trait = 288 across its three (n_site, n_trait) tuples", {
    g <- b1_grid()
    id1 <- unique(g[g$block == "C-ID1", c("n_site", "n_trait")])
    expect_equal(sort(id1$n_site * id1$n_trait), rep(288L, 3L))
  })

  test_that("C-ID2 fixes n_site = 48 and varies n_trait in {3, 6, 12}", {
    g <- b1_grid()
    id2 <- g[g$block == "C-ID2", ]
    expect_true(all(id2$n_site == 48L))
    expect_equal(sort(unique(id2$n_trait)), c(3L, 6L, 12L))
  })

  test_that("cell_id/cell_index/seed_base are unique across all 132 cells", {
    g <- b1_grid()
    expect_equal(anyDuplicated(g$cell_id), 0L)
    expect_equal(anyDuplicated(g$cell_index), 0L)
    expect_equal(anyDuplicated(g$seed_base), 0L)
    expect_equal(g$cell_index, seq_len(132L))
  })

  ## ---- Seeds: disjoint from B0 and the 2026-08-14 archive ----------------
  test_that("b1_seed_base() matches the 2026-08-15 launch spec formula", {
    expect_equal(b1_seed_base(1L), 218000000L + 1000000L)
    expect_equal(b1_seed_base(132L), 218000000L + 132L * 1000000L)
  })

  test_that("B1's seed range is disjoint from B0's and the 2026-08-14 archive's", {
    g <- b1_grid()
    ## B0: 118,000,000 + case_number*1,000,000 for case_number in 1..12 ->
    ## range [1.19e8, 1.30e8].
    b0_range <- c(118000000L + 1000000L, 118000000L + 12L * 1000000L)
    ## Archive: 1,900,000,000 + case_number*10,000,000 -> range [1.91e9, 2.02e9].
    archive_range <- c(1900000000L + 1L * 10000000L, 1900000000L + 12L * 10000000L)
    expect_true(all(g$seed_base > b0_range[[2L]]))
    expect_true(all(g$seed_base < archive_range[[1L]]))
    ## Bootstrap seeds (offset +500,000+) stay below the next cell's plain
    ## seed_base band and never collide with another outer_id's plain seed.
    row <- g[1L, ]
    plain_seeds <- vapply(1:2000, function(o) b1_outer_seed(row, o), integer(1L))
    boot_seeds <- vapply(1:5, function(a) b1_bootstrap_seed(row, outer_id = 1L, attempt_id = a), integer(1L))
    expect_true(all(!boot_seeds %in% plain_seeds))
  })

  ## ---- Task-id <-> (cell, shard) mapping: bijective ----------------------
  test_that("b1_task_map() is bijective at the default outer-per-shard/reps", {
    m <- b1_task_map(outer_per_shard = 10L, reps = 600L)
    expect_equal(nrow(m), 132L * 60L) ## 60 = ceiling(600/10) shards/cell
    expect_equal(anyDuplicated(m$task_id), 0L)
    expect_equal(sort(m$task_id), seq_len(nrow(m)))
    expect_equal(anyDuplicated(m[, c("cell_id", "shard_id")]), 0L)
  })

  test_that("b1_task_lookup() round-trips b1_task_map() for boundary task_ids", {
    m <- b1_task_map(outer_per_shard = 10L, reps = 600L)
    for (tid in c(1L, 60L, 61L, nrow(m))) {
      hit <- b1_task_lookup(tid, outer_per_shard = 10L, reps = 600L)
      expect_equal(hit$task_id, m$task_id[m$task_id == tid])
      expect_equal(hit$cell_id, m$cell_id[m$task_id == tid])
      expect_equal(hit$shard_id, m$shard_id[m$task_id == tid])
    }
    ## task_id=1 is cell 1 shard 1; task_id=61 is cell 2 shard 1.
    expect_equal(b1_task_lookup(1L)$cell_id, "B001")
    expect_equal(b1_task_lookup(1L)$shard_id, 1L)
    expect_equal(b1_task_lookup(61L)$cell_id, "B002")
    expect_equal(b1_task_lookup(61L)$shard_id, 1L)
  })

  test_that("b1_task_lookup() errors on an out-of-range task_id", {
    expect_error(b1_task_lookup(0L), "Unknown B1 task_id")
    expect_error(b1_task_lookup(999999L), "Unknown B1 task_id")
  })

  ## ---- 1-in-3 bootstrap subset: deterministic by seed/index arithmetic --
  test_that("b1_in_bootstrap_subset() is deterministic and selects ~1/3", {
    expect_equal(b1_in_bootstrap_subset(1:9), rep(c(TRUE, FALSE, FALSE), 3L))
    ## Repeated calls with the same input give the same output (no RNG state).
    expect_identical(b1_in_bootstrap_subset(1:600), b1_in_bootstrap_subset(1:600))
    expect_equal(mean(b1_in_bootstrap_subset(1:600)), 1 / 3, tolerance = 1e-12)
  })

  ## ---- Target positions and lambda construction --------------------------
  test_that("b1_target_positions() picks min/median/max trait positions", {
    expect_equal(b1_target_positions(3L)$position, c(1L, 2L, 3L))
    expect_equal(b1_target_positions(6L)$position, c(1L, 4L, 6L))
    expect_equal(b1_target_positions(12L)$position, c(1L, 6L, 12L))
    expect_equal(b1_target_positions(3L)$slot, c("min", "median", "max"))
  })

  test_that("b1_target_intercepts() is monotone increasing in trait position", {
    vals <- b1_target_intercepts(0.5, "logit", 6L)
    expect_true(all(diff(vals) > 0))
    expect_equal(length(vals), 6L)
  })

  test_that("b1_lambda_matrix() returns an n_trait x q matrix, non-degenerate across q", {
    lam <- b1_lambda_matrix(1, n_trait = 6L, q = 2L)
    expect_equal(dim(lam), c(6L, 2L))
    expect_false(isTRUE(all.equal(lam[, 1L], lam[, 2L])))
  })

  ## ---- Fence line 1 (screen) pure logic -----------------------------------
  test_that("b1_screen_refused() flags constant_response and complete/quasi_complete separation", {
    expect_true(b1_screen_refused("NOT_CHECKED", "constant_response"))
    expect_true(b1_screen_refused("WARN", "complete"))
    expect_true(b1_screen_refused("WARN", "quasi_complete"))
    expect_false(b1_screen_refused("PASS", "none"))
    expect_false(b1_screen_refused("WARN", "overlap"))
    expect_equal(
      b1_screen_refused(c("PASS", "WARN", "NOT_CHECKED"), c("none", "complete", "constant_response")),
      c(FALSE, TRUE, TRUE)
    )
  })

  ## ---- Fence line 2, F-AMD (DEV-3): attractor-proximity -------------------
  test_that("b1_proximity_refused() fires at A1b's cloglog k=24 attractor, matching b0_label_l2", {
    ## Same fixture as B0's own attractor-root tests: p_free=6, N_eff=72.
    c_n <- b0_c_n_formula(p_free = 6, N_eff = 72)
    root <- b0_attractor_root(k = 24L, n = 24L, c_n = c_n, link = "cloglog")
    expect_equal(root, 1.5964000447, tolerance = 1e-8)
    expect_true(b1_proximity_refused(root, root))
    expect_true(b1_proximity_refused(root + 5e-5, root, tol = 1e-4))
    expect_false(b1_proximity_refused(root + 5e-3, root, tol = 1e-4))
    expect_false(b1_proximity_refused(NA_real_, root))
  })

  ## ---- Output schema -------------------------------------------------------
  test_that("b1_output_columns is a schema of unique, present names", {
    expect_true(is.character(b1_output_columns))
    expect_equal(anyDuplicated(b1_output_columns), 0L)
    required <- c(
      "cell_id", "block", "split", "seed", "estimate", "truth",
      "screen_refused", "proximity_refused", "refused", "s_j",
      "profile_lower", "profile_upper", "profile_covered",
      "bootstrap_lower", "bootstrap_upper", "bootstrap_covered",
      "in_bootstrap_subset", "status"
    )
    expect_true(all(required %in% b1_output_columns))
  })

  test_that("b1_na_row() produces a schema-conformant all-NA data.frame", {
    row <- b1_na_row(3L)
    expect_equal(names(row), b1_output_columns)
    expect_equal(nrow(row), 3L)
    expect_true(all(vapply(row, function(col) all(is.na(col)), logical(1L))))
  })
})
