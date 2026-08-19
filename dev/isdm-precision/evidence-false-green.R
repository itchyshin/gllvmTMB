suppressMessages(devtools::load_all(".", quiet = TRUE))
set.seed(4)
n <- 120; sp <- c("a","b")
env <- rnorm(n)
mk <- function(mult) do.call(rbind, lapply(seq_along(sp), function(j)
  data.frame(cell_id=factor(seq_len(n)), trait=sp[j],
             value=rpois(n, exp(mult + 0.8*env)), env=env)))
for (mult in c(1, 8, 14, 18)) {
  d <- mk(mult); d$trait <- factor(d$trait, levels=sp)
  f <- try(suppressWarnings(suppressMessages(gllvmTMB(value ~ 0+trait+trait:env,
      data=d, trait="trait", unit="cell_id", family=poisson(), silent=TRUE))),
      silent=TRUE)
  if (inherits(f,"try-error")) { cat(sprintf("mult %2d: ERROR\n", mult)); next }
  it <- if (!is.null(f$opt$iterations)) f$opt$iterations else NA
  cat(sprintf("mult %2d | maxcount %.3g | conv %s | iters %s | obj %.4g\n",
      mult, max(d$value), f$opt$convergence, it, f$opt$objective))
}
