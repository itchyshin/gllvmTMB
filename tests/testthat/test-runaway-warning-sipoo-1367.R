## #1367: the fit-time runaway-loading warning went silent on the second and
## later runaway fits of an R session.
##
## Cause (reproduced on Totoro 2026-10-04, gllvmTMB 0.8.0.9000 @ 8010cfd4c): the
## warning used ONE session-wide `.frequency = "once"` id. On vegan::sipoo,
## three binomial fits run in one session -- probit d = 2, probit d = 1 (loading
## column norm 3.6e4), logit d = 2 -- emitted 1, 0, 0 fit-time warnings, while
## check_gllvmTMB() flagged all three. Each fit alone, in a fresh session, warns.
##
## The test uses recorded pieces of those three fits (tests/testthat/fixtures/
## sipoo-runaway-1367.rds, 15 KB) and calls the warning helper directly, so it
## fits nothing. It fails if any of the three warnings is absent.

.sipoo_fixtures <- function() {
  readRDS(testthat::test_path("fixtures", "sipoo-runaway-1367.rds"))
}

.sipoo_fit <- function(x) {
  traits <- x$traits
  tl <- factor(traits[x$trait_id + 1L], levels = traits)
  L <- x$L
  dimnames(L) <- list(traits, paste0("LV", seq_len(ncol(L))))
  fit <- list(
    fit_health = list(
      convergence = x$convergence, message = x$message, max_gradient = 0.3,
      sdreport_ok = TRUE, sdreport_error = NA_character_, pd_hessian = TRUE,
      max_fixed_se = 1, boundary_flags = character(0), selected_restart = 1L
    ),
    sd_report = list(pdHess = TRUE, cov.fixed = diag(2)),
    restart_history = data.frame(
      restart = 1L, optimizer = "nlminb", objective = 0,
      convergence = x$convergence, selected = TRUE
    ),
    report = list(Lambda_B = L, eta = x$eta),
    tmb_data = list(
      y = x$y, n_trials = x$n_trials, is_y_observed = x$is_y_observed,
      family_id_vec = x$family_id_vec, link_id_vec = x$link_id_vec,
      trait_id = x$trait_id
    ),
    data = data.frame(trait = tl),
    trait_col = "trait", n_traits = length(traits), use = list(rr_B = TRUE)
  )
  class(fit) <- "gllvmTMB_multi"
  fit
}

.count_runaway <- function(fit) {
  n <- 0L
  withCallingHandlers(
    gllvmTMB:::.gllvmTMB_warn_runaway_loading(fit),
    warning = function(w) {
      if (grepl("runaway trait loading", conditionMessage(w))) n <<- n + 1L
      invokeRestart("muffleWarning")
    }
  )
  n
}

test_that("sipoo fixtures: check_gllvmTMB() flags every recorded runaway fit", {
  fx <- .sipoo_fixtures()
  expect_named(fx, c("probit_d2", "probit_d1", "logit_d2"))
  for (nm in names(fx)) {
    fit <- .sipoo_fit(fx[[nm]])
    ## the recorded fits really are the ones in the report
    expect_gt(max(abs(fx[[nm]]$L)), 60, label = paste(nm, "max |loading|"))
    chk <- check_gllvmTMB(fit)
    expect_equal(
      chk$status[chk$component == "binomial_prevalence_loading"], "WARN",
      info = nm
    )
  }
})

test_that("each distinct runaway fit in one session gets its own fit-time warning", {
  fx <- .sipoo_fixtures()
  gllvmTMB:::.gllvmTMB_reset_runaway_warnings()
  on.exit(gllvmTMB:::.gllvmTMB_reset_runaway_warnings(), add = TRUE)

  ## The order the reporter ran them in. Before the fix this was 1, 0, 0.
  n <- vapply(
    c("probit_d2", "probit_d1", "logit_d2"),
    function(nm) .count_runaway(.sipoo_fit(fx[[nm]])),
    integer(1)
  )
  expect_identical(unname(n), c(1L, 1L, 1L))
})

test_that("a re-fit of the same data and model does not repeat the warning", {
  fx <- .sipoo_fixtures()
  gllvmTMB:::.gllvmTMB_reset_runaway_warnings()
  on.exit(gllvmTMB:::.gllvmTMB_reset_runaway_warnings(), add = TRUE)

  fit <- .sipoo_fit(fx$probit_d1)
  expect_identical(.count_runaway(fit), 1L)
  expect_identical(.count_runaway(fit), 0L)
  ## a different starting point of the same model changes the loadings, not the
  ## data or the model: still quiet
  fit2 <- .sipoo_fit(fx$probit_d1)
  fit2$report$Lambda_B <- fit2$report$Lambda_B * 0.5
  expect_identical(.count_runaway(fit2), 0L)
})
