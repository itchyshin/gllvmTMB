## #1574: an explicit indep() on ordinal traits with one observation per
## (unit, trait) used to collapse to a near-zero SD with no warning, and
## check_gllvmTMB() stayed green. The same identifiability gate as the
## default between-unit Psi now maps that diagonal off and warns.
## Repeated observations of a trait inside a unit stay estimated.
## An explicit indep() on a single-trial binomial trait stays estimated:
## that term is a deliberate model choice.

capture_fit <- function(expr) {
  msgs <- character()
  fit <- withCallingHandlers(
    expr,
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(fit = fit, msgs = paste(msgs, collapse = "\n"))
}

ordinal_frame <- function(n_site, n_rep, seed) {
  set.seed(seed)
  cuts <- list(vigour = c(0, 0.8), damage = c(0, 0.6))
  mu <- c(vigour = 0.3, damage = 0.2)
  dd <- expand.grid(
    site = seq_len(n_site),
    rep = seq_len(n_rep),
    trait = names(cuts)
  )
  u <- matrix(stats::rnorm(n_site * 2L, sd = 0.8), n_site, 2L)
  lia <- mu[as.character(dd$trait)] +
    u[cbind(dd$site, as.integer(dd$trait))] +
    stats::rnorm(nrow(dd))
  dd$value <- NA_integer_
  for (tr in names(cuts)) {
    rows <- dd$trait == tr
    dd$value[rows] <- findInterval(lia[rows], cuts[[tr]]) + 1L
  }
  dd$site <- factor(dd$site)
  dd$trait <- factor(dd$trait, levels = names(cuts))
  dd
}

fit_ordinal_indep <- function(dd) {
  gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site),
    data = dd,
    trait = "trait",
    unit = "site",
    family = ordinal_probit(),
    control = gllvmTMBcontrol(se = FALSE, warn_runaway = FALSE)
  )
}

test_that("explicit indep on single-observation ordinal traits is mapped off", {
  skip_on_cran()
  dd <- ordinal_frame(n_site = 40L, n_rep = 1L, seed = 2L)
  out <- capture_fit(fit_ordinal_indep(dd))
  fit <- out$fit
  expect_match(out$msgs, "not identified", fixed = TRUE)
  expect_identical(as.integer(fit$tmb_data$diag_B_skip), c(1L, 1L))
  expect_false(any(grepl("^theta_diag_B", names(fit$opt$par))))
  chk <- check_gllvmTMB(fit)
  psi <- chk[chk$component == "near_zero_psi_unit", , drop = FALSE]
  if (nrow(psi) == 1L) expect_identical(psi$status, "PASS")
  expect_false(any(chk$status == "FAIL"))
})

test_that("repeated ordinal observations keep an explicit indep term", {
  skip_on_cran()
  dd <- ordinal_frame(n_site = 25L, n_rep = 2L, seed = 3L)
  out <- capture_fit(fit_ordinal_indep(dd))
  fit <- out$fit
  expect_false(grepl("not identified", out$msgs, fixed = TRUE))
  expect_identical(as.integer(fit$tmb_data$diag_B_skip), c(0L, 0L))
})

test_that("explicit indep on a single-trial binomial trait stays free", {
  skip_on_cran()
  set.seed(4L)
  dd <- expand.grid(
    site = factor(seq_len(30L)),
    trait = factor(c("a", "b"))
  )
  dd$value <- stats::rbinom(nrow(dd), 1L, 0.4)
  out <- capture_fit(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | site),
    data = dd,
    trait = "trait",
    unit = "site",
    family = binomial(),
    control = gllvmTMBcontrol(se = FALSE, warn_runaway = FALSE)
  ))
  expect_false(grepl("not identified", out$msgs, fixed = TRUE))
  expect_identical(as.integer(out$fit$tmb_data$diag_B_skip), c(0L, 0L))
})
