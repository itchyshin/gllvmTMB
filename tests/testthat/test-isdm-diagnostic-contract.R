diagnostic_contract_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "diagnostic-rescue",
  "contract.R"
)

if (!file.exists(diagnostic_contract_path)) {
  test_that("developer-only iSDM diagnostic contract is available", {
    skip("dev/isdm-requalification/diagnostic-rescue is absent from build")
  })
} else {
source(diagnostic_contract_path, local = TRUE)

.diagnostic_test_index <- function() {
  ordinary <- do.call(rbind, lapply(c(150L, 810L), function(n_cells) {
    do.call(rbind, lapply(c(2L, 3L), function(n_sources) {
      do.call(rbind, lapply(1:2, function(pair_id) {
        data.frame(
          task_id = c(1000L, 2000L) + n_cells + 10L * n_sources + pair_id,
          programme = "ordinary", n_sources = n_sources,
          overlap = c("full", "weak"), n_cells = n_cells,
          pair_id = pair_id,
          structure_seed = 202700000L + pair_id,
          seed = c(202600000L, 202700000L) + n_cells +
            10L * n_sources + pair_id,
          status = "fit_returned", convergence = 0L, pd_hessian = TRUE,
          source_sha = ISDM_DIAG_PRODUCTION_SOURCE_SHA,
          source_tree = ISDM_DIAG_PRODUCTION_SOURCE_TREE,
          record_sha256 = sprintf("%064x", seq_len(2)),
          stringsAsFactors = FALSE
        )
      }))
    }))
  }))

  classes <- c("converged_pd", "converged_nonpd", "nonconverged_nonpd")
  spatial <- do.call(rbind, lapply(c("full", "weak"), function(overlap) {
    do.call(rbind, lapply(c(2L, 3L), function(n_sources) {
      do.call(rbind, lapply(seq_along(classes), function(i) {
        data.frame(
          task_id = 3000L + 100L * (overlap == "weak") +
            10L * n_sources + i,
          programme = "spatial", n_sources = n_sources, overlap = overlap,
          n_cells = 810L, pair_id = NA_integer_, structure_seed = NA_integer_,
          seed = 202800000L + 100L * (overlap == "weak") +
            10L * n_sources + i,
          status = "fit_returned",
          convergence = c(0L, 0L, 1L)[i],
          pd_hessian = c(TRUE, FALSE, FALSE)[i],
          source_sha = ISDM_DIAG_PRODUCTION_SOURCE_SHA,
          source_tree = ISDM_DIAG_PRODUCTION_SOURCE_TREE,
          record_sha256 = sprintf("%064x", 100L + i),
          stringsAsFactors = FALSE
        )
      }))
    }))
  }))
  rbind(ordinary, spatial)
}

test_that("frozen selectors create exactly 8 and 12 native sentinels", {
  index <- .diagnostic_test_index()
  nonsp <- isdm_diag_select_nonspatial(index)
  spatial <- isdm_diag_select_spatial(index)

  expect_equal(nrow(nonsp), 8L)
  expect_true(all(nonsp$pair_id == 1L))
  expect_equal(length(unique(nonsp$structure_seed)), 1L)
  expect_equal(as.integer(table(nonsp$overlap)), c(4L, 4L))
  expect_equal(nrow(spatial), 12L)
  expect_equal(as.integer(table(spatial$outcome_class)), c(4L, 4L, 4L))
  expect_equal(length(unique(c(nonsp$seed, spatial$seed))), 20L)
})

test_that("the immutable plan has 52 unique task identities", {
  index <- .diagnostic_test_index()
  plan <- isdm_diag_plan(
    isdm_diag_select_nonspatial(index),
    isdm_diag_select_spatial(index)
  )

  expect_equal(nrow(plan), 52L)
  expect_identical(plan$task_id, seq_len(52L))
  expect_equal(length(unique(plan$task_id)), 52L)
  expect_equal(length(unique(plan$optimizer_seed)), 52L)
  expect_equal(as.integer(table(plan$slice)[c("nonspatial", "spatial")]),
               c(16L, 36L))
  expect_equal(as.integer(table(plan$variant)[c(
    "baseline", "rep3", "default", "bfgs_continuation", "nlminb5"
  )]), c(8L, 8L, 12L, 12L, 12L))
  expect_false(any(plan$rep3_seed_1[plan$variant == "rep3"] %in% plan$seed))
  expect_false(any(plan$rep3_seed_2[plan$variant == "rep3"] %in% plan$seed))
  expect_silent(isdm_diag_validate_plan(plan))
})

test_that("nonspatial pairing and spatial control pairing are preserved", {
  index <- .diagnostic_test_index()
  selected_nonsp <- isdm_diag_select_nonspatial(index)
  selected_spatial <- isdm_diag_select_spatial(index)
  plan <- isdm_diag_plan(selected_nonsp, selected_spatial)

  paired <- split(selected_nonsp,
                  interaction(selected_nonsp$n_sources,
                              selected_nonsp$n_cells, drop = TRUE))
  expect_true(all(vapply(paired, function(x) {
    nrow(x) == 2L && length(unique(x$pair_id)) == 1L &&
      length(unique(x$structure_seed)) == 1L &&
      identical(sort(x$overlap), c("full", "weak"))
  }, logical(1L))))

  spatial <- plan[plan$slice == "spatial", ]
  controls <- split(spatial, spatial$native_task_id)
  expect_true(all(vapply(controls, function(x) {
    identical(sort(x$variant),
              sort(c("default", "bfgs_continuation", "nlminb5"))) &&
      length(unique(x$seed)) == 1L
  }, logical(1L))))
})

test_that("selectors refuse missing, ambiguous, duplicate, and wrong-source input", {
  index <- .diagnostic_test_index()
  missing_partner <- index[!(index$programme == "ordinary" &
    index$n_sources == 2L & index$n_cells == 150L &
    index$overlap == "weak"), ]
  expect_error(isdm_diag_select_nonspatial(missing_partner),
               class = "isdm_diag_pair_missing")

  missing_class <- index[!(index$programme == "spatial" &
    index$n_sources == 2L & index$overlap == "full" &
    index$convergence != 0L), ]
  expect_error(isdm_diag_select_spatial(missing_class),
               class = "isdm_diag_outcome_class_missing")

  duplicate <- rbind(index, index[index$programme == "spatial", ][1L, ])
  expect_error(isdm_diag_select_spatial(duplicate),
               class = "isdm_diag_identity_duplicate")

  wrong_source <- index
  wrong_source$source_sha[[1L]] <- paste(rep("0", 40L), collapse = "")
  expect_error(isdm_diag_validate_index(wrong_source),
               class = "isdm_diag_source_mismatch")
})

test_that("outcome classes refuse unsupported terminal states", {
  expect_identical(isdm_diag_outcome_class(0L, TRUE, "fit_returned"),
                   "converged_pd")
  expect_identical(isdm_diag_outcome_class(0L, FALSE, "fit_returned"),
                   "converged_nonpd")
  expect_identical(isdm_diag_outcome_class(1L, FALSE, "fit_returned"),
                   "nonconverged_nonpd")
  expect_identical(isdm_diag_outcome_class(1L, TRUE, "fit_returned"),
                   "nonconverged_pd")
  expect_error(isdm_diag_outcome_class(NA_integer_, NA, "error"),
               class = "isdm_diag_outcome_unavailable")
})

test_that("public plan helpers consume only a bound seed manifest", {
  index <- .diagnostic_test_index()
  manifest <- list(
    schema = ISDM_DIAG_SEED_MANIFEST_SCHEMA,
    nonspatial = isdm_diag_select_nonspatial(index),
    spatial = isdm_diag_select_spatial(index)
  )
  plan <- diagnostic_plan(manifest)
  smoke <- diagnostic_smoke_plan(manifest)

  expect_identical(names(plan)[1:12], c(
    "task_id", "slice", "native_task_id", "seed", "n_sources", "overlap",
    "n_cells", "variant", "sentinel_class", "optimizer_seed", "pair_id",
    "structure_seed"
  ))
  expect_equal(nrow(smoke), 4L)
  expect_identical(smoke$smoke_task_id, 1:4)
  expect_equal(as.integer(table(smoke$slice)[c("nonspatial", "spatial")]),
               c(1L, 3L))
  expect_identical(smoke$variant,
                   c("rep3", "default", "bfgs_continuation", "nlminb5"))
  expect_equal(length(unique(smoke$native_task_id[smoke$slice == "spatial"])),
               1L)

  manifest$schema <- "wrong"
  expect_error(diagnostic_plan(manifest),
               class = "isdm_diag_seed_manifest_invalid")
})

test_that("plan verification detects identity corruption", {
  index <- .diagnostic_test_index()
  plan <- isdm_diag_plan(
    isdm_diag_select_nonspatial(index),
    isdm_diag_select_spatial(index)
  )
  plan$optimizer_seed[[2L]] <- plan$optimizer_seed[[1L]]
  expect_error(isdm_diag_validate_plan(plan),
               class = "isdm_diag_plan_identity_invalid")
})
}
