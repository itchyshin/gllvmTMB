#' Construct an SPDE mesh for gllvmTMB
#'
#' Construct a triangular mesh and the finite-element quantities used by the
#' `spatial_*()` keywords. The helper uses the public \pkg{fmesher} API; the
#' SPDE/GMRF construction follows Lindgren, Rue, and Lindstrom (2011).
#' Scope: mesh/FEM construction and fit ingestion are covered by focused
#' tests; evidence across the broader spatial-family surface remains
#' partial; directional anisotropy, spatiotemporal fields, barriers, and
#' likelihood changes are rejected from this helper contract.
#'
#' @param data A data frame containing the coordinate columns.
#' @param xy_cols Character names of exactly two finite numeric coordinate
#'   columns in `data`.
#' @param type Mesh construction method: `"cutoff"`, `"kmeans"`, or
#'   `"cutoff_search"`.
#' @param cutoff Minimum vertex separation for `type = "cutoff"`.
#' @param n_knots Number of coordinate centres for `"kmeans"`, or target
#'   number of mesh vertices for `"cutoff_search"`. The latter returns the
#'   closest valid mesh when the exact target is unavailable.
#' @param seed Seed used only while selecting k-means centres. The caller's RNG
#'   state is restored before this function returns.
#' @param mesh Optional pre-built `fmesher` mesh.
#' @param fmesher_func Mesh constructor from \pkg{fmesher}.
#' @param convex,concave Optional non-convex-hull controls passed to
#'   [fmesher::fm_nonconvex_hull()].
#' @param ... Additional arguments passed to `fmesher_func`.
#'
#' @return A `gllvmTMBmesh` object containing `loc_xy`, `xy_cols`, `mesh`, the
#'   finite-element matrices in `spde`, mesh centres in `loc_centers`, and the
#'   observation-to-mesh projection matrix `A_st`.
#' @references Lindgren F, Rue H, Lindstrom J (2011). An explicit link between
#'   Gaussian fields and Gaussian Markov random fields: the SPDE approach.
#'   *Journal of the Royal Statistical Society: Series B*, 73, 423-498.
#' @export
#'
#' @examples
#' set.seed(1)
#' df <- data.frame(X = runif(40), Y = runif(40))
#' mesh <- make_mesh(df, c("X", "Y"), cutoff = 0.1)
#' plot(mesh)
make_mesh <- function(
  data,
  xy_cols,
  type = c("cutoff", "kmeans", "cutoff_search"),
  cutoff,
  n_knots,
  seed = 42,
  mesh = NULL,
  fmesher_func = fmesher::fm_rcdt_2d_inla,
  convex = NULL,
  concave = convex,
  ...
) {
  loc_xy <- .gllvm_mesh_coordinates(data, xy_cols)
  type <- match.arg(type)
  if (!is.function(fmesher_func)) {
    cli::cli_abort("{.arg fmesher_func} must be a mesh-construction function.")
  }

  if (!is.null(mesh)) {
    if (!missing(cutoff) || !missing(n_knots)) {
      cli::cli_abort(
        "Do not supply {.arg cutoff} or {.arg n_knots} with a pre-built {.arg mesh}."
      )
    }
    if (!inherits(mesh, "fm_mesh_2d")) {
      cli::cli_abort("{.arg mesh} must inherit from {.cls fm_mesh_2d}.")
    }
  }

  if (!missing(cutoff) && missing(n_knots)) {
    type <- "cutoff"
  }
  if (is.null(mesh) && identical(type, "cutoff") && missing(cutoff)) {
    cli::cli_abort("{.arg cutoff} is required for {.code type = 'cutoff'}.")
  }
  if (is.null(mesh) && !identical(type, "cutoff") && missing(n_knots)) {
    cli::cli_abort("{.arg n_knots} is required for {.code type = '{type}'}.")
  }
  if (!missing(n_knots) && identical(type, "cutoff")) {
    cli::cli_abort("{.arg n_knots} is not used with {.code type = 'cutoff'}.")
  }
  if (is.null(mesh) && identical(type, "cutoff")) {
    .gllvm_validate_scalar(cutoff, "cutoff", lower = 0, strict = FALSE)
  }
  if (is.null(mesh) && !identical(type, "cutoff")) {
    n_knots <- .gllvm_validate_count(n_knots, "n_knots")
  }
  if (any(abs(loc_xy) > 1e4)) {
    cli::cli_warn(c(
      "Coordinate magnitudes exceed 10,000.",
      "i" = "Use an equal-distance projection and consider kilometres rather than metres."
    ))
  }

  centres <- NULL
  if (is.null(mesh)) {
    mesh_args <- list(...)
    if (!is.null(convex) || !is.null(concave)) {
      mesh_args$boundary <- fmesher::fm_nonconvex_hull(
        loc_xy,
        convex = convex,
        concave = concave
      )
    }
    mesh_args$extend <- list()
    mesh_args$refine <- list()

    if (identical(type, "kmeans")) {
      n_unique <- nrow(unique(loc_xy))
      n_centres <- min(n_knots, n_unique - 1L)
      if (n_centres < 1L) {
        cli::cli_abort(
          "K-means mesh construction needs at least two distinct coordinate rows."
        )
      }
      if (n_centres < n_knots) {
        cli::cli_warn(
          "Reducing {.arg n_knots} to one fewer than the number of coordinate rows."
        )
      }
      centres <- .gllvm_kmeans_centres(loc_xy, n_centres, seed)
      if (is.null(mesh_args$boundary)) {
        mesh_args$boundary <- .gllvm_bounding_boundary(loc_xy)
      }
      mesh <- do.call(fmesher_func, c(list(loc = centres), mesh_args))
    } else if (identical(type, "cutoff")) {
      mesh <- do.call(
        fmesher_func,
        c(list(loc = loc_xy, cutoff = cutoff), mesh_args)
      )
    } else {
      mesh <- .gllvm_mesh_for_knots(
        loc_xy,
        n_knots,
        fmesher_func,
        mesh_args
      )
    }
  }

  .gllvm_new_mesh(loc_xy, xy_cols, mesh, centres)
}

.gllvm_validate_scalar <- function(x, argument, lower = -Inf, strict = FALSE) {
  valid <- is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)
  if (valid) {
    valid <- if (strict) x > lower else x >= lower
  }
  if (!valid) {
    relation <- if (strict) "greater than" else "at least"
    cli::cli_abort(
      "{.arg {argument}} must be one finite number {relation} {lower}."
    )
  }
  as.numeric(x)
}

.gllvm_validate_count <- function(x, argument) {
  value <- .gllvm_validate_scalar(x, argument, lower = 0, strict = TRUE)
  if (value != floor(value)) {
    cli::cli_abort("{.arg {argument}} must be a whole number.")
  }
  as.integer(value)
}

.gllvm_mesh_coordinates <- function(data, xy_cols) {
  if (!is.data.frame(data) || !nrow(data)) {
    cli::cli_abort("{.arg data} must be a non-empty data frame.")
  }
  if (
    !is.character(xy_cols) || length(xy_cols) != 2L || anyDuplicated(xy_cols)
  ) {
    cli::cli_abort(
      "{.arg xy_cols} must name exactly two distinct coordinate columns."
    )
  }
  if (!all(xy_cols %in% names(data))) {
    cli::cli_abort(
      "Every {.arg xy_cols} entry must name a column in {.arg data}."
    )
  }
  loc_xy <- as.matrix(data[, xy_cols, drop = FALSE])
  if (!is.numeric(loc_xy) || any(!is.finite(loc_xy))) {
    cli::cli_abort(
      "Coordinate columns must be numeric and contain no missing or infinite values."
    )
  }
  storage.mode(loc_xy) <- "double"
  loc_xy
}

.gllvm_kmeans_centres <- function(loc_xy, n_centres, seed) {
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit(
    {
      if (had_seed) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    },
    add = TRUE
  )
  set.seed(seed)
  stats::kmeans(loc_xy, centers = n_centres)$centers
}

.gllvm_bounding_boundary <- function(loc_xy) {
  x_range <- range(loc_xy[, 1L])
  y_range <- range(loc_xy[, 2L])
  padding <- max(diff(x_range), diff(y_range)) * 1e-8
  corners <- rbind(
    c(x_range[[1L]] - padding, y_range[[1L]] - padding),
    c(x_range[[2L]] + padding, y_range[[1L]] - padding),
    c(x_range[[2L]] + padding, y_range[[2L]] + padding),
    c(x_range[[1L]] - padding, y_range[[2L]] + padding)
  )
  fmesher::fm_segm(loc = corners, is.bnd = TRUE)
}

.gllvm_mesh_for_knots <- function(loc_xy, n_knots, fmesher_func, mesh_args) {
  centred <- sweep(loc_xy, 2L, colMeans(loc_xy), FUN = "-")
  if (qr(centred)$rank < 2L) {
    cli::cli_abort(
      "{.code type = 'cutoff_search'} needs coordinates spanning two dimensions."
    )
  }
  coordinate_span <- max(
    diff(range(loc_xy[, 1L])),
    diff(range(loc_xy[, 2L]))
  )
  if (!is.finite(coordinate_span) || coordinate_span <= 0) {
    cli::cli_abort(
      "{.code type = 'cutoff_search'} needs coordinates spanning two dimensions."
    )
  }
  lower <- coordinate_span * 1e-8
  upper <- coordinate_span * 2
  best <- NULL
  best_distance <- Inf
  for (iteration in seq_len(32L)) {
    cutoff <- exp((log(lower) + log(upper)) / 2)
    candidate <- tryCatch(
      do.call(fmesher_func, c(list(loc = loc_xy, cutoff = cutoff), mesh_args)),
      error = function(e) NULL
    )
    valid <- .gllvm_mesh_candidate_is_valid(candidate, loc_xy)
    if (valid) {
      distance <- abs(candidate$n - n_knots)
      if (distance < best_distance) {
        best <- candidate
        best_distance <- distance
      }
      if (candidate$n == n_knots) {
        break
      }
      if (candidate$n > n_knots) lower <- cutoff else upper <- cutoff
    } else {
      # Excessive point consolidation can create a degenerate triangulation;
      # a smaller cutoff moves back toward the valid side of the search.
      upper <- cutoff
    }
  }
  if (is.null(best)) {
    cli::cli_abort(
      "Could not construct a valid mesh during {.code type = 'cutoff_search'}."
    )
  }
  best
}

.gllvm_mesh_candidate_is_valid <- function(mesh, loc_xy) {
  if (
    is.null(mesh) ||
      !inherits(mesh, "fm_mesh_2d") ||
      is.null(mesh$n) ||
      length(mesh$n) != 1L ||
      mesh$n < 1L
  ) {
    return(FALSE)
  }
  fem <- tryCatch(fmesher::fm_fem(mesh, order = 2), error = function(e) NULL)
  projection <- tryCatch(
    fmesher::fm_basis(mesh, loc = loc_xy),
    error = function(e) NULL
  )
  if (is.null(fem) || is.null(projection)) {
    return(FALSE)
  }
  matrices <- fem[c("c0", "g1", "g2")]
  if (
    length(matrices) != 3L ||
      any(vapply(
        matrices,
        function(x) !inherits(x, "sparseMatrix"),
        logical(1)
      ))
  ) {
    return(FALSE)
  }
  finite_matrices <- all(vapply(
    matrices,
    function(x) all(is.finite(x@x)),
    logical(1)
  ))
  projection_ok <- inherits(projection, "sparseMatrix") &&
    nrow(projection) == nrow(loc_xy) &&
    ncol(projection) == mesh$n &&
    all(is.finite(projection@x)) &&
    all(abs(Matrix::rowSums(projection) - 1) < 1e-8)
  finite_matrices && projection_ok
}

.gllvm_new_mesh <- function(loc_xy, xy_cols, mesh, centres = NULL) {
  if (is.null(mesh$n) || !is.numeric(mesh$n) || mesh$n < 1L) {
    cli::cli_abort(
      "{.arg mesh} must be an `fmesher` mesh with a positive {.field n}."
    )
  }
  fem <- fmesher::fm_fem(mesh, order = 2)
  projection <- fmesher::fm_basis(mesh, loc = loc_xy)
  if (!all(c("c0", "g1", "g2") %in% names(fem))) {
    cli::cli_abort(
      "`fmesher::fm_fem()` did not return the required c0, g1, and g2 matrices."
    )
  }
  result <- structure(
    list(
      loc_xy = loc_xy,
      xy_cols = xy_cols,
      mesh = mesh,
      spde = fem,
      loc_centers = if (is.null(centres)) NA else centres,
      A_st = projection
    ),
    class = "gllvmTMBmesh"
  )
  .gllvm_validate_mesh(result)
  result
}

.gllvm_validate_mesh <- function(mesh) {
  required <- c("loc_xy", "xy_cols", "mesh", "spde", "A_st")
  missing <- setdiff(required, names(mesh))
  if (length(missing)) {
    cli::cli_abort(
      "Mesh is missing required field{?s}: {paste(missing, collapse = ', ')}."
    )
  }
  if (
    !is.matrix(mesh$loc_xy) ||
      ncol(mesh$loc_xy) != 2L ||
      any(!is.finite(mesh$loc_xy))
  ) {
    cli::cli_abort(
      "Mesh {.field loc_xy} must be a finite two-column numeric matrix."
    )
  }
  if (!is.character(mesh$xy_cols) || length(mesh$xy_cols) != 2L) {
    cli::cli_abort("Mesh {.field xy_cols} must contain two coordinate names.")
  }
  if (
    !inherits(mesh$A_st, "sparseMatrix") ||
      nrow(mesh$A_st) != nrow(mesh$loc_xy) ||
      !all(is.finite(mesh$A_st@x)) ||
      any(abs(Matrix::rowSums(mesh$A_st) - 1) >= 1e-8)
  ) {
    cli::cli_abort(
      "Mesh {.field A_st} must be a sparse projection with one row per coordinate row."
    )
  }
  matrices <- mesh$spde[c("c0", "g1", "g2")]
  if (
    length(matrices) != 3L ||
      any(vapply(matrices, is.null, logical(1))) ||
      any(vapply(
        matrices,
        function(x) !inherits(x, "sparseMatrix"),
        logical(1)
      ))
  ) {
    cli::cli_abort(
      "Mesh {.field spde} must contain sparse c0, g1, and g2 matrices."
    )
  }
  dimensions <- vapply(matrices, nrow, integer(1))
  invalid_matrices <- vapply(
    matrices,
    function(x) {
      ncol(x) != nrow(x) || !all(is.finite(x@x))
    },
    logical(1)
  )
  if (
    length(unique(dimensions)) != 1L ||
      ncol(mesh$A_st) != dimensions[[1]] ||
      any(invalid_matrices)
  ) {
    cli::cli_abort(
      paste(
        "Mesh finite-element matrices must be square, finite, and mutually",
        "conformable with the projection."
      )
    )
  }
  invisible(mesh)
}

.gllvm_normalize_mesh <- function(mesh, warn = TRUE) {
  legacy <- inherits(mesh, "sdmTMBmesh") && !inherits(mesh, "gllvmTMBmesh")
  if (legacy && isTRUE(warn)) {
    lifecycle::deprecate_warn(
      when = "0.6.1",
      what = "gllvmTMB(mesh = 'must be a gllvmTMBmesh object')",
      details = paste(
        "Legacy sdmTMBmesh objects are converted temporarily.",
        "Create new meshes with gllvmTMB::make_mesh()."
      )
    )
  }
  if (legacy) {
    class(mesh) <- unique(c("gllvmTMBmesh", setdiff(class(mesh), "sdmTMBmesh")))
    mesh$sdm_spatial_id <- NULL
  }
  if (!inherits(mesh, "gllvmTMBmesh")) {
    cli::cli_abort("Pass {.arg mesh} as a result of {.fn make_mesh}.")
  }
  .gllvm_validate_mesh(mesh)
  mesh
}

#' Plot a gllvmTMB SPDE mesh
#'
#' Draw mesh edges and the observed locations. This is the plot method for
#' meshes created by [make_mesh()].
#'
#' @param x A `gllvmTMBmesh` created by [make_mesh()].
#' @param ... Passed to [graphics::plot()].
#' @return Invisibly returns `x` after drawing mesh edges, observations, and
#'   optional k-means centres.
#' @name plot.gllvmTMBmesh
#' @export
plot.gllvmTMBmesh <- function(x, ...) {
  .gllvm_validate_mesh(x)
  graphics::plot(x$mesh, main = NA, edge.color = "grey60", asp = 1, ...)
  graphics::points(x$loc_xy, pch = 21, cex = 0.3, col = "#00000080")
  if (is.matrix(x$loc_centers)) {
    graphics::points(x$loc_centers, pch = 20, col = "red")
  }
  invisible(x)
}

#' @rdname plot.gllvmTMBmesh
#' @details `plot.sdmTMBmesh()` is a temporary legacy compatibility method. New
#'   meshes have class `gllvmTMBmesh` and should be plotted with
#'   `plot.gllvmTMBmesh()`.
#' @export
plot.sdmTMBmesh <- function(x, ...) {
  lifecycle::deprecate_warn(
    when = "0.6.1",
    what = "plot.sdmTMBmesh()",
    with = "plot.gllvmTMBmesh()"
  )
  x <- .gllvm_normalize_mesh(x, warn = FALSE)
  plot.gllvmTMBmesh(x, ...)
}
