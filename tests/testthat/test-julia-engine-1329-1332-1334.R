# Regression tests for the engine = "julia" route:
#   #1329 tidy(), residuals(type = "simulation_rank") and check_gllvmTMB()
#         on Julia bridge fits;
#   #1332 the bridge family gate must admit the exported ordinal_logit();
#   #1334 multi-trait Gamma must not silently fit one shared shape.
#
# Everything except the final block runs without Julia: the R-side gates fire
# before any JuliaCall setup, and the post-fit methods read the retained
# bridge payload. The live block skips cleanly when Julia is unavailable.

j1329_fake_fit <- function(family = "poisson") {
  fit <- structure(
    list(
      family = family,
      model = paste0(family, "_rr"),
      d = 1L,
      n_traits = 2L,
      n_units = 8L,
      trait_names = c("sp1", "sp2"),
      unit_names = paste0("site", 1:8),
      alpha = c(0.2, 0.4),
      loadings = matrix(c(0.5, -0.3), nrow = 2L),
      Sigma = matrix(c(0.25, -0.15, -0.15, 0.09), nrow = 2L),
      correlation = matrix(c(1, -1, -1, 1), nrow = 2L),
      communality = c(1, 1),
      loglik = -18,
      aic = 50,
      bic = 55,
      df = 5L,
      nobs = 16L,
      converged = TRUE,
      message = "converged"
    ),
    class = c("gllvmTMB_julia", "list")
  )
  fit <- .gllvm_julia_normalise_result(fit)
  fit$engine <- "julia"
  fit$scores <- matrix(
    seq(-0.35, 0.35, length.out = fit$n_units),
    ncol = 1L,
    dimnames = list(fit$unit_names, "LV1")
  )
  y <- matrix(
    c(1, 3, 2, 4, 5, 2, 3, 6, 4, 7, 5, 8, 2, 1, 4, 3),
    nrow = fit$n_traits,
    dimnames = list(fit$trait_names, fit$unit_names)
  )
  fit$bridge_input <- list(
    y = y,
    family = family,
    num.lv = 1L,
    N = NULL,
    X = NULL,
    mask = NULL,
    units_are_rows = FALSE,
    setup_args = list()
  )
  fit
}

j1329_long <- function(n_unit = 8L, traits = c("t1", "t2", "t3"), seed = 1L) {
  set.seed(seed)
  df <- expand.grid(
    unit = factor(seq_len(n_unit)),
    trait = traits,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$trait <- factor(df$trait)
  df
}

# --- #1329 -----------------------------------------------------------------

test_that("#1329 tidy() works on a Julia bridge fit", {
  fit <- j1329_fake_fit()
  fit$trait_col <- "trait"

  fx <- tidy(fit)
  expect_s3_class(fx, "data.frame")
  expect_equal(fx$term, c("traitsp1", "traitsp2"))
  expect_equal(fx$estimate, c(0.2, 0.4))
  expect_true(all(is.na(fx$std.error)))
  expect_true(all(fx$inference_status == "point_estimate_only_julia_bridge"))

  rp <- tidy(fit, effects = "ran_pars")
  expect_equal(rp$term, c("sd_global[sp1]", "sd_global[sp2]"))
  expect_equal(rp$estimate, c(0.5, 0.3))

  expect_equal(nrow(tidy(fit, effects = "cutpoint")), 0L)
  expect_error(tidy(fit, conf.int = TRUE), class = "gllvmTMB_julia_gate")
  expect_error(tidy(fit, conf.int = TRUE), "confint", fixed = TRUE)
})

test_that("#1329 tidy() reports covariate coefficients, dispersion and cutpoints", {
  fit <- j1329_fake_fit("negbinomial")
  fit$beta_cov <- c(sp1 = 0.1, sp2 = 0.3)
  fit$gamma <- c(x = 0.5)
  fit$gamma_status <- c(x = "fixed")
  fit$dispersion_public <- c(sp1 = 2, sp2 = 3)
  fit$dispersion_public_parameter <- "phi"
  fx <- tidy(fit)
  expect_equal(fx$term, c("traitsp1", "traitsp2", "x"))
  expect_equal(fx$estimate, c(0.1, 0.3, 0.5))
  expect_equal(fx$status, c("estimated", "estimated", "fixed"))
  rp <- tidy(fit, effects = "ran_pars")
  expect_equal(rp$term[3:4], c("phi[sp1]", "phi[sp2]"))
  expect_equal(rp$estimate[3:4], c(2, 3))

  ord <- j1329_fake_fit("ordinal")
  ord$alpha <- c(NaN, NaN)
  ord$cutpoints <- matrix(c(0, 0.4, NaN, 0, -0.1, 1.2), nrow = 2L, byrow = TRUE)
  expect_equal(nrow(tidy(ord)), 0L)
  cp <- tidy(ord, effects = "cutpoint")
  expect_equal(
    cp$term,
    c(
      "ordinal_cutpoint[sp1, 1]", "ordinal_cutpoint[sp1, 2]",
      "ordinal_cutpoint[sp2, 1]", "ordinal_cutpoint[sp2, 2]",
      "ordinal_cutpoint[sp2, 3]"
    )
  )
  expect_equal(cp$estimate, c(0, 0.4, 0, -0.1, 1.2))
})

test_that("#1329 residuals(type = 'simulation_rank') works on a Julia bridge fit", {
  fit <- j1329_fake_fit()
  mask <- matrix(TRUE, nrow = 2L, ncol = 8L)
  mask[1L, 2L] <- FALSE
  fit$bridge_input$mask <- mask
  fit$response_mask <- mask

  r <- residuals(fit, type = "simulation_rank", nsim = 99, seed = 1)
  expect_s3_class(r, "data.frame")
  expect_equal(nrow(r), 16L)
  expect_true(all(
    c("trait", "unit", "observed", "u", "residual", "status", "nsim") %in%
      names(r)
  ))
  expect_equal(unique(r$nsim), 99L)
  expect_equal(r$status[r$trait == "sp1" & r$unit == "site2"], "missing_response")
  ok <- r$status == "ok"
  expect_equal(sum(ok), 15L)
  expect_true(all(r$u[ok] > 0 & r$u[ok] < 1))
  expect_equal(r$residual[ok], stats::qnorm(r$u[ok]))
  expect_equal(r$observed, as.vector(fit$bridge_input$y))
  ## seed makes it reproducible, and the caller's RNG stream is restored
  set.seed(42)
  before <- stats::runif(1)
  set.seed(42)
  r2 <- residuals(fit, type = "simulation_rank", nsim = 99, seed = 1)
  after <- stats::runif(1)
  expect_identical(r, r2)
  expect_identical(before, after)

  r_u <- residuals(fit, type = "simulation_rank", nsim = 19, seed = 2,
                   scale = "uniform", trait = "sp2")
  expect_equal(unique(r_u$trait), "sp2")
  expect_equal(r_u$residual, r_u$u)

  ## the old response/Pearson types are unchanged
  expect_true(is.matrix(residuals(fit)))
})

test_that("#1329 simulation-rank residuals rank binomial successes, not proportions", {
  fit <- j1329_fake_fit("binomial")
  fit$link <- rep("LogitLink", 2L)
  fit$bridge_input$N <- matrix(4L, nrow = 2L, ncol = 8L)
  fit$bridge_input$y <- matrix(4, nrow = 2L, ncol = 8L,
                               dimnames = dimnames(fit$bridge_input$y))
  r <- residuals(fit, type = "simulation_rank", nsim = 49, seed = 3,
                 scale = "uniform")
  expect_equal(r$observed, rep(4, 16L))
  ## y = N is the largest possible draw: never below any simulation
  expect_true(all(r$u > 0.3))
})

test_that("#1329 simulation-rank residuals refuse ordinal Julia fits clearly", {
  ord <- j1329_fake_fit("ordinal_probit")
  expect_error(
    residuals(ord, type = "simulation_rank", nsim = 9),
    "GJL-GATE-ORDINAL-SIMULATE"
  )
})

test_that("#1329 check_gllvmTMB() says it needs engine = 'tmb', not that the fit is foreign", {
  fit <- j1329_fake_fit()
  err <- tryCatch(check_gllvmTMB(fit), error = function(e) e)
  expect_s3_class(err, "gllvmTMB_julia_gate")
  msg <- conditionMessage(err)
  expect_match(msg, "engine = \"julia\"", fixed = TRUE)
  expect_match(msg, "engine = \"tmb\"", fixed = TRUE)
  expect_no_match(msg, "Provide a fit returned by")
  ## a non-fit still gets the old message
  expect_error(check_gllvmTMB(list()), "Provide a fit returned by")
})

test_that("#1329 a routed gllvmTMB(engine = 'julia') fit tidies with the TMB term names", {
  df <- j1329_long()
  df$value <- stats::rpois(nrow(df), 3)
  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(y, family, num.lv, ...) {
      out <- j1329_fake_fit()
      out$trait_names <- rownames(y)
      out$n_traits <- nrow(y)
      out$alpha <- stats::setNames(c(0.1, 0.2, 0.3), rownames(y))
      out$Sigma <- diag(3)
      out$dispersion <- NULL
      out
    }
  )
  fj <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = poisson(),
    engine = "julia"
  )
  expect_identical(fj$trait_col, "trait")
  expect_equal(tidy(fj)$term, c("traitt1", "traitt2", "traitt3"))

  skip_on_cran()
  ft <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = poisson(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(tidy(fj)$term, tidy(ft)$term)
})

# --- #1332 -----------------------------------------------------------------

test_that("#1332 the Julia family gate admits ordinal_logit()", {
  expect_identical(.gllvm_julia_family(ordinal_logit()), "ordinal")
  expect_identical(.gllvm_julia_family("ordinal_logit"), "ordinal")
  expect_identical(.gllvm_julia_family(ordinal_probit()), "ordinal_probit")
  ## the cumulative-logit bridge key keeps the logit link downstream
  expect_identical(.gllvm_julia_default_link("ordinal"), "LogitLink")
})

test_that("#1332 the unsupported-family message lists only reachable constructors", {
  err <- tryCatch(.gllvm_julia_family(tweedie()), error = function(e) e)
  msg <- conditionMessage(err)
  expect_match(msg, "GJL-GATE-FAMILY", fixed = TRUE)
  expect_match(msg, "ordinal_logit()", fixed = TRUE)
  expect_match(msg, "ordinal_probit()", fixed = TRUE)
  expect_no_match(msg, "ordinal, ordinal_probit")
})

test_that("#1332 gllvmTMB(family = ordinal_logit(), engine = 'julia') reaches the bridge", {
  df <- j1329_long(n_unit = 10L)
  df$value <- rep(c(1, 2, 3, 2, 1, 3, 2, 3, 1, 2), times = 3L)
  seen <- NULL
  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(y, family, num.lv, ...) {
      seen <<- .gllvm_julia_family(family)
      out <- j1329_fake_fit("ordinal")
      out
    }
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = ordinal_logit(),
    engine = "julia"
  )
  expect_s3_class(fit, "gllvmTMB_julia")
  expect_identical(seen, "ordinal")
})

# --- #1334 -----------------------------------------------------------------

test_that("#1334 multi-trait no-X Gamma is refused before Julia is touched", {
  withr::local_options(gllvmTMB.julia_gamma_shared_shape = NULL)
  y <- matrix(stats::rgamma(3 * 20, shape = 2, rate = 1), 3, 20)
  err <- tryCatch(
    gllvm_julia_fit(y, family = Gamma(link = "log"), num.lv = 1L),
    error = function(e) e
  )
  expect_s3_class(err, "gllvmTMB_julia_gamma_shape_refused")
  msg <- conditionMessage(err)
  expect_match(msg, "GJL-GATE-GAMMA-SHAPE", fixed = TRUE)
  expect_match(msg, "engine = \"tmb\"", fixed = TRUE)
  expect_match(msg, "gllvmTMB.julia_gamma_shared_shape", fixed = TRUE)

  ## also through the main entry point
  df <- j1329_long(n_unit = 12L)
  df$value <- stats::rgamma(nrow(df), shape = 2, rate = 1)
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
      data = df, trait = "trait", unit = "unit",
      family = Gamma(link = "log"), engine = "julia"
    ),
    class = "gllvmTMB_julia_gamma_shape_refused"
  )
})

test_that("#1334 the refusal is scoped: one Gamma trait, X rows, and the opt-in pass the gate", {
  gate <- function(...) {
    tryCatch(
      gllvmTMB:::.gllvm_julia_check_gamma_shape(...),
      gllvmTMB_julia_gamma_shape_refused = function(e) "refused"
    )
  }
  withr::local_options(gllvmTMB.julia_gamma_shared_shape = NULL)
  expect_identical(gate("gamma", 3L), "refused")
  expect_identical(gate(c("gamma", "poisson", "gamma"), 3L), "refused")
  expect_false(gate("gamma", 1L))
  expect_false(gate("poisson", 5L))
  ## GLLVModels.jl's fixed-effect-X Gamma route fits per-trait shape
  expect_false(gate("gamma", 3L, has_x = TRUE))

  withr::local_options(gllvmTMB.julia_gamma_shared_shape = TRUE)
  expect_warning(
    res <- gate("gamma", 3L),
    class = "gllvmTMB_julia_gamma_shared_shape"
  )
  expect_true(res)
})

# --- live Julia (skips cleanly without JuliaCall + GLLVModels.jl) -----------

test_that("live: Julia fits support tidy(), simulation-rank residuals, ordinal_logit, and refuse shared Gamma", {
  skip_on_cran()
  skip_if_not_installed("JuliaCall")
  if (!nzchar(.gllvm_julia_project_path())) {
    skip("GLLVModels.jl path not configured (set GLLVMODELS_JL_PATH).")
  }
  set.seed(11)
  n <- 40L
  z <- stats::rnorm(n)
  df <- data.frame(
    unit = factor(rep(seq_len(n), 4L)),
    trait = factor(rep(paste0("t", 1:4), each = n))
  )
  df$value <- rep(z, 4L) * rep(c(0.9, 0.7, 0.5, 0.3), each = n) +
    stats::rnorm(4L * n, sd = 0.5)
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE)
  fj <- gllvmTMB(f, data = df, trait = "trait", unit = "unit",
                 family = gaussian(), engine = "julia")
  td <- tidy(fj)
  expect_equal(td$term, paste0("trait", levels(df$trait)))
  expect_true(all(is.finite(td$estimate)))
  r <- residuals(fj, type = "simulation_rank", nsim = 99, seed = 1)
  expect_equal(nrow(r), 4L * n)
  expect_true(all(r$status == "ok"))
  expect_error(check_gllvmTMB(fj), class = "gllvmTMB_julia_gate")

  ## #1332: ordinal_logit() is admitted
  df$ord <- as.integer(cut(df$value, c(-Inf, -0.5, 0.5, Inf)))
  fo <- gllvmTMB(ord ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
                 data = df, trait = "trait", unit = "unit",
                 family = ordinal_logit(), engine = "julia")
  expect_s3_class(fo, "gllvmTMB_julia")
  expect_true(is.finite(as.numeric(logLik(fo))))

  ## #1334: multi-trait Gamma is refused
  df$pos <- exp(df$value)
  expect_error(
    gllvmTMB(pos ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
             data = df, trait = "trait", unit = "unit",
             family = Gamma(link = "log"), engine = "julia"),
    class = "gllvmTMB_julia_gamma_shape_refused"
  )
})
