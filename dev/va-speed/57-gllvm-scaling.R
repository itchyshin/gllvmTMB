## Is VA's N^1.58 intrinsic to the APPROACH, or specific to OUR implementation?
##
## We know our AC+collapse beats gllvm's VA by 1.76x at N=1000. We do NOT know gllvm's SCALING
## EXPONENT, and that distinction decides the roadmap:
##   gllvm also ~N^1.6  -> superlinearity is intrinsic to VA-for-GLLVM; nothing to chase.
##   gllvm nearer N^1.0 -> we have an IMPLEMENTATION gap worth finding.
##
## Same DGP as 43-va-vs-la-ladder.R (same seed, same lam/eta construction, T=20, NTR=6) so these
## numbers sit directly beside the ladder's, where our own arm measured N^1.58 and Laplace N^0.97.
##
## MODEL-MATCHED, and this is not optional: our arm uses `unique = FALSE` (loadings only) and
## gllvm with num.lv=q fits no psi tier either. The arc already paid for getting this wrong once
## -- an unmatched psi tier turned a real 3.7x into an apparent 264x.
##
## Usage: Rscript 57-gllvm-scaling.R <N> <tag>
##   NOTE: needs R_LIBS_USER=$HOME/R/lib -- `Rscript --vanilla` implies --no-environ, so
##   ~/.Renviron is ignored and gllvm (installed in ~/R/lib) becomes invisible. This killed a
##   campaign launch earlier in the arc.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

`%||%` <- function(a, b) if (is.null(a)) b else a
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
if (!requireNamespace("gllvm", quietly = TRUE))
  stop("gllvm not installed/visible -- did you set R_LIBS_USER=$HOME/R/lib?", call. = FALSE)
invisible(gllvmTMB:::.va_r3_load_dll())

args <- commandArgs(trailingOnly = TRUE)
N0  <- as.integer(args[[1]])
TAG <- args[[2]]
T0 <- 20L; Q0 <- 2L; NTR <- 6L; H0 <- 15L
OUT <- sprintf("dev/va-speed/57-gllvmscale-%s.rds", TAG)

## identical to 43-va-vs-la-ladder.R::mk()
mk <- function(seed, N) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q0, 0, 0.8), T0, Q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q0), N, Q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  list(y = y,
       Y = matrix(y, N, T0),   # column-major: matches as.vector(eta) on an N x T eta
       d = data.frame(y = y, succ = y, fail = NTR - y,
                      unit = factor(rep(seq_len(N), times = T0)),
                      trait = factor(rep(seq_len(T0), each = N))))
}

run_ours <- function(cell) {
  X <- unname(stats::model.matrix(~ 0 + trait, data = cell$d))
  f <- do.call(gllvmTMB:::.va_r3_fit, list(
    y = cell$d$succ, n_trials = rep(NTR, nrow(cell$d)), X = X,
    unit_id = as.integer(cell$d$unit), trait_id = as.integer(cell$d$trait),
    q = Q0, family = "binomial_probit", link = "probit", H = H0,
    unique = FALSE, psi = FALSE,
    eval_method = "ac", collapse_variational_cov = TRUE,
    n_starts = 1L, control = list(eval.max = 2000L, iter.max = 2000L)))
  ## same arm verification as the hardened ladder -- a silently refused collapse gate looks
  ## identical to one that fired, which is how an unverified speed claim gets made.
  if (!identical(as.character(f$eval_method %||% NA), "ac"))
    stop("ARM MISMATCH: eval_method did not resolve to 'ac'", call. = FALSE)
  if (!isTRUE(attr(f$objective, "va_r3_collapsed")))
    stop(sprintf("ARM MISMATCH: collapse gate did not fire (%s)",
                 attr(f$objective, "va_r3_collapse_note") %||% "no note"), call. = FALSE)
  f
}

run_gllvm <- function(cell) gllvm::gllvm(
  y = cell$Y, family = binomial(link = "probit"),
  num.lv = Q0, method = "VA", Ntrials = NTR, seed = 1L, trace = FALSE)

cat(sprintf("== N=%d T=%d q=%d NTR=%d | gllvm %s ==\n", N0, T0, Q0, NTR,
            as.character(utils::packageVersion("gllvm")))); flush.console()

## untimed warm-up at a tiny N -- pays TMB compile + gllvm's first-call costs for BOTH arms
wu <- mk(999L, 40L)
invisible(try(run_ours(wu), silent = TRUE))
invisible(try(suppressWarnings(run_gllvm(wu)), silent = TRUE))
cat("warm-up done (UNTIMED)\n"); flush.console()

cell <- mk(1L, N0)

t0 <- proc.time()[["elapsed"]]
o <- try(run_ours(cell), silent = TRUE)
ours_s <- proc.time()[["elapsed"]] - t0
ours_err <- if (inherits(o, "try-error")) conditionMessage(attr(o, "condition")) else NA_character_
cat(sprintf("ours (AC+collapse): %8.2fs  %s\n", ours_s, ours_err %||% "")); flush.console()

t0 <- proc.time()[["elapsed"]]
g <- try(suppressWarnings(run_gllvm(cell)), silent = TRUE)
gllvm_s <- proc.time()[["elapsed"]] - t0
gllvm_err <- if (inherits(g, "try-error")) conditionMessage(attr(g, "condition")) else NA_character_
cat(sprintf("gllvm VA:           %8.2fs  %s\n", gllvm_s, gllvm_err %||% ""))

saveRDS(list(N = N0, T = T0, q = Q0, NTR = NTR, tag = TAG,
             ours_s = ours_s, gllvm_s = gllvm_s,
             ours_err = ours_err, gllvm_err = gllvm_err,
             gllvm_version = as.character(utils::packageVersion("gllvm"))), OUT)
cat(sprintf("\n== %s DONE  ours %.2fs  gllvm %.2fs  ratio %.2fx ==\n",
            TAG, ours_s, gllvm_s, gllvm_s / ours_s))
