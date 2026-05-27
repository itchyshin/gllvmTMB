## Builder for a confirmatory `lambda_constraint` matrix from
## functional-group membership. The intended user is an ecologist who
## arrives with the prior hypothesis "species in group A respond to
## gradient 1, species in group B respond to gradient 2, ..." and wants
## to convert that into the pinned-Lambda matrix that `gllvmTMB()`
## expects in its `lambda_constraint` argument.
##
## This is the biology-aware companion to `suggest_lambda_constraint()`.
## `suggest_lambda_constraint()` returns a minimal *statistical*
## identification scaffold (one of three conventions). This function
## returns the full *biological* constraint matrix (group->axis +
## per-axis anchors) in one call.

#' Build a confirmatory `lambda_constraint` matrix from group membership
#'
#' Construct the `n_species` by `d` confirmatory loading-constraint matrix
#' `M` from a discrete functional-group hypothesis. Each named group is
#' pinned to load on a specific latent axis (zero on all other axes), and
#' one anchor species per axis is pinned at `+1` to fix the scale. Groups
#' present in `group` but absent from `loads_on` remain free on all axes.
#'
#' This is the recommended starting point for confirmatory JSDMs where
#' prior knowledge takes the form "species in group A respond to
#' gradient 1, species in group B respond to gradient 2, ...". For
#' free-form constraint patterns (psychometric CFA, idiosyncratic
#' species-by-species pins), build the matrix directly; for purely
#' statistical identification scaffolding when no biology is in play,
#' see [suggest_lambda_constraint()].
#'
#' @param species Character vector of species names. Becomes the
#'   rownames of the returned matrix. Must match the species (i.e.
#'   `trait` levels) used in the `gllvmTMB()` fit.
#' @param group Character or factor vector parallel to `species`; the
#'   functional-group code for each species.
#' @param d Integer; number of latent axes (matches the `d` argument
#'   of `latent(0 + trait | site, d = d)`).
#' @param loads_on Named list or named integer vector mapping group code
#'   to latent axis index. For example, `list(A = 1L, B = 2L)` means
#'   species in group A load on axis 1 only (zero on all other axes),
#'   species in group B load on axis 2 only. Groups present in `group`
#'   but absent from `loads_on` remain free on all axes.
#' @param anchors Optional length-`d` character vector; one anchor
#'   species per axis (pinned at `+1`). If `NULL` (the default), anchors
#'   are auto-picked as the first species belonging to the group that
#'   loads on each axis. Use `NA` to skip the anchor on a specific axis.
#' @param axis_labels Optional length-`d` character vector for the
#'   matrix column names. Defaults to `c("LV1", "LV2", ...)`.
#'
#' @return An `length(species)` by `d` numeric matrix with `NA` entries
#'   (estimated), `0` entries (pinned to zero), and `1` entries (pinned
#'   at the anchor), ready to pass to `gllvmTMB()` as
#'   `lambda_constraint = list(unit = M)`.
#'
#' @seealso [suggest_lambda_constraint()] for the lower-level statistical
#'   identification scaffold, [gllvmTMB()] for the `lambda_constraint`
#'   argument.
#'
#' @examples
#' species <- c(paste0("A_", 1:3), paste0("B_", 1:3), paste0("C_", 1:4))
#' group   <- c(rep("A", 3), rep("B", 3), rep("C", 4))
#'
#' # Group A loads on axis 1; group B loads on axis 2; group C is free.
#' M <- confirmatory_lambda(
#'   species  = species,
#'   group    = group,
#'   d        = 2L,
#'   loads_on = list(A = 1L, B = 2L)
#' )
#' M
#'
#' @export
confirmatory_lambda <- function(species,
                                group,
                                d,
                                loads_on,
                                anchors     = NULL,
                                axis_labels = NULL) {

  ## ---- Validation ----
  if (!is.character(species))
    cli::cli_abort("{.code species} must be a character vector.")
  n <- length(species)
  if (n == 0L)
    cli::cli_abort("{.code species} must have at least one element.")
  if (anyDuplicated(species))
    cli::cli_abort("{.code species} must not contain duplicates.")

  if (length(group) != n)
    cli::cli_abort(
      "{.code species} and {.code group} must have the same length (got {n} and {length(group)})."
    )
  group <- as.character(group)

  if (length(d) != 1L || !is.numeric(d) || d != round(d) || d < 1L)
    cli::cli_abort("{.code d} must be a single positive integer.")
  d <- as.integer(d)

  if (!is.list(loads_on) && !is.numeric(loads_on))
    cli::cli_abort(
      "{.code loads_on} must be a named list or named integer vector mapping group -> axis."
    )
  if (is.null(names(loads_on)) || any(names(loads_on) == ""))
    cli::cli_abort("{.code loads_on} must be fully named (group codes as names).")

  if (!is.null(axis_labels) && length(axis_labels) != d)
    cli::cli_abort(
      "{.code axis_labels} must have length {.code d} (got {length(axis_labels)})."
    )

  ## ---- Build matrix ----
  M <- matrix(NA_real_, nrow = n, ncol = d)
  rownames(M) <- species
  colnames(M) <- if (is.null(axis_labels)) paste0("LV", seq_len(d)) else axis_labels

  ## Apply loads_on: group X loads on axis k => zero on all OTHER axes.
  for (grp in names(loads_on)) {
    axis_for_grp <- as.integer(loads_on[[grp]])
    if (any(is.na(axis_for_grp)) ||
        any(axis_for_grp < 1L) || any(axis_for_grp > d))
      cli::cli_abort(
        "Axis index for group {.val {grp}} must be in {.code 1:{d}} (got {.val {axis_for_grp}})."
      )
    members <- which(group == grp)
    if (length(members) == 0L) {
      cli::cli_warn(
        "Group {.val {grp}} has no matching species in {.code group}; skipping."
      )
      next
    }
    other_axes <- setdiff(seq_len(d), axis_for_grp)
    if (length(other_axes) > 0L)
      M[members, other_axes] <- 0
  }

  ## ---- Anchors ----
  if (is.null(anchors)) {
    ## Auto-pick: for each axis with at least one loaded group, anchor
    ## on the first species of the first loaded group.
    anchors <- rep(NA_character_, d)
    for (j in seq_len(d)) {
      groups_on_j <- names(loads_on)[
        vapply(loads_on, function(x) j %in% as.integer(x), logical(1))
      ]
      if (length(groups_on_j) > 0L) {
        first_member <- species[which(group == groups_on_j[1])[1]]
        anchors[j] <- first_member
      }
    }
  } else if (length(anchors) != d) {
    cli::cli_abort(
      "{.code anchors} must have length {.code d} (got {length(anchors)})."
    )
  }

  for (j in seq_len(d)) {
    sp <- anchors[j]
    if (is.na(sp) || identical(sp, "")) next
    if (!sp %in% species)
      cli::cli_abort(
        "Anchor species {.val {sp}} for axis {.val {j}} not in {.code species}."
      )
    M[sp, j] <- 1
  }

  M
}
