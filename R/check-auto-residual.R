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
##   (b) **Ordinal traits are NOT a problem.** The threshold model's
##       liability residual (1 for probit, pi^2/3 for logit) is not
##       estimated; it is added to Sigma exactly once, and only by the
##       `link_residual = "auto"` path (`link_residual_per_trait()` in
##       `R/extract-sigma.R`, fids 14 and 20). `link_residual = "none"`
##       drops it, which makes the unit-tier correlation matrix +/-1
##       (issue #1400). Ordinal traits therefore need no warning.
##
## `check_auto_residual()` inspects the fit and:
##   - errors on (a) -- it is a genuine modelling incoherence.
##   - is silent on ordinal traits (b); "auto" is the correct setting.
##   - is silent when (a) is absent.
##
## Designed to be callable directly by users for introspection AND
## by future internal pre-flight checks inside the extractors.

#' Check whether `link_residual = "auto"` is coherent for this fit
#'
#' Inspects the fit's per-row family vector and flags the one configuration
#' that makes the `link_residual = "auto"` path incoherent: within-trait
#' family mixing, which errors. Ordinal traits do not warn: the liability
#' residual (1 for [ordinal_probit()], pi^2/3 for [ordinal_logit()]) enters
#' the total covariance only through `"auto"`, so `"auto"` is the correct
#' setting and `link_residual = "none"` would drop it and give unit-tier
#' correlations of exactly +/-1.
#'
#' @param fit A fit returned by [gllvmTMB()].
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
#'   - `"warn"` path: reserved; no configuration currently reaches it.
#'   - `"ok"` path: silent.
#'
#' @seealso [extract_correlations()], [extract_Sigma()], [extract_Omega()].
#'
#' @export
check_auto_residual <- function(fit) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    .gllvmTMB_abort_not_multi_fit(fit)
  }

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
    if (length(rows_t) == 0L) {
      next
    }
    fams_t <- unique(fids[rows_t])
    if (length(fams_t) > 1L) {
      mixed_traits <- c(mixed_traits, trait_names[t])
      mixed_details <- c(
        mixed_details,
        paste0(
          "Trait {.val ",
          trait_names[t],
          "} has rows from families ",
          paste(.family_name_from_id(fams_t), collapse = ", "),
          "."
        )
      )
    } else if (fams_t %in% c(14L, 20L)) {
      ## Ordinal (probit or logit) single-family trait.
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

  ## ---- ordinal traits: deliberately no warning ------------------------------
  ## `ordinal_traits` is collected above only to document the decision. The
  ## liability residual is added once, by `link_residual = "auto"`; advising
  ## "none" would remove it and return correlations of +/-1 (issue #1400).

  invisible(list(status = "ok", messages = character()))
}

## Map family integer ids back to their canonical names. Mirrors the
## inverse of `family_to_id()` in `R/fit-multi.R`; kept local here
## so this safeguard does not depend on internal helpers.
.family_name_from_id <- function(ids) {
  names <- c(
    "0" = "gaussian",
    "1" = "binomial",
    "2" = "poisson",
    "3" = "lognormal",
    "4" = "Gamma",
    "5" = "nbinom2",
    "6" = "tweedie",
    "7" = "Beta",
    "8" = "betabinomial",
    "9" = "student",
    "10" = "truncated_poisson",
    "11" = "truncated_nbinom2",
    "12" = "delta_lognormal",
    "13" = "delta_gamma",
    "14" = "ordinal_probit",
    "15" = "nbinom1",
    "20" = "ordinal_logit"
  )
  unname(names[as.character(ids)])
}
