## The default path must be BYTE-IDENTICAL: every edit is inside
## `if (!is.null(aghq_k_req))`, which `aghq = FALSE` (the default) never enters.
## Asserting that from the diff is not evidence; this measures it.
## Usage: Rscript dev/aghq-laplace-untouched.R <pkg_root> <out.rds>
a <- commandArgs(TRUE)
suppressMessages(devtools::load_all(a[1], quiet = TRUE))
source("dev/arc0/lib.R")
res <- lapply(list(c(60,6,2,7), c(100,8,2,2), c(150,6,2,1), c(60,6,1,1)), function(cl) {
  d <- arc0_data(cl[1], cl[2], cl[3], cl[4])
  f <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = stats::binomial()))
  L <- f$report$Lambda_B[seq_len(cl[2]), seq_len(cl[3]), drop = FALSE]
  list(cell = cl, objective = f$opt$objective, par = unname(f$opt$par),
       frob = norm(L %*% t(L), "F"))
})
saveRDS(res, a[2])
for (r in res) cat(sprintf("n=%3d p=%d q=%d seed=%d  nll=%.10f  ||S||_F=%.8g\n",
                           r$cell[1], r$cell[2], r$cell[3], r$cell[4],
                           r$objective, r$frob))
