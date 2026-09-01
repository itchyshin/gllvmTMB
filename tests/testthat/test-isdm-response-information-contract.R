contract_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "response-information",
  "contract.R"
)

if (!file.exists(contract_path)) {
  test_that("response-information contract is available", {
    skip("developer-only response-information sources are absent")
  })

} else {
  source(contract_path, local = TRUE)

  test_that("qualification seeds cannot enter the retained denominator", {
    qualification <- isdm_respinfo_qualification_plan()
    plan <- isdm_respinfo_plan()
    expect_true(all(qualification$structure_seed < ISDM_RESPINFO_SEED_BASE))
    expect_true(all(plan$structure_seed >= ISDM_RESPINFO_SEED_BASE))
  })

  test_that("prospective plan has 400 paired datasets and 800 fit identities", {
    plan <- isdm_respinfo_plan()
    expect_equal(nrow(plan), 800L)
    expect_identical(plan$task_id, seq_len(800L))
    expect_equal(length(unique(plan$dataset_id)), 400L)
    expect_equal(as.integer(table(plan$variant)[c("baseline", "rep3")]),
                 c(400L, 400L))
    expect_equal(nrow(isdm_respinfo_pilot_plan(plan)), 16L)
    expect_silent(isdm_respinfo_validate_plan(plan))
  })

  test_that("qualification identities are isolated and nested by host", {
    qualification <- isdm_respinfo_qualification_plan()
    expect_silent(isdm_respinfo_validate_qualification_plan(qualification))
    expect_true(all(qualification$optimizer_seed < ISDM_RESPINFO_SEED_BASE))
    expect_equal(length(unique(qualification$host)), 2L)
  })

  test_that("paired arms retain identical truth and baseline response streams", {
    plan <- isdm_respinfo_plan()
    paired <- split(plan, plan$dataset_id)
    expect_true(all(vapply(paired, function(x) {
      nrow(x) == 2L && identical(x$variant, c("baseline", "rep3")) &&
        length(unique(x$n_sources)) == 1L && length(unique(x$n_cells)) == 1L &&
        length(unique(x$overlap)) == 1L && length(unique(x$structure_seed)) == 1L &&
        length(unique(x$observation_seed)) == 1L &&
        is.na(x$rep3_seed_1[[1L]]) && is.na(x$rep3_seed_2[[1L]]) &&
        is.finite(x$rep3_seed_1[[2L]]) && is.finite(x$rep3_seed_2[[2L]])
    }, logical(1L))))
  })

  test_that("contract rejects collisions and broken nested pairing", {
    plan <- isdm_respinfo_plan()
    duplicate <- plan
    duplicate$optimizer_seed[3:4] <- duplicate$optimizer_seed[[1L]]
    expect_error(isdm_respinfo_validate_plan(duplicate),
                 class = "isdm_respinfo_optimizer_seed_collision")

    changed <- plan
    changed$optimizer_seed[[2L]] <- changed$optimizer_seed[[2L]] + 1L
    expect_error(isdm_respinfo_validate_plan(changed),
                 class = "isdm_respinfo_pair_not_nested")

    changed <- plan
    changed$observation_seed[[2L]] <- changed$observation_seed[[2L]] + 1L
    expect_error(isdm_respinfo_validate_plan(changed),
                 class = "isdm_respinfo_pair_not_nested")

    collision <- plan
    collision$rep3_seed_1[[2L]] <- collision$observation_seed[[1L]]
    expect_error(isdm_respinfo_validate_plan(collision),
                 class = "isdm_respinfo_response_seed_collision")
  })
}
