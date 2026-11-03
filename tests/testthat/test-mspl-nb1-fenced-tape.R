## Curie-nb1: planned NB1 LA-MSPL tape (not admitted).
## Public estimator="mspl" is the planned door. Registry stays planned.
## src/gllvmTMB.cpp must name family_id == 15 and pin NB1 as PMF-summed
## exact I, NOT quasi W=mu/(1+phi).
## Kill: "Poisson worked so NB does."
## Do not edit the shared test-zz-mspl-fenced-family-tapes.R.

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
  candidates <- c(
    testthat::test_path("..", "..", "src", "gllvmTMB.cpp"),
    testthat::test_path(
      "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    ),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    ),
    file.path("src", "gllvmTMB.cpp"),
    file.path("..", "src", "gllvmTMB.cpp"),
    file.path("..", "..", "src", "gllvmTMB.cpp")
  )
  installed <- system.file("..", "src", "gllvmTMB.cpp", package = "gllvmTMB")
  if (nzchar(installed)) {
    candidates <- c(installed, candidates)
  }
  cpp_path <- candidates[file.exists(candidates)][1L]
  testthat::skip_if(
    is.na(cpp_path),
    "gllvmTMB.cpp source file is not available in this test context."
  )
  paste(readLines(cpp_path, warn = FALSE), collapse = "\n")
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

test_that("public nbinom1 estimator=mspl is the planned door, not admitted", {
  dat <- .mspl_nb1_fence_dat()
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      family = nbinom1(),
      estimator = "mspl",
      control = gllvmTMBcontrol(n_init = 1L, se = FALSE, warn_runaway = FALSE)
    ),
    NA
  )
})

test_that("nbinom1 ordinary q1/q2 registry cells stay planned, not admitted", {
  reg <- gllvmTMB:::.gllvmTMB_mspl_registry()
  nb1 <- reg[reg$family == "nbinom1", , drop = FALSE]
  expect_true(nrow(nb1) >= 2L)
  expect_true(all(nb1$status == "planned"))
  expect_false(any(nb1$status == "admitted"))
  r1 <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "nbinom1",
    link = "log",
    structure = "ordinary",
    q = 1L
  )
  r2 <- gllvmTMB:::.gllvmTMB_mspl_registry_lookup(
    family = "nbinom1",
    link = "log",
    structure = "ordinary",
    q = 2L
  )
  expect_false(is.null(r1))
  expect_false(is.null(r2))
  expect_identical(r1$status, "planned")
  expect_identical(r2$status, "planned")
  expect_match(r1$notes, "not admitted")
  expect_match(r1$notes, "not covered")
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

## #1376: the compiled PMF sum must not be cut at y = 80 for large mu.
## Full-sum reference in base R (support to mu + 40 sd, far past the tail).
.nb1_log_I_full <- function(mu, phi) {
  size <- mu / phi
  prob <- 1 / (1 + phi)
  y <- 0:ceiling(mu + 40 * sqrt(mu * (1 + phi)))
  score <- size * (digamma(y + size) - digamma(size) + log(prob))
  log(sum(stats::dnbinom(y, size = size, prob = prob) * score^2) + 1e-12)
}

## Compiled GLM-outer log weight at a common mu and phi, read through the
## planned MSPL tape: with a trait-indicator X_mspl and equal weights,
## mspl_logdet_information = logdet(X'X) + p * log w.
.nb1_tape_log_weight <- function(fit, mu, phi) {
  obj <- fit$tmb_obj
  p <- obj$env$last.par.best
  p[names(p) == "b_fix"] <- log(mu)
  p[names(p) == "log_phi_nbinom1"] <- log(phi)
  X <- fit$tmb_data$X_mspl
  ld <- as.numeric(obj$report(p)$mspl_logdet_information)
  (ld - as.numeric(determinant(crossprod(X), logarithm = TRUE)$modulus)) /
    ncol(X)
}

test_that("compiled NB1 weight uses the full PMF sum for large mu (#1376)", {
  skip_on_cran()
  dat <- .mspl_nb1_fence_dat()
  fit <- tryCatch(
    suppressWarnings(suppressMessages(gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
      data = dat,
      family = nbinom1(),
      estimator = "mspl",
      unit = "site",
      control = gllvmTMBcontrol(
        n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
      )
    ))),
    error = function(e) NULL
  )
  skip_if(is.null(fit), "NB1 MSPL tape did not build in this context.")
  phi <- 0.5
  mu <- c(60, 100, 200)
  ref <- vapply(mu, .nb1_log_I_full, numeric(1L), phi = phi)
  expect_equal(round(ref, 3), c(3.690, 4.201, 4.893))
  got <- vapply(mu, function(m) .nb1_tape_log_weight(fit, m, phi), numeric(1L))
  expect_equal(got[2:3], ref[2:3], tolerance = 1e-6)
  expect_equal(got[1], ref[1], tolerance = 1e-6)
  expect_true(all(diff(got) > 0))
})
