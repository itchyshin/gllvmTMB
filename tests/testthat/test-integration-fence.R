test_that("gllvmTMBcontrol gains integration, defaulting to laplace", {
  expect_identical(gllvmTMBcontrol()$integration, "laplace")
  expect_identical(gllvmTMBcontrol(integration = "va")$integration, "va")
  expect_identical(gllvmTMBcontrol(integration = "eva")$integration, "eva")
  expect_error(gllvmTMBcontrol(integration = "nope"))
})

test_that("AGHQ and a variational route cannot be requested together", {
  ## They are alternative evaluations of the same integral, not layers.
  expect_error(gllvmTMBcontrol(integration = "va", aghq = TRUE), "cannot be combined")
  expect_error(gllvmTMBcontrol(integration = "eva", aghq = TRUE), "cannot be combined")
  expect_no_error(gllvmTMBcontrol(integration = "laplace", aghq = TRUE))
  expect_no_error(gllvmTMBcontrol(integration = "va", aghq = FALSE))
})

test_that("the fence is a no-op for laplace", {
  expect_true(.gllvmTMB_check_integration_fence(
    "laplace", family = "gaussian", q = 99L, p = 999L, n = 2L, unique = TRUE,
    engine = "julia"
  ))
})

test_that("the fence admits an in-region variational fit", {
  expect_true(.gllvmTMB_check_integration_fence(
    "va", family = "binomial", link = "logit", q = 2L, p = 20L, n = 100L
  ))
  expect_true(.gllvmTMB_check_integration_fence(
    "va", family = "poisson", link = "log", q = 4L, p = 80L, n = 400L
  ))
})

test_that("the fence errors, rather than warns, outside every boundary", {
  ok <- list(integration = "va", family = "binomial", link = "logit",
             q = 2L, p = 20L, n = 100L)
  bad <- function(...) do.call(.gllvmTMB_check_integration_fence,
                               utils::modifyList(ok, list(...)))

  expect_error(bad(n = 40L), "below the evidenced minimum")
  expect_error(bad(q = 6L), "exceeds the evidenced maximum")
  expect_error(bad(p = 200L), "exceeds the evidenced maximum")
  expect_error(bad(unique = TRUE), "Psi")
  expect_error(bad(family = "gaussian"), "no admitted variational evaluation")
  expect_error(bad(link = "probit"), "not admitted for family")
  expect_error(bad(engine = "julia"), "no variational route")
})

test_that("n = 40 is refused because the measurement says so, not by taste", {
  ## Recomputed from dev/totoro-grid/results/grid.csv: the GH arm's signed
  ## scale tr(Sigma_hat)/tr(Sigma_true) is 4.302 at n = 40.
  expect_error(
    .gllvmTMB_check_integration_fence("va", family = "binomial", link = "logit",
                                      q = 2L, p = 20L, n = 40L),
    "disqualified"
  )
  expect_true(
    .gllvmTMB_check_integration_fence("va", family = "binomial", link = "logit",
                                      q = 2L, p = 20L, n = 100L)
  )
})

test_that("a variational request never silently returns a Laplace fit", {
  ## The failure this guards against is not an error, it is a SUCCESS that
  ## quietly ignored the argument -- the caller keeps a Laplace fit believing
  ## it is variational. Requesting one must either work or abort, never fall
  ## back.
  set.seed(1L)
  n <- 120L; p <- 6L
  Y <- matrix(rbinom(n * p, 1L, 0.5), n, p)
  df <- data.frame(y = as.numeric(t(Y)),
                   trait = factor(rep(seq_len(p), times = n)),
                   site  = factor(rep(seq_len(n), each = p)))
  fml <- y ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE)

  expect_error(
    gllvmTMB(fml, data = df, family = stats::binomial(), unit = "site",
             control = gllvmTMBcontrol(integration = "va")),
    "not yet routed"
  )
  ## …and the out-of-region case fails on the FENCE, not on the routing stub,
  ## so the more specific complaint is the one the user sees.
  expect_error(
    gllvmTMB(fml, data = df, family = stats::binomial(), unit = "site",
             engine = "julia",
             control = gllvmTMBcontrol(integration = "va")),
    "no variational route"
  )
})
