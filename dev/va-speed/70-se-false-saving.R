suppressMessages(library(gllvmTMB))
Sys.setenv(OPENBLAS_NUM_THREADS="1", OMP_NUM_THREADS="1")
mk <- function(N, T0=8L, seed=1L) {
  set.seed(seed)
  g <- expand.grid(site=seq_len(N), trait_idx=seq_len(T0))
  g$trait <- factor(paste0("t", g$trait_idx)); g$site_f <- factor(g$site)
  u <- rnorm(N, 0, 0.8)
  g$value <- (g$trait_idx*0.4) + u[g$site] + rnorm(nrow(g), 0, 0.5); g
}
tm <- function(e) { t0 <- proc.time()[["elapsed"]]; force(e); proc.time()[["elapsed"]] - t0 }
run <- function(d, se) gllvmTMB(value ~ 0+trait+(1|site_f), data=d, family=gaussian(),
                                unit="site_f", control=gllvmTMBcontrol(se=se))
cat(sprintf("%-7s %10s %10s %9s\n","N","se=TRUE","se=FALSE","saving"))
for (N in c(250L, 1000L, 2500L)) {
  d <- mk(N); invisible(run(d, TRUE))                       # warm, untimed
  # INTERLEAVED: alternate arms within each rep, order rotated
  A <- numeric(3); B <- numeric(3)
  for (r in 1:3) if (r %% 2 == 1) { A[r] <- tm(run(d,TRUE)); B[r] <- tm(run(d,FALSE)) }
                 else            { B[r] <- tm(run(d,FALSE)); A[r] <- tm(run(d,TRUE)) }
  cat(sprintf("%-7d %10.3f %10.3f %8.2fx\n", N, median(A), median(B), median(A)/median(B)))
}
