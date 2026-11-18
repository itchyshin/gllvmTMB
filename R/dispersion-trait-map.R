## Per-trait pinning for whole-vector dispersion/shape parameter gates
## (issue #1117).
##
## Each dispersion-carrying family (nbinom2, nbinom1, gamma, tweedie, beta,
## betabinom, student, truncnb2, delta_lognormal, delta_gamma) owns one
## `n_traits`-length TMB parameter vector holding its per-trait dispersion
## (or, for tweedie/student, a pair of vectors). R/fit-multi.R previously
## mapped the WHOLE vector off only when the family was absent from EVERY
## trait (`any_<family>` gates). In a MIXED-family fit where the family is
## present on SOME traits but not others, the other traits' vector entries
## were left as free parameters that the C++ per-row family dispatch
## (src/gllvmTMB.cpp fid blocks -- e.g. fid 5 nbinom2 reads
## `log_phi_nbinom2(t)` only inside `else if (fid == 5)`, ~line 2681) never
## reads for rows of a different family: a free parameter with an exactly
## zero gradient, which makes the joint Hessian singular.
##
## These two helpers build the per-trait TMB `map`, mirroring the pattern
## already used one tier up by `diag_B_skip` (R/fit-multi.R's B-tier
## auto-Psi family gate) and by `dep_chol_parity_pins()` /
## `dep_chol_crossblock_pins()` in R/lambda-constraint.R.

#' Which traits use a given family (or set of family ids)
#'
#' @param trait_id Zero-based per-row trait index (length n_obs).
#' @param family_id_vec Per-row family id (length n_obs).
#' @param fids One or more family ids that share the target parameter.
#' @param n_traits Number of traits.
#' @return `logical(n_traits)`, TRUE where the trait has at least one row
#'   of a family in `fids`.
#' @keywords internal
#' @noRd
dispersion_trait_family_mask <- function(trait_id, family_id_vec, fids, n_traits) {
  vapply(seq_len(n_traits), function(t) {
    any(family_id_vec[trait_id == (t - 1L)] %in% fids)
  }, logical(1))
}

#' Build a per-trait TMB `factor` map for a dispersion parameter vector
#'
#' Traits outside `family_mask` are pinned (mapped to `NA`, i.e. held fixed
#' at whatever value `tmb_params` already carries -- never read by the C++
#' likelihood for a non-matching row, so the value itself is immaterial).
#' `user_pin_mask` additionally pins traits the caller has already fixed by
#' other means (e.g. a user-supplied `tweedie(p = ...)` / `student(df = ...)`
#' value); those two pin reasons are combined into one map so a single
#' `tmb_map[[name]] <-` assignment captures both.
#'
#' @param family_mask `logical(n_traits)` from `dispersion_trait_family_mask()`.
#' @param user_pin_mask Optional `logical(n_traits)`, TRUE where the trait
#'   is already pinned to a user-supplied value. Defaults to all FALSE.
#' @return A `factor` map to assign to `tmb_map[[<param>]]`, or `NULL` when
#'   every trait is free and unpinned -- callers should leave `tmb_map`
#'   untouched in that case (TMB's identity default) rather than writing a
#'   no-op map.
#' @keywords internal
#' @noRd
dispersion_trait_map <- function(family_mask, user_pin_mask = NULL) {
  n_traits <- length(family_mask)
  if (is.null(user_pin_mask)) {
    user_pin_mask <- rep(FALSE, n_traits)
  }
  free_mask <- family_mask & !user_pin_mask
  if (all(family_mask) && !any(user_pin_mask)) {
    return(NULL)
  }
  m <- rep(NA_integer_, n_traits)
  m[free_mask] <- seq_len(sum(free_mask))
  factor(m)
}

#' Per-trait starting value for the zero-inflation logit parameter
#'
#' `logit_zi` starting values, one per trait, for the zero-inflated families
#' (fid 17 zi_poisson, 18 zi_nbinom2, 19 zi_binomial; Arc D / Design 62).
#' Method-of-moments: solve the ZI identity
#' \eqn{P(y=0) = \pi + (1-\pi) P_c(0)} for \eqn{\pi} using the OBSERVED
#' proportion of zeros and a naive plug-in count-process zero probability
#' \eqn{P_c(0)} (Poisson: `exp(-mbar)`; NB2: NB(size = 1, mu = mbar) as a
#' phi = 1 naive guess, matching the package's phi starting convention
#' elsewhere; binomial: `(1 - pbar)^Nbar`). Traits with no zi_* row keep a
#' neutral default (`qlogis(0.1)`, never read since the map pins them off).
#' Clamped to `qlogis(c(0.02, 0.8))` per the task brief.
#'
#' @param y Response vector (length n_obs).
#' @param trait_id Zero-based per-row trait index (length n_obs).
#' @param family_id_vec Per-row family id (length n_obs).
#' @param n_trials Per-row trial count (length n_obs); only read for fid 19.
#' @param n_traits Number of traits.
#' @return `numeric(n_traits)`, one starting `logit_zi` value per trait.
#' @keywords internal
#' @noRd
zi_logit_start <- function(y, trait_id, family_id_vec, n_trials, n_traits) {
  out <- rep(stats::qlogis(0.1), n_traits)
  lo <- stats::qlogis(0.02)
  hi <- stats::qlogis(0.8)
  for (t in seq_len(n_traits) - 1L) {
    rows_t <- which(trait_id == t & family_id_vec %in% c(17L, 18L, 19L))
    if (length(rows_t) == 0L) next
    fid_t <- family_id_vec[rows_t[1L]]
    y_t <- y[rows_t]
    p0_obs <- mean(y_t == 0)
    if (fid_t == 19L) {
      Nt <- n_trials[rows_t]
      pbar <- if (sum(Nt) > 0) sum(y_t) / sum(Nt) else 0.5
      p_count_zero <- (1 - pbar)^mean(Nt)
    } else if (fid_t == 18L) {
      mbar <- mean(y_t)
      p_count_zero <- stats::dnbinom(0, size = 1, mu = mbar) # naive phi = 1 guess
    } else {
      mbar <- mean(y_t)
      p_count_zero <- exp(-mbar)
    }
    pi_hat <- (p0_obs - p_count_zero) / max(1 - p_count_zero, 1e-6)
    pi_hat <- min(max(pi_hat, 0.02), 0.8)
    out[t + 1L] <- stats::qlogis(pi_hat)
  }
  pmin(pmax(out, lo), hi)
}
