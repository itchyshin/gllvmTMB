forensics_path <- testthat::test_path("..", "..", "dev", "isdm-requalification", "response-information-forensics", "forensics.R")
recompute_path <- testthat::test_path("..", "..", "dev", "isdm-requalification", "response-information", "recompute.R")
if (!file.exists(forensics_path) || !file.exists(recompute_path)) {
  test_that("response-information forensic sources are available", {
    skip("developer-only response-information forensic sources are absent")
  })
} else {
  source(recompute_path, local = TRUE)
  source(forensics_path, local = TRUE)

  test_that("fit-health boundary keeps the frozen gradient rule exact", {
    base <- list(convergence = 0L, pd_hessian = TRUE, finite = TRUE, max_gradient = 0.01)
    expect_true(isdm_forensics_fit_health(base))
    base$max_gradient <- 0.01000001
    expect_false(isdm_forensics_fit_health(base))
  })

  test_that("mechanism classifier recognises the first and second upper-tail ranks", {
    fits <- data.frame(cell_index = c(rep(7L, 100L), 8L), variant = c(rep(c("baseline", "rep3"), each = 50L), "baseline"),
                       max_gradient = c(seq(0.001, 0.0099, length.out = 50L), seq(0.001, 0.009, length.out = 48L), 0.0103, 0.0111, 0.02))
    focal <- data.frame(cell_index = c(7L, 7L), gradient_rank = c(49L, 50L), gradient_n = c(50L, 50L))
    out <- isdm_forensics_mechanism(fits, focal)
    expect_identical(out$label, "SUPPORTED_NARROW_GRADIENT_TAIL")
    expect_identical(out$decision, "NO_FRESH_CAMPAIGN_YET")
  })

  test_that("checksum manifests reject malformed entries", {
    path <- tempfile(fileext = ".sha256")
    writeLines(c("not a checksum", "abc"), path)
    expect_error(isdm_forensics_read_manifest(path), "no entries")
  })
}
