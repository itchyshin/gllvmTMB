## Boundary helper for the Σ_B/Σ_W -> Σ_unit/Σ_unit_obs rename
## (Design 02 Stage 2). Public extractors accept either the canonical
## user-facing name or the legacy alias; everything downstream of this
## helper sees the legacy/internal slot name.
##
## See `dev/design/02-sigma-naming.md` for the full design.
##
## Mapping
##
##   user types          canonical            legacy / internal slot
##   ------------------  -------------------  -----------------------
##   "unit"              "unit"               "B"
##   "unit_obs"          "unit_obs"           "W"
##   "spatial"           "spatial"            "spde"
##   "Omega"             "Omega"              "Omega"
##   "phy"               "phy"                "phy"     (unchanged)
##   "cluster"           "cluster"            "cluster" (unchanged)
##   "B"     (legacy)    -> deprecate_soft to "unit"     -> "B"
##   "W"     (legacy)    -> deprecate_soft to "unit_obs" -> "W"
##   "spde"  (legacy)    -> deprecate_soft to "spatial"  -> "spde"
##   "total" (legacy)    -> deprecate_soft to "Omega"    -> "Omega"

#' Normalise a `level` / `tier` argument
#'
#' Maps either the canonical user-facing name or a legacy alias to the
#' legacy / internal slot name. Emits a one-shot
#' [lifecycle::deprecate_soft()] when a legacy alias is supplied.
#'
#' @param level Single character; either canonical (`"unit"`,
#'   `"unit_obs"`, `"phy"`, `"spatial"`, `"cluster"`, `"Omega"`) or a
#'   legacy alias (`"B"`, `"W"`, `"spde"`, `"total"`).
#' @param arg_name Name of the calling function's argument
#'   (`"level"` or `"tier"`); used in the deprecation message.
#'
#' @return The legacy / internal slot name. Function bodies that
#'   currently `if (identical(level, "B"))` continue to work unchanged.
#'
#' @keywords internal
#' @noRd
.normalise_level <- function(level, arg_name = "level", .skip_warn = FALSE) {
  if (!is.character(level) || length(level) != 1L)
    return(level)  # vector / non-character — let downstream handle

  ## Canonical names that ARE the legacy/internal already
  if (level %in% c("phy", "cluster")) return(level)

  ## Legacy aliases -> emit one-shot soft deprecation message and
  ## return legacy as-is so the function body stays unchanged.
  ##
  ## We hand-roll the once-per-session caching via an R option rather
  ## than relying on `lifecycle::deprecate_soft()` (whose `what` parser
  ## expects a function-call form like `"fn(arg = )"`, not the
  ## per-value form `"fn(level = \"B\")"` we want here) or
  ## `cli::cli_warn(.frequency = "once")` (whose internal throttle is
  ## not exposed for unit testing). The option-based cache is easy to
  ## reset in tests via `withr::local_options(<key> = NULL)`.
  legacy_to_canonical <- c(B = "unit", W = "unit_obs",
                           spde = "spatial", total = "Omega")
  if (level %in% names(legacy_to_canonical)) {
    new_name <- legacy_to_canonical[[level]]
    opt_key  <- paste0("gllvmTMB.warned_", arg_name, "_", level)
    if (!.skip_warn && !isTRUE(getOption(opt_key))) {
      cli::cli_warn(
        c(
          "{.code {arg_name} = \"{level}\"} is deprecated as of gllvmTMB 0.2.0.",
          i = "Use {.code {arg_name} = \"{new_name}\"} instead.",
          i = paste0("The canonical names match the {.fun gllvmTMB} ",
                     "argument names {.code unit}, {.code unit_obs}, ",
                     "{.code cluster}. Legacy alias still works.")
        ),
        class = "lifecycle_warning_deprecated"
      )
      options(stats::setNames(list(TRUE), opt_key))
    }
    return(level)
  }

  ## Canonical names that need translation -> internal slot
  canonical_to_internal <- c(unit = "B", unit_obs = "W",
                             spatial = "spde", Omega = "Omega")
  if (level %in% names(canonical_to_internal)) {
    return(unname(canonical_to_internal[[level]]))
  }

  ## Unknown; let downstream handle (typically match.arg already
  ## rejected it).
  level
}

.canonical_level_name <- function(level) {
  if (!is.character(level) || length(level) != 1L) return(level)
  internal_to_canonical <- c(B = "unit", W = "unit_obs",
                             spde = "spatial", total = "Omega")
  if (level %in% names(internal_to_canonical)) {
    return(unname(internal_to_canonical[[level]]))
  }
  level
}
