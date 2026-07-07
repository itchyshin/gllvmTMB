## Sparse phylogenetic precision (A^{-1}) built directly from an ape `phylo`
## tree -- no MCMCglmm dependency. Deterministic branch-length construction
## (Hadfield & Nakagawa 2010; Felsenstein contrasts): each edge contributes
## 1/edge_length on its child node, with parent/child cross-terms, giving the
## same sparse A^{-1} as MCMCglmm::inverseA(tree)$Ainv but with only `ape` +
## `Matrix`. Replaces the MCMCglmm::inverseA call on the phylo_tree path
## (R/fit-multi.R).
##
## PROVENANCE: ported from drmTMB (R/phylo-utils.R, drm_phylo_augmented_precision
## and its validators phylo_node_depths / validate_phylo_tree /
## validate_phylo_species / phylo_augmented_node_labels), the univariate sister
## package, which never depended on MCMCglmm. See inst/COPYRIGHTS. Kept close to
## the drmTMB source so the two stay easy to reconcile.

#' @keywords internal
#' @noRd
.gllvm_validate_phylo_species <- function(species, tip_label) {
  if (is.null(species)) {
    return(NULL)
  }
  species <- as.character(species)
  if (length(species) == 0L) {
    cli::cli_abort("{.arg species} must contain at least one observed species.")
  }
  if (anyNA(species) || any(!nzchar(species))) {
    cli::cli_abort("{.arg species} must not contain missing or empty labels.")
  }
  species_levels <- unique(species)
  missing <- setdiff(species_levels, tip_label)
  if (length(missing) > 0L) {
    cli::cli_abort(c(
      "All observed species must be represented in {.arg tree}.",
      "x" = "Missing tip label{?s}: {.val {missing}}."
    ))
  }
  species_levels
}

#' @keywords internal
#' @noRd
.gllvm_phylo_node_depths <- function(edge, edge_length, n_total, root) {
  children <- split(seq_len(nrow(edge)), edge[, 1L])
  depths <- rep(NA_real_, n_total)
  depths[[root]] <- 0
  stack <- root
  while (length(stack) > 0L) {
    node <- stack[[length(stack)]]
    stack <- stack[-length(stack)]
    child_edges <- children[[as.character(node)]]
    if (is.null(child_edges)) next
    for (edge_id in child_edges) {
      child <- edge[edge_id, 2L]
      depths[[child]] <- depths[[node]] + edge_length[[edge_id]]
      stack <- c(stack, child)
    }
  }
  depths
}

#' @keywords internal
#' @noRd
.gllvm_phylo_augmented_node_labels <- function(node_id, tip_label) {
  labels <- paste0("node", node_id)
  tip <- node_id <= length(tip_label)
  labels[tip] <- tip_label[node_id[tip]]
  labels
}

#' @keywords internal
#' @noRd
.gllvm_validate_phylo_tree <- function(tree, species = NULL,
                                       tolerance = sqrt(.Machine$double.eps),
                                       require_ultrametric = TRUE) {
  if (!inherits(tree, "phylo")) {
    cli::cli_abort(c(
      "{.arg tree} must be a phylogeny object.",
      "x" = "Use an object with class {.cls phylo}, branch lengths, and tip labels."
    ))
  }
  if (!is.list(tree)) {
    cli::cli_abort("{.arg tree} must be a list-like {.cls phylo} object.")
  }
  edge <- tree$edge
  edge_length <- tree$edge.length
  tip_label <- tree$tip.label
  n_node <- tree$Nnode
  if (!is.character(tip_label) || length(tip_label) < 2L ||
        anyNA(tip_label) || any(!nzchar(tip_label))) {
    cli::cli_abort("{.arg tree} must contain at least two non-missing tip labels.")
  }
  if (anyDuplicated(tip_label)) {
    duplicate <- tip_label[duplicated(tip_label)][[1L]]
    cli::cli_abort(c(
      "{.arg tree} tip labels must be unique.",
      "x" = "Duplicated tip label: {.val {duplicate}}."
    ))
  }
  n_tip <- length(tip_label)
  if (!is.numeric(n_node) || length(n_node) != 1L || is.na(n_node) ||
        n_node < 1L || n_node != as.integer(n_node)) {
    cli::cli_abort("{.arg tree} must contain a scalar positive integer {.field Nnode}.")
  }
  n_node <- as.integer(n_node)
  n_total <- n_tip + n_node
  if (!is.matrix(edge) || ncol(edge) != 2L || nrow(edge) < 2L ||
        !is.numeric(edge) || anyNA(edge)) {
    cli::cli_abort("{.arg tree$edge} must be a two-column numeric matrix.")
  }
  if (any(edge != as.integer(edge)) || any(edge < 1L) || any(edge > n_total)) {
    cli::cli_abort("{.arg tree$edge} contains invalid node indices.")
  }
  edge <- matrix(as.integer(edge), ncol = 2L)
  if (!is.numeric(edge_length) || length(edge_length) != nrow(edge) ||
        anyNA(edge_length) || any(!is.finite(edge_length))) {
    cli::cli_abort("{.arg tree} must contain finite branch lengths for every edge.")
  }
  if (any(edge_length < 0)) {
    cli::cli_abort("{.arg tree} branch lengths must be non-negative.")
  }
  parent <- edge[, 1L]
  child <- edge[, 2L]
  if (any(parent <= n_tip)) {
    cli::cli_abort("{.arg tree} is invalid: tip nodes cannot be parent nodes.")
  }
  if (anyDuplicated(child)) {
    cli::cli_abort("{.arg tree} is invalid: at least one node has more than one parent.")
  }
  root <- setdiff(unique(parent), child)
  if (length(root) != 1L) {
    cli::cli_abort("{.arg tree} must have exactly one root node.")
  }
  root <- root[[1L]]
  depths <- .gllvm_phylo_node_depths(edge, edge_length, n_total, root)
  if (anyNA(depths)) {
    cli::cli_abort("{.arg tree} must be connected from a single root.")
  }
  tip_depths <- depths[seq_len(n_tip)]
  height <- tip_depths[[1L]]
  scale <- max(1, abs(height), abs(tip_depths))
  is_ultrametric <- max(abs(tip_depths - height)) <= tolerance * scale
  if (require_ultrametric && !is_ultrametric) {
    cli::cli_abort(c(
      "{.arg tree} must be ultrametric.",
      "x" = "Root-to-tip distances differ by more than {.val {tolerance}}."
    ))
  }
  if (any(tip_depths <= 0)) {
    cli::cli_abort("{.arg tree} must have positive root-to-tip height.")
  }
  species_values <- if (is.null(species)) NULL else as.character(species)
  species_levels <- .gllvm_validate_phylo_species(species_values, tip_label)
  species_index <- if (is.null(species_levels)) NULL else match(species_levels, tip_label)
  observation_species_index <- if (is.null(species_levels)) NULL else match(species_values, species_levels)
  list(
    n_tip = n_tip, n_node = n_node, root = root, tip_label = tip_label,
    height = height, is_ultrametric = is_ultrametric, node_depth = depths,
    species_levels = species_levels, species_index = species_index,
    observation_species_index = observation_species_index
  )
}

#' Sparse phylogenetic precision (A^{-1}) from an ape tree, without MCMCglmm
#'
#' Builds the augmented (tips + internal nodes) sparse phylogenetic precision
#' matrix \eqn{A^{-1}} directly from an \pkg{ape} \code{phylo} tree, using only
#' \pkg{ape} and \pkg{Matrix}. This is the deterministic Hadfield-Nakagawa
#' construction and returns the same \eqn{A^{-1}} as
#' \code{MCMCglmm::inverseA(tree)$Ainv}, so gllvmTMB's \code{phylo_latent(...,
#' tree = ...)} path no longer needs MCMCglmm.
#'
#' @param tree An \pkg{ape} \code{phylo} tree with branch lengths and tip labels.
#' @param species Optional observed species labels (subset of tip labels) used to
#'   build the observation -> node index maps.
#' @param correlation If \code{TRUE} (default) scale to the correlation (unit
#'   root-to-tip height) form, which requires an ultrametric tree; \code{FALSE}
#'   keeps the raw branch-length Brownian precision.
#' @param tolerance Ultrametricity tolerance.
#' @return A list with `precision` (sparse \eqn{A^{-1}}, a `dgCMatrix`),
#'   `log_det_precision` (\eqn{\log\det A^{-1}}), `node_labels`,
#'   `tip_node_index`, `species_node_index`, and related index maps.
#' @keywords internal
#' @noRd
.gllvm_phylo_tree_precision <- function(tree, species = NULL,
                                        correlation = TRUE,
                                        tolerance = sqrt(.Machine$double.eps)) {
  if (!is.logical(correlation) || length(correlation) != 1L || is.na(correlation)) {
    cli::cli_abort("{.arg correlation} must be {.code TRUE} or {.code FALSE}.")
  }
  info <- .gllvm_validate_phylo_tree(tree, species = species, tolerance = tolerance,
                                     require_ultrametric = correlation)
  edge <- matrix(as.integer(tree$edge), ncol = 2L)
  edge_length <- tree$edge.length
  if (any(edge_length <= 0)) {
    cli::cli_abort("{.arg tree} branch lengths must be positive to build sparse precision.")
  }
  n_total <- info$n_tip + info$n_node
  ## Order augmented nodes internal-first, tips-last -- matching the convention
  ## MCMCglmm::inverseA() used ("tips live at the end") that the downstream fit
  ## and its seed-tuned tests were built around. Node ordering never changes the
  ## fitted model (the internal nodes are marginalised), but keeping tips last
  ## makes this builder a numerical drop-in for the previous MCMCglmm path so the
  ## sparse-Cholesky trajectory of fragile fits is unchanged.
  internal_nodes <- setdiff(seq.int(info$n_tip + 1L, n_total), info$root)
  included_nodes <- c(internal_nodes, seq_len(info$n_tip))
  node_index <- integer(n_total)
  node_index[included_nodes] <- seq_along(included_nodes)
  n_aug <- length(included_nodes)

  rows <- integer(0); cols <- integer(0); values <- numeric(0)
  for (edge_id in seq_len(nrow(edge))) {
    parent <- edge[edge_id, 1L]
    child <- edge[edge_id, 2L]
    child_index <- node_index[[child]]
    weight <- 1 / edge_length[[edge_id]]
    rows <- c(rows, child_index); cols <- c(cols, child_index); values <- c(values, weight)
    if (parent != info$root) {
      parent_index <- node_index[[parent]]
      rows <- c(rows, parent_index, parent_index, child_index)
      cols <- c(cols, parent_index, child_index, parent_index)
      values <- c(values, weight, -weight, -weight)
    }
  }
  scale <- if (isTRUE(correlation)) info$height else 1
  node_labels <- .gllvm_phylo_augmented_node_labels(included_nodes, info$tip_label)
  precision <- Matrix::drop0(Matrix::sparseMatrix(
    i = rows, j = cols, x = scale * values,
    dims = c(n_aug, n_aug), dimnames = list(node_labels, node_labels)
  ))
  tip_node_index <- node_index[seq_len(info$n_tip)]
  names(tip_node_index) <- info$tip_label
  species_node_index <- if (is.null(info$species_index)) {
    NULL
  } else {
    out <- tip_node_index[info$species_index]
    names(out) <- info$species_levels
    out
  }
  list(
    precision = precision,
    log_det_precision = n_aug * log(scale) - sum(log(edge_length)),
    correlation = isTRUE(correlation), scale = scale,
    node_id = included_nodes, node_index = node_index, node_labels = node_labels,
    tip_label = info$tip_label, tip_node_index = tip_node_index,
    species_levels = info$species_levels, species_tip_index = info$species_index,
    species_node_index = species_node_index,
    observation_species_index = info$observation_species_index,
    root = info$root, height = info$height
  )
}
