## One-call user-facing diagnostic for a fitted gllvmTMB_multi model.
## Wraps sanity_multi(), checks rotation identifiability, reports the
## key biological summaries, and prints actionable hints for any WARN
## or FAIL signal. Designed to be the first call a user makes after
## fitting.

#' One-call diagnostic + biological summary for a `gllvmTMB_multi` fit
#'
#' This is the function to call right after `fit <- gllvmTMB(...)`. It
#' rolls up the existing diagnostics ([sanity_multi()]), the rotation
#' identifiability advisory, and the key biological summaries
#' (correlation diagonals, ICCs, communalities) into a single human-
#' readable report with explicit next-step hints for any WARN signal.
#'
#' @param object A `gllvmTMB_multi` fit.
#' @param gradient_thresh,se_thresh Forwarded to [sanity_multi()].
#' @param big_corr_thresh Threshold above which a `Sigma_B` correlation
#'   off-diagonal is flagged as worth highlighting. Default 0.5.
#' @param verbose If `TRUE` (default), prints the report. Always
#'   returns the structured list invisibly.
#' @return Invisibly a list with components: `sanity` (the
#'   [sanity_multi()] flags), `rotation` (rotation-advisory list),
#'   `Sigma_B`, `Sigma_W`, `ICC_site`, `communality_B`, `communality_W`,
#'   and `hints` (character vector of suggested actions).
#' @export
#' @seealso [sanity_multi()], [suggest_lambda_constraint()],
#'   [extract_Sigma()], [extract_communality()],
#'   [compare_dep_vs_two_U()] / [compare_indep_vs_two_U()] for
#'   identifiability cross-checks.
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 2), data = dat)
#' gllvmTMB_diagnose(fit)
#' }
gllvmTMB_diagnose <- function(object,
                              gradient_thresh = 1e-2,
                              se_thresh       = 100,
                              big_corr_thresh = 0.5,
                              verbose = TRUE) {
  if (!inherits(object, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")

  ## ---- Pillar 1: sanity flags --------------------------------------
  if (verbose) cli::cli_h2("1. Optimiser & numerical sanity")
  san <- if (verbose) {
    sanity_multi(object,
                 gradient_thresh = gradient_thresh,
                 se_thresh       = se_thresh)
  } else {
    ## Capture the print output so silent calls don't pollute stdout
    suppressWarnings(utils::capture.output({
      flags <- sanity_multi(object,
                            gradient_thresh = gradient_thresh,
                            se_thresh       = se_thresh)
    }))
    flags
  }

  ## ---- Pillar 2: rotation identifiability --------------------------
  rot <- object$needs_rotation_advice %||%
         list(B = FALSE, W = FALSE, phy = FALSE)
  if (verbose) {
    cli::cli_h2("2. Rotational identifiability")
    if (any(unlist(rot, use.names = FALSE))) {
      for (lvl in names(rot)) {
        if (isTRUE(rot[[lvl]])) {
          d_lvl <- object[[paste0("d_", lvl)]]
          cli::cli_inform(c(
            "!" = "{.code Lambda_{lvl}} (rank d = {d_lvl}) is identified only up to rotation."
          ))
        }
      }
    } else {
      cli::cli_inform(c("v" = "No latent / phylo_latent term with rotational ambiguity."))
    }
  }

  ## ---- Pillar 3: biological summaries ------------------------------
  out_Sigma_B <- tryCatch(extract_Sigma_B(object), error = function(e) NULL)
  out_Sigma_W <- tryCatch(extract_Sigma_W(object), error = function(e) NULL)
  ICC_site    <- tryCatch(extract_ICC_site(object), error = function(e) NULL)
  comm_B      <- tryCatch(extract_communality(object, "B"),
                          error = function(e) NULL)
  comm_W      <- tryCatch(extract_communality(object, "W"),
                          error = function(e) NULL)

  if (verbose) {
    cli::cli_h2("3. Biological summaries")
    if (!is.null(out_Sigma_B)) {
      cat("\n  Sigma_B (between-unit covariance) diagonal:\n  ")
      cat(paste(round(diag(out_Sigma_B$Sigma_B), 3), collapse = "  "), "\n")
      ## Surface large correlations
      R <- out_Sigma_B$R_B
      big <- which(abs(R) > big_corr_thresh & lower.tri(R), arr.ind = TRUE)
      if (nrow(big) > 0) {
        nm <- rownames(R) %||% paste0("trait", seq_len(nrow(R)))
        cat(sprintf("  %d trait pair(s) with |corr| > %.2f:\n",
                    nrow(big), big_corr_thresh))
        for (i in seq_len(min(nrow(big), 8L))) {
          cat(sprintf("    %s ~ %s : %+.2f\n",
                      nm[big[i, 1]], nm[big[i, 2]],
                      R[big[i, 1], big[i, 2]]))
        }
      }
    }
    if (!is.null(out_Sigma_W)) {
      cat("\n  Sigma_W (within-unit covariance) diagonal:\n  ")
      cat(paste(round(diag(out_Sigma_W$Sigma_W), 3), collapse = "  "), "\n")
    }
    if (!is.null(ICC_site)) {
      cat("\n  Per-trait site-level ICC:\n  ")
      cat(paste(round(ICC_site, 3), collapse = "  "), "\n")
    }
    if (!is.null(comm_B)) {
      cat("\n  Global communalities:\n  ")
      cat(paste(round(comm_B, 3), collapse = "  "), "\n")
    }
    if (!is.null(comm_W)) {
      cat("\n  Local communalities:\n  ")
      cat(paste(round(comm_W, 3), collapse = "  "), "\n")
    }
  }

  ## ---- Pillar 4: actionable hints ----------------------------------
  hints <- character(0)
  if (!isTRUE(san$converged)) {
    hints <- c(hints, paste(
      "Optimiser did NOT converge.",
      "Try `gllvmTMBcontrol(n_init = 5, optimizer = \"optim\",",
      "optArgs = list(method = \"BFGS\"))` and refit."
    ))
  }
  if (isTRUE(san$max_gradient >= gradient_thresh)) {
    hints <- c(hints, paste(
      sprintf("Max |gradient| = %.3g exceeds %.1e.", san$max_gradient,
              gradient_thresh),
      "Optimum may not be tight; try multiple starts via",
      "`gllvmTMBcontrol(n_init = 5)` or rescale predictors."
    ))
  }
  if (!isTRUE(san$pd_hessian)) {
    hints <- c(hints, paste(
      "Hessian is not positive-definite. Some parameters are not",
      "identified. Inspect `summary(fit)` for NaN SEs and consider",
      "removing redundant covstruct terms or pinning loadings via",
      "`suggest_lambda_constraint()`."
    ))
  }
  if (!is.na(san$max_se) && san$max_se >= se_thresh) {
    hints <- c(hints, paste(
      sprintf("Largest fixed-effect SE = %.3g.", san$max_se),
      "A coefficient is barely identified -- check for collinearity or",
      "for a fixed effect that is absorbed by a random-effect group."
    ))
  }
  if (any(unlist(rot, use.names = FALSE))) {
    hints <- c(hints, paste(
      "Lambda is identified only up to rotation. For a unique loading",
      "matrix, see `suggest_lambda_constraint()`. For interpretation,",
      "use `getLoadings(fit, rotate = \"varimax\")`. The implied Sigma",
      "matrices are rotation-invariant and need no constraint."
    ))
  }

  if (verbose) {
    cli::cli_h2("4. Suggested next steps")
    if (length(hints) == 0) {
      cli::cli_inform(c("v" = "Nothing flagged. Fit looks healthy."))
    } else {
      for (h in hints) cli::cli_inform(c("*" = h))
    }
  }

  invisible(list(
    sanity        = san,
    rotation      = rot,
    Sigma_B       = out_Sigma_B,
    Sigma_W       = out_Sigma_W,
    ICC_site      = ICC_site,
    communality_B = comm_B,
    communality_W = comm_W,
    hints         = hints
  ))
}
