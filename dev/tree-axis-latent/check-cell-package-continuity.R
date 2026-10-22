#!/usr/bin/env Rscript
# Usage: capture OUTDIR; or compare OLD_DIR NEW_DIR RECEIPT_PATH.
# Launch capture separately with R_LIBS pointing to each immutable installation.
# Stops before MakeADFun; never constructs a tape or enters an optimizer.
library(gllvmTMB)
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 1L, args[1L] %in% c("capture", "compare"))
root <- "/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88"
runner <- "dev/tree-axis-latent/run-fit.R"
fixture_path <- "dev/tree-axis-latent/fixture.R"
this_script <- "dev/tree-axis-latent/check-cell-package-continuity.R"
sha <- function(path) digest::digest(file = path, algo = "sha256")
ids <- c("G1", "G2", "G3", "GW1", "GW2", "GW3")
stopifnot(identical(unname(tools::md5sum(fixture_path)),
                    "6c3bae640dd86491171cb20fbb56b0e4"))

if (args[1L] == "compare") {
  stopifnot(length(args) == 4L, !file.exists(args[4L]))
  old <- readRDS(file.path(args[2L], "receipt.rds"))
  new <- readRDS(file.path(args[3L], "receipt.rds"))
  stopifnot(identical(old$ids, ids), identical(new$ids, ids),
    identical(old$metadata$R, new$metadata$R),
    identical(old$metadata$TMB, new$metadata$TMB),
    old$optimizer_entries == 0L, new$optimizer_entries == 0L,
    old$tapes_constructed == 0L, new$tapes_constructed == 0L)
  checks <- setNames(lapply(ids, function(id) {
    a <- readRDS(file.path(args[2L], paste0(id, ".rds")))
    b <- readRDS(file.path(args[3L], paste0(id, ".rds")))
    fields <- c("data", "parameters", "map", "random")
    checks <- setNames(vapply(fields, function(field) identical(a$payload[[field]],
                                                               b$payload[[field]]), logical(1)), fields)
    checks <- c(checks, rng = identical(a$payload$rng, b$payload$rng),
      reconstructed_starts = identical(a$reconstructed_starts, b$reconstructed_starts),
      retained_starts = isTRUE(a$all_retained_starts_identical) && isTRUE(b$all_retained_starts_identical))
    message(id, " ", paste(names(checks), checks, collapse = "; "))
    checks
  }), ids)
  pass <- all(unlist(checks))
  saveRDS(list(pass = pass, checks = checks, old_metadata = old$metadata,
    new_metadata = new$metadata, old_receipt_sha256 = sha(file.path(args[2L], "receipt.rds")),
    new_receipt_sha256 = sha(file.path(args[3L], "receipt.rds")),
    outer_optimizer_calls = 0L, tapes_constructed = 0L), args[4L])
  stopifnot(pass)
  cat("CELL_PACKAGE_CONTINUITY_PASS_SIX_PAYLOADS_TWELVE_STARTS_EXACT_NO_TAPES_NO_OPTIMIZERS\n")
  quit(status = 0L)
}

stopifnot(length(args) == 2L, dir.create(args[2L], recursive = FALSE, showWarnings = FALSE))
outdir <- args[2L]
metadata <- list(library = normalizePath(find.package("gllvmTMB")),
  dll_sha256 = sha(file.path(find.package("gllvmTMB"), "libs/gllvmTMB.so")),
  R = R.version.string, TMB = as.character(packageVersion("TMB")),
  fixture_md5 = unname(tools::md5sum(fixture_path)),
  runner_sha256 = sha(runner), checker_sha256 = sha(this_script),
  fit_function_sha256 = digest::digest(getFromNamespace("gllvmTMB_multi_fit", "gllvmTMB"), algo = "sha256"),
  estimate_seconds = "less than 10", cap_seconds = 60L,
  outer_optimizer_calls = 0L, tapes_constructed = 0L)
saveRDS(metadata, file.path(outdir, "admission.rds"))
.continuity_optimizer_entries <- 0L
for (name in c("nlminb", "optim")) trace(name, where = asNamespace("stats"), print = FALSE,
  tracer = quote({
    .GlobalEnv$.continuity_optimizer_entries <- .GlobalEnv$.continuity_optimizer_entries + 1L
    stop("No optimizer permitted in package continuity capture")
  }))
trace(".gllvmTMB_run_nlminb", where = asNamespace("gllvmTMB"), print = FALSE,
  tracer = quote({
    .GlobalEnv$.continuity_optimizer_entries <- .GlobalEnv$.continuity_optimizer_entries + 1L
    stop("No optimizer permitted in package continuity capture")
  }))
source(fixture_path)
fixture <- make_tree_axis_fixture("target")
# Reuse only the two reviewed call-building function definitions, never the
# runner's admission, fitting or validation top-level statements.
runner_expr <- parse(runner)
function_names <- c(".tree_axis_formula_env", ".tree_axis_fit_call")
selected <- vapply(runner_expr, function(x) is.call(x) &&
  identical(x[[1L]], as.name("<-")) && is.name(x[[2L]]) &&
  as.character(x[[2L]]) %in% function_names, logical(1))
stopifnot(sum(selected) == 2L)
eval(runner_expr[selected], envir = globalenv())

capture <- function(spec, start_spec) {
  intercepted <- NULL
  entries <- 0L
  warnings <- character()
  testthat::local_mocked_bindings(
    MakeADFun = function(data, parameters, map, random, ...) {
      entries <<- entries + 1L
      intercepted <<- list(data = data, parameters = parameters, map = map,
                           random = random, rng = get(".Random.seed", envir = globalenv()))
      stop("continuity-payload-captured-before-tape", call. = FALSE)
    }, .package = "TMB")
  error <- tryCatch(withCallingHandlers(.tree_axis_fit_call(fixture, spec, start_spec),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      message("CAPTURE_WARNING ", conditionMessage(w))
      invokeRestart("muffleWarning")
    }), error = identity)
  stopifnot(inherits(error, "error"),
    identical(conditionMessage(error), "continuity-payload-captured-before-tape"), entries == 1L)
  list(payload = intercepted, warnings = warnings, intercepted_entries = entries)
}

reconstruct_initial <- function(payload, template) {
  # Parameter ordering is inherited from the original recorded TMB vector.
  # Exact old/new payload equality independently protects packing order and
  # mapping. Here each free block's values are reconstructed without a tape.
  blocks <- lapply(names(payload$parameters), function(name) {
    if (name %in% payload$random) return(numeric())
    value <- as.numeric(payload$parameters[[name]])
    mp <- payload$map[[name, exact = TRUE]]
    if (is.null(mp)) return(value)
    stopifnot(is.factor(mp), length(mp) == length(value))
    value[match(levels(mp), as.character(mp))]
  })
  names(blocks) <- names(payload$parameters)
  blocks <- blocks[lengths(blocks) > 0L]
  stopifnot(setequal(names(blocks), unique(names(template))))
  initial <- template * 0
  for (name in names(blocks)) {
    at <- names(template) == name
    stopifnot(sum(at) == length(blocks[[name]]))
    initial[at] <- blocks[[name]]
  }
  initial
}
for (id in ids) {
  source_path <- file.path(root, paste0("fit-", id, ".rds"))
  retained <- readRDS(source_path)
  stopifnot(isTRUE(retained$integrated_gaussian_diag_B),
    identical(retained$start, list(seed = 202608501L, init_jitter = 0.15)))
  result <- capture(retained$spec, retained$start)
  saveRDS(c(result, list(retained_receipt_sha256 = sha(source_path))),
          file.path(outdir, paste0(id, "-payload.rds")))
  initial <- reconstruct_initial(result$payload, retained$optimizer_calls[[1L]]$start)
  starts <- list(initial)
  assign(".Random.seed", result$payload$rng, envir = globalenv())
  n <- length(retained$optimizer_calls)
  if (n > 1L) for (i in 2:n) starts[[i]] <- getFromNamespace(".gllvmTMB_reclamp_start_par", "gllvmTMB")(
    initial + stats::rnorm(length(initial), sd = retained$start$init_jitter))
  same <- vapply(seq_len(n), function(i) identical(starts[[i]], retained$optimizer_calls[[i]]$start), logical(1))
  result$reconstructed_starts <- starts
  result$retained_start_identity <- same
  result$all_retained_starts_identical <- all(same)
  result$retained_receipt_sha256 <- sha(source_path)
  saveRDS(result, file.path(outdir, paste0(id, ".rds")))
  message(id, " captured before tape; retained start identity: ", paste(same, collapse = ","))
  stopifnot(all(same), result$payload$data$integrate_gaussian_diag_B == 1L)
}
stopifnot(.continuity_optimizer_entries == 0L)
saveRDS(list(ids = ids, metadata = metadata, optimizer_entries = .continuity_optimizer_entries,
  tapes_constructed = 0L), file.path(outdir, "receipt.rds"))
cat("CELL_PACKAGE_CAPTURE_PASS_SIX_PAYLOADS_TWELVE_STARTS_NO_TAPES_NO_OPTIMIZERS\n")
