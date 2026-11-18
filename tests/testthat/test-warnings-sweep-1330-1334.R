## Warning-only sweep: #1330 (zero-inflated non-convergence) and #1334
## (engine = "julia" Gamma shares one shape). No behaviour changes.

.zi_small_fit <- function() {
  set.seed(1)
  n_site <- 30L
  dat <- data.frame(
    site  = factor(rep(seq_len(n_site), 2)),
    trait = factor(rep(1:2, each = n_site)),
    y     = c(rpois(n_site, 2), rpois(n_site, 3))
  )
  dat$y[1:6] <- 0
  suppressMessages(gllvmTMB(
    y ~ 0 + trait, data = dat, family = zi_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  ))
}

test_that("#1330 zero-inflated non-convergence with absurd gradient warns with next step", {
  skip_on_cran()
  fit <- .zi_small_fit()
  h <- fit$fit_health
  ids <- fit$tmb_data$family_id_vec
  expect_true(all(ids == 17L))
  ## Pathological state as reported: code 1, max|grad| 1.94e7.
  h$convergence <- 1L
  h$max_gradient <- 1.94e7
  expect_warning(
    gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(h, ids),
    class = "gllvmTMB_zi_nonconvergence"
  )
  expect_warning(
    gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(h, ids),
    "n_init = 5"
  )
  ## Absurd objective (logLik -1.5e10) with a modest gradient also warns.
  h2 <- fit$fit_health
  h2$convergence <- 1L
  h2$objective <- 1.5e10
  expect_warning(
    gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(h2, ids),
    class = "gllvmTMB_zi_nonconvergence"
  )
})

test_that("#1330 negative controls: healthy zi_poisson fit, non-zi family, mild non-convergence stay silent", {
  skip_on_cran()
  expect_no_warning(fit <- .zi_small_fit())
  expect_equal(fit$opt$convergence, 0L)
  h <- fit$fit_health
  ids <- fit$tmb_data$family_id_vec
  expect_no_warning(gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(h, ids))
  ## Non-zero code but a small gradient and sane objective: no new warning.
  hm <- h; hm$convergence <- 1L; hm$max_gradient <- 0.05
  expect_no_warning(gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(hm, ids))
  ## Pathological state on a non-zero-inflated family: not this warning.
  hp <- h; hp$convergence <- 1L; hp$max_gradient <- 1e7
  expect_no_warning(gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(hp, rep(0L, 10)))
})

test_that("#1334 engine = 'julia' Gamma with 3 traits warns about one shared shape when opted in", {
  ## Since the follow-up fix the shared-shape model is refused by default
  ## (test-julia-engine-1329-1332-1334.R); the warning remains on the opt-in.
  withr::local_options(gllvmTMB.julia_gamma_shared_shape = TRUE)
  y <- matrix(stats::rgamma(3 * 20, shape = 2, rate = 1), 3, 20)
  caught <- character()
  tryCatch(
    withCallingHandlers(
      gllvm_julia_fit(y, family = Gamma(link = "log"), num.lv = 1L),
      warning = function(w) {
        if (inherits(w, "gllvmTMB_julia_gamma_shared_shape")) {
          caught <<- c(caught, conditionMessage(w))
        }
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) NULL   # no Julia in CI: only the pre-Julia gate matters
  )
  expect_length(caught, 1L)
  expect_match(caught, "shared Gamma shape")
  expect_match(caught, "engine = \"tmb\"", fixed = TRUE)
})

test_that("#1334 negative controls: one Gamma trait, non-Gamma family, engine = 'tmb'", {
  expect_no_warning(gllvmTMB:::.gllvm_julia_warn_gamma_shared_shape("gamma", 1L))
  expect_no_warning(gllvmTMB:::.gllvm_julia_warn_gamma_shared_shape("poisson", 5L))
  expect_warning(
    gllvmTMB:::.gllvm_julia_warn_gamma_shared_shape(c("gamma", "poisson", "gamma"), 3L),
    class = "gllvmTMB_julia_gamma_shared_shape"
  )
  skip_on_cran()
  set.seed(2)
  dat <- data.frame(
    site = factor(rep(1:25, 3)), trait = factor(rep(1:3, each = 25)),
    y = stats::rgamma(75, shape = 3, rate = 1)
  )
  expect_no_warning(suppressMessages(gllvmTMB(
    y ~ 0 + trait, data = dat, family = Gamma(link = "log"), unit = "site",
    engine = "tmb", control = gllvmTMBcontrol(se = FALSE)
  )))
})
