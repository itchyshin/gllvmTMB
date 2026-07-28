## Totoro driver for the H4 same-start campaign. PURE R -- no TMB, no gllvmTMB, no
## package installation. Laplace is exactly k=1 of the same code path, so both arms
## share the DGP, the objective, the optimiser and the start and differ only in k.
suppressWarnings(suppressMessages(library(parallel)))
SRC <- Sys.getenv("H4_SRC", ".")
Sys.setenv(H4_SRC = SRC)
source(file.path(SRC, "aghq-h4-samestart.R"))

cells   <- read.csv(file.path(SRC, "h4-cells.csv"), stringsAsFactors = FALSE)
NCORES  <- as.integer(Sys.getenv("H4_CORES", "150"))
NSTART  <- as.integer(Sys.getenv("H4_NSTART", "5"))
OUT     <- Sys.getenv("H4_OUT", "h4-results.csv")
## q=4 at k=15 is 50625 nodes per site -- fence it rather than let one stratum
## dominate the wall clock. q=2 gets the full ladder.
KS_Q2 <- c(1L, 3L, 5L, 9L, 15L); KS_Q4 <- c(1L, 3L, 5L, 9L)

cat(sprintf("H4 campaign: %d cells x %d starts, %d cores\n", nrow(cells), NSTART, NCORES))
t0 <- Sys.time()
res <- mclapply(seq_len(nrow(cells)), function(i) {
  ce <- cells[i, ]
  ks <- if (ce$q >= 4L) KS_Q4 else KS_Q2
  tryCatch(run_cell(ce$n, ce$p, ce$q, ce$seed, ce$grp, KS = ks, n_start = NSTART),
           error = function(e) NULL)
}, mc.cores = NCORES, mc.preschedule = FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res, OUT, row.names = FALSE)
cat(sprintf("done in %.1f min; %d rows -> %s\n",
            as.numeric(Sys.time() - t0, units = "mins"), nrow(res), OUT))
