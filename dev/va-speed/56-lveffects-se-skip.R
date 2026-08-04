## A/B for the same discard in bootstrap_ci_lv_effects(): does skipping sdreport on THROWAWAY
## replicates change the answer? It must not. Same acceptance bar as 55: EXACT equality.
##
## This path needs `latent(..., lv = ~ x)` -- a predictor-informed latent term -- or the
## function aborts, so the DGP below plants one.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

ARM  <- commandArgs(trailingOnly = TRUE)[[1]]
NB   <- 25L
set.seed(20260804L)
N <- 60L; T0 <- 5L
x <- rnorm(N)
lam <- matrix(rnorm(T0, 0, 0.8), T0, 1)
a <- matrix(0.7 * x + rnorm(N, 0, 0.6), N, 1)   ## latent scores driven by x
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
y <- eta + matrix(rnorm(N * T0, 0, 0.5), N, T0)
d <- data.frame(value = as.numeric(t(y)),
                trait = factor(rep(seq_len(T0), times = N)),
                site  = factor(rep(seq_len(N),  each = T0)),
                x     = rep(x, each = T0))

cat("== base fit ==\n"); flush.console()
fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1, lv = ~ x),
                data = d, family = gaussian(), trait = "trait", site = "site",
                silent = TRUE)
cat("base fit done\n"); flush.console()

t0 <- proc.time()[["elapsed"]]
b <- bootstrap_ci_lv_effects(fit, n_boot = NB, seed = 7L, progress = FALSE)
el <- proc.time()[["elapsed"]] - t0

cat(sprintf("\n== ARM=%s  %d replicates  %.2fs ==\n", ARM, NB, el))
print(utils::head(b, 4))
saveRDS(list(arm = ARM, secs = el, res = b),
        sprintf("dev/va-speed/56-lveff-%s.rds", ARM))
cat(sprintf("== %s DONE ==\n", ARM))
