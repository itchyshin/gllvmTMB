## THE 2x2 the maintainer asked for: {VA, LA} x {gllvm, gllvmTMB}, speed AND accuracy.
## Our VA is split into its two tiers (AC and GH) because that contrast is the live
## question -- so five arms, not four.
##
##   gllvm-VA    gllvm::gllvm(method = "VA")
##   gllvm-LA    gllvm::gllvm(method = "LA")
##   ours-AC     gllvmTMB VA prototype, eval_method = "ac"   (the new closed form)
##   ours-GH     gllvmTMB VA prototype, eval_method = "gh"   (quadrature)
##   ours-LA     gllvmTMB shipped Laplace engine
##
## RUN SERIALLY AND INTERLEAVED. Arm order rotates per replicate so machine drift is
## spread across arms rather than landing on one. A sequential pass inflated a
## previous claim ~3x and forced its retraction. Do not run this concurrently with
## anything else -- the timings are the point.
##
## psi_true is a FIRST-CLASS FACTOR, not a nuisance. The AC tier collapses a real psi
## at low n_trials (0.0001 against a truth of 0.6 at n=6, where GH recovers 0.6207),
## so a comparison run only at psi_true = 0 measures AC's most favourable corner.
##
## Usage: Rscript --vanilla 18-four-way.R <N> <T> <n_trials> <psi_true> <seed> <out.rds>
## Results LOCAL (D-50).
args <- commandArgs(trailingOnly = TRUE)
N0  <- as.integer(args[1]); T0 <- as.integer(args[2])
NTR <- as.integer(args[3]); PSI <- as.numeric(args[4])
SEED <- as.integer(args[5]); OUT <- args[6]
REPS <- if (length(args) >= 7) as.integer(args[7]) else 2L
q0 <- 1L; H0 <- 15L

## Lane dir is configurable. The original hardcoded /private/tmp/gllvmtmb-mature-va,
## a worktree that no longer exists -- and /private/tmp is periodically cleaned.
## GLLVMTMB_LANE_DIR follows the convention already used by 24-totoro-smoke.R and
## 40-step0-pilot.R, so this runs unmodified locally or on a remote worker.
##
## GOTCHA, paid for on 2026-08-03: the usage line above says `Rscript --vanilla`,
## and --vanilla implies --no-environ, so ~/.Renviron is ignored, R_LIBS_USER is
## unset, and `library(gllvm)` fails on Totoro. Pass R_LIBS_USER=$HOME/R/lib
## explicitly in the invocation.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(gllvm)
})
rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))

set.seed(SEED)
lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
a   <- matrix(rnorm(N0 * q0), N0, q0)
u   <- matrix(rnorm(N0 * T0, 0, PSI), N0, T0)
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+") + u
y   <- rbinom(N0 * T0, NTR, pnorm(as.vector(eta)))
dat <- data.frame(y = y, unit = rep(seq_len(N0), times = T0),
                  trait = rep(seq_len(T0), each = N0))
X   <- unname(stats::model.matrix(~ 0 + factor(dat$trait, levels = seq_len(T0))))
Y   <- matrix(NA_real_, N0, T0); Y[cbind(dat$unit, dat$trait)] <- dat$y
Strue <- lam %*% t(lam)          # the estimand: Lambda Lambda', for every arm

## ---- our VA prototype (both tiers) -----------------------------------------
ours_va <- function(tier) {
  v <- gllvmTMB:::.va_r3_validate_data(y = dat$y, n_trials = rep(NTR, nrow(dat)),
        X = X, unit_id = dat$unit, trait_id = dat$trait, q = q0,
        family = "binomial_probit", link = "probit", unique = TRUE)
  o <- gllvmTMB:::.va_r3_make_objective(v, H = H0, eval_method = tier)
  t0 <- proc.time()[["elapsed"]]
  r <- tryCatch(stats::nlminb(o$par, o$fn, o$gr,
                  control = list(eval.max = 800L, iter.max = 400L)),
                error = function(e) NULL)
  s <- proc.time()[["elapsed"]] - t0
  if (is.null(r)) return(list(secs = s, rf = NA_real_, psi = NA_real_, note = "ERROR"))
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(r$par[names(o$par) == "theta_rr"], T0, q0)
  list(secs = s, rf = rel_frob(L %*% t(L), Strue),
       psi = median(exp(r$par[names(o$par) == "log_sd_tier"])), note = "ok")
}

## ---- our shipped Laplace engine --------------------------------------------
ours_la <- function() {
  d2 <- dat; d2$trait <- factor(d2$trait); d2$unit <- factor(d2$unit)
  fml <- y ~ 0 + trait + latent(0 + trait | unit, d = 1L)
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(suppressMessages(suppressWarnings(
        gllvmTMB::gllvmTMB(fml, data = d2, unit = "unit", trait = "trait",
          family = stats::binomial(link = "probit"),
          weights = rep(NTR, nrow(d2)),
          control = gllvmTMB::gllvmTMBcontrol()))),
       error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
  s <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "err")) return(list(secs = s, rf = NA_real_, psi = NA_real_,
                                      note = substr(f$m, 1, 50)))
  S <- tryCatch(gllvmTMB::extract_Sigma(f, level = "unit", part = "shared",
                  link_residual = "none")$Sigma, error = function(e) NULL)
  list(secs = s, rf = if (is.null(S)) NA_real_ else rel_frob(S, Strue),
       psi = NA_real_, note = "ok")
}

## ---- the reference package, both methods -----------------------------------
ref <- function(meth) {
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(gllvm::gllvm(y = Y, family = binomial(link = "probit"),
                  num.lv = q0, method = meth, Ntrials = NTR,
                  seed = 1L, trace = FALSE),
       error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
  s <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "err")) return(list(secs = s, rf = NA_real_, psi = NA_real_,
                                      note = substr(f$m, 1, 50)))
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(f$params$sigma.lv, error = function(e) NULL)
  L  <- if (!is.null(sg)) sweep(th, 2L, sg, "*") else th
  list(secs = s, rf = rel_frob(L %*% t(L), Strue), psi = NA_real_, note = "ok")
}

ARMS <- list(`gllvm-VA` = function() ref("VA"),
             `gllvm-LA` = function() ref("LA"),
             `ours-AC`  = function() ours_va("ac"),
             `ours-GH`  = function() ours_va("gh"),
             `ours-LA`  = ours_la)

rows <- list()
for (rep in seq_len(REPS)) {
  nm <- names(ARMS)
  ord <- nm[((seq_along(nm) - 1 + (rep - 1)) %% length(nm)) + 1]  # rotate
  for (arm in ord) {
    r <- ARMS[[arm]]()
    cat(sprintf("N=%d T=%d n=%d psi=%.1f seed=%d rep%d  %-9s %8.2f s  rel_frob %s  psi %s  [%s]\n",
                N0, T0, NTR, PSI, SEED, rep, arm, r$secs,
                ifelse(is.na(r$rf), "     NA", sprintf("%.4f", r$rf)),
                ifelse(is.na(r$psi), "  NA", sprintf("%.4f", r$psi)), r$note))
    flush.console()
    rows[[length(rows)+1]] <- data.frame(N=N0,T=T0,n_trials=NTR,psi_true=PSI,
      seed=SEED, rep=rep, arm=arm, secs=r$secs, rf=r$rf, psi=r$psi, note=r$note)
  }
}
res <- do.call(rbind, rows)
saveRDS(res, OUT)
cat("\n--- medians over", REPS, "reps ---\n")
print(aggregate(cbind(secs, rf) ~ arm, res, median), row.names = FALSE, digits = 4)
cat("\nFOUR_WAY_DONE\n")
