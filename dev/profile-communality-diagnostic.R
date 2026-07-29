## Diagnostic for issue #813 — profile-likelihood intervals for communality.
##
## Runs the EXISTING internal profile_communality() (R/profile-derived-curves.R)
## against a live Gaussian d=1 fit with a known loading gradient (0.9, 0.7, 0.5,
## 0.2), so c2_hat spans high to low. Reports, per trait, whether the profile
## brackets the chi-square critical value on each side.
##
## Not a test: this is an exploratory harness. Findings recorded on #813.
## Run: Rscript dev/profile-communality-diagnostic.R

suppressMessages(pkgload::load_all(".", quiet = TRUE))
set.seed(42)
n <- 120; tn <- c("t1","t2","t3","t4")
u <- factor(seq_len(n)); z <- rnorm(n, sd = 0.9)
eta <- outer(z, c(0.9,0.7,0.5,0.2)); colnames(eta) <- tn
Y <- eta + matrix(rnorm(length(eta), 0, 0.6), nrow = n)
d <- data.frame(unit=rep(u,each=4), trait=factor(rep(tn,times=n),levels=tn), value=as.vector(t(Y)))
fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1), data=d,
                trait="trait", unit="unit", family=gaussian(), silent=TRUE)

for (ti in 1:4) {
  cur <- gllvmTMB:::profile_communality(fit, tier="unit", trait_idx=ti, n_grid=15L)
  crit <- qchisq(0.95, 1)
  mle  <- cur$estimate[1]
  lo   <- cur$profile_value[cur$profile_value < mle]
  hi   <- cur$profile_value[cur$profile_value > mle]
  dlo  <- cur$delta_deviance[cur$profile_value < mle]
  dhi  <- cur$delta_deviance[cur$profile_value > mle]
  cat(sprintf("trait %d  c2_hat=%.4f  grid=[%.3f, %.3f]  max_dd_left=%.3f  max_dd_right=%.3f  crit=%.3f\n",
      ti, mle, min(cur$profile_value), max(cur$profile_value),
      max(dlo, na.rm=TRUE), max(dhi, na.rm=TRUE), crit))
  cat(sprintf("          brackets LOWER: %s   brackets UPPER: %s\n",
      max(dlo,na.rm=TRUE) >= crit, max(dhi,na.rm=TRUE) >= crit))
}
cat("\ncolumns:", paste(names(gllvmTMB:::profile_communality(fit, tier='unit', trait_idx=1L, n_grid=5L)), collapse=", "), "\n")
