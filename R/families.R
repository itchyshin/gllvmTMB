# gllvmTMB family constructors are deliberately small data objects. Likelihood
# behaviour belongs to the TMB engine; this file records names, links, and the
# few constructor-specific controls that the engine consumes.

.gllvm_link <- function(expr, value, unquoted, caller) {
  if (is.character(expr)) {
    candidate <- expr
  } else {
    written <- deparse1(expr)
    candidate <- if (written %in% unquoted) written else value
  }
  if (!is.character(candidate) || length(candidate) != 1L || is.na(candidate) ||
      !nzchar(candidate)) {
    cli::cli_abort("{.fn {caller}} requires one link name.")
  }
  tryCatch(
    stats::make.link(candidate),
    error = function(e) {
      cli::cli_abort(c(
        "{.fn {caller}} does not recognise link {.val {candidate}}.",
        "i" = conditionMessage(e)
      ))
    }
  )
}

.gllvm_family <- function(family, expr, value, unquoted, extra = list(),
                          full = TRUE, class = "family") {
  link <- .gllvm_link(expr, value, unquoted, paste0(family, "()"))
  out <- c(list(family = family, link = link$name), extra,
           link[c("linkfun", "linkinv")])
  if (full) {
    out <- c(out, link[c("mu.eta", "valideta", "name")], list(
      aic = function(...) NA_real_,
      initialize = expression({
        mustart <- 0.1 + y
      }),
      dev.resids = function(y, mu, wt) rep.int(0, length(y))
    ))
  }
  structure(out, class = class)
}

.gllvm_probability <- function(x, argument, caller) {
  if (is.null(x)) return(NULL)
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0 || x >= 1) {
    cli::cli_abort(
      "{.fn {caller}} requires {.arg {argument}} to be NULL or one number strictly between 0 and 1."
    )
  }
  as.numeric(x)
}

.gllvm_delta <- function(caller, first, second, family, link, type = NULL,
                         p_extreme = NULL, include_p = FALSE) {
  suffix <- if (identical(type, "poisson_link_delta"))
    ", type = 'poisson-link'" else ""
  out <- list(first, second, delta = TRUE, link = link, family = family)
  if (!is.null(type)) out$type <- type
  if (include_p) out["p_extreme"] <- list(p_extreme)
  out$clean_name <- sprintf(
    "%s(link1 = '%s', link2 = '%s'%s)", caller, link[[1L]], link[[2L]], suffix
  )
  structure(out, class = "family")
}

#' Response-family constructors used by gllvmTMB
#'
#' Build family descriptors for likelihoods that are not supplied directly by
#' [stats::family()]. The descriptor records the family name, link functions,
#' and any fixed shape control consumed by [gllvmTMB()].
#'
#' @param link A single link name. The fitting engine applies the narrower
#'   family-specific link restrictions documented in [gllvmTMB()].
#' @param p_extreme `NULL` to estimate the mixture probability, or one finite
#'   number strictly between zero and one to fix it.
#' @param df `NULL` to estimate Student-t degrees of freedom, or one finite
#'   number greater than one to fix it.
#' @param p `NULL` to estimate the Tweedie power, or one finite number strictly
#'   between one and two to fix it.
#' @param link1 Link for the occurrence component of a delta model.
#' @param link2 Link for the positive component of a delta model.
#' @param type Delta construction: `"standard"` uses a binary occurrence
#'   component, while `"poisson-link"` requests the alternative Poisson-link
#'   parameterisation.
#' @export
#' @rdname families
#' @name Families
#'
#' @return
#' A `family` object. One-part descriptors contain `family`, `link`, `linkfun`,
#' and `linkinv`, plus constructor-specific metadata where applicable. Delta
#' descriptors contain their two component families and `delta = TRUE`.
#'
#' @details
#' These functions construct descriptors; successful construction does not by
#' itself mean that a route is in the dependable release core. Ordinary
#' Gaussian, Poisson, NB2, and binomial Laplace routes have the strongest
#' first-release evidence. Other families and delta, mixture, truncated,
#' ordinal, or mixed-family routes have narrower evidence. Read
#' `vignette("current-limits", package = "gllvmTMB")` before relying on one of
#' those routes.
#'
#' ## Mixed-family input
#'
#' Supply a list of descriptors when response traits use different families.
#' The data column `family` selects an element for each row. Set
#' `attr(families, "family_var")` to select a differently named column. Names on
#' the list are matched to selector levels; an unnamed list is matched by order.
#'
#' Ordinarily the family may vary *between* traits but not *within* one: all
#' rows of a given trait must share one family and link, and a fit that mixes
#' them stops with an error. Poisson-log with binomial-logit, for instance, is
#' not a coherent common scale merely because it converges.
#'
#' ## Integrated multi-source models (experimental)
#'
#' To integrate more than two sources -- a portal stream, digitised
#' literature records, checklists, a structured survey -- declare every
#' source and its observation law with [isdm_sources()]. The two-source
#' contract below is the two-source case of the same rule and keeps working
#' unchanged.
#'
#' ## Integrated two-source models (experimental)
#'
#' There is one admitted exception, for combining opportunistic
#' presence-only records with a structured detection/non-detection survey of
#' the same species. Here the family genuinely does vary within a trait: the
#' portal rows are Poisson-log counts and the survey rows are Bernoulli with
#' a complementary log-log link, which is what makes both arms consistent with
#' one shared underlying intensity. Poisson and Bernoulli carry no dispersion
#' parameter, so nothing per-trait becomes ambiguous.
#'
#' To reach it, the fit must match this contract exactly:
#'
#' * `family = list(gbif = poisson(), survey_pa = binomial("cloglog"))`,
#'   with `attr(family, "family_var") <- "isdm_family"`;
#' * a `source` column holding only `"gbif"` and `"survey"`, with both present;
#' * an `isdm_family` column equal to `"gbif"` on portal rows and
#'   `"survey_pa"` on survey rows.
#'
#' Within that contract an `offset()` is admitted on the cloglog arm, where it
#' is a known change-of-support (sampled area or visit effort) rather than an
#' ordinary log-rate exposure. Anything short of the full contract keeps the
#' ordinary one-family-per-trait refusal.
#'
#' Everything such a fit reports is **relative intensity**. Presence-only data
#' cannot identify absolute abundance, occupancy, or detectability, so those
#' quantities are not estimated and must not be read off the output. This
#' interface is experimental and may change.
#'
#' ## Delta defaults and compatibility wrappers
#'
#' When `link1` is omitted, standard delta constructors use `"logit"` and
#' Poisson-link constructors use `"log"`. The older
#' `delta_poisson_link_gamma()` and `delta_poisson_link_lognormal()` names remain
#' as deprecated wrappers.
#'
#' @examples
#' Beta(link = "logit")
#' \dontrun{
#' ## Mixed-family example: per-row family chosen by a `family` column
#' sim <- simulate_site_trait(n_sites = 40, n_species = 10, n_traits = 2,
#'                            mean_species_per_site = 5)
#' sim$data$family <- factor(
#'   ifelse(sim$data$trait == levels(sim$data$trait)[1], "gaussian", "binomial"),
#'   levels = c("gaussian", "binomial")
#' )
#' fam <- list(gaussian(), binomial())
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 1),
#'   data   = sim$data,
#'   family = fam,
#'   trait  = "trait",
#'   unit   = "site"
#' )
#'
#' ## Integrated two-source model: portal counts + survey detections, one
#' ## shared ecological predictor. `dat` is long, one row per
#' ## (cell, species, source); `log_support` is log sampled area or effort.
#' dat$isdm_family <- factor(
#'   ifelse(dat$source == "gbif", "gbif", "survey_pa"),
#'   levels = c("gbif", "survey_pa")
#' )
#' isdm_fam <- list(gbif = poisson(), survey_pa = binomial(link = "cloglog"))
#' attr(isdm_fam, "family_var") <- "isdm_family"
#' fit_isdm <- gllvmTMB(
#'   value ~ 0 + trait + trait:env + trait:isdm_gbif + trait:bias +
#'     offset(log_support) + latent(0 + trait | cell_id, d = 1),
#'   data   = dat,
#'   family = isdm_fam,
#'   trait  = "trait",
#'   unit   = "cell_id"
#' )
#' }
Beta <- function(link = "logit") {
  .gllvm_family("Beta", substitute(link), link, "logit")
}

#' @export
#' @rdname families
#' @examples
#' lognormal(link = "log")
lognormal <- function(link = "log") {
  .gllvm_family("lognormal", substitute(link), link,
                c("identity", "log", "inverse"))
}

#' @keywords internal
#' @export
#' @rdname families
#' @details
#' `gengamma()` uses the Prentice parameterisation. Its fitted `gengamma_Q`
#' value controls shape; the limiting case at zero is lognormal.
#'
#' @references
#'
#' Prentice, R.L. 1974. A log gamma model and its maximum likelihood estimation.
#' Biometrika 61(3): 539–544. \doi{10.1093/biomet/61.3.539}
#'
#' @details Several constructors remain exported for compatibility although the
#' current multivariate fitter rejects them. In particular, this applies to
#' generalized-gamma, mixture, censored Poisson, truncated NB1, and most delta
#' variants. A rejected constructor is not silently mapped to another family.

gengamma <- function(link = "log") {
  .gllvm_family("gengamma", substitute(link), link,
                c("identity", "log", "inverse"))
}

#' @details Names ending in `_mix()` describe two mean components that share a
#' scale parameter. `p_extreme` is the probability assigned to the component
#' with the larger mean; leave it `NULL` to estimate that probability.
#' @references
#'
#' Thorson, J.T., Stewart, I.J., and Punt, A.E. 2011. Accounting for fish shoals
#' in single- and multi-species survey data using mixture distribution models.
#' Can. J. Fish. Aquat. Sci. 68(9): 1681–1693. \doi{10.1139/f2011-086}.

#' @export
#' @rdname families
#' @examples
#' gamma_mix(link = "log")
gamma_mix <- function(link = "log", p_extreme = NULL) {
  p_extreme <- .gllvm_probability(p_extreme, "p_extreme", "gamma_mix()")
  .gllvm_family("gamma_mix", substitute(link), link,
                c("identity", "log", "inverse"), list(p_extreme = p_extreme))
}

#' @export
#' @rdname families
#' @examples
#' lognormal_mix(link = "log")
lognormal_mix <- function(link = "log", p_extreme = NULL) {
  p_extreme <- .gllvm_probability(p_extreme, "p_extreme", "lognormal_mix()")
  .gllvm_family("lognormal_mix", substitute(link), link,
                c("identity", "log", "inverse"), list(p_extreme = p_extreme))
}

#' @export
#' @rdname families
#' @examples
#' nbinom2_mix(link = "log")
nbinom2_mix <- function(link = "log", p_extreme = NULL) {
  p_extreme <- .gllvm_probability(p_extreme, "p_extreme", "nbinom2_mix()")
  .gllvm_family("nbinom2_mix", substitute(link), link,
                c("identity", "log", "inverse"), list(p_extreme = p_extreme))
}

#' @details
#' NB2 has variance \eqn{\mu + \mu^2 / \phi}; its extra variance therefore grows
#' quadratically with the mean.
#' @references
#'
#' Hilbe, J. M. 2011. Negative binomial regression. Cambridge University Press.
#' @export
#' @examples
#' nbinom2(link = "log")
#' @rdname families
nbinom2 <- function(link = "log") {
  .gllvm_family("nbinom2", substitute(link), link, "log")
}

#' @details
#' NB1 has variance \eqn{\mu(1 + \phi)}, so its extra variance grows linearly
#' with the mean.
#' @export
#' @examples
#' nbinom1(link = "log")
#' @rdname families
nbinom1 <- function(link = "log") {
  .gllvm_family("nbinom1", substitute(link), link, "log")
}

utils::globalVariables(".phi") ## avoid R CMD check NOTE

#' @export
#' @examples
#' truncated_poisson(link = "log")
#' @rdname families
truncated_poisson <- function(link = "log") {
  out <- .gllvm_family("truncated_poisson", substitute(link), link, "log",
                       full = FALSE)
  out$linkinv <- function(eta) {
    mu <- exp(eta)
    mu / (-expm1(-mu))
  }
  out
}

#' @export
#' @examples
#' truncated_nbinom2(link = "log")
#' @rdname families
truncated_nbinom2 <- function(link = "log") {
  out <- .gllvm_family("truncated_nbinom2", substitute(link), link, "log",
                       full = FALSE)
  out$linkinv <- function(eta, phi = NULL) {
    if (is.null(phi)) phi <- .phi
    mu <- exp(eta)
    log_p_zero <- -phi * log1p(mu / phi)
    mu / (-expm1(log_p_zero))
  }
  out
}

#' @export
#' @examples
#' truncated_nbinom1(link = "log")
#' @rdname families
truncated_nbinom1 <- function(link = "log") {
  out <- .gllvm_family("truncated_nbinom1", substitute(link), link, "log",
                       full = FALSE)
  out$linkinv <- function(eta, phi = NULL) {
    if (is.null(phi)) phi <- .phi
    mu <- exp(eta)
    log_p_zero <- -(mu / phi) * log1p(phi)
    mu / (-expm1(log_p_zero))
  }
  out
}

#' @export
#' @details
#' `student()` estimates degrees of freedom unless `df` is supplied.
#' @rdname families
#' @examples
#' student(link = "identity") # estimate df
#' student(link = "identity", df = 3) # fix df at 3
student <- function(link = "identity", df = NULL) {
  if (!is.null(df) &&
      (!is.numeric(df) || length(df) != 1L || !is.finite(df) || df <= 1)) {
    cli::cli_abort(
      "student(): {.code df} must be one finite number greater than 1 (got {df})."
    )
  }

  if (is.null(df)) {
    cli::cli_inform("Student-t degrees of freedom parameter will be estimated. This used to be fixed at 3 by default. To fix it, supply a value to `df` (e.g., `df = 3`).")
  } else {
    cli::cli_inform("Student-t degrees of freedom parameter fixed at {df}. To estimate it, set `df = NULL`.")
  }

  .gllvm_family("student", substitute(link), link,
                c("identity", "log", "inverse"), list(df = df))
}

#' @export
#' @examples
#' tweedie(link = "log")
#' @rdname families
tweedie <- function(link = "log", p = NULL) {
  if (!is.null(p) &&
      (!is.numeric(p) || length(p) != 1L || !is.finite(p) || p <= 1 || p >= 2)) {
    cli::cli_abort(
      "tweedie(): {.code p} (the power) must be a single number strictly between 1 and 2 (got {p})."
    )
  }
  .gllvm_family("tweedie", substitute(link), link, c("log", "identity"),
                list(p = p))
}

#' @export
#' @examples
#' censored_poisson(link = "log")
#' @rdname families
censored_poisson <- function(link = "log") {
  .gllvm_family("censored_poisson", substitute(link), link, "log", full = FALSE)
}

#' @export
#' @importFrom stats Gamma binomial
#' @examples
#' delta_gamma()
#' @rdname families
#' @references
#' Thorson, J.T. 2018. Three problems with the conventional delta-model for
#' biomass sampling data, and a computationally efficient alternative. Canadian
#' Journal of Fisheries and Aquatic Sciences, 75(9), 1369-1382.
#' \doi{10.1139/cjfas-2017-0266}

delta_gamma <- function(link1,
  link2 = "log", type = c("standard", "poisson-link")) {
  type <- match.arg(type)
  l1 <- if (missing(link1)) if (type == "standard") "logit" else "log" else
    .gllvm_link(substitute(link1), link1,
                c("logit", "probit", "cloglog", "cauchit", "log"),
                "delta_gamma()")$name
  l2 <- .gllvm_link(substitute(link2), link2,
                    c("identity", "log", "inverse"), "delta_gamma()")$name
  .gllvm_delta(
    "delta_gamma", stats::binomial(link = l1), stats::Gamma(link = l2),
    c("binomial", "Gamma"), c(l1, l2),
    if (type == "standard") "standard" else "poisson_link_delta"
  )
}

#' @export
#' @examples
#' delta_gamma_mix()
#' @rdname families
delta_gamma_mix <- function(link1 = "logit", link2 = "log", p_extreme = NULL) {
  l1 <- .gllvm_link(substitute(link1), link1,
                    c("logit", "probit", "cloglog", "cauchit"),
                    "delta_gamma_mix()")$name
  l2 <- .gllvm_link(substitute(link2), link2,
                    c("identity", "log", "inverse"),
                    "delta_gamma_mix()")$name
  p_extreme <- .gllvm_probability(p_extreme, "p_extreme", "delta_gamma_mix()")
  .gllvm_delta(
    "delta_gamma_mix", stats::binomial(link = l1),
    gamma_mix(link = l2), c("binomial", "gamma_mix"), c(l1, l2),
    p_extreme = p_extreme, include_p = TRUE
  )
}

#' @export
#' @examples
#' delta_gengamma()
#' @rdname families
delta_gengamma <- function(link1,
  link2 = "log", type = c("standard", "poisson-link")) {
  type <- match.arg(type)
  l1 <- if (missing(link1)) if (type == "standard") "logit" else "log" else
    .gllvm_link(substitute(link1), link1,
                c("logit", "probit", "cloglog", "cauchit", "log"),
                "delta_gengamma()")$name
  l2 <- .gllvm_link(substitute(link2), link2,
                    c("identity", "log", "inverse"), "delta_gengamma()")$name
  .gllvm_delta(
    "delta_gengamma", stats::binomial(link = l1), gengamma(link = l2),
    c("binomial", "gengamma"), c(l1, l2),
    if (type == "standard") "standard" else "poisson_link_delta"
  )
}

#' @export
#' @examples
#' delta_lognormal()
#' @rdname families
delta_lognormal <- function(link1,
  link2 = "log", type = c("standard", "poisson-link")) {
  type <- match.arg(type)
  l1 <- if (missing(link1)) if (type == "standard") "logit" else "log" else
    .gllvm_link(substitute(link1), link1,
                c("logit", "probit", "cloglog", "cauchit", "log"),
                "delta_lognormal()")$name
  l2 <- .gllvm_link(substitute(link2), link2,
                    c("identity", "log", "inverse"), "delta_lognormal()")$name
  .gllvm_delta(
    "delta_lognormal", stats::binomial(link = l1), lognormal(link = l2),
    c("binomial", "lognormal"), c(l1, l2),
    if (type == "standard") "standard" else "poisson_link_delta"
  )
}

#' @export
#' @examples
#' delta_lognormal_mix()
#' @rdname families
delta_lognormal_mix <- function(link1, link2 = "log", type = c("standard", "poisson-link"), p_extreme = NULL) {
  type <- match.arg(type)
  l1 <- if (missing(link1)) if (type == "standard") "logit" else "log" else
    .gllvm_link(substitute(link1), link1,
                c("logit", "probit", "cloglog", "cauchit", "log"),
                "delta_lognormal_mix()")$name
  l2 <- .gllvm_link(substitute(link2), link2,
                    c("identity", "log", "inverse"),
                    "delta_lognormal_mix()")$name
  p_extreme <- .gllvm_probability(
    p_extreme, "p_extreme", "delta_lognormal_mix()"
  )
  .gllvm_delta(
    "delta_lognormal_mix", stats::binomial(link = l1), lognormal(link = l2),
    c("binomial", "lognormal_mix"), c(l1, l2),
    if (type == "standard") "standard" else "poisson_link_delta",
    p_extreme, TRUE
  )
}

#' @export
#' @examples
#' delta_truncated_nbinom2()
#' @rdname families
delta_truncated_nbinom2 <- function(link1 = "logit", link2 = "log") {
  l1 <- .gllvm_link(substitute(link1), link1,
                    c("logit", "probit", "cloglog", "cauchit"),
                    "delta_truncated_nbinom2()")$name
  l2 <- .gllvm_link(substitute(link2), link2, "log",
                    "delta_truncated_nbinom2()")$name
  .gllvm_delta(
    "delta_truncated_nbinom2", stats::binomial(link = l1),
    truncated_nbinom2(link = l2), c("binomial", "truncated_nbinom2"),
    c(l1, l2)
  )
}

#' @export
#' @examples
#' delta_truncated_nbinom1()
#' @rdname families
delta_truncated_nbinom1 <- function(link1 = "logit", link2 = "log") {
  l1 <- .gllvm_link(substitute(link1), link1,
                    c("logit", "probit", "cloglog", "cauchit"),
                    "delta_truncated_nbinom1()")$name
  l2 <- .gllvm_link(substitute(link2), link2, "log",
                    "delta_truncated_nbinom1()")$name
  .gllvm_delta(
    "delta_truncated_nbinom1", stats::binomial(link = l1),
    truncated_nbinom1(link = l2), c("binomial", "truncated_nbinom1"),
    c(l1, l2)
  )
}

#' @rdname families
#' @export
#' @keywords internal
delta_poisson_link_gamma <- function(link1 = "log", link2 = "log") {
  if (!identical(link1, "log") || !identical(link2, "log")) {
    cli::cli_abort("The deprecated Poisson-link wrapper accepts only log links.")
  }
  lifecycle::deprecate_warn("0.4.2.9000", "delta_poisson_link_gamma()", "delta_gamma(type)")
  delta_gamma(link1 = "logit", link2 = "log", type = "poisson-link")
}

#' @rdname families
#' @export
#' @keywords internal
delta_poisson_link_lognormal <- function(link1 = "log", link2 = "log") {
  if (!identical(link1, "log") || !identical(link2, "log")) {
    cli::cli_abort("The deprecated Poisson-link wrapper accepts only log links.")
  }
  lifecycle::deprecate_warn("0.4.2.9000", "delta_poisson_link_lognormal()", "delta_lognormal(type)")
  delta_lognormal(link1 = "logit", link2 = "log", type = "poisson-link")
}

#' @export
#' @examples
#' betabinomial(link = "logit")
#' @rdname families
betabinomial <- function(link = "logit") {
  link_name <- .gllvm_link(substitute(link), link, c("logit", "cloglog"),
                           "betabinomial()")$name
  if (!link_name %in% c("logit", "cloglog")) {
    cli::cli_abort(c(
      "{.fn betabinomial} supports only logit and cloglog links.",
      "i" = "Received {.val {link_name}}."
    ))
  }
  .gllvm_family("betabinomial", link_name, link_name,
                c("logit", "cloglog"))
}


#' @export
#' @examples
#' delta_beta()
#' @rdname families
delta_beta <- function(link1 = "logit", link2 = "logit") {
  l1 <- .gllvm_link(substitute(link1), link1,
                    c("logit", "probit", "cloglog", "cauchit"),
                    "delta_beta()")$name
  l2 <- .gllvm_link(substitute(link2), link2, "logit", "delta_beta()")$name
  .gllvm_delta(
    "delta_beta", stats::binomial(link = l1), Beta(link = l2),
    c("binomial", "Beta"), c(l1, l2)
  )
}

#' Ordinal-probit threshold family for the multivariate engine
#'
#' The Wright/Falconer/Dempster-Lerner threshold model for K-category
#' ordinal data with K >= 3, fitted on the latent (probit) scale. The
#' latent variable representation is \eqn{y^* = \eta + \varepsilon},
#' with \eqn{\varepsilon \sim N(0, 1)} and the observed category
#' \eqn{y = k} iff \eqn{\tau_{k-1} < y^* \le \tau_k}, using cutpoints
#' \eqn{\tau_0 = -\infty}, \eqn{\tau_1 = 0} (fixed for identifiability),
#' \eqn{\tau_2, \ldots, \tau_{K-1}}, \eqn{\tau_K = +\infty}. A
#' K-category trait therefore estimates K - 2 free cutpoints.
#'
#' Because \eqn{\varepsilon} has unit variance by construction, the
#' link-residual variance \eqn{\sigma^2_d = 1} *exactly* (no trigamma
#' correction needed). This fixes the ordinal liability scale; it does not make
#' an ordinal response directly comparable with an observed continuous response
#' without an explicit scale definition. In the special two-component model
#' containing only phylogenetic variance plus the unit probit residual, the
#' liability-scale ratio is
#' \eqn{H^2 = \sigma^2_{\text{phy}} / (\sigma^2_{\text{phy}} + 1)}.
#' Any additional fitted variance component belongs in the denominator, so do
#' not use that shortcut for richer models.
#'
#' Hadfield (2015) eqn 10 shows that the K = 2 case reduces exactly to
#' `binomial(link = "probit")`, so use `binomial()` for binary outcomes
#' and `ordinal_probit()` for K >= 3.
#'
#' Convention: the engine follows Hadfield's notation (\eqn{\tau_1 = 0}
#' fixed, K - 2 free cutpoints reported as `cutpoint_2`, ...,
#' `cutpoint_{K-1}`). This differs from `brms::cumulative()`, which
#' reports K - 1 cutpoints as `Intercept[1..K-1]`.
#'
#' Cross-engine note: `gllvmTMB`'s `ordinal_probit()` is a probit
#' threshold model (unit latent variance; Hadfield 2015), whereas
#' `GLLVM.jl`'s ordinal family is a cumulative-*logit* model. Cutpoints
#' and loadings therefore live on different link scales (differing by a
#' factor of roughly \eqn{\pi / \sqrt{3}}) and must not be compared
#' across engines at machine tolerance; the `engine = "julia"` bridge
#' maps probit to probit and does not route a logit ordinal response.
#'
#' @param link Always `"probit"`; provided for API symmetry with the
#'   other family constructors.
#'
#' @return A family object with class `c("ordinal_probit", "family")`.
#'   The cutpoints are estimated as part of the model fit; recover them
#'   with [extract_cutpoints()].
#'
#' @references
#' Dempster, E. R. and Lerner, I. M. (1950). Heritability of threshold
#'   characters. *Genetics* 35:212-236.
#'
#' Falconer, D. S. and Mackay, T. F. C. (1996). *Introduction to
#'   Quantitative Genetics*, 4th ed. Longman.
#'
#' Felsenstein, J. (2005). Using the quantitative genetic threshold
#'   model for inferences between and within species. *Phil. Trans. R.
#'   Soc. B* 360:1427-1434.
#'
#' Felsenstein, J. (2012). A comparative method for both discrete and
#'   continuous characters using the threshold model. *Am. Nat.*
#'   179:145-156.
#'
#' Hadfield, J. D. (2015). Increasing the efficiency of MCMC for
#'   hierarchical phylogenetic models of categorical traits using
#'   reduced mixed models. *Methods Ecol. Evol.* 6:706-714.
#'   \doi{10.1111/2041-210X.12354}
#'
#' Mizuno, A. *et al.* (2025). Phylogenetic comparative methods for
#'   threshold traits. *J. Evol. Biol.* 38(12):1699-1712.
#'
#' @seealso [extract_cutpoints()] to recover \eqn{\tau_2, \ldots,
#'   \tau_{K-1}} after fitting.
#'
#' @export
#' @examples
#' ordinal_probit()
ordinal_probit <- function(link = "probit") {
  link_name <- .gllvm_link(substitute(link), link, "probit",
                           "ordinal_probit()")$name
  if (!identical(link_name, "probit")) {
    cli::cli_abort("{.fn ordinal_probit} supports only the probit link.")
  }
  .gllvm_family("ordinal_probit", "probit", "probit", "probit",
                full = FALSE, class = c("ordinal_probit", "family"))
}

#' Multinomial (baseline-category logit) family
#'
#' Baseline-category logit / softmax family for a single \strong{unordered}
#' categorical response with \eqn{K \ge 3} categories. For a categorical trait
#' with categories \eqn{1, \ldots, K} and reference category 1, the model is
#' \eqn{\eta_{k} = \beta_{0k} + x^\top \beta_k} for \eqn{k = 2, \ldots, K} with
#' \eqn{\eta_1 \equiv 0}, and
#' \eqn{\Pr(y = k) = \exp(\eta_k) / \sum_j \exp(\eta_j)} (softmax). It recovers
#' the \eqn{(K-1)} per-category intercepts and slopes as contrasts against the
#' reference category.
#'
#' @details
#' This is a \strong{response} family and must not be confused with the
#' \code{\link{categorical}()} constructor, which is a missing-\emph{predictor}
#' imputation family. Because an unordered categorical response spans
#' \eqn{K-1} latent liability dimensions rather than one, the admitted
#' structured-term surface is narrow: fixed effects always; an ordinary
#' shared \code{latent(0 + trait | unit, d = k)} ordination, which connects
#' a multinomial trait to other-family traits through its \eqn{K-1}
#' contrast pseudo-traits (the default \code{unique = TRUE} works, with the
#' categorical contrast \eqn{\Psi} mapped off); and \code{phylo_latent()}
#' for the among-category phylogenetic surface. Every other structured /
#' random-effect keyword -- \code{dep()}, explicit \code{unique()} /
#' \code{indep()}, \code{phylo_dep()} / \code{phylo_indep()} /
#' \code{phylo_unique()}, \code{phylo_scalar()}, \code{animal_*()},
#' \code{kernel_*()}, \code{spatial_*()}, the \code{cluster} /
#' \code{cluster2} / \code{unit_obs} grouping tiers, generic
#' \code{(1 | group)} random intercepts, and \code{mi()} predictor terms --
#' is deferred and fails loud (\code{R/multinomial-fence.R}) rather than
#' reaching an untested categorical path.
#' A two-category response is exactly \code{binomial(link = "logit")} and is
#' redirected there. See also \code{\link{ordinal_probit}()} for \emph{ordered}
#' categories.
#'
#' @param link Character; only the baseline-category \code{"logit"} link is
#'   supported (present for API symmetry).
#' @param baseline Optional reference category (level of the response factor)
#'   pinned at \eqn{\eta = 0}. \code{NULL} (default) uses the first factor level.
#'
#' @return A family object with class \code{c("multinomial", "family")}.
#' @seealso [ordinal_probit()] for ordered categories; [categorical()] for the
#'   missing-predictor imputation namesake.
#' @export
#' @examples
#' multinomial()
multinomial <- function(link = "logit", baseline = NULL) {
  link_name <- .gllvm_link(substitute(link), link, "logit", "multinomial()")$name
  if (!identical(link_name, "logit")) {
    cli::cli_abort("{.fn multinomial} supports only the baseline-category logit link.")
  }
  if (!is.null(baseline) && (length(baseline) != 1L || is.na(baseline))) {
    cli::cli_abort("{.fn multinomial} requires {.arg baseline} to be NULL or one category value.")
  }
  out <- .gllvm_family(
    "multinomial", "logit", "logit", "logit", full = FALSE,
    class = c("multinomial", "family")
  )
  out["baseline"] <- list(baseline)
  out
}
