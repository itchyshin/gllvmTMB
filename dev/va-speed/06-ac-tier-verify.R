## S5 -- correctness gate for the Albert-Chib tier.
##
## NOT an identity check. AC is a STRICT LOWER BOUND on the GH objective, so the
## usual "objective identical to ~1e-13" discipline from ARC.md does NOT apply
## here and would either fail a correct implementation or pass a broken one.
## The right checks are:
##   (1) round-trip -- eval_method = "ac" actually reaches the template as 2
##       (the silent-wrong-tier failure mode the derivation flagged as HIGH risk);
##   (2) the bound never EXCEEDS a high-H GH evaluation of the same parameters;
##   (3) the gap is strict and shrinks with v, as the derivation predicts;
##   (4) AD safety -- he() finite, not just gr(). A missing input clamp leaves
##       gr correct while he goes NaN, which gr-only testing cannot see;
##   (5) the family guard admits probit and refuses everything else.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
ok <- function(lbl, pass, extra = "") cat(sprintf(
  "%-58s %s %s\n", lbl, if (isTRUE(pass)) "PASS" else "**FAIL**", extra))

fam4 <- 4L; fam1 <- 1L

## ---- (1) tier plumbing round-trip ------------------------------------------
cat("\n-- 1. tier resolution and template code --\n")
ok("resolve(ac, probit) == 'ac'",
   identical(gllvmTMB:::.va_r3_resolve_eval_method("ac", fam4), "ac"))
ok("eval_method_code(ac, probit) == 2L",
   identical(gllvmTMB:::.va_r3_eval_method_code("ac", fam4), 2L),
   paste("got", gllvmTMB:::.va_r3_eval_method_code("ac", fam4)))
ok("eval_method_code(gh, probit) == 0L still",
   identical(gllvmTMB:::.va_r3_eval_method_code("gh", fam4), 0L))
ok("eval_method_code(jj, logit) == 1L still",
   identical(gllvmTMB:::.va_r3_eval_method_code("jj", fam1), 1L))
ok("objective_type(ac) == 'ELBO_AC'",
   identical(gllvmTMB:::.va_r3_objective_type("ac"), "ELBO_AC"))
ok("default_tier for probit is STILL gh (AC must not become default)",
   identical(gllvmTMB:::.va_r3_family_entry(4L)$default_tier, "gh"))
ok("auto still resolves probit to gh",
   identical(gllvmTMB:::.va_r3_resolve_eval_method("auto", fam4), "gh"))

## ---- (5) family guard, both directions -------------------------------------
cat("\n-- 5. family guard (mirror image of the JJ guard) --\n")
ok("ac REFUSED for binomial-logit",
   inherits(try(gllvmTMB:::.va_r3_resolve_eval_method("ac", fam1), silent = TRUE),
            "try-error"))
ok("ac REFUSED for mixed family",
   inherits(try(gllvmTMB:::.va_r3_resolve_eval_method("ac", c(fam4, fam1)),
                silent = TRUE), "try-error"))
ok("jj still REFUSED for probit",
   inherits(try(gllvmTMB:::.va_r3_resolve_eval_method("jj", fam4), silent = TRUE),
            "try-error"))
ok("an unknown tier is a hard error, not a silent GH fallback",
   inherits(try(gllvmTMB:::.va_r3_eval_method_code("nonesuch", fam4),
                silent = TRUE), "try-error"))

## ---- shared toy cell --------------------------------------------------------
make_cell <- function(N = 80L, T0 = 5L, q = 1L, ntr = 6L, seed = 7L) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * q, 0, 0.8), T0, q); lam[upper.tri(lam)] <- 0
  a   <- matrix(rnorm(N * q), N, q)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y   <- rbinom(N * T0, ntr, pnorm(as.vector(eta)))
  d   <- data.frame(y = y,
                    unit  = rep(seq_len(N), times = T0),
                    trait = rep(seq_len(T0), each  = N))
  list(d = d, ntr = ntr, q = q, T0 = T0,
       X = unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0)))),
       Sigma_true = lam %*% t(lam))
}
cell <- make_cell()

build <- function(tier, H = 61L) {
  gllvmTMB:::.va_r3_make_objective(
    gllvmTMB:::.va_r3_validate_data(
      y = cell$d$y, n_trials = rep(cell$ntr, nrow(cell$d)), X = cell$X,
      unit_id = cell$d$unit, trait_id = cell$d$trait, q = cell$q,
      family = "binomial_probit", link = "probit", unique = TRUE),
    H = H, eval_method = tier)
}

cat("\n-- 2/3. bound direction and strictness (the real correctness check) --\n")
o_ac <- build("ac"); o_gh <- build("gh", H = 61L)

## REPORT round-trip: the cheapest falsifier for a silently-wrong tier.
rep_ac <- o_ac$report(o_ac$par)$eval_method
rep_gh <- o_gh$report(o_gh$par)$eval_method
ok("template REPORTs eval_method 2 for ac", identical(as.integer(rep_ac), 2L),
   paste("got", rep_ac))
ok("template REPORTs eval_method 0 for gh", identical(as.integer(rep_gh), 0L),
   paste("got", rep_gh))

## Both objectives are NEGATIVE log-likelihoods, so a LOWER bound on the ELBO is
## a HIGHER negative objective. AC >= GH is the correct direction.
set.seed(11)
pars <- c(list(o_gh$par), replicate(25, o_gh$par + rnorm(length(o_gh$par), 0, 0.35),
                                    simplify = FALSE))
f_ac <- vapply(pars, o_ac$fn, numeric(1))
f_gh <- vapply(pars, o_gh$fn, numeric(1))
gap  <- f_ac - f_gh
ok("AC never below GH on the NLL scale (i.e. never a tighter bound)",
   all(gap >= -1e-8), sprintf("min gap %.3e over %d points", min(gap), length(gap)))
ok("the bound is STRICT (gap > 0), not an equality",
   all(gap > 1e-6), sprintf("min gap %.3e", min(gap)))
ok("all AC values finite", all(is.finite(f_ac)))

## ---- (4) AD safety: gr AND he ----------------------------------------------
cat("\n-- 4. AD safety (he(), not just gr()) --\n")
g <- o_ac$gr(o_ac$par)
h <- try(o_ac$he(o_ac$par), silent = TRUE)
ok("gr finite", all(is.finite(g)))
ok("he finite (the check gr alone cannot make)",
   !inherits(h, "try-error") && all(is.finite(h)))

## Finite-difference the gradient -- catches a wrong analytic derivative that a
## finite objective would hide.
set.seed(3); idx <- sample(seq_along(o_ac$par), min(8L, length(o_ac$par)))
eps <- 1e-5
fd <- vapply(idx, function(i) {
  p1 <- p2 <- o_ac$par; p1[i] <- p1[i] + eps; p2[i] <- p2[i] - eps
  (o_ac$fn(p1) - o_ac$fn(p2)) / (2 * eps)
}, numeric(1))
relerr <- abs(fd - g[idx]) / pmax(abs(g[idx]), 1)
ok("AD gradient matches finite difference", max(relerr) < 1e-5,
   sprintf("max rel err %.2e", max(relerr)))

## ---- n-scaling: the place gllvm is wrong -----------------------------------
cat("\n-- 6. the n*v/2 term (where gllvm's form is NOT a lower bound) --\n")
## Direct check of the evaluator's n-dependence via the identity
##   E_AC(mu,v;y,n) = y logPhi(mu) + (n-y) logPhi(-mu) - n v/2
## against a high-node GH reference for several n. If the template had used
## v/2 instead of n*v/2, the bound would be VIOLATED at n > 1.
gh_ref <- function(mu, v, y, n, H = 200L) {
  gq <- statmod::gauss.quad(H, kind = "hermite")
  eta <- mu + sqrt(2 * v) * gq$nodes
  sum(gq$weights * (y * pnorm(eta, log.p = TRUE) +
                    (n - y) * pnorm(-eta, log.p = TRUE))) / sqrt(pi)
}
ac_val <- function(mu, v, y, n)
  y * pnorm(mu, log.p = TRUE) + (n - y) * pnorm(-mu, log.p = TRUE) - n * v / 2
if (requireNamespace("statmod", quietly = TRUE)) {
  grid <- expand.grid(mu = c(-2, -0.5, 0, 0.5, 2), v = c(0.05, 0.5, 2),
                      n = c(1, 6, 20))
  grid$y <- pmin(grid$n, 1)
  d_ok <- mapply(function(mu, v, n, y) gh_ref(mu, v, y, n) - ac_val(mu, v, y, n),
                 grid$mu, grid$v, grid$n, grid$y)
  ## the WRONG (gllvm) form, for contrast
  d_bad <- mapply(function(mu, v, n, y)
    gh_ref(mu, v, y, n) - (y * pnorm(mu, log.p = TRUE) +
                           (n - y) * pnorm(-mu, log.p = TRUE) - v / 2),
    grid$mu, grid$v, grid$n, grid$y)
  ok("n*v/2 form is a valid lower bound at every n", all(d_ok >= -1e-9),
     sprintf("min %.5f", min(d_ok)))
  ok("v/2 form (gllvm's) is NOT a bound at n>1 -- confirming we must differ",
     min(d_bad) < -1, sprintf("min %.3f nats", min(d_bad)))
} else cat("  (statmod absent -- n-scaling check skipped)\n")

cat("\nAC_VERIFY_DONE\n")
