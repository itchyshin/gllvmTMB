## WHY IS gllvm ~4.4x FASTER THAN OUR `ac` WHEN THEY RETURN THE SAME NUMBERS?
##
## Suspicion: the comparison is unfair by construction. Our .va_r3_fit runs
## n_starts = 4L; gllvm's default is n.init = 1. dev/bound-vs-estimates.md says
## exactly this -- "gllvm's own single-start default is not a fair fight against
## an engine that already retries from 4 starting points internally" -- and my
## shared grid called gllvm() WITHOUT n.init, so it ran 1 start against our 4.
## 5.3s / 1.2s = 4.4x, suspiciously close to the 4x start ratio.
##
## But there may be a SECOND effect. dev/va-speed/21-WHY-GLLVM-IS-FAST.md records
## that gllvm warm-starts from a num.lv = 0 fit and then runs ~3 optimiser calls
## total (BFGS), rather than jittering random starts. A good single start beats
## four bad ones. If so, the fix for us is warm-starting, not more starts.
##
## DESIGN: time all four combinations on IDENTICAL data.
##   ours   n_starts = 1 and 4
##   gllvm  n.init   = 1 and 4
## If the 4.4x collapses at matched starts, it is purely the start count.
## If a residual gap remains at matched starts, that residual is gllvm's
## algorithmic advantage (warm start / optimiser), and THAT is the part worth copying.
##
## Also reports trace, so we can see whether the extra starts buy any accuracy --
## if n_starts=1 is as accurate as 4, our default is pure waste.

LANE <- Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-ac-curvature")
setwd(LANE)
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")
T0 <<- 20L; stopifnot(identical(T0, 20L))
N0 <- 150L
N_SEED <- as.integer(Sys.getenv("N_SEED", "4"))
CORES  <- as.integer(Sys.getenv("CORES", "4"))

one <- function(s) {
  b <- sim_cell(s, "binomial_probit", N0)
  stopifnot(nrow(b$d) == N0 * T0)
  X <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d))
  Y <- matrix(b$d$y, nrow = N0, ncol = T0, byrow = TRUE)
  Xd <- data.frame(x = b$d$x[seq(1L, nrow(b$d), by = T0)])
  o <- list(seed = s)

  for (ns in c(1L, 4L)) {
    t0 <- Sys.time()
    f <- tryCatch(gllvmTMB:::.va_r3_fit(
           y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = X,
           unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
           q = Q0, family = "binomial_probit", link = "probit",
           unique = FALSE, psi = FALSE, n_starts = ns, eval_method = "ac",
           control = list(eval.max = 2000L, iter.max = 2000L)), error = function(e) NULL)
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (!is.null(f) && !is.null(f$best$par)) {
      Lam <- gllvmTMB:::.va_r3_unpack_theta_rr(
               unname(f$best$par[names(f$best$par) == "theta_rr"]), T0, Q0)
      o[[paste0("ours_ns", ns)]] <- list(
        secs = el, trace = sum(rowSums(Lam^2)) / sum(b$sigma_jj_true), status = f$status)
    }
  }

  for (ni in c(1L, 4L)) {
    t0 <- Sys.time()
    g <- tryCatch(gllvm::gllvm(y = Y, X = Xd, formula = ~ x,
                    family = binomial(link = "probit"), num.lv = Q0, method = "VA",
                    trace = FALSE,
                    control.start = list(n.init = ni, jitter.var = 0.2)),
                  error = function(e) NULL)
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (!is.null(g)) {
      th <- as.matrix(g$params$theta); sg <- tryCatch(g$params$sigma.lv, error = function(e) NULL)
      L <- if (!is.null(sg)) sweep(th, 2L, sg, "*") else th
      o[[paste0("gllvm_ni", ni)]] <- list(
        secs = el, trace = sum(rowSums(L^2)) / sum(b$sigma_jj_true), status = "gllvm")
    }
  }
  o
}

res <- Filter(function(x) length(x) > 1L,
              mclapply(20261900L + seq_len(N_SEED),
                       function(s) tryCatch(one(s), error = function(e) NULL),
                       mc.cores = CORES, mc.preschedule = FALSE))

cat(sprintf("\n==== START-MATCHED TIMING — probit n=%d p=%d q=%d, %d seeds ====\n\n",
            N0, T0, Q0, length(res)))
cat(sprintf("%-12s %8s %10s\n", "arm", "secs", "trace"))
get <- function(k, f) {
  g <- Filter(function(x) !is.null(x[[k]]), res)
  if (!length(g)) return(NA_real_)
  mean(vapply(g, function(x) x[[k]][[f]], numeric(1)))
}
for (k in c("ours_ns1", "ours_ns4", "gllvm_ni1", "gllvm_ni4"))
  cat(sprintf("%-12s %8.2f %10.4f\n", k, get(k, "secs"), get(k, "trace")))

cat("\n-- THE QUESTION: does the gap survive MATCHED starts? --\n")
u1 <- get("ours_ns1", "secs"); u4 <- get("ours_ns4", "secs")
g1 <- get("gllvm_ni1", "secs"); g4 <- get("gllvm_ni4", "secs")
cat(sprintf("  UNMATCHED (my grid: ours 4 starts vs gllvm 1) : %.2fx\n", u4 / g1))
cat(sprintf("  MATCHED at 1 start                            : %.2fx\n", u1 / g1))
cat(sprintf("  MATCHED at 4 starts                           : %.2fx\n", u4 / g4))
cat(sprintf("  our own cost of going 1 -> 4 starts           : %.2fx\n", u4 / u1))
cat("\n  If the matched ratios are ~1, the 4.4x was PURELY the start count and my\n")
cat("  grid's `secs` column is not a fair comparison. Any residual at matched\n")
cat("  starts is gllvm's real algorithmic edge (warm start from num.lv=0, BFGS).\n")
cat("\n-- do the extra starts buy ACCURACY? --\n")
cat(sprintf("  ours trace: n_starts=1 %.4f   n_starts=4 %.4f   (if equal, 4 starts is waste here)\n",
            get("ours_ns1", "trace"), get("ours_ns4", "trace")))
cat(sprintf("\n== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
