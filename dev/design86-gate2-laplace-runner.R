## Design 86 Gate 2: unchanged live-Laplace descriptive comparator.  It consumes
## the immutable input manifest written from the same frozen data as the EVA arm.

.d86_laplace_root <- function() {
  root <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    if (file.exists(file.path(root, "R", "fit-multi.R"))) return(root)
    parent <- dirname(root)
    if (identical(parent, root)) break
    root <- parent
  }
  stop("Run from the Design 86 worktree or source this runner there.", call. = FALSE)
}

source(file.path(.d86_laplace_root(), "dev", "design86-gate2-eva-runner.R"))

.d86_laplace_dll_path <- function() {
  dlls <- getLoadedDLLs()
  candidates <- vapply(dlls, function(x) x[["path"]], character(1))
  hit <- candidates[basename(candidates) %in% c("gllvmTMB.so", "gllvmTMB.dll", "gllvmTMB.dylib")]
  if (length(hit) != 1L) NA_character_ else hit[[1L]]
}

design86_gate2_laplace_run <- function(seed, output_root = NULL) {
  root <- .d86_laplace_root(); runner <- file.path(root, "dev", "design86-gate2-laplace-runner.R")
  p <- .eva_read_gate2_parameters(); input <- .eva_gate2_input(seed)
  if (is.null(output_root)) output_root <- file.path(root, p$provenance$output_root)
  manifest <- .d86_input_manifest(input, root, output_root)
  if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required for the live source comparator.", call. = FALSE)
  pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
  live <- asNamespace("gllvmTMB")
  d <- input$long_data
  names(d)[names(d) == "unit"] <- "site"
  set.seed(as.integer(seed) + 1000000L)
  ctl <- get("gllvmTMBcontrol", envir = live)(n_init = as.integer(p$starts$Laplace$n_starts),
    init_jitter = p$starts$Laplace$control$init_jitter, optimizer = "nlminb",
    optArgs = p$starts$Laplace$control$optArgs)
  fit <- tryCatch(get("gllvmTMB", envir = live)(
    value ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE), data = d,
    trait = "trait", unit = "site", unit_obs = "site", cluster = "site",
    family = stats::binomial(link = "logit"), REML = FALSE, engine = "tmb", control = ctl,
    silent = TRUE), error = identity)
  selected <- if (inherits(fit, "error")) NULL else fit$restart_history[fit$restart_history$selected, , drop = FALSE]
  fh <- if (inherits(fit, "error")) NULL else fit$fit_health
  healthy <- !inherits(fit, "error") && nrow(selected) == 1L && isTRUE(selected$success[[1L]]) &&
    identical(as.integer(fh$convergence), 0L) && is.finite(fit$opt$objective) &&
    is.finite(fh$max_gradient) && fh$max_gradient < 1e-2
  beta_hat <- Sigma_B_hat <- NULL
  if (!inherits(fit, "error")) {
    beta_hat <- get(".gllvmTMB_b_fix_values", envir = live)(fit)
    Sigma_B_hat <- get("extract_Sigma", envir = live)(fit, level = "unit", part = "shared",
      link_residual = "none")$Sigma
  }
  result <- list(gate = "G2", arm = "LAPLACE_DESCRIPTIVE_ONLY", seed = as.integer(seed),
    denominator_id = p$denominator$id, input_manifest_sha256 = manifest$sha256, hashes = input$hashes,
    I_unit = as.list(unclass(summary(input$I_unit))), I_unit_q10_type8 = unname(stats::quantile(input$I_unit, 0.10, type = 8)),
    restart_history = if (inherits(fit, "error")) NULL else fit$restart_history,
    selected_restart = if (is.null(selected)) NA_integer_ else selected$restart[[1L]],
    healthy = healthy, error = if (inherits(fit, "error")) conditionMessage(fit) else NA_character_,
    beta_hat = beta_hat, Sigma_B_hat = Sigma_B_hat,
    pd_hessian_report_only = if (is.null(fh)) NA else fh$pd_hessian)
  dll_path <- .d86_laplace_dll_path()
  source_receipt <- list(
    source_commit = .d86_git(root, c("rev-parse", "HEAD")),
    source_tree_clean = identical(system2("git", c("-C", root, "diff", "--quiet")), 0L),
    engine_source_sha256 = .d86_sha256_file(file.path(root, "src", "gllvmTMB.cpp")),
    driver_source_sha256 = .d86_sha256_file(file.path(root, "R", "fit-multi.R")),
    runner_source_sha256 = .d86_sha256_file(runner),
    dll_sha256 = if (is.na(dll_path)) NA_character_ else .d86_sha256_file(dll_path)
  )
  arm_dir <- file.path(output_root, "laplace")
  result_path <- file.path(arm_dir, sprintf("seed-%s-result.json", seed)); .d86_write_json_once(result, result_path)
  receipt <- c(list(parameter_file_sha256 = .d86_sha256_file(.eva_gate2_file()),
    inputs_manifest_sha256 = manifest$sha256,
    output_root_repo_relative = sub(paste0("^", root, "/?"), "", normalizePath(output_root, mustWork = FALSE)),
    denominator_id = p$denominator$id), source_receipt)
  receipt$output_manifest_sha256 <- .d86_sha256_file(result_path)
  .d86_write_json_once(receipt, file.path(arm_dir, sprintf("seed-%s-receipt.json", seed)))
  invisible(list(result = result, receipt = receipt, input_manifest = manifest, paths = list(result = result_path)))
}
