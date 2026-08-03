## How long does OUR LAPLACE engine take on the SAME model the VA arms fit?
##
## This checks the arc's founding premise. The whole rationale for VA is
## "SPEED VIA CLOSED FORM, not accuracy -- Laplace being more accurate is
## already known and settled" (maintainer, 2026-08-03). That premise is only
## worth anything if VA is actually much faster than our own Laplace. Nobody in
## this arc appears to have measured it at scale on the MATCHED model.
##
## MODEL MATCHING is the whole game here (the retracted 264x came from getting
## it wrong): `unique = FALSE` on both sides, so the latent tier is loadings-only
## -- no psi tier -- which is also gllvm's model. Same simulated data through
## both engines; the LA arm gets it as cbind(succ, fail), the VA arm as counts
## plus n_trials, which is the same likelihood written two ways.
##
## Paired, interleaved, order rotated. Untimed warm-up first.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

NTR <- 6L; T0 <- 20L; Q0 <- 2L
CAP <- as.numeric(Sys.getenv("LA_CAP", "900"))
rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))
loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  s <- tryCatch(system("sysctl -n vm.loadavg", intern = TRUE, ignore.stderr = TRUE),
                error = function(e) character(0))
  if (!length(s)) return(NA_real_)
  suppressWarnings(as.numeric(strsplit(trimws(gsub("[{}]", "", s[1])), " +")[[1]][1]))
}

mk <- function(seed, N) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q0, 0, 0.8), T0, Q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q0), N, Q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  d <- data.frame(y = y, succ = y, fail = NTR - y,
                  unit = factor(rep(seq_len(N), times = T0)),
                  trait = factor(rep(seq_len(T0), each = N)))
  list(d = d, X = unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0)))),
       Sigma_true = lam %*% t(lam), N = N)
}

run_va <- function(b, collapse = TRUE) gllvmTMB:::.va_r3_fit(
  y = b$d$y, n_trials = rep(NTR, nrow(b$d)), X = b$X,
  unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait), q = Q0,
  family = "binomial_probit", link = "probit",
  unique = FALSE, n_starts = 1L, H = 15L, eval_method = "ac",
  collapse_variational_cov = collapse,
  control = list(eval.max = 800L, iter.max = 400L))

## The shipped Laplace engine, same model: loadings-only latent tier (unique =
## FALSE), probit link, one row per (unit, trait).
run_la <- function(b) gllvmTMB::gllvmTMB(
  cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q0, unique = FALSE),
  data = b$d, family = binomial(link = "probit"), unit = "unit")

score_va <- function(f, b) {
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(f$best$par[names(f$best$par) == "theta_rr"], T0, Q0)
  rel_frob(L %*% t(L), b$Sigma_true)
}
## Score the LA fit on the SAME estimand: the loading-implied covariance.
## extract_Sigma() returns a LIST ($Sigma, $R) and needs `level`, not just `part`.
## With unique = FALSE the unit tier is loadings-only, so part = "total" at the
## unit level IS Lambda Lambda' -- the same estimand the VA arm is scored on.
## link_residual = "none" keeps it on the latent scale, matching Sigma_true.
score_la <- function(f, b) {
  out <- tryCatch(gllvmTMB::extract_Sigma(f, level = "unit", part = "total",
                                          link_residual = "none"),
                  error = function(e) NULL)
  if (is.null(out) || is.null(out$Sigma)) return(NA_real_)
  S <- as.matrix(out$Sigma)
  if (!identical(dim(S), dim(b$Sigma_true))) return(NA_real_)
  rel_frob(S, b$Sigma_true)
}

cat("== warm-up (untimed) ==\n"); flush.console()
wu <- mk(999L, 40L)
invisible(tryCatch(run_va(wu), error = function(e) cat("  VA warm-up error:", conditionMessage(e), "\n")))
invisible(tryCatch(run_la(wu), error = function(e) cat("  LA warm-up error:", conditionMessage(e), "\n")))
cat("== warm-up done ==\n\n"); flush.console()

NS <- as.integer(strsplit(Sys.getenv("LA_NS", "250"), ",")[[1]])
SEEDS <- seq_len(as.integer(Sys.getenv("LA_SEEDS", "3")))
cat(sprintf("%-6s %-5s %-6s %9s %10s %6s %s\n", "N", "seed", "arm", "secs", "rel_frob", "load", "status"))
res <- list()
for (N in NS) for (s in SEEDS) {
  b <- mk(s, N)
  ord <- if (s %% 2 == 1) c("VA", "LA") else c("LA", "VA")
  for (arm in ord) {
    la <- loadavg(); t0 <- proc.time()[["elapsed"]]
    setTimeLimit(elapsed = CAP, transient = TRUE)
    f <- tryCatch(if (arm == "VA") run_va(b) else run_la(b),
                  error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
    setTimeLimit(elapsed = Inf)
    secs <- proc.time()[["elapsed"]] - t0
    if (inherits(f, "err")) {
      st <- if (grepl("time limit", f$m)) "DID-NOT-COMPLETE" else paste0("ERROR: ", substr(f$m, 1, 45))
      cat(sprintf("%-6d %-5d %-6s %9.2f %10s %6.1f %s\n", N, s, arm, secs, "NA", la, st)); flush.console()
      res[[length(res) + 1]] <- data.frame(N = N, seed = s, arm = arm, secs = secs, rf = NA_real_, load = la, status = st)
      next
    }
    rf <- tryCatch(if (arm == "VA") score_va(f, b) else score_la(f, b), error = function(e) NA_real_)
    cat(sprintf("%-6d %-5d %-6s %9.2f %10.5f %6.1f ok\n", N, s, arm, secs, rf, la)); flush.console()
    res[[length(res) + 1]] <- data.frame(N = N, seed = s, arm = arm, secs = secs, rf = rf, load = la, status = "ok")
  }
}
r <- do.call(rbind, res)
cat("\n--- medians by N x arm ---\n")
ok <- r[r$status == "ok", ]
if (nrow(ok)) print(aggregate(cbind(secs, rf) ~ N + arm, ok, median), row.names = FALSE, digits = 6)
for (N in NS) {
  rc <- ok[ok$N == N, ]
  va <- median(rc$secs[rc$arm == "VA"]); lap <- median(rc$secs[rc$arm == "LA"])
  if (is.finite(va) && is.finite(lap))
    cat(sprintf("\n[N=%d] VA %.2fs vs LA %.2fs -> VA is %.2fx %s\n", N, va, lap,
                max(va, lap) / min(va, lap), if (va < lap) "FASTER" else "SLOWER"))
}
cat(sprintf("\nload median %.1f spread %.1f (paired+interleaved, so the RATIO survives ambient load)\n",
            median(r$load, na.rm = TRUE), diff(range(r$load, na.rm = TRUE))))
cat("\nLA_VS_VA_DONE\n")
