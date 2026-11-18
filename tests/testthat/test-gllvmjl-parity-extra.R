## Cross-engine parity, second set: gllvmTMB vs GLLVModels.jl reference values
## for models with fixed-effect covariates, a random site effect, a count
## offset, and K = 3. Companion to test-gllvmjl-parity-fixtures.R (plain
## latent-variable models, K = 1, 2); same pinned GLLVModels.jl commit, same
## approach: Julia is not needed to run these tests, they refit stored tables
## with gllvmTMB and compare against stored numbers.
##
## Models, all Laplace, `latent(0 + trait | site, d = K, unique = FALSE)` plus:
##   xcov    `+ x1 + x2` (one coefficient per covariate, shared by all traits);
##           gaussian, poisson, nbinom2, binomial, zip; K = 1, 2.
##   rowre   `+ (1 | site)` (one random intercept per site, shared by all
##           traits; GLLVModels.jl `fit_row_random_gllvm`); poisson, binomial;
##           K = 1, 2.
##   offset  `+ offset(off)` (log exposure that varies by site and trait);
##           poisson, nbinom2; K = 1, 2. GLLVModels.jl wires an offset through
##           `bridge_fit` for Gaussian only and gllvmTMB refuses a Gaussian
##           offset, so the two packages overlap on count families through the
##           native Julia fitters.
##   k3      p = 6 traits, rank-3 data, d = 3; gaussian, poisson.
##
## Not covered because the two packages do not support the same model:
## Gaussian offset (gllvmTMB refuses it), a random site effect for Gaussian
## and NB2 (GLLVModels.jl has one shared dispersion under a row effect;
## gllvmTMB has per-trait dispersion), Tweedie with covariates (no covariate
## route at the pin).
##
## Compared quantities do not depend on the rotation or sign of the latent
## axes: logLik, Lambda Lambda^T, the covariate coefficients (gamma), the
## trait intercepts (beta, where the Julia route reports per-trait ones), the
## random-site-effect SD (sigma_row), and for Gaussian the total Sigma.
## Bands: |delta logLik| < 1e-4; relative max-abs difference < 1e-3 on the
## matrices; max absolute difference < 1e-3 on gamma, beta and sigma_row.
##
## Known mismatches are skipped with the reason and the issue that tracks it.

gllvmjl_commit <- "aed938e1f377a2f584848c5dd100f10f1782b00d"
gllvmjl_dir <- test_path("fixtures", "gllvmjl-parity")

gllvmjl_extra_known_mismatch <- c(
  xcov_zip_K1 = paste(
    "Not the same model: GLLVModels.jl's ZIP covariate route puts the",
    "covariates in the zero-inflation part as well (separate gamma_z); gllvmTMB's",
    "zero part is per-trait intercept only. Julia also stops 22.8 logLik units",
    "below gllvmTMB while reporting converged = true (same pattern as",
    "GLLVModels.jl #739). No issue tracks the model difference."
  ),
  xcov_zip_K2 = paste(
    "Not the same model: GLLVModels.jl's ZIP covariate route puts the",
    "covariates in the zero-inflation part as well (separate gamma_z), so it",
    "nests gllvmTMB's intercept-only zero part and reaches a logLik 0.23 higher",
    "(-747.458 vs -747.686; gllvmTMB gives the same value from 16 start",
    "configurations). No issue tracks the model difference."
  )
)

gllvmjl_extra_cases <- function() {
  meta <- read.csv(file.path(gllvmjl_dir, "reference-extra-meta.csv"),
                   stringsAsFactors = FALSE)
  meta$group <- sub("_.*$", "", meta$case)
  meta
}

gllvmjl_extra_ref <- function() {
  read.csv(file.path(gllvmjl_dir, "reference-extra.csv"),
           stringsAsFactors = FALSE)
}

gllvmjl_extra_matrix <- function(ref, case, quantity) {
  x <- ref[ref$case == case & ref$quantity == quantity, ]
  p <- max(x$i)
  m <- matrix(NA_real_, p, p)
  m[cbind(x$i, x$j)] <- x$value
  m
}

gllvmjl_extra_vec <- function(ref, case, quantity) {
  x <- ref[ref$case == case & ref$quantity == quantity, ]
  x$value[order(x$i)]
}

gllvmjl_extra_family <- function(fam) {
  switch(fam,
    gaussian = gaussian(), poisson = poisson(), nbinom2 = nbinom2(),
    binomial = binomial(), zip = zi_poisson()
  )
}

gllvmjl_extra_fit <- function(group, fam, K) {
  d <- read.csv(file.path(gllvmjl_dir, sprintf("data-%s-%s.csv", group, fam)))
  d$site <- factor(d$site)
  d$trait <- factor(d$trait)
  term <- switch(group,
    xcov = "+ x1 + x2", rowre = "+ (1 | site)", offset = "+ offset(off)",
    k3 = ""
  )
  form <- as.formula(sprintf(
    "y ~ 0 + trait %s + latent(0 + trait | site, d = %d, unique = FALSE)",
    term, K
  ))
  suppressMessages(suppressWarnings(gllvmTMB(
    form, data = d, trait = "trait", unit = "site",
    family = gllvmjl_extra_family(fam)
  )))
}

rel_maxabs <- function(a, b) max(abs(a - b)) / max(abs(b))

test_that("GLLVModels.jl extra parity fixtures are pinned and complete", {
  readme <- readLines(file.path(gllvmjl_dir, "README.md"))
  gen <- readLines(file.path(gllvmjl_dir, "gen-reference-extra.jl"))
  expect_true(any(grepl(gllvmjl_commit, readme, fixed = TRUE)))
  expect_true(any(grepl(gllvmjl_commit, gen, fixed = TRUE)))

  meta <- gllvmjl_extra_cases()
  ref <- gllvmjl_extra_ref()
  expected <- c(
    as.vector(outer(c("gaussian", "poisson", "nbinom2", "binomial", "zip"),
                    1:2, function(f, k) sprintf("xcov_%s_K%d", f, k))),
    as.vector(outer(c("poisson", "binomial"), 1:2,
                    function(f, k) sprintf("rowre_%s_K%d", f, k))),
    as.vector(outer(c("poisson", "nbinom2"), 1:2,
                    function(f, k) sprintf("offset_%s_K%d", f, k))),
    "k3_gaussian_K3", "k3_poisson_K3"
  )
  expect_setequal(meta$case, expected)
  expect_setequal(unique(ref$case), expected)
  expect_true(all(names(gllvmjl_extra_known_mismatch) %in% expected))
  for (case in expected) {
    expect_length(ref$value[ref$case == case & ref$quantity == "loglik"], 1L)
    p <- if (grepl("^k3_", case)) 6L else 5L
    expect_equal(dim(gllvmjl_extra_matrix(ref, case, "LL")), c(p, p))
  }
  expect_true(all(c("xcov", "rowre", "offset", "k3") %in% meta$group))
})

local({
  meta <- gllvmjl_extra_cases()
  for (r in seq_len(nrow(meta))) {
    local({
      case <- meta$case[r]
      group <- meta$group[r]
      fam <- meta$family[r]
      K <- meta$K[r]
      test_that(sprintf("gllvmTMB matches GLLVModels.jl: %s", case), {
        skip_on_cran()
        if (case %in% names(gllvmjl_extra_known_mismatch)) {
          skip(gllvmjl_extra_known_mismatch[[case]])
        }
        ref <- gllvmjl_extra_ref()
        fit <- gllvmjl_extra_fit(group, fam, K)
        expect_identical(fit$opt$convergence, 0L)

        ll_jl <- ref$value[ref$case == case & ref$quantity == "loglik"]
        expect_lt(abs(as.numeric(logLik(fit)) - ll_jl), 1e-4)

        LL_r <- unname(suppressMessages(
          extract_Sigma(fit, level = "unit", part = "shared")
        )$Sigma)
        LL_jl <- gllvmjl_extra_matrix(ref, case, "LL")
        expect_lt(rel_maxabs(LL_r, LL_jl), 1e-3)

        b <- coef(fit)
        gamma_jl <- gllvmjl_extra_vec(ref, case, "gamma")
        if (length(gamma_jl)) {
          expect_lt(max(abs(unname(b[c("x1", "x2")]) - gamma_jl)), 1e-3)
        }
        beta_jl <- gllvmjl_extra_vec(ref, case, "beta")
        if (length(beta_jl)) {
          expect_lt(max(abs(unname(b[grepl("^trait", names(b))]) - beta_jl)),
                    1e-3)
        }
        sigma_row_jl <- gllvmjl_extra_vec(ref, case, "sigma_row")
        if (length(sigma_row_jl)) {
          sigma_row_r <- exp(unname(fit$opt$par["log_sigma_re_int"]))
          expect_lt(abs(sigma_row_r - sigma_row_jl), 1e-3)
        }

        if (fam == "gaussian") {
          Sigma_r <- LL_r + diag(fit$report$sigma_eps[1]^2, nrow(LL_r))
          Sigma_jl <- gllvmjl_extra_matrix(ref, case, "Sigma")
          expect_lt(rel_maxabs(Sigma_r, Sigma_jl), 1e-3)
        }
      })
    })
  }
})
