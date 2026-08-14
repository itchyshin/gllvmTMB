bfgs_signature_fixture <- function() {
  nms <- gllvmTMB:::.gllvmTMB_isdm_g3_signature_names
  ans <- as.list(stats::setNames(paste0("sealed-", nms), nms))
  ans$source_gate <- "BFGS_EXACT_GRADIENT_UNIT"
  ans
}

bfgs_raw_state_fixture <- function() {
  list(
    optimizer = "nlminb", convergence = 0L, pd_hessian = FALSE,
    boundary_flags = character(), is_isdm = TRUE, aghq = FALSE,
    ridge = FALSE, retry_enabled = FALSE, profile_enabled = FALSE,
    source_gate = "BFGS_EXACT_GRADIENT_UNIT"
  )
}

bfgs_curvature_record <- function(theta, positional_ids, covariance,
                                  available = TRUE, pd_hess = TRUE,
                                  reason = "available", error = NA_character_) {
  covariance <- as.matrix(covariance)
  dimnames(covariance) <- list(positional_ids, positional_ids)
  list(
    available = available, reason = reason,
    par.fixed = if (available) theta else NULL,
    cov.fixed = if (available) covariance else NULL,
    pdHess = if (available) pd_hess else NA,
    positional_ids = positional_ids, error = error
  )
}

bfgs_quadratic_fixture <- function() {
  hessian <- diag(c(2, 5, 9))
  gradient <- c(0.004, 0.002, 0.001)
  par <- drop(solve(hessian, gradient))
  names(par) <- c("beta", "theta", "theta")
  obj <- list(
    fn = function(theta) drop(crossprod(theta, hessian %*% theta) / 2),
    gr = function(theta) drop(hessian %*% theta)
  )
  list(
    obj = obj, par = par, gradient = gradient, hessian = hessian,
    covariance = solve(hessian), objective = obj$fn(par)
  )
}
