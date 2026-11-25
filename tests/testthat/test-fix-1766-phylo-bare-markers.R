## Issue #1766: bare phylo_latent / phylo_unique / phylo_scalar with a
## non-"species" grouping column must adopt that column when cluster is
## omitted, matching an explicit cluster = "taxon". Phylo bar forms are
## covered in test-fix-1766-phylo-cluster-omit.R.

.phylo_1766_bare_fixture <- function() {
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

.phylo_1766_bare_fit <- function(formula, data, cluster = NULL) {
  ctrl <- gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE)
  args <- list(
    formula = formula,
    data = data,
    trait = "trait",
    unit = "unit",
    control = ctrl,
    silent = TRUE
  )
  if (!is.null(cluster)) {
    args$cluster <- cluster
  }
  suppressMessages(suppressWarnings(do.call(gllvmTMB::gllvmTMB, args)))
}

test_that("phylo_latent(taxon, ...) fits without cluster (#1766)", {
  skip_on_cran()
  fx <- .phylo_1766_bare_fixture()
  K <- fx$K
  f <- value ~ 0 + trait + phylo_latent(taxon, d = 1, vcv = K)
  fit_omit <- .phylo_1766_bare_fit(f, fx$df)
  fit_cluster <- .phylo_1766_bare_fit(f, fx$df, cluster = "taxon")
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-6
  )
})

test_that("phylo_unique(taxon, ...) fits without cluster (#1766)", {
  skip_on_cran()
  fx <- .phylo_1766_bare_fixture()
  K <- fx$K
  f <- value ~ 0 + trait + phylo_unique(taxon, vcv = K)
  fit_omit <- .phylo_1766_bare_fit(f, fx$df)
  fit_cluster <- .phylo_1766_bare_fit(f, fx$df, cluster = "taxon")
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-6
  )
})

test_that("phylo_scalar(taxon, ...) fits without cluster (#1766)", {
  skip_on_cran()
  fx <- .phylo_1766_bare_fixture()
  K <- fx$K
  f <- value ~ 0 + trait + phylo_scalar(taxon, vcv = K)
  fit_omit <- .phylo_1766_bare_fit(f, fx$df)
  fit_cluster <- .phylo_1766_bare_fit(f, fx$df, cluster = "taxon")
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-6
  )
})

test_that("named species = taxon resolves when cluster is omitted (#1766)", {
  skip_on_cran()
  fx <- .phylo_1766_bare_fixture()
  K <- fx$K
  f <- value ~ 0 + trait + phylo_latent(d = 1, vcv = K, species = taxon)
  fit_omit <- .phylo_1766_bare_fit(f, fx$df)
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
})

test_that("a phylo vcv mismatch names phylo_vcv, not placeholder (#1766)", {
  skip_on_cran()
  fx <- .phylo_1766_bare_fixture()
  K_bad <- fx$K[-1L, -1L, drop = FALSE]
  f <- value ~ 0 + trait + phylo_latent(taxon, d = 1, vcv = K_bad)
  err <- tryCatch(
    .phylo_1766_bare_fit(f, fx$df),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "phylo_vcv")
  expect_match(msg, "t1")
  expect_no_match(msg, "placeholder")
})