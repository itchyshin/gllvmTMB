## Issue #1766: phylo_*(taxon, ...) with cluster omitted must group by taxon,
## not by a placeholder species column.

.fix1766_layout <- function() {
  set.seed(1766)
  taxa <- paste0("tx", 1:4)
  df <- expand.grid(
    plot = factor(paste0("p", 1:5)),
    taxon = factor(taxa),
    trait = factor(c("a", "b")),
    KEEP.OUT.ATTRS = FALSE
  )
  df$value <- stats::rnorm(nrow(df))
  K <- diag(length(taxa))
  dimnames(K) <- list(taxa, taxa)
  list(df = df, K = K, taxa = taxa)
}

.fix1766_control <- function() {
  gllvmTMBcontrol(n_init = 1L, se = FALSE, laplace_auto_refit = FALSE)
}

test_that("phylo_latent(taxon) fits without cluster and matches cluster = taxon (#1766)", {
  fx <- .fix1766_layout()
  K <- fx$K
  ctrl <- .fix1766_control()
  fit_omit <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(taxon, d = 1, vcv = K),
    data = fx$df, unit = "plot", trait = "trait",
    control = ctrl, silent = TRUE
  )
  fit_cluster <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(taxon, d = 1, vcv = K),
    data = fx$df, unit = "plot", trait = "trait", cluster = "taxon",
    control = ctrl, silent = TRUE
  )
  expect_s3_class(fit_omit, "gllvmTMB")
  expect_equal(fit_omit$opt$convergence, 0L)
  expect_equal(fit_cluster$opt$convergence, 0L)
  expect_equal(
    as.numeric(stats::logLik(fit_omit)),
    as.numeric(stats::logLik(fit_cluster)),
    tolerance = 1e-8
  )
})

test_that("phylo_indep(0 + trait | taxon) fits without cluster (#1766)", {
  fx <- .fix1766_layout()
  K <- fx$K
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | taxon, vcv = K),
    data = fx$df, unit = "plot", trait = "trait",
    control = .fix1766_control(), silent = TRUE
  )
  expect_s3_class(fit, "gllvmTMB")
  expect_equal(fit$opt$convergence, 0L)
})

test_that("a missing non-species phylo grouping names that column (#1766)", {
  fx <- .fix1766_layout()
  K <- fx$K
  df <- fx$df
  df$taxon <- NULL
  err <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + phylo_latent(taxon, d = 1, vcv = K),
      data = df, unit = "plot", trait = "trait",
      control = .fix1766_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_phylo_grouping")
  expect_match(conditionMessage(err), "groups by .taxon.")
  expect_no_match(conditionMessage(err), "placeholder")
})

test_that("phylo_latent(species) with a bad vcv still names phylo_vcv (#1766)", {
  sp <- paste0("sp", seq_len(4L))
  K <- diag(4L)
  rownames(K) <- colnames(K) <- sp
  K_bad <- K[1:3, 1:3, drop = FALSE]
  df <- data.frame(
    unit = factor(rep(sp, 2L), levels = sp),
    species = factor(rep(sp, 2L), levels = sp),
    trait = factor(rep(c("t1", "t2"), each = 4L)),
    value = stats::rnorm(8L)
  )
  err <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1, vcv = K_bad),
      data = df, unit = "unit", trait = "trait",
      control = .fix1766_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_false(inherits(err, "gllvmTMB_phylo_grouping"))
  msg <- conditionMessage(err)
  expect_match(msg, "phylo_vcv")
  expect_match(msg, "sp4")
})
