# modified from glmmTMB
# extra stuff for Effects package, class, etc.
add_to_family <- function(x) {
  # x <- c(x, list(link = link), make.link(link))
  # Effect.default/glm.fit
  if (is.null(x$aic)) {
    x <- c(x, list(aic = function(...) NA_real_))
  }
  if (is.null(x$initialize)) {
    x <- c(x, list(initialize = expression({
      mustart <- y + 0.1
    })))
  }
  if (is.null(x$dev.resids)) {
    # can't return NA, glm.fit is unhappy
    x <- c(x, list(dev.resids = function(y, mu, wt) {
      rep(0, length(y))
    }))
  }
  class(x) <- "family"
  x
}

#' Additional families
#'
#' Additional families compatible with [gllvmTMB()].
#'
#' @param link Link.
#' @export
#' @rdname families
#' @name Families
#'
#' @return
#' A list with elements common to standard R family objects including `family`,
#' `link`, `linkfun`, and `linkinv`. Delta/hurdle model families also have
#' elements `delta` (logical) and `type` (standard vs. Poisson-link).
#'
#' @details
#' The default `link1` for delta models of `type = "standard"` is `"logit"`.
#' The default `link1` for delta models of `type = "poisson-link"` is `"log"`.
#'
#' `delta_poisson_link_gamma()` and `delta_poisson_link_lognormal()` have been
#' deprecated in favour of `delta_gamma(type = "poisson-link")` and
#' `delta_lognormal(type = "poisson-link")`.
#'
#' @examples
#' Beta(link = "logit")
Beta <- function(link = "logit") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("logit")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }
  x <- c(list(family = "Beta", link = linktemp), stats)
  add_to_family(x)
}

#' @export
#' @rdname families
#' @examples
#' lognormal(link = "log")
lognormal <- function(link = "log") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("identity", "log", "inverse")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }
  x <- c(list(family = "lognormal", link = linktemp), stats)
  add_to_family(x)
}

#' @keywords internal
#' @export
#' @rdname families
#' @details
#' The `gengamma()` family was implemented by J.T. Thorson and uses the Prentice
#' (1974) parameterization such that the lognormal occurs as the internal
#' parameter `gengamma_Q` (reported in `print()` or `summary()` as
#' "Generalized gamma Q") approaches 0. If Q matches `phi` the distribution
#' should be the gamma.
#'
#' @references
#'
#' *Generalized gamma family*:
#'
#' Prentice, R.L. 1974. A log gamma model and its maximum likelihood estimation.
#' Biometrika 61(3): 539–544. \doi{10.1093/biomet/61.3.539}
#'
#' Stacy, E.W. 1962. A Generalization of the Gamma Distribution. The Annals of
#' Mathematical Statistics 33(3): 1187–1192. Institute of Mathematical
#' Statistics.
#'
#' Dunic, J.C., Conner, J., Anderson, S.C., and Thorson, J.T. 2025. The
#' generalized gamma is a flexible distribution that outperforms alternatives
#' when modelling catch rate data. ICES Journal of Marine Science 82(4):
#' fsaf040. \doi{10.1093/icesjms/fsaf040}.

gengamma <- function(link = "log") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("identity", "log", "inverse")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }
  x <- c(list(family = "gengamma", link = linktemp), stats)
  add_to_family(x)
}

#' @details The families ending in `_mix()` are 2-component mixtures where each
#'   distribution has its own mean but a shared scale parameter.
#'   (Thorson et al. 2011). See the model-description vignette for details.
#'   The parameter `p_extreme = plogis(logit_p_extreme)` is the probability of the extreme (larger)
#'   mean and `exp(log_ratio_mix) + 1` is the ratio of the larger extreme
#'   mean to the "regular" mean. You can see these parameters in
#'   `model$sd_report`. The parameter `p_extreme` can be fixed a priori and passed
#'   in as a proportion for these families.
#' @references
#'
#' *Families ending in `_mix()`*:
#'
#' Thorson, J.T., Stewart, I.J., and Punt, A.E. 2011. Accounting for fish shoals
#' in single- and multi-species survey data using mixture distribution models.
#' Can. J. Fish. Aquat. Sci. 68(9): 1681–1693. \doi{10.1139/f2011-086}.

#' @param p_extreme Optional fixed probability for the extreme component. If NULL (default),
#'   this is estimated. If specified, must be a proportion between 0 and 1.
#' @export
#' @rdname families
#' @examples
#' gamma_mix(link = "log")
gamma_mix <- function(link = "log", p_extreme = NULL) {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("identity", "log", "inverse")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }

  if (!is.null(p_extreme)) {
    if (!is.numeric(p_extreme) || p_extreme <= 0 || p_extreme >= 1) {
      stop("p_extreme must be NULL or a proportion between 0 and 1")
    }
  }

  x <- c(list(family = "gamma_mix", link = linktemp, p_extreme = p_extreme), stats)
  add_to_family(x)
}

#' @param p_extreme Optional fixed probability for the extreme component. If NULL (default),
#'   this is estimated. If specified, must be a proportion between 0 and 1.
#' @export
#' @rdname families
#' @examples
#' lognormal_mix(link = "log")
lognormal_mix <- function(link = "log", p_extreme = NULL) {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("identity", "log", "inverse")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }

  if (!is.null(p_extreme)) {
    if (!is.numeric(p_extreme) || p_extreme <= 0 || p_extreme >= 1) {
      stop("p_extreme must be NULL or a proportion between 0 and 1")
    }
  }
  x <- c(list(family = "lognormal_mix", link = linktemp, p_extreme = p_extreme), stats)
  add_to_family(x)
}

#' @param p_extreme Optional fixed probability for the extreme component. If NULL (default),
#'   this is estimated. If specified, must be a proportion between 0 and 1.
#' @export
#' @rdname families
#' @examples
#' nbinom2_mix(link = "log")
nbinom2_mix <- function(link = "log", p_extreme = NULL) {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("identity", "log", "inverse")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }

  if (!is.null(p_extreme)) {
    if (!is.numeric(p_extreme) || p_extreme <= 0 || p_extreme >= 1) {
      stop("p_extreme must be NULL or a proportion between 0 and 1")
    }
  }
  x <- c(list(family = "nbinom2_mix", link = linktemp, p_extreme = p_extreme), stats)
  add_to_family(x)
}

#' @details
#' The `nbinom2` negative binomial parameterization is the NB2 where the
#' variance grows quadratically with the mean (Hilbe 2011).
#' @references
#'
#' *Negative binomial families*:
#'
#' Hilbe, J. M. 2011. Negative binomial regression. Cambridge University Press.
#' @export
#' @examples
#' nbinom2(link = "log")
#' @rdname families
nbinom2 <- function(link = "log") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("log")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }

  v <- function(mu, theta) {

  }
  x <- c(list(family = "nbinom2", link = linktemp), stats)
  add_to_family(x)
}

#' @details
#' The `nbinom1` negative binomial parameterization lets the variance grow
#' linearly with the mean (Hilbe 2011).
#' @export
#' @examples
#' nbinom1(link = "log")
#' @rdname families
nbinom1 <- function(link = "log") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("log")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }
  x <- c(list(family = "nbinom1", link = linktemp), stats)
  add_to_family(x)
}

utils::globalVariables(".phi") ## avoid R CMD check NOTE

#' @export
#' @examples
#' truncated_poisson(link = "log")
#' @rdname families
truncated_poisson <- function(link = "log") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("log")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }
  linkinv <- function(eta) {
    lambda <- exp(eta)
    log_nzprob <- logspace_sub(0, -lambda)  # log(1 - exp(-lambda))
    lambda / exp(log_nzprob)
  }
  structure(list(family = "truncated_poisson", link = linktemp,
                 linkfun = stats$linkfun, linkinv = linkinv),
            class = "family")
}

#' @export
#' @examples
#' truncated_nbinom2(link = "log")
#' @rdname families
truncated_nbinom2 <- function(link = "log") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("log")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }
  linkinv <- function(eta, phi = NULL) {
    s1 <- eta
    if (is.null(phi)) phi <- .phi
    s2 <- logspace_add(0, s1 - log(phi)) # log(1 + mu/phi)
    log_nzprob <- logspace_sub(0, -phi * s2)
    exp(eta) / exp(log_nzprob)
  }
  structure(list(family = "truncated_nbinom2", link = linktemp, linkfun = stats$linkfun,
    linkinv = linkinv), class = "family")
}

logspace_sub <- function (lx, ly) lx + log1mexp(lx - ly)
logspace_add <- function (lx, ly) pmax(lx, ly) + log1p(exp(-abs(lx - ly)))
log1mexp <- function(x) ifelse(x <= log(2), log(-expm1(-x)), log1p(-exp(-x)))

#' @export
#' @examples
#' truncated_nbinom1(link = "log")
#' @rdname families
truncated_nbinom1 <- function(link = "log") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("log")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }
  linkinv <- function(eta, phi = NULL) {
    mu <- exp(eta)
    if (is.null(phi)) phi <- .phi
    s2 <- logspace_add(0, log(phi)) # log(1 + phi)
    log_nzprob <- logspace_sub(0, -mu / phi * s2) # 1 - prob(0)
    mu / exp(log_nzprob)
  }
  structure(list(family = "truncated_nbinom1", link = linktemp, linkfun = stats$linkfun,
    linkinv = linkinv), class = "family")
}

#' @param df Student-t degrees of freedom parameter. Can be `NULL` to estimate (default)
#'   or a numeric value > 1 to fix at a specific value.
#' @export
#' @details
#' For `student()`, the degrees of freedom parameter is estimated by default (`df = NULL`).
#' You can fix it at a specific value by providing a number > 1 (e.g., `df = 3`).
#' @rdname families
#' @examples
#' student(link = "identity") # estimate df
#' student(link = "identity", df = 3) # fix df at 3
student <- function(link = "identity", df = NULL) {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("identity", "log", "inverse")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }

  # Inform user about df parameter
  if (is.null(df)) {
    cli::cli_inform("Student-t degrees of freedom parameter will be estimated. This used to be fixed at 3 by default. To fix it, supply a value to `df` (e.g., `df = 3`).")
  } else {
    cli::cli_inform("Student-t degrees of freedom parameter fixed at {df}. To estimate it, set `df = NULL`.")
  }

  x <- c(list(family = "student", link = linktemp, df = df), stats)
  add_to_family(x)
}

#' @export
#' @examples
#' tweedie(link = "log")
#' @rdname families
tweedie <- function(link = "log") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("log", "identity")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }

  x <- c(list(family = "tweedie", link = linktemp), stats)
  add_to_family(x)
}

#' @export
#' @examples
#' censored_poisson(link = "log")
#' @rdname families
censored_poisson <- function(link = "log") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("log")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    stats <- stats::make.link(link)
    linktemp <- link
  }

  structure(list(family = "censored_poisson", link = linktemp, linkfun = stats$linkfun,
    linkinv = stats$linkinv), class = "family")
}

#' @param link1 Link for first part of delta/hurdle model. Defaults to `"logit"`
#'  for `type = "standard"` and `"log"` for `type = "poisson-link"`.
#' @param link2 Link for second part of delta/hurdle model.
#' @param type Delta/hurdle family type. `"standard"` for a classic hurdle
#'   model. `"poisson-link"` for a Poisson-link delta model (Thorson 2018).
#' @export
#' @importFrom stats Gamma binomial
#' @examples
#' delta_gamma()
#' @rdname families
#' @references
#' *Poisson-link delta families*:
#'
#' Thorson, J.T. 2018. Three problems with the conventional delta-model for
#' biomass sampling data, and a computationally efficient alternative. Canadian
#' Journal of Fisheries and Aquatic Sciences, 75(9), 1369-1382.
#' \doi{10.1139/cjfas-2017-0266}

delta_gamma <- function(link1,
  link2 = "log", type = c("standard", "poisson-link")) {
  type <- match.arg(type)
  if (missing(link1)) link1 <- if (type == "standard") "logit" else "log"
  l1 <- substitute(link1)
  if (!is.character(l1)) l1 <- deparse(l1)
  l2 <- substitute(link2)
  if (!is.character(l2)) l2 <- deparse(l2)
  f1 <- binomial(link = l1)
  f2 <- Gamma(link = l2)
  if (type == "poisson-link") {
    .type <- "poisson_link_delta"
    clean_name <- paste0("delta_gamma(link1 = '", l1, "', link2 = '", l2, "', type = 'poisson-link')")
  } else {
    .type <- "standard"
    clean_name <- paste0("delta_gamma(link1 = '", l1, "', link2 = '", l2, "')")
  }
  structure(list(f1, f2, delta = TRUE, link = c(l1, l2),
    type = .type, family = c("binomial", "Gamma"),
    clean_name = clean_name), class = "family")
}

#' @param p_extreme Optional fixed probability for the extreme component. If NULL (default),
#'   this is estimated. If specified, must be a proportion between 0 and 1.
#' @export
#' @examples
#' delta_gamma_mix()
#' @rdname families
delta_gamma_mix <- function(link1 = "logit", link2 = "log", p_extreme = NULL) {
  f1 <- binomial(link = link1)
  f2 <- gamma_mix(link = link2)
  structure(list(f1, f2, delta = TRUE, link = c("logit", "log"),
       family = c("binomial", "gamma_mix"),
       p_extreme = p_extreme,
       clean_name = "delta_gamma_mix(link1 = 'logit', link2 = 'log')"), class = "family")
}

#' @export
#' @examples
#' delta_gengamma()
#' @rdname families
delta_gengamma <- function(link1,
  link2 = "log", type = c("standard", "poisson-link")) {
  type <- match.arg(type)
  if (missing(link1)) link1 <- if (type == "standard") "logit" else "log"
  l1 <- substitute(link1)
  if (!is.character(l1)) l1 <- deparse(l1)
  l2 <- substitute(link2)
  if (!is.character(l2)) l2 <- deparse(l2)
  f1 <- binomial(link = l1)
  f2 <- gengamma(link = l2)
  if (type == "poisson-link") {
    .type <- "poisson_link_delta"
    clean_name <- paste0("delta_gengamma(link1 = '", l1, "', link2 = '", l2, "', type = 'poisson-link')")
  } else {
    .type <- "standard"
    clean_name <- paste0("delta_gengamma(link1 = '", l1, "', link2 = '", l2, "')")
  }
  structure(list(f1, f2, delta = TRUE, link = c(l1, l2),
    type = .type, family = c("binomial", "gengamma"),
    clean_name = clean_name), class = "family")
}

#' @export
#' @examples
#' delta_lognormal()
#' @rdname families
delta_lognormal <- function(link1,
  link2 = "log", type = c("standard", "poisson-link")) {
  type <- match.arg(type)
  if (missing(link1)) link1 <- if (type == "standard") "logit" else "log"
  l1 <- substitute(link1)
  if (!is.character(l1)) l1 <- deparse(l1)
  l2 <- substitute(link2)
  if (!is.character(l2)) l2 <- deparse(l2)
  f1 <- binomial(link = l1)
  f2 <- lognormal(link = l2)
  if (type == "poisson-link") {
    .type <- "poisson_link_delta"
    clean_name <- paste0("delta_lognormal(link1 = '", l1, "', link2 = '", l2, "', type = 'poisson-link')")
  } else {
    .type <- "standard"
    clean_name <- paste0("delta_lognormal(link1 = '", l1, "', link2 = '", l2, "')")
  }
  structure(list(f1, f2, delta = TRUE, link = c(l1, l2),
    family = c("binomial", "lognormal"), type = .type,
    clean_name = clean_name), class = "family")
}

#' @param p_extreme Optional fixed probability for the extreme component. If NULL (default),
#'   this is estimated. If specified, must be a proportion between 0 and 1.
#' @export
#' @examples
#' delta_lognormal_mix()
#' @rdname families
delta_lognormal_mix <- function(link1, link2 = "log", type = c("standard", "poisson-link"), p_extreme = NULL) {
  type <- match.arg(type)
  if (missing(link1)) link1 <- if (type == "standard") "logit" else "log"
  l1 <- substitute(link1)
  if (!is.character(l1)) l1 <- deparse(l1)
  l2 <- substitute(link2)
  if (!is.character(l2)) l2 <- deparse(l2)
  f1 <- binomial(link = l1)
  f2 <- lognormal(link = l2)
  if (type == "poisson-link") {
    .type <- "poisson_link_delta"
    clean_name <- paste0("delta_lognormal_mix(link1 = '", l1, "', link2 = '", l2, "', type = 'poisson-link')")
  } else {
    .type <- "standard"
    clean_name <- paste0("delta_lognormal_mix(link1 = '", l1, "', link2 = '", l2, "')")
  }
  structure(list(f1, f2, delta = TRUE, link = c(l1, l2),
       family = c("binomial", "lognormal_mix"), type = .type,
       p_extreme = p_extreme,
       clean_name = clean_name), class = "family")
}

#' @export
#' @examples
#' delta_truncated_nbinom2()
#' @rdname families
delta_truncated_nbinom2 <- function(link1 = "logit", link2 = "log") {
  f1 <- binomial(link = link1)
  f2 <- truncated_nbinom2(link = link2)
  structure(list(f1, f2, delta = TRUE, link = c("logit", "log"),
    family = c("binomial", "truncated_nbinom2"),
    clean_name = "delta_truncated_nbinom2(link1 = 'logit', link2 = 'log')"), class = "family")
}

#' @export
#' @examples
#' delta_truncated_nbinom1()
#' @rdname families
delta_truncated_nbinom1 <- function(link1 = "logit", link2 = "log") {
  f1 <- binomial(link = link1)
  f2 <- truncated_nbinom1(link = link2)
  structure(list(f1, f2, delta = TRUE, link = c("logit", "log"),
    family = c("binomial", "truncated_nbinom1"),
    clean_name = "delta_truncated_nbinom1(link1 = 'logit', link2 = 'log')"), class = "family")
}

#' @rdname families
#' @export
#' @keywords internal
delta_poisson_link_gamma <- function(link1 = "log", link2 = "log") {
  assert_that(link1 == "log")
  assert_that(link2 == "log")
  lifecycle::deprecate_warn("0.4.2.9000", "delta_poisson_link_gamma()", "delta_gamma(type)")
  delta_gamma(link1 = "logit", link2 = "log", type = "poisson-link")
}

#' @rdname families
#' @export
#' @keywords internal
delta_poisson_link_lognormal <- function(link1 = "log", link2 = "log") {
  assert_that(link1 == "log")
  assert_that(link2 == "log")
  lifecycle::deprecate_warn("0.4.2.9000", "delta_poisson_link_lognormal()", "delta_lognormal(type)")
  delta_lognormal(link1 = "logit", link2 = "log", type = "poisson-link")
}

#' @export
#' @examples
#' betabinomial(link = "logit")
#' @rdname families
betabinomial <- function(link = "logit") {
  linktemp <- substitute(link)
  if (!is.character(linktemp))
    linktemp <- deparse(linktemp)
  okLinks <- c("logit", "cloglog")
  if (linktemp %in% okLinks)
    stats <- stats::make.link(linktemp)
  else if (is.character(link)) {
    if (link %in% okLinks) {
      stats <- stats::make.link(link)
      linktemp <- link
    } else {
      stop(paste("link", link, "not available for betabinomial family; available links are", paste(okLinks, collapse = ", ")))
    }
  } else {
    stop(paste("link", linktemp, "not available for betabinomial family; available links are", paste(okLinks, collapse = ", ")))
  }
  x <- c(list(family = "betabinomial", link = linktemp), stats)
  add_to_family(x)
}


#' @export
#' @examples
#' delta_beta()
#' @rdname families
delta_beta <- function(link1 = "logit", link2 = "logit") {
  f1 <- binomial(link = link1)
  f2 <- Beta(link = link2)
  structure(list(f1, f2, delta = TRUE, link = c("logit", "logit"),
       family = c("binomial", "Beta"),
       clean_name = "delta_beta(link1 = 'logit', link2 = 'logit')"), class = "family")
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
#' correction needed). This is the central selling point of
#' `ordinal_probit()` for phylogenetic / threshold-trait analyses:
#' variance components estimated on the latent scale are directly
#' comparable to those of a continuous trait, giving the
#' Dempster-Lerner heritability formula
#' \eqn{H^2 = \sigma^2_{\text{phy}} / (\sigma^2_{\text{phy}} + 1)}
#' without approximation.
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
  if (!identical(link, "probit"))
    stop("ordinal_probit() supports only the probit link.")
  stats <- stats::make.link("probit")
  x <- list(family = "ordinal_probit", link = "probit",
            linkfun = stats$linkfun, linkinv = stats$linkinv)
  class(x) <- c("ordinal_probit", "family")
  x
}
