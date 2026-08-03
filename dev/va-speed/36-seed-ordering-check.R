## Is the z_B seed CORRECTLY ORDERED, or merely correctly SHAPED?
##
## 34-hybrid-mode-warmstart.R verifies the seed reached MakeADFun by comparing
## DIMENSIONS. That cannot distinguish a correctly ordered seed from one whose
## units are permuted: both are (d_B, n_sites) and both pass. And the two produce
## indistinguishable outcomes on the checks we ran -- a scrambled seed still lands
## on the right optimum, because Laplace's inner solve converges from wherever it
## starts; it just does not save any time.
##
## So the disappointing 1.13x has TWO candidate explanations:
##   (1) the inner solve genuinely is not the bottleneck at this N (the hypothesis
##       the scaling ladder is meant to test), or
##   (2) the seed is scrambled in unit order and is therefore nearly useless.
## They look identical in everything measured so far, and (2) would make the whole
## ladder measure noise. This script separates them.
##
## THE DISCRIMINATOR: VA's variational means m_i and Laplace's fitted z_B are both
## estimates of the SAME latent scores for the SAME units. If the ordering is
## right they must correlate strongly, unit for unit. If the seed is permuted, the
## correlation collapses toward zero while the marginal DISTRIBUTIONS stay
## identical -- which is precisely why no shape or summary check can catch it.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

N <- 120L; T0 <- 8L; Q <- 2L; NTR <- 6L
set.seed(11)
lam <- matrix(rnorm(T0 * Q, 0, 0.8), T0, Q); lam[upper.tri(lam)] <- 0
a <- matrix(rnorm(N * Q), N, Q)
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
d <- data.frame(y = y, succ = y, fail = NTR - y,
                unit = factor(rep(seq_len(N), times = T0)),
                trait = factor(rep(seq_len(T0), each = N)))
X <- unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))

cat("== warm-up (untimed) ==\n"); flush.console()
invisible(tryCatch(gllvmTMB:::.va_r3_fit(y = d$y[1:200], n_trials = rep(NTR, 200),
  X = X[1:200, , drop = FALSE], unit_id = as.integer(d$unit)[1:200],
  trait_id = as.integer(d$trait)[1:200], q = 1L, family = "binomial_probit",
  link = "probit", unique = FALSE, n_starts = 1L, H = 15L, eval_method = "ac",
  control = list(eval.max = 200L, iter.max = 100L)), error = function(e) NULL))
cat("== warm-up done ==\n\n"); flush.console()

## --- VA fit: variational means m, laid out unit-major (N x q) ----------------
fva <- gllvmTMB:::.va_r3_fit(
  y = d$y, n_trials = rep(NTR, nrow(d)), X = X,
  unit_id = as.integer(d$unit), trait_id = as.integer(d$trait), q = Q,
  family = "binomial_probit", link = "probit", unique = FALSE,
  n_starts = 1L, H = 15L, eval_method = "ac", collapse_variational_cov = TRUE,
  control = list(eval.max = 800L, iter.max = 400L))
m_flat <- unname(fva$best$par[names(fva$best$par) == "m"])
stopifnot(length(m_flat) == N * Q)
## Layout contract (inst/tmb/gllvmTMB_va_r3.cpp:413-417): coordinate-major, so
## entry (level g, coordinate c) sits at c*N + g. That is a COLUMN-major N x q.
m_mat <- matrix(m_flat, nrow = N, ncol = Q)

## --- Laplace fit: fitted z_B ------------------------------------------------
fla <- gllvmTMB::gllvmTMB(
  cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q, unique = FALSE),
  data = d, family = binomial(link = "probit"), unit = "unit")

zb <- NULL
for (nm in c("z_B", "z")) {
  pr <- tryCatch(fla$sd_report$par.random, error = function(e) NULL)
  if (!is.null(pr) && any(names(pr) == nm)) { zb <- unname(pr[names(pr) == nm]); break }
}
if (is.null(zb)) zb <- tryCatch(as.numeric(t(gllvmTMB::getLV(fla))), error = function(e) NULL)
if (is.null(zb)) { cat("COULD NOT EXTRACT z_B -- check failed, not the seed\n"); quit(save = "no") }

## Shipped z_B is (d_B, n_sites) -- coordinate-fastest -- so a matching N x q is
## the TRANSPOSE of the (q, N) reshape.
z_mat <- if (length(zb) == N * Q) t(matrix(zb, nrow = Q, ncol = N)) else NULL
if (is.null(z_mat)) { cat(sprintf("z_B length %d != N*q %d -- cannot align\n", length(zb), N * Q)); quit(save = "no") }

cat("\n=== DISCRIMINATOR ===\n")
for (k in seq_len(Q)) {
  r_aligned  <- suppressWarnings(cor(m_mat[, k], z_mat[, k]))
  r_permuted <- suppressWarnings(cor(m_mat[, k], sample(z_mat[, k])))
  cat(sprintf("axis %d: cor(VA m, LA z_B) = %+.4f   [same values permuted: %+.4f]\n",
              k, r_aligned, r_permuted))
}
r1 <- suppressWarnings(abs(cor(m_mat[, 1], z_mat[, 1])))
cat(sprintf("\nmarginal SDs -- VA m: %s | LA z_B: %s  (these match even when SCRAMBLED,\n",
            paste(sprintf("%.3f", apply(m_mat, 2, sd)), collapse = "/"),
            paste(sprintf("%.3f", apply(z_mat, 2, sd)), collapse = "/")))
cat("which is exactly why a distributional check cannot catch a permutation)\n")
cat(sprintf("\nVERDICT: %s\n", if (isTRUE(r1 > 0.5))
  "ORDERING LOOKS CORRECT -- the seed is informative, so the small speedup is a REAL finding about where Laplace's time goes"
  else "ORDERING SUSPECT -- correlation is weak, so the seed may be near-useless and the 1.13x would be an artefact, not a finding"))
cat("\nSEED_ORDER_CHECK_DONE\n")
