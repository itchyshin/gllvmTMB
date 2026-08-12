#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
value <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), args, value = TRUE)
  if (!length(hit)) default else sub(paste0("^--", name, "="), "", hit[[1L]])
}
mode <- value("mode", "validate")
root <- value("output")
pkg <- normalizePath(value("pkg", getwd()), mustWork = TRUE)
campaign_sha <- value("campaign-sha")
if (!mode %in% c("validate", "smoke") || is.null(root)) {
  stop("require --mode=validate|smoke and --output=PATH", call. = FALSE)
}

script <- normalizePath(
  sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]),
  mustWork = TRUE
)
base <- dirname(script)
source(file.path(base, "g2h-360cell-fixture.R"), local = TRUE)
hash <- function(path) unname(tools::md5sum(path))[[1L]]
commit <- function() system2("git", c("-C", pkg, "rev-parse", "HEAD"), stdout = TRUE)[[1L]]
check_fixture <- function() {
  fixture <- g2h_make_fixture()
  g2h_validate_fixture(fixture)
  fixture
}
valid_polish <- function(x) {
  scalar_finite <- function(value) is.numeric(value) && length(value) == 1L &&
    is.finite(value)
  finite_vector <- function(value, length_out = NULL) {
    is.numeric(value) && length(value) > 0L && all(is.finite(value)) &&
      (is.null(length_out) || length(value) == length_out)
  }
  if (!is.list(x) || !identical(x$schema, "G2I_INTERNAL_ISDM_POLISH_V1") ||
      !is.list(x$raw) || !is.list(x$candidate) || !is.list(x$boundary) ||
      !finite_vector(x$raw$parameter_vector) ||
      !finite_vector(x$candidate$parameter_vector,
                     length(x$raw$parameter_vector)) ||
      is.null(names(x$raw$parameter_vector)) ||
      is.null(names(x$candidate$parameter_vector)) ||
      !identical(names(x$raw$parameter_vector),
                 names(x$candidate$parameter_vector)) ||
      !finite_vector(x$raw$gradient, length(x$raw$parameter_vector)) ||
      !is.integer(x$boundary$outer_parameter_indices) ||
      length(x$boundary$outer_parameter_indices) != 1L) {
    return(FALSE)
  }
  parameter_names <- names(x$raw$parameter_vector)
  boundary_outer <- x$boundary$outer_parameter_indices
  max_gradient <- max(abs(x$raw$gradient))
  max_indices <- which(abs(x$raw$gradient) == max_gradient)
  max_index <- if (length(max_indices) == 1L) max_indices else NA_integer_
  max_block <- if (is.finite(max_index)) parameter_names[[max_index]] else NA_character_
  max_block_index <- if (is.finite(max_index)) {
    sum(parameter_names[seq_len(max_index)] == max_block)
  } else {
    NA_integer_
  }
  is.list(x) && identical(x$schema, "G2I_INTERNAL_ISDM_POLISH_V1") &&
    isTRUE(x$eligible) && isTRUE(x$attempted) && isTRUE(x$accepted) &&
    isTRUE(x$map_identical) &&
    scalar_finite(x$raw$objective) &&
    scalar_finite(x$raw$max_gradient) && isTRUE(x$raw$pd_hessian) &&
    x$raw$max_gradient > 1e-3 && x$raw$max_gradient < 1e-2 &&
    isTRUE(all.equal(x$raw$max_gradient, max(abs(x$raw$gradient)),
                     tolerance = 0)) &&
    identical(x$raw$boundary_flags, "near_zero_sd_B") &&
    length(max_indices) == 1L && max_block == "theta_rr_B" &&
    identical(x$raw$max_gradient_parameter_block, max_block) &&
    is.integer(x$raw$max_gradient_parameter_index) &&
    length(x$raw$max_gradient_parameter_index) == 1L &&
    identical(x$raw$max_gradient_parameter_index, as.integer(max_block_index)) &&
    scalar_finite(x$candidate$objective) &&
    finite_vector(x$candidate$gradient, length(x$raw$parameter_vector)) &&
    scalar_finite(x$candidate$max_gradient) &&
    x$candidate$max_gradient <= 1e-3 && isTRUE(x$candidate$pd_hessian) &&
    isTRUE(all.equal(x$candidate$max_gradient,
                     max(abs(x$candidate$gradient)), tolerance = 0)) &&
    x$candidate$objective <= x$raw$objective +
      64 * .Machine$double.eps * max(1, abs(x$raw$objective)) &&
    identical(x$candidate$boundary_flags, "near_zero_sd_B") &&
    is.integer(x$boundary$diagonal_indices) &&
    is.integer(x$boundary$candidate_diagonal_indices) &&
    length(x$boundary$diagonal_indices) == 1L &&
    identical(x$boundary$diagonal_indices, x$boundary$candidate_diagonal_indices) &&
    boundary_outer >= 1L && boundary_outer <= length(parameter_names) &&
    identical(parameter_names[[boundary_outer]], "theta_diag_B") &&
    sum(parameter_names[seq_len(boundary_outer)] == "theta_diag_B") ==
      x$boundary$diagonal_indices &&
    finite_vector(x$boundary$raw_theta_diag_values, 1L) &&
    finite_vector(x$boundary$candidate_theta_diag_values, 1L) &&
    isTRUE(all.equal(unname(x$boundary$raw_theta_diag_values),
                     unname(x$raw$parameter_vector[boundary_outer]),
                     tolerance = 0)) &&
    isTRUE(all.equal(unname(x$boundary$candidate_theta_diag_values),
                     unname(x$candidate$parameter_vector[boundary_outer]),
                     tolerance = 0))
}

if (identical(mode, "validate")) {
  check_fixture()
  stopifnot(file.exists(file.path(base, "2026-08-11-g2i-polish-contract.md")))
  stopifnot(file.exists(file.path(base, "2026-08-11-g2i-polish-protocol.md")))
  stopifnot(file.exists(file.path(base, "2026-08-11-g2i-polish-decision.md")))
  cat("G2I smoke wrapper validation PASS (no fit)\n")
  quit(save = "no")
}

root <- normalizePath(
  if (grepl("^/", root)) root else file.path(getwd(), root),
  mustWork = FALSE
)
parent <- normalizePath(file.path(pkg, "dev", "isdm-package-recovery", "results"),
                        mustWork = FALSE)
if (!startsWith(root, paste0(parent, "/")) ||
    (dir.exists(root) && length(list.files(root, all.files = TRUE, no.. = TRUE))) ||
    is.null(campaign_sha) || !identical(campaign_sha, commit())) {
  stop("fresh G2i root and current --campaign-sha are required", call. = FALSE)
}
dir.create(root, recursive = TRUE)
fixture <- check_fixture()
receipt <- list(
  kind = "G2I_SMOKE", commit = commit(), seed = g2h_seed,
  runner_md5 = hash(script), fixture_md5 = hash(file.path(base, "g2h-360cell-fixture.R")),
  contract_md5 = hash(file.path(base, "2026-08-11-g2i-polish-contract.md")),
  protocol_md5 = hash(file.path(base, "2026-08-11-g2i-polish-protocol.md")),
  decision_md5 = hash(file.path(base, "2026-08-11-g2i-polish-decision.md"))
)
saveRDS(receipt, file.path(root, "root-receipt.rds"))
saveRDS(fixture$truth, file.path(root, "truth.rds"))
stage <- function(x) write(x, file = file.path(root, "stage.txt"), append = TRUE)

stage("fixture_validated")
suppressMessages(devtools::load_all(pkg, quiet = TRUE))
stage("optimizer_entered")
set.seed(g2h_seed + 100000L)
fit <- tryCatch(
  .gll_isdm_fit(
    fixture$rows, fixture$X, fixture$B, d = 1L,
    control = gllvmTMBcontrol(
      n_init = 3L, init_jitter = .25, se = TRUE, aghq = FALSE,
      warn_runaway = TRUE
    ),
    silent = TRUE
  ),
  error = function(e) e
)
stage("optimizer_returned")

if (inherits(fit, "error")) {
  saveRDS(list(reason = "fit_error", detail = conditionMessage(fit)),
          file.path(root, "profile-ledger.rds"))
  saveRDS(list(
    classification = NA_character_, diagnostic_state = "INVALID_FIT_ERROR",
    polish = NULL
  ), file.path(root, "decision-ledger.rds"))
  status <- "G2I_SMOKE_HOLD"
  classification <- NA_character_
} else {
  saveRDS(fit, file.path(root, "fit.rds"))
  stage("fit_retained")
  profiles <- lapply(seq_len(6L), function(k) {
    theta_diag <- fit$tmb_obj$env$parList(fit$opt$par)$theta_diag_B
    offsets <- c(-2, -1, 0, 1, 2)
    do.call(rbind, lapply(offsets, function(offset) {
      parameters <- fit$tmb_obj$env$parList(fit$opt$par)
      parameters$theta_diag_B[k] <- theta_diag[k] + offset
      map <- fit$tmb_map
      fixed <- factor(seq_along(theta_diag))
      fixed[k] <- NA
      map$theta_diag_B <- fixed
      objective <- TMB::MakeADFun(
        data = fit$tmb_data, parameters = parameters, map = map,
        random = fit$random, DLL = fit$tmb_obj$env$DLL, silent = TRUE
      )
      optimized <- tryCatch(
        nlminb(objective$par, objective$fn, objective$gr),
        error = function(e) e
      )
      data.frame(
        offset = offset,
        nll = if (inherits(optimized, "error")) NA_real_ else objective$fn(optimized$par),
        convergence = if (inherits(optimized, "error")) NA_integer_ else optimized$convergence
      )
    }))
  })
  names(profiles) <- paste0("sp", seq_len(6L))
  profiles <- lapply(profiles, function(x) {
    x$delta_nll <- x$nll - x$nll[x$offset == 0]
    x
  })
  profile_valid <- vapply(profiles, function(x) {
    isTRUE(all(is.finite(x$nll))) && isTRUE(all(x$convergence == 0L))
  }, logical(1L))
  fixed <- .gllvmTMB_b_fix_values(fit)
  gamma_hat <- vapply(paste0("sp", seq_len(6L)), function(species) {
    index <- grep(paste0("trait", species, ".*isdm_gbif_b_bias"),
                  fit$X_fix_names)
    if (length(index) == 1L) fixed[index] else NA_real_
  }, numeric(1L))
  gamma_error <- max(abs(gamma_hat - fixture$truth$constants$gamma))
  lower_delta_nll <- vapply(profiles, function(x) x$delta_nll[x$offset == -2],
                            numeric(1L))
  final_gradient <- max(abs(fit$tmb_obj$gr(fit$opt$par)))
  classification <- if (!all(profile_valid) || !is.finite(gamma_error)) {
    NA_character_
  } else if (sum(lower_delta_nll >= 2) >= 2 && gamma_error < .30) {
    "GEOMETRY_RESPONSIVE"
  } else if (gamma_error < .30) {
    "PROFILE_LIMITED"
  } else {
    "NONRESPONSIVE"
  }
  polish <- fit$isdm_polish_provenance
  polish_valid <- valid_polish(polish)
  saveRDS(profiles, file.path(root, "profile-ledger.rds"))
  saveRDS(list(
    classification = classification, diagnostic_state = if (all(profile_valid))
      "VALID" else "INVALID_PROFILE_OR_GAMMA",
    gamma_error = gamma_error, lower_delta_nll = lower_delta_nll,
    profile_valid = profile_valid, max_gradient = final_gradient,
    three_restarts = nrow(fit$restart_history) == 3L,
    polish = polish, polish_valid = polish_valid
  ), file.path(root, "decision-ledger.rds"))
  status <- if (all(profile_valid) && nrow(fit$restart_history) == 3L &&
      polish_valid && is.finite(final_gradient) && final_gradient <= 1e-3) {
    "G2I_SMOKE_COMPLETE"
  } else {
    "G2I_SMOKE_HOLD"
  }
}

stage("artifacts_written")
files <- list.files(root, full.names = TRUE)
utils::write.csv(data.frame(
  path = basename(files), md5 = vapply(files, hash, character(1L))
), file.path(root, "file-manifest.csv"), row.names = FALSE)
writeLines(c(
  paste("#", status),
  if (!is.na(classification)) paste("classification:", classification) else
    "classification: none"
), file.path(root, "smoke-receipt.md"))
cat(if (!is.na(classification)) classification else status, "\n")
