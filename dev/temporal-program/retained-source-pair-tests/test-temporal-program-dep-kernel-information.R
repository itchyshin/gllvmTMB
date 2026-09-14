test_that("dep-kernel information diagnostic is frozen and sourceable", {
  script <- testthat::test_path("..", "..", "dev", "temporal-program",
    "diagnose-dep-kernel-information.R")
  testthat::skip_if_not(
    file.exists(script),
    "development diagnostic is excluded from the installed package"
  )
  expect_true(file.exists(script))
  source(script, local = environment())
  expect_equal(.temporal_dep_kernel_information_seeds(), 2609221:2609223)
  expect_equal(.temporal_dep_kernel_information_sizes(), c(80L, 160L))
  expect_error(.temporal_dep_kernel_information_validate(81L, 2609221L), "frozen diagnostic size")
  expect_error(.temporal_dep_kernel_information_validate(80L, 1L), "retained diagnostic seed")
  source_text <- paste(readLines(script, warn = FALSE), collapse = "\n")
  expect_match(source_text, "output must name a new result file")
  expect_match(source_text, "--n-series=N --seed=N")
  launcher <- testthat::test_path("..", "..", "dev", "temporal-program", "remote",
    "dep-kernel-information-totoro.sh")
  expect_equal(system2("bash", c("-n", launcher)), 0L)
  expect_match(paste(readLines(launcher, warn = FALSE), collapse = "\n"),
    "TEMPORAL_DEP_KERNEL_INFORMATION_TOTORO_APPROVED=YES")
})

test_that("dep-kernel information diagnostic retains every approved Totoro receipt", {
  receipts <- testthat::test_path("..", "..", "dev", "temporal-program", "results",
    "diagnostics", "dep-kernel-information-20260911")
  skip_if_not(dir.exists(receipts), "repository-only Totoro receipts are unavailable")
  paths <- sort(list.files(receipts, pattern = "rds$", full.names = TRUE))
  expect_length(paths, 6L)
  records <- lapply(paths, readRDS)
  expect_true(all(vapply(records, function(x) {
    is.list(x) && all(c("result", "summary", "contract") %in% names(x))
  }, logical(1))))
  result <- do.call(rbind, lapply(records, `[[`, "result"))
  expected <- as.vector(outer(c(80L, 160L), 2609221:2609223, paste, sep = ":"))
  expect_setequal(paste(result$n_series, result$seed, sep = ":"), expected)
  expect_true(all(result$terminal == "success"))
  expect_true(all(result$convergence == 0L))
  expect_true(all(result$pass_2_accepted))
})
