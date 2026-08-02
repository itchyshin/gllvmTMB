## Cross-package corpus adoption -- glmmTMB's shipped GLMM test corpus.
##
## Issue #800 (first item): "adopt glmmTMB's shipped test corpus for the
## GLMM backbone." glmmTMB ships 32 fitted `glmmTMB` models + 3 `lmerMod`
## twins + supporting data.frames at
## `file.path(find.package("glmmTMB"), "test_data", "models.rda")`.
##
## LICENSING: glmmTMB is AGPL-3; this package is GPL-3. We do NOT copy,
## vendor, or commit any of glmmTMB's test files or data -- the corpus is
## read at test time, straight from the installed package, and never
## written to disk here. It is also not part of glmmTMB's public API, so
## every entry point below skips with a clear reason if it is absent.
##
## ---- The central finding (read this before extending the file) -------
## gllvmTMB is NOT a general single-response GLMM engine. Per
## docs/design/04-sister-package-scope.md: "Rule: single-response models
## live in glmmTMB. Even if you plan to add more responses later, the
## gllvmTMB path requires a real (unit, trait) row layout from the
## start." This is enforced in code: `gllvmTMB()` throws
## "Column trait not found in data" when `trait` is absent, and throws a
## contrasts error when `trait` has fewer than 2 levels. Every one of
## glmmTMB's 32 shipped fits (and all 3 lmerMod twins) is a genuine
## single-response model, so NONE of them can be refit "as shipped" --
## same formula, same data, zero modification.
##
## What IS representable: five of the corpus's fitted objects sit on
## data that already carries a second categorical dimension -- a factor
## glmmTMB used only as an ordinary fixed effect, or a nesting factor
## that expands to a second grouping level, or a column that exists in
## the source data.frame but is unused by the fitted formula -- and that
## dimension can legitimately be relabelled as gllvmTMB's mandatory
## `trait` axis without changing the statistical model (verified below
## by a live fit, not merely asserted). Where that mapping exists AND the
## random-effects side of the model is nothing more than bare
## `(1 | group)` intercepts, the reparametrised gllvmTMB fit agrees with
## the shipped glmmTMB/lmerMod fit to numerical-optimiser tolerance.
## gllvmTMB's plain lme4-style pass-through does not yet implement bare
## random SLOPES -- `(x | g)` / `(0 + x | g)` outside the
## `latent()`/`dep()`/`indep()`/`unique()` keyword grammar throws
## "Bar-syntax `(x | g)` is not yet implemented" from
## `parse_re_int_call()` in R/parse-multi-formula.R -- and no keyword
## route exists for a single continuous-covariate slope on a single
## response, so every slope-RE model in the corpus is out of scope too.
##
## Classification buckets (see the triage test below for the
## programmatic count):
##   * no_re                      -- no random effects at all (plain
##                                    GLM); outside gllvmTMB's
##                                    grouped-data scope.
##   * unsupported_corr_structure -- ar1()/cs()/homcs()/hetar1(): glmmTMB
##                                    correlation structures gllvmTMB does
##                                    not implement.
##   * bare_slope_unsupported     -- a bare `(x | g)` / `(0 + x | g)` term
##                                    that is not a pure intercept.
##   * intercept_only_bare        -- every RE term is a bare `(1 | g)`
##                                    intercept (nested forms included).
##                                    Representability within this bucket
##                                    is a data-shape question the
##                                    formula text alone cannot answer,
##                                    so it is recorded by hand below and
##                                    each case is verified by a live fit.

skip_if_not_glmmTMB_corpus <- function() {
  testthat::skip_if_not_installed("glmmTMB")
  testthat::skip_if_not_installed("lme4")
  path <- file.path(find.package("glmmTMB"), "test_data", "models.rda")
  if (!file.exists(path)) {
    testthat::skip(paste(
      "glmmTMB's shipped test corpus (test_data/models.rda) is not",
      "present in this glmmTMB install"
    ))
  }
  path
}

load_glmmtmb_corpus <- function() {
  path <- skip_if_not_glmmTMB_corpus()
  e <- new.env()
  load(path, envir = e)
  e
}

# ---- Programmatic triage ----------------------------------------------

.glmmtmb_special_corr_fns <- c("ar1", "cs", "homcs", "hetar1",
                               "toep", "homtoep", "ou", "hetou")

classify_glmmtmb_fit <- function(obj) {
  form <- formula(obj)
  bars <- suppressWarnings(lme4::findbars(form))
  if (length(bars) == 0L) return("no_re")
  form_txt <- paste(deparse(form), collapse = " ")
  has_special <- any(vapply(.glmmtmb_special_corr_fns, function(fn) {
    grepl(paste0("\\b", fn, "\\("), form_txt)
  }, logical(1)))
  if (has_special) return("unsupported_corr_structure")
  bare_txt <- vapply(bars, function(b) paste(deparse(b), collapse = " "),
                     character(1))
  is_intercept_only <- grepl("^1 \\|", bare_txt)
  if (!all(is_intercept_only)) return("bare_slope_unsupported")
  "intercept_only_bare"
}

## Within `intercept_only_bare`, representability depends on whether a
## genuine second categorical dimension exists to serve as gllvmTMB's
## `trait` axis -- a data-shape judgement verified below by actually
## fitting each case, not something derivable from the formula text
## alone, so it is recorded here rather than re-derived programmatically.
.intercept_only_bare_reasons <- c(
  fm1          = "sleepstudy carries no second categorical factor besides Subject/Days -- NOT representable",
  fm_nest      = "Subject/fDays nesting supplies a real trait axis (fDays) -- representable",
  fm_nest_lmer = "lmerMod twin of fm_nest -- representable",
  fmP          = "cask is a saturated 3-level factor FE -- representable via 0 + trait",
  gm0          = "period exists in cbpp, unused in the fitted formula -- representable as a pooled trait axis",
  gm1          = "period is the only factor FE -- representable via 0 + trait"
)
.representable_models <- names(.intercept_only_bare_reasons)[
  !grepl("NOT representable", .intercept_only_bare_reasons)
]

test_that("triage: classify glmmTMB's shipped corpus against gllvmTMB's grammar", {
  e <- load_glmmtmb_corpus()
  nms <- ls(e)
  is_fit <- vapply(nms, function(n) {
    inherits(get(n, envir = e), c("glmmTMB", "lmerMod"))
  }, logical(1))
  fit_nms <- nms[is_fit]
  expect_equal(
    length(fit_nms), 35L,
    info = paste(
      "expected 32 glmmTMB fits + 3 lmerMod twins;",
      "the shipped corpus shape has changed upstream -- re-triage needed"
    )
  )

  buckets <- vapply(fit_nms, function(n) {
    classify_glmmtmb_fit(get(n, envir = e))
  }, character(1))

  expect_equal(unname(sum(buckets == "no_re")), 8L)
  expect_equal(unname(sum(buckets == "unsupported_corr_structure")), 6L)
  expect_equal(unname(sum(buckets == "bare_slope_unsupported")), 15L)
  expect_equal(unname(sum(buckets == "intercept_only_bare")), 6L)
  expect_setequal(
    names(buckets)[buckets == "intercept_only_bare"],
    names(.intercept_only_bare_reasons)
  )
  expect_setequal(.representable_models,
                  c("fm_nest", "fm_nest_lmer", "fmP", "gm0", "gm1"))
})

# ---- Representable subset: assert agreement ----------------------------

test_that("gllvmTMB reproduces glmmTMB::gm0 (cbpp, binomial, intercept-only + (1|herd)) via a pooled trait axis", {
  skip_on_cran()
  e <- load_glmmtmb_corpus()

  cbpp <- e$cbpp
  ## `trait` is unused in the formula below -- it exists purely to
  ## satisfy gllvmTMB's >=2-level trait-column requirement, matching
  ## gm0's own choice not to model a period effect.
  cbpp$trait <- factor(cbpp$period)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(incidence, size - incidence) ~ 1 + (1 | herd),
    data = cbpp, unit = "herd", trait = "trait", family = binomial()
  )))
  expect_equal(fit$opt$convergence, 0L)

  ll_g    <- as.numeric(logLik(fit))
  ll_glmm <- as.numeric(logLik(e$gm0))
  expect_equal(ll_g, ll_glmm, tolerance = 1e-4)

  td      <- gllvmTMB::tidy(fit, "fixed", conf.int = FALSE)
  glmm_fx <- glmmTMB::fixef(e$gm0)$cond
  expect_lt(
    abs(td$estimate[td$term == "(Intercept)"] - glmm_fx[["(Intercept)"]]),
    1e-3
  )
})

test_that("gllvmTMB reproduces glmmTMB::gm1 (cbpp, binomial, period + (1|herd)) with period as trait", {
  skip_on_cran()
  e <- load_glmmtmb_corpus()

  cbpp <- e$cbpp
  cbpp$trait <- factor(cbpp$period)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    cbind(incidence, size - incidence) ~ 0 + trait + (1 | herd),
    data = cbpp, unit = "herd", trait = "trait", family = binomial()
  )))
  expect_equal(fit$opt$convergence, 0L)

  ll_g    <- as.numeric(logLik(fit))
  ll_glmm <- as.numeric(logLik(e$gm1))
  expect_equal(ll_g, ll_glmm, tolerance = 1e-4)

  td      <- gllvmTMB::tidy(fit, "fixed", conf.int = FALSE)
  glmm_fx <- glmmTMB::fixef(e$gm1)$cond
  ## glmmTMB's default treatment contrasts (period 1 = baseline)
  ## reparametrise to gllvmTMB's 0 + trait cell means:
  ## trait_k = Intercept + period_k (k > 1).
  cellmeans <- c(
    glmm_fx[["(Intercept)"]],
    glmm_fx[["(Intercept)"]] + glmm_fx[["period2"]],
    glmm_fx[["(Intercept)"]] + glmm_fx[["period3"]],
    glmm_fx[["(Intercept)"]] + glmm_fx[["period4"]]
  )
  names(cellmeans) <- paste0("trait", 1:4)
  ordered_est <- td$estimate[match(names(cellmeans), td$term)]
  expect_lt(max(abs(ordered_est - cellmeans)), 1e-3)
})

test_that("gllvmTMB reproduces glmmTMB::fmP (Pastes, gaussian, cask + (1|batch) + (1|sample)) with cask as trait", {
  skip_on_cran()
  e <- load_glmmtmb_corpus()

  Pastes <- e$Pastes
  Pastes$trait <- Pastes$cask
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    strength ~ 0 + trait + (1 | batch) + (1 | sample),
    data = Pastes, unit = "batch", trait = "trait"
  )))
  expect_equal(fit$opt$convergence, 0L)

  ll_g    <- as.numeric(logLik(fit))
  ll_glmm <- as.numeric(logLik(e$fmP))
  expect_equal(ll_g, ll_glmm, tolerance = 1e-4)

  td      <- gllvmTMB::tidy(fit, "fixed", conf.int = FALSE)
  glmm_fx <- glmmTMB::fixef(e$fmP)$cond
  cellmeans <- c(
    glmm_fx[["(Intercept)"]],
    glmm_fx[["(Intercept)"]] + glmm_fx[["caskb"]],
    glmm_fx[["(Intercept)"]] + glmm_fx[["caskc"]]
  )
  names(cellmeans) <- c("traita", "traitb", "traitc")
  ordered_est <- td$estimate[match(names(cellmeans), td$term)]
  expect_lt(max(abs(ordered_est - cellmeans)), 1e-3)
})

test_that("gllvmTMB reproduces glmmTMB::fm_nest and its lmerMod twin fm_nest_lmer (Subject/fDays nesting -> fDays as trait)", {
  skip_on_cran()
  e <- load_glmmtmb_corpus()

  ## Read the exact data the shipped fit used (fm_nest$frame), rather
  ## than guessing which named corpus data.frame it came from.
  df <- e$fm_nest$frame
  df$trait <- df$fDays
  ## glmmTMB's `(1 | Subject/fDays)` expands to `(1|Subject) +
  ## (1|Subject:fDays)`; gllvmTMB has no `/`-nesting shorthand, so the
  ## Subject:fDays interaction is built explicitly as an ordinary second
  ## grouping factor.
  df$subject_fdays <- interaction(df$Subject, df$fDays, drop = TRUE)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    Reaction ~ Days + (1 | Subject) + (1 | subject_fdays),
    data = df, unit = "Subject", trait = "trait"
  )))
  expect_equal(fit$opt$convergence, 0L)

  ll_g    <- as.numeric(logLik(fit))
  ll_glmm <- as.numeric(logLik(e$fm_nest))
  ll_lmer <- as.numeric(logLik(e$fm_nest_lmer))
  expect_equal(ll_glmm, ll_lmer, tolerance = 1e-4,
               label = "sanity: glmmTMB and its own lmerMod twin should already agree")
  expect_equal(ll_g, ll_glmm, tolerance = 1e-4)

  td       <- gllvmTMB::tidy(fit, "fixed", conf.int = FALSE)
  glmm_fx  <- glmmTMB::fixef(e$fm_nest)$cond
  lmer_fx  <- lme4::fixef(e$fm_nest_lmer)
  expect_lt(abs(td$estimate[td$term == "(Intercept)"] - glmm_fx[["(Intercept)"]]), 1e-3)
  expect_lt(abs(td$estimate[td$term == "Days"] - glmm_fx[["Days"]]), 1e-3)
  expect_lt(abs(td$estimate[td$term == "(Intercept)"] - lmer_fx[["(Intercept)"]]), 1e-3)
  expect_lt(abs(td$estimate[td$term == "Days"] - lmer_fx[["Days"]]), 1e-3)
})
