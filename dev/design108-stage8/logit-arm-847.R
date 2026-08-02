## #847 RECONCILIATION ARM -- binomial-LOGIT, matched to #847's own design.
##
## WHY THIS EXISTS
## ---------------
## Issue #847 (comment, 2026-08-01) reports, for `laplace_ridge` at
## sigma_lambda = 3:
##     n=100: 0% runaway (med ||Lam_hat||/||Lam|| = 0.666)
##     n=400: 1%          (1.216)
##     n=1600: **67%**    (**2.185**)
## and, for `aghq_ridge` with the IDENTICAL tau = 2, 0% at every n (0.908 at
## n=1600) -- "same penalty, same DGP, same seeds -- opposite outcome".
##
## The Design 108 s0.2 campaign (3600 fits, 2026-08-02) measured the SAME arm
## (gllvmTMBcontrol(aghq_ridge = 2) on the Laplace path = #847's `laplace_ridge`)
## at the SAME nominal cell and got **0%**, median ratio **0.959**.
##
## HYPOTHESES ALREADY TESTED AND REJECTED (do not re-test):
##   * "It is a metric mismatch." REJECTED. Re-scored the existing 3600 rows
##     under #847's own criterion (||Lam_hat||_F/||Lam||_F > 2, computable as
##     sqrt(attenuation) since attenuation = trace(Sig_hat)/trace(Sig_true) and
##     trace(Lam Lam') = ||Lam||_F^2). Both criteria agree on that data: 0% at
##     the cell under BOTH, and 14.2% vs 15.8% overall. The criteria are broadly
##     equivalent; the disagreement is real, not definitional.
##
## THE REMAINING LEADING CANDIDATE: **family**. The s0.2 grid has NO logit arm --
## it is binomial-PROBIT, ordinal-PROBIT and gaussian only. #847's evidence is
## binomial, and the sibling audit table (2026-07-30 s6) is explicitly binomial.
## Probit and logit differ in exactly the way that should matter here: the probit
## template CLAMPS p to [1e-12, 1-1e-12] (src/gllvmTMB.cpp:2119-2142), zeroing
## the AD gradient on the clamped branch, whereas the logistic path does not use
## that floor. So this arm asks one question:
##
##     Does binomial-LOGIT reproduce #847's 67% where binomial-PROBIT gave 0%?
##
## FALSIFIER, stated before the run: if logit ALSO gives ~0% at n=1600,
## sigma_lambda=3 with the ridge, then family is NOT the explanation either, and
## the remaining candidates are p, the DGP, or an error in one of the two
## measurements. Report that outcome plainly -- it is the more expensive answer.
##
## DESIGN MATCHED TO #847, not to the s0.2 campaign:
##   n in {100, 400, 1600}      -- #847's exact n values
##   sigma_lambda in {1, 3}     -- #847's exact sigma_lambda values
##   p in {6, 12}               -- #847 cites p=6 for one table; p unstated for
##                                 the sigma_lambda table, so span it
##   arms: default / ridge2     -- ridge2 == #847's `laplace_ridge`
##   30 seeds
## Metric: BOTH criteria reported side by side, so the comparison cannot turn on
## a threshold choice.
##
## Results are LOCAL (D-50). Never a GitHub artifact, never committed.

suppressPackageStartupMessages(library(mirai))
OUT <- path.expand("~/gllvm_work/results"); dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
SMOKE <- isTRUE(as.logical(Sys.getenv("GRID_SMOKE", "FALSE")))
NWORK <- as.integer(Sys.getenv("GRID_WORKERS", "96"))

grid <- expand.grid(
  miss         = 0,
  arm          = c("default", "ridge2"),
  sigma_lambda = c(1, 3),
  n            = c(100L, 400L, 1600L),
  p            = c(6L, 12L),
  seed         = 1:30,
  stringsAsFactors = FALSE
)
grid$q <- 2L
grid$family <- "binomial_logit"
if (SMOKE) grid <- grid[grid$n == 100L & grid$p == 6L & grid$seed == 1L & grid$sigma_lambda == 3, ]

run_cell <- function(cell) {
  Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1", MKL_NUM_THREADS = "1")
  suppressPackageStartupMessages(library(gllvmTMB))
  with(cell, {
    arm_ix <- as.integer(arm == "ridge2"); sig_ix <- as.integer(sigma_lambda == 3)
    set.seed(seed * 9173L + n + p * 13L + arm_ix * 104729L + sig_ix * 251519L)
    Lam <- matrix(stats::rnorm(p * q, 0, sigma_lambda), p, q)
    Z   <- matrix(stats::rnorm(n * q), n, q)
    Sig_true <- Lam %*% t(Lam)
    eta <- Z %*% t(Lam)
    B  <- stats::rnorm(p, 0, 0.3)
    lp <- eta + matrix(B, n, p, byrow = TRUE)
    ## LOGIT link -- the one axis this arm changes.
    yv <- stats::rbinom(n * p, 1, stats::plogis(as.numeric(t(lp))))
    dat <- data.frame(trait = factor(rep(seq_len(p), times = n)),
                      site  = factor(rep(seq_len(n), each = p)), y = yv)
    ctrl <- if (arm == "ridge2") gllvmTMB::gllvmTMBcontrol(aghq_ridge = 2)
            else                 gllvmTMB::gllvmTMBcontrol()
    fml <- stats::as.formula(sprintf(
      "y ~ 0 + trait + latent(0 + trait | site, d = %d, unique = FALSE)", q))
    base <- data.frame(family = "binomial_logit", miss = miss, arm = arm,
                       sigma_lambda = sigma_lambda, n = n, p = p, q = q, seed = seed,
                       stringsAsFactors = FALSE)
    t0 <- proc.time()[["elapsed"]]
    r <- tryCatch(gllvmTMB::gllvmTMB(fml, data = dat, unit = "site",
                                     family = stats::binomial(link = "logit"),
                                     control = ctrl),
                  error = function(e) structure(list(msg = conditionMessage(e)), class = "cellerr"))
    secs <- proc.time()[["elapsed"]] - t0
    if (inherits(r, "cellerr"))
      return(cbind(base, seconds = secs, status = "ERROR", convergence = NA_integer_,
                   pdHess = NA, rel_frob = NA_real_, ratio = NA_real_, note = r$msg))
    Lh <- tryCatch(r$report$Lambda_B, error = function(e) NULL)
    if (is.null(Lh))
      return(cbind(base, seconds = secs, status = "NOLAMBDA", convergence = NA_integer_,
                   pdHess = NA, rel_frob = NA_real_, ratio = NA_real_, note = ""))
    Sh <- tcrossprod(Lh)
    cbind(base, seconds = secs, status = "OK",
          convergence = tryCatch(as.integer(r$opt$convergence), error = function(e) NA_integer_),
          pdHess      = tryCatch(isTRUE(r$sd_report$pdHess),   error = function(e) NA),
          rel_frob    = norm(Sh - Sig_true, "F") / norm(Sig_true, "F"),
          ## #847's statistic: ||Lam_hat||_F / ||Lam||_F = sqrt(trace ratio)
          ratio       = sqrt(sum(diag(Sh)) / sum(diag(Sig_true))),
          note = "")
  })
}

cells <- split(grid, seq_len(nrow(grid)))
cat(sprintf("cells=%d workers=%d smoke=%s\n", length(cells), NWORK, SMOKE))
daemons(NWORK, dispatcher = TRUE); on.exit(daemons(0), add = TRUE)
t0 <- proc.time()[["elapsed"]]
res <- mirai_map(cells, run_cell)[.progress]
el <- proc.time()[["elapsed"]] - t0
out <- do.call(rbind, res[vapply(res, is.data.frame, logical(1))])
saveRDS(out, file.path(OUT, "d108-logit-847.rds"))
write.csv(out, file.path(OUT, "d108-logit-847.csv"), row.names = FALSE)

cat(sprintf("\nDONE in %.1f s | rows %d\n", el, nrow(out)))
ok <- out[out$status == "OK", ]
cat("status:\n"); print(table(out$status))
pc <- function(x) round(100 * mean(x, na.rm = TRUE), 1)
ok$runaway_847 <- ok$ratio > 2
ok$degen_relfrob <- ok$rel_frob > 10
cat("\n=== #847 criterion (||Lam_hat||/||Lam|| > 2), by n x arm, sigma_lambda = 3 ===\n")
s3 <- ok[ok$sigma_lambda == 3, ]
print(round(tapply(s3$runaway_847, list(s3$n, s3$arm), function(x) 100*mean(x, na.rm=TRUE)), 1))
cat("\n=== median ||Lam_hat||/||Lam|| (compare #847: 0.666 / 1.216 / 2.185 for ridge) ===\n")
print(round(tapply(s3$ratio, list(s3$n, s3$arm), median, na.rm = TRUE), 3))
cat("\n=== sigma_lambda = 1 (compare #847 ridge: 0.901 / 0.824 / 0.794) ===\n")
s1 <- ok[ok$sigma_lambda == 1, ]
print(round(tapply(s1$ratio, list(s1$n, s1$arm), median, na.rm = TRUE), 3))
cat("\n=== rel_frob criterion for cross-reference ===\n")
print(round(tapply(s3$degen_relfrob, list(s3$n, s3$arm), function(x) 100*mean(x, na.rm=TRUE)), 1))
cat("\n=== THE CELL: n=1600, sigma_lambda=3, ridge2 (#847 says 67%, med 2.185) ===\n")
cl <- ok[ok$n == 1600 & ok$sigma_lambda == 3 & ok$arm == "ridge2", ]
cat("n_fits:", nrow(cl), " runaway(847):", pc(cl$runaway_847), "%  median ratio:",
    round(median(cl$ratio, na.rm = TRUE), 3), "\n")
cat("\nby p (does p explain it?):\n")
print(round(tapply(cl$ratio, cl$p, median, na.rm = TRUE), 3))
