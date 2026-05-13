## Extractor for ordinal_probit cutpoints.
##
## Implements Hadfield's (2015) convention: tau_1 = 0 fixed for
## identifiability, K - 2 free cutpoints {tau_2, ..., tau_{K-1}} estimated
## per ordinal trait. Returns one row per (trait, cutpoint) pair.

#' Extract ordinal-probit cutpoints from a `gllvmTMB_multi` fit
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
#' @param fit A `gllvmTMB_multi` fit produced with at least one
#'   `ordinal_probit()` trait.
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
#'   data = ordinal_dat, unit = "individual", cluster = "species",
#'   family = ordinal_probit()
#' )
#' extract_cutpoints(fit)
#' }
#'
#' @export
extract_cutpoints <- function(fit) {
  out_empty <- data.frame(
    trait          = character(0),
    cutpoint_index = integer(0),
    cutpoint_label = character(0),
    tau_estimate   = numeric(0),
    tau_se         = numeric(0),
    stringsAsFactors = FALSE
  )
  if (!inherits(fit, "gllvmTMB_multi"))
    stop("extract_cutpoints() requires a gllvmTMB_multi fit.", call. = FALSE)
  fids <- fit$tmb_data$family_id_vec
  if (!any(fids == 14L)) return(out_empty)
  n_cuts_pt <- as.integer(fit$tmb_data$n_ordinal_cuts_per_trait)
  off_pt    <- as.integer(fit$tmb_data$ordinal_offset_per_trait)
  trait_lab <- levels(fit$data[[fit$trait_col]])
  taus      <- as.numeric(fit$report$ordinal_cutpoints %||% numeric(0))
  ## Try to pull SEs from the sdreport (ADREPORT(ordinal_cutpoints)).
  ses <- rep(NA_real_, length(taus))
  if (!is.null(fit$sd_report)) {
    adr <- summary(fit$sd_report, "report")
    rows <- grep("^ordinal_cutpoints$", rownames(adr))
    if (length(rows) == length(taus))
      ses <- adr[rows, "Std. Error"]
  }
  rows <- list()
  for (t in seq_along(n_cuts_pt)) {
    Kt_minus_2 <- n_cuts_pt[t]
    if (Kt_minus_2 == 0L) next
    base <- off_pt[t]
    for (j in seq_len(Kt_minus_2)) {
      idx <- base + j           # 1-based position in the flat vector
      cp_index <- j + 1L        # tau_2 corresponds to j = 1
      rows[[length(rows) + 1L]] <- data.frame(
        trait          = trait_lab[t],
        cutpoint_index = cp_index,
        cutpoint_label = sprintf("cutpoint_%d", cp_index),
        tau_estimate   = taus[idx],
        tau_se         = ses[idx],
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows) == 0L) return(out_empty)
  do.call(rbind, rows)
}
