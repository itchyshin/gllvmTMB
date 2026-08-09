## Does the paired sign flip (Lambda_.k, z_.k) -> (-Lambda_.k, -z_.k) leave the
## joint log-density exactly invariant?
##
## This substantiates the numbers quoted in docs/design/04-random-effects.md
## under "Internal parameterisation". Run it from the package root:
##
##     Rscript --vanilla dev/lambda-sign-invariance.R
##
## Expected:
##     flip BOTH Lambda and z : diff = 0.000e+00   <- exact invariance
##     flip Lambda ONLY       : a non-zero, usually large fixture-specific diff
##
## The second line is the control. Its magnitude depends on the simulated data
## and fitted start; only a non-zero change is required. Without that control,
## "diff = 0" would be equally consistent with an objective that ignores
## Lambda.

suppressMessages(devtools::load_all(".", quiet = TRUE))

set.seed(20260803L)

## --- a tiny ordinary Gaussian fit: latent() + unique() at rank 1 -------------
n_units  <- 15L
n_traits <- 3L
d        <- 1L

dat <- expand.grid(
  trait = factor(paste0("t", seq_len(n_traits))),
  unit  = factor(paste0("u", seq_len(n_units)))
)
dat$value <- rnorm(nrow(dat))

fit <- gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | unit, d = d) + unique(0 + trait | unit),
  data = dat, family = gaussian(), unit = "unit"
)

## --- the JOINT objective: random effects treated as parameters, not integrated
## (`random = NULL`), so the density is pointwise-evaluable at a fixed theta.
joint <- TMB::MakeADFun(
  data       = fit$tmb_obj$env$data,
  parameters = fit$tmb_obj$env$parList(),
  random     = NULL,
  DLL        = fit$tmb_obj$env$DLL,
  silent     = TRUE
)

theta <- joint$par
nm    <- names(theta)

idx_lambda <- which(nm == "theta_rr_B")
idx_z      <- which(nm == "z_B")

stopifnot(length(idx_lambda) > 0L, length(idx_z) > 0L)

base <- joint$fn(theta)

## (a) flip BOTH the loadings column and the latent scores -> should be EXACT
th_both <- theta
th_both[idx_lambda] <- -th_both[idx_lambda]
th_both[idx_z]      <- -th_both[idx_z]
f_both <- joint$fn(th_both)

## (b) CONTROL: flip the loadings only -> must NOT be a symmetry, otherwise the
## objective is insensitive to Lambda and (a) proves nothing.
th_lam <- theta
th_lam[idx_lambda] <- -th_lam[idx_lambda]
f_lam <- joint$fn(th_lam)

cat(sprintf("\n  n(theta) = %d   n(theta_rr_B) = %d   n(z_B) = %d\n",
            length(theta), length(idx_lambda), length(idx_z)))
cat(sprintf("  baseline joint nll   : %.12f\n", base))
cat(sprintf("  flip BOTH Lambda & z : %.12f   diff = %.3e\n", f_both, f_both - base))
cat(sprintf("  flip Lambda ONLY     : %.12f   diff = %.3e\n", f_lam,  f_lam  - base))

if (!isTRUE(all.equal(f_both, base, tolerance = 0))) {
  stop("The paired Lambda/score sign flip is not an exact invariance.",
       call. = FALSE)
} else if (isTRUE(all.equal(f_lam, base, tolerance = 1e-6))) {
  stop(paste(
    "Flipping Lambda alone changed nothing;",
    "the non-invariant control failed."
  ), call. = FALSE)
} else {
  cat("\n  As documented: the PAIRED flip is exact; flipping Lambda alone is not.\n")
}
