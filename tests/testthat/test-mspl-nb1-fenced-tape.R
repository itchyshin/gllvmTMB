## Curie-nb1: fenced NB1 LA-MSPL tape.
## Public estimator="mspl" must still error. No planned/admitted nbinom1 row.
## After the C++ hook exists, src/gllvmTMB.cpp must name family_id == 15 and
## pin NB1 as PMF-summed exact I, NOT quasi W=mu/(1+phi).
## Kill: "Poisson worked so NB does."
## Do not edit the shared test-mspl-fenced-family-tapes.R.

.mspl_nb1_fence_dat <- function() {
  n_site <- 8L
  n_trait <- 3L
  data.frame(
    site = factor(rep(seq_len(n_site), each = n_trait)),
    trait = factor(rep(paste0("t", seq_len(n_trait)), n_site)),
    y = rep(0:3, length.out = n_site * n_trait)
  )
}

.mspl_nb1_read_cpp <- function() {
  cpp <- paste(
    readLines(system.file("..", "src", "gllvmTMB.cpp", package = "gllvmTMB")),
    collapse = "\n"
  )
  if (!nzchar(cpp) || identical(cpp, "\n")) {
    cpp <- paste(
      readLines(testthat::test_path("../../src/gllvmTMB.cpp")),
      collapse = "\n"
    )
  }
  cpp
}

## Pure-R pin from the Phase-4 NB1 prep note. Not a C++ call.
## Quasi / IRLS weight is mu/(1+phi). Exact I_eta is the PMF-summed
## score outer product at fixed phi (size = mu/phi).
.nb1_quasi_W <- function(mu, phi) {
  as.numeric(mu) / (1 + as.numeric(phi))
}

.nb1_exact_I_eta <- function(mu, phi, tail_prob = 1e-12) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  stopifnot(length(mu) == 1L, length(phi) == 1L, mu > 0, phi > 0)
  size <- mu / phi
  prob <- 1 / (1 + phi)
  ymax <- stats::qnbinom(1 - tail_prob, size = size, prob = prob)
  y <- 0:ymax
  pmf <- stats::dnbinom(y, size = size, prob = prob)
  score <- size * (digamma(y + size) - digamma(size) + log(prob))
  sum(pmf * score^2)
}

test_that("public nbinom1 estimator=mspl still errors at the fence", {
  dat <- .mspl_nb1_fence_dat()
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      family = nbinom1(),
      estimator = "mspl"
    ),
    class = "gllvmTMB_mspl_unsupported"
  )
})

test_that("registry has no planned or admitted nbinom1 row", {
  reg <- gllvmTMB:::.gllvmTMB_mspl_registry()
  nb1 <- reg[reg$family == "nbinom1", , drop = FALSE]
  expect_false(any(nb1$status == "planned"))
  expect_false(any(nb1$status == "admitted"))
  expect_true(is.null(
    gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
      family = "nbinom1",
      link = "log",
      structure = "ordinary",
      q = 1L
    )
  ))
  expect_true(is.null(
    gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
      family = "nbinom1",
      link = "log",
      structure = "ordinary",
      q = 2L
    )
  ))
})

test_that("C++ NB1 tape names family_id 15 and PMF-summed exact I, not quasi W", {
  cpp <- .mspl_nb1_read_cpp()
  expect_true(
    grepl("family_id == 15", cpp, fixed = TRUE),
    info = "NB1 tape hook must contain family_id == 15"
  )
  expect_true(
    grepl("PMF-summed exact I", cpp, fixed = TRUE),
    info = "comment must say NB1 is PMF-summed exact I, not a Poisson transplant"
  )
  expect_true(
    grepl("NOT quasi W=mu/(1+phi)", cpp, fixed = TRUE),
    info = "comment must reject quasi W=mu/(1+phi)"
  )
})

test_that("exact NB1 I_eta is not the quasi weight and not Poisson mu", {
  mu <- c(0.8, 1.5, 3.0)
  phi <- 1.5
  w_exact <- vapply(mu, .nb1_exact_I_eta, numeric(1L), phi = phi)
  w_quasi <- .nb1_quasi_W(mu, phi)
  expect_equal(w_quasi, mu / (1 + phi), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(w_exact, w_quasi, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(w_exact, mu, tolerance = 1e-6)))
  expect_true(all(w_exact > w_quasi))
})
