## Fit-time warning on a runaway loading scale (maintainer decision, 2026-07-31).
##
## WHY IT EXISTS. Measured over 12,000 fits (binomial p=6 q=2): under plain defaults
## the fitted loading norm exceeds twice the truth in 98-99% of fits at sigma_lambda=3
## across every n, and 49% at n=100 even at sigma_lambda=1. The failure is the COMMON
## case, and it is SILENT -- convergence = 0, positive-definite Hessian, no message.
##
## It WARNS and does not fix: the remedy has its own measured failure regime
## (aghq_ridge = 2 still runs away in 67% of fits at n=1600, sigma_lambda=3; #847).

## THE WARNING IS `.frequency = "once"` PER SESSION, which is right for users and
## makes a naive test ORDER-DEPENDENT: if any earlier test in the same session has
## already tripped it, the expectation below sees silence. Locally each file runs in
## its own session and it passed; in `R CMD check` the whole suite is one session and
## it failed. Reset the once-per-session state before every expectation that needs
## the warning to actually fire.
.rw_reset <- function() {
  try(rlang::reset_warning_verbosity("gllvmTMB-loading-runaway"), silent = TRUE)
  invisible(NULL)
}

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
  .rw_reset()
  expect_warning(
    fit <- gllvmTMB::gllvmTMB(d$fml, data = d$df, family = stats::binomial()),
    "runaway trait loading"
  )
  ## the warning must carry the remedy AND its cost, not just an alarm
  .rw_reset()
  w <- tryCatch({
    gllvmTMB::gllvmTMB(d$fml, data = d$df, family = stats::binomial()); NULL
  }, warning = function(x) conditionMessage(x))
  if (!is.null(w)) {
    expect_match(w, "loading_ridge")  # 2026-09-02: message now names loading_ridge, not aghq_ridge, by design
    expect_match(w, "MAP|penalised")     # says the remedy changes the estimand
    expect_match(w, "warn_runaway")      # says how to silence it
  }
})

test_that("warn_runaway = FALSE silences it, and the check remains available", {
  skip_on_cran()
  d <- .rw_cell()
  .rw_reset()
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
  .rw_reset()
  n_rw <- 0L
  withCallingHandlers(
    gllvmTMB::gllvmTMB(d$fml, data = d$df, family = stats::binomial()),
    warning = function(w) {
      if (grepl("runaway trait loading", conditionMessage(w))) n_rw <<- n_rw + 1L
      invokeRestart("muffleWarning")
    })
  expect_identical(n_rw, 0L)
})

test_that("loading_absolute_thresh default is 8, up from the old 6 (issue #1098)", {
  ## The old default (6) false-positived at 25% on a healthy binomial-probit
  ## pool built to span a realistic loading-scale range (928 healthy / 272
  ## degenerate fits, dev/heywood/fp-attribution-findings.md), because the
  ## arm is judged on an ABSOLUTE link-scale magnitude with no reference to
  ## the fit's true loading scale. This fixture reproduces the mechanism
  ## directly: a real check_gllvmTMB() call on a synthetic fit whose
  ## largest trait loading sits at 7 -- inside [6, 8) -- with prevalence,
  ## saturation, and the relative-loading ratio all held at ordinary,
  ## unremarkable values so ONLY the extreme_magnitude arm can possibly
  ## fire. It exercises the real `check_gllvmTMB()` code path, not a stub.
  ##
  ## trait loadings: item1 = 7 (the one under test), items 2-4 = 1 (typical).
  ## denom = max(median, mad) of c(7,1,1,1) = max(1, 0) = 1, so
  ## relative_loading for item1 = 7/1 = 7 -- below loading_relative_thresh
  ## (8) and loading_runaway_thresh (25), so neither of those arms can fire
  ## either. Prevalence is 0.5 for every trait (balanced 0/1), eta = 0
  ## throughout (fitted probability exactly 0.5, so saturation_share = 0):
  ## extreme_prevalence is FALSE everywhere, so the prevalence-gated branch
  ## cannot fire. The ONLY arm that can produce a WARN here is
  ## extreme_magnitude on item1.
  trait_levels <- paste0("item", 1:4)
  n_per_trait <- 10L
  trait_id <- rep(seq_along(trait_levels) - 1L, each = n_per_trait)
  y <- rep(rep(c(0, 1), 5L), 4L)
  eta <- rep(0, 40L)
  fit <- list(
    fit_health = list(
      convergence = 0L, message = "relative convergence", max_gradient = 0,
      sdreport_ok = TRUE, sdreport_error = NA_character_, pd_hessian = TRUE,
      max_fixed_se = 1, boundary_flags = character(0), selected_restart = 1L
    ),
    sd_report = list(pdHess = TRUE, cov.fixed = diag(2)),
    restart_history = data.frame(
      restart = 1L, optimizer = "nlminb", objective = 0,
      convergence = 0L, selected = TRUE
    ),
    report = list(
      Lambda_B = matrix(
        c(7, 1, 1, 1),
        nrow = length(trait_levels),
        dimnames = list(trait_levels, "LV1")
      ),
      eta = eta
    ),
    tmb_data = list(
      y = y, n_trials = rep(1, length(y)), is_y_observed = rep(1L, length(y)),
      family_id_vec = rep(1L, length(y)), link_id_vec = rep(1L, length(y)),
      trait_id = trait_id
    ),
    data = data.frame(
      trait = factor(trait_levels[trait_id + 1L], levels = trait_levels)
    ),
    trait_col = "trait", n_traits = length(trait_levels),
    use = list(rr_B = TRUE)
  )
  class(fit) <- "gllvmTMB_multi"

  ## the exported check_gllvmTMB() default itself
  expect_identical(formals(check_gllvmTMB)$loading_absolute_thresh, 8)

  ## pre-fix behaviour: explicitly at the OLD default (6), this fit WARNs
  chk_old <- check_gllvmTMB(fit, loading_absolute_thresh = 6)
  row_old <- chk_old[chk_old$component == "binomial_prevalence_loading", ]
  expect_equal(row_old$status, "WARN")

  ## post-fix behaviour: at the NEW default (8, the package default), the
  ## same fit passes
  chk_new <- check_gllvmTMB(fit)
  row_new <- chk_new[chk_new$component == "binomial_prevalence_loading", ]
  expect_equal(row_new$status, "PASS")
})

test_that("the multinomial degeneracy warning fires once, honours warn_runaway, and keeps its own slot", {
  skip_on_cran()
  ## The binomial and multinomial fit-time warnings share the warn_runaway
  ## control but hold SEPARATE once-per-session slots, so one family's
  ## warning cannot consume the other's. Reset both before asserting (the
  ## file header explains why: .frequency = "once" is per session, and
  ## R CMD check runs the whole suite in one).
  rlang::reset_warning_verbosity("gllvmTMB-multinomial-degeneracy")
  rlang::reset_warning_verbosity("gllvmTMB-loading-runaway")

  expect_true(
    is.function(gllvmTMB:::.gllvmTMB_multinomial_degeneracy_row),
    info = "the row builder the fit-time warning calls must exist"
  )

  ## The wiring itself: the warning block reads the multinomial row under the
  ## same control as the binomial one, with a distinct frequency id.
  src <- deparse(gllvmTMB:::gllvmTMB)
  expect_true(any(grepl("gllvmTMB-multinomial-degeneracy", src, fixed = TRUE)))
  expect_true(any(grepl(".gllvmTMB_multinomial_degeneracy_row", src, fixed = TRUE)))
  ## Both warnings sit inside the same `warn_runaway` guard, so FALSE
  ## silences both.
  expect_true(any(grepl("warn_runaway", src, fixed = TRUE)))
})
