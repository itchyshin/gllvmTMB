## #1765: omitted cluster on animal_* adopts the id column named in the keyword.

.animal_1765_fixture <- function(n_ind = 12L, n_traits = 2L, seed = 7L) {
  set.seed(seed)
  ped <- data.frame(
    id = paste0("i", seq_len(n_ind)),
    sire = c(rep(NA, 4L), rep(c("i1", "i2"), length.out = n_ind - 4L)),
    dam = c(rep(NA, 4L), rep(c("i3", "i4"), length.out = n_ind - 4L)),
    stringsAsFactors = FALSE
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  yvec <- as.numeric(MASS::mvrnorm(
    1,
    mu = rep(0, n_traits * n_ind),
    Sigma = kronecker(diag(n_traits), A) * 0.5 + diag(n_traits * n_ind) * 0.5
  ))
  df <- data.frame(
    individual = factor(rep(ped$id, each = n_traits), levels = ped$id),
    trait = factor(
      rep(paste0("t", seq_len(n_traits)), times = n_ind),
      levels = paste0("t", seq_len(n_traits))
    ),
    value = yvec
  )
  list(data = df, ped = ped)
}

test_that("animal_scalar(individual) fits without cluster and matches cluster = individual (#1765)", {
  skip_on_cran()
  fx <- .animal_1765_fixture()
  df <- fx$data
  df$unit <- df$individual
  ctrl <- gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE)
  fit_omit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(individual, pedigree = fx$ped),
    data = df, trait = "trait", unit = "unit",
    control = ctrl, silent = TRUE
  )))
  fit_cluster <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(individual, pedigree = fx$ped),
    data = df, trait = "trait", unit = "unit", cluster = "individual",
    control = ctrl, silent = TRUE
  )))
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-6
  )
})