## Arc O5 (issue #1242, vault D-210): chi-bar-square boundary inference.
##
## When a variance-type parameter (a random-effect variance, or -- as used
## by anova.gllvmTMB_multi()'s rank/dimension test in R/aghq-report.R -- the
## norm of a newly added latent-loading column) is tested against 0, that
## null sits on the BOUNDARY of the parameter space, not its interior. The
## naive likelihood-ratio reference chi-square_q (Wilks) is then WRONG --
## specifically CONSERVATIVE (it OVERSTATES the true p-value, i.e. understates
## the evidence) -- because it ignores the positive probability mass the null
## places exactly ON the boundary (chi-square_q has zero density there).
## Concretely, for q = 1 the correct reference is exactly HALF of the naive
## chi-square_1 tail probability (chibar2_pvalue(LRT, 1) == 0.5 *
## pchisq(LRT, 1, lower.tail = FALSE)): the naive test is twice as
## conservative as it should be. This is the well-established direction in
## the mixed-model literature (e.g. the classic advice to halve a chi-square_1
## p-value when testing a single random-effect variance) -- NOT the reverse.
## Self & Liang (1987) and Stram & Lee (1994) give the correct
## reference for q INDEPENDENT boundary variance components: a mixture
## ("chi-bar-square", written chi-bar^2_q) of ordinary chi-square_j
## distributions, j = 0, ..., q, weighted by the binomial coefficients
## C(q, j) * 2^-q -- the probability that exactly j of the q components are
## active at the constrained MLE when the true covariance among their score
## statistics is the identity (mutual independence).
##
## Ported from GLLVM.jl `src/boundary_inference.jl` (`chibar2_pvalue()`,
## `variance_lrt()`), which documents the identical formula and identical
## scope note. This file is a direct, faithful port -- the SAME closed-form
## weights, not a reinterpretation -- because the weights themselves are a
## fixed piece of 1987/1994 theory that does not depend on which package
## calls it. What gllvmTMB adds beyond the port is `anova.gllvmTMB_multi()`
## (R/aghq-report.R), which decides *when* this formula's assumptions
## (independence of the q boundary components; regular Fisher information in
## the rest of the model) are or are not defensible for a given pair of
## gllvmTMB fits, and REFUSES to print a p-value when they are not --
## see that function's documentation for the reasoning, in particular why a
## latent-RANK step of more than one new dimension is refused outright.

#' Chi-bar-square p-value for a boundary likelihood-ratio test
#'
#' @description
#' p-value of a likelihood-ratio statistic `LRT = 2 * (ll_full - ll_reduced)`
#' for the null hypothesis that `q` variance-type parameters are
#' simultaneously at the boundary of their parameter space (typically 0),
#' when those `q` components are asymptotically INDEPENDENT of each other and
#' of the remaining (regular, interior) parameters. This is the Self & Liang
#' (1987) / Stram & Lee (1994) chi-bar-square mixture
#' \deqn{p = \sum_{j=1}^{q} \binom{q}{j} 2^{-q} \, P(\chi^2_j \ge \mathrm{LRT})}
#' (the `j = 0` atom, a point mass at `LRT = 0`, contributes nothing once
#' `LRT > 0`). For `q = 1` this is the familiar
#' `0.5 * P(chi^2_1 >= LRT)` -- half the naive chi-square_1 p-value, because
#' half of the mixture's probability mass sits at the boundary atom.
#'
#' **This formula assumes the `q` boundary components are mutually
#' independent** (their asymptotic score covariance is diagonal) and that the
#' rest of the model's Fisher information is regular (non-singular) at the
#' null. Neither assumption is checked by this function -- it computes the
#' formula exactly as specified. The caller (in gllvmTMB,
#' [anova.gllvmTMB_multi()]) is responsible for deciding whether those
#' assumptions are defensible for the comparison at hand, and for refusing to
#' call this function (rather than calling it and reporting a wrong p-value)
#' when they are not. See `anova.gllvmTMB_multi()`'s documentation for the
#' specific case gllvmTMB refuses: a latent-rank ("number of factors") test
#' spanning more than one new loading column, where the added parameters are
#' not simple independent scalar variances and the correct reference
#' distribution is not known in closed form.
#'
#' @param LRT A single numeric likelihood-ratio statistic,
#'   `2 * (ll_full - ll_reduced)`. Values `<= 0` return a p-value of 1
#'   (no evidence against the reduced model).
#' @param q A single positive integer: the number of boundary variance
#'   components tested against 0.
#'
#' @return A single numeric p-value in `[0, 1]`.
#'
#' @references
#' Self, S. G. and Liang, K.-Y. (1987). Asymptotic properties of maximum
#' likelihood estimators and likelihood ratio tests under nonstandard
#' conditions. *Journal of the American Statistical Association*, 82(398),
#' 605-610.
#'
#' Stram, D. O. and Lee, J. W. (1994). Variance components testing in the
#' longitudinal mixed effects model. *Biometrics*, 50(4), 1171-1177.
#'
#' @seealso [variance_lrt()], [anova.gllvmTMB_multi()], [select_lv()]
#'
#' @examples
#' # q = 1: the familiar half-chi-square-1 boundary test.
#' chibar2_pvalue(LRT = 3.84, q = 1)
#' # A large-df example (independent boundary components only).
#' chibar2_pvalue(LRT = 12, q = 3)
#'
#' @export
chibar2_pvalue <- function(LRT, q) {
  if (!is.numeric(q) || length(q) != 1L || is.na(q) ||
      q != as.integer(q) || q < 1L) {
    cli::cli_abort(
      "{.arg q} (number of boundary variance components) must be a single integer >= 1; got {q}.",
      class = "gllvmTMB_chibar2_bad_q"
    )
  }
  if (!is.numeric(LRT) || length(LRT) != 1L || is.na(LRT)) {
    cli::cli_abort(
      "{.arg LRT} must be a single, non-missing numeric value.",
      class = "gllvmTMB_chibar2_bad_LRT"
    )
  }
  if (LRT <= 0) {
    return(1.0)
  }
  q <- as.integer(q)
  j <- seq_len(q)
  sum(choose(q, j) * 2^(-q) * stats::pchisq(LRT, df = j, lower.tail = FALSE))
}

#' Boundary likelihood-ratio test for one or more variance components
#'
#' @description
#' Likelihood-ratio test that `n_boundary` variance-type components are
#' jointly 0, from the two maximised log-likelihoods of a full model and a
#' reduced model with those components fixed at 0. Wraps
#' [chibar2_pvalue()]; see that function for the exact formula and its scope
#' (independent boundary components, regular Fisher information elsewhere).
#'
#' @param ll_full,ll_reduced Single numeric maximised log-likelihoods for the
#'   full and reduced models.
#' @param n_boundary A single positive integer: the number of boundary
#'   variance components being tested. Default `1L`.
#'
#' @return A list with elements `LRT`, `pvalue` (from [chibar2_pvalue()]),
#'   and `n_boundary`.
#'
#' @seealso [chibar2_pvalue()], [anova.gllvmTMB_multi()]
#'
#' @examples
#' variance_lrt(ll_full = -100.2, ll_reduced = -102.1, n_boundary = 1)
#'
#' @export
variance_lrt <- function(ll_full, ll_reduced, n_boundary = 1L) {
  if (!is.numeric(ll_full) || length(ll_full) != 1L || is.na(ll_full) ||
      !is.numeric(ll_reduced) || length(ll_reduced) != 1L || is.na(ll_reduced)) {
    cli::cli_abort(
      "{.arg ll_full} and {.arg ll_reduced} must each be a single, non-missing numeric value.",
      class = "gllvmTMB_variance_lrt_bad_loglik"
    )
  }
  LRT <- 2 * (ll_full - ll_reduced)
  list(
    LRT = LRT,
    pvalue = chibar2_pvalue(LRT, n_boundary),
    n_boundary = as.integer(n_boundary)
  )
}
