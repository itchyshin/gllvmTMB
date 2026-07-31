## =============================================================================
## 27-collect -- merge the DRAC per-task CSVs and run the pre-registered analysis
## =============================================================================
## The array writes one CSV per (cell, task) so a killed or partially-scheduled
## campaign still leaves every completed replicate intact. This merges them and
## hands the result to the SAME summariser the local runner uses, so the DRAC and
## local paths cannot drift in how they ANALYSE (they already cannot drift in how
## they SIMULATE -- see the DGP checksum in 27-drac-one-replicate.R).
##
## Usage:  RESDIR=~/gllvmtmb-aghq/results/stage1 Rscript 27-drac-collect.R
## =============================================================================
RESDIR <- Sys.getenv("RESDIR", "results/stage1")
OUT    <- Sys.getenv("MERGED", file.path(dirname(RESDIR), "24-campaign-stage1.csv"))

files <- list.files(RESDIR, pattern = "[.]csv$", full.names = TRUE)
if (!length(files)) stop("no result files in ", RESDIR)
cat(sprintf("merging %d task files from %s\n", length(files), RESDIR))

res <- do.call(rbind, lapply(files, function(f)
  tryCatch(read.csv(f, stringsAsFactors = FALSE), error = function(e) NULL)))
write.csv(res, OUT, row.names = FALSE)
cat(sprintf("merged: %d rows -> %s\n", nrow(res), OUT))

## ---- COMPLETENESS, reported rather than assumed -------------------------------
## A campaign that silently lost 12% of its tasks looks exactly like one that did
## not, so say what arrived before saying what it means.
cells <- unique(res[, c("family", "n", "lam_sd")])
cat("\n=== task completeness by cell ===\n")
for (i in seq_len(nrow(cells))) {
  cc <- cells[i, ]
  s <- res[res$family == cc$family & res$n == cc$n & res$lam_sd == cc$lam_sd, ]
  ntask <- length(unique(s$task))
  cat(sprintf("  %-9s n=%-5d lam=%.1f : %4d replicates, %4d arm-rows, %d fit failures\n",
              cc$family, cc$n, cc$lam_sd, ntask, nrow(s), sum(!s$ok)))
}
expected <- as.integer(Sys.getenv("NSIM", "400"))
short <- vapply(seq_len(nrow(cells)), function(i) {
  cc <- cells[i, ]
  length(unique(res$task[res$family == cc$family & res$n == cc$n & res$lam_sd == cc$lam_sd]))
}, integer(1))
if (any(short < expected)) {
  cat(sprintf("\n  *** INCOMPLETE: %d of %d cells have fewer than %d replicates ***\n",
              sum(short < expected), nrow(cells), expected))
  cat("  Re-submit the missing tasks before reading any contrast; a short cell\n")
  cat("  silently widens its MCSE and can flip a borderline verdict.\n")
} else {
  cat(sprintf("\n  all %d cells complete at %d replicates\n", nrow(cells), expected))
}

## ---- hand to the pre-registered summariser ------------------------------------
say <- function(...) cat(sprintf(...))
src <- Sys.getenv("SUMMARISER", "24-summarise.R")
if (file.exists(src)) {
  cat("\n"); source(src, local = TRUE)
} else {
  cat("\n(summariser not found at ", src, " -- merged CSV written, analyse locally)\n", sep = "")
}
