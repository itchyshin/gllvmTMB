#!/usr/bin/env Rscript
## dev/va-speed/03-probe-hesspattern-once.R
## Is "Matching hessian patterns" a ONE-TIME symbolic-factorization cost, or
## does it redo every call? Call fn/gr twice each at two different points and
## see which trace lines repeat. Infrastructure discovery only.

Sys.setenv(NOT_CRAN = "true")
suppressPackageStartupMessages(library(stats))
root <- "/private/tmp/gllvmtmb-va-speed"
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = TRUE))

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
obj <- .va_r3_make_objective(validated, H = 15L, parameters = start_params,
                             eval_method = "auto", profile_variational = TRUE,
                             inner_control = list(trace = TRUE), silent = FALSE)
par0 <- obj$par
par1 <- obj$par + 0.01

for (call in list(list("fn", par0), list("gr", par0), list("fn", par1), list("gr", par1),
                  list("fn", par0), list("gr", par0))) {
  what <- call[[1]]; p <- call[[2]]
  out <- capture.output({
    if (identical(what, "fn")) obj$fn(p) else obj$gr(p)
  })
  n_iter_lines <- sum(grepl("^iter:", out))
  has_pattern_match <- any(grepl("Matching hessian patterns", out))
  has_tape_opt <- any(grepl("Optimizing tape", out))
  cat(sprintf("call=%s n_iter_lines=%d hessian_pattern_match=%s tape_opt=%s\n",
              what, n_iter_lines, has_pattern_match, has_tape_opt))
}
