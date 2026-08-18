## L0 plumbing smoke for Design 125 fork B (G0 SIGNED 2026-08-18).
##
## Checks that `.gllvmTMB_mspl_profile_feasibility(objective = "unpenalized")`
## returns a typed result on a toy binomial LA-MSPL fit, that fork A is
## unchanged by default, and that the no-coverage markers survive both arms.
## Local compute only.  Not a coverage measurement -- that is L1.

suppressMessages(devtools::load_all(".", quiet = TRUE))

set.seed(20260818)

.fixture <- function(n_site = 40L, n_trait = 4L, seed = 1L) {
  set.seed(seed)
  dat <- expand.grid(
    site = factor(seq_len(n_site)),
    trait = factor(paste0("sp", seq_len(n_trait)))
  )
  z <- stats::rnorm(n_site)
  lambda <- rep(0.8, n_trait)
  beta0 <- seq(-0.4, 0.4, length.out = n_trait)
  eta <- beta0[as.integer(dat$trait)] +
    lambda[as.integer(dat$trait)] * z[as.integer(dat$site)]
  dat$y <- stats::rbinom(nrow(dat), 1L, stats::plogis(eta))
  dat
}

.fit <- function(dat) {
  gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat,
    family = stats::binomial(link = "logit"),
    estimator = "mspl",
    control = gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
  )
}

fit <- .fit(.fixture())
cat("fit ok; estimator =", fit$estimator, "\n")
cat("penalised nll   =", fit$mspl$penalized_nll, "\n")
cat("unpenalized nll =", fit$mspl$unpenalized_nll_at_estimate, "\n\n")

for (arm in c("penalised", "unpenalized")) {
  probe <- gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
    fit, which = 1L, step = 0.5, max_steps = 8L, objective = arm
  )
  diag <- gllvmTMB:::.gllvmTMB_mspl_profile_threshold_diagnostic(probe)
  cat(sprintf(
    "fork %s (%s)\n  source        : %s\n  nuisance      : %s\n  centre/lo/hi  : %s / %s / %s\n  mle           : %.5f\n  endpoints     : %.5f .. %.5f\n  finite_stable : %s\n  markers       : calibrated=%s public_confint=%s coverage_claim=%s\n  reoptimized   : %s\n\n",
    probe$design_125_fork, arm, probe$objective_source,
    probe$nuisance_treatment,
    probe$centre_status, probe$lower_status, probe$upper_status,
    probe$mle, diag$diagnostic_lower, diag$diagnostic_upper,
    probe$finite_stable,
    probe$calibrated, probe$public_confint, probe$coverage_claim,
    paste(unique(probe$trace$nuisance_reoptimized), collapse = ",")
  ))
}

## The penalised tape must be untouched by a fork-B walk.
checkpoint <- gllvmTMB:::.gllvmTMB_profile_tmb_checkpoint(fit$tmb_obj)
invisible(gllvmTMB:::.gllvmTMB_mspl_profile_feasibility(
  fit, which = 1L, objective = "unpenalized"
))
cat("penalised tape unchanged after fork-B walk: ",
    identical(gllvmTMB:::.gllvmTMB_profile_tmb_checkpoint(fit$tmb_obj),
              checkpoint), "\n")

## Public doors must still be shut.
cat("confint refuses: ",
    inherits(tryCatch(stats::confint(fit), error = identity),
             "gllvmTMB_mspl_inference_unsupported"), "\n")
cat("vcov refuses   : ",
    inherits(tryCatch(stats::vcov(fit), error = identity),
             "gllvmTMB_mspl_inference_unsupported"), "\n")
