.normalise_Xcoef_fixed <- function(Xcoef_fixed, x_names, REML = FALSE) {
  n <- length(x_names)
  out <- list(
    map = factor(seq_len(n)),
    init_fixed = rep(NA_real_, n),
    status = rep("estimated", n),
    terms = character(0),
    has_fixed = FALSE
  )
  if (is.null(Xcoef_fixed)) {
    return(out)
  }
  if (isTRUE(REML)) {
    cli::cli_abort(c(
      "{.arg Xcoef_fixed} is not yet available for {.code REML = TRUE}.",
      "i" = "Fit with {.code REML = FALSE} when pinning fixed-effect coefficients."
    ))
  }
  if (!is.numeric(Xcoef_fixed) || is.null(names(Xcoef_fixed))) {
    cli::cli_abort(c(
      "{.arg Xcoef_fixed} must be a named numeric vector.",
      "i" = "Use expanded fixed-effect column names, for example {.code c(\"traitB:x\" = 0)}."
    ))
  }
  terms <- names(Xcoef_fixed)
  if (any(!nzchar(terms))) {
    cli::cli_abort("{.arg Xcoef_fixed} entries must all have non-empty names.")
  }
  if (anyDuplicated(terms)) {
    dup <- unique(terms[duplicated(terms)])
    cli::cli_abort(c(
      "{.arg Xcoef_fixed} names must be unique.",
      "x" = "Duplicated name(s): {.val {dup}}."
    ))
  }
  bad <- setdiff(terms, x_names)
  if (length(bad)) {
    cli::cli_abort(c(
      "{.arg Xcoef_fixed} names must match expanded fixed-effect columns.",
      "x" = "Unknown name(s): {.val {bad}}.",
      "i" = "Available fixed-effect columns include: {.val {head(x_names, 12)}}."
    ))
  }
  vals <- as.numeric(Xcoef_fixed)
  if (any(!is.finite(vals))) {
    cli::cli_abort("{.arg Xcoef_fixed} values must be finite numbers.")
  }
  if (any(vals != 0)) {
    cli::cli_abort(c(
      "{.arg Xcoef_fixed} currently supports only structural-zero constraints.",
      "x" = "Non-zero fixed values are not implemented in this first slice."
    ))
  }

  fixed_idx <- match(terms, x_names)
  free_idx <- setdiff(seq_len(n), fixed_idx)
  map <- rep(NA_integer_, n)
  map[free_idx] <- seq_along(free_idx)
  out$map <- factor(map)
  out$init_fixed[fixed_idx] <- 0
  out$status[fixed_idx] <- "fixed"
  out$terms <- terms
  out$has_fixed <- length(fixed_idx) > 0L
  out
}

.gllvmTMB_xcoef_status <- function(fit) {
  n <- length(fit$X_fix_names %||% character(0))
  status <- fit$Xcoef_fixed$status
  if (is.null(status) || length(status) != n) {
    return(rep("estimated", n))
  }
  status
}

## Map each row of `X_fix_names` / the tidy fixed table to the `which`
## argument for `tmbprofile(..., name = "b_fix", which = )`, i.e. the index
## among `b_fix` entries in `opt$par`. NA for aliased / mapped-out columns.
## `confint()` and `vcov()` must share this alignment (#1959).
.gllvmTMB_b_fix_profile_which <- function(fit) {
  n <- length(fit$X_fix_names %||% character(0))
  if (n == 0L) {
    return(integer(0))
  }
  status <- .gllvmTMB_xcoef_status(fit)
  free <- status != "fixed"
  out <- rep(NA_integer_, n)
  n_free <- sum(free)
  if (n_free == 0L) {
    return(out)
  }
  n_bfix <- sum(names(fit$opt$par) == "b_fix")
  if (n_bfix != n_free) {
    return(out)
  }
  out[free] <- seq_len(n_free)
  out
}

## Wald standard error for one `opt$par` position from `sd_report$cov.fixed`.
.gllvmTMB_sdreport_se_index <- function(fit, idx_par) {
  cv <- fit$sd_report$cov.fixed
  if (is.null(cv) || !is.matrix(cv)) {
    return(NA_real_)
  }
  idx_par <- as.integer(idx_par)
  if (length(idx_par) != 1L || idx_par < 1L || idx_par > nrow(cv)) {
    return(NA_real_)
  }
  val <- unname(cv[idx_par, idx_par])
  if (!is.finite(val) || val < 0) {
    return(NA_real_)
  }
  sqrt(val)
}
