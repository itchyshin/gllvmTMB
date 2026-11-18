## One frozen numerical continuation candidate. This compares an unchanged
## two-pass baseline with exactly one additional identical BFGS pass. It never
## mutates the retained failed campaign files.

args <- commandArgs(trailingOnly = TRUE)
arg_value <- function(name) {
  hit <- grep(paste0("^", name, "="), args, value = TRUE)
  if (length(hit) != 1L) return(NULL)
  sub(paste0("^", name, "="), "", hit)
}
root <- normalizePath(".", mustWork = TRUE)
phi <- suppressWarnings(as.numeric(arg_value("--phi")))
seed <- suppressWarnings(as.integer(arg_value("--seed")))
output <- arg_value("--output")
if (length(phi) != 1L || !is.finite(phi) || length(seed) != 1L || is.na(seed) ||
    is.null(output) || !nzchar(output)) {
  stop("usage: Rscript --vanilla phylo-third-pass.R --phi=NUMERIC --seed=INTEGER --output=PATH", call. = FALSE)
}
output <- normalizePath(output, mustWork = FALSE)
if (file.exists(output)) stop("Refusing to overwrite a third-pass receipt.", call. = FALSE)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
script_dir <- file.path(root, "dev", "temporal-program", "remote")
sys.source(file.path(script_dir, "phylo-recovery-common.R"), envir = globalenv())
sys.source(file.path(script_dir, "phylo-third-pass-common.R"), envir = globalenv())
load_temporal_program_package(root)
baseline <- temporal_phylo_third_pass_fit(phi, seed, optimizer_passes = 2L)
candidate <- temporal_phylo_third_pass_fit(phi, seed, optimizer_passes = 3L)
adjudication <- temporal_phylo_third_pass_adjudicate(baseline, candidate)
commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = TRUE),
  error = function(e) NA_character_)
saveRDS(list(
  schema = "temporal_phylo_third_pass_v1", source_commit = unname(commit[[1L]]),
  phi = phi, seed = seed, controls = temporal_phylo_third_pass_controls(),
  baseline = list(history = baseline$history, state = baseline$state),
  candidate = list(history = candidate$history, state = candidate$state),
  adjudication = adjudication
), output)
cat(sprintf("TEMPORAL_PHYLO_THIRD_PASS_%s phi=%s seed=%d output=%s\n",
  if (isTRUE(adjudication$accepted)) "ACCEPT" else "REJECT", phi, seed, output))
