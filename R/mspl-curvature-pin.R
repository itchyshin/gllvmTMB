## Internal LA-MSPL curvature pin (availability only).
##
## Names two numerical Hessians at the MSPL point:
##   Q_P = fit$tmb_obj              (estimator_id = 1, active penalised tape)
##   Q_0 = fit$mspl$unpenalized_tmb_obj (estimator_id = 2, evaluate only)
##
## This is not TMB::sdreport(), not I_LA(beta), and not a public SE.
## Non-PD Hessians stay typed. No pseudoinverse, clip, or nearest-PD.
## Do not copy Codex lane-b helpers. Do not export.
##
## Family fence (availability pin only; not admission):
##   binomial + logit, poisson + log, gaussian + identity.

.gllvmTMB_mspl_pin_family_link <- function(fit) {
  fam <- fit$family
  family_name <- if (inherits(fam, "family")) {
    as.character(fam$family[[1L]])
  } else {
    as.character(fit$mspl$family %||% NA_character_)
  }
  link_name <- if (inherits(fam, "family")) {
    as.character(fam$link[[1L]])
  } else {
    NA_character_
  }
  list(family = family_name, link = link_name)
}

.gllvmTMB_mspl_tape_estimator_id <- function(obj) {
  id <- tryCatch(as.integer(obj$env$data$estimator_id), error = function(e) NA_integer_)
  if (length(id) != 1L) NA_integer_ else id
}

.gllvmTMB_mspl_numerical_hessian_status <- function(obj, par) {
  empty <- function(status, nll = NA_real_, min_ev = NA_real_,
                    se = rep(NA_real_, length(par)), message = NA_character_) {
    list(
      status = status,
      nll = nll,
      hessian_pd = identical(status, "available"),
      se_finite = identical(status, "available"),
      se = as.numeric(se),
      minimum_eigenvalue = min_ev,
      repaired = FALSE,
      message = message
    )
  }
  if (is.null(obj) || !is.function(obj$fn) || !is.function(obj$gr)) {
    return(empty("error", message = "TMB objective is missing fn or gr"))
  }
  if (!is.numeric(par) || !length(par) || any(!is.finite(par))) {
    return(empty("nonfinite", message = "MSPL point is not a finite parameter vector"))
  }

  checkpoint <- .gllvmTMB_profile_tmb_checkpoint(obj)
  on.exit(.gllvmTMB_restore_profile_tmb_checkpoint(obj, checkpoint), add = TRUE)

  nll <- tryCatch(as.numeric(obj$fn(par)), error = function(e) NA_real_)
  if (length(nll) != 1L || !is.finite(nll)) {
    return(empty("nonfinite", nll = nll, message = "tape NLL is non-finite at the MSPL point"))
  }

  hess <- tryCatch(
    stats::optimHess(par, fn = obj$fn, gr = obj$gr),
    error = function(e) e
  )
  if (inherits(hess, "error")) {
    return(empty("error", nll = nll, message = conditionMessage(hess)))
  }
  hess <- as.matrix(hess)
  if (!identical(as.integer(dim(hess)), c(length(par), length(par))) ||
      any(!is.finite(hess))) {
    return(empty("nonfinite", nll = nll, message = "numerical Hessian is non-finite"))
  }
  hess <- (hess + t(hess)) / 2

  ev <- tryCatch(
    eigen(hess, symmetric = TRUE, only.values = TRUE)$values,
    error = function(e) NA_real_
  )
  if (!length(ev) || any(!is.finite(ev))) {
    return(empty("nonfinite", nll = nll, message = "Hessian eigenvalues are non-finite"))
  }
  min_ev <- min(ev)
  if (min_ev <= 0) {
    return(empty("non_pd", nll = nll, min_ev = min_ev))
  }
  chol_ok <- tryCatch({
    chol(hess)
    TRUE
  }, error = function(e) FALSE)
  if (!isTRUE(chol_ok)) {
    return(empty("non_pd", nll = nll, min_ev = min_ev))
  }
  inv <- tryCatch(solve(hess), error = function(e) e)
  if (inherits(inv, "error") || any(!is.finite(inv))) {
    return(empty("nonfinite", nll = nll, min_ev = min_ev,
                 message = "Hessian inverse is non-finite"))
  }
  se <- sqrt(diag(inv))
  if (any(!is.finite(se))) {
    return(empty("nonfinite", nll = nll, min_ev = min_ev, se = se,
                 message = "at least one SE is non-finite"))
  }
  empty("available", nll = nll, min_ev = min_ev, se = se)
}

.gllvmTMB_mspl_curvature_pin <- function(fit) {
  if (!.gllvmTMB_is_mspl(fit)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL curvature pin requires an {.code estimator = \"mspl\"} fit.",
      class = "gllvmTMB_mspl_curvature_input"
    )
  }
  fl <- .gllvmTMB_mspl_pin_family_link(fit)
  allowed <- (identical(fl$family, "binomial") && identical(fl$link, "logit")) ||
    (identical(fl$family, "poisson") && identical(fl$link, "log")) ||
    (identical(fl$family, "gaussian") && identical(fl$link, "identity"))
  if (!isTRUE(allowed)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL curvature pin is fenced to Bernoulli logit, Poisson log, and Gaussian identity.",
      "x" = "Resolved family {.val {fl$family}}, link {.val {fl$link}}.",
      class = "gllvmTMB_mspl_curvature_family"
    )
  }
  if (is.null(fit$tmb_obj) || is.null(fit$mspl$unpenalized_tmb_obj)) {
    .gllvmTMB_mspl_abort(
      "The internal MSPL curvature pin needs both the penalised and penalty-off TMB tapes.",
      class = "gllvmTMB_mspl_curvature_tape"
    )
  }

  par <- fit$opt$par
  qp <- .gllvmTMB_mspl_numerical_hessian_status(fit$tmb_obj, par)
  q0 <- .gllvmTMB_mspl_numerical_hessian_status(fit$mspl$unpenalized_tmb_obj, par)

  list(
    family = fl$family,
    link = fl$link,
    public_se_withheld = is.null(fit$sd_report),
    penalised = c(
      list(
        tape = "Q_P",
        estimator_id = .gllvmTMB_mspl_tape_estimator_id(fit$tmb_obj),
        hessian_method = "stats::optimHess on the active penalised tape"
      ),
      qp
    ),
    penalty_off = c(
      list(
        tape = "Q_0",
        estimator_id = .gllvmTMB_mspl_tape_estimator_id(fit$mspl$unpenalized_tmb_obj),
        hessian_method = "stats::optimHess on the penalty-off tape at the MSPL point",
        evaluated_not_optimised = TRUE
      ),
      q0
    )
  )
}
