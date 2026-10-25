## #1373: a dense user-supplied vcv / phylo_vcv must be checked for positive
## semidefiniteness before it is jittered, inverted and its log-determinant
## taken. The indefinite AR(1) matrix below has minimum eigenvalue -0.98.

make_psd_fixture <- function(bad = FALSE) {
  set.seed(3)
  ns <- 12L
  nt <- 3L
  sp <- paste0("sp", seq_len(ns))
  K <- 0.6^abs(outer(seq_len(ns), seq_len(ns), "-"))
  dimnames(K) <- list(sp, sp)
  if (bad) {
    K[1, 2] <- K[2, 1] <- -0.99
    K[1, 3] <- K[3, 1] <- 0.99
    K[2, 3] <- K[3, 2] <- 0.99
  }
  d <- expand.grid(
    species = factor(sp, levels = sp),
    trait = factor(paste0("t", seq_len(nt))),
    KEEP.OUT.ATTRS = FALSE
  )
  d$site <- factor(d$species)
  d$value <- rnorm(nrow(d))
  d$x <- rnorm(nrow(d))
  list(K = K, data = d)
}

test_that("fixture matrix is indefinite (min eigenvalue about -0.98)", {
  fx <- make_psd_fixture(bad = TRUE)
  expect_lt(
    min(eigen(fx$K, symmetric = TRUE, only.values = TRUE)$values),
    -0.9
  )
})

test_that("phylo_scalar(vcv = indefinite) aborts naming vcv and positive semidefinite", {
  fx <- make_psd_fixture(bad = TRUE)
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_scalar(species, vcv = fx$K),
      data = fx$data, unit = "site", trait = "trait", cluster = "species",
      family = gaussian(), control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ))),
    "positive semidefinite"
  )
})

test_that("phylo_latent(vcv = indefinite) aborts naming vcv and positive semidefinite", {
  fx <- make_psd_fixture(bad = TRUE)
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1, vcv = fx$K, unique = FALSE),
      data = fx$data, family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ))),
    "positive semidefinite"
  )
})

test_that("phylo_slope(vcv = indefinite) aborts naming vcv and positive semidefinite", {
  fx <- make_psd_fixture(bad = TRUE)
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_slope(x | species, vcv = fx$K),
      data = fx$data, unit = "species", family = gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    ))),
    "positive semidefinite"
  )
})

test_that("phylo_scalar(vcv = valid AR(1)) still fits normally", {
  fx <- make_psd_fixture(bad = FALSE)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species, vcv = fx$K),
    data = fx$data, unit = "site", trait = "trait", cluster = "species",
    family = gaussian(), control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
  expect_true(is.finite(as.numeric(logLik(fit))))
  expect_lt(abs(as.numeric(logLik(fit))), 1e6)
  expect_equal(fit$opt$convergence, 0L)
})
