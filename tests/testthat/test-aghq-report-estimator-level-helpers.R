# Characterisation tests for internal helpers that had no direct test:
#   R/aghq-report.R          .aghq_engine_label(), .aghq_check_engine_consistency(),
#                            .aghq_warn_re_gap(), .gllvmTMB_check_reml_comparability(),
#                            .gllvmTMB_anova_global_check(), .gllvmTMB_anova_classify_step()
#   R/estimator-provenance.R .gllvmTMB_resolved_integration(),
#                            .gllvmTMB_attach_estimator_provenance()
#   R/normalise-level.R      .canonical_level_name()
#   R/laplace-accuracy.R     .gllvmTMB_laplace_accuracy_k()
#   R/diagnostic-tables.R    .gllvmTMB_plain_diagnostic_data_frame(),
#                            .gllvmTMB_diagnostic_metadata()
#   R/extract-latent-scores.R extract_latent_scores() S3 dispatch
#
# These pin what the code does on current main. Stand-ins are hand-built lists
# carrying only the fields each helper reads; one tiny Gaussian fit (shared via
# a local helper) covers the dispatch and provenance checks that need a real
# object.

## ---- stand-ins ------------------------------------------------------------

.ahp_mock <- function(REML = FALSE,
                      estimator = "ML",
                      aghq = list(used = FALSE),
                      weighted = FALSE,
                      X_fix_names = c("traitt1", "traitt2"),
                      d_B = 1L,
                      n_traits = 2L,
                      n = 10L,
                      y = seq_len(n),
                      family_id_vec = rep(0L, 2L),
                      use = list(rr_B = TRUE, diag_B = FALSE)) {
  structure(
    list(
      REML = REML,
      estimator = estimator,
      aghq = aghq,
      likelihood_weights = list(active = weighted),
      X_fix_names = X_fix_names,
      d_B = d_B,
      n_traits = n_traits,
      use = use,
      tmb_data = list(y = y, family_id_vec = family_id_vec),
      missing_data = list(counts = list(likelihood_rows = n))
    ),
    class = "gllvmTMB_multi"
  )
}

.ahp_aghq <- function(k = 5L, nodes = 5L) {
  list(
    used = TRUE, k = k,
    reason = sprintf("quadrature on z_B (d = 1, k = %d, %d nodes); x", k, nodes)
  )
}

## The "once" warners remember across the session; reset so each test is
## independent of test order.
.ahp_reset <- function(...) {
  for (id in c(...)) rlang::reset_warning_verbosity(id)
}

.ahp_tiny_fit <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      sim <- simulate_site_trait(
        n_sites = 20, n_species = 4, n_traits = 3, mean_species_per_site = 3,
        Lambda_B = matrix(c(0.9, 0.6, -0.5), nrow = 3, ncol = 1),
        psi_B = rep(0.3, 3), seed = 11
      )
      cache <<- suppressMessages(suppressWarnings(gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | site, d = 1),
        data = sim$data
      )))
    }
    cache
  }
})

## ---- .aghq_engine_label ---------------------------------------------------

test_that(".aghq_engine_label() says Laplace for absent, NULL or unused aghq", {
  expect_equal(.aghq_engine_label(list()), "Laplace")
  expect_equal(.aghq_engine_label(list(aghq = NULL)), "Laplace")
  expect_equal(.aghq_engine_label(list(aghq = list(used = FALSE))), "Laplace")
  expect_equal(.aghq_engine_label(list(aghq = list(used = NA))), "Laplace")
})

test_that(".aghq_engine_label() builds the AGHQ label from k and the parsed node count", {
  expect_equal(.aghq_engine_label(list(aghq = list(used = TRUE))), "AGHQ")
  expect_equal(
    .aghq_engine_label(list(aghq = list(used = TRUE, k = 5L))),
    "AGHQ (k = 5)"
  )
  expect_equal(
    .aghq_engine_label(list(aghq = .ahp_aghq(5L, 5L))),
    "AGHQ (k = 5, 5 nodes)"
  )
  expect_equal(
    .aghq_engine_label(list(aghq = .ahp_aghq(3L, 9L))),
    "AGHQ (k = 3, 9 nodes)"
  )
  ## A missing k drops the whole detail even when a node count is parseable.
  expect_equal(
    .aghq_engine_label(list(aghq = list(used = TRUE, k = NA_integer_, reason = "9 nodes"))),
    "AGHQ"
  )
  ## A reason with no node clause falls back to the k-only label.
  expect_equal(
    .aghq_engine_label(list(aghq = list(used = TRUE, k = 7L, reason = "no clause here"))),
    "AGHQ (k = 7)"
  )
})

test_that(".aghq_engine_label() always writes 'nodes', even for one node", {
  ## Cosmetic, suspected wart: the sprintf has no singular form, so a
  ## one-node fit reads "1 nodes". Pinned as the code produces it.
  expect_equal(
    .aghq_engine_label(list(aghq = list(used = TRUE, k = 3L, reason = "d = 2, k = 3, 1 node"))),
    "AGHQ (k = 3, 1 nodes)"
  )
})

test_that(".aghq_engine_label() of a real Laplace fit is Laplace", {
  skip_on_cran()
  fit <- .ahp_tiny_fit()
  expect_equal(.aghq_engine_label(fit), "Laplace")
})

## ---- .aghq_check_engine_consistency ---------------------------------------

test_that(".aghq_check_engine_consistency() is silent for fewer than two fits", {
  expect_silent(.aghq_check_engine_consistency(list(.ahp_mock())))
  expect_null(.aghq_check_engine_consistency(list(.ahp_mock())))
  ## Non-gllvmTMB objects are skipped, so one fit plus a foreign object is "<2".
  expect_silent(.aghq_check_engine_consistency(list(.ahp_mock(), lm(dist ~ speed, cars))))
})

test_that(".aghq_check_engine_consistency() is silent when engines agree", {
  expect_silent(.aghq_check_engine_consistency(list(.ahp_mock(), .ahp_mock())))
  expect_silent(.aghq_check_engine_consistency(list(
    .ahp_mock(aghq = .ahp_aghq()), .ahp_mock(aghq = .ahp_aghq())
  )))
})

test_that(".aghq_check_engine_consistency() warns on a Laplace/AGHQ mix, then only once", {
  .ahp_reset("gllvmTMB-aghq-cross-engine-aic")
  objs <- list(.ahp_mock(), .ahp_mock(aghq = .ahp_aghq(5L, 5L)))
  expect_warning(
    res <- .aghq_check_engine_consistency(objs),
    "different integration engines: Laplace, AGHQ \\(k = 5, 5 nodes\\)"
  )
  expect_null(res)
  ## .frequency = "once": the second identical clash is silent.
  expect_no_warning(.aghq_check_engine_consistency(objs))
  .ahp_reset("gllvmTMB-aghq-cross-engine-aic")
})

## ---- .aghq_warn_re_gap ----------------------------------------------------

test_that(".aghq_warn_re_gap() is silent unless the fit used AGHQ", {
  expect_silent(.aghq_warn_re_gap(.ahp_mock(), "predict()"))
  expect_null(.aghq_warn_re_gap(.ahp_mock(), "predict()"))
  expect_silent(.aghq_warn_re_gap(list(), "predict()"))
})

test_that(".aghq_warn_re_gap() warns once per fn_label on an AGHQ fit", {
  id <- "gllvmTMB-aghq-re-gap-pin-fn"
  .ahp_reset(id)
  fit <- .ahp_mock(aghq = .ahp_aghq())
  expect_warning(
    res <- .aghq_warn_re_gap(fit, "pin-fn"),
    "pin-fn on an AGHQ-fitted model does not currently include"
  )
  expect_null(res)
  expect_no_warning(.aghq_warn_re_gap(fit, "pin-fn"))
  .ahp_reset(id)
})

## ---- .gllvmTMB_check_reml_comparability -----------------------------------

test_that("REML comparability is silent for <2 fits, no REML fit, and ignores foreign objects", {
  expect_silent(.gllvmTMB_check_reml_comparability(list(.ahp_mock(REML = TRUE))))
  expect_silent(.gllvmTMB_check_reml_comparability(list(.ahp_mock(), .ahp_mock())))
  ## The REML fit is the only gllvmTMB_multi once the foreign object is dropped.
  expect_silent(.gllvmTMB_check_reml_comparability(
    list(.ahp_mock(REML = TRUE), lm(dist ~ speed, cars))
  ))
  expect_null(.gllvmTMB_check_reml_comparability(list(.ahp_mock(), .ahp_mock())))
})

test_that("REML comparability warns, with a class, when REML is mixed with ML", {
  objs <- list(.ahp_mock(REML = TRUE), .ahp_mock(REML = FALSE))
  expect_warning(
    res <- .gllvmTMB_check_reml_comparability(objs, "BIC"),
    class = "gllvmTMB_ic_reml_not_comparable"
  )
  expect_null(res)
  expect_warning(
    .gllvmTMB_check_reml_comparability(objs, "BIC"),
    "BIC\\(\\) is comparing `REML = TRUE` and ML fits"
  )
})

test_that("REML comparability uses AIC as the default fn_label", {
  expect_warning(
    .gllvmTMB_check_reml_comparability(list(.ahp_mock(REML = TRUE), .ahp_mock())),
    "AIC\\(\\) is comparing"
  )
})

test_that("REML comparability warns on REML fits whose fixed effects differ, not on equal sets", {
  a <- .ahp_mock(REML = TRUE, X_fix_names = c("traitt1", "traitt2"))
  b <- .ahp_mock(REML = TRUE, X_fix_names = c("traitt1", "traitt2", "x"))
  expect_warning(
    .gllvmTMB_check_reml_comparability(list(a, b)),
    class = "gllvmTMB_ic_reml_not_comparable"
  )
  expect_warning(
    .gllvmTMB_check_reml_comparability(list(a, b), "AIC"),
    "REML = TRUE` fits with different fixed effects"
  )
  ## Order of the names is irrelevant (the sets are sorted).
  a2 <- .ahp_mock(REML = TRUE, X_fix_names = c("traitt2", "traitt1"))
  expect_silent(.gllvmTMB_check_reml_comparability(list(a, a2)))
})

## ---- .gllvmTMB_anova_global_check -----------------------------------------

test_that("anova global check passes (returns NULL invisibly) for two compatible fits", {
  objs <- list(.ahp_mock(), .ahp_mock())
  expect_silent(res <- .gllvmTMB_anova_global_check(objs))
  expect_null(res)
})

test_that("anova global check refuses an MSPL fit first, even for a single argument", {
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock(estimator = "MSPL"))),
    class = "gllvmTMB_mspl_model_comparison_unsupported"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock(), .ahp_mock(estimator = "mspl"))),
    class = "gllvmTMB_mspl_model_comparison_unsupported"
  )
})

test_that("anova global check refuses fewer than two fits and non-fit arguments", {
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock())),
    class = "gllvmTMB_anova_not_comparable"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock())),
    "needs at least two"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock(), lm(dist ~ speed, cars))),
    class = "gllvmTMB_anova_not_comparable"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock(), lm(dist ~ speed, cars))),
    "1 of 2 argument\\(s\\) are not gllvmTMB fits"
  )
})

test_that("anova global check refuses weighted, non-ML, cross-engine and ridged fits", {
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock(), .ahp_mock(weighted = TRUE))),
    class = "gllvmTMB_weighted_objective_no_information_criterion"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock(), .ahp_mock(estimator = "REML"))),
    "requires ordinary ML fits"
  )
  ## The estimator is upper-cased before the test, so "ml" counts as ML.
  expect_silent(.gllvmTMB_anova_global_check(list(.ahp_mock(estimator = "ml"), .ahp_mock())))
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock(), .ahp_mock(aghq = .ahp_aghq()))),
    "same integration engine"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(
      .ahp_mock(), .ahp_mock(aghq = list(used = FALSE, ridge_tau = 2))
    )),
    "loading ridge"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(
      .ahp_mock(), .ahp_mock(aghq = list(used = FALSE, penalised = TRUE))
    )),
    class = "gllvmTMB_anova_not_comparable"
  )
  ## An infinite ridge tau means "no ridge".
  expect_silent(.gllvmTMB_anova_global_check(list(
    .ahp_mock(), .ahp_mock(aghq = list(used = FALSE, ridge_tau = Inf))
  )))
})

test_that("anova global check refuses differing data, response and family", {
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock(n = 10L), .ahp_mock(n = 12L))),
    "same data"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(.ahp_mock(y = 1:10), .ahp_mock(y = 2:11))),
    "same response data"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(
      .ahp_mock(), .ahp_mock(family_id_vec = c(0L, 1L))
    )),
    "same family/link"
  )
  expect_error(
    .gllvmTMB_anova_global_check(list(
      .ahp_mock(), .ahp_mock(family_id_vec = c(0L, 1L))
    )),
    class = "gllvmTMB_anova_not_comparable"
  )
})

## ---- .gllvmTMB_anova_classify_step ----------------------------------------

test_that("classify_step: added fixed effect with the same rank and routes is 'fixed'", {
  prev <- .ahp_mock(X_fix_names = c("a", "b"))
  curr <- .ahp_mock(X_fix_names = c("a", "b", "c"))
  expect_equal(.gllvmTMB_anova_classify_step(prev, curr), list(kind = "fixed"))
})

test_that("classify_step: one added latent dimension is a 'rank' step carrying its fields", {
  prev <- .ahp_mock(d_B = 1L, n_traits = 4L)
  curr <- .ahp_mock(d_B = 2L, n_traits = 4L)
  expect_equal(
    .gllvmTMB_anova_classify_step(prev, curr),
    list(kind = "rank", delta_d = 1L, p_traits = 4L, d_prev = 1L)
  )
})

test_that("classify_step: a rank increase of more than one is still 'rank' with delta_d = 2", {
  ## The step is not refused here; the doc says "exactly one", but this
  ## helper only requires an increase of at least one. Pinned as written.
  prev <- .ahp_mock(d_B = 1L, n_traits = 5L)
  curr <- .ahp_mock(d_B = 3L, n_traits = 5L)
  res <- .gllvmTMB_anova_classify_step(prev, curr)
  expect_equal(res$kind, "rank")
  expect_equal(res$delta_d, 2L)
})

test_that("classify_step: non-nested fixed effects are 'not_nested'", {
  prev <- .ahp_mock(X_fix_names = c("a", "b"))
  curr <- .ahp_mock(X_fix_names = c("a", "c"))
  expect_equal(.gllvmTMB_anova_classify_step(prev, curr), list(kind = "not_nested"))
})

test_that("classify_step: fixed and rank change together, or a routes change, is 'compound'", {
  prev <- .ahp_mock(X_fix_names = c("a"), d_B = 1L)
  both <- .ahp_mock(X_fix_names = c("a", "b"), d_B = 2L)
  expect_equal(.gllvmTMB_anova_classify_step(prev, both), list(kind = "compound"))

  other_use <- .ahp_mock(use = list(rr_B = TRUE, diag_B = TRUE))
  expect_equal(
    .gllvmTMB_anova_classify_step(.ahp_mock(), other_use),
    list(kind = "compound")
  )
  ## Identical fits (no change at all) are also unclassified.
  expect_equal(
    .gllvmTMB_anova_classify_step(.ahp_mock(), .ahp_mock()),
    list(kind = "compound")
  )
  ## A rank decrease is not a rank step.
  expect_equal(
    .gllvmTMB_anova_classify_step(.ahp_mock(d_B = 2L), .ahp_mock(d_B = 1L)),
    list(kind = "compound")
  )
})

test_that("classify_step: a missing d_B never counts as a rank step", {
  prev <- .ahp_mock(d_B = NULL)
  curr <- .ahp_mock(d_B = 2L)
  expect_equal(.gllvmTMB_anova_classify_step(prev, curr), list(kind = "compound"))
})

## ---- .gllvmTMB_resolved_integration / attach provenance -------------------

test_that(".gllvmTMB_resolved_integration() maps each engine signal to its id", {
  expect_equal(.gllvmTMB_resolved_integration(list()), "laplace")
  expect_equal(.gllvmTMB_resolved_integration(list(aghq = list(used = FALSE))), "laplace")
  expect_equal(.gllvmTMB_resolved_integration(list(integration = "laplace")), "laplace")
  expect_equal(.gllvmTMB_resolved_integration(list(aghq = list(used = TRUE))), "aghq")
  expect_equal(.gllvmTMB_resolved_integration(list(integration = "va")), "va")
  expect_equal(
    .gllvmTMB_resolved_integration(structure(list(), class = "gllvmTMB_va")),
    "va"
  )
  ## VA wins over AGHQ when both signals are present.
  expect_equal(
    .gllvmTMB_resolved_integration(list(integration = "va", aghq = list(used = TRUE))),
    "va"
  )
})

test_that("attach_estimator_provenance() stores the resolved row on the fit", {
  out <- .gllvmTMB_attach_estimator_provenance(list(a = 1))
  expect_equal(out$a, 1)
  prov <- out$estimator_provenance
  expect_equal(prov$integration, "laplace")
  expect_equal(prov$criterion_id, "la_ml")
  expect_equal(prov$estimator_id, 0L)
  expect_equal(prov$public_estimator, "ML")
  expect_false(prov$public_estimator_is_coarse)
  expect_equal(prov$tape_role, "primary")
  expect_equal(prov$notes, character(0))
})

test_that("attach_estimator_provenance() derives the integration from the fit when NULL", {
  aghq <- .gllvmTMB_attach_estimator_provenance(list(aghq = list(used = TRUE)))
  expect_equal(aghq$estimator_provenance$integration, "aghq")
  expect_true(aghq$estimator_provenance$public_estimator_is_coarse)
  expect_match(aghq$estimator_provenance$notes, "uses AGHQ, not Laplace", fixed = TRUE)

  va <- .gllvmTMB_attach_estimator_provenance(list(integration = "va"))
  expect_equal(va$estimator_provenance$integration, "va")
  expect_equal(va$estimator_provenance$criterion_id, "va_elbo")
  expect_true(is.na(va$estimator_provenance$estimator_id))
  expect_match(va$estimator_provenance$notes, "variational objective", fixed = TRUE)
})

test_that("attach_estimator_provenance() lets an explicit integration override the fit", {
  out <- .gllvmTMB_attach_estimator_provenance(
    list(aghq = list(used = TRUE)), integration = "laplace"
  )
  expect_equal(out$estimator_provenance$integration, "laplace")
  expect_false(out$estimator_provenance$public_estimator_is_coarse)
})

test_that("attach_estimator_provenance() resolves REML and MSPL rows", {
  reml <- .gllvmTMB_attach_estimator_provenance(list(), reml = TRUE)$estimator_provenance
  expect_equal(reml$public_estimator, "REML")
  expect_equal(reml$criterion_id, "reml")

  mspl <- .gllvmTMB_attach_estimator_provenance(list(), estimator = "mspl")$estimator_provenance
  expect_equal(mspl$public_estimator, "MSPL")
  expect_equal(mspl$estimator_id, 1L)
  expect_equal(mspl$penalty_eval_id, "on")
  ## The primary MSPL tape also records the penalty-off provenance tape.
  expect_equal(mspl$penalty_off_tape$estimator_id, 2L)
  expect_equal(mspl$penalty_off_tape$penalty_eval_id, "provenance_off")
})

test_that("a real Laplace fit carries the provenance this helper would attach", {
  skip_on_cran()
  fit <- .ahp_tiny_fit()
  expect_equal(.gllvmTMB_resolved_integration(fit), "laplace")
  prov <- fit$estimator_provenance
  expect_equal(prov$integration, "laplace")
  expect_equal(prov$estimator_id, 0L)
  again <- .gllvmTMB_attach_estimator_provenance(fit)
  expect_equal(again$estimator_provenance$integration, "laplace")
  expect_equal(again$estimator_provenance$criterion_id, "la_ml")
})

## ---- .canonical_level_name ------------------------------------------------

test_that(".canonical_level_name() maps each internal tier id to its canonical name", {
  expect_equal(.canonical_level_name("B"), "unit")
  expect_equal(.canonical_level_name("B_slope"), "unit_slope")
  expect_equal(.canonical_level_name("W"), "unit_obs")
  expect_equal(.canonical_level_name("spde"), "spatial")
  expect_equal(.canonical_level_name("total"), "Omega")
})

test_that(".canonical_level_name() passes canonical and unknown names through", {
  expect_equal(.canonical_level_name("unit"), "unit")
  expect_equal(.canonical_level_name("unit_obs"), "unit_obs")
  expect_equal(.canonical_level_name("zzz"), "zzz")
  ## Matching is case-sensitive.
  expect_equal(.canonical_level_name("b"), "b")
})

test_that(".canonical_level_name() returns non-scalar-character input unchanged", {
  expect_equal(.canonical_level_name(c("B", "W")), c("B", "W"))
  expect_equal(.canonical_level_name(1), 1)
  expect_null(.canonical_level_name(NULL))
  expect_equal(.canonical_level_name(NA_character_), NA_character_)
})

## ---- .gllvmTMB_laplace_accuracy_k -----------------------------------------

test_that(".gllvmTMB_laplace_accuracy_k() gives 15, 9, 5 nodes for d = 1, 2, 3", {
  expect_equal(.gllvmTMB_laplace_accuracy_k(1L), 15L)
  expect_equal(.gllvmTMB_laplace_accuracy_k(2L), 9L)
  expect_equal(.gllvmTMB_laplace_accuracy_k(3L), 5L)
  expect_type(.gllvmTMB_laplace_accuracy_k(2L), "integer")
  expect_equal(.gllvmTMB_laplace_accuracy_k(2), 9L)
})

test_that(".gllvmTMB_laplace_accuracy_k() errors outside d = 1..3 (callers gate d <= 3)", {
  ## Plain base-R subscript errors; no package condition class exists here.
  expect_error(.gllvmTMB_laplace_accuracy_k(4L), "subscript out of bounds")
  expect_error(.gllvmTMB_laplace_accuracy_k(0L))
})

## ---- diagnostic table helpers ---------------------------------------------

test_that(".gllvmTMB_plain_diagnostic_data_frame() strips tibble classes and diagnostic attributes", {
  x <- data.frame(a = 1:2, b = c("x", "y"), row.names = c("r1", "r2"))
  class(x) <- c("tbl_df", "tbl", "data.frame")
  attr(x, "gllvmTMB_diagnostic") <- list(note = "kept?")
  attr(x, "method") <- "rq"
  out <- .gllvmTMB_plain_diagnostic_data_frame(x)
  expect_s3_class(out, "data.frame")
  expect_equal(class(out), "data.frame")
  expect_null(attr(out, "gllvmTMB_diagnostic"))
  expect_null(attr(out, "method"))
  expect_equal(rownames(out), c("1", "2"))
  expect_equal(out$a, 1:2)
  expect_equal(out$b, c("x", "y"))
})

test_that(".gllvmTMB_plain_diagnostic_data_frame() keeps extra attributes it does not name", {
  x <- data.frame(a = 1:2)
  attr(x, "other") <- "stay"
  expect_equal(attr(.gllvmTMB_plain_diagnostic_data_frame(x), "other"), "stay")
})

test_that(".gllvmTMB_plain_diagnostic_data_frame() coerces a plain list or matrix to a data.frame", {
  out <- .gllvmTMB_plain_diagnostic_data_frame(list(a = 1:2, b = 3:4))
  expect_equal(class(out), "data.frame")
  expect_equal(names(out), c("a", "b"))
  out_m <- .gllvmTMB_plain_diagnostic_data_frame(matrix(1:4, 2, dimnames = list(NULL, c("p", "q"))))
  expect_equal(class(out_m), "data.frame")
  expect_equal(names(out_m), c("p", "q"))
})

test_that(".gllvmTMB_diagnostic_metadata() returns the attribute list and aborts otherwise", {
  meta <- list(data = data.frame(a = 1))
  x <- structure(1, gllvmTMB_diagnostic = meta)
  expect_equal(.gllvmTMB_diagnostic_metadata(x), meta)
  expect_error(
    .gllvmTMB_diagnostic_metadata(data.frame(a = 1)),
    "does not carry gllvmTMB diagnostic metadata"
  )
  ## A non-list attribute is refused too.
  expect_error(
    .gllvmTMB_diagnostic_metadata(structure(1, gllvmTMB_diagnostic = "text")),
    "does not carry"
  )
})

test_that("diagnostic_metadata abort uses the rlang error class chain", {
  err <- tryCatch(.gllvmTMB_diagnostic_metadata(1), error = identity)
  expect_s3_class(err, "rlang_error")
  expect_s3_class(err, "error")
})

## ---- extract_latent_scores() dispatch -------------------------------------

test_that("extract_latent_scores.default() aborts with the 'No method' message and the first class", {
  err <- tryCatch(extract_latent_scores(1:3), error = identity)
  expect_s3_class(err, "rlang_error")
  expect_match(conditionMessage(err), "No method for `extract_latent_scores()`", fixed = TRUE)
  expect_match(conditionMessage(err), "objects of class <integer>", fixed = TRUE)
  expect_match(conditionMessage(err), "gllvmTMB_multi", fixed = TRUE)
  expect_match(conditionMessage(err), "gllvmTMB_site_trait_sim", fixed = TRUE)
  expect_match(conditionMessage(err), "simulate_site_trait()", fixed = TRUE)

  expect_error(extract_latent_scores(data.frame(a = 1)), "<data.frame>")
  expect_error(extract_latent_scores(NULL), "<NULL>")
  expect_error(extract_latent_scores(list()), "<list>")
  ## The message names only the first class of a multi-class object.
  expect_error(
    extract_latent_scores(structure(list(), class = c("foo", "bar"))),
    "<foo>"
  )
})

test_that("extract_latent_scores() dispatches a site-trait simulation to its generating scores", {
  sim <- simulate_site_trait(
    n_sites = 8, n_species = 4, n_traits = 3, mean_species_per_site = 3,
    Lambda_B = matrix(c(0.9, 0.6, -0.5), nrow = 3, ncol = 1),
    psi_B = rep(0.3, 3), seed = 5
  )
  expect_s3_class(sim, "gllvmTMB_site_trait_sim")
  z <- extract_latent_scores(sim, level = "unit")
  expect_equal(z, sim$truth$z_B)
  expect_equal(extract_latent_scores(sim), sim$truth$z_B)
  ## The legacy alias still works but is deprecated.
  expect_warning(zb <- extract_latent_scores(sim, level = "B"), "deprecated")
  expect_equal(zb, sim$truth$z_B)
  ## No within-unit loadings were simulated, so unit_obs has no scores.
  expect_null(sim$truth$z_W)
  expect_null(extract_latent_scores(sim, level = "unit_obs"))
  expect_error(extract_latent_scores(sim, level = "zzz"), "should be one of")
})

test_that("extract_latent_scores() dispatches a real fit to the gllvmTMB_multi method", {
  skip_on_cran()
  fit <- .ahp_tiny_fit()
  expect_s3_class(fit, "gllvmTMB_multi")
  z <- extract_latent_scores(fit, level = "unit")
  expect_equal(z, extract_latent_scores.gllvmTMB_multi(fit, level = "unit"))
  expect_equal(nrow(z), 20L)
  expect_equal(ncol(z), 1L)
  ## Default level is "unit".
  expect_equal(extract_latent_scores(fit), z)
  ## No unit_obs tier on this fit.
  expect_null(extract_latent_scores(fit, level = "unit_obs"))
})
