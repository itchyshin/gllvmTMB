fixture_path <- testthat::test_path(
  "..", "..", "dev", "isdm-requalification", "response-information",
  "harness.R"
)

if (!file.exists(fixture_path)) {
  test_that("response-information fixture harness is available", {
    skip("developer-only response-information sources are absent")
  })
} else {
  source(fixture_path, local = TRUE)

  test_that("rep3 retains baseline rows and draws registered extra streams", {
    plan <- isdm_respinfo_plan()
    pair <- plan[plan$dataset_id == 1L, , drop = FALSE]
    baseline <- isdm_respinfo_fixture(pair[pair$variant == "baseline", , drop = FALSE])
    rep3 <- isdm_respinfo_fixture(pair[pair$variant == "rep3", , drop = FALSE])
    n <- nrow(baseline$data)

    expect_identical(rep3$data[seq_len(n), names(baseline$data), drop = FALSE],
                     baseline$data)
    expect_identical(rep3$data$replicate_id, rep(1:3, each = n))
    expect_identical(rep3$design$replicate_seeds,
                     as.integer(pair[pair$variant == "rep3", c("rep3_seed_1", "rep3_seed_2")]))
    expect_false(identical(rep3$data$value[seq_len(n)],
                           rep3$data$value[n + seq_len(n)]))
  })

  test_that("fixture construction rejects a baseline row with added stream seeds", {
    task <- isdm_respinfo_plan()[1L, , drop = FALSE]
    task$rep3_seed_1 <- 1L
    task$rep3_seed_2 <- 2L
    expect_error(isdm_respinfo_fixture(task), class = "isdm_respinfo_fixture_contract_invalid")
  })
}
