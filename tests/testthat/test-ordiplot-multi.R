## Tests for S3 dispatch of ordiplot() on gllvmTMB_multi fits.
##
## Background: when the `gllvm` package is loaded alongside
## `gllvmTMB`, `gllvm::ordiplot` (an S3 generic) masks
## `gllvmTMB::ordiplot`. Without a registered `ordiplot.gllvmTMB_multi`
## method, the multi-response render of vignettes/articles/
## morphometric-phylogeny.Rmd dies with
##   "no applicable method for 'ordiplot' applied to an object
##    of class 'c(\"gllvmTMB_multi\", \"gllvmTMB\")'".
##
## These tests confirm the S3 dispatch path works regardless of load
## order (always with the gllvm generic on top, mirroring the article
## environment most exposed to the bug).

# ---- helpers --------------------------------------------------------------

make_multi_rrB <- function(seed = 1, d = 2, n_traits = 3) {
  set.seed(seed)
  Lam <- matrix(c(1.0, 0.5, -0.4, 0.3,
                  0.0, 0.8, 0.4, -0.2,
                  0.5, -0.2, 0.6, 0.1)[seq_len(n_traits * d)],
                n_traits, d)
  sim <- simulate_site_trait(
    n_sites = 25, n_species = 5, n_traits = n_traits,
    mean_species_per_site = 3,
    Lambda_B = Lam, S_B = rep(0.3, n_traits), seed = seed
  )
  fmla <- stats::as.formula(sprintf(
    "value ~ 0 + trait + latent(0 + trait | site, d = %d)",
    d
  ))
  suppressMessages(suppressWarnings(gllvmTMB(fmla, data = sim$data)))
}

# ---- S3 dispatch tests ----------------------------------------------------

test_that("ordiplot.gllvmTMB_multi is registered as an S3 method", {
  ## The method must be discoverable by getS3method() so that the
  ## gllvm::ordiplot generic — which calls UseMethod("ordiplot") —
  ## finds it for objects of class c("gllvmTMB_multi", "gllvmTMB").
  m <- getS3method("ordiplot", "gllvmTMB_multi", optional = TRUE)
  expect_false(is.null(m), info = "ordiplot.gllvmTMB_multi must be registered.")
})

test_that("ordiplot() dispatches to ordiplot.gllvmTMB_multi for multi fits", {
  fit <- make_multi_rrB(seed = 5, d = 2)
  expect_s3_class(fit, "gllvmTMB_multi")

  pdf(NULL); on.exit(dev.off(), add = TRUE)
  ## ordiplot is now a gllvmTMB-defined S3 generic; calling it on a
  ## multi-class fit must dispatch (no longer fall through as a regular
  ## function call). Before the fix this was a regular function so
  ## the check below couldn't even be expressed. We assert the call
  ## runs without "no applicable method" errors.
  expect_no_error(
    out <- suppressWarnings(suppressMessages(
      ordiplot(fit, level = "unit", biplot = TRUE)
    ))
  )
})

test_that("ordiplot.gllvmTMB_multi is registered against the gllvm generic too", {
  ## Cross-package S3 registration: when the user has gllvm loaded
  ## (which exports its own `ordiplot` S3 generic that masks ours),
  ## dispatch via gllvm::ordiplot must still find our method. The
  ## NAMESPACE directive `if (requireNamespace("gllvm", quietly = TRUE))
  ## S3method(gllvm::ordiplot, gllvmTMB_multi)` puts the method into
  ## gllvm's S3 table at install time when gllvm is available.
  ##
  ## This test runs the check only if the installed gllvmTMB has
  ## successfully shipped that registration AND gllvm is available
  ## in the current session. With devtools::load_all() the rawNamespace
  ## directive is honoured the same as with library() (R-exts §1.1.5).
  skip_if_not_installed("gllvm")
  ord_env <- asNamespace("gllvm")$.__S3MethodsTable__.
  expect_true(
    "ordiplot.gllvmTMB_multi" %in% names(ord_env),
    info = paste0(
      "ordiplot.gllvmTMB_multi must be registered in gllvm's S3 table ",
      "via the rawNamespace directive in NAMESPACE."
    )
  )
})

test_that("ordiplot.gllvmTMB_multi returns scores + loadings list", {
  fit <- make_multi_rrB(seed = 7, d = 2)
  pdf(NULL); on.exit(dev.off(), add = TRUE)
  out <- suppressWarnings(suppressMessages(
    ordiplot(fit, level = "unit", biplot = TRUE)
  ))
  expect_type(out, "list")
  expect_named(out, c("scores", "loadings"))
  expect_equal(ncol(out$scores), 2L)
  expect_equal(ncol(out$loadings), 2L)
  expect_equal(nrow(out$loadings), fit$n_traits)
})
