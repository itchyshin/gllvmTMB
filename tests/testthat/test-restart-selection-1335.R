## Multi-start restart selection (#1335) and the all-restarts-failed
## message (#1333).
##
## #1335: with n_init > 1 the fit returned could be WORSE than the default
## single start. Restarts were ranked by the objective nlminb reported, but
## on a student() fit the inner (Laplace) Hessian at the winning point was
## near-singular, so that value depended on where TMB's inner Newton solve
## started and `obj$fn(opt$par)` did not reproduce it (263.85 reported,
## 269.38 on re-evaluation). The fix ranks restarts by the re-evaluated
## objective and hands TMB the selected restart's state.

sim_restart_fit_data <- function() {
  gllvmTMB::simulate_site_trait(
    n_sites = 40, n_species = 10, n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(1.0, 0.7, -0.3,
                        0.3, -0.5, 0.8), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 7L
  )
}

doubs_student_long <- function() {
  data("doubs", package = "ade4", envir = environment())
  ee <- doubs$env
  w <- data.frame(unit = paste0("site", rownames(ee)), scale(log1p(ee)))
  ## CSV round trip, as in the issue's reproduction.
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(w, path, row.names = FALSE)
  w <- utils::read.csv(path)
  resp <- setdiff(names(w), "unit")
  long <- do.call(rbind, lapply(resp, function(r) {
    data.frame(unit = w$unit, trait = r, value = w[[r]])
  }))
  long$unit <- factor(long$unit, levels = w$unit)
  long$trait <- factor(long$trait, levels = resp)
  long
}

test_that("#1335 explicit n_init = 1 fit is unchanged (parity pin)", {
  ## Pinned on origin/main (0cf373d55) before the #1335 fix. The explicit
  ## n_init = 1 single-start path must not move (the default is now 3, #1331): a Julia true-parity lane compares
  ## against it. Before and after the fix the macOS value was byte-identical;
  ## the 1e-6 tolerance only absorbs cross-platform BLAS differences.
  sim <- sim_restart_fit_data()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) +
      unique(0 + trait | site),
    data = sim$data,
    control = gllvmTMBcontrol(n_init = 1L)
  )))
  expect_equal(fit$opt$objective, 665.09608921189783, tolerance = 1e-6)
  expect_equal(as.numeric(logLik(fit)), -665.09608921189783,
               tolerance = 1e-6)
  ## #1331: the default fit also runs the deterministic "svd" start. Here it
  ## reaches the same optimum, so the default start's fit is kept unchanged.
  expect_identical(fit$restart_history$start_label, c("initial", "svd"))
  expect_identical(fit$restart_history$selected, c(TRUE, FALSE))
})

test_that("#1331 default fit leaves the session RNG alone and is reproducible", {
  skip_on_cran()
  sim <- sim_restart_fit_data()
  fit_default <- function() suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2) +
      unique(0 + trait | site),
    data = sim$data
  )))
  set.seed(1)
  s <- .Random.seed
  f1 <- fit_default()
  expect_identical(s, .Random.seed)
  f2 <- fit_default()
  expect_identical(s, .Random.seed)
  expect_true(sum(f1$restart_history$start_label == "jitter") == 2L)
  rh_cmp <- function(f) f$restart_history[setdiff(names(f$restart_history), "elapsed_s")]
  expect_identical(rh_cmp(f1), rh_cmp(f2))
  expect_identical(as.numeric(logLik(f1)), as.numeric(logLik(f2)))
  ## No .Random.seed before the fit -> none after.
  rm(".Random.seed", envir = globalenv())
  f3 <- fit_default()
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  expect_identical(rh_cmp(f1), rh_cmp(f3))
  set.seed(1)
})

test_that("#1335 the selected restart is the fit that is returned", {
  skip_on_cran()
  skip_if_not_installed("ade4")
  long <- doubs_student_long()
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 2)
  fit_once <- function(...) suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(f, data = long, trait = "trait", unit = "unit",
                       family = student(df = 4), engine = "tmb", ...)
  ))
  single <- fit_once(control = gllvmTMBcontrol(n_init = 1L))
  set.seed(2)
  multi <- fit_once(control = gllvmTMBcontrol(n_init = 2))

  rh <- multi$restart_history
  selected_objective <- rh$objective[rh$selected]
  ## The returned object carries the selected restart's objective ...
  expect_equal(multi$opt$objective, selected_objective, tolerance = 1e-6)
  expect_lt(abs(multi$tmb_obj$fn(multi$opt$par) - selected_objective), 1e-6)
  expect_lt(abs(as.numeric(logLik(multi)) + selected_objective), 1e-6)
  ## ... and the best of the starts is never below the default start.
  expect_gte(as.numeric(logLik(multi)), as.numeric(logLik(single)) - 1e-6)
  ## Restart 1 is the default start, so it reproduces the single-start fit.
  ## (Compare restart 1 of each: the single-start fit may keep its svd start.)
  expect_equal(rh$objective[1L], single$restart_history$objective[1L],
               tolerance = 1e-8)
})

test_that("#1333 all-restarts-failed abort reports each restart's reason", {
  sim <- sim_restart_fit_data()
  calls <- 0L
  local_mocked_bindings(.gllvmTMB_run_nlminb = function(args) {
    calls <<- calls + 1L
    if (calls == 1L) {
      list(par = args$start, objective = NaN, convergence = 1L,
           message = "false convergence (8)", iterations = 3L,
           evaluations = c(`function` = 4L, gradient = 3L))
    } else {
      stop("NA/NaN function evaluation {boom}")
    }
  })
  err <- expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 2) +
        unique(0 + trait | site),
      data = sim$data,
      control = gllvmTMBcontrol(n_init = 2, svd_start = FALSE)
    ))),
    class = "gllvmTMB_all_restarts_failed"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "All 2 restarts failed", fixed = TRUE)
  expect_match(msg,
    "Restart 1 (initial): objective NaN; convergence code 1; false convergence (8)",
    fixed = TRUE)
  expect_match(msg, "Restart 2 (jitter): NA/NaN function evaluation {boom}",
               fixed = TRUE)
})
