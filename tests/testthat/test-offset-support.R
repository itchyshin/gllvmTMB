## `offset()` support, scoped to count families -- issue #833.
##
## The failure this suite exists to prevent is a SILENTLY IGNORED offset.
## Before #807 an `offset()` term reached `fixed_terms` and was then dropped by
## `model.matrix()`, so the fit used a different model from the one written:
## the logLik was identical with and without a *varying* offset, to the last
## digit. Re-implementing that bug while adding the feature is the main risk
## here, so every test below uses a VARYING offset -- a constant one is
## absorbed by the intercept and would pass even if the offset were ignored --
## and the engagement tests assert the fit actually moves.
##
## Deliberately NOT behind `skip_if_not_heavy()`: the failure is silent, so it
## has to be caught on an ordinary run (#834).
##
## Grammar (settled 2026-07-30, maintainer):
##   long   `offset(col)`         per-row (unit x trait) values as supplied
##   wide   `offset(w)`           one unit-level column, recycled across traits
##   wide   `offset(e1, e2, ...)` one column per trait, in `traits()` order
## The gate fires on a NONZERO offset at a non-count row. Zero is a legal
## no-op, which is what makes a mixed-family fit expressible.

## Exposure is correlated with `z` on purpose. If it were independent, omitting
## the offset would only shift the intercept, and a test built on that cannot
## distinguish "offset applied" from "offset absorbed by the intercept".
## Correlated exposure makes omission bias the `z` slope, which gives the
## recovery test a two-sided signal.
.ofs_pois_long <- function(n = 60, seed = 11) {
  set.seed(seed)
  nn <- 2L * n
  z <- stats::rnorm(nn)
  log_eff <- 0.8 * z + stats::rnorm(nn, 0, 0.4)
  trait <- factor(rep(c("t1", "t2"), each = n))
  b0 <- c(t1 = 0.4, t2 = 0.1)[as.character(trait)]
  b1 <- c(t1 = 0.5, t2 = -0.3)[as.character(trait)]
  data.frame(
    site    = factor(rep(seq_len(n), times = 2L)),
    trait   = trait,
    z       = z,
    log_eff = log_eff,
    value   = stats::rpois(nn, lambda = exp(b0 + b1 * z + log_eff))
  )
}

## Wide fixture: `z` and `log_eff` are unit-level columns, so `offset(log_eff)`
## exercises the recycle-across-traits path.
.ofs_pois_wide <- function(n = 60, seed = 12) {
  set.seed(seed)
  z <- stats::rnorm(n)
  log_eff <- 0.8 * z + stats::rnorm(n, 0, 0.4)
  d <- data.frame(site = factor(seq_len(n)), z = z, log_eff = log_eff)
  d$t1 <- stats::rpois(n, exp(0.4 + 0.5 * z + log_eff))
  d$t2 <- stats::rpois(n, exp(0.1 - 0.3 * z + log_eff))
  d
}

## The same wide fixture stacked by hand, row-major (traits vary within source
## row) to match `rewrite_traits_lhs()`.
.ofs_wide_to_long <- function(d) {
  data.frame(
    site    = factor(rep(seq_len(nrow(d)), each = 2L)),
    trait   = factor(rep(c("t1", "t2"), times = nrow(d))),
    z       = rep(d$z, each = 2L),
    log_eff = rep(d$log_eff, each = 2L),
    value   = as.vector(t(as.matrix(d[c("t1", "t2")])))
  )
}

.ofs_fit <- function(...) {
  suppressMessages(suppressWarnings(gllvmTMB(
    ..., control = gllvmTMBcontrol(se = FALSE)
  )))
}

.ofs_msg <- function(expr) {
  msg <- tryCatch({
    force(expr)
    NA_character_
  }, error = function(e) conditionMessage(e))
  ## cli wraps long messages; collapse so fragment matching is not defeated by
  ## a line break landing inside the phrase being asserted.
  gsub("[\r\n]+", " ", msg)
}

# ---- (1) Engagement: the offset must change the fit -------------------

test_that("a varying offset changes a poisson fit and adds no parameters", {
  d <- .ofs_pois_long()

  fit_no  <- .ofs_fit(value ~ 0 + trait + (0 + trait):z,
                      data = d, trait = "trait", unit = "site",
                      family = poisson())
  fit_off <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(log_eff),
                      data = d, trait = "trait", unit = "site",
                      family = poisson())

  ll_no  <- as.numeric(stats::logLik(fit_no))
  ll_off <- as.numeric(stats::logLik(fit_off))

  ## The exact bug #807 fixed produced a difference of exactly 0.
  expect_false(isTRUE(all.equal(ll_no, ll_off)),
               label = sprintf("logLik with offset = %.6f, without = %.6f",
                               ll_off, ll_no))
  ## And not merely a rounding-level difference either.
  expect_gt(abs(ll_off - ll_no), 1)

  ## An offset is a known column, not a coefficient: the parameter count must
  ## be unchanged. (Before #807 npar was also unchanged -- because the term was
  ## dropped -- so this is a necessary check, not a sufficient one.)
  expect_equal(attr(stats::logLik(fit_off), "df"),
               attr(stats::logLik(fit_no), "df"))
})

# ---- (2) Recovery: the offset corrects a bias that omitting it causes --

test_that("a poisson offset recovers the slope that omitting it biases", {
  d <- .ofs_pois_long(n = 300, seed = 21)

  fit_off <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(log_eff),
                      data = d, trait = "trait", unit = "site",
                      family = poisson())
  fit_no  <- .ofs_fit(value ~ 0 + trait + (0 + trait):z,
                      data = d, trait = "trait", unit = "site",
                      family = poisson())

  slope <- function(fit, term) {
    td <- suppressMessages(tidy(fit, "fixed", conf.int = FALSE))
    td$estimate[td$term == term]
  }

  ## Truth for the t1 z-slope is 0.5. Exposure carries 0.8*z, so omitting the
  ## offset should pull the estimate toward 1.3.
  b1_off <- slope(fit_off, "traitt1:z")
  b1_no  <- slope(fit_no,  "traitt1:z")

  expect_lt(abs(b1_off - 0.5), 0.08,
            label = sprintf("t1 z-slope with offset = %.4f (truth 0.5)", b1_off))
  expect_gt(b1_no - b1_off, 0.5,
            label = sprintf("t1 z-slope without offset = %.4f, with = %.4f",
                            b1_no, b1_off))
})

# ---- (3) External oracle: agree with glmmTMB, which has offsets --------

test_that("gllvmTMB and glmmTMB agree on a poisson offset fit (cross-package)", {
  skip_on_cran()
  skip_if_not_installed("glmmTMB")

  ## Fixed effects only and the SAME formula on both sides, so the two
  ## packages are fitting literally the same model and any disagreement is
  ## the offset wiring rather than a modelling difference.
  d <- .ofs_pois_long(n = 200, seed = 31)
  f <- value ~ 0 + trait + (0 + trait):z + offset(log_eff)

  fit_glmm <- suppressMessages(suppressWarnings(glmmTMB::glmmTMB(
    f, data = d, family = stats::poisson()
  )))
  fit_gll <- .ofs_fit(f, data = d, trait = "trait", unit = "site",
                      family = poisson())

  glmm_b <- glmmTMB::fixef(fit_glmm)$cond
  td <- suppressMessages(tidy(fit_gll, "fixed", conf.int = FALSE))

  for (term in names(glmm_b)) {
    gll <- td$estimate[td$term == term]
    expect_equal(length(gll), 1L,
                 label = sprintf("gllvmTMB has exactly one estimate for %s", term))
    expect_lt(abs(gll - glmm_b[[term]]), 1e-3,
              label = sprintf("%s: gllvmTMB = %.6f, glmmTMB = %.6f",
                              term, gll, glmm_b[[term]]))
  }
})

# ---- (4) Wide shape: recycled across traits, same fit as long ----------

test_that("wide traits() offset(w) engages and matches the equivalent long fit", {
  d <- .ofs_pois_wide()
  long <- .ofs_wide_to_long(d)

  fit_wide <- .ofs_fit(traits(t1, t2) ~ 1 + z + offset(log_eff),
                       data = d, unit = "site", family = poisson())
  fit_wide_no <- .ofs_fit(traits(t1, t2) ~ 1 + z,
                          data = d, unit = "site", family = poisson())
  fit_long <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(log_eff),
                       data = long, trait = "trait", unit = "site",
                       family = poisson())

  ## Engagement in the wide shape specifically. The #807 guard originally
  ## caught long format and MISSED wide, because the traits() expander rewrites
  ## predictors to `(0 + trait):x`; a wide-only regression is the live risk.
  expect_gt(abs(as.numeric(stats::logLik(fit_wide)) -
                as.numeric(stats::logLik(fit_wide_no))), 1)

  ## Wide is shorthand for long, so the offset must wire identically.
  expect_equal(as.numeric(stats::logLik(fit_wide)),
               as.numeric(stats::logLik(fit_long)),
               tolerance = 1e-6)
})

# ---- (5) The family gate ----------------------------------------------

test_that("a nonzero offset on a non-count trait is rejected, naming the trait", {
  d <- .ofs_pois_long()
  ## t2 becomes gaussian; its offset stays nonzero, which is the error case.
  d$value[d$trait == "t2"] <- stats::rnorm(sum(d$trait == "t2"))
  fams <- list(t1 = poisson(), t2 = gaussian())
  attr(fams, "family_var") <- "trait"

  msg <- .ofs_msg(.ofs_fit(
    value ~ 0 + trait + (0 + trait):z + offset(log_eff),
    data = d, trait = "trait", unit = "site", family = fams
  ))

  expect_false(is.na(msg), label = "a nonzero offset on a gaussian trait must error")
  ## Assert the DIAGNOSIS, not merely that something failed. A guard has
  ## shipped past a green test emitting "Invalid cli literal" instead of its
  ## intended message; "did it error?" would not have caught that.
  expect_match(msg, "count", ignore.case = TRUE)
  expect_match(msg, "poisson", ignore.case = TRUE)
  expect_match(msg, "t2", ignore.case = TRUE)
  expect_match(msg, "gaussian", ignore.case = TRUE)
})

test_that("a zero offset on a non-count trait is a legal no-op", {
  d <- .ofs_pois_long()
  d$value[d$trait == "t2"] <- stats::rnorm(sum(d$trait == "t2"))
  ## Zero on the gaussian rows: an offset of 0 is a multiplier of 1, so this
  ## is a genuine no-op rather than a workaround. It is what makes a
  ## mixed-family fit expressible under the gate.
  d$off <- ifelse(d$trait == "t2", 0, d$log_eff)
  fams <- list(t1 = poisson(), t2 = gaussian())
  attr(fams, "family_var") <- "trait"

  fit_off <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(off),
                      data = d, trait = "trait", unit = "site", family = fams)
  d$zero <- 0
  fit_zero <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(zero),
                       data = d, trait = "trait", unit = "site", family = fams)

  expect_equal(fit_off$opt$convergence, 0L)
  ## The poisson rows still feel their offset, so the two fits must differ.
  ## An all-zero offset is the only case where "no change" is the right answer.
  expect_gt(abs(as.numeric(stats::logLik(fit_off)) -
                as.numeric(stats::logLik(fit_zero))), 1)

  ## And an all-zero offset must leave the fit exactly where no offset does.
  fit_none <- .ofs_fit(value ~ 0 + trait + (0 + trait):z,
                       data = d, trait = "trait", unit = "site", family = fams)
  expect_equal(as.numeric(stats::logLik(fit_zero)),
               as.numeric(stats::logLik(fit_none)),
               tolerance = 1e-8)
})

# ---- (5b) binomial(cloglog): a family x link exception, not a family --
#
# Issue #946: `offset()` is gated on family AND link, not family alone.
# `binomial(cloglog)` is admitted -- `cloglog(p) = eta + log(area)` is the
# change-of-support term that lets a presence/absence arm and a count arm
# share one Poisson-process intensity (an integrated SDM). `binomial(logit)`
# and `binomial(probit)` stay refused, so the boundary sits at the LINK, not
# at whether the trait is "binomial".

## Two binomial(cloglog) traits, so `offset(log_area)` engages on both.
## `log_area` is correlated with `z` on purpose (mirrors `.ofs_pois_long`):
## if it were independent, omitting the offset would only shift the
## intercept, and the recovery test below could not distinguish "offset
## applied" from "offset absorbed by the intercept".
.ofs_cloglog_long <- function(n = 400, seed = 91) {
  set.seed(seed)
  nn <- 2L * n
  z <- stats::rnorm(nn)
  log_area <- 0.4 * z + stats::rnorm(nn, 0, 0.3)
  area <- exp(log_area)
  trait <- factor(rep(c("t1", "t2"), each = n))
  b0 <- c(t1 = -0.2, t2 = -0.5)[as.character(trait)]
  b1 <- c(t1 = 0.5, t2 = -0.4)[as.character(trait)]
  mu <- exp(b0 + b1 * z)
  p <- 1 - exp(-area * mu)
  data.frame(
    site     = factor(rep(seq_len(n), times = 2L)),
    trait    = trait,
    z        = z,
    log_area = log_area,
    value    = stats::rbinom(nn, 1, p)
  )
}

## FAILURE-BEFORE-FIX: before this change, `binomial` was refused outright
## regardless of link, so this fit aborted with the count-family message.
## Not merely "does not error" -- checks genuine recovery of the planted
## intensity slope against a truth that is NOT what omitting the offset
## would recover (the offset's own z-coefficient biases the no-offset fit
## toward a different value, same mechanism as the poisson recovery test).
test_that("a binomial(cloglog) offset is accepted and recovers the planted intensity slope", {
  d <- .ofs_cloglog_long()

  fit_off <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(log_area),
                      data = d, trait = "trait", unit = "site",
                      family = stats::binomial(link = "cloglog"))
  fit_no  <- .ofs_fit(value ~ 0 + trait + (0 + trait):z,
                      data = d, trait = "trait", unit = "site",
                      family = stats::binomial(link = "cloglog"))

  slope <- function(fit, term) {
    td <- suppressMessages(tidy(fit, "fixed", conf.int = FALSE))
    td$estimate[td$term == term]
  }

  ## Truth for the t1 z-slope is 0.5; log_area carries +0.4*z, so omitting
  ## the offset should pull the estimate up toward roughly 0.9.
  b1_off <- slope(fit_off, "traitt1:z")
  b1_no  <- slope(fit_no,  "traitt1:z")

  expect_equal(fit_off$opt$convergence, 0L)
  expect_lt(abs(b1_off - 0.5), 0.15,
            label = sprintf("t1 z-slope with offset = %.4f (truth 0.5)", b1_off))
  expect_gt(b1_no - b1_off, 0.2,
            label = sprintf("t1 z-slope without offset = %.4f, with = %.4f",
                            b1_no, b1_off))
})

## BOUNDARY: the gate sits at the link, not at "is this family binomial".
## Nothing guarded this refusal before #946 -- the old gate refused every
## binomial row unconditionally, so a test could not tell "binomial is
## refused" from "binomial(logit) is refused for the right reason".
test_that("binomial(logit) and binomial(probit) offsets still abort, naming the link", {
  set.seed(201)
  n <- 60L
  nn <- 2L * n
  d <- data.frame(
    site  = factor(rep(seq_len(n), times = 2L)),
    trait = factor(rep(c("t1", "t2"), each = n)),
    z     = stats::rnorm(nn),
    off   = stats::rnorm(nn),
    value = stats::rbinom(nn, 1, 0.5)
  )

  for (link in c("logit", "probit")) {
    msg <- .ofs_msg(.ofs_fit(
      value ~ 0 + trait + (0 + trait):z + offset(off),
      data = d, trait = "trait", unit = "site",
      family = stats::binomial(link = link)
    ))
    expect_false(is.na(msg),
                 label = sprintf("binomial(%s) with a nonzero offset must error", link))
    expect_match(msg, "count", ignore.case = TRUE)
    expect_match(msg, "binomial", ignore.case = TRUE)
    expect_match(msg, link, fixed = TRUE)
  }
})

## FEATURE-COMBINATION: poisson rows (log-link exposure offset) and
## binomial-cloglog rows (change-of-support area offset) in one mixed-family
## fit, both nonzero -- the integrated-SDM use case issue #946 exists for.
test_that("poisson exposure offsets and binomial(cloglog) area offsets combine in one mixed-family fit", {
  set.seed(101)
  n <- 150L
  nn <- 2L * n
  z <- stats::rnorm(nn)
  trait <- factor(rep(c("t1", "t2"), each = n))
  is_t1 <- trait == "t1"

  log_eff  <- 0.8 * z + stats::rnorm(nn, 0, 0.4)   # t1: poisson exposure
  log_area <- 0.4 * z + stats::rnorm(nn, 0, 0.3)   # t2: binomial(cloglog) area
  area <- exp(log_area)

  y <- numeric(nn)
  y[is_t1]  <- stats::rpois(sum(is_t1),
                            exp(0.4 + 0.5 * z[is_t1] + log_eff[is_t1]))
  mu_b <- exp(-0.3 - 0.4 * z[!is_t1])
  p_b  <- 1 - exp(-area[!is_t1] * mu_b)
  y[!is_t1] <- stats::rbinom(sum(!is_t1), 1, p_b)

  d <- data.frame(
    site  = factor(rep(seq_len(n), times = 2L)),
    trait = trait,
    z     = z,
    off   = ifelse(is_t1, log_eff, log_area),
    value = y
  )
  fams <- list(t1 = poisson(), t2 = stats::binomial(link = "cloglog"))
  attr(fams, "family_var") <- "trait"

  fit_off <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(off),
                      data = d, trait = "trait", unit = "site", family = fams)
  fit_zero <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(off * 0),
                       data = d, trait = "trait", unit = "site", family = fams)

  expect_equal(fit_off$opt$convergence, 0L)
  ## Both offsets are nonzero and neither trait's family/link is refused, so
  ## the whole fit must be accepted and the offsets must engage.
  expect_gt(abs(as.numeric(stats::logLik(fit_off)) -
                as.numeric(stats::logLik(fit_zero))), 1)
})

# ---- (6) Wide per-trait offset(e1, e2) --------------------------------

test_that("wide offset(e1, e2) gives one offset column per trait", {
  d <- .ofs_pois_wide()
  d$t2 <- stats::rnorm(nrow(d))       # t2 gaussian
  d$zero <- 0
  fams <- list(t1 = poisson(), t2 = gaussian())
  attr(fams, "family_var") <- "trait"

  ## The wide + mixed-family case: a single recycled offset would land nonzero
  ## on the gaussian rows and hit the gate, so the per-trait form is the only
  ## way to write this.
  fit <- .ofs_fit(traits(t1, t2) ~ 1 + z + offset(log_eff, zero),
                  data = d, unit = "site", family = fams)
  expect_equal(fit$opt$convergence, 0L)

  fit_no <- .ofs_fit(traits(t1, t2) ~ 1 + z + offset(zero, zero),
                     data = d, unit = "site", family = fams)
  expect_gt(abs(as.numeric(stats::logLik(fit)) -
                as.numeric(stats::logLik(fit_no))), 1)

  ## The single-column form must still hit the gate here -- it recycles
  ## log_eff onto the gaussian rows.
  msg <- .ofs_msg(.ofs_fit(traits(t1, t2) ~ 1 + z + offset(log_eff),
                           data = d, unit = "site", family = fams))
  expect_false(is.na(msg))
  expect_match(msg, "count", ignore.case = TRUE)
  expect_match(msg, "t2", ignore.case = TRUE)
})

test_that("offset() arity must match traits() arity", {
  d <- .ofs_pois_wide()
  d$zero <- 0
  msg <- .ofs_msg(.ofs_fit(traits(t1, t2) ~ 1 + z + offset(log_eff, zero, zero),
                           data = d, unit = "site", family = poisson()))
  expect_false(is.na(msg))
  expect_match(msg, "offset", ignore.case = TRUE)
  expect_match(msg, "3", ignore.case = TRUE)
  expect_match(msg, "2", ignore.case = TRUE)
})

# ---- (7) Every count family the engine supports ------------------------

test_that("all five supported count families accept an offset", {
  ## poisson (2), nbinom2 (5), nbinom1 (15), truncated_poisson (10),
  ## truncated_nbinom2 (11). truncated_nbinom1 is not in the engine at all.
  set.seed(41)
  n_unit <- 80L
  n <- 2L * n_unit
  z <- stats::rnorm(n)
  log_eff <- 0.6 * z + stats::rnorm(n, 0, 0.3)
  base <- data.frame(
    site    = factor(rep(seq_len(n_unit), times = 2L)),
    trait   = factor(rep(c("t1", "t2"), each = n_unit)),
    z       = z,
    log_eff = log_eff
  )

  ## Zero-truncated draw by rejection, so the truncated families see y >= 1.
  rpois_pos <- function(lambda) {
    y <- stats::rpois(length(lambda), lambda)
    while (any(y == 0L)) {
      zi <- y == 0L
      y[zi] <- stats::rpois(sum(zi), lambda[zi])
    }
    y
  }

  lambda <- exp(0.6 + 0.4 * z + log_eff)
  cases <- list(
    poisson           = list(fam = poisson(),           y = stats::rpois(n, lambda)),
    nbinom2           = list(fam = nbinom2(),           y = stats::rnbinom(n, mu = lambda, size = 3)),
    nbinom1           = list(fam = nbinom1(),           y = stats::rnbinom(n, mu = lambda, size = 3)),
    truncated_poisson = list(fam = truncated_poisson(), y = rpois_pos(lambda)),
    truncated_nbinom2 = list(fam = truncated_nbinom2(), y = rpois_pos(lambda))
  )

  for (nm in names(cases)) {
    d <- base
    d$value <- cases[[nm]]$y
    msg_off <- .ofs_msg(.ofs_fit(
      value ~ 0 + trait + (0 + trait):z + offset(log_eff),
      data = d, trait = "trait", unit = "site", family = cases[[nm]]$fam
    ))
    expect_true(is.na(msg_off),
                label = sprintf("%s must accept an offset; got: %s", nm, msg_off))

    ## Accepting is not engaging. A silently-ignored offset also fails to
    ## error, so each family has to be shown to MOVE.
    fit_off <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(log_eff),
                        data = d, trait = "trait", unit = "site",
                        family = cases[[nm]]$fam)
    fit_no  <- .ofs_fit(value ~ 0 + trait + (0 + trait):z,
                        data = d, trait = "trait", unit = "site",
                        family = cases[[nm]]$fam)
    dll <- abs(as.numeric(stats::logLik(fit_off)) -
               as.numeric(stats::logLik(fit_no)))
    expect_gt(dll, 1)
    expect_true(dll > 1, label = sprintf("%s logLik shift = %.4f", nm, dll))
  }
})

# ---- (9) Composition with the rest of the model -----------------------

test_that("the offset composes with a random effect and reaches the SE path", {
  d <- .ofs_pois_long(n = 80, seed = 71)

  ## The offset is added to eta BEFORE every random-effect contribution, so a
  ## model carrying both must still show the offset engaging. Fitted with SEs
  ## on, which also exercises the sdreport path an `se = FALSE` fit skips.
  fit_off <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + offset(log_eff) + (1 | site),
    data = d, trait = "trait", unit = "site", family = poisson()
  )))
  fit_no <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):z + (1 | site),
    data = d, trait = "trait", unit = "site", family = poisson()
  )))

  expect_equal(fit_off$opt$convergence, 0L)
  expect_gt(abs(as.numeric(stats::logLik(fit_off)) -
                as.numeric(stats::logLik(fit_no))), 1)

  td <- suppressMessages(tidy(fit_off, "fixed", conf.int = TRUE))
  expect_true(all(is.finite(td$std.error)),
              label = "standard errors must be finite for an offset fit")
})

# ---- (10) The impute-formula surface ----------------------------------

test_that("offset() inside an impute formula is diagnosed, not left opaque", {
  ## Previously this surfaced the raw base-R "undefined columns selected",
  ## which names nothing about offsets or impute formulas. The response-model
  ## offset being supported now makes a clear refusal here more important, not
  ## less: a user who has just learned offsets work will try one.
  d <- .ofs_pois_long(n = 40, seed = 81)
  d$x1 <- stats::rnorm(nrow(d))
  d$x1[c(3L, 9L)] <- NA
  d$w <- stats::rnorm(nrow(d))

  msg <- .ofs_msg(.ofs_fit(
    value ~ 0 + trait + mi(x1),
    data = d, trait = "trait", unit = "site", family = poisson(),
    impute = list(x1 = x1 ~ z + offset(w)),
    missing = miss_control(predictor = "model")
  ))

  expect_false(is.na(msg))
  expect_match(msg, "offset", ignore.case = TRUE)
  expect_match(msg, "impute", ignore.case = TRUE)
  ## The old failure said none of this.
  expect_no_match(msg, "undefined columns", ignore.case = TRUE)
})

# ---- (8) Downstream paths that rebuild eta on the R side --------------

## predict(newdata = ), simulate(), and the julia bridge do not read the
## TMB-reported eta; they recompute the predictor from the coefficients. Each
## is therefore its own opportunity to reintroduce a silently-ignored offset.

test_that("simulate() draws from a predictor that includes the offset", {
  ## An intercept-only model with an offset that is uncorrelated with anything
  ## else, so row-to-row variation in the simulated mean can come from nothing
  ## but the offset. An ignored offset gives a high/low ratio of about 1.
  set.seed(51)
  n_unit <- 100L
  n <- 2L * n_unit
  log_eff <- rep(c(-1.5, 1.5), length.out = n)
  d <- data.frame(
    site    = factor(rep(seq_len(n_unit), times = 2L)),
    trait   = factor(rep(c("t1", "t2"), each = n_unit)),
    log_eff = log_eff,
    value   = stats::rpois(n, exp(1.0 + log_eff))
  )

  fit <- .ofs_fit(value ~ 0 + trait + offset(log_eff),
                  data = d, trait = "trait", unit = "site", family = poisson())

  set.seed(52)
  sim <- as.matrix(suppressMessages(stats::simulate(fit, nsim = 20L)))
  hi <- mean(sim[log_eff > 0, ])
  lo <- mean(sim[log_eff < 0, ])

  ## exp(1.5) / exp(-1.5) = exp(3) ~= 20. Anything near 1 means the offset was
  ## dropped from the redraw -- which would also silently corrupt
  ## bootstrap_Sigma() and coverage_study(), both of which redraw through here.
  expect_gt(hi / max(lo, 1e-9), 5,
            label = sprintf("simulated mean: high offset = %.3f, low = %.3f",
                            hi, lo))
})

test_that("predict(newdata =) re-evaluates the offset for the new rows", {
  d <- .ofs_pois_long(n = 60, seed = 61)
  fit <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(log_eff),
                  data = d, trait = "trait", unit = "site", family = poisson())

  nd <- d
  nd2 <- d
  nd2$log_eff <- nd2$log_eff + 1        # a known shift on the link scale

  p1 <- suppressMessages(stats::predict(fit, newdata = nd,  re_form = ~0))$est
  p2 <- suppressMessages(stats::predict(fit, newdata = nd2, re_form = ~0))$est

  ## The offset enters eta additively, so a +1 shift must move every linear
  ## predictor by exactly 1. A dropped offset would give a difference of 0 --
  ## which is precisely the signature of the bug #807 fixed.
  expect_equal(p2 - p1, rep(1, length(p1)), tolerance = 1e-8)
})

test_that("predict(newdata =) says so when the offset variable is absent", {
  d <- .ofs_pois_long(n = 40, seed = 62)
  fit <- .ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(log_eff),
                  data = d, trait = "trait", unit = "site", family = poisson())

  nd <- d
  nd$log_eff <- NULL
  msg <- .ofs_msg(suppressMessages(stats::predict(fit, newdata = nd, re_form = ~0)))

  expect_false(is.na(msg), label = "predicting without the offset column must error")
  expect_match(msg, "offset", ignore.case = TRUE)
  expect_match(msg, "log_eff", ignore.case = TRUE)
})

test_that("engine = 'julia' refuses an offset rather than dropping it", {
  ## The guard fires before any dispatch, so this needs no Julia install.
  d <- .ofs_pois_long(n = 20, seed = 63)
  msg <- .ofs_msg(.ofs_fit(value ~ 0 + trait + (0 + trait):z + offset(log_eff),
                           data = d, trait = "trait", unit = "site",
                           family = poisson(), engine = "julia"))
  expect_false(is.na(msg))
  expect_match(msg, "offset", ignore.case = TRUE)
  expect_match(msg, "julia", ignore.case = TRUE)
})
