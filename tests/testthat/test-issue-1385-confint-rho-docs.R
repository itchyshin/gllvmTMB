test_that("rho parm parser accepts cluster tiers (#1385)", {
  trait_names <- c("t1", "t2", "t3")
  parsed <- gllvmTMB:::.parse_rho_parm("rho:cluster2:1,2", trait_names)
  expect_equal(parsed$tier, "cluster2")
  expect_equal(parsed$pairs, matrix(c(1L, 2L), nrow = 1L))
})
