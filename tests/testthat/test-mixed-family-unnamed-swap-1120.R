## Issue #1120: `.align_mixed_family_list()` (R/fit-multi.R) returned an
## unnamed mixed-family `family = list(...)` unchanged, while the levels of a
## character `family_var` column are built alphabetically
## (`sort(unique(...))`). The i-th entry of the user's list was matched to
## the i-th *alphabetical* level rather than anything the user's list order
## implies -- a silent trait <-> family swap with no warning and a converged
## fit. See also test-mixed-dispersion-pinning-1117.R, which worked around
## this with explicit `levels =` and pointed here.
##
## The chosen contract (`.gllvmTMB_resolve_unnamed_family_list()`, shared by
## `.align_mixed_family_list()` and the independent duplicate in
## `expand_multinomial_response()`, R/gllvmTMB.R) keys loudness off
## DISAGREEMENT, not off naming: it computes both the POSITIONAL reading (the
## order the user wrote the list in) and the NAME-RESOLVED reading (each
## family object's own `$family` matched against the level text), and:
##   1. readings agree                 -> proceed silently (never ambiguous)
##   2. readings disagree               -> abort, showing BOTH readings
##   3. no level has any name evidence  -> positional is all there is; use
##                                          it, but report the resolved
##                                          pairing once (auditable)
##   4. a level matches >1 family object's name, OR some levels have
##      evidence and others don't       -> abort as ambiguous
##
## This file pins the real #1120 swap (branch 2) end to end through
## gllvmTMB(), plus each of the other three branches at the internal
## resolver (which both call sites share, so one set of branch tests covers
## both). Branch 2's gllvmTMB()-level test is the one proven to FAIL on
## pre-#1120 `origin/main` (silently fits the swapped model; no error).

test_that("#1120 branch 2 (disagreement): unnamed list against a character family column swaps silently pre-fix, errors post-fix", {
  skip_on_cran()
  set.seed(101)
  n <- 60L
  u <- stats::rnorm(n, sd = 1.0)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), 2)),
    trait = factor(rep(c("y_t", "y_g"), each = n), levels = c("y_t", "y_g")),
    y = c(1.5 + 0.8 * u + stats::rt(n, df = 7),
          1.0 + 0.6 * u + stats::rnorm(n, sd = 1.0)),
    ## Plain CHARACTER column (not a factor): no stored order at all.
    ## "gaussian" < "student" alphabetically, but the list below is written
    ## in DATA order (student first) -- anti-alphabetical.
    family = rep(c("student", "gaussian"), each = n)
  )

  family_list <- list(student(), gaussian())
  attr(family_list, "family_var") <- "family"

  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 1),
      data = dat, unit = "site", trait = "trait",
      family = family_list, silent = TRUE
    ),
    class = "gllvmTMB_mixed_family_unnamed_ambiguous"
  )

  ## The named form is unaffected and fits each trait with its own family:
  ## family_id 9 = student on y_t, family_id 0 = gaussian on y_g.
  named_list <- list(student = student(), gaussian = gaussian())
  attr(named_list, "family_var") <- "family"

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = dat, unit = "site", trait = "trait",
    family = named_list, silent = TRUE
  )))
  fid <- fit$tmb_data$family_id_vec
  expect_true(all(fid[dat$trait == "y_t"] == 9L))  # student
  expect_true(all(fid[dat$trait == "y_g"] == 0L))  # gaussian
})

test_that("#1120 branch 1 (agreement): unnamed list whose order matches level-name evidence fits silently, correctly paired", {
  skip_on_cran()
  set.seed(6L)
  n <- 40L
  x <- stats::rnorm(2L * n)
  dat <- data.frame(
    site  = factor(rep(seq_len(n), 2)),
    trait = factor(rep(c("t_bin", "t_gau"), each = n), levels = c("t_bin", "t_gau")),
    ## "binomial" < "gaussian" alphabetically, and the list below is ALSO
    ## written binomial-first: position and name evidence agree, so this was
    ## never ambiguous even before #1120 -- and must stay silent post-fix.
    family = ifelse(rep(c(TRUE, FALSE), each = n), "binomial", "gaussian")
  )
  dat$y <- NA_real_
  is_b <- dat$family == "binomial"
  dat$y[is_b]  <- stats::rbinom(sum(is_b), 1L, stats::plogis(0.2 * x[is_b]))
  dat$y[!is_b] <- 0.3 * x[!is_b] + stats::rnorm(sum(!is_b), sd = 0.5)

  fams <- list(binomial(), gaussian())   # unnamed, agrees with name evidence
  attr(fams, "family_var") <- "family"

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = dat, unit = "site", trait = "trait",
    family = fams, silent = TRUE
  )))
  fid <- fit$tmb_data$family_id_vec
  expect_true(all(fid[dat$trait == "t_bin"] == 1L))  # binomial
  expect_true(all(fid[dat$trait == "t_gau"] == 0L))  # gaussian
})

test_that("#1120 branch 3 (no name evidence): unnamed list against arbitrary labels uses list order and reports it", {
  skip_on_cran()
  fam_levels <- c("binary", "count")   # neither string is a family's own name
  fams <- list(binomial(), poisson())  # positional: binary->binomial, count->poisson
  expect_message(
    resolved <- gllvmTMB:::.gllvmTMB_resolve_unnamed_family_list(fams, fam_levels, "family"),
    "no name evidence"
  )
  expect_identical(resolved[[1]]$family, "binomial")
  expect_identical(resolved[[2]]$family, "poisson")
})

test_that("#1120 branch 4a (ambiguous): a level's text matches more than one family object's name", {
  skip_on_cran()
  fam_levels <- c("poisson", "other")
  fams <- list(poisson(), poisson(link = "identity"))
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_unnamed_family_list(fams, fam_levels, "family"),
    class = "gllvmTMB_mixed_family_unnamed_ambiguous"
  )
})

test_that("#1120 branch 4b (partial evidence): some levels have name evidence, others don't", {
  skip_on_cran()
  fam_levels <- c("gaussian", "other")
  fams <- list(gaussian(), poisson())
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_unnamed_family_list(fams, fam_levels, "family"),
    class = "gllvmTMB_mixed_family_unnamed_ambiguous"
  )
})

test_that("#1120: the same disagreement contract applies to the independent multinomial-expansion site (expand_multinomial_response, R/gllvmTMB.R)", {
  skip_on_cran()
  ## Reachable BEFORE .align_mixed_family_list() runs -- item 2a-ii
  ## cross-family multinomial fits go through expand_multinomial_response()
  ## first, which independently derives which family_var level is the
  ## multinomial trait. This duplicated the #1120 defect pattern; it now
  ## shares the same resolver.
  set.seed(5L)
  n <- 60L
  cats <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  dat <- rbind(
    data.frame(unit = factor(seq_len(n)), trait = "cat_trait",
               value = as.character(cats), family = "categorical"),
    data.frame(unit = factor(seq_len(n)), trait = "gauss_trait",
               value = as.character(round(stats::rnorm(n), 3)),
               family = "gaussian_like")
  )
  ## Unnamed list where list order (multinomial, gaussian) DISAGREES with
  ## what a name-evidence reader would infer from levels
  ## c("categorical","gaussian_like") -- but "categorical"/"gaussian_like"
  ## don't literally spell "multinomial"/"gaussian" either, so this is
  ## actually branch 3 (no evidence) for THIS particular label choice; the
  ## key assertion is only that the resolver is consulted at all and does
  ## not error spuriously.
  fam_list <- list(multinomial(), gaussian())
  attr(fam_list, "family_var") <- "family"
  expect_message(
    out <- expand_multinomial_response(
      value ~ 0 + trait, data = dat, family = fam_list, trait_col = "trait"
    ),
    "no name evidence"
  )
  expect_true(isTRUE(out$expanded))
})
