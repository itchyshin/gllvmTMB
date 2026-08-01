#!/usr/bin/env Rscript
## Summarise dev/va-gate3/eva-parity/results/ladder-results.csv +
## ladder-lambda-comparison.csv into the numbers cited in the report.
out_dir <- "/private/tmp/gllvmtmb-va-in-06/dev/va-gate3/eva-parity/results"
d <- read.csv(file.path(out_dir, "ladder-results.csv"), stringsAsFactors = FALSE)
lam <- read.csv(file.path(out_dir, "ladder-lambda-comparison.csv"), stringsAsFactors = FALSE)

cat("=== rows attempted (every fit in the denominator) ===\n")
cat("total rows:", nrow(d), " (expect", 2 * 80, "for the full 80-cell grid)\n")
print(table(d$engine, d$status))

cat("\n=== gllvm convergence flag vs independent beta_exploded flag ===\n")
g <- d[d$engine == "gllvm", ]
print(table(reported_convergence = g$reported_convergence, beta_exploded = g$beta_exploded, useNA = "ifany"))
cat("Fraction of gllvm rows reporting convergence=TRUE that ALSO have beta_exploded=TRUE:\n")
cat(" ", mean(g$beta_exploded[g$reported_convergence %in% TRUE], na.rm = TRUE), "\n")

cat("\n=== ours: reported_healthy vs beta_exploded ===\n")
o <- d[d$engine == "ours", ]
print(table(reported_healthy = o$reported_healthy, beta_exploded = o$beta_exploded, useNA = "ifany"))

## clean subset: neither engine exploded for that cell
key <- function(x) paste(x$n, x$p, x$q, x$seed)
explode_by_cell <- tapply(d$beta_exploded, key(d), function(x) any(isTRUE(x[1]) || isTRUE(x[2]), na.rm = TRUE))
bad_cells <- names(explode_by_cell)[vapply(explode_by_cell, isTRUE, logical(1))]
d$cellkey <- key(d)
d$cell_clean <- !(d$cellkey %in% bad_cells)

cat("\n=== cells where NEITHER engine's beta exploded (clean subset) ===\n")
n_cells_total <- length(unique(d$cellkey))
n_cells_clean <- sum(!(unique(d$cellkey) %in% bad_cells))
cat(sprintf("%d / %d cells clean (%.0f%%)\n", n_cells_clean, n_cells_total, 100 * n_cells_clean / n_cells_total))

summarise_engine <- function(sub, label) {
  cat("\n--", label, "--\n")
  for (eng in c("ours", "gllvm")) {
    x <- sub[sub$engine == eng, ]
    cat(sprintf("  %-6s n=%3d  median rel_frob=%.4g  median kappa=%.4g  median beta_rmse=%.4g  median secs=%.3g\n",
                eng, nrow(x),
                median(x$rel_frob, na.rm = TRUE), median(x$kappa, na.rm = TRUE),
                median(x$beta_rmse, na.rm = TRUE), median(x$seconds, na.rm = TRUE)))
  }
}
summarise_engine(d, "ALL attempted rows")
summarise_engine(d[d$cell_clean, ], "CLEAN subset (neither engine's beta exploded)")

cat("\n=== direct Lambda-vs-Lambda agreement (Procrustes), ALL cells with a valid pair ===\n")
cat("n pairs:", nrow(lam), "\n")
cat("median rel_disagreement (rotation only, scale fixed at 1):", median(lam$rel_disagreement_rotation_only, na.rm = TRUE), "\n")
cat("median rel_disagreement (rotation + free scale)          :", median(lam$rel_disagreement_scaled, na.rm = TRUE), "\n")
cat("median fitted scale c (expect ~1 under genuine parity)    :", median(lam$fitted_scale, na.rm = TRUE), "\n")

lam_clean <- lam[!lam$both_beta_exploded, ]
cat("\n--- CLEAN subset (both_beta_exploded == FALSE) ---\n")
cat("n pairs:", nrow(lam_clean), "\n")
cat("median rel_disagreement (rotation only):", median(lam_clean$rel_disagreement_rotation_only, na.rm = TRUE), "\n")
cat("median rel_disagreement (rotation+scale):", median(lam_clean$rel_disagreement_scaled, na.rm = TRUE), "\n")
cat("median fitted scale c:", median(lam_clean$fitted_scale, na.rm = TRUE), "\n")
cat("IQR fitted scale c: [", quantile(lam_clean$fitted_scale, 0.25, na.rm=TRUE), ",",
    quantile(lam_clean$fitted_scale, 0.75, na.rm=TRUE), "]\n")

cat("\n=== per-cell side-by-side rel_frob (ours vs gllvm), CLEAN subset only ===\n")
wide <- reshape(d[d$cell_clean, c("n","p","q","seed","engine","rel_frob")],
                idvar = c("n","p","q","seed"), timevar = "engine", direction = "wide")
wide$rel_diff <- abs(wide$rel_frob.ours - wide$rel_frob.gllvm) /
  pmax(abs(wide$rel_frob.ours), abs(wide$rel_frob.gllvm), 1e-12)
print(wide[order(wide$n, wide$p, wide$q, wide$seed), ])
cat("\nmedian |ours-gllvm| relative difference in rel_frob, clean subset:", median(wide$rel_diff, na.rm = TRUE), "\n")

write.csv(d, file.path(out_dir, "ladder-results-annotated.csv"), row.names = FALSE)
cat("\nWrote", file.path(out_dir, "ladder-results-annotated.csv"), "\n")
