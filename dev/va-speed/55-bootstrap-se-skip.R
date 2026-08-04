## Does skipping sdreport on THROWAWAY bootstrap replicates change the answer? It must not.
##
## `bootstrap_Sigma()` builds PERCENTILE CIs from the spread across replicates, and
## `.extract_summaries()` -- the only thing applied to each refit -- has zero references to
## `sd_report`. So each replicate was running a full TMB::sdreport() and discarding it, at a
## measured 22-39% of Laplace wall-clock (docs/design/laplace-cost-profile.md), nsim times over.
##
## THE ACCEPTANCE BAR IS EXACT EQUALITY, not "close". Both arms use the same seed, so the
## simulated responses are identical and the refits are the same optimisation problem; skipping
## a POST-hoc uncertainty calculation cannot legitimately move a point estimate. If any bound
## moves at all, the assumption "the replicate's SEs are unused" is WRONG somewhere and this
## change must be reverted rather than explained away.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

NSIM <- 30L
set.seed(20260804L)
N <- 60L; T0 <- 6L
lam <- matrix(rnorm(T0, 0, 0.8), T0, 1)
a <- matrix(rnorm(N), N, 1)
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
y <- eta + matrix(rnorm(N * T0, 0, 0.5), N, T0)
d <- data.frame(value = as.numeric(t(y)),
                trait = factor(rep(seq_len(T0), times = N)),
                site  = factor(rep(seq_len(N),  each = T0)))

cat("== fitting the base model ==\n"); flush.console()
fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
                data = d, family = gaussian(), trait = "trait", site = "site",
                silent = TRUE)
cat("base fit done\n"); flush.console()

## ARM is supplied by the caller and names which VERSION OF THE SOURCE is loaded -- the arms are
## produced by running this same script against the unpatched and patched `R/bootstrap-sigma.R`,
## NOT by a runtime switch. That keeps the comparison honest: nothing in this script can
## accidentally emulate the fix.
ARM <- commandArgs(trailingOnly = TRUE)[[1]]

## `seed=` is passed explicitly rather than relying on set.seed(): it is the function's own
## documented control over the simulated responses, so both arms draw the SAME data and the
## refits are the same optimisation problem. That is what makes exact equality the right bar.
t0 <- proc.time()[["elapsed"]]
b <- bootstrap_Sigma(fit, n_boot = NSIM, seed = 99L, progress = FALSE)
el <- proc.time()[["elapsed"]] - t0

cat(sprintf("\n== ARM=%s  %d replicates  %.2fs ==\n", ARM, NSIM, el))
print(utils::head(b, 4))
saveRDS(list(arm = ARM, secs = el, res = b),
        sprintf("dev/va-speed/55-boot-%s.rds", ARM))
cat(sprintf("== %s DONE ==\n", ARM))
