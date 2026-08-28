#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("usage: qualify-two-cell-source.R ARTIFACT_ROOT RUN_ROOT GLLVM_JL_PATH", call. = FALSE)
}
artifact_root <- normalizePath(args[[1L]], mustWork = TRUE)
run_root <- normalizePath(args[[2L]], mustWork = TRUE)
gllvmjl_path <- normalizePath(args[[3L]], mustWork = TRUE)
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
source(file.path(dirname(script_path), "two-cell-gate-lib.R"), local = TRUE)

sha256 <- function(path) {
  line <- system2("sha256sum", shQuote(path), stdout = TRUE)
  if (length(line) != 1L || !grepl("^[0-9a-f]{64}", line)) {
    stop("failed to hash ", path, call. = FALSE)
  }
  substr(line, 1L, 64L)
}

spec <- bridge_gate_spec()
paths <- list(
  gllvmtmb_archive = file.path(run_root, "incoming", "gllvmTMB-86e95fff.tar.gz"),
  gllvmjl_archive = file.path(run_root, "incoming", "GLLVMjl-00a2d7b7.tar.gz"),
  project = file.path(gllvmjl_path, "Project.toml"),
  manifest = file.path(gllvmjl_path, "Manifest.toml")
)
if (!all(file.exists(unlist(paths)))) stop("one or more source identity files are missing", call. = FALSE)

gllvmTMB::gllvm_julia_setup(jl_path = gllvmjl_path)
capabilities <- JuliaCall::julia_eval("GLLVM.bridge_capabilities()")
cap_text <- paste(capture.output(str(capabilities)), collapse = "\n")
if (!grepl("gaussian", cap_text, fixed = TRUE) || !grepl("poisson", cap_text, fixed = TRUE)) {
  stop("runtime capabilities do not expose both frozen families", call. = FALSE)
}
dll <- list.files(system.file("libs", package = "gllvmTMB"), pattern = "gllvmTMB.*\\.(so|dll|dylib)$", full.names = TRUE)
if (length(dll) != 1L) stop("exactly one installed gllvmTMB shared library was expected", call. = FALSE)

contract <- list(
  status = "eligible",
  gllvmtmb_sha = spec$gllvmtmb_sha,
  gllvmtmb_tree = spec$gllvmtmb_tree,
  gllvmjl_sha = spec$gllvmjl_sha,
  gllvmjl_tree = spec$gllvmjl_tree,
  gllvmtmb_archive_sha256 = sha256(paths$gllvmtmb_archive),
  gllvmjl_archive_sha256 = sha256(paths$gllvmjl_archive),
  project_sha256 = sha256(paths$project),
  manifest_status = "absent_in_source_generated_at_runtime",
  resolved_manifest_sha256 = sha256(paths$manifest),
  installed_dll_sha256 = sha256(dll),
  capability_status = "eligible_static_and_runtime",
  gllvmtmb_version = as.character(utils::packageVersion("gllvmTMB")),
  juliacall_version = as.character(utils::packageVersion("JuliaCall")),
  r_version = R.version.string,
  julia_version = as.character(JuliaCall::julia_eval("string(VERSION)")),
  gllvmjl_path = gllvmjl_path,
  installed_package_path = find.package("gllvmTMB"),
  installed_dll_path = dll,
  capabilities = capabilities,
  qualified_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
)
bridge_gate_validate_source_contract(contract)
saveRDS(contract, file.path(artifact_root, "source-contract.rds"))
dput(contract, file = file.path(artifact_root, "source-contract.txt"))
writeLines(capture.output(sessionInfo()), file.path(artifact_root, "R-sessionInfo.txt"))
file.copy(paths$manifest, file.path(artifact_root, "GLLVM-Manifest.toml"), overwrite = FALSE)
writeLines(cap_text, file.path(artifact_root, "GLLVM-capabilities.txt"))
cat("SOURCE_CONTRACT_ELIGIBLE\n")
