## #1568: the two-psi cross-checks refit with generated phylo_* + dep/indep
## formulas that never use unit_obs, so the refit must not supply it (it
## triggered "Unused optional grouping argument(s): unit_obs" on every call).

.two_psi_cc_fit <- function() {
  skip_on_cran()
  set.seed(1568)
  n_sp <- 30
  n_tr <- 3
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  traits <- paste0("t", seq_len(n_tr))
  df <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    trait = factor(traits, levels = traits)
  )
  df$value <- rnorm(nrow(df))
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1, unique = TRUE, vcv = Cphy) +
      indep(0 + trait | species),
    data = df,
    trait = "trait",
    unit = "species",
    cluster = "species"
  )))
  list(fit = fit, Cphy = Cphy)
}

.two_psi_cc_run <- function(fn, fit) {
  notes <- character()
  warns <- character()
  res <- withCallingHandlers(
    fn(fit),
    message = function(m) {
      notes <<- c(notes, conditionMessage(m))
      invokeRestart("muffleMessage")
    },
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(res = res, notes = notes, warns = warns)
}

test_that("compare_dep_vs_two_psi() refits without an unused-unit_obs warning (#1568)", {
  x <- .two_psi_cc_fit()
  out <- .two_psi_cc_run(compare_dep_vs_two_psi, x$fit)
  expect_length(out$warns, 0L)
  expect_false(any(grepl("phylo_vcv|phylo_tree", out$notes)))
  expect_false(any(grepl("unit_obs", out$warns)))
  expect_false(is.null(out$res$alt_fit))
})

test_that("compare_indep_vs_two_psi() refits without an unused-unit_obs warning (#1568)", {
  x <- .two_psi_cc_fit()
  out <- .two_psi_cc_run(compare_indep_vs_two_psi, x$fit)
  expect_length(out$warns, 0L)
  expect_false(any(grepl("phylo_vcv|phylo_tree", out$notes)))
  expect_false(any(grepl("unit_obs", out$warns)))
  expect_false(is.null(out$res$alt_fit))
})

test_that("a failed alt refit is reported as a refit failure, not as instability (#1572)", {
  x <- .two_psi_cc_fit()
  testthat::local_mocked_bindings(
    gllvmTMB = function(...) stop("forced structural refusal"),
    .package = "gllvmTMB"
  )
  for (cmp in list(compare_dep_vs_two_psi, compare_indep_vs_two_psi)) {
    msg <- NULL
    res <- withCallingHandlers(
      suppressMessages(cmp(x$fit)),
      warning = function(w) {
        msg <<- c(msg, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    expect_length(msg, 1L)
    expect_match(msg, "forced structural refusal", fixed = TRUE)
    expect_match(msg, "Refit under", fixed = TRUE)
    expect_no_match(msg, "unstable", ignore.case = TRUE)
    expect_null(res$alt_fit)
  }
})

## #1571: both cross-checks report a likelihood-ratio test of the paired fit
## against the refit, next to the descriptive rel_disagreement / flag.
test_that("compare_dep_vs_two_psi() reports the LR test of the nested pair (#1571)", {
  x <- .two_psi_cc_fit()
  res <- suppressWarnings(suppressMessages(compare_dep_vs_two_psi(x$fit)))
  expect_s3_class(res$lrt, "data.frame")
  expect_identical(
    names(res$lrt),
    c("loglik_joint", "loglik_alt", "chi2", "df", "p_value")
  )
  expect_identical(nrow(res$lrt), 1L)
  ll_j <- logLik(x$fit)
  ll_a <- logLik(res$alt_fit)
  expect_equal(res$lrt$loglik_joint, as.numeric(ll_j))
  expect_equal(res$lrt$loglik_alt, as.numeric(ll_a))
  ## The unstructured refit is the full model.
  expect_equal(res$lrt$chi2, 2 * (as.numeric(ll_a) - as.numeric(ll_j)))
  expect_equal(res$lrt$df, attr(ll_a, "df") - attr(ll_j, "df"))
  expect_gt(res$lrt$df, 0)
  expect_equal(
    res$lrt$p_value,
    pchisq(max(res$lrt$chi2, 0), res$lrt$df, lower.tail = FALSE)
  )
  ## Descriptive columns are unchanged.
  expect_true(all(c("rel_disagreement", "flag") %in% names(res$agreement)))
})

test_that("compare_indep_vs_two_psi() reports the LR test with the paired fit as the full model (#1571)", {
  x <- .two_psi_cc_fit()
  res <- suppressWarnings(suppressMessages(compare_indep_vs_two_psi(x$fit)))
  ll_j <- logLik(x$fit)
  ll_a <- logLik(res$alt_fit)
  expect_identical(
    names(res$lrt),
    c("loglik_joint", "loglik_alt", "chi2", "df", "p_value")
  )
  expect_equal(res$lrt$chi2, 2 * (as.numeric(ll_j) - as.numeric(ll_a)))
  expect_equal(res$lrt$df, attr(ll_j, "df") - attr(ll_a, "df"))
  expect_gt(res$lrt$df, 0)
  expect_equal(
    res$lrt$p_value,
    pchisq(max(res$lrt$chi2, 0), res$lrt$df, lower.tail = FALSE)
  )
  expect_true(all(c("rel_disagreement", "flag") %in% names(res$agreement)))
})

test_that("the LR test is NA, not an error, when the refit failed (#1571)", {
  x <- .two_psi_cc_fit()
  testthat::local_mocked_bindings(
    gllvmTMB = function(...) stop("forced structural refusal"),
    .package = "gllvmTMB"
  )
  for (cmp in list(compare_dep_vs_two_psi, compare_indep_vs_two_psi)) {
    res <- suppressWarnings(suppressMessages(cmp(x$fit)))
    expect_true(all(is.na(res$lrt)))
    expect_identical(nrow(res$lrt), 1L)
  }
})

test_that(".two_psi_lrt() is NA for a non-nested phylo-only pair and non-positive df (#1571)", {
  ll <- function(v, k) structure(v, df = k, class = "logLik")
  fj <- structure(list(), class = "fake_joint")
  fa <- structure(list(), class = "fake_alt")
  logLik.fake_joint <- function(object, ...) ll(-100, 10)
  logLik.fake_alt <- function(object, ...) ll(-98, 10)
  registerS3method("logLik", "fake_joint", logLik.fake_joint)
  registerS3method("logLik", "fake_alt", logLik.fake_alt)
  ## No non-phylogenetic term in the paired fit: not nested.
  expect_true(all(is.na(.two_psi_lrt(fj, fa, NULL, alt_is_full = TRUE)[, c("chi2", "df", "p_value")])))
  ## Equal parameter counts: statistic reported, no p-value.
  r <- .two_psi_lrt(fj, fa, matrix(1), alt_is_full = TRUE)
  expect_equal(r$chi2, 4)
  expect_equal(r$df, 0)
  expect_true(is.na(r$p_value))
})

test_that(".two_psi_boundary() reports boundary flags and notes the LR caveat (#1732)", {
  testthat::local_mocked_bindings(
    .gllvmTMB_boundary_flags = function(object, ...) {
      if (identical(object, "joint_fit")) character(0) else "near_zero_sd_B"
    },
    .package = "gllvmTMB"
  )
  expect_message(
    b <- .two_psi_boundary("joint_fit", "alt_fit"),
    "boundary"
  )
  expect_identical(b$joint, character(0))
  expect_identical(b$alt, "near_zero_sd_B")
  ## No flags: silent, and a NULL refit is tolerated.
  expect_silent(b0 <- .two_psi_boundary("joint_fit", NULL))
  expect_identical(b0, list(joint = character(0), alt = character(0)))
})

test_that("both compare functions return a boundary component (#1732)", {
  x <- .two_psi_cc_fit()
  for (cmp in list(compare_dep_vs_two_psi, compare_indep_vs_two_psi)) {
    res <- suppressWarnings(suppressMessages(cmp(x$fit)))
    expect_named(res$boundary, c("joint", "alt"))
    expect_type(res$boundary$joint, "character")
  }
})

test_that("compare_dep_vs_two_psi() flags a boundary fit with pdHess TRUE and notes the LR caveat (#1732)", {
  ## Pure-noise data: the phylogenetic component is truly zero, so the paired
  ## fit sits on a boundary (near_zero_sd_phy_diag) while pdHess stays TRUE.
  x <- .two_psi_cc_fit()
  expect_true(isTRUE(x$fit$sd_report$pdHess))
  for (cmp in list(compare_dep_vs_two_psi, compare_indep_vs_two_psi)) {
    out <- .two_psi_cc_run(cmp, x$fit)
    expect_gt(length(out$res$boundary$joint), 0L)
    expect_true("near_zero_sd_phy_diag" %in% out$res$boundary$joint)
    expect_true(any(grepl("unreliable", out$notes)))
    expect_true(is.finite(out$res$lrt$p_value))
  }
})
