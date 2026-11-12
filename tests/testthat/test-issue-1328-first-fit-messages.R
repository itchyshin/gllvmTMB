test_that("README explains first-fit console messages (#1328)", {
  readme <- gllvmTMB_pkg_file("README.md")
  text <- paste(readLines(readme, warn = FALSE), collapse = "\n")
  testthat::expect_match(
    text,
    "one-time warning.*per-trait Psi by default",
    info = "README should note the expected latent() Psi warning"
  )
  testthat::expect_match(
    text,
    "latent_unit.*indep_unit",
    info = "README should explain Covstructs internal names"
  )
  testthat::expect_match(
    text,
    "gllvmTMB_diagnose\\(\\).*check_gllvmTMB\\(\\)",
    info = "README should point readers to check_gllvmTMB"
  )
})

test_that("Get-started vignette explains hidden first-fit messages (#1328)", {
  rmd <- gllvmTMB_pkg_file("vignettes", "gllvmTMB.Rmd")
  text <- paste(readLines(rmd, warn = FALSE), collapse = "\n")
  testthat::expect_match(
    text,
    "sigma_eps.*indep\\(0 \\+ trait \\| individual\\)",
    info = "Vignette should explain sigma_eps / indep suppression message"
  )
  testthat::expect_match(
    text,
    "(rotation_convention.*WARN|WARN.*rotation_convention).*Lambda_B",
    info = "Vignette should explain expected rotation WARN on d > 1"
  )
})
