test_that("gllvmTMBcontrol d_B/d_W/spde_mode are stored compat fields (#1421)", {
  ctl <- gllvmTMBcontrol(d_B = 2L, d_W = 1L, spde_mode = "shared")
  expect_equal(ctl$d_B, 2L)
  expect_equal(ctl$d_W, 1L)
  expect_equal(ctl$spde_mode, "shared")
})

test_that("check_gllvmTMB help documents INFO status (#1421)", {
  rd_path <- file.path(
    testthat::test_path("..", ".."),
    "man",
    "check_gllvmTMB.Rd"
  )
  skip_if_not(file.exists(rd_path))
  txt <- paste(tools::parse_Rd(rd_path), collapse = "\n")
  expect_match(txt, "INFO")
})
