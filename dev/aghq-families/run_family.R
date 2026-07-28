## dev/aghq-families/run_family.R -- fit one (family, seed, k) cell under
## Laplace and under AGHQ, and return ONE ROW comparing them.
##
## Source family_spec.R first (defines family_spec(), .aghq_fam_formula()).

## ---------------------------------------------------------------------
## The identified error functionals. Reused VERBATIM from established
## convention already in this repo (not invented here):
##   rel_frobenius   -- dev/aghq-r-reference.R's `ref_rel_frob()`
##   attenuation_ratio -- dev/controlled-gh-vs-jj.R / dev/three-engine-demo.R's
##                        `attenuation_ratio()`
## Both are rotation-invariant: computed on Sigma = Lambda Lambda', never on
## Lambda itself (Lambda is only identified up to a q x q rotation).
##
##   rel_frobenius(Sigma_hat, Sigma_true)
##     = ||Sigma_hat - Sigma_true||_F / ||Sigma_true||_F
##     Overall distance between the estimated and true covariance.
##
##   attenuation_ratio(Sigma_hat, Sigma_true) = tr(Sigma_hat) / tr(Sigma_true)
##     A SCALE-only summary: the pre-registered AGHQ-vs-Laplace kill rule
##     (kill_rule.R) is stated in terms of this quantity because Laplace's
##     known failure mode against a genuinely non-Gaussian likelihood is to
##     SHRINK (attenuate) the estimated random-effect variance toward zero;
##     attenuation_ratio < 1 is shrinkage, > 1 is inflation, and 1 is exact
##     recovery. |attenuation_ratio - 1| scores under- and over-shoot
##     IDENTICALLY (see kill_rule.R) -- this file only computes the ratio;
##     it does not take the absolute deviation itself.
## ---------------------------------------------------------------------

.aghq_fam_rel_frobenius <- function(Sigma_hat, Sigma_true) {
  norm(Sigma_hat - Sigma_true, "F") / norm(Sigma_true, "F")
}

.aghq_fam_attenuation_ratio <- function(Sigma_hat, Sigma_true) {
  sum(diag(Sigma_hat)) / sum(diag(Sigma_true))
}

## Fit one engine (Laplace: aghq = FALSE; AGHQ: aghq = k) and extract the
## metrics needed for one row. Never throws: every failure mode is caught
## and reported in the `error` field, so one bad cell cannot abort a
## multi-family run (the driver relies on this).
.aghq_fam_fit_one <- function(fml, df, family_obj, unit_col, p, q,
                              aghq_ctrl, Sigma_true) {
  t0 <- Sys.time()
  out <- list(objective = NA_real_, frob = NA_real_, rel_frob = NA_real_,
              attenuation = NA_real_, convergence = NA_integer_,
              aghq_used = NA, aghq_reason = NA_character_,
              elapsed = NA_real_, error = NA_character_)
  fit <- tryCatch(
    suppressWarnings(suppressMessages(gllvmTMB::gllvmTMB(
      fml, data = df, unit = unit_col, trait = "trait",
      family = family_obj, control = aghq_ctrl
    ))),
    error = function(e) e
  )
  out$elapsed <- as.numeric(Sys.time() - t0, units = "secs")
  if (inherits(fit, "error")) {
    out$error <- conditionMessage(fit)
    return(out)
  }
  Lambda_hat <- tryCatch(
    fit$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE],
    error = function(e) NULL
  )
  if (is.null(Lambda_hat) || anyNA(Lambda_hat)) {
    out$error <- "fit$report$Lambda_B missing or NA after fit"
    out$convergence <- suppressWarnings(as.integer(fit$opt$convergence))
    return(out)
  }
  Sigma_hat <- Lambda_hat %*% t(Lambda_hat)
  out$objective   <- suppressWarnings(as.numeric(fit$opt$objective))
  out$convergence <- suppressWarnings(as.integer(fit$opt$convergence))
  out$frob        <- norm(Sigma_hat, "F")
  out$rel_frob    <- .aghq_fam_rel_frobenius(Sigma_hat, Sigma_true)
  out$attenuation <- .aghq_fam_attenuation_ratio(Sigma_hat, Sigma_true)
  out$aghq_used   <- isTRUE(fit$aghq$used)
  out$aghq_reason <- fit$aghq$reason %||% NA_character_
  out
}

`%||%` <- function(x, y) if (is.null(x)) y else x

## run_family(spec, seed, k): simulate from `spec`'s DGP, fit Laplace (k = 1
## rule, via aghq = FALSE) and AGHQ (aghq = k), and return ONE ROW comparing
## them. Never aborts: any failure at any stage lands in the `error` column
## with NA metrics rather than propagating (the driver depends on this to
## survive a bad cell).
run_family <- function(spec, seed, k = 9L) {
  base <- data.frame(family = spec$name, fid = spec$fid, seed = seed, k = k,
                      n = spec$n, p = spec$p, q = spec$q, n_rep = spec$n_rep,
                      stringsAsFactors = FALSE)

  sim <- tryCatch(spec$simulate(seed), error = function(e) e)
  if (inherits(sim, "error")) {
    return(cbind(base, data.frame(
      objective_laplace = NA_real_, objective_aghq = NA_real_,
      frob_laplace = NA_real_, frob_aghq = NA_real_,
      rel_frob_laplace = NA_real_, rel_frob_aghq = NA_real_,
      attenuation_laplace = NA_real_, attenuation_aghq = NA_real_,
      convergence_laplace = NA_integer_, convergence_aghq = NA_integer_,
      aghq_used = NA, aghq_reason = NA_character_,
      elapsed_laplace = NA_real_, elapsed_aghq = NA_real_,
      error = paste0("simulate() failed: ", conditionMessage(sim)),
      stringsAsFactors = FALSE
    )))
  }

  fml <- .aghq_fam_formula(sim$response_lhs, spec$q)
  family_obj <- tryCatch(spec$family(), error = function(e) e)
  if (inherits(family_obj, "error")) {
    return(cbind(base, data.frame(
      objective_laplace = NA_real_, objective_aghq = NA_real_,
      frob_laplace = NA_real_, frob_aghq = NA_real_,
      rel_frob_laplace = NA_real_, rel_frob_aghq = NA_real_,
      attenuation_laplace = NA_real_, attenuation_aghq = NA_real_,
      convergence_laplace = NA_integer_, convergence_aghq = NA_integer_,
      aghq_used = NA, aghq_reason = NA_character_,
      elapsed_laplace = NA_real_, elapsed_aghq = NA_real_,
      error = paste0("family constructor failed: ", conditionMessage(family_obj)),
      stringsAsFactors = FALSE
    )))
  }

  ctrl_laplace <- gllvmTMB::gllvmTMBcontrol(aghq = FALSE, n_init = 1L,
                                            init_jitter = 0, se = FALSE)
  ctrl_aghq    <- gllvmTMB::gllvmTMBcontrol(aghq = k, n_init = 1L,
                                            init_jitter = 0, se = FALSE)

  lap  <- .aghq_fam_fit_one(fml, sim$df, family_obj, "unit", spec$p, spec$q,
                            ctrl_laplace, sim$Sigma_true)
  agh  <- .aghq_fam_fit_one(fml, sim$df, family_obj, "unit", spec$p, spec$q,
                            ctrl_aghq, sim$Sigma_true)

  err <- paste(
    if (!is.na(lap$error)) paste0("laplace: ", lap$error) else NULL,
    if (!is.na(agh$error)) paste0("aghq: ", agh$error) else NULL,
    collapse = " | "
  )
  if (identical(err, "")) err <- NA_character_

  cbind(base, data.frame(
    objective_laplace    = lap$objective,    objective_aghq    = agh$objective,
    frob_laplace         = lap$frob,         frob_aghq         = agh$frob,
    rel_frob_laplace     = lap$rel_frob,     rel_frob_aghq     = agh$rel_frob,
    attenuation_laplace  = lap$attenuation,  attenuation_aghq  = agh$attenuation,
    convergence_laplace  = lap$convergence,  convergence_aghq  = agh$convergence,
    aghq_used            = agh$aghq_used,    aghq_reason       = agh$aghq_reason,
    elapsed_laplace      = lap$elapsed,      elapsed_aghq      = agh$elapsed,
    error                = err,
    stringsAsFactors = FALSE
  ))
}
