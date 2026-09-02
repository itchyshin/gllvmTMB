#' Generic dense-kernel covariance keywords
#'
#' @description
#' `kernel_latent()` fits a named random-effect tier with a user-supplied
#' between-unit covariance matrix `K`. For one named tier,
#' `unique = TRUE` adds a kernel-structured diagonal
#' \eqn{\boldsymbol\Psi} companion; the default `FALSE` is loadings-only.
#' Two or more named `kernel_latent()` tiers may share the same grouping levels,
#' each with its own `K`, loading matrix, and latent field. Multi-kernel fits are
#' loadings-only: `unique = TRUE` and `kernel_dep()` are not available in that
#' combination. Similar kernels can be
#' weakly separable, so use [diagnose_kernel_separability()] before assigning a
#' distinct interpretation to each component.
#'
#' A matrix returned by [make_cross_kernel()] is treated as a fixed supplied
#' covariance. The model does not estimate its association structure or bridge
#' strength. [extract_Gamma()] returns descriptive point summaries; it does not
#' provide calibrated intervals or establish a causal evolutionary process.
#'
#' @param unit Unquoted grouping column whose levels align with `rownames(K)`.
#' @param K Numeric dense positive-semidefinite covariance or correlation
#'   matrix aligned to the grouping levels.
#' @param name Character scalar used as the extractor level, e.g.
#'   `extract_Sigma(fit, level = "cross")`.
#' @param d Integer latent rank for `kernel_latent()`.
#' @param unique Logical; `TRUE` auto-includes the kernel-structured diagonal
#'   trait-specific \eqn{\boldsymbol\Psi} companion for a single dense-kernel
#'   tier. The default `FALSE` preserves the loadings-only subset.
#'
#' @return A formula marker; never evaluated as a regular R function.
#'
#' @examples
#' \dontrun{
#' A <- diag(5)
#' dat <- data.frame(
#'   unit = factor(rep(paste0("u", 1:5), each = 2), levels = paste0("u", 1:5)),
#'   obs = factor(seq_len(10)),
#'   y1 = rnorm(10),
#'   y2 = rnorm(10)
#' )
#' rownames(A) <- colnames(A) <- levels(dat$unit)
#' fit <- gllvmTMB(
#'   traits(y1, y2) ~
#'     1 + kernel_latent(unit, K = A, d = 1, name = "known",
#'                       unique = TRUE),
#'   data = dat,
#'   unit = "obs",
#'   cluster = "unit",
#'   family = gaussian()
#' )
#' extract_Sigma(fit, level = "known")
#' }
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
