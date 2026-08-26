## Pure seed-registry contract for the CI-08--CI-15 calibration programme.
## This file expands and checks reservations only; it never simulates or fits.

ic_read_seed_registry <- function(path) {
  out <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c(
    "packet",
    "n_cells",
    "n_sim",
    "rep_start",
    "rep_end",
    "seed_base",
    "seed_formula",
    "min_seed",
    "max_seed",
    "target_sharing",
    "status",
    "collision_status"
  )
  if (!all(required %in% names(out))) {
    stop("seed registry is missing required columns", call. = FALSE)
  }
  if (
    !setequal(
      out$packet,
      c("PVT-02", "CI09", "CI10", "CI13", "CI14", "CI15")
    ) ||
      anyDuplicated(out$packet)
  ) {
    stop(
      "seed registry must contain each frozen packet exactly once",
      call. = FALSE
    )
  }
  out
}

.ic_seed_for <- function(packet, seed_base, cell_id, rep) {
  if (identical(packet, "PVT-02")) {
    return(as.integer(seed_base + rep))
  }
  if (identical(packet, "CI10")) {
    return(as.integer(
      (seed_base %% 100000L) + 1000003L * (cell_id %% 997L) + rep
    ))
  }
  as.integer(seed_base + cell_id * 10000L + rep)
}

.ic_expected_formula <- function(packet, seed_base) {
  if (identical(packet, "PVT-02")) {
    return(sprintf("seed = %d + replicate_id", as.integer(seed_base)))
  }
  if (identical(packet, "CI10")) {
    return(sprintf(
      ".xfc_rep_seed(%d; cell_id; local_rep)",
      as.integer(seed_base)
    ))
  }
  sprintf("seed = %d + cell_id * 10000 + local_rep", as.integer(seed_base))
}

ic_expand_seed_registry <- function(registry) {
  pieces <- lapply(seq_len(nrow(registry)), function(i) {
    row <- registry[i, , drop = FALSE]
    cells <- seq_len(as.integer(row$n_cells))
    reps <- seq.int(as.integer(row$rep_start), as.integer(row$rep_end))
    if (length(reps) != as.integer(row$n_sim)) {
      stop("seed registry replicate range does not equal n_sim", call. = FALSE)
    }
    ids <- expand.grid(
      cell_id = cells,
      rep = reps,
      KEEP.OUT.ATTRS = FALSE,
      stringsAsFactors = FALSE
    )
    ids$packet <- row$packet
    ids$seed <- .ic_seed_for(
      row$packet,
      as.integer(row$seed_base),
      as.integer(ids$cell_id),
      as.integer(ids$rep)
    )
    ids[, c("packet", "cell_id", "rep", "seed")]
  })
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  out
}

ic_validate_seed_registry <- function(
  registry,
  expanded = ic_expand_seed_registry(registry)
) {
  expected_shape <- data.frame(
    packet = c("PVT-02", "CI09", "CI10", "CI13", "CI14", "CI15"),
    n_cells = c(1L, 6L, 18L, 4L, 2L, 4L),
    n_sim = rep(5000L, 6L),
    rep_start = c(50001L, rep(1L, 5L)),
    rep_end = c(55000L, rep(5000L, 5L)),
    stringsAsFactors = FALSE
  )
  aligned <- registry[
    match(expected_shape$packet, registry$packet),
    ,
    drop = FALSE
  ]
  for (nm in c("n_cells", "n_sim", "rep_start", "rep_end")) {
    if (!identical(as.integer(aligned[[nm]]), expected_shape[[nm]])) {
      stop(
        "seed registry does not match the frozen campaign shape",
        call. = FALSE
      )
    }
  }
  formulas <- mapply(
    .ic_expected_formula,
    registry$packet,
    registry$seed_base,
    USE.NAMES = FALSE
  )
  if (!identical(registry$seed_formula, formulas)) {
    stop(
      "seed registry formula text does not match executable arithmetic",
      call. = FALSE
    )
  }
  expected_n <- sum(as.integer(registry$n_cells) * as.integer(registry$n_sim))
  if (
    nrow(expanded) != expected_n ||
      anyDuplicated(expanded[c("packet", "cell_id", "rep")])
  ) {
    stop(
      "seed registry expansion is incomplete or duplicates outer identities",
      call. = FALSE
    )
  }
  if (
    anyNA(expanded$seed) ||
      any(expanded$seed < 1L) ||
      any(expanded$seed > .Machine$integer.max)
  ) {
    stop("expanded seeds must be positive R integers", call. = FALSE)
  }
  if (anyDuplicated(expanded$seed)) {
    stop("seed collision across calibration packets", call. = FALSE)
  }
  observed_bounds <- do.call(
    rbind,
    lapply(split(expanded, expanded$packet), function(x) {
      data.frame(
        packet = x$packet[[1L]],
        min_seed = min(x$seed),
        max_seed = max(x$seed)
      )
    })
  )
  observed_bounds <- observed_bounds[
    match(registry$packet, observed_bounds$packet),
  ]
  if (
    !identical(
      as.integer(registry$min_seed),
      as.integer(observed_bounds$min_seed)
    ) ||
      !identical(
        as.integer(registry$max_seed),
        as.integer(observed_bounds$max_seed)
      )
  ) {
    stop("seed registry bounds do not match expanded arithmetic", call. = FALSE)
  }
  list(
    disjoint = TRUE,
    n_planned = nrow(expanded),
    n_unique = length(unique(expanded$seed)),
    bounds = observed_bounds
  )
}

ic_collect_historical_seeds <- function(paths, exclude_paths = character()) {
  paths <- unique(paths[file.exists(paths)])
  exclude_paths <- unique(as.character(exclude_paths))
  paths <- setdiff(paths, exclude_paths)
  pieces <- lapply(paths, function(path) {
    header <- tryCatch(
      names(utils::read.csv(path, nrows = 0L, check.names = FALSE)),
      error = function(e) character()
    )
    seed_cols <- header[header == "seed" | grepl("_seed$", header)]
    seed_cols <- setdiff(seed_cols, c("seed_base", "random_seed"))
    if (!length(seed_cols)) {
      return(NULL)
    }
    values <- tryCatch(
      data.table::fread(path, select = seed_cols, showProgress = FALSE),
      error = function(e) NULL
    )
    if (is.null(values)) {
      return(NULL)
    }
    seeds <- suppressWarnings(as.numeric(unlist(values, use.names = FALSE)))
    seeds <- seeds[
      is.finite(seeds) &
        seeds >= 1 &
        seeds <= .Machine$integer.max &
        seeds == floor(seeds)
    ]
    if (!length(seeds)) {
      return(NULL)
    }
    data.frame(
      seed = as.integer(seeds),
      source = path,
      stringsAsFactors = FALSE
    )
  })
  pieces <- Filter(Negate(is.null), pieces)
  if (!length(pieces)) {
    return(data.frame(
      seed = integer(),
      source = character(),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  unique(out)
}

ic_historical_seed_collisions <- function(planned, historical) {
  if (
    !all(c("packet", "seed") %in% names(planned)) ||
      !all(c("seed", "source") %in% names(historical))
  ) {
    stop(
      "planned and historical seed tables have incompatible schemas",
      call. = FALSE
    )
  }
  merge(
    unique(planned[c("packet", "seed")]),
    unique(historical[c("seed", "source")]),
    by = "seed",
    all = FALSE,
    sort = TRUE
  )
}
