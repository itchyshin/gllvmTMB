## Two-sided companion to the one-sided `rel_frob > 10` degeneracy detector.
##
## RESEARCH-ONLY. Not sourced by the package, not on any load path, no NAMESPACE
## change. Read-only with respect to grid.csv/grid.rds: this file only computes
## and reports; it does not touch R/, src/, or any file under dev/totoro-grid/,
## dev/heywood/, dev/arc0/, or dev/vgh/.
##
## ---------------------------------------------------------------------------
## 1. The algebra (why the one-sided rule is structurally blind to contraction)
## ---------------------------------------------------------------------------
##
## The existing rule (dev/totoro-grid/analyse-grid.R:99, mirrored in
## dev/lambda-spectrum-vs-degeneracy.R:38, dev/arc0/00-cells.R:58,
## dev/arc0/20-profile.R:240,480, dev/arc0/30-ray.R:39,
## dev/vgh/gaussian-degeneracy-reachability.R:101,107,
## dev/heywood/vgh-vs-laplace-degeneracy.R:115-119,
## dev/relative-collapse-vs-59of70.R:26) is
##
##   rel_frob = ||Sigma_hat - Sigma_true||_F / ||Sigma_true||_F
##   degenerate  <-  rel_frob > 10
##
## (dev/totoro-grid/run-grid.R:47: `relfrob <- function(S, St) norm(S - St, "F") / norm(St, "F")`.)
##
## Let kappa = ||Sigma_hat||_F / ||Sigma_true||_F  (the scale of the estimate relative to truth;
## kappa < 1 is contraction, kappa > 1 is inflation, kappa = 1 is scale-correct).
##
## Ordinary triangle inequality applied to Sigma_hat = (Sigma_hat - Sigma_true) + Sigma_true:
##   ||Sigma_hat||_F <= ||Sigma_hat - Sigma_true||_F + ||Sigma_true||_F
##   =>  kappa <= rel_frob + 1
##   =>  rel_frob >= kappa - 1                                                   ... (i)
##
## The complementary bound (apply the same inequality with Sigma_hat and Sigma_true swapped, i.e. to
## Sigma_true = (Sigma_true - Sigma_hat) + Sigma_hat, equivalently the reverse triangle inequality
## | ||Sigma_hat||_F - ||Sigma_true||_F | <= ||Sigma_hat - Sigma_true||_F ):
##   ||Sigma_hat - Sigma_true||_F <= ||Sigma_hat||_F + ||Sigma_true||_F
##   =>  rel_frob <= kappa + 1                                                   ... (ii)
##
## (ii) is the load-bearing direction for "large rel_frob requires large kappa": rel_frob > 10
## forces kappa > 9, i.e. ||Sigma_hat||_F > 9 * ||Sigma_true||_F -- the one-sided rule can only fire
## on INFLATION.
##
## For CONTRACTION, kappa in [0, 1] by definition, so (ii) gives rel_frob <= kappa + 1 <= 2. Sharper:
## if Sigma_hat and Sigma_true are co-directional (Sigma_hat = c * Sigma_true, 0 <= c <= 1 -- the
## "uniform shrinkage" shape a variational bound that over-charges variance would produce), the
## reverse triangle inequality holds with EQUALITY, rel_frob = |kappa - 1| = 1 - kappa <= 1. Either
## way, no degree of contraction -- kappa = 0.5, 0.1, 0.001, all the way to Sigma_hat = 0 exactly,
## where rel_frob = 1 -- can ever reach rel_frob > 10. An estimator that contracts Sigma toward zero
## is INVISIBLE to this detector by construction, not by tuning.
##
## Verified numerically below (`.two_sided_verify_algebra()`).
##
## ---------------------------------------------------------------------------
## 2. The two-sided companion
## ---------------------------------------------------------------------------
##
## kappa is reported directly (a signed diagnostic, not folded into one absolute-value number), and
## flags contraction at kappa < 1/3, alongside the untouched inflation rule at rel_frob > 10.
##
## kappa should be the SAME norm used inside rel_frob (Frobenius) whenever raw Sigma_hat/Sigma_true
## matrices are available -- see two_sided_from_matrices(). When only precomputed scalar columns are
## available (as in dev/totoro-grid/results/grid.csv, which stores rel_frob and attenuation but not
## the raw Lambda/Sigma matrices), this file PREFERS the existing `attenuation` column
## (tr(Sigma_hat)/tr(Sigma_true), dev/totoro-grid/run-grid.R:73: `at <- sum(diag(Sh)) /
## sum(diag(Sig_true))`) as kappa, per the task instruction to match what is already recorded rather
## than inventing a second, redundant scale column.
##
## CAVEAT, stated explicitly because it is a real approximation, not a formality: tr(.) and ||.||_F
## are DIFFERENT matrix norms. For a q x q symmetric PSD matrix A they satisfy
## ||A||_F <= tr(A) <= sqrt(q) * ||A||_F (Cauchy-Schwarz on the nonnegative eigenvalues), so the
## trace ratio and the Frobenius ratio can differ by up to sqrt(q) (1.4x at q=2, 2x at q=4 in this
## grid) and will diverge most exactly when the eigenvalue spectrum is skewed -- i.e. near the
## Heywood-like cases this detector exists to catch. They coincide EXACTLY under uniform rescaling
## (Sigma_hat = c * Sigma_true for scalar c), which is the shape JJ's over-charging mechanism is
## theorised to produce. NOT independently verified against the Frobenius ratio in this pass (that
## would require the raw Lambda/Sigma matrices, which grid.csv does not retain -- see the after-task
## report's "Uncertain" section). Treat attenuation-as-kappa as a documented, motivated substitution,
## not an identity.

#' Two-sided scale/degeneracy diagnostic from raw covariance matrices
#'
#' Computes rel_frob (Frobenius, matching the existing one-sided rule exactly) and kappa
#' (Frobenius scale ratio) from the raw estimated and true covariance matrices, and flags both
#' inflation (rel_frob > inflation_thresh) and contraction (kappa < contraction_thresh).
#'
#' @param Sigma_hat,Sigma_true Symmetric matrices of the same dimension (e.g. Lambda %*% t(Lambda)).
#' @param inflation_thresh Old one-sided threshold on rel_frob. Default 10, matching
#'   dev/totoro-grid/analyse-grid.R:99.
#' @param contraction_thresh New threshold on kappa. Default 1/3.
#' @return A one-row data.frame: rel_frob, kappa, flag_inflated (old rule), flag_contracted (new),
#'   flag_two_sided (either).
two_sided_from_matrices <- function(Sigma_hat, Sigma_true,
                                    inflation_thresh = 10, contraction_thresh = 1 / 3) {
  stopifnot(is.matrix(Sigma_hat), is.matrix(Sigma_true), all(dim(Sigma_hat) == dim(Sigma_true)))
  nt <- norm(Sigma_true, "F")
  rel_frob <- norm(Sigma_hat - Sigma_true, "F") / nt
  kappa <- norm(Sigma_hat, "F") / nt
  .two_sided_row(rel_frob, kappa, inflation_thresh, contraction_thresh)
}

#' Two-sided scale/degeneracy diagnostic from precomputed scalar columns
#'
#' For data that already carries rel_frob and a scale column (e.g. grid.csv's `attenuation`,
#' the trace ratio) but not the raw matrices. Vectorised: all arguments may be vectors/columns.
#'
#' @param rel_frob Numeric vector, the existing one-sided statistic.
#' @param kappa Numeric vector, a scale ratio for Sigma_hat vs Sigma_true. Pass the `attenuation`
#'   column from grid.csv here (trace ratio) -- see the CAVEAT above.
#' @param inflation_thresh,contraction_thresh As above.
#' @return A data.frame, one row per input element, with rel_frob, kappa, flag_inflated (the OLD
#'   rule, unchanged), flag_contracted (the NEW rule), flag_two_sided (either).
two_sided_from_scalars <- function(rel_frob, kappa,
                                   inflation_thresh = 10, contraction_thresh = 1 / 3) {
  n <- max(length(rel_frob), length(kappa))
  rel_frob <- rep_len(rel_frob, n)
  kappa <- rep_len(kappa, n)
  .two_sided_row(rel_frob, kappa, inflation_thresh, contraction_thresh)
}

.two_sided_row <- function(rel_frob, kappa, inflation_thresh, contraction_thresh) {
  flag_inflated <- is.finite(rel_frob) & rel_frob > inflation_thresh
  flag_contracted <- is.finite(kappa) & kappa < contraction_thresh
  data.frame(
    rel_frob = rel_frob,
    kappa = kappa,
    flag_inflated = flag_inflated,      # the OLD rule, byte-identical logic
    flag_contracted = flag_contracted,  # the NEW, complementary rule
    flag_two_sided = flag_inflated | flag_contracted
  )
}

## ---------------------------------------------------------------------------
## 3. Numeric verification of the algebra in section 1 (run when sourced with
##    verify = TRUE, or call directly)
## ---------------------------------------------------------------------------
.two_sided_verify_algebra <- function(n_checks = 20000L, seed = 1L) {
  set.seed(seed)
  q <- 4L
  bad_ii <- 0L  # count of violations of rel_frob <= kappa + 1
  bad_i <- 0L   # count of violations of rel_frob >= kappa - 1
  max_rel_frob_under_contraction <- 0
  for (i in seq_len(n_checks)) {
    L_true <- matrix(rnorm(q * q), q, q)
    Sigma_true <- tcrossprod(L_true)
    ## Random scale (including contraction, kappa < 1, on ~half the draws) and random rotation, so
    ## Sigma_hat is NOT simply a multiple of Sigma_true -- a genuine stress test of the inequality.
    scale <- exp(rnorm(1, 0, 1.2))
    L_hat <- matrix(rnorm(q * q), q, q)
    Sigma_hat <- scale * tcrossprod(L_hat) / norm(tcrossprod(L_hat), "F") * norm(Sigma_true, "F")
    nt <- norm(Sigma_true, "F")
    rel_frob <- norm(Sigma_hat - Sigma_true, "F") / nt
    kappa <- norm(Sigma_hat, "F") / nt
    if (rel_frob > kappa + 1 + 1e-8) bad_ii <- bad_ii + 1L
    if (rel_frob < kappa - 1 - 1e-8) bad_i <- bad_i + 1L
    if (kappa <= 1) max_rel_frob_under_contraction <- max(max_rel_frob_under_contraction, rel_frob)
  }
  list(
    n_checks = n_checks,
    violations_of_rel_frob_le_kappa_plus_1 = bad_ii,
    violations_of_rel_frob_ge_kappa_minus_1 = bad_i,
    max_rel_frob_observed_when_kappa_le_1 = max_rel_frob_under_contraction,
    verdict = if (bad_ii == 0L && bad_i == 0L && max_rel_frob_under_contraction <= 2 + 1e-8) {
      "PASS: rel_frob <= kappa + 1 held on every draw; rel_frob capped at <= 2 whenever kappa <= 1"
    } else "FAIL: see counts above"
  )
}

if (identical(Sys.getenv("TWO_SIDED_VERIFY"), "TRUE")) {
  print(.two_sided_verify_algebra())
}
