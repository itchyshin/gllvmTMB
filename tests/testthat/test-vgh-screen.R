## Phase 3 degenerate-fit screen: H1 (mean per-unit, per-axis posterior
## log-contraction, p3-health-statistic-design.md) plus the two-sided flag.
##
## A screen that flags everything has sensitivity 1 and is worthless, so every
## test here pairs a case that MUST be flagged with a case that must NOT be --
## the same discipline the measurement in p3-screen-performance.md applies at
## scale (there: 11 healthy Laplace fits, 8 silently-degenerate ones).

test_that(".vgh_screen_verdict rejects a malformed threshold", {
  fake <- structure(list(Svec = matrix(c(1, 0, 0, 1), 1, 4), q = 2L),
                     class = "vgh_fit")
  expect_error(.vgh_screen_verdict(fake, threshold = c(1, 1)), "lo < hi")
  expect_error(.vgh_screen_verdict(fake, threshold = 1), "lo < hi")
})

test_that("a constructed EXPLODED posterior is flagged (h far above the band)", {
  ## S_i = diag(1e-6, 1e-6) for every unit: P_i = S_i^{-1} = diag(1e6, 1e6),
  ## i.e. Lambda' W_i Lambda ~ 1e6 -- exactly the "off by several orders of
  ## magnitude" signature Design 108 recorded. logdet(S_i) = 2*log(1e-6), so
  ## h = -mean(logdetS)/q = -log(1e-6) = 13.8 nats -- far above any healthy
  ## band, which the measurement puts at O(1).
  q <- 2L; N <- 10L
  Svec <- matrix(rep(c(1e-6, 0, 0, 1e-6), N), nrow = N, byrow = TRUE)
  fake <- structure(list(Svec = Svec, q = q), class = "vgh_fit")

  v <- .vgh_screen_verdict(fake, threshold = c(0.05, 6))
  expect_true(v$degenerate)
  expect_gt(v$h, 6)
})

test_that("a constructed COLLAPSED posterior is flagged (h at its exact floor)", {
  ## S_i = I_q (posterior == prior) for every unit is the OTHER failure
  ## direction the design note identifies: h == 0 exactly, by the P_i >= I_q
  ## construction (va-vgh.R:201-224). A one-sided screen tuned only to catch
  ## explosion would miss this -- this test exists so a one-sided regression
  ## cannot pass silently.
  q <- 2L; N <- 10L
  Svec <- matrix(rep(c(1, 0, 0, 1), N), nrow = N, byrow = TRUE)
  fake <- structure(list(Svec = Svec, q = q), class = "vgh_fit")

  v <- .vgh_screen_verdict(fake, threshold = c(0.05, 6))
  expect_true(v$degenerate)
  expect_equal(v$h, 0, tolerance = 1e-12)
})

test_that("a constructed HEALTHY posterior is NOT flagged (negative control)", {
  ## S_i corresponding to mu = 1 on both axes (a moderate, well-identified
  ## posterior contraction): s = 1/(1+1) = 0.5, h = -log(0.5) = log(2) ~ 0.69,
  ## squarely inside the band used above. This is the case a screen that
  ## flags everything would fail -- it must NOT be flagged.
  q <- 2L; N <- 10L
  Svec <- matrix(rep(c(0.5, 0, 0, 0.5), N), nrow = N, byrow = TRUE)
  fake <- structure(list(Svec = Svec, q = q), class = "vgh_fit")

  v <- .vgh_screen_verdict(fake, threshold = c(0.05, 6))
  expect_false(v$degenerate)
  expect_equal(v$h, log(2), tolerance = 1e-12)
})

test_that("h is invariant under a rotation of every unit's S_i (rotation orbit)", {
  ## Lambda is identified only up to an orthogonal rotation, and S_i -> R'S_iR
  ## under that rotation (design note section 3, H1). logdet is invariant
  ## under conjugation by an orthogonal matrix, so h must be identical before
  ## and after -- if this ever fails, the screen has started reading a
  ## rotation-dependent quantity and every pass/fail verdict above it is
  ## meaningless.
  q <- 2L; N <- 6L
  set.seed(1L)
  raw <- lapply(seq_len(N), function(i) {
    A <- matrix(stats::rnorm(q * q), q, q)
    S <- crossprod(A) / (q * 2) + diag(0.3, q)  # SPD, eigenvalues in (0,1]-ish
    S / (max(eigen(S, only.values = TRUE)$values) + 0.5)
  })
  Svec <- t(vapply(raw, as.vector, numeric(q * q)))
  fake <- structure(list(Svec = Svec, q = q), class = "vgh_fit")
  h_before <- .vgh_health_stat(fake)$h

  theta <- pi / 5
  R <- matrix(c(cos(theta), sin(theta), -sin(theta), cos(theta)), 2, 2)
  Svec_rot <- t(vapply(raw, function(S) as.vector(t(R) %*% S %*% R), numeric(q * q)))
  fake_rot <- structure(list(Svec = Svec_rot, q = q), class = "vgh_fit")
  h_after <- .vgh_health_stat(fake_rot)$h

  expect_equal(h_after, h_before, tolerance = 1e-10)
})

test_that("a real, small VGH fit on a benign dataset is not flagged (plumbing check)", {
  ## The fixtures above test the flagging arithmetic in isolation; this test
  ## exercises .vgh_screen_fit() end to end -- .vgh_fit() plus the verdict --
  ## on an actual small, well-identified gaussian_anchor dataset, so a
  ## regression in the plumbing (wrong q, wrong Svec shape, ...) cannot hide
  ## behind fixture-only coverage.
  set.seed(20260729L)
  n <- 40L; Tt <- 6L; q <- 1L
  lambda_true <- matrix(stats::rnorm(Tt * q, 0, 0.6), Tt, q)
  u <- matrix(stats::rnorm(n * q), n, q)
  beta_true <- stats::rnorm(Tt, 0, 0.3)
  eta <- matrix(beta_true, n, Tt, byrow = TRUE) + u %*% t(lambda_true)
  Y <- eta + matrix(stats::rnorm(n * Tt, 0, 0.5), n, Tt)

  v <- .vgh_screen_fit(
    y = as.numeric(t(Y)), n_trials = rep(1L, n * Tt),
    X = matrix(1, n * Tt, 1),
    unit_id = rep(seq_len(n), each = Tt), trait_id = rep(seq_len(Tt), times = n),
    N = n, T = Tt, q = q, family = "gaussian_anchor", link = "identity",
    gaussian_sd = 0.5, maxit = 200L,
    threshold = c(0.05, 6)
  )

  expect_s3_class(v, "vgh_screen")
  expect_false(v$degenerate)
  expect_true(is.finite(v$h) && v$h > 0)
})
