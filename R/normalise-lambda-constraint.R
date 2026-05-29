## Boundary helper for the `lambda_constraint = list(B = ..., W = ...)`
## -> `lambda_constraint = list(unit = ..., unit_obs = ...)` rename
## (Design 02 Stage 2 follow-on). Same once-per-session option-cached
## deprecation pattern as `R/normalise-level.R` so the two argument
## surfaces stay symmetric: the `level` argument and the
## `lambda_constraint` element names accept the same canonical /
## legacy pair (`unit` / `B`, `unit_obs` / `W`).
##
## Mapping (user-facing -> internal slot consumed by `fit-multi.R`):
##
##   user types        canonical            legacy / internal slot
##   ----------------  -------------------  -----------------------
##   "unit"            "unit"               "B"
##   "unit_obs"        "unit_obs"           "W"
##   "phy"             "phy"                "phy"     (unchanged)
##   "spde"            "spde"               "spde"    (unchanged)
##   "B"     (legacy)  -> deprecate_soft to "unit"     -> "B"
##   "W"     (legacy)  -> deprecate_soft to "unit_obs" -> "W"
##
## Internal slot names stay as `B` / `W` because they map directly onto
## TMB-side parameter names (`theta_rr_B`, `theta_rr_W`); renaming the
## internal slots would require a C++ change. The normaliser here
## translates user input to those internal names.

#' Normalise `lambda_constraint` list element names
#'
#' Maps user-facing names (`unit`, `unit_obs`) to legacy / internal slot
#' names (`B`, `W`) so the engine consumption code in `fit-multi.R` can
#' continue using `lambda_constraint$B` / `$W` unchanged. Emits a
#' one-shot soft deprecation message when legacy `B` / `W` are passed
#' directly. Other element names (`phy`, `spde`) pass through unchanged.
#'
#' @param x A list passed as the `lambda_constraint` argument, or `NULL`.
#'
#' @return The input list with names normalised to the internal slot
#'   names (`B`, `W`, `phy`, `spde`). Element order is preserved.
#'   `NULL` input returns `NULL`.
#'
#' @keywords internal
#' @noRd
.normalise_lambda_constraint_names <- function(x) {
  if (is.null(x)) return(x)
  if (!is.list(x))
    cli::cli_abort(
      "{.code lambda_constraint} must be a list (got {.cls {class(x)}})."
    )
  nm <- names(x)
  if (length(x) > 0L && (is.null(nm) || any(nm == "")))
    cli::cli_abort(
      "Every element of {.code lambda_constraint} must be named (e.g. {.code list(unit = M)})."
    )

  canonical_to_internal <- c(unit = "B", unit_obs = "W",
                             phy  = "phy", spde = "spde")
  legacy_to_canonical   <- c(B = "unit", W = "unit_obs")

  for (i in seq_along(nm)) {
    n <- nm[i]
    if (n %in% names(legacy_to_canonical)) {
      ## Legacy alias supplied directly: warn once per session, keep
      ## the (legacy = internal) name unchanged so consumption code
      ## continues to read `$B` / `$W`.
      new_name <- legacy_to_canonical[[n]]
      opt_key  <- paste0("gllvmTMB.warned_lambda_constraint_", n)
      if (!isTRUE(getOption(opt_key))) {
        cli::cli_warn(
          c(
            "{.code lambda_constraint = list({n} = ...)} is deprecated as of gllvmTMB 0.2.0.",
            i = "Use {.code lambda_constraint = list({new_name} = ...)} instead.",
            i = paste0("The canonical names match the {.fun gllvmTMB} ",
                       "argument names {.code unit}, {.code unit_obs}. ",
                       "The legacy alias still works.")
          ),
          class = "lifecycle_warning_deprecated"
        )
        options(stats::setNames(list(TRUE), opt_key))
      }
    } else if (n %in% names(canonical_to_internal)) {
      ## Canonical user-facing name: translate to internal slot.
      nm[i] <- canonical_to_internal[[n]]
    } else {
      cli::cli_abort(
        c(
          "Unknown element name in {.code lambda_constraint}: {.val {n}}.",
          i = "Recognised names: {.code {names(canonical_to_internal)}}."
        )
      )
    }
  }
  names(x) <- nm
  x
}
