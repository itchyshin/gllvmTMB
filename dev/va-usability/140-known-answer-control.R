## KNOWN-ANSWER CONTROL for every scoring convention.
## [[WHAT-WORKS]]:45 "Validate where the answer is KNOWN, then descend."
## The gaussian cell is where every arm MUST return trace ~ 1. Any arm that
## does not has a SCORING-CONVENTION bug, not an estimator problem.
## This is the check that would have caught the gllvm sigma.lv mis-scoring
## (folding sigma.lv=0.71 shrinks loadings 0.71^2 ~ 0.5) on sight.
setwd("/private/tmp/gllvmtmb-va-lane2")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll()); source("dev/va-usability/attenuation-lib.R")
T0 <<- 20L; N0 <- 150L
sc <- function(Lam, Z, b) c(sd_z = mean(apply(Z, 2, sd)),
      trace = sum(rowSums(Lam^2))/sum(b$sigma_jj_true),
      eta = var(as.numeric(Z %*% t(Lam)))/var(as.numeric(b$z_true %*% t(b$Lambda_true))))
out <- list()
for (s in 20262000L + 1:6) {
  b <- sim_cell(s, "gaussian_anchor", N0)
  f <- tryCatch(run_seed(s, "gaussian_anchor", N0), error = function(e) NULL)
  Y <- matrix(b$d$y, N0, T0, byrow = TRUE)
  X <- data.frame(x = b$d$x[seq(1, nrow(b$d), by = T0)])
  g <- tryCatch(gllvm::gllvm(y = Y, X = X, formula = ~ x, family = gaussian(),
                             num.lv = Q0, method = "VA", trace = FALSE), error = function(e) NULL)
  if (is.null(g)) next
  th <- as.matrix(g$params$theta); sg <- tryCatch(g$params$sigma.lv, error = function(e) NULL)
  out[[length(out)+1]] <- list(
    gllvm_raw = sc(th, as.matrix(g$lvs), b),
    gllvm_scaled = sc(if (!is.null(sg)) sweep(th, 2, sg, "*") else th, as.matrix(g$lvs), b),
    sigma_lv = if (is.null(sg)) NA else mean(sg))
}
cat(sprintf("\n== KNOWN-ANSWER CONTROL: gaussian n=%d p=%d, %d seeds. EVERY arm must give trace ~ 1 ==\n\n", N0, T0, length(out)))
for (a in c("gllvm_raw","gllvm_scaled")) {
  m <- rowMeans(sapply(out, function(x) x[[a]]))
  cat(sprintf("%-14s sd_z=%.3f  trace=%.3f  eta_var=%.3f   %s\n", a, m[1], m[2], m[3],
      if (abs(m[2]-1) < 0.15) "<- CONVENTION OK" else "<- CONVENTION WRONG"))
}
cat(sprintf("\ngllvm mean sigma.lv (gaussian) = %.3f\n", mean(unlist(lapply(out, function(x) x$sigma_lv)), na.rm=TRUE)))
