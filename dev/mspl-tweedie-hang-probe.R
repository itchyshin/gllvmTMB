## Timeout-bounded #999 8x3 Tweedie MSPL hang probe.
## Not a public door. Requires GLLVMTMB_MSPL_TWEEDIE_PROBE=1.
## Call via:  timeout 90 env GLLVMTMB_MSPL_TWEEDIE_PROBE=1 \
##   Rscript --vanilla dev/mspl-tweedie-hang-probe.R
## Do not run from testthat / CI.
##
## Default nlminb (no iter.max cap). Tweedie skips the MSPL BFGS
## rescue. Working W_* + Huber is the existence tape.

Sys.setenv(GLLVMTMB_MSPL_TWEEDIE_PROBE = "1")
if (!identical(Sys.getenv("GLLVMTMB_MSPL_TWEEDIE_PROBE"), "1")) {
  stop("probe env failed to set", call. = FALSE)
}

suppressPackageStartupMessages({
  if (dir.exists("/private/tmp/gllvmtmb-mspl-tweedie-hang/R")) {
    pkgload::load_all("/private/tmp/gllvmtmb-mspl-tweedie-hang", quiet = TRUE)
  } else {
    library(gllvmTMB)
  }
})
cat(sprintf("PROBE_LIB=%s\n", system.file(package = "gllvmTMB")))

dat <- data.frame(
  site = factor(rep(seq_len(8L), each = 3L)),
  trait = factor(rep(paste0("t", seq_len(3L)), 8L)),
  y = rep(c(0.5, 1, 2), length.out = 24L)
)

cat("PROBE_START_FIT\n")
t0 <- proc.time()[["elapsed"]]
fit <- gllvmTMB(
  y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
  data = dat,
  family = tweedie(),
  estimator = "mspl",
  control = gllvmTMBcontrol(
    n_init = 1L,
    init_jitter = 0,
    se = FALSE,
    warn_runaway = FALSE
  )
)
elapsed <- proc.time()[["elapsed"]] - t0

cat(sprintf(
  "PROBE_OK class=%s registry=%s elapsed=%.3fs optimizer=%s\n",
  paste(class(fit), collapse = "/"),
  if (is.null(fit$mspl$registry_status)) "NA" else fit$mspl$registry_status,
  elapsed,
  if (is.null(fit$opt$optimizer_used)) "NA" else fit$opt$optimizer_used
))
