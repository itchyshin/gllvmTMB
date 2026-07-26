#!/usr/bin/env Rscript

# Validate the retained private comparison manifest without re-fitting models.

args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[[1]], mustWork = TRUE) else getwd()
path <- file.path(root, "dev", "va-eva-engine-spine", "receipts",
                  "2026-07-26-va-eva-executable-comparison.rds")
if (!file.exists(path)) stop("Run the isolated comparison tracks before this check.", call. = FALSE)
x <- readRDS(path)

stopifnot(isTRUE(x$provenance$research_only))
stopifnot(identical(x$provenance$track_isolation,
                    "one fresh R process per template-owning track"))
source_paths <- names(x$provenance$source_sha256)
stopifnot(identical(
  unname(tools::sha256sum(file.path(root, source_paths))),
  unname(x$provenance$source_sha256)
))
child_dir <- file.path(root, "dev", "va-eva-engine-spine", "receipts", "executable-run")
child_paths <- file.path(child_dir, names(x$provenance$child_sha256))
stopifnot(all(file.exists(child_paths)))
stopifnot(identical(unname(tools::sha256sum(child_paths)), unname(x$provenance$child_sha256)))
receipt <- file.path(root, "dev", "va-eva-engine-spine", "receipts",
                     "2026-07-26-va-eva-executable-comparison.md")
receipt_hash <- sub("^Manifest SHA-256: ", "", grep("^Manifest SHA-256: ", readLines(receipt), value = TRUE))
stopifnot(length(receipt_hash) == 1L, identical(receipt_hash, unname(tools::sha256sum(path))))
calls <- c(x$multitrial$calls, x$bernoulli$calls)
needed <- c("internal_va_r3", "gllvmTMB_laplace", "gllvm_va",
            "internal_eva_gate1", "gllvm_eva")
stopifnot(all(needed %in% vapply(calls, `[[`, character(1), "name")))
stopifnot(all(vapply(calls, function(z) z$status %in% c("ok", "error", "extract_error",
                                                          "not_converged", "evaluated_fixed_gate1_fixture",
                                                          "boundary_or_invalid_for_comparison"), logical(1))))
stopifnot(identical(x$bernoulli$calls$internal_eva_gate1$status,
                    "evaluated_fixed_gate1_fixture"))
stopifnot(identical(x$bernoulli$calls$laplace$status,
                    "boundary_or_invalid_for_comparison"))
stopifnot(identical(x$bernoulli$calls$gllvm_eva$status,
                    "boundary_or_invalid_for_comparison"))
ladder <- x$multitrial$calls$internal_va_r3$diagnostics$quadrature_ladder
stopifnot(isTRUE(ladder$available), identical(ladder$orders, c(15L, 25L, 61L)),
          is.finite(ladder$max_abs_spread))
stopifnot(identical(dim(x$multitrial$calls$gllvm_va$diagnostics$LambdaLambdaT), c(2L, 2L)))
stopifnot(identical(dim(x$bernoulli$calls$gllvm_eva$diagnostics$LambdaLambdaT), c(2L, 2L)))
stopifnot(x$exact$va_scalar$max_abs_gap < 1e-9)
stopifnot(x$exact$eva_gate1$max_abs_gap < 1e-10)
stopifnot(identical(x$multitrial$calls$internal_va_r3$diagnostics$score$model_selection_comparable,
                    FALSE))
stopifnot(identical(x$bernoulli$calls$internal_eva_gate1$diagnostics$score$model_selection_comparable,
                    FALSE))

cat("VA_EVA_EXECUTABLE_COMPARISON_MANIFEST_PASS\n")
