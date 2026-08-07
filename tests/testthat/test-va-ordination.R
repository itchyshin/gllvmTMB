## Tests for the VA ordination surface: extract_ordination()'s gllvmTMB_va
## branch, and the getLoadings()/extract_loadings()/getLV() accessors that
## funnel through it, plus getLV(se = TRUE)'s eval_method gate and the new
## refusing predict.gllvmTMB_va(). Shares the small binomial-logit fixture
## style of test-va-intervals.R.
##
## Fixed-effect VA-Wald behavior is tested in test-va-intervals.R; this file
## retains a fail-closed check for malformed/unhealthy VA objects.

skip_on_cran()

## ---------------------------------------------------------------------
## Shared fixtures: small, fast, healthy VA-R3 binomial-logit fits built
## directly from the engine adapter (bypassing gllvmTMB()'s formula parsing,
## as test-va-intervals.R's own fixture does). N=30 units, T=5 traits, q=1.
## ---------------------------------------------------------------------

.va_ordination_fixture <- function(seed = 20260805L, N = 30L, Tn = 5L, q = 1L,
                                   eval_method = "jj",
                                   family = "binomial", link = "logit") {
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(Tn))
  long <- data.frame(
    unit = factor(rep(seq_len(N), each = Tn)),
    trait = factor(rep(trait_names, N), levels = trait_names)
  )
  beta_true <- seq(0.2, by = 0.15, length.out = Tn)
  Lambda_true <- matrix(c(0.6, 0.4, -0.3, 0.5, 0.2)[seq_len(Tn * q)], Tn, q)
  score <- matrix(stats::rnorm(N * q), N, q)
  unit <- as.integer(long$unit)
  trait <- as.integer(long$trait)
  eta <- beta_true[trait] +
    rowSums(Lambda_true[trait, , drop = FALSE] * score[unit, , drop = FALSE])
  y <- stats::rbinom(N * Tn, 1L, stats::plogis(eta))
  n_trials <- rep(1L, N * Tn)
  X <- stats::model.matrix(~ 0 + trait, long)

  engine_fit <- .approximation_engine_va_r3_fit(
    y = y, n_trials = n_trials, X = X, unit_id = unit, trait_id = trait,
    q = q, family = family, link = link, H = 15L, eval_method = eval_method
  )
  fit <- .va_route_build_fit(
    engine_fit, call = quote(dummy_call()), q = q, p = Tn, n = N,
    eval_method = eval_method, family = family, link = link
  )
  list(fit = fit, N = N, Tn = Tn, q = q)
}

## Built once and reused -- fitting is the expensive part.
fx <- .va_ordination_fixture()                    ## eval_method = "jj" (default tier for pure binomial)
fx_gh <- .va_ordination_fixture(eval_method = "gh") ## same data, gh tier

test_that("fixture VA fits are healthy (precondition for every test below)", {
  expect_identical(fx$fit$status, "healthy")
  expect_identical(fx_gh$fit$status, "healthy")
})

## ---------------------------------------------------------------------
## (1) extract_ordination()'s gllvmTMB_va branch
## ---------------------------------------------------------------------

test_that("extract_ordination() returns a unit-level VA ordination with synthesised names", {
  ord <- extract_ordination(fx$fit, level = "unit")
  expect_equal(dim(ord$scores), c(fx$N, fx$q))
  expect_equal(dim(ord$loadings), c(fx$Tn, fx$q))
  expect_identical(rownames(ord$scores), paste0("unit", seq_len(fx$N)))
  expect_identical(rownames(ord$loadings), paste0("trait", seq_len(fx$Tn)))
  expect_identical(colnames(ord$scores), colnames(ord$loadings))
  expect_identical(ord$row_id, paste0("unit", seq_len(fx$N)))
  expect_true(all(is.finite(ord$scores)))
  expect_true(all(is.finite(ord$loadings)))
})

test_that("extract_ordination() returns NULL at level = 'unit_obs' for a VA fit (no within-unit tier)", {
  expect_null(extract_ordination(fx$fit, level = "unit_obs"))
})

test_that("extract_ordination()'s VA component argument: total == innovation, mean == 0 always", {
  ord_total <- extract_ordination(fx$fit, level = "unit", component = "total")
  ord_innovation <- extract_ordination(fx$fit, level = "unit", component = "innovation")
  ord_mean <- extract_ordination(fx$fit, level = "unit", component = "mean")
  expect_equal(ord_total$scores, ord_innovation$scores)
  expect_true(all(ord_mean$scores == 0))
})

test_that("extract_ordination() errors, not nonsense, on a VA fit with no fitted parameter vector", {
  fake_va <- structure(list(engine_result = list()), class = c("gllvmTMB_va", "gllvmTMB"))
  expect_error(extract_ordination(fake_va, level = "unit"), "no fitted parameter vector")
})

## ---------------------------------------------------------------------
## getLoadings() / extract_loadings() / getLV() point estimates -- all four
## funnel through extract_ordination(), so fixing it brings all four alive.
## ---------------------------------------------------------------------

test_that("getLoadings()/extract_loadings() work for a VA fit and agree with extract_ordination()", {
  l1 <- getLoadings(fx$fit)
  l2 <- extract_loadings(fx$fit)
  ord <- extract_ordination(fx$fit, level = "unit")
  expect_identical(l1, l2)
  expect_identical(l1, ord$loadings)
  expect_equal(dim(l1), c(fx$Tn, fx$q))
})

test_that("getLV() point estimates work for a VA fit and match extract_ordination()", {
  scores <- getLV(fx$fit)
  ord <- extract_ordination(fx$fit, level = "unit")
  expect_identical(scores, ord$scores)
})

test_that("getLV(level = 'unit_obs') is NULL for a VA fit", {
  expect_null(getLV(fx$fit, level = "unit_obs"))
})

## ---------------------------------------------------------------------
## (2) getLV(se = TRUE) -- gated on eval_method
## ---------------------------------------------------------------------

test_that("getLV(se = TRUE) is refused under eval_method = 'jj' (no established informativeness)", {
  expect_error(getLV(fx$fit, se = TRUE), "eval_method")
})

test_that("getLV(se = TRUE) is refused under eval_method = 'ac' -- the established machine-zero finding", {
  ## A minimal fake object exercises the CONTRACT (refusal) without paying for
  ## a real binomial-probit AC fit; the underlying machine-zero collapse
  ## itself is independently measured elsewhere (dev/va-speed/32-gh-vs-ac-
  ## per-unit-spread.R, docs/design/va-latent-uncertainty.md).
  fake_ac <- structure(
    list(
      eval_method = "ac",
      engine_result = list(latent = list(
        scores = matrix(0, 2, 1), se = matrix(1, 2, 1)
      ))
    ),
    class = c("gllvmTMB_va", "gllvmTMB")
  )
  expect_error(
    .va_getLV_se(fake_ac, scores = matrix(0, 2, 1)),
    "same value for every unit"
  )
})

test_that("getLV(se = TRUE) returns a labelled posterior SD under eval_method = 'gh'", {
  out <- getLV(fx_gh$fit, se = TRUE)
  expect_equal(dim(out$se), dim(out$scores))
  expect_identical(dimnames(out$se), dimnames(out$scores))
  expect_true(all(is.finite(out$se)))
  expect_true(all(out$se > 0))
  ## Explicit, in-band disclosure that this is a posterior SD, not a
  ## frequentist standard error -- not just documentation prose.
  expect_false(isTRUE(attr(out$se, "calibrated")))
  expect_match(attr(out$se, "uncertainty_basis"), "variational posterior")
})

test_that("getLV(se = TRUE) still refuses for engine = 'julia' bridge fits (unaffected by this slice)", {
  fake_julia <- structure(list(), class = c("gllvmTMB_julia", "gllvmTMB_multi"))
  expect_error(getLV(fake_julia, se = TRUE), "bridge fits")
})

## ---------------------------------------------------------------------
## (3) predict.gllvmTMB_va()
## ---------------------------------------------------------------------

test_that("predict() refuses for a VA fit with a clear, VA-specific message instead of a bare dispatch error", {
  expect_error(predict(fx$fit), "variational fit")
})

## ---------------------------------------------------------------------
## Fixed-effect VA-Wald still fails closed for an invalid object.
## ---------------------------------------------------------------------

test_that("confint.gllvmTMB_va() and vcov.gllvmTMB_va() refuse an invalid VA object", {
  fake_va <- structure(list(), class = c("gllvmTMB_va", "gllvmTMB"))
  expect_error(confint(fake_va), "healthy variational fit")
  expect_error(vcov(fake_va), "healthy variational fit")
})

## ---------------------------------------------------------------------
## Degeneracy gate on getLV(se = TRUE).
##
## Regression for an adversarial-review finding (2026-08-05): gating on
## `eval_method` alone left a live hole. The "ac" branch is UNREACHABLE from
## the public route (R/va-routing.R:350-355 emits only "jj"/"gh"), while a
## public GAUSSIAN fit resolves to "gh" and returned a per-unit SD that was
## constant across every unit (measured CV 1.6e-15) -- one row per unit,
## carrying no per-unit information, which is precisely what the "ac"
## refusal existed to prevent. The gate now tests the observable property.
## ---------------------------------------------------------------------

test_that(".va_getLV_se() refuses a per-unit SD that is constant across units", {
  scores <- matrix(stats::rnorm(20L), nrow = 10L, ncol = 2L,
                   dimnames = list(paste0("unit", 1:10), c("LV1", "LV2")))
  degenerate <- structure(
    list(eval_method = "gh",
         engine_result = list(latent = list(se = matrix(0.7, 10L, 2L)))),
    class = c("gllvmTMB_va", "gllvmTMB")
  )
  expect_error(
    gllvmTMB:::.va_getLV_se(degenerate, scores = scores),
    class = "gllvmTMB_getLV_se_va_degenerate"
  )
})

test_that(".va_getLV_se() admits a genuinely varying per-unit SD", {
  scores <- matrix(stats::rnorm(20L), nrow = 10L, ncol = 2L,
                   dimnames = list(paste0("unit", 1:10), c("LV1", "LV2")))
  varying <- structure(
    list(eval_method = "gh",
         engine_result = list(
           latent = list(se = cbind(seq(0.4, 1.3, length.out = 10L),
                                    seq(0.5, 0.9, length.out = 10L))))),
    class = c("gllvmTMB_va", "gllvmTMB")
  )
  se <- gllvmTMB:::.va_getLV_se(varying, scores = scores)
  expect_equal(dim(se), c(10L, 2L))
  expect_false(attr(se, "calibrated"))
})
