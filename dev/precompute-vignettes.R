## dev/precompute-vignettes.R
## ============================
## Reproducible precompute pipeline for empirical-coverage artefacts
## referenced by vignettes and the validation-debt register.
##
## Phase 0C / PR-0C.COVERAGE scope (2026-05-16): Gaussian baseline only.
## d = 2 / n_sites = 60 / T = 4 traits / R = 200 reps / methods = wald +
## profile. Closes the Phase 1b validation milestone's empirical-coverage
## gate for the Gaussian cell. Non-Gaussian and mixed-family cells walk
## to `covered` at the M3 close PR (per ROADMAP M3.3).
##
## Run from the repo root: `Rscript dev/precompute-vignettes.R`.
## Output: dev/precomputed/coverage-gaussian-d2.rds
##
## Compute: ~ 10–25 min on a 2025 laptop (R = 200 refits + per-rep
## profile). Set N_REPS below to a smaller value (e.g. 30) to dry-run.
## Wall-clock is recorded inside the saved object.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(stats)
})

## ---- Configuration ----------------------------------------------------

N_SITES <- 60L
N_TRAITS <- 4L
D <- 2L
N_REPS <- 200L
METHODS <- c("wald", "profile")
SEED <- 20260516L

OUT_DIR <- file.path("dev", "precomputed")
OUT_FILE <- file.path(OUT_DIR, "coverage-gaussian-d2.rds")

if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

## ---- Simulate base Gaussian fixture -----------------------------------

set.seed(SEED)

df <- expand.grid(
  site  = factor(seq_len(N_SITES)),
  trait = factor(paste0("t", seq_len(N_TRAITS)))
)

## Generate Gaussian responses from a known DGP: rank-2 Lambda + diagonal
## unique variance. The base fit recovers the marginal latent + unique
## decomposition; coverage_study() repeats parametric bootstrap from the
## fitted parameters to estimate empirical coverage.
Lambda_true <- matrix(
  c( 0.8,  0.0,
     0.6,  0.5,
     0.4, -0.6,
     0.2,  0.7),
  nrow = N_TRAITS, ncol = D, byrow = TRUE
)
psi_true <- rep(0.25, N_TRAITS)

eta_true <- matrix(rnorm(N_SITES * D), nrow = N_SITES) %*% t(Lambda_true)
y_mat <- eta_true + matrix(rnorm(N_SITES * N_TRAITS, sd = sqrt(psi_true)),
                            nrow = N_SITES, byrow = TRUE)

df$value <- as.numeric(y_mat[cbind(as.integer(df$site),
                                   as.integer(df$trait))])

## ---- Base fit ---------------------------------------------------------

cat("[precompute] fitting base Gaussian rank-2 fit ...\n")
t_fit <- system.time({
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = D) +
                        unique(0 + trait | site),
    data   = df,
    trait  = "trait",
    unit   = "site",
    family = gaussian()
  )
})
cat(sprintf("[precompute] base fit done in %.1fs (convergence = %d)\n",
            t_fit["elapsed"], fit$opt$convergence))
stopifnot(fit$opt$convergence == 0L)

## ---- Empirical coverage at R = N_REPS ---------------------------------

cat(sprintf("[precompute] coverage_study(n_reps = %d, methods = %s) ...\n",
            N_REPS, paste(METHODS, collapse = ", ")))
t_cov <- system.time({
  cov_res <- coverage_study(
    fit,
    n_reps   = N_REPS,
    methods  = METHODS,
    seed     = SEED,
    progress = FALSE
  )
})
cat(sprintf("[precompute] coverage_study done in %.1fs\n",
            t_cov["elapsed"]))

## ---- Persist artefact -------------------------------------------------

artefact <- list(
  meta = list(
    created_at    = format(Sys.time(), tz = "UTC", usetz = TRUE),
    gllvmTMB_ver  = as.character(utils::packageVersion("gllvmTMB")),
    R_version     = R.version.string,
    seed          = SEED,
    config        = list(n_sites = N_SITES, n_traits = N_TRAITS, d = D,
                         n_reps = N_REPS, methods = METHODS),
    timings_sec   = list(fit = unname(t_fit["elapsed"]),
                         coverage = unname(t_cov["elapsed"]))
  ),
  fit_summary = list(
    convergence = fit$opt$convergence,
    logLik      = as.numeric(logLik(fit)),
    n_par       = length(fit$opt$par)
  ),
  coverage = cov_res
)

saveRDS(artefact, OUT_FILE)
cat(sprintf("[precompute] saved -> %s\n", OUT_FILE))
cat("[precompute] done.\n")
