#' Generic dense-kernel covariance keywords
#'
#' @description
#' `kernel_latent()` fits a named random-effect tier with a user-supplied
#' between-unit covariance matrix `K`. For one named tier,
#' `unique = TRUE` adds a kernel-structured diagonal
#' \eqn{\boldsymbol\Psi} companion; the default `FALSE` is loadings-only.
#' Two or more named `kernel_latent()` tiers may share the same grouping levels,
#' each with its own `K`, loading matrix, and latent field. On the TMB engine,
#' two named Gaussian tiers can each use `unique = TRUE` with a known common
#' observation-error SD supplied through `known_sigma_eps` to [gllvmTMB()],
#' positive weights, and observed same-trait kernel patterns that pass a
#' separation check. Each declared trait needs at least two observed rows.
#' Passing that check does not guarantee precise component estimates: recovery
#' has been poor in some known-truth settings, and intervals remain unvalidated.
#' Mixed-family and Julia-engine requests, as well as separate `kernel_dep()`
#' tiers, are not supported. Similar kernels can be
#' weakly separable, so use [diagnose_kernel_separability()] before assigning a
#' distinct interpretation to each component.
#'
#' A matrix returned by [make_cross_kernel()] is treated as a fixed supplied
#' covariance. The model does not estimate its association structure or bridge
#' strength. [extract_Gamma()] returns descriptive point summaries; it does not
#' provide calibrated intervals or establish a causal evolutionary process.
#'
#' @param unit Unquoted grouping column whose levels align with `rownames(K)`.
#'   When `cluster` is omitted, [gllvmTMB()] uses this column, so `K` is
#'   checked against it. An explicit `cluster` is unchanged.
#' @param K Numeric dense positive-semidefinite covariance or correlation
#'   matrix aligned to the grouping levels.
#' @param name Character scalar used as the extractor level, e.g.
#'   `extract_Sigma(fit, level = "cross")`.
#' @param d Integer latent rank for `kernel_latent()`.
#' @param unique Logical; `TRUE` auto-includes the kernel-structured diagonal
#'   trait-specific \eqn{\boldsymbol\Psi} companion. Two named tiers may each
#'   use it under the Gaussian fixed-error conditions described above. The
#'   default `FALSE` preserves the loadings-only subset.
#'
#' @return A formula marker; never evaluated as a regular R function.
#'
#' @examples
#' set.seed(1)
#' ## A known similarity among 30 sites along an environmental gradient; any
#' ## dense positive-semidefinite covariance or correlation matrix can be K.
#' x <- seq(0, 1, length.out = 30)
#' K <- exp(-abs(outer(x, x, "-")) / 0.1)
#' dimnames(K) <- list(paste0("s", 1:30), paste0("s", 1:30))
#' ## Four traits load on one K-correlated latent field and carry their own
#' ## K-correlated deviations, so the site-level trait covariance is
#' ## lambda lambda^T + diag(0.2).
#' L <- t(chol(K))
#' lambda <- c(0.8, 0.6, -0.5, 0.4)
#' site_eff <- outer(drop(L %*% rnorm(30)), lambda) +
#'   L %*% matrix(rnorm(30 * 4, sd = sqrt(0.2)), 30, 4)
#' ## Long format: four replicate visits per site, one row per (visit, trait).
#' dat <- expand.grid(trait = factor(paste0("y", 1:4)), visit = 1:4,
#'                    site = factor(rownames(K), levels = rownames(K)))
#' dat$obs <- factor(paste(dat$site, dat$visit, sep = "_"))
#' dat$value <- site_eff[cbind(as.integer(dat$site), as.integer(dat$trait))] +
#'   rnorm(nrow(dat), sd = 0.4)
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'     kernel_latent(site, K = K, d = 1, name = "gradient", unique = TRUE),
#'   data = dat, trait = "trait", unit = "obs", cluster = "site"
#' )
#' extract_Sigma(fit, level = "gradient")$Sigma
#' ## kernel_indep(): trait-specific variances only, on the same K:
#' fit_indep <- gllvmTMB(
#'   value ~ 0 + trait + kernel_indep(site, K = K, name = "gradient"),
#'   data = dat, trait = "trait", unit = "obs", cluster = "site"
#' )
#' extract_Sigma(fit_indep, level = "gradient")$Sigma
#'
#' @export
#' @param rho Source strength: a number in `[0,1]` fixes
#'   `rho * K + (1-rho) * diag(diag(K))` on the legacy-resolved source scale.
#'   Omitted or explicit `1` preserves the existing model. `NULL` estimates
#'   strength for one Gaussian structured trait-intercept block with complete
#'   replicated multivariate observations and no competing ordinary covariance.
#'   Estimated latent terms require rank one and at least four traits. The same
#'   strength applies to the entire latent-plus-Psi covariance. This parameter
#'   is not a variance-share summary. Fixed attenuation and the admitted
#'   Gaussian estimator have implementation checks; recovery is regime-specific.
kernel_latent <- function(unit, K, d = 1, name = "kernel", unique = FALSE, rho = 1) {
  invisible(NULL)
}

#' Deprecated alias: `kernel_unique()`
#'
#' `r lifecycle::badge("deprecated")`
#'
#' Only `kernel_unique()` is deprecated; dense-kernel modelling and
#' [kernel_latent()], [kernel_indep()], and [kernel_dep()] remain current.
#' This alias is retained for old formulas. Use [kernel_indep()] for a
#' standalone diagonal kernel covariance, or `kernel_latent(..., unique = TRUE)`
#' when a single latent kernel tier should include its diagonal
#' \eqn{\boldsymbol\Psi} companion.
#'
#' @inheritParams kernel_latent
#' @return A formula marker; never evaluated as a regular R function.
#' @export
kernel_unique <- function(unit, K, name = "kernel") {
  ## Fire-on-use notice when this marker is called directly. The formula
  ## parser already warns on `kernel_unique(...)` used inside a `~` formula
  ## via the shared `.gllvmTMB_warn_unique_family_deprecated()` cli_warn
  ## tracker (R/brms-sugar.R) -- that path is unaffected. This function's own
  ## BODY, though, is never evaluated when the keyword appears inside a
  ## formula (only its name is matched), so a direct call to
  ## `kernel_unique()` -- outside a formula, e.g. in a script or test -- was
  ## previously silent. Mirrors the once-per-session tracker
  ## `.gllvmTMB_warn_scalar_family_deprecated()` /
  ## `.gllvmTMB_warn_latent_residual_alias()` use in R/brms-sugar.R.
  if (!isTRUE(getOption("gllvmTMB.quiet_grammar_notes", FALSE))) {
    if (!isTRUE(.gllvmTMB_deprecation_seen[["kernel_unique_direct_call"]])) {
      lifecycle::deprecate_soft(
        "0.2.0",
        "kernel_unique()",
        "kernel_indep()"
      )
      .gllvmTMB_deprecation_seen[["kernel_unique_direct_call"]] <- TRUE
    }
  }
  invisible(NULL)
}

#' @rdname kernel_latent
#' @param common `FALSE` (default) for a separate dense-kernel variance per
#'   trait (`kernel_indep`); `TRUE` ties all traits to one shared variance,
#'   the canonical spelling for the soft-deprecated [kernel_scalar()].
#' @export
kernel_indep <- function(unit, K, name = "kernel", common = FALSE, rho = 1) {
  invisible(NULL)
}

#' @rdname kernel_latent
#' @export
kernel_dep <- function(unit, K, name = "kernel", rho = 1) {
  invisible(NULL)
}

#' Dense-kernel one-shared-variance covariance: `kernel_scalar()`
#'
#' `kernel_scalar()` is the dense-kernel analogue of [scalar()] /
#' [phylo_scalar()]: **one variance shared by every trait**, coupled between
#' grouping levels by the supplied dense matrix `K`
#' (\eqn{\boldsymbol\Sigma = \sigma^2\,\mathbf I_T},
#' \eqn{\operatorname{Cov}(b_{gt}, b_{g't}) = \sigma^2 K_{gg'}}). It uses the
#' same phylo-equivalent diagonal engine path as [kernel_indep()], with the
#' per-trait variances tied to a single shared parameter, so
#' [extract_Sigma()] exposes it under `level = name`.
#'
#' @inheritParams kernel_latent
#' @return A formula marker; never evaluated as a regular R function.
#' @seealso [kernel_indep()], [kernel_dep()], [kernel_latent()], [scalar()],
#'   [phylo_scalar()], [extract_Sigma()].
#' @export
kernel_scalar <- function(unit, K, name = "kernel") {
  invisible(NULL)
}

## Bare grouping columns named by kernel_*() intercept terms.
## `kernel_indep(unit, K = K)` stores `unit` as the first argument.
## `kernel_indep(K = K, unit = g)` names that argument later, and
## positional or partially matched `unit` must bind too; use match.call()
## on the keyword, then fall back to the second subexpression (#1805).
## A bar (`1 + x | g`) is a slope and keeps its own group; it is not
## collected here. Returns a zero-row data.frame when no bare kernel
## grouping is present.
.gllvmTMB_lme4_bar_rhs <- function(expr) {
  if (!is.call(expr) || !identical(expr[[1L]], as.symbol("|"))) {
    return(NA_character_)
  }
  rhs <- expr[[3L]]
  if (is.symbol(rhs)) {
    return(as.character(rhs))
  }
  if (is.character(rhs) && length(rhs) == 1L && !is.na(rhs)) {
    return(rhs)
  }
  NA_character_
}

.gllvmTMB_keyword_base_name <- function(fn) {
  fn <- as.character(fn)[1L]
  if (is.na(fn) || !nzchar(fn)) {
    return(NA_character_)
  }
  sub("^[^:]*:+", "", fn)
}

.gllvmTMB_keyword_bare_symbol <- function(arg) {
  if (is.symbol(arg)) {
    return(as.character(arg))
  }
  if (is.character(arg) && length(arg) == 1L && !is.na(arg)) {
    return(arg)
  }
  NA_character_
}

.gllvmTMB_keyword_match_call <- function(fn, e) {
  fn <- .gllvmTMB_keyword_base_name(fn)
  if (is.na(fn)) {
    return(NULL)
  }
  tryCatch(
    match.call(get(fn, envir = asNamespace("gllvmTMB")), e),
    error = function(err) NULL
  )
}

.gllvmTMB_keyword_group_arg <- function(matched, e,
                                        group_fields = c("unit", "species", "id")) {
  if (!is.null(matched)) {
    for (fld in group_fields) {
      if (!is.null(matched[[fld]])) {
        sym <- .gllvmTMB_keyword_bare_symbol(matched[[fld]])
        if (!is.na(sym)) {
          return(sym)
        }
      }
    }
  }
  nms <- names(e)
  if (!is.null(nms)) {
    for (fld in group_fields) {
      idx <- match(fld, nms)
      if (!is.na(idx)) {
        sym <- .gllvmTMB_keyword_bare_symbol(e[[idx]])
        if (!is.na(sym)) {
          return(sym)
        }
      }
    }
  }
  if (length(e) >= 2L) {
    return(.gllvmTMB_keyword_bare_symbol(e[[2L]]))
  }
  NA_character_
}

.gllvmTMB_keyword_bare_groups <- function(formula, keywords, bar_keywords) {
  found <- list()
  walk <- function(e) {
    if (!is.call(e)) return(invisible(NULL))
    fn <- .gllvmTMB_keyword_base_name(e[[1L]])
    if (!is.na(fn) && fn %in% keywords && length(e) >= 2L) {
      matched <- .gllvmTMB_keyword_match_call(fn, e)
      group <- NA_character_
      if (fn %in% bar_keywords) {
        formula_expr <- if (!is.null(matched) && !is.null(matched$formula)) {
          matched$formula
        } else if (length(e) >= 2L) {
          e[[2L]]
        } else {
          NULL
        }
        if (is.call(formula_expr)) {
          group <- .gllvmTMB_lme4_bar_rhs(formula_expr)
        }
      } else {
        group <- .gllvmTMB_keyword_group_arg(matched, e)
      }
      if (!is.na(group) && nzchar(group)) {
        found[[length(found) + 1L]] <<- list(fn = fn, group = group)
      }
    }
    for (i in seq_along(e)[-1L]) walk(e[[i]])
    invisible(NULL)
  }
  if (is.call(formula)) walk(formula)
  if (!length(found)) {
    return(data.frame(
      fn = character(), group = character(), stringsAsFactors = FALSE
    ))
  }
  data.frame(
    fn = vapply(found, `[[`, character(1L), "fn"),
    group = vapply(found, `[[`, character(1L), "group"),
    stringsAsFactors = FALSE
  )
}

.gllvmTMB_kernel_bare_groups <- function(formula) {
  kernels <- c(
    "kernel_latent", "kernel_unique", "kernel_indep",
    "kernel_dep", "kernel_scalar"
  )
  .gllvmTMB_keyword_bare_groups(formula, kernels, character())
}

.gllvmTMB_animal_bare_groups <- function(formula) {
  keywords <- c(
    "animal_latent", "animal_unique", "animal_indep",
    "animal_dep", "animal_scalar"
  )
  .gllvmTMB_keyword_bare_groups(
    formula, keywords, c("animal_indep", "animal_dep")
  )
}

.gllvmTMB_phylo_bare_groups <- function(formula) {
  keywords <- c(
    "phylo_latent", "phylo_unique", "phylo_indep",
    "phylo_dep", "phylo_scalar"
  )
  .gllvmTMB_keyword_bare_groups(
    formula, keywords, c("phylo_indep", "phylo_dep")
  )
}

## Public keyword behind a harvested kernel mode. A folded
## `kernel_latent(..., unique = TRUE)` carries both "latent" and "unique".
.gllvmTMB_kernel_fn_from_modes <- function(modes) {
  modes <- unique(as.character(modes[!is.na(modes)]))
  if ("latent" %in% modes) return("kernel_latent")
  if ("dep" %in% modes) return("kernel_dep")
  if ("scalar" %in% modes) return("kernel_scalar")
  if ("indep" %in% modes) return("kernel_indep")
  if ("unique" %in% modes) return("kernel_unique")
  "kernel_indep"
}
