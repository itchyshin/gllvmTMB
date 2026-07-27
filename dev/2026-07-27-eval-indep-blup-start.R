## Does the upgraded `indep` (BLUP-SVD loadings) beat `res` and match `default`
## on the cells where `res` was shown to land on a worse optimum?
## Seeds reproduce the 2026-07-27 breadth sweep cell() construction exactly.
suppressPackageStartupMessages(devtools::load_all("/private/tmp/gllvmtmb-va-wiring-20260726", quiet = TRUE))
options(gllvmTMB.quiet_grammar_notes = TRUE, warn = -1)

obj_of <- function(ff, dat, ctrl) {
  f <- try(gllvmTMB(ff, data = dat, control = ctrl), silent = TRUE)
  if (inherits(f, "try-error")) return(NA_real_)
  f$opt$objective
}

cell <- function(seed, p = 3L, d = 1L) {
  set.seed(seed)
  Lam <- matrix(round(runif(p * p, -0.8, 0.8), 2), p, p)
  sim <- simulate_site_trait(n_sites = 200, n_species = 15, n_traits = p,
    mean_species_per_site = 8, Lambda_B = Lam, psi_B = rep(0.3, p), seed = seed)
  ff <- as.formula(sprintf("value ~ 0 + trait + latent(0 + trait | site, d = %d)", d))
  o <- c(
    default = obj_of(ff, sim$data, gllvmTMBcontrol(n_init = 1L)),
    res     = obj_of(ff, sim$data, gllvmTMBcontrol(n_init = 1L,
                start_method = list(method = "res"))),
    indep   = obj_of(ff, sim$data, gllvmTMBcontrol(n_init = 1L,
                start_method = list(method = "indep")))
  )
  best <- min(o, na.rm = TRUE)
  cat(sprintf("seed %4d | default %+8.3f | res %+8.3f | indep %+8.3f   (nats above best)\n",
              seed, o["default"] - best, o["res"] - best, o["indep"] - best))
  flush.console()
  data.frame(seed = seed, t(o), best = best)
}

## The 4 seeds where `res` was materially worse, plus 4 where it was fine.
bad  <- c(301L, 401L, 1001L, 1901L)
good <- c(101L, 201L, 601L, 801L)
cat("=== cells where res was WORSE ===\n")
B <- do.call(rbind, lapply(bad, cell))
cat("\n=== control cells where res was fine ===\n")
G <- do.call(rbind, lapply(good, cell))

all <- rbind(B, G)
all$res_gap   <- all$res   - pmin(all$default, all$res, all$indep, na.rm = TRUE)
all$indep_gap <- all$indep - pmin(all$default, all$res, all$indep, na.rm = TRUE)
all$def_gap   <- all$default - pmin(all$default, all$res, all$indep, na.rm = TRUE)
cat("\n=== TALLY (nats above the best of the three; 0 = found the best optimum) ===\n")
print(all[, c("seed", "def_gap", "res_gap", "indep_gap")], row.names = FALSE)
cat(sprintf("\nreached best: default %d/%d | res %d/%d | indep %d/%d\n",
            sum(all$def_gap < 0.01), nrow(all),
            sum(all$res_gap < 0.01), nrow(all),
            sum(all$indep_gap < 0.01), nrow(all)))
saveRDS(all, "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB--claude-worktrees-awesome-fermat-0e06a9/bb280ead-2f7e-4ac6-ad5a-1e04da29afe3/scratchpad/eval-indep.rds")
cat("\nDONE\n")
