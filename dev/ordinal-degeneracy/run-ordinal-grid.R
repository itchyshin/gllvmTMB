## dev/ordinal-degeneracy/run-ordinal-grid.R
##
## Grid driver for the pre-registered ordinal calibration campaign
## (pass-criteria-ordinal.md). campaign-ordinal-calibration.R defines the
## simulators, fitters and `run_one()` but stages only --mode timing/smoke;
## this driver supplies the parallel grid loop and the aggregation.
##
## Usage (from the package root):
##   OPENBLAS_NUM_THREADS=1 CAMPAIGN_CORES=10 \
##     Rscript dev/ordinal-degeneracy/run-ordinal-grid.R [n_values] [seed_scale]

suppressMessages(devtools::load_all(".", quiet = TRUE))

## Evaluate the campaign script's definition prefix verbatim (everything
## above its --mode dispatch). Its own arg parsing runs harmlessly: no
## --mode is passed here, so MODE defaults to "timing" and is never read by
## the prefix.
defs <- readLines("dev/ordinal-degeneracy/campaign-ordinal-calibration.R")
cut <- grep("mode timing ---", defs)[1] - 1L
eval(parse(text = paste(defs[seq_len(cut)], collapse = "\n")), envir = globalenv())

args <- commandArgs(trailingOnly = TRUE)
N_VALUES <- if (length(args) >= 1L) as.integer(strsplit(args[1], ",")[[1]]) else c(100L, 400L)
CORES <- as.integer(Sys.getenv("CAMPAIGN_CORES", "10"))

## Seeds per arm, distributed across the n values. The healthy pool
## (healthy + transport + mixed) is what bounds the false-positive rate, so
## it is the arm set that must stay large.
SEEDS <- list(degenerate = 40L, healthy = 60L, transport = 60L, mixed = 50L)

## Optional per-n seed scaling (second CLI arg, comma-separated, one per n
## value). Lets the expensive large-n cells run at a reduced seed count so the
## whole grid stays inside the D-139 budget; the trim is reported, never
## silent.
SCALE <- if (length(args) >= 2L) {
  as.numeric(strsplit(args[2], ",")[[1]])
} else {
  rep(1, length(N_VALUES))
}
stopifnot(length(SCALE) == length(N_VALUES))

grid <- do.call(rbind, lapply(names(SEEDS), function(a) {
  do.call(rbind, lapply(seq_along(N_VALUES), function(k) {
    n_seed <- max(1L, as.integer(round(SEEDS[[a]] * SCALE[k])))
    data.frame(arm = a, n = N_VALUES[k], seed = seq_len(n_seed) + 1000L,
               stringsAsFactors = FALSE)
  }))
}))

cat(sprintf("ordinal calibration grid: %d fits over n = %s, cores = %d\n",
            nrow(grid), paste(N_VALUES, collapse = "/"), CORES))
t0 <- proc.time()[["elapsed"]]
rows <- parallel::mclapply(seq_len(nrow(grid)), function(i) {
  tryCatch(run_one(grid$arm[i], grid$n[i], grid$seed[i]),
           error = function(e) NULL)
}, mc.cores = CORES)
res <- do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
elapsed <- proc.time()[["elapsed"]] - t0

stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
out <- file.path("dev/ordinal-degeneracy/results",
                 sprintf("ordinal-calibration-%s.csv", stamp))
write.csv(res, out, row.names = FALSE)
cat(sprintf("ORDINAL GRID DONE in %.1f s | rows %d | %s\n", elapsed, nrow(res), out))
