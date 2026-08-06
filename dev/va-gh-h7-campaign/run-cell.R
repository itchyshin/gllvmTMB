#!/usr/bin/env Rscript

## Design 110 Arc-2 campaign driver. VA evaluations deliberately use the
## installed package's private research engine; Laplace remains the public
## comparator. Every run-mode entry point validates Gate-E and runtime receipts.

`%||%` <- function(x, y) if (is.null(x) || !length(x)) y else x

parse_cli <- function(x = commandArgs(trailingOnly = TRUE)) {
  out <- list()
  for (item in x) {
    if (!grepl("^--[^=]+=", item)) {
      stop("arguments must use --key=value: ", item, call. = FALSE)
    }
    pair <- strsplit(sub("^--", "", item), "=", fixed = TRUE)[[1L]]
    key <- pair[[1L]]
    if (key %in% names(out)) stop("duplicate CLI flag: --", key, call. = FALSE)
    out[[key]] <- paste(pair[-1L], collapse = "=")
  }
  out
}

normalise_cli <- function(x) {
  aliases <- c(
    cell = "cells", seed = "seeds", H = "Hs", q = "qs",
    estimator = "estimators"
  )
  allowed <- c(
    "mode", "plan", "output-dir", "gate-receipt", "runtime-manifest",
    "preflight-receipt", "gate-report", "package-lib", "build-root",
    "task-index", "cells", "seeds", "Hs", "qs", "estimators", "n", "p",
    names(aliases)
  )
  unknown <- setdiff(names(x), allowed)
  if (length(unknown)) {
    stop("unknown CLI flag(s): ", paste0("--", unknown, collapse = ", "),
         call. = FALSE)
  }
  for (alias in names(aliases)) {
    canonical <- unname(aliases[[alias]])
    if (!is.null(x[[alias]])) {
      if (!is.null(x[[canonical]])) {
        stop("use only one of --", alias, " and --", canonical, call. = FALSE)
      }
      x[[canonical]] <- x[[alias]]
      x[[alias]] <- NULL
    }
  }
  x
}

cli <- normalise_cli(parse_cli())
get_arg <- function(name, env, default = NULL) {
  value <- cli[[name]]
  if (is.null(value)) value <- Sys.getenv(env, unset = default %||% "")
  if (length(value) == 1L && !nzchar(value)) default else value
}

script_flag <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
script_path <- if (length(script_flag)) {
  sub("^--file=", "", script_flag[[1L]])
} else {
  "dev/va-gh-h7-campaign/run-cell.R"
}
repo_root <- normalizePath(
  file.path(dirname(script_path), "..", ".."), mustWork = TRUE
)

as_int <- function(x, name, min = 1L) {
  if (length(x) != 1L || is.na(x) || !grepl("^-?[0-9]+$", as.character(x))) {
    stop(name, " must be integer >= ", min, call. = FALSE)
  }
  value <- suppressWarnings(as.integer(x))
  if (length(value) != 1L || is.na(value) || value < min) {
    stop(name, " must be integer >= ", min, call. = FALSE)
  }
  value
}

split_values <- function(x, type = c("character", "integer")) {
  type <- match.arg(type)
  values <- strsplit(x, ",", fixed = TRUE)[[1L]]
  if (type == "integer") as.integer(values) else values
}

cells <- data.frame(
  cell = c(
    "gaussian_identity", "binomial_logit", "binomial_probit",
    "binomial_cloglog", "poisson_log", "lognormal_log", "gamma_log",
    "nbinom2_log", "tweedie_log", "beta_logit", "betabinomial_logit",
    "student_identity", "truncated_poisson_log",
    "truncated_nbinom2_log", "delta_lognormal_log", "delta_gamma_log",
    "ordinal_probit", "nbinom1_log"
  ),
  family_id = c(0L, 1L, 1L, 1L, 2:15),
  link = c(
    "identity", "logit", "probit", "cloglog", rep("log", 5L),
    "logit", "logit", "identity", rep("log", 4L), "probit", "log"
  ),
  link_id = c(0L, 0L, 1L, 2L, rep(0L, 14L)),
  route = c(
    "exact", "gh", "gh", "gh", "exact", "exact", "exact",
    "gh", "gh", "gh", "gh", "gh", "gh", "gh", "hybrid",
    "hybrid", "gh", "gh"
  ),
  stringsAsFactors = FALSE
)
stopifnot(
  nrow(cells) == 18L,
  setequal(cells$family_id, 0:15),
  sum(cells$route == "exact") == 4L
)

parse_seeds <- function(x) {
  if (grepl(":", x, fixed = TRUE)) {
    bounds <- as.integer(strsplit(x, ":", fixed = TRUE)[[1L]])
    if (length(bounds) != 2L || anyNA(bounds) || bounds[[2L]] < bounds[[1L]]) {
      stop("bad seed range", call. = FALSE)
    }
    return(seq.int(bounds[[1L]], bounds[[2L]]))
  }
  split_values(x, "integer")
}

cross_conditions <- function(selected, seeds, qs, n, p) {
  expand.grid(
    cell = selected, seed = seeds, q = qs, n = n, p = p,
    stringsAsFactors = FALSE
  )
}

make_plan <- function() {
  unknown_cli <- setdiff(
    names(cli),
    c(
      "mode", "plan", "output-dir", "gate-receipt", "runtime-manifest",
      "preflight-receipt", "gate-report", "package-lib", "build-root",
      "task-index", "cells", "seeds", "Hs", "qs", "estimators", "n", "p"
    )
  )
  if (length(unknown_cli)) {
    stop("unknown CLI flag(s): ", paste0("--", unknown_cli, collapse = ", "),
         call. = FALSE)
  }
  selected <- get_arg("cells", "VA_CELLS", "all")
  selected <- if (identical(selected, "all")) cells$cell else split_values(selected)
  unknown <- setdiff(selected, cells$cell)
  if (length(unknown)) stop("unknown cells: ", paste(unknown, collapse = ","))

  seeds <- parse_seeds(get_arg("seeds", "VA_SEEDS", "1:30"))
  orders <- split_values(get_arg("Hs", "VA_HS", "5,7,9,15,61"), "integer")
  qs <- split_values(get_arg("qs", "VA_QS", "2,5"), "integer")
  estimators <- split_values(
    get_arg("estimators", "VA_ESTIMATORS", "va,laplace")
  )
  n <- as_int(get_arg("n", "VA_N", "120"), "n", 100L)
  p <- as_int(get_arg("p", "VA_P", "8"), "p", 2L)
  if (anyNA(seeds) || any(seeds < 0L)) stop("seeds must be non-negative integers")
  if (anyNA(orders) || any(orders < 3L | orders %% 2L == 0L)) {
    stop("H values must be odd integers >= 3")
  }
  if (anyNA(qs) || any(qs < 1L) || any(qs > p)) stop("every q must be in 1..p")
  if (!all(estimators %in% c("va", "laplace"))) {
    stop("estimator must be va or laplace")
  }

  base <- merge(
    cross_conditions(selected, seeds, qs, n, p), cells,
    by = "cell", sort = FALSE
  )
  pieces <- list()
  if ("va" %in% estimators) {
    va_exact <- base[base$route == "exact", , drop = FALSE]
    if (nrow(va_exact)) {
      va_exact$H <- 0L
      va_exact$estimator <- "va"
      pieces[[length(pieces) + 1L]] <- va_exact
    }
    va_quadrature <- base[base$route != "exact", , drop = FALSE]
    if (nrow(va_quadrature)) {
      va_quadrature <- merge(
        va_quadrature, data.frame(H = orders), by = NULL, sort = FALSE
      )
      va_quadrature$estimator <- "va"
      pieces[[length(pieces) + 1L]] <- va_quadrature
    }
  }
  if ("laplace" %in% estimators) {
    laplace <- base
    laplace$H <- 0L
    laplace$estimator <- "laplace"
    pieces[[length(pieces) + 1L]] <- laplace
  }
  if (!length(pieces)) stop("plan has no estimators")

  plan <- do.call(rbind, pieces)
  plan$va_match_laplace_residual_sd <-
    plan$estimator == "va" & plan$family_id %in% c(0L, 3L)
  plan <- plan[order(
    match(plan$cell, cells$cell), plan$seed, plan$q,
    match(plan$estimator, c("va", "laplace")), plan$H
  ), ]
  plan$task_id <- seq_len(nrow(plan))
  plan <- plan[, c(
    "task_id", "cell", "family_id", "link", "link_id", "route",
    "seed", "H", "q", "n", "p", "estimator",
    "va_match_laplace_residual_sd"
  )]
  rownames(plan) <- NULL
  validate_plan(plan)
  plan
}

validate_plan <- function(plan) {
  required <- c(
    "task_id", "cell", "family_id", "link", "link_id", "route",
    "seed", "H", "q", "n", "p", "estimator",
    "va_match_laplace_residual_sd"
  )
  missing <- setdiff(required, names(plan))
  if (length(missing)) stop("plan lacks: ", paste(missing, collapse = ", "))
  if (!nrow(plan)) stop("plan has no tasks")
  integer_columns <- c("task_id", "family_id", "link_id", "seed", "H", "q", "n", "p")
  non_integer <- vapply(integer_columns, function(name) {
    value <- plan[[name]]
    anyNA(value) || any(!is.finite(value)) || any(value != floor(value))
  }, logical(1L))
  if (any(non_integer)) {
    stop("plan columns must contain integers: ",
         paste(integer_columns[non_integer], collapse = ", "))
  }
  if (!identical(as.integer(plan$task_id), seq_len(nrow(plan)))) {
    stop("plan task_id must equal row position 1..nrow(plan)")
  }
  if (anyNA(plan$n) || any(plan$n < 100L)) {
    stop("every plan row must have n >= 100")
  }
  if (anyNA(plan$p) || any(plan$p < 2L) || anyNA(plan$q) ||
      any(plan$q < 1L | plan$q > plan$p)) {
    stop("every plan row must have p >= 2 and q in 1..p")
  }
  if (anyNA(plan$seed) || any(plan$seed < 0L)) {
    stop("every plan seed must be a non-negative integer")
  }
  if (!all(plan$estimator %in% c("va", "laplace"))) {
    stop("every plan estimator must be va or laplace")
  }
  reference <- cells[match(plan$cell, cells$cell), , drop = FALSE]
  if (anyNA(reference$cell) ||
      !identical(as.integer(plan$family_id), reference$family_id) ||
      !identical(as.character(plan$link), reference$link) ||
      !identical(as.integer(plan$link_id), reference$link_id) ||
      !identical(as.character(plan$route), reference$route)) {
    stop("plan cell metadata does not match the canonical 18-cell registry")
  }
  expected_residual_sd <- plan$estimator == "va" & plan$family_id %in% c(0L, 3L)
  if (!identical(as.logical(plan$va_match_laplace_residual_sd),
                 expected_residual_sd)) {
    stop("plan residual-SD matching metadata is inconsistent")
  }
  va_quadrature <- plan$estimator == "va" & plan$route != "exact"
  if (anyNA(plan$H) || any(plan$H[!va_quadrature] != 0L) ||
      any(plan$H[va_quadrature] < 3L | plan$H[va_quadrature] %% 2L == 0L)) {
    stop("plan H must be zero outside quadrature VA and odd >= 3 within it")
  }
  invisible(plan)
}

atomic_save <- function(object, path, writer) {
  if (file.exists(path)) stop("immutable output already exists: ", path)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "."), tmpdir = dirname(path)
  )
  on.exit(unlink(temporary, recursive = TRUE), add = TRUE)
  writer(object, temporary)
  if (!file.rename(temporary, path)) stop("atomic rename failed for ", path)
}

write_plan <- function(plan, path) {
  if (file.exists(path)) {
    old <- read.csv(path, stringsAsFactors = FALSE)
    if (!identical(old, plan)) stop("existing immutable plan differs: ", path)
    message("plan already exists and is identical: ", path)
    return(invisible(path))
  }
  atomic_save(plan, path, function(x, file) {
    write.csv(x, file, row.names = FALSE)
  })
  message("wrote immutable plan: ", path, " (", nrow(plan), " tasks)")
}

file_checksum <- function(path) {
  if (!file.exists(path)) stop("file does not exist: ", path)
  unname(tools::md5sum(path))
}

git_revision <- function(root = repo_root) {
  value <- system2(
    "git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE, stderr = TRUE
  )
  if (length(value) != 1L || !grepl("^[0-9a-f]{40}$", value)) {
    stop("could not resolve a full git revision for ", root)
  }
  value
}

read_single_dcf <- function(path, label) {
  if (is.null(path) || !file.exists(path)) stop(label, " is missing: ", path)
  value <- read.dcf(path)
  if (nrow(value) != 1L) stop(label, " must contain exactly one DCF record")
  as.list(value[1L, , drop = TRUE])
}

validate_gate_report <- function(path) {
  if (!file.exists(path)) stop("Gate-E report is missing: ", path)
  report <- read.csv(path, stringsAsFactors = FALSE)
  required <- c("cell", "status")
  if (!all(required %in% names(report))) {
    stop("Gate-E report must contain cell and status columns")
  }
  verdict <- report[, required, drop = FALSE]
  if (nrow(verdict) != nrow(cells) || anyDuplicated(verdict$cell) ||
      !setequal(verdict$cell, cells$cell)) {
    stop("Gate-E report must contain exactly one verdict for every scalar cell")
  }
  if (anyNA(verdict$status) || !all(verdict$status == "PASS")) {
    failed <- verdict$cell[is.na(verdict$status) | verdict$status != "PASS"]
    stop("Gate-E has non-PASS cells: ", paste(failed, collapse = ", "))
  }
  verdict[match(cells$cell, verdict$cell), , drop = FALSE]
}

gate_template_path <- function(root = repo_root) {
  file.path(root, "inst", "tmb", "gllvmTMB_va_r3.cpp")
}

repo_relative_path <- function(path, root = repo_root) {
  root <- normalizePath(root, mustWork = TRUE)
  path <- normalizePath(path, mustWork = TRUE)
  prefix <- paste0(root, .Platform$file.sep)
  if (!startsWith(path, prefix)) {
    stop("path must be inside the verified checkout: ", path)
  }
  substring(path, nchar(prefix) + 1L)
}

resolve_repo_path <- function(path, root = repo_root) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) ||
      grepl("^(/|[A-Za-z]:[/\\\\])", path)) {
    stop("receipt report_path must be a non-empty repo-relative path")
  }
  resolved <- normalizePath(file.path(root, path), mustWork = TRUE)
  expected <- repo_relative_path(resolved, root)
  if (!identical(expected, path)) {
    stop("receipt report_path is not canonical within the checkout")
  }
  resolved
}

write_gate_receipt <- function(report_path, receipt_path) {
  status <- system2(
    "git", c("-C", repo_root, "status", "--porcelain"),
    stdout = TRUE, stderr = TRUE
  )
  if (length(status)) {
    stop("Gate-E receipt requires a clean checkout; commit the approved state first")
  }
  report <- validate_gate_report(report_path)
  record <- data.frame(
    format_version = "2",
    gate = "Design-110-Gate-E",
    status = "PASS",
    git_revision = git_revision(),
    template_checksum_md5 = file_checksum(gate_template_path()),
    report_path = repo_relative_path(report_path),
    report_checksum_md5 = file_checksum(report_path),
    report_row_count = as.character(nrow(report)),
    passed_cells = paste(report$cell, collapse = ","),
    created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    stringsAsFactors = FALSE
  )
  atomic_save(record, receipt_path, function(x, file) write.dcf(x, file = file))
  message("wrote immutable Gate-E receipt: ", receipt_path)
}

verify_gate_receipt <- function(receipt_path, root = repo_root) {
  receipt <- read_single_dcf(receipt_path, "Gate-E receipt")
  required <- c(
    "format_version", "gate", "status", "git_revision",
    "template_checksum_md5", "report_path", "report_checksum_md5",
    "report_row_count", "passed_cells"
  )
  missing <- setdiff(required, names(receipt))
  if (length(missing)) {
    stop("Gate-E receipt checksum contract lacks: ", paste(missing, collapse = ", "))
  }
  if (!identical(receipt$format_version, "2") ||
      !identical(receipt$gate, "Design-110-Gate-E") ||
      !identical(receipt$status, "PASS")) {
    stop("Gate-E receipt has the wrong format, gate, or status")
  }
  if (!identical(receipt$git_revision, git_revision(root))) {
    stop("Gate-E receipt revision does not match the checkout")
  }
  template <- gate_template_path(root)
  if (!identical(receipt$template_checksum_md5, file_checksum(template))) {
    stop("Gate-E receipt template checksum does not match the checkout")
  }
  report_path <- resolve_repo_path(receipt$report_path, root)
  if (!identical(receipt$report_checksum_md5, file_checksum(report_path))) {
    stop("Gate-E report is missing or its checksum has changed")
  }
  report <- validate_gate_report(report_path)
  if (!identical(receipt$report_row_count, as.character(nrow(report)))) {
    stop("Gate-E receipt report row count has changed")
  }
  passed <- strsplit(receipt$passed_cells, ",", fixed = TRUE)[[1L]]
  if (!identical(passed, report$cell) || !identical(passed, cells$cell)) {
    stop("Gate-E receipt does not bind the ordered 18-cell PASS set")
  }
  invisible(receipt)
}

write_runtime_manifest <- function(
    gate_receipt, package_lib, build_root, manifest_path) {
  gate <- verify_gate_receipt(gate_receipt)
  package_lib <- normalizePath(package_lib, mustWork = TRUE)
  build_root <- normalizePath(build_root, mustWork = TRUE)
  installed_template <- file.path(
    package_lib, "gllvmTMB", "tmb", "gllvmTMB_va_r3.cpp"
  )
  if (!file.exists(installed_template)) {
    stop("installed VA template is missing: ", installed_template)
  }
  if (!identical(file_checksum(installed_template), gate$template_checksum_md5)) {
    stop("installed VA template does not match Gate E")
  }
  record <- data.frame(
    format_version = "2",
    git_revision = gate$git_revision,
    template_checksum_md5 = gate$template_checksum_md5,
    package_lib = package_lib,
    build_root = build_root,
    gate_receipt = normalizePath(gate_receipt, mustWork = TRUE),
    gate_receipt_checksum_md5 = file_checksum(gate_receipt),
    gate_report_checksum_md5 = gate$report_checksum_md5,
    installed_template = normalizePath(installed_template, mustWork = TRUE),
    created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    stringsAsFactors = FALSE
  )
  if (file.exists(manifest_path)) {
    existing <- read_single_dcf(manifest_path, "runtime manifest")
    compare <- setdiff(names(record), "created_utc")
    expected <- as.list(record[1L, compare, drop = TRUE])
    if (!identical(existing[compare], expected)) {
      stop("existing immutable runtime manifest differs: ", manifest_path)
    }
    message("runtime manifest already exists and matches: ", manifest_path)
    return(invisible(existing))
  }
  atomic_save(record, manifest_path, function(x, file) write.dcf(x, file = file))
  message("wrote immutable runtime manifest: ", manifest_path)
}

preflight_spec <- function() {
  list(
    cell = "binomial_logit", seed = "202608061", H = "7", q = "1",
    n = "100", p = "4"
  )
}

verify_runtime <- function(runtime_manifest, gate_receipt, preflight_receipt = NULL) {
  gate <- verify_gate_receipt(gate_receipt)
  runtime <- read_single_dcf(runtime_manifest, "runtime manifest")
  required <- c(
    "format_version", "git_revision", "template_checksum_md5", "package_lib",
    "build_root", "gate_receipt", "gate_receipt_checksum_md5",
    "gate_report_checksum_md5", "installed_template"
  )
  missing <- setdiff(required, names(runtime))
  if (length(missing)) stop("runtime manifest lacks: ", paste(missing, collapse = ", "))
  supplied_gate <- normalizePath(gate_receipt, mustWork = TRUE)
  if (!identical(runtime$format_version, "2") ||
      !identical(normalizePath(runtime$gate_receipt, mustWork = TRUE), supplied_gate) ||
      !identical(runtime$gate_receipt_checksum_md5, file_checksum(supplied_gate)) ||
      !identical(runtime$gate_report_checksum_md5, gate$report_checksum_md5) ||
      !identical(runtime$git_revision, gate$git_revision) ||
      !identical(runtime$template_checksum_md5, gate$template_checksum_md5)) {
    stop("runtime manifest is not bound to the current Gate-E receipt")
  }
  if (!dir.exists(runtime$package_lib) || !dir.exists(runtime$build_root)) {
    stop("runtime package library or shared VA build root is missing")
  }
  expected_template_path <- file.path(
    runtime$package_lib, "gllvmTMB", "tmb", "gllvmTMB_va_r3.cpp"
  )
  if (!file.exists(runtime$installed_template) ||
      !file.exists(expected_template_path)) {
    stop("installed runtime template is missing or changed")
  }
  expected_template <- normalizePath(
    expected_template_path,
    mustWork = TRUE
  )
  if (!identical(normalizePath(runtime$installed_template, mustWork = TRUE),
                 expected_template) ||
      !identical(
        file_checksum(runtime$installed_template), runtime$template_checksum_md5
      )) {
    stop("installed runtime template is missing or changed")
  }
  if (!is.null(preflight_receipt)) {
    preflight <- read_single_dcf(preflight_receipt, "preflight receipt")
    required_preflight <- c(
      "format_version", "status", "runtime_manifest_checksum_md5",
      "gate_receipt_checksum_md5", "git_revision", "template_checksum_md5",
      "cell", "seed", "H", "q", "n", "p", "va_status", "laplace_status"
    )
    spec <- preflight_spec()
    if (!all(required_preflight %in% names(preflight)) ||
        !identical(preflight$format_version, "2") ||
        !identical(preflight$status, "PASS") ||
        !identical(preflight$va_status, "completed") ||
        !identical(preflight$laplace_status, "completed") ||
        !identical(preflight[names(spec)], spec) ||
        !identical(preflight$gate_receipt_checksum_md5,
                   runtime$gate_receipt_checksum_md5) ||
        !identical(preflight$git_revision, runtime$git_revision) ||
        !identical(preflight$template_checksum_md5,
                   runtime$template_checksum_md5) ||
        !identical(
          preflight$runtime_manifest_checksum_md5,
          file_checksum(runtime_manifest)
        )) {
      stop("preflight receipt is incomplete, failed, or bound to another runtime")
    }
  }
  runtime
}

load_campaign_package <- function(runtime) {
  Sys.setenv(GLLVMTMB_VA_R3_BUILD_ROOT = runtime$build_root)
  .libPaths(c(runtime$package_lib, .libPaths()))
  suppressPackageStartupMessages(library(gllvmTMB, character.only = TRUE))
  installed_template <- system.file("tmb", "gllvmTMB_va_r3.cpp", package = "gllvmTMB")
  if (!identical(file_checksum(installed_template), runtime$template_checksum_md5)) {
    stop("loaded package template does not match the runtime manifest")
  }
  invisible(TRUE)
}

invlogit_link <- function(eta, link) {
  switch(
    link,
    logit = plogis(eta),
    probit = pnorm(eta),
    cloglog = -expm1(-exp(eta)),
    stop("unknown binomial link")
  )
}

positive_draw <- function(draw) {
  value <- draw()
  while (any(value <= 0)) {
    bad <- which(value <= 0)
    fresh <- draw()
    value[bad] <- fresh[bad]
  }
  value
}

family_truth <- function(fid, p) {
  one <- function(parameter, value) {
    data.frame(
      parameter = parameter, trait = seq_len(p), truth = rep(value, p),
      stringsAsFactors = FALSE
    )
  }
  switch(
    as.character(fid),
    `0` = one("sigma", 0.70),
    `3` = one("sigma", 0.65),
    `4` = one("shape", 2.50),
    `5` = one("phi", 2.50),
    `6` = rbind(one("phi", 0.80), one("power", 1.50)),
    `7` = one("precision", 8.00),
    `8` = one("precision", 6.00),
    `9` = rbind(one("sigma", 0.80), one("df", 5.00)),
    `11` = one("phi", 2.50),
    `12` = one("sigma", 0.65),
    `13` = one("phi", 0.70),
    `14` = one("cut_increment", 1.00),
    `15` = one("phi", 0.70),
    data.frame(parameter = character(), trait = integer(), truth = numeric())
  )
}

simulate_cell <- function(spec) {
  set.seed(spec$seed)
  n <- spec$n
  p <- spec$p
  q <- spec$q
  if (p < q) stop("p must be >= q")
  Lambda <- matrix(rnorm(p * q, 0, 0.25), p, q)
  for (k in seq_len(q)) {
    if (k > 1L) Lambda[seq_len(k - 1L), k] <- 0
    Lambda[k, k] <- 0.55 + 0.05 * k
  }
  scores <- matrix(rnorm(n * q), n, q)
  beta <- seq(-0.25, 0.25, length.out = p)
  eta <- sweep(scores %*% t(Lambda), 2L, beta, "+")
  nr <- n * p
  fid <- spec$family_id
  n_trials <- 8L
  mu <- exp(eta)
  y <- if (fid == 0L) {
    eta + rnorm(nr, sd = 0.70)
  } else if (fid == 1L) {
    rbinom(nr, n_trials, invlogit_link(eta, spec$link))
  } else if (fid == 2L) {
    rpois(nr, mu)
  } else if (fid == 3L) {
    rlnorm(nr, eta, 0.65)
  } else if (fid == 4L) {
    rgamma(nr, shape = 2.5, scale = mu / 2.5)
  } else if (fid == 5L) {
    rnbinom(nr, size = 2.5, mu = mu)
  } else if (fid == 6L) {
    if (!requireNamespace("tweedie", quietly = TRUE)) {
      stop("the campaign requires the suggested package tweedie")
    }
    tweedie::rtweedie(nr, mu = mu, phi = 0.8, power = 1.5)
  } else if (fid == 7L) {
    rbeta(nr, plogis(eta) * 8, (1 - plogis(eta)) * 8)
  } else if (fid == 8L) {
    rbinom(nr, n_trials, rbeta(nr, plogis(eta) * 6, (1 - plogis(eta)) * 6))
  } else if (fid == 9L) {
    eta + 0.8 * rt(nr, df = 5)
  } else if (fid == 10L) {
    positive_draw(function() rpois(nr, mu))
  } else if (fid == 11L) {
    positive_draw(function() rnbinom(nr, size = 2.5, mu = mu))
  } else if (fid == 12L) {
    rbinom(nr, 1, plogis(eta)) * rlnorm(nr, eta, 0.65)
  } else if (fid == 13L) {
    rbinom(nr, 1, plogis(eta)) *
      rgamma(nr, 1 / 0.7^2, scale = mu * 0.7^2)
  } else if (fid == 14L) {
    ystar <- eta + rnorm(nr)
    1L + (ystar > 0) + (ystar > 1)
  } else if (fid == 15L) {
    rnbinom(nr, size = mu / 0.7, mu = mu)
  } else {
    stop("unsupported family id")
  }

  dat <- data.frame(
    unit = factor(rep(seq_len(n), each = p)),
    trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
    value = as.vector(t(matrix(y, n, p))),
    stringsAsFactors = FALSE
  )
  if (fid == 14L) {
    attempts <- 0L
    represented <- function() {
      all(vapply(split(dat$value, dat$trait), function(x) {
        identical(sort(unique(x)), 1:3)
      }, logical(1L)))
    }
    while (!represented() && attempts < 100L) {
      attempts <- attempts + 1L
      ystar <- eta + matrix(rnorm(nr), n, p)
      dat$value <- as.vector(t(1L + (ystar > 0) + (ystar > 1)))
    }
    if (!represented()) stop("ordinal DGP did not represent all categories")
  }
  if (fid %in% c(1L, 8L)) {
    dat$success <- dat$value
    dat$failure <- n_trials - dat$value
  }
  list(
    data = dat, beta = beta, Lambda = Lambda,
    Sigma = Lambda %*% t(Lambda), scores = scores,
    family = family_truth(fid, p), n_trials = n_trials
  )
}

family_object <- function(spec) {
  switch(
    spec$cell,
    gaussian_identity = gaussian(),
    binomial_logit = binomial("logit"),
    binomial_probit = binomial("probit"),
    binomial_cloglog = binomial("cloglog"),
    poisson_log = poisson(),
    lognormal_log = lognormal(),
    gamma_log = Gamma("log"),
    nbinom2_log = nbinom2(),
    tweedie_log = tweedie(p = 1.5),
    beta_logit = Beta(),
    betabinomial_logit = betabinomial(),
    student_identity = student(df = 5),
    truncated_poisson_log = truncated_poisson(),
    truncated_nbinom2_log = truncated_nbinom2(),
    delta_lognormal_log = delta_lognormal(),
    delta_gamma_log = delta_gamma(),
    ordinal_probit = ordinal_probit(),
    nbinom1_log = nbinom1(),
    stop("unknown cell")
  )
}

private_va_fit <- function(spec, dgp) {
  ns <- asNamespace("gllvmTMB")
  engine <- get(".approximation_engine_va_r3_fit", envir = ns)
  wrap <- get(".va_route_build_fit", envir = ns)
  dat <- dgp$data
  X <- model.matrix(~ 0 + trait, data = dat)
  n_obs <- nrow(dat)
  n_trials <- if (spec$family_id %in% c(1L, 8L)) {
    rep.int(dgp$n_trials, n_obs)
  } else {
    rep.int(1, n_obs)
  }
  ordinal <- spec$family_id == 14L
  result <- engine(
    y = dat$value,
    n_trials = n_trials,
    X = X,
    unit_id = as.integer(dat$unit),
    trait_id = as.integer(dat$trait),
    q = spec$q,
    N = spec$n,
    T = spec$p,
    H = if (spec$H == 0L) 7L else spec$H,
    eval_method = "gh",
    family_codes = rep.int(spec$family_id, n_obs),
    link_ids = rep.int(spec$link_id, n_obs),
    n_ordinal_cuts_per_trait = if (ordinal) rep.int(1L, spec$p) else integer(spec$p),
    ordinal_offset_per_trait = if (ordinal) seq.int(0L, spec$p - 1L) else integer(spec$p),
    ordinal_log_increments_start = if (ordinal) rep.int(0, spec$p) else numeric(),
    fixed_tweedie_power = if (spec$family_id == 6L) rep.int(1.5, spec$p) else NULL,
    fixed_student_df = if (spec$family_id == 9L) rep.int(5, spec$p) else NULL,
    match_laplace_residual_sd = isTRUE(spec$va_match_laplace_residual_sd),
    silent = TRUE
  )
  wrap(
    result,
    call = match.call(),
    q = spec$q,
    p = spec$p,
    n = spec$n,
    eval_method = "gh",
    family = spec$cell,
    link = spec$link,
    beta_names = colnames(X)
  )
}

laplace_fit <- function(spec, dgp) {
  rhs <- sprintf(
    "0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)", spec$q
  )
  lhs <- if (spec$family_id %in% c(1L, 8L)) {
    "cbind(success, failure)"
  } else {
    "value"
  }
  form <- as.formula(paste(lhs, "~", rhs))
  control <- gllvmTMBcontrol(integration = "laplace", se = TRUE)
  gllvmTMB(
    form, data = dgp$data, unit = "unit", family = family_object(spec),
    control = control, silent = TRUE
  )
}

parameter_vector <- function(fit, estimator) {
  if (identical(estimator, "va")) return(fit$fitted$parameters %||% numeric())
  par <- fit$tmb_obj$env$last.par.best %||% fit$tmb_obj$par
  fit$tmb_obj$env$parList(par)
}

named_parameter <- function(parameters, name) {
  if (is.list(parameters)) return(as.numeric(parameters[[name]] %||% numeric()))
  as.numeric(parameters[names(parameters) == name])
}

family_parameter_map <- function(fid, estimator) {
  sigma_name <- if (identical(estimator, "va")) "log_sigma" else "log_sigma_eps"
  lognormal_name <- if (identical(estimator, "va")) {
    "log_sigma_lognormal"
  } else {
    "log_sigma_eps"
  }
  switch(
    as.character(fid),
    `0` = data.frame(parameter = "sigma", tmb = sigma_name, transform = "exp"),
    `3` = data.frame(parameter = "sigma", tmb = lognormal_name, transform = "exp"),
    `4` = data.frame(parameter = "shape", tmb = "log_phi_gamma", transform = "exp"),
    `5` = data.frame(parameter = "phi", tmb = "log_phi_nbinom2", transform = "exp"),
    `6` = data.frame(
      parameter = c("phi", "power"),
      tmb = c("log_phi_tweedie", "logit_p_tweedie"),
      transform = c("exp", "one_plus_plogis")
    ),
    `7` = data.frame(parameter = "precision", tmb = "log_phi_beta", transform = "exp"),
    `8` = data.frame(parameter = "precision", tmb = "log_phi_betabinom", transform = "exp"),
    `9` = data.frame(
      parameter = c("sigma", "df"),
      tmb = c("log_sigma_student", "log_df_student"),
      transform = c("exp", "one_plus_exp")
    ),
    `11` = data.frame(parameter = "phi", tmb = "log_phi_truncnb2", transform = "exp"),
    `12` = data.frame(parameter = "sigma", tmb = "log_sigma_lognormal_delta", transform = "exp"),
    `13` = data.frame(parameter = "phi", tmb = "log_phi_gamma_delta", transform = "exp"),
    `14` = data.frame(parameter = "cut_increment", tmb = "ordinal_log_increments", transform = "exp"),
    `15` = data.frame(parameter = "phi", tmb = "log_phi_nbinom1", transform = "exp"),
    data.frame(parameter = character(), tmb = character(), transform = character())
  )
}

transform_parameter <- function(value, transform) {
  switch(
    transform,
    exp = exp(value),
    one_plus_exp = 1 + exp(value),
    one_plus_plogis = 1 + plogis(value),
    stop("unknown transform")
  )
}

family_parameter_table <- function(spec, dgp, fit) {
  map <- family_parameter_map(spec$family_id, spec$estimator)
  if (!nrow(map)) {
    return(data.frame(
      parameter = character(), trait = integer(), truth = numeric(),
      estimate = numeric(), error = numeric(), fixed = logical(),
      stringsAsFactors = FALSE
    ))
  }
  parameters <- parameter_vector(fit, spec$estimator)
  rows <- lapply(seq_len(nrow(map)), function(i) {
    fixed <- (spec$family_id == 6L && map$parameter[[i]] == "power") ||
      (spec$family_id == 9L && map$parameter[[i]] == "df")
    values <- if (fixed) {
      if (spec$family_id == 6L) rep.int(1.5, spec$p) else rep.int(5, spec$p)
    } else {
      transform_parameter(
        named_parameter(parameters, map$tmb[[i]]), map$transform[[i]]
      )
    }
    if (length(values) == 1L) values <- rep.int(values, spec$p)
    if (length(values) != spec$p) values <- rep.int(NA_real_, spec$p)
    truth <- dgp$family[dgp$family$parameter == map$parameter[[i]], ]
    if (nrow(truth) != spec$p) stop("family truth table is incomplete")
    data.frame(
      parameter = map$parameter[[i]], trait = seq_len(spec$p),
      truth = truth$truth, estimate = values, error = values - truth$truth,
      fixed = rep.int(fixed, spec$p),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

extract_fit_components <- function(fit, estimator) {
  if (identical(estimator, "va")) {
    raw <- fit$engine_result
    return(list(
      Sigma = raw$report$Sigma_B %||% NULL,
      Lambda = raw$report$Lambda %||% NULL,
      latent = raw$latent %||% NULL
    ))
  }
  Sigma <- tryCatch(
    get("extract_Sigma", envir = asNamespace("gllvmTMB"))(
      fit, level = "unit", part = "shared"
    ),
    error = function(e) NULL
  )
  if (is.list(Sigma)) {
    matrices <- Filter(is.matrix, Sigma)
    Sigma <- if (length(matrices)) matrices[[1L]] else NULL
  }
  list(Sigma = Sigma, Lambda = NULL, latent = NULL)
}

beta_table <- function(fit, spec, dgp) {
  estimate <- if (identical(spec$estimator, "va")) {
    named_parameter(fit$fitted$parameters %||% numeric(), "beta")
  } else {
    get(".gllvmTMB_b_fix_values", envir = asNamespace("gllvmTMB"))(fit)
  }
  if (length(estimate) != spec$p) estimate <- rep.int(NA_real_, spec$p)
  interval <- tryCatch({
    if (identical(spec$estimator, "va")) {
      confint(fit, level = 0.95)
    } else {
      summary_fixed <- summary(fit$sd_report, "fixed")
      selected <- rownames(summary_fixed) == "b_fix"
      data.frame(
        lower = summary_fixed[selected, "Estimate"] -
          1.96 * summary_fixed[selected, "Std. Error"],
        upper = summary_fixed[selected, "Estimate"] +
          1.96 * summary_fixed[selected, "Std. Error"]
      )
    }
  }, error = function(e) NULL)
  lower <- upper <- rep.int(NA_real_, spec$p)
  if (!is.null(interval) && nrow(interval) == spec$p) {
    lower <- as.numeric(interval[, 1L])
    upper <- as.numeric(interval[, 2L])
  }
  data.frame(
    trait = seq_len(spec$p), truth = dgp$beta, estimate = estimate,
    error = estimate - dgp$beta, lower = lower, upper = upper,
    covered = lower <= dgp$beta & dgp$beta <= upper,
    width = upper - lower, stringsAsFactors = FALSE
  )
}

laplace_health <- function(fit, gradient_tolerance = 1e-3) {
  convergence <- as.integer(fit$opt$convergence %||% NA_integer_)
  objective <- as.numeric(fit$opt$objective %||% NA_real_)
  pd_hessian <- isTRUE(fit$sd_report$pdHess)
  gradient <- tryCatch({
    par <- fit$tmb_obj$env$last.par.best %||% fit$tmb_obj$par
    max(abs(fit$tmb_obj$gr(par)))
  }, error = function(e) Inf)
  healthy <- identical(convergence, 0L) && is.finite(objective) &&
    pd_hessian && is.finite(gradient) && gradient < gradient_tolerance
  list(
    healthy = healthy, convergence = convergence, objective = objective,
    pd_hessian = pd_hessian, max_gradient = gradient,
    gradient_tolerance = gradient_tolerance
  )
}

va_health <- function(fit) {
  list(
    healthy = identical(fit$status, "healthy"),
    convergence = as.integer(fit$diagnostics$convergence %||% NA_integer_),
    objective = as.numeric(fit$score$negative_elbo_gh %||% NA_real_),
    pd_hessian = NA,
    max_gradient = as.numeric(fit$diagnostics$max_abs_gradient %||% NA_real_),
    gradient_tolerance = as.numeric(
      fit$diagnostics$health$gradient_tolerance %||% NA_real_
    )
  )
}

fit_and_score <- function(spec, dgp) {
  started <- proc.time()[[3L]]
  fit <- if (identical(spec$estimator, "va")) {
    private_va_fit(spec, dgp)
  } else {
    laplace_fit(spec, dgp)
  }
  elapsed <- proc.time()[[3L]] - started
  health <- if (identical(spec$estimator, "va")) va_health(fit) else laplace_health(fit)
  beta <- beta_table(fit, spec, dgp)
  family <- family_parameter_table(spec, dgp, fit)
  components <- extract_fit_components(fit, spec$estimator)

  sigma_rel_frob <- sigma_diag_rmse <- NA_real_
  if (is.matrix(components$Sigma) && identical(dim(components$Sigma), dim(dgp$Sigma))) {
    sigma_rel_frob <- sqrt(sum((components$Sigma - dgp$Sigma)^2)) /
      sqrt(sum(dgp$Sigma^2))
    sigma_diag_rmse <- sqrt(mean((diag(components$Sigma) - diag(dgp$Sigma))^2))
  }

  lv_sd_mean <- lv_sd_coverage <- NA_real_
  alignment_sign <- rep.int(NA_real_, spec$q)
  alignment_matrix <- matrix(NA_real_, spec$q, spec$q)
  latent <- components$latent
  if (identical(spec$estimator, "va") &&
      is.matrix(components$Lambda) &&
      identical(dim(components$Lambda), dim(dgp$Lambda)) &&
      is.list(latent) && is.matrix(latent$scores) && is.matrix(latent$se) &&
      identical(dim(latent$scores), dim(dgp$scores)) &&
      identical(dim(latent$se), dim(dgp$scores))) {
    if (spec$q == 1L) {
      alignment_sign <- sign(sum(components$Lambda * dgp$Lambda))
      alignment_sign[!is.finite(alignment_sign) | alignment_sign == 0] <- 1
      alignment_matrix <- matrix(alignment_sign, 1L, 1L)
    } else {
      cross_loading <- crossprod(dgp$Lambda, components$Lambda)
      decomposition <- svd(cross_loading)
      alignment_matrix <- decomposition$u %*% t(decomposition$v)
    }
    aligned_truth <- dgp$scores %*% alignment_matrix
    lv_sd_mean <- mean(latent$se, na.rm = TRUE)
    lv_sd_coverage <- mean(
      abs(latent$scores - aligned_truth) <= 1.96 * latent$se,
      na.rm = TRUE
    )
  }

  list(
    fit = fit, elapsed = elapsed, health = health, beta = beta, family = family,
    Sigma = components$Sigma, Lambda = components$Lambda,
    sigma_rel_frob = sigma_rel_frob, sigma_diag_rmse = sigma_diag_rmse,
    alignment_sign = alignment_sign, alignment_matrix = alignment_matrix,
    lv_posterior_sd_mean = lv_sd_mean,
    lv_posterior_sd_coverage = lv_sd_coverage
  )
}

result_key <- function(spec) {
  sprintf(
    "%05d-%s-%s-H%02d-q%d-n%d-p%d-seed%08d",
    spec$task_id, spec$cell, spec$estimator, spec$H, spec$q,
    spec$n, spec$p, spec$seed
  )
}

empty_beta_table <- function() {
  data.frame(
    trait = integer(), truth = numeric(), estimate = numeric(), error = numeric(),
    lower = numeric(), upper = numeric(), covered = logical(), width = numeric()
  )
}

empty_family_table <- function() {
  data.frame(
    parameter = character(), trait = integer(), truth = numeric(),
    estimate = numeric(), error = numeric(), fixed = logical()
  )
}

bundle_complete <- function(path) {
  required <- c("result.csv", "beta.csv", "family.csv", "payload.rds", "COMPLETE.dcf")
  if (!dir.exists(path) || !all(file.exists(file.path(path, required)))) return(FALSE)
  manifest <- read_single_dcf(file.path(path, "COMPLETE.dcf"), "bundle manifest")
  checks <- c(
    result.csv = "result_checksum_md5", beta.csv = "beta_checksum_md5",
    family.csv = "family_checksum_md5", payload.rds = "payload_checksum_md5"
  )
  all(vapply(names(checks), function(file) {
    key <- unname(checks[[file]])
    !is.null(manifest[[key]]) &&
      identical(manifest[[key]], file_checksum(file.path(path, file)))
  }, logical(1L)))
}

recover_staged_bundle <- function(parent, key, final) {
  staged <- list.files(
    parent, pattern = paste0("^\\.staging-", key, "-"), full.names = TRUE
  )
  complete <- staged[vapply(staged, bundle_complete, logical(1L))]
  incomplete <- setdiff(staged, complete)
  if (length(incomplete)) {
    stop(
      "incomplete staged bundle requires quarantine before retry: ",
      paste(incomplete, collapse = ", ")
    )
  }
  if (length(complete) > 1L) stop("multiple complete staged bundles exist for ", key)
  if (length(complete) == 1L) {
    if (!file.rename(complete, final)) stop("could not recover staged bundle: ", key)
    message("recovered complete staged bundle: ", key)
    return(TRUE)
  }
  FALSE
}

publish_bundle <- function(path, result, beta, family, payload) {
  parent <- dirname(path)
  key <- basename(path)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  if (dir.exists(path)) stop("immutable result bundle already exists: ", path)
  stage <- tempfile(pattern = paste0(".staging-", key, "-"), tmpdir = parent)
  dir.create(stage)
  write.csv(result, file.path(stage, "result.csv"), row.names = FALSE)
  write.csv(beta, file.path(stage, "beta.csv"), row.names = FALSE)
  write.csv(family, file.path(stage, "family.csv"), row.names = FALSE)
  saveRDS(payload, file.path(stage, "payload.rds"))
  manifest <- data.frame(
    format_version = "1",
    result_checksum_md5 = file_checksum(file.path(stage, "result.csv")),
    beta_checksum_md5 = file_checksum(file.path(stage, "beta.csv")),
    family_checksum_md5 = file_checksum(file.path(stage, "family.csv")),
    payload_checksum_md5 = file_checksum(file.path(stage, "payload.rds")),
    stringsAsFactors = FALSE
  )
  write.dcf(manifest, file = file.path(stage, "COMPLETE.dcf"))
  if (!bundle_complete(stage)) stop("staged result bundle failed validation: ", stage)
  if (!file.rename(stage, path)) stop("atomic bundle publication failed: ", path)
}

run_one <- function(spec, output_dir, provenance) {
  key <- result_key(spec)
  bundle <- file.path(output_dir, "replicates", paste0(key, ".bundle"))
  parent <- dirname(bundle)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  if (dir.exists(bundle)) {
    if (!bundle_complete(bundle)) stop("immutable bundle is incomplete or corrupt: ", bundle)
    message("complete immutable result exists; skip: ", key)
    return(invisible(NULL))
  }
  if (recover_staged_bundle(parent, paste0(key, ".bundle"), bundle)) {
    return(invisible(NULL))
  }

  started <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  run_clock <- proc.time()[[3L]]
  dgp <- NULL
  scored <- NULL
  failure <- NULL
  scored <- tryCatch({
    dgp <- simulate_cell(spec)
    fit_and_score(spec, dgp)
  }, error = function(e) {
    failure <<- conditionMessage(e)
    NULL
  })
  ok <- !is.null(scored)
  healthy <- ok && isTRUE(scored$health$healthy)
  status <- if (!ok) "failed" else if (healthy) "completed" else "unhealthy"
  beta <- if (ok) scored$beta else empty_beta_table()
  family <- if (ok) scored$family else empty_family_table()
  free_family <- nrow(family) > 0L && any(!family$fixed)
  result <- data.frame(
    spec,
    status = status,
    error = failure %||% "",
    elapsed_seconds = if (ok) scored$elapsed else proc.time()[[3L]] - run_clock,
    convergence_code = if (ok) scored$health$convergence else NA_integer_,
    healthy = healthy,
    objective = if (ok) scored$health$objective else NA_real_,
    pd_hessian = if (ok) scored$health$pd_hessian else NA,
    max_gradient = if (ok) scored$health$max_gradient else NA_real_,
    gradient_tolerance = if (ok) scored$health$gradient_tolerance else NA_real_,
    beta_bias_mean = if (nrow(beta)) mean(beta$error, na.rm = TRUE) else NA_real_,
    beta_squared_error_mean = if (nrow(beta)) mean(beta$error^2, na.rm = TRUE) else NA_real_,
    beta_wald_available = nrow(beta) > 0L && all(is.finite(beta$lower)),
    beta_wald_coverage = if (nrow(beta)) mean(beta$covered, na.rm = TRUE) else NA_real_,
    beta_wald_width = if (nrow(beta)) mean(beta$width, na.rm = TRUE) else NA_real_,
    family_parameter_available = free_family &&
      all(is.finite(family$estimate[!family$fixed])),
    family_parameter_rmse = if (free_family) {
      sqrt(mean(family$error[!family$fixed]^2, na.rm = TRUE))
    } else {
      NA_real_
    },
    sigma_available = ok && is.finite(scored$sigma_rel_frob),
    sigma_rel_frob = if (ok) scored$sigma_rel_frob else NA_real_,
    sigma_diag_rmse = if (ok) scored$sigma_diag_rmse else NA_real_,
    lv_sd_available = ok && is.finite(scored$lv_posterior_sd_coverage),
    lv_posterior_sd_mean = if (ok) scored$lv_posterior_sd_mean else NA_real_,
    lv_posterior_sd_coverage = if (ok) scored$lv_posterior_sd_coverage else NA_real_,
    started_utc = started,
    finished_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    stringsAsFactors = FALSE
  )
  payload <- list(
    spec = spec,
    result = result,
    truth = if (is.null(dgp)) NULL else dgp[c("beta", "Lambda", "Sigma", "scores", "family")],
    estimates = if (!ok) NULL else list(
      beta = beta, family = family, Sigma = scored$Sigma,
      Lambda = scored$Lambda, alignment_sign = scored$alignment_sign,
      alignment_matrix = scored$alignment_matrix
    ),
    fit_snapshot = if (!ok) NULL else list(
      class = class(scored$fit),
      status = if (identical(spec$estimator, "va")) {
        scored$fit$status
      } else {
        scored$fit$opt$convergence
      },
      health = scored$health,
      parameters = parameter_vector(scored$fit, spec$estimator)
    ),
    failure = failure,
    session_info = sessionInfo(),
    provenance = provenance
  )
  publish_bundle(bundle, result, beta, family, payload)
  message(status, ": ", key)
}

mc_mean <- function(x) {
  n <- sum(is.finite(x))
  if (n > 1L) sd(x, na.rm = TRUE) / sqrt(n) else NA_real_
}

eligible_mean <- function(x, eligible) {
  eligible <- !is.na(eligible) & eligible & is.finite(x)
  if (!any(eligible)) return(NA_real_)
  mean(x[eligible])
}

eligible_mcse <- function(x, eligible) {
  eligible <- !is.na(eligible) & eligible & is.finite(x)
  if (!any(eligible)) return(NA_real_)
  mc_mean(x[eligible])
}

scheduler_failure_rows <- function(plan_rows) {
  if (!nrow(plan_rows)) return(NULL)
  data.frame(
    plan_rows,
    status = "scheduler_failed",
    error = "planned task has no published immutable result bundle",
    elapsed_seconds = NA_real_, convergence_code = NA_integer_, healthy = FALSE,
    objective = NA_real_, pd_hessian = NA, max_gradient = NA_real_,
    gradient_tolerance = NA_real_, beta_bias_mean = NA_real_,
    beta_squared_error_mean = NA_real_, beta_wald_available = FALSE,
    beta_wald_coverage = NA_real_, beta_wald_width = NA_real_,
    family_parameter_available = FALSE, family_parameter_rmse = NA_real_,
    sigma_available = FALSE, sigma_rel_frob = NA_real_, sigma_diag_rmse = NA_real_,
    lv_sd_available = FALSE, lv_posterior_sd_mean = NA_real_,
    lv_posterior_sd_coverage = NA_real_, started_utc = NA_character_,
    finished_utc = NA_character_, stringsAsFactors = FALSE
  )
}

bind_results_to_plan <- function(results, plan) {
  validate_plan(plan)
  if (anyDuplicated(results$task_id)) {
    stop("more than one result bundle claims the same plan task_id")
  }
  extra <- setdiff(results$task_id, plan$task_id)
  if (length(extra)) {
    stop("result bundles contain task_id values absent from the immutable plan: ",
         paste(extra, collapse = ", "))
  }
  spec_columns <- c(
    "cell", "family_id", "link", "link_id", "route", "seed", "H", "q",
    "n", "p", "estimator", "va_match_laplace_residual_sd"
  )
  expected <- plan[match(results$task_id, plan$task_id), spec_columns, drop = FALSE]
  actual <- results[, spec_columns, drop = FALSE]
  agrees <- vapply(spec_columns, function(name) {
    identical(as.character(actual[[name]]), as.character(expected[[name]]))
  }, logical(1L))
  if (!all(agrees)) {
    stop("result bundle specification disagrees with the immutable plan: ",
         paste(spec_columns[!agrees], collapse = ", "))
  }
  missing <- plan[!plan$task_id %in% results$task_id, , drop = FALSE]
  if (nrow(missing)) results <- rbind(results, scheduler_failure_rows(missing))
  results[match(plan$task_id, results$task_id), , drop = FALSE]
}

verify_task_bundle <- function(plan, output_dir, task, provenance = NULL) {
  validate_plan(plan)
  if (task > nrow(plan)) stop("task-index exceeds plan")
  spec <- plan[task, , drop = FALSE]
  bundle <- file.path(
    output_dir, "replicates", paste0(result_key(spec), ".bundle")
  )
  if (!bundle_complete(bundle)) {
    stop("planned task does not have a complete verified bundle: ", bundle)
  }
  result <- read.csv(file.path(bundle, "result.csv"), stringsAsFactors = FALSE)
  if (nrow(result) != 1L) stop("verified task bundle must contain one result row")
  spec_columns <- c(
    "task_id", "cell", "family_id", "link", "link_id", "route", "seed",
    "H", "q", "n", "p", "estimator", "va_match_laplace_residual_sd"
  )
  agrees <- vapply(spec_columns, function(name) {
    identical(as.character(result[[name]]), as.character(spec[[name]]))
  }, logical(1L))
  if (!all(agrees)) {
    stop("verified task bundle disagrees with its immutable plan row: ",
         paste(spec_columns[!agrees], collapse = ", "))
  }
  if (!is.null(provenance)) {
    payload <- readRDS(file.path(bundle, "payload.rds"))
    recorded <- payload$provenance %||% list()
    required <- names(provenance)
    if (!all(required %in% names(recorded))) {
      stop("verified task payload lacks runtime-chain provenance: ",
           paste(setdiff(required, names(recorded)), collapse = ", "))
    }
    agrees <- vapply(required, function(name) {
      identical(as.character(recorded[[name]]), as.character(provenance[[name]]))
    }, logical(1L))
    if (!all(agrees)) {
      stop("verified task payload disagrees with the current runtime chain: ",
           paste(required[!agrees], collapse = ", "))
    }
  }
  invisible(normalizePath(bundle, mustWork = TRUE))
}

summarise_result_rows <- function(results) {
  required <- c(
    "cell", "family_id", "estimator", "H", "q", "n", "p", "status",
    "elapsed_seconds", "beta_bias_mean", "beta_squared_error_mean",
    "beta_wald_available", "beta_wald_coverage",
    "family_parameter_available", "family_parameter_rmse",
    "sigma_available", "sigma_rel_frob", "lv_sd_available",
    "lv_posterior_sd_coverage"
  )
  missing <- setdiff(required, names(results))
  if (length(missing)) stop("result rows lack: ", paste(missing, collapse = ", "))
  group <- interaction(
    results$cell, results$estimator, results$H, results$q,
    results$n, results$p, drop = TRUE
  )
  one <- function(data) {
    if (length(unique(data$cell)) != 1L) {
      stop("summary groups must never pool family cells")
    }
    completed <- data$status == "completed"
    failed <- !completed
    beta_recovery_available <- completed & is.finite(data$beta_bias_mean) &
      is.finite(data$beta_squared_error_mean)
    beta_interval_available <- completed &
      (data$beta_wald_available %in% TRUE) &
      is.finite(data$beta_wald_coverage)
    beta_coverage <- ifelse(
      beta_interval_available, data$beta_wald_coverage, 0
    )
    family_applicable <- nrow(family_truth(data$family_id[[1L]], data$p[[1L]])) > 0L
    family_available <- completed & (data$family_parameter_available %in% TRUE) &
      is.finite(data$family_parameter_rmse)
    sigma_available <- completed & (data$sigma_available %in% TRUE) &
      is.finite(data$sigma_rel_frob)
    lv_applicable <- identical(data$estimator[[1L]], "va")
    lv_available <- completed & (data$lv_sd_available %in% TRUE) &
      is.finite(data$lv_posterior_sd_coverage)
    lv_coverage <- ifelse(lv_available, data$lv_posterior_sd_coverage, 0)
    data.frame(
      data[1L, c("cell", "estimator", "H", "q", "n", "p")],
      adjudication_unit = "family_cell",
      attempted = nrow(data),
      completed = sum(completed),
      failure_rate = mean(failed),
      failure_mcse = sqrt(mean(failed) * (1 - mean(failed)) / nrow(data)),
      beta_recovery_eligible_n = sum(beta_recovery_available),
      beta_recovery_available_rate = mean(beta_recovery_available),
      beta_bias = eligible_mean(data$beta_bias_mean, beta_recovery_available),
      beta_bias_mcse = eligible_mcse(
        data$beta_bias_mean, beta_recovery_available
      ),
      beta_rmse = sqrt(eligible_mean(
        data$beta_squared_error_mean, beta_recovery_available
      )),
      beta_wald_eligible_n = sum(beta_interval_available),
      beta_wald_available_rate = mean(beta_interval_available),
      beta_wald_coverage = mean(beta_coverage),
      beta_wald_coverage_mcse = mc_mean(beta_coverage),
      family_parameter_available_rate = if (family_applicable) {
        mean(family_available)
      } else {
        NA_real_
      },
      family_parameter_rmse = if (family_applicable) {
        eligible_mean(data$family_parameter_rmse, family_available)
      } else {
        NA_real_
      },
      family_parameter_eligible_n = if (family_applicable) {
        sum(family_available)
      } else {
        NA_integer_
      },
      sigma_eligible_n = sum(sigma_available),
      sigma_available_rate = mean(sigma_available),
      sigma_rel_frob = eligible_mean(data$sigma_rel_frob, sigma_available),
      sigma_rel_frob_mcse = eligible_mcse(
        data$sigma_rel_frob, sigma_available
      ),
      lv_sd_eligible_n = if (lv_applicable) sum(lv_available) else NA_integer_,
      lv_sd_available_rate = if (lv_applicable) mean(lv_available) else NA_real_,
      lv_sd_coverage = if (lv_applicable) mean(lv_coverage) else NA_real_,
      lv_sd_coverage_mcse = if (lv_applicable) mc_mean(lv_coverage) else NA_real_,
      elapsed_eligible_n = sum(is.finite(data$elapsed_seconds)),
      elapsed_seconds = eligible_mean(
        data$elapsed_seconds, is.finite(data$elapsed_seconds)
      ),
      elapsed_mcse = mc_mean(data$elapsed_seconds)
    )
  }
  summary <- do.call(rbind, lapply(split(results, group), one))
  rownames(summary) <- NULL
  summary
}

summarise_results <- function(output_dir, plan) {
  bundles <- list.dirs(file.path(output_dir, "replicates"), recursive = FALSE)
  bundles <- bundles[grepl("\\.bundle$", bundles)]
  if (length(bundles) && !all(vapply(bundles, bundle_complete, logical(1L)))) {
    stop("one or more immutable result bundles are incomplete or corrupt")
  }
  if (length(bundles)) {
    results <- do.call(rbind, lapply(bundles, function(path) {
      read.csv(file.path(path, "result.csv"), stringsAsFactors = FALSE)
    }))
    results <- bind_results_to_plan(results, plan)
    beta <- do.call(rbind, lapply(bundles, function(path) {
      value <- read.csv(file.path(path, "beta.csv"), stringsAsFactors = FALSE)
      if (!nrow(value)) return(NULL)
      spec <- read.csv(file.path(path, "result.csv"), stringsAsFactors = FALSE)
      cbind(spec[rep(1L, nrow(value)), c(
        "cell", "estimator", "H", "q", "n", "p", "seed", "status"
      )], value)
    }))
    family <- do.call(rbind, lapply(bundles, function(path) {
      value <- read.csv(file.path(path, "family.csv"), stringsAsFactors = FALSE)
      if (!nrow(value)) return(NULL)
      spec <- read.csv(file.path(path, "result.csv"), stringsAsFactors = FALSE)
      cbind(spec[rep(1L, nrow(value)), c(
        "cell", "estimator", "H", "q", "n", "p", "seed", "status"
      )], value)
    }))
  } else {
    validate_plan(plan)
    results <- scheduler_failure_rows(plan)
    beta <- family <- NULL
  }
  summary <- summarise_result_rows(results)
  stamp <- format(Sys.time(), "%Y%m%dT%H%M%OS6Z", tz = "UTC")
  atomic_save(summary, file.path(output_dir, paste0("summary-", stamp, ".csv")), function(x, file) {
    write.csv(x, file, row.names = FALSE)
  })
  if (!is.null(beta) && nrow(beta)) {
    atomic_save(beta, file.path(output_dir, paste0("beta-trait-", stamp, ".csv")), function(x, file) {
      write.csv(x, file, row.names = FALSE)
    })
  }
  if (!is.null(family) && nrow(family)) {
    atomic_save(family, file.path(output_dir, paste0("family-trait-", stamp, ".csv")), function(x, file) {
      write.csv(x, file, row.names = FALSE)
    })
  }
  message("wrote MCSE-ready summaries with stamp ", stamp)
}

write_preflight_receipt <- function(
    runtime_manifest, gate_receipt, receipt_path, va, laplace) {
  if (!identical(va$status, "completed") || !identical(laplace$status, "completed")) {
    stop("timed preflight requires healthy VA and Laplace fits")
  }
  runtime <- read_single_dcf(runtime_manifest, "runtime manifest")
  spec <- preflight_spec()
  matches_spec <- function(row) {
    all(vapply(names(spec), function(name) {
      identical(as.character(row[[name]]), spec[[name]])
    }, logical(1L)))
  }
  if (!matches_spec(va) || !matches_spec(laplace)) {
    stop("timed preflight rows do not match the canonical preflight specification")
  }
  gate_checksum <- file_checksum(gate_receipt)
  if (!identical(runtime$gate_receipt_checksum_md5, gate_checksum)) {
    stop("timed preflight gate receipt disagrees with the runtime manifest")
  }
  record <- data.frame(
    format_version = "2",
    status = "PASS",
    runtime_manifest_checksum_md5 = file_checksum(runtime_manifest),
    gate_receipt_checksum_md5 = gate_checksum,
    git_revision = runtime$git_revision,
    template_checksum_md5 = runtime$template_checksum_md5,
    cell = spec$cell,
    seed = spec$seed,
    H = spec$H,
    q = spec$q,
    n = spec$n,
    p = spec$p,
    va_status = va$status,
    va_seconds = va$elapsed_seconds,
    laplace_status = laplace$status,
    laplace_seconds = laplace$elapsed_seconds,
    created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    stringsAsFactors = FALSE
  )
  if (file.exists(receipt_path)) {
    existing <- read_single_dcf(receipt_path, "preflight receipt")
    compare <- setdiff(names(record), "created_utc")
    expected <- as.list(record[1L, compare, drop = TRUE])
    if (!identical(existing[compare], expected)) {
      stop("existing immutable preflight receipt differs: ", receipt_path)
    }
    return(invisible(existing))
  }
  atomic_save(record, receipt_path, function(x, file) write.dcf(x, file = file))
  message("wrote immutable timed-preflight receipt: ", receipt_path)
}

mode <- get_arg("mode", "VA_MODE", "dry-run")
plan_path <- normalizePath(
  get_arg("plan", "VA_PLAN", "va-gh-h7-plan.csv"), mustWork = FALSE
)
output_dir <- normalizePath(
  get_arg("output-dir", "VA_OUTPUT_DIR", "va-gh-h7-results"), mustWork = FALSE
)
gate_receipt <- get_arg("gate-receipt", "GATE_E_RECEIPT")
runtime_manifest <- get_arg("runtime-manifest", "VA_RUNTIME_MANIFEST")
preflight_receipt <- get_arg("preflight-receipt", "VA_PREFLIGHT_RECEIPT")

if (mode == "plan") {
  verify_gate_receipt(gate_receipt)
  write_plan(make_plan(), plan_path)
} else if (mode == "dry-run") {
  plan <- make_plan()
  cat("DRY RUN ONLY; no fit and no files written\n")
  print(utils::head(plan, 12L))
  cat("tasks:", nrow(plan), "\n")
  cat("laplace rows with nonzero H:", sum(plan$estimator == "laplace" & plan$H != 0L), "\n")
  cat("exact VA rows with nonzero H:", sum(plan$estimator == "va" & plan$route == "exact" & plan$H != 0L), "\n")
} else if (mode == "gate-receipt") {
  report <- normalizePath(
    get_arg("gate-report", "GATE_E_REPORT"), mustWork = TRUE
  )
  receipt <- normalizePath(gate_receipt, mustWork = FALSE)
  write_gate_receipt(report, receipt)
} else if (mode == "verify-gate") {
  verify_gate_receipt(gate_receipt)
  cat("Gate-E receipt verified\n")
} else if (mode == "runtime-manifest") {
  package_lib <- get_arg("package-lib", "VA_PACKAGE_LIB")
  build_root <- get_arg("build-root", "GLLVMTMB_VA_R3_BUILD_ROOT")
  write_runtime_manifest(
    gate_receipt, package_lib, build_root,
    normalizePath(runtime_manifest, mustWork = FALSE)
  )
} else if (mode == "verify-runtime") {
  verify_runtime(runtime_manifest, gate_receipt, preflight_receipt)
  cat("runtime and preflight receipts verified\n")
} else if (mode == "preflight") {
  runtime <- verify_runtime(runtime_manifest, gate_receipt)
  load_campaign_package(runtime)
  expected_preflight <- preflight_spec()
  base <- cells[cells$cell == "binomial_logit", , drop = FALSE]
  base$task_id <- 1L
  base$seed <- as.integer(expected_preflight$seed)
  base$H <- as.integer(expected_preflight$H)
  base$q <- as.integer(expected_preflight$q)
  base$n <- as.integer(expected_preflight$n)
  base$p <- as.integer(expected_preflight$p)
  rows <- lapply(c("va", "laplace"), function(estimator) {
    spec <- base
    spec$estimator <- estimator
    dgp <- simulate_cell(spec)
    started <- proc.time()[[3L]]
    scored <- fit_and_score(spec, dgp)
    data.frame(
      cell = spec$cell, seed = spec$seed, H = spec$H, q = spec$q,
      n = spec$n, p = spec$p,
      estimator = estimator,
      status = if (isTRUE(scored$health$healthy)) "completed" else "unhealthy",
      elapsed_seconds = proc.time()[[3L]] - started,
      max_gradient = scored$health$max_gradient,
      pd_hessian = scored$health$pd_hessian,
      stringsAsFactors = FALSE
    )
  })
  preflight <- do.call(rbind, rows)
  print(preflight)
  write_preflight_receipt(
    runtime_manifest, gate_receipt,
    normalizePath(preflight_receipt, mustWork = FALSE),
    preflight[preflight$estimator == "va", , drop = FALSE],
    preflight[preflight$estimator == "laplace", , drop = FALSE]
  )
} else if (mode == "run") {
  runtime <- verify_runtime(runtime_manifest, gate_receipt, preflight_receipt)
  load_campaign_package(runtime)
  if (!file.exists(plan_path)) stop("plan does not exist: ", plan_path)
  plan <- read.csv(plan_path, stringsAsFactors = FALSE)
  validate_plan(plan)
  task <- as_int(get_arg("task-index", "VA_TASK_INDEX", ""), "task-index")
  if (task > nrow(plan)) stop("task-index exceeds plan")
  provenance <- list(
    git_revision = runtime$git_revision,
    template_checksum_md5 = runtime$template_checksum_md5,
    runtime_manifest_checksum_md5 = file_checksum(runtime_manifest),
    gate_receipt_checksum_md5 = file_checksum(gate_receipt),
    preflight_receipt_checksum_md5 = file_checksum(preflight_receipt),
    plan_checksum_md5 = file_checksum(plan_path)
  )
  run_one(plan[task, , drop = FALSE], output_dir, provenance)
} else if (mode == "verify-task") {
  if (!file.exists(plan_path)) stop("plan does not exist: ", plan_path)
  plan <- read.csv(plan_path, stringsAsFactors = FALSE)
  task <- as_int(get_arg("task-index", "VA_TASK_INDEX", ""), "task-index")
  runtime_args <- list(gate_receipt, runtime_manifest, preflight_receipt)
  supplied <- vapply(runtime_args, function(value) {
    !is.null(value) && length(value) == 1L && nzchar(value)
  }, logical(1L))
  if (any(supplied) && !all(supplied)) {
    stop("verify-task requires gate, runtime, and preflight receipts together")
  }
  provenance <- NULL
  if (all(supplied)) {
    runtime <- verify_runtime(runtime_manifest, gate_receipt, preflight_receipt)
    provenance <- list(
      git_revision = runtime$git_revision,
      template_checksum_md5 = runtime$template_checksum_md5,
      runtime_manifest_checksum_md5 = file_checksum(runtime_manifest),
      gate_receipt_checksum_md5 = file_checksum(gate_receipt),
      preflight_receipt_checksum_md5 = file_checksum(preflight_receipt),
      plan_checksum_md5 = file_checksum(plan_path)
    )
  }
  bundle <- verify_task_bundle(plan, output_dir, task, provenance)
  cat("verified complete task bundle:", bundle, "\n")
} else if (mode == "summarise") {
  if (!file.exists(plan_path)) stop("plan does not exist: ", plan_path)
  plan <- read.csv(plan_path, stringsAsFactors = FALSE)
  validate_plan(plan)
  summarise_results(output_dir, plan)
} else {
  stop(
    "mode must be dry-run, gate-receipt, verify-gate, runtime-manifest, ",
    "verify-runtime, preflight, plan, run, verify-task, or summarise"
  )
}
