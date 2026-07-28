## Wall-clock, measured back-to-back in ONE process so both arms see the same
## machine load. Usage: Rscript dev/aghq-timing-fair.R <pkg_root>
a <- commandArgs(TRUE)
suppressMessages(devtools::load_all(a[1], quiet = TRUE))
source("dev/arc0/lib.R")
d <- arc0_data(60, 6, 2, 7)
for (rep in 1:2) {
  t0 <- Sys.time()
  f <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::binomial(),
                                 control = gllvmTMBcontrol(aghq = 9L)))
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("rep %d: passes=%3s  nll=%.8f  %.1fs\n", rep,
              f$aghq$passes %||% NA, f$opt$objective, el))
}
