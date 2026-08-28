contract_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "contract.R"
)
source(contract_path, local = TRUE)

test_that("point plans preserve exact denominators and registered seeds", {
  ordinary <- isdm_point_plan("ordinary")
  attack <- isdm_point_plan("attack")
  spatial <- isdm_point_plan("spatial")

  expect_equal(nrow(ordinary), 1600L)
  expect_equal(nrow(attack), 200L)
  expect_equal(nrow(spatial), 800L)
  expect_identical(range(c(ordinary$seed, attack$seed)),
                   c(202608280L, 202610079L))
  expect_identical(range(spatial$seed), c(202610080L, 202610879L))
  expect_equal(length(unique(c(ordinary$seed, attack$seed, spatial$seed))),
               2600L)
  expect_equal(as.integer(table(ordinary$n_sources)), c(800L, 800L))
  expect_equal(as.integer(table(ordinary$overlap)), c(800L, 800L))
  expect_equal(as.integer(table(ordinary$n_cells)), c(800L, 800L))
  expect_equal(as.integer(table(attack$n_sources)), c(100L, 100L))
  expect_equal(as.integer(table(spatial$n_sources)), c(400L, 400L))
  expect_equal(as.integer(table(spatial$overlap)), c(400L, 400L))
  full <- ordinary[ordinary$overlap == "full", ]
  weak <- ordinary[ordinary$overlap == "weak", ]
  paired <- merge(full, weak, by = c("n_sources", "n_cells", "rep"),
                  suffixes = c("_full", "_weak"))
  expect_equal(nrow(paired), 800L)
  expect_identical(paired$structure_seed_full, paired$structure_seed_weak)
  expect_false(any(paired$seed_full == paired$seed_weak))
})

test_that("uncertainty plan preserves exact cells and registered seeds", {
  plan <- isdm_interval_plan()
  expect_equal(nrow(plan), 4800L)
  expect_identical(range(plan$seed), c(202610880L, 202615679L))
  cells <- interaction(plan$n_cells, plan$n_sources, plan$overlap, drop = TRUE)
  expect_equal(length(levels(cells)), 8L)
  expect_true(all(table(cells) == 600L))
})

test_that("pre-run plan contains one point fit per cell and three interval fits per cell", {
  plan <- isdm_prerun_plan()
  expect_equal(sum(plan$programme %in% c("ordinary", "attack", "spatial")), 14L)
  expect_equal(sum(plan$programme == "interval"), 24L)
  expect_identical(as.integer(table(plan$programme)[c(
    "ordinary", "attack", "spatial", "interval"
  )]), c(8L, 2L, 4L, 24L))
  expect_identical(plan$task_id, seq_len(38L))
  expect_equal(length(unique(plan$seed)), 38L)
  expect_false(any(plan$seed %in% 202608280:202615679))
})

test_that("frozen thresholds retain the approved values", {
  gates <- isdm_frozen_gates()
  expect_identical(gates$ordinary$campaign_terminal_n, 1800L)
  expect_identical(gates$ordinary$promotion_terminal_n, 1600L)
  expect_identical(gates$ordinary$stress_terminal_n, 200L)
  expect_identical(gates$ordinary$convergence_min, 0.95)
  expect_identical(gates$ordinary$finite_objective_min, 0.99)
  expect_identical(gates$ordinary$pd_hessian_min, 0.85)
  expect_identical(gates$ordinary$target_availability_min, 0.85)
  expect_identical(gates$ordinary$coefficient_abs_bias_max, 0.10)
  expect_identical(gates$ordinary$coefficient_rmse_max, 0.25)
  expect_identical(gates$ordinary$surface_correlation_median_min, 0.90)
  expect_identical(gates$ordinary$surface_nrmse_median_max, 0.50)
  expect_identical(gates$ordinary$sigma_relative_frobenius_median_max, 0.35)
  expect_identical(gates$ordinary$psi_relative_error_median_max, 0.35)
  expect_identical(gates$spatial$training_identity_max, 1e-10)
  expect_identical(gates$interval$availability_min, 0.85)
  expect_identical(gates$interval$ordered_finite_min, 0.99)
  expect_identical(gates$interval$wilson90_acceptance, c(0.92, 0.98))
  expect_identical(gates$interval$immediate_failure_below, 0.80)
  expect_identical(gates$interval$quantile_type, 1L)
  expect_identical(gates$interval$coverage_unit,
                   "species_within_cell_across_replicates")
})

test_that("only rotation-invariant estimands are admitted", {
  estimands <- isdm_estimand_contract()
  expect_true(all(c("ecological_coefficients", "source_observation_coefficients",
                    "centered_relative_intensity", "Sigma", "Psi") %in%
                  estimands$admitted))
  expect_true(all(c("raw_latent_scores", "unaligned_loadings") %in%
                  estimands$refused))
})

test_that("fixed target applicability is frozen before observing fits", {
  two <- isdm_expected_fixed_targets(2L)
  three <- isdm_expected_fixed_targets(3L)
  expect_length(two, 9L)
  expect_length(three, 11L)
  expect_true(all(two %in% three))
  expect_identical(setdiff(three, two),
                   c("isdm_source:source2:(Intercept)",
                     "isdm_source:source3:bias_x"))
})
