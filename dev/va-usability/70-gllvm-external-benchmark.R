## EXTERNAL benchmark: the CRAN-published `gllvm` package, scored on the same
## planted truth as our arms.
##
## Maintainer, 2026-08-05: "this is why we should be always compared against
## what is published in CRAN or more established."
##
## The A2 grid benchmarked our VA against OUR OWN Laplace. That is an internal
## control: it can show the two things we built agree, but it cannot show that
## either is right. `gllvm` (Niku, Hui, Taskinen, Warton) is the CRAN-published
## reference implementation of variational GLLVM ordination and is the external
## standard this work should be held to.
##
## It answers two things the internal control could not:
##   1. Is the binomial r ~ 0.59 latent-score ceiling ALSO where the
##      established package lands? If yes, the ceiling is a property of the
##      problem, confirmed OUTSIDE our own codebase.
##   2. Is our VA competitive with the state of the art, on truth?
##
## Same planted DGP, same seeds, same two statistics (trace ratio against
## planted Sigma_jj; orthogonal-Procrustes latent-score correlation against
## planted z) as `attenuation-lib.R`, so every number is directly comparable.
##
## Usage: Rscript dev/va-usability/70-gllvm-external-benchmark.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== gllvm external benchmark start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
stopifnot(requireNamespace("gllvm", quietly = TRUE))
cat("gllvm version:", as.character(utils::packageVersion("gllvm")), "\n")
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

N_SEED <- 20L
CORES  <- as.integer(Sys.getenv("PILOT_CORES", "8"))
## p = 8 is the information-starved cell where EVERY estimator we have measured
## collapses to r ~ 0.57 (dev/va-usability/60-pladder-summary.csv: our own VA
## climbs 0.568 -> 0.774 -> 0.859 -> 0.919 across p = 8/20/40/80). Benchmarking
## against gllvm at p = 8 alone would compare both packages at their worst and
## tell us little, so the grid carries a p = 20 cell too.
CELLS  <- list(list(family = "binomial", N0 = 150L, p =  8L),
               list(family = "binomial", N0 = 150L, p = 20L),
               list(family = "binomial", N0 = 400L, p =  8L),
               list(family = "gaussian_anchor", N0 = 150L, p =  8L))

## Wide response matrix from the shared long-format DGP. `sim_cell()` builds
## `d$y` as as.numeric(t(y)) over an N0 x T0 matrix, so the inverse is a
## byrow=TRUE fill -- verified below against the planted dimensions rather
## than assumed.
wide_from_long <- function(b, N0) {
  Y <- matrix(b$d$y, nrow = N0, ncol = T0, byrow = TRUE)
  stopifnot(nrow(Y) == N0, ncol(Y) == T0)
  Y
}

run_gllvm_seed <- function(seed_id, family, N0) {
  b <- sim_cell(seed_id, family, N0)
  Y <- wide_from_long(b, N0)
  X <- data.frame(x = b$d$x[seq(1L, nrow(b$d), by = T0)])
  fam <- switch(family,
                binomial = binomial(link = "logit"),
                gaussian_anchor = gaussian(),
                stop("unhandled family"))
  t0 <- Sys.time()
  f <- tryCatch(
    gllvm::gllvm(y = Y, X = X, formula = ~ x, family = fam,
                 num.lv = Q0, method = "VA", seed = seed_id, trace = FALSE),
    error = function(e) e
  )
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (inherits(f, "error")) {
    return(list(seed = seed_id, family = family, N0 = N0, fit_s = el,
                ok = FALSE, err = conditionMessage(f)))
  }
  ## Loadings: gllvm stores unit-scaled `theta`; the LV scale lives in
  ## `sigma.lv` and must be folded in before comparing to a planted Lambda.
  ## This is the same reconstruction dev/va-speed/29-head-to-head-gllvm.R:70-73
  ## already uses for this package.
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(f$params$sigma.lv, error = function(e) NULL)
  L  <- if (!is.null(sg)) sweep(th, 2L, sg, "*") else th
  sigma_hat_jj <- rowSums(L^2)
  trace_ratio  <- sum(sigma_hat_jj) / sum(b$sigma_jj_true)

  U <- as.matrix(f$lvs)
  R <- .procrustes_R(U, b$z_true)
  Ua <- U %*% R
  r_axis <- vapply(seq_len(Q0), function(k) stats::cor(Ua[, k], b$z_true[, k]), numeric(1))

  list(seed = seed_id, family = family, N0 = N0, fit_s = el, ok = TRUE,
       trace_ratio = trace_ratio, sigma_ratio = sigma_hat_jj / b$sigma_jj_true,
       latent_cor_mean = mean(abs(r_axis)))
}

run_cell <- function(cell) {
  T0 <<- as.integer(cell$p)   # attenuation-lib.R reads T0 from the global env
  seeds <- 20261400L + cell$N0 * 10L + cell$p + seq_len(N_SEED)
  cat(sprintf("-- gllvm %s n=%d p=%d (%d seeds) --\n",
              cell$family, cell$N0, cell$p, N_SEED))
  flush.console()
  res <- mclapply(seeds, function(s) {
    tryCatch(run_gllvm_seed(s, cell$family, cell$N0),
             error = function(e) list(seed = s, ok = FALSE, err = conditionMessage(e)))
  }, mc.cores = CORES, mc.preschedule = FALSE)
  saveRDS(res, sprintf("dev/va-usability/raw/A2-gllvm-%s_n%d_p%d.rds",
                       cell$family, cell$N0, cell$p))
  good <- Filter(function(r) isTRUE(r$ok), res)
  if (!length(good)) {
    return(data.frame(arm = "gllvm (CRAN)", family = cell$family, N0 = cell$N0,
                      p = cell$p, n_ok = 0L, n_att = length(res),
                      trace_mean = NA_real_, trace_median = NA_real_,
                      latent_r_mean = NA_real_, latent_r_sd = NA_real_,
                      fit_s_median = NA_real_))
  }
  data.frame(
    arm = "gllvm (CRAN)", family = cell$family, N0 = cell$N0, p = cell$p,
    n_ok = length(good), n_att = length(res),
    trace_mean = mean(vapply(good, function(r) r$trace_ratio, numeric(1)), na.rm = TRUE),
    trace_median = stats::median(vapply(good, function(r) r$trace_ratio, numeric(1)), na.rm = TRUE),
    latent_r_mean = mean(vapply(good, function(r) r$latent_cor_mean, numeric(1)), na.rm = TRUE),
    latent_r_sd = stats::sd(vapply(good, function(r) r$latent_cor_mean, numeric(1)), na.rm = TRUE),
    fit_s_median = stats::median(vapply(good, function(r) r$fit_s, numeric(1)), na.rm = TRUE)
  )
}

## Untimed warm-up so the first timed cell does not absorb load/JIT cost --
## the discipline dev/va-speed/57-gllvm-scaling.R:74-78 established after a
## retracted headline in this lane.
cat("== warm-up (untimed) ==\n"); flush.console()
invisible(tryCatch(run_gllvm_seed(999L, "binomial", 150L), error = function(e) NULL))
cat("== warm-up done ==\n\n"); flush.console()

out <- do.call(rbind, lapply(CELLS, run_cell))

cat("\n============ gllvm (CRAN 2.0.13) SCORED ON PLANTED TRUTH ============\n")
print(out, row.names = FALSE, digits = 4)
cat("\n-- our arms on the SAME DGP (A2-summary.csv, LA control, 60-pladder-summary.csv) --\n")
cat("  binomial n=150 p= 8 : VA-jj r=0.587  VA-gh r=0.571  LAPLACE r=0.563 | trace VA-jj 0.670\n")
cat("  binomial n=150 p=20 : VA-jj r=0.774                                  (p-ladder)\n")
cat("  binomial n=400 p= 8 : VA-jj r=0.593  VA-gh r=0.587  LAPLACE r=0.590 | trace VA-jj 0.582\n")
cat("  gaussian n=150 p= 8 : VA    r=0.937                 LAPLACE r=0.934 | trace VA    1.009\n")
cat("\nREAD (maintainer's bar, 2026-08-05: 'if we can get somewhere close or closer'):\n")
cat("  gllvm CLOSE to our numbers  => we are at the industry standard; ship it.\n")
cat("  gllvm materially HIGHER     => we have a real gap to close, and its size is now known.\n")
cat("  gllvm materially LOWER      => our route is ahead; verify before believing it.\n")
cat("  gllvm ALSO ~0.57 at p=8     => the thin-cell ceiling is confirmed OUTSIDE our codebase.\n")
write.csv(out, "dev/va-usability/70-gllvm-benchmark-summary.csv", row.names = FALSE)
cat(sprintf("\n== gllvm external benchmark done %s ==\n", format(Sys.time(), "%H:%M:%S")))
