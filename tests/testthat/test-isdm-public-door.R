## The public door for the integrated two-source model: what it opens, what it
## must keep shut, and that it reaches the same likelihood as the developer
## route it replaces for users.

test_that("the cloglog offset opens only inside the two-source contract", {
  ## Inside the contract: a nonzero offset on the Bernoulli-cloglog arm is a
  ## change-of-support term and is admitted.
  fids <- c(2L, 1L)
  lids <- c(0L, 2L)
  expect_silent(
    gll_prepare_offset(
      offset_expr = quote(eff),
      data = data.frame(eff = c(1.5, 2.5)),
      formula_env = environment(),
      family_id_vec = fids,
      link_id_vec = lids,
      family_per_row = list(stats::poisson(),
                            stats::binomial(link = "cloglog")),
      trait_vec = factor(c("sp1", "sp1")),
      allow_isdm_cloglog = TRUE
    )
  )

  ## Same rows, contract NOT matched (so the caller passes FALSE): the cloglog
  ## row is an ordinary binomial row again and the count-family gate fires.
  expect_error(
    gll_prepare_offset(
      offset_expr = quote(eff),
      data = data.frame(eff = c(1.5, 2.5)),
      formula_env = environment(),
      family_id_vec = fids,
      link_id_vec = lids,
      family_per_row = list(stats::poisson(),
                            stats::binomial(link = "cloglog")),
      trait_vec = factor(c("sp1", "sp1")),
      allow_isdm_cloglog = FALSE
    ),
    "count families"
  )
})

test_that("admitting the contract never opens the offset for other families", {
  ## gaussian, binomial-logit, binomial-probit and Beta must still be refused
  ## even with the flag on -- the flag is keyed to cloglog specifically.
  cases <- list(
    gaussian     = list(fid = 0L, lid = 0L, fam = stats::gaussian()),
    binom_logit  = list(fid = 1L, lid = 0L, fam = stats::binomial()),
    binom_probit = list(fid = 1L, lid = 1L,
                        fam = stats::binomial(link = "probit")),
    beta         = list(fid = 7L, lid = 0L, fam = list(family = "Beta"))
  )
  for (nm in names(cases)) {
    cs <- cases[[nm]]
    expect_error(
      gll_prepare_offset(
        offset_expr = quote(eff),
        data = data.frame(eff = 2),
        formula_env = environment(),
        family_id_vec = cs$fid,
        link_id_vec = cs$lid,
        family_per_row = list(cs$fam),
        trait_vec = factor("sp1"),
        allow_isdm_cloglog = TRUE
      ),
      "count families",
      info = nm
    )
  }
})

test_that("the contract requires BOTH arms within every trait", {
  fam <- local({
    f <- list(gbif = stats::poisson(),
              survey_pa = stats::binomial(link = "cloglog"))
    attr(f, "family_var") <- "isdm_family"
    f
  })

  ## Genuinely integrated: one trait, both sources.
  good <- data.frame(
    source = c("gbif", "survey"),
    isdm_family = c("gbif", "survey_pa"),
    stringsAsFactors = FALSE
  )
  expect_true(.gllvmTMB_integrated_two_source_contract(
    fam, good, c(2L, 1L), c(0L, 2L), trait_labels = factor(c("A", "A"))))

  ## NOT integrated: trait A is all portal, trait B is all survey. This is an
  ## ordinary between-trait mixed-family fit; no family varies within a trait,
  ## so it needs no relaxation and must not receive one.
  split_traits <- data.frame(
    source = c("gbif", "gbif", "survey", "survey"),
    isdm_family = c("gbif", "gbif", "survey_pa", "survey_pa"),
    stringsAsFactors = FALSE
  )
  expect_false(.gllvmTMB_integrated_two_source_contract(
    fam, split_traits, c(2L, 2L, 1L, 1L), c(0L, 0L, 2L, 2L),
    trait_labels = factor(c("A", "A", "B", "B"))))

  ## NOT integrated: a single dummy portal row must not buy a survey-only
  ## data set access to the cloglog offset and the augmented spatial slope.
  dummy <- data.frame(
    source = c("gbif", "survey", "survey", "survey"),
    isdm_family = c("gbif", "survey_pa", "survey_pa", "survey_pa"),
    stringsAsFactors = FALSE
  )
  expect_false(.gllvmTMB_integrated_two_source_contract(
    fam, dummy, c(2L, 1L, 1L, 1L), c(0L, 2L, 2L, 2L),
    trait_labels = factor(c("A", "B", "B", "B"))))
})

## Gauss's two blockers, found by adversarial review of the opened fence.
## Both inputs are reachable through the PUBLIC door and neither is coherent
## inside this contract, so both must be refused rather than silently accepted.

## Two traits, two cells, both arms in every trait: the smallest shape that
## satisfies the contract AND survives model.matrix (a single-level trait
## factor cannot be contrast-coded, and fails before either gate is reached).
.isdm_door_fixture <- function() {
  d <- expand.grid(
    cell_id = c("c1", "c2"),
    trait = c("sp1", "sp2"),
    source = c("gbif", "survey"),
    stringsAsFactors = FALSE
  )
  d$trait <- factor(d$trait)
  d$cell_id <- factor(d$cell_id)
  d$isdm_gbif <- as.integer(d$source == "gbif")
  d$isdm_family <- factor(ifelse(d$source == "gbif", "gbif", "survey_pa"),
                          levels = c("gbif", "survey_pa"))
  d$log_support <- 0.1
  d$value <- c(3, 2, 4, 1, 1, 0, 1, 0)
  d$succ <- d$value
  d$fail <- c(0, 0, 0, 0, 2, 3, 1, 2)
  d
}

.isdm_door_family <- function() {
  f <- list(gbif = stats::poisson(),
            survey_pa = stats::binomial(link = "cloglog"))
  attr(f, "family_var") <- "isdm_family"
  f
}

test_that("weights is refused inside the integrated two-source contract", {
  skip_if_not_installed("TMB")
  d <- .isdm_door_fixture()
  ## Across the two arms `weights` would be a binomial trial count on the
  ## survey rows and a likelihood multiplier on the portal rows -- and the
  ## existing weighted-objective warning skips binomial rows, so without this
  ## refusal it would pass in silence.
  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + trait:isdm_gbif + offset(log_support) +
        latent(0 + trait | cell_id, d = 1),
      data = d, trait = "trait", unit = "cell_id", family = .isdm_door_family(),
      weights = rep(c(1, 3), each = 4), silent = TRUE
    )),
    class = "gllvmTMB_isdm_weights_unsupported"
  )
})

test_that("multi-trial survey rows are refused inside the contract", {
  skip_if_not_installed("TMB")
  ## cbind(successes, failures) reaches n_trials > 1 without `weights`. The
  ## thinned-Poisson coherence argument is for ONE trial of support a, so a
  ## user supplying total effort across n visits would be wrong by a factor
  ## of n inside the exponent.
  d <- .isdm_door_fixture()
  expect_error(
    suppressMessages(gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + trait:isdm_gbif + offset(log_support) +
        latent(0 + trait | cell_id, d = 1),
      data = d, trait = "trait", unit = "cell_id", family = .isdm_door_family(),
      silent = TRUE
    )),
    class = "gllvmTMB_isdm_multitrial_unsupported"
  )
})

## The public-vs-developer equivalence test lives in
## test-isdm-developer-fit.R, where the .isdm_fit_fixture() /
## .isdm_test_control() helpers are defined (they are file-local there, not in
## helper-isdm-dev-contract.R).
