recompute_path <- testthat::test_path("..", "..", "dev", "isdm-requalification",
                                      "response-information", "recompute.R")

if (!file.exists(recompute_path)) {
  test_that("response-information raw scorer is available", { skip("developer-only scorer is absent") })
} else {
  source(recompute_path, local = TRUE)

  test_that("raw scorer independently recovers zero error", {
    truth <- c(1, 2, 3, 2, 4, 6)
    raw <- list(
      surfaces = list(shared = truth, full = truth), trait = rep(c("sp1", "sp2"), each = 3L),
      truth_surfaces = list(shared = truth, full = truth),
      Sigma = diag(c(2, 3, 4)), truth_Sigma = diag(c(2, 3, 4)),
      Psi = diag(c(0.2, 0.3, 0.4)), truth_Psi = diag(c(0.2, 0.3, 0.4)),
      fixed = c("isdm_source:source2:bias_x" = 1), fixed_truth = c("isdm_source:source2:bias_x" = 1)
    )
    scored <- isdm_respinfo_recompute_raw(raw)
    expect_equal(unname(unlist(scored)), rep(0, 7L))
  })
}
