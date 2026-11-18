## Cross-engine parity: gllvmTMB vs GLLVModels.jl reference fixtures.
##
## The fixtures (tests/testthat/fixtures/gllvmjl-parity/, see README.md there)
## hold six simulated long-format tables and the values GLLVModels.jl returns
## for them at a pinned commit. Julia is not needed to run these tests: they
## refit each table with gllvmTMB and compare against the stored numbers.
##
## Model on both sides, K = 1 and 2, Laplace:
##   y ~ 0 + trait + latent(0 + trait | site, d = K, unique = FALSE)
##
## Compared quantities do not depend on the rotation or sign of the latent
## axes: the log-likelihood, Lambda Lambda^T, and for Gaussian the total
## Sigma = Lambda Lambda^T + sigma_eps^2 I.
##
## Agreement band. Both engines maximise the same Laplace marginal on the
## same bytes, so this is a numerical check. Observed agreement on the eight
## passing cases is at most 1.3e-7 on logLik and 4.1e-5 (relative max-abs) on
## Lambda Lambda^T. The bands below (1e-4 on logLik, 1e-3 relative on the
## matrices) leave room for optimiser and BLAS jitter while still failing on
## any different optimum.
##
## Known mismatches are skipped with the reason and the issue that tracks it.

gllvmjl_commit <- "aed938e1f377a2f584848c5dd100f10f1782b00d"
gllvmjl_dir <- test_path("fixtures", "gllvmjl-parity")

gllvmjl_known_mismatch <- c(
  nbinom2_K2 = paste(
    "gllvmTMB stops 0.70 logLik units below GLLVModels.jl with the NB2 size",
    "for traits 3 and 5 at the Poisson boundary (phi ~ 1e9, 3e7); n_init = 8",
    "lands on the same point. gllvmTMB #1710."
  ),
  binomial_K2 = paste(
    "GLLVModels.jl returns converged = false with runaway loadings",
    "(max Lambda Lambda^T ~ 5.9e3) and a logLik 15.4 above gllvmTMB's proper",
    "fit; Julia has no runaway-loading detector. GLLVModels.jl #498."
  ),
  zip_K1 = paste(
    "GLLVModels.jl fit_zip_gllvm reports converged = true 7.94 logLik units",
    "below gllvmTMB. GLLVModels.jl #739."
  ),
  tweedie_K1 = paste(
    "GLLVModels.jl returns loglik = -Inf, converged = false (Laplace marginal",
    "not evaluable at any accepted point). GLLVModels.jl #1042."
  )
)

gllvmjl_ref <- function() {
  read.csv(file.path(gllvmjl_dir, "reference.csv"), stringsAsFactors = FALSE)
}

gllvmjl_ref_matrix <- function(ref, case, quantity) {
  x <- ref[ref$case == case & ref$quantity == quantity, ]
  p <- max(x$i)
  m <- matrix(NA_real_, p, p)
  m[cbind(x$i, x$j)] <- x$value
  m
}

gllvmjl_family <- function(fam) {
  switch(fam,
    gaussian = gaussian(), poisson = poisson(), nbinom2 = nbinom2(),
    binomial = binomial(), zip = zi_poisson(), tweedie = tweedie()
  )
}

gllvmjl_fit <- function(fam, K) {
  d <- read.csv(file.path(gllvmjl_dir, sprintf("data-%s.csv", fam)))
  d$site <- factor(d$site)
  d$trait <- factor(d$trait)
  form <- as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)", K
  ))
  suppressMessages(suppressWarnings(gllvmTMB(
    form, data = d, trait = "trait", unit = "site", family = gllvmjl_family(fam)
  )))
}

rel_maxabs <- function(a, b) max(abs(a - b)) / max(abs(b))

test_that("GLLVModels.jl parity fixtures are pinned and complete", {
  readme <- readLines(file.path(gllvmjl_dir, "README.md"))
  gen <- readLines(file.path(gllvmjl_dir, "gen-reference.jl"))
  expect_true(any(grepl(gllvmjl_commit, readme, fixed = TRUE)))
  expect_true(any(grepl(gllvmjl_commit, gen, fixed = TRUE)))

  ref <- gllvmjl_ref()
  meta <- read.csv(file.path(gllvmjl_dir, "reference-meta.csv"))
  cases <- as.vector(outer(
    c("gaussian", "poisson", "nbinom2", "binomial", "zip", "tweedie"),
    1:2, function(f, k) sprintf("%s_K%d", f, k)
  ))
  expect_setequal(meta$case, cases)
  expect_setequal(unique(ref$case), cases)
  expect_true(all(names(gllvmjl_known_mismatch) %in% cases))
  for (case in cases) {
    expect_length(ref$value[ref$case == case & ref$quantity == "loglik"], 1L)
    expect_equal(dim(gllvmjl_ref_matrix(ref, case, "LL")), c(5L, 5L))
  }
})

for (fam in c("gaussian", "poisson", "nbinom2", "binomial", "zip", "tweedie")) {
  for (K in 1:2) {
    local({
      fam <- fam
      K <- K
      case <- sprintf("%s_K%d", fam, K)
      test_that(sprintf("gllvmTMB matches GLLVModels.jl: %s", case), {
        skip_on_cran()
        if (case %in% names(gllvmjl_known_mismatch)) {
          skip(gllvmjl_known_mismatch[[case]])
        }
        ref <- gllvmjl_ref()
        fit <- gllvmjl_fit(fam, K)
        expect_identical(fit$opt$convergence, 0L)

        ll_jl <- ref$value[ref$case == case & ref$quantity == "loglik"]
        expect_lt(abs(as.numeric(logLik(fit)) - ll_jl), 1e-4)

        LL_r <- unname(suppressMessages(
          extract_Sigma(fit, level = "unit", part = "shared")
        )$Sigma)
        LL_jl <- gllvmjl_ref_matrix(ref, case, "LL")
        expect_lt(rel_maxabs(LL_r, LL_jl), 1e-3)

        if (fam == "gaussian") {
          Sigma_r <- LL_r + diag(fit$report$sigma_eps[1]^2, nrow(LL_r))
          Sigma_jl <- gllvmjl_ref_matrix(ref, case, "Sigma")
          expect_lt(rel_maxabs(Sigma_r, Sigma_jl), 1e-3)
        }
      })
    })
  }
}
