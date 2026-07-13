## extract_Sigma(fit, level = "phy") returns the trait-stacked (intercept, slope)
## covariance Sigma_b for the dep/indep augmented-slope engine, including the `||`
## uncorrelated cells. The returned MATRIX encodes the mode via its structural
## zeros; the accompanying note describes them (not a blanket "full unstructured").

skip_heavy_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  if (!identical(Sys.getenv("GLLVMTMB_HEAVY_TESTS"), "1")) {
    testthat::skip("heavy recovery test; set GLLVMTMB_HEAVY_TESTS=1 to run")
  }
}

.fit_phy <- function(fx, mode, cp) suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  stats::as.formula(sprintf("value ~ 0 + trait + phylo_%s(1 + x %s species)", mode, cp)),
  data = fx$df, phylo_tree = fx$tree, unit = "species", cluster = "species",
  family = stats::gaussian())))

.load_fixture <- function() {
  ex <- parse(test_path("test-phylo-indep-slope-gaussian.R"))
  for (e in ex) if (is.call(e) && identical(e[[1]], as.name("<-")) &&
      identical(e[[2]], as.name("make_gaussian_indep_slope_fixture")))
    eval(e, envir = environment())
  make_gaussian_indep_slope_fixture
}

.int_slope_max <- function(m) {
  T <- nrow(m) / 2L; pos <- seq_len(2L * T)
  cross <- subset(expand.grid(i = pos, j = pos), i < j & (i %% 2) != (j %% 2))
  max(abs(mapply(function(i, j) m[i, j], cross$i, cross$j)))
}
.cross_trait_max <- function(m) {
  ## interleaved (int_t, slope_t): trait of position p is ceiling(p/2)
  T <- nrow(m) / 2L; pos <- seq_len(2L * T); tr <- ((pos - 1L) %/% 2L) + 1L
  ct <- subset(expand.grid(i = pos, j = pos), i < j)
  ct <- ct[tr[ct$i] != tr[ct$j], ]
  max(abs(mapply(function(i, j) m[i, j], ct$i, ct$j)))
}

test_that("extract_Sigma(level='phy') on indep|| is fully diagonal", {
  skip_heavy_ape()
  fx <- .load_fixture()(seed = 1L)
  s <- gllvmTMB::extract_Sigma(.fit_phy(fx, "indep", "||"), level = "phy")
  m <- as.matrix(s$Sigma)
  expect_equal(dim(m), c(6L, 6L))
  expect_lt(.int_slope_max(m), 1e-6)     # intercept _|_ slope
  expect_lt(.cross_trait_max(m), 1e-6)   # no cross-trait covariance (indep)
  expect_match(rownames(m)[1], "intercept")
})

test_that("extract_Sigma(level='phy') on dep|| is Sigma_int (+) Sigma_slope", {
  skip_heavy_ape()
  fx <- .load_fixture()(seed = 1L)
  s <- gllvmTMB::extract_Sigma(.fit_phy(fx, "dep", "||"), level = "phy")
  m <- as.matrix(s$Sigma)
  expect_lt(.int_slope_max(m), 1e-6)     # intercept _|_ slope
  expect_gt(.cross_trait_max(m), 0.02)   # cross-trait covariance FREE
  ## the note describes the block structure, not a blanket "full unstructured".
  expect_match(s$note, "Sigma_intercept")
  expect_match(s$note, "block-diagonal")
})
