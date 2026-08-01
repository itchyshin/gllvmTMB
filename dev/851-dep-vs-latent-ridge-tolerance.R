## Is the `dep()` vs `latent(d = n_traits)` objective tolerance an INVARIANT,
## or one lucky optimiser trajectory?  (issue #851)
##
## `tests/testthat/test-canonical-keywords.R:556` asserts
##
##   expect_equal(fit_dep$opt$objective, fit_latent$opt$objective, tolerance = 1e-10)
##
## on the grounds that the two spellings take the same engine path and only the
## `.dep` marker differs.  The FIRST half of that is true.  The second half is
## not, and it is the reason the tolerance is fragile:
##
##   dep(0 + trait | site)               -> an unstructured 4x4 covariance, 10 params
##   latent(0 + trait | site, d = 4)     -> Lambda Lambda' with Lambda 4x4 lower
##                                          triangular (10 params, already a FULL
##                                          unstructured PD covariance) PLUS the
##                                          default diag(Psi) (4 more)
##
## So the `latent` spelling is over-parameterised by 4 dimensions.  Both fits
## maximise the same likelihood and reach the same Sigma, but the `latent` one
## does it on a genuinely FLAT 4-dimensional ridge, where the objective is
## constant to many digits and the stopping point is set by the optimiser path
## rather than by the model.  Asserting agreement at 1e-10 RELATIVE (about 450x
## tighter than testthat's default 1.5e-8) therefore asserts trajectory
## identity, not model identity.
##
## MEASURED 2026-07-31, 12 seeds, this comparison run on BOTH trees:
##
##   origin/main                   : 6 / 12 seeds BREACH 1e-10   max 5.31e-09
##   claude/851-scale-aware-start  : 6 / 12 seeds BREACH 1e-10   max 1.15e-09
##
## `main` fails its own tolerance on HALF of all seeds.  It passes at seed 42 --
## the seed the test happens to use -- by luck.  The #851 branch is not worse on
## this metric; its worst case is about 4.6x better.
##
## The point of recording this: when the #851 start change moved seed 42 from
## 7.00e-11 to 1.25e-10, that looked like a regression the branch had caused.
## It is not.  It is a pre-existing knife-edge assertion being re-rolled.  Any
## change anywhere that perturbs the optimiser path -- a start value, a
## tolerance, a BLAS version, a compiler -- has a coin-flip chance of tripping
## it.  Widening it to something the flat ridge can actually deliver is a
## correction, not a relaxation; leaving it at 1e-10 means the test fails
## randomly for reasons unrelated to what it is testing.
##
## What the test is FOR -- that `dep()` and saturated `latent()` agree on the
## fitted model -- is better served by comparing the fitted Sigma, or by a
## tolerance near the achievable precision of a flat ridge (~1e-8, i.e.
## testthat's default), than by 1e-10 on the objective.
##
## Run: Rscript dev/851-dep-vs-latent-ridge-tolerance.R [pkg_dir]

args <- commandArgs(trailingOnly = TRUE)
pkg <- if (length(args) >= 1L) args[[1L]] else "."
suppressMessages(devtools::load_all(pkg, quiet = TRUE))

SEEDS <- c(42, 1, 2, 3, 7, 11, 13, 17, 19, 23, 29, 31)
TOL <- 1e-10

res <- data.frame()
for (s in SEEDS) {
  set.seed(s)
  df <- gllvmTMB::simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 4,
    mean_species_per_site = 4, seed = s
  )$data
  f <- function(form) tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(form, data = df))),
    error = function(e) NULL
  )
  fd <- f(value ~ 0 + trait + dep(0 + trait | site))
  fl <- f(value ~ 0 + trait + latent(0 + trait | site, d = 4))
  if (is.null(fd) || is.null(fl)) next
  rel <- abs(fd$opt$objective - fl$opt$objective) / abs(fl$opt$objective)
  res <- rbind(res, data.frame(
    seed = s, sd_y = sd(df$value),
    rel_diff = rel, breach = rel > TOL,
    conv_dep = fd$opt$convergence, conv_lat = fl$opt$convergence
  ))
}

cat("\n===== dep() vs latent(d = 4): objective agreement across seeds =====\n")
print(res, digits = 6)
cat(sprintf("\nBREACHES of tolerance %.0e : %d / %d seeds\n",
            TOL, sum(res$breach), nrow(res)))
cat(sprintf("median rel.diff = %.3e   max = %.3e\n",
            median(res$rel_diff), max(res$rel_diff)))
cat(sprintf("convergence != 0 on the saturated latent fit: %d / %d seeds\n",
            sum(res$conv_lat != 0), nrow(res)))
