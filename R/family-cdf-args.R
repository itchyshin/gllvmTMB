## Internal per-trait dispersion-parameter accessor (issue #1080).
##
## The quantities on `fit$report` are named after the ENGINE's internal
## parameterisation (src/gllvmTMB.cpp), not after standard R distribution
## arguments, and several names are correctness traps:
##
##   * `phi_gamma` (Gamma, fid 4) is the SHAPE, not a dispersion;
##     scale = mu / shape, CV = 1 / sqrt(shape).
##   * `phi_gamma_delta` (delta_gamma, fid 13) is the CV of the positive
##     part; shape = 1 / phi^2, scale = mu * phi^2.
##   * `sigma_student` (student, fid 9) is the SCALE, not the SD;
##     SD = sigma * sqrt(df / (df - 2)), undefined for df <= 2.
##   * `phi_truncnb2` (truncated_nbinom2, fid 11) is a SEPARATE per-trait
##     vector from `phi_nbinom2` (its own log_phi_truncnb2 PARAMETER_VECTOR).
##   * `sigma_eps` has one within-family shared slot in pure fits. When
##     gaussian (fid 0) and lognormal (fid 3) coexist it has two slots:
##     Gaussian raw-scale SD, then lognormal log-scale SD. It is not per-trait.
##
## `.gllvmTMB_family_cdf_args()` converts a trait's reported values into
## standard R distribution arguments once, in one place. NOTE ON THE SOURCE
## OF TRUTH: `.gllvmTMB_exact_rq_residuals()` (R/predictive-diagnostics.R)
## performs the same conversions inline per row; its branches interleave the
## conversion lines with per-row status handling, support checks, and RNG,
## so extracting them would restructure the loop rather than only the
## conversions. The accessor therefore mirrors those branches EXACTLY and
## tests/testthat/test-family-cdf-args-1080.R pins the agreement between the
## two on fitted objects. Any change to a conversion here or in the residual
## branches must keep that test green.

## Read element t of a per-trait report vector, NA when absent/short.
.gllvmTMB_report_at <- function(v, t) {
  if (is.null(v) || length(v) < t) NA_real_ else as.numeric(v[t])
}

#' Standard-R distribution arguments for one trait's family
#'
#' Internal accessor converting the engine-parameterised dispersion
#' quantities on `fit$report` into standard R distribution arguments for
#' the family of one trait. With `eta` supplied (the linear-predictor
#' value(s) for rows of that trait), the mean-dependent arguments are
#' completed; without it, only the per-trait constants are returned and
#' `note` records what `eta` would complete.
#'
#' @param fit A fitted `gllvmTMB_multi` object (or a list carrying
#'   `tmb_data` and `report` in the same layout).
#' @param trait_id 1-based trait index (matching
#'   `fit$tmb_data$trait_id + 1L`).
#' @param eta Optional numeric vector of linear-predictor values for rows
#'   of this trait, used to complete mean-dependent arguments.
#' @return A list with `trait_id`, `family_id`, `family`, `dist` (the
#'   base-R distribution stem for `p*/q*/d*` functions, or `NA` when none
#'   exists), `report` (the raw reported per-trait values, under their
#'   report names), `args` (the converted standard-R arguments), and
#'   `note` (character; conversion formula and caveats).
#' @keywords internal
#' @noRd
.gllvmTMB_family_cdf_args <- function(fit, trait_id, eta = NULL) {
  trait_id <- as.integer(trait_id)
  n_traits <- length(unique(as.integer(fit$tmb_data$trait_id)))
  if (length(trait_id) != 1L || is.na(trait_id) || trait_id < 1L) {
    cli::cli_abort(c(
      "{.arg trait_id} must be a single positive integer.",
      ">" = "Pass a value from 1 to {n_traits} (this fit's number of traits), matching {.code fit$tmb_data$trait_id + 1L}."
    ))
  }
  tid_rows <- as.integer(fit$tmb_data$trait_id) + 1L
  rows <- which(tid_rows == trait_id)
  if (length(rows) == 0L) {
    cli::cli_abort(c(
      "No rows with trait_id {trait_id} in {.code fit$tmb_data$trait_id}.",
      ">" = "This fit has {n_traits} trait(s); pass a {.arg trait_id} from 1 to {n_traits}."
    ))
  }
  fid <- unique(as.integer(fit$tmb_data$family_id_vec[rows]))
  if (length(fid) != 1L || is.na(fid)) {
    cli::cli_abort(c(
      "Trait {trait_id} does not map to a single known family_id.",
      ">" = "This usually means mixed families were assigned inconsistently within the trait; check {.code fit$family_input} for this trait."
    ))
  }
  lid <- unique(as.integer(fit$tmb_data$link_id_vec[rows]))
  lid <- if (length(lid) == 1L) lid else NA_integer_
  rep_ <- fit$report
  t <- trait_id
  has_eta <- !is.null(eta)
  if (has_eta) {
    eta <- as.numeric(eta)
  }

  out <- list(
    trait_id = t,
    family_id = fid,
    family = .gllvmTMB_family_label_from_id(fid),
    dist = NA_character_,
    report = list(),
    args = list(),
    note = character(0)
  )

  if (fid == 0L) {
    ## Gaussian, identity link: y ~ Normal(eta, sigma_eps). Joint Gaussian-
    ## lognormal fits use the raw-scale Gaussian slot.
    sigma_eps <- .gllvmTMB_sigma_eps_for_family(fit, 0L)
    out$dist <- "norm"
    out$report <- list(sigma_eps = sigma_eps)
    out$args <- list(sd = sigma_eps)
    if (has_eta) out$args$mean <- eta
    out$note <- paste(
      "Gaussian raw-scale sigma_eps; shared by Gaussian traits; mean = eta."
    )
  } else if (fid == 1L) {
    ## Binomial: prob = linkinv(eta) per link_id (0 logit, 1 probit,
    ## 2 cloglog); size is the row-level n_trials, not a trait constant.
    out$dist <- "binom"
    if (has_eta && !is.na(lid) && lid %in% c(0L, 1L, 2L)) {
      out$args$prob <- .gllvmTMB_binom_prob(eta, lid)
    }
    out$note <- paste(
      "prob = linkinv(eta) by link_id (0 logit, 1 probit, 2 cloglog);",
      "size = the row's n_trials (row-level, not per-trait)."
    )
  } else if (fid == 2L) {
    out$dist <- "pois"
    if (has_eta) out$args$lambda <- exp(eta)
    out$note <- "lambda = exp(eta)."
  } else if (fid == 3L) {
    ## Lognormal: log(y) ~ Normal(eta, sigma_eps). Joint Gaussian-lognormal
    ## fits use the distinct log-scale slot.
    sigma_eps <- .gllvmTMB_sigma_eps_for_family(fit, 3L)
    out$dist <- "lnorm"
    out$report <- list(sigma_eps = sigma_eps)
    out$args <- list(sdlog = sigma_eps)
    if (has_eta) out$args$meanlog <- eta
    out$note <- paste(
      "lognormal log-scale sigma_eps; shared by lognormal traits;",
      "meanlog = eta."
    )
  } else if (fid == 4L) {
    ## Gamma: phi_gamma is the SHAPE (mean-shape parameterisation).
    shape <- .gllvmTMB_report_at(rep_$phi_gamma, t)
    out$dist <- "gamma"
    out$report <- list(phi_gamma = shape)
    out$args <- list(shape = shape)
    if (has_eta) out$args$scale <- exp(eta) / shape
    out$note <- paste(
      "phi_gamma is the SHAPE, not a dispersion: scale = exp(eta) / shape,",
      "E(y) = exp(eta), CV(y) = 1 / sqrt(shape)."
    )
  } else if (fid == 5L) {
    size <- .gllvmTMB_report_at(rep_$phi_nbinom2, t)
    out$dist <- "nbinom"
    out$report <- list(phi_nbinom2 = size)
    out$args <- list(size = size)
    if (has_eta) out$args$mu <- exp(eta)
    out$note <- "phi_nbinom2 is the NB size; Var(y) = mu + mu^2 / size."
  } else if (fid == 6L) {
    ## Tweedie: no base-R CDF; args follow tweedie::ptweedie() naming.
    phi <- .gllvmTMB_report_at(rep_$phi_tweedie, t)
    power <- .gllvmTMB_report_at(rep_$p_tweedie, t)
    out$report <- list(phi_tweedie = phi, p_tweedie = power)
    out$args <- list(phi = phi, power = power)
    if (has_eta) out$args$mu <- exp(eta)
    out$note <- paste(
      "No base-R CDF; args follow tweedie::ptweedie() (mu = exp(eta),",
      "phi = dispersion, power = p in (1, 2))."
    )
  } else if (fid == 7L) {
    ## Beta: phi_beta is the PRECISION (mean-precision parameterisation);
    ## the engine hardcodes the logit link for this family.
    phi <- .gllvmTMB_report_at(rep_$phi_beta, t)
    out$dist <- "beta"
    out$report <- list(phi_beta = phi)
    if (has_eta) {
      mu <- stats::plogis(eta)
      out$args <- list(shape1 = mu * phi, shape2 = (1 - mu) * phi)
    }
    out$note <- paste(
      "phi_beta is the precision: shape1 = mu * phi, shape2 = (1 - mu) * phi",
      "with mu = plogis(eta) (logit link is hardcoded for this family)."
    )
  } else if (fid == 8L) {
    ## Beta-binomial: precision of the Beta mixing distribution; no base-R
    ## CDF exists (see .gllvmTMB_betabinom_cdf).
    phi <- .gllvmTMB_report_at(rep_$phi_betabinom, t)
    out$report <- list(phi_betabinom = phi)
    if (has_eta) {
      mu <- stats::plogis(eta)
      out$args <- list(shape1 = mu * phi, shape2 = (1 - mu) * phi)
    }
    out$note <- paste(
      "phi_betabinom is the Beta-mixing precision: a = mu * phi,",
      "b = (1 - mu) * phi with mu = plogis(eta); size = the row's n_trials.",
      "No base-R CDF (see .gllvmTMB_betabinom_cdf)."
    )
  } else if (fid == 9L) {
    ## Student-t, identity link: sigma_student is the SCALE, not the SD.
    sigma <- .gllvmTMB_report_at(rep_$sigma_student, t)
    df <- .gllvmTMB_report_at(rep_$df_student, t)
    out$dist <- "t"
    out$report <- list(sigma_student = sigma, df_student = df)
    out$args <- list(df = df, scale = sigma)
    out$args$sd <- if (is.finite(df) && df > 2) {
      sigma * sqrt(df / (df - 2))
    } else {
      NA_real_
    }
    if (has_eta) out$args$location <- eta
    out$note <- paste(
      "sigma_student is the SCALE, not the SD: SD = scale *",
      "sqrt(df / (df - 2)), undefined (NA) for df <= 2. CDF:",
      "pt((y - eta) / scale, df)."
    )
  } else if (fid == 10L) {
    out$dist <- "pois"
    if (has_eta) out$args$lambda <- exp(eta)
    out$note <- paste(
      "Zero-truncated Poisson: lambda = exp(eta) of the UNtruncated",
      "distribution; renormalise the CDF by 1 - ppois(0, lambda)."
    )
  } else if (fid == 11L) {
    ## Truncated NB2: its OWN per-trait size vector, not phi_nbinom2.
    size <- .gllvmTMB_report_at(rep_$phi_truncnb2, t)
    out$dist <- "nbinom"
    out$report <- list(phi_truncnb2 = size)
    out$args <- list(size = size)
    if (has_eta) out$args$mu <- exp(eta)
    out$note <- paste(
      "phi_truncnb2 is a SEPARATE per-trait size from phi_nbinom2 (its own",
      "parameter vector); mu = exp(eta) of the UNtruncated NB2; renormalise",
      "the CDF by 1 - pnbinom(0, size, mu = mu)."
    )
  } else if (fid == 12L) {
    ## delta_lognormal (hurdle): sdlog of the positive part; presence
    ## probability plogis(eta) at the SAME shared eta.
    sdlog <- .gllvmTMB_report_at(rep_$sigma_lognormal_delta, t)
    out$dist <- "lnorm"
    out$report <- list(sigma_lognormal_delta = sdlog)
    out$args <- list(sdlog = sdlog)
    if (has_eta) out$args$meanlog <- eta
    out$note <- paste(
      "Hurdle positive part only: log(y) | y > 0 ~ Normal(eta, sdlog);",
      "presence P(y > 0) = plogis(eta) at the same shared eta."
    )
  } else if (fid == 13L) {
    ## delta_gamma (hurdle): phi_gamma_delta is the CV of the positive
    ## part, NOT a shape.
    cv <- .gllvmTMB_report_at(rep_$phi_gamma_delta, t)
    out$dist <- "gamma"
    out$report <- list(phi_gamma_delta = cv)
    out$args <- list(shape = 1 / cv^2)
    if (has_eta) out$args$scale <- exp(eta) * cv^2
    out$note <- paste(
      "phi_gamma_delta is the CV of the positive part, NOT a shape:",
      "shape = 1 / phi^2, scale = exp(eta) * phi^2, E(y | y > 0) = exp(eta);",
      "presence P(y > 0) = plogis(eta) at the same shared eta."
    )
  } else if (fid == 14L) {
    ## ordinal_probit: cutpoints tau_1 = 0 fixed, tau_2..tau_{K-1} read
    ## from the flattened report (same reconstruction as the residual and
    ## simulate paths).
    n_cuts <- as.integer(fit$tmb_data$n_ordinal_cuts_per_trait %||% integer(0))
    offsets <- as.integer(fit$tmb_data$ordinal_offset_per_trait %||% integer(0))
    flat <- as.numeric(rep_$ordinal_cutpoints %||% numeric(0))
    cuts <- if (t <= length(n_cuts) && !is.na(n_cuts[t]) && n_cuts[t] >= 0L) {
      extra <- if (n_cuts[t] > 0L) {
        flat[(offsets[t] + 1L):(offsets[t] + n_cuts[t])]
      } else {
        numeric(0)
      }
      c(0, extra)
    } else {
      NULL
    }
    out$report <- list(ordinal_cutpoints = cuts)
    out$args <- list(cutpoints = cuts)
    if (has_eta) out$args$mean <- eta
    out$note <- paste(
      "Threshold model with unit link-scale variance: P(y <= k) =",
      "pnorm(tau_k - eta), tau_1 = 0 fixed."
    )
  } else if (fid == 20L) {
    ## ordinal_logit: identical cutpoint reconstruction to fid 14, with the
    ## logistic CDF instead of pnorm (link-scale variance pi^2/3, not 1).
    n_cuts <- as.integer(fit$tmb_data$n_ordinal_cuts_per_trait %||% integer(0))
    offsets <- as.integer(fit$tmb_data$ordinal_offset_per_trait %||% integer(0))
    flat <- as.numeric(rep_$ordinal_cutpoints %||% numeric(0))
    cuts <- if (t <= length(n_cuts) && !is.na(n_cuts[t]) && n_cuts[t] >= 0L) {
      extra <- if (n_cuts[t] > 0L) {
        flat[(offsets[t] + 1L):(offsets[t] + n_cuts[t])]
      } else {
        numeric(0)
      }
      c(0, extra)
    } else {
      NULL
    }
    out$report <- list(ordinal_cutpoints = cuts)
    out$args <- list(cutpoints = cuts)
    if (has_eta) out$args$mean <- eta
    out$note <- paste(
      "Threshold model with pi^2/3 link-scale variance: P(y <= k) =",
      "plogis(tau_k - eta), tau_1 = 0 fixed."
    )
  } else if (fid == 15L) {
    ## NB1: linear mean-variance Var = mu * (1 + phi); the NB size is
    ## mu / phi, so it is mean-dependent.
    phi <- .gllvmTMB_report_at(rep_$phi_nbinom1, t)
    out$dist <- "nbinom"
    out$report <- list(phi_nbinom1 = phi)
    if (has_eta) {
      mu <- exp(eta)
      out$args <- list(size = mu / phi, mu = mu)
    }
    out$note <- paste(
      "phi_nbinom1 gives the linear overdispersion Var(y) = mu * (1 + phi);",
      "the NB size is mu / phi (mean-dependent), NOT phi."
    )
  } else {
    out$note <- paste0(
      "No scalar CDF conversion for family_id ", fid,
      " (unordered categorical or unsupported)."
    )
  }

  out
}
