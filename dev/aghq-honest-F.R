## A COMMON YARDSTICK for comparing two AGHQ parameter vectors.
##
## The honest AGHQ objective is F(theta) = the quadrature objective with the
## adaptation points solved AT theta. A fit's own $opt$objective is NOT that in
## general (the pre-continuation loop returned a tape adapted one optimiser step
## behind), so comparing two fits' reported objectives compares two different
## functions. This rebuilds F from an AGHQ object + a Laplace object of the SAME
## model and evaluates it wherever asked.
##
## fit_aghq : any AGHQ fit of the model  (supplies the quadrature tape)
## fit_lap  : a Laplace fit of the same model (supplies the conditional-mode solver)
aghq_F <- function(fit_aghq, fit_lap, par) {
  o <- fit_aghq$tmb_obj
  d_B <- ncol(o$env$data$aghq_mode)
  n_sites <- nrow(o$env$data$aghq_mode)
  stopifnot(identical(names(par), names(fit_lap$tmb_obj$par)))
  ad <- gllvmTMB:::.gllvmTMB_aghq_adapt(fit_lap$tmb_obj, par, d_B, n_sites)
  o$env$data$aghq_mode   <- ad$mode
  o$env$data$aghq_Lt     <- ad$Lt
  o$env$data$aghq_logdet <- as.numeric(ad$logdet)
  o$retape()
  as.numeric(o$fn(par))
}

## ||Sigma_B||_F at a given parameter vector, via the fit's own report().
aghq_frob <- function(fit, p, q) {
  L <- fit$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  norm(L %*% t(L), "F")
}
