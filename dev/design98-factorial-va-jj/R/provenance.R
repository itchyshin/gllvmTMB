d98_sha256_raw <- function(x) {
  stopifnot(is.raw(x))
  digest::digest(x, algo = "sha256", serialize = FALSE)
}

d98_sha256_file <- function(path) {
  stopifnot(length(path) == 1L, !is.na(path))
  if (!file.exists(path) || dir.exists(path)) {
    return(NA_character_)
  }
  d98_sha256_raw(readBin(path, what = "raw", n = file.info(path)$size))
}

d98_rel_path <- function(path, root = ".") {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(root, "/")
  if (!startsWith(path, prefix)) {
    stop("Path is outside the Design-98 repository root: ", path)
  }
  substring(path, nchar(prefix) + 1L)
}

d98_prior_design_roots <- function(root = ".") {
  file.path(
    root,
    c(
      "docs/design/72-variational-approximation-feasibility.md",
      "docs/design/85-highdim-nongaussian-va-formal-contract.md",
      "docs/design/95-free-jj-variational-arc.md",
      "docs/design/96-jj-recovery-smoke.md",
      "docs/design/97-fullcov-jj-discrimination.md",
      "docs/dev-log/after-task/2026-07-23-design95-free-jj-prototype.md",
      "docs/dev-log/after-task/2026-07-24-design96-jj-recovery-smoke-stop.md",
      "docs/dev-log/after-task/2026-07-24-design97-fullcov-jj-smoke-stop.md",
      "docs/dev-log/handover/2026-07-24-codex-handover-design97.md",
      "dev/design95-free-jj-va",
      "dev/design96-jj-recovery",
      "dev/design97-fullcov-jj"
    )
  )
}

d98_expand_inventory_paths <- function(paths, root = ".") {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  paths <- unique(normalizePath(paths, winslash = "/", mustWork = FALSE))
  files <- unlist(
    lapply(paths, function(path) {
      if (!file.exists(path)) {
        return(path)
      }
      if (!dir.exists(path)) {
        return(path)
      }
      sort(list.files(
        path,
        recursive = TRUE,
        full.names = TRUE,
        all.files = TRUE,
        no.. = TRUE
      ))
    }),
    use.names = FALSE
  )
  sort(unique(vapply(files, d98_rel_path, character(1), root = root)))
}

d98_file_inventory <- function(paths, root = ".") {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  relative <- d98_expand_inventory_paths(paths, root = root)
  absolute <- file.path(root, relative)
  exists <- file.exists(absolute) & !dir.exists(absolute)
  data.frame(
    path = relative,
    exists = exists,
    sha256 = vapply(absolute, d98_sha256_file, character(1)),
    stringsAsFactors = FALSE
  )
}

d98_prior_design_inventory <- function(root = ".") {
  d98_file_inventory(d98_prior_design_roots(root), root = root)
}

d98_assert_same_inventory <- function(baseline, current) {
  required <- c("path", "exists", "sha256")
  if (
    !identical(names(baseline), required) ||
      !identical(names(current), required)
  ) {
    stop("Inventory schema must be path, exists, sha256")
  }
  baseline <- baseline[order(baseline$path), required, drop = FALSE]
  current <- current[order(current$path), required, drop = FALSE]
  if (!identical(baseline, current)) {
    stop("Prior immutable-path inventory changed")
  }
  invisible(TRUE)
}

d98_gh_checksum <- function(gh) {
  if (!is.list(gh) || !identical(sort(names(gh)), c("w", "z"))) {
    stop("GH rule must be a list with z and w")
  }
  z <- as.numeric(gh$z)
  w <- as.numeric(gh$w)
  if (
    !length(z) ||
      length(z) != length(w) ||
      any(!is.finite(z)) ||
      any(!is.finite(w)) ||
      any(w < 0) ||
      abs(sum(w) - 1) > 1e-12
  ) {
    stop("GH rule must have finite nodes and nonnegative normalized weights")
  }
  list(
    order = length(z),
    node_sha256 = d98_sha256_raw(serialize(z, NULL, version = 2)),
    weight_sha256 = d98_sha256_raw(serialize(w, NULL, version = 2)),
    weight_sum = sum(w)
  )
}

d98_standard_normal_gh <- function(order) {
  order <- as.integer(order)
  if (length(order) != 1L || is.na(order) || order < 1L) {
    stop("GH order must be one positive integer")
  }
  if (order == 1L) {
    return(list(z = 0, w = 1))
  }
  index <- seq_len(order - 1L)
  jacobi <- matrix(0, nrow = order, ncol = order)
  jacobi[cbind(index, index + 1L)] <- sqrt(index / 2)
  jacobi[cbind(index + 1L, index)] <- sqrt(index / 2)
  decomposition <- eigen(jacobi, symmetric = TRUE)
  list(
    z = sqrt(2) * decomposition$values,
    w = decomposition$vectors[1L, ]^2
  )
}

d98_gh_checksums <- function(orders = c(31L, 41L, 61L), gh_rule) {
  stopifnot(is.function(gh_rule), all(orders > 0), !anyDuplicated(orders))
  out <- lapply(as.integer(orders), function(order) {
    d98_gh_checksum(gh_rule(order))
  })
  names(out) <- as.character(orders)
  out
}

d98_package_version <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(NA_character_)
  }
  as.character(utils::packageVersion(package))
}

d98_git_value <- function(args, root = ".") {
  out <- suppressWarnings(system2(
    "git",
    c("-C", normalizePath(root), args),
    stdout = TRUE,
    stderr = FALSE
  ))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    return(NA_character_)
  }
  paste(out, collapse = "\n")
}

d98_git_is_ancestor <- function(ancestor, descendant = "HEAD", root = ".") {
  status <- suppressWarnings(system2(
    "git",
    c(
      "-C",
      normalizePath(root),
      "merge-base",
      "--is-ancestor",
      ancestor,
      descendant
    ),
    stdout = FALSE,
    stderr = FALSE
  ))
  identical(status, 0L)
}

d98_r_config <- function(key) {
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "config", key),
    stdout = TRUE,
    stderr = FALSE
  ))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    return(NA_character_)
  }
  paste(out, collapse = "\n")
}

d98_design98_source_paths <- function(root = ".") {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  design_root <- file.path(root, "dev", "design98-factorial-va-jj")
  design_files <- list.files(
    design_root,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    no.. = TRUE
  )
  design_files <- design_files[!dir.exists(design_files)]
  design_files <- design_files[
    !startsWith(
      normalizePath(design_files, winslash = "/", mustWork = FALSE),
      paste0(
        normalizePath(
          file.path(design_root, "results"),
          winslash = "/",
          mustWork = FALSE
        ),
        "/"
      )
    )
  ]
  sort(c(
    "docs/design/98-factorial-va-jj-discriminator.md",
    vapply(design_files, d98_rel_path, character(1), root = root)
  ))
}

d98_manifest_metadata <- function(
  uuid,
  source_paths,
  gh_checksums,
  root = ".",
  expected_base_commit = "7a725c5e",
  contract_path = "docs/design/98-factorial-va-jj-discriminator.md"
) {
  stopifnot(
    length(uuid) == 1L,
    nzchar(uuid),
    is.character(source_paths),
    is.list(gh_checksums),
    length(expected_base_commit) == 1L,
    length(contract_path) == 1L
  )
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  source_head <- d98_git_value(c("rev-parse", "HEAD"), root = root)
  if (!d98_git_is_ancestor(expected_base_commit, source_head, root = root)) {
    stop(
      "Design-98 source head ",
      source_head,
      " does not descend from declared base ",
      expected_base_commit
    )
  }
  contract_absolute <- file.path(root, contract_path)
  if (!file.exists(contract_absolute)) {
    stop("Missing Design-98 contract: ", contract_path)
  }
  list(
    design = 98L,
    uuid = uuid,
    base_commit = expected_base_commit,
    source_head = source_head,
    contract_path = d98_rel_path(contract_absolute, root = root),
    contract_sha256 = d98_sha256_file(contract_absolute),
    git_status_porcelain = d98_git_value(
      c("status", "--porcelain"),
      root = root
    ),
    source_inventory = d98_file_inventory(
      file.path(root, source_paths),
      root = root
    ),
    gh_checksums = gh_checksums,
    versions = list(
      R = R.version.string,
      TMB = d98_package_version("TMB"),
      compiler = R.version$compiler,
      CXX = d98_r_config("CXX"),
      CXXFLAGS = d98_r_config("CXXFLAGS"),
      platform = R.version$platform,
      os = Sys.info()[["sysname"]]
    ),
    rng_kind = RNGkind()
  )
}
