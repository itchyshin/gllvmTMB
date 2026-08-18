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
