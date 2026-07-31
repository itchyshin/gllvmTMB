## Fit-time warning on a runaway loading scale (maintainer decision, 2026-07-31).
##
## WHY IT EXISTS. Measured over 12,000 fits (binomial p=6 q=2): under plain defaults
## the fitted loading norm exceeds twice the truth in 98-99% of fits at sigma_lambda=3
## across every n, and 49% at n=100 even at sigma_lambda=1. The failure is the COMMON
## case, and it is SILENT -- convergence = 0, positive-definite Hessian, no message.
##
## It WARNS and does not fix: the remedy has its own measured failure regime
## (aghq_ridge = 2 still runs away in 67% of fits at n=1600, sigma_lambda=3; #847).

.rw_cell <- function(seed = 2003L, lam = 3, n = 100L, p = 6L, q = 2L) {
  set.seed(seed)
  Lt <- matrix(stats::rnorm(p * q, 0, lam), p, q)
  u  <- matrix(stats::rnorm(n * q), n, q)
  b  <- stats::rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  list(df = df, fml = stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
    paste(colnames(Y), collapse = ", "), q)))
}

test_that("warn_runaway is a real control argument, defaulting to TRUE", {
  expect_true(isTRUE(gllvmTMB::gllvmTMBcontrol()$warn_runaway))
  expect_identical(gllvmTMB::gllvmTMBcontrol(warn_runaway = FALSE)$warn_runaway, FALSE)
  ## it must not fall through to the "extra arguments are ignored" path -- the
  ## defect class of #871/#844, where a documented switch was silently swallowed
  expect_no_warning(gllvmTMB::gllvmTMBcontrol(warn_runaway = FALSE))
})

test_that("a runaway fit warns by default, and the warning is actionable", {
  skip_on_cran()
  d <- .rw_cell()
  expect_warning(
    fit <- gllvmTMB::gllvmTMB(d$fml, data = d$df, family = stats::binomial()),
    "runaway trait loading"
  )
  ## the warning must carry the remedy AND its cost, not just an alarm
  w <- tryCatch({
    gllvmTMB::gllvmTMB(d$fml, data = d$df, family = stats::binomial()); NULL
  }, warning = function(x) conditionMessage(x))
  if (!is.null(w)) {
    expect_match(w, "aghq_ridge")
    expect_match(w, "MAP|penalised")     # says the remedy changes the estimand
    expect_match(w, "warn_runaway")      # says how to silence it
  }
})

test_that("warn_runaway = FALSE silences it, and the check remains available", {
  skip_on_cran()
  d <- .rw_cell()
  n_rw <- 0L
  fit <- withCallingHandlers(
    gllvmTMB::gllvmTMB(d$fml, data = d$df, family = stats::binomial(),
                       control = gllvmTMB::gllvmTMBcontrol(warn_runaway = FALSE)),
    warning = function(w) {
      if (grepl("runaway trait loading", conditionMessage(w))) n_rw <<- n_rw + 1L
      invokeRestart("muffleWarning")
    })
  expect_identical(n_rw, 0L)
  ## suppressing the WARNING must not suppress the DETECTION -- a user who opts out
  ## of the message can still ask for the check
  row <- gllvmTMB:::.gllvmTMB_binomial_prevalence_loading_row(fit)
  expect_identical(as.character(row$status), "WARN")
})

test_that("a healthy fit does NOT warn", {
  skip_on_cran()
  ## Guards against the warning being useless by firing on everything. Small
  ## loadings, larger n -- the regime where the campaign measured low runaway.
  d <- .rw_cell(seed = 11L, lam = 0.5, n = 300L)
  n_rw <- 0L
  withCallingHandlers(
    gllvmTMB::gllvmTMB(d$fml, data = d$df, family = stats::binomial()),
    warning = function(w) {
      if (grepl("runaway trait loading", conditionMessage(w))) n_rw <<- n_rw + 1L
      invokeRestart("muffleWarning")
    })
  expect_identical(n_rw, 0L)
})
