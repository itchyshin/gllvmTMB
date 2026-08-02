## dev/boot-vs-profile-diagnosis.R
##
## Diagnose the 17-point coverage gap between `.profile_ci_total_variance()`
## (0.9467) and the exported `bootstrap_Sigma()` (0.7774 / 0.7810) for the SAME
## estimand -- the Sigma_unit diagonal V_t = (Lambda Lambda')[t,t] + psi[t] --
## reported in docs/dev-log/2026-07-29-certificate-run-record-v2.md.
##
## The campaign that produced 0.78 was invoked with NBOOT=10
## (dev/totoro-profile-rescore.sh -> --n-boot=10 -> bootstrap_Sigma(n_boot = 10)),
## one twentieth of the documented default of 200. `.summarise_draws()`
## (R/bootstrap-sigma.R:490) forms percentile bounds with stats::quantile()
## (type 7) at probs 0.025 / 0.975. With B = 10 those probs land between order
## statistics 1-2 and 9-10, i.e. essentially [min, max] of ten draws, whose
## maximum attainable coverage of an independent draw is (B-1)/(B+1) = 0.818.
##
## LEADING HYPOTHESIS: the 0.78 is a harness-configuration artifact (n_boot = 10),
## not a defect in bootstrap_Sigma().
##
## Design: for each replicate, run ONE bootstrap at B = B_MAX with
## keep_draws = TRUE, then form percentile CIs from (a) the first 10 draws and
## (b) all B_MAX draws. Identical refits, identical machinery -- the ONLY thing
## that varies is the number of draws entering quantile(). The profile CI is
## computed on the same fit. This isolates n_boot exactly.
##
## Rival hypotheses also instrumented:
##   - conditional-RE fallback: recorded via the simulator's one-shot warning.
##   - plug-in / ML downward bias: recorded as median(boot draws) - V_hat and
##     V_hat - truth, so bias-vs-width can be separated post hoc.
##
## DGP + fit copied verbatim from dev/m3-grid.R (m3_sample_truth,
## m3_simulate_response, m3_run_cell fit call) so the comparison is against the
## certified harness, not a re-invented fixture.
##
## Results are LOCAL (D-50): nothing here is written to inst/ or promoted.

suppressMessages(devtools::load_all(".", quiet = TRUE))

N_REPS  <- as.integer(Sys.getenv("N_REPS",  "40"))
B_MAX   <- as.integer(Sys.getenv("B_MAX",   "200"))
B_SMALL <- as.integer(Sys.getenv("B_SMALL", "10"))
D_RANK  <- as.integer(Sys.getenv("D_RANK",  "1"))
N_UNITS <- as.integer(Sys.getenv("N_UNITS", "150"))
N_TRAITS <- 5L
N_CORES <- as.integer(Sys.getenv("N_CORES", "1"))
B_LADDER <- c(10L, 20L, 50L, 100L, 200L)
SEED_BASE <- 771000L

## ---- DGP (verbatim structure from m3_sample_truth / m3_simulate_response) ----

make_rep <- function(seed, d, n_units, n_traits) {
  set.seed(seed)
  Lambda <- matrix(stats::runif(n_traits * d, -1.5, 1.5), n_traits, d)
  psi <- stats::rgamma(n_traits, shape = 2, rate = 2)
  Z <- matrix(stats::rnorm(n_units * d), n_units, d)
  diag_Sigma <- diag(tcrossprod(Lambda) + diag(psi, n_traits))

  e_unique <- matrix(stats::rnorm(n_units * n_traits), n_units, n_traits) *
    matrix(rep(sqrt(psi), each = n_units), n_units, n_traits)
  ## Gaussian trait: eta IS the response (no separate sigma_eps; see m3-grid).
  Y <- Z %*% t(Lambda) + e_unique

  unit_levels <- paste0("u", seq_len(n_units))
  trait_levels <- paste0("t", seq_len(n_traits))
  df <- data.frame(
    unit = factor(rep(unit_levels, each = n_traits), levels = unit_levels),
    trait = factor(rep(trait_levels, times = n_units), levels = trait_levels),
    value = as.numeric(t(Y))
  )
  list(data = df, diag_Sigma = diag_Sigma)
}

fit_one <- function(dat, d) {
  tryCatch(
    withCallingHandlers(
      gllvmTMB::gllvmTMB(
        value ~ 0 + trait +
          latent(0 + trait | unit, d = d) +
          unique(0 + trait | unit),
        data = dat,
        family = stats::gaussian(),
        unit = "unit"
      ),
      warning = function(w) invokeRestart("muffleWarning")
    ),
    error = function(e) e
  )
}

## Percentile bounds from the first `B` stored draws -- the SAME code path
## bootstrap_Sigma() uses internally (stats::quantile type 7).
pct_from_draws <- function(draws, B, conf = 0.95) {
  a <- (1 - conf) / 2
  mat <- vapply(
    draws[seq_len(B)],
    function(d) if (is.null(d$Sigma_B)) rep(NA_real_, N_TRAITS) else diag(d$Sigma_B),
    numeric(N_TRAITS)
  )
  list(
    lo = apply(mat, 1L, stats::quantile, probs = a, na.rm = TRUE, names = FALSE),
    hi = apply(mat, 1L, stats::quantile, probs = 1 - a, na.rm = TRUE, names = FALSE),
    med = apply(mat, 1L, stats::median, na.rm = TRUE)
  )
}

run_rep <- function(r) {
  seed <- SEED_BASE + 1000L * D_RANK + r
  sim <- make_rep(seed, D_RANK, N_UNITS, N_TRAITS)
  t0 <- Sys.time()
  fit <- fit_one(sim$data, D_RANK)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi") ||
        fit$opt$convergence != 0L) {
    return(NULL)
  }

  V_hat <- diag(gllvmTMB::extract_Sigma(fit, level = "unit",
                                        link_residual = "none")$Sigma)

  ## --- profile route (the certified, unexported one) ---
  prof <- tryCatch(
    gllvmTMB:::.profile_ci_total_variance(fit, tier = "unit", level = 0.95),
    error = function(e) NULL
  )

  ## --- bootstrap route: ONE run at B_MAX, draws retained ---
  fallback_warned <- FALSE
  boot <- tryCatch(
    withCallingHandlers(
      suppressMessages(gllvmTMB::bootstrap_Sigma(
        fit, n_boot = B_MAX, level = "unit", what = "Sigma",
        conf = 0.95, link_residual = "none",
        seed = seed + 9000000L, n_cores = 1L,
        progress = FALSE, keep_draws = TRUE
      )),
      warning = function(w) {
        if (grepl("conditional|redraw|not implemented", conditionMessage(w),
                  ignore.case = TRUE)) {
          fallback_warned <<- TRUE
        }
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) NULL
  )
  if (is.null(boot)) return(NULL)

  ## Ladder in B, all from the SAME stored draws: only the number of draws
  ## entering quantile() varies.
  ladder <- B_LADDER[B_LADDER <= B_MAX]
  lad <- lapply(ladder, function(B) {
    p <- pct_from_draws(boot$draws, B)
    setNames(
      data.frame(sim$diag_Sigma >= p$lo & sim$diag_Sigma <= p$hi, p$hi - p$lo),
      c(paste0("cov_B", B), paste0("w_B", B))
    )
  })
  b_small <- pct_from_draws(boot$draws, B_SMALL)
  b_big   <- pct_from_draws(boot$draws, B_MAX)

  cbind(do.call(cbind, lad), data.frame(
    rep = r,
    trait = seq_len(N_TRAITS),
    truth = sim$diag_Sigma,
    V_hat = V_hat,
    cov_prof = if (is.null(prof)) NA else
      sim$diag_Sigma >= prof$lower & sim$diag_Sigma <= prof$upper,
    w_prof = if (is.null(prof)) NA_real_ else prof$upper - prof$lower,
    cov_b10 = sim$diag_Sigma >= b_small$lo & sim$diag_Sigma <= b_small$hi,
    w_b10 = b_small$hi - b_small$lo,
    cov_bmax = sim$diag_Sigma >= b_big$lo & sim$diag_Sigma <= b_big$hi,
    w_bmax = b_big$hi - b_big$lo,
    boot_med = b_big$med,
    n_boot_failed = boot$n_failed,
    fallback_warned = fallback_warned,
    secs = as.numeric(difftime(Sys.time(), t0, units = "secs")),
    stringsAsFactors = FALSE
  ))
}

## ---- smoke: one replicate, timing, finiteness ----
cat(sprintf("SMOKE: 1 rep, d=%d, n=%d, B_MAX=%d\n", D_RANK, N_UNITS, B_MAX))
smoke <- run_rep(1L)
stopifnot(!is.null(smoke), nrow(smoke) == N_TRAITS)
stopifnot(all(is.finite(smoke$w_b10)), all(is.finite(smoke$w_bmax)))
print(smoke[, c("trait", "truth", "V_hat", "w_prof", "w_b10", "w_bmax",
                "cov_prof", "cov_b10", "cov_bmax")])
cat(sprintf("smoke ok; %.1f s/rep; boot refit failures = %d; RE-fallback warning = %s\n",
            smoke$secs[1], smoke$n_boot_failed[1], smoke$fallback_warned[1]))
cat(sprintf("projected wall time for %d reps on %d cores: %.1f min\n",
            N_REPS, N_CORES, smoke$secs[1] * N_REPS / N_CORES / 60))

## ---- full run ----
reps <- seq_len(N_REPS)
res_list <- if (N_CORES > 1L) {
  parallel::mclapply(reps, run_rep, mc.cores = N_CORES)
} else {
  lapply(reps, function(r) { cat(sprintf("  rep %d/%d\n", r, N_REPS)); run_rep(r) })
}
res <- do.call(rbind, Filter(function(x) !is.null(x) && is.data.frame(x), res_list))

cov_of <- function(x) mean(x, na.rm = TRUE)
mcse <- function(x) { p <- cov_of(x); n <- sum(!is.na(x)); sqrt(p * (1 - p) / n) }

cat("\n================ RESULT ================\n")
cat(sprintf("cells: %d rep-traits from %d converged reps (d=%d, n_units=%d)\n",
            nrow(res), length(unique(res$rep)), D_RANK, N_UNITS))
cat(sprintf("simulator conditional-RE fallback warning fired: %s\n",
            any(res$fallback_warned)))
cat(sprintf("bootstrap refit failures per rep (mean): %.2f of %d\n",
            mean(res$n_boot_failed), B_MAX))
ladder <- B_LADDER[B_LADDER <= B_MAX]
out <- data.frame(
  route = c("profile (unexported)",
            sprintf("bootstrap_Sigma B=%d", ladder)),
  coverage = c(cov_of(res$cov_prof),
               vapply(ladder, function(B) cov_of(res[[paste0("cov_B", B)]]), 0)),
  mcse = c(mcse(res$cov_prof),
           vapply(ladder, function(B) mcse(res[[paste0("cov_B", B)]]), 0)),
  mean_width = c(mean(res$w_prof, na.rm = TRUE),
                 vapply(ladder, function(B)
                   mean(res[[paste0("w_B", B)]], na.rm = TRUE), 0)),
  ceiling_minmax = c(NA_real_, (ladder - 1) / (ladder + 1))
)
print(out, row.names = FALSE)

cat("\n-- bias decomposition (does the interval sit in the wrong place?) --\n")
cat(sprintf("mean(V_hat - truth)        = %+.4f   (ML plug-in bias)\n",
            mean(res$V_hat - res$truth)))
cat(sprintf("mean(boot_median - V_hat)  = %+.4f   (bootstrap re-centering)\n",
            mean(res$boot_med - res$V_hat)))
for (tag in c("b10", "bmax")) {
  lo_miss <- sum(res[[paste0("cov_", tag)]] == FALSE & res$truth < res$V_hat,
                 na.rm = TRUE)
  hi_miss <- sum(res[[paste0("cov_", tag)]] == FALSE & res$truth >= res$V_hat,
                 na.rm = TRUE)
  cat(sprintf("%s: misses with truth below V_hat = %d, above = %d\n",
              tag, lo_miss, hi_miss))
}

## Theoretical ceiling for a [min, max]-style percentile interval at B draws.
cat(sprintf("\nreference: P(new draw inside [min,max] of B) = (B-1)/(B+1): B=%d -> %.3f, B=%d -> %.3f\n",
            B_SMALL, (B_SMALL - 1) / (B_SMALL + 1),
            B_MAX, (B_MAX - 1) / (B_MAX + 1)))

saveRDS(res, file.path("dev", sprintf("boot-vs-profile-diagnosis-d%d.rds", D_RANK)))
cat(sprintf("\nraw rows saved to dev/boot-vs-profile-diagnosis-d%d.rds\n", D_RANK))
