#!/usr/bin/env Rscript
## Arc E aggregation -- ledger claim 30: "we have a better VA than gllvm" is
## NOT ESTABLISHED, and two attempts to claim it (claim 16, 1 seed; claim 18,
## 6 seeds) were RETRACTED for being underpowered. The ledger names the settling
## arc: model-matched, >=10 seeds, interleaved, speed AND accuracy AND psi.
##
## This reports all three, plus the PAIRED per-seed win count -- because a
## median over seeds can hide a coin-flip, and a coin-flip is exactly what the
## two retracted claims mistook for a ranking.

fs <- Sys.glob("dev/va-speed/arcE/fw2-s*.rds")
a <- do.call(rbind, lapply(fs, readRDS))

cat("seed files:", length(fs), " rows:", nrow(a), " seeds:", length(unique(a$seed)), "\n")
cat("cell: N=120 T=10 n_trials=6 psi_true=0.6, serial, arm order rotated per replicate\n")

## STATUS BEFORE RESULT -- this lane's standing rule.
if ("status" %in% names(a)) {
  cat("\nstatus values present:", paste(sort(unique(as.character(a$status))), collapse = ", "), "\n")
}

cat("\n===== ACCURACY rel_frob (median over 12 seeds; LOWER IS BETTER) =====\n")
print(aggregate(rf ~ arm, a, median), row.names = FALSE, digits = 4)

cat("\n===== SPEED seconds (median) =====\n")
print(aggregate(secs ~ arm, a, median), row.names = FALSE, digits = 3)

cat("\n===== psi recovery (planted truth 0.6; VA arms only) =====\n")
p <- a[!is.na(a$psi), ]
if (nrow(p)) print(aggregate(psi ~ arm, p, median), row.names = FALSE, digits = 4)

cat("\n===== per-seed rel_frob RANGE (does 12 seeds resolve the arms?) =====\n")
rng <- aggregate(rf ~ arm, a, function(z) c(min = min(z), max = max(z)))
out <- data.frame(arm = rng$arm, min = round(rng$rf[, "min"], 3), max = round(rng$rf[, "max"], 3))
print(out, row.names = FALSE)

cat("\n===== PAIRED head-to-head, per seed (the thing claims 16/18 lacked) =====\n")
m <- aggregate(rf ~ arm + seed, a, median)
w <- reshape(m, idvar = "seed", timevar = "arm", direction = "wide")
names(w) <- sub("^rf[.]", "", names(w))
pair <- function(ours, theirs) {
  if (!all(c(ours, theirs) %in% names(w))) return(invisible(NULL))
  wins <- sum(w[[ours]] < w[[theirs]])
  cat(sprintf("  %-9s beats %-9s on %2d of %2d seeds\n", ours, theirs, wins, nrow(w)))
}
pair("ours-LA", "gllvm-LA"); pair("ours-LA", "gllvm-VA")
pair("ours-AC", "gllvm-VA"); pair("ours-GH", "gllvm-VA")

cat("\n===== SPEED, paired =====\n")
ms <- aggregate(secs ~ arm + seed, a, median)
ws <- reshape(ms, idvar = "seed", timevar = "arm", direction = "wide")
names(ws) <- sub("^secs[.]", "", names(ws))
spair <- function(ours, theirs) {
  if (!all(c(ours, theirs) %in% names(ws))) return(invisible(NULL))
  cat(sprintf("  %-9s faster than %-9s on %2d of %2d seeds (median ratio %.2fx)\n",
              ours, theirs, sum(ws[[ours]] < ws[[theirs]]), nrow(ws),
              median(ws[[theirs]] / ws[[ours]])))
}
spair("ours-LA", "gllvm-LA"); spair("ours-AC", "gllvm-VA"); spair("ours-GH", "gllvm-VA")
