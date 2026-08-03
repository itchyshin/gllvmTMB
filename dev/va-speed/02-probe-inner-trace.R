#!/usr/bin/env Rscript
## dev/va-speed/02-probe-inner-trace.R
## Quick probe (tiny cell): how does TMB's inner Newton solve report its
## iteration count when profile_variational = TRUE? Establishes a reliable
## way to COUNT inner iterations before committing the full Q2 script to it.
## Not part of the timed profile -- infrastructure discovery only.

Sys.setenv(NOT_CRAN = "true")
suppressPackageStartupMessages(library(stats))
root <- "/private/tmp/gllvmtmb-va-speed"
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = TRUE))
`%||%` <- function(x, y) if (is.null(x)) y else x

set.seed(31)
n_tip <- 10L; T <- 4L; q <- 1L
tree <- ape::rcoal(n_tip)
levels_sp <- sort(tree$tip.label)
s <- .va_r3_phylo_structure(tree, levels_sp)
unit <- rep(seq_len(n_tip), each = T)
trait <- rep(seq_len(T), n_tip)
X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
y <- stats::rnorm(n_tip * T)

validated <- .va_r3_validate_data(
  y, rep(1L, n_tip * T), X, unit, trait, q,
  family = "gaussian_anchor", link = "identity",
  structured = s$structured,
  extra_tiers = list(list(kind = "diagonal", level_id = s$node_of_species[unit],
                          structured = TRUE, label = "phylo_psi"))
)
start_params <- .va_r3_default_parameters(validated, 1L)

cat("=== attempt 1: inner_control = list(trace = TRUE), silent = FALSE ===\n")
out1 <- capture.output({
  obj <- .va_r3_make_objective(validated, H = 15L, parameters = start_params,
                               eval_method = "auto", profile_variational = TRUE,
                               inner_control = list(trace = TRUE), silent = FALSE)
  v <- obj$fn(obj$par)
  g <- obj$gr(obj$par)
}, type = "output")
cat("n_lines_captured:", length(out1), "\n")
cat(paste(utils::head(out1, 30), collapse = "\n"), "\n")
saveRDS(out1, file.path(root, "dev", "va-speed", "probe-trace-out1.rds"))

cat("\n=== attempt 2: does obj$env expose an inner-iteration count directly? ===\n")
obj2 <- .va_r3_make_objective(validated, H = 15L, parameters = start_params,
                              eval_method = "auto", profile_variational = TRUE)
v2 <- obj2$fn(obj2$par)
nm <- ls(obj2$env)
cat("obj$env members matching iter/trace/count:\n")
print(grep("iter|trace|count|newton", nm, ignore.case = TRUE, value = TRUE))
cat("class(obj2$env$random):", class(obj2$env$random %||% NULL), "\n")
