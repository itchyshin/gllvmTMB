## W_* two-sided vanishing audit — pure R + C++ source pins.
##
## Research note:
##   docs/dev-log/research/2026-08-16-mspl-W-onesided-audit.md
## Helpers stay in this file. Do not call live MSPL. No se=TRUE.
## G0 SIGNED REPLACE (#1102): live Poisson tape is working W_*;
## W1/W2 keep true-W=mu algebra as historical contrast.

.wstar_working_W <- function(eta) {
  mu <- stats::plogis(as.numeric(eta))
  mu * (1 - mu)
}

.wstar_pois_W <- function(eta) {
  exp(as.numeric(eta))
}

.wstar_tweedie_true_W <- function(eta, phi = 1.4, p = 1.5) {
  exp((2 - as.numeric(p)) * as.numeric(eta)) / as.numeric(phi)
}

.wstar_nb2_W <- function(eta, phi = 2) {
  mu <- exp(as.numeric(eta))
  phi <- as.numeric(phi)
  mu * phi / (phi + mu)
}

.wstar_nb1_quasi_W <- function(eta, phi = 1) {
  exp(as.numeric(eta)) / (1 + as.numeric(phi))
}

.wstar_Pj <- function(X, w) {
  I <- crossprod(X, X * as.numeric(w))
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.wstar_toy <- function() {
  ## Same four-row intercept + covariate as the Phase-4 Poisson /
  ## NB2 / Tweedie oracles. Slope held at -0.4; intercept is swept.
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  list(X = X, b1 = -0.4)
}

.wstar_eta <- function(fx, b0) {
  as.numeric(fx$X[, 1L] * b0 + fx$X[, 2L] * fx$b1)
}

.wstar_cpp_src <- function() {
  candidates <- c(
    testthat::test_path("..", "..", "src", "gllvmTMB.cpp"),
    testthat::test_path(
      "..", "..", "..", "00_pkg_src", "gllvmTMB", "src", "gllvmTMB.cpp"
    ),
    file.path("src", "gllvmTMB.cpp"),
    file.path("..", "src", "gllvmTMB.cpp"),
    file.path("..", "..", "src", "gllvmTMB.cpp")
  )
  installed <- system.file("..", "src", "gllvmTMB.cpp", package = "gllvmTMB")
  if (nzchar(installed)) {
    candidates <- c(candidates, installed)
  }
  cpp_path <- candidates[file.exists(candidates)][1L]
  testthat::skip_if(
    is.na(cpp_path),
    "gllvmTMB.cpp source file is not available in this test context."
  )
  readLines(cpp_path, warn = FALSE)
}

test_that("W1: Poisson W=exp(eta) vanishes at -Inf and grows at +Inf", {
  fx <- .wstar_toy()
  eta_lo <- .wstar_eta(fx, -8)
  eta_0 <- .wstar_eta(fx, 0)
  eta_hi <- .wstar_eta(fx, 8)
  w_lo <- .wstar_pois_W(eta_lo)
  w_0 <- .wstar_pois_W(eta_0)
  w_hi <- .wstar_pois_W(eta_hi)
  expect_true(all(w_lo < 1e-3))
  expect_true(all(w_hi > 1e3))
  expect_true(all(w_lo < w_0))
  expect_true(all(w_0 < w_hi))
  ## One-sided: W -> 0 on the left, W -> +Inf on the right.
  expect_lt(max(w_lo), 1e-3)
  expect_gt(min(w_hi), 1e3)
})

test_that("W2: Poisson true W is one-sided; live tape is W_*", {
  fx <- .wstar_toy()
  b0 <- c(-8, -4, 0, 4, 8)
  ## Historical / true-W contrast (why REPLACE was signed): P_J rewards +Inf.
  Pj_true <- vapply(b0, function(b) {
    .wstar_Pj(fx$X, .wstar_pois_W(.wstar_eta(fx, b)))
  }, numeric(1L))
  expect_true(all(is.finite(Pj_true)))
  expect_true(all(diff(Pj_true) > 0))
  expect_lt(Pj_true[1L], -5)
  expect_gt(tail(Pj_true, 1L), 8)
  ## Linear in the intercept on this design: +4 per +4 in beta0.
  expect_equal(diff(Pj_true), rep(4, 4L), tolerance = 1e-8)

  ## Live tape after #1102: working logistic W_* is two-sided on this design
  ## (same algebra W3 pins; kept here so W2 mirrors the Tweedie W4 shape).
  Pj_live <- vapply(b0, function(b) {
    .wstar_Pj(fx$X, .wstar_working_W(.wstar_eta(fx, b)))
  }, numeric(1L))
  expect_true(all(is.finite(Pj_live)))
  expect_lt(Pj_live[1L], -5)
  expect_lt(tail(Pj_live, 1L), -5)
  expect_equal(Pj_live[1L], tail(Pj_live, 1L), tolerance = 1e-8)
  expect_gt(Pj_live[3L], Pj_live[1L])
  expect_gt(Pj_live[3L], tail(Pj_live, 1L))

  ## Source pin (Tweedie W4 pattern): live Poisson branch is W_*, not return eta.
  cpp <- paste(.wstar_cpp_src(), collapse = "\n")
  expect_match(cpp, "True Poisson W = mu")
  expect_match(cpp, "working logistic")
  expect_match(
    cpp,
    "if \\(family_id == 2\\) \\{[\\s\\S]*?return gll_mspl_log_weight\\(eta, 0\\);",
    perl = TRUE
  )
})

test_that("W3: working W_* vanishes at both infinities; P_J is two-sided", {
  fx <- .wstar_toy()
  w_lo <- .wstar_working_W(.wstar_eta(fx, -8))
  w_hi <- .wstar_working_W(.wstar_eta(fx, 8))
  expect_true(all(w_lo < 1e-3))
  expect_true(all(w_hi < 1e-3))
  ## Row order reverses with the covariate; the multiset of weights matches.
  expect_equal(sort(w_lo), sort(w_hi), tolerance = 1e-10)

  Pj_lo <- .wstar_Pj(fx$X, w_lo)
  Pj_0 <- .wstar_Pj(fx$X, .wstar_working_W(.wstar_eta(fx, 0)))
  Pj_hi <- .wstar_Pj(fx$X, w_hi)
  expect_lt(Pj_lo, -5)
  expect_lt(Pj_hi, -5)
  expect_equal(Pj_lo, Pj_hi, tolerance = 1e-8)
  expect_gt(Pj_0, Pj_lo)
  expect_gt(Pj_0, Pj_hi)
})

test_that("W4: Tweedie true W is one-sided like Poisson; live tape is W_*", {
  fx <- .wstar_toy()
  w_lo <- .wstar_tweedie_true_W(.wstar_eta(fx, -8))
  w_hi <- .wstar_tweedie_true_W(.wstar_eta(fx, 8))
  expect_true(all(w_lo < 0.05))
  expect_true(all(w_hi > 20))
  Pj_lo <- .wstar_Pj(fx$X, w_lo)
  Pj_hi <- .wstar_Pj(fx$X, w_hi)
  expect_lt(Pj_lo, 0)
  expect_gt(Pj_hi, 4)

  cpp <- paste(.wstar_cpp_src(), collapse = "\n")
  expect_match(cpp, "True Tweedie W = mu\\^\\{2-p\\}/phi")
  expect_match(cpp, "working logistic")
  expect_match(cpp, "return gll_mspl_log_weight\\(eta, 0\\)")
})

test_that("W5: nbinom2 W saturates to phi; P_J stays finite at +Inf", {
  fx <- .wstar_toy()
  phi <- 2
  w_lo <- .wstar_nb2_W(.wstar_eta(fx, -8), phi)
  w_hi <- .wstar_nb2_W(.wstar_eta(fx, 8), phi)
  w_far <- .wstar_nb2_W(.wstar_eta(fx, 12), phi)
  expect_true(all(w_lo < 1e-3))
  expect_true(all(w_hi < phi))
  expect_gt(min(w_hi / phi), 0.99)
  expect_equal(max(w_far), phi, tolerance = 1e-4)

  Pj_hi <- .wstar_Pj(fx$X, w_hi)
  Pj_far <- .wstar_Pj(fx$X, w_far)
  expect_true(is.finite(Pj_hi))
  expect_true(is.finite(Pj_far))
  expect_lt(abs(Pj_far - Pj_hi), 0.01)
  ## Contrast: Poisson P_J on the same +Inf path is still climbing.
  Pj_pois_hi <- .wstar_Pj(fx$X, .wstar_pois_W(.wstar_eta(fx, 8)))
  Pj_pois_far <- .wstar_Pj(fx$X, .wstar_pois_W(.wstar_eta(fx, 12)))
  expect_gt(Pj_pois_far - Pj_pois_hi, 3)
})

test_that("W6: nbinom1 quasi W is one-sided like Poisson", {
  fx <- .wstar_toy()
  w_lo <- .wstar_nb1_quasi_W(.wstar_eta(fx, -8), 1)
  w_hi <- .wstar_nb1_quasi_W(.wstar_eta(fx, 8), 1)
  expect_true(all(w_lo < 1e-3))
  expect_true(all(w_hi > 500))
  Pj_lo <- .wstar_Pj(fx$X, w_lo)
  Pj_hi <- .wstar_Pj(fx$X, w_hi)
  expect_lt(Pj_lo, -5)
  expect_gt(Pj_hi, 5)
})

test_that("W7: C++ Poisson live tape is working W_*; NB2 still saturates", {
  cpp <- paste(.wstar_cpp_src(), collapse = "\n")
  expect_match(cpp, "Live tape uses working logistic W_\\*")
  expect_match(cpp, "G0 SIGNED REPLACE 2026-08-17")
  ## Poisson branch must NOT return eta (true-W); it must call the
  ## Tweedie-precedent working-logistic helper on link_id 0.
  expect_match(
    cpp,
    "if \\(family_id == 2\\) \\{[\\s\\S]*?return gll_mspl_log_weight\\(eta, 0\\);",
    perl = TRUE
  )
  expect_false(grepl(
    "if \\(family_id == 2\\) \\{[\\s\\S]*?return eta;",
    cpp,
    perl = TRUE
  ))
  expect_match(cpp, "NB2: W = mu \\* phi / \\(phi \\+ mu\\)")
  expect_match(cpp, "NOT quasi W=mu/\\(1\\+phi\\)")
})

test_that("W8: registry names live Poisson W_*; no admit flip / no covered", {
  pois <- .gllvmTMB_mspl_registry_lookup("poisson", "log", "ordinary", 1L)
  expect_identical(pois$status, "admitted")
  expect_match(pois$notes, "working logistic W_\\*")
  expect_match(pois$notes, "G0 REPLACE")
  ## Historical true-W wording may remain as contrast; live claim is W_*.
  expect_match(pois$notes, "true W=diag\\(mu\\) was one-sided")
  notes_claim <- gsub(
    "not a covered campaign|not covered",
    "",
    pois$notes,
    ignore.case = TRUE
  )
  expect_false(grepl("\\bcovered\\b", notes_claim, ignore.case = TRUE))

  tw <- .gllvmTMB_mspl_registry_lookup("tweedie", "log", "ordinary", 1L)
  expect_identical(tw$status, "planned")
  expect_match(tw$notes, "working logistic W_\\*")
  expect_match(tw$notes, "one-sided")

  nb2 <- .gllvmTMB_mspl_registry_lookup("nbinom2", "log", "ordinary", 1L)
  expect_identical(nb2$status, "planned")
  expect_match(nb2$notes, "W=mu\\*phi/\\(phi\\+mu\\)")

  nb1 <- .gllvmTMB_mspl_registry_lookup("nbinom1", "log", "ordinary", 1L)
  expect_identical(nb1$status, "planned")
  expect_match(nb1$notes, "NOT quasi W=mu/\\(1\\+phi\\)")
})

test_that("W-onesided oracles never invoke a live MSPL fit or public SE", {
  src_lines <- readLines(test_path("test-mspl-W-onesided-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl("gllvmTMB\\s*\\([^)]*estimator\\s*=", code))
  expect_false(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code))
  expect_false(grepl("\\bse\\s*=\\s*TRUE", code))
})
