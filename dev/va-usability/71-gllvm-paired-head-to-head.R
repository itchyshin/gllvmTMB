## gllvm (CRAN) vs our VA -- PAIRED on identical seeds, both fitted in this script.
##
## SUPERSEDES the unpaired comparison in 70-gllvm-external-benchmark.R for any
## claim about the DIFFERENCE between the two packages.
##
## WHY THIS EXISTS. `70-...R` fitted gllvm on its own seed stream
## (20261400 + N0*10 + p + 1:20) and compared the result to our numbers taken
## from TWO OTHER streams -- the A2 grid (20261100 + ...) and the p-ladder
## (20261300 + p*1000 + ...). Three independent samples. With per-cell
## sd ~ 0.083 at n = 20 the SE of an UNPAIRED difference is ~0.026, which
## swamps every observed gap (+0.004 to +0.029). The resulting claim, "we are
## marginally ahead on every cell", was NOT SUPPORTED and is retracted.
##
## This violated a rule the vault already holds and that this same session had
## just re-filed: [[WHAT-WORKS]] -- "Pair, don't sample independently;
## per-replicate agreement counts are far stronger evidence than similar
## averages." Recorded as a repeat, not a first offence.
##
## DESIGN. One `sim_cell(seed, family, N0)` per seed -> the SAME simulated data
## handed to BOTH engines. Per-seed paired differences, so the between-seed
## variance that dominates each marginal cancels. Reports the paired mean
## difference, its SE, and the per-seed win count -- the "per-replicate
## agreement" the rule asks for, not two averages side by side.
##
## Usage: Rscript dev/va-usability/71-gllvm-paired-head-to-head.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== PAIRED gllvm vs our VA start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
stopifnot(requireNamespace("gllvm", quietly = TRUE))
cat("gllvm version:", as.character(utils::packageVersion("gllvm")), "\n")
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

N_SEED <- 20L
CORES  <- as.integer(Sys.getenv("PILOT_CORES", "8"))
## Both engines see the SAME seeds. One stream, used twice.
CELLS <- list(list(family = "binomial",        N0 = 150L, p =  8L),
              list(family = "binomial",        N0 = 150L, p = 20L),
              list(family = "binomial",        N0 = 400L, p =  8L),
              list(family = "gaussian_anchor", N0 = 150L, p =  8L))

fit_gllvm_on <- function(b, N0, family) {
  Y <- matrix(b$d$y, nrow = N0, ncol = T0, byrow = TRUE)
  X <- data.frame(x = b$d$x[seq(1L, nrow(b$d), by = T0)])
  fam <- switch(family, binomial = binomial(link = "logit"),
                gaussian_anchor = gaussian(), stop("unhandled"))
  f <- tryCatch(gllvm::gllvm(y = Y, X = X, formula = ~ x, family = fam,
                             num.lv = Q0, method = "VA", trace = FALSE),
                error = function(e) e)
  if (inherits(f, "error")) return(NULL)
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(f$params$sigma.lv, error = function(e) NULL)
  L  <- if (!is.null(sg)) sweep(th, 2L, sg, "*") else th
  U  <- as.matrix(f$lvs); R <- .procrustes_R(U, b$z_true); Ua <- U %*% R
  list(trace = sum(rowSums(L^2)) / sum(b$sigma_jj_true),
       r = mean(abs(vapply(seq_len(Q0), function(k)
             stats::cor(Ua[, k], b$z_true[, k]), numeric(1)))))
}

one_seed <- function(s, family, N0) {
  b <- sim_cell(s, family, N0)                       # the SAME data for both
  ours <- tryCatch(run_seed(seed_id = s, family = family, N0 = N0),
                   error = function(e) NULL)
  ok_ours <- !is.null(ours) && is.null(ours$error) && isTRUE(ours$va_healthy)
  g <- fit_gllvm_on(b, N0, family)
  if (!ok_ours || is.null(g)) return(NULL)
  ours_tr <- if (!is.null(ours$trace_ratio)) as.numeric(ours$trace_ratio)[1] else
    sum(ours$sigma_ratio * b$sigma_jj_true) / sum(b$sigma_jj_true)
  list(seed = s, ours_r = ours$latent_cor_mean, gllvm_r = g$r,
       ours_trace = ours_tr, gllvm_trace = g$trace)
}

run_cell <- function(cell) {
  T0 <<- as.integer(cell$p)
  seeds <- 20261700L + cell$N0 * 10L + cell$p + seq_len(N_SEED)
  res <- Filter(Negate(is.null), mclapply(seeds, function(s)
    tryCatch(one_seed(s, cell$family, cell$N0), error = function(e) NULL),
    mc.cores = CORES, mc.preschedule = FALSE))
  if (!length(res)) return(NULL)
  dr <- vapply(res, function(r) r$ours_r - r$gllvm_r, numeric(1))
  dt <- vapply(res, function(r) r$ours_trace - r$gllvm_trace, numeric(1))
  n <- length(dr)
  se <- stats::sd(dr) / sqrt(n)
  cat(sprintf("-- %s n=%d p=%2d : %d pairs | ours_r=%.4f gllvm_r=%.4f | PAIRED d=%+.4f +/- %.4f | ours wins %d/%d --\n",
              cell$family, cell$N0, cell$p, n, mean(vapply(res, function(r) r$ours_r, numeric(1))),
              mean(vapply(res, function(r) r$gllvm_r, numeric(1))), mean(dr), se, sum(dr > 0), n))
  flush.console()
  data.frame(family = cell$family, N0 = cell$N0, p = cell$p, n_pairs = n,
             ours_r = mean(vapply(res, function(r) r$ours_r, numeric(1))),
             gllvm_r = mean(vapply(res, function(r) r$gllvm_r, numeric(1))),
             paired_dr = mean(dr), paired_dr_se = se,
             dr_ci_lo = mean(dr) - 1.96 * se, dr_ci_hi = mean(dr) + 1.96 * se,
             ours_wins = sum(dr > 0),
             ours_trace = mean(vapply(res, function(r) r$ours_trace, numeric(1))),
             gllvm_trace = mean(vapply(res, function(r) r$gllvm_trace, numeric(1))),
             paired_dtrace = mean(dt))
}

cat("== warm-up (untimed) ==\n"); flush.console()
invisible(tryCatch(one_seed(999L, "binomial", 150L), error = function(e) NULL))
cat("== warm-up done ==\n\n"); flush.console()

out <- do.call(rbind, Filter(Negate(is.null), lapply(CELLS, run_cell)))
cat("\n======== PAIRED: gllvm (CRAN 2.0.13) vs our VA, IDENTICAL seeds ========\n")
print(out, row.names = FALSE, digits = 4)
write.csv(out, "dev/va-usability/71-paired-summary.csv", row.names = FALSE)
cat("\nREAD: `paired_dr` with its 95% CI is the ONLY defensible statement about the\n")
cat("      difference. A CI spanning 0 means the two packages are indistinguishable\n")
cat("      on that cell -- which meets the maintainer's 'close or closer' bar and is\n")
cat("      NOT a claim that either is ahead. `ours_wins` out of n_pairs is the\n")
cat("      per-replicate agreement count [[WHAT-WORKS]] asks for.\n")
cat(sprintf("\n== PAIRED head-to-head done %s ==\n", format(Sys.time(), "%H:%M:%S")))
