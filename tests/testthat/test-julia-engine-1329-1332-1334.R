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
  ## sd_global comes from Lambda, never from a Sigma payload that carries a
  ## residual / link-residual diagonal (e.g. pi^2 / 3 for logit rows)
  fit$Sigma <- fit$Sigma + diag(pi^2 / 3, 2L)
  expect_equal(tidy(fit, effects = "ran_pars")$estimate, c(0.5, 0.3))

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
  ## tau_1 = 0 is fixed (not an estimate); free cutpoints use TMB's labels
  ord$cutpoints <- matrix(c(0, 0.4, NaN, 0, 0.3, 1.2), nrow = 2L, byrow = TRUE)
  expect_equal(nrow(tidy(ord)), 0L)
  cp <- tidy(ord, effects = "cutpoint")
  expect_equal(
    cp$term,
    c(
      "ordinal_cutpoint[sp1, cutpoint_2]",
      "ordinal_cutpoint[sp2, cutpoint_2]",
      "ordinal_cutpoint[sp2, cutpoint_3]"
    )
  )
  expect_equal(cp$estimate, c(0.4, 0.3, 1.2))
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

# --- review follow-ups on PR #1474 -----------------------------------------

j1329_fake_from_y <- function(y, family = "poisson") {
  p <- nrow(y)
  n <- ncol(y)
  fit <- structure(
    list(
      family = family, model = paste0(family, "_rr"), d = 1L,
      n_traits = p, n_units = n,
      trait_names = rownames(y), unit_names = colnames(y),
      alpha = rep(log(3), p),
      loadings = matrix(seq(0.2, 0.6, length.out = p), ncol = 1L),
      Sigma = diag(p), correlation = diag(p), communality = rep(1, p),
      loglik = -10, aic = 30, bic = 35, df = 2L * p, nobs = p * n,
      converged = TRUE, message = "converged"
    ),
    class = c("gllvmTMB_julia", "list")
  )
  fit <- .gllvm_julia_normalise_result(fit)
  fit$engine <- "julia"
  fit$scores <- matrix(seq(-0.3, 0.3, length.out = n), ncol = 1L,
                       dimnames = list(colnames(y), "LV1"))
  fit$bridge_input <- list(y = y, family = family, num.lv = 1L, N = NULL,
                           X = NULL, mask = NULL, units_are_rows = FALSE,
                           setup_args = list())
  fit
}

test_that("#1329 simulation-rank rows follow the input data rows (p != n, permuted)", {
  set.seed(5)
  traits <- c("aa", "bb", "cc")
  n_unit <- 5L
  df <- data.frame(
    unit = factor(rep(paste0("u", seq_len(n_unit)), times = 3L)),
    trait = factor(rep(traits, each = n_unit)),
    value = c(0:4, 10:14, 20:24)  # every cell distinct: a transpose shows
  )
  df <- df[sample(nrow(df)), ]
  rownames(df) <- NULL
  df$value[df$trait == "bb" & df$unit == "u3"] <- NA  # one masked cell
  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(y, family, ...) j1329_fake_from_y(y)
  )
  fj <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = poisson(),
    engine = "julia"
  )
  r <- residuals(fj, type = "simulation_rank", nsim = 19, seed = 1)
  keep <- !is.na(df$value)
  ## input row order, masked row dropped (as the TMB engine drops it)
  expect_equal(nrow(r), sum(keep))
  expect_equal(r$observed, df$value[keep])
  expect_equal(r$trait, as.character(df$trait[keep]))
  expect_equal(r$unit, as.character(df$unit[keep]))
  expect_true(all(r$status == "ok"))

  ## direct gllvm_julia_fit() objects keep every p x n cell in simulate()'s
  ## order, with the masked cell flagged rather than dropped
  direct <- j1329_fake_from_y(fj$bridge_input$y)
  direct$response_mask <- fj$response_mask
  rd <- residuals(direct, type = "simulation_rank", nsim = 19, seed = 1)
  expect_equal(nrow(rd), 15L)
  expect_equal(sum(rd$status == "missing_response"), 1L)
  expect_equal(
    rd$observed[rd$status == "ok"],
    as.vector(direct$bridge_input$y)[rd$status == "ok"]
  )
  sim_names <- rownames(simulate(direct, nsim = 1L, seed = 1))
  expect_equal(paste(rd$trait, rd$unit, sep = ":"), sim_names)

  ## same row order as the TMB engine's simulation-rank residuals
  skip_on_cran()
  ft <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = poisson(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  rt <- residuals(ft, type = "simulation_rank", nsim = 19, seed = 1)
  expect_equal(nrow(r), nrow(rt))
  expect_equal(r$observed, rt$observed)
  expect_equal(r$trait, as.character(rt$trait))
})

test_that("#1334 a zero-column X stops in R; an intercept-only X is not refused", {
  withr::local_options(gllvmTMB.julia_gamma_shared_shape = NULL)
  y <- matrix(stats::rgamma(3 * 10, shape = 2, rate = 1), 3, 10)
  err_class <- function(X, family = Gamma(link = "log")) {
    err <- tryCatch(
      gllvm_julia_fit(y, family = family, num.lv = 1L, X = X),
      error = function(e) e
    )
    class(err)
  }
  ## zero-column X: classed R error before Julia, for any family
  expect_true("gllvmTMB_julia_x_empty" %in% err_class(array(0, c(3L, 10L, 0L))))
  expect_true("gllvmTMB_julia_x_empty" %in%
    err_class(array(0, c(3L, 10L, 0L)), family = poisson()))
  ## intercept-only X takes the fixed-effect-X route (per-trait shape)
  cls <- err_class(array(1, c(3L, 10L, 1L)))
  expect_false("gllvmTMB_julia_gamma_shape_refused" %in% cls)
  expect_false("gllvmTMB_julia_x_empty" %in% cls)
  expect_false(.gllvm_julia_has_covariates(NULL))
  expect_true(.gllvm_julia_has_covariates(array(1, c(3L, 10L, 1L))))
})

test_that("#1329 sibling gates explain the Julia boundary instead of denying the fit", {
  fit <- j1329_fake_fit()
  for (f in list(
    function() rotate_loadings(fit),
    function() extract_Gamma(fit),
    function() check_identifiability(fit)
  )) {
    err <- tryCatch(f(), error = function(e) e)
    expect_s3_class(err, "gllvmTMB_julia_gate")
    expect_no_match(conditionMessage(err), "Provide a fit returned by")
    expect_match(conditionMessage(err), "engine = \"tmb\"", fixed = TRUE)
  }
  expect_error(rotate_loadings(list()), "Provide a fit returned by")
})

test_that("#1329 tidy() on a Julia fit matches the TMB engine's ran_pars and cutpoints", {
  skip_on_cran()
  set.seed(7)
  n <- 60L
  z <- stats::rnorm(n)
  traits <- paste0("q", 1:3)
  eta <- outer(z, c(1.2, 0.8, -0.6))
  ycat <- apply(eta + matrix(stats::rlogis(3 * n), n), 2L, function(v) {
    as.integer(cut(v, c(-Inf, -0.7, 0.4, 1.3, Inf)))
  })
  df <- data.frame(
    unit = factor(rep(seq_len(n), 3L)),
    trait = factor(rep(traits, each = n)),
    value = as.vector(ycat)
  )
  ft <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = ordinal_logit(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  L <- as.matrix(extract_ordination(ft, level = "unit")$loadings)
  cuts_tmb <- extract_cutpoints(ft, quiet = TRUE)
  K <- max(df$value)
  cut_mat <- matrix(NaN, 3L, K - 1L, dimnames = list(traits, NULL))
  cut_mat[, 1L] <- 0
  cut_mat[cbind(match(cuts_tmb$trait, traits), cuts_tmb$cutpoint_index)] <-
    cuts_tmb$tau_estimate
  ## a Julia payload carrying the same Lambda and cutpoints; its Sigma adds
  ## the logit link-residual diagonal, which tidy() must not report
  fj <- structure(
    list(family = "ordinal", d = 1L, n_traits = 3L, trait_names = traits,
         loadings = L, Sigma = L %*% t(L) + diag(pi^2 / 3, 3L),
         alpha = rep(NaN, 3L), cutpoints = cut_mat, trait_col = "trait"),
    class = c("gllvmTMB_julia", "list")
  )
  rp_t <- tidy(ft, effects = "ran_pars")
  rp_t <- rp_t[startsWith(rp_t$term, "sd_global["), ]
  rp_j <- tidy(fj, effects = "ran_pars")
  expect_equal(rp_j$term, rp_t$term)
  expect_equal(rp_j$estimate, rp_t$estimate, tolerance = 1e-8)
  cp_t <- tidy(ft, effects = "cutpoint")
  cp_j <- tidy(fj, effects = "cutpoint")
  expect_equal(cp_j$term, cp_t$term)
  expect_equal(cp_j$estimate, cp_t$estimate, tolerance = 1e-8)
})

j1329_skip_if_no_live_julia <- function() {
  skip_on_cran()
  skip_if_not_installed("JuliaCall")
  if (!nzchar(.gllvm_julia_project_path())) {
    skip("GLLVModels.jl path not configured (set GLLVMODELS_JL_PATH).")
  }
}

test_that("live: simulation-rank row keys match the TMB engine on a masked fit", {
  j1329_skip_if_no_live_julia()
  set.seed(21)
  n <- 20L
  traits <- c("t1", "t2", "t3")
  z <- stats::rnorm(n)
  df <- data.frame(
    unit = factor(rep(seq_len(n), 3L)),
    trait = factor(rep(traits, each = n))
  )
  df$value <- stats::rpois(3L * n, exp(0.5 + rep(z, 3L) * 0.6))
  df$value[c(4L, 27L)] <- NA
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE)
  fj <- gllvmTMB(f, data = df, trait = "trait", unit = "unit",
                 family = poisson(), engine = "julia")
  ft <- suppressWarnings(suppressMessages(gllvmTMB(
    f, data = df, trait = "trait", unit = "unit", family = poisson(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  rj <- residuals(fj, type = "simulation_rank", nsim = 49, seed = 1)
  rt <- residuals(ft, type = "simulation_rank", nsim = 49, seed = 1)
  expect_equal(nrow(rj), nrow(rt))
  expect_equal(nrow(rj), sum(!is.na(df$value)))
  expect_equal(rj$trait, as.character(rt$trait))
  expect_equal(rj$observed, rt$observed)
})

test_that("live: intercept-only X Gamma fits per-trait shape and matches TMB logLik", {
  j1329_skip_if_no_live_julia()
  withr::local_options(gllvmTMB.julia_gamma_shared_shape = NULL)
  set.seed(31)
  n <- 40L
  z <- stats::rnorm(n)
  shape <- c(2, 8, 30)  # very different CVs: a shared shape would fit badly
  y <- t(sapply(1:3, function(j) {
    stats::rgamma(n, shape = shape[j], rate = shape[j] / exp(0.3 * j + 0.5 * z))
  }))
  dimnames(y) <- list(paste0("t", 1:3), paste0("u", seq_len(n)))
  fx <- gllvm_julia_fit(y, family = Gamma(link = "log"), num.lv = 1L,
                        X = array(1, c(3L, n, 1L),
                                  dimnames = list(NULL, NULL, "one")))
  df <- data.frame(
    unit = factor(rep(colnames(y), each = 3L), levels = colnames(y)),
    trait = factor(rep(rownames(y), times = n)),
    value = as.vector(y)
  )
  ft <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = Gamma(link = "log"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(as.numeric(logLik(fx)), as.numeric(logLik(ft)), tolerance = 1e-4)
})
