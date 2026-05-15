## Phase 1b safeguard for the `extract_correlations()` /
## `extract_Sigma()` / `extract_Omega()` `link_residual = "auto"`
## default (Emmy persona consult 2026-05-14, captured in
## `docs/dev-log/after-task/2026-05-14-phase-1a-batch-d.md`).
##
## The "auto" path adds a per-family link-residual variance to the
## diagonal of the implied trait Sigma before computing correlations.
## Two configurations make that addition incoherent:
##
##   (a) **Within-trait family mixing.** A single trait carries rows
##       from more than one family (e.g., some rows fit as binomial,
##       others as poisson on the same trait). `link_residual_per_trait()`
##       (`R/extract-sigma.R`) picks the modal family and warns, but
##       the per-trait link-residual is then computed for ONE family
##       while the other family's rows still contribute to the trait
##       block of Sigma. The reported correlation is misleading.
##
##   (b) **Ordinal-probit traits.** The probit link's latent residual
##       is **already** fixed at 1 by construction of the threshold
##       model -- the cutpoints absorb the location and the latent
##       variance is standardised. `link_residual = "auto"` adds 1
##       again, which over-counts. The user should pass
##       `link_residual = "none"` for ordinal-probit fits to avoid
##       this double-count.
##
## `check_auto_residual()` inspects the fit and:
##   - errors on (a) -- it is a genuine modelling incoherence.
##   - warns on (b) -- the user can proceed but the result is not
##     what they probably want.
##   - is silent when both conditions are absent.
##
## Designed to be callable directly by users for introspection AND
## by future internal pre-flight checks inside the extractors.

#' Check whether `link_residual = "auto"` is coherent for this fit
#'
#' Inspects the fit's per-row family vector and flags two configurations
#' that make the `link_residual = "auto"` path incoherent: within-trait
#' family mixing (errors) and ordinal-probit traits (warns; the latent
#' residual is already standardised at 1, so adding 1 again over-counts).
#'
#' @param fit A `gllvmTMB_multi` fit returned by [gllvmTMB()].
#'
#' @return Invisibly, a list with components `status` (one of `"ok"`,
#'   `"warn"`, or `"err"` -- though the `"err"` path is unreachable
#'   from a successful return because `cli::cli_abort` halts) and
#'   `messages` (a character vector of human-readable findings; empty
#'   when `status = "ok"`).
#'
#' @section Side effects:
#'   - `"err"` path: `cli::cli_abort` is fired and the function does
#'     not return.
#'   - `"warn"` path: `cli::cli_warn` is fired before the function
#'     returns the list invisibly.
#'   - `"ok"` path: silent.
#'
#' @seealso [extract_correlations()], [extract_Sigma()], [extract_Omega()].
#'
#' @export
check_auto_residual <- function(fit) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")

  fids <- fit$tmb_data$family_id_vec
  tids <- fit$tmb_data$trait_id
  if (is.null(fids) || is.null(tids)) {
    ## Older fits / mock objects without the per-row family vector.
    ## Treat as "ok" since we have nothing to check.
    return(invisible(list(status = "ok", messages = character())))
  }

  trait_names <- levels(fit$data[[fit$trait_col]])
  Tn <- length(trait_names)
  ## trait_id is 0-based on tmb_data.
  tids_1 <- tids + 1L

  ## ---- check (a): within-trait family mixing -----------------------------
  mixed_traits <- character()
  mixed_details <- character()
  ordinal_traits <- character()
  for (t in seq_len(Tn)) {
    rows_t <- which(tids_1 == t)
    if (length(rows_t) == 0L) next
    fams_t <- unique(fids[rows_t])
    if (length(fams_t) > 1L) {
      mixed_traits <- c(mixed_traits, trait_names[t])
      mixed_details <- c(
        mixed_details,
        paste0(
          "Trait {.val ", trait_names[t], "} has rows from families ",
          paste(.family_name_from_id(fams_t), collapse = ", "), "."
        )
      )
    } else if (identical(fams_t, 14L)) {
      ## Ordinal-probit single-family trait.
      ordinal_traits <- c(ordinal_traits, trait_names[t])
    }
  }

  if (length(mixed_traits) > 0L) {
    cli::cli_abort(
      c(
        "Within-trait family mixing is incoherent for {.code link_residual = \"auto\"}.",
        "x" = "{length(mixed_traits)} trait{?s} carr{?ies/y} rows from multiple families.",
        stats::setNames(mixed_details, rep("i", length(mixed_details))),
        ">" = "Either separate the offending traits into single-family blocks, or pass {.code link_residual = \"none\"} to skip the per-family residual addition."
      ),
      class = "gllvmTMB_auto_residual_incoherent"
    )
  }

  ## ---- check (b): ordinal-probit traits ---------------------------------
  if (length(ordinal_traits) > 0L) {
    msg <- paste0(
      "Ordinal-probit trait", if (length(ordinal_traits) > 1L) "s" else "",
      " present: ",
      paste(paste0("{.val ", ordinal_traits, "}"), collapse = ", "),
      "."
    )
    cli::cli_warn(
      c(
        "{.code link_residual = \"auto\"} over-counts the latent residual for ordinal-probit traits.",
        "i" = msg,
        "i" = "The probit link's latent residual is already {.val 1} by construction of the threshold model (cutpoints absorb location; latent variance is standardised).",
        ">" = "Pass {.code link_residual = \"none\"} for ordinal-probit fits, or extract per tier and adjust manually."
      ),
      class = "gllvmTMB_auto_residual_ordinal_probit_overcount"
    )
    return(invisible(list(
      status   = "warn",
      messages = paste(
        "Ordinal-probit traits present;",
        "link_residual = 'auto' over-counts the latent residual (already 1 by construction)."
      )
    )))
  }

  invisible(list(status = "ok", messages = character()))
}

## Map family integer ids back to their canonical names. Mirrors the
## inverse of `family_to_id()` in `R/fit-multi.R`; kept local here
## so this safeguard does not depend on internal helpers.
.family_name_from_id <- function(ids) {
  names <- c(
    "0"  = "gaussian",
    "1"  = "binomial",
    "2"  = "poisson",
    "3"  = "lognormal",
    "4"  = "Gamma",
    "5"  = "nbinom2",
    "6"  = "tweedie",
    "7"  = "Beta",
    "8"  = "betabinomial",
    "9"  = "student",
    "10" = "truncated_poisson",
    "11" = "truncated_nbinom2",
    "12" = "delta_lognormal",
    "13" = "delta_gamma",
    "14" = "ordinal_probit"
  )
  unname(names[as.character(ids)])
}
