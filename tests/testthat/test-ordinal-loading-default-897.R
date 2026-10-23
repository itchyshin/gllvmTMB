## #897: ordinal_probit had no working degeneracy screen -- the
## `ordinal_liability_loading` row existed but both arms defaulted to Inf, so
## degenerate fits passed `check_gllvmTMB()` unflagged (binomial catches the same
## defect). The absolute arm (O2) now defaults to 30 liability units.
##
## The fixture (tests/testthat/fixtures/ordinal-loading-897.rds, 1 KB) records
## four ordinal_probit fits of the S2b calibration DGP (n = 100, 4 traits, 2
## latent variables, sigma_lambda = 3), each fitted in 1-3 s on Totoro:
##   healthy_1006  rel_frob    0.84  max unit-tier loading   2.3  -> PASS
##   miss_1026     rel_frob   26.6   max unit-tier loading  22.3  -> PASS (a known miss)
##   flagged_1009  rel_frob  112     max unit-tier loading  42.5  -> WARN
##   flagged_1038  rel_frob 1123     max unit-tier loading 184.6  -> WARN
## All four report convergence = 0, so nothing but the loading size separates
## them at fit time. No model is fitted here.

.ord_fixtures <- function() {
  readRDS(testthat::test_path("fixtures", "ordinal-loading-897.rds"))
}

.ord_fit <- function(x) {
  traits <- paste0("ord", 1:4)
  L <- x$L
  dimnames(L) <- list(traits, paste0("LV", seq_len(ncol(L))))
  n <- length(x$trait_id)
  fit <- list(
    fit_health = list(
      convergence = x$convergence, message = "relative convergence",
      max_gradient = 0, sdreport_ok = TRUE, sdreport_error = NA_character_,
      pd_hessian = TRUE, max_fixed_se = 1, boundary_flags = character(0),
      selected_restart = 1L
    ),
    sd_report = list(pdHess = TRUE, cov.fixed = diag(2)),
    restart_history = data.frame(
      restart = 1L, optimizer = "nlminb", objective = 0,
      convergence = x$convergence, selected = TRUE
    ),
    report = list(
      Lambda_B = L, eta = rep(0, n), ordinal_cutpoints = x$ordinal_cutpoints
    ),
    tmb_data = list(
      trait_id = x$trait_id, family_id_vec = x$family_id_vec,
      link_id_vec = x$link_id_vec, y = rep(0, n), n_trials = rep(1, n),
      is_y_observed = rep(1L, n),
      n_ordinal_cuts_per_trait = x$n_ordinal_cuts_per_trait,
      ordinal_offset_per_trait = x$ordinal_offset_per_trait
    ),
    data = data.frame(trait = factor(traits[x$trait_id + 1L], levels = traits)),
    trait_col = "trait", n_traits = 4L, use = list(rr_B = TRUE)
  )
  class(fit) <- "gllvmTMB_multi"
  fit
}

.ord_row <- function(x, ...) {
  chk <- check_gllvmTMB(.ord_fit(x), ...)
  chk[chk$component == "ordinal_liability_loading", , drop = FALSE]
}

test_that("the O2 default is 30 and O1 stays disabled", {
  expect_identical(formals(check_gllvmTMB)$ordinal_loading_absolute_thresh, 30)
  expect_identical(formals(check_gllvmTMB)$ordinal_loading_runaway_thresh, Inf)
  expect_identical(
    formals(gllvmTMB:::.gllvmTMB_ordinal_degeneracy_row)$ordinal_loading_absolute_thresh,
    30
  )
})

test_that("degenerate ordinal fits are flagged by check_gllvmTMB() defaults", {
  fx <- .ord_fixtures()
  for (nm in c("flagged_1009", "flagged_1038")) {
    row <- .ord_row(fx[[nm]])
    expect_equal(nrow(row), 1L, info = nm)
    expect_equal(row$status, "WARN", info = nm)
    expect_match(row$message, "O2", info = nm)
    expect_false(grepl("O1", row$message), info = nm)
    ## it names the runaway trait (the row of Lambda with the largest entry) and its loading
    runaway_trait <- paste0("ord", which.max(apply(abs(fx[[nm]]$L), 1L, max)))
    expect_match(row$value, runaway_trait, info = nm)
    expect_match(row$value, as.character(signif(fx[[nm]]$max_loading_unit, 3)),
                 fixed = TRUE, info = nm)
    expect_match(row$action, "loading_ridge", info = nm)
  }
})

test_that("a recovered ordinal fit is not flagged", {
  row <- .ord_row(.ord_fixtures()$healthy_1006)
  expect_equal(row$status, "PASS")
})

test_that("known miss: a degenerate fit with a moderate loading still passes", {
  ## rel_frob 26.6 but the largest loading is 22.3, below 30. Recorded so a
  ## future change to the default shows up here rather than silently.
  fx <- .ord_fixtures()
  expect_gt(fx$miss_1026$rel_frob, 10)
  expect_lt(fx$miss_1026$max_loading_unit, 30)
  expect_equal(.ord_row(fx$miss_1026)$status, "PASS")
})

test_that("Inf disables the absolute arm, and the threshold is honoured", {
  x <- .ord_fixtures()$flagged_1009            # largest loading 42.5
  expect_equal(.ord_row(x, ordinal_loading_absolute_thresh = Inf)$status, "PASS")
  expect_equal(.ord_row(x, ordinal_loading_absolute_thresh = 42)$status, "WARN")
  expect_equal(.ord_row(x, ordinal_loading_absolute_thresh = 43)$status, "PASS")
})

test_that("the default does not touch ordinal_logit or other families", {
  ## family id 14 only: relabel the same fit as gaussian (id 0) and the row is absent
  x <- .ord_fixtures()$flagged_1038
  x$family_id_vec[] <- 0L
  expect_false("ordinal_liability_loading" %in% check_gllvmTMB(.ord_fit(x))$component)
})
