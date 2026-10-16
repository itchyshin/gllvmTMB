## Issues #1373 and #1372: a user-supplied dense phylogenetic covariance.
##  #1373: an indefinite `vcv` was inverted with no positive-definite check
##         and returned a fit with logLik ~ 7.7e15.
##  #1372: a per-term `vcv = K1` was silently dropped when `phylo_vcv = K2`
##         was also given and the sizes matched.

.vcv_1372 <- function(ns = 12L, rho = 0.6) {
  sp <- paste0("sp", seq_len(ns))
  K <- rho^abs(outer(seq_len(ns), seq_len(ns), "-"))
  dimnames(K) <- list(sp, sp)
  K
}

.dat_1372 <- function(ns = 12L, nt = 3L, seed = 3L) {
  set.seed(seed)
  sp <- paste0("sp", seq_len(ns))
  d <- expand.grid(species = factor(sp, levels = sp),
                   trait = factor(paste0("t", seq_len(nt))),
                   KEEP.OUT.ATTRS = FALSE)
  d$site <- factor(d$species)
  d$value <- rnorm(nrow(d))
  d
}

.fit_1372 <- function(formula, d, ...) {
  suppressMessages(gllvmTMB(
    formula, data = d, unit = "site", trait = "trait", cluster = "species",
    family = gaussian(), control = gllvmTMBcontrol(se = FALSE), ...
  ))
}

test_that("#1373 helper: PD passes, indefinite and non-finite abort naming the argument", {
  K <- .vcv_1372()
  expect_silent(.gllvmTMB_assert_pd_vcv(K + diag(1e-8, nrow(K)), "phylo_vcv"))
  Kbad <- K
  Kbad[1, 2] <- Kbad[2, 1] <- -0.99
  Kbad[1, 3] <- Kbad[3, 1] <- 0.99
  Kbad[2, 3] <- Kbad[3, 2] <- 0.99
  expect_lt(min(eigen(Kbad, symmetric = TRUE, only.values = TRUE)$values), -0.9)
  expect_error(.gllvmTMB_assert_pd_vcv(Kbad + diag(1e-8, nrow(K)), "phylo_vcv"),
               "phylo_vcv.*positive semidefinite")
  Kna <- K; Kna[1, 1] <- NA
  expect_error(.gllvmTMB_assert_pd_vcv(Kna, "phylo_vcv"), "non-finite")
  ## a singular PSD matrix (a tree-like rank deficiency) is fine after jitter
  Ks <- matrix(1, 4, 4, dimnames = list(letters[1:4], letters[1:4]))
  expect_silent(.gllvmTMB_assert_pd_vcv(Ks + diag(1e-8, 4), "phylo_vcv"))
})

test_that("#1373: an indefinite phylo_scalar(vcv =) is refused, not fitted", {
  skip_on_cran()
  K <- .vcv_1372()
  Kbad <- K
  Kbad[1, 2] <- Kbad[2, 1] <- -0.99
  Kbad[1, 3] <- Kbad[3, 1] <- 0.99
  Kbad[2, 3] <- Kbad[3, 2] <- 0.99
  d <- .dat_1372()
  expect_error(
    .fit_1372(value ~ 0 + trait + phylo_scalar(species, vcv = Kbad), d),
    "positive semidefinite"
  )
  ## the valid matrix still fits
  r <- .fit_1372(value ~ 0 + trait + phylo_scalar(species, vcv = K), d)
  expect_true(is.finite(as.numeric(logLik(r))))
})

test_that("#1373: an indefinite phylo_latent vcv is refused", {
  skip_on_cran()
  K <- .vcv_1372()
  Kbad <- K
  Kbad[1, 2] <- Kbad[2, 1] <- -0.99
  Kbad[1, 3] <- Kbad[3, 1] <- 0.99
  Kbad[2, 3] <- Kbad[3, 2] <- 0.99
  d <- .dat_1372()
  expect_error(
    .fit_1372(value ~ 0 + trait + phylo_latent(species, d = 1, vcv = Kbad), d),
    "positive semidefinite"
  )
})

test_that("#1372 helper: same matrix is recognised by name, different one is not", {
  K1 <- .vcv_1372(rho = 0.3); K2 <- .vcv_1372(rho = 0.9)
  expect_true(.gllvmTMB_same_vcv(K1, K1))
  expect_true(.gllvmTMB_same_vcv(K1, K1[rev(rownames(K1)), rev(rownames(K1))]))
  expect_false(.gllvmTMB_same_vcv(K1, K2))
  expect_false(.gllvmTMB_same_vcv(K1, K1[1:5, 1:5]))
})

test_that("#1372: per-term vcv differing from phylo_vcv is refused, equal ones fit", {
  skip_on_cran()
  K1 <- .vcv_1372(rho = 0.3); K2 <- .vcv_1372(rho = 0.9)
  d <- .dat_1372()
  expect_error(
    .fit_1372(value ~ 0 + trait + phylo_scalar(species, vcv = K1), d,
              phylo_vcv = K2),
    "differs from the .*phylo_vcv"
  )
  ## agreeing inputs are accepted
  r <- .fit_1372(value ~ 0 + trait + phylo_scalar(species, vcv = K1), d,
                 phylo_vcv = K1)
  expect_true(is.finite(as.numeric(logLik(r))))
})
