## Which binomial cells have a NON-degenerate Laplace fit? The AGHQ loop can
## only be judged on cells where the starting point is sane: on the Arc-0
## degenerate cells ||Sigma_B||_F is already 1e3-1e6 BEFORE any quadrature runs,
## so any frob measured after AGHQ says nothing about the loop.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet = TRUE))
source("dev/arc0/lib.R")
for (cl in list(c(60,6,2,7), c(60,6,2,11), c(100,8,2,1), c(100,8,2,2),
                c(150,6,2,1), c(200,6,2,3), c(60,6,1,1), c(100,6,1,2))) {
  d <- arc0_data(cl[1], cl[2], cl[3], cl[4])
  f <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::binomial()))
  L <- f$report$Lambda_B[seq_len(cl[2]), seq_len(cl[3]), drop = FALSE]
  fr <- norm(L %*% t(L), "F"); tr <- norm(d$Sigma_true, "F")
  cat(sprintf("n=%3d p=%d q=%d seed=%2d  laplace ||S||_F=%12.5g  true=%8.4g  ratio=%9.4g  %s\n",
              cl[1], cl[2], cl[3], cl[4], fr, tr, fr / tr,
              if (fr / tr < 5) "HEALTHY" else "degenerate"))
}
