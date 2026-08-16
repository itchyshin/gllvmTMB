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

## The public-vs-developer equivalence test lives in
## test-isdm-developer-fit.R, where the .isdm_fit_fixture() /
## .isdm_test_control() helpers are defined (they are file-local there, not in
## helper-isdm-dev-contract.R).
