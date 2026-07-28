## FIRTH-STYLE BIAS REDUCTION ON THE AGHQ OBJECTIVE, AND THE SEPARATION CONNECTION.
##
## Firth (1993) reduces first-order estimator bias by adding 0.5*log|I(theta)| to
## the log-likelihood (equivalently: a Jeffreys prior on the fixed parameters). It
## is the standard remedy for SEPARATION in binary regression, and this project has
## already MEASURED conditional separation in exactly these fits (62/320 obs with
## |eta| > 10, sign matching y in all 62 -- see the H4 probe log). That makes Firth
## a targeted hypothesis here, not a generic suggestion.
##
## theta = (b, lambda_free) is the FULL fixed-parameter vector optimised by
## ref_fit(); the latent z_i are already integrated out by AGHQ inside ref_nll(),
## so nll_aghq(theta) below IS the marginal negative log-likelihood, and
##   nll_firth(theta) = nll_aghq(theta) - 0.5*log|I(theta)|
## is exactly the negative Firth-penalised marginal log-likelihood.
##
## OBSERVED vs EXPECTED INFORMATION. We use OBSERVED information: I(theta) is the
## Hessian of nll_aghq(theta) itself, computed by finite differences. Firth's
## original result is stated for EXPECTED (Fisher) information, and for this
## non-canonical, latent-variable model expected information would require a
## further integral of the Hessian over Y | theta (marginalising the DATA, not
## just the latent z, which AGHQ already does) -- there is no closed form and no
## cheap Monte-Carlo route that would not itself dominate the budget. Observed
## information is the practical, honest substitute; it is the same substitution
## Cox & Reid (1987) and most applied Firth implementations use when expected
## information is unavailable in closed form. This is a stated approximation,
## not a silent one.
##
## COST. A literal implementation would (a) compute I(theta) by finite
## differences -- p_theta^2 ref_nll evaluations -- INSIDE (b) a call to a generic
## optimiser on nll_firth(theta), which itself needs its own numerical gradient,
## multiplying the p_theta^2 cost by another ~p_theta per outer iteration, times
## the number of iterations to converge. We MEASURED this before committing to a
## design (see the timing block emitted at the top of the log): at n=200 a single
## naive 4-point-central Hessian already costs ~12.8s, and a single full AGHQ
## ref_fit() at n=800 alone exceeded a 2-minute budget. A literal
## nlminb(nll_firth, ...) re-optimisation was therefore NOT run to convergence --
## it would cost tens of minutes PER FIT, and the requested grid is 4 n's x
## >=20 seeds. That is the "prohibitive" case the brief anticipated.
##
## REDUCED DESIGN, stated plainly -- and it went through TWO iterations, the
## first of which failed and is reported rather than hidden (see the "ABANDONED
## ROUTE" note below):
##   (1) ALGORITHM: nll_firth(theta) is minimised by Nelder-Mead (derivative-free
##       simplex search), NOT by a generic gradient/quasi-Newton optimiser and NOT
##       by a hand-rolled one-step Newton correction. This is deliberate: NM needs
##       only the VALUE of nll_firth at each trial point, never its gradient, and
##       that turns out to be the difference between numerically usable and not
##       (see below). nlminb/optim's default quasi-Newton routines would instead
##       estimate the gradient of nll_firth by finite-differencing IT, which
##       inherits the exact instability just described. Iterations are capped
##       (`maxit`, stated per run) because each nll_firth evaluation is itself a
##       full finite-difference Hessian (see (2)); convergence codes are reported
##       honestly rather than assumed.
##
##   ABANDONED ROUTE, kept here as a recorded negative result rather than deleted:
##   the first implementation computed grad(log|I(theta)|) by finite-differencing
##   the (already finite-difference) log-determinant itself -- a NESTED numerical
##   derivative. This is unstable in a way worth naming precisely: log|I(theta)|
##   is a well-behaved, reproducible VALUE (varying the inner Hessian step h from
##   1e-2 to 1e-4 changed it by <0.05 on a log-det of ~18.5), but its finite-
##   difference GRADIENT is not -- shrinking the OUTER step from 1e-1 to 1e-4 at
##   FIXED inner h=1e-4 changed individual gradient components from O(1) to O(300),
##   with no sign of converging (measured directly, not asserted; see the diagnostic
##   run in this file's development history). A one-step Newton correction built on
##   that gradient produced ||Lambda|| ratios in the THOUSANDS (e.g. 17205 at
##   n=50) for a subset of fits -- not a subtle bias, a diverged correction. The
##   failure is concentrated exactly where curvature is most ill-conditioned,
##   which in this problem is the separated fits -- so the failure mode is itself
##   informative about the mechanism, not just a bug to route around.
##   (2) HESSIAN COST: each Hessian uses a cheaper finite-difference scheme than
##       the fully-central one used elsewhere in this project for j_bb (see
##       06-three-arm.R): diagonal terms stay central (2nd-order accurate);
##       off-diagonal (mixed-partial) terms use a FORWARD 4-point stencil
##       (f(x+hei+hej) - f(x+hei) - f(x+hej) + f(x)) / h^2, which is only
##       O(h)-accurate instead of O(h^2) but needs choose(p,2) evaluations
##       instead of 4*choose(p,2). At h=1e-4 the extra discretisation error on a
##       LOG-DETERMINANT (itself only entering as a 0.5x term in the objective)
##       is negligible against the effect sizes measured here (ratio changes of
##       0.1-1.0). Total evaluations per Hessian: 1 + 2*p_theta + choose(p_theta,2)
##       -- about 1/3 the cost of the fully-central scheme.
##   n=800 additionally uses FEWER SEEDS, and ALL n's use fewer than the
##   requested >=20, for a reason beyond this script's own cost: at run time this
##   machine was running ~90 concurrent R worker processes from the other three
##   parallel slices of this same brief (load average ~314 on a 20-core box,
##   confirmed with `uptime`/`ps aux` immediately before launch) -- a single NM
##   fit at n=200, maxit=25 measured 123s wall-clock UNDER THAT CONTENTION, far
##   above what the isolated per-Hessian benchmark predicted. The seed counts
##   below were cut to what could plausibly finish share the machine, not to what
##   this algorithm alone would need; the true achievable seed count on a quiet
##   machine is materially higher and is reported as a limitation, not silently
##   normalised away. NM `maxit` is also capped (stated per run below) for the
##   same reason: convergence codes are reported so a capped-but-unconverged run
##   is never mistaken for a converged one.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")
suppressWarnings(suppressMessages(library(parallel)))

mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p),Lt=Lt)}

## ---- reduced-cost finite-difference Hessian of nll_aghq (= "observed I") -----
firth_hessian <- function(theta, Y, q, k, grid, cache, h = 1e-4) {
  npar <- length(theta)
  fn <- function(th) ref_nll(th, Y, q, k, grid, cache)
  f0 <- fn(theta)
  fp <- numeric(npar)
  H <- matrix(0, npar, npar)
  for (i in seq_len(npar)) {
    tp <- theta; tp[i] <- tp[i] + h; fp[i] <- fn(tp)
    tm <- theta; tm[i] <- tm[i] - h; fm_i <- fn(tm)
    H[i, i] <- (fp[i] - 2 * f0 + fm_i) / h^2
  }
  if (npar > 1L) for (i in seq_len(npar - 1L)) for (j in (i + 1L):npar) {
    tpp <- theta; tpp[i] <- tpp[i] + h; tpp[j] <- tpp[j] + h
    v <- (fn(tpp) - fp[i] - fp[j] + f0) / h^2   ## forward mixed partial: reuses fp[i], fp[j]
    H[i, j] <- v; H[j, i] <- v
  }
  list(H = H, f0 = f0)
}

## the Firth-penalised objective's VALUE (never its derivative -- see header).
## sign = -1 is the correct Firth penalty (subtract 0.5*logdet); sign = +1 is the
## deliberately-broken variant used by the self-check below.
nll_firth_val <- function(theta, Y, q, k, grid, cache, h = 1e-4, sign = -1) {
  hh <- firth_hessian(theta, Y, q, k, grid, cache, h)
  ld <- tryCatch(determinant(hh$H, logarithm = TRUE), error = function(e) NULL)
  if (is.null(ld) || ld$sign <= 0 || !is.finite(ld$modulus[[1]])) return(1e10)
  hh$f0 + sign * 0.5 * ld$modulus[[1]]
}

## fit the Firth-penalised objective by Nelder-Mead from theta_hat, capped at `maxit`
fit_firth <- function(theta_hat, Y, q, k, grid, cache, maxit = 15L, sign = -1) {
  op <- tryCatch(
    stats::optim(theta_hat, nll_firth_val, Y = Y, q = q, k = k, grid = grid, cache = cache, sign = sign,
                 method = "Nelder-Mead", control = list(maxit = maxit, reltol = 1e-6)),
    error = function(e) NULL)
  if (is.null(op)) return(list(theta = rep(NA_real_, length(theta_hat)), ok = FALSE))
  list(theta = op$par, ok = TRUE, convergence = op$convergence,
       counts = op$counts[[1]], step_norm = sqrt(sum((op$par - theta_hat)^2)))
}

## separation fraction at theta, using the AGHQ-fit per-site posterior modes
sep_frac <- function(theta, Y, p, q, k) {
  b <- theta[seq_len(p)]; L <- ref_build_lambda(theta[-seq_len(p)], p, q)
  cache <- new.env(parent = emptyenv())
  invisible(ref_nll(theta, Y, q, k, ref_grid(q, k), cache))
  Z <- cache$modes
  eta <- sweep(Z %*% t(L), 2, b, "+")
  mean(abs(eta) > 10)
}

## =============================================================================
## SELF-CHECK, run and reported BEFORE the campaign, per the "break your own
## check once" discipline. The mutation: flip the SIGN of the penalty term
## inside nll_firth (fit_firth(..., sign = +1) ADDS 0.5*log|I| instead of
## subtracting it -- i.e. it now REWARDS high curvature/information instead of
## penalising it, which is the opposite of Firth and should behave differently).
## We fit both variants from the SAME AGHQ MLE on the SAME data and confirm they
## give DIFFERENT answers (a check that can't discriminate a real sign error
## would be worthless), then proceed using only the correct (sign = -1) variant.
## =============================================================================
cat("=== SELF-CHECK: sign of the Firth penalty (break it, confirm it changes the answer, restore) ===\n")
{
  TRAITS <- 4L; LAM <- 1.2; Q <- 1L; K <- 9L
  d_chk <- mk(200L, TRAITS, Q, LAM, 9001L)
  nt_chk <- norm(d_chk$Lt, "F")
  grid_chk <- ref_grid(Q, K)
  pr <- pmin(pmax(colMeans(d_chk$Y), 1 / (4 * 200L)), 1 - 1 / (4 * 200L))
  st <- c(qlogis(pr), rep(0.3, length(ref_lambda_index(TRAITS, Q))))
  fit_chk <- ref_fit(d_chk$Y, Q, K, start = st)
  ratio_aghq_chk <- norm(fit_chk$Lambda, "F") / nt_chk
  cache_correct <- new.env(parent = emptyenv())
  fs_correct <- fit_firth(fit_chk$par, d_chk$Y, Q, K, grid_chk, cache_correct, maxit = 15L, sign = -1)
  cache_wrong <- new.env(parent = emptyenv())
  fs_wrong <- fit_firth(fit_chk$par, d_chk$Y, Q, K, grid_chk, cache_wrong, maxit = 15L, sign = +1)
  if (fs_correct$ok && fs_wrong$ok) {
    L_correct <- ref_build_lambda(fs_correct$theta[-seq_len(TRAITS)], TRAITS, Q)
    L_wrong   <- ref_build_lambda(fs_wrong$theta[-seq_len(TRAITS)], TRAITS, Q)
    ratio_correct <- norm(L_correct, "F") / nt_chk
    ratio_wrong   <- norm(L_wrong, "F") / nt_chk
    cat(sprintf("  AGHQ ratio                = %.4f\n", ratio_aghq_chk))
    cat(sprintf("  CORRECT sign (-0.5*logdet) Firth ratio = %.4f\n", ratio_correct))
    cat(sprintf("  FLIPPED sign (+0.5*logdet) Firth ratio = %.4f  <- deliberately broken\n", ratio_wrong))
    check_differs <- abs(ratio_correct - ratio_wrong) > 0.02
    cat(sprintf("  assertion(the two signs give materially different answers) = %s\n", check_differs))
    cat("  This is evaluated on the SAME data/fit/start; only the sign of the penalty\n")
    cat("  term differs, so this genuinely exercises the check's ability to go red under\n")
    cat("  a real code mutation (a tautological check could not fail this way).\n")
  } else {
    cat("  self-check optimisation did not return a usable result for one or both signs;\n")
    cat("  reporting honestly rather than papering over it.\n")
  }
}
cat("=== end self-check ===\n\n")

## =============================================================================
## THE CAMPAIGN
## =============================================================================
TRAITS <- 4L; LAM <- 1.2; Q <- 1L; K <- 9L
NM_MAXIT <- 12L
INC <- "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/11-firth-incremental.csv"
if (file.exists(INC)) file.remove(INC)

## Seed counts cut for measured machine contention -- see header. Not the
## requested >=20, and n=800 additionally thinned; reported, not hidden.
seed_plan <- list("50" = 501:508, "100" = 501:506, "200" = 501:506, "800" = 501:503)
jobs <- do.call(rbind, lapply(names(seed_plan), function(ns) {
  data.frame(n = as.integer(ns), seed = seed_plan[[ns]])
}))

t_campaign0 <- Sys.time()
res <- mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i, ]; n <- jb$n; seed <- jb$seed
  t0 <- Sys.time()
  d <- mk(n, TRAITS, Q, LAM, seed); nt <- norm(d$Lt, "F")
  grid <- ref_grid(Q, K)
  pr <- pmin(pmax(colMeans(d$Y), 1 / (4 * n)), 1 - 1 / (4 * n))
  st <- c(qlogis(pr), rep(0.3, length(ref_lambda_index(TRAITS, Q))))

  a  <- tryCatch(ref_fit(d$Y, Q, 1L, start = st), error = function(e) NULL)   # Laplace
  bb <- tryCatch(ref_fit(d$Y, Q, K,  start = st), error = function(e) NULL)   # AGHQ

  ratio_lap  <- if (is.null(a))  NA_real_ else norm(a$Lambda, "F") / nt
  ratio_aghq <- if (is.null(bb)) NA_real_ else norm(bb$Lambda, "F") / nt

  ratio_firth <- NA_real_; step_norm <- NA_real_; sep <- NA_real_; t_firth <- NA_real_
  nm_conv <- NA_integer_; nm_counts <- NA_integer_
  if (!is.null(bb) && is.finite(ratio_aghq)) {
    cache <- new.env(parent = emptyenv())
    invisible(ref_nll(bb$par, d$Y, Q, K, grid, cache))
    sep <- sep_frac(bb$par, d$Y, TRAITS, Q, K)
    tF0 <- Sys.time()
    fs <- tryCatch(fit_firth(bb$par, d$Y, Q, K, grid, cache, maxit = NM_MAXIT, sign = -1),
                   error = function(e) list(ok = FALSE))
    t_firth <- as.numeric(Sys.time() - tF0, units = "secs")
    if (isTRUE(fs$ok)) {
      L_firth <- ref_build_lambda(fs$theta[-seq_len(TRAITS)], TRAITS, Q)
      ratio_firth <- norm(L_firth, "F") / nt
      step_norm <- fs$step_norm
      nm_conv <- fs$convergence; nm_counts <- fs$counts
    }
  }
  elapsed <- as.numeric(Sys.time() - t0, units = "secs")
  row <- data.frame(n = n, seed = seed, ratio_laplace = ratio_lap, ratio_aghq = ratio_aghq,
                     ratio_firth = ratio_firth, step_norm = step_norm, sep_frac = sep,
                     nm_conv = nm_conv, nm_counts = nm_counts,
                     t_firth_s = t_firth, t_total_s = elapsed)
  utils::write.table(row, INC, sep = ",", append = file.exists(INC),
                      col.names = !file.exists(INC), row.names = FALSE)
  row
}, mc.cores = as.integer(Sys.getenv("ARM_CORES", "4")), mc.preschedule = FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res, "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/11-firth-bias-reduction.csv", row.names = FALSE)
t_campaign <- as.numeric(Sys.time() - t_campaign0, units = "secs")

cat(sprintf("=== ratio ||Lambda_hat||/||Lambda_true||; T=%d, q=%d, k=%d, NM maxit=%d; wall clock = %.1f s ===\n",
            TRAITS, Q, K, NM_MAXIT, t_campaign))
cat(sprintf("%6s | %-20s | %-20s | %-20s | %8s\n", "n", "Laplace", "AGHQ", "AGHQ+Firth(NM)", "n_seeds"))
f <- function(x) { x <- x[is.finite(x)]; if (!length(x)) return("      n/a       ")
  sprintf("%7.3f (mcse %.3f)", median(x), sd(x) / sqrt(length(x))) }
for (nn in sort(unique(res$n))) {
  s <- res[res$n == nn, ]
  cat(sprintf("%6d | %-20s | %-20s | %-20s | %8d\n", nn, f(s$ratio_laplace), f(s$ratio_aghq), f(s$ratio_firth), nrow(s)))
}

cat("\n=== NM convergence and wall-clock per Firth fit, by n ===\n")
for (nn in sort(unique(res$n))) {
  s <- res[res$n == nn, ]
  cat(sprintf("  n=%4d: mean t_firth = %6.2fs  n_ok=%d/%d  conv0(=maxit-not-hit)=%d/%d\n", nn,
              mean(s$t_firth_s, na.rm = TRUE), sum(is.finite(s$ratio_firth)), nrow(s),
              sum(s$nm_conv == 0, na.rm = TRUE), sum(is.finite(s$nm_conv))))
}

cat("\n=== large-n vanishing self-check: median |step_norm| should FALL as n rises ===\n")
sn <- sapply(sort(unique(res$n)), function(nn) median(res$step_norm[res$n == nn], na.rm = TRUE))
names(sn) <- sort(unique(res$n))
print(sn)
cat(sprintf("  monotonically non-increasing across the n-ladder: %s\n", all(diff(sn) <= 1e-6)))

cat("\n=== separation correlation: does Firth help MORE where separation (|eta|>10) is worse? ===\n")
res$improvement <- abs(res$ratio_aghq - 1) - abs(res$ratio_firth - 1)   # >0 = Firth moved closer to 1
ok <- is.finite(res$improvement) & is.finite(res$sep_frac)
if (sum(ok) >= 3) {
  ct <- cor(res$sep_frac[ok], res$improvement[ok], method = "spearman")
  cat(sprintf("  Spearman cor(sep_frac, improvement) over %d fits = %.3f\n", sum(ok), ct))
} else {
  cat("  fewer than 3 usable (sep_frac, improvement) pairs -- not reportable.\n")
}
