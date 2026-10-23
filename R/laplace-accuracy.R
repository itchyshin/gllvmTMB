## Laplace-accuracy audit for check_gllvmTMB() (#1389).
##
## A converged Laplace fit can sit where the Laplace objective is optimistic:
## on psychTools::ability a probit d = 2 fit with one spike item reported a
## logLik 67 units ABOVE the exact marginal logLik at the same parameters,
## with every convergence and Hessian check passing. No fit-side statistic
## (gradient, Hessian, loading size) can see that, because the approximation
## error lives in the objective itself. The only direct test is to evaluate
## the marginal likelihood more accurately at the fitted parameters and
## compare.
##
## This reuses the AGHQ engine's own pieces: `.gllvmTMB_aghq_adapt()` takes
## the conditional modes and site Hessians from the fitted Laplace object,
## and the template's `use_aghq = 1` path integrates each site's z_B block on
## an adapted tensor Gauss-Hermite grid. At k = 1 that grid IS the Laplace
## rule, so the gap measured here is exactly the Laplace error (up to the
## quadrature error at k nodes). Nothing is re-optimised: the audit evaluates
## one objective at one parameter vector.
##
## Scope mirrors the AGHQ Stage-1a fence: z_B must be the only random block
## (ordinary `latent(..., unique = FALSE)`, or a `latent()` whose Psi was
## mapped off by the identifiability gate), no multinomial / zero-inflated /
## censored rows, and d_B <= 3. Anything else returns `NULL` (not evaluated).

.gllvmTMB_laplace_accuracy_k <- function(d) {
  c(15L, 9L, 5L)[[d]]
}

.gllvmTMB_laplace_accuracy <- function(object, k = NULL, max_work = 2e7) {
  skip <- function(reason, too_large = FALSE) {
    list(evaluated = FALSE, reason = reason, too_large = too_large)
  }
  obj <- object$tmb_obj
  if (is.null(obj) || is.null(obj$env)) return(skip("no TMB object on the fit"))
  if (isTRUE(object$aghq$used)) {
    return(skip("fit already integrated by AGHQ"))
  }
  if (.gllvmTMB_is_mspl(object)) return(skip("MSPL estimator"))
  d_B <- as.integer(object$d_B %||% 0L)
  if (!isTRUE(object$use$rr_B) || d_B < 1L || d_B > 3L) {
    return(skip("no B-tier latent block with d <= 3"))
  }
  ridx <- obj$env$random
  full_names <- names(obj$env$last.par)
  if (!length(ridx) || !all(full_names[ridx] == "z_B")) {
    return(skip("random effects other than the latent scores"))
  }
  ## Rebuild from the inputs the fit stored (obj$env$data is TMB's processed
  ## copy and is not a valid MakeADFun input).
  data <- object$tmb_data %||% obj$env$data
  fid <- as.integer(data$family_id_vec %||% integer(0L))
  if (!length(fid) || any(fid %in% c(16L, 17L, 18L, 19L, 21L))) {
    return(skip("family not supported by the quadrature engine"))
  }
  if (all(fid == 0L)) {
    return(skip("all-Gaussian fit: the Laplace marginal is exact"))
  }
  if (isTRUE(as.integer(data$use_lv_B %||% 0L) == 1L) ||
      isTRUE(as.integer(data$has_mi %||% 0L) == 1L) ||
      is.null(data$use_aghq)) {
    return(skip("model class not supported by the quadrature engine"))
  }
  n_sites <- as.integer(data$n_sites)
  par <- object$opt$par
  if (is.null(par) || !all(is.finite(par))) return(skip("non-finite parameters"))
  k <- as.integer(k %||% .gllvmTMB_laplace_accuracy_k(d_B))
  ## Cost is one likelihood evaluation per (row, node): cap it so the audit
  ## stays a few seconds (about 2 s at 1.9e6 on a 23k-row d = 2 fit).
  work <- as.numeric(length(fid)) * as.numeric(k)^d_B
  if (!is.finite(work) || work > max_work) {
    return(skip(sprintf(
      "problem too large for the audit (%.3g row-node evaluations > %.3g)",
      work, max_work), too_large = TRUE))
  }

  ## The adaptation and the Laplace evaluation below move the fitted object's
  ## inner state (last.par / last.par.best, which seed the next inner
  ## optimisation). Put it back however this function exits.
  env <- obj$env
  last_par <- env$last.par
  last_par_best <- env$last.par.best
  on.exit({
    env$last.par <- last_par
    env$last.par.best <- last_par_best
  }, add = TRUE)

  res <- tryCatch({
    ad <- .gllvmTMB_aghq_adapt(obj, par, d_B, n_sites)
    nll_laplace <- as.numeric(obj$fn(par))
    grid <- .gllvmTMB_aghq_grid(d_B, k)
    data_q <- data
    data_q$use_aghq    <- 1L
    data_q$aghq_d      <- d_B
    data_q$aghq_nodes  <- grid$nodes
    data_q$aghq_logw   <- as.numeric(grid$logw)
    data_q$aghq_mode   <- ad$mode
    data_q$aghq_Lt     <- ad$Lt
    data_q$aghq_logdet <- as.numeric(ad$logdet)
    map_q <- object$tmb_map %||% list()
    pars_q <- object$tmb_params %||% obj$env$parameters
    map_q$z_B <- factor(rep(NA_integer_, length(pars_q$z_B)))
    ## type = "Fun": a plain double evaluation. Taping the quadrature for
    ## derivatives would cost ~100x more and nothing here differentiates.
    obj_q <- TMB::MakeADFun(data = data_q, parameters = pars_q, map = map_q,
                            random = NULL, DLL = "gllvmTMB", silent = TRUE,
                            type = "Fun")
    ## A "Fun" object carries no $par, so check alignment by counting the
    ## free coordinates the map leaves, block by block, in template order.
    n_free <- vapply(names(pars_q), function(nm) {
      m <- map_q[[nm]]
      if (is.null(m)) length(pars_q[[nm]]) else length(unique(stats::na.omit(as.integer(m))))
    }, numeric(1))
    expected <- rep(names(pars_q), n_free)
    if (!identical(expected, names(par))) {
      stop("quadrature parameter vector does not align with the fit")
    }
    nll_q <- as.numeric(obj_q$env$f(par, order = 0, type = "double"))
    list(nll_laplace = nll_laplace, nll_quadrature = nll_q)
  }, error = function(e) e)
  if (inherits(res, "error")) {
    return(skip(paste0("quadrature failed: ", conditionMessage(res))))
  }
  if (!is.finite(res$nll_laplace) || !is.finite(res$nll_quadrature)) {
    return(skip("non-finite objective"))
  }
  list(
    evaluated = TRUE, k = k, d = d_B,
    loglik_laplace = -res$nll_laplace,
    loglik_quadrature = -res$nll_quadrature,
    ## Positive = Laplace reports a HIGHER logLik than the integral it
    ## approximates (optimistic). That direction is what makes logLik / AIC /
    ## LRT comparisons favour the wrong model.
    optimism = res$nll_quadrature - res$nll_laplace
  )
}
