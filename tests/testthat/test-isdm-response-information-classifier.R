classifier_path <- testthat::test_path("..", "..", "dev", "isdm-requalification", "response-information", "classify.R")
contract_path <- testthat::test_path("..", "..", "dev", "isdm-requalification", "response-information", "contract.R")
if (!file.exists(classifier_path) || !file.exists(contract_path)) {
  test_that("response-information classifier sources are available", skip("developer-only classifier sources are absent"))
} else {
  source(contract_path, local = TRUE); source(classifier_path, local = TRUE)
  make_pairs <- function(value = -.20, psi = -.01) data.frame(cell_index = rep(1:8, each = 50), shared_D = value, full_D = value, psi1_D = psi, psi2_D = psi, psi3_D = psi)
  test_that("classifier distinguishes surface, joint, mixed, and incomplete evidence", {
    expect_identical(isdm_respinfo_classify(make_pairs(psi = .01), B = 20)$classification, "SURFACE_ONLY")
    expect_identical(isdm_respinfo_classify(make_pairs(psi = -.20), B = 20)$classification, "JOINT")
    expect_identical(isdm_respinfo_classify(make_pairs(value = .01, psi = -.20), B = 20)$classification, "MIXED_OR_NULL")
    incomplete <- make_pairs(); incomplete$full_D[[301L]] <- NA_real_; incomplete$psi1_D[[316L]] <- NA_real_
    result <- isdm_respinfo_classify(incomplete, B = 20)
    expect_identical(result$classification, "EVIDENCE_INCOMPLETE")
    expect_identical(unname(result$n_scoreable), as.integer(c(50, 50, 50, 50, 50, 50, 48, 50)))
  })
}
