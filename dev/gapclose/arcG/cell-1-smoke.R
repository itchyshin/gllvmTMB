#!/usr/bin/env Rscript
## Cell-1 local smoke: smallest arcG grid cell through coverage harness.
## Cell-1 = n_units=40, d=1, n_traits=4 (coverage-design.md Section 4).
## Uses extract_latent_scores() for z_hat / u_true; ordination_uncertainty() for se.
##
## Usage (from repo root):
##   NOT_CRAN=true Rscript dev/gapclose/arcG/cell-1-smoke.R
##
## Requires devtools::load_all(".") — run via wrapper or source after load_all.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

repo_root <- Sys.getenv("GLLVMTMB_ROOT", unset = normalizePath(getwd(), winslash = "/"))
setwd(repo_root)

if (!nzchar(Sys.getenv("NOT_CRAN"))) {
  stop("Set NOT_CRAN=true (real fit required, not skip-on-cran path)")
}

message("Running devtools::load_all('.') ...")
t_load <- system.time(devtools::load_all(".", quiet = TRUE))["elapsed"]
message(sprintf("load_all elapsed: %.1f s", t_load))
stopifnot(exists("extract_latent_scores", mode = "function"))

source("dev/gapclose/arcG/coverage-harness.R", local = TRUE)

CELL1 <- arcG_grid()[[1L]]  ## cell01_d1_n40_t4
SEEDS <- c(501L, 502L, 503L)  ## smoke: 3 seeds (disjoint from campaign 1:500)

cat(sprintf("\n=== Cell-1 smoke: %s (n_sites=%d, d=%d, n_traits=%d) ===\n",
            CELL1$label, CELL1$n_sites, CELL1$d, CELL1$n_traits))
cat(sprintf("HEAD: %s\n", substr(trimws(system("git rev-parse HEAD", intern = TRUE)), 1, 12)))
cat(sprintf("Seeds: %s\n\n", paste(SEEDS, collapse = ", ")))

t_cell <- system.time({
  results <- lapply(SEEDS, function(s) arcG_run_one_seed(CELL1, s, verbose = TRUE))
})

## Aggregate smoke summary
ok <- vapply(results, function(r) identical(r$status, "ok"), logical(1))
conv <- vapply(results, function(r) isTRUE(r$converged == 0L), logical(1))
pd <- vapply(results, function(r) isTRUE(r$pdHess), logical(1))
dims_ok <- vapply(results, function(r) {
  identical(r$status, "ok") &&
    identical(r$z_dims, c(CELL1$n_sites, CELL1$d)) &&
    identical(r$u_dims, c(CELL1$n_sites, CELL1$d)) &&
    identical(r$se_dims, c(CELL1$n_sites, CELL1$d))
}, logical(1))

cov90 <- vapply(results, function(r) {
  if (r$status != "ok") return(NA_real_)
  r$coverage$nominal_0.9$coverage
}, numeric(1))
cov95 <- vapply(results, function(r) {
  if (r$status != "ok") return(NA_real_)
  r$coverage$nominal_0.95$coverage
}, numeric(1))

pass <- all(ok) && all(conv) && all(pd) && all(dims_ok) &&
  all(is.finite(cov90)) && all(is.finite(cov95))

summary_row <- data.frame(
  cell = CELL1$label,
  n_seeds = length(SEEDS),
  n_ok = sum(ok),
  n_converged = sum(conv),
  n_pdHess = sum(pd),
  n_dims_ok = sum(dims_ok),
  mean_cov90 = mean(cov90, na.rm = TRUE),
  mean_cov95 = mean(cov95, na.rm = TRUE),
  wall_s = as.numeric(t_cell["elapsed"]),
  pass = pass,
  stringsAsFactors = FALSE
)

out_csv <- "dev/gapclose/arcG/cell-1-smoke-results.csv"
write.csv(summary_row, out_csv, row.names = FALSE)

cat("\n=== Cell-1 VERDICT ===\n")
print(summary_row, row.names = FALSE)
cat(sprintf("\nCell-1: %s\n", if (pass) "PASS" else "FAIL"))
cat(sprintf("Results: %s\n", out_csv))

if (!pass) quit(status = 1)
