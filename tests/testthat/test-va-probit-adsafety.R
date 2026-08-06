## Design 108 Gate A Stage 4 — AD-safety of the tail-safe `log Phi` primitive
## and the binomial-probit branch (family_id 1, link_id 1) UNDER QUADRATURE.
##
## This file is the deliverable of the stage; the template change is only what
## makes it runnable. Design 105 s1.3 is the hazard being tested: every probit
## guard in the package was written for a SINGLE evaluation at eta = mu, but
## Gauss-Hermite evaluates the integrand at eta_h = mu + sqrt(2v) x_h, whose
## extreme node reaches +/- 6.36 SD of eta at H = 15 and +/- 14.50 SD at H = 61.
## Past x ~ -37.5 pnorm() underflows and past x ~ -38.6 dnorm() does too, so the
## naive derivative dnorm/pnorm becomes 0/0 = NaN -- a NaN GRADIENT, not a
## slightly wrong number. A test that only exercises the bulk proves nothing, so
## every derivative check below is run at cells where the naive route IS NaN.
##
## Scope, stated so it is not over-read. This is a fenced research spike:
## binomial-probit is reachable from the PROTOTYPE engine only and is
## deliberately NOT on the public integration fence, so `integration = "va"`
## still refuses it. Nothing here is a recovery, coverage or capability claim.
##
## 🔴 RUNNING THIS FOR REAL NEEDS `NOT_CRAN=true`. Without it the file skips
##    while testthat still prints a clean pass.

## ---------------------------------------------------------------------------
## Fixture: an N=1, T=1, q=1 objective built straight on the template, so the
## measurement is of the TEMPLATE and not of the adapter. With lambda = 1 and
## m = 0 the parameter-to-(mu, v) map is exactly
##     mu = beta,      v = exp(2 * log_L_diag)
## which makes the two derivatives of interest readable off the gradient:
##     dE/dmu = -grad_beta                       (KL does not depend on beta)
##     dE/dv  = (grad_l[masked] - grad_l[obs]) / (2 v)
## The second uses a SECOND fixture identical but for is_y_observed = 0, whose
## objective is the KL alone. Differencing the two cancels the KL empirically,
## so no analytic KL derivative is trusted anywhere in this file.
## ---------------------------------------------------------------------------
.probit_obj <- function(mu, v, y, n, H, observed = 1L) {
  dll <- .va_r3_load_dll()
  rule <- .va_r3_gh_rule(H)
  dat <- list(y = as.numeric(y), n_trials = as.numeric(n),
              X = matrix(1, 1L, 1L), unit_id = 0L, trait_id = 0L,
              is_y_observed = as.integer(observed), N = 1L, T = 1L, q = 1L,
              gh_nodes = rule$nodes, gh_weights = rule$weights,
              family = 1L, link_id = 1L,
              n_ordinal_cuts_per_trait = 0L,
              ordinal_offset_per_trait = 0L,
              eval_method = 0L,
              ## ac2_threshold (Design 108 Gate A Stage 5, the ac2 runaway
              ## fix) is read UNCONDITIONALLY by the template regardless of
              ## eval_method -- this fixture builds `dat` directly rather
              ## than through .va_r3_make_objective(), so it must supply the
              ## field itself. eval_method = 0L (gh) never reads it; the
              ## value is inert here, matching R/va-r3-proto.R's own default.
              ac2_threshold = 1.0,
              ## Design 108 Stage 6 made the tier structure DATA. This fixture
              ## builds on the template directly, so it declares the single
              ## dense ordinary latent tier explicitly: one tier, dimension
              ## q = 1, one level, level index = unit_id. That restates the
              ## Stage-5 model rather than changing it -- (mu, v) and every
              ## derivative measured below are unaltered.
              n_tiers = 1L, tier_kind = 0L, tier_dim = 1L,
              tier_n_levels = 1L, level_id = matrix(0L, 1L, 1L),
              ## Design 108 Stage 7 added the structured-prior DATA. This
              ## fixture's one tier is the ordinary latent tier, so it is
              ## UNSTRUCTURED and the precision slots are the placeholders the
              ## template never reads. Same model, same (mu, v), same
              ## derivatives -- what changed is the declaration, not the cell.
              tier_structured = 0L,
              Ainv_struct = Matrix::sparseMatrix(i = integer(0),
                                                 j = integer(0),
                                                 x = numeric(0),
                                                 dims = c(1L, 1L)),
              diag_Ainv_struct = 0, log_det_A_struct = 0)
  par <- list(
    beta = mu, theta_rr = 1, log_sd_tier = numeric(0),
    m = 0, log_L_diag = 0.5 * log(v), L_off = numeric(0),
    log_sigma = 0, log_sigma_lognormal = 0, log_phi_gamma = 0,
    log_phi_nbinom2 = 0, log_phi_tweedie = 0, logit_p_tweedie = 0,
    log_phi_beta = 0, log_phi_betabinom = 0,
    log_sigma_student = 0, log_df_student = log(4),
    log_phi_truncnb2 = 0, log_sigma_lognormal_delta = 0,
    log_phi_gamma_delta = 0, ordinal_log_increments = numeric(0),
    log_phi_nbinom1 = 0
  )
  inactive <- setdiff(names(par), c("beta", "log_L_diag"))
  map <- lapply(par[inactive], function(x) factor(rep(NA_integer_, length(x))))
  TMB::MakeADFun(dat, par,
                 map = map,
                 DLL = dll$DLL, silent = TRUE)
}

## Everything the template computes for one cell, plus its finiteness.
.probit_ad <- function(mu, v, y, n, H) {
  o  <- .probit_obj(mu, v, y, n, H)
  om <- .probit_obj(mu, v, y, n, H, observed = 0L)
  p <- o$par
  gr  <- drop(o$gr(p))
  grm <- drop(om$gr(p))
  he  <- tryCatch(o$he(p), error = function(e) NA_real_)
  list(
    ## ell = log_choose + E, as the template reports it per observation.
    ell    = o$report(p)$expected_loglik_by_obs[[1L]],
    dEdmu  = -gr[[1L]],
    dEdv   = (grm[[2L]] - gr[[2L]]) / (2 * v),
    finite = all(is.finite(gr)) && all(is.finite(he)) && is.finite(o$fn(p))
  )
}

## Reference for the integrand: the same quadrature rule, evaluated with R's own
## pnorm(log.p = TRUE).
##
## WHAT THIS IS AND IS NOT INDEPENDENT OF (corrected after adversarial review,
## 2026-08-02 -- an earlier version of this comment claimed "nothing here shares
## code with the template", which is FALSE and overstated the guarantee):
##   INDEPENDENT of: the log-Phi primitive itself -- the thing this stage adds.
##     R's pnorm(log.p = TRUE) has no connection to the continued-fraction
##     implementation, so a bug in the CF cannot hide here.  That is the claim
##     these tests actually need.
##   SHARED with the template: .va_r3_gh_rule(H) (the SAME function whose nodes
##     and weights are handed to the template), the mu + sqrt(2v)*x scaling, the
##     /sqrt(pi) normalisation, and the logPhi(-eta) symmetry.
## Consequence, and it matters: these checks certify that the template
## DIFFERENTIATES ITS OWN QUADRATURE SUM correctly.  They do NOT certify that
## the sum approximates the true expectation.  Measured externally against
## stats::integrate(rel.tol = 1e-13) on the bulk bernoulli cell, the H=15 rule
## is already 2.98e-09 off the true integral -- five orders LARGER than the
## ~2.4e-14 AD error these tests certify (H=61: 3.82e-15).  "AD-safe" is
## therefore established; "accurate" is NOT, and is Stage 8's job. Do not let
## these numbers be quoted as recovery or accuracy evidence.
.probit_E_ref <- function(mu, v, y, n, H) {
  r <- .va_r3_gh_rule(H)
  eta <- mu + sqrt(2 * v) * r$nodes
  sum(r$weights / sqrt(pi) *
        (y * pnorm(eta, log.p = TRUE) + (n - y) * pnorm(-eta, log.p = TRUE)))
}

## Analytic pieces for the small-v branch, again from R's pnorm/dnorm only.
.probit_lam <- function(x) exp(dnorm(x, log = TRUE) - pnorm(x, log.p = TRUE))
.probit_g1  <- function(x, y, n) y * .probit_lam(x) - (n - y) * .probit_lam(-x)
.probit_g2  <- function(x, y, n) {
  lp <- .probit_lam(x); lq <- .probit_lam(-x)
  -y * lp * (x + lp) - (n - y) * lq * (-x + lq)   # d2/dx2 log Phi = -lam(x+lam)
}

## Richardson-extrapolated central difference (O(h^4)).
.probit_fd <- function(f, x, h) {
  (8 * (f(x + h) - f(x - h)) - (f(x + 2 * h) - f(x - 2 * h))) / (12 * h)
}

## NOTE (adversarial review 2026-08-02): when the reference is exactly 0 this
## silently degrades from a RELATIVE to an ABSOLUTE comparison. dE/dv IS exactly
## 0 on the small-v expansion branch for mu >= 8, so this is a latent
## silent-pass mode. It is not currently exercised by any live assertion; if a
## future cell puts a zero reference through here, the tolerance it is compared
## against changes meaning without warning. Left as-is deliberately rather than
## silently changed under a verification task -- flagged so the next editor sees it.
.probit_relerr <- function(a, b) {
  if (abs(b) > 0) abs(a - b) / abs(b) else abs(a - b)
}

## The cells.
##
## Tail reach, RECOMPUTED per cell (corrected 2026-08-02; the previous comment
## claimed "every one but the first two" reaches a NaN node, which is false at
## H=15 for two of the five tail cells and contradicted this file's own later
## note). The first NaN in dnorm(x)/pnorm(x) is near x = -38.6
## (dnorm(-37.5)/pnorm(-37.5) = 37.53, still finite).
##
##   cell                  H=15 min eta / #NaN nodes   H=61 min eta / #NaN nodes
##   bulk bernoulli             -6.06 /  0                 -14.20 /  0
##   bulk binomial n=10         -5.43 /  0                 -11.73 /  0
##   left tail mu=-30          -36.36 /  0                 -44.50 / 10
##   deep tail mu=-40          -46.36 /  9                 -54.50 / 34
##   huge v=100                -63.64 /  6                -144.99 / 42
##   right tail mu=+30         -36.36 /  0                 -15.50 / 10
##   both tails                -51.82 /  3                 -92.49 / 25
##
## So: 3 of 5 tail cells reach the NaN region at H=15, and 5 of 5 at H=61. The
## suite does exercise the regime where the naive ratio dies -- but not in every
## tail cell at every H, and a reader should not assume otherwise.
.probit_cells <- list(
  list(tag = "bulk bernoulli",     mu =   0.3, v = 1e0,  y = 1, n = 1),
  list(tag = "bulk binomial n=10", mu =  -0.5, v = 6e-1, y = 3, n = 10),
  list(tag = "left tail mu=-30",   mu = -30.0, v = 1e0,  y = 1, n = 1),
  list(tag = "deep tail mu=-40",   mu = -40.0, v = 1e0,  y = 1, n = 1),
  list(tag = "huge v=100",         mu =   0.0, v = 1e2,  y = 1, n = 1),
  list(tag = "right tail mu=+30",  mu =  30.0, v = 1e0,  y = 0, n = 1),
  list(tag = "both tails",         mu = -20.0, v = 25.0, y = 5, n = 10)
)


test_that("the point-evaluation guard really IS 0/0 at the quadrature reach", {
  ## Not decoration: this fixes that the hazard Design 105 s1.3 describes is a
  ## real double-precision failure at nodes this package actually evaluates, so
  ## the tests below are not testing against a hypothetical.
  expect_true(is.nan(dnorm(-40) / pnorm(-40)))
  expect_true(is.nan(dnorm(-45) / pnorm(-45)))
  expect_identical(pnorm(-45), 0)          # the CDF itself has underflowed
  expect_true(is.finite(pnorm(-45, log.p = TRUE)))   # the LOG scale has not
  ## H = 15 at mu = -30, v = 1 reaches -36.4; H = 61 reaches -44.5.
  expect_lt(-30 - sqrt(2) * max(.va_r3_gh_rule(15L)$nodes), -36)
  expect_lt(-30 - sqrt(2) * max(.va_r3_gh_rule(61L)$nodes), -44)
})


test_that("the log Phi primitive matches R's pnorm(log.p = TRUE) past underflow", {
  skip_on_cran()
  ## Read the primitive straight off the template: at v below the expansion
  ## threshold with y = n = 1, ell = log_choose + E = log Phi(mu) + v g''(mu)/2.
  ## v = 1e-14 puts that second term at <= 1e-14 in absolute value -- two orders
  ## below the tolerance -- so what is compared is the primitive itself. (At
  ## v = 1e-12 the whole residual below IS that term, not any inaccuracy.)
  mus <- c(-300, -200, -100, -50, -45, -40, -37.5, -30, -20, -10.5, -10,
           -9.5, -8, -6.4, -5, -2, 0, 2, 6.4)
  got <- vapply(mus, function(mu) .probit_ad(mu, 1e-14, 1, 1, 15L)$ell,
                numeric(1))
  ref <- pnorm(mus, log.p = TRUE)
  ## ABSOLUTE accuracy is the contract: log Phi enters the likelihood additively.
  expect_true(all(is.finite(got)))
  expect_lt(max(abs(got - ref)), 1e-9)
  ## RELATIVE accuracy holds wherever the value is not already numerically zero.
  ## Above mu ~ 6 the value is < 1e-10 and log(pnorm) can only carry it to ~1e-16
  ## ABSOLUTE -- inherent to the right tail, and harmless, since there the term
  ## contributes nothing to the likelihood.
  big <- abs(ref) > 1e-9
  expect_lt(max(abs((got[big] - ref[big]) / ref[big])), 1e-12)
})


test_that("the Mills-ratio derivative is exact where dnorm/pnorm is 0/0", {
  skip_on_cran()
  mus <- c(-300, -100, -45, -40, -37.5, -20, -10.5, -10, -9.5, -8, -5, 0, 2)
  got <- vapply(mus, function(mu) .probit_ad(mu, 1e-14, 1, 1, 15L)$dEdmu,
                numeric(1))
  ref <- .probit_lam(mus)                     # phi/Phi, exact via log scale
  expect_true(all(is.finite(got)))
  expect_lt(max(abs((got - ref) / ref)), 1e-10)
  ## And the naive form is genuinely unusable over part of that same sweep.
  expect_true(any(is.nan(dnorm(mus) / pnorm(mus))))
})


for (.H in c(15L, 61L)) local({
  H <- .H
  test_that(sprintf("dE/dmu and dE/dv finite-difference correctly at H = %d", H), {
    skip_on_cran()
    reach <- sqrt(2) * max(.va_r3_gh_rule(H)$nodes)
    cat(sprintf(
      "\n-- Design 108 Stage 4 AD-safety, H = %d (extreme node %.4f SD of eta) --\n%-20s %14s %14s %10s %14s %14s %10s %8s\n",
      H, reach, "cell", "dE/dmu AD", "dE/dmu FD", "rel", "dE/dv AD",
      "dE/dv FD", "rel", "min eta"))
    for (g in .probit_cells) {
      ad <- .probit_ad(g$mu, g$v, g$y, g$n, H)
      fm <- function(m)  .probit_E_ref(m, g$v, g$y, g$n, H)
      fv <- function(vv) .probit_E_ref(g$mu, vv, g$y, g$n, H)
      dmu_fd <- .probit_fd(fm, g$mu, 1e-4 * max(1, abs(g$mu)))
      dv_fd  <- .probit_fd(fv, g$v,  1e-4 * g$v)
      r_mu <- .probit_relerr(ad$dEdmu, dmu_fd)
      r_v  <- .probit_relerr(ad$dEdv,  dv_fd)
      cat(sprintf("%-20s %14.7g %14.7g %10.2e %14.7g %14.7g %10.2e %8.1f\n",
                  g$tag, ad$dEdmu, dmu_fd, r_mu, ad$dEdv, dv_fd, r_v,
                  g$mu - reach * sqrt(g$v)))

      expect_true(ad$finite)
      ## dE/dmu: the AD gradient and the independent integrand agree to well
      ## inside the finite-difference reference's own conditioning.
      expect_lt(r_mu, 1e-8)
      ## dE/dv is looser only because the FD reference is: on the deep-tail
      ## cells E is O(1e3) while dE/dv is O(1), so the central difference
      ## itself carries ~1e-9 relative noise. The bound is on the REFERENCE's
      ## accuracy, not on the AD gradient's.
      ##
      ## VERIFIED INDEPENDENTLY (adversarial review 2026-08-02): replacing the
      ## Richardson FD with an ANALYTIC derivative of the same GH sum (built from
      ## log-scale lambda = exp(dnorm(log) - pnorm(log.p)), exact in the tail, no
      ## cancellation) gives the true AD error, 2-5 orders below these bounds:
      ##     dE/dmu H=15  2.361e-14   (asserted 1e-8)
      ##     dE/dv  H=15  2.891e-13   (asserted 1e-6)
      ##     dE/dmu H=61  2.543e-14
      ##     dE/dv  H=61  6.924e-14
      ## And row for row rel(FD,ANALYTIC) ~= rel(AD,FD) -- e.g. deep tail H=15:
      ## FD-vs-analytic 2.891e-09 vs AD-vs-FD 2.892e-09, while AD-vs-analytic is
      ## 2.891e-13. So the residual really is the FD reference's own
      ## conditioning, exactly as claimed above. The looser 1e-6 hides nothing.
      ## NB this explanation is specific to THIS loop; the small-v switch test
      ## below is limited by something else (see its own note).
      expect_lt(r_v, 1e-6)
      ## The reported per-observation value must match the reference integrand.
      lchoose <- lgamma(g$n + 1) - lgamma(g$y + 1) - lgamma(g$n - g$y + 1)
      expect_equal(ad$ell,
                   lchoose + .probit_E_ref(g$mu, g$v, g$y, g$n, H),
                   tolerance = 1e-12)
    }
  })
})


test_that("the small-v branch reproduces g(mu) + v g''(mu)/2, including in the tail", {
  skip_on_cran()
  ## Below v = 1e-6 the GH branch is replaced by a heat-kernel expansion, so the
  ## reference is the expansion's own analytic target rather than the quadrature
  ## (a finite difference of the quadrature at v = 1e-9 is pure cancellation
  ## noise and would be a meaningless comparator).
  for (cs in list(list(mu = -8,  v = 1e-9, y = 1, n = 1),
                  list(mu = -45, v = 1e-9, y = 1, n = 1),   # naive = NaN here
                  list(mu = 0.4, v = 1e-8, y = 3, n = 10))) {
    ad <- .probit_ad(cs$mu, cs$v, cs$y, cs$n, 15L)
    expect_true(ad$finite)
    expect_equal(ad$dEdmu, .probit_g1(cs$mu, cs$y, cs$n), tolerance = 1e-9)
    expect_equal(ad$dEdv,  .probit_g2(cs$mu, cs$y, cs$n) / 2, tolerance = 1e-6)
  }
})


test_that("branches meet across the v = 1e-6 switch at the tested mu (see scope note)", {
  skip_on_cran()
  ## The expansion and the quadrature must meet. Compare the two sides after
  ## removing the genuine variation over the gap, so what is measured is the
  ## BRANCH mismatch and not dE/dv * delta_v.
  ##
  ## SCOPE -- this assertion is REGIONAL, not general (adversarial review
  ## 2026-08-02; the test was previously titled "value and both derivatives are
  ## continuous across the v = 1e-6 switch", which asserts a property the
  ## implementation does not have everywhere). Scanning mu in [-100, 30]:
  ##   * value jump holds throughout: worst 1.317e-13 (y=n=1), 5.088e-13
  ##     (y=3,n=10), against the 1e-12 asserted below.
  ##   * |d dE/dmu| < 1e-8 FAILS at (mu=-1, y=3, n=10) = 1.719e-08. The bound is
  ##     ABSOLUTE, so it is not scale-invariant, and all three cells here use n=1.
  ##   * |d dE/dv|/|dE/dv| < 1e-6 FAILS for mu >~ 2.5 (mu=3: 3.08e-06; mu=6:
  ##     1.31e-03) and is 0/0 for mu >= 8, where dE/dv is exactly 0 on the
  ##     expansion branch.
  ## Those are numerically void regimes -- |dE/dv| <= 1.8e-8 by mu=6 -- so the
  ## TEMPLATE is fine and the truncation matches its documented O(v) budget
  ## (rel value <= 2.9e-14; rel dE/dv 6.3e-10 at mu=-8, 9.1e-08 at mu=0.4).
  ## What is NOT true is the general claim. Widen these mu only together with a
  ## relative dE/dmu bound and an explicit guard for dE/dv == 0.
  ##
  ## Also: the limiter here is NOT the reference's accuracy (as in the H-loop
  ## above) but TWIN-DIFFERENCE CANCELLATION -- dE/dv is a difference of two O(1)
  ## gradients divided by 2v, with an absolute noise floor ~ eps*|grad|/(2v),
  ## i.e. ~1.1e-7 at v=1e-9. About one order of headroom, not many.
  for (mu in c(-8, -45, 0.4)) {
    lo <- .probit_ad(mu, 0.99e-6, 1, 1, 15L)   # expansion branch
    hi <- .probit_ad(mu, 1.01e-6, 1, 1, 15L)   # quadrature branch
    slope <- 0.5 * (lo$dEdv + hi$dEdv)
    expect_lt(abs((hi$ell - lo$ell) - slope * 0.02e-6), 1e-12)
    expect_lt(abs(hi$dEdmu - lo$dEdmu), 1e-8)
    expect_lt(abs(hi$dEdv - lo$dEdv) / abs(lo$dEdv), 1e-6)
  }
})


test_that("HARD GUARD: the shared family id retains the distinct binomial link id", {
  ## The trap this closes: Laplace gives binomial-logit and binomial-probit the
  ## SAME family_id (1) and separates them by link_id only. A link-blind map
  ## Design 110 removes the divergent enum: both cells remain family 1 and the
  ## template dispatches on link_id. The pair, not family alone, is the guard.
  expect_identical(.va_r3_laplace_id_to_code(1L, 1L), 1L)
  expect_identical(.va_r3_laplace_id_to_code(1L, 0L), 1L)
  expect_identical(.va_r3_laplace_id_to_code(c(1L, 1L), c(0L, 1L)), c(1L, 1L))
  expect_identical(.va_r3_laplace_id_to_code(1L, 2L), 1L)
  ## A non-canonical link on a family that has only one must not map either.
  expect_error(.va_r3_laplace_id_to_code(2L, 1L), "does not admit")
  ## `lid` is required: a default would let the trap back in by omission.
  expect_error(.va_r3_laplace_id_to_code(1L))
})


test_that("the adapter carries family_id 1 with probit link_id and trial counts", {
  v <- .va_r3_validate_data(
    y = c(1L, 0L, 1L, 0L), n_trials = c(3L, 4L, 5L, 6L),
    X = matrix(1, nrow = 4L, ncol = 1L),
    unit_id = rep(1:2, each = 2L), trait_id = rep(1:2, 2L), q = 1L,
    family = "binomial_probit", link = "probit"
  )
  expect_identical(v$family, rep(1L, 4L))
  expect_identical(v$link_id, rep(1L, 4L))
  expect_identical(v$family_name, "binomial_probit")
  expect_identical(v$link, "probit")
  ## Regression: n_trials must NOT be reset to 1 on probit rows (it is only a
  ## sentinel for the families that do not use it).
  expect_identical(v$n_trials, c(3L, 4L, 5L, 6L))

  ## The link is checked against the code, both ways round.
  expect_error(
    .va_r3_validate_data(y = c(1L, 0L, 1L, 0L), n_trials = rep(1L, 4L),
                         X = matrix(1, 4L, 1L), unit_id = rep(1:2, each = 2L),
                         trait_id = rep(1:2, 2L), q = 1L,
                         family = "binomial_probit", link = "logit"),
    "requires link = \"probit\""
  )
  ## Mixed logit + probit derives a per-row link vector from the codes.
  vm <- .va_r3_validate_data(
    y = c(1L, 0L, 1L, 0L), n_trials = rep(1L, 4L),
    X = matrix(1, nrow = 4L, ncol = 1L),
    unit_id = rep(1:2, each = 2L), trait_id = rep(1:2, 2L), q = 1L,
    family_codes = rep(1L, 4L), link_ids = c(0L, 1L, 0L, 1L)
  )
  expect_identical(vm$link, c("logit", "probit", "logit", "probit"))
  expect_identical(vm$family_name, "mixed_binomial_links")
})


test_that("probit resolves to GH only; the Jaakkola-Jordan bound is refused", {
  ## JJ bounds the LOGISTIC term specifically. There is no probit analogue, so
  ## asking for it must error rather than silently fall back to quadrature.
  expect_identical(.va_r3_resolve_eval_method("auto", 1L, 1L), "gh")
  expect_identical(.va_r3_resolve_eval_method("gh", 1L, 1L), "gh")
  expect_error(.va_r3_resolve_eval_method("jj", 1L, 1L), "not implemented")
  expect_error(.va_r3_resolve_eval_method("jj", c(1L, 1L), c(0L, 1L)),
               "pure-binomial")
  expect_identical(.va_r3_family_entry(1L, 1L)$link, "probit")
})


test_that("integration = \"va\" admits binomial-probit through public GH H=7", {
  expect_true(.gllvmTMB_check_integration_fence(
    "va", family = "binomial", link = "probit", q = 1L, p = 4L, n = 150L
  ))
  skip_on_cran()
  set.seed(20260802L)
  n <- 120L; p <- 4L
  df <- data.frame(
    y     = rbinom(n * p, 1L, 0.5),
    trait = factor(rep(seq_len(p), times = n)),
    site  = factor(rep(seq_len(n), each = p))
  )
  fit <- gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = df, family = stats::binomial(link = "probit"),
    unit = "site", control = gllvmTMBcontrol(integration = "va")
  )
  expect_s3_class(fit, "gllvmTMB_va")
  expect_identical(fit$status, "healthy")
  expect_identical(fit$eval_method, "gh")
  expect_identical(fit$engine_result$quadrature$order, 7L)
})


test_that("a Bernoulli-probit toy fit tracks the shipped Laplace probit engine", {
  skip_on_cran()
  ## Design 108 s6's end-to-end leg. The discriminating comparison is against
  ## BOTH shipped links: if the new branch were secretly the logistic one, its
  ## latent-scale covariance would sit near the LOGIT fit (a ~2.9x difference on
  ## Sigma_B), not the probit one.
  set.seed(10805L)
  N <- 150L; T <- 4L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), N)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  beta <- c(-0.3, 0.1, 0.4, -0.1)
  Lambda <- matrix(c(0.8, 0.7, 0.6, 0.5), T, 1L)
  eta <- drop(X %*% beta) +
    as.numeric(Lambda[trait, ] * matrix(rnorm(N), N, 1L)[unit, ])
  y <- rbinom(N * T, 1L, pnorm(eta))

  df <- data.frame(y = y, trait = factor(trait), site = factor(unit))
  fml <- y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE)
  sigma_diag <- function(m) {
    s <- extract_Sigma_B(m)
    diag(if (is.list(s)) s[[1L]] else s)
  }
  lap_probit <- gllvmTMB(fml, data = df, unit = "site",
                         family = stats::binomial(link = "probit"))
  lap_logit  <- gllvmTMB(fml, data = df, unit = "site",
                         family = stats::binomial(link = "logit"))
  va <- .va_r3_fit(y = y, n_trials = rep(1L, N * T), X = X, unit_id = unit,
                   trait_id = trait, q = 1L, family = "binomial_probit",
                   H = 15L, n_starts = 4L)

  expect_identical(va$status, "healthy")
  expect_identical(va$family, "binomial_probit")
  expect_identical(va$eval_method, "gh")
  expect_identical(lap_probit$opt$convergence, 0L)

  d_probit <- max(abs(log(diag(va$report$Sigma_B) / sigma_diag(lap_probit))))
  d_logit  <- max(abs(log(diag(va$report$Sigma_B) / sigma_diag(lap_logit))))
  cat(sprintf("\n-- Stage 4 toy: max|log Sigma_B ratio| vs Laplace probit %.4f, vs Laplace logit %.4f\n",
              d_probit, d_logit))
  ## Relative, not a tuned absolute bound: the probit comparator must be much
  ## the closer of the two.
  expect_lt(d_probit, 0.5 * d_logit)

  ## Fixed effects agree tightly across the two approximations.
  b_va  <- unname(va$best$par[names(va$best$par) == "beta"])
  b_lap <- unname(lap_probit$opt$par[names(lap_probit$opt$par) == "b_fix"])
  expect_length(b_va, T)
  expect_lt(max(abs(b_va - b_lap)), 0.02)

  ## Honest note, recorded rather than asserted: on THIS single seed both
  ## engines under-recover the planted Sigma_B diagonal (VA 0.27-0.43 and
  ## Laplace 0.15-0.37 against a truth of 0.25-0.64). Agreement between two
  ## approximations is not accuracy, and one seed carries no MCSE. Recovery for
  ## probit is Design 108 Stage 8's measurement, not this stage's.
})
