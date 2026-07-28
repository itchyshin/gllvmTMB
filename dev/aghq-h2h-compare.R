## Scores the two head-to-head runs on ONE honest objective F(theta) (nodes
## adapted AT theta), plus Laplace and truth as reference points.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet = TRUE))
source("dev/arc0/lib.R"); source("dev/aghq-honest-F.R")

A <- readRDS("dev/aghq-h2h-old.rds")
B <- readRDS("dev/aghq-h2h-new.rds")

for (i in seq_along(A)) {
  a <- A[[i]]; b <- B[[i]]
  d <- arc0_data(a$n, a$p, a$q, a$seed)
  fl <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::binomial()))
  fa <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::binomial(),
                                  control = gllvmTMBcontrol(aghq = 9L)))
  Lla <- fl$report$Lambda_B[seq_len(a$p), seq_len(a$q), drop = FALSE]
  cat(sprintf("\n=== n=%d p=%d q=%d seed=%d  (k=9) ===\n", a$n, a$p, a$q, a$seed))
  cat(sprintf("  truth   ||Sigma_B||_F = %.6g\n", norm(d$Sigma_true, "F")))
  cat(sprintf("  laplace ||Sigma_B||_F = %.6g   nll(laplace) = %.6f\n",
              norm(Lla %*% t(Lla), "F"), fl$opt$objective))
  Fa <- aghq_F(fa, fl, a$par)
  Fb <- aghq_F(fa, fl, b$par)
  Fl <- aghq_F(fa, fl, fl$opt$par)
  cat(sprintf("  F(laplace optimum)             = %.8f\n", Fl))
  cat(sprintf("  OLD  passes=%-4s %6.0fs  reported=%.6f  F=%.8f  ||Sigma_B||_F=%.6g\n",
              a$passes, a$elapsed, a$objective, Fa, a$frob))
  cat(sprintf("  NEW  passes=%-4s %6.0fs  reported=%.6f  F=%.8f  ||Sigma_B||_F=%.6g  [%s]\n",
              b$passes, b$elapsed, b$objective, Fb, b$frob, b$stop_reason))
  cat(sprintf("  --> NEW is %s on F by %.6g ; %.2fx wall clock\n",
              if (Fb < Fa) "BETTER" else "WORSE", abs(Fb - Fa), a$elapsed / b$elapsed))
}
