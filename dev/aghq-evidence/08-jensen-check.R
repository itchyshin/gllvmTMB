## IS THE "AGHQ SMALL-n UPWARD BIAS" JUST A METRIC ARTEFACT?
##
## Every ratio reported so far is ||Lambda_hat|| / ||Lambda_true||. The norm is CONVEX,
## so estimation noise inflates it even when Lambda_hat is perfectly unbiased:
## if Lambda_hat = Lambda + eps with E[eps] = 0 and Var = sigma^2, then
##      E||Lambda_hat||^2 = ||Lambda||^2 + p*q*sigma^2   >   ||Lambda||^2
## and the inflation GROWS as n falls, because sigma^2 does. That is the same shape as
## the measured AGHQ curve -- so before hunting a third bias lever, find out how much of
## the effect a PERFECTLY UNBIASED estimator would produce on its own.
##
## This needs no fitting at all: simulate an unbiased estimator with the sampling
## variability an MLE would actually have, and read off the inflation.
set.seed(11)
p <- 4L; q <- 1L; LAM <- 1.2; TRAITS <- p
Lt <- matrix(rnorm(p*q, 0, LAM), p, q)
nt <- norm(Lt, "F")

## Sampling SD of a loading, order 1/sqrt(n * information-per-site). Calibrate the
## constant so the n = 3200 case matches the MCSE actually observed there (~0.05 on the
## ratio), then read the implied inflation at every smaller n.
cal <- 0.05 * sqrt(3200)
cat(sprintf("true ||Lambda||_F = %.4f ; p = %d, q = %d\n\n", nt, p, q))
cat(sprintf("%6s | %10s | %10s | %10s\n", "n", "sd(elt)", "median ratio", "mean ratio"))
cat("       |            | of an UNBIASED estimator\n")
for (n in c(3200L,1600L,800L,400L,200L,100L,50L,25L)) {
  s <- cal / sqrt(n) * nt / sqrt(p*q)      # per-element sampling sd
  r <- replicate(20000, norm(Lt + matrix(rnorm(p*q, 0, s), p, q), "F") / nt)
  cat(sprintf("%6d | %10.4f | %10.4f | %10.4f\n", n, s, median(r), mean(r)))
}
cat("\nIf these ratios are ~1.00 everywhere, the metric is innocent and the measured\n")
cat("AGHQ curve (1.00 -> 1.97 -> 2.58) is real estimator bias. If they climb with the\n")
cat("same shape, a large part of that curve is Jensen inflation, not bias.\n")
