## Extractor for ordinal_probit cutpoints.
##
## Implements Hadfield's (2015) convention: tau_1 = 0 fixed for
## identifiability, K - 2 free cutpoints {tau_2, ..., tau_{K-1}} estimated
## per ordinal trait. Returns one row per (trait, cutpoint) pair.

#' Extract ordinal-probit cutpoints from a fitted gllvmTMB model
#'
#' For traits fitted with [ordinal_probit()], returns a tidy data frame
#' with the K - 2 estimated cutpoints \eqn{\tau_2, \ldots, \tau_{K-1}}
#' per trait, with optional standard errors from the joint sdreport.
#'
#' Convention: `gllvmTMB` follows Hadfield (2015) — \eqn{\tau_1 = 0} is
#' fixed for identifiability and the K - 2 free cutpoints are reported
#' as `cutpoint_2`, `cutpoint_3`, etc. This differs from `brms`, which
#' reports K - 1 cutpoints as `Intercept[1..K-1]`.
#'
#' @param fit A fit returned by [gllvmTMB()] with at least one
#'   [ordinal_probit()] trait.
#'
#' @return A data frame with columns
#'   \describe{
#'     \item{`trait`}{Trait label (factor level from `data[[trait]]`).}
#'     \item{`cutpoint_index`}{Integer index \eqn{k \in \{2, \ldots, K-1\}}.}
#'     \item{`cutpoint_label`}{Character label `"cutpoint_<k>"`.}
#'     \item{`tau_estimate`}{Estimated \eqn{\tau_k} on the latent (probit)
#'       scale.}
#'     \item{`tau_se`}{Standard error from the joint sdreport, or `NA` if
#'       the report is unavailable.}
#'   }
#'
#'   If the fit contains no `ordinal_probit()` traits, returns a
#'   zero-row data frame with the same columns.
#'
#' ## Julia-engine bridge fits
#'
#' For a `gllvmTMB(engine = "julia")` ordinal bridge fit the function returns
#' the fitted cutpoints from the bridge payload in the same five-column shape,
#' but the **contract differs** from the native per-trait shape. The Julia
#' engine fits a **single shared** ordered cutpoint vector across all ordinal
#' traits (the bridge payload carries the full `C - 1` ordered cutpoints
#' \eqn{\tau_1, \ldots, \tau_{C-1}} with no \eqn{\tau_1 = 0} anchor), whereas
#' native `gllvmTMB` keeps **per-trait** cutpoints and reports the `K - 2` free
#' values \eqn{\tau_2, \ldots, \tau_{K-1}} for each trait. The bridge therefore
#' returns one row per shared cutpoint, the `trait` column is `"(shared)"`,
#' `cutpoint_index` runs `1:(C - 1)`, and `tau_se` is `NA` (the bridge payload
#' carries no TMB `sdreport`). A non-ordinal bridge fit errors clearly. See
#' `docs/dev-log/2026-06-15-dispersion-structure-divergence.md` for the
#' shared-vs-per-trait divergence.
#'
#' @references
#' Hadfield, J. D. (2015). Increasing the efficiency of MCMC for
#'   hierarchical phylogenetic models of categorical traits using
#'   reduced mixed models. *Methods Ecol. Evol.* 6:706-714.
#'   \doi{10.1111/2041-210X.12354}
#'
#' @seealso [ordinal_probit()] for the family constructor and the
#'   threshold-trait theory reference list.
#'
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + phylo_unique(species, tree = tree),
#'   data    = ordinal_dat,
#'   trait   = "trait",
#'   unit    = "individual",
#'   cluster = "species",
#'   family  = ordinal_probit()
#' )
#' extract_cutpoints(fit)
#' }
#'
#' @export
extract_cutpoints <- function(fit) {
  out_empty <- data.frame(
    trait = character(0),
    cutpoint_index = integer(0),
    cutpoint_label = character(0),
    tau_estimate = numeric(0),
    tau_se = numeric(0),
    stringsAsFactors = FALSE
  )
  if (inherits(fit, "gllvmTMB_julia")) {
    ## Bridge fits expose the POINT cutpoints only. The engine fits a SINGLE
    ## SHARED cutpoint vector (full C - 1 ordered cutpoints), not the native
    ## per-trait tau_2 .. tau_{K-1} shape; the helper returns the shared vector
    ## in the same five-column frame and documents the divergence.
    return(.gllvm_julia_cutpoints(fit))
  }
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  fids <- fit$tmb_data$family_id_vec
  if (!any(fids == 14L)) {
    return(out_empty)
  }
  n_cuts_pt <- as.integer(fit$tmb_data$n_ordinal_cuts_per_trait)
  off_pt <- as.integer(fit$tmb_data$ordinal_offset_per_trait)
  trait_lab <- levels(fit$data[[fit$trait_col]])
  taus <- as.numeric(fit$report$ordinal_cutpoints %||% numeric(0))
  ## Try to pull SEs from the sdreport (ADREPORT(ordinal_cutpoints)).
  ses <- rep(NA_real_, length(taus))
  if (!is.null(fit$sd_report)) {
    adr <- summary(fit$sd_report, "report")
    rows <- grep("^ordinal_cutpoints$", rownames(adr))
    if (length(rows) == length(taus)) {
      ses <- adr[rows, "Std. Error"]
    }
  }
  rows <- list()
  for (t in seq_along(n_cuts_pt)) {
    Kt_minus_2 <- n_cuts_pt[t]
    if (Kt_minus_2 == 0L) {
      next
    }
    base <- off_pt[t]
    for (j in seq_len(Kt_minus_2)) {
      idx <- base + j # 1-based position in the flat vector
      cp_index <- j + 1L # tau_2 corresponds to j = 1
      rows[[length(rows) + 1L]] <- data.frame(
        trait = trait_lab[t],
        cutpoint_index = cp_index,
        cutpoint_label = sprintf("cutpoint_%d", cp_index),
        tau_estimate = taus[idx],
        tau_se = ses[idx],
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) {
    return(out_empty)
  }
  do.call(rbind, rows)
}
