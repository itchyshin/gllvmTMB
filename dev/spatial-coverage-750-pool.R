## Pool the issue-#750 coverage shards into one tight per-cell coverage table.
## Usage: Rscript dev/spatial-coverage-750-pool.R
files <- list.files("dev/cov-shards", pattern = "^shard-.*\\.rds$", full.names = TRUE)
cat("shards found:", length(files), "\n")
stopifnot(length(files) > 0)
agg <- do.call(rbind, lapply(files, readRDS))
pooled <- aggregate(cbind(n_reps, n_covered) ~ parm + method, data = agg, FUN = sum)
pooled$rate <- pooled$n_covered / pooled$n_reps
pooled$mcse <- sqrt(pooled$rate * (1 - pooled$rate) / pooled$n_reps)
pooled$hi2 <- round(pooled$rate + 2 * pooled$mcse, 3)   # 2-MCSE upper band
## Honest per-cell verdict vs the 0.94 gate (target = nominal 0.95):
##   CLEARS>=0.94 = point rate at/above the gate
##   BELOW-0.94   = even the +2-MCSE band < 0.94 (a genuine shortfall)
##   within-noise = straddles 0.94
pooled$verdict <- ifelse(pooled$rate >= 0.94, "CLEARS>=0.94",
                  ifelse(pooled$hi2 < 0.94, "BELOW-0.94", "within-noise"))
pooled$rate <- round(pooled$rate, 3)
pooled$mcse <- round(pooled$mcse, 4)
cat("== POOLED coverage, N =", pooled$n_reps[1], "reps/cell ==\n")
print(pooled[order(pooled$parm), ], row.names = FALSE)
saveRDS(pooled, "dev/spatial-coverage-750-pooled.rds")
