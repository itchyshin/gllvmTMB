test_that("metadata-only Gate A holds BBS/GBIF out of the frozen PA law", {
  env <- new.env(parent = globalenv())
  source(isdm_dev_path("empirical-gate-a-metadata-contract.R"), local = env)
  contract <- env$empirical_gate_a_template()
  decision <- env$empirical_gate_a_assess(contract)
  expect_silent(env$empirical_gate_a_validate(decision))
  expect_true(decision$descriptive_qa)
  expect_false(decision$observation_law_admitted)
  expect_false(decision$empirical_fit_admitted)
  expect_identical(decision$decision, "HOLD_FOR_FIT_AND_DOWNLOAD")
})
test_that("metadata-only Gate A helper cannot request data or fit a model", {
  path <- isdm_dev_path("empirical-gate-a-metadata-contract.R")
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")
  expect_false(grepl("download\\s*\\(|occurrence_\\w*\\s*\\(|MakeADFun\\(|\\.gll_isdm_fit\\(|nlminb\\(|optim\\(|profile\\(",
                     text, ignore.case = TRUE))
})
