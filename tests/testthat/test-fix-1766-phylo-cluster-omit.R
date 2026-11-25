## #1766: omitted cluster on phylo_* adopts the column named in the keyword.

.phylo_1766_fixture <- function() {
  set.seed(4)
  n <- 10L
  p <- 2L
  taxa <- paste0("t", seq_len(n))
  K <- matrix(0.7, n, n)
  diag(K) <- 1
  rownames(K) <- colnames(K) <- taxa
  y <- MASS::mvrnorm(n, mu = rep(0, p), Sigma = diag(0.3, p)) +
    matrix(rnorm(n * p, sd = 0.25), n, p)
  df <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    taxon = factor(rep(taxa, each = p), levels = taxa),
    trait = factor(rep(paste0("v", seq_len(p)), times = n)),
    value = as.vector(y)
  )
  list(df = df, K = K)
}

test_that("phylo_indep(0 + trait | taxon, vcv = K) fits without cluster (#1766)", {
  skip_on_cran()
  fx <- .phylo_1766_fixture()
  ctrl <- gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE)
  fit_omit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | taxon, vcv = fx$K),
    data = fx$df, trait = "trait", unit = "unit",
    control = ctrl, silent = TRUE
  )))
  fit_cluster <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | taxon, vcv = fx$K),
    data = fx$df, trait = "trait", unit = "unit", cluster = "taxon",
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