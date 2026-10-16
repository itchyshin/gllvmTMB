## #1393: bootstrap_Sigma() refits each replicate by calling gllvmTMB() again.
## The refit must reuse every argument the original fit used. Before the fix
## the refit call was a hand-picked list: a custom `unit_obs` (or `cluster2`,
## `(1 | g)`, a lone `phylo_indep()`) made every refit fail, and an `offset()`
## or `Xcoef_fixed` pin was silently dropped, so the refits fitted a different
## model. A bootstrap whose refits all failed returned all-NA bounds with no
## warning.

unit_obs_1393_fit <- function() {
  set.seed(12)
  n <- 20
  d <- expand.grid(
    trait = factor(c("a", "b", "c")), rep = 1:2,
    unit = factor(sprintf("u%02d", 1:n))
  )
  d$obs <- factor(paste(d$unit, d$rep, sep = "_"))
  z <- rnorm(n)
  d$value <- c(1, 0, -1)[as.integer(d$trait)] +
    c(.8, .5, -.6)[as.integer(d$trait)] * z[as.integer(d$unit)] +
    rnorm(nrow(d), sd = .5)
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1) +
      indep(0 + trait | obs),
    data = d, unit = "unit", unit_obs = "obs", trait = "trait",
    family = gaussian()
  )))
}

## Run bootstrap_Sigma() and collect its warnings instead of letting them
## escape (small n_boot always warns about the percentile floor).
boot_1393 <- function(fit, ...) {
  warns <- list()
  out <- withCallingHandlers(
    suppressMessages(bootstrap_Sigma(fit, progress = FALSE, seed = 1, ...)),
    warning = function(w) {
      warns[[length(warns) + 1L]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  list(boot = out, warnings = warns)
}

has_class_1393 <- function(warns, class) {
  any(vapply(warns, inherits, logical(1), what = class))
}

## Capture the first refit call bootstrap_Sigma() makes, then replay it on the
## ORIGINAL response: a refit that reuses every argument reproduces the
## original optimum exactly.
replay_refit_1393 <- function(fit) {
  real_gllvmTMB <- gllvmTMB
  args <- NULL
  testthat::with_mocked_bindings(
    gllvmTMB = function(...) {
      if (is.null(args)) args <<- list(...)
      stop("refit captured")
    },
    .package = "gllvmTMB",
    suppressMessages(suppressWarnings(bootstrap_Sigma(
      fit, n_boot = 1L, what = "Sigma", progress = FALSE, seed = 1
    )))
  )
  resp <- all.vars(fit$formula)[1L]
  args$data[[resp]] <- fit$data[[resp]]
  suppressMessages(suppressWarnings(do.call(real_gllvmTMB, args)))
}

expect_refit_reproduces_1393 <- function(fit) {
  expect_identical(fit$opt$convergence, 0L)
  refit <- replay_refit_1393(fit)
  expect_s3_class(refit, "gllvmTMB_multi")
  expect_equal(refit$opt$objective, fit$opt$objective, tolerance = 1e-6)
}

site_trait_1393 <- function() {
  gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 5, n_traits = 3,
    mean_species_per_site = 4, seed = 3
  )$data
}

test_that("bootstrap_Sigma() refits a custom unit_obs fit (#1393)", {
  fit <- unit_obs_1393_fit()
  res <- boot_1393(fit, n_boot = 3, level = c("unit", "unit_obs"),
                   what = "Sigma")
  expect_identical(res$boot$n_failed, 0L)
  expect_true(all(is.finite(res$boot$ci_lower$Sigma_B)))
  expect_true(all(is.finite(res$boot$ci_upper$Sigma_B)))
  expect_true(all(is.finite(res$boot$ci_lower$Sigma_W)))
  expect_true(all(is.finite(res$boot$ci_upper$Sigma_W)))
  expect_false(has_class_1393(res$warnings,
                              "gllvmTMB_bootstrap_refits_failed"))
})

test_that("bootstrap_Sigma() warns when every refit fails (#1393)", {
  fit <- unit_obs_1393_fit()
  res <- testthat::with_mocked_bindings(
    gllvmTMB = function(...) stop("refit exploded on purpose"),
    .package = "gllvmTMB",
    boot_1393(fit, n_boot = 3, level = "unit", what = "Sigma")
  )
  expect_identical(res$boot$n_failed, 3L)
  expect_true(all(is.na(res$boot$ci_lower$Sigma_B)))
  failed <- Filter(
    function(w) inherits(w, "gllvmTMB_bootstrap_refits_failed"),
    res$warnings
  )
  expect_length(failed, 1L)
  ## The warning carries the refit's own error, not just a count.
  expect_match(conditionMessage(failed[[1L]]), "refit exploded on purpose",
               fixed = TRUE)
})

test_that("bootstrap_Sigma() reports attrition for matrix summaries (#1393)", {
  fit <- unit_obs_1393_fit()
  real_gllvmTMB <- gllvmTMB
  calls <- 0L
  res <- testthat::with_mocked_bindings(
    gllvmTMB = function(...) {
      calls <<- calls + 1L
      if (calls <= 2L) stop("refit exploded on purpose")
      real_gllvmTMB(...)
    },
    .package = "gllvmTMB",
    boot_1393(fit, n_boot = 3, level = "unit", what = "Sigma")
  )
  ## One of three refits survived: the Sigma bounds rest on a single draw,
  ## and the attrition warning has to say so even though Sigma is a matrix.
  expect_identical(res$boot$n_failed, 2L)
  msgs <- vapply(res$warnings, conditionMessage, character(1))
  expect_true(any(grepl("attrition", msgs, fixed = TRUE)))
  expect_false(has_class_1393(res$warnings,
                              "gllvmTMB_bootstrap_refits_failed"))
})

test_that("the refit argument table covers every gllvmTMB() argument (#1393)", {
  fit <- unit_obs_1393_fit()
  expect_setequal(
    names(.bootstrap_refit_arg_table(fit)),
    names(formals(gllvmTMB))
  )
})

test_that("bootstrap refits reproduce the original fit (#1393)", {
  ## Custom unit_obs (the reported case).
  expect_refit_reproduces_1393(unit_obs_1393_fit())

  s <- site_trait_1393()

  ## Default unit_obs / cluster slots, used by name in the formula.
  expect_refit_reproduces_1393(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
      indep(0 + trait | site_species),
    data = s, unit = "site"
  ))))

  ## Custom cluster column name.
  s_cl <- s
  names(s_cl)[names(s_cl) == "species"] <- "sp"
  expect_refit_reproduces_1393(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
      indep(0 + trait | sp),
    data = s_cl, unit = "site", cluster = "sp"
  ))))

  ## cluster2 slot.
  s_c2 <- s
  s_c2$c2 <- factor(as.integer(s_c2$site) %% 6)
  expect_refit_reproduces_1393(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
      indep(0 + trait | c2),
    data = s_c2, unit = "site", cluster2 = "c2"
  ))))

  ## Ordinary random intercept (1 | g).
  s_re <- s
  s_re$g <- factor(as.integer(s_re$site) %% 5)
  expect_refit_reproduces_1393(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) + (1 | g),
    data = s_re, unit = "site"
  ))))

  ## Pinned fixed-effect coefficient.
  s_x <- s
  s_x$x <- rnorm(nrow(s_x))
  expect_refit_reproduces_1393(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + (0 + trait):x + latent(0 + trait | site, d = 1),
    data = s_x, unit = "site",
    Xcoef_fixed = stats::setNames(0, paste0("trait", levels(s_x$trait)[1], ":x"))
  ))))

  ## User loading constraint (stored under the engine slot name).
  expect_refit_reproduces_1393(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = s, unit = "site",
    lambda_constraint = list(unit = matrix(c(1, NA, NA), 3, 1))
  ))))

  ## Count model with an offset.
  set.seed(4)
  dd <- expand.grid(trait = factor(c("a", "b", "c")), unit = factor(1:40))
  dd$log_e <- log(runif(nrow(dd), 0.5, 5))
  zz <- rnorm(40)
  dd$y <- rpois(nrow(dd), exp(0.3 + 0.5 * zz[as.integer(dd$unit)] + dd$log_e))
  expect_refit_reproduces_1393(suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1) + offset(log_e),
    data = dd, unit = "unit", family = poisson()
  ))))
})

test_that("bootstrap refits reproduce a lone phylo_indep() fit (#1393)", {
  skip_if_not_installed("ape")
  set.seed(126)
  n_sp <- 20
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 40, n_species = n_sp, n_traits = 3,
    mean_species_per_site = 5, Cphy = ape::vcv(tree, corr = TRUE),
    sigma2_phy = rep(0.4, 3), seed = 126
  )
  df <- sim$data
  levels(df$species) <- paste0("sp", seq_len(n_sp))
  expect_refit_reproduces_1393(suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
      phylo_indep(0 + trait | species, tree = tree),
    data = df, unit = "site", cluster = "species"
  ))))
})

test_that("bootstrap_Sigma() refuses fits whose inputs it cannot recover (#1393)", {
  ## meta_V(): the fitted object does not keep the known_V matrix.
  set.seed(131)
  ## Kept small: on the unfixed code each refit spends seconds parsing the
  ## deparsed V matrix before it fails.
  df <- expand.grid(site = factor(seq_len(15)),
                    trait = factor(paste0("t", 1:3)))
  df$value <- rnorm(nrow(df), sd = 0.5)
  df$sampling_var <- runif(nrow(df), 0.02, 0.08)
  V <- diag(df$sampling_var)
  fit_v <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
      meta_V(V = V, type = "exact"),
    data = df, unit = "site", known_V = V
  )))
  expect_error(
    suppressWarnings(bootstrap_Sigma(fit_v, n_boot = 2, level = "unit",
                                     what = "Sigma", progress = FALSE)),
    class = "gllvmTMB_bootstrap_refit_unsupported"
  )

  ## mi(): the fitted object does not keep the `impute` model.
  s <- site_trait_1393()
  xs <- rnorm(nlevels(s$site))
  s$x <- xs[as.integer(s$site)]
  s$x[s$site %in% levels(s$site)[1:4]] <- NA
  fit_mi <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + mi(x) + latent(0 + trait | site, d = 1),
    data = s, unit = "site",
    missing = miss_control(predictor = "model"), impute = list(x ~ 1)
  )))
  expect_error(
    suppressWarnings(bootstrap_Sigma(fit_mi, n_boot = 2, level = "unit",
                                     what = "Sigma", progress = FALSE)),
    class = "gllvmTMB_bootstrap_refit_unsupported"
  )
})
