## Source-current formula gates for trait-axis-bridge.rds.
## Usage: Rscript dev/trait-axis-bridge/verify-formulas.R --pcm

args <- commandArgs(trailingOnly = TRUE)
allowed <- c("--pcm", "--column-slope", "--isdm-source")
if (length(args) != 1L || !args %in% allowed) {
  stop("Supply exactly one of: ", paste(allowed, collapse = ", "), call. = FALSE)
}

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
bridge <- readRDS(file.path("inst", "extdata", "examples", "trait-axis-bridge.rds"))

if (identical(args, "--pcm")) {
  tree <- bridge$pcm$tree
  formula <- bridge$pcm$formula
  environment(formula) <- environment()
  fit <- gllvmTMB(
    formula, data = bridge$pcm$data,
    trait = bridge$pcm$fit_args$trait, unit = bridge$pcm$fit_args$unit,
    family = bridge$pcm$fit_args$family, silent = TRUE
  )
  if (!inherits(fit, "gllvmTMB")) stop("PCM formula did not construct a gllvmTMB fit.")
  cat("PCM_FORMULA_GATE_OK\n")
}

if (identical(args, "--column-slope")) {
  tree <- bridge$column$tree
  formula <- bridge$column$formula
  environment(formula) <- environment()
  fit <- gllvmTMB(
    formula, data = bridge$column$data,
    trait = bridge$column$fit_args$trait, unit = bridge$column$fit_args$unit,
    family = bridge$column$fit_args$family, silent = TRUE
  )
  if (!inherits(fit, "gllvmTMB")) stop("Column-slope formula did not construct a gllvmTMB fit.")
  cat("COLUMN_SLOPE_FORMULA_GATE_OK\n")
}

if (identical(args, "--isdm-source")) {
  if (!identical(attr(bridge$isdm$family, "family_var"), "isdm_source")) {
    stop("iSDM source declaration is not source-current.")
  }
  ## Declaration is the source-current gate: fitting this small mixed-law data
  ## is intentionally left to the article's numerical admission workflow.
  cat("ISDM_SOURCE_GATE_OK\n")
}
